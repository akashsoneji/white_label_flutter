// ignore_for_file: avoid_print
//
// SingleStreamWebSocketService
// ----------------------------
// One single WebSocket connection to `/ws/stream` (engine v1.1 spec) that
// carries prices, positions, pending orders and account metrics, multiplexed
// over MessagePack binary frames + JSON control messages.
//
// Demux strategy: condition-based routing on the first array element
// (server tag) of each binary envelope `[tag, payload]`:
//   - 'p'   -> prices (marketwatch)  -> pricesStream
//   - 'pos' -> positions             -> positionsStream
//   - 'po'  -> pending orders        -> ordersStream
//   - 'ac'  -> account metrics       -> accountsStream
//
// JSON text control messages:
//   - {type:'authenticated'}        -> mark authenticated, subscribe channels
//   - {type:'stream_subscribed'}    -> ack of stream_subscribe
//   - {type:'subscription_updated'} -> ack of symbol subscribe/unsubscribe
//   - {type:'pending_orders_init'}  -> legacy JSON orders snapshot
//   - {type:'unsubscribed'}         -> teardown ack
//   - {type:'error'}                -> surface to logs, hard-fail on auth
//
// Reconnect: exponential backoff (1s -> 2s -> 4s ... max 30s), re-auth + re-
// stream_subscribe on every reconnect. Resubscribes all symbols that were
// known before the disconnect.
//
// Account switch: in-socket teardown (`{type:'unsubscribe'}`) then
// re-authenticate + re-stream_subscribe (server auto-clears the group).
//

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:crm_app/core/config/app_config_service.dart';
import 'package:crm_app/core/feature_flags/feature_keys.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:crm_app/utils/message_pack_decoder.dart';

/// Condition-based demux key on incoming data frames.
enum _StreamTag {
  prices, // 'p'
  positions, // 'pos'
  orders, // 'po'
  accounts, // 'ac'
  unknown,
}

_StreamTag _tagFromString(String? raw) {
  switch (raw) {
    case 'p':
      return _StreamTag.prices;
    case 'pos':
      return _StreamTag.positions;
    case 'po':
      return _StreamTag.orders;
    case 'ac':
      return _StreamTag.accounts;
    default:
      return _StreamTag.unknown;
  }
}

/// A unified single-stream WebSocket service.
///
/// Public surface is intentionally minimal and condition-based: consumers
/// subscribe to one of the four typed streams, send control messages via
/// the public methods, and let the service handle reconnect, account
/// switch, and demux.
class SingleStreamWebSocketService extends GetxService {
  // ─── Connection state ──────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final RxBool isConnected = false.obs;
  final RxBool isAuthenticating = false.obs;
  final RxBool isAuthenticated = false.obs;
  final RxBool isSubscribed = false.obs; // stream_subscribe ack received
  final RxBool isFallbackActive = false.obs; // legacy multi-socket is in use

  MT5Account? _currentAccount;

  // ─── Reconnect state ───────────────────────────────────────────────────────
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelayMs = 30000;
  int _backoffMs = 1000;
  int _consecutiveAuthFailures = 0;

  // ─── Demux streams ─────────────────────────────────────────────────────────
  final _pricesCtrl = StreamController<dynamic>.broadcast();
  final _positionsCtrl = StreamController<dynamic>.broadcast();
  final _ordersCtrl = StreamController<dynamic>.broadcast();
  final _accountsCtrl = StreamController<dynamic>.broadcast();
  final _controlCtrl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<dynamic> get pricesStream => _pricesCtrl.stream;
  Stream<dynamic> get positionsStream => _positionsCtrl.stream;
  Stream<dynamic> get ordersStream => _ordersCtrl.stream;
  Stream<dynamic> get accountsStream => _accountsCtrl.stream;

  /// All control frames (auth ack, subscribe ack, errors, etc.) — useful
  /// for tests and for advanced consumers (e.g. UI banners).
  Stream<Map<String, dynamic>> get controlStream => _controlCtrl.stream;

  // ─── Symbol subscription tracking ──────────────────────────────────────────
  final Set<String> _subscribedSymbols = <String>{};
  // Per-frame write gate to avoid races while we mutate _subscribedSymbols.
  final _sendLock = _SendLock();

