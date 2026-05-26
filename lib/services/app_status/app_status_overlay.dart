import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/app_status/app_status_controller.dart';
import 'package:crm_app/services/app_status/maintenance_screen.dart';

/// Global overlay widget for app status (maintenance screen)
/// This widget listens to AppStatusController and shows maintenance screen when needed
class AppStatusOverlay extends StatelessWidget {
  const AppStatusOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppStatusController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<AppStatusController>();

    return Obx(() {
      // Show maintenance screen if maintenance mode is active
      final isMaintenance = controller.isMaintenanceMode.value;
      
      if (isMaintenance) {
        return Positioned.fill(
          child: Material(
            color: AppColors.whiteColor,
            child: const MaintenanceScreen(),
          ),
        );
      }

      // Return empty widget if not in maintenance mode
      return const SizedBox.shrink();
    });
  }
}
