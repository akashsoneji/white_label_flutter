import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/account_cache_service.dart';
import 'package:crm_app/utils/date_helper.dart';

/// Centralized WebSocket endpoint management
/// Provides consistent endpoint selection based on account type (MT5 vs Self-hosted)
class WebSocketEndpointHelper {
  // ==================== CACHE FOR PRIMARY ACCOUNT ====================
  static MT5Account? _cachedPrimaryAccount;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheValidity = Duration(minutes: 5);

  // ==================== SWITCH TRACE ====================
  static String? _currentSwitchId;
  static int? _currentSwitchStartMs;

  // ✅ FIX: Store primary account set during app initialization
  static MT5Account? _initializedPrimaryAccount;

  /// Set primary account during app initialization
  static void setPrimaryAccount(MT5Account? account) {
    _initializedPrimaryAccount = account;
    _cachedPrimaryAccount = account;
    _cacheTimestamp = account != null ? DateHelper.nowUtc() : null;
    // ✅ FIX: Also save to persistent cache
    AccountCacheService.savePrimaryAccount(account);
    if (kDebugMode) {
      print(
        'WebSocketEndpointHelper: Primary account set: ${account?.metaAccountNumber ?? "null"} (${account?.tradingServer ?? "N/A"})',
      );
    }
  }

  /// Get stored primary account (set during initialization)
  /// ✅ FIX: Check persistent cache first, then in-memory cache
  static Future<MT5Account?> getStoredPrimaryAccount() async {
    // First check persistent cache
    final cachedAccount = await AccountCacheService.getCachedPrimaryAccount();
    if (cachedAccount != null) {
      // Update in-memory cache for consistency
      _initializedPrimaryAccount = cachedAccount;
      _cachedPrimaryAccount = cachedAccount;
      return cachedAccount;
    }
    // Fallback to in-memory cache
    return _initializedPrimaryAccount ?? _cachedPrimaryAccount;
  }

  /// Get cached primary account from persistent storage
  /// This is a synchronous wrapper that returns the in-memory cache
  /// For async persistent cache, use getStoredPrimaryAccount()
  static MT5Account? getCachedPrimaryAccountSync() {
    return _initializedPrimaryAccount ?? _cachedPrimaryAccount;
  }

  // ==================== UNIFIED ENDPOINTS (BOTH MT5 AND SELF-HOSTED) ====================
  static const String openPositions = '/ws/op';
  static const String pendingOrders = '/ws/po';
  static const String symbol = '/ws/symbol';
  static const String marketWatch = '/ws/marketwatch';
  static const String accountEndpoint = '/ws/account';

  // ==================== ENDPOINT GETTERS ====================

  /// Get open positions endpoint (unified for both MT5 and self-hosted)
  /// Account type detection happens on Trade Engine side after authentication
  static String getOpenPositionsEndpoint(MT5Account? account) {
    return openPositions; // Always '/ws/op'
  }

  /// Get symbol endpoint (unified for both MT5 and self-hosted)
  static String getSymbolEndpoint(MT5Account? account) {
    return symbol; // Always '/ws/symbol'
  }

  /// Get market watch endpoint (unified for both MT5 and self-hosted)
  static String getMarketWatchEndpoint(MT5Account? account) {
    return marketWatch; // Always '/ws/marketwatch'
  }

  /// Get account endpoint (unified for both MT5 and self-hosted)
  static String getAccountEndpoint(MT5Account? account) {
    return accountEndpoint; // Always '/ws/account'
  }

  /// Get pending orders endpoint (unified for both MT5 and self-hosted)
  /// Account type detection happens on Trade Engine side after authentication
  static String getPendingOrdersEndpoint(MT5Account? account) {
    return pendingOrders; // Always '/ws/po'
  }

  // ==================== HELPER METHODS ====================

  /// Check if account is MT5 type
  /// Returns true if account exists and tradingServer is "MT5" (case-insensitive)
  /// Returns false if account is null or not MT5
  static bool _isMT5Account(MT5Account? account) {
    if (account == null) return false;
    return account.tradingServer.toUpperCase() == "MT5";
  }

  /// Public method to check if account is MT5 type (for external use)
  /// Returns true if account exists and tradingServer is "MT5" (case-insensitive)
  /// Returns false if account is null or not MT5
  static bool isMT5Account(MT5Account? account) {
    return _isMT5Account(account);
  }

  /// Get account type as string for logging
  static String getAccountType(MT5Account? account) {
    return _isMT5Account(account) ? "MT5" : "Self-hosted";
  }

  /// Get full WebSocket URL by combining base URL with endpoint
  static String getFullUrl(String endpoint) {
    final baseUrl = ApiConstants.socketUrl;
    // ✅ FIX: Ensure endpoint starts with / and baseUrl doesn't end with /
    final cleanBaseUrl =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    // ✅ FIX: Remove any fragments (#) or query parameters that shouldn't be in WebSocket URL
    final cleanEndpointNoFragment = cleanEndpoint.split('#')[0].split('?')[0];

    final fullUrl = '$cleanBaseUrl$cleanEndpointNoFragment';

    // ✅ FIX: Ensure URL doesn't contain any fragments
    final finalUrl = fullUrl.split('#')[0];

    if (kDebugMode) {
      print(
        'WebSocketEndpointHelper: Constructed URL: $finalUrl (base: $baseUrl, endpoint: $endpoint)',
      );
    }

    return finalUrl;
  }

  /// Get full WebSocket URL for open positions
  static String getOpenPositionsUrl(MT5Account? account) {
    return getFullUrl(getOpenPositionsEndpoint(account));
  }

