import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'api.dart';
import 'models.dart';

/// Drives one chart instance: pushes data IN (candles, ticks, orders, theme)
/// and handles what the trader does (drag SL/TP, close). You rarely call this
/// directly for data plumbing — [TenaxChartView] wires the API to it — but it is
/// the handle you keep to change symbol, push a tick, or flip theme at runtime.
///
/// Nothing here is applied to the chart optimistically for order edits: when the
/// trader drags a level, we call your API and only push the confirmed order back.
class TenaxChartController {
  TenaxChartController({required this.api});

  /// Your broker/Trade-Engine bridge. See [TenaxChartApi].
  final TenaxChartApi api;

  InAppWebViewController? _web;
  bool _ready = false;
  final List<Map<String, dynamic>> _preReadyQueue = [];

  String? _symbol;

  /// Instrument currently shown (or being loaded); null before the first
  /// [setSymbol].
  String? get symbol => _symbol;
  String _resolution = '60';
  ChartTheme _theme = ChartTheme.light;

  void Function()? _tickCancel;

  /// The JS handler name the chart calls (see docs/flutter.md). Do not change.
  static const String kHandler = 'tenaxchart';

  // ---- lifecycle -----------------------------------------------------------

  /// Called by the view once the WebView finishes loading. Binds the handler.
  void attach(InAppWebViewController controller) {
    _web = controller;
    controller.addJavaScriptHandler(
      handlerName: kHandler,
      callback: (args) => _onMessage(args.isNotEmpty ? args.first : null),
    );
  }

  /// Free the tick subscription. Call from the widget's dispose.
  void dispose() {
    _tickCancel?.call();
    _tickCancel = null;
    _web = null;
    _ready = false;
  }

  // ---- inbound: chart -> host ----------------------------------------------

  void _onMessage(dynamic raw) {
    final msg = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : (raw as Map).cast<String, dynamic>();
    if (msg['type'] != 'error') {
      debugPrint('TenaxTrace chart→app $msg (current $_symbol|$_resolution)');
    }

    switch (msg['type']) {
      case 'ready':
        _ready = true;
        // Candles fetched before the page was ready sit in the queue; the
        // flush paints them, so that load must not be repeated. A reload
        // (empty queue) has a blank canvas and needs a fresh load.
        final replayedCandles =
            _preReadyQueue.any((m) => m['type'] == 'candles');
        _flushQueue();
        if (!replayedCandles) _loadedKey = null;
        _pushEverything();
        break;

      case 'orderModify':
        // NOT applied by the chart — it shows the level dashed and waits.
        api
            .modifyOrder(
          orderId: msg['orderId'] as String,
          field: msg['kind'] as String, // 'sl' | 'tp' | 'pending'
          price: (msg['to'] as num).toDouble(),
        )
            .then((updated) {
          upsertOrder(updated);
        }).catchError((Object e) {
          _emitError(e); // no confirm → chart keeps the old level
        });
        break;

      case 'orderLevelRemove':
        api
            .modifyOrder(
          orderId: msg['orderId'] as String,
          field: msg['kind'] as String,
          price: null,
        )
            .then((updated) {
          upsertOrder(updated);
        }).catchError((Object e) {
          _emitError(e);
          return null;
        });
        break;

      case 'orderClose':
        final id = msg['orderId'] as String;
        api.closeOrder(id).then((_) {
          removeOrder(id);
        }).catchError((Object e) {
          _emitError(e);
          return null;
        });
        break;

      case 'orderFocus':
        // The trader tapped an order; the chart already highlighted it. Hook
        // here if the app wants to scroll a position list. No-op by default.
        break;

      case 'interval':
        // The chart echoes back the interval we just pushed. Only a real
        // change by the trader may reload history, otherwise app → chart →
        // app loops and floods /market/history.
        final res = msg['interval'] as String?;
        if (res != null && !_sameResolution(res, _resolution)) {
          setInterval(res);
        }
        break;

      case 'symbol':
        final sym = msg['symbol'] as String?;
        final iv = msg['interval'] as String?;
        if (sym == null) break;
        if (sym != _symbol) {
          setSymbol(sym, resolution: iv);
        } else if (iv != null && !_sameResolution(iv, _resolution)) {
          setInterval(iv);
        }
        break;

      case 'error':
        _emitError(msg['message'] ?? 'unknown chart error');
        break;

      default:
        print('TenaxChartController unhandled message: $msg');
        break;
    }
  }

