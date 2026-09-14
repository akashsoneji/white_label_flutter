import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// **New** chart widget used when `FlavorConfig.instance.useNewChart == true`.
///
/// Loads the local `assets/chart/advanced/index.html`, which embeds the
/// **free public TradingView widget** (`https://s3.tradingview.com/tv.js`).
/// This avoids the need for a licensed Advanced Charting Library bundle —
/// the trade-off being that we use TradingView's own market data (the page
/// supports built-in symbol search + theme + indicators + drawing tools).
///
/// Public API mirrors `ChartInAppWebView` so `chart_screen.dart` can swap
/// them 1:1 behind the `useNewChart` flavor flag.
class AdvancedChartInAppWebView extends StatefulWidget {
  /// Initial symbol to load. May be a raw symbol like `EURUSD`, `XAUUSD`,
  /// `BTCUSD`, or a broker-suffixed `EURUSD.r` — the HTML maps it to a
  /// TradingView exchange-qualified symbol (`FX:EURUSD`, `OANDA:XAUUSD`, …).
  final String symbol;

  /// `light` or `dark`.
  final String theme;

  const AdvancedChartInAppWebView({
    super.key,
    required this.symbol,
    this.theme = 'light',
  });

  @override
  State<AdvancedChartInAppWebView> createState() =>
      AdvancedChartInAppWebViewState();
}

class AdvancedChartInAppWebViewState extends State<AdvancedChartInAppWebView> {
  static const String _assetFile = 'assets/chart/advanced/index.html';

  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isReady = false;
  Timer? _loadingTimeout;

  @override
  void initState() {
    super.initState();
    _startLoadingTimeout();
  }

  @override
  void didUpdateWidget(covariant AdvancedChartInAppWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      unawaited(_applyTheme(widget.theme));
    }
    if (oldWidget.symbol != widget.symbol) {
      unawaited(updateSymbol(widget.symbol));
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  void _startLoadingTimeout() {
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (_isReady) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    });
  }

  /// User script that runs at document start, so the HTML can read the
  /// initial symbol + theme synchronously when it boots tv.js.
  UserScript _buildBootstrapScript() {
    final cleanSymbol = widget.symbol.contains('.')
        ? widget.symbol.substring(0, widget.symbol.lastIndexOf('.'))
        : widget.symbol;
    return UserScript(
      source:
          'window.__initSymbol = ${jsonEncode(cleanSymbol)};'
          'window.__initTheme  = ${jsonEncode(widget.theme)};',
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );
  }

  /// Public — same signature as legacy `ChartInAppWebView.updateSymbol`.
  Future<void> updateSymbol(String symbol) async {
    if (_controller == null || !_isReady) return;
    final cleanSymbol = symbol.contains('.')
        ? symbol.substring(0, symbol.lastIndexOf('.'))
        : symbol;
    try {
      await _controller!.evaluateJavascript(
        source:
            'if (typeof window.__setSymbol === "function") { window.__setSymbol(${jsonEncode(cleanSymbol)}); }',
      );
    } catch (_) {
      await _reload();
    }
  }

  /// Public — kept for API parity. Public tv.js widget cannot render
  /// custom trade overlays, so this is a no-op.
  Future<void> updateNativeTrades(String tradesJson) async {
    if (_controller == null || !_isReady) return;
    try {
      await _controller!.evaluateJavascript(
        source:
            'if (typeof window.__renderNativeTrades === "function") { window.__renderNativeTrades($tradesJson); }',
      );
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _applyTheme(String theme) async {
    if (_controller == null || !_isReady) return;
    try {
      await _controller!.evaluateJavascript(
        source:
            'if (typeof window.__setTheme === "function") { window.__setTheme(${jsonEncode(theme)}); }',
      );
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _reload() async {
    if (_controller == null) return;
    await _controller!.loadFile(assetFilePath: _assetFile);
  }

  Future<void> _retry() async {
    if (_controller == null) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
      _isReady = false;
    });
    _startLoadingTimeout();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
        children: [
          InAppWebView(
            initialFile: _assetFile,
            initialUserScripts: UnmodifiableListView<UserScript>(
              [_buildBootstrapScript()],
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              // Required so the page (loaded via file://) can fetch tv.js
              // from https://s3.tradingview.com.
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              clearCache: false,
              cacheEnabled: true,
              supportZoom: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            shouldOverrideUrlLoading: (controller, action) async {
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, url) {
              if (!mounted) return;
              setState(() {
                _isLoading = true;
                _hasError = false;
                _isReady = false;
              });
            },
            onLoadStop: (controller, url) async {
              if (!mounted) return;
              _loadingTimeout?.cancel();
              setState(() {
                _isLoading = false;
                _hasError = false;
                _isReady = true;
              });
              unawaited(updateSymbol(widget.symbol));
            },
            onReceivedError: (controller, request, error) {
              if (!mounted) return;
              // Only main-frame failures are fatal — sub-resource errors
              // (a single failing tv.js asset, an analytics ping, etc.)
              // must not blow up the whole chart.
              final isMainFrame = request.isForMainFrame ?? false;
              if (!isMainFrame) return;
              setState(() {
                _hasError = true;
                _isLoading = false;
                _isReady = false;
              });
            },
            androidOnRenderProcessGone: (controller, detail) async {
              if (!mounted) return;
              if (kDebugMode) {
                debugPrint('Advanced Chart WebView renderer died: $detail');
              }
              setState(() {
                _hasError = true;
                _isLoading = false;
                _isReady = false;
              });
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.transparent,
              child: Center(
                  child: CommonLoadingWidget(
                    message: Get.find<LanguageService>().tr(
                      'advanced_chart_inapp_webview_loading_chart',
                    ),
                    size: 40.0,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (_hasError)
            Container(
              color: Colors.transparent,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48.h,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Chart unavailable',
                      style: AppTextStyles.subheading.copyWith(
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      height: 42.h,
                      width: 140.w,
                      child: OutlinedButton(
                        onPressed: _retry,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.whiteColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
