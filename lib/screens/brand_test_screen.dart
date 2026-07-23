import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/color.dart';
import '../../constants/text_styles.dart';
import '../../flavor_config.dart';
import '../../brand_switcher.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class BrandTestScreen extends StatelessWidget {
  const BrandTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('🎨 ${FlavorConfig.instance.appName} Brand Test'),
        backgroundColor: FlavorConfig.instance.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Brand Info
            Card(
              color: FlavorConfig.instance.primaryColor,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Current Brand: ${FlavorConfig.instance.appName}',
                      style:   AppTextStyles.bodyText.copyWith(
                        color: AppColors.whiteColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'App Title: ${FlavorConfig.instance.appTitle}',
                      style:   AppTextStyles.bodyText.copyWith(color: AppColors.whiteColor),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Color Samples
            Text(
              '🎨 Brand Colors:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),

            // Primary Color
            _buildColorSample(
              'Primary Color',
              FlavorConfig.instance.primaryColor,
              'Used for buttons, app bar, etc.',
            ),

            // Secondary Color
            _buildColorSample(
              'Secondary Color',
              FlavorConfig.instance.secondaryColor,
              'Used for backgrounds, cards, etc.',
            ),

            // Accent Color
            _buildColorSample(
              'Accent Color',
              FlavorConfig.instance.accentColor,
              'Used for highlights, links, etc.',
            ),

            SizedBox(height: 30),

            // Brand Switching Buttons
            Text(
              '🔄 Switch Brands:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  BrandSwitcher.switchToTenax();
                  if (Get.isRegistered<AppNotificationController>()) {
                    Get.find<AppNotificationController>().showSuccess(
                      message: 'Tenax active',
                      title: 'Brand',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlavorConfig.instance.primaryColor,
                  foregroundColor: AppColors.whiteColor,
                ),
                child: Text('Tenax'),
              ),
            ),

            SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  BrandSwitcher.quickSwitchBrand();
                  if (Get.isRegistered<AppNotificationController>()) {
                    Get.find<AppNotificationController>().showSuccess(
                      message: 'Tenax-only: no other brands',
                      title: 'Brand',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlavorConfig.instance.primaryColor,
                  foregroundColor: AppColors.whiteColor,
                ),
                child: Text('🔄 Quick Switch to Next Brand'),
              ),
            ),

            SizedBox(height: 20),

            // Test using AppColors
            Text(
              '🧪 Testing AppColors:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This uses AppColors.primary - should match brand color!',
                style:   AppTextStyles.bodyText.copyWith(
                  color: AppColors.whiteColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSample(String name, Color color, String description) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.cardTitle,
                  ),
                  Text(
                    '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    description,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
