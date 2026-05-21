import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/screens/common/webview_screen.dart';
import 'package:crm_app/services/crm_settings_service.dart';
import 'package:crm_app/services/language_service.dart';

/// Opens Terms, Privacy, or IB agreements from CRM settings API with fallbacks.
class AgreementLauncher {
  AgreementLauncher._();

  static const String termsKey = 'terms_conditions';
  static const String privacyKey = 'privacy_policy';
  static const String ibTermsKey = 'ib_terms';

  static Future<void> openTerms() => _open(
        agreementKey: termsKey,
        fallbackTitleKey: 'register_terms_condition',
      );

  static Future<void> openPrivacy() => _open(
        agreementKey: privacyKey,
        fallbackTitleKey: 'privacy_policy_title',
      );

  static Future<void> openIbTerms() => _open(
        agreementKey: ibTermsKey,
        fallbackTitleKey: 'terms_conditions',
      );

  static Future<void> _open({
    required String agreementKey,
    required String fallbackTitleKey,
  }) async {
    final languageService = Get.find<LanguageService>();
    final title = languageService.tr(fallbackTitleKey);

    if (Get.isRegistered<CrmSettingsService>()) {
      final crmService = Get.find<CrmSettingsService>();
      if (crmService.current == null) {
        await crmService.fetchCrmSettings();
      }
      final agreement = crmService.agreementFor(agreementKey);
      if (agreement != null && (agreement.canOpen || agreement.hasUrl)) {
        await _openUrl(
          agreement.url,
          agreement.label.isNotEmpty ? agreement.label : title,
        );
        return;
      }
    }

    await _handleUnavailableFallback(
      agreementKey: agreementKey,
      title: title,
      languageService: languageService,
    );
  }

  static Future<void> _handleUnavailableFallback({
    required String agreementKey,
    required String title,
    required LanguageService languageService,
  }) async {
    if (agreementKey == privacyKey) {
      Get.toNamed(AppPages.PRIVACY_POLICY);
      return;
    }

    _showInAppNotice(
      title: title,
      message: languageService.tr('agreement_document_unavailable'),
    );
  }

  static void _showInAppNotice({
    required String title,
    required String message,
  }) {
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showInfo(
        title: title,
        message: message,
      );
    }
  }

  static Future<void> _openUrl(String url, String title) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      await Get.to(
        () => WebViewScreen(url: trimmed, title: title),
        transition: Transition.rightToLeft,
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
