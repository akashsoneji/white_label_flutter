import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/trading/view_models/chart_controller.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';

class SoundTestWidget extends StatelessWidget {
  const SoundTestWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('Sound Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Test Audio Playback',
              style: AppTextStyles.bodyText.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30),

            // Test No Money Sound Button
            ElevatedButton(
              onPressed: () async {
                try {
                  final controller = Get.put(ChartController());
                  await controller.testNoMoneySound();

                  // Show success message
                  if (Get.isRegistered<AppNotificationController>()) {
                    Get.find<AppNotificationController>().showSuccess(
                      message: 'No Money Sound Test Completed',
                    );
                  }
                } catch (e) {
                  // Show error message
                  if (Get.isRegistered<AppNotificationController>()) {
                    Get.find<AppNotificationController>().showError(
                      message: 'Error: $e',
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child:   Text(
                'Test No Money Sound',
                style: AppTextStyles.bodyText.copyWith(fontSize: 18, color: AppColors.whiteColor),
              ),
            ),

            SizedBox(height: 20),

            // Instructions
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: AppTextStyles.bodyText.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('1. Make sure your device volume is turned up'),
                    Text('2. Click the button above to test the sound'),
                    Text('3. Check the console logs for debug information'),
                    Text(
                      '4. The sound should play when you get "Not enough money" error',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
