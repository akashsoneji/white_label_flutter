import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/app_settings_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/app_status/app_status_service.dart';
import 'package:crm_app/services/crm_settings_service.dart';
import 'package:crm_app/services/enabled_modules_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/utils/app_logger.dart';

/// Fetches public app settings (maintenance switches, support contacts, KYC
/// lock, OTP policy, Reverb). Called before login too, so it never needs a
/// token.
class AppSettingsService extends GetxService with WidgetsBindingObserver {
  /// Resume refresh is throttled so quick app switches don't re-hit 4 APIs.
  static const _resumeRefreshInterval = Duration(minutes: 5);

  final Rxn<AppSettingsModel> settings = Rxn<AppSettingsModel>();
  final RxBool isLoading = false.obs;
  DateTime? _lastResumeRefresh;

  AppSettingsModel get current => settings.value ?? AppSettingsModel.empty;

  /// Admin turned the SMS channel off. False until settings load, so an
  /// unloaded/failed fetch keeps the existing mobile OTP flows working.
  bool get isMobileOtpOff =>
      settings.value != null && !current.isMobileOtpAvailable;

  /// KYC must not be submitted before the mobile number is verified.
  bool get kycRequiresMobileVerified =>
      !isMobileOtpOff && current.otpPolicy.kycRequireMobileVerified;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    fetchAppSettings();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshOnResume());
    }
  }

  /// Re-reads maintenance / update / module switches when the app returns to
  /// the foreground so an admin change is picked up without a restart.
  Future<void> refreshOnResume() async {
    final now = DateTime.now();
    final last = _lastResumeRefresh;
    if (last != null && now.difference(last) < _resumeRefreshInterval) return;
    _lastResumeRefresh = now;

    await fetchAppSettings(force: true);
    if (Get.isRegistered<CrmSettingsService>()) {
      unawaited(Get.find<CrmSettingsService>().fetchCrmSettings(force: true));
    }
    // Runs after app-settings so portal maintenance is evaluated on fresh data.
    if (Get.isRegistered<AppStatusService>()) {
      unawaited(Get.find<AppStatusService>().checkAppStatus());
    }

    final token = await SecureStorageService.getAuthToken();
    if (token != null &&
        token.isNotEmpty &&
        Get.isRegistered<EnabledModulesService>()) {
      unawaited(
        Get.find<EnabledModulesService>().fetchEnabledModules(force: true),
      );
    }
  }

  Future<AppSettingsModel?> fetchAppSettings({bool force = false}) async {
    if (!force && settings.value != null) {
      return settings.value;
    }

    try {
      isLoading.value = true;
      final response = await ApiService.get(
        endpoint: ApiConstants.appSettings,
        queryParameters: {
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (!response.success || response.data == null) {
        AppLogger.error(
          'AppSettingsService: Failed to load - ${response.message}',
        );
        return settings.value;
      }

      final payload = _extractPayload(response.data);
      if (payload == null) {
        AppLogger.error('AppSettingsService: Could not parse payload');
        return settings.value;
      }

      final model = AppSettingsModel.fromJson(payload);
      settings.value = model;
      AppLogger.debug('AppSettingsService: app settings loaded');
      return model;
    } catch (e, stackTrace) {
      AppLogger.error(
        'AppSettingsService: Error loading settings',
        error: e,
        stackTrace: stackTrace,
      );
      return settings.value;
    } finally {
      isLoading.value = false;
    }
  }

  Map<String, dynamic>? _extractPayload(dynamic raw) {
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    final top = asMap(raw);
    if (top == null) return null;
    final inner = asMap(top['data']);
    if (inner != null) return inner;
    return top.containsKey('portal_maintenance_mode') ? top : null;
  }
}
