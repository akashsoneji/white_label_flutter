import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class ResetPassword {
  final AuthRepository _repo;
  ResetPassword(this._repo);

  Future<ApiResponse<Map<String, dynamic>>> call({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _repo.resetPassword(email: email, otp: otp, newPassword: newPassword);
  }
}

