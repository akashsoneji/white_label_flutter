import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// @deprecated Use [AppBackButton] — kept for existing imports.
class AppSvgBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double? iconWidth;
  final double? iconHeight;

  const AppSvgBackButton({
    super.key,
    this.onPressed,
    this.iconWidth,
    this.iconHeight,
  });

  static void popRoute(BuildContext context) =>
      AppBackButton.popRoute(context);

  @override
  Widget build(BuildContext context) {
    if (iconWidth != null || iconHeight != null) {
      final iconColor = AppColors.textPrimary;
      return IconButton(
        onPressed: onPressed ?? () => AppBackButton.popRoute(context),
        icon: SvgPicture.asset(
          AppBackButton.assetPath,
          width: iconWidth,
          height: iconHeight,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      );
    }
    return AppBackButton(
      onPressed: onPressed ?? () => AppBackButton.popRoute(context),
    );
  }
}
