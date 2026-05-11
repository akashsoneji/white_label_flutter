import 'package:get/get.dart';

import 'biometric_service.dart';
import 'secure_storage_service.dart';

class AppLockService extends GetxService {
  final RxBool isLocked = false.obs;
  final RxBool isUnlocking = false.obs;
  final RxBool authUnavailable = false.obs;
  final RxBool lastUnlockFailed = false.obs;

  DateTime? _justAuthenticatedUntil;

  Future<void> lockIfNeeded({required String reason}) async {
    if (_isWithinGraceWindow()) {
      return;
    }

    final enabled = await SecureStorageService.getBiometricEnabled();
    if (!enabled) {
      clearLock();
      return;
    }

    final sessionValid = await SecureStorageService.isUserLoggedIn();
    if (!sessionValid) {
      clearLock();
      return;
    }

    isLocked.value = true;
    authUnavailable.value = false;
    lastUnlockFailed.value = false;
  }

  Future<bool> unlock({required String reason}) async {
    if (isUnlocking.value) return false;

    isUnlocking.value = true;
    authUnavailable.value = false;
    lastUnlockFailed.value = false;

    try {
      final supported = await BiometricService.instance.isDeviceSupported();
      if (!supported) {
        authUnavailable.value = true;
        return false;
      }

      final ok = await BiometricService.instance.authenticate(reason: reason);
      if (ok) {
        isLocked.value = false;
        markJustAuthenticated();
        return true;
      }

      lastUnlockFailed.value = true;
      return false;
    } finally {
      isUnlocking.value = false;
    }
  }

  Future<void> disableAppLock() async {
    await SecureStorageService.setBiometricEnabled(false);
    clearLock();
  }

  void clearLock() {
    isLocked.value = false;
    isUnlocking.value = false;
    authUnavailable.value = false;
    lastUnlockFailed.value = false;
  }

  void markJustAuthenticated({Duration window = const Duration(seconds: 2)}) {
    _justAuthenticatedUntil = DateTime.now().add(window);
  }

  bool _isWithinGraceWindow() {
    final until = _justAuthenticatedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }
}

