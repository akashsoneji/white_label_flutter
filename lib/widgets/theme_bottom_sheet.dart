import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/theme_service.dart';

enum ThemeOption {
  system,
  light,
  dark,
}

extension ThemeOptionExtension on ThemeOption {
  String get translationKey {
    switch (this) {
      case ThemeOption.system:
        return 'settings_theme_system';
      case ThemeOption.light:
        return 'settings_theme_light';
      case ThemeOption.dark:
        return 'settings_theme_dark';
    }
  }

  ThemeMode get themeMode {
    switch (this) {
      case ThemeOption.system:
        return ThemeMode.system;
      case ThemeOption.light:
        return ThemeMode.light;
      case ThemeOption.dark:
        return ThemeMode.dark;
    }
  }

  IconData get icon {
    switch (this) {
      case ThemeOption.system:
        return Icons.settings_brightness_rounded;
      case ThemeOption.light:
        return Icons.light_mode_rounded;
      case ThemeOption.dark:
        return Icons.dark_mode_rounded;
    }
  }
}

/// Returns true if the theme switcher should be shown for the current brand.
/// Hidden when the active brand is forced dark or forced light.
bool isThemeSwitcherVisible() {
  if (!Get.isRegistered<ThemeService>()) return true;
  return !Get.find<ThemeService>().isThemeSwitcherHidden;
}

void showThemeBottomSheet(BuildContext context) {
  final languageService = Get.find<LanguageService>();
  final themeService = Get.find<ThemeService>();

  // Guard: brand is locked to a single theme — show info sheet instead.
  if (themeService.isThemeSwitcherHidden) {
    final lockedMode = themeService.forcedThemeMode ?? ThemeMode.light;
    _showLockedThemeSheet(context, languageService, lockedMode);
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(18.w, 16.h, 18.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      languageService.tr('settings_theme_title'),
                      style: AppTextStyles.screenTitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: Icon(
                      Icons.close,
                      size: 22.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              ...ThemeOption.values.map((option) {
                return Obx(() {
                  final isSelected = themeService.themeMode == option.themeMode;
                  return _buildThemeOption(
                    context: sheetContext,
                    option: option,
                    languageService: languageService,
                    isSelected: isSelected,
                    onTap: () {
                      themeService.setThemeMode(option.themeMode);
                      Navigator.pop(sheetContext);
                    },
                  );
                });
              }),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Sheet shown when the active brand has a locked theme (e.g. Celestial = dark).
void _showLockedThemeSheet(
  BuildContext context,
  LanguageService languageService,
  ThemeMode lockedMode,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final isDark = lockedMode == ThemeMode.dark;
      final label = isDark
          ? languageService.tr('settings_theme_dark')
          : languageService.tr('settings_theme_light');
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(18.w, 16.h, 18.w, 18.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        languageService.tr('settings_theme_title'),
                        style: AppTextStyles.screenTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Icon(
                        Icons.close,
                        size: 22.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: AppColors.iconBgPrimary,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppColors.primary,
                        size: 22.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          '${languageService.tr('settings_theme_locked')}: $label',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildThemeOption({
  required BuildContext context,
  required ThemeOption option,
  required dynamic languageService,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Icon(
                  option.icon,
                  color: AppColors.primary,
                  size: 22.sp,
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                languageService.tr(option.translationKey),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22.sp,
              ),
          ],
        ),
      ),
    ),
  );
}
