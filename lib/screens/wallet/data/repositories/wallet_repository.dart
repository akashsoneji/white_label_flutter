import 'package:crm_app/core/network/api_response.dart';

abstract class WalletRepository {
  Future<ApiResponse> getWalletData({
    required String token,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getWalletDetailsNew({
    required String token,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> checkBalance({
    required String token,
    required Map<String, dynamic> payload,
  });

  Future<ApiResponse> sendOtp({
    required String token,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> internalTransfer({
    required String token,
    required Map<String, dynamic> payload,
  });
}

