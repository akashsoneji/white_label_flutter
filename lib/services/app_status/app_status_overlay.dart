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
      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    }

    final controller = Get.find<AppStatusController>();

    return Obx(() {
      final isMaintenance = controller.isMaintenanceMode.value;
      
      if (isMaintenance) {
        return Positioned.fill(
          child: Material(
            color: AppColors.whiteColor,
            child: const MaintenanceScreen(),
          ),
        );
      }

      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    });
  }
}
