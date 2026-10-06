import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/utils/message_pack_decoder.dart';

/// Single multiplexed Trade Engine socket (`{socketUrl}/ws/stream`).
///
/// Replaces the legacy 5-socket layout (`/ws/op`, `/ws/po`, `/ws/symbol`,
/// `/ws/marketwatch`, `/ws/account`) for flavors that opt in via
/// [FlavorConfig.usesSingleStreamSocket] (pippro / pipze).
///
/// Wire protocol (observed from server):
/// - First JSON frame: `{"type":"authenticate","authID":"<token>","trading_account":"<id>","channels":[...],"symbols":[...]}`
/// - Server responds JSON: `{"type":"authenticated",...}` + `{"type":"stream_subscribed",...}`.
/// - Data frames are binary MessagePack arrays whose first element is the
///   channel tag (`"prices"`, `"positions"`, `"orders"`, `"accounts"`), e.g.
///   `["prices","EURUSD",...]`.
/// - Symbol updates: `{"type":"subscription_updated","action":"subscribe"|"unsubscribe","symbols":[...]}`.
///
/// The service tags each decoded frame with its channel and republishes it on
/// four broadcast streams so existing controllers can migrate one at a time.
class StreamWebSocketService extends GetxService with WidgetsBindingObserver {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  MT5Account? _currentAccount;
  final Set<String> _symbols = <String>{};
  List<String> _channels = const <String>[
    'prices',
    'positions',
    'orders',
    'accounts',
  ];

  final RxBool isConnected = false.obs;
  final RxBool isAuthenticated = false.obs;

  // Heartbeat + reconnect state, mirroring the web client contract
  // (ws-stream-reference.md §7). "Alive" is marked on every inbound frame.
  Timer? _pingTimer;
  Timer? _staleTimer;
  Timer? _reconnectTimer;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _reconnectAttempt = 0;
  bool _manualClose = false;

  /// Monotonic account-switch sequence (spec §6). Every async step inside
  /// switchAccount captures this value and aborts if a newer switch has
  /// started (fast A→B→C tap must only land C).
  int _switchSeq = 0;

  /// Chart's currently selected symbol — always kept subscribed even if the
  /// user removes it from favorites (spec §6). Nullable: no chart open.
  String? _pinnedSymbol;

  static const Duration _pingInterval = Duration(seconds: 20);
  static const Duration _staleThreshold = Duration(seconds: 60);
  static const Duration _minBackoff = Duration(milliseconds: 500);
  static const Duration _maxBackoff = Duration(seconds: 30);

  /// Fires when the engine signals `{type:'symbols.changed'}` — downstream
  /// code must drop its symbol-details cache and refetch.
  final RxInt symbolsChangedTick = 0.obs;

  // Per-channel broadcast streams. Payload is whatever the server sent after
  // the channel tag — a list for binary frames, or the full JSON map for
  // control frames routed by `type`.
  final StreamController<dynamic> _pricesCtrl =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> _positionsCtrl =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> _ordersCtrl =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> _accountsCtrl =
      StreamController<dynamic>.broadcast();
  final StreamController<Map<String, dynamic>> _controlCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<dynamic> get prices => _pricesCtrl.stream;
  Stream<dynamic> get positions => _positionsCtrl.stream;
  Stream<dynamic> get orders => _ordersCtrl.stream;
  Stream<dynamic> get accounts => _accountsCtrl.stream;
  Stream<Map<String, dynamic>> get control => _controlCtrl.stream;

  Worker? _accountWorker;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _bindAccountStream();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Spec §8: on resume from background, if no frame has arrived in a
    // while, force a reconnect — iOS/Android often drop the socket silently.
    if (state == AppLifecycleState.resumed) {
      if (_currentAccount == null) return;
      final sinceLast = DateTime.now().difference(_lastFrameAt);
      if (_channel == null || sinceLast > const Duration(seconds: 10)) {
        if (kDebugMode) {
          debugPrint('StreamWS: resumed after ${sinceLast.inSeconds}s — reconnect');
        }
        _teardown();
        _scheduleReconnect();
      }
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _accountWorker?.dispose();
    _accountWorker = null;
    _teardown();
    _pricesCtrl.close();
    _positionsCtrl.close();
    _ordersCtrl.close();
    _accountsCtrl.close();
    _controlCtrl.close();
    super.onClose();
  }

