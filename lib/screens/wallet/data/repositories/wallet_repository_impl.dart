import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

import 'wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final ApiClient _api;
  WalletRepositoryImpl(this._api);

  @override
  Future<ApiResponse> getWalletData({
    required String token,
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: ApiConstants.getWalletData,
      token: token,
      queryParameters: queryParameters,
    );
  }

  @override
  Future<ApiResponse> checkBalance({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(
      endpoint: ApiConstants.checkBalance,
      token: token,
      data: payload,
    );
  }

  @override
  Future<ApiResponse> sendOtp({
    required String token,
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: ApiConstants.withdrawalSendOTPRequest,
      token: token,
      queryParameters: queryParameters,
    );
  }

  @override
  Future<ApiResponse> internalTransfer({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(
      endpoint: ApiConstants.internalTransferRequest,
      token: token,
      data: payload,
    );
  }
}

