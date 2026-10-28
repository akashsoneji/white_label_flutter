import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/models/google_otp_models.dart';
import 'package:crm_app/models/login_response_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'dart:developer' as dev;

abstract class AuthService extends GetxService {
  Future<ApiResponse<LoginApiResult>> login({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceType,
  });

  // Password reset OTP flow methods
  Future<ApiResponse<Map<String, dynamic>>> requestPasswordResetOTP({
    required String email,
  });

  Future<ApiResponse<Map<String, dynamic>>> verifyPasswordResetOTP({
    required String email,
    required String otp,
  });

  Future<ApiResponse<Map<String, dynamic>>> resetPasswordWithOTP({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  });

  Future<ApiResponse<Map<String, dynamic>>> changePassword({
    required String mt5Account,
    required String newPassword,
  });

  Future<ApiResponse<Map<String, dynamic>>> resetInvestorPassword({
    required String mt5Account,
    required String newPassword,
  });

  Future<ApiResponse<Map<String, dynamic>>> changeLeverage({
    required String mt5Account,
    required int leverage,
  });

  Future<ApiResponse<Map<String, dynamic>>> changeUserPassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  });

  Future<ApiResponse<Map<String, dynamic>>> register({
    required Map<String, dynamic> data,
  });

  Future<ApiResponse<LoginResponseModel>> registerWithOTPVerification({
    required Map<String, dynamic> data,
  });
}

class AuthServiceImpl extends AuthService {
  final ApiClient _api;
  AuthServiceImpl(this._api);

