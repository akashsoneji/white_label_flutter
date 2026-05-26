import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_app/services/app_status/app_status_model.dart';
import 'package:crm_app/services/app_status/app_status_service.dart';
import 'package:crm_app/services/app_version_service.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:crm_app/services/app_status/force_update_dialog.dart'
    as force_update;
// import 'package:crm_app/services/app_status/maintenance_screen.dart';

/// Controller for managing app status (version check and maintenance mode)
class AppStatusController extends GetxController {
  final AppStatusService _service = Get.find<AppStatusService>();

  // Observable states
  final RxBool isUpdateRequired = false.obs;
  final RxBool isMaintenanceMode = false.obs;
  final RxString latestVersion = ''.obs;
  final RxBool isChecking = false.obs;
  final RxBool isForceUpdate = true.obs;
  final Rx<AppStatusModel?> statusData = Rx<AppStatusModel?>(null);

  bool _forceUpdateDialogShown = false;
  bool _maintenanceScreenShown = false;

  // Getter for force update dialog shown state
  bool get forceUpdateDialogShown => _forceUpdateDialogShown;

  // Method to reset force update dialog flag
  void resetForceUpdateDialogFlag() {
    _forceUpdateDialogShown = false;
  }

  static const String _skipUpdateTimestampKey = 'app_update_skip_timestamp';
  static const Duration _skipDuration = Duration(hours: 6);

  @override
  void onInit() {
    super.onInit();
    AppLogger.debug('AppStatusController: Initialized');
  }

  /// Handle status update from service
  Future<void> handleStatusUpdate(AppStatusModel status) async {
    try {
      isChecking.value = true;
      latestVersion.value = status.appVersion;

      bool computedForceUpdate = status.isForceUpdate;

      // If not marked as force update by backend, check the later_date
      if (!computedForceUpdate && status.laterDate != null) {
        try {
          final DateTime laterDate = DateTime.parse(status.laterDate!);
          if (DateTime.now().isAfter(laterDate)) {
            computedForceUpdate = true;
          }
        } catch (e) {
          AppLogger.error(
            'AppStatusController: Error parsing later_date',
            error: e,
          );
        }
      }

      isForceUpdate.value = computedForceUpdate;
      statusData.value = status;

      // Check maintenance mode first (takes priority)
      if (status.isUnderMaintenance) {
        isMaintenanceMode.value = true;
        if (!_maintenanceScreenShown) {
          showMaintenanceScreen();
        }
        // Don't hide force update dialog during maintenance - it should persist
        isUpdateRequired.value = true; // Keep update required flag true
      } else {
        // Maintenance mode is off - hide maintenance screen
        if (isMaintenanceMode.value) {
          AppLogger.debug(
            'AppStatusController: Maintenance mode turned off, hiding maintenance screen',
          );
          isMaintenanceMode.value = false;
          hideMaintenanceScreen();
        }

        // Check if update is required
        final updateRequired = await _service.isUpdateRequired(
          status.appVersion,
        );
        isUpdateRequired.value = updateRequired;

        if (updateRequired) {
          // Check if user has skipped the update (only for non-force updates)
          if (!computedForceUpdate) {
            final shouldShow = await shouldShowUpdateDialog();
            if (!shouldShow) {
              AppLogger.debug(
                'AppStatusController: Update skipped, not showing dialog',
              );
              return;
            }
          }

          // Always show dialog if update is required (even if already shown, ensure it's visible)
          if (!_forceUpdateDialogShown) {
            showForceUpdateDialog(computedForceUpdate);
          } else {
            // Dialog already shown - verify it's still open, if not, show it again
            if (!(Get.isDialogOpen ?? false)) {
              _forceUpdateDialogShown =
                  false; // Reset flag to allow showing again
              showForceUpdateDialog(computedForceUpdate);
            }
          }
        } else {
          // Only hide dialog if versions actually match (user updated the app)
          // This means the installed version now matches the API version
          // But only hide if we're sure - don't hide on first check if dialog wasn't shown
          if (_forceUpdateDialogShown && (Get.isDialogOpen ?? false)) {
            hideForceUpdateDialog();
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'AppStatusController: Error handling status update',
        error: e,
        stackTrace: stackTrace,
      );
      // On error, don't hide the dialog - keep it shown if it was already shown
    } finally {
      isChecking.value = false;
    }
  }

  /// Show force update dialog
  void showForceUpdateDialog(bool isForceUpdate) {
    // If already shown and dialog is still open, don't show again
    if (_forceUpdateDialogShown && (Get.isDialogOpen ?? false)) {
      return;
    }

    _forceUpdateDialogShown = true;

    Get.dialog(
      PopScope(
        canPop: !isForceUpdate,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && isForceUpdate) {
            _forceUpdateDialogShown = false;
          }
        },
        child: force_update.ForceUpdateDialog(isForceUpdate: isForceUpdate),
      ),
      barrierDismissible: false,
    );
    AppLogger.debug(
      'AppStatusController: Force update dialog shown (force: $isForceUpdate)',
    );
  }

