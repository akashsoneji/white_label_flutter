import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:get/get.dart';

/// Flutter-side Datafeed bridge for the **new** advanced chart WebView
/// (`AdvancedChartInAppWebView`).
///
/// This mirrors the TradingView Datafeed JS API (UDF style):
/// - `onReady`
/// - `resolveSymbol`
/// - `getBars`
/// - `subscribeBars`
/// - `unsubscribeBars`
///
/// The new chart's HTML embeds a JS shim that posts messages to Flutter via
/// `window.flutter_inappwebview.callHandler(name, args)` and awaits a
/// callback id. The widget (`AdvancedChartInAppWebViewState`) routes those
/// calls to this class.
///
/// History (getBars) uses the brand's existing REST base; if the backend does
/// not expose a candle endpoint the call resolves to `{bars: [], noData: true}`
/// so the chart renders blank rather than throwing.
class ChartDatafeedBridge {
 /// Resolutions advertised to TradingView.
 static const List<String> supportedResolutions = [
 '1',
 '5',
 '15',
 '30',
 '60',
 '240',
 '1D',
 '1W',
 ];

 /// Active tick subscriptions keyed by `symbol_resolution_subscriberUID`.
 final Map<String, StreamSubscription<Map<String, dynamic>>> _subs = {};
 final Map<String, void Function(Map<String, dynamic>)> _tickCbs = {};
 String? _currentSymbol;

 /// Returns TradingView `onReady` config.
 Map<String, dynamic> onReady() => {
 'supported_resolutions': supportedResolutions,
 'supports_time': true,
 'supports_marks': true,
 'showCountdown': true,
 'exchanges': [
 {'value': '', 'name': 'All Exchanges', 'desc': ''},
 ],
 };

