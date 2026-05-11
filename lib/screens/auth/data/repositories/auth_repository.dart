import 'package:crm_app/models/login_response_model.dart';
import 'package:crm_app/core/network/api_response.dart';

abstract class AuthRepository {
  Future<ApiResponse<LoginResponseModel>> login({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceType,
  });

  Future<ApiResponse<Map<String, dynamic>>> register({
    required Map<String, dynamic> data,
  });

  Future<ApiResponse<LoginResponseModel>> registerWithOTPVerification({
    required Map<String, dynamic> data,
  });

  Future<ApiResponse<Map<String, dynamic>>> sendOTP({required String email});

  Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

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

  Future<ApiResponse<Map<String, dynamic>>> forgotPassword({
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> logout({String? token});

  Future<ApiResponse> deleteAccount({
    required String token,
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> fetchProfile({String? token});

  Future<ApiResponse> updateProfileData({
    String? token,
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> registerFcmToken({
    String? token,
    required Map<String, dynamic> data,
  });
}

