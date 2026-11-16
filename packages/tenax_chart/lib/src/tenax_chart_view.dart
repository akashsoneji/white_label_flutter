import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'messages.dart';
import 'models/tenax_bar.dart';
import 'models/tenax_order.dart';
import 'tenax_chart_config.dart';
import 'tenax_chart_controller.dart';
import 'tenax_chart_data_source.dart';

/// The bundled Tenax Chart in a WebView, fed entirely by [dataSource].
///
/// Symbol, interval and theme changes are sent as messages; the page is only
/// reloaded when the widget is recreated.
class TenaxChartView extends StatefulWidget {
  const TenaxChartView({
    super.key,
    required this.config,
    required this.dataSource,
    this.controller,
    this.onEvent,
    this.onActionError,
    this.placeholder,
  });

  final TenaxChartConfig config;
  final TenaxChartDataSource dataSource;

  /// Optional, to send extra messages from outside. Must not change between
  /// rebuilds.
  final TenaxChartController? controller;

  /// Every event from the chart, after the view has handled it.
  final ValueChanged<TenaxChartEvent>? onEvent;

  /// The broker refused an SL/TP change or a close. The chart has been
  /// snapped back to the server state already.
  final ValueChanged<Object>? onActionError;

  /// Shown while the first bars page (and its display offset) loads.
  final Widget? placeholder;

  @override
  State<TenaxChartView> createState() => _TenaxChartViewState();
}

