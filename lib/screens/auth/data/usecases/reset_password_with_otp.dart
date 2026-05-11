import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class ResetPasswordWithOtp {
  final AuthRepository _repo;
  ResetPasswordWithOtp(this._repo);

  Future<ApiResponse<Map<String, dynamic>>> call({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) {
    return _repo.resetPasswordWithOTP(
      email: email,
      otp: otp,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }
}

