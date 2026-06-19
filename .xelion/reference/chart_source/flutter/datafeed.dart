// ============================================================
// TRADYN - TradynDatafeed (Flutter / Dart)
// Converted from Datafeed.js
//
// This class mirrors the TradingView Datafeed JS API inside
// the WebView via a JavaScript bridge. It fetches OHLC history
// from https://trade-socket.tradyn.com/charthistory and
// streams live ticks from the Socket.IO connection.
//
// Usage: inject this as window.__tradynDatafeed in the WebView
// HTML, or call methods via JavascriptChannel messages.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

// ─── Supported resolutions ─────────────────────────────────────────────────

const List<String> supportedResolutions = [
  '1', '3', '5', '15', '30', '60', '1D', '1W',
];

// ─── Models ────────────────────────────────────────────────────────────────

class OhlcBar {
  final int timeMs; // milliseconds
  final double open;
  final double high;
  final double low;
  final double close;

  const OhlcBar({
    required this.timeMs,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  OhlcBar copyWith({double? high, double? low, double? close}) => OhlcBar(
        timeMs: timeMs,
        open: open,
        high: high ?? this.high,
        low: low ?? this.low,
        close: close ?? this.close,
      );

  Map<String, dynamic> toJson() => {
        'time': timeMs,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
      };
}

class _Subscription {
  final String resolution;
  OhlcBar? lastBar;
  final List<void Function(OhlcBar)> handlers;

  _Subscription({
    required this.resolution,
    this.lastBar,
    required this.handlers,
  });
}

// ─── Cache ─────────────────────────────────────────────────────────────────

/// `${symbol}_${resolution}` → last OhlcBar
final _lastBarCache = <String, OhlcBar>{};

/// `${symbol}_${resolution}_${from}_${to}` → { bars, timestamp }
final _barsCache = <String, ({List<OhlcBar> bars, int timestamp})>{};

/// `${symbol}_${resolution}` → _Subscription
final _subscriberMap = <String, _Subscription>{};

String _currentSymbol = '';

void clearChartCaches() {
  _lastBarCache.clear();
  _barsCache.clear();
  _subscriberMap.clear();
}

// ─── Resolution → milliseconds ─────────────────────────────────────────────

int _resolutionToMs(String resolution) {
  if (resolution == '1W' || resolution == 'W') return 7 * 24 * 60 * 60 * 1000;
  if (resolution == '1D' || resolution == 'D') return 24 * 60 * 60 * 1000;
  final minutes = {
    '1': 1, '3': 3, '5': 5, '15': 15, '30': 30, '60': 60,
  }[resolution] ?? (int.tryParse(resolution) ?? 1);
  return minutes * 60 * 1000;
}

int _getMondayUTC(int tsMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true);
  final day = d.weekday; // 1=Mon … 7=Sun
  final diff = day - 1;
  return DateTime.utc(d.year, d.month, d.day - diff).millisecondsSinceEpoch;
}

int _getDayUTC(int tsMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true);
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch;
}

// ─── Tick handler (module-level, mirrors JS onTick) ────────────────────────

