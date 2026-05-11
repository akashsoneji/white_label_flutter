import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class LanguageSelectorScreen extends StatefulWidget {
  const LanguageSelectorScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSelectorScreen> createState() => _LanguageSelectorScreenState();
}

class _LanguageSelectorScreenState extends State<LanguageSelectorScreen> {
  final LanguageService _languageService = Get.find<LanguageService>();
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _languageService.currentLanguage.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          _languageService.tr('settings_language_title'),
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: _languageService.getTextDirection(),
        child: Column(
          children: [
            // Language list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // System default option
                  _buildLanguageOption(
                    languageCode: 'system',
                    languageName: _languageService.tr(
                      'settings_language_system',
                    ),
                    isSelected: _selectedLanguage == 'system',
                    onTap: () => _selectLanguage('system'),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Container(height: 1, color: AppColors.border),

                  const SizedBox(height: 16),

                  // Supported languages
                  ..._languageService.getSupportedLanguages().entries.map(
                    (entry) => _buildLanguageOption(
                      languageCode: entry.key,
                      languageName: entry.value,
                      isSelected: _selectedLanguage == entry.key,
                      onTap: () => _selectLanguage(entry.key),
                      isRTL:
                          _languageService.getLanguageInfo(entry.key)['isRTL'],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom section with info
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // RTL info if current language is RTL
                  if (_languageService.isRTL())
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'RTL (Right-to-Left) layout is enabled for this language. The interface will automatically adjust for better readability.',
                              style: AppTextStyles.subheading.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Apply button
                  Padding(
                    padding: EdgeInsets.only(bottom: Get.height * 0.05),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _selectedLanguage != null ? _applyLanguage : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.whiteColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                        child: Text(
                          _languageService.tr('common_apply'),
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.whiteColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String languageCode,
    required String languageName,
    required bool isSelected,
    required VoidCallback onTap,
    bool isRTL = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Language flag/icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _getLanguageFlag(languageCode),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Language info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageName,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isRTL)
                        Text(
                          'RTL Layout',
                          style: AppTextStyles.subheading.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child:   Icon(
                      Icons.check,
                      color: AppColors.whiteColor,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇺🇸';
      case 'ar':
        return '🇸🇦';
      case 'tr':
        return '🇹🇷';
      case 'hi':
        return '🇮🇳';
      case 'es':
        return '🇪🇸';
      case 'system':
        return '⚙️';
      default:
        return '🌐';
    }
  }

  void _selectLanguage(String languageCode) {
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  Future<void> _applyLanguage() async {
    if (_selectedLanguage == null) return;

    try {
      // Show loading indicator
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );

      if (_selectedLanguage == 'system') {
        await _languageService.initializeWithSystemLanguage();
      } else {
        await _languageService.changeLanguage(_selectedLanguage!);
      }

      // Close loading dialog
      Get.back(closeOverlays: true);

      // Show success message
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showSuccess(
          message: 'Language changed successfully',
          title: 'Success',
        );
      }

      // Navigate back
      Get.back(closeOverlays: true);
    } catch (e) {
      // Close loading dialog
      Get.back(closeOverlays: true);

      // Show error message
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to change language: $e',
          title: 'Error',
        );
      }
    }
  }
}

// RTL-aware widget wrapper
class RTLWrapper extends StatelessWidget {
  final Widget child;
  final LanguageService languageService;

  const RTLWrapper({
    Key? key,
    required this.child,
    required this.languageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: languageService.getTextDirection(),
      child: child,
    );
  }
}

// Language info widget
class LanguageInfoWidget extends StatelessWidget {
  final String languageCode;
  final LanguageService languageService;

  const LanguageInfoWidget({
    Key? key,
    required this.languageCode,
    required this.languageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageInfo = languageService.getLanguageInfo(languageCode);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            languageInfo['isRTL']
                ? Icons.arrow_back_ios
                : Icons.arrow_forward_ios,
            color: AppColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            languageInfo['isRTL'] ? 'RTL Layout' : 'LTR Layout',
            style: AppTextStyles.input.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
