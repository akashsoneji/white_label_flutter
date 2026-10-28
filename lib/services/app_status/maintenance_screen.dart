import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/app_status/app_status_controller.dart';
import 'package:crm_app/services/language_service.dart';

/// Full-screen maintenance mode widget
/// Shows when app is under maintenance
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppStatusController>();

    return Container(
      color: AppColors.whiteColor,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Maintenance Icon
              Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.build_circle,
                  size: 80.w,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 32.h),

              // Title
              Text(
                TranslationUtils.tr('maintenance_under_maintenance'),
                style: AppTextStyles.heading.copyWith(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),

              // Admin's portal maintenance message, else the default text.
              Obx(() {
                final adminMessage = controller.maintenanceMessage.value;
                return Text(
                  adminMessage.isNotEmpty
                      ? adminMessage
                      : TranslationUtils.tr('maintenance_message'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                );
              }),
              SizedBox(height: 48.h),

              // Retry Button
              Obx(() {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isChecking.value
                        ? null
                        : () {
                            controller.checkStatus();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    child: controller.isChecking.value
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.whiteColor,
                              ),
                            ),
                          )
                        : Text(
                            TranslationUtils.tr('common_retry'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.whiteColor,
                            ),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
