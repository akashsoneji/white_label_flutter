import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/utils/agreement_launcher.dart';

class GetStartedScreen extends StatelessWidget {
  GetStartedScreen({super.key});
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Container(
                                      height: 110.w,
                                      width: 110.w,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(30),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: EdgeInsets.all(14.w),
                                      child: BrandLogo(
                                        source:
                                            FlavorConfig.instance.appIconPath,
                                        isCircle: true,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                        // child: CircleAvatar(
                        //   child: BrandLogo(
                        //     source: FlavorConfig.instance.appIconPath,
                        //     // color: AppColors.primary,
                        //     height: 100.h,
                        //     width: 180.w,
                        //   ),
                        // ),
                      // ),
                      SizedBox(height: 30.h),
                      Text(
                        languageService.tr("onboarding_slide1_description"),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 50.h),
                      SizedBox(
                        width: double.infinity,
                        height: 46.h,
                        child: ElevatedButton(
                          onPressed: () {
                            Get.toNamed(AppPages.LOGIN);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            languageService.tr("onboarding_get_started"),
                            style: AppTextStyles.button.copyWith(fontSize: 13),
                          ),
                        ),
                      ),
                      SizedBox(height: 15.h),
                      SizedBox(
                        width: double.infinity,
                        height: 46.h,
                        child: OutlinedButton(
                          onPressed: () {
                            Get.toNamed(AppPages.CREATE_ACCOUNT);
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            languageService.tr("register_title"),
                            style: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                  text: "${languageService.tr("register_terms").tr}\n",
                  children: [
                    TextSpan(
                      text:
                          "${languageService.tr("register_terms_condition").tr}",
                      style: AppTextStyles.bodyText.copyWith(
                        decoration: TextDecoration.underline,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              AgreementLauncher.openTerms();
                            },
                    ),
                    TextSpan(
                      text: " ${languageService.tr("common_and")} ",
                    ),
                    TextSpan(
                      text: "${languageService.tr("privacy_policy_title").tr}",
                      style: AppTextStyles.bodyText.copyWith(
                        decoration: TextDecoration.underline,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              AgreementLauncher.openPrivacy();
                            },
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
