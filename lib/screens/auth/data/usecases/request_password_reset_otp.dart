import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class RequestPasswordResetOtp {
  final AuthRepository _repo;
  RequestPasswordResetOtp(this._repo);

  Future<ApiResponse<Map<String, dynamic>>> call({required String email}) {
    return _repo.requestPasswordResetOTP(email: email);
  }
}

