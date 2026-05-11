import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crm_app/models/user_model.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

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
}
