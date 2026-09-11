import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/google_otp_models.dart';
import 'package:crm_app/models/login_response_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:get/get.dart';

class GoogleOtpService extends GetxService {
  Map<String, dynamic>? _innerData(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  String _message(ApiResponse response, String fallback) {
    if (response.message?.isNotEmpty == true) return response.message!;
    if (response.data is Map<String, dynamic>) {
      final msg = (response.data as Map<String, dynamic>)['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return fallback;
  }

  Future<ApiResponse<GoogleOtpGenerateData>> generate() async {
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.googleOtpGenerate,
        data: {},
      );
      if (!response.success) {
        return ApiResponse.error(
          _message(response, TranslationUtils.tr('two_factor_generate_failed')),
        );
      }
      final data = _innerData(response.data);
      if (data == null) {
        return ApiResponse.error(
          TranslationUtils.tr('api_invalid_response_from_server'),
        );
      }
      return ApiResponse.success(GoogleOtpGenerateData.fromJson(data));
    } catch (e) {
      return ApiResponse.error('Failed to generate QR code: $e');
    }
  }

  Future<ApiResponse<GoogleOtpVerifyData>> verifySetup(String otpCode) async {
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.googleOtpVerify,
        data: {'otp_code': otpCode},
      );
      if (!response.success) {
        return ApiResponse.error(
          _message(response, TranslationUtils.tr('two_factor_verify_failed')),
        );
      }
      final data = _innerData(response.data);
      if (data == null) {
        return ApiResponse.error(
          TranslationUtils.tr('api_invalid_response_from_server'),
        );
      }
      return ApiResponse.success(GoogleOtpVerifyData.fromJson(data));
    } catch (e) {
      return ApiResponse.error('Failed to verify OTP: $e');
    }
  }

  Future<ApiResponse<GoogleOtpVerifyData>> disable(String otpCode) async {
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.googleOtpDisable,
        data: {'otp_code': otpCode},
      );
      if (!response.success) {
        return ApiResponse.error(
          _message(response, TranslationUtils.tr('two_factor_disable_failed')),
        );
      }
      final data = _innerData(response.data);
      if (data == null) {
        return ApiResponse.error(
          TranslationUtils.tr('api_invalid_response_from_server'),
        );
      }
      return ApiResponse.success(GoogleOtpVerifyData.fromJson(data));
    } catch (e) {
      return ApiResponse.error('Failed to disable OTP: $e');
    }
  }

  Future<ApiResponse<LoginResponseModel>> verifyLoginOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.googleOtpVerifyLogin,
        data: {'email': email, 'otp_code': otpCode},
        token: '',
      );
      if (!response.success) {
        return ApiResponse.error(
          _message(
            response,
            TranslationUtils.tr('two_factor_verify_login_failed'),
          ),
        );
      }
      if (response.data != null && response.data is Map<String, dynamic>) {
        final loginResponse = LoginResponseModel.fromJson(
          response.data as Map<String, dynamic>,
        );
        if (loginResponse.status == false) {
          return ApiResponse.error(
            loginResponse.message.isNotEmpty
                ? loginResponse.message
                : TranslationUtils.tr('auth_otp_verification_failed'),
          );
        }
        if (loginResponse.data.token.isEmpty) {
          return ApiResponse.error(
            TranslationUtils.tr('auth_invalid_login_response'),
          );
        }
        return ApiResponse.success(loginResponse);
      }
      return ApiResponse.error(
        TranslationUtils.tr('api_invalid_response_from_server'),
      );
    } catch (e) {
      return ApiResponse.error('Failed to verify login OTP: $e');
    }
  }
}
