import 'package:crm_app/models/user_model.dart';
import 'package:crm_app/services/secure_storage_service.dart';

/// Thin typed wrapper over SecureStorageService for session primitives.
/// Keeps existing storage behavior intact while giving features a clean interface.
class SessionStorage {
  Future<String?> getAuthToken() => SecureStorageService.getAuthToken();
  Future<void> saveAuthToken(String token) => SecureStorageService.saveAuthToken(token);

  Future<String?> getWebsocketToken() => SecureStorageService.getWebsocketToken();
  Future<void> saveWebsocketToken(String token) =>
      SecureStorageService.saveWebsocketToken(token);

  Future<UserModel?> getUser() => SecureStorageService.getUserData();

  Future<bool> isLoggedIn() => SecureStorageService.isUserLoggedIn();
  Future<void> setLoggedIn(bool value) => SecureStorageService.saveLoginStatus(value);

  Future<void> clearAuth() => SecureStorageService.clearAuthData();
}

