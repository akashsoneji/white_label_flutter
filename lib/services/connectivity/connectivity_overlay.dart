import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/connectivity/connectivity_controller.dart';
import 'package:crm_app/services/connectivity/no_internet_screen.dart';

/// Global overlay widget that shows a "No Internet" screen
/// whenever the device loses connectivity.
///
/// This sits on top of all app screens in the global Stack (main.dart)
/// and auto-dismisses when connection is restored.
class ConnectivityOverlay extends StatelessWidget {
  const ConnectivityOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConnectivityController>()) {
      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    }

    final controller = Get.find<ConnectivityController>();

    return Obx(() {
      final disconnected = !controller.isConnected.value;

      if (disconnected) {
        return Positioned.fill(
          child: Material(
            color: Colors.white,
            child: const NoInternetScreen(),
          ),
        );
      }

      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    });
  }
}
