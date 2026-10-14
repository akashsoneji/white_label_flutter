import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/utils/date_helper.dart';

import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';

/// Service for caching symbol details (contract size, digits, etc.) per account
/// Fetches from /api/user/instruments/{trading_account} API
/// Uses SharedPreferences for persistent storage per account
class SymbolDetailsCacheService {
  // Cache key format: symbol_details_{account_number}
  static String _getCacheKey(String accountNumber) => 'symbol_details_$accountNumber';
  static String _getCacheTimestampKey(String accountNumber) => 'symbol_details_timestamp_$accountNumber';
  
  // Default cache validity: 24 hours
  static const int _defaultCacheValidityHours = 24;

  /// In-memory cache for fast, synchronous datafeed symbol lookups
  static final Map<String, List<Map<String, dynamic>>> _memoryCache = {};

  /// Fast global lookup for clean/upper symbol -> broker datafeed_symbol (e.g. "UKOIL" -> "UKOil.c")
  static final Map<String, String> _globalDatafeedLookup = {};

  /// Reverse lookup: upper datafeed/display symbol -> API `display_symbol`
  /// (e.g. "UKOIL.C" -> "UKOil").
  static final Map<String, String> _globalDisplayLookup = {};

  /// Symbol without whatever broker suffix follows the last dot. The suffix
  /// itself (`.c`, `.cent`, `.r`, ...) is never hardcoded — it comes from
  /// the instruments API `datafeed_symbol`.
  static String _cleanKey(String upper) {
    final dot = upper.lastIndexOf('.');
    return dot > 0 ? upper.substring(0, dot) : upper;
  }

  /// Registers a display -> datafeed mapping in the global lookup table
  static void registerDatafeedSymbol(String displaySymbol, String datafeedSymbol) {
    if (displaySymbol.isEmpty || datafeedSymbol.isEmpty) return;
    final display = displaySymbol.trim();
    final datafeed = datafeedSymbol.trim();
    final upperDisp = display.toUpperCase();
    final upperDf = datafeed.toUpperCase();
    _globalDatafeedLookup[upperDisp] = datafeed;
    _globalDatafeedLookup[_cleanKey(upperDf)] = datafeed;
    _globalDatafeedLookup[upperDf] = datafeed;
    _globalDisplayLookup[upperDisp] = display;
    _globalDisplayLookup[upperDf] = display;
  }

  /// Datafeed symbol -> display symbol from the instruments API
  /// (`AUDCAD.c` -> `AUDCAD`). A symbol not in any instruments response
  /// drops the part after its last dot.
  static String displaySymbolOf(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final fromApi = _globalDisplayLookup[trimmed.toUpperCase()];
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    final dot = trimmed.lastIndexOf('.');
    return dot > 0 ? trimmed.substring(0, dot) : trimmed;
  }

  /// `datafeed_symbol` of the entry in [symbols] matching [symbolUpper].
  static String? _findDatafeed(
    List<Map<String, dynamic>>? symbols,
    String symbolUpper,
  ) {
    if (symbols == null) return null;
    final cleanSymbol = _cleanKey(symbolUpper);
    for (final s in symbols) {
      final display = (s['display_symbol'] ?? '').toString().trim();
      final datafeed = (s['datafeed_symbol'] ?? '').toString().trim();
      if (datafeed.isEmpty) continue;
      final displayUpper = display.toUpperCase();
      final datafeedUpper = datafeed.toUpperCase();
      final matches =
          displayUpper == symbolUpper ||
          datafeedUpper == symbolUpper ||
          _cleanKey(datafeedUpper) == cleanSymbol;
      if (!matches) continue;
      registerDatafeedSymbol(display, datafeed);
      return datafeed;
    }
    return null;
  }

