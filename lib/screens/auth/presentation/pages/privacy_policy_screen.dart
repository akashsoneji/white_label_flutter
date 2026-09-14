import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import '../auth_screen_theme.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthScreenTheme.scaffoldBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(Get.find<LanguageService>().tr('privacy_policy_title')),
        backgroundColor: AuthScreenTheme.scaffoldBackground,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: FlavorConfig.isVantage() ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Get.find<LanguageService>().tr('create_account_privacy_policy'),
                style: AppTextStyles.bodyText.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                Get.find<LanguageService>().tr(
                  'privacy_policy_screen_this_is_placeholder_for_the_privacy',
                ),
                style: AppTextStyles.bodyText.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

