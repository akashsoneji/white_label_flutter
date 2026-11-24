import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/screens/trading_central/trading_central_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/utils/app_logger.dart';

class TradingCentralService {
  const TradingCentralService._();

  /// Throws with the API message when the request fails, so the screen can
  /// show it next to a retry button.
  static Future<TradingCentralSettings> fetch() async {
    final response = await ApiService.get(endpoint: ApiConstants.tradingCentral);
    final payload = extractPayload(response.data);
    if (!response.success || payload == null) {
      AppLogger.error('TradingCentralService: Failed - ${response.message}');
      throw Exception(response.message);
    }
    return TradingCentralSettings.fromJson(payload);
  }

  /// Accepts either the full body (`{status, data: {...}}`) or the inner
  /// `data` object, whichever ApiResponse hands back.
  static Map<String, dynamic>? extractPayload(dynamic raw) {
    if (raw is! Map) return null;
    final inner = raw['data'];
    if (inner is Map && !raw.containsKey('pages')) {
      return Map<String, dynamic>.from(inner);
    }
    return Map<String, dynamic>.from(raw);
  }
}
