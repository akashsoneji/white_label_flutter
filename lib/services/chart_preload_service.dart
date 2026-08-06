import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChartPreloadService extends GetxService {
  InAppWebViewKeepAlive? keepAlive;
  HeadlessInAppWebView? headlessWebView;
  InAppWebViewController? _headlessController;

  /// Singleton-style accessor for non-Get code (e.g. main.dart widget tree).
  static ChartPreloadService get instance =>
      Get.isRegistered<ChartPreloadService>()
          ? Get.find<ChartPreloadService>()
          : _bootstrap;

  static ChartPreloadService? _cached;
  static ChartPreloadService get _bootstrap {
    _cached ??= Get.put(ChartPreloadService(), permanent: true);
    final svc = _cached!;
    if (svc.keepAlive == null) svc.onInit();
    return svc;
  }

  /// Current symbol being shown in the persistent webview.
  String currentSymbol = 'XAUUSD';

  /// Full chart URL for [currentSymbol].
  String get currentChartUrl => _buildUrl(currentSymbol);

  /// The persistent InAppWebView widget rendered by main.dart's
  /// _ChartWebViewShell. When the user opens the chart tab, the host
  /// simply moves this widget from offstage to onstage — zero reload,
  /// sub-second switch.
  static const String _preloadSymbol = 'XAUUSD';
  static const String _preloadFlagKey = 'chart_preloaded_xauusd_v1';

  Widget get persistentWebView {
    if (!Get.isRegistered<ChartPreloadService>()) {
      Get.put(ChartPreloadService(), permanent: true);
    }
    return _PersistentChartWebView(this);
  }

  String _buildUrl(String sym) {
    return '${FlavorConfig.instance.chartBaseUrl}/mobile-chart'
        '?symbol=$sym&theme=${AppColors.chartTheme}';
  }

  /// Called by _ChartWebViewShell (in main.dart) when the InAppWebView
  /// is created. Public so the widget in another library can hand the
  /// controller back here.
  void onPersistentWebViewCreated(InAppWebViewController controller) {
    _headlessController = controller;
  }

  /// Called by _ChartWebViewShell when page load completes.
  void onPersistentPageLoadComplete() {
    if (kDebugMode) {
      print('✅ [ChartPreloadService] Persistent chart loaded: $currentSymbol');
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Initialize keepAlive for single shared native WebView engine
    keepAlive = InAppWebViewKeepAlive();
    _cached = this;
  }

  /// Called by user-facing chart UI when the user picks a new symbol.
  static Future<void> setSymbol(String sym) async {
    final svc = Get.isRegistered<ChartPreloadService>()
        ? Get.find<ChartPreloadService>()
        : instance;
    svc.currentSymbol = sym;
  }

  /// Clears all chart cache state. Call on logout so the next login
  /// starts with a clean chart slate — no stale symbols or WebView state.
  static Future<void> clearCache() async {
    try {
      final svc = Get.isRegistered<ChartPreloadService>()
          ? Get.find<ChartPreloadService>()
          : null;
      if (svc == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_preloadFlagKey);
      await svc.headlessWebView?.dispose();
      svc.headlessWebView = null;
      svc._headlessController = null;
      svc.currentSymbol = _preloadSymbol;
      if (kDebugMode) {
        print('✅ [ChartPreloadService] Cache cleared on logout.');
      }
    } catch (e) {
      if (kDebugMode) print('ChartPreloadService.clearCache error: $e');
    }
  }

  @override
  void onClose() {
    headlessWebView?.dispose();
    _headlessController = null;
    super.onClose();
  }
}

/// The persistent InAppWebView widget rendered inside main.dart's
/// _PersistentChartHost. Its build() depends on `currentSymbol` so when
/// the service updates the symbol, the widget rebuilds with a new URL.
class _PersistentChartWebView extends StatelessWidget {
  final ChartPreloadService _svc;
  const _PersistentChartWebView(this._svc);

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      key: ValueKey(_svc.currentSymbol),
      initialUrlRequest:
          URLRequest(url: WebUri(_svc.currentChartUrl)),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          javaScriptEnabled: true,
          transparentBackground: true,
          cacheEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
      ),
      onWebViewCreated: _svc.onPersistentWebViewCreated,
      onLoadStop: (_, __) => _svc.onPersistentPageLoadComplete(),
    );
  }
}
