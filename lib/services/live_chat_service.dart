import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/common/webview_screen.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';

/// `GET user/live-chat` → `data`. The broker turns live chat on/off and sets
/// the provider link (e.g. tawk) and the menu label from the admin panel.
class LiveChatConfig {
  final bool enabled;
  final String provider;
  final Uri? url;
  final String label;

  const LiveChatConfig({
    required this.enabled,
    required this.provider,
    required this.url,
    required this.label,
  });

  factory LiveChatConfig.fromJson(Map<String, dynamic> json) {
    final uri = Uri.tryParse(json['url']?.toString().trim() ?? '');
    return LiveChatConfig(
      enabled: json['enabled'] == true,
      provider: json['provider']?.toString() ?? '',
      url: uri != null && uri.hasScheme ? uri : null,
      label: json['label']?.toString().trim() ?? '',
    );
  }
}

/// Opens the broker's live chat (GET user/live-chat). When the broker has a
/// provider URL configured it is opened in an in-app WebView screen;
/// otherwise the built-in Chat With Us screen is used, as before.
class LiveChatService {
  LiveChatService._();

  /// Last config from the server; `null` until [load] succeeds. Menus watch
  /// this to show the Live Chat entry only when the broker enabled it.
  static final Rxn<LiveChatConfig> config = Rxn<LiveChatConfig>();

  static bool _isOpening = false;
  static bool _isLoading = false;

  static bool get isEnabled => config.value?.enabled ?? false;

  static Future<LiveChatConfig?> load() async {
    if (_isLoading) return config.value;
    _isLoading = true;
    try {
      final response = await ApiService.get(endpoint: ApiConstants.liveChatConfig);
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      if (response.success && data is Map<String, dynamic>) {
        config.value = LiveChatConfig.fromJson(data);
      }
    } catch (e) {
      debugPrint('LiveChatService: failed to load live chat config: $e');
    } finally {
      _isLoading = false;
    }
    return config.value;
  }

  static Future<void> open() async {
    if (_isOpening) return;
    _isOpening = true;
    try {
      final current = config.value ?? await load();
      final url = current?.enabled == true ? current?.url : null;
      if (url == null) {
        Get.toNamed(AppPages.CHAT_WITH_US);
        return;
      }
      Get.to(
        () => WebViewScreen(
          url: url.toString(),
          title: current!.label.isNotEmpty
              ? current.label
              : Get.find<LanguageService>().tr('live_chat'),
          attachAuthToken: false,
        ),
      );
    } finally {
      _isOpening = false;
    }
  }
}
