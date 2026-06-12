// ignore_for_file: avoid_print
//
// UnifiedStreamAdapter
// --------------------
// Condition-based bridge between the new single-stream socket
// (`/ws/stream`, MessagePack binary) and the legacy multi-socket code
// path. The adapter:
//
//   1. Opens one connection via [SingleStreamWebSocketService].
//   2. Demultiplexes the typed streams (prices, positions, orders,
//      accounts) and re-injects them into the legacy consumers'
//      public methods (so existing parsers keep working unchanged).
//   3. Exposes a `useUnified` flag for runtime toggle; when the new
//      socket reports a sustained auth failure the adapter flips the
//      flag off, marks `isFallbackActive`, and the legacy services
//      take over transparently.
//
// Wiring (in `main.dart` GetX bindings):
//
// ```dart
//   final adapter = Get.put(UnifiedStreamAdapter()..init());
//   // Legacy services stay as-is; the adapter re-feeds them.
// ```
//
// The legacy `UnifiedWebSocketService` (5 separate channels) and the
// legacy `AccountWebSocketService` / `TradingWebSocketService` keep
// running as a no-op when the unified stream is healthy — or as the
// real source of data when the unified stream is disabled / falling
// back. The app's UI is unchanged.

import 'dart:async';

import 'package:get/get.dart';

import 'package:crm_app/core/config/app_config_service.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'package:crm_app/services/single_stream_websocket_service.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/utils/app_logger.dart';

class UnifiedStreamAdapter extends GetxService {
  SingleStreamWebSocketService? _stream;
  StreamSubscription<dynamic>? _pricesSub;
  StreamSubscription<dynamic>? _positionsSub;
  StreamSubscription<dynamic>? _ordersSub;
  StreamSubscription<dynamic>? _accountsSub;

  /// Toggleable from runtime. `null` means "follow feature flag".
  final RxnBool overrideUseUnified = RxnBool();

  /// Resolves whether the adapter should drive the new single-socket path.
  /// Priority: explicit override > brand.yaml featureFlags.unifiedStreamSocket
  /// > false (default off so legacy 5-socket path is the safe fallback).
  bool get _useUnified {
    final override = overrideUseUnified.value;
    if (override != null) return override;
    try {
      return Get.find<AppConfigService>().useUnifiedStreamSocket;
    } catch (_) {
      return false;
    }
  }

  bool get useUnified => _useUnified;

  bool get isHealthy =>
      _useUnified && (_stream?.isConnected.value ?? false);

  @override
  void onInit() {
    super.onInit();
    if (_useUnified) _bootstrap();
  }

  @override
  void onClose() {
    _teardown();
    super.onClose();
  }

  /// Initializes the single-stream service and starts re-feeding legacy
  /// consumers. Idempotent.
  Future<void> init() async {
    if (_useUnified) await _bootstrap();
  }

  /// Switch the bound account. Proxies the call to whichever socket
  /// path is currently active.
  Future<void> switchAccount(MT5Account newAccount) async {
    if (_useUnified && _stream != null) {
      await _stream!.switchAccount(newAccount);
    }
    // Legacy services are re-invoked by their own account controller
    // (account_controller.dart) when the active account changes.
  }

  /// Subscribe to one or more symbols for the `prices` stream.
  Future<void> subscribeSymbols(List<String> symbols) async {
    if (_useUnified && _stream != null) {
      await _stream!.subscribeSymbols(symbols);
    }
  }

  Future<void> unsubscribeSymbols(List<String> symbols) async {
    if (_useUnified && _stream != null) {
      await _stream!.unsubscribeSymbols(symbols);
    }
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    _stream ??= Get.put(
      SingleStreamWebSocketService(),
      permanent: true,
    );

    // 1. Wire each typed stream into the legacy services' *public* methods.
    //    The legacy services are unchanged: they keep their own channel
    //    state, but when they receive a "foreign" payload via these
    //    re-injection points, the rest of the code (parsers, controllers,
    //    UI) sees no difference.
    _pricesSub?.cancel();
    _positionsSub?.cancel();
    _ordersSub?.cancel();
    _accountsSub?.cancel();

    _pricesSub = _stream!.pricesStream.listen(_onPrice);
    _positionsSub = _stream!.positionsStream.listen(_onPositions);
    _ordersSub = _stream!.ordersStream.listen(_onOrders);
    _accountsSub = _stream!.accountsStream.listen(_onAccounts);

    // 2. Listen for control events (errors, fallback triggers) to
    //    surface them and possibly fall back to the legacy path.
    _stream!.controlStream.listen(_onControl);

    // 3. Resolve the active account and kick off the connection.
    final account = await WebSocketEndpointHelper.getPrimaryAccount(null);
    if (account == null) {
      AppLogger.warning(
        'UnifiedStreamAdapter: no primary account yet; will connect later',
      );
      return;
    }
    await _stream!.connect(account: account);
  }

  // ─── Re-injection handlers ────────────────────────────────────────────────

  void _onPrice(dynamic payload) {
    // payload: List<List<dynamic>> of normalized ticks.
    // Each tick: [symbol, bid, ask, spreadPoints, digits, dayHigh, dayLow, category]
    // bid/ask are STRINGS per v1.1 spec.
    if (Get.isRegistered<TradingWebSocketService>()) {
      // We do not have a public "inject price" method on the legacy
      // service; the chart controller listens to the unified stream
      // directly via ChartSocketController's `_bindUnifiedSymbol`. So
      // for the price stream we just log here — real consumers wire up
      // to `_stream!.pricesStream` directly when `_useUnified` is on.
    }
    // The Markets/Chart screen already binds to SingleStreamWebSocketService
    // when the feature flag is on. Nothing else to do here.
  }

  void _onPositions(dynamic payload) {
    // payload: legacy-compatible shape (already msgpack-decoded):
    //   - 'op' / 'a' / 'u' / 'r'  (single) or a list of those.
    // We forward to TradingWebSocketService's existing handler so all
    // its batch/duplicate/zombie-filter logic keeps applying. The
    // public surface we use is its `_handleSocketMessage` — but it
    // is private, so we instead expose this via TradingWebSocketService
    // (see injectFromStream below).
    if (Get.isRegistered<TradingWebSocketService>()) {
      Get.find<TradingWebSocketService>().injectFromStream(
        tag: 'pos',
        payload: payload,
      );
    }
  }

  void _onOrders(dynamic payload) {
    if (Get.isRegistered<TradingWebSocketService>()) {
      Get.find<TradingWebSocketService>().injectFromStream(
        tag: 'po',
        payload: payload,
      );
    }
  }

  void _onAccounts(dynamic payload) {
    if (Get.isRegistered<AccountWebSocketService>()) {
      Get.find<AccountWebSocketService>().injectFromStream(payload);
    }
  }

  void _onControl(Map<String, dynamic> frame) {
    final type = frame['type']?.toString();
    if (type == 'error' && _stream?.isFallbackActive.value == true) {
      // Engine keeps closing on auth errors — switch off the new path
      // and let the legacy sockets drive the app from now on.
      AppLogger.error(
        'UnifiedStreamAdapter: server reported persistent auth failure; '
        'disabling unified stream and letting legacy services take over',
      );
      overrideUseUnified.value = false;
      _teardown();
    }
  }

  void _teardown() {
    _pricesSub?.cancel();
    _positionsSub?.cancel();
    _ordersSub?.cancel();
    _accountsSub?.cancel();
    _pricesSub = _positionsSub = _ordersSub = _accountsSub = null;
  }
}
