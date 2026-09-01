import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';

/// A ready-made [TenaxChartApi] wired to the standard Tenax endpoints. The
/// mobile dev does not touch any URL — they pass a [TenaxApiConfig] where **only
/// `baseDomain` changes** per broker; every path (history, symbols, ticks,
/// modify, close) is fixed and identical across brokers, matching the web build.
///
/// ```dart
/// final api = TenaxRestApi(const TenaxApiConfig(
///   baseDomain: 'https://api.mybroker.com', // the only per-broker change
///   token: sessionToken,
/// ));
/// ```
///
/// If your backend differs, implement [TenaxChartApi] directly instead — this
/// class is a convenience, not a requirement.
class TenaxRestApi extends TenaxChartApi {
  TenaxRestApi(this.config, {http.Client? client})
      : _http = client ?? http.Client();

  final TenaxApiConfig config;
  final http.Client _http;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  final Map<String, void Function(Tick)> _tickListeners = {};

  // ---- history -------------------------------------------------------------

  /// Number of bars to request on the first (unbounded) history load. Keeping
  /// this bounded makes the initial chart paint fast — older bars are fetched
  /// lazily as the user scrolls back.
  static const int _initialBarCount = 500;

  @override
  Future<List<Candle>> fetchCandles({
    required String symbol,
    required String resolution,
    int? from,
    int? to,
  }) async {
    // When the caller gives no explicit range (the first load), bound the
    // window to the most recent [_initialBarCount] bars instead of letting the
    // server return its full default history — that default can be thousands of
    // bars and is the main first-load cost.
    if (from == null && to == null) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      to = nowSec;
      from = nowSec - _resolutionSeconds(resolution) * _initialBarCount;
    }
    final res = await _http.get(
      config.url(TenaxApiConfig.historyPath, query: {
        'symbol': symbol,
        'resolution': resolution,
        'from': from,
        'to': to,
      }),
      headers: config.headers,
    );
    _ensureOk(res);
    final body = jsonDecode(res.body);
    final rows = (body is Map ? (body['bars'] ?? body['data'] ?? []) : body) as List;
    return rows
        .map((b) => Candle(
              time: _asInt(b['time'] ?? b['t'])!,
              open: _asDouble(b['open'] ?? b['o'])!,
              high: _asDouble(b['high'] ?? b['h'])!,
              low: _asDouble(b['low'] ?? b['l'])!,
              close: _asDouble(b['close'] ?? b['c'])!,
              volume: _asDouble(b['volume'] ?? b['v']),
            ))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time)); // oldest-first
  }

  // ---- symbols -------------------------------------------------------------

  @override
  Future<List<SymbolInfo>> fetchSymbols() async {
    try {
      final res = await _http.get(
        config.url(TenaxApiConfig.symbolsPath),
        headers: config.headers,
      );
      _ensureOk(res);
      final body = jsonDecode(res.body);
      final rows = (body is Map ? (body['symbols'] ?? body['data'] ?? []) : body) as List;
      return rows
          .map((s) => SymbolInfo(
                symbol: (s['symbol'] ?? s['name']) as String,
                description: s['description'] as String?,
                digits: _asInt(s['digits']),
              ))
          .toList();
    } catch (e) {
      return []; // Return empty list on failure so _pushEverything continues
    }
  }

  // ---- live ticks (one shared socket) --------------------------------------

  @override
  void Function() subscribeTicks(String symbol, void Function(Tick) onTick) {
    _tickListeners[symbol] = onTick;
    _ensureSocket();
    _socket?.sink.add(jsonEncode({'op': 'sub', 'symbol': symbol}));
    return () {
      _tickListeners.remove(symbol);
      _socket?.sink.add(jsonEncode({'op': 'unsub', 'symbol': symbol}));
      if (_tickListeners.isEmpty) _closeSocket();
    };
  }

  void _ensureSocket() {
    if (_socket != null) return;
    final uri = Uri.parse('${config.resolvedWsBase}${TenaxApiConfig.ticksPath}');
    final channel = WebSocketChannel.connect(uri);
    _socket = channel;
    _socketSub = channel.stream.listen(
      _onSocketMessage,
      onError: (_) => _closeSocket(),
      onDone: _closeSocket,
    );
  }

  void _onSocketMessage(dynamic raw) {
    final m = raw is String ? jsonDecode(raw) : raw;
    if (m is! Map) return;
    final symbol = (m['symbol'] ?? m['s']) as String?;
    if (symbol == null) return;
    final listener = _tickListeners[symbol];
    if (listener == null) return;
    listener(Tick(
      symbol: symbol,
      bid: _asDouble(m['bid'] ?? m['b'])!,
      ask: _asDouble(m['ask'] ?? m['a'])!,
      time: _asInt(m['time'] ?? m['t']),
    ));
  }

  void _closeSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.sink.close();
    _socket = null;
  }

  // ---- order actions (confirm-by-return; throw = reject) -------------------

  @override
  Future<Map<String, dynamic>> modifyOrder({
    required String orderId,
    required String field,
    required double? price,
  }) async {
    final res = await _http.post(
      config.url(TenaxApiConfig.orderModifyPath, orderId: orderId),
      headers: config.headers,
      body: jsonEncode({'field': field, 'price': price}),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body);
    return ((body is Map ? (body['order'] ?? body) : body) as Map)
        .cast<String, dynamic>();
  }

  @override
  Future<void> closeOrder(String orderId) async {
    final res = await _http.post(
      config.url(TenaxApiConfig.orderClosePath, orderId: orderId),
      headers: config.headers,
    );
    _ensureOk(res);
  }

  @override
  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> request) async {
    final res = await _http.post(
      config.url(TenaxApiConfig.orderPlacePath),
      headers: config.headers,
      body: jsonEncode(request),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body);
    return ((body is Map ? (body['order'] ?? body) : body) as Map)
        .cast<String, dynamic>();
  }

  /// Release the socket + HTTP client. Call when the chart screen is gone.
  void dispose() {
    _closeSocket();
    _http.close();
  }

  // ---- helpers -------------------------------------------------------------

  void _ensureOk(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String message = 'HTTP ${res.statusCode}';
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b['message'] != null) message = '${b['message']}';
    } catch (_) {/* keep default */}
    throw Exception(message);
  }

  /// Maps a chart resolution string (e.g. "1", "5", "60", "1D", "1W") to its
  /// duration in seconds. Used to size the initial history window.
  static int _resolutionSeconds(String resolution) {
    final r = resolution.trim().toUpperCase();
    if (r.endsWith('D')) {
      final n = int.tryParse(r.substring(0, r.length - 1)) ?? 1;
      return n * 86400;
    }
    if (r.endsWith('W')) {
      final n = int.tryParse(r.substring(0, r.length - 1)) ?? 1;
      return n * 604800;
    }
    if (r.endsWith('M')) {
      final n = int.tryParse(r.substring(0, r.length - 1)) ?? 1;
      return n * 2592000; // ~30 days
    }
    // Bare number = minutes.
    final minutes = int.tryParse(r) ?? 1;
    return minutes * 60;
  }

  static int? _asInt(dynamic v) =>
      v == null ? null : (v is int ? v : int.tryParse('$v'));
  static double? _asDouble(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
}
