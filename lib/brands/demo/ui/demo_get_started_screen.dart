import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/color.dart';
import '../../../routes/app_pages.dart';
import '../../../services/language_service.dart';

/// Demo brand version of GetStarted to validate brand switching.
/// Replace with full design when adding a real flavor.
class DemoGetStartedScreen extends StatelessWidget {
  DemoGetStartedScreen({super.key});

  final LanguageService _languageService = Get.find<LanguageService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary.withValues(alpha: 0.06),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'DEMO BRAND',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _languageService.tr("onboarding_slide1_description"),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Get.toNamed(AppPages.LOGIN),
                  child: Text(_languageService.tr("onboarding_get_started")),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Get.toNamed(AppPages.CREATE_ACCOUNT),
                  child: Text(_languageService.tr("register_title")),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