  /// Get full WebSocket URL for pending orders
  static String getPendingOrdersUrl(MT5Account? account) {
    return getFullUrl(getPendingOrdersEndpoint(account));
  }

  /// Get full WebSocket URL for symbol
  static String getSymbolUrl(MT5Account? account) {
    return getFullUrl(getSymbolEndpoint(account));
  }

  /// Get full WebSocket URL for market watch
  static String getMarketWatchUrl(MT5Account? account) {
    return getFullUrl(getMarketWatchEndpoint(account));
  }

  static const String marketWatchV2 = '/ws/marketwatchv2';

  /// Per-symbol subscribe/unsubscribe feed (binary MessagePack ticks).
  static String getMarketWatchV2Url() {
    return getFullUrl(marketWatchV2);
  }

  /// Get full WebSocket URL for account
  static String getAccountUrl(MT5Account? account) {
    return getFullUrl(getAccountEndpoint(account));
  }

  // ==================== ACCOUNT FETCHING METHODS ====================

  /// Fetch MT5 accounts from API and return primary account
  static Future<MT5Account?> fetchPrimaryAccount() async {
    try {
      // ✅ FIX: Check persistent cache first
      final cachedAccount = await AccountCacheService.getCachedPrimaryAccount();
      if (cachedAccount != null) {
        // Update in-memory cache for consistency
        _cachedPrimaryAccount = cachedAccount;
        _cacheTimestamp = DateHelper.nowUtc();
        if (kDebugMode) {
          print('WebSocketEndpointHelper: Using cached primary account from persistent storage');
        }
        return cachedAccount;
      }

      // Fallback to in-memory cache
      if (_cachedPrimaryAccount != null &&
          _cacheTimestamp != null &&
          DateHelper.nowUtc().difference(_cacheTimestamp!) < _cacheValidity) {
        if (kDebugMode) {
          print('WebSocketEndpointHelper: Using in-memory cached primary account');
        }
        return _cachedPrimaryAccount;
      }

      final token = await SecureStorageService.getAuthToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('WebSocketEndpointHelper: No auth token available');
        }
        return null;
      }

      if (kDebugMode) {
        print(
          'WebSocketEndpointHelper: Fetching accounts from API: ${ApiConstants.getMT5Accounts}',
        );
      }

      final response = await Get.find<ApiClient>().get(
        endpoint: ApiConstants.getMT5Accounts,
        token: token,
      );

      if (response.success && response.data['status'] == true) {
        final accountsData = response.data['data'] as List?;
        if (accountsData != null && accountsData.isNotEmpty) {
          final accounts =
              accountsData
                  .map((account) => MT5Account.fromJson(account))
                  .toList();

          // Find primary account
          MT5Account? primaryAccount;
          try {
            primaryAccount = accounts.firstWhere(
              (account) => account.isPrimaryAccount,
            );
          } catch (e) {
            // No primary account found, use first account
            primaryAccount = accounts.first;
          }

          _cachedPrimaryAccount = primaryAccount;
          _cacheTimestamp = DateHelper.nowUtc();
          // ✅ FIX: Also save to persistent cache
          await AccountCacheService.savePrimaryAccount(primaryAccount);

          if (kDebugMode) {
            print(
              'WebSocketEndpointHelper: Fetched primary account: ${primaryAccount.metaAccountNumber} (${primaryAccount.tradingServer})',
            );
          }

          return primaryAccount;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebSocketEndpointHelper: Error fetching accounts: $e');
      }
    }
    return null;
  }

  /// Get primary account, fetching from API if not provided
  static Future<MT5Account?> getPrimaryAccount(
    MT5Account? providedAccount,
  ) async {
    if (providedAccount != null) return providedAccount;
    return await fetchPrimaryAccount();
  }

  /// Clear cached account (call when account switches)
  static void clearCache() {
    _cachedPrimaryAccount = null;
    _cacheTimestamp = null;
    _initializedPrimaryAccount = null;
    if (kDebugMode) {
      print('WebSocketEndpointHelper: Cache cleared');
    }
  }

  /// Begin a trace for an account switch to measure end-to-end latency
  static void beginSwitchTrace(String accountNumber) {
    _currentSwitchStartMs = DateHelper.nowUtc().millisecondsSinceEpoch;
    _currentSwitchId = 'sw-${_currentSwitchStartMs ?? 0}-$accountNumber';
    if (kDebugMode) {
      print('⏱️ WS Switch Trace started ($_currentSwitchId) for $accountNumber');
    }
  }

  /// Log a timed step for the active switch trace
  static void logSwitchStep(
    String label, {
    String? url,
    Map<String, dynamic>? payload,
  }) {
    if (!kDebugMode) return;
    final now = DateHelper.nowUtc().millisecondsSinceEpoch;
    final delta = _currentSwitchStartMs != null
        ? now - _currentSwitchStartMs!
        : null;
    final parts = <String>[
      '⏱️ WS Switch Step',
      if (_currentSwitchId != null) '[${_currentSwitchId}]',
      label,
      if (delta != null) '(${delta}ms)',
      if (url != null) 'url=$url',
      if (payload != null) 'payload=$payload',
    ];
    print(parts.join(' | '));
  }

  /// Clear current switch trace
  static void endSwitchTrace() {
    if (kDebugMode && _currentSwitchId != null) {
      print('⏱️ WS Switch Trace ended (${_currentSwitchId})');
    }
    _currentSwitchId = null;
    _currentSwitchStartMs = null;
  }
}
