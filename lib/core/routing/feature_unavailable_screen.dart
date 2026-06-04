import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/color.dart';
import '../../services/language_service.dart';
import '../../widgets/app_back_button.dart';

class FeatureUnavailableScreen extends StatelessWidget {
  static const String routeName = '/feature-unavailable';

  const FeatureUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final args = (Get.arguments is Map) ? (Get.arguments as Map) : <dynamic, dynamic>{};
    final featureKey = (args['featureKey'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(languageService.tr('general_not_available')),
        backgroundColor: AppColors.whiteColor,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: AppColors.textGrey),
              const SizedBox(height: 12),
              Text(
                languageService.tr('general_feature_not_available'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              if (featureKey.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  featureKey,
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: Text(languageService.tr('navigation_ok')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
