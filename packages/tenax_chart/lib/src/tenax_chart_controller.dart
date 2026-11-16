import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'messages.dart';
import 'models/tenax_bar.dart';
import 'models/tenax_instrument.dart';
import 'models/tenax_order.dart';
import 'models/tenax_orders_options.dart';

/// App → chart messages (flutter.md §3) and the chart's events.
///
/// Messages sent before the page reports `ready` are queued and delivered in
/// order once it does, so callers never have to wait for the WebView.
class TenaxChartController {
  InAppWebViewController? _web;
  bool _ready = false;
  final List<Map<String, dynamic>> _queued = [];
  Future<void> _lastSend = Future<void>.value();
  final StreamController<TenaxChartEvent> _events =
      StreamController<TenaxChartEvent>.broadcast();

  Stream<TenaxChartEvent> get events => _events.stream;
  bool get isReady => _ready;

  /// Called by `TenaxChartView` when its WebView is created.
  void attach(InAppWebViewController web) {
    _web = web;
    _ready = false;
  }

  /// Called by `TenaxChartView` when its WebView goes away.
  void detach() {
    _web = null;
    _ready = false;
    _queued.clear();
  }

  /// Called by `TenaxChartView` for every `tenaxchart` handler call.
  void handleMessage(Object? raw) {
    // Raw, before parsing: shows message types this wrapper does not know.
    tenaxChartDebugLog('page → app: ${_describeRaw(raw)}');
    final event = TenaxChartEvent.parse(raw);
    if (event is TenaxReadyEvent) {
      _ready = true;
      final queued = List.of(_queued);
      _queued.clear();
      queued.forEach(_enqueue);
    }
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> send(Map<String, dynamic> message) {
    if (_web == null || !_ready) {
      tenaxChartDebugLog('app → page (queued until ready): ${_summarize(message)}');
      _queued.add(message);
      return Future<void>.value();
    }
    return _enqueue(message);
  }

  Future<void> setSymbol(String symbol, {String? interval}) => send({
        'type': 'symbol',
        'symbol': symbol,
        if (interval != null) 'interval': interval,
      });

  Future<void> setInterval(String interval) =>
      send({'type': 'interval', 'interval': interval});

  /// Replaces the whole series; forming bar last.
  Future<void> setBars(List<TenaxBar> bars) => send({
        'type': 'bars',
        'bars': [for (final bar in bars) bar.toJson()],
      });

  /// Upserts one bar by time.
  Future<void> applyBar(TenaxBar bar) =>
      send({'type': 'bar', 'bar': bar.toJson()});

  Future<void> setLastPrice(TenaxLastPrice price) =>
      send({'type': 'lastPrice', ...price.toJson()});

  Future<void> setOrders(TenaxOrdersSnapshot snapshot) => send({
        'type': 'orders',
        'positions': [for (final p in snapshot.positions) p.toJson()],
        'pendings': [for (final o in snapshot.pendings) o.toJson()],
      });

  Future<void> upsertOrder(TenaxChartOrder order) =>
      send({'type': 'order', 'action': 'upsert', 'order': order.toJson()});

  Future<void> removeOrder(String orderId) =>
      send({'type': 'order', 'action': 'remove', 'orderId': orderId});

  Future<void> setSymbols(List<TenaxInstrument> instruments) => send({
        'type': 'symbols',
        'list': [for (final i in instruments) i.toJson()],
      });

  /// 'dark' | 'light'.
  Future<void> setTheme(String mode) => send({'type': 'theme', 'mode': mode});

  Future<void> setConfig({
    Map<String, String>? theme,
    TenaxOrdersOptions? orders,
  }) =>
      send({
        'type': 'config',
        if (theme != null) 'theme': theme,
        if (orders != null) 'orders': orders.toJson(),
      });

  void dispose() {
    detach();
    _events.close();
  }

  // Chained so messages reach the page in the order they were sent, even
  // while the ready-queue is still flushing.
  Future<void> _enqueue(Map<String, dynamic> message) {
    final next = _lastSend.then((_) => _evaluate(message));
    _lastSend = next;
    return next;
  }

  Future<void> _evaluate(Map<String, dynamic> message) async {
    final web = _web;
    if (web == null) return;
    // lastPrice goes out on every tick; logging it would bury everything else.
    if (message['type'] != 'lastPrice') {
      tenaxChartDebugLog('app → page: ${_summarize(message)}');
    }
    try {
      await web.evaluateJavascript(
        source: 'TenaxChart.receive(${jsonEncode(message)});',
      );
    } catch (e) {
      // The WebView was torn down mid-send; the next mount pushes everything again.
      debugPrint('[tenax_chart] send ${message['type']} failed: $e');
    }
  }

  static String _describeRaw(Object? raw) {
    try {
      return jsonEncode(raw);
    } catch (_) {
      return '$raw';
    }
  }

  /// One line per message; series payloads reduced to their size and edges.
  static String _summarize(Map<String, dynamic> message) {
    final type = message['type'];
    switch (type) {
      case 'bars':
        final bars = (message['bars'] as List?) ?? const [];
        if (bars.isEmpty) return 'bars count=0';
        final first = bars.first as Map;
        final last = bars.last as Map;
        return 'bars count=${bars.length} '
            'first=${first['time']} last=${last['time']} close=${last['close']}';
      case 'bar':
        final bar = (message['bar'] as Map?) ?? const {};
        return 'bar ${bar['symbol'] ?? ''} ${bar['interval'] ?? ''} '
            'time=${bar['time']} close=${bar['close']} closed=${bar['closed']}';
      case 'orders':
        return 'orders positions=${(message['positions'] as List?)?.length ?? 0} '
            'pendings=${(message['pendings'] as List?)?.length ?? 0}';
      case 'symbols':
        return 'symbols count=${(message['list'] as List?)?.length ?? 0}';
      default:
        return jsonEncode(message);
    }
  }
}

/// Debug-build trace of everything the chart loads and exchanges, tagged
/// `[tenax_chart]` so `flutter logs | grep tenax_chart` shows the whole flow.
void tenaxChartDebugLog(String message) {
  if (kDebugMode) debugPrint('[tenax_chart] $message');
}
