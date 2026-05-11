import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/utils/date_helper.dart';

/// Service for caching symbol details (contract size, digits, etc.) per account
/// Fetches from /api/user/instruments/{trading_account} API
/// Uses SharedPreferences for persistent storage per account
class SymbolDetailsCacheService {
  // Cache key format: symbol_details_{account_number}
  static String _getCacheKey(String accountNumber) => 'symbol_details_$accountNumber';
  static String _getCacheTimestampKey(String accountNumber) => 'symbol_details_timestamp_$accountNumber';
  
  // Default cache validity: 24 hours
  static const int _defaultCacheValidityHours = 24;

  /// Symbol detail model for caching
  static Map<String, dynamic> _symbolDetailFromApi(Map<String, dynamic> symbol) {
    return {
      'symbol_id': symbol['symbol_id'],
      'display_symbol': symbol['display_symbol'] ?? '',
      'datafeed_symbol': symbol['datafeed_symbol'] ?? '',
      'contract_size': symbol['contract_size'] ?? 100000, // Default to 100000 for forex
      'digits': symbol['digits'] ?? 5,
      'category_name': symbol['category_name'] ?? 'Currency',
      'is_active': symbol['is_active'] ?? true,
    };
  }

  /// Fetch and cache symbol details for an account
  /// Returns true if successful, false otherwise
  static Future<bool> fetchAndCacheSymbolDetails(String accountNumber) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('🔵 SymbolDetailsCacheService: API CALL - Fetching symbols');
      print('   Account: $accountNumber');
      print('   Endpoint: user/instruments/$accountNumber');
      print('═══════════════════════════════════════════════════════════');
      
      final response = await Get.find<ApiClient>().get(
        endpoint: 'user/instruments/$accountNumber',
      );

      print('SymbolDetailsCacheService: API Response received');
      print('   Success: ${response.success}');
      print('   Message: ${response.message}');
      print('   Response data type: ${response.data.runtimeType}');
      if (response.data != null && response.data is Map) {
        print('   Response data keys: ${(response.data as Map).keys.toList()}');
      }

