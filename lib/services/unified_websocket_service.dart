import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';

enum WebSocketChannelType {
  marketWatch,
  symbols,
  openPositions,
  pendingOrders,
  account,
  dashboard, // alias for account data feed
  instruments, // alias for market watch feed
  chart, // alias for symbols feed
}

/// Centralized WebSocket manager.
/// Maintains separate channels per type and exposes broadcast streams.
class UnifiedWebSocketService extends GetxService {
  // Connection flags
  final RxBool isMarketWatchConnected = false.obs;
  final RxBool isSymbolsConnected = false.obs;
  final RxBool isOpenPositionsConnected = false.obs;
  final RxBool isPendingOrdersConnected = false.obs;
  final RxBool isAccountConnected = false.obs;

  // Channels
  WebSocketChannel? _marketWatchChannel;
  WebSocketChannel? _symbolsChannel;
  WebSocketChannel? _opChannel;
  WebSocketChannel? _poChannel;
  WebSocketChannel? _accountChannel;

  // Streams
  final _marketWatchCtrl = StreamController<dynamic>.broadcast();
  final _symbolsCtrl = StreamController<dynamic>.broadcast();
  final _opCtrl = StreamController<dynamic>.broadcast();
  final _poCtrl = StreamController<dynamic>.broadcast();
  final _accountCtrl = StreamController<dynamic>.broadcast();

  // Subscriptions
  StreamSubscription? _mwSub;
  StreamSubscription? _symSub;
  StreamSubscription? _opSub;
  StreamSubscription? _poSub;
  StreamSubscription? _accSub;

  MT5Account? _currentAccount;

  @override
  void onClose() {
    _disposeAll();
    super.onClose();
  }

  // Public streams
  Stream<dynamic> marketWatchStream() => _marketWatchCtrl.stream;
  Stream<dynamic> symbolsStream() => _symbolsCtrl.stream;
  Stream<dynamic> openPositionsStream() => _opCtrl.stream;
  Stream<dynamic> pendingOrdersStream() => _poCtrl.stream;
  Stream<dynamic> accountStream() => _accountCtrl.stream;

  /// Ensure a channel is connected for the provided account.
  Future<void> ensureConnected(
    WebSocketChannelType type,
    MT5Account? account,
  ) async {
    // Pippro / pipze use the single multiplexed `/ws/stream` socket via
    // `StreamWebSocketService`. Skip the legacy per-channel sockets so we
    // don't open duplicate connections for the same data.
    if (FlavorConfig.usesSingleStreamSocket) return;
    _currentAccount = account ?? _currentAccount;
    switch (type) {
      case WebSocketChannelType.marketWatch:
      case WebSocketChannelType.instruments:
        if (!isMarketWatchConnected.value) {
          await _connectMarketWatch();
        }
        break;
      case WebSocketChannelType.symbols:
      case WebSocketChannelType.chart:
        if (!isSymbolsConnected.value) {
          await _connectSymbols();
        }
        break;
      case WebSocketChannelType.openPositions:
        if (!isOpenPositionsConnected.value) {
          await _connectOpenPositions();
        }
        break;
      case WebSocketChannelType.pendingOrders:
        if (!isPendingOrdersConnected.value) {
          await _connectPendingOrders();
        }
        break;
      case WebSocketChannelType.account:
      case WebSocketChannelType.dashboard:
        if (!isAccountConnected.value) {
          await _connectAccount();
        }
        break;
    }
  }

