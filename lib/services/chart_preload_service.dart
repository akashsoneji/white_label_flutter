import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';

class ChartPreloadService extends GetxService {
  InAppWebViewKeepAlive? keepAlive;
  HeadlessInAppWebView? headlessWebView;

  @override
  void onInit() {
    super.onInit();
    // Initialize keepAlive and headless webview
    keepAlive = InAppWebViewKeepAlive();
    
    // We preload with XAUUSD as default, it will instantly switch via JS when opened
    final initialUrl = '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?symbol=XAUUSD&theme=${AppColors.chartTheme}';
    
    headlessWebView = HeadlessInAppWebView(
      keepAlive: keepAlive,
      initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        cacheEnabled: true,
        clearCache: false,
        domStorageEnabled: true,
        databaseEnabled: true,
      ),
      onWebViewCreated: (controller) {
        if (kDebugMode) {
          print('🚀 [ChartPreloadService] Headless WebView created');
        }
      },
      onLoadStop: (controller, url) {
        if (kDebugMode) {
          print('✅ [ChartPreloadService] Headless WebView fully loaded: $url');
        }
      },
    );
    
    // Start running it in the background
    headlessWebView?.run();
  }

  @override
  void onClose() {
    headlessWebView?.dispose();
    super.onClose();
  }
}
