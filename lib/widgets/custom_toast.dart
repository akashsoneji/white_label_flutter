import 'dart:async';
import 'package:crm_app/constants/text_styles.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';

enum ToastType { success, error, info, warning }

class CustomToast extends StatelessWidget {
  final String message;
  final ToastType type;
  final String? title;
  final Duration duration;
  final VoidCallback? onClose;
  final bool showIcon;
  final bool showCloseButton;

  const CustomToast({
    super.key,
    required this.message,
    this.type = ToastType.info,
    this.title,
    this.duration = const Duration(milliseconds: 1500),
    this.onClose,
    this.showIcon = true,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            // Icon with circular background
            if (showIcon) ...[
              Container(
                width: 24.w,
                height: 24.h,
                decoration: BoxDecoration(
                  color: AppColors.whiteColor.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.whiteColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _getIcon(),
                  color: AppColors.whiteColor,
                  size: 16.h,
                ),
              ),
              SizedBox(width: 14.w),
            ],

            // Content section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.whiteColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 3.h),
                  ],
                  Text(
                    message,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.whiteColor.withValues(alpha: 0.95),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Close button
            if (showCloseButton) ...[
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: onClose ?? () => CustomToastService.close(),
                child: Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: AppColors.whiteColor,
                    size: 18.h,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
        return AppColors.error;
      case ToastType.info:
        return AppColors.primary;
      case ToastType.warning:
        return AppColors.warning;
    }
  }

  IconData _getIcon() {
    switch (type) {
      case ToastType.success:
        return Icons.check;
      case ToastType.error:
        return Icons.close;
      case ToastType.info:
        return Icons.info;
      case ToastType.warning:
        return Icons.warning;
    }
  }
}

class CustomToastService {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void show({
    required String message,
    ToastType type = ToastType.info,
    String? title,
    Duration duration = const Duration(milliseconds: 1500),
    VoidCallback? onClose,
    bool showIcon = true,
    bool showCloseButton = false,
    SnackPosition position = SnackPosition.TOP,
  }) {
    // Remove any existing toast immediately
    close();

    // Get overlay context - try multiple fallbacks
    BuildContext? overlayContext;
    OverlayState? overlayState;

    // Try Get.overlayContext first
    try {
      overlayContext = Get.overlayContext;
      if (overlayContext != null) {
        overlayState = Overlay.of(overlayContext);
      }
    } catch (e) {
      overlayContext = null;
      overlayState = null;
    }

    // Fallback to Get.context if overlayContext is not available
    if (overlayState == null) {
      try {
        overlayContext = Get.context;
        if (overlayContext != null) {
          overlayState = Overlay.of(overlayContext);
        }
      } catch (e) {
        overlayContext = null;
        overlayState = null;
      }
    }

    // Final fallback to navigator key context
    if (overlayState == null && Get.key.currentContext != null) {
      try {
        overlayContext = Get.key.currentContext;
        if (overlayContext != null) {
          overlayState = Overlay.of(overlayContext);
        }
      } catch (e) {
        overlayContext = null;
        overlayState = null;
      }
    }

    if (overlayState == null || overlayContext == null) {
      final errorMsg =
          'CustomToastService: No valid overlay context found for showing toast';
      debugPrint(errorMsg);
      print('❌ $errorMsg');
      print('   Get.overlayContext: ${Get.overlayContext}');
      print('   Get.context: ${Get.context}');
      print('   Get.key.currentContext: ${Get.key.currentContext}');

      // Try fallback to Get.snackbar
      try {
        Get.snackbar(
          title ?? 'Error',
          message,
          snackPosition: position,
          backgroundColor: AppColors.error,
          colorText: AppColors.whiteColor,
          duration: duration,
        );
        print('✅ Fallback: Using Get.snackbar() instead');
      } catch (e) {
        print('❌ Fallback Get.snackbar() also failed: $e');
        print('🔴 ERROR MESSAGE (All toast methods failed): $message');
      }
      return;
    }

    final isTop = position == SnackPosition.TOP;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: isTop ? MediaQuery.of(context).padding.top + 10 : null,
            bottom: !isTop ? MediaQuery.of(context).padding.bottom + 10 : null,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: CustomToast(
                  message: message,
                  type: type,
                  title: title,
                  duration: duration,
                  onClose: onClose,
                  showIcon: showIcon,
                  showCloseButton: showCloseButton,
                ),
              ),
            ),
          ),
    );

    overlayState.insert(_overlayEntry!);

    _timer = Timer(duration, () {
      close();
    });
  }

  static void close() {
    _timer?.cancel();
    _timer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // Convenience methods for different toast types
  static void showSuccess({
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 1500),
    VoidCallback? onClose,
    SnackPosition position = SnackPosition.TOP,
  }) {
    // Use AppNotificationController instead of overlay
    if (Get.isRegistered<AppNotificationController>()) {
      final controller = Get.find<AppNotificationController>();
      controller.showSuccess(
        message: message,
        title: title,
        duration: duration,
      );

      // Call onClose callback if provided
      if (onClose != null) {
        Future.delayed(duration, onClose);
      }
    } else {
      // Fallback to old method if controller not registered
      print(
        '⚠️ CustomToastService: AppNotificationController not registered, using fallback',
      );
      show(
        message: message,
        title: title,
        type: ToastType.success,
        duration: duration,
        onClose: onClose,
        position: position,
      );
    }
  }

  static void showError({
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 1500),
    VoidCallback? onClose,
    SnackPosition position = SnackPosition.TOP,
  }) {
    // Use AppNotificationController instead of overlay
    if (Get.isRegistered<AppNotificationController>()) {
      final controller = Get.find<AppNotificationController>();
      controller.showError(message: message, title: title, duration: duration);

      // Call onClose callback if provided
      if (onClose != null) {
        Future.delayed(duration, onClose);
      }
    } else {
      // Fallback to old method if controller not registered
      print(
        '⚠️ CustomToastService: AppNotificationController not registered, using fallback',
      );
      show(
        message: message,
        title: title,
        type: ToastType.error,
        duration: duration,
        onClose: onClose,
        position: position,
      );
    }
  }

  static void showInfo({
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 1500),
    VoidCallback? onClose,
    SnackPosition position = SnackPosition.TOP,
  }) {
    // Use AppNotificationController instead of overlay
    if (Get.isRegistered<AppNotificationController>()) {
      final controller = Get.find<AppNotificationController>();
      controller.showInfo(message: message, title: title, duration: duration);

      // Call onClose callback if provided
      if (onClose != null) {
        Future.delayed(duration, onClose);
      }
    } else {
      // Fallback to old method if controller not registered
      print(
        '⚠️ CustomToastService: AppNotificationController not registered, using fallback',
      );
      show(
        message: message,
        title: title,
        type: ToastType.info,
        duration: duration,
        onClose: onClose,
        position: position,
      );
    }
  }

  static void showWarning({
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 1500),
    VoidCallback? onClose,
    SnackPosition position = SnackPosition.TOP,
  }) {
    // Use AppNotificationController instead of overlay
    if (Get.isRegistered<AppNotificationController>()) {
      final controller = Get.find<AppNotificationController>();
      controller.showWarning(
        message: message,
        title: title,
        duration: duration,
      );

      // Call onClose callback if provided
      if (onClose != null) {
        Future.delayed(duration, onClose);
      }
    } else {
      // Fallback to old method if controller not registered
      print(
        '⚠️ CustomToastService: AppNotificationController not registered, using fallback',
      );
      show(
        message: message,
        title: title,
        type: ToastType.warning,
        duration: duration,
        onClose: onClose,
        position: position,
      );
    }
  }

  // Method to show toast from bottom
  static void showFromBottom({
    required String message,
    ToastType type = ToastType.info,
    String? title,
    Duration duration = const Duration(milliseconds: 1500),
    VoidCallback? onClose,
    bool showIcon = true,
    bool showCloseButton = true,
  }) {
    show(
      message: message,
      type: type,
      title: title,
      duration: duration,
      onClose: onClose,
      showIcon: showIcon,
      showCloseButton: showCloseButton,
      position: SnackPosition.BOTTOM,
    );
  }

  // Method to show toast from top
  static void showFromTop({
    required String message,
    ToastType type = ToastType.info,
    String? title,
    Duration duration = const Duration(milliseconds: 1500),
    VoidCallback? onClose,
    bool showIcon = true,
    bool showCloseButton = true,
  }) {
    show(
      message: message,
      type: type,
      title: title,
      duration: duration,
      onClose: onClose,
      showIcon: showIcon,
      showCloseButton: showCloseButton,
      position: SnackPosition.TOP,
    );
  }
}
