import 'dart:async';
import 'dart:convert';

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

    switch (msg['type']) {
      case 'ready':
        _ready = true;
        _flushQueue();
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
        final res = msg['interval'] as String?;
        if (res != null) {
          setInterval(res);
        }
        break;

      case 'symbol':
        final sym = msg['symbol'] as String?;
        if (sym != null) {
          setSymbol(sym);
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
      await setSymbol(_symbol!, resolution: _resolution);
    }
  }

  // ---- public API the app calls --------------------------------------------

  /// Switch instrument (and optionally interval). Loads history, then subscribes
  /// to ticks through your [TenaxChartApi] — one subscription at a time.
  Future<void> setSymbol(String symbol, {String? resolution}) async {
    _symbol = symbol;
    if (resolution != null) _resolution = resolution;

    // Cancel old tick subscription FIRST — prevents stale ticks from old symbol
    // appearing on the new chart while candles are being fetched.
    _tickCancel?.call();
    _tickCancel = null;

    // Tell the chart to switch symbol. The chart will reset its own canvas state.
    await _send({'type': 'symbol', 'symbol': symbol, 'interval': _resolution});

    // Subscribe to ticks immediately so live price ticks stream instantly
    // without being blocked on historical candle loading over HTTP.
    _tickCancel = api.subscribeTicks(symbol, (tick) => pushTick(tick));

    try {
      final bars = await api.fetchCandles(symbol: symbol, resolution: _resolution);
      await _send({'type': 'candles', 'bars': bars.map((c) => c.toJson()).toList()});
    } catch (e) {
      _emitError('Failed to fetch candles for $symbol: $e');
    }
  }

  /// Change timeframe on the current symbol (reloads history).
  Future<void> setInterval(String resolution) async {
    _resolution = resolution;
    // Use type:'interval' — this only changes the timeframe without resetting
    // the chart's drawn lines or full state (unlike type:'symbol').
    await _send({'type': 'interval', 'interval': resolution});
    if (_symbol != null) {
      try {
        final bars =
            await api.fetchCandles(symbol: _symbol!, resolution: resolution);
        await _send({'type': 'candles', 'bars': bars.map((c) => c.toJson()).toList()});
      } catch (e) {
        _emitError('Failed to fetch candles: $e');
      }
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
