import 'dart:async';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChartInAppWebView extends StatefulWidget {
  final String url;
  final String symbol;

  const ChartInAppWebView({super.key, required this.url, required this.symbol});

  @override
  State<ChartInAppWebView> createState() => ChartInAppWebViewState();
}

class ChartInAppWebViewState extends State<ChartInAppWebView> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isReady = false;
  String? _lastUrl;
  Timer? _loadingTimeout;

  @override
  void initState() {
    super.initState();
    _lastUrl = widget.url;
    _startLoadingTimeout();
  }

  @override
  void didUpdateWidget(covariant ChartInAppWebView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _lastUrl = widget.url;
      _isReady = false;
      _hasError = false;
      _isLoading = true;
      _startLoadingTimeout();
      _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
      return;
    }

    // If only symbol changed, try JS update first (no reload).
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
    _loadingTimeout = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      if (_isReady) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    });
  }

  Future<void> updateSymbol(String symbol) async {
    if (_controller == null) return;
    if (!_isReady) return;

    final String chartSymbol =
        symbol.contains('.') ? symbol.substring(0, symbol.lastIndexOf('.')) : symbol;

    try {
      await _controller!.evaluateJavascript(source: '''
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
            }
          } catch (e) {}
          return false;
        })();
      ''');
    } catch (_) {
      // If JS bridge fails, fallback to reload the URL (keeps app alive).
      if (_lastUrl != null) {
        await _controller!.loadUrl(
          urlRequest: URLRequest(url: WebUri(_lastUrl!)),
        );
      }
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
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            shouldOverrideUrlLoading: (controller, action) async {
              // Keep navigation inside the same webview.
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

