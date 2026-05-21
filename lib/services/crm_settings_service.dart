import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/crm_settings_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/utils/app_logger.dart';

/// Fetches public CRM settings (agreements, disclaimers, company info).
class CrmSettingsService extends GetxService {
  final Rxn<CrmSettingsModel> settings = Rxn<CrmSettingsModel>();
  final RxBool isLoading = false.obs;

  CrmSettingsModel? get current => settings.value;

  @override
  void onInit() {
    super.onInit();
    fetchCrmSettings();
  }

  Future<CrmSettingsModel?> fetchCrmSettings({bool force = false}) async {
    if (!force && settings.value != null) {
      return settings.value;
    }

    try {
      isLoading.value = true;
      final response = await ApiService.get(
        endpoint: ApiConstants.crmSettings,
      );

      if (!response.success || response.data == null) {
        AppLogger.error(
          'CrmSettingsService: Failed to load - ${response.message}',
        );
        return settings.value;
      }

      final payload = _extractPayload(response.data);
      if (payload == null) {
        AppLogger.error('CrmSettingsService: Could not parse payload');
        return settings.value;
      }

      final model = CrmSettingsModel.fromJson(payload);
      settings.value = model;
      AppLogger.debug('CrmSettingsService: CRM settings loaded');
      return model;
    } catch (e, stackTrace) {
      AppLogger.error(
        'CrmSettingsService: Error loading settings',
        error: e,
        stackTrace: stackTrace,
      );
      return settings.value;
    } finally {
      isLoading.value = false;
    }
  }

  CrmAgreementItem? agreementFor(String key) {
    return settings.value?.agreements.byKey(key);
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
    if (top.containsKey('agreements')) return top;
    final inner = asMap(top['data']);
    if (inner != null && inner.containsKey('agreements')) return inner;
    return null;
  }
}
