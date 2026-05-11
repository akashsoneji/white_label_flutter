import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';

/// SVG back control for app bars (same asset as Finance and other trade flows).
/// Uses [AppColors.textPrimary] so icon follows light / dark theme.
class AppSvgBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AppSvgBackButton({super.key, required this.onPressed});

  /// Prefer [Navigator.pop] when possible, otherwise [Get.back].
  static void popRoute(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: SvgPicture.asset(
        'assets/svg/trade/arro_back.svg',
        colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
      ),
      onPressed: onPressed,
    );
  }
}
