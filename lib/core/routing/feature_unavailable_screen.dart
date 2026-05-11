import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/color.dart';
import '../../services/language_service.dart';

class FeatureUnavailableScreen extends StatelessWidget {
  static const String routeName = '/feature-unavailable';

  const FeatureUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final args = (Get.arguments is Map) ? (Get.arguments as Map) : <dynamic, dynamic>{};
    final featureKey = (args['featureKey'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(languageService.tr('general_not_available')),
        backgroundColor: AppColors.whiteColor,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                languageService.tr('general_feature_not_available'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (featureKey.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  featureKey,
                  style: const TextStyle(color: Colors.grey),
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