  /// The chart echoes intervals in its own spelling ('15' for '15m', '60' for
  /// '1h'). Comparing raw strings treats that echo as a change and reloads
  /// history, so compare the canonical minute/period form instead.
  static String _canonResolution(String r) {
    var clean = r.trim().toLowerCase();
    if (clean.endsWith('m') && clean.length > 1) {
      clean = clean.substring(0, clean.length - 1);
    } else if (clean.endsWith('h')) {
      final hours = int.tryParse(clean.substring(0, clean.length - 1)) ?? 1;
      clean = '${hours * 60}';
    } else if (clean == 'd' || clean == '1d') {
      clean = '1D';
    } else if (clean == 'w' || clean == '1w') {
      clean = '1W';
    } else if (clean == 'm' || clean == '1m') {
      clean = '1M';
    }
    return clean;
  }

  static bool _sameResolution(String a, String b) =>
      _canonResolution(a) == _canonResolution(b);

  /// Optional external error sink (toast/snackbar). Set by the view.
  void Function(Object error)? onError;
  void _emitError(Object e) => onError?.call(e);

  // ---- outbound: host -> chart ---------------------------------------------

  Future<void> _send(Map<String, dynamic> message) async {
    if (!_ready || _web == null) {
      _preReadyQueue.add(message);
      return;
    }
    final json = jsonEncode(message);
    // The bundle exposes window.TenaxChart.receive(msgOrJsonString).
    await _web!.evaluateJavascript(
      source: 'window.TenaxChart && window.TenaxChart.receive($json);',
    );
  }

  void _flushQueue() {
    if (_web == null) return;
    final pending = List<Map<String, dynamic>>.from(_preReadyQueue);
    _preReadyQueue.clear();
    for (final m in pending) {
      _send(m);
    }
  }

  /// On (re)connect, paint the current view: symbol + theme, then live data.
  Future<void> _pushEverything() async {
    await setTheme(_theme);
    final syms = await api.fetchSymbols();
    await _send({'type': 'symbols', 'list': syms.map((s) => s.toJson()).toList()});
    if (_symbol != null) {
      // Skipped when the candles were already painted by the queue flush or
      // are still in flight; loads only when the canvas is really blank.
      await setSymbol(_symbol!, resolution: _resolution);
    }
  }

  /// symbol|interval whose candles are on the chart / being fetched now.
  String? _loadedKey;
  String? _inFlightKey;


  /// The in-flight fetch's result. A caller that arrives while it runs
  /// awaits it and re-sends it, instead of starting a second HTTP request.
  Future<List<Candle>>? _inFlightBars;

  /// One history request per symbol+interval at a time. When the bars arrive
  /// they are sent to the chart if that symbol+interval is still current —
  /// after every chart reset that happened while waiting, so the canvas
  /// always ends up with candles. A late response for a symbol/interval the
  /// trader already left is dropped.
  Future<void> _loadCandles(String symbol, String resolution) async {
    final key = '$symbol|$resolution';

    // Candles for this key were already sent after the latest reset.
    if (_loadedKey == key) {
      debugPrint('TenaxTrace load $key already on chart');
      return;
    }
    // Already fetching this exact key: its owner sends the bars when they
    // arrive, and that send happens after any reset made meanwhile.
    if (_inFlightKey == key && _inFlightBars != null) {
      debugPrint('TenaxTrace load $key joins in-flight request');
      return;
    }

    final request = api.fetchCandles(symbol: symbol, resolution: resolution);
    _inFlightKey = key;
    _inFlightBars = request;

    try {
      final bars = await request;
      if (symbol != _symbol || resolution != _resolution) {
        debugPrint('TenaxTrace drop stale $key (now $_symbol|$_resolution)');
        return;
      }
      print('TenaxTrace candles → chart $key bars=${bars.length}');
      await _send({'type': 'candles', 'bars': bars.map((c) => c.toJson()).toList()});
      _loadedKey = key;
    } catch (e) {
      print('TenaxTrace load $key failed: $e');
      if (symbol == _symbol && resolution == _resolution) {
        _emitError('Failed to fetch candles for $symbol: $e');
      }
    } finally {
      if (_inFlightKey == key) {
        _inFlightKey = null;
        _inFlightBars = null;
      }
    }
  }

