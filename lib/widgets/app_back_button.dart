import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';

/// App-wide back control: same SVG asset, size, and tap target on every screen.
/// Uses AppColors.textPrimary which automatically supports dark/light mode.
class AppBackButton extends StatelessWidget {
  static const String assetPath = 'assets/svg/trade/arro_back.svg';

  /// Standard AppBar leading slot (matches Material [kToolbarHeight] alignment).
  static const double leadingSlotSize = 48;

  static const double iconSize = 22;

  final VoidCallback? onPressed;
  final bool closeOverlays;

  const AppBackButton({super.key, this.onPressed, this.closeOverlays = true});

  /// Prefer [Navigator.pop] when possible, otherwise [Get.back].
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
    // Uses AppColors.textPrimary which is theme-aware (white in dark mode, black in light mode)
    final iconColor = AppColors.textPrimary;

    return SizedBox(
      width: leadingSlotSize.w,
      height: leadingSlotSize.w,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        alignment: Alignment.center,
        onPressed:
            onPressed ?? () => popRoute(context, closeOverlays: closeOverlays),
        icon: SvgPicture.asset(
          assetPath,
          width: iconSize.w,
          height: iconSize.w,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
    );
  }
}