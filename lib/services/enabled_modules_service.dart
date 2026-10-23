import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/enabled_modules_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/utils/app_logger.dart';

/// Fetches which optional modules are enabled for the current user.
class EnabledModulesService extends GetxService {
  final Rxn<EnabledModulesModel> modules = Rxn<EnabledModulesModel>();
  final RxBool isLoading = false.obs;

  EnabledModulesModel get current => modules.value ?? EnabledModulesModel.empty;

  bool get isPmamEnabled => current.pmam;
  bool get isCopyTradingEnabled => current.copytrading;
  bool get isScratchCardEnabled => current.scratchcard;
  bool get isTradeWinEnabled => current.tradewin;
  bool get isIbmReportsEnabled => current.ibmReports;

  /// Promotional entry when at least one in-app promotional module is on.
  bool get isPromotionalMenuVisible => true;

  Future<EnabledModulesModel?> fetchEnabledModules({bool force = false}) async {
    if (!force && modules.value != null) {
      return modules.value;
    }

    try {
      isLoading.value = true;
      final model = await _requestModules();
      if (model != null) return model;

      // A transient failure (e.g. "Connection closed before full header")
      // would otherwise hide Copy Trading / PAMM until the next screen refresh.
      if (modules.value == null) {
        await Future<void>.delayed(const Duration(seconds: 2));
        return await _requestModules() ?? modules.value;
      }
      return modules.value;
    } finally {
      isLoading.value = false;
    }
  }

  Future<EnabledModulesModel?> _requestModules() async {
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.enabledModules,
      );

      if (!response.success || response.data == null) {
        AppLogger.error(
          'EnabledModulesService: Failed - ${response.message}',
        );
        return null;
      }

      final payload = _extractPayload(response.data);
      if (payload == null) {
        AppLogger.error('EnabledModulesService: Could not parse payload');
        return null;
      }

      final model = EnabledModulesModel.fromJson(payload);
      modules.value = model;
      AppLogger.debug('EnabledModulesService: modules loaded');
      return model;
    } catch (e, stackTrace) {
      AppLogger.error(
        'EnabledModulesService: Error',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Map<String, dynamic>? _extractPayload(dynamic raw) {
    if (raw == null) return null;
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    final top = asMap(raw);
    if (top == null) return null;
    if (_looksLikeModules(top)) return top;
    final inner = asMap(top['data']);
    if (inner != null && _looksLikeModules(inner)) return inner;
    return null;
  }

  bool _looksLikeModules(Map<String, dynamic> map) {
    return map.containsKey('pmam') ||
        map.containsKey('copytrading') ||
        map.containsKey('scratchcard') ||
        map.containsKey('tradewin');
  }
}