  @override
  void onClose() {
    _shutdown();
    _pricesCtrl.close();
    _positionsCtrl.close();
    _ordersCtrl.close();
    _accountsCtrl.close();
    _controlCtrl.close();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Open (or reuse) the single connection for the given account.
  ///
  /// If a connection is already open for a different account this falls
  /// through to [switchAccount].
  Future<void> connect({MT5Account? account}) async {
    try {
      final enabled = Get.find<AppConfigService>().useUnifiedStreamSocket;
      if (!enabled) {
        isFallbackActive.value = true;
        AppLogger.websocket(
          'SingleStreamWS: disabled by feature flag, signalling fallback to legacy',
        );
        return;
      }
    } catch (_) {
      // AppConfig not available yet; assume enabled for now so it connects if
      // the flag is supposed to be true, otherwise it'll fall back naturally.
    }

    if (account != null) _currentAccount = account;
    if (_currentAccount == null) {
      AppLogger.warning('SingleStreamWS: no account, skipping connect');
      return;
    }

    if (_channel != null) {
      // Already connected. Re-authenticate is the way to switch account
      // in-socket per the v1.1 spec.
      return;
    }

    final token = await SecureStorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      AppLogger.warning('SingleStreamWS: no auth token, skipping connect');
      return;
    }

    final url = WebSocketEndpointHelper.getFullUrl('/ws/stream');
    AppLogger.websocket(
      'SingleStreamWS: connecting $url for ${_currentAccount!.metaAccountNumber}',
    );

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      isConnected.value = true;
      _backoffMs = 1000;

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (err, st) {
          AppLogger.error('SingleStreamWS: stream error', error: err);
          _handleDisconnect();
        },
        onDone: () {
          AppLogger.websocket('SingleStreamWS: stream closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      _authenticate(token);
    } catch (e) {
      AppLogger.error('SingleStreamWS: failed to connect', error: e);
      _handleDisconnect();
    }
  }

  /// Subscribe to a single stream channel. Idempotent server-side.
  void subscribeChannels(List<String> channels) {
    if (!isAuthenticated.value) {
      AppLogger.warning(
        'SingleStreamWS: subscribeChannels before authenticated; deferring',
      );
      _pendingChannelSubscribe = channels;
      return;
    }
    _send({'type': 'stream_subscribe', 'channels': channels});
  }

  /// Subscribe to a list of symbols (prices).
  ///
  /// Server will immediately send a snapshot frame for these symbols
  /// (tag='p') and then start ticking.
  Future<void> subscribeSymbols(List<String> symbols) async {
    if (symbols.isEmpty) return;
    await _sendLock.protect(() async {
      _subscribedSymbols.addAll(symbols);
      if (isAuthenticated.value) {
        _send({'action': 'subscribe', 'symbols': symbols.toList()});
      }
    });
  }

  /// Unsubscribe from a list of symbols.
  Future<void> unsubscribeSymbols(List<String> symbols) async {
    if (symbols.isEmpty) return;
    await _sendLock.protect(() async {
      _subscribedSymbols.removeAll(symbols);
      if (isAuthenticated.value) {
        _send({'action': 'unsubscribe', 'symbols': symbols.toList()});
      }
    });
  }

  /// Request more (paginated) positions / orders / accounts.
  void loadMore(String dataType, int offset, {int limit = 100}) {
    if (!isAuthenticated.value) return;
    _send({
      'type': 'chunk_request',
      'data_type': dataType,
      'offset': offset,
      'limit': limit,
    });
  }

  /// Hard teardown — the socket stays open per spec, but we clear our
  /// server-side subscriptions.
  void teardown() {
    if (isAuthenticated.value) _send({'type': 'unsubscribe'});
    isSubscribed.value = false;
  }

  /// Switch the bound MT5 account.
  ///
  /// Per v1.1 spec we keep the socket open and re-authenticate. The server
  /// auto-clears the previous group.
  Future<void> switchAccount(MT5Account newAccount) async {
    AppLogger.websocket(
      'SingleStreamWS: switching account to ${newAccount.metaAccountNumber}',
    );

    if (_channel == null) {
      _currentAccount = newAccount;
      await connect(account: newAccount);
      return;
    }

    teardown();
    // Tiny delay to let the server apply the unsubscribe.
    await Future.delayed(const Duration(milliseconds: 50));

    _currentAccount = newAccount;
    _subscribedSymbols.clear();
    isAuthenticated.value = false;
    isSubscribed.value = false;

    final token = await SecureStorageService.getAuthToken();
    if (token == null) {
      AppLogger.warning('SingleStreamWS: no token for switchAccount');
      return;
    }
    _authenticate(token);
  }

  /// Force a clean reconnect (used by the lifecycle hooks and the
  /// "reconnect now" debug action).
  Future<void> forceReconnect() async {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    isConnected.value = false;
    isAuthenticating.value = false;
    isAuthenticated.value = false;
    isSubscribed.value = false;
    _reconnectAttempts = 0;
    await Future.delayed(const Duration(milliseconds: 100));
    await connect();
  }

  /// Returns the currently subscribed symbol set (read-only copy).
  Set<String> get subscribedSymbolsSnapshot =>
      Set<String>.unmodifiable(_subscribedSymbols);

  // ─────────────────────────────────────────────────────────────────────────
  // Internal: send / receive
  // ─────────────────────────────────────────────────────────────────────────

  List<String>? _pendingChannelSubscribe;

  void _authenticate(String token) {
    if (_channel == null || _currentAccount == null) return;
    isAuthenticating.value = true;
    _send({
      'type': 'authenticate',
      'authID': token,
      'trading_account': _currentAccount!.metaAccountNumber,
    });
  }

  void _send(Map<String, dynamic> msg) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(msg));
    } catch (e) {
      AppLogger.error('SingleStreamWS: send error', error: e);
    }
  }

  void _onMessage(dynamic message) {
    try {
      if (message is String) {
        _handleJson(message);
      } else if (message is Uint8List || message is List<int>) {
        _handleBinary(
          message is Uint8List
              ? message
              : Uint8List.fromList(message as List<int>),
        );
      } else {
        AppLogger.warning(
          'SingleStreamWS: unhandled message type ${message.runtimeType}',
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'SingleStreamWS: onMessage error',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _handleJson(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      AppLogger.warning('SingleStreamWS: invalid JSON frame: $raw');
      return;
    }

    if (decoded is Map<String, dynamic>) {
      _handleControlFrame(decoded);
      return;
    }

    if (decoded is List && decoded.length >= 2) {
      // JSON-array envelope: [tag, payload] (used by pending_orders_init
      // variants and some legacy compat paths).
      _routePayloadByTag(decoded[0]?.toString(), decoded[1]);
      return;
    }

    AppLogger.warning('SingleStreamWS: unknown JSON shape: $raw');
  }

  void _handleBinary(Uint8List bytes) {
    final decoded = MessagePackDecoder.decodeBinary(bytes);
    if (decoded is! List || decoded.length < 2) {
      AppLogger.warning('SingleStreamWS: bad msgpack envelope');
      return;
    }
    _routePayloadByTag(decoded[0]?.toString(), decoded[1]);
  }

  void _handleControlFrame(Map<String, dynamic> frame) {
    final type = frame['type']?.toString();
    if (!_controlCtrl.isClosed) {
      _controlCtrl.add(frame);
    }

    switch (type) {
      case 'authenticated':
        isAuthenticating.value = false;
        isAuthenticated.value = true;
        _consecutiveAuthFailures = 0;
        AppLogger.websocket('SingleStreamWS: authenticated');

        // Auto-subscribe to all four channels.
        if (_pendingChannelSubscribe != null) {
          _send({
            'type': 'stream_subscribe',
            'channels': _pendingChannelSubscribe,
          });
          _pendingChannelSubscribe = null;
        } else {
          _send({
            'type': 'stream_subscribe',
            'channels': ['prices', 'positions', 'orders', 'accounts'],
          });
        }
        break;

      case 'stream_subscribed':
        isSubscribed.value = true;
        AppLogger.websocket('SingleStreamWS: stream_subscribed');

        // Per v1.1 spec, prices need an explicit symbol subscribe
        // (otherwise no 'p' frames). If a caller subscribed symbols
        // before auth, replay them now.
        if (_subscribedSymbols.isNotEmpty) {
          _send({'action': 'subscribe', 'symbols': _subscribedSymbols.toList()});
        }
        break;

      case 'subscription_updated':
        // ack for symbol subscribe/unsubscribe — no-op beyond logging.
        AppLogger.websocket(
          'SingleStreamWS: subscription_updated ${frame['symbols']} '
          '(action=${frame['action']}, total=${frame['total_subscribed']})',
        );
        break;

      case 'unsubscribed':
        AppLogger.websocket('SingleStreamWS: unsubscribed (in-socket)');
        break;

      case 'pending_orders_init':
        // Some servers send a JSON envelope for the initial pending orders
        // chunk even in the unified stream.
        if (!_ordersCtrl.isClosed) _ordersCtrl.add(frame);
        break;

      case 'error':
        final message = frame['message']?.toString() ?? '';
        AppLogger.error('SingleStreamWS: server error: $message');
        if (message.contains('Authentication failed')) {
          _consecutiveAuthFailures++;
          try {
            _channel?.sink.close;
          } catch (_) {}
          if (_consecutiveAuthFailures >=
              FeatureKeys.unifiedStreamFailureThreshold) {
            isFallbackActive.value = true;
            AppLogger.error(
              'SingleStreamWS: auth failing repeatedly, '
              'flagging legacy fallback (isFallbackActive=true)',
            );
          }
        }
        break;

      default:
        // Unknown / vendor-specific control frame — keep on the bus for
        // consumers but do nothing here.
        break;
    }
  }

  // ─── Demux / condition-based routing ───────────────────────────────────────

  void _routePayloadByTag(String? tag, dynamic payload) {
    final t = _tagFromString(tag);
    switch (t) {
      case _StreamTag.prices:
        if (!_pricesCtrl.isClosed) _pricesCtrl.add(_normalizePrices(payload));
        break;
      case _StreamTag.positions:
        if (!_positionsCtrl.isClosed) _positionsCtrl.add(payload);
        break;
      case _StreamTag.orders:
        if (!_ordersCtrl.isClosed) _ordersCtrl.add(payload);
        break;
      case _StreamTag.accounts:
        if (!_accountsCtrl.isClosed) {
          _accountsCtrl.add(_normalizeAccountPayload(payload));
        }
        break;
      case _StreamTag.unknown:
        AppLogger.warning('SingleStreamWS: unknown tag: $tag');
        break;
    }
  }

  /// Normalize the price payload into a `List<List<dynamic>>` where each
  /// inner list is a single tick. This keeps downstream consumers simple
  /// regardless of whether the server sent a single tick or a batch.
  List<List<dynamic>> _normalizePrices(dynamic payload) {
    if (payload is! List) return <List<dynamic>>[];
    if (payload.isEmpty) return <List<dynamic>>[];

    // Single tick: ['EURUSD', '1.08562', '1.08581', 19, 5, 1.08620, ...]
    if (payload.first is! List) {
      return <List<dynamic>>[List<dynamic>.from(payload)];
    }

    // Batch.
    return (payload as List)
        .whereType<List>()
        .map<List<dynamic>>((e) => List<dynamic>.from(e))
        .toList(growable: false);
  }

  /// Legacy `AccountWebSocketService` / `DashboardController` parsers
  /// expect each account row to begin with the literal `'ac'` marker.
  /// The stream demux hands us the payload after stripping the tag, so we
  /// re-add the marker here when it's missing.
  dynamic _normalizeAccountPayload(dynamic payload) {
    if (payload is! List) return payload;
    if (payload.isEmpty) return payload;

    // Already legacy-compatible: ['ac', account, ...]
    if (payload.first?.toString().toLowerCase() == 'ac') {
      return payload;
    }

    // Multiple rows: [[account, ...], [account, ...]]
    if (payload.first is List) {
      return payload.map((row) {
        if (row is List &&
            row.isNotEmpty &&
            row.first?.toString().toLowerCase() != 'ac') {
          return ['ac', ...row];
        }
        return row;
      }).toList();
    }

    // Single row without marker.
    return ['ac', ...payload];
  }

  // ─── Reconnect ─────────────────────────────────────────────────────────────

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    isConnected.value = false;
    isAuthenticating.value = false;
    isAuthenticated.value = false;
    isSubscribed.value = false;

    try {
      if (!Get.find<AppConfigService>().useUnifiedStreamSocket) {
        // Don't auto-reconnect if feature is off.
        return;
      }
    } catch (_) {
      // If AppConfig isn't up, allow reconnect.
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), () async {
      _reconnectAttempts++;
      _backoffMs = (_backoffMs * 2).clamp(1000, _maxReconnectDelayMs);
      AppLogger.websocket(
        'SingleStreamWS: reconnecting (attempt $_reconnectAttempts)',
      );
      await connect();
    });
  }

  void _shutdown() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    isConnected.value = false;
    isAuthenticating.value = false;
    isAuthenticated.value = false;
    isSubscribed.value = false;
  }
}

/// Minimal cooperative send-lock so two near-simultaneous subscribe/unsubscribe
/// calls don't interleave their messages.
class _SendLock {
  Future<void> _last = Future.value();

  Future<T> protect<T>(Future<T> Function() body) {
    final completer = Completer<T>();
    _last = _last.then((_) async {
      try {
        completer.complete(await body());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
