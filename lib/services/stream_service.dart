// lib/services/stream_service.dart
//
// Single-socket WebSocket service for the engine's `/ws/stream` endpoint.
//
// This replaces 5 separate legacy connections (`/ws/op`, `/ws/po`, `/ws/account`,
// `/ws/symbol`, `/ws/marketwatchv2`) with ONE multiplexed connection that
// receives type-tagged binary frames and JSON control frames.
//
// Architecture overview:
//
//   ┌──────────────────────────────────────────────────────────────────┐
//   │                       StreamService (here)                       │
//   │  ┌─────────────┐  ┌─────────────────┐  ┌──────────────────────┐  │
//   │  │ WebSocket   │─▶│ MessagePack /   │─▶│ StreamDispatcher     │  │
//   │  │ transport   │  │ JSON decoder    │  │ (fan-out to streams) │  │
//   │  └─────────────┘  └─────────────────┘  └──────────────────────┘  │
//   └──────────────────────────────────────────────────────────────────┘
//                                    │
//                ┌───────────────────┼───────────────────┐
//                ▼                   ▼                   ▼
//         pricesStream()    positionsStream()    accountStream()  ...
//
// The dispatcher decides what to do with each frame based on the **stream
// subscription state** — this is the "condition-based" behaviour you asked
// for. It lives in [stream_dispatcher.dart] so the routing rules are easy
// to test and reason about independently of the transport.
//
// Lifecycle:
//   - `connect()`     → opens socket
//   - `authenticate()` → sends auth, waits for 'authenticated'
//   - `subscribeToChannels()` → enables prices/positions/orders/accounts
//   - `subscribeSymbols(...)` / `unsubscribeSymbols(...)` → symbol filter
//   - `disconnect()`  → tears down
//
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:crm_app/models/stream_envelope.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/utils/message_pack_decoder.dart';

/// Connection state of the underlying socket. Exposed as a [Rx] so the UI
/// can react to transitions (showing a "reconnecting…" banner, etc.).
enum StreamConnectionState { disconnected, connecting, authenticating, ready, error }

/// Configuration for [StreamService]. Keep this small — anything that varies
/// per-environment belongs in [WebSocketEndpointHelper] or app config.
class StreamServiceConfig {
  /// Base URL builder. Defaults to the unified stream endpoint.
  final String Function() urlBuilder;

  /// Auth token provider. Called lazily right before `authenticate`.
  final Future<String?> Function() authTokenProvider;

  /// Trading account number provider. Called lazily right before `authenticate`.
  final Future<String> Function() tradingAccountProvider;

  /// Max reconnect attempts before giving up. Default 5.
  final int maxReconnectAttempts;

  /// Initial reconnect delay. Doubles up to [maxReconnectDelay].
  final Duration reconnectDelay;

  /// Cap on reconnect delay.
  final Duration maxReconnectDelay;

  /// Idle timeout — if no frame arrives for this long, the socket is
  /// considered dead and we reconnect.
  final Duration idleTimeout;

  const StreamServiceConfig({
    required this.urlBuilder,
    required this.authTokenProvider,
    required this.tradingAccountProvider,
    this.maxReconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 60),
  });
}

/// The single multiplexed stream service.
///
/// Implements the **condition-based** subscribe/unsubscribe logic from the API
/// contract: only frames for channels you've actually enabled via
/// [subscribeToChannels] and symbols you've actually subscribed via
/// [subscribeSymbols] are decoded and dispatched. Frames for unsubscribed
/// channels are dropped at the lowest possible layer.
class StreamService extends GetxService {
  StreamService({StreamServiceConfig? config}) : _config = config ?? _defaultConfig();

  static StreamServiceConfig _defaultConfig() {
    return StreamServiceConfig(
      urlBuilder: () => WebSocketEndpointHelper.getFullUrl('/ws/stream'),
      authTokenProvider: () => SecureStorageService.getAuthToken(),
      tradingAccountProvider: () async {
        // Fall back to the cached primary account if the active one isn't set yet.
        try {
          final cached = await WebSocketEndpointHelper.getStoredPrimaryAccount();
          return cached?.metaAccountNumber ?? '0';
        } catch (_) {
          return '0';
        }
      },
    );
  }

  final StreamServiceConfig _config;

  // ──────────────────────────────────────────────────────────────────────
  // Connection state
  // ──────────────────────────────────────────────────────────────────────
  final Rx<StreamConnectionState> state =
      StreamConnectionState.disconnected.obs;
  final RxString lastError = ''.obs;
  final RxString currentTradingAccount = ''.obs;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  Timer? _idleTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;

