import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class SendOtp {
  final AuthRepository _repo;
  SendOtp(this._repo);

  Future<ApiResponse<Map<String, dynamic>>> call({required String email}) {
    return _repo.sendOTP(email: email);
  }
}

