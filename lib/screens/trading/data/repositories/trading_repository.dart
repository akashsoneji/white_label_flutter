import 'package:crm_app/core/network/api_response.dart';

abstract class TradingRepository {
  Future<ApiResponse> closePositionByPositionId({
    String? token,
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> updateTPSL({
    String? token,
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> updatePendingOrderTPSL({
    String? token,
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> closePendingOrder({
    String? token,
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> getTradeHistory({
    String? token,
    required Map<String, dynamic> queryParameters,
  });

  Future<ApiResponse> placeOrder({
    String? token,
    required Map<String, dynamic> data,
  });
}
