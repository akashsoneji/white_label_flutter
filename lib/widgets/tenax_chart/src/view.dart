import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'api.dart';
import 'controller.dart';
import 'models.dart';

/// Drop-in trading chart. Give it your [TenaxChartApi] and an initial symbol;
/// it hosts the obfuscated chart bundle (shipped inside this package) in a
/// WebView and wires every message for you.
///
/// ```dart
/// TenaxChartView(
///   api: myBrokerApi,
///   initialSymbol: 'BTCUSD',
///   initialResolution: '15m',
///   theme: ChartTheme.dark,
///   onControllerReady: (c) => _chart = c, // keep to push ticks/orders later
/// )
/// ```
class TenaxChartView extends StatefulWidget {
  const TenaxChartView({
    super.key,
    required this.api,
    required this.initialSymbol,
    this.initialResolution = '60',
    this.theme = ChartTheme.light,
    this.brokerConfig,
    this.onControllerReady,
    this.onError,
  });

  /// Your broker / Trade-Engine bridge.
  final TenaxChartApi api;

  /// Symbol to load first.
  final String initialSymbol;

  /// Timeframe to load first ('1','5','15m','60','1D' — as your feed expects).
  final String initialResolution;

  /// Start theme; change later via the controller.
  final ChartTheme theme;

  /// Optional per-broker live config ({'theme': {...}, 'orders': {...}}). One
  /// bundle, styled per broker at runtime — no rebuild.
  final Map<String, dynamic>? brokerConfig;

  /// Handed the controller once the chart is ready, so the app can push ticks,
  /// orders and theme changes over the session.
  final void Function(TenaxChartController controller)? onControllerReady;

  /// Surface chart / broker errors (rejected drag, socket drop) to the app.
  final void Function(Object error)? onError;

  @override
  State<TenaxChartView> createState() => _TenaxChartViewState();
}

class _TenaxChartViewState extends State<TenaxChartView> {
  late final TenaxChartController _controller;
  bool _handedOver = false;

  // Assets ship inside this package, so the WebView loads them from the
  // package-scoped asset path — the app depends on the package and nothing else.
  static const String _assetFile =
      'assets/chart/tenax/index.html';

  @override
  void initState() {
    super.initState();
    _controller = TenaxChartController(api: widget.api)
      ..onError = widget.onError;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: _assetFile,
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        supportZoom: false,
        // Canvas rendering; without hybrid composition Android scrolls at ~20fps.
        useHybridComposition: true,
        // The bundle is local; block it from wandering off to the network for
        // anything except what the app explicitly pushes.
        disableContextMenu: true,
        javaScriptEnabled: true,
        allowFileAccess: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: _controller.attach,
      onLoadStop: (_, __) async {
        // Seed the session config before the chart announces 'ready'; the
        // controller queues anything sent early and flushes on ready.
        if (widget.brokerConfig != null) {
          _controller.setConfig(
            theme: widget.brokerConfig!['theme'] as Map<String, dynamic>?,
            orders: widget.brokerConfig!['orders'] as Map<String, dynamic>?,
          );
        }
        await _controller.setTheme(widget.theme);
        await _controller.setSymbol(
          widget.initialSymbol,
          resolution: widget.initialResolution,
        );
        if (!_handedOver) {
          _handedOver = true;
          widget.onControllerReady?.call(_controller);
        }
      },
      onConsoleMessage: (_, msg) {
        debugPrint('TenaxChart JS Console [${msg.messageLevel}]: ${msg.message}');
        if (msg.messageLevel == ConsoleMessageLevel.ERROR) {
          widget.onError?.call(msg.message);
        }
      },
    );
  }
}
