import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class IbmApplicationScreen extends StatelessWidget {
  const IbmApplicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        title: Text(
          TranslationUtils.tr('ibm_become_a_partner'),
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handshake, size: 80.w, color: AppColors.primary),
            SizedBox(height: 24.h),
            Text(
              TranslationUtils.tr('ibm_partner_with_us_and_earn'),
              style: AppTextStyles.heading.copyWith(fontSize: 20.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Text(
              TranslationUtils.tr('ibm_submit_request_to_become_partner'),
              style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () {
                  // Implement partner request submission
                  Get.back();
                  Get.snackbar(
                    TranslationUtils.tr('create_account_success'),
                    TranslationUtils.tr('ibm_request_submitted'),
                  );
                },
                child: Text(
                  TranslationUtils.tr('id_upload_screen_submit_request'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.whiteColor,
                    fontWeight: FontWeight.bold,
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
