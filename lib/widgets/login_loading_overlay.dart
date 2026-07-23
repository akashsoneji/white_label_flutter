import 'package:flutter/material.dart';
import '../constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../constants/color.dart';

/// Custom loading overlay for login screen
class LoginLoadingOverlay extends StatelessWidget {
  final String message;
  final double size;
  final Color? color;

  const LoginLoadingOverlay({
    super.key,
    this.message = "Logging in...",
    this.size = 60.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.surface.withOpacity(0.4),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.border.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingAnimationWidget.fourRotatingDots(
                color: color ?? AppColors.primary,
                size: size.w,
              ),
              SizedBox(height: 16.h),
              Text(
                message,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