class _TenaxChartViewState extends State<TenaxChartView>
    with WidgetsBindingObserver {
  static const String _assetPath =
      'packages/tenax_chart/assets/chart/index.html';
  static const Duration _tailInterval = Duration(seconds: 2);
  static const int _tailLimit = 3;

  late final TenaxChartController _chart;
  late final bool _ownsController;
  StreamSubscription<TenaxChartEvent>? _eventsSub;

  int? _offsetMinutes;
  TenaxBarsPage? _prefetched;
  String? _prefetchedKey;

  final List<StreamSubscription<dynamic>> _seriesSubs = [];
  Timer? _tailTimer;
  bool _tailInFlight = false;
  int _seriesSeq = 0;
  bool _paused = false;

  // The series being fed. Starts from the config; the trader's symbol or
  // timeframe pick inside the chart moves it, as does a new config value.
  late String _symbol = widget.config.symbol;
  late String _interval = widget.config.interval;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _chart = widget.controller ?? TenaxChartController();
    _eventsSub = _chart.events.listen(_onChartEvent);

    tenaxChartDebugLog('mount symbol=$_symbol tf=$_interval');
    final knownOffset = widget.config.displayOffsetMinutes;
    if (knownOffset != null) {
      _offsetMinutes = knownOffset;
    } else {
      unawaited(_prefetchFirstPage());
    }
  }

  @override
  void didUpdateWidget(TenaxChartView old) {
    super.didUpdateWidget(old);
    final config = widget.config;
    // Only a changed config moves the series; an unchanged one must not undo
    // a timeframe the trader picked inside the chart. A config that matches
    // what the chart already shows (the host echoing that pick) is a no-op.
    final configMoved = old.config.symbol != config.symbol ||
        old.config.interval != config.interval;
    final symbolChanged = configMoved && config.symbol != _symbol;
    final intervalChanged = configMoved && config.interval != _interval;
    if (symbolChanged || intervalChanged) {
      tenaxChartDebugLog('app changed series '
          '$_symbol/$_interval → ${config.symbol}/${config.interval}');
      _symbol = config.symbol;
      _interval = config.interval;
    }

    if (symbolChanged) {
      _chart.setSymbol(config.symbol, interval: config.interval);
    } else if (intervalChanged) {
      _chart.setInterval(config.interval);
    }
    if (symbolChanged || intervalChanged || old.dataSource != widget.dataSource) {
      unawaited(_openSeries());
    }

    final isExplicitTheme =
        config.themeMode == 'dark' || config.themeMode == 'light';
    if (old.config.themeMode != config.themeMode && isExplicitTheme) {
      _chart.setTheme(config.themeMode);
    }
    final colors = config.themeColors;
    if (colors != null && !mapEquals(old.config.themeColors, colors)) {
      _chart.setConfig(theme: colors);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // flutter.md §2b: stop the tail refresh and the bar subscription while
    // hidden; reopening reloads history, so the gap is filled.
    if (state == AppLifecycleState.paused) {
      tenaxChartDebugLog('app paused: closing live series');
      _paused = true;
      _seriesSeq++;
      _closeSeries();
    } else if (state == AppLifecycleState.resumed && _paused) {
      tenaxChartDebugLog('app resumed: reloading series');
      _paused = false;
      unawaited(_openSeries());
    }
  }

  @override
  void dispose() {
    tenaxChartDebugLog('dispose symbol=$_symbol tf=$_interval');
    WidgetsBinding.instance.removeObserver(this);
    _seriesSeq++;
    _closeSeries();
    _eventsSub?.cancel();
    if (_ownsController) {
      _chart.dispose();
    } else {
      _chart.detach();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = _offsetMinutes;
    if (offset == null) return widget.placeholder ?? const SizedBox.expand();

    final boot = jsonEncode(
      widget.config.toBootJson(displayOffsetMinutes: offset),
    );
    return InAppWebView(
      initialFile: _assetPath,
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: 'window.TENAX_CHART_BOOT = $boot;',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
        // index.html pads #app by env(safe-area-inset-*). On edge-to-edge
        // Android the WebView reports the status/nav bar insets even when it
        // sits mid-screen, which leaves empty bands above and below the chart.
        // The Flutter host owns safe areas (SafeArea), so drop that padding.
        UserScript(
          source: "var s=document.createElement('style');"
              "s.textContent='#app{padding:0 !important}';"
              'document.head.appendChild(s);',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        supportZoom: false,
        useHybridComposition: true,
      ),
      // The chart pans and pinch-zooms itself; without this a parent
      // PageView or scroll view takes the drag.
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      onLoadStop: (_, url) => tenaxChartDebugLog('page loaded $url'),
      onConsoleMessage: (_, console) => tenaxChartDebugLog(
        'page console [${console.messageLevel}] ${console.message}',
      ),
      onWebViewCreated: (web) {
        _chart.attach(web);
        web.addJavaScriptHandler(
          handlerName: 'tenaxchart',
          callback: (args) {
            if (args.isNotEmpty) _chart.handleMessage(args.first);
            return null;
          },
        );
      },
    );
  }

  // The page cannot change its display offset after mount, so the first
  // page is fetched before the WebView exists and reused on `ready`.
  Future<void> _prefetchFirstPage() async {
    final symbol = _symbol;
    final interval = _interval;
    var offset = 0;
    try {
      final page = await widget.dataSource.fetchBars(symbol, interval);
      _prefetched = page;
      _prefetchedKey = _seriesKey(symbol, interval);
      offset = page.serverOffsetMinutes;
    } catch (e) {
      _log('first bars page failed, mounting without offset: $e');
    }
    if (!mounted) return;
    tenaxChartDebugLog('opening page with displayOffsetMinutes=$offset');
    setState(() => _offsetMinutes = offset);
  }

  void _onChartEvent(TenaxChartEvent event) {
    switch (event) {
      case TenaxReadyEvent():
        unawaited(_onReady());
      case TenaxOrderModifyEvent(:final orderId, :final kind, :final to):
        unawaited(_applyLevel(orderId, kind, to));
      case TenaxOrderLevelRemoveEvent(:final orderId, :final kind):
        unawaited(_applyLevel(orderId, kind, null));
      case TenaxOrderCloseEvent(:final orderId):
        unawaited(_closeOrder(orderId));
      case TenaxErrorEvent(:final message):
        _log('chart: $message');
      case TenaxSymbolChangeEvent(:final symbol, :final interval):
        _onPageSeriesChange(symbol, interval ?? _interval);
      case TenaxOrderFocusEvent():
      case TenaxOrderTimeoutEvent():
      case TenaxUnknownEvent():
        break;
    }
    widget.onEvent?.call(event);
  }

  /// The trader picked a timeframe (or symbol) inside the chart. Like the web
  /// chart: drop the old series, load `limit=1000` for the new one, then
  /// follow it live (`subscribe_bars` + the `limit=3` tail refresh).
  void _onPageSeriesChange(String symbol, String interval) {
    if (symbol == _symbol && interval == _interval) return;
    tenaxChartDebugLog('page picked series '
        '$_symbol/$_interval → $symbol/$interval');
    _symbol = symbol;
    _interval = interval;
    unawaited(_openSeries());
  }

  Future<void> _onReady() async {
    // The page restores the timeframe it last showed, which can differ from
    // the one this app feeds; align it before any bars go out.
    _chart.setSymbol(_symbol, interval: _interval);
    final colors = widget.config.themeColors;
    if (colors != null) _chart.setConfig(theme: colors);
    unawaited(_sendInstruments());
    await _openSeries();
  }

  Future<void> _sendInstruments() async {
    final instruments = await _guard(widget.dataSource.instruments());
    if (instruments != null) _chart.setSymbols(instruments);
  }

  /// Loads history, orders and per-symbol settings for the current
  /// symbol/interval, then follows the live streams. Serves both the first
  /// load and every switch.
  Future<void> _openSeries() async {
    final seq = ++_seriesSeq;
    _closeSeries();
    if (_paused || !_chart.isReady) {
      tenaxChartDebugLog('open series skipped '
          '(paused=$_paused, pageReady=${_chart.isReady})');
      return;
    }

    final symbol = _symbol;
    final interval = _interval;
    final source = widget.dataSource;

    final key = _seriesKey(symbol, interval);
    final prefetched = _prefetchedKey == key ? _prefetched : null;
    _prefetched = null;
    _prefetchedKey = null;
    tenaxChartDebugLog('open series symbol=$symbol tf=$interval '
        '(history: ${prefetched != null ? 'reusing first page' : 'new request'})');

    final pageFuture = prefetched != null
        ? Future<TenaxBarsPage?>.value(prefetched)
        : _guard(source.fetchBars(symbol, interval));
    final ordersFuture = _guard(source.orders(symbol));
    final optionsFuture = _guard(source.instrumentOptions(symbol));
    final page = await pageFuture;
    final orders = await ordersFuture;
    final options = await optionsFuture;
    if (seq != _seriesSeq) return;

    _chart.setConfig(orders: widget.config.orders.merge(options));
    if (page != null) _chart.setBars(page.bars);
    if (orders != null) _chart.setOrders(orders);

    _seriesSubs
      ..add(source.liveBars(symbol, interval).listen(
        (bar) {
          _chart.applyBar(bar);
          // A closed bar: re-read the tail at once (integration.md §7).
          if (bar.closed == true) unawaited(_refreshTail(seq));
        },
        onError: _logError,
      ))
      ..add(source.lastPrice(symbol).listen(_chart.setLastPrice,
          onError: _logError))
      ..add(source.orderChanges(symbol).listen(_applyOrderChange,
          onError: _logError));
    _tailTimer = Timer.periodic(_tailInterval, (_) => _refreshTail(seq));
    tenaxChartDebugLog('series live: bars + price + orders subscribed, '
        'tail refresh every ${_tailInterval.inSeconds}s');
  }

  void _closeSeries() {
    _tailTimer?.cancel();
    _tailTimer = null;
    for (final sub in _seriesSubs) {
      sub.cancel();
    }
    _seriesSubs.clear();
  }

  /// A dropped frame must never leave a wrong candle: re-apply the last bars.
  Future<void> _refreshTail(int seq) async {
    if (_tailInFlight) return;
    _tailInFlight = true;
    final symbol = _symbol;
    final interval = _interval;
    try {
      final page = await widget.dataSource
          .fetchBars(symbol, interval, limit: _tailLimit);
      if (seq != _seriesSeq) return;
      for (final bar in page.bars) {
        _chart.applyBar(bar.tagged(symbol, interval));
      }
    } catch (e) {
      _log('tail refresh failed: $e');
    } finally {
      _tailInFlight = false;
    }
  }

  void _applyOrderChange(TenaxOrderChange change) {
    switch (change) {
      case TenaxOrderUpsert(:final order):
        _chart.upsertOrder(order);
      case TenaxOrderRemove(:final orderId):
        _chart.removeOrder(orderId);
    }
  }

  // The chart applies nothing until confirmed (integration.md §3): accepted →
  // upsert, refused → resend the server state so the level snaps back now
  // instead of after the confirm timeout.
  Future<void> _applyLevel(
    String orderId,
    TenaxLevelKind kind,
    double? price,
  ) async {
    try {
      final updated = await widget.dataSource
          .modifyLevel(orderId: orderId, kind: kind, price: price);
      _chart.upsertOrder(updated);
    } catch (e) {
      widget.onActionError?.call(e);
      await _resyncOrders();
    }
  }

  Future<void> _closeOrder(String orderId) async {
    try {
      await widget.dataSource.closeOrder(orderId);
      _chart.removeOrder(orderId);
    } catch (e) {
      widget.onActionError?.call(e);
      await _resyncOrders();
    }
  }

  Future<void> _resyncOrders() async {
    final orders = await _guard(widget.dataSource.orders(_symbol));
    if (orders != null) _chart.setOrders(orders);
  }

  Future<T?> _guard<T>(Future<T> future) async {
    try {
      return await future;
    } catch (e) {
      _logError(e);
      return null;
    }
  }

  String _seriesKey(String symbol, String interval) => '$symbol|$interval';

  void _logError(Object error) => _log('$error');

  void _log(String message) => debugPrint('[tenax_chart] $message');
}
