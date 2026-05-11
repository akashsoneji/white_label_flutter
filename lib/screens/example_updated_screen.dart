import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart' show TranslationUtils;
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/utils/rtl_wrapper.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';

/// Example of how to update an existing screen to use the new translation system
class ExampleUpdatedScreen extends StatelessWidget {
  const ExampleUpdatedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RTLWrapper(
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundLight,
          elevation: 0,
          leading: IconButton(
            icon: RTLIcon(
              icon: Icons.arrow_back_ios,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Get.back(closeOverlays: true),
          ),
          title: RTLText(
            text: TranslationUtils.tr('example_screen_title'),
            style: AppTextStyles.heading.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              _buildWelcomeSection(),

              const SizedBox(height: 24),

              // Form section
              _buildFormSection(),

              const SizedBox(height: 24),

              // Actions section
              _buildActionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RTLText(
            text: TranslationUtils.tr('welcome_title'),
            style: AppTextStyles.heading.copyWith(
              color: AppColors.primary,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          RTLText(
            text: TranslationUtils.tr('welcome_subtitle'),
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RTLText(
          text: TranslationUtils.tr('form_section_title'),
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),

        // Email field
        RTLContainer(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RTLText(
                text: TranslationUtils.tr('email_label'),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: TranslationUtils.tr('email_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Password field
        RTLContainer(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RTLText(
                text: TranslationUtils.tr('password_label'),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  hintText: TranslationUtils.tr('password_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RTLText(
          text: TranslationUtils.tr('actions_section_title'),
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),

        // Primary action button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _handlePrimaryAction(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.whiteColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: RTLText(
              text: TranslationUtils.tr('primary_action_button'),
              style: AppTextStyles.button.copyWith(
                color: AppColors.whiteColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary action button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => _handleSecondaryAction(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: RTLText(
              text: TranslationUtils.tr('secondary_action_button'),
              style: AppTextStyles.button.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Info text with arguments
        RTLContainer(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: RTLText(
            text: TranslationUtils.trArgs('info_text_with_args', {
              'count': '5',
              'type': 'items',
            }),
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _handlePrimaryAction() {
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showSuccess(
        message: TranslationUtils.tr('primary_action_success'),
        title: TranslationUtils.tr('success_title'),
      );
    }
  }

  void _handleSecondaryAction() {
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showInfo(
        message: TranslationUtils.tr('secondary_action_info'),
        title: TranslationUtils.tr('info_title'),
      );
    }
  }
}
