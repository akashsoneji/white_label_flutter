// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:crm_app/constants/color.dart';
// import 'package:crm_app/constants/text_styles.dart';
// import 'package:crm_app/widgets/common_loading_widget.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// class FixedSizeWebView extends StatefulWidget {
//   final String url;

//   const FixedSizeWebView({required this.url, super.key});

//   @override
//   State<FixedSizeWebView> createState() => _FixedSizeWebViewState();
// }

// class _FixedSizeWebViewState extends State<FixedSizeWebView> {
//   late final WebViewController _controller;
//   bool _isLoading = true;
//   bool _hasError = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeWebView();
//   }

//   void _initializeWebView() {
//     final navigationDelegate = WebViewUtils.getOptimizedNavigationDelegate(
//       onPageStarted: () {
//         setState(() {
//           _isLoading = true;
//           _hasError = false;
//         });
//       },
//       onPageFinished: () {
//         setState(() {
//           _isLoading = false;
//         });
//       },
//       onError: () {
//         setState(() {
//           _hasError = true;
//           _isLoading = false;
//         });
//       },
//     );

//     _controller = WebViewUtils.createOptimizedController(
//       url: widget.url,
//       navigationDelegate: navigationDelegate,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: double.maxFinite,
//       height: 490.h,
//       child: Stack(
//         children: [
//           WebViewWidget(controller: _controller),
//           if (_isLoading)
//             Container(
//               width: double.maxFinite,
//               height: 490.h,
//               color: AppColors.whiteColor,
//               child: const Center(child: OverlayLoadingWidget()),
//             ),
//           if (_hasError)
//             Container(
//               width: double.maxFinite,
//               height: 490.h,
//               color: AppColors.whiteColor,
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.error_outline, size: 48.h, color: Colors.grey),
//                     SizedBox(height: 16.h),
//                     Text(
//                       'Failed to load chart',
//                       style: TextStyle(
//                         fontSize: 16.sp,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     SizedBox(height: 8.h),
//                     SizedBox(
//                       height: 42.h,
//                       width: 120.w,
//                       child: OutlinedButton(
//                         onPressed: () {
//                           setState(() {
//                             _hasError = false;
//                             _isLoading = true;
//                           });
//                           _initializeWebView();
//                         },
//                         style: OutlinedButton.styleFrom(
//                           // padding: EdgeInsets.symmetric(vertical: 16.h),
//                           backgroundColor: AppColors.primary,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8.r),
//                           ),
//                         ),
//                         child: Text(
//                           'Retry',
//                           style: AppTextStyles.label.copyWith(
//                             fontSize: 12.sp,
//                             fontWeight: FontWeight.w600,
//                             color: AppColors.whiteColor,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// class WebViewUtils {
//   /// Creates optimized NavigationDelegate with error handling
//   static NavigationDelegate getOptimizedNavigationDelegate({
//     required VoidCallback onPageStarted,
//     required VoidCallback onPageFinished,
//     required VoidCallback onError,
//   }) {
//     return NavigationDelegate(
//       onPageStarted: (String url) {
//         onPageStarted();
//       },
//       onPageFinished: (String url) {
//         onPageFinished();
//       },
//       onWebResourceError: (WebResourceError error) {
//         onError();
//       },
//       // Prevent navigation to external URLs
//       onNavigationRequest: (NavigationRequest request) {
//         // Only allow navigation to the original URL or relative paths
//         if (request.url.startsWith('http') &&
//             !request.url.contains('my.app.com')) {
//           return NavigationDecision.prevent;
//         }
//         return NavigationDecision.navigate;
//       },
//     );
//   }

//   /// Creates a WebViewController with optimized settings
//   static WebViewController createOptimizedController({
//     required String url,
//     required NavigationDelegate navigationDelegate,
//   }) {
//     return WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setBackgroundColor(AppColors.whiteColor)
//       ..enableZoom(false)
//       ..setNavigationDelegate(navigationDelegate)
//       ..loadRequest(Uri.parse(url));
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'; // For rootBundle

class FixedSizeWebView extends StatefulWidget {
  final String url;
  final String symbol;

