import 'package:crm_app/models/login_response_model.dart';
import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class RegisterWithOtpVerification {
  final AuthRepository _repo;
  RegisterWithOtpVerification(this._repo);

  Future<ApiResponse<LoginResponseModel>> call({
    required Map<String, dynamic> data,
  }) {
    return _repo.registerWithOTPVerification(data: data);
  }
}