void _onTick(Map<String, dynamic> tick) {
  final symbol = tick['symbol']?.toString() ?? '';
  if (_currentSymbol.isEmpty || _currentSymbol != symbol) return;

  final tickTimeMs =
      (int.tryParse(tick['time']?.toString() ?? '0') ?? 0) * 1000;
  final bid = double.tryParse(tick['bid']?.toString() ?? '') ?? double.nan;
  final ask = double.tryParse(tick['ask']?.toString() ?? '') ?? double.nan;

  if (bid.isNaN || ask.isNaN || bid.isInfinite || ask.isInfinite) return;
  final mid = (bid + ask) / 2;

  for (final entry in _subscriberMap.entries) {
    if (!entry.key.startsWith('${symbol}_')) continue;
    final sub = entry.value;
    if (sub.lastBar == null) continue;

    final resolution = sub.resolution;
    OhlcBar newBar;
    bool isNewBar;
    int barTime;

    if (resolution == '1W' || resolution == 'W') {
      barTime = _getMondayUTC(tickTimeMs);
      isNewBar = barTime > sub.lastBar!.timeMs;
    } else if (resolution == '1D' || resolution == 'D') {
      barTime = _getDayUTC(tickTimeMs);
      isNewBar = barTime > sub.lastBar!.timeMs;
    } else {
      final ms = _resolutionToMs(resolution);
      barTime = (tickTimeMs ~/ ms) * ms;
      isNewBar = tickTimeMs >= sub.lastBar!.timeMs + ms;
    }

    if (isNewBar) {
      newBar = OhlcBar(
          timeMs: barTime, open: mid, high: mid, low: mid, close: mid);
    } else {
      newBar = sub.lastBar!.copyWith(
        high: sub.lastBar!.high > mid ? sub.lastBar!.high : mid,
        low: sub.lastBar!.low < mid ? sub.lastBar!.low : mid,
        close: mid,
      );
    }

    sub.lastBar = newBar;
    for (final h in sub.handlers) {
      h(newBar);
    }
  }
}

// ─── TradynDatafeed class ──────────────────────────────────────────────────

class TradynDatafeed {
  List<Map<String, dynamic>> symbols;
  IO.Socket? socket;
  final String server;

  // Chart-storage base URL
  static const String _httpBase = 'https://trade-socket.tradyn.com';

  TradynDatafeed({
    required this.symbols,
    required this.socket,
    required this.server,
  }) {
    _attachTickListener();
  }

  void updateSymbols(List<Map<String, dynamic>> updated) {
    symbols = updated;
  }

  // ── Symbol lookup ─────────────────────────────────────────────────────────

