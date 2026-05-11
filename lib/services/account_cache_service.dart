import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/utils/date_helper.dart';

/// Service for caching MT5 account data to avoid API delays
/// Uses SharedPreferences for persistent storage
class AccountCacheService {
  static const String _cachedMT5AccountsKey = 'cached_mt5_accounts';
  static const String _cachedPrimaryAccountKey = 'cached_primary_account';
  static const String _cacheTimestampKey = 'account_cache_timestamp';
  static const String _cacheValidityMinutesKey = 'account_cache_validity_minutes';
  
  // Default cache validity: 5 minutes
  static const int _defaultCacheValidityMinutes = 5;

  /// Save MT5 accounts list to cache
  static Future<void> saveMT5Accounts(List<MT5Account> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = accounts.map((account) => account.toJson()).toList();
      await prefs.setString(_cachedMT5AccountsKey, jsonEncode(accountsJson));
      await prefs.setString(_cacheTimestampKey, DateHelper.nowUtc().toIso8601String());
      await prefs.setInt(_cacheValidityMinutesKey, _defaultCacheValidityMinutes);
    } catch (e) {
      print('AccountCacheService: Error saving MT5 accounts: $e');
    }
  }

  /// Get cached MT5 accounts list
  /// Returns null if cache doesn't exist, is expired, or invalid
  static Future<List<MT5Account>?> getCachedMT5Accounts() async {
    try {
      if (!await isCacheValid()) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final accountsJsonStr = prefs.getString(_cachedMT5AccountsKey);
      
      if (accountsJsonStr == null || accountsJsonStr.isEmpty) {
        return null;
      }

      final accountsJson = jsonDecode(accountsJsonStr) as List;
      final accounts = accountsJson
          .map((json) => MT5Account.fromJson(json as Map<String, dynamic>))
          .toList();

      return accounts;
    } catch (e) {
      print('AccountCacheService: Error getting cached MT5 accounts: $e');
      return null;
    }
  }

  /// Save primary account to cache
  static Future<void> savePrimaryAccount(MT5Account? account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (account == null) {
        await prefs.remove(_cachedPrimaryAccountKey);
        return;
      }
      await prefs.setString(_cachedPrimaryAccountKey, jsonEncode(account.toJson()));
      await prefs.setString(_cacheTimestampKey, DateHelper.nowUtc().toIso8601String());
    } catch (e) {
      print('AccountCacheService: Error saving primary account: $e');
    }
  }

  /// Get cached primary account
  /// Returns null if cache doesn't exist, is expired, or invalid
  static Future<MT5Account?> getCachedPrimaryAccount() async {
    try {
      if (!await isCacheValid()) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final accountJsonStr = prefs.getString(_cachedPrimaryAccountKey);
      
      if (accountJsonStr == null || accountJsonStr.isEmpty) {
        return null;
      }

      final accountJson = jsonDecode(accountJsonStr) as Map<String, dynamic>;
      return MT5Account.fromJson(accountJson);
    } catch (e) {
      print('AccountCacheService: Error getting cached primary account: $e');
      return null;
    }
  }

  /// Check if cache is still valid
  /// Returns true if cache exists and is within validity period
  static Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(_cacheTimestampKey);
      
      if (timestampStr == null || timestampStr.isEmpty) {
        return false;
      }

      final timestamp = DateTime.parse(timestampStr);
      final validityMinutes = prefs.getInt(_cacheValidityMinutesKey) ?? _defaultCacheValidityMinutes;
      final validityDuration = Duration(minutes: validityMinutes);
      final now = DateHelper.nowUtc();

      return now.difference(timestamp) < validityDuration;
    } catch (e) {
      print('AccountCacheService: Error checking cache validity: $e');
      return false;
    }
  }

  /// Clear all cached account data
  /// Called on logout to prevent data leakage between users
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedMT5AccountsKey);
      await prefs.remove(_cachedPrimaryAccountKey);
      await prefs.remove(_cacheTimestampKey);
      await prefs.remove(_cacheValidityMinutesKey);
      print('AccountCacheService: Cache cleared successfully');
    } catch (e) {
      print('AccountCacheService: Error clearing cache: $e');
    }
  }
}

