import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/services/favorites_storage_service.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm_app/utils/message_pack_decoder.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/services/unified_websocket_service.dart';

class InstrumentsController extends GetxController with WidgetsBindingObserver {
  final FinanceRepository _financeRepo = Get.find<FinanceRepository>();
  final RxList<ListElement> allInstruments = <ListElement>[].obs;
  final RxList<ListElement> instruments = <ListElement>[].obs;
  // Vantage: manual reordering support (UI can override default order)
  final RxList<String> manualOrderSymbols = <String>[].obs;

  // ✅ PERF: Per-symbol reactive price store (prevents full list rebuilds)
  // Each symbol has its own Rx, so only that row's price widgets update.
  final Map<String, Rx<InstrumentPrice>> _priceBySymbol = {};
  final Map<String, InstrumentPrice> _pendingPriceUpdates = {};
  Timer? _priceFlushTimer;
  bool _userScrolling = false;
  Timer? _scrollIdleTimer;

  Rx<InstrumentPrice> priceRx(String symbol) {
    return _priceBySymbol.putIfAbsent(
      symbol,
      () => InstrumentPrice.empty().obs,
    );
  }

  void _applyPriceUpdate(ListElement item) {
    // Queue and batch UI updates to keep scrolling smooth.
    final current = priceRx(item.symbol).value;
    _pendingPriceUpdates[item.symbol] = current.copyWith(
      bid: item.bid,
      ask: item.ask,
      digits: item.digits,
      spreadDiff: item.spreadDiff,
      dayLow: item.dayLow ?? current.dayLow,
      dayHigh: item.dayHigh ?? current.dayHigh,
    );
    _schedulePriceFlush();
  }

  void notifyUserScrollActivity() {
    if (!_userScrolling) {
      _userScrolling = true;
    }
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(const Duration(milliseconds: 200), () {
      _userScrolling = false;
      _schedulePriceFlush(flushSoon: true);
    });
  }

  void _schedulePriceFlush({bool flushSoon = false}) {
    if (_userScrolling) return;
    if (_pendingPriceUpdates.isEmpty) return;
    if (_priceFlushTimer?.isActive ?? false) return;
    _priceFlushTimer = Timer(
      flushSoon ? const Duration(milliseconds: 30) : const Duration(milliseconds: 120),
      _flushPendingPrices,
    );
  }

  void _flushPendingPrices() {
    if (_userScrolling) return;
    if (_pendingPriceUpdates.isEmpty) return;
    final batch = Map<String, InstrumentPrice>.from(_pendingPriceUpdates);
    _pendingPriceUpdates.clear();
    for (final e in batch.entries) {
      priceRx(e.key).value = e.value;
    }
  }

  // Track previous filtered instruments symbols to detect structure changes
  Set<String> _previousFilteredSymbols = {};
  final RxString currentFilter =
      'Favorites'.obs; // Default to 'Favorites' instead of 'All'
  final RxString currentSort = 'Default'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxMap<String, List<ListElement>> tradingGroups =
      <String, List<ListElement>>{}.obs;

  // Dynamic filters based on WebSocket categories
  final RxList<String> availableFilters = <String>['Favorites'].obs;

  // Favorites management
  final RxList<String> favoriteInstruments = <String>[].obs;
  final RxBool isLoadingFavorites = false.obs;

  // Put your WebSocket URL here
  late WebSocketChannel channel;
  StreamSubscription? _unifiedMwSub;

  // Connection management
  final RxBool isConnected = false.obs;
  final RxBool isReconnecting = false.obs;
  Timer? _reconnectTimer;

  // ✅ FIX: Debounce timer to prevent double getSocketdata calls
  Timer? _socketDataDebounceTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _baseReconnectDelay = Duration(seconds: 3);
  static const Duration _connectionTimeout = Duration(seconds: 10);
  bool _isConnecting = false; // Guard to prevent concurrent connections
  bool _isInitialSnapshot = true; // Track if we're receiving initial snapshot
  bool _isReconnecting =
      false; // Track if we're in reconnection mode to preserve prices
  bool _loggedFirstMessage = false;
  bool _isClearingData =
      false; // Guard to prevent duplicate clearing operations

  // Unsubscribe/resubscribe state
  Completer<void>? _unsubscribeCompleter;

  // Track current account number to detect account changes
  String? _currentAccountNumber;
  String? _currentWsUrl;

  // Get exponential backoff delay
  Duration _getReconnectDelay() {
    final baseSeconds = _baseReconnectDelay.inSeconds;
    final exponentialSeconds =
        baseSeconds * (1 << (_reconnectAttempts - 1).clamp(0, 4));
    return Duration(seconds: exponentialSeconds.clamp(3, 60)); // Max 60 seconds
  }

