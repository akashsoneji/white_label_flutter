import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/services/auth_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';

class ChangePasswordController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  // Observable states
  final _isLoading = false.obs;
  final _errorMessage = ''.obs;
  final _successMessage = ''.obs;

  // Getters
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  String get successMessage => _successMessage.value;

  // Text editing controllers
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  /// ✅ Main function to change user password
  Future<void> changePassword() async {
    try {
      _setLoading(true);
      _clearError();

      print('🔐 Changing user password...');

      // Call new user password change API
      final response = await _authService.changeUserPassword(
        currentPassword: currentPasswordController.text.trim(),
        password: newPasswordController.text.trim(),
        passwordConfirmation: confirmPasswordController.text.trim(),
      );

      print('🔐 Response: $response');
      if (response.success) {
        final message =
            response.data?['message'] ??
            TranslationUtils.tr('change_password_controller_password_changed_login_again');
        _setSuccess(message);

        // Check if re-login is required
        final requiresRelogin = response.data?['requires_relogin'] ?? true;

        if (requiresRelogin) {
          // Clear all auth data and navigate to login
          await _clearAllDataAndNavigateToLogin();
        }
      } else {
        _setError(response.message ?? TranslationUtils.tr('change_password_controller_failed_to_change_password'));
      }
    } catch (e) {
      _setError('${TranslationUtils.tr('change_password_controller_error_changing_password')}: $e');
      if (kDebugMode) print('ChangePasswordController: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Clear all data and navigate to login screen
  Future<void> _clearAllDataAndNavigateToLogin() async {
    try {
      // Clear secure storage
      await SecureStorageService.clearAuthData();

      // Clear Instruments Controller WebSocket
      try {
        if (Get.isRegistered<InstrumentsController>()) {
          final instrumentsController = Get.find<InstrumentsController>();
          instrumentsController.disconnectWebSocket();
          print('ChangePasswordController: Instruments socket disconnected');
        }
      } catch (e) {
        print(
          'ChangePasswordController: Error disconnecting Instruments socket: $e',
        );
      }

      // Clear Chart Socket Controller WebSocket
      try {
        if (Get.isRegistered<ChartSocketController>()) {
          final chartSocketController = Get.find<ChartSocketController>();
          chartSocketController.resetController();
          print('ChangePasswordController: Chart socket disconnected');
        }
      } catch (e) {
        print('ChangePasswordController: Error disconnecting Chart socket: $e');
      }

      // Navigate to login screen
      Get.offAllNamed(AppPages.LOGIN);
    } catch (e) {
      print('ChangePasswordController: Error clearing data: $e');
      // Still navigate to login even if clearing fails
      Get.offAllNamed(AppPages.LOGIN);
    }
  }

  /// Internal helpers
  void _setLoading(bool value) => _isLoading.value = value;

  void _setError(String message) {
    _errorMessage.value = message;
    if (message.isNotEmpty) {
      CustomToastService.showError(message: message);
    }
  }

  void _setSuccess(String message) {
    _successMessage.value = message;
    if (message.isNotEmpty) {
      CustomToastService.showSuccess(
        message: message,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _clearError() => _errorMessage.value = '';

  void clearMessages() {
    _errorMessage.value = '';
    _successMessage.value = '';
  }

  @override
  void onClose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
