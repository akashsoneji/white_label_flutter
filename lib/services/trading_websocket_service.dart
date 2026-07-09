import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/services/account_switch_logger.dart'; // ✅ ADD: File-based logging
import 'package:crm_app/utils/message_pack_decoder.dart'; // ✅ ADD: For binary decoding
import 'package:crm_app/utils/app_logger.dart'; // ✅ CENTRALIZED: Logging
import 'package:crm_app/utils/date_helper.dart'; // ✅ UTC timezone support
import 'package:web_socket_channel/web_socket_channel.dart';

class TradingWebSocketService extends GetxService with WidgetsBindingObserver {
  // Connection state - support multiple concurrent connections
  final RxBool isConnected = false.obs;
  final RxBool isReconnecting = false.obs;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  // ✅ FIX: Heartbeat ping timer to keep connection alive
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  bool _isDisposed = false;
  bool _isConnecting = false; // Guard to prevent concurrent connections

  // WebSocket channel for main connection
  WebSocketChannel? _channel;

  // Separate channels for main (positions + orders), market watch, and symbols
  WebSocketChannel?
  _openPositionsChannel; // Main channel (handles both positions and orders)
  WebSocketChannel?
  _pendingOrdersChannel; // Separate channel for pending orders
  WebSocketChannel? _marketWatchChannel;
  WebSocketChannel? _symbolsChannel;

  // Connection state for each channel
  final RxBool isOpenPositionsConnected = false.obs;
  final RxBool isPendingOrdersConnected = false.obs;
  final RxBool isMarketWatchConnected = false.obs;
  final RxBool isSymbolsConnected = false.obs;
  bool _isConnectingOpenPositions = false;
  bool _isConnectingPendingOrders = false;
  bool _isConnectingSymbols = false;
  bool _loggedFirstMessage = false;

  // Reconnect state for each channel
  Timer? _openPositionsReconnectTimer;
  Timer? _pendingOrdersReconnectTimer;
  Timer? _marketWatchReconnectTimer;
  Timer? _symbolsReconnectTimer;
  int _openPositionsReconnectAttempts = 0;
  int _pendingOrdersReconnectAttempts = 0;
  int _marketWatchReconnectAttempts = 0;
  int _symbolsReconnectAttempts = 0;

  // Subscription state tracking
  Timer? _subscriptionRefreshTimer;
  Timer? _dataRetryTimer;
  DateTime? _lastDataReceived;
  // Track account used for last subscription to drop stale frames
  String? _lastSubscribedAccount;
  // Session gating to ignore late frames from previous connections
  int _sessionId = 0;
  int _activeSessionId = 0;

  // Normalize account numbers (string/int, leading zeros) for safe comparison
  bool _accountMatches(String? expected, String actual) {
    if (expected == null || expected.isEmpty) return true;
    if (expected == actual) return true;
    final ei = int.tryParse(expected);
    final ai = int.tryParse(actual);
    if (ei != null && ai != null && ei == ai) return true;
    return false;
  }

  // ✅ Track removed trades to prevent re-adding from WebSocket
  // Only used to filter batch responses, NOT individual add/update messages
  final Set<String> _removedPositionIds = {};
  final Map<String, double> _removedPositionVolumes = {}; // Track volume at removal
  final Map<String, DateTime> _removedPositionTimes = {}; // Track removal time
  final Set<int> _removedPendingOrderIds = {};

  // Debounce timer to prevent rapid updates causing flickering
  Timer? _updateDebounceTimer;

  // Unsubscribe/resubscribe state
  Completer<void>? _unsubscribeCompleter;

  // Track current endpoint to avoid unnecessary reconnections
  String? _currentEndpoint;

  // ✅ FIX: Store all StreamSubscription references to prevent memory leaks
  StreamSubscription? _mainChannelSubscription;
  StreamSubscription? _openPositionsSubscription;
  StreamSubscription? _pendingOrdersSubscription;
  StreamSubscription? _marketWatchSubscription;
  StreamSubscription? _symbolsSubscription;
  StreamSubscription? _accountChangeSubscription;

  // Controllers
  late TradingController _tradingController;
  late AccountController _accountController;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // Initialize controllers
    _tradingController = Get.find<TradingController>();
    _accountController = Get.find<AccountController>();

