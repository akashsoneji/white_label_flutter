import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';

class TradeWinRedemptionSuccessScreen extends StatelessWidget {
  const TradeWinRedemptionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final productName = args['productName']?.toString() ?? '';
    final reference = args['reference']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.tradeWinScaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.check_circle, size: 88.sp, color: AppColors.green),
              SizedBox(height: 20.h),
              Text(
                languageService.tr('tw_redemption_successful'),
                style: AppTextStyles.centerbodyHeading.copyWith(
                  color: AppColors.green,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text.rich(
                TextSpan(
                  text: languageService.tr('tw_item_being_processed_prefix'),
                  style: AppTextStyles.subheading,
                  children: [
                    TextSpan(
                      text: productName,
                      style: AppTextStyles.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: languageService.tr(
                        'tw_item_being_processed_suffix',
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.icongrey.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      languageService.tr('tw_reference_number'),
                      style: AppTextStyles.subheading,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      reference,
                      style: AppTextStyles.centerbodyHeading.copyWith(
                        color: AppColors.primary,
                        fontSize: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                languageService.tr('tw_status_update_note'),
                style: AppTextStyles.subheading,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: Builder(
                  builder: (context) {
                    final btnTextColor = ThemeData.estimateBrightnessForColor(AppColors.primary) == Brightness.light
                        ? Colors.black
                        : Colors.white;
                    return ElevatedButton(
                      onPressed: () {
                        Get.until(
                          (route) => route.settings.name == AppPages.TRADE_WIN_MAIN,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: btnTextColor,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide.none,
                        ),
                      ),
                      child: Text(
                        languageService.tr('tw_done'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                          color: btnTextColor,
                        ),
                      ),
                    );
                  }
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