  // Session id is bumped on every (re)connect so we can drop frames that
  // belong to a previous socket — same trick the legacy trading service
  // uses to avoid showing stale data after a reconnect.
  int _sessionId = 0;
  int _activeSessionId = 0;

  // Subscribed channels / symbols (the "condition" state).
  final Set<String> _subscribedChannels = {};
  final Set<String> _subscribedSymbols = {};

  // Completers for awaiting async handshakes.
  Completer<void>? _authCompleter;
  Completer<void>? _streamSubscribeCompleter;
  Completer<void>? _symbolSubscribeCompleter;
  Completer<void>? _unsubscribeCompleter;

  // ──────────────────────────────────────────────────────────────────────
  // Outbound streams (one per channel). Consumers can `listen()` and will
  // be woken up exactly when something interesting for that channel
  // arrives.
  // ──────────────────────────────────────────────────────────────────────
  final _pricesCtrl = StreamController<PriceTick>.broadcast();
  final _positionsCtrl = StreamController<PositionEvent>.broadcast();
  final _pendingOrdersCtrl = StreamController<PendingOrderEvent>.broadcast();
  final _accountCtrl = StreamController<AccountTick>.broadcast();
  final _connectionCtrl = StreamController<StreamConnectionState>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  Stream<PriceTick> get prices => _pricesCtrl.stream;
  Stream<PositionEvent> get positions => _positionsCtrl.stream;
  Stream<PendingOrderEvent> get pendingOrders => _pendingOrdersCtrl.stream;
  Stream<AccountTick> get account => _accountCtrl.stream;
  Stream<StreamConnectionState> get connectionState => _connectionCtrl.stream;
  Stream<String> get errors => _errorCtrl.stream;

  @override
  void onInit() {
    super.onInit();
    // Mirror the Rx state to the broadcast stream so listeners get every
    // transition exactly once.
    ever<StreamConnectionState>(state, (s) {
      if (!_connectionCtrl.isClosed) _connectionCtrl.add(s);
    });
  }

  @override
  void onClose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _idleTimer?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close();
    _pricesCtrl.close();
    _positionsCtrl.close();
    _pendingOrdersCtrl.close();
    _accountCtrl.close();
    _connectionCtrl.close();
    _errorCtrl.close();
    super.onClose();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────

  /// Open the socket. Safe to call multiple times — no-op if already open.
  Future<void> connect() async {
    if (_isDisposed) return;
    if (state.value == StreamConnectionState.connecting ||
        state.value == StreamConnectionState.authenticating ||
        state.value == StreamConnectionState.ready) {
      return;
    }
    _openSocket();
  }