    // ✅ FIX: Check authentication before initializing WebSocket
    // Don't start WebSocket connections until user is logged in
    _checkAuthAndConnect();
  }

  /// Check authentication status before connecting WebSocket
  void _checkAuthAndConnect() async {
    try {
      final isLoggedIn = await SecureStorageService.isUserLoggedIn();
      if (!isLoggedIn) {
        AppLogger.websocket(
          'User not logged in, skipping WebSocket initialization',
        );
        // Listen for authentication state changes
        _listenForAuthChanges();
        return;
      }

      // User is authenticated - proceed with connection
      _waitForAccountAndConnect();
    } catch (e) {
      AppLogger.error('Trading WS: Error checking auth status', error: e);
    }
  }

  /// Listen for authentication state changes and connect when user logs in
  void _listenForAuthChanges() {
    try {
      final authController = Get.find<AuthController>();
      // Listen to authentication state changes
      // Check periodically if user logs in (since _isAuthenticated is private)
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        if (authController.isAuthenticated) {
          timer.cancel();
          AppLogger.websocket('User logged in, initializing WebSocket');
          _waitForAccountAndConnect();
        }
      });
    } catch (e) {
      AppLogger.error('Trading WS: Error setting up auth listener', error: e);
    }
  }

  /// Wait for AccountController to load account data, then connect with correct endpoint
  void _waitForAccountAndConnect() async {
    try {
      // Initialize account switch logger for file-based logging
      await AccountSwitchLogger.initialize();
      await AccountSwitchLogger.cleanupOldLogs();

      // ✅ FIX: Check persistent cache first for immediate connection
      final cachedAccount =
          await WebSocketEndpointHelper.getStoredPrimaryAccount();
      if (cachedAccount != null) {
        AppLogger.websocket(
          'Using cached account ${cachedAccount.metaAccountNumber} for immediate connection',
        );
        _initializeWebSocket();
        _initializeAllConnections();
        return;
      }

      // Fallback to waiting for AccountController if no cache
      // Wait for account controller to finish loading accounts from API
      await _accountController.waitForInitialization();

      if (_isDisposed) return;

      final activeAccount = _accountController.activeMT5Account;
      if (activeAccount != null) {
        // Account loaded - connect with correct endpoints
        _initializeWebSocket();
        _initializeAllConnections();
      } else {
        // No account yet - listen for account changes
        // ✅ FIX: Cancel old subscription before creating new one
        _accountChangeSubscription?.cancel();
        _accountChangeSubscription = _accountController.activeMT5AccountRx.listen((
          account,
        ) {
          if (account != null && !_isDisposed) {
            final currentAccountNumber = account.metaAccountNumber;

            // ✅ FIX: Handle all account switch cases:
            // 1. Account type change (self-hosted ↔ MT5)
            // 2. Account number change within same type (self-hosted 100 → 102, MT5 1002 → 1003)
            final accountNumberChanged =
                _lastSubscribedAccount != null &&
                _lastSubscribedAccount != currentAccountNumber;

            if (!isConnected.value) {
              // Not connected - initialize normally
              _initializeWebSocket();
              _initializeAllConnections();
            } else if (accountNumberChanged) {
              // ✅ FIX: Account number changed (same or different type) - clear data and resubscribe
              // Clear data first, then resubscribe
              if (Get.isRegistered<TradingController>()) {
                final tradingController = Get.find<TradingController>();
                tradingController.clearAllTradingData();
              }
              unsubscribeAndResubscribe();
            }
            // If same account number and already connected, no action needed
          }
        });
      }
    } catch (e) {
      AppLogger.error('Trading WS: Error waiting for account', error: e);
      // Fallback: connect with default endpoint after short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isDisposed && !isConnected.value) {
          _initializeWebSocket();
          _initializeAllConnections();
        }
      });
    }
  }

  /// Initialize all WebSocket connections simultaneously for fast data loading
  /// Connect main channel and marketwatch - main channel handles both positions and orders
  void _initializeAllConnections() {
    // Connect main channel (handles both positions and orders) and marketwatch
    _connectToMarketWatch();
    _connectToOpenPositions();
    // Note: Pending orders are handled by main channel (/ws/op)
    // Note: Symbols connection is lazy-loaded when chart screen opens
  }

  @override
  void onClose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    // ✅ FIX: Cancel account change listener to prevent memory leaks
    _accountChangeSubscription?.cancel();
    _accountChangeSubscription = null;

    _disconnectWebSocket();
    _disconnectOpenPositions();
    _disconnectPendingOrders();
    _disconnectMarketWatch();
    _disconnectSymbols();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Connection state is centrally coordinated by AccountController to prevent race conditions and duplicate connections.
    return;
  }

  // Initialize WebSocket connection - always use unified /ws/op endpoint
  // Main channel handles both positions and orders (batched)
  void _initializeWebSocket() {
    // ✅ Always use unified endpoint - account type detection happens on Trade Engine side
    final endpoint = WebSocketEndpointHelper.getOpenPositionsEndpoint(null);

    // Use centralized helper to get full URL
    final wsUrl = WebSocketEndpointHelper.getFullUrl(endpoint);

    // Check if already connected to the same endpoint
    if (isConnected.value && _currentEndpoint == wsUrl) {
      return;
    }

    // If connected to different endpoint, disconnect first
    if (isConnected.value && _currentEndpoint != wsUrl) {
      _disconnectWebSocket();
      // Wait a bit for clean disconnect - reduced for real-time trading
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!_isDisposed) {
          _connectToEndpoint(
            wsUrl,
            0,
          ); // Tab doesn't matter - unified endpoint handles both
        }
      });
      return;
    }

    // Not connected, connect now
    if (!isConnected.value) {
      _connectToEndpoint(
        wsUrl,
        0,
      ); // Tab doesn't matter - unified endpoint handles both
    }
  }

  // Connect to a specific endpoint
  Future<void> _connectToEndpoint(String wsUrl, int tab) async {
    if (_isConnecting) {
      return;
    }

    try {
      _loggedFirstMessage = false;
      _isConnecting = true;
      // Increment session and mark active
      _activeSessionId = ++_sessionId;

      // Create WebSocket connection
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _currentEndpoint = wsUrl;
      isConnected.value = true;
      _reconnectAttempts = 0;
      isReconnecting.value = false;

      // ✅ FIX: Cancel old subscription before creating new one
      _mainChannelSubscription?.cancel();
      // Listen to messages
      _mainChannelSubscription = _channel!.stream.listen(
        (message) => _handleSocketMessageWithSession(_activeSessionId, message),
        onError: (error) {
          AppLogger.error('Trading WS error', error: error);
          isConnected.value = false;
          _currentEndpoint = null;
          _isConnecting = false;
          _scheduleReconnect();
        },
        onDone: () {
          AppLogger.websocket('Trading WS: Connection closed');
          isConnected.value = false;
          _currentEndpoint = null;
          _isConnecting = false;
          _scheduleReconnect();
        },
      );

      // Request trading data after connection
      Future.delayed(const Duration(milliseconds: 100), () {
        if (isConnected.value && !_isDisposed) {
          _requestTradingData();
          _startPeriodicRefresh();
        }
        _isConnecting = false;
      });
    } catch (e) {
      AppLogger.error('Trading WS: Initialization failed', error: e);
      isConnected.value = false;
      _currentEndpoint = null;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  // Wrapper to drop frames from old sessions
  void _handleSocketMessageWithSession(int session, dynamic message) {
    if (_isDisposed) return;
    if (session != _activeSessionId) {
      // Stale frame from previous connection
      return;
    }
    if (!_loggedFirstMessage) {
      _loggedFirstMessage = true;
      WebSocketEndpointHelper.logSwitchStep(
        'Trading first message',
        url: _currentEndpoint,
      );
    }
    _handleSocketMessage(message);
  }

  // Request trading data from WebSocket
  void _requestTradingData() async {
    if (_isDisposed || !isConnected.value) {
      if (kDebugMode) {
        // dev.log('Trading WS: Cannot request data - disposed or not connected');
      }
      return;
    }

    // ✅ CLEANUP: Remove stale entries from zombie filter maps (older than 30s)
    final now = DateTime.now();
    _removedPositionTimes.removeWhere((id, time) {
      final isStale = now.difference(time).inSeconds > 30;
      if (isStale) {
        _removedPositionVolumes.remove(id);
        _removedPositionIds.remove(id);
      }
      return isStale;
    });

    // Use getAuthToken for /ws/op endpoint (same as other new endpoints)
    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) {
      if (kDebugMode) {
        // dev.log('Trading WS: No auth token, retrying in 2 seconds...');
      }
      Timer(const Duration(seconds: 2), () {
        if (isConnected.value && !_isDisposed) {
          _requestTradingData();
        }
      });
      return;
    }

    final activeAccount = _accountController.activeMT5Account;
    var accountNumber = activeAccount?.metaAccountNumber ?? "0";

    // ✅ FIX: If account is null/empty, check cached account before giving up
    if (accountNumber == "0" || accountNumber.isEmpty) {
      final cachedAccount =
          await WebSocketEndpointHelper.getStoredPrimaryAccount();
      if (cachedAccount != null) {
        accountNumber = cachedAccount.metaAccountNumber;
        AppLogger.websocket(
          'Using cached account $accountNumber instead of null/empty account',
        );
      } else {
        // No cached account either - don't send null request
        AppLogger.websocket(
          'No account available (active or cached), skipping request to prevent null account data',
        );
        Timer(const Duration(seconds: 2), () {
          if (isConnected.value && !_isDisposed) {
            _requestTradingData();
          }
        });
        return;
      }
    }

    WebSocketEndpointHelper.logSwitchStep(
      'Trading subscribe',
      url: _currentEndpoint,
      payload: {"authID": authId, "trading_account": accountNumber},
    );

    // ✅ Unified endpoint: main channel (/ws/op) handles both positions and orders
    // No need to check tab or separate endpoints - always use same subscription
    final payload = {"authID": authId, "trading_account": accountNumber};
    _sendEvent(payload);
    _lastSubscribedAccount = accountNumber;

    // Set up retry timer if no data received within 3 seconds
    _setupDataRetryTimer();
  }

  // Setup retry timer if data doesn't arrive
  void _setupDataRetryTimer() {
    _dataRetryTimer?.cancel();
    _dataRetryTimer = Timer(const Duration(seconds: 3), () async {
      if (_isDisposed || !isConnected.value) return;

      // Check if we received data after last subscription
      if (_lastDataReceived == null ||
          DateHelper.nowUtc().difference(_lastDataReceived!).inSeconds > 2) {
        // Retry subscription - unified endpoint handles both positions and orders
        final activeAccount = _accountController.activeMT5Account;
        final accountNumber = activeAccount?.metaAccountNumber ?? "0";
        final authId = await SecureStorageService.getAuthToken();
        if (authId != null && authId.isNotEmpty) {
          _sendEvent({"authID": authId, "trading_account": accountNumber});
        } else {
          _sendEvent({
            "type": "subscribe_all_groups",
            "account": accountNumber,
          });
        }

        // Setup another retry if still no data
        _setupDataRetryTimer();
      }
    });
  }

  // Start periodic refresh to maintain subscription
  void _startPeriodicRefresh() {
    _subscriptionRefreshTimer?.cancel();
    // Refresh subscription every 30 seconds to maintain connection
    _subscriptionRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) {
      if (_isDisposed || !isConnected.value) {
        timer.cancel();
        return;
      }
      _requestTradingData();
    });
  }

  // Refresh data based on current tab - reconnect to ensure correct endpoint
  void refreshDataForCurrentTab() {
    if (_isDisposed) {
      return;
    }

    // Cancel retry timer since we're manually refreshing
    _dataRetryTimer?.cancel();

    // ✅ FIX: Check account type to determine correct endpoint (MT5 vs self-hosted)
    final activeAccount = _accountController.activeMT5Account;

    // ✅ Always use unified endpoint - main channel handles both positions and orders
    final expectedEndpoint = WebSocketEndpointHelper.getOpenPositionsUrl(
      activeAccount,
    );

    // Check if already connected to correct endpoint
    if (isConnected.value && _currentEndpoint == expectedEndpoint) {
      // Just refresh the subscription without reconnecting
      _requestTradingData();
      return;
    }

    // Need to reconnect to correct endpoint
    _initializeWebSocket();
  }

  // Ensure WebSocket is connected to pending orders endpoint
  // This is called before navigating to pending tab to pre-connect
  Future<void> ensurePendingOrdersConnection() async {
    if (_isDisposed) {
      if (kDebugMode) {
        // dev.log('Trading WS: Cannot ensure pending connection - disposed');
      }
      return;
    }

    final activeAccount = _accountController.activeMT5Account;
    if (activeAccount == null) {
      return;
    }

    final expectedEndpoint = WebSocketEndpointHelper.getPendingOrdersUrl(
      activeAccount,
    );

    // Check if already connected to correct endpoint
    if (isPendingOrdersConnected.value &&
        _currentEndpoint == expectedEndpoint) {
      // Just refresh the subscription without reconnecting
      _requestPendingOrdersData();
      return;
    }

    // Need to connect to pending orders endpoint
    _initializePendingOrdersWebSocket();
  }

  // Ensure WebSocket is connected to open positions endpoint
  // This is called before navigating to market tab to pre-connect
  Future<void> ensureOpenPositionsConnection() async {
    if (_isDisposed) {
      return;
    }

    final activeAccount = _accountController.activeMT5Account;
    if (activeAccount == null) {
      return;
    }

    final currentAccountNumber = activeAccount.metaAccountNumber;

    // ✅ FIX: If account changed, disconnect and reconnect to ensure clean state
    if (isOpenPositionsConnected.value && _openPositionsChannel != null) {
      // Check if account changed - if so, reconnect
      if (_lastSubscribedAccount != null &&
          _lastSubscribedAccount != currentAccountNumber) {
        // Account changed - disconnect and reconnect
        _openPositionsChannel?.sink.close();
        isOpenPositionsConnected.value = false;
        _openPositionsSubscription?.cancel();
        _openPositionsSubscription = null;
        _openPositionsChannel = null;
        // Small delay to ensure connection is fully closed
        await Future.delayed(const Duration(milliseconds: 50));
        _connectToOpenPositions();
        return;
      }
      // Same account - just refresh subscription
      _requestOpenPositionsData();
      return;
    }

    // Not connected - connect now
    _connectToOpenPositions();
  }

  // Connect to open positions endpoint with conditional MT5 prefix
  void _connectToOpenPositions() {
    if (_isDisposed || _isConnectingOpenPositions) return;

    final activeAccount = _accountController.activeMT5Account;

    // ✅ Validate account exists before determining endpoint
    if (activeAccount == null) {
      AppLogger.websocket(
        'Cannot connect to open positions - no active account',
      );
      return;
    }

    // ✅ Use centralized endpoint helper
    final openPositionsUrl = WebSocketEndpointHelper.getOpenPositionsUrl(
      activeAccount,
    );

    // Check if already connected
    if (isOpenPositionsConnected.value && _openPositionsChannel != null) {
      _requestOpenPositionsData();
      return;
    }

    try {
      _isConnectingOpenPositions = true;
      _openPositionsChannel = WebSocketChannel.connect(
        Uri.parse(openPositionsUrl),
      );
      isOpenPositionsConnected.value = true;
      _openPositionsReconnectAttempts = 0;

      // ✅ FIX: Start heartbeat to keep connection alive
      _startHeartbeat();

      // ✅ FIX: Cancel old subscription before creating new one
      _openPositionsSubscription?.cancel();
      _openPositionsSubscription = _openPositionsChannel!.stream.listen(
        (message) {
          if (_isDisposed) return;
          _handleOpenPositionsMessage(message);
        },
        onError: (error) {
          AppLogger.error(
            'Trading WS: Open positions connection error',
            error: error,
          );
          isOpenPositionsConnected.value = false;
          _scheduleOpenPositionsReconnect();
        },
        onDone: () {
          AppLogger.websocket('Trading WS: Open positions connection closed');
          isOpenPositionsConnected.value = false;
          if (!_isDisposed) {
            _scheduleOpenPositionsReconnect();
          }
        },
        cancelOnError: false,
      );

      // Request data immediately to avoid any visible lag on Market tab
      _requestOpenPositionsData();
      // Fire a quick follow-up in case the socket wasn't ready on the first send
      Future.delayed(const Duration(milliseconds: 150), () {
        if (isOpenPositionsConnected.value && !_isDisposed) {
          _requestOpenPositionsData();
        }
      });

      _isConnectingOpenPositions = false;
    } catch (e) {
      _isConnectingOpenPositions = false;
      AppLogger.error(
        'Trading WS: Error connecting to open positions',
        error: e,
      );
      _scheduleOpenPositionsReconnect();
    }
  }

  // Initialize pending orders WebSocket connection
  void _initializePendingOrdersWebSocket() {
    final activeAccount = _accountController.activeMT5Account;
    if (activeAccount == null) {
      return;
    }

    final endpoint = WebSocketEndpointHelper.getPendingOrdersEndpoint(
      activeAccount,
    );
    final wsUrl = WebSocketEndpointHelper.getFullUrl(endpoint);

    // Check if already connected to the same endpoint
    if (isPendingOrdersConnected.value && _currentEndpoint == wsUrl) {
      _requestPendingOrdersData();
      return;
    }

    // If connected to different endpoint, disconnect first
    if (isPendingOrdersConnected.value && _currentEndpoint != wsUrl) {
      _disconnectPendingOrders();
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!_isDisposed) {
          _connectToPendingOrders();
        }
      });
      return;
    }

    // Not connected - connect now
    _connectToPendingOrders();
  }

  // Connect to pending orders endpoint
  void _connectToPendingOrders() {
    if (_isDisposed || _isConnectingPendingOrders) return;

    final activeAccount = _accountController.activeMT5Account;

    if (activeAccount == null) {
      AppLogger.websocket(
        'Cannot connect to pending orders - no active account',
      );
      return;
    }

    final pendingOrdersUrl = WebSocketEndpointHelper.getPendingOrdersUrl(
      activeAccount,
    );

    // Check if already connected
    if (isPendingOrdersConnected.value && _pendingOrdersChannel != null) {
      _requestPendingOrdersData();
      return;
    }

    try {
      _isConnectingPendingOrders = true;
      _pendingOrdersChannel = WebSocketChannel.connect(
        Uri.parse(pendingOrdersUrl),
      );
      isPendingOrdersConnected.value = true;
      _pendingOrdersReconnectAttempts = 0;

      // Cancel old subscription before creating new one
      _pendingOrdersSubscription?.cancel();
      _pendingOrdersSubscription = _pendingOrdersChannel!.stream.listen(
        (message) {
          if (_isDisposed) return;
          _handlePendingOrdersMessage(message);
        },
        onError: (error) {
          AppLogger.error(
            'Trading WS: Pending orders connection error',
            error: error,
          );
          isPendingOrdersConnected.value = false;
          _schedulePendingOrdersReconnect();
        },
        onDone: () {
          AppLogger.websocket('Trading WS: Pending orders connection closed');
          isPendingOrdersConnected.value = false;
          if (!_isDisposed) {
            _schedulePendingOrdersReconnect();
          }
        },
        cancelOnError: false,
      );

      // Request data immediately
      _requestPendingOrdersData();
      // Quick retry shortly after connect
      Future.delayed(const Duration(milliseconds: 150), () {
        if (isPendingOrdersConnected.value && !_isDisposed) {
          _requestPendingOrdersData();
        }
      });

      _isConnectingPendingOrders = false;
    } catch (e) {
      _isConnectingPendingOrders = false;
      AppLogger.error(
        'Trading WS: Error connecting to pending orders',
        error: e,
      );
      _schedulePendingOrdersReconnect();
    }
  }

  // Request pending orders data from WebSocket
  void _requestPendingOrdersData() async {
    if (_isDisposed ||
        !isPendingOrdersConnected.value ||
        _pendingOrdersChannel == null) {
      return;
    }

    try {
      final authId = await SecureStorageService.getAuthToken();
      if (authId == null || authId.isEmpty) {
        return;
      }

      final activeAccount = _accountController.activeMT5Account;
      if (activeAccount == null) {
        return;
      }

      final accountNumber = activeAccount.metaAccountNumber;
      final event = {"authID": authId, "trading_account": accountNumber};

      final encoded = jsonEncode(event);
      _pendingOrdersChannel!.sink.add(encoded);
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error requesting pending orders data',
        error: e,
      );
    }
  }

  // Handle messages from pending orders WebSocket
  void _handlePendingOrdersMessage(dynamic message) {
    if (_isDisposed) return;

    try {
      // Use the existing pending order message handler
      // This handles both JSON and array formats
      _handleSocketMessage(message, isPendingOrderChannel: true);
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error handling pending orders message',
        error: e,
      );
    }
  }

  // Schedule pending orders reconnection
  void _schedulePendingOrdersReconnect() {
    if (_isDisposed ||
        _pendingOrdersReconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    if (_pendingOrdersReconnectTimer?.isActive == true) return;

    _pendingOrdersReconnectAttempts++;
    _pendingOrdersReconnectTimer = Timer(_reconnectDelay, () {
      if (!_isDisposed && !isPendingOrdersConnected.value) {
        _connectToPendingOrders();
      }
    });
  }

  /// Legacy `/ws/marketwatch` — intentionally not opened; pricing for instruments uses
  /// [MarketWatchV2Service]. Restore connection logic here if a feature still needs this channel.
  void _connectToMarketWatch() {}

  /// Ensure Symbols WebSocket is connected (lazy loading)
  /// Call this when user opens chart screen to connect on demand
  void ensureSymbolsConnected() {
    if (_isDisposed) {
      return;
    }

    // Use separate connection for symbols
    if (!isSymbolsConnected.value) {
      _connectToSymbols();
    } else {
      // Already connected, just refresh subscription
      _requestSymbolsData();
    }
  }

  // Connect to symbols endpoint with conditional MT5 prefix
  void _connectToSymbols() {
    if (_isDisposed || _isConnectingSymbols) return;

    final activeAccount = _accountController.activeMT5Account;

    // ✅ Validate account exists before determining endpoint
    if (activeAccount == null) {
      return;
    }

    // ✅ Use centralized endpoint helper
    final symbolsUrl = WebSocketEndpointHelper.getSymbolUrl(activeAccount);

    // Check if already connected
    if (isSymbolsConnected.value && _symbolsChannel != null) {
      _requestSymbolsData();
      return;
    }

    _isConnectingSymbols = true;
    _symbolsReconnectAttempts = 0;

    try {
      _symbolsChannel = WebSocketChannel.connect(Uri.parse(symbolsUrl));
      isSymbolsConnected.value = true;

      // ✅ FIX: Cancel old subscription before creating new one
      _symbolsSubscription?.cancel();
      _symbolsSubscription = _symbolsChannel!.stream.listen(
        (message) => _handleSymbolsMessage(message),
        onError: (error) {
          AppLogger.error('Trading WS: Symbols connection error', error: error);
          isSymbolsConnected.value = false;
          _scheduleSymbolsReconnect();
        },
        onDone: () {
          AppLogger.websocket('Trading WS: Symbols connection closed');
          isSymbolsConnected.value = false;
          if (!_isDisposed) {
            _scheduleSymbolsReconnect();
          }
        },
        cancelOnError: false,
      );

      // Request data after connection
      Future.delayed(const Duration(milliseconds: 500), () {
        _requestSymbolsData();
      });

      _isConnectingSymbols = false;
    } catch (e) {
      _isConnectingSymbols = false;
      AppLogger.error('Trading WS: Error connecting to symbols', error: e);
      _scheduleSymbolsReconnect();
    }
  }

  // Disconnect open positions connection
  void _disconnectOpenPositions() {
    _openPositionsReconnectTimer?.cancel();
    // ✅ FIX: Cancel stream subscription to prevent memory leaks
    _openPositionsSubscription?.cancel();
    _openPositionsSubscription = null;
    try {
      _openPositionsChannel?.sink.close();
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error closing open positions connection',
        error: e,
      );
    }
    _openPositionsChannel = null;
    isOpenPositionsConnected.value = false;
  }

  // Disconnect pending orders connection
  void _disconnectPendingOrders() {
    _pendingOrdersReconnectTimer?.cancel();
    // ✅ FIX: Cancel stream subscription to prevent memory leaks
    _pendingOrdersSubscription?.cancel();
    _pendingOrdersSubscription = null;
    try {
      _pendingOrdersChannel?.sink.close();
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error closing pending orders connection',
        error: e,
      );
    }
    _pendingOrdersChannel = null;
    isPendingOrdersConnected.value = false;
  }

  // Disconnect market watch connection
  void _disconnectMarketWatch() {
    _marketWatchReconnectTimer?.cancel();
    // ✅ FIX: Cancel stream subscription to prevent memory leaks
    _marketWatchSubscription?.cancel();
    _marketWatchSubscription = null;
    try {
      _marketWatchChannel?.sink.close();
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error closing market watch connection',
        error: e,
      );
    }
    _marketWatchChannel = null;
    isMarketWatchConnected.value = false;
  }

  // Disconnect symbols connection
  void _disconnectSymbols() {
    _symbolsReconnectTimer?.cancel();
    // ✅ FIX: Cancel stream subscription to prevent memory leaks
    _symbolsSubscription?.cancel();
    _symbolsSubscription = null;
    try {
      _symbolsChannel?.sink.close();
    } catch (e) {
      AppLogger.error('Trading WS: Error closing symbols connection', error: e);
    }
    _symbolsChannel = null;
    isSymbolsConnected.value = false;
  }

  // Schedule reconnect for open positions
  void _scheduleOpenPositionsReconnect() {
    if (_isDisposed ||
        _openPositionsReconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _openPositionsReconnectTimer?.cancel();
    _openPositionsReconnectAttempts++;

    _openPositionsReconnectTimer = Timer(_reconnectDelay, () {
      if (!_isDisposed) {
        _connectToOpenPositions();
      }
    });
  }

  // Schedule reconnect for market watch (legacy channel disabled — kept for reference)
  // ignore: unused_element
  void _scheduleMarketWatchReconnect() {
    if (_isDisposed || _marketWatchReconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _marketWatchReconnectTimer?.cancel();
    _marketWatchReconnectAttempts++;

    _marketWatchReconnectTimer = Timer(_reconnectDelay, () {
      if (!_isDisposed) {
        _connectToMarketWatch();
      }
    });
  }

  // Schedule reconnect for symbols
  void _scheduleSymbolsReconnect() {
    if (_isDisposed || _symbolsReconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _symbolsReconnectTimer?.cancel();
    _symbolsReconnectAttempts++;

    _symbolsReconnectTimer = Timer(_reconnectDelay, () {
      if (!_isDisposed) {
        _connectToSymbols();
      }
    });
  }

  // ✅ FIX: Start heartbeat to keep WebSocket connections alive
  void _startHeartbeat() {
    _stopHeartbeat(); // Clear any existing timer
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _sendHeartbeatPing();
    });
    AppLogger.websocket('Trading WS: Heartbeat started (30s interval)');
  }

  // ✅ FIX: Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ✅ FIX: Send ping to all open channels
  void _sendHeartbeatPing() {
    final pingMessage = '{"type":"ping"}';

    try {
      if (_openPositionsChannel != null && isOpenPositionsConnected.value) {
        _openPositionsChannel!.sink.add(pingMessage);
      }
      if (_pendingOrdersChannel != null && isPendingOrdersConnected.value) {
        _pendingOrdersChannel!.sink.add(pingMessage);
      }
      if (_marketWatchChannel != null && isMarketWatchConnected.value) {
        _marketWatchChannel!.sink.add(pingMessage);
      }
      AppLogger.websocket('Trading WS: Heartbeat ping sent');
    } catch (e) {
      AppLogger.error('Trading WS: Heartbeat ping failed', error: e);
    }
  }

  // Request data for open positions
  void _requestOpenPositionsData() async {
    if (!isOpenPositionsConnected.value || _isDisposed) return;

    final account = _accountController.activeMT5Account?.metaAccountNumber;
    if (account == null || account.isEmpty) return;

    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) {
      // Retry after delay if auth token not available
      Future.delayed(const Duration(seconds: 2), () {
        if (isOpenPositionsConnected.value && !_isDisposed) {
          _requestOpenPositionsData();
        }
      });
      return;
    }

    _sendEventToChannel(_openPositionsChannel, {
      "authID": authId,
      "trading_account": account,
      "format": "binary", // ✅ Request binary (MessagePack) format
    });
    _lastSubscribedAccount = account;
  }

  // Handle messages from open positions channel
  void _handleOpenPositionsMessage(dynamic message) {
    _handleSocketMessage(message, isOpenPositionChannel: true);
  }

  // Request market watch data (legacy channel disabled — kept for reference)
  // ignore: unused_element
  void _requestMarketWatchData() async {
    if (_marketWatchChannel == null || _isDisposed) return;

    final activeAccount = _accountController.activeMT5Account;
    final accountNumber = activeAccount?.metaAccountNumber ?? "";

    if (accountNumber.isEmpty) {
      return;
    }

    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) {
      return;
    }

    final event = {
      "authID": authId,
      "trading_account": accountNumber,
      "type": "subscribe_marketwatch",
    };

    _sendEventToChannel(_marketWatchChannel, event);
  }

  // Handle market watch messages (legacy channel disabled — kept for reference)
  // ignore: unused_element
  void _handleMarketWatchMessage(dynamic message) {
    try {
      // ✅ PERFORMANCE: Handle both JSON and binary (MessagePack) formats
      dynamic decodedData;
      if (MessagePackDecoder.isBinaryMessage(message)) {
        // Binary MessagePack format - decode it
        decodedData = MessagePackDecoder.decodeBinary(
          message is Uint8List
              ? message
              : Uint8List.fromList(message as List<int>),
        );
        if (decodedData == null) {
          AppLogger.warning('Trading WS: Market watch binary decode failed');
          return;
        }
      } else {
        // JSON format - decode as string
        final String messageStr = message.toString();
        decodedData = jsonDecode(messageStr);
      }

      // ✅ FIX: Market watch messages are price updates - only block if account transition
      // Price updates don't have account numbers, so we only block during transitions
      if (_lastSubscribedAccount == null) {
        return;
      }

      _handleSocketMessage(decodedData); // Process through main handler
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error handling market watch message',
        error: e,
      );
    }
  }

  // Request symbols data
  void _requestSymbolsData() async {
    if (_symbolsChannel == null || _isDisposed) return;

    final activeAccount = _accountController.activeMT5Account;
    final accountNumber = activeAccount?.metaAccountNumber ?? "";

    if (accountNumber.isEmpty) {
      return;
    }

    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) {
      return;
    }

    final event = {
      "authID": authId,
      "trading_account": accountNumber,
      "type": "subscribe_symbols",
    };

    _sendEventToChannel(_symbolsChannel, event);
  }

  // Handle symbols messages
  void _handleSymbolsMessage(dynamic message) {
    try {
      // ✅ PERFORMANCE: Handle both JSON and binary (MessagePack) formats
      dynamic decodedData;
      if (MessagePackDecoder.isBinaryMessage(message)) {
        // Binary MessagePack format - decode it
        decodedData = MessagePackDecoder.decodeBinary(
          message is Uint8List
              ? message
              : Uint8List.fromList(message as List<int>),
        );
        if (decodedData == null) {
          AppLogger.warning('Trading WS: Symbols binary decode failed');
          return;
        }
      } else {
        // JSON format - decode as string
        final String messageStr = message.toString();
        decodedData = jsonDecode(messageStr);
      }

      _handleSocketMessage(decodedData); // Process through main handler
    } catch (e) {
      AppLogger.error('Trading WS: Error handling symbols message', error: e);
    }
  }

  // Send event to a specific channel
  void _sendEventToChannel(
    WebSocketChannel? channel,
    Map<String, dynamic> event,
  ) {
    // ✅ FIX: Use the passed channel parameter, not _channel
    if (channel == null || _isDisposed) return;

    try {
      final message = jsonEncode(event);
      channel.sink.add(message); // ✅ FIX: Use passed channel, not _channel
      if (kDebugMode) {
        // Commented out to reduce noise - uncomment if needed
        // dev.log('Trading WS: Sent event to channel: $event');
      }
    } catch (e) {
      AppLogger.error('Trading WS: Error sending event to channel', error: e);
    }
  }

  // Send event to WebSocket (legacy method for backward compatibility)
  void _sendEvent(Map<String, dynamic> event) {
    if (!isConnected.value || _isDisposed) return;

    try {
      final message = jsonEncode(event);
      _channel?.sink.add(message); // ✅ CHANGED: Use _channel instead of channel
      if (kDebugMode) {
        // Commented out to reduce noise - uncomment if needed
        // dev.log('Trading WS: Sent event: $event');
      }
    } catch (e) {
      AppLogger.error('Trading WS: Error sending event', error: e);
    }
  }

  // ✅ FIX: Helper function to check if message should be processed based on account
  bool _shouldProcessMessage(dynamic decoded) {
    // If we don't have a subscribed account yet, fall back to the active one
    // so that first ticks after a reconnect aren't dropped as "transition".
    if (_lastSubscribedAccount == null) {
      final activeAccount = _accountController.activeMT5Account;
      final activeAccountNumber = activeAccount?.metaAccountNumber ?? '';
      if (activeAccountNumber.isNotEmpty) {
        _lastSubscribedAccount = activeAccountNumber;
      } else {
        return false;
      }
    }

    final currentAccount =
        _accountController.activeMT5Account?.metaAccountNumber;
    if (currentAccount == null || currentAccount.isEmpty) {
      return false;
    }

    // For array-based messages, check account in the message
    if (decoded is List && decoded.isNotEmpty) {
      // Check if it's a batch message: [["a","op",...], ["u","op",...]]
      if (decoded[0] is List && decoded[0].isNotEmpty) {
        // Batch message - extract account from first item
        final firstItem = decoded[0] as List;
        if (firstItem.length >= 2) {
          final firstElement = firstItem[0].toString();
          final secondElement = firstItem[1].toString();

          String? messageAccount;

          // Check if it's ["a"/"add"/"u", "op"/"po", id, account, ...]
          if ((firstElement == 'a' ||
                  firstElement == 'add' ||
                  firstElement == 'u') &&
              (secondElement == 'op' || secondElement == 'po') &&
              firstItem.length >= 4) {
            // Account is at index 3
            if (firstItem[3] is String) {
              messageAccount = firstItem[3].toString();
            } else if (firstItem[3] is int) {
              messageAccount = firstItem[3].toString();
            }
          }
          // Check if it's ["op", position_id, account, ...] or ["po", order_id, account, ...]
          else if ((firstElement == 'op' || firstElement == 'po') &&
              firstItem.length >= 3) {
            // Account is at index 2
            if (firstItem[2] is String) {
              messageAccount = firstItem[2].toString();
            } else if (firstItem[2] is int) {
              messageAccount = firstItem[2].toString();
            }
          }

          // If we found an account in the batch, validate it
          if (messageAccount != null && messageAccount.isNotEmpty) {
            if (messageAccount != currentAccount &&
                messageAccount != _lastSubscribedAccount) {
              return false;
            }
          }
        }
        // For batch messages, if we can't extract account, allow through (handlers will validate)
        return true;
      }

      // Single array message
      // Check if it's a position/order message with account info
      // Format: ["add"/"a"/"u", "op"/"po", position_id/order_id, account, ...]
      // Or: ["op", position_id, account, ...] (direct format without prefix)
      // Or: ["r", account, position_id] or ["r", position_id, account]
      if (decoded.length >= 3) {
        String? messageAccount;

        // Try to extract account from different message formats
        if (decoded[0] is String && decoded[0].toString() == 'r') {
          // Remove format: ["r", account, position_id] or ["r", position_id, account]
          if (decoded[1] is String && decoded[1].toString().length > 3) {
            // Likely account number (MT5 accounts are usually 6+ digits)
            messageAccount = decoded[1].toString();
          } else if (decoded.length > 2 &&
              decoded[2] is String &&
              decoded[2].toString().length > 3) {
            messageAccount = decoded[2].toString();
          }
        } else {
          // Position/Order format: Check if it's ["a"/"add"/"u", "op"/"po", ...] or ["op", ...]
          final firstElement = decoded[0].toString();
          final secondElement = decoded.length > 1 ? decoded[1].toString() : '';

          // Check if it's ["a"/"add"/"u", "op"/"po", id, account, ...]
          if ((firstElement == 'a' ||
                  firstElement == 'add' ||
                  firstElement == 'u') &&
              (secondElement == 'op' || secondElement == 'po') &&
              decoded.length >= 4) {
            // Account is at index 3
            if (decoded[3] is String) {
              messageAccount = decoded[3].toString();
            } else if (decoded[3] is int) {
              messageAccount = decoded[3].toString();
            }
          }
          // Check if it's ["op", position_id, account, ...] or ["po", order_id, account, ...]
          else if ((firstElement == 'op' || firstElement == 'po') &&
              decoded.length >= 3) {
            // Account is at index 2
            if (decoded[2] is String) {
              messageAccount = decoded[2].toString();
            } else if (decoded[2] is int) {
              messageAccount = decoded[2].toString();
            }
          }
        }

        // If we found an account in the message, validate it
        if (messageAccount != null && messageAccount.isNotEmpty) {
          if (messageAccount != currentAccount &&
              messageAccount != _lastSubscribedAccount) {
            return false;
          }
        }
      }
    }

    return true;
  }

  // Handle incoming WebSocket messages
  void _handleSocketMessage(
    dynamic message, {
    bool isPendingOrderChannel = false,
    bool isOpenPositionChannel = false,
  }) {
    if (_isDisposed) return;

    try {
      // ✅ PERFORMANCE: Handle both JSON and binary (MessagePack) formats
      dynamic decoded;
      if (MessagePackDecoder.isBinaryMessage(message)) {
        // Binary MessagePack format - decode it
        decoded = MessagePackDecoder.decodeBinary(
          message is Uint8List
              ? message
              : Uint8List.fromList(message as List<int>),
        );
        if (decoded == null) {
          AppLogger.warning(
            'Trading WS: Binary decode failed, skipping message',
          );
          return;
        }
      } else {
        // JSON format - decode as string
        final String messageStr = message.toString();
        decoded = jsonDecode(messageStr);
      }

      // ✅ FIX: Update timestamp first to prevent false reconnections
      // Always update timestamp even if we block the message (connection is alive)
      _lastDataReceived = DateHelper.nowUtc();
      _dataRetryTimer?.cancel();

      // ✅ FIX: Allow control messages (unsubscribed, authenticated, errors) even during transitions
      // Only block data messages (positions, orders, account data)
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();
        // Allow control messages to pass through
        if (type == 'unsubscribed' ||
            type == 'account_switched' ||
            type == 'authenticated' ||
            type == 'positions_joined' ||
            type == 'pending_orders_joined' ||
            type == 'error' ||
            type == 'positions_init' ||
            type == 'pending_orders_init' ||
            type == 'positions_delta' ||
            type == 'pending_orders_delta' ||
            type == 'group_changed' ||
            type == 'subscribed_pricing') {
          // Control messages - process them (they don't contain account-specific data)
        } else {
          // Other messages - check account
          if (!_shouldProcessMessage(decoded)) {
            return;
          }
        }
      } else {
        // Array-based messages (positions, orders) - always check account
        if (!_shouldProcessMessage(decoded)) {
          return;
        }
      }

      // Only log important message types in debug mode
      if (kDebugMode) {
        // Comment out to reduce noise - uncomment if needed for debugging
        // dev.log('Trading WS: Received message type: ${decoded.runtimeType}');
      }

      // Handle /ws/op and /ws/po endpoint responses (JSON format)
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();

        // Handle unsubscribe confirmation
        if (type == 'unsubscribed') {
          if (_unsubscribeCompleter != null &&
              !_unsubscribeCompleter!.isCompleted) {
            _unsubscribeCompleter!.complete();
            _unsubscribeCompleter = null;
          }
          return;
        }

        // Handle atomic account switch confirmation
        if (type == 'account_switched') {
          final tradingAccount = decoded['trading_account']?.toString();
          if (tradingAccount != null && tradingAccount.isNotEmpty) {
            _lastSubscribedAccount = tradingAccount;
          }
          if (_switchAccountCompleter != null &&
              !_switchAccountCompleter!.isCompleted) {
            _switchAccountCompleter!.complete();
            _switchAccountCompleter = null;
          }
          AppLogger.websocket(
            'Trading WS: account_switched received for $tradingAccount',
          );
          return;
        }

        // Handle authentication success for both /ws/op and /ws/po
        if (type == 'authenticated' ||
            type == 'positions_joined' ||
            type == 'pending_orders_joined') {
          // ✅ CRITICAL: Update _lastSubscribedAccount when authentication succeeds
          // This ensures data filtering works correctly after account switch
          final tradingAccount = decoded['trading_account']?.toString();
          if (tradingAccount != null && tradingAccount.isNotEmpty) {
            _lastSubscribedAccount = tradingAccount;
          }

          // ✅ CRITICAL: Update _lastDataReceived to prevent false reconnection triggers
          _lastDataReceived = DateHelper.nowUtc();

          return;
        }

        // Handle error responses
        if (type == 'error') {
          final errorMessage =
              decoded['message']?.toString() ?? 'Unknown error';
          AppLogger.error('Trading WS: Error response - $errorMessage');
          // Complete unsubscribe completer even on error to avoid hanging
          if (_unsubscribeCompleter != null &&
              !_unsubscribeCompleter!.isCompleted) {
            _unsubscribeCompleter!.complete();
            _unsubscribeCompleter = null;
          }
          return;
        }

        // Account group changed: server sends new spread snapshot next; no action needed here
        if (type == 'group_changed') return;

        // Marketwatch subscribed_pricing confirmation (snapshot already sent in previous message)
        if (type == 'subscribed_pricing') return;

        // Handle positions_init - initial load from /ws/op
        if (type == 'positions_init') {
          final chunk = decoded['chunk'] as List?;
          final isComplete = decoded['is_complete'] as bool? ?? false;

          if (chunk != null) {
            _handlePositionsOpFormat(chunk);
          }

          // If not complete, request more chunks
          if (!isComplete) {
            final offset = chunk?.length ?? 0;
            _sendEvent({
              "type": "request_positions_chunk",
              "offset": offset,
              "limit": 100,
            });
          }
          return;
        }

        // Handle positions_delta - real-time updates from /ws/op
        if (type == 'positions_delta') {
          final changes = decoded['changes'] as List?;
          if (kDebugMode) {
            // dev.log(
            //   'Trading WS: /ws/op positions_delta - ${changes?.length ?? 0} changes',
            // );
          }
          if (changes != null) {
            _handlePositionsDeltaOpFormat(changes);
          }
          return;
        }

        // Handle pending_orders_init - initial load from /ws/po
        if (type == 'pending_orders_init') {
          final chunk = decoded['chunk'] as List?;
          final isComplete = decoded['is_complete'] as bool? ?? false;

          if (chunk != null) {
            // Process each order in the chunk
            for (final item in chunk) {
              if (item is List) {
                _handlePendingOrderMessage(item);
              }
            }
          }

          // If not complete, request more chunks
          if (!isComplete) {
            final offset = chunk?.length ?? 0;
            _sendEvent({
              "type": "request_pending_orders_chunk",
              "offset": offset,
              "limit": 100,
            });
          }
          return;
        }

        // Handle pending_orders_delta - real-time updates from /ws/po
        if (type == 'pending_orders_delta') {
          final changes = decoded['changes'] as List?;
          if (changes != null) {
            // Process each change (add/update/remove)
            for (final item in changes) {
              if (item is List) {
                _handlePendingOrderMessage(item);
              }
            }
          }
          return;
        }
      }

      // Handle /ws/po pending orders format (check before /ws/op handlers):
      // Add: ["a", "po", ...] (self-hosted) or ["add", "po", ...] (MT5)
      // Update: ["u", "po", ...] (full array updates)
      // Remove: ["r", orderId]
      // Batch: [["a"/"add"/"u", "po", ...], [...]]
      if (decoded is List && decoded.isNotEmpty) {
        // Check if it's a pending order message
        if (decoded.length >= 2 && decoded[0] is String) {
          final firstElement = decoded[0].toString();
          final secondElement = decoded.length > 1 ? decoded[1].toString() : '';

          // Handle pending order operations from /ws/po
          // Check for ["a", "po", ...], ["add", "po", ...], ["u", "po", ...], or ["r", orderId]
          if (secondElement == 'po' ||
              (firstElement == 'r' &&
                  (decoded.length == 2 || decoded.length == 3) &&
                  (isPendingOrderChannel ||
                      _tradingController.selectedTab == 1))) {
            _handlePendingOrderMessage(decoded);
            return;
          }
        }

        // Handle array of arrays for pending orders: [["a"/"add", "po", ...], ["u", "po", ...], ["r", orderId]]
        if (decoded[0] is List && decoded[0].isNotEmpty) {
          final firstItem = decoded[0] as List;
          if (firstItem.length >= 2 &&
              firstItem[0] is String &&
              firstItem[1] is String &&
              firstItem[1].toString() == 'po') {
            // This is a batch of pending orders
            for (final item in decoded) {
              if (item is List) {
                _handlePendingOrderMessage(item);
              }
            }
            return;
          }

          // ✅ CRITICAL: Handle batch of open positions: [["add", "op", ...], ["u", "op", ...], ["a", "op", ...]]
          // Server sends batched position updates when multiple positions need updating
          // This handles both MT5 format ("add"/"u") and self-hosted format ("a"/"u")
          if (firstItem.length >= 2 &&
              firstItem[0] is String &&
              firstItem[1] is String &&
              firstItem[1].toString() == 'op') {
            // ✅ OPTIMIZED: Process batch and update UI once at the end for faster updates
            _handleBatchPositions(decoded);
            return;
          }
        }
      }

      // Handle /ws/op remove flag: ["r", position_id] or ["r", position_id, account] or [["r", position_id]]
      // MT5 account-first formats we now support:
      // - Single remove: ["r", account_number, position_id]
      // - Bulk remove (close all): ["r", account_number, [position_id1, position_id2, ...]]
      // Existing formats remain supported:
      // - ["r", position_id] (regular)
      // - ["r", position_id, account_number] (MT5 legacy)
      // - [["r", position_id], ["r", position_id, account_number]] (batch)
      if (decoded is List && decoded.isNotEmpty) {
        // Check if single array format: ["r", position_id] or ["r", position_id, account]
        if (decoded[0] is String && decoded[0].toString() == 'r') {
          final activeAccount = _accountController.activeMT5Account;
          final currentAccountNumber = activeAccount?.metaAccountNumber ?? "0";

          String? accountNumber;
          final List<dynamic> rawIds = [];

          if (decoded.length == 2) {
            // Format: ["r", position_id]
            rawIds.add(decoded[1]);
          } else if (decoded.length == 3) {
            final second = decoded[1];
            final third = decoded[2];

            // Account-first bulk: ["r", account, [ids]]
            if (third is List) {
              accountNumber = second.toString();
              rawIds.addAll(third);
            }
            // Account-first single: ["r", account, id]
            // Try account-first format first (new format)
            else if (second.toString() == currentAccountNumber) {
              // Second element matches current account, so it's account-first format
              accountNumber = second.toString();
              rawIds.add(third);
            }
            // Legacy: ["r", id, account]
            else if (third.toString() == currentAccountNumber) {
              // Third element matches current account, so it's legacy format
              accountNumber = third.toString();
              rawIds.add(second);
            }
            // Ambiguous - default to account-first (new format)
            else {
              accountNumber = second.toString();
              rawIds.add(third);
            }
          } else if (decoded.length >= 4) {
            // Bulk remove (flat): ["r", account, id1, id2, id3, ...] - account at index 1, then varargs of position IDs
            accountNumber = decoded[1].toString();
            rawIds.addAll(decoded.sublist(2));
          }

          // Validate account if provided
          if (accountNumber != null &&
              accountNumber != 'N/A' &&
              accountNumber != currentAccountNumber) {
            return;
          }

          if (rawIds.isEmpty) return;

          for (final rawId in rawIds) {
            final positionId = rawId.toString();
            final orderIdInt = int.tryParse(positionId) ?? 0;

            // ✅ FIX: Check if orderId exists in pending orders list
            // This ensures we remove pending orders correctly regardless of tab or channel
            final isPendingOrder =
                orderIdInt > 0 &&
                _tradingController.hasPendingOrder(orderIdInt);

            if (isPendingOrder) {
              // Order exists in pending list - remove from pending orders
              _tradingController.removePendingOrder(orderIdInt);
              _removedPendingOrderIds.add(orderIdInt); // Track removal
            } else if (isPendingOrderChannel ||
                _tradingController.selectedTab == 1) {
              // Not in pending list, but message came from pending channel or we're on pending tab
              // Try to remove anyway (might be a race condition)
              if (orderIdInt > 0) {
                _tradingController.removePendingOrder(orderIdInt);
                _removedPendingOrderIds.add(orderIdInt); // Track removal
              }
            } else {
              // Default to Position removal (Open Positions channel or legacy)
              // ✅ FIX: Track volume and time of removal to prevent zombie re-adds
              final pos = _tradingController.getMarketPositionById(positionId);
              if (pos != null) {
                _removedPositionVolumes[positionId] = pos.volume;
                _removedPositionTimes[positionId] = DateTime.now();
              }

              // ✅ FIX: Remove from UI immediately and track removal to block future updates
              _tradingController.removePositionFromList(positionId);
              _removedPositionIds.add(
                positionId,
              ); // Track removal - blocks all future updates
            }
          }
          return;
        }

        // Check if array of arrays: [["r", position_id], ["r", position_id, account]] or [["r", "400125", [ids]]]
        if (decoded[0] is List && decoded[0].isNotEmpty) {
          final firstItem = decoded[0] as List;
          // Check if first item is ["r", position_id] or ["r", position_id, account] format
          // OR ["r", account, [ids]] format (bulk remove with account number)
          if (firstItem[0] is String && firstItem[0].toString() == 'r') {
            AppLogger.websocket(
              'Trading WS: Batch remove detected - firstItem=$firstItem, length=${firstItem.length}',
            );
            // Handle bulk remove format: ["r", "400125", [ids]]
            if (firstItem.length == 3 && firstItem[2] is List) {
              final accountNumber = firstItem[1].toString();
              final idsList = firstItem[2] as List;
              final activeAccount = _accountController.activeMT5Account;
              final currentAccountNumber =
                  activeAccount?.metaAccountNumber ?? "0";

              // Validate account if provided
              AppLogger.websocket(
                'Trading WS: Remove bulk - accountNumber=$accountNumber, currentAccountNumber=$currentAccountNumber, idsList=$idsList',
              );
              if (accountNumber != 'N/A' &&
                  accountNumber != currentAccountNumber) {
                AppLogger.websocket(
                  'Trading WS: Remove bulk - SKIPPED (account mismatch)',
                );
                return;
              }

              AppLogger.websocket(
                'Trading WS: Remove bulk - PROCESSING ${idsList.length} IDs',
              );
              // Process all IDs in the list
              for (final rawId in idsList) {
                final positionId = rawId.toString();
                final orderIdInt = int.tryParse(positionId) ?? 0;

                // ✅ FIX: Check if orderId exists in pending orders list
                final isPendingOrder =
                    orderIdInt > 0 &&
                    _tradingController.hasPendingOrder(orderIdInt);

                if (isPendingOrder) {
                  // Order exists in pending list - remove from pending orders
                  _tradingController.removePendingOrder(orderIdInt);
                  _removedPendingOrderIds.add(orderIdInt); // Track removal
                } else {
                  // Not a pending order - remove from market positions
                  // ✅ FIX: Track volume and time of removal
                  final pos = _tradingController.getMarketPositionById(positionId);
                  if (pos != null) {
                    _removedPositionVolumes[positionId] = pos.volume;
                    _removedPositionTimes[positionId] = DateTime.now();
                  }

                  // ✅ FIX: Remove immediately and track to block future updates
                  _tradingController.removePositionFromList(positionId);
                  _removedPositionIds.add(
                    positionId,
                  ); // Track removal - blocks all future updates
                }
              }
              return;
            }
            // Handle single remove formats: ["r", position_id] or ["r", position_id, account]
            else if ((firstItem.length == 2 || firstItem.length == 3)) {
              AppLogger.websocket(
                'Trading WS: Single remove detected - firstItem=$firstItem, decoded length=${decoded.length}',
              );
              // Process all remove flags (supports both 2-element and 3-element formats)
              for (final item in decoded) {
                if (item is List &&
                    (item.length == 2 || item.length == 3) &&
                    item[0] is String &&
                    item[0].toString() == 'r') {
                  final activeAccount = _accountController.activeMT5Account;
                  final currentAccountNumber =
                      activeAccount?.metaAccountNumber ?? "0";

                  AppLogger.websocket(
                    'Trading WS: Processing remove item=$item, currentAccount=$currentAccountNumber',
                  );

                  String? accountNumber;
                  final List<dynamic> rawIds = [];

                  if (item.length == 2) {
                    rawIds.add(item[1]);
                  } else if (item.length == 3) {
                    final second = item[1];
                    final third = item[2];

                    // Account-first bulk: ["r", account, [ids]] inside batch
                    if (third is List) {
                      accountNumber = second.toString();
                      rawIds.addAll(third);
                    }
                    // Account-first single: ["r", account, id]
                    // ✅ FIX: Handle both string and number account formats
                    else if (third is! List) {
                      final secondStr = second.toString();
                      final thirdStr = third.toString();

                      // Try account at index 1 first (most common format from Trade Engine)
                      if (secondStr == currentAccountNumber) {
                        accountNumber = secondStr;
                        rawIds.add(third);
                      }
                      // Try account at index 2 (legacy format)
                      else if (thirdStr == currentAccountNumber) {
                        accountNumber = thirdStr;
                        rawIds.add(second);
                      }
                      // If neither matches, assume index 1 is account (Trade Engine format)
                      else {
                        accountNumber = secondStr;
                        rawIds.add(third);
                      }
                    } else {
                      accountNumber = third.toString();
                      rawIds.add(second);
                    }
                  }

                  // ✅ FIX: If account doesn't match, still try to remove by position ID
                  // This handles edge cases where account format might differ slightly
                  // We'll check if the position exists in the current account's list
                  if (accountNumber != null &&
                      accountNumber != 'N/A' &&
                      accountNumber != currentAccountNumber) {
                    // Account doesn't match - but still try to remove if position exists
                    // This handles cases where account format differs (string vs number)
                    AppLogger.websocket(
                      'Trading WS: Remove - account mismatch (received=$accountNumber, current=$currentAccountNumber), but attempting removal anyway',
                    );
                  }

                  AppLogger.websocket(
                    'Trading WS: Extracted rawIds=$rawIds, accountNumber=$accountNumber',
                  );

                  for (final rawId in rawIds) {
                    final positionId = rawId.toString();
                    final orderIdInt = int.tryParse(positionId) ?? 0;

                    AppLogger.websocket(
                      'Trading WS: Processing remove for positionId=$positionId (orderIdInt=$orderIdInt)',
                    );

                    if (orderIdInt <= 0) {
                      AppLogger.websocket(
                        'Trading WS: Skipping invalid position ID $positionId',
                      );
                      continue; // Skip invalid IDs
                    }

                    // ✅ FIX: Check if orderId exists in pending orders list
                    // This ensures we remove pending orders correctly regardless of tab or channel
                    final isPendingOrder = _tradingController.hasPendingOrder(
                      orderIdInt,
                    );

                    if (isPendingOrder) {
                      // Order exists in pending list - remove from pending orders
                      _tradingController.removePendingOrder(orderIdInt);
                      _removedPendingOrderIds.add(orderIdInt); // Track removal
                      AppLogger.websocket(
                        'Trading WS: Removed pending order $orderIdInt',
                      );
                    } else {
                      // Not a pending order - remove from market positions
                      // ✅ CRITICAL FIX: Mark as removed FIRST to block any pending updates
                      // This prevents race conditions where an update arrives right before remove
                      _removedPositionIds.add(positionId);

                      AppLogger.websocket(
                        'Trading WS: Attempting to remove position $positionId from list (current positions: ${_tradingController.marketPositions.length})',
                      );

                      // Now remove from the list
                      _tradingController.removePositionFromList(positionId);

                      AppLogger.websocket(
                        'Trading WS: Removed position $positionId (account check: received=$accountNumber, current=$currentAccountNumber, remaining positions: ${_tradingController.marketPositions.length})',
                      );
                    }
                  }
                }
              }
              return;
            }
          }
        }
      }

      // Handle /ws/op array format:
      // ["a","op",...] or ["add","op",...] - Add new position (self-hosted uses "a", MT5 uses "add")
      // ["u","op",...] - Update existing position
      // ["op",...] - Update existing position (legacy format)
      if (decoded is List && decoded.isNotEmpty) {
        // Check if single array format: ["a"/"add","op",...], ["u","op",...] or ["op",...]
        if (decoded[0] is String && decoded.length >= 13) {
          final firstElement = decoded[0].toString();
          final secondElement =
              decoded.length >= 14 ? decoded[1].toString() : '';
          // ✅ FIX: Handle ["a","op",...], ["add","op",...], ["u","op",...] and ["op",...] formats
          if ((firstElement == 'op' ||
                  firstElement == 'u' ||
                  firstElement == 'a' ||
                  firstElement == 'add') &&
              (decoded.length >= 13 ||
                  (decoded.length >= 12 && secondElement == 'op'))) {
            if (kDebugMode) {
              // dev.log(
              //   'Trading WS: Received /ws/op array format position (${firstElement == 'a'
              //       ? 'add'
              //       : firstElement == 'u'
              //       ? 'update'
              //       : 'update'})',
              // );
            }
            _handleSinglePositionOpFormat(decoded);
            return;
          }
        }

        // Check if array of arrays: [["a"/"add","op",...], ["u","op",...], ["op",...]]
        if (decoded[0] is List && decoded[0].isNotEmpty) {
          final firstItem = decoded[0] as List;
          // ✅ FIX: Check if first item starts with "a", "add", "op", "u","op" or just "op"
          if (firstItem.length >= 13 &&
              (firstItem[0] == 'op' ||
                  (firstItem[0] == 'u' &&
                      firstItem.length >= 14 &&
                      firstItem[1] == 'op') ||
                  (firstItem[0] == 'a' &&
                      firstItem.length >= 14 &&
                      firstItem[1] == 'op') ||
                  (firstItem[0] == 'add' &&
                      firstItem.length >= 14 &&
                      firstItem[1] == 'op'))) {
            if (kDebugMode) {
              // dev.log(
              //   'Trading WS: Received /ws/op array of arrays - ${decoded.length} positions',
              // );
            }
            // ✅ FIX: Process each item individually to ensure all positions update correctly
            // This handles mixed batches (XAUUSD update + NZDUSD update) properly
            for (final item in decoded) {
              if (item is List && item.length >= 13) {
                _handleSinglePositionOpFormat(item);
              }
            }
            return;
          }
        }
      }

      // Handle new format: {"positions": [[...], [...]], "account": [...]}
      // Example: {"positions": [[387809, 301541, "EURUSD.c", 1, 0.01, 1.16248, 1.16269, -0.21]], "account": [8502.2, 0.0, 8499.9, 8489.54, 82045.37, -2.3]}
      // Also handles empty positions: {"positions": [], "account": [8502.2, 0.0, 8499.9, 8489.54, 82045.37, -2.3]}
      if (decoded is Map<String, dynamic> && decoded.containsKey('positions')) {
        if (kDebugMode) {
          // Only log raw message in debug mode when needed for troubleshooting
          // dev.log('Trading WS: Received positions with account data format');
          // dev.log('Trading WS: Raw message: $message');
        }
        final positionsArray = decoded['positions'];
        final accountArray = decoded['account'];

        // Guard: if we recently subscribed for a different account, drop stale frames
        final currentAcc =
            _accountController.activeMT5Account?.metaAccountNumber;
        if (_lastSubscribedAccount != null &&
            currentAcc != null &&
            _lastSubscribedAccount != currentAcc) {
          // Stale payload from previous account, ignore
          return;
        }

        // positionsArray can be empty, which is valid (no open positions)
        if (positionsArray is List) {
          _handlePositionsAndAccountFormat(positionsArray, accountArray);
          return;
        }
      }

      // Handle raw array format: [[...], [...]]
      // Positions format: [382703, 301333, "GBPUSD.c", 1, 0.02, 1.27500, 1.27450, -10.0] (8 elements)
      //   - Element [6] is entry price (number), [7] is profit/loss (number)
      // Pending orders format: [778926, 76356, "USDJPY", 154.091, 152.1, 0.01, "buy", 0.0, 0.0] (7-9 elements)
      //   - Element [6] is action (string like "buy"), [7] is SL (optional), [8] is TP (optional)
      // Self-hosted format: ["a","op",posId,account,symbol,action,vol,priceOpen,priceCurrent,profit,extra,swap,sl,serverType,openedAt,digits,extra]
      if (decoded is List) {
        // Check if it's an array of arrays
        if (decoded.isNotEmpty && decoded[0] is List) {
          final firstItem = decoded[0] as List;

          // Check for self-hosted ["a"/"u","op",...] batch format FIRST
          final isBatchOpFormat =
              firstItem.length >= 14 &&
              firstItem[0] is String &&
              (firstItem[0] == 'a' ||
                  firstItem[0] == 'u' ||
                  firstItem[0] == 'add') &&
              firstItem[1] is String &&
              firstItem[1] == 'op';

          if (isBatchOpFormat) {
            _handleBatchPositions(decoded);
            return;
          }

          // Check if element [6] is a string (pending order) or number (position)
          // Positions: element [6] is entry price (number), [7] is profit/loss (number)
          // Pending orders: element [6] is action (string like "buy"), [7] and [8] are SL/TP (optional numbers)
          final isPendingOrder =
              firstItem.length >= 7 &&
              firstItem.length <= 9 &&
              firstItem[6] is String;

          if (isPendingOrder) {
            // This is pending orders array (7-9 elements) from subscribe_pending_orders
            if (kDebugMode) {
              // Commented out to reduce log noise - uncomment if needed
              // dev.log('Trading WS: Received array of pending orders: ${decoded.length} orders');
            }
            _handlePendingOrdersArrayFormat(decoded);
            return;
          } else if (firstItem.length >= 8) {
            // Guard against stale frames based on embedded MT5 account id at [1]
            try {
              final frameAcc =
                  int.tryParse(firstItem[1].toString())?.toString();
              final currentAcc =
                  _accountController.activeMT5Account?.metaAccountNumber;
              if (_lastSubscribedAccount != null &&
                  currentAcc != null &&
                  _lastSubscribedAccount != currentAcc) {
                return;
              }
              if (frameAcc != null &&
                  currentAcc != null &&
                  frameAcc != currentAcc) {
                return;
              }
            } catch (_) {}
            // This is positions array (8+ elements)
            if (kDebugMode) {
              // Commented out to reduce log noise - uncomment if needed
              // dev.log('Trading WS: Received array of positions: ${decoded.length} positions');
            }
            _handlePositionsArrayFormat(decoded);
            return;
          }
        }
        // Single item array
        else {
          // Check if element [6] is a string (pending order) or number (position)
          final isPendingOrder =
              decoded.length >= 7 &&
              decoded.length <= 9 &&
              decoded[6] is String;

          if (isPendingOrder) {
            if (kDebugMode) {
              // dev.log('Trading WS: Received single pending order array');
            }
            _handlePendingOrdersArrayFormat([decoded]);
            return;
          } else if (decoded.length >= 8) {
            if (kDebugMode) {
              // dev.log('Trading WS: Received single position array');
            }
            _handlePositionsArrayFormat([decoded]);
            return;
          }
        }
      }

      // Handle old JSON object format (backward compatibility)
      if (decoded is Map<String, dynamic>) {
        if (kDebugMode) {
          // dev.log('Trading WS: Received old JSON object format');
        }

        // Check if this is trading data
        if (decoded.containsKey('openPositions') ||
            decoded.containsKey('pendingOrders')) {
          final tradingResponse = WebSocketTradingResponse.fromJson(decoded);
          // ✅ FIX: Update immediately for real-time trading data (removed 100ms debounce delay)
          // Real-time position updates need instant UI refresh for accurate trading
          if (!_isDisposed) {
            _tradingController.updateWebSocketData(tradingResponse);
            if (kDebugMode) {
              // dev.log('Trading WS: Updated trading data successfully');
            }
          }
        }
      }
    } catch (e) {
      // Always log errors
      if (kDebugMode) {
        // dev.log('Trading WS: Error parsing message: $e');
        // dev.log('Trading WS: Raw message: $message');
      }
    }
  }

  // Public helper: switch to currently active MT5 account by hard restarting WS
  Future<void> switchToActiveAccount() async {
    if (_isDisposed) return;
    try {
      _disconnectWebSocket();
      // Ensure the previous socket actually closes before reconnect
      await _gracefulClose();
      // Small gap to avoid late frames landing after new connect
      await Future.delayed(const Duration(milliseconds: 200));
      _reconnectAttempts = 0;
      _lastSubscribedAccount = null;
      _initializeWebSocket();
    } catch (e) {
      AppLogger.error('Trading WS: switchToActiveAccount error', error: e);
    }
  }

  // Try to await socket close (best-effort)
  Future<void> _gracefulClose() async {
    if (!isConnected.value) return;
    try {
      final done = Completer<void>();
      late StreamSubscription sub;
      sub = _channel!.stream.listen(
        (_) {},
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (_) {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      try {
        _channel?.sink.close();
      } catch (_) {}
      await done.future.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () {},
      );
      await sub.cancel();
    } catch (_) {}
  }

  // Handle positions and account format
  // Format: {"positions": [[...], [...]], "account": [balance, credit, equity, marginFree, marginLevel, floating]}
  // Example: {"positions": [[387809, 301541, "EURUSD.c", 1, 0.01, 1.16248, 1.16269, -0.21]], "account": [8502.2, 0.0, 8499.9, 8489.54, 82045.37, -2.3]}
  void _handlePositionsAndAccountFormat(
    List<dynamic> positionsArray,
    dynamic accountArray,
  ) {
    try {
      // Guard: Block data if _lastSubscribedAccount is null (during unsubscribe)
      if (_lastSubscribedAccount == null) {
        return;
      }

      final List<TradingPosition> positions = [];
      List<AccountInfo> accountInfos = [];
      final currentAccount =
          _accountController.activeMT5Account?.metaAccountNumber;

      // Parse positions array
      for (final positionData in positionsArray) {
        if (positionData is! List || positionData.length < 8) {
          if (positionData is! List || positionData.length < 8) {
            continue;
          }
        }

        try {
          // Parse array format:
          // 8 elements: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit]
          // 10 elements: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit, SL, TP]
          // Example 8: [382703, 301333, "GBPUSD.c", 1, 0.02, 1.27500, 1.27450, -10.0]
          // Example 10: [76355, 778926, "USDJPY", 0, 0.01, 154.347, 154.134, -1.38, 0.0, 156.65]
          final positionId = int.tryParse(positionData[0].toString()) ?? 0;
          final mt5AccountStr = positionData[1].toString();

          final activeOk = _accountMatches(currentAccount, mt5AccountStr);
          final subscribedOk = _accountMatches(
            _lastSubscribedAccount,
            mt5AccountStr,
          );
          if (!activeOk && !subscribedOk) {
            continue; // Skip this position
          }

          final mt5Account = int.tryParse(mt5AccountStr) ?? 0;
          final symbol = positionData[2].toString();
          final actionValue =
              int.tryParse(positionData[3].toString()) ??
              0; // 0 = Buy, 1 = Sell
          final volume = double.tryParse(positionData[4].toString()) ?? 0.0;
          final priceOpen = double.tryParse(positionData[5].toString()) ?? 0.0;
          final priceCurrent =
              double.tryParse(positionData[6].toString()) ?? 0.0;
          final profit = double.tryParse(positionData[7].toString()) ?? 0.0;

          // Extract SL and TP if available (indices 8 and 9 for 10-element arrays)
          // Index 8 is TP and Index 9 is SL from backend
          final priceTP =
              positionData.length >= 9
                  ? (double.tryParse(positionData[8].toString()) ?? 0.0)
                  : 0.0;
          final priceSL =
              positionData.length >= 10
                  ? (double.tryParse(positionData[9].toString()) ?? 0.0)
                  : 0.0;

          // Convert action: 0 = Buy, 1 = Sell
          final action = actionValue == 0 ? 'Buy' : 'Sell';

          // Parse digits from last element of array (if available)
          // Format: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit, SL?, TP?, digits?]
          int digits = 5; // Default
          if (positionData.length > 7) {
            final lastElement = positionData[positionData.length - 1];
            final parsedDigits = int.tryParse(lastElement.toString());
            // Check if last element is digits (not SL/TP which are doubles)
            if (parsedDigits != null &&
                parsedDigits > 0 &&
                parsedDigits <= 10) {
              digits = parsedDigits;
            }
          }

          // Create TradingPosition from array data
          final position = TradingPosition(
            mt5Account: mt5Account,
            position: positionId,
            action: action,
            volume: volume.toString(),
            priceOpen: priceOpen.toString(),
            priceSL: priceSL == 0.0 ? '0' : priceSL.toString(),
            priceTP: priceTP == 0.0 ? '0' : priceTP.toString(),
            priceCurrent: priceCurrent.toString(),
            closeTime: '', // Not in array
            timeCreate: '', // Not in array
            symbol: symbol,
            logo: '', // Will be set later if needed
            profit: profit,
            digits: digits, // Use parsed digits from WebSocket
            swap: 0.0, // Swap not available in this format
          );

          positions.add(position);
          if (kDebugMode) {
            // Commented out to reduce noise - fires for every position
            // dev.log('Trading WS: Parsed position: $symbol $action $volume @ $priceOpen (P&L: $profit)');
          }
        } catch (e) {
          AppLogger.error('Trading WS: Error parsing position', error: e);
        }
      }

      // Parse account array: [balance, credit, equity, marginFree, marginLevel, floating]
      // Example: [8502.2, 0.0, 8499.9, 8489.54, 82045.37, -2.3]
      if (accountArray != null) {
        if (accountArray is List && accountArray.length >= 6) {
          try {
            final balance = double.tryParse(accountArray[0].toString()) ?? 0.0;
            final credit = double.tryParse(accountArray[1].toString()) ?? 0.0;
            final equity = double.tryParse(accountArray[2].toString()) ?? 0.0;
            final marginFree =
                double.tryParse(accountArray[3].toString()) ?? 0.0;
            final marginLevel =
                double.tryParse(accountArray[4].toString()) ?? 0.0;
            final floating = double.tryParse(accountArray[5].toString()) ?? 0.0;

            // Calculate used margin: equity - marginFree (or balance - marginFree if equity not available)
            // Margin = Used margin for open positions
            final margin =
                equity > 0
                    ? (equity - marginFree).abs()
                    : (balance - marginFree).abs();

            // Create AccountInfo from array data
            final accountInfo = AccountInfo(
              assets: balance + credit, // Assets = Balance + Credit
              balance: balance,
              blockedCommission: 0.0, // Not in array
              blockedProfit: 0.0, // Not in array
              credit: credit,
              currencyDigits: 2, // Default
              equity: equity,
              floating: floating,
              liabilities: 0.0, // Not in array
              login:
                  int.tryParse(
                    _accountController.activeMT5Account?.metaAccountNumber ??
                        '0',
                  ) ??
                  0,
              margin: margin,
              marginFree: marginFree,
              marginInitial: 0.0, // Not in array
              marginLevel: marginLevel,
              marginLeverage: 0, // Not in array
              marginMaintenance: 0.0, // Not in array
              profit: floating, // Profit is same as floating
              soActivation: 0.0, // Not in array
              soEquity: 0.0, // Not in array
              soLevel: 0.0, // Not in array
              soMargin: 0.0, // Not in array
              soTime: 0.0, // Not in array
              storage: 0.0, // Not in array
            );

            accountInfos = [accountInfo];
            if (kDebugMode) {
              // Commented out to reduce noise - fires frequently
              // dev.log('Trading WS: Parsed account info - Balance: $balance, Equity: $equity, Margin: $margin, Floating: $floating');
            }
          } catch (e) {
            AppLogger.error('Trading WS: Error parsing account data', error: e);
          }
        }
      }

      // Always create OpenPositionsData and update controller, even if positions are empty
      // This ensures account info is updated even when there are no open positions
      final openPositionsData = OpenPositionsData(
        positions: positions,
        accountinfo: accountInfos.isNotEmpty ? accountInfos : [],
      );

      // Create WebSocketTradingResponse and update controller
      final tradingResponse = WebSocketTradingResponse(
        openPositions: openPositionsData,
        pendingOrders: null,
        realtime: true,
        serverTimestamp: DateHelper.nowUtc().millisecondsSinceEpoch,
      );

      // ✅ FIX: Update immediately for real-time trading data (removed 100ms debounce delay)
      // Real-time position updates need instant UI refresh for accurate trading
      if (!_isDisposed) {
        _tradingController.updateWebSocketData(tradingResponse);
        if (kDebugMode) {
          // Commented out to reduce noise - fires on every update
          // dev.log('Trading WS: Updated ${positions.length} positions and ${accountInfos.length} account info(s)');
          // dev.log('Trading WS: Account balance: ${accountInfos.isNotEmpty ? accountInfos.first.balance : "N/A"}, Equity: ${accountInfos.isNotEmpty ? accountInfos.first.equity : "N/A"}');
        }
      }
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error handling positions and account format',
        error: e,
      );
    }
  }

  // Handle array format positions (raw array without account data)
  // Format: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit]
  // Or: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit, SL, TP]
  // Or: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit, SL, TP, server_type, opened_at]
  // Example 8: [382703, 301333, "GBPUSD.c", 1, 0.02, 1.27500, 1.27450, -10.0]
  // Example 10: [76355, 778926, "USDJPY", 0, 0.01, 154.347, 154.134, -1.38, 0.0, 156.65]
  // Example 12: [76355, 778926, "USDJPY", 0, 0.01, 154.347, 154.134, -1.38, 0.0, 156.65, 0, 1704067200]
  void _handlePositionsArrayFormat(List<dynamic> positionsArray) {
    try {
      // Guard: Block data if _lastSubscribedAccount is null (during unsubscribe)
      if (_lastSubscribedAccount == null) {
        return;
      }

      final List<TradingPosition> positions = [];
      final currentAccount =
          _accountController.activeMT5Account?.metaAccountNumber;

      for (final positionData in positionsArray) {
        if (positionData is! List || positionData.length < 8) {
          if (positionData is! List || positionData.length < 8) {
            continue;
          }
        }

        try {
          // Parse array format:
          // 8 elements: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit]
          // 10 elements: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit, SL, TP]
          // 12 elements: [position_id, MT5Account, symbol, action, volume, price_open, price_current, profit, SL, TP, server_type, opened_at]
          final positionId = int.tryParse(positionData[0].toString()) ?? 0;
          final mt5AccountStr = positionData[1].toString();

          final activeOk = _accountMatches(currentAccount, mt5AccountStr);
          final subscribedOk = _accountMatches(
            _lastSubscribedAccount,
            mt5AccountStr,
          );
          if (!activeOk && !subscribedOk) {
            continue; // Skip this position
          }

          final mt5Account = int.tryParse(mt5AccountStr) ?? 0;
          final symbol = positionData[2].toString();
          final actionValue =
              int.tryParse(positionData[3].toString()) ??
              0; // 0 = Buy, 1 = Sell
          final volume = double.tryParse(positionData[4].toString()) ?? 0.0;
          final priceOpen = double.tryParse(positionData[5].toString()) ?? 0.0;
          final priceCurrent =
              double.tryParse(positionData[6].toString()) ?? 0.0;
          final profit = double.tryParse(positionData[7].toString()) ?? 0.0;

          // Extract SL and TP if available (indices 8 and 9 for 10+ element arrays)
          final priceSL =
              positionData.length >= 9
                  ? (double.tryParse(positionData[8].toString()) ?? 0.0)
                  : 0.0;
          final priceTP =
              positionData.length >= 10
                  ? (double.tryParse(positionData[9].toString()) ?? 0.0)
                  : 0.0;

          // Extract opened_at (timeCreate) if available (index 11 for 12+ element arrays)
          // server_type is at index 10, opened_at is at index 11
          // opened_at is a Unix timestamp in seconds
          final openedAt =
              positionData.length >= 12
                  ? (int.tryParse(positionData[11].toString()) ?? 0)
                  : 0;

          // Convert opened_at Unix timestamp (seconds) to format: "YYYY-MM-DD HH:MM:SS" (UTC)
          String timeCreate = '';
          if (openedAt > 0) {
            try {
              // Multiply by 1000 to convert seconds to milliseconds for DateTime.fromMillisecondsSinceEpoch
              // Unix timestamps are in UTC, so create UTC DateTime
              final dateTime = DateTime.fromMillisecondsSinceEpoch(
                openedAt * 1000,
                isUtc: true,
              );
              // Format as UTC "YYYY-MM-DD HH:MM:SS" to match UI format
              timeCreate = DateHelper.formatUtcDateTime(dateTime);
            } catch (e) {
              AppLogger.error(
                'Trading WS: Error parsing opened_at timestamp',
                error: e,
              );
            }
          }

          // Parse digits from last element of array (if available)
          // If not available, use default of 5
          int digits = 5; // Default
          if (positionData.length > 10) {
            // Check if digits is in the last element
            final lastElement = positionData[positionData.length - 1];
            final parsedDigits = int.tryParse(lastElement.toString());
            if (parsedDigits != null && parsedDigits > 0) {
              digits = parsedDigits;
            }
          }

          // Convert action: 0 = Buy, 1 = Sell
          final action = actionValue == 0 ? 'Buy' : 'Sell';

          // Create TradingPosition from array data
          final position = TradingPosition(
            mt5Account: mt5Account,
            position: positionId,
            action: action,
            volume: volume.toString(),
            priceOpen: priceOpen.toString(),
            priceSL: priceSL == 0.0 ? '0' : priceSL.toString(),
            priceTP: priceTP == 0.0 ? '0' : priceTP.toString(),
            priceCurrent: priceCurrent.toString(),
            closeTime:
                '', // Not in array (open positions don't have close time)
            timeCreate: timeCreate, // Extracted from opened_at if available
            symbol: symbol,
            logo: '', // Will be set later if needed
            profit: profit,
            digits: digits, // Calculated from price precision
            swap: 0.0, // Swap not available in this format
          );

          positions.add(position);
          if (kDebugMode) {
            // Commented out to reduce noise - fires for every position
            // dev.log('Trading WS: Parsed position: $symbol $action $volume @ $priceOpen (P&L: $profit, timeCreate: $timeCreate, digits: $digits)');
          }
        } catch (e) {
          AppLogger.error('Trading WS: Error parsing position', error: e);
        }
      }

      if (positions.isNotEmpty) {
        // Create OpenPositionsData from parsed positions
        final openPositionsData = OpenPositionsData(
          positions: positions,
          accountinfo: [], // Account info not in array format
        );

        // Create WebSocketTradingResponse and update controller
        final tradingResponse = WebSocketTradingResponse(
          openPositions: openPositionsData,
          pendingOrders: null,
          realtime: true,
          serverTimestamp: DateHelper.nowUtc().millisecondsSinceEpoch,
        );

        // ✅ FIX: Update immediately for real-time trading data (removed 100ms debounce delay)
        // Real-time position updates need instant UI refresh for accurate trading
        if (!_isDisposed) {
          _tradingController.updateWebSocketData(tradingResponse);
          if (kDebugMode) {
            // Commented out to reduce noise
            // dev.log('Trading WS: Updated ${positions.length} positions from array format');
          }
        }
      }
    } catch (e) {
      AppLogger.error('Trading WS: Error handling positions array', error: e);
    }
  }

  // Handle /ws/po pending order messages
  // Add: ["a", "po", ...] (self-hosted) or ["add", "po", ...] (MT5)
  // Update: ["u", "po", ...] (full array updates)
  // Remove: ["r", orderId]
  void _handlePendingOrderMessage(List<dynamic> message) {
    try {
      if (message.isEmpty) return;

      // Guard: Block data if _lastSubscribedAccount is null (during unsubscribe)
      if (_lastSubscribedAccount == null) {
        return;
      }

      final firstElement = message[0].toString();
      final secondElement = message.length > 1 ? message[1].toString() : '';
      final currentAccount =
          _accountController.activeMT5Account?.metaAccountNumber;

      // Handle remove: ["r", orderId] or ["r", orderId, account] or ["r", account, orderId]
      if (firstElement == 'r' && (message.length == 2 || message.length == 3)) {
        int orderId = 0;
        String? accountNumber;

        if (message.length == 2) {
          orderId = int.tryParse(message[1].toString()) ?? 0;
        } else if (message.length == 3) {
          final second = message[1];
          final third = message[2];

          // ✅ FIX: Better detection for self-hosted format ["r", account, orderId]
          // Check if second is a string (account) and third is a number (orderId)
          // This is more reliable than checking currentAccount match
          if (third is! List &&
              second is String &&
              (third is int || third is num) &&
              int.tryParse(third.toString()) != null) {
            // Self-hosted format: ["r", account, orderId]
            accountNumber = second.toString();
            orderId = int.tryParse(third.toString()) ?? 0;
          }
          // Legacy format: ["r", orderId, account] - check if second is numeric
          else if (int.tryParse(second.toString()) != null) {
            orderId = int.tryParse(second.toString()) ?? 0;
            accountNumber =
                third is String || third is num ? third.toString() : null;
          }
          // Fallback: Try account-first format if second matches currentAccount
          else if (second is String &&
              currentAccount != null &&
              second.toString() == currentAccount) {
            accountNumber = second.toString();
            orderId = int.tryParse(third.toString()) ?? 0;
          }
          // Final fallback: Legacy format
          else {
            orderId = int.tryParse(second.toString()) ?? 0;
            accountNumber =
                third is String || third is num ? third.toString() : null;
          }
        }

        // Validate account if provided
        if (accountNumber != null &&
            currentAccount != null &&
            accountNumber != currentAccount) {
          return; // Skip this removal
        }

        if (orderId > 0) {
          _tradingController.removePendingOrder(orderId);
          _removedPendingOrderIds.add(orderId); // Track removal
        }
        return;
      }

      // Handle add or update: ["a", "po", ...], ["add", "po", ...] or ["u", "po", ...]
      // ✅ FIX: Handle both "a" (self-hosted) and "add" (MT5) for adding pending orders
      // Format: ["a"/"add","po", orderId, account, symbol, action, volume, price_order, price_current, price_sl, price_tp, server_type, opened_at, swap, digits]
      if ((firstElement == 'a' ||
              firstElement == 'add' ||
              firstElement == 'u') &&
          secondElement == 'po' &&
          message.length >= 12) {
        // Parse pending order array format
        // [0] = "a", "add" or "u" (add/update)
        // [1] = "po" (pending order identifier)
        // [2] = orderId
        // [3] = account
        // [4] = symbol
        // [5] = action
        // [6] = volume
        // [7] = price_order
        // [8] = price_current
        // [9] = price_sl
        // [10] = price_tp
        // [11] = server_type
        // [12] = opened_at (Unix timestamp in seconds)
        // [13] = swap
        // [14] = digits
        final orderId = int.tryParse(message[2].toString()) ?? 0;
        final account = message[3].toString();

        // ✅ FIX: Check if order was deleted BEFORE any processing
        // This prevents deleted orders from being re-added by websocket
        if (orderId > 0 && _tradingController.isPendingOrderDeleted(orderId)) {
          return; // Skip this order - it was deleted, no updates allowed
        }

        // Validate account number matches current account
        if (currentAccount != null && currentAccount.isNotEmpty && !_accountMatches(currentAccount, account)) {
          return; // Skip this order
        }

        // Also check _lastSubscribedAccount for additional safety
        if (_lastSubscribedAccount != null &&
            !_accountMatches(_lastSubscribedAccount, account)) {
          return; // Skip this order
        }

        final accountInt = int.tryParse(account) ?? 0;
        final symbol = message[4].toString();
        // Action is a numeric code: 0, 1, 2, 3, 4, 5
        // 0 = buyMarket, 1 = sellMarket, 2 = buyLimit, 3 = sellLimit, 4 = buyStop, 5 = sellStop
        final actionCode = int.tryParse(message[5].toString()) ?? 0;
        final volume = double.tryParse(message[6].toString()) ?? 0.0;
        final priceOrder = double.tryParse(message[7].toString()) ?? 0.0;
        final priceCurrent = double.tryParse(message[8].toString()) ?? 0.0;
        // Parse price_sl and price_tp - handle empty strings, null, or "0" values
        // Index 9 is TP and Index 10 is SL from backend
        final priceTPStr =
            message.length > 9 ? message[9].toString().trim() : '0';
        final priceSLStr =
            message.length > 10 ? message[10].toString().trim() : '0';
        final priceSL =
            (priceSLStr.isEmpty ||
                    priceSLStr == '0' ||
                    priceSLStr == 'null' ||
                    priceSLStr == '-')
                ? 0.0
                : (double.tryParse(priceSLStr) ?? 0.0);
        final priceTP =
            (priceTPStr.isEmpty ||
                    priceTPStr == '0' ||
                    priceTPStr == 'null' ||
                    priceTPStr == '-')
                ? 0.0
                : (double.tryParse(priceTPStr) ?? 0.0);
        // server_type at [11] - not used in PendingOrder model
        // Parse opened_at and digits based on message length (C++ datafeed recently added fields)
        // Format Evolution:
        // - Legacy (14 elements): [..., server_type, opened_at, digits]
        // - Older (15 elements): [..., server_type, opened_at, swap, digits]
        // - Latest (16 elements): [..., commission, swap, server_type, opened_at, digits]
        int openedAt = 0;
        int digits = 0;

        if (message.length >= 16) {
          // Latest C++ format (16+ elements): [..., commission, swap, server_type, opened_at, digits]
          // Index 14: opened_at, Index 15: digits
          openedAt = int.tryParse(message[14].toString()) ?? 0;
          digits = int.tryParse(message[15].toString()) ?? 0;
        } else if (message.length == 15) {
          // Older format (15 elements): [..., server_type, opened_at, swap, digits]
          // Index 12: opened_at, Index 14: digits
          openedAt = int.tryParse(message[12].toString()) ?? 0;
          digits = int.tryParse(message[14].toString()) ?? 0;
        } else if (message.length == 14) {
          // Legacy format (14 elements): [..., server_type, opened_at, digits]
          // Index 12: opened_at, Index 13: digits
          openedAt = int.tryParse(message[12].toString()) ?? 0;
          digits = int.tryParse(message[13].toString()) ?? 0;
        } else if (message.length >= 12) {
          // Fallback for other lengths
          openedAt = int.tryParse(message[12].toString()) ?? 0;
          digits = int.tryParse(message[message.length - 1].toString()) ?? 0;
        }

        // Convert opened_at timestamp to ISO8601 string for timeCreate (UTC)
        final timeCreate =
            openedAt > 0
                ? DateTime.fromMillisecondsSinceEpoch(
                  openedAt * 1000,
                  isUtc: true,
                ).toIso8601String()
                : DateHelper.nowUtc().toIso8601String();

        // Convert action code to proper format using switch-case
        String action;
        switch (actionCode) {
          case 0:
            action = 'Buy';
          case 1:
            action = 'Sell';
          case 2:
            action = 'Buy Limit';
          case 3:
            action = 'Sell Limit';
          case 4:
            action = 'Buy Stop';
          case 5:
            action = 'Sell Stop';
          case 6:
            action = 'Buy Stop Limit';
          case 7:
            action = 'Sell Stop Limit';
          default:
            // For codes 0-1 (market) or unknown codes, determine from price relationship
            if (priceOrder > 0 && priceCurrent > 0) {
              if (priceOrder < priceCurrent) {
                action = 'Buy Limit';
              } else {
                action = 'Sell Limit';
              }
            } else {
              action = 'Buy Limit';
            }
        }

        final pendingOrder = PendingOrder(
          mt5Account: accountInt,
          order: orderId,
          action: action,
          symbol: symbol,
          priceOrder: priceOrder,
          priceCurrent: priceCurrent,
          volume: volume,
          priceSL: priceSL,
          priceTP: priceTP,
          timeCreate: timeCreate, // Parsed from opened_at timestamp
          state: 'PLACED', // Pending orders are in PLACED state
          logo: '', // Will be set later if needed
          digits: digits > 0 ? digits : 0, // Parse digits from message array
        );

        if (kDebugMode) {
          // dev.log(
          //   'Trading WS: /ws/po ${firstElement == 'a' ? 'Add' : 'Update'} pending order: $symbol $action $volume @ $priceOrder (ID: $orderId, SL: $priceSL, TP: $priceTP, timeCreate: $timeCreate)',
          // );
        }

        // Add or update pending order incrementally
        _tradingController.addOrUpdatePendingOrder(pendingOrder);
        return;
      }

      // Handle array of arrays: [["a"/"add", "po", ...], ["u", "po", ...], ["r", orderId]]
      if (message[0] is List) {
        for (final item in message) {
          if (item is List) {
            _handlePendingOrderMessage(item);
          }
        }
        return;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Trading WS: Error handling /ws/po message',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Handle pending orders array format from subscribe_pending_orders (legacy)
  // Response format: [[778926, 76356, "USDJPY", 154.091, 152.1, 0.01, "buy", 0.0, 0.0], ...]
  // Format: [MT5Account, OrderID, Symbol, PriceOrder, PriceCurrent, Volume, Action, PriceSL?, PriceTP?]
  // Action is string: "buy", "sell", "Buy Limit", "Sell Limit", etc.
  // PriceSL and PriceTP are optional (indices 7 and 8)
  void _handlePendingOrdersArrayFormat(List<dynamic> pendingOrdersArray) {
    try {
      // Guard: Block data if _lastSubscribedAccount is null (during unsubscribe)
      if (_lastSubscribedAccount == null) {
        return;
      }

      final List<PendingOrder> pendingOrders = [];
      final currentAccount =
          _accountController.activeMT5Account?.metaAccountNumber;

      for (final orderData in pendingOrdersArray) {
        // Accept arrays with 7, 8, or 9 elements
        if (orderData is! List || orderData.length < 7) {
          continue;
        }

        try {
          // Parse pending order array format
          // [0]: MT5Account, [1]: OrderID, [2]: Symbol, [3]: PriceOrder,
          // [4]: PriceCurrent, [5]: Volume, [6]: Action (string)
          // [7]: PriceSL (optional), [8]: PriceTP (optional)
          final mt5AccountStr = orderData[0].toString();

          final activeOk = _accountMatches(currentAccount, mt5AccountStr);
          final subscribedOk = _accountMatches(
            _lastSubscribedAccount,
            mt5AccountStr,
          );
          if (!activeOk && !subscribedOk) {
            continue; // Skip this order
          }

          final mt5Account = int.tryParse(mt5AccountStr) ?? 0;
          final orderId = int.tryParse(orderData[1].toString()) ?? 0;
          final symbol = orderData[2].toString();
          final priceOrder = double.tryParse(orderData[3].toString()) ?? 0.0;
          final priceCurrent = double.tryParse(orderData[4].toString()) ?? 0.0;
          final volume = double.tryParse(orderData[5].toString()) ?? 0.0;

          // Parse optional SL and TP (indices 7 and 8)
          // Index 7 is TP and Index 8 is SL from backend
          final priceTP =
              orderData.length > 7
                  ? (double.tryParse(orderData[7].toString()) ?? 0.0)
                  : 0.0;
          final priceSL =
              orderData.length > 8
                  ? (double.tryParse(orderData[8].toString()) ?? 0.0)
                  : 0.0;

          // Convert action string/code to proper format using switch-case
          // actionCode at [6] can be either a number (2-7) or a string ("buy", "sell", etc.)
          final actionCodeRaw = orderData[6];
          String action;
          if (actionCodeRaw is num) {
            final actionCode = actionCodeRaw.toInt();
            switch (actionCode) {
              case 0:
                action = 'Buy';
              case 1:
                action = 'Sell';
              case 2:
                action = 'Buy Limit';
              case 3:
                action = 'Sell Limit';
              case 4:
                action = 'Buy Stop';
              case 5:
                action = 'Sell Stop';
              case 6:
                action = 'Buy Stop Limit';
              case 7:
                action = 'Sell Stop Limit';
              default:
                action = 'Buy Limit';
            }
          } else {
            final actionStr = actionCodeRaw.toString().toLowerCase();
            if (actionStr.contains('buy')) {
              action = 'Buy Limit';
            } else if (actionStr.contains('sell')) {
              action = 'Sell Limit';
            } else {
              action = actionStr.isEmpty
                  ? 'Buy Limit'
                  : actionStr[0].toUpperCase() + actionStr.substring(1);
            }
          }

          final pendingOrder = PendingOrder(
            mt5Account: mt5Account,
            order: orderId,
            action: action,
            symbol: symbol,
            priceOrder: priceOrder,
            priceCurrent: priceCurrent,
            volume: volume,
            priceSL: priceSL,
            priceTP: priceTP,
            timeCreate: '', // Not in array
            state: 'pending',
            logo: '', // Will be set later if needed
          );

          pendingOrders.add(pendingOrder);
          if (kDebugMode) {
            // Commented out to reduce noise - fires for every pending order
            // dev.log('Trading WS: Parsed pending order: $symbol $action $volume @ $priceOrder (Current: $priceCurrent) SL: $priceSL TP: $priceTP');
          }
        } catch (e) {
          AppLogger.error('Trading WS: Error parsing pending order', error: e);
        }
      }

      // Always update pending orders (even if empty, to clear existing)
      final pendingOrdersData = PendingOrdersData(pendingOrders: pendingOrders);

      final tradingResponse = WebSocketTradingResponse(
        openPositions: null, // Don't update positions
        pendingOrders: pendingOrdersData,
        realtime: true,
        serverTimestamp: DateHelper.nowUtc().millisecondsSinceEpoch,
      );

      // Update only pending orders in controller (separate from positions)
      if (tradingResponse.pendingOrders != null) {
        _tradingController.updatePendingOrders(
          tradingResponse.pendingOrders!.pendingOrders,
        );
      }

      if (kDebugMode) {
        // Commented out to reduce noise - fires frequently
        // dev.log('Trading WS: Updated ${pendingOrders.length} pending orders (separate from positions)');
      }
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error handling pending orders array',
        error: e,
      );
    }
  }

  // Schedule reconnection
  void _scheduleReconnect() {
    if (_isDisposed || _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    if (isReconnecting.value) return;

    isReconnecting.value = true;
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_isDisposed) {
        _initializeWebSocket();
      }
    });
  }

  // ✅ OPTIMIZED: Handle batch of positions - process all and update UI once for faster updates
  void _handleBatchPositions(List<dynamic> batchItems) {
    try {
      // Guard: Block data if _lastSubscribedAccount is null (during unsubscribe)
      if (_lastSubscribedAccount == null) {
        return;
      }

      final currentAccount =
          _accountController.activeMT5Account?.metaAccountNumber;
      if (currentAccount == null || currentAccount.isEmpty) {
        return;
      }

      // Get current positions once
      final currentPositions =
          _tradingController.marketPositions
              .map(
                (p) => TradingPosition(
                  mt5Account: int.tryParse(p.accountId) ?? 0,
                  position: int.tryParse(p.orderId) ?? 0,
                  action: p.action,
                  volume: p.volume.toString(),
                  priceOpen: p.entryPrice,
                  priceSL:
                      p.stopLoss.isEmpty || p.stopLoss == '-'
                          ? '0'
                          : p.stopLoss,
                  priceTP:
                      p.takeProfit.isEmpty || p.takeProfit == '-'
                          ? '0'
                          : p.takeProfit,
                  priceCurrent: p.currentPrice,
                  closeTime: p.closeTime,
                  timeCreate: p.openTime,
                  symbol: p.symbol,
                  logo: p.flag,
                  profit: p.profitLoss,
                  digits: p.digits > 0 ? p.digits : 5,
                  swap: p.swap,
                ),
              )
              .toList();

      // ✅ OPTIMIZATION: Build position map once for O(1) lookups (essential for 100+ positions)
      // This reduces complexity from O(n²) to O(n) for large batches
      final positionMap = <int, int>{}; // positionId -> index
      for (int i = 0; i < currentPositions.length; i++) {
        positionMap[currentPositions[i].position] = i;
      }

      // Process all positions in batch
      for (final item in batchItems) {
        if (item is! List || item.length < 13) continue;

        try {
          final firstElement = item[0].toString();
          final secondElement = item.length > 1 ? item[1].toString() : '';

          bool isAFormat =
              (firstElement == 'a' || firstElement == 'add') &&
              item.length >= 16 &&
              secondElement == 'op';
          bool isUFormat =
              firstElement == 'u' && item.length >= 16 && secondElement == 'op';
          bool isOpFormat = firstElement == 'op' && item.length >= 15;

          if (!isAFormat && !isUFormat && !isOpFormat) continue;

          final isAddOnly = isAFormat;
          final isUpdate = isUFormat || isOpFormat;
          final offset = (isAFormat || isUFormat) ? 2 : 1;

          final positionId = int.tryParse(item[offset].toString()) ?? 0;
          final account = item[offset + 1].toString();

          // ✅ FIX: Validate account - block messages from wrong accounts
          if (!_accountMatches(currentAccount, account)) {
            continue;
          }
          if (_lastSubscribedAccount != null &&
              !_accountMatches(_lastSubscribedAccount, account)) {
            continue;
          }

          final symbol = item[offset + 2].toString();
          final action = int.tryParse(item[offset + 3].toString()) ?? 0;
          // ✅ FIX: double.tryParse("NaN") returns double.nan (NOT null), so
          // `?? 0.0` does NOT catch NaN/Infinity. Sanitize at the source so
          // bad WS payloads never reach PrecisionHelper and crash the UI.
          double _sanitizeDouble(double v) =>
              (v.isNaN || v.isInfinite) ? 0.0 : v;
          final volume = _sanitizeDouble(
            double.tryParse(item[offset + 4].toString()) ?? 0.0,
          );
          final priceOpen = _sanitizeDouble(
            double.tryParse(item[offset + 5].toString()) ?? 0.0,
          );
          final priceCurrent = _sanitizeDouble(
            double.tryParse(item[offset + 6].toString()) ?? 0.0,
          );
          final profit = _sanitizeDouble(
            double.tryParse(item[offset + 7].toString()) ?? 0.0,
          );

          final swap = item.length > offset + 8 ? (double.tryParse(item[offset + 8].toString()) ?? 0.0) : 0.0;
          final priceSLStr = item.length > offset + 9 ? item[offset + 9].toString().trim() : '0';
          final priceTPStr = item.length > offset + 10 ? item[offset + 10].toString().trim() : '0';

          double _parsePrice(String s) {
            if (s.isEmpty || s == '0' || s == 'null' || s == '-') return 0.0;
            final v = double.tryParse(s) ?? 0.0;
            return (v.isNaN || v.isInfinite) ? 0.0 : v;
          }

          final priceSL = _parsePrice(priceSLStr);
          final priceTP = _parsePrice(priceTPStr);

          bool hasServerField = item.length > offset + 11 && item[offset + 11] is String && !RegExp(r'^\d+$').hasMatch(item[offset + 11].toString());
          int serverOffset = hasServerField ? 1 : 0;

          final openedAt = item.length > offset + 11 + serverOffset
              ? (int.tryParse(item[offset + 11 + serverOffset].toString()) ?? 0)
              : 0;
          final digits = item.length > offset + 12 + serverOffset
              ? (int.tryParse(item[offset + 12 + serverOffset].toString()) ?? 5)
              : 5;


          // ✅ FIX: Handle "zombie" positions that come back after removal.
          // We only allow a removed position back in if it's a valid PARTIAL close
          // (i.e., volume is strictly LESS than when it was removed).
          // Stale updates with the same volume are ignored.
          final positionIdStr = positionId.toString();
          final bool wasMarkedRemoved =
              _removedPositionIds.contains(positionIdStr) ||
              _tradingController.isPositionDeleted(positionIdStr);

          if (wasMarkedRemoved) {
            final lastVolume = _removedPositionVolumes[positionIdStr];
            final removedAt = _removedPositionTimes[positionIdStr];
            final now = DateTime.now();

            // If it arrived within 15 seconds of removal and volume is same/more, it's likely a zombie
            bool isZombie = false;
            if (removedAt != null && now.difference(removedAt).inSeconds < 15) {
              if (lastVolume != null && volume >= lastVolume) {
                isZombie = true;
              }
            }

            if (!isZombie && volume > 0) {
              // Valid partial close - allow it back in
              _removedPositionIds.remove(positionIdStr);
              _removedPositionVolumes.remove(positionIdStr);
              _removedPositionTimes.remove(positionIdStr);
              _tradingController.unmarkPositionAsDeleted(positionIdStr);
            } else {
              // Ignore zombie or zero-volume update
              continue;
            }
          }

          final position = TradingPosition(
            mt5Account: int.tryParse(account) ?? 0,
            position: positionId,
            action: action == 0 ? 'Buy' : 'Sell',
            volume: volume.toString(),
            priceOpen: priceOpen.toString(),
            priceSL: priceSL == 0.0 ? '0' : priceSL.toString(),
            priceTP: priceTP == 0.0 ? '0' : priceTP.toString(),
            priceCurrent: priceCurrent.toString(),
            closeTime: '-',
            timeCreate:
                openedAt > 0
                    ? DateTime.fromMillisecondsSinceEpoch(
                      openedAt * 1000,
                      isUtc: true,
                    ).toIso8601String()
                    : DateHelper.nowUtc().toIso8601String(),
            symbol: symbol,
            logo: '',
            profit: profit,
            digits: digits,
            swap: swap,
          );

          // ✅ OPTIMIZATION: Use O(1) Map lookup instead of O(n) indexWhere
          // This is critical for handling 100+ position batches efficiently
          final index = positionMap[position.position] ?? -1;

          if (isAddOnly) {
            // ✅ FIX: Prevent duplicate additions in batch processing
            if (index == -1) {
              currentPositions.add(position);
              // Update map for future lookups
              positionMap[position.position] = currentPositions.length - 1;
            } else {
              // Position already exists - skip to prevent duplicate
            }
          } else if (isUpdate) {
            // ✅ FIX: Process updates immediately - update existing or add new
            if (index != -1) {
              currentPositions[index] = position;
            } else {
              currentPositions.add(position);
              // Update map for future lookups
              positionMap[position.position] = currentPositions.length - 1;
            }
          }
        } catch (e) {
          AppLogger.error('Trading WS: Error processing batch item', error: e);
        }
      }

      // ✅ FIX: Update UI immediately with all positions - no delays for real-time trading
      // Process batch updates instantly to match website behavior (millisecond updates)
      _tradingController.updateWebSocketData(
        WebSocketTradingResponse(
          openPositions: OpenPositionsData(
            positions: currentPositions,
            accountinfo: [],
          ),
          pendingOrders: null,
          realtime: true,
          serverTimestamp: DateHelper.nowUtc().millisecondsSinceEpoch ~/ 1000,
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Trading WS: Error handling batch positions',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Handle /ws/op single position format:
  // Format 1: ["a","op", ...] or ["add","op", ...] - Add (self-hosted uses "a", MT5 uses "add")
  // Format 2: ["u","op", ...] - Update
  // Format 3: ["op", ...] - Update (legacy)
  // Fields: position_id, account, symbol, action, volume, price_open, price_current, profit, swap, price_sl, price_tp, server_type, opened_at, digits
  void _handleSinglePositionOpFormat(List item) {
    try {
      // Guard: Block data if _lastSubscribedAccount is null (during unsubscribe)
      if (_lastSubscribedAccount == null) {
        return;
      }

      if (item.length < 13) return;

      // Check format: ["a","op",...], ["add","op",...], ["u","op",...] or ["op",...]
      // New format includes swap and digits: length should be 16 for ["a","op",...], ["add","op",...] or ["u","op",...]
      // Or 15 for ["op",...] format
      final firstElement = item[0].toString();
      final secondElement = item.length > 1 ? item[1].toString() : '';
      // ✅ FIX: Handle both "a" (self-hosted) and "add" (MT5) for adding positions
      bool isAFormat =
          (firstElement == 'a' || firstElement == 'add') &&
          item.length >= 16 &&
          secondElement == 'op';

      bool isUFormat =
          firstElement == 'u' &&
          item.length >= 16 &&
          item[1].toString() == 'op';
      bool isOpFormat = firstElement == 'op' && item.length >= 15;

      if (!isAFormat && !isUFormat && !isOpFormat) return;

      // Determine operation type: "a"/"add" = add only, "u" or "op" = update (or add if not exists)
      final isAddOnly = isAFormat;
      final isUpdate = isUFormat || isOpFormat;

      // Parse based on format
      int offset =
          (isAFormat || isUFormat)
              ? 2
              : 1; // Skip ["a","op"], ["u","op"] or ["op"]

      final positionId = int.tryParse(item[offset].toString()) ?? 0;
      final account = item[offset + 1].toString();

      // Validate account number matches current account
      final currentAccount =
          _accountController.activeMT5Account?.metaAccountNumber;
      if (currentAccount != null && currentAccount.isNotEmpty && !_accountMatches(currentAccount, account)) {
        return; // Skip this position
      }

      // Also check _lastSubscribedAccount for additional safety
      if (_lastSubscribedAccount != null && !_accountMatches(_lastSubscribedAccount, account)) {
        return; // Skip this position
      }
      final symbol = item[offset + 2].toString();
      final action =
          int.tryParse(item[offset + 3].toString()) ?? 0; // 0 = BUY, 1 = SELL
      final volume = double.tryParse(item[offset + 4].toString()) ?? 0.0;
      final priceOpen = double.tryParse(item[offset + 5].toString()) ?? 0.0;
      final priceCurrent = double.tryParse(item[offset + 6].toString()) ?? 0.0;
      final profit = double.tryParse(item[offset + 7].toString()) ?? 0.0;

      final swap = item.length > offset + 8 ? (double.tryParse(item[offset + 8].toString()) ?? 0.0) : 0.0;
          final priceSLStr = item.length > offset + 9 ? item[offset + 9].toString().trim() : '0';
          final priceTPStr = item.length > offset + 10 ? item[offset + 10].toString().trim() : '0';

          double _parsePrice(String s) {
            if (s.isEmpty || s == '0' || s == 'null' || s == '-') return 0.0;
            final v = double.tryParse(s) ?? 0.0;
            return (v.isNaN || v.isInfinite) ? 0.0 : v;
          }

          final priceSL = _parsePrice(priceSLStr);
          final priceTP = _parsePrice(priceTPStr);

          bool hasServerField = item.length > offset + 11 && item[offset + 11] is String && !RegExp(r'^\d+$').hasMatch(item[offset + 11].toString());
          int serverOffset = hasServerField ? 1 : 0;

          final openedAt = item.length > offset + 11 + serverOffset
              ? (int.tryParse(item[offset + 11 + serverOffset].toString()) ?? 0)
              : 0;
          final digits = item.length > offset + 12 + serverOffset
              ? (int.tryParse(item[offset + 12 + serverOffset].toString()) ?? 5)
              : 5;


      // ✅ FIX: Handle "zombie" positions for single updates
      final positionIdStr = positionId.toString();
      final bool wasMarkedRemoved =
          _removedPositionIds.contains(positionIdStr) ||
          _tradingController.isPositionDeleted(positionIdStr);

      if (wasMarkedRemoved) {
        final lastVolume = _removedPositionVolumes[positionIdStr];
        final removedAt = _removedPositionTimes[positionIdStr];
        final now = DateTime.now();

        bool isZombie = false;
        if (removedAt != null && now.difference(removedAt).inSeconds < 15) {
          if (lastVolume != null && volume >= lastVolume) {
            isZombie = true;
          }
        }

        if (!isZombie && volume > 0) {
          _removedPositionIds.remove(positionIdStr);
          _removedPositionVolumes.remove(positionIdStr);
          _removedPositionTimes.remove(positionIdStr);
          _tradingController.unmarkPositionAsDeleted(positionIdStr);
        } else {
          return;
        }
      }

      // Convert to TradingPosition format
      // Handle TP/SL: preserve actual values, only use '0' if truly 0.0
      final position = TradingPosition(
        mt5Account: int.tryParse(account) ?? 0,
        position: positionId,
        action: action == 0 ? 'Buy' : 'Sell',
        volume: volume.toString(),
        priceOpen: priceOpen.toString(),
        priceSL: priceSL == 0.0 ? '0' : priceSL.toString(),
        priceTP: priceTP == 0.0 ? '0' : priceTP.toString(),
        priceCurrent: priceCurrent.toString(),
        closeTime: '-',
        timeCreate:
            openedAt > 0
                ? DateTime.fromMillisecondsSinceEpoch(
                  openedAt * 1000,
                  isUtc: true,
                ).toIso8601String()
                : DateHelper.nowUtc().toIso8601String(),
        symbol: symbol,
        logo: '',
        profit: profit,
        digits: digits,
        swap: swap,
      );

      // Get current positions and update
      final currentPositions =
          _tradingController.marketPositions
              .map(
                (p) => TradingPosition(
                  mt5Account: int.tryParse(p.accountId) ?? 0,
                  position: int.tryParse(p.orderId) ?? 0,
                  action: p.action,
                  volume: p.volume.toString(),
                  priceOpen: p.entryPrice,
                  priceSL:
                      p.stopLoss.isEmpty || p.stopLoss == '-'
                          ? '0'
                          : p.stopLoss,
                  priceTP:
                      p.takeProfit.isEmpty || p.takeProfit == '-'
                          ? '0'
                          : p.takeProfit,
                  priceCurrent: p.currentPrice,
                  closeTime: p.closeTime,
                  timeCreate: p.openTime,
                  symbol: p.symbol,
                  logo: p.flag,
                  profit: p.profitLoss,
                  digits:
                      p.digits > 0
                          ? p.digits
                          : 5, // Use digits from TradePosition
                  swap: p.swap,
                ),
              )
              .toList();

      // Handle add vs update to avoid conflicts
      final index = currentPositions.indexWhere(
        (p) => p.position == position.position,
      );

      if (isAddOnly) {
        // "a"/"add" flag: Only add if position doesn't exist
        // ✅ FIX: Prevent duplicate additions - if position already exists, skip entirely
        if (index == -1) {
          currentPositions.add(position);
        } else {
          // ✅ FIX: Position already exists - skip to prevent duplicate
          // Return early to avoid unnecessary UI update
          return; // Skip processing to avoid duplicate
        }
      } else if (isUpdate) {
        // "u" flag or "op" format: Update if exists, add if doesn't exist
        // ✅ FIX: Process updates immediately without any delays
        if (index != -1) {
          currentPositions[index] = position;
        } else {
          // Position doesn't exist - add it (this handles late-arriving positions)
          currentPositions.add(position);
        }
      }

      // ✅ FIX: Update TradingController immediately for real-time updates
      // No debounce or delays - instant UI refresh for trading data
      _tradingController.updateWebSocketData(
        WebSocketTradingResponse(
          openPositions: OpenPositionsData(
            positions: currentPositions,
            accountinfo: [],
          ),
          pendingOrders: null,
          realtime: true,
          serverTimestamp: DateHelper.nowUtc().millisecondsSinceEpoch ~/ 1000,
        ),
      );

      if (kDebugMode) {
        // dev.log(
        //   'Trading WS: Updated position ${position.symbol} (ID: ${position.position}) from /ws/op',
        // );
      }
    } catch (e, t) {
      AppLogger.error(
        'Trading WS: Error parsing /ws/op position',
        error: e,
        stackTrace: t,
      );
    }
  }

  // Handle /ws/op positions chunk format
  void _handlePositionsOpFormat(List chunk) {
    try {
      // Guard: Block data if _lastSubscribedAccount is null (during unsubscribe)
      if (_lastSubscribedAccount == null) {
        return;
      }

      final List<TradingPosition> positions = [];
      final currentAccount =
          _accountController.activeMT5Account?.metaAccountNumber;

      for (final item in chunk) {
        if (item is! List || item.length < 13) continue;

        // Check format: ["a","op",...], ["u","op",...] or ["op",...]
        final firstElement = item[0].toString();
        bool isAFormat =
            firstElement == 'a' &&
            item.length >= 14 &&
            item[1].toString() == 'op';
        bool isUFormat =
            firstElement == 'u' &&
            item.length >= 14 &&
            item[1].toString() == 'op';
        bool isOpFormat = firstElement == 'op' && item.length >= 13;

        if (!isAFormat && !isUFormat && !isOpFormat) continue;

        // Parse based on format (for batch operations, we add all positions)
        int offset =
            (isAFormat || isUFormat)
                ? 2
                : 1; // Skip ["a","op"], ["u","op"] or ["op"]

        final positionId = int.tryParse(item[offset].toString()) ?? 0;
        final account = item[offset + 1].toString();

        // Validate account number matches current account
        if (currentAccount != null && currentAccount.isNotEmpty && !_accountMatches(currentAccount, account)) {
          continue; // Skip this position
        }

        // Also check _lastSubscribedAccount for additional safety
        if (_lastSubscribedAccount != null &&
            !_accountMatches(_lastSubscribedAccount, account)) {
          continue; // Skip this position
        }

        final symbol = item[offset + 2].toString();
        final action = int.tryParse(item[offset + 3].toString()) ?? 0;
        final volume = double.tryParse(item[offset + 4].toString()) ?? 0.0;
        final priceOpen = double.tryParse(item[offset + 5].toString()) ?? 0.0;
        final priceCurrent =
            double.tryParse(item[offset + 6].toString()) ?? 0.0;
        final profit = double.tryParse(item[offset + 7].toString()) ?? 0.0;
        final swap = item.length > offset + 8 ? (double.tryParse(item[offset + 8].toString()) ?? 0.0) : 0.0;
          final priceSLStr = item.length > offset + 9 ? item[offset + 9].toString().trim() : '0';
          final priceTPStr = item.length > offset + 10 ? item[offset + 10].toString().trim() : '0';

          double _parsePrice(String s) {
            if (s.isEmpty || s == '0' || s == 'null' || s == '-') return 0.0;
            final v = double.tryParse(s) ?? 0.0;
            return (v.isNaN || v.isInfinite) ? 0.0 : v;
          }

          final priceSL = _parsePrice(priceSLStr);
          final priceTP = _parsePrice(priceTPStr);

          bool hasServerField = item.length > offset + 11 && item[offset + 11] is String && !RegExp(r'^\d+$').hasMatch(item[offset + 11].toString());
          int serverOffset = hasServerField ? 1 : 0;

          final openedAt = item.length > offset + 11 + serverOffset
              ? (int.tryParse(item[offset + 11 + serverOffset].toString()) ?? 0)
              : 0;
          final digits = item.length > offset + 12 + serverOffset
              ? (int.tryParse(item[offset + 12 + serverOffset].toString()) ?? 5)
              : 5;


        final position = TradingPosition(
          mt5Account: int.tryParse(account) ?? 0,
          position: positionId,
          action: action == 0 ? 'Buy' : 'Sell',
          volume: volume.toString(),
          priceOpen: priceOpen.toString(),
          priceSL: priceSL == 0.0 ? '0' : priceSL.toString(),
          priceTP: priceTP == 0.0 ? '0' : priceTP.toString(),
          priceCurrent: priceCurrent.toString(),
          closeTime: '-',
          timeCreate:
              openedAt > 0
                  ? DateTime.fromMillisecondsSinceEpoch(
                    openedAt * 1000,
                    isUtc: true,
                  ).toIso8601String()
                  : DateHelper.nowUtc().toIso8601String(),
          symbol: symbol,
          logo: '',
          profit: profit,
          digits: digits,
          swap: swap,
        );

        // ✅ ONLY filter batch responses - skip if position was explicitly removed
        // This prevents removed positions from reappearing in batch updates
        final positionIdStr = positionId.toString();
        if (!_removedPositionIds.contains(positionIdStr) &&
            !_tradingController.isPositionDeleted(positionIdStr)) {
          positions.add(position);
        }
      }

      if (positions.isNotEmpty || chunk.isEmpty) {
        _tradingController.updateWebSocketData(
          WebSocketTradingResponse(
            openPositions: OpenPositionsData(
              positions: positions,
              accountinfo: [],
            ),
            pendingOrders: null,
            realtime: true,
            serverTimestamp: DateHelper.nowUtc().millisecondsSinceEpoch ~/ 1000,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Trading WS: Error parsing /ws/op chunk', error: e);
    }
  }

  // Handle /ws/op positions_delta format
  void _handlePositionsDeltaOpFormat(List changes) {
    try {
      // Guard: Block data if _lastSubscribedAccount is null (during unsubscribe)
      if (_lastSubscribedAccount == null) {
        return;
      }

      final currentAccount =
          _accountController.activeMT5Account?.metaAccountNumber;

      for (final change in changes) {
        if (change is Map<String, dynamic>) {
          final action = change['action']?.toString();
          final data = change['data'] as List?;

          if (data == null || data.length < 13) continue;

          // Check format: ["a","op",...], ["u","op",...] or ["op",...]
          final firstElement = data[0].toString();
          bool isAFormat =
              firstElement == 'a' &&
              data.length >= 14 &&
              data[1].toString() == 'op';
          bool isUFormat =
              firstElement == 'u' &&
              data.length >= 14 &&
              data[1].toString() == 'op';
          bool isOpFormat = firstElement == 'op' && data.length >= 13;

          if (!isAFormat && !isUFormat && !isOpFormat) continue;

          // Extract account number for validation
          int offset = (isAFormat || isUFormat) ? 2 : 1;
          if (data.length > offset + 1) {
            final account = data[offset + 1].toString();

            // Validate account number matches current account
            if (currentAccount != null && currentAccount.isNotEmpty && !_accountMatches(currentAccount, account)) {
              continue; // Skip this change
            }

            // Also check _lastSubscribedAccount for additional safety
            if (_lastSubscribedAccount != null &&
                !_accountMatches(_lastSubscribedAccount, account)) {
              continue; // Skip this change
            }
          }

          if (action == 'add' || action == 'update') {
            _handleSinglePositionOpFormat(data);
          } else if (action == 'remove') {
            // Remove position
            final positionId = int.tryParse(data[1].toString()) ?? 0;
            final currentPositions =
                _tradingController.marketPositions
                    .where((p) => p.orderId != positionId.toString())
                    .toList();

            _tradingController.updateWebSocketData(
              WebSocketTradingResponse(
                openPositions: OpenPositionsData(
                  positions:
                      currentPositions
                          .map(
                            (p) => TradingPosition(
                              mt5Account: int.tryParse(p.accountId) ?? 0,
                              position: int.tryParse(p.orderId) ?? 0,
                              action: p.action,
                              volume: p.volume.toString(),
                              priceOpen: p.entryPrice,
                              priceSL:
                                  p.stopLoss.isEmpty || p.stopLoss == '-'
                                      ? '0'
                                      : p.stopLoss,
                              priceTP:
                                  p.takeProfit.isEmpty || p.takeProfit == '-'
                                      ? '0'
                                      : p.takeProfit,
                              priceCurrent: p.currentPrice,
                              closeTime: p.closeTime,
                              timeCreate: p.openTime,
                              symbol: p.symbol,
                              logo: p.flag,
                              profit: p.profitLoss,
                              digits:
                                  p.digits > 0
                                      ? p.digits
                                      : 5, // Use digits from TradePosition
                              swap: p.swap,
                            ),
                          )
                          .toList(),
                  accountinfo: [],
                ),
                pendingOrders: null,
                realtime: true,
                serverTimestamp:
                    DateHelper.nowUtc().millisecondsSinceEpoch ~/ 1000,
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error('Trading WS: Error parsing /ws/op delta', error: e);
    }
  }

  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // ✅ FIX: Stop heartbeat on disconnect
    _stopHeartbeat();

    // Cancel all timers
    _subscriptionRefreshTimer?.cancel();
    _subscriptionRefreshTimer = null;
    _dataRetryTimer?.cancel();
    _dataRetryTimer = null;
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = null;

    // ✅ FIX: Cancel all stream subscriptions to prevent memory leaks
    _mainChannelSubscription?.cancel();
    _mainChannelSubscription = null;
    _openPositionsSubscription?.cancel();
    _openPositionsSubscription = null;
    _marketWatchSubscription?.cancel();
    _marketWatchSubscription = null;
    _symbolsSubscription?.cancel();
    _symbolsSubscription = null;
    _accountChangeSubscription?.cancel();
    _accountChangeSubscription = null;

    if (isConnected.value) {
      try {
        // Close channel
        _channel?.sink.close();
        _channel = null; // Keep this line to nullify the channel

        AppLogger.websocket('Trading WS: Disconnected');
      } catch (e) {
        AppLogger.error('Trading WS: Error during disconnect', error: e);
      }
    }

    isConnected.value = false;
    isReconnecting.value = false;
    _lastDataReceived = null;
    _currentEndpoint = null;
    _isConnecting = false;
  }

  // Manual reconnection
  void reconnect() {
    if (_isDisposed) return;

    AppLogger.websocket('Trading WS: Manual reconnection requested');
    _disconnectWebSocket();
    _reconnectAttempts = 0;
    _initializeWebSocket();
    _connectToMarketWatch();
    _connectToOpenPositions();
    _connectToPendingOrders();
  }

  // Manual disconnect
  void disconnect() {
    AppLogger.websocket('Trading WS: Manual disconnect requested');
    _disconnectWebSocket();
  }

  void disconnectAll() {
    AppLogger.websocket('Trading WS: Disconnecting all channels and cancelling all timers/subscriptions');
    
    // Cancel all timers
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _openPositionsReconnectTimer?.cancel();
    _openPositionsReconnectTimer = null;
    _pendingOrdersReconnectTimer?.cancel();
    _pendingOrdersReconnectTimer = null;
    _marketWatchReconnectTimer?.cancel();
    _marketWatchReconnectTimer = null;
    _symbolsReconnectTimer?.cancel();
    _symbolsReconnectTimer = null;
    _subscriptionRefreshTimer?.cancel();
    _subscriptionRefreshTimer = null;
    _dataRetryTimer?.cancel();
    _dataRetryTimer = null;
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = null;

    // Cancel all subscriptions
    _mainChannelSubscription?.cancel();
    _mainChannelSubscription = null;
    _openPositionsSubscription?.cancel();
    _openPositionsSubscription = null;
    _pendingOrdersSubscription?.cancel();
    _pendingOrdersSubscription = null;
    _marketWatchSubscription?.cancel();
    _marketWatchSubscription = null;
    _symbolsSubscription?.cancel();
    _symbolsSubscription = null;

    // Close and nullify channels
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    try { _openPositionsChannel?.sink.close(); } catch (_) {}
    _openPositionsChannel = null;
    try { _pendingOrdersChannel?.sink.close(); } catch (_) {}
    _pendingOrdersChannel = null;
    try { _marketWatchChannel?.sink.close(); } catch (_) {}
    _marketWatchChannel = null;
    try { _symbolsChannel?.sink.close(); } catch (_) {}
    _symbolsChannel = null;

    isConnected.value = false;
    isOpenPositionsConnected.value = false;
    isPendingOrdersConnected.value = false;
    isMarketWatchConnected.value = false;
    isSymbolsConnected.value = false;
  }

  // Refresh trading data
  void refreshTradingData() {
    if (isConnected.value && !_isDisposed) {
      AppLogger.websocket('Trading WS: Manual refresh requested');
      _requestTradingData();
    } else {}
  }

  // Refresh current trading data without clearing cache/UI first.
  // Use this on app resume so positions/orders stay visible while the socket resubscribes.
  void refreshCurrentTradingData() {
    AppLogger.websocket('Trading WS: Resume refresh requested');

    if (isConnected.value && !_isDisposed) {
      _requestTradingData();
    }
    if (isOpenPositionsConnected.value && !_isDisposed) {
      _requestOpenPositionsData();
    }
    if (isPendingOrdersConnected.value && !_isDisposed) {
      _requestPendingOrdersData();
    }
  }

  // Force refresh trading data (clears cache and requests fresh data)
  void forceRefreshTradingData() {
    AppLogger.websocket('Trading WS: Force refresh requested');

    // Clear all trading data first
    _tradingController.clearAllTradingData();

    // Request fresh data
    refreshCurrentTradingData();
  }

  // Update account without disconnecting (faster account switching)
  // This just refreshes the subscription with new account instead of full reconnect
  void updateAccountAndRefresh() {
    AppLogger.websocket(
      'Trading WS: Updating account and refreshing subscription',
    );

    // If connected, just refresh subscription with new account
    if (isConnected.value && !_isDisposed) {
      // DON'T clear all data immediately to prevent flickering
      // Data will be replaced with new account data when it arrives
      // _tradingController.clearAllTradingData(); // Commented to prevent flickering

      // Request fresh data with new account immediately
      // This will update the data without clearing first (prevents flickering)
      _requestTradingData();
    } else {
      // If not connected, initialize connection
      _initializeWebSocket();
    }
  }

  // Unsubscribe and resubscribe with new account (keeps socket active)
  Future<void> unsubscribeAndResubscribe() async {
    if (_isDisposed) {
      return;
    }

    // Prevent concurrent reconnection attempts
    if (_isConnecting) {
      return;
    }

    // ✅ FIX: Cancel all stream subscriptions before account switch to prevent memory leaks
    _mainChannelSubscription?.cancel();
    _openPositionsSubscription?.cancel();
    _marketWatchSubscription?.cancel();
    _symbolsSubscription?.cancel();

    // If not connected, just initialize normally
    if (!isConnected.value) {
      _tradingController.clearAllTradingData();
      _initializeWebSocket();
      return;
    }

    try {
      // Log to file instead of console
      await AccountSwitchLogger.logSwitchStart(
        _lastSubscribedAccount,
        _accountController.activeMT5Account?.metaAccountNumber ?? 'unknown',
      );

      // Step 1: Clear trading data and block incoming data BEFORE unsubscribe
      await AccountSwitchLogger.logStep(1, 'Clearing all trading data');
      _tradingController.clearAllTradingData();

      // ✅ FIX: Clear marketwatch/instruments data when switching accounts
      try {
        if (Get.isRegistered<InstrumentsController>()) {
          final instrumentsController = Get.find<InstrumentsController>();
          instrumentsController.clearInstrumentsData();
          await AccountSwitchLogger.log('Cleared instruments data');
        }
      } catch (e) {
        // InstrumentsController might not be registered, continue
      }

      // ✅ FIX: Clear removed position tracking on account switch
      // This prevents removed positions from previous account blocking new account's positions
      _removedPositionIds.clear();
      _removedPendingOrderIds.clear();
      _lastSubscribedAccount =
          null; // Block all incoming data during transition

      await AccountSwitchLogger.log('Data cleared, blocking incoming messages');

      // Step 2: Unsubscribe from ALL THREE channels at the same time
      // This ensures old data stops coming from all channels simultaneously
      await AccountSwitchLogger.logStep(
        2,
        'Sending UNSUBSCRIBE to all channels',
      );
      await AccountSwitchLogger.logRequest('Main Channel', {
        'type': 'unsubscribe',
      });
      _unsubscribeCompleter = Completer<void>();

      // Send unsubscribe to main channel
      _sendEvent({"type": "unsubscribe"});

      // Send unsubscribe to open positions channel
      if (isOpenPositionsConnected.value && _openPositionsChannel != null) {
        await AccountSwitchLogger.logRequest('Open Positions Channel', {
          'type': 'unsubscribe',
        });
        _sendEventToChannel(_openPositionsChannel, {"type": "unsubscribe"});
      }

      // ✅ FIX: Send unsubscribe to marketwatch channel at the same time
      if (isMarketWatchConnected.value && _marketWatchChannel != null) {
        await AccountSwitchLogger.logRequest('MarketWatch Channel', {
          'type': 'unsubscribe',
        });
        _sendEventToChannel(_marketWatchChannel, {"type": "unsubscribe"});
      }

      await AccountSwitchLogger.log('Waiting for unsubscribe confirmation...');

      // Step 3: Wait for unsubscribe confirmation (with shorter timeout for faster switching)
      try {
        await _unsubscribeCompleter!.future.timeout(
          const Duration(milliseconds: 500), // Reduced from 2 seconds to 500ms
          onTimeout: () {
            if (_unsubscribeCompleter != null &&
                !_unsubscribeCompleter!.isCompleted) {
              _unsubscribeCompleter!.complete();
              _unsubscribeCompleter = null;
            }
          },
        );
        await AccountSwitchLogger.logSuccess(
          'Unsubscribe confirmation received',
        );
      } catch (e) {
        await AccountSwitchLogger.logWarning(
          'Unsubscribe timeout or error: $e',
        );
      }

      // 🔴 BREAKPOINT 1: After unsubscribe, before clearing in-flight messages
      await AccountSwitchLogger.logBreakpoint(1, 'Unsubscribe complete', {
        'Main channel connected': isConnected.value,
        'Open Positions connected': isOpenPositionsConnected.value,
        'MarketWatch connected': isMarketWatchConnected.value,
        'Last subscribed account': _lastSubscribedAccount ?? 'null',
      });
      // Pause to allow inspection
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 4: Wait for in-flight messages to clear (all three channels)
      await AccountSwitchLogger.logStep(
        3,
        'Waiting 100ms for in-flight messages to clear',
      );
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 5: Get new account number and set it BEFORE resubscribing
      final activeAccount = _accountController.activeMT5Account;
      final newAccountNumber = activeAccount?.metaAccountNumber ?? "0";

      await AccountSwitchLogger.logStep(
        4,
        'New account number: $newAccountNumber',
      );

      if (newAccountNumber == "0" || newAccountNumber.isEmpty) {
        await AccountSwitchLogger.logError(
          'No valid account number, aborting switch',
        );
        return;
      }

      // Step 6: Set new account number BEFORE resubscribing to block old account data
      _lastSubscribedAccount = newAccountNumber;
      await AccountSwitchLogger.logStep(
        5,
        'Set _lastSubscribedAccount = $newAccountNumber',
      );

      // 🔴 BREAKPOINT 2: After setting new account, before reconnecting
      await AccountSwitchLogger.logBreakpoint(
        2,
        'New account set, ready to reconnect',
        {
          'Old account': _lastSubscribedAccount ?? 'null',
          'New account': newAccountNumber,
          'Account type': activeAccount?.tradingServer ?? 'unknown',
          'Main channel connected': isConnected.value,
          'Open Positions connected': isOpenPositionsConnected.value,
          'MarketWatch connected': isMarketWatchConnected.value,
        },
      );
      // Pause to allow inspection
      await Future.delayed(const Duration(milliseconds: 200));

      // ✅ CRITICAL FIX: Re-authenticate BOTH channels - main channel AND open positions channel
      // Main channel and open positions channel are SEPARATE WebSocket connections
      // Each needs its own authentication for the new account
      // Unsubscribe was already sent to both channels above, now re-authenticate

      // ✅ FIX: Force disconnect and reconnect open positions channel to ensure clean state
      // This ensures the channel is properly re-authenticated with the new account number
      // when switching between accounts of the same type (self-hosted to self-hosted, MT5 to MT5)
      await AccountSwitchLogger.logStep(
        6,
        'Reconnecting Open Positions channel',
      );
      if (isOpenPositionsConnected.value && _openPositionsChannel != null) {
        // Disconnect first to ensure clean state
        await AccountSwitchLogger.log(
          'Closing existing Open Positions connection',
        );
        _openPositionsChannel?.sink.close();
        isOpenPositionsConnected.value = false;
        _openPositionsSubscription?.cancel();
        _openPositionsSubscription = null;
        _openPositionsChannel = null;
        // Small delay to ensure connection is fully closed
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // Always reconnect to ensure fresh connection with new account
      _connectToOpenPositions();

      // ✅ FIX: Also reconnect marketwatch channel with new account
      // Disconnect first to ensure clean state
      await AccountSwitchLogger.logStep(7, 'Reconnecting MarketWatch channel');
      if (isMarketWatchConnected.value && _marketWatchChannel != null) {
        await AccountSwitchLogger.log(
          'Closing existing MarketWatch connection',
        );
        _marketWatchChannel?.sink.close();
        isMarketWatchConnected.value = false;
        _marketWatchSubscription?.cancel();
        _marketWatchSubscription = null;
        _marketWatchChannel = null;
        // Small delay to ensure connection is fully closed
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // Always reconnect marketwatch to ensure fresh connection with new account
      _connectToMarketWatch();

      // Re-auth main channel
      await AccountSwitchLogger.logStep(
        8,
        'Re-authenticating main channel with account $newAccountNumber',
      );
      _requestTradingData();

      // 🔴 BREAKPOINT 3: After all reconnections, waiting for responses
      await AccountSwitchLogger.logBreakpoint(
        3,
        'All channels reconnected, subscribe requests sent',
        {
          'Main channel connected': isConnected.value,
          'Open Positions connected': isOpenPositionsConnected.value,
          'MarketWatch connected': isMarketWatchConnected.value,
          'Current account': _lastSubscribedAccount ?? 'null',
        },
      );
      await AccountSwitchLogger.log('');
      await AccountSwitchLogger.log(
        '⏳ Watch for these responses in next 2-3 seconds:',
      );
      await AccountSwitchLogger.log(
        '   📥 RESPONSE: Authentication success - type: authenticated',
      );
      await AccountSwitchLogger.log(
        '   📥 RESPONSE: Authentication success - type: positions_joined',
      );
      await AccountSwitchLogger.log(
        '   📥 RESPONSE: Authentication success - type: pending_orders_joined',
      );
      // Pause to allow inspection
      await Future.delayed(const Duration(milliseconds: 300));

      await AccountSwitchLogger.logSwitchComplete();
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error in unsubscribeAndResubscribe',
        error: e,
      );
      // Fallback: if unsubscribe/resubscribe fails, do full reconnect
      _disconnectWebSocket();
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // Reduced from 150ms to 50ms
      _reconnectAttempts = 0;
      if (!_isDisposed) {
        _initializeWebSocket();
      }
    }
  }

  // Disconnect and reconnect with new account (for account switching)
  // This ensures clean connection with new account number
  Future<void> disconnectAndReconnect() async {
    if (_isDisposed) {
      return;
    }

    // Prevent concurrent reconnection attempts
    if (_isConnecting) {
      return;
    }

    // ✅ FIX: Cancel all stream subscriptions before reconnecting to prevent memory leaks
    _mainChannelSubscription?.cancel();
    _openPositionsSubscription?.cancel();
    _marketWatchSubscription?.cancel();
    _symbolsSubscription?.cancel();
    _accountChangeSubscription?.cancel();

    // ✅ FIX: Disconnect ALL WebSocket channels, not just main channel
    // This ensures old MT5/Self-hosted endpoints are fully closed
    _disconnectWebSocket();
    _disconnectOpenPositions();
    _disconnectPendingOrders();
    _disconnectMarketWatch();
    _disconnectSymbols();

    // Reset reconnection attempts for fresh start
    _reconnectAttempts = 0;

    // Reconnect with new account immediately (will use correct endpoints based on new account type)
    if (!_isDisposed) {
      _initializeWebSocket();
      // Reconnect all channels simultaneously
      _initializeAllConnections();
      AppLogger.websocket('Trading WS: Reconnected with new account');
    }
  }

  // Clear all trading data and disconnect (called on logout)
  void clearAllDataAndDisconnect() {
    AppLogger.websocket('Trading WS: Clearing all data and disconnecting...');

    // Disconnect WebSocket
    _disconnectWebSocket();

    // Clear trading controller data if it exists
    try {
      if (Get.isRegistered<TradingController>()) {
        final tradingController = Get.find<TradingController>();
        tradingController.clearAllTradingData();
      }
    } catch (e) {
      AppLogger.error(
        'Trading WS: Error clearing trading controller',
        error: e,
      );
    }

    // Reset reconnection attempts
    _reconnectAttempts = 0;
  }

  // ✅ OPTIMIZATION: Atomic account switch - keeps connection open
  // This is faster than unsubscribe + reconnect + authenticate
  Completer<void>? _switchAccountCompleter;

  Future<void> switchAccount(String newAccountNumber) async {
    if (_isDisposed) return;

    // If not connected, fall back to normal reconnect flow
    if (!isConnected.value) {
      _tradingController.clearAllTradingData();
      _initializeWebSocket();
      return;
    }

    try {
      AppLogger.websocket('Trading WS: switchAccount to $newAccountNumber');

      // ✅ FIX: Check if account TYPE changed (selfhosted vs MT5)
      // If type changed, URL changes too - need full reconnect, not just switch_account
      final accountController = _accountController;
      final newAccount = accountController.mt5Accounts.firstWhereOrNull(
        (acc) => acc.metaAccountNumber == newAccountNumber,
      );
      final currentAccount = accountController.activeMT5Account;

      final wassMT5 = currentAccount?.tradingServer.toUpperCase() == 'MT5';
      final isNowMT5 = newAccount?.tradingServer.toUpperCase() == 'MT5';

      if (wassMT5 != isNowMT5) {
        // Account type changed - need full disconnect/reconnect
        AppLogger.websocket(
          'Trading WS: Account type changed (MT5: $wassMT5 -> $isNowMT5), doing full reconnect',
        );
        _tradingController.clearAllTradingData();
        await disconnectAndReconnect();
        return;
      }

      // Clear local data immediately
      _tradingController.clearAllTradingData();
      _removedPositionIds.clear();
      _removedPendingOrderIds.clear();

      // Clear instruments if registered
      try {
        if (Get.isRegistered<InstrumentsController>()) {
          Get.find<InstrumentsController>().clearInstrumentsData();
        }
      } catch (_) {}

      // Get auth token
      final authToken = await SecureStorageService.getAuthToken();
      if (authToken == null) {
        AppLogger.websocket(
          'Trading WS: No auth token for switch, falling back to reconnect',
        );
        await disconnectAndReconnect();
        return;
      }

      // Send atomic switch_account message
      _switchAccountCompleter = Completer<void>();
      _sendEvent({
        "type": "switch_account",
        "authID": authToken,
        "trading_account": newAccountNumber,
      });

      // Also send to open positions channel if connected
      if (isOpenPositionsConnected.value && _openPositionsChannel != null) {
        _sendEventToChannel(_openPositionsChannel, {
          "type": "switch_account",
          "authID": authToken,
          "trading_account": newAccountNumber,
        });
      }

      // ✅ FIX: Also send to pending orders channel if connected
      if (isPendingOrdersConnected.value && _pendingOrdersChannel != null) {
        _sendEventToChannel(_pendingOrdersChannel, {
          "type": "switch_account",
          "authID": authToken,
          "trading_account": newAccountNumber,
        });
      }

      // ✅ FIX: Also send to marketwatch channel if connected
      if (isMarketWatchConnected.value && _marketWatchChannel != null) {
        _sendEventToChannel(_marketWatchChannel, {
          "type": "switch_account",
          "authID": authToken,
          "trading_account": newAccountNumber,
        });
      }

      // Wait for account_switched confirmation (with timeout)
      try {
        await _switchAccountCompleter!.future.timeout(
          const Duration(milliseconds: 2000),
          onTimeout: () {
            if (_switchAccountCompleter != null &&
                !_switchAccountCompleter!.isCompleted) {
              _switchAccountCompleter!.complete();
              _switchAccountCompleter = null;
            }
          },
        );
      } catch (e) {
        AppLogger.websocket('Trading WS: Switch timeout: $e');
      }

      // Update last subscribed account
      _lastSubscribedAccount = newAccountNumber;

      AppLogger.websocket('Trading WS: switchAccount complete');
    } catch (e) {
      AppLogger.error('Trading WS: switchAccount error', error: e);
      // Fall back to full reconnect on error
      await disconnectAndReconnect();
    } finally {
      _switchAccountCompleter = null;
    }
  }

  // Reset and reconnect with new account (called on login)
  void resetAndReconnect() {
    // Clear all data first
    clearAllDataAndDisconnect();

    // Reset disposed flag
    _isDisposed = false;

    // Reconnect after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        _initializeWebSocket();
      }
    });
  }

  // Force endpoint switch when account type changes
  Future<void> forceEndpointSwitch(String accountType) async {
    // Clear all trading data caches
    _clearAllTradingCaches();

    // Force reconnection with new endpoints
    await disconnectAndReconnect();
  }

  // Clear all trading caches when switching account types
  void _clearAllTradingCaches() {
    try {
      AppLogger.websocket('Trading WS: Clearing all trading caches');

      // Clear all trading data using the controller method
      // This clears openPositions, pendingOrders, and all other trading data
      _tradingController.clearAllTradingData();

      // Disconnect all channels to force reconnection with new endpoints
      _disconnectOpenPositions();
      _disconnectMarketWatch();
      _disconnectSymbols();

      // Reset session state
      _lastDataReceived = null;
      _lastSubscribedAccount = null;

      // Clear removed IDs tracking (new account = fresh start)
      _removedPositionIds.clear();
      _removedPendingOrderIds.clear();

      // Reset reconnect attempts for fresh start
      _openPositionsReconnectAttempts = 0;
      _marketWatchReconnectAttempts = 0;
      _symbolsReconnectAttempts = 0;

      AppLogger.websocket('Trading WS: Trading cache clearing completed');
    } catch (e) {
      AppLogger.error('Trading WS: Error clearing trading caches', error: e);
    }
  }

  // Subscribe to single symbol for MT5 accounts
  void subscribeToSingleSymbol(String symbol) async {
    final activeAccount = _accountController.activeMT5Account;
    if (activeAccount == null) {
      return;
    }

    // Use symbols channel for MT5 accounts, main channel for self-hosted
    final isMT5Account = activeAccount.tradingServer.toUpperCase() == "MT5";
    final targetChannel = isMT5Account ? _symbolsChannel : _channel;
    final isChannelConnected =
        isMT5Account ? isSymbolsConnected.value : isConnected.value;

    if (!isChannelConnected || targetChannel == null) {
      return;
    }

    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) {
      return;
    }

    final event = {
      "authID": authId,
      "trading_account": activeAccount.metaAccountNumber,
      "symbol": symbol,
      "type": "subscribe_symbols",
    };

    if (isMT5Account) {
      _sendEventToChannel(targetChannel, event);
    } else {
      _sendEvent(event);
    }
  }

  // Unsubscribe from single symbol
  void unsubscribeFromSingleSymbol(String symbol) async {
    final activeAccount = _accountController.activeMT5Account;
    if (activeAccount == null) return;

    final isMT5Account = activeAccount.tradingServer.toUpperCase() == "MT5";
    final targetChannel = isMT5Account ? _symbolsChannel : _channel;
    final isChannelConnected =
        isMT5Account ? isSymbolsConnected.value : isConnected.value;

    if (!isChannelConnected || targetChannel == null) return;

    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) return;

    final event = {
      "authID": authId,
      "trading_account": activeAccount.metaAccountNumber,
      "symbol": symbol,
      "type": "unsubscribe_symbols",
    };

    if (isMT5Account) {
      _sendEventToChannel(targetChannel, event);
    } else {
      _sendEvent(event);
    }
  }

  // Connect to market watch endpoint
  void connectToMarketWatch() {
    if (!isMarketWatchConnected.value) {
      _connectToMarketWatch();
    }
  }

  // Connect to symbols endpoint
  void connectToSymbols() {
    if (!isSymbolsConnected.value) {
      _connectToSymbols();
    }
  }

  // Disconnect from market watch
  void disconnectFromMarketWatch() {
    _disconnectMarketWatch();
  }

  // Disconnect from symbols
  void disconnectFromSymbols() {
    _disconnectSymbols();
  }
}
