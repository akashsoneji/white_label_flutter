import 'dart:async';
import 'dart:convert';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/services/chart_datafeed_bridge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChartInAppWebView
//
// Loads the broker's remote chart page (BASE_URL/mobile-chart?symbol=X&theme=Y).
// Symbol switches go through JS first (zero flicker / no page reload).
// Falls back to a URL reload with the new symbol only after 3 JS failures.
// ─────────────────────────────────────────────────────────────────────────────

class ChartInAppWebView extends StatefulWidget {
  /// Stable base URL e.g. "https://dev.tenaxcodecrm.com/mobile-chart?theme=dark"
  /// (no symbol in it — symbol is appended on first load and updated via JS).
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

  /// Symbol queued while the WebView was still loading.
  String? _pendingSymbol;
  Timer? _pendingSymbolTimer;

  /// Datafeed bridge — history + live ticks for the chart page.
  final ChartDatafeedBridge _df = ChartDatafeedBridge();

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Full initial URL with symbol baked in so the chart opens on the right symbol.
  String _urlWithSymbol(String symbol) {
    final clean =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;
    try {
      final uri = Uri.parse(widget.url);
      final params = Map<String, String>.from(uri.queryParameters);
      params['symbol'] = clean;
      return uri.replace(queryParameters: params).toString();
    } catch (_) {
      final base =
          widget.url.contains('?')
              ? '${widget.url}&symbol=${Uri.encodeComponent(clean)}'
              : '${widget.url}?symbol=${Uri.encodeComponent(clean)}';
      return base;
    }
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _startLoadingTimeout();
  }