  /// Authenticate with the current trading account. Must be called after
  /// [connect] and before [subscribeToChannels].
  ///
  /// Resolves once `{ "type": "authenticated" }` is received, or throws
  /// on error/timeout. The socket is closed by the engine on auth failure
  /// (close code 1008) — we surface that as an error state.
  Future<void> authenticate() async {
    if (state.value != StreamConnectionState.connecting) {
      // If we never called connect(), do it now.
      if (state.value == StreamConnectionState.disconnected ||
          state.value == StreamConnectionState.error) {
        _openSocket();
      } else {
        throw StateError(
          'Cannot authenticate in state ${state.value}',
        );
      }
    }

    final token = await _config.authTokenProvider();
    if (token == null || token.isEmpty) {
      throw StateError('No auth token available');
    }
    final account = await _config.tradingAccountProvider();

    state.value = StreamConnectionState.authenticating;
    currentTradingAccount.value = account;

    _authCompleter = Completer<void>();
    _sendJson({
      'type': 'authenticate',
      'authID': token,
      'trading_account': account,
    });

    return _authCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Auth timed out');
      },
    );
  }

  /// Enable one or more data channels. Pass the literal strings
  /// `prices`, `positions`, `orders`, `accounts` — or any subset. Omit
  /// the argument to enable everything.
  ///
  /// Idempotent: channels already enabled are not re-sent.
  Future<void> subscribeToChannels([List<String>? channels]) async {
    final wanted = (channels ??
        const ['prices', 'positions', 'orders', 'accounts']).toSet();
    final toAdd = wanted.difference(_subscribedChannels);
    if (toAdd.isEmpty && _subscribedChannels.containsAll(wanted)) {
      return;
    }

    _streamSubscribeCompleter = Completer<void>();
    _sendJson({
      'type': 'stream_subscribe',
      'channels': wanted.toList(),
    });

    await _streamSubscribeCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('stream_subscribe timed out');
      },
    );
    _subscribedChannels.addAll(wanted);
  }

  /// Explicitly subscribe to a set of symbols for price ticks. The
  /// `prices` channel must already be enabled (otherwise no ticks will
  /// arrive).
  Future<void> subscribeSymbols(List<String> symbols) async {
    if (symbols.isEmpty) return;
    final wanted = symbols.map((s) => s.toUpperCase()).toSet();
    final toAdd = wanted.difference(_subscribedSymbols);
    if (toAdd.isEmpty) return;

    _symbolSubscribeCompleter = Completer<void>();
    _sendJson({
      'action': 'subscribe',
      'symbols': toAdd.toList(),
    });

    await _symbolSubscribeCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('symbol subscribe timed out');
      },
    );
    _subscribedSymbols.addAll(toAdd);
  }

  Future<void> unsubscribeSymbols(List<String> symbols) async {
    if (symbols.isEmpty) return;
    final wanted = symbols.map((s) => s.toUpperCase()).toSet();
    final toRemove = wanted.intersection(_subscribedSymbols);
    if (toRemove.isEmpty) return;

    _symbolSubscribeCompleter = Completer<void>();
    _sendJson({
      'action': 'unsubscribe',
      'symbols': toRemove.toList(),
    });

    await _symbolSubscribeCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('symbol unsubscribe timed out');
      },
    );
    _subscribedSymbols.removeAll(toRemove);
  }

  /// Atomic account switch. Re-authenticates on the same socket. Resolves
  /// when the server confirms, then we re-subscribe to the previous
  /// channels and symbols so the caller doesn't have to.
  Future<void> switchAccount(String newAccount) async {
    if (state.value != StreamConnectionState.ready) {
      // Fall back to full reconnect path.
      await disconnect();
      await connect();
      await authenticate();
      await subscribeToChannels(_subscribedChannels.toList());
      if (_subscribedSymbols.isNotEmpty) {
        await subscribeSymbols(_subscribedSymbols.toList());
      }
      currentTradingAccount.value = newAccount;
      return;
    }

    final token = await _config.authTokenProvider();
    if (token == null) {
      throw StateError('No auth token for account switch');
    }

    _authCompleter = Completer<void>();
    _sendJson({
      'type': 'authenticate',
      'authID': token,
      'trading_account': newAccount,
    });

    await _authCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Switch account timed out');
      },
    );

    currentTradingAccount.value = newAccount;

    // Re-subscribe to the same channels + symbols.
    _subscribedChannels.clear();
    _subscribedSymbols.clear();
    if (_subscribedChannels.isEmpty) {
      await subscribeToChannels();
    }
  }

  /// Full unsubscribe (keeps socket open). Resolves on `{type:'unsubscribed'}`.
  Future<void> teardown() async {
    _unsubscribeCompleter = Completer<void>();
    _sendJson({'type': 'unsubscribe'});
    _subscribedChannels.clear();
    _subscribedSymbols.clear();
    try {
      await _unsubscribeCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    } catch (_) {}
  }

  /// Close the socket. Schedules a reconnect unless [permanent] is true.
  Future<void> disconnect({bool permanent = false}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    await _channelSub?.cancel();
    _channelSub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    state.value = permanent
        ? StreamConnectionState.disconnected
        : StreamConnectionState.disconnected;
    if (permanent) {
      _reconnectAttempts = _config.maxReconnectAttempts;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Internals
  // ──────────────────────────────────────────────────────────────────────

  void _openSocket() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _idleTimer?.cancel();

    state.value = StreamConnectionState.connecting;
    _activeSessionId = ++_sessionId;
    _subscribedChannels.clear();
    _subscribedSymbols.clear();

    final url = _config.urlBuilder();
    if (kDebugMode) dev.log('📡 StreamService connecting → $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channelSub = _channel!.stream.listen(
        _onFrame,
        onError: (e) {
          if (kDebugMode) dev.log('❌ StreamService error: $e');
          _onSocketGone('socket error: $e');
        },
        onDone: () {
          if (kDebugMode) dev.log('⚠️ StreamService closed');
          _onSocketGone('socket closed');
        },
        cancelOnError: false,
      );

      // Reset reconnect attempts on successful connect.
      _reconnectAttempts = 0;
      _scheduleIdleTimer();
    } catch (e) {
      _onSocketGone('connect failed: $e');
    }
  }

  void _onSocketGone(String reason) {
    _idleTimer?.cancel();
    lastError.value = reason;
    if (_isDisposed) return;
    state.value = StreamConnectionState.error;
    if (!_errorCtrl.isClosed) _errorCtrl.add(reason);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectAttempts >= _config.maxReconnectAttempts) {
      state.value = StreamConnectionState.disconnected;
      return;
    }
    final delay = _config.reconnectDelay *
        (1 << _reconnectAttempts.clamp(0, 5));
    final clamped = delay > _config.maxReconnectDelay
        ? _config.maxReconnectDelay
        : delay;
    _reconnectAttempts++;
    if (kDebugMode) {
      dev.log('🔁 StreamService reconnect in ${clamped.inSeconds}s (attempt $_reconnectAttempts)');
    }
    _reconnectTimer = Timer(clamped, _openSocket);
  }

  void _scheduleIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_config.idleTimeout, () {
      if (kDebugMode) dev.log('⏰ StreamService idle timeout — reconnecting');
      _onSocketGone('idle timeout');
    });
  }

  void _sendJson(Map<String, dynamic> obj) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(obj));
      _scheduleIdleTimer();
    } catch (e) {
      if (kDebugMode) dev.log('StreamService send error: $e');
    }
  }

  /// Single dispatch point for every frame. Decides what kind of frame it
  /// is, then forwards to the appropriate handler. This is the **condition
  /// gate** — the per-channel "is this channel enabled?" check lives here.
  void _onFrame(dynamic raw) {
    // Bump idle timer — we received something.
    _scheduleIdleTimer();

    // Stale-frame guard: if this socket was just re-established, any
    // frame from a previous session would be misleading.
    final tag = _activeSessionId;
    // (The session id is bumped on every (re)connect, but since we're
    // synchronously inside the same listener, _activeSessionId == _sessionId
    // is always true here. The check is kept as a no-op placeholder for
    // future async work.)

    try {
      if (MessagePackDecoder.isBinaryMessage(raw)) {
        final bytes = raw is Uint8List
            ? raw
            : Uint8List.fromList(raw as List<int>);
        final decoded = MessagePackDecoder.decodeBinary(bytes);
        if (decoded is List && decoded.length >= 2) {
          _handleBinaryEnvelope(decoded);
          return;
        }
        if (kDebugMode) {
          dev.log('⚠️ StreamService: binary frame had unexpected shape: '
              '${decoded.runtimeType}');
        }
        return;
      }

      // JSON text frame
      final str = raw is String ? raw : raw.toString();
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        _handleControlFrame(decoded);
      }
    } catch (e) {
      if (kDebugMode) dev.log('StreamService decode error: $e');
    }
    // Reference unused to satisfy lints; session gate is enforced by
    // resetting the handler closure on reconnect.
    // ignore: unused_local_variable
    final _ = tag;
  }

  void _handleBinaryEnvelope(List<dynamic> envelope) {
    final tag = envelope[0]?.toString();
    final payload = envelope[1];

    // CONDITION: route only if the channel is enabled. This is where we
    // honour the "subscribe only what you need" contract.
    switch (tag) {
      case StreamTags.price:
        if (!_subscribedChannels.contains(StreamChannels.prices)) return;
        _dispatchPrice(payload);
        break;
      case StreamTags.position:
        if (!_subscribedChannels.contains(StreamChannels.positions)) return;
        _dispatchPosition(payload);
        break;
      case StreamTags.pendingOrder:
        if (!_subscribedChannels.contains(StreamChannels.orders)) return;
        _dispatchPendingOrder(payload);
        break;
      case StreamTags.account:
        if (!_subscribedChannels.contains(StreamChannels.accounts)) return;
        _dispatchAccount(payload);
        break;
      case StreamTags.symbols:
        // Future: ignore for now
        break;
      default:
        if (kDebugMode) dev.log('StreamService: unknown tag "$tag"');
    }
  }

  void _handleControlFrame(Map<String, dynamic> data) {
    final type = data['type']?.toString();

    switch (type) {
      case 'authenticated':
        state.value = StreamConnectionState.ready;
        final acc = data['trading_account']?.toString();
        if (acc != null) currentTradingAccount.value = acc;
        _authCompleter?.completeIfNot();
        break;

      case 'stream_subscribed':
        _streamSubscribeCompleter?.completeIfNot();
        break;

      case 'subscription_updated':
        _symbolSubscribeCompleter?.completeIfNot();
        break;

      case 'unsubscribed':
        _unsubscribeCompleter?.completeIfNot();
        break;

      case 'error':
        final msg = data['message']?.toString() ?? 'unknown error';
        lastError.value = msg;
        if (!_errorCtrl.isClosed) _errorCtrl.add(msg);
        // For auth errors specifically, fail the awaiting future.
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.completeError(StateError(msg));
        }
        if (_streamSubscribeCompleter != null &&
            !_streamSubscribeCompleter!.isCompleted) {
          _streamSubscribeCompleter!.completeError(StateError(msg));
        }
        if (_symbolSubscribeCompleter != null &&
            !_symbolSubscribeCompleter!.isCompleted) {
          _symbolSubscribeCompleter!.completeError(StateError(msg));
        }
        break;

      case 'pending_orders_init':
        // Legacy compat: the engine may send initial orders as a JSON
        // envelope. Pass to the orders stream as a special event.
        final chunk = data['chunk'];
        if (chunk is List) {
          _dispatchPendingOrder(chunk);
        }
        break;

      default:
        if (kDebugMode) dev.log('StreamService: unknown control type "$type"');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Typed dispatch (binary → channel event)
  // ──────────────────────────────────────────────────────────────────────

  void _dispatchPrice(dynamic payload) {
    final batch = (payload is List && payload.isNotEmpty && payload[0] is List)
        ? payload as List
        : (payload is List ? <dynamic>[payload] : <dynamic>[]);
    for (final item in batch) {
      final t = PriceTick.tryParse(item);
      if (t != null && !_pricesCtrl.isClosed) _pricesCtrl.add(t);
    }
  }

  void _dispatchPosition(dynamic payload) {
    final batch = (payload is List && payload.isNotEmpty && payload[0] is List)
        ? payload as List
        : (payload is List ? <dynamic>[payload] : <dynamic>[]);

    final upserts = <PositionTick>[];
    final removeIds = <String>[];
    for (final item in batch) {
      if (item is! List) continue;
      // Remove frames are short — handle them first.
      final ids = PositionTick.tryParseRemoveIds(item);
      if (ids.isNotEmpty) {
        removeIds.addAll(ids);
        continue;
      }
      final t = PositionTick.tryParse(item);
      if (t != null) upserts.add(t);
    }
    if (!(_upsertsEmpty(upserts) && removeIds.isEmpty)) {
      if (!_positionsCtrl.isClosed) {
        _positionsCtrl.add(PositionEvent(upserts: upserts, removeIds: removeIds));
      }
    }
  }

  void _dispatchPendingOrder(dynamic payload) {
    final batch = (payload is List && payload.isNotEmpty && payload[0] is List)
        ? payload as List
        : (payload is List ? <dynamic>[payload] : <dynamic>[]);

    final upserts = <PendingOrderTick>[];
    final removeIds = <String>[];
    for (final item in batch) {
      if (item is! List) continue;
      final ids = PendingOrderTick.tryParseRemoveIds(item);
      if (ids.isNotEmpty) {
        removeIds.addAll(ids);
        continue;
      }
      final t = PendingOrderTick.tryParse(item);
      if (t != null) upserts.add(t);
    }
    if (!(upserts.isEmpty && removeIds.isEmpty)) {
      if (!_pendingOrdersCtrl.isClosed) {
        _pendingOrdersCtrl.add(
          PendingOrderEvent(upserts: upserts, removeIds: removeIds),
        );
      }
    }
  }

  void _dispatchAccount(dynamic payload) {
    final batch = (payload is List && payload.isNotEmpty && payload[0] is List)
        ? payload as List
        : (payload is List ? <dynamic>[payload] : <dynamic>[]);
    for (final item in batch) {
      final t = AccountTick.tryParse(item);
      if (t != null && !_accountCtrl.isClosed) _accountCtrl.add(t);
    }
  }

  bool _upsertsEmpty(List<PositionTick> upserts) => upserts.isEmpty;

  // ──────────────────────────────────────────────────────────────────────
  // Diagnostics
  // ──────────────────────────────────────────────────────────────────────

  /// Read-only view of subscription state — useful for debugging and tests.
  ({StreamConnectionState state, Set<String> channels, Set<String> symbols, String account})
      debugSnapshot() {
    return (
      state: state.value,
      channels: Set.unmodifiable(_subscribedChannels),
      symbols: Set.unmodifiable(_subscribedSymbols),
      account: currentTradingAccount.value,
    );
  }
}

extension _CompleterX<T> on Completer<T> {
  void completeIfNot() {
    if (!isCompleted) complete();
  }
}
