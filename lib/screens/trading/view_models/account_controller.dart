import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:crm_app/models/account_models.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/services/account_cache_service.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/services/account_service.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'package:crm_app/services/market_watch_v2_service.dart';

class AccountController extends GetxController {
  final AccountService _accountService = Get.find<AccountService>();
  final FinanceRepository _financeRepo = Get.find<FinanceRepository>();
  late final DashboardController _dashboardController;

  // Observable states
  final _isLoading = false.obs;
  final _errorMessage = ''.obs;
  final _accounts = <AccountModel>[].obs;
  final _activeAccount = Rxn<AccountModel>();
  final _successMessage = ''.obs;

  // MT5 Account integration
  final _mt5Accounts = <MT5Account>[].obs;
  final _activeMT5Account = Rxn<MT5Account>();
  final _isInitialized = false.obs;

  // Getters
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  List<AccountModel> get accounts => _accounts;
  AccountModel? get activeAccount => _activeAccount.value;
  String get successMessage => _successMessage.value;

  // MT5 Account getters
  List<MT5Account> get mt5Accounts => _mt5Accounts;
  MT5Account? get activeMT5Account => _activeMT5Account.value;
  Rxn<MT5Account> get activeMT5AccountRx =>
      _activeMT5Account; // Expose observable for listeners
  bool get isInitialized => _isInitialized.value;
  List<MT5Account> get realMT5Accounts =>
      _mt5Accounts.where((account) => account.isRealAccount).toList();
  List<MT5Account> get demoMT5Accounts =>
      _mt5Accounts.where((account) => account.isDemoAccount).toList();

  // Wait for AccountController to be ready before proceeding
  Future<void> waitForInitialization() async {
    if (_isInitialized.value) return;

    // Wait for initialization to complete
    await _isInitialized.stream.firstWhere((initialized) => initialized);

    // Small additional delay to ensure MT5 accounts are synced
    await Future.delayed(const Duration(milliseconds: 100));
  }

