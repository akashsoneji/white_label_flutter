import 'package:crm_app/core/network/api_response.dart';

import '../repositories/auth_repository.dart';

class RegisterUser {
  final AuthRepository _repo;
  RegisterUser(this._repo);

  Future<ApiResponse<Map<String, dynamic>>> call({
    required Map<String, dynamic> data,
  }) {
    return _repo.register(data: data);
  }
}

