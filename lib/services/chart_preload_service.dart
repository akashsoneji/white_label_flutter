import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/favorites_storage_service.dart';

class ChartPreloadService extends GetxService {
  InAppWebViewKeepAlive? keepAlive;
  HeadlessInAppWebView? headlessWebView;

  List<String> _symbolsToPreload = [];
  int _currentPreloadIndex = 0;

  @override
  void onInit() {
    super.onInit();
    // Initialize keepAlive
    keepAlive = InAppWebViewKeepAlive();
    
    // Start the sequential preload of favorite symbols
    _startPreloadSequence();
  }

  Future<void> _startPreloadSequence() async {
    try {
      final favorites = await FavoritesStorageService.instance.getFavoriteInstruments();
      if (favorites.isEmpty) {
        _symbolsToPreload = ['XAUUSD']; // Default if empty
      } else {
        _symbolsToPreload = favorites;
      }
      
      _currentPreloadIndex = 0;
      _preloadNextSymbol();
    } catch (e) {
      if (kDebugMode) print('Error starting chart preload: $e');
    }
  }

  void _preloadNextSymbol() {
    if (_currentPreloadIndex >= _symbolsToPreload.length) {
      if (kDebugMode) print('✅ [ChartPreloadService] Finished preloading all favorites.');
      return;
    }
    
    final symbol = _symbolsToPreload[_currentPreloadIndex];
    final cleanSymbol = symbol.contains('.') ? symbol.substring(0, symbol.lastIndexOf('.')) : symbol;
    
    final url = '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?symbol=$cleanSymbol&theme=${AppColors.chartTheme}';
    
    if (headlessWebView == null) {
      headlessWebView = HeadlessInAppWebView(
        keepAlive: keepAlive,
        initialUrlRequest: URLRequest(url: WebUri(url)),
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
            print('🚀 [ChartPreloadService] Headless WebView created, loading: $cleanSymbol');
          }
        },
        onLoadStop: (controller, url) {
          if (kDebugMode) {
            print('✅ [ChartPreloadService] Cached: $url');
          }
          _currentPreloadIndex++;
          // Delay briefly to avoid freezing the app with rapid WebView reloads
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!Get.isRegistered<ChartPreloadService>()) return; // check if still active
            _preloadNextSymbol();
          });
        },
      );
      
      headlessWebView?.run();
    } else {
      headlessWebView?.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
  }

  @override
  void onClose() {
    headlessWebView?.dispose();
    super.onClose();
  }
}
