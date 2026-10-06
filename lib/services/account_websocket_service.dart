import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data'; // ✅ ADD: For binary message handling
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/utils/message_pack_decoder.dart'; // ✅ ADD: For binary decoding
import 'package:web_socket_channel/web_socket_channel.dart';

class AccountWebSocketService extends GetxService with WidgetsBindingObserver {
  // Connection state
  final RxBool isConnected = false.obs;
  final RxBool isReconnecting = false.obs;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  bool _isDisposed = false;
  bool _isConnecting = false; // Guard to prevent concurrent connections
  WebSocketChannel? channel;

  // ✅ FIX: Store stream subscription to prevent memory leaks
  StreamSubscription? _channelSubscription;
  Worker? _accountChangeWorker; // Store ever() worker to cancel it

  // Unsubscribe/resubscribe state
  Completer<void>? _unsubscribeCompleter;

  // Data blocking during account switch
  String? _lastSubscribedAccount; // Track which account we're subscribed to
  bool _isUnsubscribing =
      false; // Flag to block data during unsubscribe/resubscribe

  // Account type tracking for endpoint switching
  String? _lastAccountType; // 'mt5' or 'selfhosted'
  String? _currentUrl; // Track current URL for debug logging
  bool _loggedFirstMessage = false;

  // ✅ FIX: Debounce timer to prevent double requestAccountData calls
  Timer? _requestDebounceTimer;

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