  const FixedSizeWebView({required this.url, required this.symbol, super.key});

  @override
  State<FixedSizeWebView> createState() => FixedSizeWebViewState();
}

class FallbackChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey[300]!
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    final fillPaint =
        Paint()
          ..color = Colors.grey[200]!.withOpacity(0.3)
          ..style = PaintingStyle.fill;

    // Draw grid lines
    for (int i = 0; i <= 10; i++) {
      final y = (size.height / 10) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (int i = 0; i <= 8; i++) {
      final x = (size.width / 8) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw a simple candlestick pattern
    final candleWidth = size.width * 0.08;
    final candleSpacing = size.width * 0.1;

    for (int i = 0; i < 6; i++) {
      final x = candleSpacing + (i * candleSpacing);
      final open = size.height * 0.3 + (i * 20);
      final close = size.height * 0.4 + (i * 15);
      final high = size.height * 0.2 + (i * 10);
      final low = size.height * 0.5 + (i * 25);

      final bodyHeight = (close - open).abs();
      final bodyTop = open < close ? open : close;

      canvas.drawRect(
        Rect.fromLTWH(x - candleWidth / 2, bodyTop, candleWidth, bodyHeight),
        fillPaint,
      );

      canvas.drawLine(Offset(x, high), Offset(x, low), paint);
    }

    final trendPaint =
        Paint()
          ..color = Colors.blue[300]!.withOpacity(0.6)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.7),
      Offset(size.width * 0.9, size.height * 0.3),
      trendPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Make state class accessible for GlobalKey usage
class FixedSizeWebViewState extends State<FixedSizeWebView>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isWebViewReady = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _timeoutTimer;
  Timer? _healthCheckTimer;
  Timer? _debounceTimer;
  bool _wasVisible = true;
  String? _cachedUrl;
  String?
  _previousSymbol; // Track previous symbol to prevent unnecessary updates
  bool _isUpdating = false; // Flag to prevent concurrent updates

  bool get _hasRemoteUrl => widget.url.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWebView();
  }

  @override
  void didUpdateWidget(FixedSizeWebView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle URL changes (full reinitialization needed)
    if (oldWidget.url != widget.url) {
      _retryCount = 0;
      _previousSymbol = null; // Reset symbol tracking
      _initializeWebView();
      return;
    }

    // Handle symbol changes - optimize to use JavaScript update if WebView is ready
    if (oldWidget.symbol != widget.symbol) {
      // Cancel any pending debounce timer
      _debounceTimer?.cancel();

      // Debounce rapid symbol changes (300ms delay)
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;

        // Check if symbol actually changed (prevent duplicate updates)
        if (_previousSymbol == widget.symbol) {
          print('Symbol unchanged, skipping update: ${widget.symbol}');
          return;
        }

        // If WebView is ready, use JavaScript update (faster, no full reload)
        if (_isWebViewReady && _controller != null && !_isUpdating) {
          print('Updating chart symbol via JavaScript: ${widget.symbol}');
          _updateSymbolWithJavaScript(widget.symbol);
        } else {
          // WebView not ready, need full reinitialization
          print(
            'WebView not ready, reinitializing with symbol: ${widget.symbol}',
          );
          _retryCount = 0;
          _previousSymbol = null;
          _initializeWebView();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _healthCheckTimer?.cancel();
    _debounceTimer?.cancel();

    // Safely dispose WebView controller
    try {
      if (_controller != null) {
        _isWebViewReady = false;
        // Clear cache and dispose controller safely
        _controller?.clearCache();
        _controller = null;
      }
    } catch (e) {
      print('Error disposing WebView: $e');
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('App resumed - checking WebView state');
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        print('App paused - saving WebView state');
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        print('App inactive');
        break;
      case AppLifecycleState.detached:
        print('App detached');
        break;
      case AppLifecycleState.hidden:
        print('App hidden');
        break;
    }
  }

  void _handleAppPaused() {
    _wasVisible = false;
    _cachedUrl = widget.url; // Cache current URL for faster recovery
    print('App paused - caching URL: $_cachedUrl');
    // Don't clear the WebView when app goes to background
    // Just mark that it was paused
  }

  void _handleAppResumed() {
    if (!_wasVisible && mounted) {
      _wasVisible = true;

      // Only refresh if WebView is not ready or if there's an error
      // Don't refresh if chart is already loaded and working
      if (!_isWebViewReady || _hasError) {
        print(
          'App resumed from background - reloading chart with symbol: ${widget.symbol}',
        );

        // Show loading immediately for better UX
        setState(() {
          _isLoading = true;
          _hasError = false;
          _isWebViewReady = false;
        });

        // Reinitialize only if needed
        print('Reinitializing WebView with symbol: ${widget.symbol}');
        _retryCount = 0;
        _previousSymbol = null;
        _initializeWebView();
      } else {
        print('App resumed - chart already loaded, keeping alive');
        // Chart is already loaded, just verify it's still working
        // Don't reload unnecessarily
      }
    }
  }

  // ignore: unused_element
  void _instantRefresh() async {
    try {
      if (_controller != null) {
        print('Instant WebView refresh with symbol: ${widget.symbol}');
        // First update the symbol, then refresh the chart
        await _controller!.runJavaScript('''
          if (typeof updateSymbol === 'function') {
            updateSymbol("${widget.symbol}");
          } else if (typeof selectedSymbol !== 'undefined') {
            selectedSymbol = "${widget.symbol}";
          }
        ''');

        // Use JavaScript to refresh only the chart content without full page reload
        await _controller!.runJavaScript('''
          if (typeof window.location !== 'undefined') {
            // Try to refresh chart data without full reload
            if (typeof refreshChart === 'function') {
              refreshChart();
            } else if (typeof window.chart !== 'undefined' && window.chart.refresh) {
              window.chart.refresh();
            } else {
              // Fallback to location reload
              window.location.reload();
            }
          }
        ''');

        // Hide loading after successful refresh
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isWebViewReady = true;
              });
            }
          });
        }
      }
    } catch (e) {
      print('Instant refresh failed, using fallback: $e');
      _refreshWebView();
    }
  }

  void _refreshWebView() async {
    if (!mounted || _controller == null || !_isWebViewReady) {
      return;
    }

    try {
      print('Refreshing WebView content');
      await _controller!.reload();
    } catch (e) {
      print('Error refreshing WebView: $e');
      // If refresh fails, reinitialize
      if (mounted) {
        _retryCount = 0;
        _initializeWebView();
      }
    }
  }

  // Add a method to check WebView health
  void _checkWebViewHealth() async {
    if (!mounted || _controller == null || !_isWebViewReady) {
      return;
    }

    try {
      // Try to evaluate a simple JavaScript to check if WebView is responsive
      final result = await _controller!.runJavaScriptReturningResult(
        'document.readyState',
      );
      print('WebView health check result: $result');

      // If the result indicates an error, refresh the WebView
      if (mounted &&
          (result.toString().contains('error') || result.toString().isEmpty)) {
        print('WebView appears unhealthy, refreshing...');
        _refreshWebView();
      }
    } catch (e) {
      print('WebView health check failed: $e');
      if (mounted) {
        // If health check fails, reinitialize
        _retryCount = 0;
        _initializeWebView();
      }
    }
  }

  // ignore: unused_element
  Future<void> _quickInitializeWebView() async {
    print('Quick WebView initialization');
    if (!_hasRemoteUrl) {
      print(
        'No remote chart URL provided, falling back to local asset loader even for quick init.',
      );
      await _initializeWebView(useQuickTimeout: true);
      return;
    }

    try {
      _timeoutTimer?.cancel();

      if (Platform.isAndroid) {
        await WebViewPlatform.instance;
      }

      final navigationDelegate = WebViewUtils.getOptimizedNavigationDelegate(
        onPageStarted: () {
          if (mounted) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            _startTimeoutTimer(
              duration: const Duration(seconds: 8),
              logLabel: 'Quick WebView loading timeout',
            );
          }
        },
        onPageFinished: () {
          if (mounted) {
            _timeoutTimer?.cancel();
            setState(() {
              _isLoading = false;
              _isWebViewReady = true;
              _retryCount = 0;
            });
            _startHealthCheckTimer();
          }
        },
        onError: () {
          if (mounted) {
            _timeoutTimer?.cancel();
            _handleWebViewError();
          }
        },
      );

      _controller = WebViewUtils.createFastRecoveryController(
        url: widget.url,
        navigationDelegate: navigationDelegate,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Quick WebView initialization error: $e');
      _timeoutTimer?.cancel();
      if (mounted) {
        _handleWebViewError();
      }
    }
  }

  Future<void> _initializeWebView({bool useQuickTimeout = false}) async {
    try {
      // Cancel any existing timeout timer
      _timeoutTimer?.cancel();

      // Platform-specific WebView initialization
      // ✅ CRITICAL: iOS also needs WebViewPlatform initialization
      await WebViewPlatform.instance;

      final navigationDelegate = WebViewUtils.getOptimizedNavigationDelegate(
        onPageStarted: () {
          if (mounted) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            _startTimeoutTimer(
              duration:
                  useQuickTimeout
                      ? const Duration(seconds: 8)
                      : const Duration(seconds: 15),
              logLabel:
                  useQuickTimeout
                      ? 'Quick WebView loading timeout'
                      : 'WebView loading timeout',
            );
          }
        },
        onPageFinished: () async {
          if (mounted) {
            _timeoutTimer?.cancel();

            // ✅ FIX FOR iOS: Ensure symbol is set after page fully loads
            // This is critical for iOS where external scripts (TradingView) load asynchronously
            if (_controller != null) {
              try {
                // Remove suffix for chart display (XAUUSD.c -> XAUUSD)
                String chartSymbol = widget.symbol;
                if (chartSymbol.contains('.')) {
                  chartSymbol = chartSymbol.substring(
                    0,
                    chartSymbol.lastIndexOf('.'),
                  );
                }

                // Wait for TradingView script to load (it loads asynchronously)
                // Retry a few times if TradingView is not ready yet
                bool symbolSet = false;
                for (int attempt = 0; attempt < 5 && !symbolSet; attempt++) {
                  await Future.delayed(
                    Duration(milliseconds: 300 + (attempt * 200)),
                  );

                  try {
                    // Check if TradingView is available
                    final tradingViewReady = await _controller!
                        .runJavaScriptReturningResult(
                          'typeof TradingView !== "undefined"',
                        );

                    if (tradingViewReady.toString() == 'true' || attempt >= 3) {
                      // Set symbol and update chart
                      await _controller!.runJavaScript('''
                        if (typeof selectedSymbol !== 'undefined') {
                          selectedSymbol = "$chartSymbol";
                        }
                        if (typeof updateSymbol === 'function') {
                          updateSymbol("$chartSymbol");
                        } else if (typeof createTradingViewChart === 'function') {
                          createTradingViewChart("$chartSymbol");
                        }
                      ''');
                      print(
                        '✅ Chart symbol set after page load (attempt ${attempt + 1}): $chartSymbol',
                      );
                      symbolSet = true;
                    } else {
                      print(
                        '⏳ Waiting for TradingView to load (attempt ${attempt + 1}/5)...',
                      );
                    }
                  } catch (e) {
                    print('⚠️ Error checking TradingView availability: $e');
                    // Try to set symbol anyway on last attempt
                    if (attempt >= 3) {
                      await _controller!.runJavaScript('''
                        if (typeof selectedSymbol !== 'undefined') {
                          selectedSymbol = "$chartSymbol";
                        }
                        if (typeof updateSymbol === 'function') {
                          updateSymbol("$chartSymbol");
                        }
                      ''');
                      symbolSet = true;
                    }
                  }
                }
              } catch (e) {
                print('⚠️ Error setting symbol after page load: $e');
              }
            }

            setState(() {
              _isLoading = false;
              _isWebViewReady = true;
              _retryCount = 0; // Reset retry count on success
            });
            // Track current symbol after successful load
            _previousSymbol = widget.symbol;
            _isUpdating = false; // Reset update flag
            // Start periodic health check
            _startHealthCheckTimer();
          }
        },
        onError: () {
          // Detailed error logging is handled by onWebResourceError in NavigationDelegate
          if (mounted) {
            _timeoutTimer?.cancel();
            _handleWebViewError();
          }
        },
      );

      WebViewController controller;

      if (widget.url.startsWith('http')) {
        print('🌐 Loading remote URL: ${widget.url}');
        controller = WebViewUtils.createOptimizedController(
          url: widget.url,
          navigationDelegate: navigationDelegate,
        );
      } else {
        // Load HTML content and prepare symbol
        final rawHtml = await rootBundle.loadString('assets/chart/index.html');

        // Remove suffix for chart display (XAUUSD.c -> XAUUSD)
        String chartSymbol = widget.symbol;
        if (chartSymbol.contains('.')) {
          chartSymbol = chartSymbol.substring(0, chartSymbol.lastIndexOf('.'));
        }

        // Replace the placeholder symbol with the actual symbol
        final modifiedHtml = rawHtml.replaceFirst(
          RegExp(r'let selectedSymbol\s*=\s*".*?";'),
          'let selectedSymbol = "$chartSymbol";',
        );

        controller =
            WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setBackgroundColor(AppColors.whiteColor)
              ..enableZoom(false)
              ..setNavigationDelegate(navigationDelegate)
              ..setUserAgent(
                Platform.isIOS
                    ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1'
                    : 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
              )
              ..setBackgroundColor(Colors.transparent);

        if (Platform.isAndroid) {
          controller
            ..enableZoom(false)
            ..setBackgroundColor(Colors.transparent);
        }

        try {
          print('📦 Loading HTML asset: assets/chart/index.html');
          await controller.loadFlutterAsset('assets/chart/index.html');
          print('✅ HTML asset loaded successfully');
        } catch (e) {
          print('❌ Error loading HTML asset: $e');
          print('🔄 Attempting alternative loading method...');
          // Fallback: Try loading HTML string directly
          try {
            await controller.loadHtmlString(modifiedHtml);
            print('✅ HTML loaded via loadHtmlString fallback');
          } catch (e2) {
            print('❌ Both loading methods failed: $e2');
            rethrow;
          }
        }
      }

      print(
        '✅ WebView initiated with symbol: ${widget.symbol} (Remote: ${widget.url.startsWith('http')})',
      );

      _controller = controller;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('WebView initialization error: $e');
      _timeoutTimer?.cancel();
      if (mounted) {
        _handleWebViewError();
      }
    }
  }

  /// Update native trades via JavaScript bridge
  Future<void> updateNativeTrades(String tradesJson) async {
    if (!mounted || _controller == null || !_isWebViewReady) {
      return;
    }

    try {
      await _controller?.runJavaScript(
        'window.updateNativeTrades(\'$tradesJson\');',
      );
      // print('✅ Native trades updated in chart');
    } catch (e) {
      print('❌ Error updating native trades: $e');
    }
  }

  /// Internal method to update symbol via JavaScript (used by didUpdateWidget)
  Future<void> _updateSymbolWithJavaScript(String newSymbol) async {
    if (!mounted || _controller == null || !_isWebViewReady || _isUpdating) {
      print('Cannot update symbol - WebView not ready or update in progress');
      return;
    }

    // Prevent concurrent updates
    _isUpdating = true;
    _previousSymbol = newSymbol;

    print('🔄 Updating chart symbol via JavaScript: $newSymbol');
    try {
      // Remove suffix for chart display (XAUUSD.c -> XAUUSD)
      String chartSymbol = newSymbol;
      if (chartSymbol.contains('.')) {
        chartSymbol = chartSymbol.substring(0, chartSymbol.lastIndexOf('.'));
      }

      await _controller?.runJavaScript('updateSymbol("$chartSymbol");');
      print('✅ updateSymbol JavaScript command sent successfully.');

      // Verify that the value is updated in HTML
      if (mounted && _controller != null) {
        final result = await _controller?.runJavaScriptReturningResult(
          'selectedSymbol',
        );
        print('✅ HTML verification - selectedSymbol = $result');
      }
    } catch (e) {
      print('❌ Error while sending or verifying symbol in HTML: $e');
      // If JavaScript update fails, fallback to full reinitialization
      if (mounted) {
        print('🔄 Falling back to full WebView reinitialization');
        _retryCount = 0;
        _previousSymbol = null;
        _initializeWebView();
      }
    } finally {
      if (mounted) {
        _isUpdating = false;
      }
    }
  }

  /// Public method to update the symbol dynamically at runtime.
  void updateSymbol(String newSymbol) async {
    if (!mounted || _controller == null || !_isWebViewReady) {
      print('Cannot update symbol - WebView not ready');
      return;
    }

    // Use internal method
    await _updateSymbolWithJavaScript(newSymbol);
  }

  void _startTimeoutTimer({
    Duration duration = const Duration(seconds: 15),
    String logLabel = 'WebView loading timeout',
  }) {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(duration, () {
      if (mounted && _isLoading) {
        print(logLabel);
        _handleWebViewError();
      }
    });
  }

  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isWebViewReady && _wasVisible) {
        _checkWebViewHealth();
      }
    });
  }

  void _handleWebViewError() {
    if (mounted) {
      _healthCheckTimer?.cancel();
      setState(() {
        _hasError = true;
        _isLoading = false;
        _isWebViewReady = false;
      });
    }
  }

  void _retryLoading() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      print('Retrying WebView load (attempt $_retryCount/$_maxRetries)');

      if (mounted) {
        setState(() {
          _hasError = false;
          _isLoading = true;
          _isWebViewReady = false;
        });

        // Clear cache and retry
        _controller?.clearCache();
        _initializeWebView();
      }
    } else {
      print('Max retry attempts reached');
    }
  }

  Widget _buildFallbackChart() {
    return Container(
      width: double.maxFinite,
      height: 490.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[50]!, Colors.grey[100]!],
        ),
      ),
      child: CustomPaint(
        painter: FallbackChartPainter(),
        size: Size(double.maxFinite, 490.h),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: 490.h,
      child: Stack(
        children: [
          if (_controller != null && _isWebViewReady && mounted)
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // This helps detect if the widget is still visible
                return false;
              },
              child: Builder(
                builder: (context) {
                  try {
                    return WebViewWidget(controller: _controller!);
                  } catch (e) {
                    print('Error building WebViewWidget: $e');
                    return Container(
                      width: double.maxFinite,
                      height: 490.h,
                      color: AppColors.whiteColor,
                      child: Center(
                        child: Text(
                          'Chart unavailable',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          if (_isLoading)
            Container(
              width: double.maxFinite,
              height: 490.h,
              color: AppColors.whiteColor,
              child: const Center(child: OverlayLoadingWidget()),
            ),
          if (_hasError)
            Container(
              width: double.maxFinite,
              height: 490.h,
              color: AppColors.whiteColor,
              child: Stack(
                children: [
                  // Fallback chart background
                  _buildFallbackChart(),
                  // Error overlay
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48.h,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            _retryCount == 0
                                ? 'Failed to load chart'
                                : 'Chart loading failed',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Check your internet connection',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (_retryCount > 0) ...[
                            SizedBox(height: 8.h),
                            Text(
                              'Attempt $_retryCount/$_maxRetries',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                          SizedBox(height: 16.h),
                          SizedBox(
                            height: 42.h,
                            width: 120.w,
                            child: OutlinedButton(
                              onPressed:
                                  _retryCount < _maxRetries
                                      ? _retryLoading
                                      : null,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Text(
                                _retryCount < _maxRetries
                                    ? 'Retry'
                                    : 'Max Retries Reached',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _retryCount < _maxRetries
                                          ? AppColors.whiteColor
                                          : Colors.grey,
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
        ],
      ),
    );
  }
}

class WebViewUtils {
  /// Creates optimized NavigationDelegate with error handling
  static NavigationDelegate getOptimizedNavigationDelegate({
    required VoidCallback onPageStarted,
    required VoidCallback onPageFinished,
    required VoidCallback onError,
  }) {
    return NavigationDelegate(
      onPageStarted: (String url) {
        print('WebView page started loading: $url');
        onPageStarted();
      },
      onPageFinished: (String url) {
        print('WebView page finished loading: $url');
        onPageFinished();
      },
      onWebResourceError: (WebResourceError error) {
        print(
          'WebView resource error: ${error.description} (Code: ${error.errorCode})',
        );
        print('Error URL: ${error.url}');
        onError();
      },
      onNavigationRequest: (NavigationRequest request) {
        print('WebView navigation request: ${request.url}');
        // Allow TradingView domains for chart iframe
        final url = request.url.toLowerCase();
        final isTradingView =
            url.contains('tradingview.com') ||
            url.contains('s.tradingview.com');
        final isPipze = url.contains('my.pipze.com');
        final isLocal =
            url.startsWith('file://') ||
            url.startsWith('flutter-asset://') ||
            url.startsWith('data:');

        // Block only non-whitelisted external URLs
        if (request.url.startsWith('http') &&
            !isTradingView &&
            !isPipze &&
            !isLocal) {
          print('Blocking external navigation to: ${request.url}');
          return NavigationDecision.prevent;
        }

        // Allow TradingView, app, and local URLs
        print('Allowing navigation to: ${request.url}');
        return NavigationDecision.navigate;
      },
      onUrlChange: (UrlChange change) {
        print('WebView URL changed: ${change.url}');
      },
    );
  }

  /// Creates a WebViewController with optimized settings
  static WebViewController createOptimizedController({
    required String url,
    required NavigationDelegate navigationDelegate,
  }) {
    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(AppColors.whiteColor)
          ..enableZoom(false)
          ..setNavigationDelegate(navigationDelegate)
          ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
          )
          ..setBackgroundColor(Colors.transparent);

    // Add platform-specific optimizations
    if (Platform.isAndroid) {
      controller
        ..enableZoom(false)
        ..setBackgroundColor(Colors.transparent);
    }

    // Load the URL
    try {
      controller.loadRequest(Uri.parse(url));
    } catch (e) {
      print('Error parsing URL: $url - $e');
      throw Exception('Invalid URL: $url');
    }

    return controller;
  }

  /// Creates a WebViewController with fast recovery settings
  static WebViewController createFastRecoveryController({
    required String url,
    required NavigationDelegate navigationDelegate,
  }) {
    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.transparent)
          ..enableZoom(false)
          ..setNavigationDelegate(navigationDelegate)
          ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
          );

    // Load the URL immediately without additional checks
    try {
      controller.loadRequest(Uri.parse(url));
    } catch (e) {
      print('Error parsing URL for fast recovery: $url - $e');
      throw Exception('Invalid URL: $url');
    }

    return controller;
  }

  /// Creates a WebViewController that loads a local HTML asset
  static WebViewController createOptimizedControllerFromAsset({
    required String assetPath,
    required NavigationDelegate navigationDelegate,
  }) {
    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(AppColors.whiteColor)
          ..enableZoom(false)
          ..setNavigationDelegate(navigationDelegate)
          ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
          )
          ..setBackgroundColor(Colors.transparent);

    if (Platform.isAndroid) {
      controller
        ..enableZoom(false)
        ..setBackgroundColor(Colors.transparent);
    }

    // Load the local HTML asset
    try {
      controller.loadFlutterAsset(assetPath);
    } catch (e) {
      print('Error loading local asset: $assetPath - $e');
      throw Exception('Invalid asset: $assetPath');
    }

    return controller;
  }

  /// Check network connectivity by making a simple HTTP request
  static Future<bool> checkConnectivity() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://www.google.com'),
            headers: {'Connection': 'close'},
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Connectivity check failed: $e');
      return false;
    }
  }

  /// Check if the specific URL is reachable
  static Future<bool> checkUrlReachability(String url) async {
    try {
      final response = await http
          .head(Uri.parse(url), headers: {'Connection': 'close'})
          .timeout(const Duration(seconds: 10));
      return response.statusCode < 400;
    } catch (e) {
      print('URL reachability check failed for $url: $e');
      return false;
    }
  }
}
