import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../widgets/vantage_auth_theme.dart';
import '../widgets/vantage_controls.dart';

class VantageGetStartedScreen extends StatelessWidget {
  VantageGetStartedScreen({super.key});

  final LanguageService languageService = Get.find<LanguageService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [VantageAuthTheme.primary, VantageAuthTheme.background],
            stops: const [0.0, 0.9],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Center(
                  child: BrandLogo(
                    source: FlavorConfig.effectiveLogo,
                    height: 84.w,
                    width: 84.w,
                    fit: BoxFit.contain,
                    isCircle: true,
                  ),
                ),
                SizedBox(height: 18.h),
                // Text(
                //   FlavorConfig.instance.appName,
                //   style: TextStyle(
                //     color: Colors.white,
                //     fontSize: 34.sp,
                //     fontWeight: FontWeight.w800,
                //     letterSpacing: 0.4,
                //   ),
                // ),
                // SizedBox(height: 10.h),
                Text(
                  languageService.tr('get_started_tagline'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 3),
                VantagePrimaryButton(
                  text: languageService.tr('login_button'),
                  onPressed: () => Get.toNamed(AppPages.LOGIN),
                ),
                SizedBox(height: 14.h),
                VantageOutlinedButton(
                  text: languageService.tr('register_title'),
                  onPressed: () => Get.toNamed(AppPages.CREATE_ACCOUNT),
                ),
                SizedBox(height: 18.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
