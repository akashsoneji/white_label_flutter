import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_app/models/user_model.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Clear secure storage on first run to handle iOS Keychain persistent data on reinstall
  static Future<void> clearSecureStorageOnFirstRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstRun = prefs.getBool('is_first_run') ?? true;
      if (isFirstRun) {
        print('SecureStorage: First run detected. Wiping Keychain to prevent stale login.');
        await _storage.deleteAll();
        await prefs.setBool('is_first_run', false);
      }
    } catch (e) {
      print('SecureStorage: Error checking first run: $e');
    }
  }

  // Storage keys
  static const String _authTokenKey = 'auth_token';
  // NOTE: This is a hardcoded token used to bypass the login flow when needed.
  //       Use ONLY in development / QA builds. For production, remove or disable.
  // static const String _defaultBypassAuthToken =
  //     '3802|vSbWIFD2sHBI3hpCM8wcKpZCSrGvlm78enjnfXhPada4b335';
  static const String _websocketTokenKey = 'websocket_token';
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _selectedSymbolKey = 'selected_symbol';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricUserKey = 'biometric_user';

  // Save authentication token
  static Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: _authTokenKey, value: token);
      print('SecureStorage: Auth token saved successfully');
    } catch (e) {
      print('SecureStorage: Error saving auth token: $e');
      rethrow;
    }
  }

  // Get authentication token
  static Future<String?> getAuthToken() async {
    try {
      final token = await _storage.read(key: _authTokenKey);
      print(
        'SecureStorage: Auth token retrieved: ${token != null ? 'exists' : 'null'}',
      );
      return token;
    } catch (e) {
      print('SecureStorage: Error getting auth token: $e');
      return null;
    }
  }

  // Save websocket token
  static Future<void> saveWebsocketToken(String token) async {
    try {
      await _storage.write(key: _websocketTokenKey, value: token);
      print('SecureStorage: Websocket token saved successfully');
    } catch (e) {
      print('SecureStorage: Error saving websocket token: $e');
      rethrow;
    }
  }

  // Get websocket token
  static Future<String?> getWebsocketToken() async {
    try {
      final token = await _storage.read(key: _websocketTokenKey);
      print(
        'SecureStorage: Websocket token retrieved: ${token != null ? 'exists' : 'null'}',
      );
      return token;
    } catch (e) {
      print('SecureStorage: Error getting websocket token: $e');
      return null;
    }
  }

  // Save FCM token
  static Future<void> saveFcmToken(String token) async {
    try {
      await _storage.write(key: _fcmTokenKey, value: token);
      print('SecureStorage: FCM token saved successfully');
    } catch (e) {
      print('SecureStorage: Error saving FCM token: $e');
    }
  }

  // Get FCM token
  static Future<String?> getFcmToken() async {
    try {
      final token = await _storage.read(key: _fcmTokenKey);
      print(
        'SecureStorage: FCM token retrieved: ${token != null ? 'exists' : 'null'}',
      );
      return token;
    } catch (e) {
      print('SecureStorage: Error getting FCM token: $e');
      return null;
    }
  }

  // Save user data
  static Future<void> saveUserData(String userData) async {
    try {
      await _storage.write(key: _userDataKey, value: userData);
      print('SecureStorage: User data saved successfully');
    } catch (e) {
      print('SecureStorage: Error saving user data: $e');
      rethrow;
    }
  }

  // Get user data
  static Future<UserModel?> getUserData() async {
    try {
      final userData = await _storage.read(key: _userDataKey);
      if (userData == null) {
        print('SecureStorage: No user data found');
        return null;
      }

      final Map<String, dynamic> loginData = jsonDecode(userData);
      final userModel = UserModel.fromJson(loginData['user']);
      print("userData getUserData : $userData");
      print('SecureStorage: User data retrieved: exists');
      return userModel;
    } catch (e) {
      print('SecureStorage: Error getting user data: $e');
      return null;
    }
  }

  // Get complete login data (including token, websocket token, etc.)
  static Future<Map<String, dynamic>?> getCompleteLoginData() async {
    try {
      final userData = await _storage.read(key: _userDataKey);
      if (userData == null) {
        print('SecureStorage: No login data found');
        return null;
      }

      final Map<String, dynamic> loginData = jsonDecode(userData);
      print('SecureStorage: Complete login data retrieved');
      return loginData;
    } catch (e) {
      print('SecureStorage: Error getting complete login data: $e');
      return null;
    }
  }

  // Save login status
  static Future<void> saveLoginStatus(bool isLoggedIn) async {
    try {
      await _storage.write(key: _isLoggedInKey, value: isLoggedIn.toString());
      print('SecureStorage: Login status saved: $isLoggedIn');
    } catch (e) {
      print('SecureStorage: Error saving login status: $e');
      rethrow;
    }
  }

  // Get login status
  static Future<bool> getLoginStatus() async {
    try {
      final status = await _storage.read(key: _isLoggedInKey);
      final isLoggedIn = status == 'true';
      print('SecureStorage: Login status retrieved: $isLoggedIn');
      return isLoggedIn;
    } catch (e) {
      print('SecureStorage: Error getting login status: $e');
      return false;
    }
  }

  // Save all login data
  static Future<void> saveLoginData({
    required String authToken,
    required String websocketToken,
    required String userData,
  }) async {
    try {
      await Future.wait([
        saveAuthToken(authToken),
        saveWebsocketToken(websocketToken),
        saveUserData(userData),
        saveLoginStatus(true),
      ]);
      print('SecureStorage: All login data saved successfully');
    } catch (e) {
      print('SecureStorage: Error saving login data: $e');
      rethrow;
    }
  }

  // Clear all authentication data
  static Future<void> clearAuthData() async {
    try {
      await Future.wait([
        _storage.delete(key: _authTokenKey),
        _storage.delete(key: _websocketTokenKey),
        _storage.delete(key: _userDataKey),
        _storage.delete(key: _isLoggedInKey),
        _storage.delete(key: _selectedSymbolKey),
      ]);
      print('SecureStorage: All authentication data cleared');
    } catch (e) {
      print('SecureStorage: Error clearing authentication data: $e');
      rethrow;
    }
  }

  static Future<void> setBiometricEnabled(
    bool enabled, {
    String? userIdentifier,
  }) async {
    try {
      await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
      if (enabled) {
        if (userIdentifier != null && userIdentifier.trim().isNotEmpty) {
          await _storage.write(
            key: _biometricUserKey,
            value: userIdentifier.trim(),
          );
        }
      } else {
        await _storage.delete(key: _biometricUserKey);
      }
    } catch (e) {
      print('SecureStorage: Error saving biometric state: $e');
    }
  }

  static Future<bool> getBiometricEnabled() async {
    try {
      final v = await _storage.read(key: _biometricEnabledKey);
      return v == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getBiometricUserIdentifier() async {
    try {
      return await _storage.read(key: _biometricUserKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearBiometricState() async {
    try {
      await Future.wait([
        _storage.delete(key: _biometricEnabledKey),
        _storage.delete(key: _biometricUserKey),
      ]);
    } catch (e) {
      print('SecureStorage: Error clearing biometric state: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isUserLoggedIn() async {
    try {
      String? token = await getAuthToken();
      bool isLoggedIn = await getLoginStatus();

      return token != null && token.isNotEmpty && isLoggedIn;
    } catch (e) {
      print('SecureStorage: Error checking login status: $e');
      return false;
    }
  }

  // Save last selected trading symbol
  static Future<void> saveSelectedSymbol(String symbol) async {
    try {
      await _storage.write(key: _selectedSymbolKey, value: symbol);
      print('SecureStorage: Selected symbol saved: $symbol');
    } catch (e) {
      print('SecureStorage: Error saving selected symbol: $e');
      rethrow;
    }
  }

  // Get last selected trading symbol
  static Future<String?> getSelectedSymbol() async {
    try {
      final symbol = await _storage.read(key: _selectedSymbolKey);
      print('SecureStorage: Selected symbol retrieved: ${symbol ?? 'null'}');
      return symbol;
    } catch (e) {
      print('SecureStorage: Error getting selected symbol: $e');
      return null;
    }
  }

  // ── Tenax multi-broker support ────────────────────────────────────
  // Keys for Tenax broker data, profiles, and current selection.
  static const String _tenaxBrokerSelectionKey = 'tenax_broker_selection';
  static const String _tenaxBrokerSelectionFlagKey =
      'tenax_broker_selection_enabled';
  static const String _tenaxUserBrokerProfilesKey =
      'tenax_user_broker_profiles';
  static const String _tenaxCurrentProfileKeyKey = 'tenax_current_profile_key';

  /// Returns the persisted broker selection payload (JSON) for Tenax.
  static Future<Map<String, dynamic>?> getTenaxBrokerSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tenaxBrokerSelectionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (e) {
      print('SecureStorage: Error reading Tenax broker selection: $e');
      return null;
    }
  }

  /// Persist the broker selection payload (JSON-serializable map).
  static Future<void> saveTenaxBrokerSelection(
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenaxBrokerSelectionKey, json.encode(data));
    } catch (e) {
      print('SecureStorage: Error saving Tenax broker selection: $e');
    }
  }

  /// Feature flag: whether the Tenax multi-broker UI is enabled.
  static Future<bool> getTenaxBrokerSelectionFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_tenaxBrokerSelectionFlagKey) ?? false;
    } catch (e) {
      print('SecureStorage: Error reading Tenax broker selection flag: $e');
      return false;
    }
  }

  /// Stored list of broker profiles the user has logged into.
  static Future<List<Map<String, dynamic>>> getTenaxUserBrokerProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tenaxUserBrokerProfilesKey);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      print('SecureStorage: Error reading Tenax user broker profiles: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Insert or update a broker profile keyed by `profile_key` (email+broker).
  static Future<void> upsertTenaxUserBrokerProfile(
    Map<String, dynamic> profile,
  ) async {
    try {
      final profiles = await getTenaxUserBrokerProfiles();
      final key = profile['profile_key']?.toString() ?? '';
      final filtered =
          profiles.where((p) => p['profile_key']?.toString() != key).toList();
      filtered.add(profile);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _tenaxUserBrokerProfilesKey,
        json.encode(filtered),
      );
    } catch (e) {
      print('SecureStorage: Error upserting Tenax user broker profile: $e');
    }
  }

  /// Current active broker profile key (email+broker composite).
  static Future<String?> getTenaxCurrentProfileKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tenaxCurrentProfileKeyKey);
    } catch (e) {
      print('SecureStorage: Error reading Tenax current profile key: $e');
      return null;
    }
  }

  /// Set the current active broker profile key (email+broker composite).
  static Future<void> setTenaxCurrentProfileKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenaxCurrentProfileKeyKey, key);
    } catch (e) {
      print('SecureStorage: Error setting Tenax current profile key: $e');
    }
  }
}