      if (response.success && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        // ApiService returns the entire response object, so we need to access data.data.symbols
        final innerData = responseData['data'] as Map<String, dynamic>?;
        
        if (innerData != null && innerData['symbols'] != null) {
          final symbols = (innerData['symbols'] as List)
              .map((s) => _symbolDetailFromApi(s as Map<String, dynamic>))
              .toList();

          // Clear old cache before storing new data to avoid memory leaks
          await clearCacheForAccount(accountNumber);

          // Store in cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _getCacheKey(accountNumber),
            jsonEncode(symbols),
          );
          await prefs.setString(
            _getCacheTimestampKey(accountNumber),
            DateHelper.nowUtc().toIso8601String(),
          );

          print('═══════════════════════════════════════════════════════════');
          print('✅ SymbolDetailsCacheService: Cached ${symbols.length} symbols');
          print('   Account: $accountNumber');
          print('   Sample symbols: ${symbols.take(3).map((s) => s['display_symbol']).join(', ')}');
          print('═══════════════════════════════════════════════════════════');
          return true;
        } else {
          print('❌ SymbolDetailsCacheService: API returned no symbols data');
          print('   Inner data: $innerData');
          print('   Inner data keys: ${innerData?.keys.toList()}');
          return false;
        }
      } else {
        print('❌ SymbolDetailsCacheService: API error - ${response.message}');
        return false;
      }
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ SymbolDetailsCacheService: Error fetching symbols');
      print('   Error: $e');
      print('   StackTrace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      return false;
    }
  }

  /// Get cached symbol details for an account
  /// Returns null if cache doesn't exist, is expired, or invalid
  static Future<List<Map<String, dynamic>>?> getCachedSymbolDetails(String accountNumber) async {
    try {
      if (!await isCacheValid(accountNumber)) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final symbolsJsonStr = prefs.getString(_getCacheKey(accountNumber));
      
      if (symbolsJsonStr == null || symbolsJsonStr.isEmpty) {
        return null;
      }

      final symbolsJson = jsonDecode(symbolsJsonStr) as List;
      return symbolsJson.cast<Map<String, dynamic>>();
    } catch (e) {
      print('SymbolDetailsCacheService: Error getting cached symbols: $e');
      return null;
    }
  }

  /// Get symbol details (contract size, digits, etc.) for a symbol
  /// Returns null if symbol not found in cache
  static Future<Map<String, dynamic>?> getSymbolDetails(String symbol, String accountNumber) async {
    try {
      print('SymbolDetailsCacheService: Looking up symbol "$symbol" for account $accountNumber');
      
      final cachedSymbols = await getCachedSymbolDetails(accountNumber);
      
      if (cachedSymbols == null || cachedSymbols.isEmpty) {
        print('❌ SymbolDetailsCacheService: No cached symbols for account $accountNumber');
        print('   Cache might be empty or expired. Try calling ensureCached() first.');
        return null;
      }

      print('SymbolDetailsCacheService: Found ${cachedSymbols.length} cached symbols');

      // Try to match by display_symbol or datafeed_symbol
      final symbolUpper = symbol.toUpperCase();
      final matchedSymbol = cachedSymbols.firstWhere(
        (s) {
          final displaySymbol = (s['display_symbol'] ?? '').toString().toUpperCase();
          final datafeedSymbol = (s['datafeed_symbol'] ?? '').toString().toUpperCase();
          // Remove .c suffix for comparison
          final cleanDisplay = displaySymbol.replaceAll('.C', '').replaceAll('.R', '');
          final cleanDatafeed = datafeedSymbol.replaceAll('.C', '').replaceAll('.R', '');
          final cleanSymbol = symbolUpper.replaceAll('.C', '').replaceAll('.R', '');
          
          return cleanDisplay == cleanSymbol || cleanDatafeed == cleanSymbol;
        },
        orElse: () => <String, dynamic>{},
      );

      if (matchedSymbol.isNotEmpty) {
        print('✅ SymbolDetailsCacheService: Found symbol "$symbol"');
        print('   Contract Size: ${matchedSymbol['contract_size']}');
        print('   Digits: ${matchedSymbol['digits']}');
        return matchedSymbol;
      }

      print('❌ SymbolDetailsCacheService: Symbol "$symbol" not found in cache');
      print('   Available symbols: ${cachedSymbols.take(5).map((s) => s['display_symbol']).join(', ')}...');
      return null;
    } catch (e, stackTrace) {
      print('❌ SymbolDetailsCacheService: Error getting symbol details: $e');
      print('   StackTrace: $stackTrace');
      return null;
    }
  }

  /// Get contract size for a symbol
  /// Returns null if symbol not found in cache (no hardcoded fallback)
  static Future<int?> getContractSize(String symbol, String accountNumber) async {
    final symbolDetails = await getSymbolDetails(symbol, accountNumber);
    if (symbolDetails != null && symbolDetails['contract_size'] != null) {
      return (symbolDetails['contract_size'] as num).toInt();
    }
    return null;
  }

  /// Get digits for a symbol (for price/P&L formatting)
  /// Returns null if symbol not found in cache
  static Future<int?> getSymbolDigits(String symbol, String accountNumber) async {
    final symbolDetails = await getSymbolDetails(symbol, accountNumber);
    if (symbolDetails != null && symbolDetails['digits'] != null) {
      return (symbolDetails['digits'] as num).toInt();
    }
    return null;
  }

  /// Check if cache is still valid for an account
  /// Returns true if cache exists and is within validity period
  static Future<bool> isCacheValid(String accountNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(_getCacheTimestampKey(accountNumber));
      
      if (timestampStr == null || timestampStr.isEmpty) {
        return false;
      }

      final timestamp = DateTime.parse(timestampStr);
      final validityDuration = Duration(hours: _defaultCacheValidityHours);
      final now = DateHelper.nowUtc();

      return now.difference(timestamp) < validityDuration;
    } catch (e) {
      print('SymbolDetailsCacheService: Error checking cache validity: $e');
      return false;
    }
  }

  /// Clear cached symbol details for a specific account
  static Future<void> clearCacheForAccount(String accountNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getCacheKey(accountNumber));
      await prefs.remove(_getCacheTimestampKey(accountNumber));
      print('SymbolDetailsCacheService: Cleared cache for account $accountNumber');
    } catch (e) {
      print('SymbolDetailsCacheService: Error clearing cache: $e');
    }
  }

  /// Clear all cached symbol details (all accounts)
  /// Called on logout to prevent data leakage between users
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('symbol_details_') && !key.contains('timestamp')) {
          await prefs.remove(key);
        }
        if (key.startsWith('symbol_details_timestamp_')) {
          await prefs.remove(key);
        }
      }
      
      print('SymbolDetailsCacheService: Cleared all symbol details cache');
    } catch (e) {
      print('SymbolDetailsCacheService: Error clearing all cache: $e');
    }
  }

  /// Ensure symbol details are cached for an account
  /// Fetches if cache is missing or expired
  /// Returns true if cache is available (either existing or newly fetched)
  static Future<bool> ensureCached(String accountNumber) async {
    try {
      // Check if cache is valid
      if (await isCacheValid(accountNumber)) {
        print('SymbolDetailsCacheService: Cache valid for account $accountNumber');
        return true;
      }

      // Cache expired or missing, fetch fresh data
      print('SymbolDetailsCacheService: Cache expired/missing, fetching for account $accountNumber');
      return await fetchAndCacheSymbolDetails(accountNumber);
    } catch (e) {
      print('SymbolDetailsCacheService: Error ensuring cache: $e');
      return false;
    }
  }
}
