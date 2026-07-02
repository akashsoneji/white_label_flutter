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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: BrandLogo(
                          source: FlavorConfig.effectiveLogo,
                          // color: AppColors.primary,
                          height: 100.h,
                          width: 180.w,
                        ),
                      ),
                      SizedBox(height: 30.h),
                      Text(
                        languageService.tr("onboarding_slide1_description"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                            style: TextStyle(color: AppColors.primary),
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(color: AppColors.textGrey),
                  text: "${languageService.tr("register_terms").tr}\n",
                  children: [
                    TextSpan(
                      text:
                          "${languageService.tr("register_terms_condition").tr}",
                      style: TextStyle(
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
                    const TextSpan(text: " and "),
                    TextSpan(
                      text: "${languageService.tr("privacy_policy_title").tr}",
                      style: TextStyle(
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
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
