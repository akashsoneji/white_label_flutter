import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

import 'profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _api;
  ProfileRepositoryImpl(this._api);

  @override
  Future<ApiResponse> getDashboard({required String token}) {
    return _api.get(endpoint: ApiConstants.dashboard, token: token);
  }

  @override
  Future<ApiResponse> updateProfile({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(endpoint: ApiConstants.profile, token: token, data: payload);
  }
}

