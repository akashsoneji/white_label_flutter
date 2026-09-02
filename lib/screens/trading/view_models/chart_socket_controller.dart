// lib/controllers/chart_socket_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crm_app/utils/message_pack_decoder.dart';
import 'package:crm_app/services/unified_websocket_service.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/market_watch_v2_service.dart';

class ChartSocketController extends GetxController with WidgetsBindingObserver {
  // Connection state
  final RxBool isConnected = false.obs;
  final RxBool isReconnecting = false.obs;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  bool _isDisposed = false;
  bool _loggedFirstMessage = false;
  late WebSocketChannel channel;
  StreamSubscription? _unifiedSymbolSub;
  StreamSubscription<dynamic>? _marketWatchV2Sub;

  // Unsubscribe/resubscribe state
  Completer<void>? _unsubscribeCompleter;

  // Symbol & data
  final RxString currentSymbol = ''.obs;
  final RxMap<String, dynamic> realTimePrice = <String, dynamic>{}.obs;

  final StreamController<Map<String, dynamic>> _priceStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get priceStream => _priceStreamController.stream;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // Bind currentSymbol to SymbolSelectionService.lastSymbolRx
    final symService = Get.isRegistered<SymbolSelectionService>()
        ? Get.find<SymbolSelectionService>()
        : Get.put(SymbolSelectionService());
    
    // Sync initially
    if (symService.currentSymbol.isNotEmpty) {
      currentSymbol.value = symService.currentSymbol;
    }

    // Listen to changes from SymbolSelectionService to update currentSymbol
    ever(symService.lastSymbolRx, (String sym) {
      if (sym.isNotEmpty && currentSymbol.value != sym) {
        changeSymbol(sym);
      }
    });

    // Listen to changes from currentSymbol (watchlist, selector) to update SymbolSelectionService
    ever(currentSymbol, (String sym) {
      if (sym.isNotEmpty && symService.currentSymbol != sym) {
        symService.setSymbol(sym);
      }
    });

    // DON'T auto-connect - let screen decide when to start
    // Auto-(re)connect + subscribe when symbol changes
    ever<String>(currentSymbol, (sym) async {
      if (sym.isEmpty) return;
      // Only auto-subscribe if already connected
      if (isConnected.value && !_isDisposed) {
        getSocketData();
      }
    });

    _bindMarketWatchV2Listener();

    // ✅ FIX: Listen to account changes and reconnect when needed
    try {
      final accountController = Get.find<AccountController>();
      MT5Account? _lastAccount;

      ever(accountController.activeMT5AccountRx, (MT5Account? account) {
        if (account == null || _isDisposed) return;

        // Check if account changed (different account number or type)
        final accountChanged =
            _lastAccount == null ||
            _lastAccount!.metaAccountNumber != account.metaAccountNumber ||
            (_lastAccount!.tradingServer.toUpperCase() !=
                account.tradingServer.toUpperCase());

        if (accountChanged && currentSymbol.value.isNotEmpty) {
          if (kDebugMode) {
            // dev.log('Chart WS: Account changed, reconnecting...');
            // dev.log(
            //   'Chart WS: Old account: ${_lastAccount?.metaAccountNumber ?? "N/A"} (${_lastAccount?.tradingServer ?? "N/A"})',
            // );
            // dev.log(
            //   'Chart WS: New account: ${account.metaAccountNumber} (${account.tradingServer})',
            // );
          }

          // Check if endpoint needs to change
          final oldEndpoint = _getWebSocketUrl();
          _lastAccount = account;
          final newEndpoint = _getWebSocketUrl();
          final endpointChanged = oldEndpoint != newEndpoint;

          if (kDebugMode) {
            dev.log('Chart WS: Endpoint changed: $endpointChanged');
            dev.log('Chart WS: Old endpoint: $oldEndpoint');
            dev.log('Chart WS: New endpoint: $newEndpoint');
          }

          if (endpointChanged || isConnected.value) {
            // Endpoint changed or already connected - full reconnect
            _disconnectWebSocket();
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!_isDisposed && currentSymbol.value.isNotEmpty) {
                initializeWebSocket();
              }
            });
          } else {
            // Same endpoint, just resubscribe with new account
            if (isConnected.value) {
              getSocketData();
            }
          }
        }