  /// Watch active MT5 account; (re)connect single socket when it changes.
  /// Also connects immediately if an account is already loaded.
  void _bindAccountStream() {
    try {
      final auth = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      if (auth != null && !auth.isAuthenticated) {
        // Wait until user logs in, then bind.
        Future.delayed(const Duration(seconds: 1), _bindAccountStream);
        return;
      }
      final accountController = Get.isRegistered<AccountController>()
          ? Get.find<AccountController>()
          : null;
      if (accountController == null) {
        Future.delayed(const Duration(seconds: 1), _bindAccountStream);
        return;
      }

      final current = accountController.activeMT5Account;
      if (current != null) {
        // Fire-and-forget; errors are logged inside connect().
        unawaited(connect(account: current));
      }

      _accountWorker?.dispose();
      _accountWorker =
          ever<MT5Account?>(accountController.activeMT5AccountRx, (account) {
        if (account == null) return;
        unawaited(switchAccount(account));
      });
    } catch (e) {
      if (kDebugMode) debugPrint('StreamWS: bind error $e');
    }
  }

  /// Re-attach to the CURRENT `AccountController` after a logout → login
  /// cycle. `AuthController` deletes and recreates `AccountController` on
  /// logout, so the worker bound by `_bindAccountStream()` at app start ends
  /// up pointing at a disposed instance and never fires for the new user.
  /// Call this right after the new `AccountController` is registered.
  void rebindAccount() {
    _manualClose = false;
    _bindAccountStream();
  }

  /// Tear down everything owned by this service without destroying the
  /// singleton. Used on logout so the next login can rebind cleanly.
  Future<void> resetForLogout() async {
    _manualClose = true;
    _accountWorker?.dispose();
    _accountWorker = null;
    _currentAccount = null;
    _symbols.clear();
    _pinnedSymbol = null;
    isAuthenticated.value = false;
    await disconnect();
  }