  // ---- public API the app calls --------------------------------------------

  /// Switch instrument (and optionally interval). Loads history, then subscribes
  /// to ticks through your [TenaxChartApi] — one subscription at a time.
  Future<void> setSymbol(
    String symbol, {
    String? resolution,
    bool force = false,
  }) async {
    final nextResolution = resolution ?? _resolution;
    final key = '$symbol|$nextResolution';
    debugPrint(
      'TenaxTrace setSymbol $key force=$force loaded=$_loadedKey inFlight=$_inFlightKey',
    );
    // Same symbol+interval already shown or loading → nothing to do. Stops
    // widget rebuilds (price ticks) from re-requesting history.
    if (!force && (key == _loadedKey || key == _inFlightKey)) return;

    _symbol = symbol;
    _resolution = nextResolution;

    // Cancel old tick subscription FIRST — prevents stale ticks from old symbol
    // appearing on the new chart while candles are being fetched.
    _tickCancel?.call();
    _tickCancel = null;

    // Tell the chart to switch symbol. The chart resets its canvas, so the
    // candles currently shown are gone until we send them again.
    _loadedKey = null;
    await _send({'type': 'symbol', 'symbol': symbol, 'interval': _resolution});

    // History first, live ticks after: a tick pushed onto an empty canvas
    // starts a lone candle that the history then has to overwrite.
    await _loadCandles(symbol, _resolution);
    if (symbol != _symbol || _tickCancel != null) return;
    _tickCancel = api.subscribeTicks(symbol, (tick) => pushTick(tick));
  }

  /// Change timeframe on the current symbol (reloads history).
  Future<void> setInterval(String resolution) async {
    if (_symbol != null) {
      final key = '$_symbol|$resolution';
      if (key == _loadedKey || key == _inFlightKey) return;
      if (_sameResolution(resolution, _resolution) && _loadedKey != null) return;
    }
    _resolution = resolution;
    // Use type:'interval' — this only changes the timeframe without resetting
    // the chart's drawn lines or full state (unlike type:'symbol').
    await _send({'type': 'interval', 'interval': resolution});
    if (_symbol != null) {
      await _loadCandles(_symbol!, resolution);
    }
  }

  /// Push one live tick. Cheap; call it for every price update you receive.
  void pushTick(Tick tick) {
    _send({'type': 'tick', ...tick.toJson()});
  }

  /// Replace the whole order book on the chart (open positions + pendings).
  void setOrders({
    List<Position> positions = const [],
    List<PendingOrder> pendings = const [],
  }) {
    _send({
      'type': 'orders',
      'positions': positions.map((p) => p.toJson()).toList(),
      'pendings': pendings.map((p) => p.toJson()).toList(),
    });
  }

  /// Add or update a single order/position (confirm after a broker action, or
  /// on a live P/L refresh).
  void upsertOrder(Map<String, dynamic> order) {
    _send({'type': 'order', 'action': 'upsert', 'order': order});
  }

  /// Remove one order/position from the chart.
  void removeOrder(String orderId) {
    _send({'type': 'order', 'action': 'remove', 'orderId': orderId});
  }

  /// Highlight a set of orders (e.g. the app selected a row in a list).
  void focusOrders(List<String> orderIds) {
    _send({'type': 'focus', 'orderIds': orderIds});
  }

  /// Light / dark, follow the app.
  Future<void> setTheme(ChartTheme theme) async {
    _theme = theme;
    await _send({'type': 'theme', 'mode': theme.wire});
  }

  /// Per-broker live config: canvas theme colors + order-line styling. Applied
  /// without a rebuild so one bundle serves every broker.
  void setConfig({Map<String, dynamic>? theme, Map<String, dynamic>? orders}) {
    _send({
      'type': 'config',
      if (theme != null) 'theme': theme,
      if (orders != null) 'orders': orders,
    });
  }

  /// Candles / line / area / bars. Value must be one the chart understands.
  void setChartType(String value) {
    _send({'type': 'chartType', 'value': value});
  }

  /// Fit the visible range back to default.
  void resetZoom() {
    _send({'type': 'resetZoom'});
  }
}
