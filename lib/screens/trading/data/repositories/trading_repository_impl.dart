import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

import 'trading_repository.dart';

class TradingRepositoryImpl implements TradingRepository {
  final ApiClient _api;
  TradingRepositoryImpl(this._api);

  @override
  Future<ApiResponse> closePositionByPositionId({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.closePositionByPositionId,
      token: token,
      data: data,
    );
  }

  @override
  Future<ApiResponse> updateTPSL({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.updateTPSL,
      token: token,
      data: data,
    );
  }

  @override
  Future<ApiResponse> closePendingOrder({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.closePendingOrder,
      token: token,
      data: data,
    );
  }

  @override
  Future<ApiResponse> getTradeHistory({
    String? token,
    required Map<String, dynamic> queryParameters,
  }) {
    return _api.get(
      endpoint: ApiConstants.tradeHistory,
      token: token,
      queryParameters: queryParameters,
    );
  }

  @override
  Future<ApiResponse> placeOrder({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.placeOrder,
      token: token,
      data: data,
    );
  }
}