  // ==================== LOGIN ====================
  @override
  Future<ApiResponse<LoginApiResult>> login({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceType,
  }) async {
    try {
      // Check network connectivity before attempting login
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return ApiResponse.error(
          TranslationUtils.tr('auth_no_internet_connection'),
        );
      }

      final data = {
        'email': email,
        'password': password,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (deviceType != null) 'device_type': deviceType,
      };

      final response = await _api.post(
        endpoint: ApiConstants.login,
        data: data,
      );

      // Log the response for debugging
      print('🔍 AuthService.login() - Response received:');
      print('   success: ${response.success}');
      print('   message: ${response.message}');
      print('   data type: ${response.data?.runtimeType}');
      print('   data: ${response.data}');

      // PRIORITY 1: If response failed, ALWAYS return error message from API
      if (!response.success) {
        final errorMessage =
            response.message?.isNotEmpty == true
                ? response.message!
                : TranslationUtils.tr('auth_login_failed_credentials');
        print(
          '⚠️ AuthService: Login failed - Returning error message: $errorMessage',
        );
        return ApiResponse.error(errorMessage);
      }

      // PRIORITY 2: Check if response.data is a valid Map for parsing LoginResponseModel
      if (response.data != null && response.data is Map<String, dynamic>) {
        try {
          final loginResponse = LoginResponseModel.fromJson(response.data);

          // Check if the login response itself indicates failure
          if (loginResponse.status == false) {
            final errorMessage =
                loginResponse.message.isNotEmpty
                    ? loginResponse.message
                    : TranslationUtils.tr('auth_login_failed_credentials');
            print(
              '⚠️ AuthService: LoginResponse status is false, message: $errorMessage',
            );
            return ApiResponse.error(errorMessage);
          }

          final envelope = response.data as Map<String, dynamic>;
          final envelopeData = envelope['data'];
          if (envelopeData is Map<String, dynamic> &&
              envelopeData['requires_google_otp'] == true) {
            return ApiResponse(
              success: true,
              message: loginResponse.message,
              data: LoginApiResult.fromGoogleOtpChallenge(
                GoogleOtpLoginChallenge.fromJson(envelopeData),
              ),
            );
          }

          if (loginResponse.data.token.isEmpty) {
            return ApiResponse.error(
              loginResponse.message.isNotEmpty
                  ? loginResponse.message
                  : TranslationUtils.tr('auth_login_failed_credentials'),
            );
          }

          print('✅ AuthService: Login successful');
          return ApiResponse.success(
            LoginApiResult.fromLoginResponse(loginResponse),
          );
        } catch (e, t) {
          print("❌ AuthService login parsing error: ${e.toString()}");
          print("❌ AuthService login parsing stacktrace: ${t.toString()}");
          return ApiResponse.error('Failed to parse login response: $e');
        }
      } else {
        // If data is null or not a map, but response.success is true,
        // this is unexpected - return a generic error
        final errorMessage =
            response.message?.isNotEmpty == true
                ? response.message!
                : TranslationUtils.tr('auth_login_invalid_response_format');
        print(
          '⚠️ AuthService: Data is not a valid Map, returning error: $errorMessage',
        );
        return ApiResponse.error(errorMessage);
      }
    } catch (e, t) {
      print("AuthService login network error: ${e.toString()}");
      print("AuthService login network stacktrace: ${t.toString()}");
      return ApiResponse.error('Network error during login: $e');
    }
  }

  // ==================== PASSWORD RESET OTP FLOW ====================
  @override
  Future<ApiResponse<Map<String, dynamic>>> requestPasswordResetOTP({
    required String email,
  }) async {
    try {
      final data = {'email': email};

      final response = await _api.post(
        endpoint: ApiConstants.requestPasswordResetOTP,
        data: data,
      );

      if (response.success && response.data != null) {
        return ApiResponse.success(response.data);
      } else {
        return ApiResponse.error(
          response.message ?? response.data?['message'] ?? 'Failed to send OTP',
        );
      }
    } catch (e) {
      print("AuthService requestPasswordResetOTP error: ${e.toString()}");
      return ApiResponse.error('Network error: $e');
    }
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final data = {'email': email, 'otp': otp};

      final response = await _api.post(
        endpoint: ApiConstants.verifyPasswordResetOTP,
        data: data,
      );

      if (response.success && response.data != null) {
        return ApiResponse.success(response.data);
      } else {
        return ApiResponse.error(
          response.message ??
              response.data?['message'] ??
              TranslationUtils.tr('auth_otp_verification_failed'),
        );
      }
    } catch (e) {
      print("AuthService verifyPasswordResetOTP error: ${e.toString()}");
      return ApiResponse.error('Network error: $e');
    }
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> resetPasswordWithOTP({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final data = {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };

      final response = await _api.post(
        endpoint: ApiConstants.resetPasswordWithOTP,
        data: data,
      );

      if (response.success && response.data != null) {
        return ApiResponse.success(response.data);
      } else {
        return ApiResponse.error(
          response.message ??
              response.data?['message'] ??
              TranslationUtils.tr('auth_controller_password_reset_failed'),
        );
      }
    } catch (e) {
      print("AuthService resetPasswordWithOTP error: ${e.toString()}");
      return ApiResponse.error('Network error: $e');
    }
  }

  // ==================== CHANGE PASSWORD ====================
  @override
  Future<ApiResponse<Map<String, dynamic>>> changePassword({
    required String mt5Account,
    required String newPassword,
  }) async {
    try {
      final data = {
        'meta_account_number': mt5Account,
        'newPassword': newPassword,
      };

      final response = await _api.post(
        endpoint: ApiConstants.changePassword,
        data: data,
      );

      if (response.success && response.data != null) {
        return ApiResponse.success(response.data);
      } else {
        return ApiResponse.error(
          response.data?['message'] ?? 'Change password failed',
        );
      }
    } catch (e) {
      print("AuthService changePassword error: ${e.toString()}");
      return ApiResponse.error('Network error: $e');
    }
  }

  // ==================== RESET INVESTOR PASSWORD ====================
  @override
  Future<ApiResponse<Map<String, dynamic>>> resetInvestorPassword({
    required String mt5Account,
    required String newPassword,
  }) async {
    try {
      final data = {
        'meta_account_number': mt5Account,
        'newPassword': newPassword,
      };

      final response = await _api.post(
        endpoint: ApiConstants.resetInvestorPassword,
        data: data,
      );

      if (response.success && response.data != null) {
        return ApiResponse.success(response.data);
      } else {
        return ApiResponse.error(
          response.data?['message'] ?? 'Reset investor password failed',
        );
      }
    } catch (e) {
      print("AuthService resetInvestorPassword error: ${e.toString()}");
      return ApiResponse.error('Network error: $e');
    }
  }

  // ==================== CHANGE LEVERAGE ====================
  @override
  Future<ApiResponse<Map<String, dynamic>>> changeLeverage({
    required String mt5Account,
    required int leverage,
  }) async {
    try {
      final data = {'mt5_account': mt5Account, 'leverage': leverage};

      final response = await _api.post(
        endpoint: ApiConstants.changeLeverage,
        data: data,
      );

      if (response.success && response.data != null) {
        return ApiResponse.success(response.data);
      } else {
        return ApiResponse.error(
          response.data?['message'] ?? 'Change leverage failed',
        );
      }
    } catch (e) {
      print("AuthService changeLeverage error: ${e.toString()}");
      return ApiResponse.error('Network error: $e');
    }
  }

  // ==================== CHANGE USER PASSWORD ====================
  @override
  Future<ApiResponse<Map<String, dynamic>>> changeUserPassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final data = {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };

      final response = await _api.post(
        endpoint: ApiConstants.changeUserPassword,
        data: data,
      );

      if (response.success && response.data != null) {
        return ApiResponse.success(response.data);
      } else {
        // Handle validation errors
        final errorData = response.data;
        String errorMessage =
            response.message ??
            TranslationUtils.tr('auth_change_password_failed');

        if (errorData is Map<String, dynamic> &&
            errorData.containsKey('errors')) {
          final errors = errorData['errors'] as Map<String, dynamic>?;
          if (errors != null && errors.isNotEmpty) {
            // Get first error message
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              errorMessage = firstError.first.toString();
            } else if (firstError is String) {
              errorMessage = firstError;
            }
          }
        }

        return ApiResponse.error(errorMessage, data: errorData);
      }
    } catch (e) {
      print("AuthService changeUserPassword error: ${e.toString()}");
      return ApiResponse.error('Network error: $e');
    }
  }

  // Helper function to extract and format validation errors from API response
  String _formatValidationErrors(dynamic errorData) {
    if (errorData == null) return '';

    if (errorData is Map<String, dynamic>) {
      final List<String> errorMessages = [];

      errorData.forEach((field, errors) {
        if (errors is List) {
          for (var error in errors) {
            // Capitalize field name and add error message
            final fieldName = field
                .replaceAll('_', ' ')
                .split(' ')
                .map((word) {
                  return word.isEmpty
                      ? word
                      : word[0].toUpperCase() + word.substring(1);
                })
                .join(' ');
            errorMessages.add('$fieldName: $error');
          }
        } else if (errors is String) {
          final fieldName = field
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) {
                return word.isEmpty
                    ? word
                    : word[0].toUpperCase() + word.substring(1);
              })
              .join(' ');
          errorMessages.add('$fieldName: $errors');
        }
      });

      if (errorMessages.isNotEmpty) {
        return errorMessages.join('\n');
      }
    }

    return '';
  }

  /// Fields the backend expects on every `user/register` call (both the
  /// `register` and `verifyOtp` steps), added here so all brand screens send them.
  Map<String, dynamic> _withRegisterMeta(Map<String, dynamic> data) {
    return {
      ...data,
      'device_type': Platform.isIOS ? 'ios' : 'android',
      'utm_source': 'app',
    };
  }

  // ==================== REGISTER ====================
  @override
  Future<ApiResponse<Map<String, dynamic>>> register({
    required Map<String, dynamic> data,
  }) async {
    try {
      // Check network connectivity before attempting registration
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return ApiResponse.error(
          TranslationUtils.tr('auth_no_internet_connection'),
        );
      }

      final response = await _api.post(
        endpoint: ApiConstants.register,
        data: _withRegisterMeta(data),
      );

      // If response failed, check for validation errors in data
      if (!response.success) {
        String errorMessage =
            response.message ?? TranslationUtils.tr('auth_registration_failed');

        // Check if there are validation errors in response.data
        if (response.data != null) {
          final validationErrors = _formatValidationErrors(response.data);
          if (validationErrors.isNotEmpty) {
            errorMessage = validationErrors;
          }
        }

        return ApiResponse.error(errorMessage, data: response.data);
      }

      if (response.success && response.data != null) {
        return ApiResponse.success(response.data);
      } else {
        // If data is null or not a map, return error message from API
        final errorMessage =
            response.message ??
            TranslationUtils.tr('auth_registration_invalid_response');
        return ApiResponse.error(errorMessage);
      }
    } catch (e, t) {
      print("AuthService register network error: ${e.toString()}");
      print("AuthService register network stacktrace: ${t.toString()}");
      return ApiResponse.error('Network error during registration: $e');
    }
  }

  // ==================== REGISTER With OTP Verification ====================
  @override
  Future<ApiResponse<LoginResponseModel>> registerWithOTPVerification({
    required Map<String, dynamic> data,
  }) async {
    try {
      // Check network connectivity before attempting registration
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return ApiResponse.error(
          TranslationUtils.tr('auth_no_internet_connection'),
        );
      }

      final response = await _api.post(
        endpoint: ApiConstants.register,
        data: _withRegisterMeta(data),
      );

      // If response failed, check for validation errors in data
      if (!response.success) {
        String errorMessage =
            response.message ?? TranslationUtils.tr('auth_registration_failed');

        // Check if there are validation errors in response.data
        if (response.data != null) {
          final validationErrors = _formatValidationErrors(response.data);
          if (validationErrors.isNotEmpty) {
            errorMessage = validationErrors;
          }
        }

        return ApiResponse.error(errorMessage, data: response.data);
      }

      // Check if response.data is a valid Map
      if (response.data != null && response.data is Map<String, dynamic>) {
        print(
          "AuthService registerWithOTPVerification raw response: ${response.data}",
        );
        try {
          final loginResponse = LoginResponseModel.fromJson(response.data);
          print("AuthService registerWithOTPVerification parsed successfully");

          // Check if the API response indicates failure
          if (!loginResponse.status) {
            return ApiResponse.error(loginResponse.message);
          }

          return ApiResponse.success(loginResponse);
        } catch (e, t) {
          print(
            "AuthService registerWithOTPVerification parsing error: ${e.toString()}",
          );
          print(
            "AuthService registerWithOTPVerification response data: ${response.data}",
          );
          dev.log(
            "AuthService registerWithOTPVerification parsing stacktrace: ${t.toString()}",
          );
          return ApiResponse.error('Failed to parse registration response: $e');
        }
      } else {
        // If data is null or not a map, return error message from API
        print(
          "AuthService registerWithOTPVerification failed: ${response.message}",
        );
        final errorMessage =
            response.message ??
            TranslationUtils.tr('auth_registration_invalid_response');
        return ApiResponse.error(errorMessage);
      }
    } catch (e, t) {
      print(
        "AuthService registerWithOTPVerification network error: ${e.toString()}",
      );
      dev.log(
        "AuthService registerWithOTPVerification network stacktrace: ${t.toString()}",
      );
      return ApiResponse.error('Network error during registration: $e');
    }
  }
}
