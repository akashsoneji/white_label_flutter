import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';

/// App-wide back button matching `ChartScreen` app bar style.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool closeOverlays;

  const AppBackButton({super.key, this.onPressed, this.closeOverlays = true});

  static void popRoute(BuildContext context, {bool closeOverlays = true}) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      Get.back(closeOverlays: closeOverlays);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed:
          onPressed ?? () => popRoute(context, closeOverlays: closeOverlays),
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18.sp,
        color: AppColors.textPrimary,
      ),
    );
  }
}

