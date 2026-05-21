import 'package:crm_app/models/google_otp_models.dart';
import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class LoginUser {
  final AuthRepository _repo;
  LoginUser(this._repo);

  Future<ApiResponse<LoginApiResult>> call({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceType,
  }) {
    return _repo.login(
      email: email,
      password: password,
      fcmToken: fcmToken,
      deviceType: deviceType,
    );
  }
}

