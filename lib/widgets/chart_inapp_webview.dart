import 'dart:async';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/chart_preload_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChartInAppWebView extends StatefulWidget {
  final String url;
  final String symbol;
  final VoidCallback? onReady;

  const ChartInAppWebView({
    super.key,
    required this.url,
    required this.symbol,
    this.onReady,
  });

  @override
  State<ChartInAppWebView> createState() => ChartInAppWebViewState();
}

class ChartInAppWebViewState extends State<ChartInAppWebView> {
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
  void didUpdateWidget(covariant ChartInAppWebView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url || oldWidget.symbol != widget.symbol) {
      if (_isReady) {
        // Try JS update first
        updateSymbol(widget.symbol).then((success) {
          if (!success) {
            // JS update failed or not supported by the page. Fallback to full reload.
            // Do NOT set _isLoading = true here to prevent flickering/spinner during switch.
            _hasError = false;
            _controller?.loadUrl(
                urlRequest: URLRequest(url: WebUri(widget.url)));
            if (mounted) setState(() {});
          }
        });
      } else {
        _isLoading = true;
        _hasError = false;
        _startLoadingTimeout();
        _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  void _startLoadingTimeout() {
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      if (_isReady) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    });
  }

  Future<bool> updateSymbol(String symbol) async {
    if (_controller == null) return false;
    if (!_isReady) return false;

    final String chartSymbol =
        symbol.contains('.') ? symbol.substring(0, symbol.lastIndexOf('.')) : symbol;

    try {
      final res = await _controller!.evaluateJavascript(source: '''
        (function() {
          try {
            if (typeof selectedSymbol !== 'undefined') {
              selectedSymbol = "$chartSymbol";
            }
            if (typeof updateSymbol === 'function') {
              updateSymbol("$chartSymbol");
              return true;
            }
            if (typeof createTradingViewChart === 'function') {
              createTradingViewChart("$chartSymbol");
              return true;
            // Fallback for Vue/React SPA: change URL via location.replace
            var newUrl = window.location.pathname + "?symbol=" + "$chartSymbol" + "&theme=" + (new URLSearchParams(window.location.search).get("theme") || "light");
            window.location.replace(newUrl);
            return true;
          } catch (e) {}
          return false;
        })();
      ''');

      return res == true || res == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> updateNativeTrades(String tradesJson) async {
    if (_controller == null) return;
    if (!_isReady) return;

    // tradesJson is already JSON string; pass as JS value.
    try {
      await _controller!.evaluateJavascript(source: '''
        (function() {
          try {
            if (typeof updateNativeTrades === 'function') {
              updateNativeTrades($tradesJson);
              return true;
            }
          } catch (e) {}
          return false;
        })();
      ''');
    } catch (_) {
      // ignore – chart still usable
    }
  }

  Future<dynamic> evaluateJavascript(String source) async {
    if (_controller == null || !_isReady) return null;
    try {
      return await _controller!.evaluateJavascript(source: source);
    } catch (e) {
      debugPrint('[Chart] JS Eval Error: $e');
      return null;
    }
  }

  Future<void> _retry() async {
    if (_controller == null) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
      _isReady = false;
    });
    _startLoadingTimeout();
    await _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          InAppWebView(
            keepAlive: Get.isRegistered<ChartPreloadService>() ? Get.find<ChartPreloadService>().keepAlive : null,
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              cacheEnabled: true,
              clearCache: false,
              domStorageEnabled: true,
              databaseEnabled: true,
              supportZoom: false,
            ),
            onWebViewCreated: (controller) async {
              _controller = controller;
              // Check if we attached to a preloaded KeepAlive webview that's already finished loading
              final progress = await controller.getProgress();
              if (progress == 100) {
                if (!mounted) return;
                _loadingTimeout?.cancel();
                setState(() {
                  _isLoading = false;
                  _hasError = false;
                  _isReady = true;
                });
                widget.onReady?.call();
                unawaited(updateSymbol(widget.symbol));
              }
            },
            shouldOverrideUrlLoading: (controller, action) async {
              // Keep navigation inside the same webview.
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, url) {
              if (!mounted) return;
              // Only show loader if it's the first time loading
              if (!_isReady) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onLoadStop: (controller, url) async {
              if (!mounted) return;
              _loadingTimeout?.cancel();
              setState(() {
                _isLoading = false;
                _hasError = false;
                _isReady = true;
              });
              widget.onReady?.call();
              // Ensure symbol is set after load.
              unawaited(updateSymbol(widget.symbol));
            },
            onReceivedError: (controller, request, error) {
              if (!mounted) return;
              setState(() {
                _hasError = true;
                _isLoading = false;
                _isReady = false;
              });
            },
            androidOnRenderProcessGone: (controller, detail) async {
              // ✅ Prevent the whole app from crashing when WebView renderer dies.
              if (!mounted) return;
              if (kDebugMode) {
                debugPrint('Chart WebView renderer died: $detail');
              }
              setState(() {
                _hasError = true;
                _isLoading = false;
                _isReady = false;
              });
              // Returning void here is correct for this callback signature.
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.transparent,
              child: Center(
                child: CommonLoadingWidget(
                  message: 'Loading chart...',
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
                    Icon(Icons.error_outline, size: 48.h, color: AppColors.textGrey),
                    SizedBox(height: 12.h),
                    Text(
                      'Chart unavailable',
                      style: AppTextStyles.subheading.copyWith(color: AppColors.textGrey),
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
    );
  }
}

