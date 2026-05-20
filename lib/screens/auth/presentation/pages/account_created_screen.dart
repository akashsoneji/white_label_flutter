import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import '../auth_screen_theme.dart';
import '../brands/vantage/widgets/vantage_auth_scaffold.dart';
import '../brands/vantage/widgets/vantage_controls.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';

class AccountCreatedScreen extends StatelessWidget {
  AccountCreatedScreen({super.key});
  final AuthController authController = Get.find<AuthController>();
  final LanguageService languageService = Get.find<LanguageService>();

  Widget _buildBody() {
    return Column(
      children: [
        SizedBox(height: 40.h),
        _buildSuccessIcon(),
        SizedBox(height: 24.h),
        _buildWelcomeMessage(),
        SizedBox(height: 32.h),
        _buildCallToAction(),
        SizedBox(height: 24.h),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FlavorConfig.isVantage()) {
      return VantageAuthScaffold(
        showBack: false,
        child: _buildBody(),
      );
    }

    return Scaffold(
      backgroundColor: AuthScreenTheme.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        children: [
          Container(height: 40.h, width: 40.w),
          SizedBox(width: 16.w),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _progressBar(active: true),
                SizedBox(width: 8.w),
                _progressBar(active: true),
                SizedBox(width: 8.w),
                _progressBar(active: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar({bool active = false}) {
    return Container(
      width: 60.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.border,
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      height: 130.w,
      width: 130.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.whiteColor,
        border: Border.all(color: AppColors.success, width: 2.5),
      ),
      child: Icon(
        Icons.check_rounded,
        color: AppColors.success,
        size: 72.sp,
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Column(
      children: [
        Text(
          "Welcome to ${FlavorConfig.appNameDisplay}",
          style: AppTextStyles.heading.copyWith(
            fontSize: 28.sp,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12.h),
        Text(
          languageService.tr("onboarding_slide3_subtitle"),
          style: TextStyle(
            fontSize: 16.sp,
            color: AppColors.textGrey,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCallToAction() {
    if (FlavorConfig.isVantage()) {
      return Column(
        children: [
          Text(
            languageService.tr("common_to_start_trading"),
            style: TextStyle(
              fontSize: 16.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          VantagePrimaryButton(
            text: 'Create Trading Account',
            onPressed: () {
              Get.toNamed(
                AppPages.CHOOSE_ACCOUNT,
                arguments: {'from': 'account_created'},
              );
            },
          ),
          SizedBox(height: 12.h),
          VantageOutlinedButton(
            text: languageService.tr("common_skip_for_now"),
            onPressed: () => Get.offAllNamed(AppPages.TRADING),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          languageService.tr("common_to_start_trading"),
          style: TextStyle(
            fontSize: 16.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 20.h),
        SizedBox(
          height: 46.h,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Get.toNamed(
                AppPages.CHOOSE_ACCOUNT,
                arguments: {'from': 'account_created'},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text("Create Trading Account", style: AppTextStyles.button),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 46.h,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Get.offAllNamed(AppPages.TRADING),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              languageService.tr("common_skip_for_now"),
              style: AppTextStyles.button.copyWith(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

