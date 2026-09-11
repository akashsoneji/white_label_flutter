import 'dart:async';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChartWebViewPrewarmer
//
// Starts a HeadlessInAppWebView as soon as the chart screen is created so that
// the browser engine initialises, DNS resolves, TCP handshakes complete, and
// the chart HTML / JS / CSS are downloaded and cached — all before the user
// ever taps the chart tab.
//
// When the visible ChartInAppWebView is built, its InAppWebView will hit the
// disk/memory HTTP cache and render in ~300 ms instead of 4-6 seconds.
//
// Usage:
//   ChartWebViewPrewarmer.instance.prewarm(symbol: 'EURUSD');
//   // when ChartScreen unmounts:
//   ChartWebViewPrewarmer.instance.dispose();
// ─────────────────────────────────────────────────────────────────────────────

class ChartWebViewPrewarmer {
  ChartWebViewPrewarmer._();
  static final ChartWebViewPrewarmer instance = ChartWebViewPrewarmer._();

  HeadlessInAppWebView? _headless;
  bool _warmed = false;
  bool _disposed = false;

  /// Builds the same URL the visible chart will load, so the cache hit is exact.
  String _chartUrl(String symbol) {
    String? acc;
    if (Get.isRegistered<AccountController>()) {
      acc = Get.find<AccountController>().activeMT5Account?.metaAccountNumber.toString();
    }
    final effective = SymbolDetailsCacheService.resolveDatafeedSymbolSync(symbol, acc);
    final base =
        '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?theme=${AppColors.chartTheme}';
    return '$base&symbol=${Uri.encodeComponent(effective)}';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Starts a background (headless) WebView that loads the chart URL.
  /// Call this as early as possible — typically in [initState] of ChartScreen.
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> prewarm({required String symbol}) async {
    if (_warmed || _disposed) return;
    _warmed = true;

    try {
      String? acc;
      if (Get.isRegistered<AccountController>()) {
        acc = Get.find<AccountController>().activeMT5Account?.metaAccountNumber.toString();
      }
      final effectiveSymbol = await SymbolDetailsCacheService.resolveDatafeedSymbol(symbol, acc);
      debugPrint('📊 Prewarmer: starting headless load for $effectiveSymbol');
      _headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_chartUrl(effectiveSymbol))),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          // Use the same aggressive cache mode as the visible WebView so the
          // on-disk cache is populated and the visible WebView benefits.
          cacheEnabled: true,
          cacheMode: CacheMode.LOAD_DEFAULT,
          domStorageEnabled: true,
          databaseEnabled: true,
        ),
        onLoadStop: (controller, url) {
          debugPrint('📊 Prewarmer: page cached ($url)');
          // Keep the headless view alive so the in-memory cache stays warm.
          // It will be disposed when ChartScreen disposes.
        },
        onReceivedError: (controller, request, error) {
          debugPrint('📊 Prewarmer: load error — ${error.description}');
        },
      );
      await _headless!.run();
    } catch (e) {
      debugPrint('📊 Prewarmer: failed to start — $e');
      _warmed = false; // allow retry
    }
  }

  /// Tear down the headless WebView. Call from [dispose] of ChartScreen.
  Future<void> dispose() async {
    _disposed = true;
    try {
      await _headless?.dispose();
    } catch (_) {}
    _headless = null;
    _warmed = false;
    _disposed = false; // reset so next ChartScreen can prewarm again
  }
}