  /// Initialize memory cache and global lookup from SharedPreferences on app launch
  static Future<void> initFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('symbol_details_') && !key.contains('timestamp')) {
          final jsonStr = prefs.getString(key);
          if (jsonStr != null && jsonStr.isNotEmpty) {
            final acc = key.replaceFirst('symbol_details_', '');
            final decoded = jsonDecode(jsonStr);
            if (decoded is List) {
              final list = <Map<String, dynamic>>[];
              for (final item in decoded) {
                if (item is Map) {
                  final map = Map<String, dynamic>.from(item);
                  list.add(map);
                  final disp = (map['display_symbol'] ?? '').toString();
                  final df = (map['datafeed_symbol'] ?? '').toString();
                  if (df.isNotEmpty) {
                    registerDatafeedSymbol(disp, df);
                  }
                }
              }
              _memoryCache[acc] = list;
            }
          }
        }
      }
      print('✅ SymbolDetailsCacheService: Loaded ${_globalDatafeedLookup.length} datafeed mappings from storage');
    } catch (e) {
      print('⚠️ SymbolDetailsCacheService: Error loading from storage: $e');
    }
  }

  static String? _activeAccount(String? accountNumber) {
    if (accountNumber != null && accountNumber.isNotEmpty) return accountNumber;
    if (!Get.isRegistered<AccountController>()) return null;
    final active = Get.find<AccountController>().activeMT5Account;
    return active?.metaAccountNumber.toString();
  }

  /// Synchronous lookup of the broker `datafeed_symbol` from the
  /// `user/instruments/{account}` API ("AUDCAD" -> "AUDCAD.c"). The active
  /// account's instruments win, because each account can use a different
  /// suffix. Nothing is appended by the app: an unknown symbol is returned
  /// as-is until the instruments API has been loaded.
  static String resolveDatafeedSymbolSync(String symbol, String? accountNumber) {
    if (symbol.isEmpty) return symbol;
    final symbolUpper = symbol.toUpperCase().trim();

    final acc = _activeAccount(accountNumber);
    if (acc != null && acc.isNotEmpty) {
      final fromAccount = _findDatafeed(_memoryCache[acc], symbolUpper);
      if (fromAccount != null) return fromAccount;
    }

    final fromGlobal =
        _globalDatafeedLookup[symbolUpper] ??
        _globalDatafeedLookup[_cleanKey(symbolUpper)];
    if (fromGlobal != null && fromGlobal.isNotEmpty) return fromGlobal;

    for (final symbols in _memoryCache.values) {
      final fromAny = _findDatafeed(symbols, symbolUpper);
      if (fromAny != null) return fromAny;
    }

    if (Get.isRegistered<InstrumentsController>()) {
      final inst = Get.find<InstrumentsController>().findInstrument(symbol);
      if (inst != null && inst.symbol.contains('.')) return inst.symbol;
    }

    return symbol.trim();
  }

  /// Async lookup: loads the account's instruments API when it is not cached
  /// yet, then resolves the `datafeed_symbol` from it.
  static Future<String> resolveDatafeedSymbol(String symbol, String? accountNumber) async {
    if (symbol.isEmpty) return symbol;
    final acc = _activeAccount(accountNumber);
    if (acc != null && acc.isNotEmpty && !_memoryCache.containsKey(acc)) {
      try {
        await ensureCached(acc);
      } catch (e) {
        print('SymbolDetailsCacheService: ensureCached failed for $acc: $e');
      }
    }
    return resolveDatafeedSymbolSync(symbol, acc);
  }

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

      if (response.success && response.data != null) {
        final Map<String, dynamic> responseData =
            response.data is Map ? Map<String, dynamic>.from(response.data as Map) : {};
        
        dynamic rawData = responseData['data'] ?? responseData;
        List rawSymbols = [];
        if (rawData is Map && rawData['symbols'] is List) {
          rawSymbols = rawData['symbols'] as List;
        } else if (rawData is List) {
          rawSymbols = rawData;
        } else if (responseData['symbols'] is List) {
          rawSymbols = responseData['symbols'] as List;
        }

        if (rawSymbols.isNotEmpty) {
          final symbols = <Map<String, dynamic>>[];
          for (final item in rawSymbols) {
            if (item is Map) {
              symbols.add(_symbolDetailFromApi(Map<String, dynamic>.from(item)));
            }
          }

          if (symbols.isNotEmpty) {
            await clearCacheForAccount(accountNumber);
            _memoryCache[accountNumber] = symbols;
            for (final s in symbols) {
              registerDatafeedSymbol(
                (s['display_symbol'] ?? '').toString(),
                (s['datafeed_symbol'] ?? '').toString(),
              );
            }

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
          }
        }
        print('❌ SymbolDetailsCacheService: API returned no symbols data');
        return false;
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
      if (_memoryCache.containsKey(accountNumber)) {
        return _memoryCache[accountNumber];
      }

      if (!await isCacheValid(accountNumber)) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final symbolsJsonStr = prefs.getString(_getCacheKey(accountNumber));
      
      if (symbolsJsonStr == null || symbolsJsonStr.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(symbolsJsonStr);
      if (decoded is! List) return null;
      final result = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
      _memoryCache[accountNumber] = result;
      for (final s in result) {
        registerDatafeedSymbol(
          (s['display_symbol'] ?? '').toString(),
          (s['datafeed_symbol'] ?? '').toString(),
        );
      }
      return result;
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
      
      var cachedSymbols = await getCachedSymbolDetails(accountNumber);
      
      if (cachedSymbols == null || cachedSymbols.isEmpty) {
        await ensureCached(accountNumber);
        cachedSymbols = await getCachedSymbolDetails(accountNumber);
      }

      if (cachedSymbols == null || cachedSymbols.isEmpty) {
        print('❌ SymbolDetailsCacheService: No cached symbols for account $accountNumber');
        return null;
      }

      print('SymbolDetailsCacheService: Found ${cachedSymbols.length} cached symbols');

      // Try to match by display_symbol or datafeed_symbol
      final symbolUpper = symbol.toUpperCase().trim();
      final cleanSymbol = _cleanKey(symbolUpper);

      final matchedSymbol = cachedSymbols.firstWhere(
        (s) {
          final displaySymbol = (s['display_symbol'] ?? '').toString().toUpperCase().trim();
          final datafeedSymbol = (s['datafeed_symbol'] ?? '').toString().toUpperCase().trim();
          return displaySymbol == symbolUpper ||
              datafeedSymbol == symbolUpper ||
              _cleanKey(datafeedSymbol) == cleanSymbol;
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
      _memoryCache.remove(accountNumber);
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
      _memoryCache.clear();
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
        if (!_memoryCache.containsKey(accountNumber)) {
          await getCachedSymbolDetails(accountNumber);
        }
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