  @override
  void didUpdateWidget(covariant ChartInAppWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // debugPrint(
      // '📊 ChartInAppWebView: didUpdateWidget - old: ${oldWidget.symbol}, new: ${widget.symbol}',
    // );

    // Base URL changed (e.g. theme toggle) — reload.
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
      _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_urlWithSymbol(widget.symbol))),
      );
      return;
    }

    // Symbol changed — try JS first (zero reload) or reload immediately if not ready.
    if (oldWidget.symbol != widget.symbol) {
      _pendingSymbol = widget.symbol;
      if (_isReady) {
        _applyPendingSymbol();
      }
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _pendingSymbolTimer?.cancel();
    _df.dispose();
    super.dispose();
  }

  void _startLoadingTimeout() {
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted || _isReady) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    });
  }

  // ─── Symbol switching ─────────────────────────────────────────────────────

  void _applyPendingSymbol() {
    _pendingSymbolTimer?.cancel();
    if (_pendingSymbol == null || !_isReady || _controller == null) return;

    final symbolToApply = _pendingSymbol!;
    _pendingSymbol = null;
    debugPrint('📊 Chart: applying symbol $symbolToApply');

    unawaited(
      updateSymbol(symbolToApply).then((success) {
        if (!mounted) return;
        debugPrint('📊 Chart: updateSymbol $symbolToApply → $success');
        if (!success) {
          debugPrint(
            '📊 Chart: JS update not available, reloading URL for $symbolToApply',
          );
          _controller?.loadUrl(
            urlRequest: URLRequest(url: WebUri(_urlWithSymbol(symbolToApply))),
          );
        }
      }),
    );
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Forces a complete reload of the WebView URL.
  /// Useful for recovering from deep sleep / background suspensions.
  void forceReload() {
    _retry();
  }

  /// Loads the chart URL with a specific symbol baked in.
  /// Used as a fallback when JS symbol switch fails (blank WebView after OS
  /// suspension or app kill). Resets ready/loading state so the loading
  /// indicator shows while the new URL loads.
  void loadUrlWithSymbol(String symbol) {
    if (_controller == null) return;
    final clean =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;
    if (!mounted) return;
    setState(() {
      _isReady = false;
      _isLoading = true;
      _hasError = false;
    });
    _startLoadingTimeout();
    _controller!.loadUrl(
      urlRequest: URLRequest(url: WebUri(_urlWithSymbol(clean))),
    );
  }

  /// Switch symbol via JS — returns true if the chart accepted it.
  Future<bool> updateSymbol(String symbol) async {
    // debugPrint('📊 ChartInAppWebView: updateSymbol called for $symbol');
    if (_controller == null || symbol.isEmpty) return false;
    if (!_isReady) {
      // debugPrint('📊 ChartInAppWebView: Not ready, storing as pendingSymbol');
      _pendingSymbol = symbol;
      return false;
    }

    // Strip broker suffix (.c / .m / .r) for fallback attempts.
    final symClean =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;

    String jsSource(String s) => '''
      (function() {
        var sym = ${_jsStr(s)};
        function trySet(t) {
          try { if (typeof selectedSymbol !== 'undefined') selectedSymbol = t; } catch(e) {}
          try {
            if (typeof window.__changeSymbol === 'function') {
              var res = window.__changeSymbol(t);
              if (res === true || res === undefined) return true;
            }
          } catch(e) {}
          try {
            if (typeof window.__setSymbol === 'function') {
              var res = window.__setSymbol(t);
              if (res === true || res === undefined) return true;
            }
          } catch(e) {}
          
          try {
            var w = window.__tvWidget || window.tvWidget || window.chartWidget || window.widget;
            if (w) {
              if (typeof w.chart === 'function' && w.chart() && typeof w.chart().setSymbol === 'function') {
                w.chart().setSymbol(t, function(){});
                return true;
              }
              if (typeof w.activeChart === 'function' && w.activeChart() && typeof w.activeChart().setSymbol === 'function') {
                w.activeChart().setSymbol(t, function(){});
                return true;
              }
              if (typeof w.setSymbol === 'function') {
                w.setSymbol(t, "5", function(){});
                return true;
              }
            }
          } catch(e) {}

          for (var prop in window) {
            try {
              if (prop !== 'webkit' && window[prop]) {
                if (typeof window[prop].setSymbol === 'function') {
                  window[prop].setSymbol(t, "5", function(){});
                  return true;
                }
                if (typeof window[prop].chart === 'function' && window[prop].chart() && typeof window[prop].chart().setSymbol === 'function') {
                  window[prop].chart().setSymbol(t, function(){});
                  return true;
                }
              }
            } catch(e) {}
          }
          
          return false;
        }
        if (trySet(sym)) return 'ok';
        return 'miss';
      })();
    ''';

    try {
      // debugPrint('📊 ChartInAppWebView: Executing JS for $symbol (attempt 1)');
      var res = await _controller!.evaluateJavascript(source: jsSource(symbol));
      if (res == 'ok') return true;

      // debugPrint(
        // '📊 ChartInAppWebView: Executing JS for $symClean (attempt 2)',
      // );
      res = await _controller!.evaluateJavascript(source: jsSource(symClean));
      if (res == 'ok') return true;

      return false;
    } catch (e) {
      debugPrint('📊 Chart updateSymbol error: $e');
      return false;
    }
  }

  static String _jsStr(String s) => '"${s.replaceAll('"', r'\"')}"';

  Future<void> updateNativeTrades(String tradesJson) async {
    if (_controller == null || !_isReady) return;
    try {
      await _controller!.evaluateJavascript(
        source: '''
        (function() {
          try {
            if (typeof updateNativeTrades === 'function') {
              updateNativeTrades($tradesJson); return true;
            }
          } catch(e) {}
          return false;
        })();
      ''',
      );
    } catch (_) {}
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
    await _controller!.loadUrl(
      urlRequest: URLRequest(url: WebUri(_urlWithSymbol(widget.symbol))),
    );
  }

  // ─── Datafeed bridge ──────────────────────────────────────────────────────

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
                accountNumber =
                    Get.find<AccountController>()
                        .activeMT5Account
                        ?.metaAccountNumber;
              }
              result = await _df.resolveSymbol(
                symbol: payload['sym']?.toString() ?? '',
                accountNumber: accountNumber,
              );
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
              _df.unsubscribeBars(payload['uid']?.toString() ?? '');
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          InAppWebView(
            // Symbol baked into initial URL so the chart opens on the right symbol.
            initialUrlRequest: URLRequest(
              url: WebUri(_urlWithSymbol(widget.symbol)),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              // LOAD_CACHE_ELSE_NETWORK: serves from disk/memory cache when
              // available (populated by ChartWebViewPrewarmer) and only falls
              // back to network on a miss.  This is what cuts 4-6s → <1s.
              cacheEnabled: true,
              cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
              domStorageEnabled: true,
              databaseEnabled: true,
              clearCache: false,
              supportZoom: false,
            ),
            onWebViewCreated: (controller) async {
              final startTime = DateTime.now();
              debugPrint(
                '⏱️ Chart WebView: CREATED at ${startTime.toIso8601String()}',
              );
              _controller = controller;
              await _initDatafeedBridge(controller);
              // If pre-warmed WebView already finished loading:
              final progress = await controller.getProgress();
              debugPrint('⏱️ Chart WebView: progress on create = $progress%');
              if (progress == 100) {
                if (!mounted) return;
                _loadingTimeout?.cancel();
                setState(() {
                  _isLoading = false;
                  _hasError = false;
                  _isReady = true;
                });
                widget.onReady?.call();
                if (_pendingSymbol != null) {
                  _applyPendingSymbol();
                }
              }
            },
            shouldOverrideUrlLoading: (controller, action) async {
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, url) {
              debugPrint(
                '⏱️ Chart WebView: LOAD START at ${DateTime.now().toIso8601String()} for url: $url',
              );
              if (!mounted) return;
              if (!_isReady) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onLoadStop: (controller, url) async {
              debugPrint(
                '⏱️ Chart WebView: LOAD STOP at ${DateTime.now().toIso8601String()} for url: $url',
              );
              if (!mounted) return;
              _loadingTimeout?.cancel();
              setState(() {
                _isLoading = false;
                _hasError = false;
                _isReady = true;
              });
              widget.onReady?.call();

              // If a symbol was requested while the WebView was loading, apply it now
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
              if (kDebugMode)
                debugPrint('Chart WebView renderer died: $detail');
              setState(() {
                _hasError = true;
                _isLoading = false;
                _isReady = false;
              });
            },
          ),

          // ── Loading overlay ─────────────────────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.transparent,
              child: Center(
                  child: CommonLoadingWidget(
                    message: Get.find<LanguageService>().tr(
                      'chart_inapp_webview_loading_chart',
                    ),
                    size: 40.0,
                  color: AppColors.primary,
                ),
              ),
            ),

          // ── Error overlay ───────────────────────────────────────────────
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
    );
  }
}
