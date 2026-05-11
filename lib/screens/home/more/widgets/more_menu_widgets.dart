import 'package:crm_app/constants/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class MoreMenuCardGroup extends StatelessWidget {
  final List<Widget> children;

  const MoreMenuCardGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.14)),
      ),
      child: Column(
        children:
            children.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              if (index == children.length - 1) return child;

              return Column(
                children: [
                  child,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Divider(
                      height: 1,
                      color: AppColors.icongrey.withValues(alpha: 0.14),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }
}

class MoreMenuTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  final bool showArrow;
  final String? iconName;
  final String? iconAssetPath;

  const MoreMenuTile({
    super.key,
    required this.label,
    required this.onTap,
    this.textColor,
    this.showArrow = true,
    this.iconName,
    this.iconAssetPath,
  }) : assert(
         iconName != null || iconAssetPath != null,
         'Either iconName or iconAssetPath must be provided.',
       );

  @override
  Widget build(BuildContext context) {
    final iconPath =
        iconAssetPath != null ? iconAssetPath! : 'assets/svg/more/$iconName.svg';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
          child: Row(
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    iconPath,
                    height: 18.h,
                    width: 18.w,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: textColor ?? AppColors.textPrimary,
                  ),
                ),
              ),
              if (showArrow)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.sp,
                  color: AppColors.icongrey.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
