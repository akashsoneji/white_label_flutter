import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/api_service.dart';

/// Opens the broker's live chat (GET user/live-chat). When the broker has a
/// provider URL configured it is opened in an in-app browser; otherwise the
/// built-in Chat With Us screen is used, as before.
class LiveChatService {
  LiveChatService._();

  static bool _isOpening = false;

  static Future<void> open() async {
    if (_isOpening) return;
    _isOpening = true;
    try {
      final url = await _configuredUrl();
      if (url != null &&
          await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
        return;
      }
      Get.toNamed(AppPages.CHAT_WITH_US);
    } finally {
      _isOpening = false;
    }
  }

  static Future<Uri?> _configuredUrl() async {
    try {
      final response = await ApiService.get(endpoint: ApiConstants.liveChatConfig);
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      if (!response.success || data is! Map<String, dynamic>) return null;
      if (data['enabled'] != true) return null;
      final uri = Uri.tryParse(data['url']?.toString().trim() ?? '');
      if (uri == null || !uri.hasScheme) return null;
      return uri;
    } catch (e) {
      debugPrint('LiveChatService: failed to load live chat config: $e');
      return null;
    }
  }
}
