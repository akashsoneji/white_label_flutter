import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/app_status/app_status_controller.dart';
import 'package:crm_app/widgets/brand_logo.dart';

/// App update dialog widget
/// Shows when app version doesn't match API version
class ForceUpdateDialog extends StatelessWidget {
  final bool isForceUpdate;

  const ForceUpdateDialog({super.key, required this.isForceUpdate});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppStatusController>();
    final releaseNotes = controller.statusData.value?.releaseNotes;
    final latestVersion =
        controller.statusData.value?.appVersion ??
        controller.latestVersion.value;

    return WillPopScope(
      onWillPop: () async {
        // Prevent closing if it's a forced update
        return !isForceUpdate;
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 24.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16.r,
                  offset: const Offset(0.0, 8.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Keep card compact
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // App Logo mapping mult-broker and flavors
                BrandLogo(
                  source: FlavorConfig.effectiveLogo,
                  height: 64.w,
                  width: 64.w,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 20.h),

                // Title
                Text(
                  "Update Available",
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),

                // Subtitle
                Text(
                  "Version $latestVersion is now available.\nYou're currently using an older version of ${FlavorConfig.appNameDisplay}.",
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),

                // Release Notes (If available)
                if (releaseNotes != null && releaseNotes.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppColors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      releaseNotes,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textPrimary.withOpacity(0.8),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],

                // Buttons
                Row(
                  children: [
                    if (!isForceUpdate) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            controller.skipUpdateFor24Hours();
                            Get.back(closeOverlays: true);
                            controller.resetForceUpdateDialogFlag();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            "Later",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          controller.openAppStore();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          "Update Now",
                          style: TextStyle(
                            color: AppColors.whiteColor,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
