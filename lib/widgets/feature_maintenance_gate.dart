import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/app_settings_model.dart';
import 'package:crm_app/services/app_settings_service.dart';
import 'package:crm_app/services/language_service.dart';

/// Features an admin can switch off from `user/app-settings`
/// (`<feature>_maintenance_mode` + `<feature>_maintenance_message`).
enum MaintenanceFeature { deposit, withdrawal, registration, ibWithdrawal }

class FeatureMaintenance {
  FeatureMaintenance._();

  static MaintenanceFlag flagFor(MaintenanceFeature feature) {
    if (!Get.isRegistered<AppSettingsService>()) return MaintenanceFlag.off;
    final settings = Get.find<AppSettingsService>().current;
    switch (feature) {
      case MaintenanceFeature.deposit:
        return settings.depositMaintenance;
      case MaintenanceFeature.withdrawal:
        return settings.withdrawalMaintenance;
      case MaintenanceFeature.registration:
        return settings.registrationMaintenance;
      case MaintenanceFeature.ibWithdrawal:
        return settings.ibWithdrawalMaintenance;
    }
  }

  /// Admin message, or the translated default when the admin left it empty.
  static String messageFor(MaintenanceFeature feature) {
    final message = flagFor(feature).message;
    if (message.isNotEmpty) return message;
    switch (feature) {
      case MaintenanceFeature.deposit:
        return TranslationUtils.tr('maintenance_deposit_default');
      case MaintenanceFeature.withdrawal:
        return TranslationUtils.tr('maintenance_withdrawal_default');
      case MaintenanceFeature.registration:
        return TranslationUtils.tr('maintenance_registration_default');
      case MaintenanceFeature.ibWithdrawal:
        return TranslationUtils.tr('maintenance_ib_withdrawal_default');
    }
  }

  /// For tap handlers: shows the maintenance message and returns true when
  /// [feature] is switched off, so the caller skips navigation.
  static bool blockIfActive(MaintenanceFeature feature) {
    if (!flagFor(feature).isOn) return false;
    Get.dialog(
      AlertDialog(
        title: Text(TranslationUtils.tr('maintenance_feature_title')),
        content: Text(messageFor(feature)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(TranslationUtils.tr('general_ok')),
          ),
        ],
      ),
    );
    return true;
  }
}

/// Replaces [child] with a maintenance notice while [feature] is switched off.
/// Wrapping the screen itself covers every entry point (named routes,
/// `Get.to`, deep links) without touching each caller.
class FeatureMaintenanceGate extends StatelessWidget {
  final MaintenanceFeature feature;
  final Widget child;

  const FeatureMaintenanceGate({
    super.key,
    required this.feature,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppSettingsService>()) return child;
    return Obx(() {
      // Read inside Obx so an admin switch picked up on resume rebuilds this.
      Get.find<AppSettingsService>().settings.value;
      if (!FeatureMaintenance.flagFor(feature).isOn) return child;
      return Scaffold(
        appBar: AppBar(
          title: Text(TranslationUtils.tr('maintenance_feature_title')),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 56.sp,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    FeatureMaintenance.messageFor(feature),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