        _lastAccount = account;
      });
    } catch (e) {
      if (kDebugMode) {
        dev.log('Chart WS: Error setting up account listener: $e');
      }
    }
  }

  // Method to start WebSocket when screen becomes visible
  void startWebSocket() async {
    // ✅ FIX: Check authentication before starting WebSocket
    final isLoggedIn = await SecureStorageService.isUserLoggedIn();
    if (!isLoggedIn) {
      if (kDebugMode) {
        // dev.log('Chart WS: User not logged in, skipping WebSocket start');
      }
      return;
    }

    if (currentSymbol.value.isEmpty) {
      if (kDebugMode) {
        // dev.log('Chart WS: Cannot start - no symbol selected');
      }
      return;
    }

    // If user has no MT5 accounts, we still allow symbol WebSocket to run.
    // Trade engine accepts `trading_account: "0"` for read-only symbol pricing.

    if (_bindUnifiedSymbol()) {
      return;
    }

    if (!isConnected.value) {
      initializeWebSocket();
    }
  }

  bool _bindUnifiedSymbol() {
    try {
      final unified = Get.find<UnifiedWebSocketService>();
      MT5Account? account;
      try {
        final accountController = Get.find<AccountController>();
        account = accountController.activeMT5Account;
      } catch (_) {}
      unified.ensureConnected(WebSocketChannelType.symbols, account);
      _unifiedSymbolSub?.cancel();
      _unifiedSymbolSub = unified.symbolsStream().listen(
        (message) => _handleSocketMessage(message),
        onError: (_) => isConnected.value = false,
        onDone: () => isConnected.value = false,
      );
      isConnected.value = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        dev.log('Chart WS: Failed to bind unified symbol stream: $e');
      }
      return false;
    }
  }

  // Method to stop WebSocket when screen is hidden
  void stopWebSocket() {
    resetController();
  }

  @override
  void onClose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _unifiedSymbolSub?.cancel();
    _marketWatchV2Sub?.cancel();
    try {
      if (!_priceStreamController.isClosed) {
        _priceStreamController.close();
      }
    } catch (_) {}
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Account-level lifecycle (account switching) is centrally coordinated
    // by AccountController to prevent race conditions. The cross-app
    // pause/resume case is NOT covered there, though: the OS can silently
    // drop the WebSocket TCP connection when the app is suspended, and
    // on resume the listener stays bound to a dead channel until the
    // user does something that triggers a manual reconnect. We handle
    // that explicitly here, mirroring the fix on InstrumentsController.
    switch (state) {
      case AppLifecycleState.resumed:
        if (kDebugMode) {
          dev.log('ChartSocketController: App resumed — restarting symbol stream');
        }
        _startIdleKeepAlive();
        // Only attempt a restart if we actually have a symbol selected
        // — otherwise startWebSocket() will no-op anyway.
        if (currentSymbol.value.isNotEmpty) {
          Future.microtask(() => handleAppRestart());
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopIdleKeepAlive();
        break;
    }
  }

  // ── Idle keep-alive for chart symbol stream ───────────────────────────
  //
  // The chart socket only carries ticks for ONE symbol (currentSymbol).
  // When the app is idle (no UI interaction, screen off, OS think it's
  // idle), the TCP socket can sit quiet for long enough that intermediate
  // proxies drop the connection. Periodic resubscribe frames keep the
  // server side warm and let us cheaply detect a dead socket.
  Timer? _idleKeepAliveTimer;
  static const Duration _idleKeepAliveInterval = Duration(seconds: 15);
  int _lastTickEpochMs = 0;
  bool _keepAliveRunning = false;

  void _startIdleKeepAlive() {
    if (_keepAliveRunning) return;
    _keepAliveRunning = true;
    _idleKeepAliveTimer?.cancel();
    _idleKeepAliveTimer = Timer.periodic(_idleKeepAliveInterval, (_) async {
      try {
        final isLoggedIn = await SecureStorageService.isUserLoggedIn();
        if (!isLoggedIn) return;
        if (currentSymbol.value.isEmpty) return;
        // If ticks are flowing, skip — server is happily pushing.
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final sinceLastTick = nowMs - _lastTickEpochMs;
        if (isConnected.value &&
            sinceLastTick < _idleKeepAliveInterval.inMilliseconds) {
          return;
        }
        // Force a soft re-subscribe to wake the server up.
        if (isConnected.value) {
          getSocketData();
        } else {
          handleAppRestart();
        }
      } catch (_) {
        // Best-effort — never crash the controller.
      }
    });
  }

  void _stopIdleKeepAlive() {
    _idleKeepAliveTimer?.cancel();
    _idleKeepAliveTimer = null;
    _keepAliveRunning = false;
  }

  /// Call from the price-tick handler to let the keep-alive timer
  /// skip needless resubscribes while the socket is happy.
  void noteTickObserved() {
    _lastTickEpochMs = DateTime.now().millisecondsSinceEpoch;
  }

  // ---------- Public API ----------
  Future<void> initializeSocketForSymbol(String symbol) async {
    if (symbol.isEmpty) return;

    // ✅ FIX: Check authentication before initializing WebSocket
    final isLoggedIn = await SecureStorageService.isUserLoggedIn();
    if (!isLoggedIn) {
      if (kDebugMode) {
        // dev.log('Chart WS: User not logged in, skipping WebSocket initialization');
      }
      return;
    }

    // ✅ FIX: If already connected with same symbol, ensure resubscription
    if (isConnected.value && currentSymbol.value == symbol) {
      getSocketData(); // Resubscribe to same symbol
      return;
    }

    currentSymbol.value = symbol;

    _bindMarketWatchV2Listener();

    // Immediately seed with cached/live price from InstrumentsController so
    // Buy/Sell buttons and chart prices render INSTANTLY without showing '--' or '0.00'
    if (Get.isRegistered<InstrumentsController>()) {
      final inst = Get.find<InstrumentsController>();
      final live = inst.getLivePrice(symbol);
      final match = inst.findInstrument(symbol);
      final bid = (live != null && live.bid > 0) ? live.bid : match?.bid;
      final ask = (live != null && live.ask > 0) ? live.ask : match?.ask;
      final spreadDiff = (live != null && live.spreadDiff > 0) ? live.spreadDiff : match?.spreadDiff;

      if (bid != null && bid > 0) {
        realTimePrice['symbol'] = symbol;
        realTimePrice['bid'] = bid;
        realTimePrice['ask'] = (ask != null && ask > 0) ? ask : bid;
        realTimePrice['spreadDiff'] = spreadDiff ?? 0.0;
        _priceStreamController.add(Map<String, dynamic>.from(realTimePrice));
      }
    }

    // Subscribe immediately on MarketWatchV2Service as well so ticks flow without delay
    if (Get.isRegistered<MarketWatchV2Service>()) {
      final clean = MarketWatchV2Service.normalizeSymbol(symbol);
      if (clean.isNotEmpty) {
        Get.find<MarketWatchV2Service>().subscribeSymbols([clean]);
      }
    }

    // If connected with a different symbol, don't drop the entire TCP connection
    // and wait 450ms. Just push the new subscription payload to the server.
    if (isConnected.value) {
      getSocketData();
    } else {
      if (!_isDisposed) initializeWebSocket();
    }
  }

  Future<void> changeSymbol(String newSymbol) =>
      initializeSocketForSymbol(newSymbol);

  /// Called by chart screen after restart/resume (kept for compatibility).
  void handleAppRestart() {
    if (currentSymbol.value.isEmpty) return;

    // ✅ FIX: Ensure resubscription to current symbol on app restart
    if (!isConnected.value) {
      _reconnectWebSocket(); // Will reconnect and resubscribe via initializeWebSocket()
    } else {
      // Already connected - just resubscribe to current symbol
      Future.delayed(const Duration(milliseconds: 300), () {
        if (isConnected.value && currentSymbol.value.isNotEmpty) {
          getSocketData(); // Resubscribe to current symbol
        }
      });
    }
  }

  /// Convenience: ensure started for a symbol (used by screen bootstrap)
  Future<void> ensureStartedFor(String? symbol) async {
    if (symbol == null || symbol.isEmpty) return;
    await initializeSocketForSymbol(symbol);
    handleAppRestart();
  }

  // Get WebSocket URL based on account type (MT5 vs self-hosted)
  String _getWebSocketUrl() {
    try {
      var activeAccount;

      // Try AccountController first
      try {
        final accountController = Get.find<AccountController>();
        activeAccount = accountController.activeMT5Account;
      } catch (e) {
        // AccountController not available
      }

      // ✅ FIX: Fallback to stored primary account from initialization (sync version)
      if (activeAccount == null) {
        activeAccount = WebSocketEndpointHelper.getCachedPrimaryAccountSync();
        // if (kDebugMode && activeAccount != null) {
        //   dev.log('Chart WS: Using stored primary account from initialization');
        // }
      }

      // Try DashboardController as second fallback
      if (activeAccount == null) {
        try {
          final dashboardController = Get.find<DashboardController>();
          if (dashboardController.mt5Accounts.isNotEmpty) {
            activeAccount = dashboardController.primaryMT5Account;
            if (kDebugMode) {
              // dev.log(
              //   'Chart WS: Got account from DashboardController: ${activeAccount?.metaAccountNumber ?? "N/A"}',
              // );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            // dev.log('Chart WS: DashboardController not available: $e');
          }
        }
      }

      // ✅ Use centralized endpoint helper
      var wsUrl = WebSocketEndpointHelper.getSymbolUrl(activeAccount);

      // ✅ FIX: Remove any fragments (#) that might have been accidentally added
      wsUrl = wsUrl.split('#')[0];

      final accountType = WebSocketEndpointHelper.getAccountType(activeAccount);

      if (kDebugMode) {
        dev.log(
          'Chart WS: Using $accountType endpoint: $wsUrl (Account: ${activeAccount?.metaAccountNumber ?? "N/A"}, trading_server: ${activeAccount?.tradingServer ?? "N/A"})',
        );
      }

      return wsUrl;
    } catch (e) {
      // Fallback to unified endpoint if account controller not found
      if (kDebugMode) {
        // dev.log(
        //   'Chart WS: Error getting account, using default unified endpoint: $e',
        // );
      }
      return WebSocketEndpointHelper.getFullUrl(WebSocketEndpointHelper.symbol);
    }
  }

  // ---------- WebSocket ----------
  void initializeWebSocket() async {
    if (currentSymbol.value.isEmpty) {
      // dev.log('Chart: initializeWebSocket() called with empty symbol');
      return;
    }
    if (isConnected.value) return;

    // ✅ FIX: Check authentication before initializing WebSocket
    final isLoggedIn = await SecureStorageService.isUserLoggedIn();
    if (!isLoggedIn) {
      if (kDebugMode) {
        // dev.log('Chart WS: User not logged in, skipping WebSocket initialization');
      }
      return;
    }

    // If user has no MT5 accounts, still connect to symbol WS for pricing.

    try {
      // ✅ Use correct endpoint: /ws/symbol for single symbol subscription
      final wsUrl = _getWebSocketUrl();

      // ✅ FIX: Validate and clean WebSocket URL
      if (kDebugMode) {
        dev.log('Chart WS: Connecting to URL: $wsUrl');
      }
      WebSocketEndpointHelper.logSwitchStep('Chart connect start', url: wsUrl);

      // Ensure URL is properly formatted (wss:// or ws://)
      if (!wsUrl.startsWith('wss://') && !wsUrl.startsWith('ws://')) {
        dev.log('❌ Chart WS: Invalid WebSocket URL format: $wsUrl');
        throw Exception('Invalid WebSocket URL format: $wsUrl');
      }

      // Parse and validate URI
      final uri = Uri.parse(wsUrl);
      if (kDebugMode) {
        dev.log(
          'Chart WS: Parsed URI - scheme: ${uri.scheme}, host: ${uri.host}, port: ${uri.port}, path: ${uri.path}',
        );
      }

      // Ensure scheme is wss:// or ws://
      final cleanUri =
          uri.scheme == 'wss' || uri.scheme == 'ws'
              ? uri
              : Uri(
                scheme:
                    uri.scheme == 'https'
                        ? 'wss'
                        : (uri.scheme == 'http' ? 'ws' : 'wss'),
                host: uri.host,
                port: uri.port == 0 || uri.port == -1 ? null : uri.port,
                path: uri.path,
                query: uri.query,
              );

      channel = WebSocketChannel.connect(cleanUri);
      isConnected.value = true;
      _reconnectAttempts = 0;
      isReconnecting.value = false;
      _loggedFirstMessage = false;
      dev.log('✅ Chart WebSocket connected to: ${cleanUri.toString()}');
      WebSocketEndpointHelper.logSwitchStep(
        'Chart connected',
        url: cleanUri.toString(),
      );

      channel.stream.listen(
        (message) {
          if (!_loggedFirstMessage) {
            _loggedFirstMessage = true;
            WebSocketEndpointHelper.logSwitchStep(
              'Chart first message',
              url: cleanUri.toString(),
            );
          }
          if (kDebugMode) {
            // dev.log(
            //   '📥 Chart: Raw message received (type: ${message.runtimeType})',
            // );
          }
          _handleSocketMessage(message);
        },
        onError: (error) {
          dev.log('❌ Chart WS error: $error');
          isConnected.value = false;
          _scheduleReconnect();
        },
        onDone: () {
          dev.log('⚠️ Chart WS closed');
          isConnected.value = false;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );

      // ✅ FIX: Always resubscribe to current symbol after connection
      // This ensures socket resubscribes even after disconnect/reconnect
      Future.delayed(const Duration(milliseconds: 100), () {
        if (isConnected.value &&
            !_isDisposed &&
            currentSymbol.value.isNotEmpty) {
          getSocketData(); // Resubscribe to current symbol
        }
      });
    } catch (e) {
      dev.log('Chart WS init failed: $e');
      isConnected.value = false;
      _scheduleReconnect();
    }
  }

  void getSocketData() async {
    if (currentSymbol.value.isEmpty) {
      dev.log('Chart: getSocketData() called with empty symbol');
      return;
    }

    // ✅ FIX: Check authentication before requesting socket data
    final isLoggedIn = await SecureStorageService.isUserLoggedIn();
    if (!isLoggedIn) {
      if (kDebugMode) {
        dev.log('Chart WS: User not logged in, skipping socket data request');
      }
      return;
    }

    // ✅ Use authID (same as instruments controller)
    final authid = await SecureStorageService.getAuthToken();
    dev.log("Chart: WebSocket token: ${authid != null ? 'exists' : 'null'}");

    if (authid == null || authid.isEmpty) {
      if (kDebugMode) {
        dev.log(
          'Chart: WebSocket token is null or empty, skipping request (user not logged in)',
        );
      }
      // Don't retry if user is not logged in
      return;
    }

    // Get the active MT5 account number (if any). If user has no account,
    // allow read-only pricing subscription with trading_account="0".
    String accountNumber = "0";
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;
      accountNumber = activeAccount?.metaAccountNumber ?? "0";
    } catch (_) {}

    // dev.log("Chart: Using MT5 Account Number: $accountNumber");
    // dev.log("Chart: Subscribing to symbol: ${currentSymbol.value}");
    // dev.log("Chart: WebSocket connected: ${isConnected.value}");

    // ✅ Send correct request format: { "authID": "token", "trading_account": "account", "symbol": "SYMBOL" }
    // ✅ PERFORMANCE: Request binary format for improved performance (50-70% smaller, 5-10x faster)
    final subscriptionPayload = {
      "authID": authid,
      "trading_account": accountNumber,
      "symbol": currentSymbol.value,
      "format": "binary", // Request binary format
    };

    sendEvent(subscriptionPayload);

    // dev.log(
    //   '📤 ChartSocket: Sent subscription request for ${currentSymbol.value} (account: $accountNumber)',
    // );
    if (kDebugMode) {
      dev.log('📤 ChartSocket: Subscription payload: $subscriptionPayload');
    }
    WebSocketEndpointHelper.logSwitchStep(
      'Chart subscribed',
      url: _getWebSocketUrl(),
      payload: subscriptionPayload,
    );
  }

  void sendEvent(Map<String, dynamic> event) {
    try {
      final jsonStr = jsonEncode(event);
      if (isConnected.value) {
        try {
          channel.sink.add(jsonStr);
        } catch (_) {}
      }
      try {
        final unified = Get.find<UnifiedWebSocketService>();
        if (unified.isSymbolsConnected.value) {
          unified.sendEvent(WebSocketChannelType.symbols, event);
        }
      } catch (_) {}
    } catch (e) {
      dev.log('Chart: send error: $e');
      isConnected.value = false;
    }
  }

  void _handleSocketMessage(dynamic message) {
    try {
      // ✅ PERFORMANCE: Handle both JSON and binary (MessagePack) formats
      dynamic data;

      if (MessagePackDecoder.isBinaryMessage(message)) {
        // Binary MessagePack format - decode it
        if (kDebugMode) {
          final sizeInfo = MessagePackDecoder.getMessageSize(message);
          dev.log(
            '📦 Chart: Received binary MessagePack message (${sizeInfo['sizeKB']} KB)',
          );
        }
        data = MessagePackDecoder.decodeBinary(
          message is Uint8List
              ? message
              : Uint8List.fromList(message as List<int>),
        );

        if (data == null) {
          dev.log('⚠️ Chart: Binary decode failed, skipping message');
          return;
        }
      } else {
        // JSON format - decode as string
        final jsonStr = message is String ? message : message.toString();
        data = jsonDecode(jsonStr);
      }

      // ✅ DEBUG: Log received message for troubleshooting
      if (kDebugMode) {
        // dev.log(
        //   '📥 Chart: Received message type: ${data.runtimeType}, currentSymbol: ${currentSymbol.value}',
        // );
      }

      // ✅ Handle JSON object responses (authentication, errors, etc.)
      if (data is Map<String, dynamic>) {
        final type = data['type']?.toString();

        // Handle unsubscribe confirmation
        if (type == 'symbol_left') {
          dev.log('✅ Unsubscribed from symbol');
          if (_unsubscribeCompleter != null &&
              !_unsubscribeCompleter!.isCompleted) {
            _unsubscribeCompleter!.complete();
            _unsubscribeCompleter = null;
          }
          return;
        }

        // Handle authentication success messages
        if (type == 'symbol_joined' || type == 'authenticated') {
          final status = data['status']?.toString();
          final messageText = data['message']?.toString();

          if (status == 'success') {
            dev.log('✅ Chart WebSocket authenticated: $messageText');
            if (type == 'symbol_joined') {
              dev.log('✅ Subscribed to symbol: ${data['symbol']}');
            }
          }
          return;
        }

        // Handle error responses
        if (type == 'error') {
          final errorMessage = data['message']?.toString() ?? 'Unknown error';
          dev.log('❌ Chart WebSocket error: $errorMessage');
          // Complete unsubscribe completer even on error to avoid hanging
          if (_unsubscribeCompleter != null &&
              !_unsubscribeCompleter!.isCompleted) {
            _unsubscribeCompleter!.complete();
            _unsubscribeCompleter = null;
          }
          return;
        }

        // Handle old format with groups
        if (data.containsKey('groups')) {
          _handleGroupsData(data);
          return;
        }

        // Handle old format with singleSymbol
        if (data.containsKey('singleSymbol')) {
          final single = Map<String, dynamic>.from(data['singleSymbol'] ?? {});
          final responseSymbol = single['Symbol']?.toString();

          if (_matchesCurrentSymbol(responseSymbol)) {
            final transformed = {
              'type': 'singleSymbolPrice',
              'symbol': responseSymbol,
              'bid': single['Bid'],
              'ask': single['Ask'],
              'digits': single['Digits'],
              'last': single['Last'],
              'spreadDiff': single['SpreadDiff'],
              'volume': single['Volume'],
            };

            if (!_isDisposed) {
              realTimePrice.value = transformed;
              noteTickObserved();
            }
            if (!_priceStreamController.isClosed) {
              _priceStreamController.add(
                Map<String, dynamic>.from(transformed),
              );
            }
          }
          return;
        }

        // Handle other JSON responses
        // ✅ FIX: Check symbol match more flexibly (with or without suffix)
        final responseSymbol = data['symbol']?.toString() ?? data['Symbol']?.toString();
        final isSymbolMatch =
            responseSymbol != null &&
            (_matchesCurrentSymbol(responseSymbol) ||
                responseSymbol == currentSymbol.value);

        if (data['type'] == 'singleSymbolPrice' || isSymbolMatch) {
          if (kDebugMode) {
            dev.log(
              '✅ Chart: Processing price update for symbol: $responseSymbol (current: ${currentSymbol.value})',
            );
          }
          final normalized = Map<String, dynamic>.from(data);
          if (normalized.containsKey('Bid') && !normalized.containsKey('bid')) {
            normalized['bid'] = normalized['Bid'];
          }
          if (normalized.containsKey('Ask') && !normalized.containsKey('ask')) {
            normalized['ask'] = normalized['Ask'];
          }
          if (normalized.containsKey('Digits') && !normalized.containsKey('digits')) {
            normalized['digits'] = normalized['Digits'];
          }
          if (normalized.containsKey('SpreadDiff') && !normalized.containsKey('spread_diff')) {
            normalized['spread_diff'] = normalized['SpreadDiff'];
          }
          if (normalized.containsKey('SpreadDiff') && !normalized.containsKey('spreadDiff')) {
            normalized['spreadDiff'] = normalized['SpreadDiff'];
          }
          if (normalized.containsKey('Symbol') && !normalized.containsKey('symbol')) {
            normalized['symbol'] = normalized['Symbol'];
          }

          if (!_isDisposed) {
            realTimePrice.value = normalized;
            noteTickObserved();
            if (kDebugMode) {
              dev.log(
                '📊 Chart: Updated realTimePrice - bid: ${normalized['bid']}, ask: ${normalized['ask']}',
              );
            }
          }
          if (!_priceStreamController.isClosed) {
            _priceStreamController.add(Map<String, dynamic>.from(normalized));
            if (kDebugMode) {
              dev.log('📡 Chart: Broadcasted price update to stream');
            }
          }
          return;
        } else {
          if (kDebugMode) {
            dev.log(
              '⚠️ Chart: Symbol mismatch - received: $responseSymbol, current: ${currentSymbol.value}',
            );
          }
        }
        return;
      }

      // ✅ Handle array format: [symbol, bid, ask, spread_points, digits, category]
      // New format: ["XAUUSD", 2650.50, 2650.70, 2, 2, "metals"]
      if (data is List && data.length >= 5) {
        final symbol = data[0].toString();

        if (_matchesCurrentSymbol(symbol)) {
          final transformed = {
            'type': 'singleSymbolPrice',
            'symbol': symbol,
            'bid': double.tryParse(data[1].toString()) ?? 0.0,
            'ask': double.tryParse(data[2].toString()) ?? 0.0,
            'spreadDiff':
                double.tryParse(data[3].toString()) ?? 0.0, // spread_points
            'digits': int.tryParse(data[4].toString()) ?? 5,
            'category': data.length >= 6 ? data[5].toString() : null,
            'last': 0,
            'volume': 0,
          };

          if (kDebugMode) {
            // dev.log(
            //   '✅ Chart: Processing array price update for symbol: $symbol (current: ${currentSymbol.value})',
            // );
            // dev.log(
            //   '📊 Chart: Price - bid: ${transformed['bid']}, ask: ${transformed['ask']}',
            // );
          }

          if (!_isDisposed) {
            realTimePrice.value = transformed;
            noteTickObserved();
          }
          if (!_priceStreamController.isClosed) {
            _priceStreamController.add(Map<String, dynamic>.from(transformed));
            if (kDebugMode) {
              // dev.log('📡 Chart: Broadcasted array price update to stream');
            }
          }
        } else {
          if (kDebugMode) {
            dev.log(
              '⚠️ Chart: Array symbol mismatch - received: $symbol, current: ${currentSymbol.value}',
            );
          }
        }
        return;
      }
    } catch (e) {
      dev.log('Chart: parse error: $e; raw: $message');
    }
  }

  void _handleGroupsData(Map<String, dynamic> data) {
    final groups = data['groups'] as List<dynamic>? ?? [];
    for (final g in groups) {
      final group = g as Map<String, dynamic>;
      final list = group['list'] as List<dynamic>? ?? [];
      for (final it in list) {
        // Handle both array and object formats
        if (it is List && it.length >= 5) {
          // Array format: ["symbol", "bid", "ask", "spreadDiff", "digits", "category"]
          final symbol = it[0].toString();
          if (_matchesCurrentSymbol(symbol)) {
            final transformed = {
              'type': 'singleSymbolPrice',
              'symbol': symbol,
              'bid': double.tryParse(it[1].toString()) ?? 0.0,
              'ask': double.tryParse(it[2].toString()) ?? 0.0,
              'spreadDiff': int.tryParse(it[3].toString()) ?? 0,
              'digits': int.tryParse(it[4].toString()) ?? 0,
              'category': it.length >= 6 ? it[5].toString() : null,
              'last': 0,
              'volume': 0,
            };
            if (!_isDisposed) {
              realTimePrice.value = transformed;
              noteTickObserved();
            }
            if (!_priceStreamController.isClosed) {
              _priceStreamController.add(
                Map<String, dynamic>.from(transformed),
              );
            }
            return;
          }
        } else if (it is Map<String, dynamic>) {
          // Object format
          final symbol = it['Symbol']?.toString() ?? '';
          if (_matchesCurrentSymbol(symbol)) {
            final transformed = {
              'type': 'singleSymbolPrice',
              'symbol': symbol,
              'bid': it['Bid'],
              'ask': it['Ask'],
              'digits': it['Digits'],
              'last': it['Last'],
              'spreadDiff': it['SpreadDiff'],
              'volume': it['Volume'],
            };
            if (!_isDisposed) {
              realTimePrice.value = transformed;
              noteTickObserved();
            }
            if (!_priceStreamController.isClosed) {
              _priceStreamController.add(
                Map<String, dynamic>.from(transformed),
              );
            }
            return;
          }
        }
      }
    }
  }

  void _bindMarketWatchV2Listener() {
    if (_marketWatchV2Sub != null) return;
    if (!Get.isRegistered<MarketWatchV2Service>()) return;
    _marketWatchV2Sub = Get.find<MarketWatchV2Service>().decodedFrames.listen(
      _handleMarketWatchV2Decoded,
    );
  }

  void _handleMarketWatchV2Decoded(dynamic decodedData) {
    if (_isDisposed || currentSymbol.value.isEmpty) return;
    final cur = currentSymbol.value;
    final cleanCur = MarketWatchV2Service.normalizeSymbol(cur);

    void checkAndApply(Map map) {
      final s = map['symbol'] ?? map['Symbol'] ?? map['s'] ?? map['name'];
      if (s == null) return;
      final str = s.toString();
      if (_matchesCurrentSymbol(str) ||
          MarketWatchV2Service.normalizeSymbol(str) == cleanCur) {
        final bid = (map['bid'] ?? map['Bid'] ?? map['b'] as num?)?.toDouble();
        final ask = (map['ask'] ?? map['Ask'] ?? map['a'] as num?)?.toDouble();
        final spread = (map['spread'] ??
                map['spread_points'] ??
                map['spreadPoints'] ??
                map['SpreadDiff'] ??
                map['spread_diff'] as num?)
            ?.toDouble();
        if (bid != null && bid > 0) {
          updatePriceFromExternal(
            symbol: cur,
            bid: bid,
            ask: ask ?? bid,
            spreadDiff: spread,
          );
        }
      }
    }

    if (decodedData is Map) {
      checkAndApply(decodedData);
    } else if (decodedData is List) {
      for (final item in decodedData) {
        if (item is Map) {
          checkAndApply(item);
        } else if (item is List && item.length >= 3) {
          final s = item[0]?.toString();
          if (s != null &&
              (_matchesCurrentSymbol(s) ||
                  MarketWatchV2Service.normalizeSymbol(s) == cleanCur)) {
            final bid = double.tryParse(item[1].toString());
            final ask = double.tryParse(item[2].toString());
            final spread =
                item.length > 3 ? double.tryParse(item[3].toString()) : null;
            if (bid != null && bid > 0) {
              updatePriceFromExternal(
                symbol: cur,
                bid: bid,
                ask: ask ?? bid,
                spreadDiff: spread,
              );
            }
          }
        }
      }
    }
  }

  bool matchesSymbol(String? responseSymbol) =>
      _matchesCurrentSymbol(responseSymbol);

  void updatePriceFromExternal({
    required String symbol,
    required double bid,
    required double ask,
    double? spreadDiff,
  }) {
    if (_isDisposed) return;
    if (!_matchesCurrentSymbol(symbol)) return;

    final transformed = <String, dynamic>{
      'type': 'singleSymbolPrice',
      'symbol': symbol,
      'bid': bid,
      'ask': ask,
      'spreadDiff': spreadDiff ?? realTimePrice['spreadDiff'] ?? 0.0,
      'digits': realTimePrice['digits'] ?? 5,
    };

    realTimePrice.value = transformed;
    noteTickObserved();
    if (!_priceStreamController.isClosed) {
      _priceStreamController.add(Map<String, dynamic>.from(transformed));
    }
  }

  bool _matchesCurrentSymbol(String? responseSymbol) {
    final cur = currentSymbol.value;
    if (responseSymbol == null || cur.isEmpty) return false;

    // Exact match (with or without suffix)
    if (responseSymbol == cur) return true;

    // Remove any suffix (.c, .r, etc.) and compare base symbols
    final baseResponse = _removeSuffix(responseSymbol);
    final baseCurrent = _removeSuffix(cur);

    // Match if base symbols are same (handles EURUSD.c == EURUSD)
    return baseResponse == baseCurrent;
  }

  // Helper to remove any suffix (.c, .r, etc.) for comparison purposes
  // Handles both cases: symbols WITH suffix (EURUSD.c) and WITHOUT suffix (EURUSD)
  String _removeSuffix(String symbol) {
    if (symbol.contains('.')) {
      return symbol.substring(0, symbol.lastIndexOf('.'));
    }
    return symbol; // No suffix, return original
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      isReconnecting.value = false;
      return;
    }
    _reconnectAttempts++;
    isReconnecting.value = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _reconnectWebSocket);
  }

  void _reconnectWebSocket() {
    if (isConnected.value) return;

    // ✅ FIX: Ensure we have a symbol before reconnecting
    if (currentSymbol.value.isEmpty) {
      dev.log('Chart: Cannot reconnect - no symbol set');
      isReconnecting.value = false;
      return;
    }

    try {
      _disconnectWebSocket();
      Future.delayed(const Duration(milliseconds: 100), () {
        // ✅ FIX: Reconnect and resubscribe to current symbol
        // initializeWebSocket() will call getSocketData() after connection
        if (currentSymbol.value.isNotEmpty && !_isDisposed) {
          initializeWebSocket();
        }
      });
    } catch (e) {
      dev.log('Chart: reconnect error: $e');
      isReconnecting.value = false;
    }
  }

  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    isConnected.value = false;
    isReconnecting.value = false;
    realTimePrice.clear();
    try {
      channel.sink.close();
    } catch (_) {}
  }

  // Unsubscribe and resubscribe with new account (keeps socket active)
  Future<void> unsubscribeAndResubscribe(
    String newAccountNumber,
  ) async {

    // If not connected or symbol is empty, just initialize normally
    if (!isConnected.value || currentSymbol.value.isEmpty) {
      realTimePrice.clear();
      if (!isConnected.value) {
        initializeWebSocket();
      } else {
        getSocketData();
      }
      return;
    }

    try {
      // Step 1: Unsubscribe from current symbol
      // print('📤 ChartSocketController: Sending leave_symbol request');
      _unsubscribeCompleter = Completer<void>();
      // sendEvent({"type": "leave_symbol"});
      sendEvent({"type": "unsubscribe"});

      // Step 2: Wait for unsubscribe confirmation (with timeout)
      try {
        await _unsubscribeCompleter!.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            if (_unsubscribeCompleter != null &&
                !_unsubscribeCompleter!.isCompleted) {
              _unsubscribeCompleter!.complete();
              _unsubscribeCompleter = null;
            }
          },
        );
      } catch (e) {
      }

      // Step 3: Clear price data and set symbol
      realTimePrice.clear();
      // No need to update currentSymbol, it is already current

      // Step 4: Resubscribe with new account
      final authid = await SecureStorageService.getAuthToken();
      if (authid != null && authid.isNotEmpty) {
        sendEvent({
          "authID": authid,
          "trading_account": newAccountNumber,
          "symbol": currentSymbol.value,
        });
      } else {
      }
    } catch (e) {
      // Fallback: if unsubscribe/resubscribe fails, do full reconnect
      _disconnectWebSocket();
      await Future.delayed(const Duration(milliseconds: 100));
      realTimePrice.clear();
      initializeWebSocket();
    }
  }

  void resetController() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    isReconnecting.value = false;
    if (isConnected.value) {
      try {
        channel.sink.close();
      } catch (_) {}
    }
    isConnected.value = false;
    realTimePrice.clear();
  }

  void forceReconnect() {
    resetController();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!_isDisposed) initializeWebSocket();
    });
  }

  // ----- Convenience getters -----
  Map<String, dynamic>? getCurrentPrice() {
    return realTimePrice.isNotEmpty ? realTimePrice : null;
  }

  double? getBidPrice() {
    final p = getCurrentPrice();
    if (p != null) {
      final bidVal = p['bid'] ?? p['Bid'];
      if (bidVal != null) {
        return double.tryParse(bidVal.toString());
      }
    }
    return null;
  }

  double? getAskPrice() {
    final p = getCurrentPrice();
    if (p != null) {
      final askVal = p['ask'] ?? p['Ask'];
      if (askVal != null) {
        return double.tryParse(askVal.toString());
      }
    }
    return null;
  }

  double? getDifference() {
    try {
      final p = getCurrentPrice();
      if (p == null) return null;
      final spreadField = p['spreadDiff'] ?? p['SpreadDiff'];
      if (spreadField != null) {
        final v = double.tryParse(spreadField.toString());
        if (v != null) return v.abs();
      }
      // final bid = getBidPrice();
      // final ask = getAskPrice();
      // if (bid != null && ask != null) return (ask - bid).abs();
    } catch (e) {
      dev.log('Chart: getDifference error: $e');
    }
    return null;
  }

  // Get market price (average of bid and ask) for price alerts
  double? getMarketPrice() {
    try {
      final bid = getBidPrice();
      final ask = getAskPrice();
      if (bid != null && ask != null) {
        return (bid + ask) / 2;
      }
      // Fallback to bid price if ask is not available
      return bid;
    } catch (e) {
      dev.log('Chart: getMarketPrice error: $e');
      return null;
    }
  }

  // WebsocketPriceData? getCurrentPriceDataModel() {
  //   try {
  //     final p = getCurrentPrice();
  //     if (p == null) return null;
  //     final candidate = <String, dynamic>{
  //       'Symbol': p['symbol'] ?? p['Symbol'],
  //       'Bid': p['bid'] ?? p['Bid'],
  //       'Ask': p['ask'] ?? p['Ask'],
  //       'Last': p['last'] ?? p['Last'],
  //       'Digits': p['digits'] ?? p['Digits'],
  //       'SpreadDiff': p['spreadDiff'] ?? p['SpreadDiff'],
  //       'Volume': p['volume'] ?? p['Volume'],
  //     };
  //     try {
  //       return WebsocketPriceData.fromJson(candidate);
  //     } catch (_) {
  //       return WebsocketPriceData.fromJson({'singleSymbol': candidate});
  //     }
  //   } catch (e) {
  //     dev.log('Chart: getCurrentPriceDataModel error: $e');
  //     return null;
  //   }
  // }
}