  Future<void> switchAccount(MT5Account newAccount) async {
    // Pippro / pipze: single-socket path handles switches via
    // `StreamWebSocketService.switchAccount`.
    if (FlavorConfig.usesSingleStreamSocket) {
      _currentAccount = newAccount;
      return;
    }
    print(
      '═══════════════════════════════════════════════════════════',
    );
    print(
      '🔄 UNIFIED WEBSOCKET: Switching Account',
    );
    print(
      '   From: ${_currentAccount?.metaAccountNumber ?? "N/A"}',
    );
    print(
      '   To:   ${newAccount.metaAccountNumber}',
    );
    print(
      '═══════════════════════════════════════════════════════════',
    );
    
    // ✅ STEP 1: Unsubscribe from all channels first
    print('   STEP 1: Unsubscribing from all channels...');
    await _unsubscribeAllChannels();
    
    // ✅ STEP 2: Wait for unsubscribe to complete
    await Future.delayed(const Duration(milliseconds: 50));
    
    // ✅ STEP 3: Close all connections
    print('   STEP 2: Closing all connections...');
    await _closeAllConnections();
    
    // ✅ STEP 4: Wait for clean disconnect
    await Future.delayed(const Duration(milliseconds: 50));
    
    // ✅ STEP 5: Update current account
    _currentAccount = newAccount;
    print('   STEP 3: Account updated in unified service');
    
    // ✅ STEP 6: Reconnect all channels with new account
    print('   STEP 4: Reconnecting all channels with new account...');
    await _connectAllChannels();
    
    print(
      '✅ UNIFIED WEBSOCKET: Account switched successfully',
    );
  }

  Future<void> _connectAllChannels() async {
    await Future.wait([
      _connectMarketWatch(),
      _connectSymbols(),
      _connectOpenPositions(),
      _connectPendingOrders(),
      _connectAccount(),
    ]);
  }

  Future<void> _connectMarketWatch() async {
    if (_marketWatchChannel != null) return;
    final url = WebSocketEndpointHelper.getMarketWatchUrl(_currentAccount);
    _marketWatchChannel = WebSocketChannel.connect(Uri.parse(url));
    _mwSub = _marketWatchChannel!.stream.listen(
      _marketWatchCtrl.add,
      onDone: () => isMarketWatchConnected.value = false,
      onError: (_) => isMarketWatchConnected.value = false,
    );
    isMarketWatchConnected.value = true;
  }

  Future<void> _connectSymbols() async {
    if (_symbolsChannel != null) return;
    final url = WebSocketEndpointHelper.getSymbolUrl(_currentAccount);
    _symbolsChannel = WebSocketChannel.connect(Uri.parse(url));
    _symSub = _symbolsChannel!.stream.listen(
      _symbolsCtrl.add,
      onDone: () => isSymbolsConnected.value = false,
      onError: (_) => isSymbolsConnected.value = false,
    );
    isSymbolsConnected.value = true;
  }

  Future<void> _connectOpenPositions() async {
    if (_opChannel != null) return;
    final url = WebSocketEndpointHelper.getOpenPositionsUrl(_currentAccount);
    _opChannel = WebSocketChannel.connect(Uri.parse(url));
    _opSub = _opChannel!.stream.listen(
      _opCtrl.add,
      onDone: () => isOpenPositionsConnected.value = false,
      onError: (_) => isOpenPositionsConnected.value = false,
    );
    isOpenPositionsConnected.value = true;
  }

  Future<void> _connectPendingOrders() async {
    if (_poChannel != null) return;
    final url = WebSocketEndpointHelper.getPendingOrdersUrl(_currentAccount);
    _poChannel = WebSocketChannel.connect(Uri.parse(url));
    _poSub = _poChannel!.stream.listen(
      _poCtrl.add,
      onDone: () => isPendingOrdersConnected.value = false,
      onError: (_) => isPendingOrdersConnected.value = false,
    );
    isPendingOrdersConnected.value = true;
  }

  Future<void> _connectAccount() async {
    if (_accountChannel != null) return;
    final url = WebSocketEndpointHelper.getAccountUrl(_currentAccount);
    _accountChannel = WebSocketChannel.connect(Uri.parse(url));
    _accSub = _accountChannel!.stream.listen(
      _accountCtrl.add,
      onDone: () => isAccountConnected.value = false,
      onError: (_) => isAccountConnected.value = false,
    );
    isAccountConnected.value = true;
  }

  Future<void> _unsubscribeAllChannels() async {
    // Best-effort unsubscribe messages
    final authId = await SecureStorageService.getAuthToken();
    final accountNumber = _currentAccount?.metaAccountNumber ?? '';
    final payload = {
      "type": "unsubscribe",
      if (authId != null) "authID": authId,
      if (accountNumber.isNotEmpty) "trading_account": accountNumber,
    };
    await sendEvent(WebSocketChannelType.marketWatch, payload);
    await sendEvent(WebSocketChannelType.symbols, payload);
    await sendEvent(WebSocketChannelType.openPositions, payload);
    await sendEvent(WebSocketChannelType.pendingOrders, payload);
    await sendEvent(WebSocketChannelType.account, payload);
  }

