import 'package:get/get.dart';

import 'biometric_service.dart';
import 'secure_storage_service.dart';

class AppLockService extends GetxService {
  final RxBool isLocked = false.obs;
  final RxBool isUnlocking = false.obs;
  final RxBool authUnavailable = false.obs;
  final RxBool lastUnlockFailed = false.obs;

  DateTime? _lastUnlockAttemptAt;
  DateTime? _lastSuccessfulUnlockAt;
  DateTime? _lastAuthUiAt;
  DateTime? _pausedAt;
  static const Duration _resumeGrace = Duration(milliseconds: 1800);

  void markPaused() {
    _pausedAt = DateTime.now();
  }

  /// Lock only when:
  /// - biometric enabled in app, AND
  /// - user session exists (token + logged-in status).
  Future<void> lockIfNeeded({required String reason}) async {
    // If the app was paused/inactive and returned in less than 15 seconds, don't lock.
    // This prevents locking on brief focus loss (e.g. permission prompts, native dialogs, Face ID sheets).
    if (_pausedAt != null &&
        DateTime.now().difference(_pausedAt!) < const Duration(seconds: 15)) {
      _pausedAt = null;
      return;
    }
    _pausedAt = null;

    // If we are currently showing auth UI (or just returned), don't immediately re-lock.
    if (_lastAuthUiAt != null &&
        DateTime.now().difference(_lastAuthUiAt!) < _resumeGrace) {
      return;
    }
    if (_lastSuccessfulUnlockAt != null &&
        DateTime.now().difference(_lastSuccessfulUnlockAt!) < _resumeGrace) {
      return;
    }
    if (isUnlocking.value) return;

    final enabled = await SecureStorageService.getBiometricEnabled();
    if (!enabled) {
      isLocked.value = false;
      authUnavailable.value = false;
      lastUnlockFailed.value = false;
      return;
    }

    final token = await SecureStorageService.getAuthToken();
    final loggedIn = await SecureStorageService.getLoginStatus();
    if (token == null || token.isEmpty || !loggedIn) {
      isLocked.value = false;
      authUnavailable.value = false;
      lastUnlockFailed.value = false;
      return;
    }

    // Lock. We will attempt device authentication (biometric OR device credential)
    // during unlock. If the device cannot authenticate, we'll show a full-screen
    // recovery UI (Open Settings / Disable AppLock).
    isLocked.value = true;
    authUnavailable.value = false;
    lastUnlockFailed.value = false;
  }

  /// Unlock with biometric OR device credential fallback.
  /// Returns true if unlocked.
  Future<bool> unlock({required String reason}) async {
    if (isUnlocking.value) return false;
    if (!isLocked.value) return true;

    // Simple debounce: if user cancels repeatedly, don't auto-loop.
    final now = DateTime.now();
    if (_lastUnlockAttemptAt != null &&
        now.difference(_lastUnlockAttemptAt!).inMilliseconds < 600) {
      return false;
    }
    _lastUnlockAttemptAt = now;
    _lastAuthUiAt = now;

    isUnlocking.value = true;
    try {
      lastUnlockFailed.value = false;
      final enabled = await SecureStorageService.getBiometricEnabled();
      if (!enabled) {
        isLocked.value = false;
        authUnavailable.value = false;
        lastUnlockFailed.value = false;
        return true;
      }

      final supported = await BiometricService.instance.isDeviceSupported();
      if (!supported) {
        authUnavailable.value = true;
        lastUnlockFailed.value = true;
        return false;
      }

      final ok = await BiometricService.instance.authenticate(reason: reason);
      if (ok) {
        isLocked.value = false;
        authUnavailable.value = false;
        _lastSuccessfulUnlockAt = DateTime.now();
        lastUnlockFailed.value = false;
      }
      if (!ok) {
        lastUnlockFailed.value = true;
      }
      return ok;
    } finally {
      isUnlocking.value = false;
    }
  }

  Future<void> disableAppLock() async {
    await SecureStorageService.setBiometricEnabled(false);
    authUnavailable.value = false;
    lastUnlockFailed.value = false;
    isLocked.value = false;
  }

  Future<void> clearLock() async {
    isLocked.value = false;
    isUnlocking.value = false;
    authUnavailable.value = false;
    lastUnlockFailed.value = false;
  }

  /// Call after successful device auth used to **enable** biometrics (settings / login / registration).
  /// Prevents an immediate second prompt when the biometric sheet dismisses and the app
  /// lifecycle fires `resumed` → [lockIfNeeded] / [AppLockOverlay].
  void markJustAuthenticated() {
    final now = DateTime.now();
    _lastAuthUiAt = now;
    _lastSuccessfulUnlockAt = now;
    _lastUnlockAttemptAt = now;
    isLocked.value = false;
    authUnavailable.value = false;
    lastUnlockFailed.value = false;
  }
}