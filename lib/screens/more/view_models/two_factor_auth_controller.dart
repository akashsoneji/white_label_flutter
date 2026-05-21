import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/models/google_otp_models.dart';
import 'package:crm_app/services/google_otp_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:get/get.dart';

enum TwoFactorAuthUiState { disabled, setup, enabled, disabling }

class TwoFactorAuthController extends GetxController {
  final GoogleOtpService _googleOtpService = Get.find<GoogleOtpService>();
  final AuthController _authController = Get.find<AuthController>();
  final LanguageService _languageService = Get.find<LanguageService>();

  final _isLoading = false.obs;
  final _uiState = TwoFactorAuthUiState.disabled.obs;
  final _generateData = Rxn<GoogleOtpGenerateData>();
  final _otpCode = ''.obs;

  bool get isLoading => _isLoading.value;
  TwoFactorAuthUiState get uiState => _uiState.value;
  GoogleOtpGenerateData? get generateData => _generateData.value;
  String get otpCode => _otpCode.value;
  bool get isOtpComplete => _otpCode.value.length == 6;

  @override
  void onInit() {
    super.onInit();
    _syncEnabledState();
  }

  void _syncEnabledState() {
    if (_authController.isGoogleOtpEnabled) {
      _uiState.value = TwoFactorAuthUiState.enabled;
    } else {
      _uiState.value = TwoFactorAuthUiState.disabled;
    }
  }

  void onOtpChanged(String code) {
    _otpCode.value = code;
  }

  Future<void> generateQr() async {
    try {
      _setLoading(true);
      final response = await _googleOtpService.generate();
      if (response.success && response.data != null) {
        _generateData.value = response.data;
        _otpCode.value = '';
        _uiState.value = TwoFactorAuthUiState.setup;
      } else {
        _showError(
          response.message ??
              _languageService.tr('two_factor_generate_failed'),
        );
      }
    } catch (e) {
      _showError(
        '${_languageService.tr('two_factor_generate_failed')}: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifySetup() async {
    if (!isOtpComplete) return;
    try {
      _setLoading(true);
      final response = await _googleOtpService.verifySetup(_otpCode.value);
      if (response.success) {
        await _authController.updateGoogleOtpEnabled(true);
        _generateData.value = null;
        _otpCode.value = '';
        _uiState.value = TwoFactorAuthUiState.enabled;
        _showSuccess(
          response.message ??
              _languageService.tr('two_factor_enabled_success'),
        );
      } else {
        _showError(
          response.message ??
              _languageService.tr('two_factor_verify_failed'),
        );
      }
    } catch (e) {
      _showError(
        '${_languageService.tr('two_factor_verify_failed')}: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  void startDisable() {
    _otpCode.value = '';
    _uiState.value = TwoFactorAuthUiState.disabling;
  }

  void cancelDisable() {
    _otpCode.value = '';
    _uiState.value = TwoFactorAuthUiState.enabled;
  }

  void cancelSetup() {
    _generateData.value = null;
    _otpCode.value = '';
    _uiState.value = TwoFactorAuthUiState.disabled;
  }

  Future<void> disable() async {
    if (!isOtpComplete) return;
    try {
      _setLoading(true);
      final response = await _googleOtpService.disable(_otpCode.value);
      if (response.success) {
        await _authController.updateGoogleOtpEnabled(false);
        _generateData.value = null;
        _otpCode.value = '';
        _uiState.value = TwoFactorAuthUiState.disabled;
        _showSuccess(
          response.message ??
              _languageService.tr('two_factor_disabled_success'),
        );
      } else {
        _showError(
          response.message ??
              _languageService.tr('two_factor_disable_failed'),
        );
      }
    } catch (e) {
      _showError(
        '${_languageService.tr('two_factor_disable_failed')}: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) => _isLoading.value = value;

  void _showError(String message) {
    CustomToastService.showError(
      title: _languageService.tr('general_error'),
      message: message,
      position: SnackPosition.TOP,
    );
  }

  void _showSuccess(String message) {
    CustomToastService.showSuccess(
      title: _languageService.tr('success'),
      message: message,
      position: SnackPosition.TOP,
    );
  }
}