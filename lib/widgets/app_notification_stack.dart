import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/widgets/app_notification_item.dart';

/// Stack widget to display multiple app-wide notifications.
/// Must always return a Positioned widget since it lives inside a Stack.
class AppNotificationStack extends StatelessWidget {
  const AppNotificationStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10.h,
      left: 16.w,
      right: 16.w,
      child: _NotificationContent(),
    );
  }
}

class _NotificationContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppNotificationController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<AppNotificationController>();

    return Obx(() {
      final notifications = controller.notifications;
      if (notifications.isEmpty) {
        return const SizedBox.shrink();
      }

      return Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children:
              notifications.map((notification) {
                return AppNotificationItem(notification: notification);
              }).toList(),
        ),
      );
    });
  }
}
