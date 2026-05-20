import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import '../auth_screen_theme.dart';
import 'package:crm_app/services/language_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthScreenTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text(Get.find<LanguageService>().tr('privacy_policy_title')),
        backgroundColor: AuthScreenTheme.scaffoldBackground,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: FlavorConfig.isVantage() ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'This is a placeholder for the privacy policy content. You can replace this with your actual privacy policy text.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

