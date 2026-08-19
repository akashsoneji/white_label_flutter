import 'package:crm_app/models/google_otp_models.dart';
import 'package:crm_app/models/login_response_model.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/auth_service.dart';

import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _service;
  final ApiClient _api;

  AuthRepositoryImpl(this._service, this._api);

  @override
  Future<ApiResponse<LoginApiResult>> login({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceType,
  }) {
    return _service.login(
      email: email,
      password: password,
      fcmToken: fcmToken,
      deviceType: deviceType,
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> register({
    required Map<String, dynamic> data,
  }) {
    return _service.register(data: data);
  }

  @override
  Future<ApiResponse<LoginResponseModel>> registerWithOTPVerification({
    required Map<String, dynamic> data,
  }) {
    return _service.registerWithOTPVerification(data: data);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> sendOTP({required String email}) {
    return _service.sendOTP(email: email);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _service.resetPassword(email: email, otp: otp, newPassword: newPassword);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> requestPasswordResetOTP({
    required String email,
  }) {
    return _service.requestPasswordResetOTP(email: email);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) {
    return _service.verifyPasswordResetOTP(email: email, otp: otp);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> resetPasswordWithOTP({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) {
    return _service.resetPasswordWithOTP(
      email: email,
      otp: otp,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> forgotPassword({
    required Map<String, dynamic> data,
  }) async {
    final response = await _api.post(
      endpoint: ApiConstants.forgotPassword,
      data: data,
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      return ApiResponse.success(payload);
    }

    return ApiResponse.error(
      response.message ?? 'Invalid response',
      data: payload is Map<String, dynamic> ? payload : null,
    );
  }

  @override
  Future<ApiResponse> logout({String? token, String? fcmToken}) {
    final data = fcmToken != null ? {'fcm_token': fcmToken} : null;
    return _api.post(endpoint: ApiConstants.logout, token: token, data: data);
  }

  @override
  Future<ApiResponse> deleteAccount({
    required String token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.deleteAccount,
      token: token,
      data: data,
    );
  }

  @override
  Future<ApiResponse> fetchProfile({String? token}) {
    return _api.get(endpoint: ApiConstants.profile, token: token);
  }

  @override
  Future<ApiResponse> updateProfileData({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.profile,
      token: token,
      data: data,
    );
  }

  @override
  Future<ApiResponse> registerFcmToken({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.registerFcmToken,
      token: token,
      data: data,
    );
  }
}

