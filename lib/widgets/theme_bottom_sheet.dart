import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/language_service.dart';

/// Theme picker — app uses light theme only.
void showThemeBottomSheet(BuildContext context) {
  final languageService = Get.find<LanguageService>();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder:
        (context) => Container(
          margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
          padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 18.h),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      languageService.tr('settings_theme_title'),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, size: 22.sp, color: AppColors.textPrimary),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Icon(Icons.light_mode_rounded, color: AppColors.primary, size: 28.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      languageService.tr('settings_theme_light'),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22.sp),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                languageService.tr('settings_theme_description'),
                style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
  );
}