  /// Returns metadata for TradingView `resolveSymbol`.
  Future<Map<String, dynamic>?> resolveSymbol({
    required String symbol,
    String? accountNumber,
  }) async {
    String? acc = accountNumber;
    if (acc == null && Get.isRegistered<AccountController>()) {
      acc = Get.find<AccountController>()
          .activeMT5Account
          ?.metaAccountNumber
          .toString();
    }
    final effectiveSymbol =
        SymbolDetailsCacheService.resolveDatafeedSymbolSync(symbol, acc);
    final symbolInfo = await _safeSymbolDetails(effectiveSymbol, acc);
    final digits = (symbolInfo?['digits'] ?? 5) as int;
    final point = _pointFromDigits(digits);
    return {
      'ticker': effectiveSymbol,
      'name': effectiveSymbol,
      'description': symbolInfo?['category_name'] ?? effectiveSymbol,
      'type': 'forex',
      'session': '24x7',
      'timezone': 'Etc/UTC',
      'minmov': 1,
      'pointvalue': 1,
      'pricescale': (1 / point).round(),
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

  /// Fetches historical bars. Returns TradingView-shaped result.
  Future<Map<String, dynamic>> getBars({
    required String symbol,
    required String resolution,
    required int from,
    required int to,
    required int countBack,
    String? accountNumber,
  }) async {
    String effectiveSymbol = symbol;
    String? acc = accountNumber;
    if (acc == null && Get.isRegistered<AccountController>()) {
      acc = Get.find<AccountController>().activeMT5Account?.metaAccountNumber.toString();
    }
    effectiveSymbol = SymbolDetailsCacheService.resolveDatafeedSymbolSync(symbol, acc);

    final base = FlavorConfig.instance.chartBaseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/charthistory');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'symbol': effectiveSymbol,
              'from': from,
              'to': to,
              'resolution': resolution,
              'count': countBack,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return {'bars': <Map<String, dynamic>>[], 'noData': true};
      }
      final body = jsonDecode(response.body);
      if (body is! Map) {
        return {'bars': <Map<String, dynamic>>[], 'noData': true};
      }
      final raw = body['data'];
      if (raw is! List || raw.isEmpty) {
        return {'bars': <Map<String, dynamic>>[], 'noData': true};
      }
      final bars = raw.whereType<Map>().map((m) {
        return {
          'time': ((m['time'] as num?)?.toInt() ?? 0) * 1000,
          'open': (m['open'] as num?)?.toDouble() ?? 0.0,
          'high': (m['high'] as num?)?.toDouble() ?? 0.0,
          'low': (m['low'] as num?)?.toDouble() ?? 0.0,
          'close': (m['close'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
      if (bars.isNotEmpty && Get.isRegistered<ChartSocketController>()) {
        final lastBar = bars.last;
        final close = lastBar['close'] as double?;
        if (close != null && close > 0) {
          final socket = Get.find<ChartSocketController>();
          if (socket.matchesSymbol(effectiveSymbol) || socket.matchesSymbol(symbol)) {
            final curBid = socket.realTimePrice['bid'];
            if (curBid == null || curBid == 0.0) {
              socket.updatePriceFromExternal(
                symbol: effectiveSymbol,
                bid: close,
                ask: close,
              );
            }
          }
        }
      }
      return {'bars': bars, 'noData': false};
    } catch (e) {
      debugPrint('[ChartDatafeedBridge] getBars error: $e');
      return {'bars': <Map<String, dynamic>>[], 'noData': true};
    }
  }

  /// Starts ticking for `subscriberUID`. `onTick` is invoked on every
  /// `ChartSocketController` price update for `symbol`.
  void subscribeBars({
    required String symbol,
    required String resolution,
    required String subscriberUID,
    required void Function(Map<String, dynamic> tick) onTick,
  }) {
    if (!Get.isRegistered<ChartSocketController>()) return;
    _currentSymbol = symbol;
    final key = '${symbol}_${resolution}_$subscriberUID';
    _tickCbs[key] = onTick;
    if (_subs.containsKey(key)) return;

    final controller = Get.find<ChartSocketController>();
    final sub = controller.priceStream.listen((priceData) {
      final tickSymbol = priceData['symbol']?.toString() ?? _currentSymbol;
      if (tickSymbol == null) return;
      final tickDisplay =
          SymbolDetailsCacheService.displaySymbolOf(tickSymbol).toUpperCase();
      final curDisplay = SymbolDetailsCacheService.displaySymbolOf(
        _currentSymbol ?? '',
      ).toUpperCase();
      if (tickSymbol != _currentSymbol && tickDisplay != curDisplay) return;
      final bid = _toDouble(priceData['bid']);
      final ask = _toDouble(priceData['ask']);
      if (bid == null || ask == null) return;
      final mid = (bid + ask) / 2.0;
      final bar = _aggregateTick(priceData, mid);
      if (bar == null) return;
      final cb = _tickCbs[key];
      cb?.call(bar);
    });
    _subs[key] = sub;
  }

 /// Stops ticking for a subscriber.
 void unsubscribeBars(
 String subscriberUID, {
 String? symbol,
 String? resolution,
 }) {
 if (symbol != null && resolution != null) {
 final key = '${symbol}_${resolution}_$subscriberUID';
 _subs.remove(key)?.cancel();
 _tickCbs.remove(key);
 return;
 }
 _subs.removeWhere((k, sub) {
 if (k.endsWith('_$subscriberUID')) {
 sub.cancel();
 return true;
 }
 return false;
 });
 _tickCbs.removeWhere((k, _) => k.endsWith('_$subscriberUID'));
 }

 void dispose() {
 for (final sub in _subs.values) {
 sub.cancel();
 }
 _subs.clear();
 _tickCbs.clear();
 }

 // ─── helpers ─────────────────────────────────────────────────────────────

 double? _toDouble(dynamic v) {
 if (v == null) return null;
 if (v is num) return v.toDouble();
 return double.tryParse(v.toString());
 }

 double _pointFromDigits(int digits) {
 var p = 1.0;
 for (var i = 0; i < digits; i++) {
 p /= 10.0;
 }
 return p;
 }

  Future<Map<String, dynamic>?> _safeSymbolDetails(
    String symbol,
    String? accountNumber,
  ) async {
    String? acc = accountNumber;
    if (acc == null && Get.isRegistered<AccountController>()) {
      acc = Get.find<AccountController>()
          .activeMT5Account
          ?.metaAccountNumber
          .toString();
    }
    if (acc == null) return null;
    try {
      return await SymbolDetailsCacheService.getSymbolDetails(
        symbol,
        acc,
      );
    } catch (_) {
      return null;
    }
  }

 Map<String, dynamic>? _aggregateTick(
 Map<String, dynamic> priceData,
 double mid,
 ) {
 final t = _toDouble(priceData['time']);
 final tsMs = t == null
 ? DateTime.now().millisecondsSinceEpoch
 : (t > 1e12 ? t.toInt() : (t * 1000).toInt());
 return {
 'time': tsMs,
 'open': mid,
 'high': mid,
 'low': mid,
 'close': mid,
 'volume': 0,
 };
 }
}
