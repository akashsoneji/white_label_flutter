import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class ForgotPassword {
  final AuthRepository _repo;
  ForgotPassword(this._repo);

  Future<ApiResponse<Map<String, dynamic>>> call({
    required Map<String, dynamic> data,
  }) {
    return _repo.forgotPassword(data: data);
  }
}

