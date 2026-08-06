import 'dart:async';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/chart_preload_service.dart';

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

  /// Symbol requested while the WebView wasn't ready yet.
  /// Applied immediately after onLoadStop fires.
  String? _pendingSymbol;

  @override
  void initState() {
    super.initState();
    _startLoadingTimeout();
  }

  @override
  void didUpdateWidget(covariant ChartInAppWebView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ── Case 1: URL genuinely changed (e.g. user switched to a different brand/page).
    // This is NOT triggered by symbol changes since the URL is now stable (no symbol in URL).
    if (oldWidget.url != widget.url) {
      if (mounted) {
        setState(() {
          _isReady = false;
          _isLoading = true;
          _hasError = false;
        });
      }
      _pendingSymbol = widget.symbol;
      _startLoadingTimeout();
      _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
      return;
    }

    // ── Case 2: Symbol changed — try JS first (zero flicker), fall back to
    //    loadUrl with symbol in URL only if JS bridge is not available on the page.
    if (oldWidget.symbol != widget.symbol) {
      if (_isReady) {
        // Build the symbol URL for fallback use
        final symbolUrl = widget.url.contains('?')
            ? '${widget.url}&symbol=${Uri.encodeComponent(widget.symbol)}'
            : '${widget.url}?symbol=${Uri.encodeComponent(widget.symbol)}';
        unawaited(updateSymbol(widget.symbol).then((success) {
          if (!success && mounted && _controller != null) {
            // JS bridge not available on this page (remote TradingView hosted chart).
            // Use loadUrl with symbol in URL — WebView assets are already cached so
            // this hits browser cache and completes in ~1-2s instead of cold 5-7s.
            _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(symbolUrl)));
          }
        }));
      } else {
        // Chart still loading — queue the symbol; when onLoadStop fires it will apply it.
        _pendingSymbol = widget.symbol;
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
    _loadingTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (_isReady) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    });
  }

  Future<bool> updateSymbol(String symbol) async {
    if (_controller == null || symbol.isEmpty) return false;
    if (!_isReady) {
      _pendingSymbol = symbol;
      return false;
    }

    final sym = symbol;
    final symClean = sym.contains('.') ? sym.substring(0, sym.lastIndexOf('.')) : sym;

    // ── JS helper — tries every known TradingView widget API surface.
    String _jsSource(String s) => '''
      (function() {
        var sym = ${_jsStr(s)};
        function trySet(t) {
          try { if (typeof selectedSymbol!=='undefined') selectedSymbol=t; } catch(e) {}
          try { if (typeof window.__setSymbol==='function') { window.__setSymbol(t); return true; } } catch(e) {}
          try {
            if (typeof tvWidget!=='undefined' && tvWidget) {
              if (typeof tvWidget.setSymbol==='function') { tvWidget.setSymbol(t,"5",function(){}); return true; }
              if (typeof tvWidget.activeChart==='function') { tvWidget.activeChart().setSymbol(t); return true; }
            }
          } catch(e) {}
          try {
            if (typeof _tvWidget!=='undefined' && _tvWidget) {
              if (typeof _tvWidget.setSymbol==='function') { _tvWidget.setSymbol(t,"5",function(){}); return true; }
              if (typeof _tvWidget.activeChart==='function') { _tvWidget.activeChart().setSymbol(t); return true; }
            }
          } catch(e) {}
          try {
            if (typeof chartWidget!=='undefined' && chartWidget) {
              if (typeof chartWidget.setSymbol==='function') { chartWidget.setSymbol(t,"5",function(){}); return true; }
              if (typeof chartWidget.activeChart==='function') { chartWidget.activeChart().setSymbol(t); return true; }
            }
          } catch(e) {}
          try { if (typeof updateSymbol==='function') { updateSymbol(t); return true; } } catch(e) {}
          try { if (typeof createTradingViewChart==='function') { createTradingViewChart(t); return true; } } catch(e) {}
          return false;
        }
        if (trySet(sym)) return 'ok';
        return 'miss';
      })();
    ''';

    try {
      var res = await _controller!.evaluateJavascript(source: _jsSource(sym));
      if (res == 'ok') return true;

      // Fallback to clean symbol (without suffix like .c / .m)
      res = await _controller!.evaluateJavascript(source: _jsSource(symClean));
      if (res == 'ok') return true;

      // Single retry after 300ms — handles cases where tab-switch animation
      // is still running and the widget container is not yet visible/sized.
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted || _controller == null) return false;

      res = await _controller!.evaluateJavascript(source: _jsSource(sym));
      if (res == 'ok') return true;
      res = await _controller!.evaluateJavascript(source: _jsSource(symClean));
      return res == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Dart string → JS quoted string literal.
  static String _jsStr(String s) => '"${s.replaceAll('"', r'\"')}"';



  Future<void> updateNativeTrades(String tradesJson) async {
    if (_controller == null) return;
    if (!_isReady) return;

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
      // ignore
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
    // Load with symbol in URL for retry
    final retryUrl = widget.symbol.isNotEmpty
        ? (widget.url.contains('?')
            ? '${widget.url}&symbol=${Uri.encodeComponent(widget.symbol)}'
            : '${widget.url}?symbol=${Uri.encodeComponent(widget.symbol)}')
        : widget.url;
    await _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(retryUrl)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          InAppWebView(
            keepAlive: Get.isRegistered<ChartPreloadService>()
                ? Get.find<ChartPreloadService>().keepAlive
                : null,
            // Include symbol in initial URL so TradingView renders the right symbol on first load.
            // After that, symbol changes go through JS-only updates — the URL never changes again.
            initialUrlRequest: URLRequest(url: WebUri(
              widget.symbol.isNotEmpty
                  ? '${widget.url}&symbol=${Uri.encodeComponent(widget.symbol)}'
                  : widget.url,
            )),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              cacheEnabled: true,
              cacheMode: CacheMode.LOAD_DEFAULT,
              domStorageEnabled: true,
              databaseEnabled: true,
              clearCache: false,
              supportZoom: false,
            ),
            onWebViewCreated: (controller) async {
              _controller = controller;
              // Check if we attached to a pre-warmed persistent webview that's already finished loading
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
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, url) {
              if (!mounted) return;
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

              // If a pending symbol was queued while loading, try JS update.
              // If page URL already contains the symbol (loadUrl fallback path), skip JS.
              final symbolToApply = _pendingSymbol ?? widget.symbol;
              _pendingSymbol = null;
              final loadedUrl = url?.toString() ?? '';
              final symbolInUrl = Uri.encodeComponent(symbolToApply);
              if (!loadedUrl.contains(symbolInUrl) && !loadedUrl.contains(symbolToApply)) {
                await Future<void>.delayed(const Duration(milliseconds: 300));
                if (mounted) unawaited(updateSymbol(symbolToApply));
              }
            },
            onReceivedError: (controller, request, error) {
              if (!mounted) return;
              if (request.isForMainFrame == true) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                  _isReady = false;
                });
              }
            },
            androidOnRenderProcessGone: (controller, detail) async {
              if (!mounted) return;
              if (kDebugMode) {
                debugPrint('Chart WebView renderer died: $detail');
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
