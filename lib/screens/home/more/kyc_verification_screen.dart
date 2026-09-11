import 'dart:ui';
import 'package:crm_app/constants/text_styles.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/app_back_button.dart';

import 'package:crm_app/screens/kyc/view_models/kyc_controller.dart';
import '../../../services/language_service.dart';

class KycVerificationScreen extends StatelessWidget {
  const KycVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(KYCController());
    final isTablet = MediaQuery.of(context).size.width > 600;
    final languageService = Get.find<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Obx(
        () => Stack(
          children: [
            // Main content
            _buildMainContent(controller, isTablet, languageService),
            // Bottom sheet overlay
            if (controller.showBottomSheet.value)
              _buildBottomSheetOverlay(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    KYCController controller,
    bool isTablet,
    LanguageService languageService,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          // App Bar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(Get.context!).padding.top,
              left: isTablet ? 32.0 : 16.0,
              right: isTablet ? 32.0 : 16.0,
              bottom: 16.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const AppBackButton(),

                Expanded(
                  child: Text(
                    languageService.tr('kyc_verification'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 48), // Balance the back button
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 64.0 : 24.0,
                ),
                child: Column(
                  children: [
                    SizedBox(height: isTablet ? 80 : 60),

                    // Illustration
                    _buildIllustration(),

                    SizedBox(height: isTablet ? 60 : 40),

                    // Title
                    Text(
                      languageService.tr(
                        'kyc_verification_first_lets_know_you',
                      ),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: isTablet ? 32 : 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),

                    SizedBox(height: isTablet ? 32 : 24),

                    // Subtitle
                    Text(
                      languageService.tr('kyc_verification_prepare_documents'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: isTablet ? 18 : 16,
                        color: AppColors.textGrey,
                        height: 1.4,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      languageService.tr('kyc_verification_document_types'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    SizedBox(
                      height: isTablet ? Get.height * 0.42 : Get.height * 0.22,
                    ),

                    // Choose Document Button
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: double.infinity,
                        height: isTablet ? 60 : 56,
                        child: ElevatedButton(
                          onPressed: controller.showDocumentSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.whiteColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            languageService.tr(
                              'kyc_verification_choose_document',
                            ),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 40 : 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      width: 200,
      height: 180,
      child: Stack(
        children: [
          // Documents stack
          Positioned(left: 20, top: 20, child: _buildDocumentStack()),

          // Character
          Positioned(right: 0, bottom: 0, child: _buildCharacter()),
        ],
      ),
    );
  }

  Widget _buildDocumentStack() {
    return SizedBox(
      width: 120,
      height: 140,
      child: Stack(
        children: [
          // Back document
          Positioned(
            left: 20,
            top: 0,
            child: _buildDocument(AppColors.border),
          ),

          // Middle document
          Positioned(
            left: 10,
            top: 10,
            child: _buildDocument(AppColors.border.withOpacity(0.7)),
          ),

          // Front document with purple section
          Positioned(
            left: 0,
            top: 20,
            child: _buildDocument(AppColors.whiteColor, hasPurpleSection: true),
          ),
        ],
      ),
    );
  }

  Widget _buildDocument(
    Color backgroundColor, {
    bool hasPurpleSection = false,
  }) {
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header lines
          Container(
            margin: EdgeInsets.all(8),
            child: Column(
              children: [
                Container(
                  height: 3,
                  width: double.infinity,
                  color: Colors.grey[400],
                  margin: EdgeInsets.only(bottom: 4),
                ),
                Container(
                  height: 2,
                  width: 40,
                  color: Colors.grey[400],
                  margin: EdgeInsets.only(bottom: 4),
                ),
                Container(height: 2, width: 50, color: Colors.grey[400]),
              ],
            ),
          ),

          // Purple section for front document
          if (hasPurpleSection)
            Expanded(
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(8, 4, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacter() {
    return SizedBox(
      width: 80,
      height: 100,
      child: Stack(
        children: [
          // Body
          Positioned(
            bottom: 0,
            left: 25,
            child: Container(
              width: 30,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
            ),
          ),

          // Head
          Positioned(
            top: 10,
            left: 30,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Hair
          Positioned(
            top: 8,
            left: 32,
            child: Container(
              width: 25,
              height: 15,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Arms
          Positioned(
            top: 35,
            left: 15,
            child: Container(
              width: 45,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Legs
          Positioned(
            bottom: 0,
            left: 20,
            child: Container(width: 8, height: 20, color: Colors.black87),
          ),
          Positioned(
            bottom: 0,
            right: 20,
            child: Container(width: 8, height: 20, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetOverlay(KYCController controller) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: GestureDetector(
              onTap: controller.hideDocumentSelection,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSheet(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(KYCController controller) {
    return AnimatedSlide(
      offset:
          controller.showBottomSheet.value ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        decoration:   BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Text(
                    TranslationUtils.tr(
                      'kyc_verification_choose_document_type',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    TranslationUtils.tr('kyc_verification_face_picture_note'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Document options
            ...controller.documentTypes
                .map((document) => _buildDocumentOption(document, controller))
                .toList(),

            // Bottom padding
            SizedBox(height: MediaQuery.of(Get.context!).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentOption(DocumentType document, KYCController controller) {
    return GestureDetector(
      onTap: () => controller.selectDocument(document),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: document.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(document.icon, color: document.iconColor, size: 24),
            ),

            SizedBox(width: 16),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    document.subtitle,
                    style: AppTextStyles.bodyText.copyWith(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Arrow icon
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
