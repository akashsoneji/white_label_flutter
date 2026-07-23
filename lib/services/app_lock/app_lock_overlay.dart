import 'package:flutter/material.dart';
import '../../constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../constants/color.dart';
import '../../services/app_lock_service.dart';
import '../../services/biometric_service.dart';
import '../../services/language_service.dart';
import '../../screens/auth/view_models/auth_controller.dart';

class AppLockOverlay extends StatefulWidget {
  const AppLockOverlay({super.key});

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay> {
  bool _autoPromptedForCurrentLock = false;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppLockService>()) {
      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    }

    final lock = Get.find<AppLockService>();
    final language = Get.find<LanguageService>();

    return Obx(() {
      final locked = lock.isLocked.value;
      if (!locked) {
        _autoPromptedForCurrentLock = false;
        return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (_autoPromptedForCurrentLock) return;
        _autoPromptedForCurrentLock = true;
        await lock.unlock(reason: language.tr('biometric_unlock_reason'));
      });

      return Positioned.fill(
        child: Material(
          color: Colors.black.withOpacity(0.45),
          child: SafeArea(
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 18.w),
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Obx(() {
                  final isUnlocking = lock.isUnlocking.value;
                  final authUnavailable = lock.authUnavailable.value;
                  final lastUnlockFailed = lock.lastUnlockFailed.value;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 44.r,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        language.tr('biometric_locked_title'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        language.tr('biometric_locked_subtitle'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textGrey,
                        ),
                      ),
                      if (lastUnlockFailed) ...[
                        SizedBox(height: 10.h),
                        Text(
                          language.tr('biometric_unlock_failed'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                      SizedBox(height: 14.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              isUnlocking
                                  ? null
                                  : () async {
                                    await lock.unlock(
                                      reason: language.tr(
                                        'biometric_unlock_reason',
                                      ),
                                    );
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.whiteColor,
                            minimumSize: Size(double.infinity, 44.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                          child:
                              isUnlocking
                                  ? SizedBox(
                                    width: 18.r,
                                    height: 18.r,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                            AppColors.whiteColor,
                                          ),
                                    ),
                                  )
                                  : Text(
                                    language.tr('biometric_unlock_button'),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                      if (authUnavailable) ...[
                        SizedBox(height: 10.h),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              await BiometricService.instance
                                  .openDeviceSecuritySettings();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                              minimumSize: Size(double.infinity, 44.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              language.tr('biometric_open_settings'),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await lock.disableAppLock();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: BorderSide(
                                  color: AppColors.icongrey.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                                minimumSize: Size(double.infinity, 44.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                language.tr('biometric_disable_app_lock'),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  final auth = Get.find<AuthController>();
                                  await auth.logoutWithOutApi();
                                } finally {
                                  lock.clearLock();
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.red,
                                side: BorderSide(color: AppColors.red),
                                minimumSize: Size(double.infinity, 44.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                language.tr('biometric_logout'),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      );
    });
  }
}

