import 'dart:async';
import 'dart:convert';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/services/chart_datafeed_bridge.dart';

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
  Timer? _pendingSymbolTimer;
  int _retryCount = 0;

  /// Datafeed bridge — mirrors the TradingView UDF Datafeed API so
  /// `tradyn_chart.html`'s `__tradynDatafeed` shim can call Dart
  /// (via FlutterBridge) for history + live ticks.
  final ChartDatafeedBridge _df = ChartDatafeedBridge();

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
      _retryCount = 0;
      _startLoadingTimeout();
      _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
      return;
    }

    // ── Case 2: Symbol changed — try JS first (zero flicker)
    if (oldWidget.symbol != widget.symbol) {
      _pendingSymbol = widget.symbol;
      _retryCount = 0;
      if (_isReady) {
        _applyPendingSymbol();
      }
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _pendingSymbolTimer?.cancel();
    super.dispose();
  }

  /// Attempts to apply the pending symbol. If it fails (due to offscreen suspension
  /// or TradingView initialization delay), it retries every 500ms up to 3 times,
  /// then falls back to loading the symbol URL directly.
  void _applyPendingSymbol() {
    _pendingSymbolTimer?.cancel();
    if (_pendingSymbol == null) {
      print('📊 WebView Retry: No pending symbol to apply.');
      return;
    }
    if (!_isReady) {
      print('📊 WebView Retry: WebView not ready yet.');
      return;
    }
    if (_controller == null) {
      print('📊 WebView Retry: Controller is null.');
      return;
    }

    final symbolToApply = _pendingSymbol!;
    print('📊 WebView Retry: Attempting to apply symbol $symbolToApply (attempt ${_retryCount + 1})');
    unawaited(updateSymbol(symbolToApply).then((success) {
      print('📊 WebView Retry: updateSymbol result for $symbolToApply was: $success');
      if (success) {
        _pendingSymbol = null;
        _retryCount = 0;
      } else {
        _retryCount++;
        if (_retryCount >= 3) {
          final symbolUrl = widget.url.contains('?')
              ? '${widget.url}&symbol=${Uri.encodeComponent(symbolToApply)}'
              : '${widget.url}?symbol=${Uri.encodeComponent(symbolToApply)}';
          print('📊 WebView Retry: JS failed 3 times. Falling back to loadUrl: $symbolUrl');
          _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(symbolUrl)));
          _pendingSymbol = null;
          _retryCount = 0;
        } else {
          _pendingSymbolTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted && _pendingSymbol == symbolToApply) {
              _applyPendingSymbol();
            }
          });
        }
      }
    }));
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
    if (_controller == null || symbol.isEmpty) {
      print('📊 updateSymbol: controller null or symbol empty');
      return false;
    }
    if (!_isReady) {
      print('📊 updateSymbol: WebView not ready');
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
          try {
            if (typeof window.__changeSymbol==='function') {
              var res = window.__changeSymbol(t);
              if (res === true || res === undefined) return true;
            }
          } catch(e) {}
          try {
            if (typeof window.__setSymbol==='function') {
              var res = window.__setSymbol(t);
              if (res === true || res === undefined) return true;
            }
          } catch(e) {}
          
          // Generic search for TradingView widget object inside window properties
          for (var prop in window) {
            try {
              if (prop !== 'webkit' && window[prop] && typeof window[prop].setSymbol === 'function') {
                window[prop].setSymbol(t, "5", function(){});
                return true;
              }
            } catch(e) {}
          }
          
          try { if (typeof updateSymbol==='function') { updateSymbol(t); return true; } } catch(e) {}
          try { if (typeof createTradingViewChart==='function') { createTradingViewChart(t); return true; } } catch(e) {}
          return false;
        }
        if (trySet(sym)) return 'ok';
        return 'miss';
      })();
    ''';

    try {
      print('📊 updateSymbol: Evaluating JS for $sym');
      var res = await _controller!.evaluateJavascript(source: _jsSource(sym));
      print('📊 updateSymbol: JS result for $sym: $res');
      if (res == 'ok') return true;

      // Fallback to clean symbol (without suffix like .c / .m)
      print('📊 updateSymbol: Evaluating JS for clean $symClean');
      res = await _controller!.evaluateJavascript(source: _jsSource(symClean));
      print('📊 updateSymbol: JS result for clean $symClean: $res');
      if (res == 'ok') return true;

      // Single retry after 300ms — handles cases where tab-switch animation
      // is still running and the widget container is not yet visible/sized.
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted || _controller == null) return false;

      print('📊 updateSymbol: Retrying JS for $sym');
      res = await _controller!.evaluateJavascript(source: _jsSource(sym));
      if (res == 'ok') return true;
      res = await _controller!.evaluateJavascript(source: _jsSource(symClean));
      return res == 'ok';
    } catch (e) {
      print('📊 updateSymbol: Error: $e');
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

  /// Registers the `FlutterBridge` JavaScript handler so `tradyn_chart.html`'s
  /// `__tradynDatafeed` shim can call Dart for history (getBars), symbol
  /// metadata (resolveSymbol), live ticks (subscribeBars), and unsubscribe.
  /// Results are delivered back via `window.__resolveDfCallback(cbId, result)`.
  Future<void> _initDatafeedBridge(InAppWebViewController controller) async {
    controller.addJavaScriptHandler(
      handlerName: 'FlutterBridge',
      callback: (List<dynamic> args) async {
        try {
          final raw = args.isNotEmpty ? args.first : null;
          if (raw is! String) return null;
          final msg = jsonDecode(raw) as Map<String, dynamic>;
          final method = msg['method']?.toString();
          final cbId = msg['cbId'];
          final payload = (msg['args'] as Map?)?.cast<String, dynamic>() ?? {};

          Map<String, dynamic>? result;
          switch (method) {
            case 'onReady':
              result = _df.onReady();
              break;
            case 'resolveSymbol':
              String? accountNumber;
              if (Get.isRegistered<AccountController>()) {
                accountNumber = Get.find<AccountController>()
                    .activeMT5Account
                    ?.metaAccountNumber;
              }
              final info = await _df.resolveSymbol(
                symbol: payload['sym']?.toString() ?? '',
                accountNumber: accountNumber,
              );
              result = info;
              break;
            case 'getBars':
              result = await _df.getBars(
                symbol: payload['symbol']?.toString() ?? '',
                resolution: payload['resolution']?.toString() ?? '1',
                from: (payload['from'] as num?)?.toInt() ?? 0,
                to: (payload['to'] as num?)?.toInt() ?? 0,
                countBack: (payload['countBack'] as num?)?.toInt() ?? 500,
              );
              break;
            case 'subscribeBars':
              final uid = payload['uid']?.toString() ?? '';
              _df.subscribeBars(
                symbol: payload['symbol']?.toString() ?? '',
                resolution: payload['resolution']?.toString() ?? '1',
                subscriberUID: uid,
                onTick: (bar) async {
                  final js =
                      'if (window.__rtCb_$uid) { try { window.__rtCb_$uid(${_jsonEncode(bar)}); } catch(e){} }';
                  try {
                    await controller.evaluateJavascript(source: js);
                  } catch (_) {}
                },
              );
              result = {'ok': true};
              break;
            case 'unsubscribeBars':
              _df.unsubscribeBars(
                payload['uid']?.toString() ?? '',
              );
              result = {'ok': true};
              break;
            default:
              result = {'error': 'unknown_method: $method'};
          }

          if (cbId != null) {
            final resultJson = _jsonEncode(result ?? const {});
            await controller.evaluateJavascript(
              source: 'window.__resolveDfCallback($cbId, $resultJson);',
            );
          }
          return result;
        } catch (e) {
          if (kDebugMode) debugPrint('[ChartBridge] handler error: $e');
          return {'error': e.toString()};
        }
      },
    );
  }

  static String _jsonEncode(dynamic v) {
    try {
      return jsonEncode(v);
    } catch (_) {
      return '{}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          InAppWebView(

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
              await _initDatafeedBridge(controller);
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

              // Apply the pending symbol if one was queued during loading
              if (_pendingSymbol != null) {
                _applyPendingSymbol();
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