  MT5Account? get primaryMT5Account {
    try {
      return _mt5Accounts.firstWhere((account) => account.isPrimaryAccount);
    } catch (e) {
      return _mt5Accounts.isNotEmpty ? _mt5Accounts.first : null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initializeControllers();
    loadAccounts();
  }

  void _initializeControllers() {
    try {
      // Try to get existing DashboardController first
      _dashboardController = Get.find<DashboardController>();
    } catch (e) {
      // If not found, create a new one
      _dashboardController = Get.put(DashboardController());
    }

    // Wait a bit for DashboardController to initialize, then sync
    Future.delayed(Duration(milliseconds: 500), () {
      _syncWithMT5Accounts();
    });
  }

  Future<void> loadAccounts() async {
    try {
      _setLoading(true);
      _clearError();

      // ✅ FIX: Try to load from cache first for immediate initialization
      final cachedAccounts = await AccountCacheService.getCachedMT5Accounts();
      if (cachedAccounts != null && cachedAccounts.isNotEmpty) {
        // Use cached accounts immediately
        _mt5Accounts.assignAll(cachedAccounts);
        _updateActiveMT5Account();
        _isInitialized.value = true;
        _setLoading(false);

        if (kDebugMode) {
          print(
            'AccountController: Loaded ${cachedAccounts.length} accounts from cache',
          );
        }

        // Fetch fresh data from API in background and update cache
        _fetchFreshAccountsInBackground();
        return;
      }

      // No cache - fetch from API (existing behavior)
      final accounts = await _accountService.getAccounts();
      final activeAccount = await _accountService.getActiveAccount();

      _accounts.value = accounts;
      _activeAccount.value = activeAccount;

      // Mark as initialized after loading accounts
      _isInitialized.value = true;
    } catch (e) {
      _setError('Failed to load accounts: $e');
      _isInitialized.value = false;
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch fresh account data from API in background
  /// This is called after loading from cache to keep data fresh
  Future<void> _fetchFreshAccountsInBackground() async {
    try {
      final accounts = await _accountService.getAccounts();
      final activeAccount = await _accountService.getActiveAccount();

      // Update with fresh data
      _accounts.value = accounts;
      _activeAccount.value = activeAccount;

      // Update MT5 accounts if available
      if (_dashboardController.mt5Accounts.isNotEmpty) {
        _mt5Accounts.assignAll(_dashboardController.mt5Accounts);
        _updateActiveMT5Account();
      }

      if (kDebugMode) {
        print('AccountController: Fresh account data fetched in background');
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'AccountController: Error fetching fresh accounts in background: $e',
        );
      }
      // Don't show error to user - cache is still valid
    }
  }

  Future<void> setActiveAccount(String accountId) async {
    try {
      _setLoading(true);
      _clearError();

      await _accountService.setActiveAccount(accountId);

      // Reload accounts to get updated data
      await loadAccounts();

      // _setSuccess('Account switched successfully');
    } catch (e) {
      _setError('Failed to set active account: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addAccount(AccountModel account) async {
    try {
      _setLoading(true);
      _clearError();

      await _accountService.addAccount(account);
      await loadAccounts();

      _setSuccess('Account added successfully');
    } catch (e) {
      _setError('Failed to add account: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateAccount(AccountModel account) async {
    try {
      _setLoading(true);
      _clearError();

      await _accountService.updateAccount(account);
      await loadAccounts();

      _setSuccess('Account updated successfully');
    } catch (e) {
      _setError('Failed to update account: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount(String accountId) async {
    try {
      _setLoading(true);
      _clearError();

      await _accountService.deleteAccount(accountId);
      await loadAccounts();

      _setSuccess('Account deleted successfully');
    } catch (e) {
      _setError('Failed to delete account: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    try {
      _setLoading(true);
      _clearError();

      await _accountService.updateAccountBalance(accountId, newBalance);
      await loadAccounts();

      _setSuccess('Account balance updated successfully');
    } catch (e) {
      _setError('Failed to update account balance: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshAccounts() async {
    // Sync accounts with backend first (for both self-hosted and MT5 accounts)
    await syncMT5Accounts();
    // Then reload accounts to get updated data
    await loadAccounts();
  }

  Future<void> resetToDefaultAccounts() async {
    try {
      _setLoading(true);
      _clearError();

      await _accountService.resetToDefaultAccounts();
      await loadAccounts();

      // _setSuccess('Accounts reset to default');
    } catch (e) {
      _setError('Failed to reset accounts: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading.value = loading;
  }

  void _setError(String error) {
    _errorMessage.value = error;
    if (error.isNotEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: error,
          title: 'Error',
        );
      }
    }
  }

  void _setSuccess(String message) {
    _successMessage.value = message;
    if (message.isNotEmpty) {
      // Get.snackbar('Success', message, snackPosition: SnackPosition.TOP);
      CustomToastService.showSuccess(
        message: message,
        duration: const Duration(seconds: 1),
      );
    }
  }

  void _clearError() {
    _errorMessage.value = '';
  }

  void clearMessages() {
    _errorMessage.value = '';
    _successMessage.value = '';
  }

  // MT5 Account Integration Methods

  // Sync with MT5 accounts from dashboard controller
  void _syncWithMT5Accounts() {
    try {
      // Listen to MT5 accounts changes from dashboard controller
      ever(_dashboardController.mt5Accounts, (List<MT5Account> mt5Accounts) {
        _mt5Accounts.assignAll(mt5Accounts);
        _updateActiveMT5Account();
      });

      // Initial sync
      if (_dashboardController.mt5Accounts.isNotEmpty) {
        _mt5Accounts.assignAll(_dashboardController.mt5Accounts);
        _updateActiveMT5Account();

        // ✅ FIX: Update WebSocketEndpointHelper with primary account
        final primaryAccount = primaryMT5Account;
        if (primaryAccount != null) {
          WebSocketEndpointHelper.setPrimaryAccount(primaryAccount);
        }
      } else {
        // Retry after a delay
        Future.delayed(Duration(seconds: 2), () {
          if (_dashboardController.mt5Accounts.isNotEmpty) {
            _mt5Accounts.assignAll(_dashboardController.mt5Accounts);
            _updateActiveMT5Account();
          }
        });
      }
    } catch (e) {
      // Error syncing with MT5 accounts
    }
  }

  // Force refresh account data
  Future<void> forceRefreshAccountData() async {
    try {
      // Sync accounts with backend first (for both self-hosted and MT5 accounts)
      await syncMT5Accounts();

      // Reload accounts
      await loadAccounts();

      // Force sync with MT5 accounts
      _syncWithMT5Accounts();
    } catch (e) {
      // Error force refreshing account data
      if (kDebugMode) {
        print('AccountController: Error force refreshing account data: $e');
      }
    }
  }

  /// Sync MT5 accounts with backend (for both self-hosted and MT5 accounts)
  /// This ensures account balances and data are up-to-date before loading accounts
  Future<void> syncMT5Accounts() async {
    try {
      if (kDebugMode) {
        print('AccountController: Syncing MT5 accounts with backend...');
      }

      final response = await _financeRepo.syncMt5Accounts();

      if (response.success) {
        if (kDebugMode) {
          print('AccountController: MT5 accounts synced successfully');
          if (response.data != null) {
            print('AccountController: Sync result: ${response.data}');
          }
        }
      } else {
        if (kDebugMode) {
          print(
            'AccountController: Failed to sync MT5 accounts: ${response.message}',
          );
        }
        // Don't throw error - allow accounts to load even if sync fails
      }
    } catch (e) {
      if (kDebugMode) {
        print('AccountController: Error syncing MT5 accounts: $e');
      }
      // Don't throw error - allow accounts to load even if sync fails
    }
  }

  // Debug method to check account data
  void debugAccountData() {
    // Debug method - kept for potential debugging needs
  }

  // Method to update MT5 accounts (called by dashboard controller)
  void updateMT5Accounts(List<MT5Account> mt5Accounts) {
    _mt5Accounts.assignAll(mt5Accounts);
    _updateActiveMT5Account();

    // ✅ FIX: Update WebSocketEndpointHelper with primary account
    final primaryAccount = primaryMT5Account;
    if (primaryAccount != null) {
      WebSocketEndpointHelper.setPrimaryAccount(primaryAccount);
    }

    // Debug account data
    debugAccountData();
  }

  // Update active MT5 account based on primary account
  // ✅ FIX: Preserve currently selected account if it's still valid
  // Only fall back to primary/first if current account is not in the list
  void _updateActiveMT5Account() {
    // ✅ FIX: First check if current active account is still valid
    final currentActive = _activeMT5Account.value;
    if (currentActive != null) {
      // Check if current active account still exists in the list
      final stillExists = _mt5Accounts.any(
        (acc) => acc.metaAccountNumber == currentActive.metaAccountNumber,
      );
      if (stillExists) {
        // Current account is still valid - update with fresh data but don't change account
        final freshAccount = _mt5Accounts.firstWhere(
          (acc) => acc.metaAccountNumber == currentActive.metaAccountNumber,
        );
        _activeMT5Account.value = freshAccount;
        return; // Don't reset to primary!
      }
    }

    // Current account not valid - fall back to primary or first
    final primaryAccount = primaryMT5Account;

    if (primaryAccount != null) {
      _activeMT5Account.value = primaryAccount;
    } else if (_mt5Accounts.isNotEmpty) {
      _activeMT5Account.value = _mt5Accounts.first;
    } else {
      _activeMT5Account.value = null;
    }
  }

  // Set active MT5 account (this will call dashboard controller's changePrimaryAccount)
  Future<void> setActiveMT5Account(String accountNumber) async {
    try {
      _setLoading(true);
      _clearError();

      // Get the new account details
      final account = _mt5Accounts.firstWhereOrNull(
        (acc) => acc.metaAccountNumber == accountNumber,
      );

      if (account == null) {
        _setError('Account not found');
        return;
      }

      final previousAccount = _activeMT5Account.value;
      final previousEndpoints = _snapshotWebSocketEndpoints(previousAccount);
      final nextEndpoints = _snapshotWebSocketEndpoints(account);

      // Start switch trace timer
      WebSocketEndpointHelper.beginSwitchTrace(account.metaAccountNumber);

      _logEndpointChanges(previousEndpoints, nextEndpoints);

      // ✅ OPTIMIZATION: Detect account type change early (before API call)
      final currentAccount = _activeMT5Account.value;
      final currentIsMT5 = currentAccount?.tradingServer.toUpperCase() == "MT5";
      final newIsMT5 = account.tradingServer.toUpperCase() == "MT5";
      final accountTypeChanged = currentIsMT5 != newIsMT5;
      // Kick off background disconnect for screen-level sockets while API executes
      final screenDisconnect = _disconnectScreenSockets();

      // ✅ FIX: Clear data FIRST before setting account switching flag
      // This ensures UI shows empty state immediately when account changes
      try {
        if (Get.isRegistered<TradingController>()) {
          final tradingController = Get.find<TradingController>();
          // Clear all data immediately to show empty state
          // ✅ FIX: Don't reset tab during account switch to preserve History data if on History tab
          tradingController.clearAllTradingData(resetTab: false);
          // Set flag to allow first update (even if empty) to show new account state
          tradingController.setAccountSwitching(true);
        }
      } catch (e) {
        // Error clearing trading data or setting account switching flag
      }

      // ✅ OPTIMIZATION: Optimistic UI update for faster response
      // ✅ FIX: Clear instruments data BEFORE setting account to ensure list clears immediately
      // This ensures list clears even if ever() listener doesn't fire immediately
      try {
        if (Get.isRegistered<InstrumentsController>()) {
          final instrumentsController = Get.find<InstrumentsController>();
          print('═══════════════════════════════════════════════════════════');
          print(
            '🔄 AccountController: Clearing instruments BEFORE account switch',
          );
          print(
            '   From: ${_activeMT5Account.value?.metaAccountNumber ?? "N/A"}',
          );
          print('   To:   ${account.metaAccountNumber}');
          print('═══════════════════════════════════════════════════════════');

          // ✅ STEP 1: Cancel unified subscription FIRST
          if (instrumentsController.isConnected.value) {
            print('   STEP 1: Stopping WebSocket to cancel subscription...');
            instrumentsController.stopWebSocket();
          }

          // ✅ STEP 2: Clear data immediately
          print('   STEP 2: Clearing instruments data...');
          instrumentsController.clearInstrumentsData();

          print(
            '✅ AccountController: Instruments cleared before account switch',
          );
        }
      } catch (e) {
        print('⚠️ AccountController: Error clearing instruments: $e');
      }

      // ✅ STEP 3: Set new account (this will trigger ever() listener)
      _activeMT5Account.value = account;
      print(
        '✅ AccountController: Active account set to ${account.metaAccountNumber}',
      );

      // ✅ OPTIMIZATION: If account type changed (MT5 ↔ self-hosted), disconnect first,
      // then reconnect only after the backend confirms the switch. This prevents reconnecting
      // to the old endpoint and ensures market/watch & accounts data refresh correctly.
      Future<void>? disconnectTask;
      if (accountTypeChanged) {
        disconnectTask = Future.wait([
          // Close Instruments WebSocket
          Future(() async {
            try {
              if (Get.isRegistered<InstrumentsController>()) {
                final instrumentsController = Get.find<InstrumentsController>();
                instrumentsController.stopWebSocket();
              }
            } catch (e) {
              // Error closing Instruments WebSocket
            }
          }),

          // Close Chart WebSocket
          Future(() async {
            try {
              if (Get.isRegistered<ChartSocketController>()) {
                final chartSocketController = Get.find<ChartSocketController>();
                chartSocketController.stopWebSocket();
              }
            } catch (e) {
              // Error closing Chart WebSocket
            }
          }),
        ]);
      }

      // Call dashboard controller's method to change primary account
      await _dashboardController.changePrimaryAccount(accountNumber);

      // ✅ FIX: Clear endpoint helper cache to ensure fresh account data
      WebSocketEndpointHelper.clearCache();
      // Set the new primary account for endpoint helper to avoid stale URLs
      WebSocketEndpointHelper.setPrimaryAccount(account);

      // ✅ NOTE: Trading data already cleared above when setting switching flag
      // No need to clear again here to avoid double clearing
      try {
        // Clear dashboard cached account info so next stream is fresh
        _dashboardController.accountInfoMap.clear();
      } catch (_) {}

      // Ensure disconnects complete before reconnecting with the new endpoints
      if (disconnectTask != null) {
        await disconnectTask;
      }
      await screenDisconnect;

      // ✅ FIX: Add small delay to allow backend to fully process account switch
      // Backend needs time to update internal state before websockets can receive data
      // This prevents websockets from connecting before backend is ready
      if (accountTypeChanged) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Reconnect all websockets after API so URLs and subscriptions are fresh
      await _reconnectAllSockets(accountNumber, account);

      // ✅ Fetch and cache symbol details for the new account in background
      // This ensures contract sizes are available for P&L calculations
      // Called after WebSocket reconnection so it doesn't block account switch
      Future(() async {
        try {
          await SymbolDetailsCacheService.fetchAndCacheSymbolDetails(
            accountNumber,
          );
        } catch (e) {
          print(
            'AccountController: Error fetching symbol details in background: $e',
          );
          // Don't block account switch if symbol fetch fails
        }
      });

      // Clear account switching flag after a shorter delay for faster updates
      // Flag will also be cleared when real data arrives in _updateMarketPositions
      try {
        if (Get.isRegistered<TradingController>()) {
          final tradingController = Get.find<TradingController>();
          Future.delayed(const Duration(milliseconds: 400), () {
            tradingController.setAccountSwitching(false);
          });
        }
      } catch (e) {
        // Error clearing account switching flag
      }

      // ✅ FIX: Force refresh trading data to ensure Market tab updates after account switch
      // This ensures any cached or stale data is replaced with fresh data from the new account
      try {
        if (Get.isRegistered<TradingWebSocketService>()) {
          final tradingWS = Get.find<TradingWebSocketService>();
          // Add a small delay to ensure WebSocket is ready
          Future.delayed(const Duration(milliseconds: 100), () {
            if (tradingWS.isConnected.value ||
                tradingWS.isOpenPositionsConnected.value) {
              // Force refresh if connected
              tradingWS.forceRefreshTradingData();
            }
          });
        }
      } catch (e) {
        // Error forcing data refresh
      }

      // _setSuccess('Account switched successfully');
    } catch (e) {
      _setError('Failed to switch account: $e');
    } finally {
      _setLoading(false);

      // Ensure any open loading dialogs are closed
      if (Get.isDialogOpen ?? false) {
        Get.back(closeOverlays: true);
      }

      // End switch trace
      WebSocketEndpointHelper.endSwitchTrace();
    }
  }

  Map<String, String> _snapshotWebSocketEndpoints(MT5Account? account) {
    return {
      'trading_open_positions': WebSocketEndpointHelper.getOpenPositionsUrl(
        account,
      ),
      'trading_pending_orders': WebSocketEndpointHelper.getPendingOrdersUrl(
        account,
      ),
      'trading_market_watch': WebSocketEndpointHelper.getMarketWatchUrl(
        account,
      ),
      'trading_symbol': WebSocketEndpointHelper.getSymbolUrl(account),
      'account': WebSocketEndpointHelper.getAccountUrl(account),
    };
  }

  void _logEndpointChanges(
    Map<String, String> oldEndpoints,
    Map<String, String> newEndpoints,
  ) {
    // Endpoint changes logged internally if needed
  }

  Future<void> _disconnectScreenSockets() async {
    await Future.wait([
      Future(() async {
        try {
          if (Get.isRegistered<InstrumentsController>()) {
            final c = Get.find<InstrumentsController>();
            WebSocketEndpointHelper.logSwitchStep('Instruments stop');
            c.stopWebSocket();
          }
        } catch (_) {}
      }),
      Future(() async {
        try {
          if (Get.isRegistered<ChartSocketController>()) {
            final c = Get.find<ChartSocketController>();
            WebSocketEndpointHelper.logSwitchStep('Chart stop');
            c.stopWebSocket();
          }
        } catch (_) {}
      }),
    ]);
  }

  // Public method to trigger WebSocket reconnection after account change
  // This is used when account is changed from DashboardController to avoid circular calls
  Future<void> reconnectAllSocketsForAccount(String accountNumber) async {
    try {
      // Find the account
      final account = _mt5Accounts.firstWhereOrNull(
        (acc) => acc.metaAccountNumber == accountNumber,
      );

      if (account != null) {
        // Update active account first
        _activeMT5Account.value = account;

        // Clear trading data before reconnection
        try {
          if (Get.isRegistered<TradingController>()) {
            final tradingController = Get.find<TradingController>();
            tradingController.clearAllTradingData();
            tradingController.setAccountSwitching(true);
          }
        } catch (e) {
          // Error clearing trading data
        }

        // Trigger reconnection of all WebSockets
        await _reconnectAllSockets(accountNumber, account);

        // ✅ FIX: Ensure instrument data is requested after account switch
        // Add a small delay to ensure WebSocket is ready before requesting data
        Future.delayed(const Duration(milliseconds: 200), () {
          try {
            if (Get.isRegistered<InstrumentsController>()) {
              final instrumentsController = Get.find<InstrumentsController>();
              if (instrumentsController.isConnected.value) {
                instrumentsController.getSocketdata();
              }
            }
          } catch (e) {
            // Error requesting instrument data
          }
        });

        // Clear account switching flag after delay
        try {
          if (Get.isRegistered<TradingController>()) {
            final tradingController = Get.find<TradingController>();
            Future.delayed(const Duration(milliseconds: 400), () {
              tradingController.setAccountSwitching(false);
            });
          }
        } catch (e) {
          // Error clearing account switching flag
        }
      }
    } catch (e) {
      print('AccountController: Error in reconnectAllSocketsForAccount: $e');
    }
  }

  Future<void> _reconnectAllSockets(
    String accountNumber,
    MT5Account account,
  ) async {
    // Ensure active is set before reconnects
    _activeMT5Account.value = account;

    // ✅ OPTIMIZATION: Use atomic switchAccount for faster account switching
    await Future.wait([
      // Trading WS - Atomic account switch (keeps connection open)
      Future(() async {
        try {
          if (Get.isRegistered<TradingWebSocketService>()) {
            final tradingWS = Get.find<TradingWebSocketService>();
            if (tradingWS.isConnected.value) {
              WebSocketEndpointHelper.logSwitchStep('Trading switch start');
              await tradingWS.switchAccount(accountNumber);
              WebSocketEndpointHelper.logSwitchStep('Trading switch done');
            } else {
              // Not connected, just reconnect
              WebSocketEndpointHelper.logSwitchStep('Trading reconnect start');
              await tradingWS.disconnectAndReconnect();
              WebSocketEndpointHelper.logSwitchStep('Trading reconnect done');
            }
          }
        } catch (_) {}
      }),
      // Account WS - Unsubscribe if connected
      Future(() async {
        try {
          if (Get.isRegistered<AccountWebSocketService>()) {
            final accountWS = Get.find<AccountWebSocketService>();
            if (accountWS.isConnected.value) {
              WebSocketEndpointHelper.logSwitchStep(
                'Account unsubscribe start',
              );
              await accountWS.unsubscribeAndResubscribe();
              WebSocketEndpointHelper.logSwitchStep('Account unsubscribe done');
            } else {
              // Not connected, just reconnect
              WebSocketEndpointHelper.logSwitchStep('Account reconnect start');
              await accountWS.disconnectAndReconnect();
              WebSocketEndpointHelper.logSwitchStep('Account reconnect done');
            }
          }
        } catch (_) {}
      }),
      // Instruments WS - Unsubscribe if connected
      Future(() async {
        try {
          if (Get.isRegistered<InstrumentsController>()) {
            final instrumentsController = Get.find<InstrumentsController>();
            if (instrumentsController.isConnected.value) {
              WebSocketEndpointHelper.logSwitchStep(
                'Instruments unsubscribe start',
              );
              // Clear data before unsubscribe
              instrumentsController.clearInstrumentsData();
              await instrumentsController.unsubscribeAndResubscribe(
                accountNumber,
              );
              Future.delayed(const Duration(milliseconds: 150), () async {
                try {
                  if (Get.isRegistered<MarketWatchV2Service>()) {
                    await Get.find<MarketWatchV2Service>()
                        .reconnectAndResyncFavorites();
                  }
                } catch (_) {}
              });
              WebSocketEndpointHelper.logSwitchStep(
                'Instruments unsubscribe done',
              );
            } else {
              // Not connected, just reconnect
              WebSocketEndpointHelper.logSwitchStep(
                'Instruments reconnect start',
              );
              instrumentsController.stopWebSocket();
              await Future.delayed(const Duration(milliseconds: 60));
              instrumentsController.clearInstrumentsData();
              instrumentsController.startWebSocket();
              Future.delayed(const Duration(milliseconds: 150), () async {
                try {
                  if (Get.isRegistered<MarketWatchV2Service>()) {
                    await Get.find<MarketWatchV2Service>()
                        .reconnectAndResyncFavorites();
                  }
                } catch (_) {}
              });
              // ✅ FIX: Request instrument data after reconnection
              Future.delayed(const Duration(milliseconds: 100), () {
                if (Get.isRegistered<InstrumentsController>()) {
                  try {
                    final instrumentsController =
                        Get.find<InstrumentsController>();
                    if (instrumentsController.isConnected.value) {
                      instrumentsController.getSocketdata();
                    }
                  } catch (e) {
                    // Error requesting instrument data
                  }
                }
              });
              WebSocketEndpointHelper.logSwitchStep(
                'Instruments reconnect done',
              );
            }
          }
        } catch (_) {}
      }),
      // Chart WS - Unsubscribe if connected
      Future(() async {
        try {
          if (Get.isRegistered<ChartSocketController>()) {
            final chartSocketController = Get.find<ChartSocketController>();
            final currentSymbol = chartSocketController.currentSymbol.value;
            if (chartSocketController.isConnected.value &&
                currentSymbol.isNotEmpty) {
              WebSocketEndpointHelper.logSwitchStep('Chart unsubscribe start');
              await chartSocketController.unsubscribeAndResubscribe(
                accountNumber,
                currentSymbol,
              );
              WebSocketEndpointHelper.logSwitchStep('Chart unsubscribe done');
            } else {
              // Not connected, just reconnect
              WebSocketEndpointHelper.logSwitchStep('Chart reconnect start');
              chartSocketController.stopWebSocket();
              if (currentSymbol.isNotEmpty) {
                await Future.delayed(const Duration(milliseconds: 150));
                chartSocketController.initializeSocketForSymbol(currentSymbol);
              }
              WebSocketEndpointHelper.logSwitchStep('Chart reconnect done');
            }
          }
        } catch (_) {}
      }),
      // Dashboard WS - Unsubscribe if connected
      Future(() async {
        try {
          if (Get.isRegistered<DashboardController>()) {
            final dashboardController = Get.find<DashboardController>();
            // unsubscribeAndResubscribe handles both connected and disconnected cases
            WebSocketEndpointHelper.logSwitchStep(
              'Dashboard unsubscribe start',
            );
            await dashboardController.unsubscribeAndResubscribe();
            WebSocketEndpointHelper.logSwitchStep('Dashboard unsubscribe done');
          }
        } catch (_) {}
      }),
    ]);

    // ✅ FIX: Add explicit data requests after all WebSocket reconnections complete
    // This ensures data is requested even if services didn't request it automatically
    Future.delayed(const Duration(milliseconds: 150), () {
      try {
        // Request account data explicitly
        if (Get.isRegistered<AccountWebSocketService>()) {
          final accountWS = Get.find<AccountWebSocketService>();
          if (accountWS.isConnected.value) {
            accountWS.requestAccountData();
          }
        }

        // Request instrument data explicitly (if instruments controller is connected)
        if (Get.isRegistered<InstrumentsController>()) {
          final instrumentsController = Get.find<InstrumentsController>();
          if (instrumentsController.isConnected.value) {
            instrumentsController.getSocketdata();
          }
        }
      } catch (e) {
        // Error requesting data - services may not be ready yet
      }
    });
  }

  // Convert MT5 account to AccountModel for compatibility
  AccountModel? convertMT5ToAccountModel(MT5Account mt5Account) {
    try {
      return AccountModel(
        id: mt5Account.metaAccountNumber,
        type: mt5Account.isRealAccount ? 'REAL' : 'DEMO',
        balance: double.tryParse(mt5Account.balance) ?? 0.0,
        currency: 'USD', // Default currency
        isActive: mt5Account.isPrimaryAccount,
        createdAt: DateTime.now(), // You might want to get this from API
        metadata: {
          'mt5_account': true,
          'account_type': mt5Account.accountType,
          'master_group_id': mt5Account.masterGroupId,
          'leverage_id': mt5Account.leverageId,
          'equity': mt5Account.equity,
          'margin': mt5Account.margin,
          'free_margin': mt5Account.freeMargin,
          'profit': mt5Account.profit,
        },
      );
    } catch (e) {
      return null;
    }
  }

  // Get all accounts (both local and MT5) as AccountModel list
  List<AccountModel> getAllAccountsAsModels() {
    final List<AccountModel> allAccounts = List.from(_accounts);

    // Add MT5 accounts as AccountModel
    for (final mt5Account in _mt5Accounts) {
      final accountModel = convertMT5ToAccountModel(mt5Account);
      if (accountModel != null) {
        allAccounts.add(accountModel);
      }
    }

    return allAccounts;
  }

  // Refresh both local accounts and MT5 accounts
  Future<void> refreshAllAccounts() async {
    await loadAccounts();
    await _dashboardController.refreshMT5Accounts();
  }

  // Force refresh MT5 accounts
  Future<void> forceRefreshMT5Accounts() async {
    await _dashboardController.forceCheckMT5Accounts();
  }

  // Test method to create a demo MT5 account
  // Future<void> testCreateMT5Account() async {
  //   print('🧪 Testing MT5 account creation...');

  //   final success = await createMT5Account(
  //     groupId: 1,
  //     mainPassword: 'test123',
  //     investorPassword: 'investor123',
  //     accountType: 'demo',
  //   );

  //   if (success) {
  //     print('✅ Test MT5 account created successfully!');
  //     print('📊 Total MT5 accounts: ${mt5Accounts.length}');
  //     for (var account in mt5Accounts) {
  //       print('   - ${account.metaAccountNumber} (${account.accountType})');
  //     }
  //   } else {
  //     print('❌ Test MT5 account creation failed: $errorMessage');
  //   }
  // }

  // Create new MT5 account
  Future<Map<String, dynamic>?> createMT5Account({
    int? groupId,
    required String mainPassword,
    required String investorPassword,
    String? leverage,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final success;
      if (groupId != null) {
        success = await _dashboardController.createMT5Account(
          groupId: groupId,
          mainPassword: mainPassword,
          investorPassword: investorPassword,
          leverage: leverage,
        );
      } else {
        success = await _dashboardController.createMT5Account(
          mainPassword: mainPassword,
          investorPassword: investorPassword,
          leverage: leverage,
        );
      }

      if (success != null) {
        _successMessage.value = 'MT5 account created successfully';
        // Refresh all accounts to get the latest data
        await refreshAllAccounts();
        return success; // Return the account data
      } else {
        _errorMessage.value =
            success.message ??
            'Something went wrong'; //'Failed to create MT5 account';
        return null;
      }
    } catch (e) {
      _errorMessage.value = 'Something went wrong';
      return null;
    } finally {
      _setLoading(false);
    }
  }
}
