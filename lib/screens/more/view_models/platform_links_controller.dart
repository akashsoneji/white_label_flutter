import 'package:get/get.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/crm_settings_service.dart';
import 'package:crm_app/services/language_service.dart';

/// A trading-platform download link (GET user/platform-links).
class PlatformLink {
  /// Synthetic entry for the admin's custom web terminal
  /// (`crm-settings.trading_settings.web_trading_custom_url`).
  static const webTradingSlug = 'web_trading_custom';

  final String slug;
  final String name;
  final String description;
  final String imageUrl;
  final String url;
  final int sortOrder;

  const PlatformLink({
    required this.slug,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.url,
    this.sortOrder = 0,
  });

  factory PlatformLink.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key]?.toString().trim() ?? '';
    return PlatformLink(
      slug: read('slug'),
      name: read('name'),
      description: read('description'),
      imageUrl: read('image_url'),
      url: read('url'),
      sortOrder: int.tryParse(read('sort_order')) ?? 0,
    );
  }
}

class PlatformLinksController extends GetxController {
  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final links = <PlatformLink>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadLinks();
  }

  Future<void> loadLinks() async {
    isLoading(true);
    errorMessage('');
    try {
      final response = await ApiService.get(endpoint: ApiConstants.platformLinks);
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      final raw = data is Map ? data['platform_links'] : null;
      if (!response.success || raw is! List) {
        errorMessage(
          response.message?.isNotEmpty == true
              ? response.message!
              : TranslationUtils.tr('platforms_load_failed'),
        );
        return;
      }
      // An empty url means the broker has not configured that platform.
      final configured = raw
          .whereType<Map>()
          .map((e) => PlatformLink.fromJson(e.cast<String, dynamic>()))
          .where((link) => link.url.isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      links.assignAll(_applyTradingSettings(configured));
    } catch (_) {
      errorMessage(TranslationUtils.tr('platforms_load_failed'));
    } finally {
      isLoading(false);
    }
  }

  /// `trading_settings`: web trading off hides the web terminal links; in
  /// "custom" mode the admin's URL is offered first (opened in a WebView).
  /// The native in-app terminal is the app itself and is never hidden.
  List<PlatformLink> _applyTradingSettings(List<PlatformLink> configured) {
    if (!Get.isRegistered<CrmSettingsService>()) return configured;
    final trading = Get.find<CrmSettingsService>().current?.tradingSettings;
    if (trading == null) return configured;
    if (!trading.webTradingEnabled) {
      return configured
          .where((link) => !_isWebTerminal(link.slug))
          .toList();
    }
    if (trading.usesInAppTerminal || trading.webTradingCustomUrl.isEmpty) {
      return configured;
    }
    return [
      PlatformLink(
        slug: PlatformLink.webTradingSlug,
        name: TranslationUtils.tr('platforms_web_trading'),
        description: '',
        imageUrl: '',
        url: trading.webTradingCustomUrl,
      ),
      ...configured,
    ];
  }

  bool _isWebTerminal(String slug) {
    final normalized = slug.toLowerCase();
    return normalized == 'web' ||
        normalized == 'webtrader' ||
        normalized == 'web_trader';
  }
}