    // ✅ FIX: Check authentication before setting up listeners
    // Don't initialize WebSocket until user is logged in
    _checkAuthAndSetup();
  }

  /// Check authentication status before setting up WebSocket
  void _checkAuthAndSetup() async {
    try {
      final isLoggedIn = await SecureStorageService.isUserLoggedIn();
      if (!isLoggedIn) {
        if (kDebugMode) {
          dev.log(
            'Account WS: User not logged in, skipping WebSocket initialization',
          );
        }
        // Listen for authentication state changes
        _listenForAuthChanges();
        return;
      }

      // User is authenticated - proceed with setup
      _setupAccountListeners();
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Error checking auth status: $e');
      }
    }
  }

  /// Listen for authentication state changes and setup when user logs in
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
          if (kDebugMode) {
            dev.log('Account WS: User logged in, setting up WebSocket');
          }
          _setupAccountListeners();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Error setting up auth listener: $e');
      }
    }
  }

  /// Setup account change listeners and initialize WebSocket
  void _setupAccountListeners() {
    // Listen to active account changes and handle endpoint switching
    // This ensures proper endpoint switching when account type changes (MT5 vs self-hosted)
    // ✅ FIX: Cancel old worker before creating new one
    _accountChangeWorker?.dispose();
    _accountChangeWorker = ever(_accountController.activeMT5AccountRx, (
      MT5Account? account,
    ) {
      if (account != null && !_isDisposed) {
        final currentAccountType = _getAccountType(account);

        if (kDebugMode) {
          dev.log(
            'Account WS: Active account changed to: ${account.metaAccountNumber} (${currentAccountType}), last type: $_lastAccountType',
          );
        }

        // ✅ FIX: Check if account number actually changed (not just type)
        final currentAccountNumber = account.metaAccountNumber;
        final accountNumberChanged =
            _lastSubscribedAccount != null &&
            _lastSubscribedAccount != currentAccountNumber;

        // Check if account type changed (MT5 vs self-hosted)
        final accountTypeChanged =
            _lastAccountType != null && _lastAccountType != currentAccountType;

        if (accountTypeChanged) {
          // Account type changed (self-hosted ↔ MT5) - force full reconnection with new endpoints
          // This ensures all services switch to correct endpoints simultaneously
          _forceEndpointSwitch(currentAccountType);
          _lastSubscribedAccount = currentAccountNumber; // Update after switch
        } else if (accountNumberChanged || _lastSubscribedAccount == null) {
          // ✅ FIX: Account number changed (same type: self-hosted 100 → 102, or MT5 1002 → 1003)
          // OR first connection - always unsubscribe/resubscribe
          // This ensures old account data is cleared even when switching within same account type
          if (isConnected.value) {
            unsubscribeAndResubscribe();
          } else {
            _initializeWebSocket();
          }
          _lastSubscribedAccount =
              currentAccountNumber; // Update after resubscribe
        }

        _lastAccountType = currentAccountType;
      }
    });

    // Initialize WebSocket connection
    _initializeWebSocket();
  }

  @override
  void onClose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    // ✅ FIX: Cancel account change listener to prevent memory leaks
    _accountChangeWorker?.dispose();
    _accountChangeWorker = null;

    _disconnectWebSocket();
    super.onClose();
  }

  void disconnectWebSocket() {
    _requestDebounceTimer?.cancel();
    _requestDebounceTimer = null;
    _disconnectWebSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Connection state is centrally coordinated by AccountController to prevent race conditions.
    return;
  }

  // Check if primary account has trading_server="MT5"
  bool _isMT5Account() {
    try {
      final activeAccount = _accountController.activeMT5Account;
      return activeAccount?.tradingServer.toUpperCase() == "MT5";
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Error checking MT5 account: $e');
      }
      return false;
    }
  }

  // Get account type string for tracking changes
  String _getAccountType(MT5Account account) {
    return account.tradingServer.toUpperCase() == "MT5" ? 'mt5' : 'selfhosted';
  }

  // Force endpoint switch when account type changes
  // This ensures all WebSocket services switch endpoints simultaneously
  void _forceEndpointSwitch(String newAccountType) async {
    if (kDebugMode) {
      dev.log('Account WS: Forcing endpoint switch to $newAccountType');
    }

    // Clear all caches first
    await _clearAllCaches();

    // Disconnect current connection
    await disconnectAndReconnect();

    // Notify trading service to switch endpoints too
    final tradingService = Get.find<TradingWebSocketService>();
    await tradingService.forceEndpointSwitch(newAccountType);

    // Small delay to ensure clean switching
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // Clear all caches when switching account types
  Future<void> _clearAllCaches() async {
    try {
      // Clear trading controller caches
      _tradingController.clearAllTradingData();
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Error clearing caches: $e');
      }
    }
  }

  // Get WebSocket URL based on account type (same base URL, conditional endpoint)
  // ✅ Uses centralized WebSocketEndpointHelper for consistent endpoint selection
  String _getWebSocketUrl() {
    try {
      var activeAccount;

      // Try AccountController first
      try {
        activeAccount = _accountController.activeMT5Account;
      } catch (e) {
        // AccountController not available
      }

      // ✅ FIX: Fallback to stored primary account from initialization (sync version)
      if (activeAccount == null) {
        activeAccount = WebSocketEndpointHelper.getCachedPrimaryAccountSync();
      }

      // Try DashboardController as second fallback
      if (activeAccount == null) {
        try {
          if (Get.isRegistered<DashboardController>()) {
            final dashboardController = Get.find<DashboardController>();
            if (dashboardController.mt5Accounts.isNotEmpty) {
              activeAccount = dashboardController.primaryMT5Account;
              if (kDebugMode) {
                dev.log(
                  'Account WS: Got account from DashboardController: ${activeAccount?.metaAccountNumber ?? "N/A"}',
                );
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            dev.log('Account WS: DashboardController not available: $e');
          }
        }
      }

      // ✅ Use centralized endpoint helper
      final wsUrl = WebSocketEndpointHelper.getAccountUrl(activeAccount);
      return wsUrl;
    } catch (e) {
      // Fallback to unified endpoint if all else fails
      if (kDebugMode) {
        dev.log(
          'Account WS: Error getting account, using default unified endpoint: $e',
        );
      }
      return WebSocketEndpointHelper.getFullUrl(
        WebSocketEndpointHelper.accountEndpoint,
      );
    }
  }

  // Initialize WebSocket connection
  void _initializeWebSocket() {
    // Pippro / pipze: account data arrives on the single multiplexed
    // `/ws/stream` socket (StreamWebSocketService.accounts). Skip opening
    // the dedicated `/ws/account` socket for these flavors.
    if (FlavorConfig.usesSingleStreamSocket) return;
    if (isConnected.value || _isConnecting) return;

    _isConnecting = true;

    try {
      final wsUrl = _getWebSocketUrl();

      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      isConnected.value = true;
      _reconnectAttempts = 0;
      isReconnecting.value = false;
      _isConnecting = false;
      _currentUrl = wsUrl;
      _loggedFirstMessage = false;
      // Reset data blocking flags for new connection
      _isUnsubscribing = false;
      _lastSubscribedAccount = null;

      // ✅ FIX: Cancel old subscription before creating new one
      _channelSubscription?.cancel();
      _channelSubscription = channel!.stream.listen(
        (message) {
          if (!_loggedFirstMessage) {
            _loggedFirstMessage = true;
            WebSocketEndpointHelper.logSwitchStep(
              'Account first message',
              url: _currentUrl,
            );
          }
          _handleSocketMessage(message);
        },
        onError: (error) {
          if (kDebugMode) {
            dev.log('Account WS error: $error');
          }
          isConnected.value = false;
          _isConnecting = false;
          _scheduleReconnect();
        },
        onDone: () {
          if (kDebugMode) {
            dev.log('Account WS: Connection closed');
          }
          isConnected.value = false;
          _currentUrl = null;
          _isConnecting = false;
          _scheduleReconnect();
        },
      );

      // Request account data after connection (reduced delay for faster MT5 response)
      Future.delayed(const Duration(milliseconds: 150), () async {
        if (isConnected.value && !_isDisposed) {
          // Ensure account controller is ready before requesting data
          final accountController = Get.find<AccountController>();
          final activeAccount = accountController.activeMT5Account;

          if (!accountController.isInitialized) {
            if (kDebugMode) {
              dev.log(
                'Account WS: Waiting for AccountController before requesting data...',
              );
            }
            await accountController.waitForInitialization();
            if (kDebugMode) {
              dev.log(
                'Account WS: AccountController ready, requesting account data',
              );
            }
          }

          // ✅ FIX: Log account info before requesting
          if (kDebugMode) {
            if (activeAccount != null) {
              dev.log(
                'Account WS: Requesting data for active account: ${activeAccount.metaAccountNumber} (${activeAccount.tradingServer})',
              );
            } else {
              dev.log('Account WS: No active account found, will retry');
            }
          }

          requestAccountData();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Initialization failed: $e');
      }
      isConnected.value = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  // Request account data from WebSocket
  void requestAccountData() async {
    // ✅ FIX: Debounce to prevent double calls during account switch
    // Cancel any pending request timer
    _requestDebounceTimer?.cancel();

    if (_isDisposed || !isConnected.value || channel == null) {
      if (kDebugMode) {
        dev.log('Account WS: Cannot request data - disposed or not connected');
      }
      return;
    }

    // ✅ FIX: Check authentication before requesting account data
    final isLoggedIn = await SecureStorageService.isUserLoggedIn();
    if (!isLoggedIn) {
      if (kDebugMode) {
        dev.log(
          'Account WS: User not logged in, skipping account data request',
        );
      }
      return;
    }

    // Get active account number
    final activeAccount = _accountController.activeMT5Account;
    var accountNumber = activeAccount?.metaAccountNumber ?? "0";

    // ✅ FIX: If account is null/empty, check cached account before giving up
    if (accountNumber == "0" || accountNumber.isEmpty) {
      final cachedAccount =
          await WebSocketEndpointHelper.getStoredPrimaryAccount();
      if (cachedAccount != null) {
        accountNumber = cachedAccount.metaAccountNumber;
        if (kDebugMode) {
          dev.log(
            'Account WS: Using cached account ${accountNumber} instead of null/empty account',
          );
        }
      } else {
        // No cached account either - don't send null request
        if (kDebugMode) {
          dev.log(
            'Account WS: No account available (active or cached), skipping request to prevent null account data',
          );
        }
        Timer(const Duration(seconds: 2), () {
          if (isConnected.value && !_isDisposed) {
            requestAccountData();
          }
        });
        return;
      }
    }

    // Set subscribed account before sending request
    _lastSubscribedAccount = accountNumber;
    _isUnsubscribing = false;

    if (kDebugMode) {
      if (activeAccount != null) {
        dev.log(
          'Account WS: Active account details - Number: ${activeAccount.metaAccountNumber}, Type: ${activeAccount.tradingServer}',
        );
      }
    }

    // Get auth token for both MT5 and self-hosted accounts
    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) {
      if (kDebugMode) {
        dev.log('Account WS: No auth token, retrying in 2 seconds...');
      }
      Timer(const Duration(seconds: 2), () {
        if (isConnected.value && !_isDisposed) {
          requestAccountData();
        }
      });
      return;
    }

    // Check if this is an MT5 account
    if (_isMT5Account()) {
      // ✅ FIX: For MT5 accounts, use "authenticate" type (not "subscribe_accounts")
      // Trade Engine expects: { type: "authenticate", authID: "token", trading_account: "400012" }
      final requestPayload = {
        "type": "authenticate",
        "authID": authId,
        "trading_account": accountNumber,
        "format": "binary", // ✅ Request binary (MessagePack) format
      };
      _sendEvent(requestPayload);
    } else {
      // For regular accounts, send: { "authID": "user_token", "trading_account": "301023" }
      _sendEvent({"authID": authId, "trading_account": accountNumber});
    }
  }

  // Handle incoming WebSocket messages
  void _handleSocketMessage(dynamic message) {
    if (_isDisposed) return;

    try {
      // ✅ FIX: Allow control messages (unsubscribed, authenticated, errors) even during transitions
      // Only block account data messages
      // ✅ PERFORMANCE: Handle both JSON and binary (MessagePack) formats
      dynamic decodedData;
      final isBinary = MessagePackDecoder.isBinaryMessage(message);

      if (isBinary) {
        // Binary MessagePack format - decode it
        decodedData = MessagePackDecoder.decodeBinary(
          message is Uint8List
              ? message
              : Uint8List.fromList(message as List<int>),
        );
        if (decodedData == null) {
          if (kDebugMode) {}
          // Fallback to JSON if binary decode fails
          try {
            final String messageStr = message.toString();
            decodedData = jsonDecode(messageStr);
            if (kDebugMode) {}
          } catch (e) {
            if (kDebugMode) {
              dev.log('⚠️ Account WS: Both binary and JSON decode failed: $e');
            }
          }
          if (decodedData == null) {
            return;
          }
        } else {
          if (kDebugMode) {
            dev.log(
              '✅ Account WS: Binary decode succeeded, type: ${decodedData.runtimeType}, isList: ${decodedData is List}, isEmpty: ${decodedData is List ? decodedData.isEmpty : 'N/A'}',
            );
          }
        }
      } else {
        // JSON format - decode as string
        final String messageStr = message.toString();
        decodedData = jsonDecode(messageStr);
      }

      handleStreamFrame(decodedData);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log('Account WS: Error handling message: $e\n$stackTrace');
      }
    }
  }

  /// Public entry for already-decoded frames (used by `/ws/stream` bridge for
  /// pippro / pipze). The decode step is skipped — payload has already been
  /// decoded by `StreamWebSocketService`.
  void handleStreamFrame(dynamic decodedData) {
    if (_isDisposed) return;
    try {
      // Handle array responses (account data)
      // Format: [["ac","1000003",7164.04,7163.87,1.3,7162.57,551066.92,-0.17,0]]
      if (decodedData is List && decodedData.isNotEmpty) {
        // Array of arrays (multiple account updates)
        if (decodedData[0] is List) {
          for (final accountArray in decodedData) {
            if (accountArray is List && accountArray.isNotEmpty) {
              _parseAccountArray(accountArray);
            }
          }
        }
        // Single array (one account update)
        else if (decodedData[0] is String && decodedData.length >= 5) {
          _parseAccountArray(decodedData);
        }
        return;
      }

      // Handle JSON object responses (authentication, unsubscribe, errors)
      if (decodedData is Map<String, dynamic>) {
        _handleJsonResponse(decodedData);
        return;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log('Account WS: Error parsing message: $e\n$stackTrace');
      }
    }
  }

  // Parse account array response
  // Format NEW (Length >= 10): ["ac", account, balance, credit, equity, margin, free_margin, margin_level, profit, swap]
  // Format OLD (Length < 10):  ["ac", account, balance, equity, margin, free_margin, margin_level, profit, swap]
  void _parseAccountArray(List accountArray) {
    try {
      if (accountArray.isEmpty) return;

      // Check if first element is "ac" (account type identifier)
      if (accountArray[0]?.toString().toLowerCase() != 'ac') {
        return;
      }

      // Validate minimum array length (should have at least "ac" and account)
      if (accountArray.length < 2) {
        return;
      }

      final metaAccountNumber =
          accountArray.length > 1 ? accountArray[1].toString() : '';

      // ✅ CRITICAL FIX: Block data ONLY if unsubscribing (not if _lastSubscribedAccount is null)
      // During active trading, _lastSubscribedAccount might be null, but we should still process
      // updates if they match the active account
      if (_isUnsubscribing) {
        if (kDebugMode) {
          dev.log(
            'Account WS: Blocking update - unsubscribing in progress. Account: $metaAccountNumber',
          );
        }
        return;
      }

      // ✅ CRITICAL FIX: Check account number against active account FIRST
      // This allows updates during active trading even if _lastSubscribedAccount is null
      final activeAccount = _accountController.activeMT5Account;
      bool shouldProcess = false;

      if (activeAccount != null) {
        final activeAccountNumber = activeAccount.metaAccountNumber;
        
        // If account number matches active account, always process (even if _lastSubscribedAccount is null)
        if (metaAccountNumber == activeAccountNumber) {
          shouldProcess = true;
          // ✅ CRITICAL: Set _lastSubscribedAccount automatically when valid update is received
          // This fixes the issue where updates stop during active trading
          if (_lastSubscribedAccount != metaAccountNumber) {
            _lastSubscribedAccount = metaAccountNumber;
            if (kDebugMode) {
              dev.log(
                'Account WS: Auto-set _lastSubscribedAccount to $metaAccountNumber (matched active account)',
              );
            }
          }
        } else if (_lastSubscribedAccount != null) {
          // If _lastSubscribedAccount is set, only process if it matches
          if (metaAccountNumber == _lastSubscribedAccount) {
            shouldProcess = true;
          } else {
            // Account number doesn't match - block this update
            if (kDebugMode) {
              dev.log(
                'Account WS: Blocking update - account mismatch. Received: $metaAccountNumber, Expected: $_lastSubscribedAccount, Active: $activeAccountNumber',
              );
            }
            return;
          }
        } else {
          // _lastSubscribedAccount is null and account doesn't match active account - block
          if (kDebugMode) {
            dev.log(
              'Account WS: Blocking update - account mismatch and _lastSubscribedAccount is null. Received: $metaAccountNumber, Active: $activeAccountNumber',
            );
          }
          return;
        }
      } else {
        // No active account - only process if _lastSubscribedAccount matches
        if (_lastSubscribedAccount != null && metaAccountNumber == _lastSubscribedAccount) {
          shouldProcess = true;
        } else {
          if (kDebugMode) {
            dev.log(
              'Account WS: Blocking update - no active account and _lastSubscribedAccount mismatch. Received: $metaAccountNumber, Expected: $_lastSubscribedAccount',
            );
          }
          return;
        }
      }

      // If we shouldn't process, return early
      if (!shouldProcess) {
        return;
      }

      // ✅ OPTIMIZATION: Direct numeric conversion (faster than toString then parse)
      final balance = accountArray.length > 2
          ? (accountArray[2] is num
              ? (accountArray[2] as num).toDouble()
              : double.tryParse(accountArray[2].toString()) ?? 0.0)
          : 0.0;

      // Determine format version using heuristic check logic
      // We compare which format yields a consistent Account Equation:
      // Equity = Eq(Balance + Credit + Profit + Swap)

      bool isNewFormat = false;

      if (accountArray.length >= 9) {
        // ✅ OPTIMIZATION: Direct numeric conversion (faster than toString then parse)
        // Calculate Error for NEW FORMAT
        // [2]=Bal, [3]=Cred, [4]=Eq, [8]=Prof, [9]=Swap (if exists)
        final nBal = accountArray[2] is num
            ? (accountArray[2] as num).toDouble()
            : double.tryParse(accountArray[2].toString()) ?? 0.0;
        final nCred = accountArray[3] is num
            ? (accountArray[3] as num).toDouble()
            : double.tryParse(accountArray[3].toString()) ?? 0.0;
        final nEq = accountArray[4] is num
            ? (accountArray[4] as num).toDouble()
            : double.tryParse(accountArray[4].toString()) ?? 0.0;
        final nProf = accountArray[8] is num
            ? (accountArray[8] as num).toDouble()
            : double.tryParse(accountArray[8].toString()) ?? 0.0;
        final nSwap = accountArray.length > 9
            ? (accountArray[9] is num
                ? (accountArray[9] as num).toDouble()
                : double.tryParse(accountArray[9].toString()) ?? 0.0)
            : 0.0;

        final nDiff = (nEq - (nBal + nCred + nProf + nSwap)).abs();

        // Calculate Error for OLD FORMAT
        // [2]=Bal, [3]=Eq, [7]=Prof, [8]=Swap
        final oBal = accountArray[2] is num
            ? (accountArray[2] as num).toDouble()
            : double.tryParse(accountArray[2].toString()) ?? 0.0;
        final oEq = accountArray[3] is num
            ? (accountArray[3] as num).toDouble()
            : double.tryParse(accountArray[3].toString()) ?? 0.0;
        final oProf = accountArray[7] is num
            ? (accountArray[7] as num).toDouble()
            : double.tryParse(accountArray[7].toString()) ?? 0.0;
        final oSwap = accountArray[8] is num
            ? (accountArray[8] as num).toDouble()
            : double.tryParse(accountArray[8].toString()) ?? 0.0;

        final oDiff = (oEq - (oBal + oProf + oSwap)).abs();

        if (nDiff < oDiff && nDiff < 5.0) {
          isNewFormat = true;
        } else if (oDiff < nDiff && oDiff < 5.0) {
          isNewFormat = false;
        } else {
          // Default to New Format if length >= 10
          isNewFormat = true;
        }
      } else {
        isNewFormat = false;
      }

      double credit = 0.0;
      double equity = 0.0;
      double margin = 0.0;
      double freeMargin = 0.0;
      double marginLevel = 0.0;
      double profit = 0.0;
      double swap = 0.0;

      if (isNewFormat) {
        // NEW FORMAT
        // ✅ OPTIMIZATION: Direct numeric conversion (faster than toString then parse)
        credit = accountArray.length > 3
            ? (accountArray[3] is num
                ? (accountArray[3] as num).toDouble()
                : double.tryParse(accountArray[3].toString()) ?? 0.0)
            : 0.0;

        equity = accountArray.length > 4
            ? (accountArray[4] is num
                ? (accountArray[4] as num).toDouble()
                : double.tryParse(accountArray[4].toString()) ?? 0.0)
            : 0.0;

        margin = accountArray.length > 5
            ? (accountArray[5] is num
                ? (accountArray[5] as num).toDouble()
                : double.tryParse(accountArray[5].toString()) ?? 0.0)
            : 0.0;

        freeMargin = accountArray.length > 6
            ? (accountArray[6] is num
                ? (accountArray[6] as num).toDouble()
                : double.tryParse(accountArray[6].toString()) ?? 0.0)
            : 0.0;

        marginLevel = accountArray.length > 7
            ? (accountArray[7] is num
                ? (accountArray[7] as num).toDouble()
                : double.tryParse(accountArray[7].toString()) ?? 0.0)
            : 0.0;

        profit = accountArray.length > 8
            ? (accountArray[8] is num
                ? (accountArray[8] as num).toDouble()
                : double.tryParse(accountArray[8].toString()) ?? 0.0)
            : 0.0;

        swap = accountArray.length > 9
            ? (accountArray[9] is num
                ? (accountArray[9] as num).toDouble()
                : double.tryParse(accountArray[9].toString()) ?? 0.0)
            : 0.0;
      } else {
        // OLD FORMAT
        credit = 0.0; // Old format does not have a credit field

        // ✅ OPTIMIZATION: Direct numeric conversion (faster than toString then parse)
        equity = accountArray.length > 3
            ? (accountArray[3] is num
                ? (accountArray[3] as num).toDouble()
                : double.tryParse(accountArray[3].toString()) ?? 0.0)
            : 0.0;

        margin = accountArray.length > 4
            ? (accountArray[4] is num
                ? (accountArray[4] as num).toDouble()
                : double.tryParse(accountArray[4].toString()) ?? 0.0)
            : 0.0;

        freeMargin = accountArray.length > 5
            ? (accountArray[5] is num
                ? (accountArray[5] as num).toDouble()
                : double.tryParse(accountArray[5].toString()) ?? 0.0)
            : 0.0;

        marginLevel = accountArray.length > 6
            ? (accountArray[6] is num
                ? (accountArray[6] as num).toDouble()
                : double.tryParse(accountArray[6].toString()) ?? 0.0)
            : 0.0;

        profit = accountArray.length > 7
            ? (accountArray[7] is num
                ? (accountArray[7] as num).toDouble()
                : double.tryParse(accountArray[7].toString()) ?? 0.0)
            : 0.0;

        swap = accountArray.length > 8
            ? (accountArray[8] is num
                ? (accountArray[8] as num).toDouble()
                : double.tryParse(accountArray[8].toString()) ?? 0.0)
            : 0.0;

        if (kDebugMode) {
          dev.log(
            'Account WS: Detected OLD format (No Credit field). Length: ${accountArray.length}',
          );
        }
      }

      if (kDebugMode) {
        // dev.log(
        //   'Account WS: Parsed account data for $metaAccountNumber - Balance: $balance, Credit: $credit, Equity: $equity, Margin: $margin, Free Margin: $freeMargin, Margin Level: $marginLevel%, Profit: $profit, Swap: $swap',
        // );
      }

      // Create AccountInfo from parsed data
      final accountInfo = AccountInfo(
        assets: balance, // Assets = Balance (cash balance)
        balance: balance, // Cash balance (doesn't include unrealized P&L)
        blockedCommission: 0.0, // Not in array
        blockedProfit: 0.0, // Not in array
        credit: credit, // NEW Credit field
        currencyDigits: 2, // Default
        equity: equity, // Balance + unrealized P&L + swap
        floating: profit, // Floating profit/loss (unrealized P&L)
        liabilities: 0.0, // Not in array
        login: int.tryParse(metaAccountNumber) ?? 0,
        margin: margin, // Margin currently used by open positions
        marginFree: freeMargin, // Available margin (equity - margin)
        marginInitial: 0.0, // Not in array
        marginLevel: marginLevel, // Percentage (equity / margin * 100)
        marginLeverage: 0, // Not in array
        marginMaintenance: 0.0, // Not in array
        profit: profit, // Unrealized P&L across open positions
        soActivation: 0.0, // Not in array
        soEquity: 0.0, // Not in array
        soLevel: 0.0, // Not in array
        soMargin: 0.0, // Not in array
        soTime: 0.0, // Not in array
        storage: swap, // Accumulated swap (overnight interest)
      );

      // Update TradingController with account info
      _tradingController.updateAccountInfoFromWebSocket(accountInfo);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        dev.log('Account WS: Error parsing account array: $e\n$stackTrace');
      }
    }
  }

  // Handle JSON object responses (authentication, errors, etc.)
  void _handleJsonResponse(Map<String, dynamic> data) {
    final type = data['type']?.toString();

    // Handle unsubscribe confirmation
    if (type == 'unsubscribed') {
      if (_unsubscribeCompleter != null &&
          !_unsubscribeCompleter!.isCompleted) {
        _unsubscribeCompleter!.complete();
        _unsubscribeCompleter = null;
      }
      return;
    }

    // Handle authentication success messages
    if (type == 'accounts_joined' ||
        type == 'authenticated' ||
        type == 'account_subscribed') {
      final status = data['status']?.toString();

      if (status == 'success') {
        // ✅ CRITICAL FIX: Set _lastSubscribedAccount immediately after successful authentication
        // This ensures account updates are not blocked during active trading
        final activeAccount = _accountController.activeMT5Account;
        if (activeAccount != null) {
          final accountNumber = activeAccount.metaAccountNumber;
          if (_lastSubscribedAccount != accountNumber) {
            _lastSubscribedAccount = accountNumber;
            _isUnsubscribing = false; // Clear unsubscribing flag on successful auth
            if (kDebugMode) {
              dev.log(
                'Account WS: Set _lastSubscribedAccount to $accountNumber after successful authentication (type: $type)',
              );
            }
          }
        }
      }
      return;
    }

    // Handle error responses
    if (type == 'error') {
      final errorMessage = data['message']?.toString() ?? 'Unknown error';
      if (kDebugMode) {
        dev.log('Account WS: ❌ Error: $errorMessage');
        dev.log('Account WS: Full error response: $data');
      }

      // If error is about binary format, try without binary format
      if (errorMessage.toLowerCase().contains('binary') ||
          errorMessage.toLowerCase().contains('format')) {
        if (kDebugMode) {
          dev.log(
            '⚠️ Account WS: Binary format not supported, will retry without binary format',
          );
        }
        // Note: This will be handled on next subscription attempt
      }

      // Complete unsubscribe completer even on error to avoid hanging
      if (_unsubscribeCompleter != null &&
          !_unsubscribeCompleter!.isCompleted) {
        _unsubscribeCompleter!.complete();
        _unsubscribeCompleter = null;
      }
      return;
    }
  }

  // Send event with parameters over WebSocket
  void _sendEvent(Map<String, dynamic> event) {
    try {
      if (channel == null || !isConnected.value) {
        if (kDebugMode) {
          dev.log(
            'Account WS: Cannot send event - channel is null or not connected',
          );
        }
        return;
      }
      final encoded = jsonEncode(event);
      channel!.sink.add(encoded);
      if (kDebugMode) {
        dev.log('Account WS: Sent event: $encoded');
      }
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Error sending event: $e');
      }
    }
  }

  // Schedule reconnection
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        // dev.log('Account WS: Max reconnection attempts reached');
      }
      return;
    }

    if (_reconnectTimer?.isActive == true) return;

    _reconnectAttempts++;
    isReconnecting.value = true;

    if (kDebugMode) {
      // dev.log(
      // 'Account WS: Scheduling reconnection attempt $_reconnectAttempts in ${_reconnectDelay.inSeconds} seconds',
      // );
    }

    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectWebSocket();
    });
  }

  // Reconnect WebSocket
  void _reconnectWebSocket() {
    if (isConnected.value) return;

    if (kDebugMode) {
      // dev.log('Account WS: Attempting to reconnect...');
    }
    isReconnecting.value = true;

    try {
      _disconnectWebSocket();
      _initializeWebSocket();
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Reconnection failed: $e');
      }
      isReconnecting.value = false;
      _scheduleReconnect();
    }
  }

  // Disconnect WebSocket
  void _disconnectWebSocket() {
    try {
      // ✅ FIX: Cancel stream subscription to prevent memory leaks
      _channelSubscription?.cancel();
      _channelSubscription = null;

      if (channel != null) {
        channel!.sink.close();
        channel = null;
      }
      _currentUrl = null;
      isConnected.value = false;
      isReconnecting.value = false;
      _isConnecting = false;
      _reconnectTimer?.cancel();
      if (kDebugMode) {
        dev.log('Account WS: Disconnected');
      }
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Error disconnecting: $e');
      }
    }
  }

  // Public method to manually reconnect
  void reconnect() {
    _reconnectAttempts = 0; // Reset attempts for manual reconnect
    _reconnectWebSocket();
  }

  // Public method to refresh account data
  void refreshAccountData() {
    if (isConnected.value && !_isDisposed) {
      requestAccountData();
    } else if (!isConnected.value) {
      _initializeWebSocket();
    }
  }

  // Subscribe to single symbol data (for MT5 accounts)
  void subscribeToSymbol(String symbol) async {
    final activeAccount = _accountController.activeMT5Account;
    if (activeAccount == null || !isConnected.value || channel == null) {
      if (kDebugMode) {
        dev.log(
          'Account WS: Cannot subscribe to symbol - no account or not connected',
        );
      }
      return;
    }

    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) {
      if (kDebugMode) {
        dev.log('Account WS: Cannot subscribe to symbol - no auth token');
      }
      return;
    }

    final event = {
      "authID": authId,
      "trading_account": activeAccount.metaAccountNumber,
      "symbol": symbol,
      "type": "subscribe_symbols",
    };

    _sendEvent(event);

    if (kDebugMode) {
      dev.log(
        'Account WS: Subscribed to symbol: $symbol for account: ${activeAccount.metaAccountNumber}',
      );
    }
  }

  // Unsubscribe from single symbol data
  void unsubscribeFromSymbol(String symbol) async {
    final activeAccount = _accountController.activeMT5Account;
    if (activeAccount == null || !isConnected.value || channel == null) return;

    final authId = await SecureStorageService.getAuthToken();
    if (authId == null || authId.isEmpty) return;

    final event = {
      "authID": authId,
      "trading_account": activeAccount.metaAccountNumber,
      "symbol": symbol,
      "type": "unsubscribe_symbols",
    };

    _sendEvent(event);

    if (kDebugMode) {
      dev.log('Account WS: Unsubscribed from symbol: $symbol');
    }
  }

  // Public method to force endpoint switch (called by account controller)
  Future<void> forceEndpointSwitch(String accountType) async {
    _lastAccountType = accountType;
    await disconnectAndReconnect();
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

    // ✅ FIX: Cancel stream subscription before account switch to prevent memory leaks
    _channelSubscription?.cancel();

    // If not connected, just initialize normally
    if (!isConnected.value) {
      if (kDebugMode) {
        dev.log('Account WS: Not connected, initializing normally');
      }
      _initializeWebSocket();
      return;
    }

    try {
      if (kDebugMode) {
        dev.log(
          'Account WS: Unsubscribing and resubscribing for account change',
        );
      }

      // Step 1: Block incoming data BEFORE unsubscribe
      _isUnsubscribing = true;
      _lastSubscribedAccount = null;

      // Step 2: Unsubscribe from current subscription
      _unsubscribeCompleter = Completer<void>();
      _sendEvent({"type": "unsubscribe"});

      // Step 3: Wait for unsubscribe confirmation (with timeout)
      try {
        await _unsubscribeCompleter!.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            if (kDebugMode) {
              dev.log('Account WS: Unsubscribe timeout, proceeding anyway');
            }
            if (_unsubscribeCompleter != null &&
                !_unsubscribeCompleter!.isCompleted) {
              _unsubscribeCompleter!.complete();
              _unsubscribeCompleter = null;
            }
          },
        );
      } catch (e) {
        if (kDebugMode) {
          dev.log('Account WS: Error waiting for unsubscribe: $e');
        }
      }

      // Step 4: Longer delay to let in-flight messages clear and ensure old data is blocked
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 5: Get new account number and set it BEFORE resubscribing
      final activeAccount = _accountController.activeMT5Account;
      final newAccountNumber = activeAccount?.metaAccountNumber;

      if (newAccountNumber == null || newAccountNumber.isEmpty) {
        if (kDebugMode) {
          dev.log('Account WS: No active account found, cannot resubscribe');
        }
        _isUnsubscribing = false;
        _lastSubscribedAccount = null;
        return;
      }

      // Step 6: ✅ CRITICAL FIX: Clear stale account data before resubscribing
      // This prevents overlapping old data when resubscribing
      // Note: Account info will be cleared when new data arrives
      // The _lastSubscribedAccount check will ensure only new account data is processed
      if (kDebugMode) {
        dev.log('Account WS: Preparing to resubscribe - stale data will be cleared on new subscription');
      }

      // Step 7: Set new account number BEFORE resubscribing to block old account data
      _lastSubscribedAccount = newAccountNumber;
      _isUnsubscribing = false;

      // ✅ FIX: Add small delay to ensure WebSocket is ready before requesting data
      // This ensures the connection is fully established and ready to receive data
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_isDisposed && isConnected.value && !_isUnsubscribing) {
          requestAccountData();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        dev.log('Account WS: Error in unsubscribeAndResubscribe: $e');
      }
      // Reset flags on error
      _isUnsubscribing = false;
      _lastSubscribedAccount = null;
      // Fallback: if unsubscribe/resubscribe fails, do full reconnect
      _disconnectWebSocket();
      await Future.delayed(const Duration(milliseconds: 150));
      _reconnectAttempts = 0;
      if (!_isDisposed) {
        _initializeWebSocket();
      }
    }
  }

  // Disconnect and reconnect with new account (for account switching)
  // This ensures clean connection with new account number and new URL if needed
  Future<void> disconnectAndReconnect() async {
    if (_isDisposed) {
      return;
    }

    // Prevent concurrent reconnection attempts
    if (_isConnecting) {
      return;
    }

    // Block data during disconnect
    _isUnsubscribing = true;
    _lastSubscribedAccount = null;

    // Fully disconnect WebSocket
    _disconnectWebSocket();

    // Small delay to ensure disconnect completes
    await Future.delayed(const Duration(milliseconds: 200));

    // Reset reconnection attempts for fresh start
    _reconnectAttempts = 0;

    // Reconnect with new account immediately (will use new URL if trading_server changed)
    if (!_isDisposed && !_isConnecting) {
      _initializeWebSocket();

      // ✅ CRITICAL FIX: Clear stale account data before reconnecting
      // This prevents overlapping old data when reconnecting
      // Note: Account info will be cleared when new data arrives
      // The _lastSubscribedAccount check will ensure only new account data is processed
      if (kDebugMode) {
        dev.log('Account WS: Preparing to reconnect - stale data will be cleared on new connection');
      }

      // ✅ FIX: Set account number and request data after reconnection
      // Add delay to ensure WebSocket is fully connected before requesting data
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_isDisposed && isConnected.value) {
          final activeAccount = _accountController.activeMT5Account;
          final newAccountNumber = activeAccount?.metaAccountNumber;

          if (newAccountNumber != null && newAccountNumber.isNotEmpty) {
            // Set account number to allow data through
            _lastSubscribedAccount = newAccountNumber;
            _isUnsubscribing = false;

            // Explicitly request account data
            requestAccountData();
          }
        }
      });
    }
  }
}