  Map<String, dynamic>? _fetchSymbolRecord(String symbolName) {
    try {
      return symbols.firstWhere(
        (s) => s['symbol']?.toString().toLowerCase() ==
            symbolName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Tick listener ─────────────────────────────────────────────────────────

  void _attachTickListener() {
    socket?.off('tick');
    socket?.on('tick', (data) {
      final tick = data is Map
          ? data.cast<String, dynamic>()
          : <String, dynamic>{};
      _onTick(tick);
    });
  }

  // ── onReady ───────────────────────────────────────────────────────────────

  void onReady(void Function(Map<String, dynamic>) callback) {
    Future.delayed(Duration.zero, () => callback({
          'supported_resolutions': supportedResolutions,
          'supports_time': true,
          'supports_marks': true,
          'showCountdown': true,
          'exchanges': [
            {'value': '', 'name': 'All Exchanges', 'desc': ''}
          ],
        }));
  }

  // ── getServerTime ─────────────────────────────────────────────────────────

  Future<int> getServerTime() {
    final s = socket;
    if (s == null || !s.connected) {
      return Future.value(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    }

    final completer = Completer<int>();
    bool resolved = false;

    s.on('servertime-response', (res) {
      if (resolved) return;
      resolved = true;
      s.off('servertime-response');
      final t = (res is Map ? res['time'] : null);
      completer.complete(
          t != null ? int.tryParse(t.toString()) ?? _nowSec() : _nowSec());
    });

    s.emit('get-servertime', {});

    Future.delayed(const Duration(seconds: 5), () {
      if (!resolved) {
        resolved = true;
        s.off('servertime-response');
        if (!completer.isCompleted) completer.complete(_nowSec());
      }
    });

    return completer.future;
  }

  int _nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // ── searchSymbols ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> searchSymbols(String query) {
    final q = query.toLowerCase();
    return symbols.where((s) {
      return (s['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (s['description']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── formatTradingViewSession ──────────────────────────────────────────────

  String formatTradingViewSession(List<dynamic> tradeSessions) {
    if (tradeSessions.isEmpty) return '24x7';

    const dayIndex = {
      'sunday': 1, 'monday': 2, 'tuesday': 3,
      'wednesday': 4, 'thursday': 5, 'friday': 6, 'saturday': 7,
    };

    // Map of "HHMM-HHMM" → List<int> dayNums
    final sessionMap = <String, List<int>>{};

    for (final entry in tradeSessions) {
      final day = entry['day']?.toString().toLowerCase() ?? '';
      final dayNum = dayIndex[day];
      if (dayNum == null) continue;
      final sessions = entry['sessions'] as List<dynamic>? ?? [];
      final sorted = List.of(sessions)
        ..sort((a, b) {
          final ao = int.tryParse(
                  a['open']?.toString().replaceAll(':', '') ?? '0') ??
              0;
          final bo = int.tryParse(
                  b['open']?.toString().replaceAll(':', '') ?? '0') ??
              0;
          return ao.compareTo(bo);
        });

      for (final sess in sorted) {
        final open = sess['open']?.toString().replaceAll(':', '') ?? '0000';
        final close = sess['close']?.toString().replaceAll(':', '') ?? '2359';
        final key = '$open-$close';
        sessionMap.putIfAbsent(key, () => []).add(dayNum);
      }
    }

    if (sessionMap.isEmpty) return '24x7';

    final parts = sessionMap.entries.map((e) {
      final days = (List.of(e.value)..sort()).join('');
      final openTime = int.tryParse(e.key.split('-').first) ?? 0;
      return (timeRange: e.key, days: days, openTime: openTime);
    }).toList()
      ..sort((a, b) => a.openTime.compareTo(b.openTime));

    return parts.map((p) => '${p.timeRange}:${p.days}').join('|');
  }

  // ── resolveSymbol ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> resolveSymbol(String symbolName) async {
    final sym = _fetchSymbolRecord(symbolName);
    if (sym == null) return null;

    final point = (sym['point'] ?? 0.00001).toDouble();
    final pricescale = (1 / point).round();
    final session =
        formatTradingViewSession(sym['trade_sessions'] as List? ?? []);

    return {
      'ticker': sym['symbol'],
      'name': sym['symbol'],
      'description': sym['description'] ?? '',
      'type': sym['type'] ?? 'forex',
      'session': session,
      'timezone': 'Etc/UTC',
      'minmov': 1,
      'pointvalue': 1,
      'pricescale': pricescale,
      'has_intraday': true,
      'visible_plots_set': 'ohlc',
      'has_weekly_and_monthly': true,
      'supported_resolutions': supportedResolutions,
      'volume_precision': 2,
      'showCountdown': true,
      'supports_time': true,
      'supports_marks': true,
      'data_status': 'streaming',
    };
  }

  // ── getBars ───────────────────────────────────────────────────────────────

  /// Returns OHLC bars. [from] and [to] are Unix seconds. [countBack] is hint.
  Future<List<OhlcBar>> getBars({
    required String symbolName,
    required String resolution,
    required int from,
    required int to,
    required int countBack,
    required bool firstDataRequest,
    required String sessionToken,
  }) async {
    final cacheKey = '${symbolName}_${resolution}_${from}_$to';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (!firstDataRequest) {
      final cached = _barsCache[cacheKey];
      if (cached != null && nowMs - cached.timestamp < 300000) {
        return cached.bars;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$_httpBase/charthistory'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: jsonEncode({
          'symbol': symbolName,
          'from': from,
          'to': to,
          'resolution': resolution,
          'count': countBack,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('[Datafeed] getBars HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = (json['data'] as List<dynamic>?) ?? [];

      if (raw.isEmpty) {
        _barsCache[cacheKey] = (bars: [], timestamp: nowMs);
        return [];
      }

      final bars = raw.map((b) {
        final m = b as Map<String, dynamic>;
        return OhlcBar(
          timeMs: ((m['time'] as num).toInt()) * 1000,
          open: (m['open'] as num).toDouble(),
          high: (m['high'] as num).toDouble(),
          low: (m['low'] as num).toDouble(),
          close: (m['close'] as num).toDouble(),
        );
      }).toList();

      _barsCache[cacheKey] = (bars: bars, timestamp: nowMs);

      if (firstDataRequest && bars.isNotEmpty) {
        final barKey = '${symbolName}_$resolution';
        _lastBarCache[barKey] = bars.last;
      }

      return bars;
    } catch (e) {
      debugPrint('[Datafeed] getBars error: $e');
      rethrow;
    }
  }

  // ── subscribeBars ─────────────────────────────────────────────────────────

  void subscribeBars({
    required String symbolName,
    required String resolution,
    required String subscriberUID,
    required void Function(OhlcBar bar) onRealtimeCallback,
  }) {
    final barKey = '${symbolName}_$resolution';
    final lastBar = _lastBarCache[barKey];

    _currentSymbol = symbolName;

    _attachTickListener();

    final handler = onRealtimeCallback;
    final existing = _subscriberMap[barKey];
    if (existing != null) {
      existing.handlers.add(handler);
    } else {
      _subscriberMap[barKey] = _Subscription(
        resolution: resolution,
        lastBar: lastBar,
        handlers: [handler],
      );
    }
  }

  // ── unsubscribeBars ───────────────────────────────────────────────────────

  void unsubscribeBars(String subscriberUID) {
    // Since we store handlers by barKey, iterate to find and remove by UID
    // In production wire subscriberUID → handler reference for O(1) removal
    _subscriberMap.removeWhere((_, sub) {
      sub.handlers.clear();
      return sub.handlers.isEmpty;
    });
  }

  // ── JavaScript bridge: generate JS datafeed object string ─────────────────
  //
  // Call this to get a JS snippet that wires the datafeed into TradingView
  // inside the WebView. The Flutter side handles network calls; the JS side
  // posts messages to FlutterBridge and receives callbacks via evaluateJavascript.

  static String buildJsDatafeedBridge() => r'''
    (function() {
      const pendingCallbacks = {};
      let cbId = 0;

      function call(method, args, cb) {
        const id = ++cbId;
        if (cb) pendingCallbacks[id] = cb;
        FlutterBridge.postMessage(JSON.stringify({ method, args, cbId: id }));
      }

      window.__resolveDfCallback = function(id, result) {
        const cb = pendingCallbacks[id];
        if (cb) { delete pendingCallbacks[id]; cb(result); }
      };

      window.__tradynDatafeed = {
        onReady: function(cb) { call('onReady', {}, cb); },
        getServerTime: function(cb) { call('getServerTime', {}, cb); },
        searchSymbols: function(q, ex, type, cb) {
          call('searchSymbols', { q }, cb);
        },
        resolveSymbol: function(sym, onOk, onErr) {
          call('resolveSymbol', { sym }, function(res) {
            if (res) onOk(res); else onErr('Cannot resolve');
          });
        },
        getBars: function(info, res, params, onOk, onErr) {
          call('getBars', {
            symbol: info.name, resolution: res,
            from: params.from, to: params.to,
            countBack: params.countBack,
            firstDataRequest: params.firstDataRequest,
          }, function(r) {
            if (r && r.bars) onOk(r.bars, { noData: r.noData });
            else onErr('getBars error');
          });
        },
        subscribeBars: function(info, res, cb, uid) {
          call('subscribeBars', { symbol: info.name, resolution: res, uid });
          window['__rtCb_' + uid] = cb;
        },
        unsubscribeBars: function(uid) {
          call('unsubscribeBars', { uid });
          delete window['__rtCb_' + uid];
        },
      };
    })();
  ''';

  // ── Push a real-time bar update into the WebView ──────────────────────────
  //
  // Call this from the FlutterBridge message handler after subscribeBars.
  // [uid] is the subscriberUID, [bar] is the latest OhlcBar.

  static String buildPushBarJs(String uid, OhlcBar bar) =>
      "if(window.__rtCb_$uid) window.__rtCb_$uid(${jsonEncode(bar.toJson())});";
}