  /// Opens the single socket for [account] and sends the initial authenticate
  /// frame with [symbols]. Safe to call multiple times — reconnects only when
  /// the bound account changes.
  Future<void> connect({
    required MT5Account account,
    List<String> symbols = const <String>[],
    List<String> channels = const <String>[
      'prices',
      'positions',
      'orders',
      'accounts',
    ],
  }) async {
    final sameAccount =
        _currentAccount?.metaAccountNumber == account.metaAccountNumber;
    if (_channel != null && sameAccount) {
      // Already connected to this account — just reconcile symbols.
      await setSymbols(symbols);
      return;
    }

    await disconnect();
    _manualClose = false;

    _currentAccount = account;
    _channels = channels;
    // Merge: keep any symbols already queued by `addSymbols` before the
    // connect call landed; add the ones explicitly passed in `symbols`.
    _symbols.addAll(
      symbols.map(_normalize).where((s) => s.isNotEmpty),
    );

    final url = WebSocketEndpointHelper.getStreamUrl();
    if (kDebugMode) {
      debugPrint('StreamWS: connecting $url for ${account.metaAccountNumber}');
    }
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    // Stale-socket guard (ws-stream-reference.md §6 engine bug):
    // listeners capture `channel` by closure. If a newer connect replaces
    // `_channel`, this listener must ignore `onError` / `onDone` so the OLD
    // socket's close does not mark the NEW socket as disconnected.
    _sub = channel.stream.listen(
      (msg) {
        if (!identical(channel, _channel)) return;
        _onMessage(msg);
      },
      onError: (Object e) {
        if (!identical(channel, _channel)) return;
        if (kDebugMode) debugPrint('StreamWS: error $e');
        _teardown();
        _scheduleReconnect();
      },
      onDone: () {
        if (!identical(channel, _channel)) return;
        if (kDebugMode) debugPrint('StreamWS: closed');
        _teardown();
        if (!_manualClose) _scheduleReconnect();
      },
    );
    isConnected.value = true;
    _lastFrameAt = DateTime.now();
    _startHeartbeat();

    final token = await SecureStorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) debugPrint('StreamWS: no auth token, aborting handshake');
      return;
    }

    // Inline auth: `channels` + `symbols` in one frame so the engine
    // runs authenticate → stream_subscribe → symbol-subscribe itself
    // (ws-stream-reference.md §2).
    final authPayload = <String, dynamic>{
      'type': 'authenticate',
      'authID': token,
      'trading_account': account.metaAccountNumber,
      'channels': _channels,
      'symbols': _symbols.toList(),
    };
    channel.sink.add(jsonEncode(authPayload));
  }

  /// Add symbols to the active subscription set (delta subscribe).
  ///
  /// Safe to call before the socket is connected — the symbols are queued
  /// and shipped inside the next `authenticate` frame (or flushed as a
  /// `subscribe` frame on reconnect).
  Future<void> addSymbols(List<String> symbols) async {
    final add = symbols
        .map(_normalize)
        .where((s) => s.isNotEmpty && !_symbols.contains(s))
        .toSet();
    if (add.isEmpty) return;
    _symbols.addAll(add);
    if (_channel == null || !isAuthenticated.value) {
      // Not ready yet — _symbols will be sent in the next authenticate frame.
      return;
    }
    _channel!.sink.add(jsonEncode(<String, dynamic>{
      'action': 'subscribe',
      'symbols': add.toList(),
    }));
  }

  /// Remove symbols from the active subscription set.
  Future<void> removeSymbols(List<String> symbols) async {
    final remove = symbols
        .map(_normalize)
        .where(_symbols.contains)
        .toSet();
    if (remove.isEmpty) return;
    _symbols.removeAll(remove);
    if (_channel == null || !isAuthenticated.value) return;
    _channel!.sink.add(jsonEncode(<String, dynamic>{
      'action': 'unsubscribe',
      'symbols': remove.toList(),
    }));
  }

  /// Replace the subscribed symbol set. Sends an unsubscribe for removed
  /// symbols and a subscribe for added ones.
  Future<void> setSymbols(List<String> symbols) async {
    if (_channel == null) return;
    final next = symbols
        .map(_normalize)
        .where((s) => s.isNotEmpty)
        .toSet();
    final toAdd = next.difference(_symbols);
    final toRemove = _symbols.difference(next);

    if (toRemove.isNotEmpty) {
      _channel!.sink.add(jsonEncode(<String, dynamic>{
        'action': 'unsubscribe',
        'symbols': toRemove.toList(),
      }));
    }
    if (toAdd.isNotEmpty) {
      _channel!.sink.add(jsonEncode(<String, dynamic>{
        'action': 'subscribe',
        'symbols': toAdd.toList(),
      }));
    }
    _symbols
      ..clear()
      ..addAll(next);
  }

  /// Send a raw JSON event on the socket (e.g. order placement).
  void sendEvent(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  Future<void> switchAccount(
    MT5Account newAccount, {
    List<String>? filteredSymbols,
  }) async {
    // Spec §6 engine bug workaround: never re-auth on the same socket —
    // old account's price binding sticks. Flow: unsubscribe-old → close →
    // reconnect with new account.
    final seq = ++_switchSeq;
    final old = _currentAccount;
    if (_channel != null && old != null) {
      try {
        _channel!.sink.add(jsonEncode(<String, dynamic>{
          'type': 'unsubscribe',
          'trading_account': old.metaAccountNumber,
        }));
      } catch (_) {}
    }

    // Prefer the caller-supplied filtered list (favorites ∩ new account's
    // symbols + chart-pinned). Fall back to carrying over the previous
    // active set so prices do not go blank during the switch (spec §6).
    final carryOver = (filteredSymbols != null && filteredSymbols.isNotEmpty)
        ? filteredSymbols
        : _symbols.toList();
    if (_pinnedSymbol != null && _pinnedSymbol!.isNotEmpty) {
      if (!carryOver.contains(_pinnedSymbol)) {
        carryOver.add(_pinnedSymbol!);
      }
    }
    _symbols.clear();

    // Bail if a newer switch has started during the await chain.
    if (seq != _switchSeq) return;

    await connect(
      account: newAccount,
      symbols: carryOver,
      channels: _channels,
    );
  }

  /// Pin a symbol (usually the chart's active symbol) so it survives
  /// account switches even if the user removes it from favorites — spec §6.
  void pinSymbol(String? symbol) {
    _pinnedSymbol = symbol == null ? null : _normalize(symbol);
    if (_pinnedSymbol != null && _pinnedSymbol!.isNotEmpty) {
      // Fire-and-forget — safe before auth; queues if not ready.
      unawaited(addSymbols(<String>[_pinnedSymbol!]));
    }
  }

  /// Spec §5: tear down channel subscriptions without closing the socket.
  void tearDownSubscriptions() {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(<String, dynamic>{'type': 'unsubscribe'}));
    } catch (_) {}
  }

  /// Ask the engine to re-send positions/orders/accounts from the given
  /// offset. Mirrors `tradingWebSocket.service.js` chunk_request calls.
  void requestChunk({
    required String dataType, // 'positions' | 'orders' | 'accounts'
    int offset = 0,
    int limit = 100,
  }) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(<String, dynamic>{
      'type': 'chunk_request',
      'data_type': dataType,
      'offset': offset,
      'limit': limit,
    }));
  }

  Future<void> disconnect() async {
    _manualClose = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    isConnected.value = false;
    isAuthenticated.value = false;
  }

  void _teardown() {
    _stopHeartbeat();
    _sub?.cancel();
    _sub = null;
    _channel = null;
    isConnected.value = false;
    isAuthenticated.value = false;
  }

  // ─── Heartbeat ─────────────────────────────────────────────────────────
  void _startHeartbeat() {
    _stopHeartbeat();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_channel == null) return;
      try {
        _channel!.sink.add(jsonEncode(<String, dynamic>{'type': 'ping'}));
      } catch (_) {}
    });
    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_channel == null) return;
      // Mark dead when no frame has arrived for staleThreshold during market
      // hours. Reconnect loop will take over.
      if (DateTime.now().difference(_lastFrameAt) > _staleThreshold) {
        if (kDebugMode) debugPrint('StreamWS: stale — forcing reconnect');
        _teardown();
        if (!_manualClose) _scheduleReconnect();
      }
    });
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _staleTimer?.cancel();
    _staleTimer = null;
  }

  // ─── Reconnect backoff ─────────────────────────────────────────────────
  void _scheduleReconnect() {
    if (_manualClose) return;
    final account = _currentAccount;
    if (account == null) return;
    _reconnectTimer?.cancel();
    final attempt = _reconnectAttempt.clamp(0, 10);
    final delayMs =
        (_minBackoff.inMilliseconds * (1 << attempt)).clamp(
      _minBackoff.inMilliseconds,
      _maxBackoff.inMilliseconds,
    );
    _reconnectAttempt++;
    if (kDebugMode) {
      debugPrint('StreamWS: reconnect in ${delayMs}ms (attempt $attempt)');
    }
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      // _symbols already holds the current set; connect() will merge.
      unawaited(connect(
        account: account,
        symbols: const <String>[],
        channels: _channels,
      ));
    });
  }

  void _onMessage(dynamic message) {
    _lastFrameAt = DateTime.now();
    // Any frame = alive → reset backoff.
    _reconnectAttempt = 0;
    try {
      if (MessagePackDecoder.isBinaryMessage(message)) {
        final bytes = message is Uint8List
            ? message
            : Uint8List.fromList(message as List<int>);
        final decoded = MessagePackDecoder.decodeBinary(bytes);
        if (decoded is List && decoded.isNotEmpty && decoded.first is String) {
          _route(decoded.first as String, decoded.sublist(1));
        }
        return;
      }

      final text = message.toString();
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        _handleControl(decoded);
      } else if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is String) {
        _route(decoded.first as String, decoded.sublist(1));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('StreamWS: onMessage error $e');
    }
  }

  void _handleControl(Map<String, dynamic> decoded) {
    final type = decoded['type']?.toString();
    switch (type) {
      case 'authenticated':
        final ok = decoded['status'] == 'success';
        isAuthenticated.value = ok;
        if (ok && _channel != null && _symbols.isNotEmpty) {
          _channel!.sink.add(jsonEncode(<String, dynamic>{
            'action': 'subscribe',
            'symbols': _symbols.toList(),
          }));
        }
        break;
      case 'pong':
        // Alive already marked by _lastFrameAt above.
        break;
      case 'error':
        if (kDebugMode) debugPrint('StreamWS: engine error $decoded');
        // SYMBOL_NOT_AVAILABLE → drop the symbol from the active set so we
        // do not keep resubscribing it on every reconnect.
        if (decoded['code'] == 'SYMBOL_NOT_AVAILABLE') {
          final sym = decoded['symbol']?.toString();
          if (sym != null) _symbols.remove(_normalize(sym));
        }
        break;
      case 'symbols.changed':
        symbolsChangedTick.value++;
        // Spec §3: drop symbol-details cache and refetch.
        if (Get.isRegistered<InstrumentsController>()) {
          try {
            // ignore: avoid_dynamic_calls
            (Get.find<InstrumentsController>() as dynamic)
                .forceRefreshSymbols();
          } catch (_) {}
        }
        break;
      case 'group_changed':
        // Fresh socket required (ws-stream-reference.md §3).
        Future.delayed(const Duration(milliseconds: 500), () async {
          final account = _currentAccount;
          if (account == null) return;
          _manualClose = false;
          await disconnect();
          _manualClose = false;
          await connect(account: account, channels: _channels);
        });
        break;
      case 'stream_subscribed':
      case 'subscription_updated':
        // Informational — nothing to do.
        break;
    }
    _controlCtrl.add(decoded);
  }

  void _route(String channel, List<dynamic> payload) {
    // Protocol per ws-stream-reference.md §4: binary frames are
    // `[tag, payload]`, where tag is a short string:
    //   'p'   → market-watch price row (`[symbol, bid, ask, ...]`) or list.
    //   'pos' → positions snapshot/delta (same shape as `/ws/op`).
    //   'po'  → pending orders (same shape as `/ws/po`).
    //   'ac'  → account tuple (same shape as `/ws/account`).
    // Long-form names ('prices'/'positions'/'orders'/'accounts') are the
    // JSON `channels` list on authenticate — kept as aliases for safety.
    switch (channel) {
      case 'p':
      case 'prices':
        // Normalize: if a single row (`[symbol, bid, ask, ...]`), wrap it as
        // a one-row list so downstream parsers always see rows[].
        if (payload.isNotEmpty && payload.first is String) {
          _pricesCtrl.add(<dynamic>[payload]);
        } else if (payload.length == 1 && payload.first is List) {
          _pricesCtrl.add(payload.first);
        } else {
          _pricesCtrl.add(payload);
        }
        break;
      case 'pos':
      case 'positions':
        _positionsCtrl.add(payload);
        _forwardToTrading(payload, isOpenPosition: true);
        break;
      case 'po':
      case 'orders':
        _ordersCtrl.add(payload);
        _forwardToTrading(payload, isPendingOrder: true);
        break;
      case 'ac':
      case 'accounts':
        _accountsCtrl.add(payload);
        _forwardToAccount(payload);
        break;
      default:
        _controlCtrl.add(<String, dynamic>{
          'type': 'unknown_channel',
          'channel': channel,
          'payload': payload,
        });
    }
  }

  static String _normalize(String raw) {
    var s = raw.trim();
    if (s.contains('.')) {
      s = s.substring(0, s.lastIndexOf('.'));
    }
    return s.toUpperCase();
  }

  // ─── Bridges to legacy services (reuses their parsers) ─────────────────

  /// Unwrap one-element `[payload]` the demuxer may hand us when the frame
  /// shape was `['pos', <payload>]` → sublist(1) = `[<payload>]`.
  dynamic _unwrap(List<dynamic> payload) {
    if (payload.length == 1) return payload.first;
    return payload;
  }

  void _forwardToTrading(
    List<dynamic> payload, {
    bool isOpenPosition = false,
    bool isPendingOrder = false,
  }) {
    if (!Get.isRegistered<TradingWebSocketService>()) return;
    try {
      Get.find<TradingWebSocketService>().handleStreamFrame(
        _unwrap(payload),
        isOpenPositionChannel: isOpenPosition,
        isPendingOrderChannel: isPendingOrder,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('StreamWS: forwardToTrading error $e');
    }
  }

  void _forwardToAccount(List<dynamic> payload) {
    if (!Get.isRegistered<AccountWebSocketService>()) return;
    try {
      // Legacy /ws/account parser expects either a single `[tag, acct, ...]`
      // row OR a batch `[[tag,...], [tag,...]]`. Our stream strips the tag,
      // so re-prepend 'ac' for compatibility.
      final inner = _unwrap(payload);
      dynamic reshaped;
      if (inner is List && inner.isNotEmpty && inner.first is List) {
        // Batch of account rows → prepend 'ac' to each.
        reshaped = inner
            .map((row) => row is List ? <dynamic>['ac', ...row] : row)
            .toList();
      } else if (inner is List) {
        reshaped = <dynamic>['ac', ...inner];
      } else {
        reshaped = inner;
      }
      Get.find<AccountWebSocketService>().handleStreamFrame(reshaped);
    } catch (e) {
      if (kDebugMode) debugPrint('StreamWS: forwardToAccount error $e');
    }
  }
}
