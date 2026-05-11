import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/services/app_version_service.dart';
import 'package:crm_app/services/app_status/app_status_model.dart';
import 'package:crm_app/services/app_status/app_status_controller.dart';
import 'package:crm_app/utils/app_logger.dart';

/// Service to check app version and maintenance status
class AppStatusService extends GetxService {
  Timer? _periodicTimer;
  // static const Duration _checkInterval = Duration(seconds: 10);

  /// When true, loads [mockFileName] from assets instead of the API.
  /// Only honored in [kDebugMode] so release builds always use the API.
  static bool useMockData = false;
  static String mockFileName =
      'app_status_response.json'; // Modify this file to test different scenarios (change app_version or is_under_maintenance)

  /// Start periodic checking
  void startPeriodicCheck() {
    // App update disabled per user request
    return;
  }

  /// Stop periodic checking
  void stopPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    AppLogger.debug('AppStatusService: Stopped periodic checking');
  }

  /// Check app status (either from API or mock data)
  Future<AppStatusModel?> checkAppStatus() async {
    try {
      // Ensure AppVersionService is initialized before checking
      await AppVersionService.instance.initialize();

      AppStatusModel? status;

      if (kDebugMode && useMockData) {
        // Load from mock JSON file (debug only)
        status = await loadMockData(mockFileName);
        AppLogger.debug(
          'AppStatusService: Loaded mock data from $mockFileName',
        );
      } else {
        final response = await Get.find<ApiClient>().get(
          endpoint: ApiConstants.mobileAppDetails,
        );

        if (response.success && response.data != null) {
          final payload = _extractStatusPayload(response.data);
          if (payload == null) {
            AppLogger.error(
              'AppStatusService: Could not parse mobile-app-details payload',
            );
            return null;
          }
          status = AppStatusModel.fromJson(payload);
          AppLogger.debug('AppStatusService: Loaded status from API');
        } else {
          AppLogger.error(
            'AppStatusService: API call failed - ${response.message}',
          );
          // Don't return null on API failure - continue with previous state
          // This prevents hiding the dialog on temporary network errors
          return null;
        }
      }

      if (status != null) {
        // Compare versions and notify controller
        // Only process if we have valid status data
        if (Get.isRegistered<AppStatusController>()) {
          final controller = Get.find<AppStatusController>();
          await controller.handleStatusUpdate(status);
        }
      }

      return status;
    } catch (e, stackTrace) {
      AppLogger.error(
        'AppStatusService: Error checking app status',
        error: e,
        stackTrace: stackTrace,
      );
      // On error, don't return null - let the previous state persist
      // This ensures the dialog stays visible even if there's a temporary error
      return null;
    }
  }

  /// Flat `{ app_version: ... }` or wrapped `{ data: { app_version: ... } }`.
  Map<String, dynamic>? _extractStatusPayload(dynamic raw) {
    if (raw == null) return null;
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    final top = asMap(raw);
    if (top == null) return null;
    if (top.containsKey('app_version')) return top;
    final inner = asMap(top['data']);
    if (inner != null && inner.containsKey('app_version')) return inner;
    return null;
  }

  /// Load mock data from assets
  Future<AppStatusModel?> loadMockData(String fileName) async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/mock/$fileName',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return AppStatusModel.fromJson(jsonData);
    } catch (e, stackTrace) {
      AppLogger.error(
        'AppStatusService: Error loading mock data from $fileName',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Compare installed version with API version
  /// Returns true if update is required (API version is greater than installed)
  Future<bool> isUpdateRequired(String apiVersion) async {
    try {
      final installedVersion = await AppVersionService.instance.getVersion();

      debugPrint(
        'AppStatusService: Installed version: $installedVersion, API version: $apiVersion',
      );
      // Update is required only when the backend version is higher than the
      // installed version. If the installed version is already ahead (e.g. QA
      // builds), do not show update dialogs.
      return _compareSemanticVersions(installedVersion, apiVersion) < 0;
    } catch (e) {
      AppLogger.error('AppStatusService: Error comparing versions', error: e);
      return false;
    }
  }

  /// Compare two semantic versions.
  /// Returns:
  /// - `< 0` if [installed] < [api]
  /// - `0` if equal
  /// - `> 0` if [installed] > [api]
  ///
  /// Notes:
  /// - Accepts versions like `2.2.26`, `2.2`, `v2.2.26`
  /// - Ignores any non-numeric suffix in each part (e.g. `1.2.3+4`, `1.2.3-beta`)
  int _compareSemanticVersions(String installed, String api) {
    try {
      List<int> parseParts(String v) {
        final cleaned = v.trim().replaceFirst(RegExp(r'^[vV]'), '');
        return cleaned.split('.').map((raw) {
          final match = RegExp(r'^\d+').firstMatch(raw.trim());
          return int.tryParse(match?.group(0) ?? '') ?? 0;
        }).toList();
      }

      final installedParts = parseParts(installed);
      final apiParts = parseParts(api);

      // Pad with zeros if lengths differ
      while (installedParts.length < apiParts.length) {
        installedParts.add(0);
      }
      while (apiParts.length < installedParts.length) {
        apiParts.add(0);
      }

      for (int i = 0; i < installedParts.length; i++) {
        final diff = installedParts[i] - apiParts[i];
        if (diff != 0) return diff;
      }
      return 0;
    } catch (e) {
      AppLogger.error(
        'AppStatusService: Error in version comparison',
        error: e,
      );
      return 0;
    }
  }

  @override
  void onClose() {
    stopPeriodicCheck();
    super.onClose();
  }
}
