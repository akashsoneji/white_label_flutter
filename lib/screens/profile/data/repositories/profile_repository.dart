import 'package:crm_app/core/network/api_response.dart';

abstract class ProfileRepository {
  Future<ApiResponse> getDashboard({required String token});

  Future<ApiResponse> updateProfile({
    required String token,
    required Map<String, dynamic> payload,
  });
}

