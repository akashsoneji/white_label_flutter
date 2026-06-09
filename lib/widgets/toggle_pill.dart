import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

class TogglePill extends StatelessWidget {
  const TogglePill({
    super.key,
    required this.value,
    required this.label,
    required this.onTap,
    this.padding,
  });

  final bool value;
  final String label;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12.r);

    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            padding ??
            EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 8.h,
            ),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: borderRadius,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textGrey,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48.w,
              height: 26.h,
              decoration: BoxDecoration(
                color:
                    value ? AppColors.primary : AppColors.border.withOpacity(0.6),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                curve: Curves.easeOut,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: 20.w,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.border.withOpacity(0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