  /// Check if update dialog should be shown (considering skip timestamp)
  Future<bool> shouldShowUpdateDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skipTimestamp = prefs.getInt(_skipUpdateTimestampKey);

      if (skipTimestamp == null) {
        return true; // No skip recorded, show dialog
      }

      final skipTime = DateTime.fromMillisecondsSinceEpoch(skipTimestamp);
      final now = DateTime.now();
      final difference = now.difference(skipTime);

      // If 24 hours have passed, show dialog again
      if (difference >= _skipDuration) {
        // Clear the skip timestamp
        await prefs.remove(_skipUpdateTimestampKey);
        return true;
      }

      // Still within 24 hours, don't show
      return false;
    } catch (e) {
      AppLogger.error(
        'AppStatusController: Error checking skip timestamp',
        error: e,
      );
      return true; // On error, show dialog to be safe
    }
  }

  /// Save skip timestamp when user taps "Skip for now"
  Future<void> skipUpdateFor24Hours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setInt(_skipUpdateTimestampKey, now.millisecondsSinceEpoch);
      AppLogger.debug('AppStatusController: Update skipped for 6 hours');
    } catch (e) {
      AppLogger.error(
        'AppStatusController: Error saving skip timestamp',
        error: e,
      );
    }
  }

  /// Hide force update dialog
  void hideForceUpdateDialog() {
    if (!_forceUpdateDialogShown) return;

    if (Get.isDialogOpen ?? false) {
      Get.back(closeOverlays: true);
    }
    _forceUpdateDialogShown = false;
    AppLogger.debug('AppStatusController: Force update dialog hidden');
  }

  /// Show maintenance screen
  void showMaintenanceScreen() {
    if (_maintenanceScreenShown) return;

    _maintenanceScreenShown = true;
    AppLogger.debug('AppStatusController: Maintenance screen shown');
  }

  /// Hide maintenance screen
  void hideMaintenanceScreen() {
    if (!_maintenanceScreenShown) return;

    _maintenanceScreenShown = false;
    AppLogger.debug('AppStatusController: Maintenance screen hidden');
  }

  /// Check status manually (for retry button)
  Future<void> checkStatus() async {
    await _service.checkAppStatus();
  }

  /// Open app store/play store
  Future<void> openAppStore() async {
    try {
      final packageName = await AppVersionService.instance.getPackageName();
      String url;

      if (Platform.isAndroid) {
        // Prefer backend URL if available (can be Play Store URL or direct APK URL)
        final androidUrl = statusData.value?.updateUrlAndroid;
        if (androidUrl != null && androidUrl.isNotEmpty) {
          url = androidUrl;
        } else {
          url = 'https://play.google.com/store/apps/details?id=$packageName';
        }
      } else if (Platform.isIOS) {
        // Prefer backend URL for iOS; fallback to App Store URL using package name
        url = statusData.value?.updateUrlIos?.isNotEmpty == true
            ? statusData.value!.updateUrlIos!
            : 'https://apps.apple.com/app/id$packageName';
      } else {
        AppLogger.error(
          'AppStatusController: Unsupported platform for app store',
        );
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        AppLogger.debug('AppStatusController: Opened app store: $url');
      } else {
        AppLogger.error(
          'AppStatusController: Could not launch app store URL: $url',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'AppStatusController: Error opening app store',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void onClose() {
    hideForceUpdateDialog();
    super.onClose();
  }
}