  Future<void> _closeAllConnections() async {
    await Future.wait([
      _closeChannel(WebSocketChannelType.marketWatch),
      _closeChannel(WebSocketChannelType.symbols),
      _closeChannel(WebSocketChannelType.openPositions),
      _closeChannel(WebSocketChannelType.pendingOrders),
      _closeChannel(WebSocketChannelType.account),
    ]);
  }

  Future<void> _closeChannel(WebSocketChannelType type) async {
    try {
      switch (type) {
        case WebSocketChannelType.marketWatch:
        case WebSocketChannelType.instruments:
          await _mwSub?.cancel();
          _mwSub = null;
          await _marketWatchChannel?.sink.close();
          _marketWatchChannel = null;
          isMarketWatchConnected.value = false;
          break;
        case WebSocketChannelType.symbols:
        case WebSocketChannelType.chart:
          await _symSub?.cancel();
          _symSub = null;
          await _symbolsChannel?.sink.close();
          _symbolsChannel = null;
          isSymbolsConnected.value = false;
          break;
        case WebSocketChannelType.openPositions:
          await _opSub?.cancel();
          _opSub = null;
          await _opChannel?.sink.close();
          _opChannel = null;
          isOpenPositionsConnected.value = false;
          break;
        case WebSocketChannelType.pendingOrders:
          await _poSub?.cancel();
          _poSub = null;
          await _poChannel?.sink.close();
          _poChannel = null;
          isPendingOrdersConnected.value = false;
          break;
        case WebSocketChannelType.account:
        case WebSocketChannelType.dashboard:
          await _accSub?.cancel();
          _accSub = null;
          await _accountChannel?.sink.close();
          _accountChannel = null;
          isAccountConnected.value = false;
          break;
      }
    } catch (_) {}
  }

  Future<void> sendEvent(
    WebSocketChannelType type,
    Map<String, dynamic> payload,
  ) async {
    final event = jsonEncode(payload);
    switch (type) {
      case WebSocketChannelType.marketWatch:
      case WebSocketChannelType.instruments:
        _marketWatchChannel?.sink.add(event);
        break;
      case WebSocketChannelType.symbols:
      case WebSocketChannelType.chart:
        _symbolsChannel?.sink.add(event);
        break;
      case WebSocketChannelType.openPositions:
        _opChannel?.sink.add(event);
        break;
      case WebSocketChannelType.pendingOrders:
        _poChannel?.sink.add(event);
        break;
      case WebSocketChannelType.account:
      case WebSocketChannelType.dashboard:
        _accountChannel?.sink.add(event);
        break;
    }
  }

  void disconnectAll() {
    print('🔄 UNIFIED WEBSOCKET: Disconnecting all channels');
    _mwSub?.cancel();
    _symSub?.cancel();
    _opSub?.cancel();
    _poSub?.cancel();
    _accSub?.cancel();
    _mwSub = _symSub = _opSub = _poSub = _accSub = null;

    try { _marketWatchChannel?.sink.close(); } catch (_) {}
    try { _symbolsChannel?.sink.close(); } catch (_) {}
    try { _opChannel?.sink.close(); } catch (_) {}
    try { _poChannel?.sink.close(); } catch (_) {}
    try { _accountChannel?.sink.close(); } catch (_) {}
    _marketWatchChannel = _symbolsChannel = _opChannel = _poChannel = _accountChannel = null;

    isMarketWatchConnected.value = false;
    isSymbolsConnected.value = false;
    isOpenPositionsConnected.value = false;
    isPendingOrdersConnected.value = false;
    isAccountConnected.value = false;
  }

  void _disposeAll() {
    _mwSub?.cancel();
    _symSub?.cancel();
    _opSub?.cancel();
    _poSub?.cancel();
    _accSub?.cancel();
    _marketWatchChannel?.sink.close();
    _symbolsChannel?.sink.close();
    _opChannel?.sink.close();
    _poChannel?.sink.close();
    _accountChannel?.sink.close();
    _marketWatchCtrl.close();
    _symbolsCtrl.close();
    _opCtrl.close();
    _poCtrl.close();
    _accountCtrl.close();
  }
}
