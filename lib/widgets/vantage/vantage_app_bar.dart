import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// Vantage-only unified AppBar shell.
///
/// Use this ONLY inside `if (FlavorConfig.isVantage())` branches.
class VantageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBottomDivider;
  final Color? backgroundColor;
  final double? toolbarHeight;
  final double titleSpacing;

  const VantageAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.onBack,
    this.actions,
    this.centerTitle = false,
    this.showBottomDivider = true,
    this.backgroundColor,
    this.toolbarHeight,
    this.titleSpacing = 0,
  });

  factory VantageAppBar.text(
    String titleText, {
    Key? key,
    bool showBack = true,
    VoidCallback? onBack,
    List<Widget>? actions,
    bool centerTitle = false,
    bool showBottomDivider = true,
    Color? backgroundColor,
    double? toolbarHeight,
    double titleSpacing = 0,
    TextStyle? titleStyle,
  }) {
    return VantageAppBar(
      key: key,
      title: Text(
        titleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (titleStyle ?? AppTextStyles.heading).copyWith(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      showBack: showBack,
      onBack: onBack,
      actions: actions,
      centerTitle: centerTitle,
      showBottomDivider: showBottomDivider,
      backgroundColor: backgroundColor,
      toolbarHeight: toolbarHeight,
      titleSpacing: titleSpacing,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.background;

    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      toolbarHeight: toolbarHeight,
      titleSpacing: titleSpacing,
      automaticallyImplyLeading: showBack,
      leading:
          showBack
              ? AppBackButton(
                onPressed: onBack ?? () => AppBackButton.popRoute(context),
              )
              : null,
      title: DefaultTextStyle.merge(
        style: AppTextStyles.heading.copyWith(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        child: title,
      ),
      actions: actions,
      bottom:
          showBottomDivider
              ? PreferredSize(
                preferredSize: Size.fromHeight(1.h),
                child: Container(
                  height: 1,
                  color: AppColors.border.withOpacity(0.25),
                ),
              )
              : null,
    );
  }
}

