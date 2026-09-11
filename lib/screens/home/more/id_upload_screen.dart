import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'dart:io';
import 'package:crm_app/widgets/app_back_button.dart';

import 'package:crm_app/screens/kyc/view_models/id_scanner_controller.dart';
import '../../../services/language_service.dart';

class IdUploadScreen extends StatelessWidget {
  final IdScannerController controller = Get.put(IdScannerController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          TranslationUtils.tr('id_upload_screen_id_aadhar_card'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr(
                'id_upload_screen_the_document_you_are_providing_must',
              ),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14,
                color: AppColors.textGrey,
                height: 1.5,
              ),
            ),
            SizedBox(height: 40),

            // Front Side Card
            Obx(
              () => _buildImageCard(
                title: Get.find<LanguageService>().tr('id_upload_front_side'),
                imagePath: controller.frontImagePath.value,
                onTap: controller.setCameraForFrontSide,
              ),
            ),

            SizedBox(height: 20),

            // Back Side Card
            Obx(
              () => _buildImageCard(
                title: Get.find<LanguageService>().tr('id_upload_back_side'),
                imagePath: controller.backImagePath.value,
                onTap: controller.setCameraForBackSide,
              ),
            ),

            SizedBox(height: 30),

            // Guidelines
            _buildGuideline(
              icon: Icons.check_circle,
              text: TranslationUtils.tr('id_upload_screen_guideline_upload'),
              isPositive: true,
            ),

            SizedBox(height: 12),

            _buildGuideline(
              icon: Icons.cancel,
              text: TranslationUtils.tr('id_upload_screen_guideline_no_selfies'),
              isPositive: false,
            ),

            Spacer(),

            // Submit Button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  TranslationUtils.tr('id_upload_screen_submit_request'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard({
    required String title,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child:
            imagePath.isEmpty
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: AppColors.icongrey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      title,
                      style: AppTextStyles.bodyText.copyWith(fontSize: 14, color: AppColors.textGrey),
                    ),
                  ],
                )
                : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.file(
                        File(imagePath),
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            title,
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.whiteColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildGuideline({
    required IconData icon,
    required String text,
    required bool isPositive,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: isPositive ? Colors.green : Colors.red, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