  // Check if primary account has trading_server="MT5"
  bool _isMT5Account() {
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;
      return activeAccount?.tradingServer.toUpperCase() == "MT5";
    } catch (e) {
      print('Error checking MT5 account: $e');
      return false;
    }
  }

  // Get MT5 group name and escape backslashes (single to double)
  // Group name comes as "app\Standard" but needs to be sent as "app\\Standard"
  Future<String> _getMT5GroupName() async {
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;
      String mt5GroupName = activeAccount?.mt5GroupName ?? "";

      if (mt5GroupName.isEmpty) {
        // Fallback: fetch from API if not available in account
        try {
          final resp = await _financeRepo.postRealPlanDetails(
            data: {"group_id": 0},
          );
          if (resp.success && resp.data is Map && resp.data['data'] is List) {
            final List list = resp.data['data'] as List;
            if (list.isNotEmpty) {
              final first = list.first as Map<String, dynamic>;
              mt5GroupName =
                  (first['mt5_group_name'] ?? first['group_name'])
                      ?.toString() ??
                  "";
            }
          }
        } catch (e) {
          print('Error fetching MT5 group name from API: $e');
        }
      }

      // Escape backslashes: "app\Standard" -> "app\\Standard"
      if (mt5GroupName.isNotEmpty) {
        mt5GroupName = mt5GroupName.replaceAll('\\', '\\\\');
      }

      return mt5GroupName.isNotEmpty ? mt5GroupName : "Internal\\Standard";
    } catch (e) {
      print('Error getting MT5 group name: $e');
      return "Internal\\Standard";
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Add lifecycle observer to handle app state changes
    WidgetsBinding.instance.addObserver(this);

    // Load favorites from storage
    _loadFavorites();

    // Force reinitialize with new defaults if needed (for existing users)
    _checkAndUpdateDefaults();

    // ✅ FIX: Listen to account changes and update instruments data
    try {
      final accountController = Get.find<AccountController>();
      MT5Account? _lastAccount;

      ever(accountController.activeMT5AccountRx, (MT5Account? account) {
        if (account == null) return;

        // Check if account changed (different account number or type)
        final accountChanged =
            _lastAccount == null ||
            _lastAccount!.metaAccountNumber != account.metaAccountNumber ||
            (_lastAccount!.tradingServer.toUpperCase() !=
                account.tradingServer.toUpperCase());

        if (accountChanged) {
          print(
            '═══════════════════════════════════════════════════════════',
          );
          print(
            '🔄 ACCOUNT CHANGED - InstrumentsController',
          );
          print(
            '   From: ${_lastAccount?.metaAccountNumber ?? "N/A"} (${_lastAccount?.tradingServer ?? "N/A"})',
          );
          print(
            '   To:   ${account.metaAccountNumber} (${account.tradingServer})',
          );
          print(
            '═══════════════════════════════════════════════════════════',
          );

          // Update last account
          _lastAccount = account;

          // ✅ STEP 1: Cancel unified subscription FIRST to stop old data flow
          if (_unifiedMwSub != null) {
            print(
              '🛑 STEP 1: Cancelling unified WebSocket subscription to stop old data...',
            );
            _unifiedMwSub?.cancel();
            _unifiedMwSub = null;
            isConnected.value = false;
          }

          // ✅ STEP 2: Set clearing flag to block new data processing
          _isClearingData = true;
          print(
            '🛑 STEP 2: Setting _isClearingData flag to block data processing',
          );

          // ✅ STEP 3: Clear instruments data immediately
          print(
            '🗑️ STEP 3: Clearing all instruments data...',
          );
          allInstruments.clear();
          instruments.clear();
          tradingGroups.clear();
          currentFilter.value = 'Favorites';
          availableFilters.value = ['Favorites'];
          searchQuery.value = '';

          // Update current account number
          _currentAccountNumber = account.metaAccountNumber;

          // ✅ STEP 4: Switch account in unified service (async, non-blocking)
          Future.microtask(() async {
            try {
              final unified = Get.find<UnifiedWebSocketService>();
              print(
                '🔄 STEP 4: Switching account in unified WebSocket service...',
              );
              await unified.switchAccount(account);
              print(
                '✅ Unified service account switched successfully',
              );
              
              // ✅ STEP 5: Reconnect with new account after switch
              print(
                '🔄 STEP 5: Reconnecting with new account...',
              );
              // Small delay to ensure clean disconnect
              await Future.delayed(const Duration(milliseconds: 100));
              startWebSocket();
            } catch (e) {
              print(
                '⚠️ Error switching account in unified service: $e',
              );
              // Fallback: try to reconnect anyway
              startWebSocket();
            }
          });

          // ✅ STEP 6: Reset clearing flag after reconnect (will be reset when data arrives)
          // Flag will be reset in _parseNewFormat when initial snapshot arrives

          // Trigger UI update
          update();
        }
      });
    } catch (e) {
      print('⚠️ InstrumentsController: Error setting up account listener: $e');
    }

    // ✅ FIX: DON'T initialize WebSocket automatically - let screen decide when to start
    // WebSocket will only start when:
    // 1. User is logged in (checked in startWebSocket method)
    // 2. Screen explicitly calls startWebSocket()
    // _initializeWebSocket();
  }

  // Method to start WebSocket when screen becomes visible
  void startWebSocket() async {
    // ✅ FIX: Check authentication before starting WebSocket
    final isLoggedIn = await SecureStorageService.isUserLoggedIn();
    if (!isLoggedIn) {
      if (kDebugMode) {
        print('Instruments: User not logged in, skipping WebSocket start');
      }
      return;
    }

    print('🔌 InstrumentsController: Starting WebSocket');

    // Use unified service
    if (_bindUnifiedMarketWatch()) {
      return;
    }

    // Get current account number
    String? newAccountNumber;
    try {
      final accountController = Get.find<AccountController>();
      newAccountNumber = accountController.activeMT5Account?.metaAccountNumber;
    } catch (e) {
      print('Error getting account number: $e');
    }

    // Check if account changed
    // Account changed if:
    // 1. We have a previous account number AND new account number is different
    // 2. OR we have a new account number but no previous one (first connection)
    final accountChanged =
        _currentAccountNumber != null &&
        newAccountNumber != null &&
        _currentAccountNumber != newAccountNumber;

    // If this is the first connection (no previous account), treat it as not changed
    final isFirstConnection =
        _currentAccountNumber == null && newAccountNumber != null;

    // ✅ FIX: When called from account switch (dashboard), always reconnect if account changed
    // This ensures instrument data loads even when instruments screen is not visible

    // Only reconnect if:
    // 1. Not already connecting
    // 2. AND (not connected OR account changed)
    if (!_isConnecting) {
      if (isConnected.value && !accountChanged && !isFirstConnection) {
        // Already connected and account hasn't changed - no need to reconnect
        print(
          'Instruments: Already connected with same account, skipping reconnect',
        );
        return;
      }

      print('Websocket started');
      // ✅ OPTIMIZATION: If already connected and account changed, reuse same channel
      // This is faster than disconnecting and reconnecting
      // When accountChanged is true, newAccountNumber is guaranteed to be non-null
      // (accountChanged requires both _currentAccountNumber and newAccountNumber to be non-null)
      if (isConnected.value && accountChanged) {
        // ignore: unnecessary_null_assertion
        // newAccountNumber is guaranteed non-null when accountChanged is true
        print(
          'Instruments: Account changed from $_currentAccountNumber to $newAccountNumber, reusing same channel',
        );
        // Reuse same channel - just unsubscribe and resubscribe with new account
        // newAccountNumber is guaranteed non-null when accountChanged is true
        unsubscribeAndResubscribe(newAccountNumber);
        return; // Don't create new connection
      }

      // Update current account number before connecting
      _currentAccountNumber = newAccountNumber;
      _initializeWebSocket();
    } else {
      print('Instruments: Connection already in progress, skipping');
    }
  }

  bool _bindUnifiedMarketWatch() {
    try {
      final unified = Get.find<UnifiedWebSocketService>();
      MT5Account? account;
      try {
        final accountController = Get.find<AccountController>();
        account = accountController.activeMT5Account;
      } catch (_) {}
      
      print(
        '🔌 InstrumentsController: Binding to unified WebSocket service',
      );
      print(
        '   Account: ${account?.metaAccountNumber ?? "N/A"}',
      );
      
      // ✅ FIX: Cancel old subscription FIRST to prevent old data flow
      if (_unifiedMwSub != null) {
        print(
          '   Cancelling old subscription...',
        );
        _unifiedMwSub?.cancel();
        _unifiedMwSub = null;
      }
      
      // ✅ FIX: Switch account in unified service BEFORE connecting
      if (account != null) {
        print(
          '   Switching account in unified service...',
        );
        unified.switchAccount(account);
      }
      
      // ✅ FIX: Ensure connected with new account
      unified.ensureConnected(WebSocketChannelType.marketWatch, account);
      
      // ✅ FIX: Create new subscription AFTER account switch
      _unifiedMwSub = unified.marketWatchStream().listen(
        (message) => _handleSocketMessage(message),
        onError: (_) {
          isConnected.value = false;
          print('❌ InstrumentsController: Unified WebSocket error');
        },
        onDone: () {
          isConnected.value = false;
          print('❌ InstrumentsController: Unified WebSocket closed');
        },
      );
      isConnected.value = true;
      print(
        '✅ InstrumentsController: Successfully bound to unified WebSocket service',
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Instruments: Failed to bind unified marketwatch: $e');
      }
      return false;
    }
  }

  void _handleSocketMessage(dynamic message) {
    // ✅ FIX: Ignore messages while clearing data to prevent old data from being added
    if (_isClearingData) {
      print(
        '⚠️ InstrumentsController: Ignoring message while clearing data (preventing old data)',
      );
      return;
    }

    try {
      dynamic decodedData;
      if (message is Uint8List || message is List<int>) {
        decodedData = MessagePackDecoder.decodeBinary(
          message is Uint8List
              ? message
              : Uint8List.fromList(message as List<int>),
        );
        if (decodedData == null) return;
      } else {
        final jsonStr = message is String ? message : message.toString();
        decodedData = jsonDecode(jsonStr);
      }

      if (decodedData is Map<String, dynamic>) {
        _handleJsonResponse(decodedData);
        return;
      }

      if (decodedData is List && decodedData.isNotEmpty) {
        if (decodedData[0] is List) {
          _parseNewFormat(decodedData);
        } else if (decodedData[0] is String && decodedData.length >= 5) {
          _parseSingleInstrument(decodedData);
        }
        return;
      }
    } catch (e, t) {
      print('Error parsing JSON: $e\n $t');
    }
  }

  // Method to stop WebSocket when screen is hidden
  void stopWebSocket() {
    print(
      '═══════════════════════════════════════════════════════════',
    );
    print(
      '🛑 STOPPING WEBSOCKET - InstrumentsController',
    );
    print(
      '   Account: ${_currentAccountNumber ?? "N/A"}',
    );
    print(
      '═══════════════════════════════════════════════════════════',
    );
    
    // ✅ FIX: Cancel unified subscription FIRST to stop data flow
    if (_unifiedMwSub != null) {
      print(
        '   Cancelling unified WebSocket subscription...',
      );
      _unifiedMwSub?.cancel();
      _unifiedMwSub = null;
      isConnected.value = false;
    }
    
    // ✅ FIX: Set clearing flag to block any remaining messages
    _isClearingData = true;
    
    // Disconnect direct WebSocket if using it
    _disconnectWebSocket();
    
    print(
      '✅ WebSocket stopped and data flow blocked',
    );
  }

  // Check if we need to update defaults (for existing users)
  Future<void> _checkAndUpdateDefaults() async {
    try {
      final currentFavorites =
          await FavoritesStorageService.instance.getFavoriteInstruments();
      // If user has old defaults (USOIL, NAS100, BTCUSD), update to new ones
      if (currentFavorites.contains('USIOL.c') ||
          currentFavorites.contains('NAS100.c') ||
          currentFavorites.contains('BTCUSD.c')) {
        print('🔄 Detected old default favorites, updating to new ones');
        await forceReinitializeDefaults();
      }
    } catch (e) {
      print('Error checking and updating defaults: $e');
    }
  }

  void _initializeWebSocket() async {
    if (_isConnecting) {
      print('Instruments: Connection already in progress, skipping');
      return;
    }

    // ✅ FIX: Check authentication before initializing WebSocket
    final isLoggedIn = await SecureStorageService.isUserLoggedIn();
    if (!isLoggedIn) {
      if (kDebugMode) {
        print(
          'Instruments: User not logged in, skipping WebSocket initialization',
        );
      }
      return;
    }

    // Check network connectivity first
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        print('Instruments: No network connectivity, retrying later...');
        _scheduleReconnect();
        return;
      }
    } catch (e) {
      print('Instruments: Error checking connectivity: $e');
      // Continue anyway - connectivity check might not be available
    }

    try {
      _isConnecting = true;
      _isInitialSnapshot = true; // Reset for new connection

      final accountController = Get.find<AccountController>();
      var activeAccount = accountController.activeMT5Account;

      // ✅ FIX: Fallback to stored primary account from initialization
      if (activeAccount == null) {
        activeAccount = await WebSocketEndpointHelper.getStoredPrimaryAccount();
        if (kDebugMode && activeAccount != null) {
          print(
            'Instruments: Using stored primary account from initialization',
          );
        }
      }

      // ✅ Use centralized endpoint helper
      final wsUrl = WebSocketEndpointHelper.getMarketWatchUrl(activeAccount);
      final accountType = WebSocketEndpointHelper.getAccountType(activeAccount);

      print(
        'Instruments: Endpoint change? prev=${_currentWsUrl ?? "none"} -> new=$wsUrl',
      );
      WebSocketEndpointHelper.logSwitchStep(
        'Instruments connect start',
        url: wsUrl,
      );
      print(
        'Instruments: Connecting to $wsUrl ($accountType account, Account: ${activeAccount?.metaAccountNumber ?? "N/A"}, trading_server: ${activeAccount?.tradingServer ?? "N/A"})',
      );

      // Connect with timeout handling
      channel = await Future<WebSocketChannel>.delayed(
        Duration.zero,
        () => WebSocketChannel.connect(Uri.parse(wsUrl)),
      ).timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Connection timeout after ${_connectionTimeout.inSeconds}s',
          );
        },
      );

      // Don't set isConnected = true yet - wait for first message or confirmation
      _reconnectAttempts = 0;
      isReconnecting.value = false;
      _currentWsUrl = wsUrl;
      _loggedFirstMessage = false;

      // Update current account number when connecting
      try {
        final accountController = Get.find<AccountController>();
        _currentAccountNumber =
            accountController.activeMT5Account?.metaAccountNumber;
      } catch (e) {
        print('Error updating account number: $e');
      }

      // Listen for data from socket server
      // ✅ PERFORMANCE: Handle both JSON (String) and binary (Uint8List) messages
      channel.stream.listen(
        (message) {
          updateFromJson(message); // Can be String (JSON) or Uint8List (binary)
          // Set connected after receiving first valid message
          if (!isConnected.value) {
            isConnected.value = true;
            print('Instruments: WebSocket connected and receiving data');
          }
          if (!_loggedFirstMessage) {
            _loggedFirstMessage = true;
            WebSocketEndpointHelper.logSwitchStep(
              'Instruments first message',
              url: _currentWsUrl,
            );
          }
        },
        onError: (error) {
          print('Instruments: WebSocket error: $error');
          isConnected.value = false;
          _isConnecting = false;
          _scheduleReconnect();
        },
        onDone: () {
          print('Instruments: WebSocket connection closed');
          isConnected.value = false;
          _isConnecting = false;
          _scheduleReconnect();
        },
      );

      // Request authentication and subscription
      // ✅ PERFORMANCE: Request binary format for improved performance
      getSocketdata();
      _isConnecting = false;
    } catch (e) {
      print('Instruments: Failed to initialize WebSocket: $e');
      isConnected.value = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void getSocketdata() async {
    // ✅ FIX: Debounce to prevent double calls during account switch
    _socketDataDebounceTimer?.cancel();

    // ✅ FIX: Check authentication before requesting socket data
    final isLoggedIn = await SecureStorageService.isUserLoggedIn();
    if (!isLoggedIn) {
      if (kDebugMode) {
        print('Instruments: User not logged in, skipping socket data request');
      }
      return;
    }

    final authid = await SecureStorageService.getAuthToken();
    print(
      "Instruments: WebSocket token: ${authid != null ? 'exists' : 'null'}",
    );

    if (authid == null || authid.isEmpty) {
      if (kDebugMode) {
        print(
          'Instruments: WebSocket token is null or empty, skipping request (user not logged in)',
        );
      }
      // Don't retry if user is not logged in
      return;
    }

    // Get the active MT5 account number from account controller
    final accountController = Get.find<AccountController>();
    final activeAccount = accountController.activeMT5Account;
    final accountNumber = activeAccount?.metaAccountNumber ?? "0";

    print("Instruments: Using MT5 Account Number: $accountNumber");

    // Send different event based on trading_server
    // ✅ PERFORMANCE: Request binary format for improved performance (50-70% smaller, 5-10x faster)
    if (_isMT5Account()) {
      // MT5 account: send join_market event with actual group name
      final groupName = await _getMT5GroupName();
      print(
        "Instruments: Sending join_market event for MT5 account with group: $groupName",
      );
      // sendEvent({"type": "join_market", "group": groupName});
      sendEvent({
        "authID": authid,
        "trading_account": accountNumber,
        "format": "binary", // Request binary format
      });
    } else {
      // Default: send authID and trading_account
      sendEvent({
        "authID": authid,
        "trading_account": accountNumber,
        "format": "binary", // Request binary format
      });
    }
  }

  void updateFromJson(dynamic message) {
    try {
      // ✅ PERFORMANCE: Handle both JSON and binary (MessagePack) formats
      // WebSocket can send either String (JSON) or Uint8List (binary)
      dynamic decodedData;

      if (MessagePackDecoder.isBinaryMessage(message)) {
        // Binary MessagePack format - decode it
        if (kDebugMode) {
          final sizeInfo = MessagePackDecoder.getMessageSize(message);
          WebSocketEndpointHelper.logSwitchStep(
            'Instruments first snapshot',
            url: _currentWsUrl,
            payload: {'sizeKB': sizeInfo['sizeKB']},
          );
        }
        decodedData = MessagePackDecoder.decodeBinary(
          message is Uint8List
              ? message
              : Uint8List.fromList(message as List<int>),
        );

        if (decodedData == null) {
          return;
        }
      } else {
        // JSON format - decode as string
        final jsonStr = message is String ? message : message.toString();
        decodedData = jsonDecode(jsonStr);
      }

      // ✅ Handle JSON object responses (authentication, errors, etc.)
      if (decodedData is Map<String, dynamic>) {
        _handleJsonResponse(decodedData);
        return;
      }

      // ✅ Handle array responses (price updates)
      // STEP 1: Initial snapshot (array of arrays) - comes first
      // STEP 3: Real-time updates (array of arrays) - comes after confirmation
      // Format: [symbol, bid, ask, spread_points, digits, day_high, day_low, category]
      if (decodedData is List && decodedData.isNotEmpty) {
        // Array of arrays (multiple instruments)
        if (decodedData[0] is List) {
          _parseNewFormat(decodedData);
        }
        // Single array (one instrument update)
        else if (decodedData[0] is String && decodedData.length >= 5) {
          _parseSingleInstrument(decodedData);
        }
        return;
      }

      // Fallback: Try old JSON format (only if it's actually a Map)
      if (decodedData is Map<String, dynamic>) {
        try {
          final SocketResponse socketResponse = SocketResponse.fromJson(
            decodedData,
          );

          final List<ListElement> allItems = [];
          final Map<String, List<ListElement>> map = {};
          final Set<String> uniqueCategories = {};

          for (final group in socketResponse.groups) {
            var groupName = group.groupName;

            if (groupName.toLowerCase() == 'fx cross' ||
                groupName.toLowerCase() == 'fxcross') {
              groupName = 'Forex';
            }
            if (groupName.toLowerCase() == 'currency') {
              groupName = 'Forex';
            }

            if (!map.containsKey(groupName)) {
              map[groupName] = [];
            }
            map[groupName]!.addAll(group.list);

            if (groupName.isNotEmpty) {
              uniqueCategories.add(groupName);
            }
          }

          tradingGroups.value = map;

          for (final group in socketResponse.groups) {
            allItems.addAll(group.list);
          }

          _updateInstrumentsList(allItems);

          // ✅ Update trading groups and available filters
          _updateTradingGroups(allInstruments);

          // ✅ Apply current filter and sort
          _updateFilteredInstruments();
        } catch (e) {
          print('Error parsing old format: $e');
        }
      }
    } catch (e, t) {
      print('Error parsing JSON: $e\n $t');
    }
  }

  void _handleJsonResponse(Map<String, dynamic> data) {
    final type = data['type']?.toString();

    // Account group changed on server (e.g. admin changed group): resubscribe to get new spreads/market watch
    // Same behaviour as crmfrontend: unsubscribe then resubscribe with same account so server sends new group data
    if (type == 'group_changed') {
      print(
        '🔄 InstrumentsController: Group changed on server, resubscribing to refresh market watch',
      );
      Future.microtask(() => _onGroupChanged());
      return;
    }

    // Handle unsubscribe confirmation
    if (type == 'marketwatch_left') {
      print('✅ Unsubscribed from market watch');
      if (_unsubscribeCompleter != null &&
          !_unsubscribeCompleter!.isCompleted) {
        _unsubscribeCompleter!.complete();
        _unsubscribeCompleter = null;
      }
      return;
    }

    // Handle STEP 2: Confirmation message (subscribed_pricing)
    // Note: This comes AFTER the initial snapshot (STEP 1)
    if (type == 'subscribed_pricing') {
      final status = data['status']?.toString();
      final pricesCount = data['prices_count'];
      final totalSymbols = data['total_symbols'];
      final tradingAccount = data['trading_account'];
      final isReconnection = data['is_reconnection'] ?? false;

      if (status == 'ok') {
        print('✅ Instruments: Subscribed to pricing');
        print('   Account: $tradingAccount');
        print('   Prices count: $pricesCount / Total symbols: $totalSymbols');
        print('   Is reconnection: $isReconnection');

        // Confirmation received - initial snapshot should have been processed already
        // Next arrays will be real-time updates (STEP 3)
        _isInitialSnapshot = false;

        // ✅ Clear reconnection flag after successful subscription
        if (_isReconnecting) {
          _isReconnecting = false;
          print('✅ Reconnection complete - normal updates resumed');
        }

        // Set connected state after successful subscription
        if (!isConnected.value) {
          isConnected.value = true;
        }
      }
      return;
    }

    // Handle authentication success messages
    if (type == 'marketwatch_joined' ||
        type == 'symbol_joined' ||
        type == 'authenticated') {
      final status = data['status']?.toString();
      final message = data['message']?.toString();

      if (status == 'success') {
        print('✅ WebSocket authenticated: $message');
        if (type == 'marketwatch_joined') {
          print(
            '✅ Subscribed to market watch for account: ${data['trading_account']}',
          );
        } else if (type == 'symbol_joined') {
          print('✅ Subscribed to symbol: ${data['symbol']}');
        }
      }
      return;
    }

    // Handle error responses
    if (type == 'error') {
      final errorMessage = data['message']?.toString() ?? 'Unknown error';
      print('❌ WebSocket error: $errorMessage');
      // Complete unsubscribe completer even on error to avoid hanging
      if (_unsubscribeCompleter != null &&
          !_unsubscribeCompleter!.isCompleted) {
        _unsubscribeCompleter!.complete();
        _unsubscribeCompleter = null;
      }
      return;
    }

    // Handle other JSON responses (if any)
    print('📨 Received JSON response: $data');
  }

  void _parseNewFormat(List decodedData) {
    final List<ListElement> incomingItems = [];

    for (final item in decodedData) {
      final parsed = _parseInstrumentItem(item);
      if (parsed != null) incomingItems.add(parsed);
    }

    // STEP 1: Initial snapshot - replace all instruments
    // STEP 3: Real-time updates - merge/update only changed symbols
    // ✅ FIX: During reconnection, always use merge logic to preserve prices
    if (_isInitialSnapshot && incomingItems.isNotEmpty && !_isReconnecting) {
      // This is the FIRST initial snapshot (not a reconnection) - replace all
      print(
        '═══════════════════════════════════════════════════════════',
      );
      print(
        '📊 INITIAL SNAPSHOT RECEIVED',
      );
      print(
        '   Account: ${_currentAccountNumber ?? "N/A"}',
      );
      print(
        '   Symbols count: ${incomingItems.length}',
      );
      print(
        '   Sample symbols: ${incomingItems.take(5).map((e) => e.symbol).join(", ")}${incomingItems.length > 5 ? "..." : ""}',
      );
      print(
        '═══════════════════════════════════════════════════════════',
      );
      
      // ✅ FIX: Reset clearing flag BEFORE assigning data (allows data processing)
      if (_isClearingData) {
        _isClearingData = false;
        print(
          '✅ Clearing flag reset - data processing enabled',
        );
      }
      
      // ✅ COMPLETE REBUILD: Clear first, then assign new data
      allInstruments.clear();
      allInstruments.assignAll(incomingItems);
      _isInitialSnapshot = false; // Next updates will be real-time

      // Seed reactive prices for all symbols in snapshot.
      for (final it in incomingItems) {
        _applyPriceUpdate(it);
      }
      
      print(
        '✅ Instruments list INSTANTIATED: ${allInstruments.length} total instruments',
      );
      print(
        '   Verified count: ${allInstruments.length == incomingItems.length ? "✅ MATCH" : "❌ MISMATCH"} (expected ${incomingItems.length})',
      );
    } else {
      // Real-time updates: update reactive prices only (no RxList assignAll).
      // Only touch allInstruments/instruments when structure changes (new symbols).
      final existingSymbols = allInstruments.map((e) => e.symbol).toSet();
      bool structureChanged = false;

      for (final newItem in incomingItems) {
        _applyPriceUpdate(newItem);

        if (!existingSymbols.contains(newItem.symbol)) {
          allInstruments.add(newItem);
          existingSymbols.add(newItem.symbol);
          structureChanged = true;
        }
      }

      // ✅ Clear reconnection flag after first successful merge
      if (_isReconnecting) {
        _isReconnecting = false;
        print('✅ Reconnection merge complete - prices preserved');
      }

      // Only update groups/filters when list structure changed.
      if (!structureChanged) {
        return;
      }
    }

    // ✅ Update trading groups and available filters
    _updateTradingGroups(allInstruments);

    // ✅ Apply current filter and sort
    _updateFilteredInstruments();
  }

  void _parseSingleInstrument(List item) {
    final newItem = _parseInstrumentItem(item);
    if (newItem != null) {
      _applyPriceUpdate(newItem);
      // Check if this symbol already exists
      final existingIndex = allInstruments.indexWhere(
        (element) => element.symbol == newItem.symbol,
      );

      if (existingIndex != -1) {
        // Price tick for an existing symbol.
        // ✅ CRITICAL PERF: Do NOT rebuild filtered list here.
        // Prices are displayed via priceRx(symbol), so the UI stays realtime
        // without triggering a full ListView rebuild.
        //
        // Keep structure stable; optionally update metadata if needed,
        // but do not call _updateFilteredInstruments().
        final existing = allInstruments[existingIndex];
        allInstruments[existingIndex] = existing.copyWith(
          // metadata that may change occasionally
          spreadDiff: newItem.spreadDiff,
          digits: newItem.digits,
          category: newItem.category,
          dayHigh: newItem.dayHigh,
          dayLow: newItem.dayLow,
        );
        return;
      } else {
        // ✅ Add brand new instrument
        allInstruments.add(newItem);
      }

      // ✅ Update trading groups and available filters
      _updateTradingGroups(allInstruments);

      // ✅ Apply current filter and sort
      _updateFilteredInstruments();
    }
  }

  ListElement? _parseInstrumentItem(List item) {
    try {
      // New format: [symbol, bid, ask, spread_points, digits, day_high, day_low, category]
      // spread_points is the spread in points (not percentage)
      if (item.length < 5) {
        print(
          "❌ Invalid item format: expected at least 5 elements, got ${item.length}",
        );
        return null;
      }

      final symbol = item[0].toString();
      final bid = double.tryParse(item[1].toString()) ?? 0.0;
      final ask = double.tryParse(item[2].toString()) ?? 0.0;
      final spreadPoints = double.tryParse(item[3].toString()) ?? 0.0;
      final digits = int.tryParse(item[4].toString()) ?? 5;
      // day_high and day_low are at indices 5 and 6
      final dayHigh =
          item.length >= 6 ? (double.tryParse(item[5].toString())) : null;
      final dayLow =
          item.length >= 7 ? (double.tryParse(item[6].toString())) : null;
      final category =
          item.length >= 8
              ? item[7].toString()
              : (item.length >= 6 && dayHigh == null && dayLow == null
                  ? item[5].toString()
                  : null);

      return ListElement(
        symbol: symbol,
        bid: bid,
        ask: ask,
        spreadDiff: spreadPoints, // spread_points from API
        digits: digits,
        last: 0,
        volume: 0,
        volumeReal: 0,
        logo: '',
        category: category,
        dayHigh: dayHigh,
        dayLow: dayLow,
      );
    } catch (e) {
      print("❌ Failed parsing $item — $e");
      return null;
    }
  }

  void _updateTradingGroups(List<ListElement> allItems) {
    final Map<String, List<ListElement>> map = {};
    final Set<String> uniqueCategories = {};

    for (final instrument in allItems) {
      var groupName = instrument.category ?? _inferGroupName(instrument.symbol);

      // Normalize category names
      final lowerName = groupName.toLowerCase();
      if (lowerName == 'fx cross' ||
          lowerName == 'fxcross' ||
          lowerName == 'currency' ||
          lowerName == 'forex') {
        groupName = 'Forex';
      } else if (lowerName == 'metals' || lowerName == 'metal') {
        groupName = 'Metals';
      } else if (lowerName == 'crypto' || lowerName == 'cryptocurrency') {
        groupName = 'Crypto';
      } else if (lowerName == 'indices' || lowerName == 'index') {
        groupName = 'Indices';
      } else if (lowerName == 'commodities' || lowerName == 'commodity') {
        groupName = 'Commodities';
      } else {
        // Capitalize first letter for consistency
        if (groupName.isNotEmpty) {
          groupName =
              groupName[0].toUpperCase() + groupName.substring(1).toLowerCase();
        }
      }

      if (!map.containsKey(groupName)) {
        map[groupName] = [];
      }
      map[groupName]!.add(instrument);

      if (groupName.isNotEmpty) {
        uniqueCategories.add(groupName);
      }
    }

    tradingGroups.value = map;

    // ✅ Update available filters dynamically based on categories
    final List<String> newFilters = ['Favorites'];
    final sortedCategories = uniqueCategories.toList()..sort();
    newFilters.addAll(sortedCategories);
    availableFilters.assignAll(newFilters);
  }

  // Helper method to infer group name from symbol
  String _inferGroupName(String symbol) {
    final upperSymbol = symbol.toUpperCase();

    // Currency pairs
    if (_isCurrencyPair(symbol)) {
      return 'Currency';
    }

    // Metals
    if (upperSymbol.contains('XAU') || upperSymbol.contains('XAG')) {
      return 'Metals';
    }

    // Crypto
    if (upperSymbol.contains('BTC') ||
        upperSymbol.contains('ETH') ||
        upperSymbol.contains('USDT') ||
        upperSymbol.contains('DOGE')) {
      return 'Crypto';
    }

    // Indices
    if (upperSymbol.contains('NAS') ||
        upperSymbol.contains('SPX') ||
        upperSymbol.contains('DOW') ||
        upperSymbol.contains('UK100')) {
      return 'Indices';
    }

    // Commodities
    if (upperSymbol.contains('OIL') || upperSymbol.contains('USIOL')) {
      return 'Commodities';
    }

    return 'Other';
  }

  bool _isCurrencyPair(String symbol) {
    final majorPairs = ['EUR', 'GBP', 'AUD', 'NZD', 'USD', 'CAD', 'CHF', 'JPY'];
    final symbolWithoutSuffix = symbol
        .replaceAll('.c', '')
        .replaceAll('.r', '');

    int matchCount = 0;
    for (final pair in majorPairs) {
      if (symbolWithoutSuffix.contains(pair)) {
        matchCount++;
      }
    }

    // If it contains 2 major currencies, it's likely a currency pair
    return matchCount >= 2 && symbolWithoutSuffix.length <= 6;
  }

  void _updateInstrumentsList(List<ListElement> newInstruments) {
    // Create a map of existing instruments by symbol for quick lookup
    final Map<String, ListElement> existingInstrumentsMap = {};
    for (final instrument in allInstruments) {
      existingInstrumentsMap[instrument.symbol] = instrument;
    }

    // Update or add instruments - preserve order from WebSocket (newInstruments order)
    final List<ListElement> updatedInstruments = [];
    for (final newInstrument in newInstruments) {
      final existingInstrument = existingInstrumentsMap[newInstrument.symbol];
      if (existingInstrument != null) {
        // Update existing instrument with new price data
        final updatedInstrument = existingInstrument.copyWith(
          bid: newInstrument.bid,
          ask: newInstrument.ask,
          last: newInstrument.last,
          volume: newInstrument.volume,
          volumeReal: newInstrument.volumeReal,
          spreadDiff: newInstrument.spreadDiff,
          category: newInstrument.category,
        );
        updatedInstruments.add(updatedInstrument);
      } else {
        // Add new instrument (preserves WebSocket order)
        updatedInstruments.add(newInstrument);
      }
    }

    // Update the observable list (order is preserved from newInstruments)
    allInstruments.assignAll(updatedInstruments.toSet().toList());
  }

  // Send event with parameters over WebSocket
  void sendEvent(Map<String, dynamic> event) {
    try {
      final unified = Get.find<UnifiedWebSocketService>();
      unified.sendEvent(WebSocketChannelType.marketWatch, event);
    } catch (_) {
      final encoded = jsonEncode(event);
      channel.sink.add(encoded);
    }
  }

  @override
  void onClose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Cancel reconnect timer
    _reconnectTimer?.cancel();
    _unifiedMwSub?.cancel();
    _priceFlushTimer?.cancel();
    _scrollIdleTimer?.cancel();

    // Close WebSocket connection when controller disposed
    try {
      channel.sink.close();
    } catch (e) {
      print('Error closing WebSocket: $e');
    }

    super.onClose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('App resumed - checking WebSocket connection');
        // ✅ FIX: Force reconnect even if connected flag says connected
        // The connection might be stale after app was paused
        if (!isConnected.value) {
          // Clear data before reconnecting to ensure fresh data
          clearInstrumentsData();
          _reconnectWebSocket();
        }
        break;
      case AppLifecycleState.paused:
        print('App paused - WebSocket may disconnect');
        break;
      case AppLifecycleState.detached:
        print('App detached - closing WebSocket');
        _disconnectWebSocket();
        break;
      case AppLifecycleState.inactive:
        print('App inactive');
        break;
      case AppLifecycleState.hidden:
        print('App hidden');
        break;
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Instruments: Max reconnection attempts reached');
      isReconnecting.value = false;
      return;
    }

    if (isReconnecting.value) return; // Already scheduled

    _reconnectAttempts++;
    isReconnecting.value = true;

    final delay = _getReconnectDelay();
    print(
      'Instruments: Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s (exponential backoff)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!isConnected.value && !_isConnecting) {
        _reconnectWebSocket();
      } else {
        isReconnecting.value = false;
      }
    });
  }

  void _reconnectWebSocket() {
    if (isConnected.value) return;

    print('🔄 Attempting to reconnect WebSocket...');
    isReconnecting.value = true;
    _isReconnecting = true; // ✅ Mark as reconnection to preserve prices

    try {
      _disconnectWebSocket();
      _initializeWebSocket();
    } catch (e) {
      print('Reconnection failed: $e');
      isReconnecting.value = false;
      _isReconnecting = false; // ✅ Clear flag on error
      _scheduleReconnect();
    }
  }

  void disconnectWebSocket() {
    try {
      channel.sink.close();
      isConnected.value = false;
      isReconnecting.value = false;
      _currentWsUrl = null;
      print('InstrumentsController: WebSocket disconnected');
    } catch (e) {
      print('Error disconnecting WebSocket: $e');
    }
  }

  void _disconnectWebSocket() {
    disconnectWebSocket();
  }

  void loadInstruments() {
    final currencyInstruments =
        allInstruments
            .where(
              (instrument) =>
                  getGroupNameForSymbol(instrument.symbol) == 'Forex',
            )
            .toList();
    instruments.assignAll(currencyInstruments);
    currentFilter.value = 'Forex';
    searchQuery.value = '';
    isSearching.value = false;
  }

  String getGroupNameForSymbol(String symbol) {
    // First, try to find the symbol in trading groups
    for (final entry in tradingGroups.entries) {
      if (entry.value.any((element) => element.symbol == symbol)) {
        return entry.key;
      }
    }

    // If not found in groups, try to find in allInstruments and use its category
    final instrument = allInstruments.firstWhereOrNull(
      (element) => element.symbol == symbol,
    );

    if (instrument != null && instrument.category != null) {
      var category = instrument.category!;
      // Merge "Fx Cross" into "Forex"
      if (category.toLowerCase() == 'fx cross' ||
          category.toLowerCase() == 'fxcross') {
        return 'Forex';
      }
      return category;
    }

    // Fallback to inferring from symbol
    return _inferGroupName(symbol);
  }

  void searchInstruments(String query) {
    searchQuery.value = query;
    isSearching.value = query.isNotEmpty;
    _updateFilteredInstruments();
  }

  void filterInstruments(String filter) {
    currentFilter.value = filter;
    _updateFilteredInstruments();
  }

  void sortInstruments(String sortBy) {
    currentSort.value = sortBy;
    // Reapply sorting using the same helper method
    _applyCurrentSort(instruments);
    // Trigger update by reassigning
    instruments.assignAll(instruments);
  }

  // Load favorites from storage
  Future<void> _loadFavorites() async {
    try {
      isLoadingFavorites.value = true;
      final favorites =
          await FavoritesStorageService.instance.getFavoriteInstruments();
      favoriteInstruments.assignAll(favorites);
      // print('📱 Loaded ${favorites.length} favorite instruments: $favorites');
    } catch (e) {
      print('Error loading favorites: $e');
    } finally {
      isLoadingFavorites.value = false;
    }
  }

  // Toggle favorite status for an instrument
  Future<void> toggleFavorite(String instrumentSymbol) async {
    try {
      // Normalize symbol format - always store with .c suffix for consistency
      final normalizedSymbol =
          instrumentSymbol.endsWith('.c')
              ? instrumentSymbol
              : instrumentSymbol + '.c';

      final success = await FavoritesStorageService.instance.toggleFavorite(
        normalizedSymbol,
      );
      if (success) {
        // Reload favorites to update the list
        await _loadFavorites();
        // Update filtered instruments to reflect changes
        _updateFilteredInstruments();
        // print('Toggled favorite for: $normalizedSymbol');
      }
    } catch (e) {
      print('Error toggling favorite for $instrumentSymbol: $e');
    }
  }

  // Check if an instrument is favorite
  bool isFavorite(String instrumentSymbol) {
    // Check both with and without .c suffix
    final isFav =
        favoriteInstruments.contains(instrumentSymbol) ||
        favoriteInstruments.contains(instrumentSymbol + '.c') ||
        favoriteInstruments.contains(instrumentSymbol.replaceAll('.c', ''));

    // print('🔍 isFavorite check for "$instrumentSymbol": $isFav');
    // print('🔍 Current favorites: $favoriteInstruments');

    return isFav;
  }

  // Add instrument to favorites
  Future<void> addToFavorites(String instrumentSymbol) async {
    try {
      final success = await FavoritesStorageService.instance.addToFavorites(
        instrumentSymbol,
      );
      if (success) {
        await _loadFavorites();
        _updateFilteredInstruments();
        print('Added $instrumentSymbol to favorites');
      }
    } catch (e) {
      print('Error adding $instrumentSymbol to favorites: $e');
    }
  }

  // Remove instrument from favorites
  Future<void> removeFromFavorites(String instrumentSymbol) async {
    try {
      final success = await FavoritesStorageService.instance
          .removeFromFavorites(instrumentSymbol);
      if (success) {
        await _loadFavorites();
        _updateFilteredInstruments();
        print('Removed $instrumentSymbol from favorites');
      }
    } catch (e) {
      print('Error removing $instrumentSymbol from favorites: $e');
    }
  }

  // Get favorites count
  int get favoritesCount => favoriteInstruments.length;

  // Reset to default favorites (useful for testing or user preference)
  Future<void> resetToDefaultFavorites() async {
    try {
      await FavoritesStorageService.instance.resetToDefaultFavorites();
      await _loadFavorites();
      _updateFilteredInstruments();
      print('Reset to default favorites');
    } catch (e) {
      print('Error resetting to default favorites: $e');
    }
  }

  // Force reinitialize with new defaults (useful when default list changes)
  Future<void> forceReinitializeDefaults() async {
    try {
      await FavoritesStorageService.instance.forceReinitializeDefaults();
      await _loadFavorites();
      _updateFilteredInstruments();
      print('Force reinitialized with new defaults');
    } catch (e) {
      print('Error force reinitializing defaults: $e');
    }
  }

  void _updateFilteredInstruments() {
    List<ListElement> filteredInstruments = List.from(allInstruments);

    // If searching, ignore category/favorites filter and search across ALL instruments
    if (searchQuery.value.isNotEmpty) {
      // Search across all instruments regardless of current filter
      filteredInstruments =
          filteredInstruments
              .where(
                (instrument) => instrument.symbol.toLowerCase().contains(
                  searchQuery.value.toLowerCase(),
                ),
              )
              .toList();
    } else {
      // Only apply category/favorites filter when NOT searching
      // Apply category filter
      if (currentFilter.value != 'Favorites') {
        filteredInstruments =
            filteredInstruments
                .where(
                  (instrument) =>
                      getGroupNameForSymbol(instrument.symbol) ==
                      currentFilter.value,
                )
                .toList();
      }

      // Apply favorites filter
      if (currentFilter.value == 'Favorites') {
        filteredInstruments =
            filteredInstruments
                .where((instrument) => isFavorite(instrument.symbol))
                .toList();
      }
    }

    // Apply manual order (only when not searching and sort is Default).
    // Keeps user drag-drop ordering stable across live updates.
    _applyManualOrderIfAny(filteredInstruments);

    // Apply current sort (preserve sort when filters/search change)
    _applyCurrentSort(filteredInstruments);

    // ✅ PERFORMANCE FIX: Detect if list structure changed (items added/removed)
    // vs just prices updated
    final currentSymbols = filteredInstruments.map((i) => i.symbol).toSet();
    final structureChanged =
        currentSymbols.length != _previousFilteredSymbols.length ||
        !currentSymbols.containsAll(_previousFilteredSymbols) ||
        !_previousFilteredSymbols.containsAll(currentSymbols);

    // Update the filtered list (RxList will trigger reactive updates automatically)
    instruments.assignAll(filteredInstruments);

    // ✅ PERFORMANCE FIX: Only call update() when list structure changes
    // Price updates will be handled reactively by RxList, no need for full GetBuilder rebuild
    if (structureChanged) {
      _previousFilteredSymbols = currentSymbols;
      update(); // Only rebuild when items are added/removed
    }
    // Note: Price updates don't need update() - RxList changes trigger Obx automatically
  }

  void _applyManualOrderIfAny(List<ListElement> instrumentsToOrder) {
    if (manualOrderSymbols.isEmpty) return;
    if (searchQuery.value.isNotEmpty) return;
    if (currentSort.value != 'Default') return;

    final orderIndex = <String, int>{};
    for (var i = 0; i < manualOrderSymbols.length; i++) {
      orderIndex[manualOrderSymbols[i]] = i;
    }

    instrumentsToOrder.sort((a, b) {
      final ai = orderIndex[a.symbol];
      final bi = orderIndex[b.symbol];
      if (ai == null && bi == null) return 0;
      if (ai == null) return 1;
      if (bi == null) return -1;
      return ai.compareTo(bi);
    });
  }

  void setManualOrderSymbols(List<String> symbols) {
    manualOrderSymbols.assignAll(symbols);
    _updateFilteredInstruments();
  }

  // Helper method to apply current sort to instruments list
  void _applyCurrentSort(List<ListElement> instrumentsToSort) {
    switch (currentSort.value) {
      case 'Default':
        // Don't sort - keep original order from WebSocket
        break;
      case 'Symbol A-Z':
        instrumentsToSort.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
      case 'Symbol Z-A':
        instrumentsToSort.sort((a, b) => b.symbol.compareTo(a.symbol));
        break;
      default:
        // Default: keep original order from WebSocket
        break;
    }
  }

  // Method to refresh socket data when account changes
  void refreshSocketData() {
    print("Refreshing socket data for new account...");

    // Update current account number
    try {
      final accountController = Get.find<AccountController>();
      _currentAccountNumber =
          accountController.activeMT5Account?.metaAccountNumber;
    } catch (e) {
      print('Error updating account number in refreshSocketData: $e');
    }

    // If not connected, try to reconnect first
    if (!isConnected.value) {
      print("Not connected, attempting to reconnect...");
      _reconnectWebSocket();
    } else {
      // If connected, just send new data
      getSocketdata();
    }
  }

  // Clear instruments data (called when account changes)
  // Note: This method is now called AFTER subscription is cancelled in account change handler
  void clearInstrumentsData() {
    // ✅ FIX: Prevent duplicate clearing - only clear once
    if (_isClearingData) {
      print(
        "⚠️ InstrumentsController: Already clearing data, skipping duplicate clear",
      );
      return;
    }

    _isClearingData = true; // Set flag to prevent duplicate clearing and block data processing
    
    print(
      '═══════════════════════════════════════════════════════════',
    );
    print(
      "🗑️ CLEARING INSTRUMENTS DATA - COMPLETE RESET",
    );
    print(
      "   Account: ${_currentAccountNumber ?? "N/A"}",
    );
    print(
      "   Before clear: Total=${allInstruments.length}, Filtered=${instruments.length}",
    );
    print(
      '═══════════════════════════════════════════════════════════',
    );
    
    // ✅ FIX: Cancel unified subscription FIRST to stop old data flow
    // This is critical when called from AccountController (dashboard switch)
    if (_unifiedMwSub != null) {
      print(
        '   Cancelling unified WebSocket subscription to stop old data...',
      );
      _unifiedMwSub?.cancel();
      _unifiedMwSub = null;
      isConnected.value = false;
    }
    
    // ✅ Clear all data
    allInstruments.clear();
    instruments.clear();
    tradingGroups.clear();
    // Reset filter to 'Favorites' to show favorites from new account
    currentFilter.value = 'Favorites';
    // Clear available filters and rebuild from new account data
    availableFilters.value = ['Favorites'];
    searchQuery.value = '';

    // ✅ Also clear trading data to prevent old positions/orders showing
    try {
      final tradingController = Get.find<TradingController>();
      tradingController.clearAllTradingData();
    } catch (e) {
      print('Error clearing trading data: $e');
    }

    print("✅ InstrumentsController: ALL DATA CLEARED");
    print(
      "   After clear: Total=${allInstruments.length}, Filtered=${instruments.length}",
    );
    
    // ✅ Force UI update to show cleared state
    update();
    
    // Note: _isClearingData flag will be reset when initial snapshot arrives
    // This prevents old data from being processed while clearing
  }

  // Method to manually reconnect (can be called from UI)
  Future<void> manualReconnect() async {
    print("Manual reconnection requested");
    _reconnectAttempts = 0; // Reset attempts for manual reconnect

    // Ensure clean disconnect first
    stopWebSocket();
    await Future.delayed(const Duration(milliseconds: 100));

    // Then reconnect
    if (!isConnected.value && !_isConnecting) {
      _initializeWebSocket();
    }
  }

  /// Called when server sends group_changed (admin changed account's group).
  /// Resubscribes with same account so server sends new group's spread snapshot and market watch.
  Future<void> _onGroupChanged() async {
    String? accountNumber = _currentAccountNumber;
    if (accountNumber == null || accountNumber.isEmpty) {
      try {
        final accountController = Get.find<AccountController>();
        final account = accountController.activeMT5Account;
        accountNumber = account?.metaAccountNumber;
      } catch (_) {}
    }
    if (accountNumber == null || accountNumber.isEmpty) {
      print(
        '⚠️ InstrumentsController: Group changed but no current account, skipping resubscribe',
      );
      return;
    }
    await unsubscribeAndResubscribe(accountNumber);
  }

  // Unsubscribe and resubscribe with new account (keeps socket active)
  Future<void> unsubscribeAndResubscribe(String newAccountNumber) async {
    print(
      '🔄 InstrumentsController: Unsubscribing and resubscribing for account: $newAccountNumber',
    );

    // Update current account number
    _currentAccountNumber = newAccountNumber;

    // Check if URL needs to change (trading_server changed)
    final wasMT5 = _isMT5Account();

    // Get new account to check if trading_server changed
    try {
      final accountController = Get.find<AccountController>();
      final newAccount = accountController.mt5Accounts.firstWhereOrNull(
        (acc) => acc.metaAccountNumber == newAccountNumber,
      );
      final isNowMT5 = newAccount?.tradingServer.toUpperCase() == "MT5";

      // If URL needs to change, close and reconnect
      if (wasMT5 != isNowMT5) {
        print(
          '🔄 InstrumentsController: Trading server changed (was MT5: $wasMT5, now MT5: $isNowMT5), closing and reconnecting',
        );
        stopWebSocket();
        await Future.delayed(const Duration(milliseconds: 150));
        clearInstrumentsData();
        startWebSocket();
        return;
      }
    } catch (e) {
      print('⚠️ InstrumentsController: Error checking trading server: $e');
    }

    // If not connected, just initialize normally
    if (!isConnected.value) {
      print('⚠️ InstrumentsController: Not connected, initializing normally');
      clearInstrumentsData();
      startWebSocket();
      return;
    }

    try {
      // Step 1: Unsubscribe from current market watch
      print(
        '📤 InstrumentsController: Sending {"type": "unsubscribe"} request',
      );
      _unsubscribeCompleter = Completer<void>();
      sendEvent({"type": "unsubscribe"});

      // Step 2: Wait for unsubscribe confirmation (with timeout)
      try {
        await _unsubscribeCompleter!.future.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () {
            print(
              '⚠️ InstrumentsController: Unsubscribe timeout, proceeding anyway',
            );
            if (_unsubscribeCompleter != null &&
                !_unsubscribeCompleter!.isCompleted) {
              _unsubscribeCompleter!.complete();
              _unsubscribeCompleter = null;
            }
          },
        );
      } catch (e) {
        print('⚠️ InstrumentsController: Error waiting for unsubscribe: $e');
      }

      // Step 3: Clear instruments data
      clearInstrumentsData();

      // Step 4: Resubscribe with new account (using appropriate event)
      print(
        '📤 InstrumentsController: Resubscribing with new account: $newAccountNumber',
      );

      // ✅ FIX: Add small delay to ensure unsubscribe is fully processed
      await Future.delayed(const Duration(milliseconds: 100));

      if (_isMT5Account()) {
        // MT5 account: send join_market event with actual group name
        final groupName = await _getMT5GroupName();
        print(
          "InstrumentsController: Sending join_market event for MT5 account with group: $groupName",
        );
        sendEvent({"type": "join_market", "group": groupName});
      } else {
        // Default: send authID and trading_account
        final authid = await SecureStorageService.getAuthToken();
        if (authid != null && authid.isNotEmpty) {
          sendEvent({"authID": authid, "trading_account": newAccountNumber});
        } else {
          print(
            '❌ InstrumentsController: No auth token available for resubscribe',
          );
        }
      }

      // ✅ FIX: Request instrument data after resubscription to ensure data loads
      Future.delayed(const Duration(milliseconds: 100), () {
        if (isConnected.value) {
          getSocketdata();
        }
      });

      print('✅ InstrumentsController: Resubscribed successfully');
    } catch (e) {
      print('❌ InstrumentsController: Error in unsubscribeAndResubscribe: $e');
      // Fallback: if unsubscribe/resubscribe fails, do full reconnect
      stopWebSocket();
      await Future.delayed(const Duration(milliseconds: 100));
      clearInstrumentsData();
      startWebSocket();
    }
  }
}

class InstrumentPrice {
  final double bid;
  final double ask;
  final int digits;
  final double spreadDiff;
  final double? dayHigh;
  final double? dayLow;

  const InstrumentPrice({
    required this.bid,
    required this.ask,
    required this.digits,
    required this.spreadDiff,
    this.dayHigh,
    this.dayLow,
  });

  factory InstrumentPrice.empty() => const InstrumentPrice(
    bid: 0.0,
    ask: 0.0,
    digits: 5,
    spreadDiff: 0.0,
  );

  InstrumentPrice copyWith({
    double? bid,
    double? ask,
    int? digits,
    double? spreadDiff,
    double? dayHigh,
    double? dayLow,
  }) {
    return InstrumentPrice(
      bid: bid ?? this.bid,
      ask: ask ?? this.ask,
      digits: digits ?? this.digits,
      spreadDiff: spreadDiff ?? this.spreadDiff,
      dayHigh: dayHigh ?? this.dayHigh,
      dayLow: dayLow ?? this.dayLow,
    );
  }
}
