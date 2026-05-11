import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class VerifyPasswordResetOtp {
  final AuthRepository _repo;
  VerifyPasswordResetOtp(this._repo);

  Future<ApiResponse<Map<String, dynamic>>> call({
    required String email,
    required String otp,
  }) {
    return _repo.verifyPasswordResetOTP(email: email, otp: otp);
  }
}

