import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

///
/// The chart is a local HTML bundle whose JavaScript (~736 KB) has to be parsed
/// by the platform WebView the first time it is loaded. When that happens lazily
/// on the first chart-tab open, the user waits for: native WebView boot + bundle
/// parse + history fetch, all serially.
///
/// Calling [warm] once shortly after the home screen mounts loads that same
/// bundle in a hidden [HeadlessInAppWebView]. Because the WebView cache is shared
/// across instances (see `cacheEnabled: true` in `TenaxChartView`), the real
/// chart then reuses the already-parsed bundle and paints far quicker.
///
/// This is best-effort and idempotent: it runs at most once per app session and
/// silently no-ops on any failure — it must never affect app startup.
class TenaxChartPrewarmer {
  TenaxChartPrewarmer._();

  static const String _assetFile = 'assets/chart/tenax/index.html';

  static bool _started = false;
  static HeadlessInAppWebView? _headless;

  /// Kicks off a one-time hidden load of the chart bundle. Safe to call from
  /// multiple home screens — only the first call does any work.
  static Future<void> warm() async {
    if (_started) return;
    _started = true;
    try {
      final headless = HeadlessInAppWebView(
        initialFile: _assetFile,
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          javaScriptEnabled: true,
          cacheEnabled: true,
          clearCache: false,
          allowFileAccess: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),
        onLoadStop: (_, __) {
          // Bundle parsed + cached. Keep the headless view alive briefly so the
          // platform finishes warming, then tear it down to free memory.
          Future.delayed(const Duration(seconds: 5), dispose);
        },
      );
      _headless = headless;
      await headless.run();
    } catch (e) {
      debugPrint('TenaxChartPrewarmer: warm skipped ($e)');
      dispose();
    }
  }

  /// Disposes the hidden WebView if it is still alive.
  static void dispose() {
    _headless?.dispose();
    _headless = null;
  }
}
