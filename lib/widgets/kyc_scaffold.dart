import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

import '../routes/app_pages.dart';

class KycScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final VoidCallback? onClose;

  const KycScaffold({Key? key, required this.body, this.title, this.onClose})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable back navigation
      child: Scaffold(
        backgroundColor: AppColors.whiteColor,
        appBar: AppBar(
          backgroundColor: AppColors.whiteColor,
          scrolledUnderElevation: 0,
          elevation: 0,
          automaticallyImplyLeading: false, // No back arrow
          title: Text(
            title ?? 'Verify your account',
            style: AppTextStyles.heading,
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Container(
                width: 24.w,
                height: 24.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary),
                ),
                child: Icon(
                  Icons.close,
                  size: 20.w,
                  color: AppColors.textPrimary,
                ),
              ),
              onPressed: onClose ?? _showExitConfirmation,
            ),
          ],
          shape: Border(bottom: BorderSide(color: AppColors.grey)),
        ),
        body: body,
      ),
    );
  }

  void _showExitConfirmation() {
    Get.dialog(
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(Get.context!).size.width * 0.9,
          maxHeight: MediaQuery.of(Get.context!).size.height * 0.6,
        ),
        child: AlertDialog(
          backgroundColor: AppColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    width: 24.w,
                    height: 24.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.icongrey),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16.w,
                      color: AppColors.icongrey,
                    ),
                  ),
                ),
              ),

              SvgPicture.asset(
                'assets/svg/kyc/personalcard.svg',
                height: 60.h,
                width: 60.w,
                color: AppColors.primary,
              ),
              SizedBox(height: 20.h, width: 20.w),
              Text('Verify Later?', style: AppTextStyles.black16600),
            ],
          ),
          content: Text(
            'You can continue later, but you won\'t get all benefits until verification is complete',
            style: AppTextStyles.grey14400h57,
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              // Removed mainAxisAlignment: MainAxisAlignment.spaceBetween to avoid overflow
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Get.back(closeOverlays: true); // Close dialog
                      // Get.offAllNamed('/more'); // Navigate to more screen
                      Get.offAllNamed(Routes.TRADING);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withAlpha(
                        20,
                      ), // Light purple
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Verify\nLater',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, // Light purple
                      foregroundColor: AppColors.whiteColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      elevation: 0,
                    ),
                    child: Text(
                      textAlign: TextAlign.center,
                      'Continue Verification',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Exit button (left) - light purple background, dark purple text
          ],
        ),
      ),
    );
  }
}
