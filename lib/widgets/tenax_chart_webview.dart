// ============================================================
// TenaxChartWebView
//
// Drop-in for ChartInAppWebView / AdvancedChartInAppWebView that renders
// the custom chart bundle backed by the real broker datafeed (REST history + WebSocket ticks).
//
//
//   TenaxChartWebView(key: tenaxKey, symbol: raw, isDark: isDark)
//
// Token is read once from SecureStorageService; after that, symbol
// switches go through the controller (no WebView teardown).
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'tenax_chart/tenax_chart.dart';

import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/models/order_types.dart';

class TenaxChartWebView extends StatefulWidget {
  const TenaxChartWebView({
    super.key,
    required this.symbol,
    required this.isDark,
  });

  final String symbol;
  final bool isDark;

  @override
  State<TenaxChartWebView> createState() => TenaxChartWebViewState();
}

class TenaxChartWebViewState extends State<TenaxChartWebView> {
  _PipzeTenaxApi? _api;
  TenaxChartController? _controller;

  // Fixed at first build — never changed so the WebView is never torn down.
  late final String _initialSymbol;

  bool _loading = true;
  String? _error;

  Worker? _positionsWorker;
  Worker? _pendingWorker;

  @override
  void initState() {
    super.initState();
    _initialSymbol = _chartSymbol(widget.symbol);
    _resolveToken();
    _setupOrderSync();
  }


  void _setupOrderSync() {
    try {
      if (Get.isRegistered<TradingController>()) {
        final tradeCtrl = Get.find<TradingController>();
        _positionsWorker = ever(tradeCtrl.marketPositionsRx, (_) => _syncOrders());
        _pendingWorker = ever(tradeCtrl.pendingPositionsRx, (_) => _syncOrders());
      }
    } catch (_) {}
  }

  void _syncOrders() {
    if (_controller == null) return;
    try {
      if (!Get.isRegistered<TradingController>()) return;
      final tradeCtrl = Get.find<TradingController>();

      final positions = tradeCtrl.marketPositions.map((p) {
        return Position(
          id: p.orderId.isNotEmpty ? p.orderId : (p.orderNo.isNotEmpty ? p.orderNo : '${p.symbol}_${p.openTime}'),
          symbol: _chartSymbol(p.symbol),
          side: p.action.toLowerCase() == 'buy' ? OrderSide.buy : OrderSide.sell,
          volume: p.volume,
          entry: double.tryParse(p.entryPrice) ?? 0.0,
          sl: double.tryParse(p.stopLoss),
          tp: double.tryParse(p.takeProfit),
          profit: p.profitLoss,
        );
      }).toList();

      final pendings = tradeCtrl.pendingPositions.map((p) {
        PendingKind kind = PendingKind.buyLimit;
        final act = p.action.toLowerCase();
        if (act.contains('buy') && act.contains('stop')) kind = PendingKind.buyStop;
        else if (act.contains('sell') && act.contains('limit')) kind = PendingKind.sellLimit;
        else if (act.contains('sell') && act.contains('stop')) kind = PendingKind.sellStop;
        else if (act.contains('buy')) kind = PendingKind.buyLimit;

        return PendingOrder(
          id: p.orderId.isNotEmpty ? p.orderId : (p.orderNo.isNotEmpty ? p.orderNo : '${p.symbol}_${p.openTime}'),
          symbol: _chartSymbol(p.symbol),
          kind: kind,
          volume: p.volume,
          price: double.tryParse(p.entryPrice) ?? 0.0,
          sl: double.tryParse(p.stopLoss),
          tp: double.tryParse(p.takeProfit),
        );
      }).toList();

      _controller!.setOrders(positions: positions, pendings: pendings);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant TenaxChartWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = _chartSymbol(oldWidget.symbol);
    final next = _chartSymbol(widget.symbol);
    // `XAUUSD` → `XAUUSD.c` is the same instrument; only a real change
    // switches the chart (and reloads history).
    if (previous != next) {
      debugPrint(
        'TenaxChartWebView didUpdateWidget: symbol changed from $previous to $next '
        '(controller ready: ${_controller != null})',
      );
      // In-place switch — controller sends a JS message; WebView stays alive.
      _controller?.setSymbol(next);
      _syncOrders();
    }
  }

  /// Chart/history symbol: upper-case, no account suffix (`.c`, `.m` …).
  static String _chartSymbol(String raw) {
    final upper = raw.trim().toUpperCase();
    final dot = upper.indexOf('.');
    return dot > 0 ? upper.substring(0, dot) : upper;
  }

  @override
  void dispose() {
    _positionsWorker?.dispose();
    _pendingWorker?.dispose();
    _api?.dispose();
    super.dispose();
  }

  Future<void> _resolveToken() async {
    try {
      final token = await SecureStorageService.getAuthToken();
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No auth token found. Please log in again.';
        });
        return;
      }

      final base = FlavorConfig.instance.chartBaseUrl.replaceAll(
        RegExp(r'/$'),
        '',
      );

      setState(() {
        _api = _PipzeTenaxApi(baseUrl: base, token: token);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load credentials: $e';
      });
    }
  }

  void updateSymbol(String symbol) {
    _controller?.setSymbol(_chartSymbol(symbol));
    _syncOrders();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CommonLoadingWidget(
          message: Get.find<LanguageService>().tr(
            'tenax_chart_webview_initializing_chart',
          ),
          size: 40.0,
          color: AppColors.primary,
        ),
      );
    }

    if (_error != null || _api == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.h, color: AppColors.textGrey),
            SizedBox(height: 12.h),
            Text(
              _error ?? 'Chart unavailable',
              textAlign: TextAlign.center,
              style: AppTextStyles.subheading.copyWith(
                color: AppColors.textGrey,
              ),
            ),
            SizedBox(height: 12.h),
            OutlinedButton(
              onPressed: () {
                setState(() { _loading = true; _error = null; _api = null; });
                _resolveToken();
              },
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
          ],
        ),
      );
    }

    // MediaQuery.removePadding strips any top/bottom safe-area insets injected
    // by the parent Scaffold's SafeArea so the WebView fills edge-to-edge
    // without a blank gap at the top or bottom.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: TenaxChartView(
          // Stable ValueKey → WebView is never torn down on symbol change.
          key: const ValueKey('tenax_chart_pipze'),
          api: _api!,
          initialSymbol: _initialSymbol,
          initialResolution: '15m',
          theme: widget.isDark ? ChartTheme.dark : ChartTheme.light,
          onControllerReady: (c) {
            _controller = c;
            // The header may have switched symbol while the chart was still
            // loading; that change had no controller to go to, so apply it now.
            final current = _chartSymbol(widget.symbol);
            debugPrint(
              'TenaxChartWebView controller ready (initial $_initialSymbol, current $current)',
            );
            if (current != _initialSymbol) {
              c.setSymbol(current);
            }
            _syncOrders();
          },
          onError: (e) => debugPrint('TenaxChartWebView: $e'),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PipzeTenaxApi  —  TenaxChartApi implementation for the CRM backend
// ─────────────────────────────────────────────────────────────────────────────
class _PipzeTenaxApi extends TenaxChartApi {
  _PipzeTenaxApi({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;
  final http.Client _client = http.Client();

  WebSocketChannel? _socket;
  final Map<String, void Function(Tick)> _tickListeners = {};
  final Map<String, void Function()> _cancelCallbacks = {};

  static String _cleanSymbol(String raw) {
    final upper = raw.trim().toUpperCase();
    final dot = upper.indexOf('.');
    return dot > 0 ? upper.substring(0, dot) : upper;
  }

  /// Seconds per bar for the cleaned resolution ('15', '60', '1D', ...).
  static int _barSeconds(String cleanedRes) {
    switch (cleanedRes) {
      case '1D':
        return 86400;
      case '1W':
        return 7 * 86400;
      case '1M':
        return 30 * 86400;
      default:
        return (int.tryParse(cleanedRes) ?? 1) * 60;
    }
  }

  /// Active MT5 trading account for `user/instruments/{account}`. The token
  /// prefix (`16362|...`) is the Sanctum token id, not an account, and the
  /// API answers it with 404 "Trading account not found".
  String get _accountNumber {
    if (!Get.isRegistered<AccountController>()) return '';
    final raw = Get.find<AccountController>().activeMT5Account?.metaAccountNumber;
    return raw?.trim() ?? '';
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  String _cleanResolution(String r) {
    var clean = r.toLowerCase();
    if (clean.endsWith('m')) {
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

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // ── fetchCandles ──────────────────────────────────────────────────────────
  /// In-flight history requests shared by every chart instance (chart tab,
  /// order screens, rebuilt widgets). A second caller for the same
  /// symbol+resolution awaits the running response instead of opening a
  /// new connection — that pile-up is what flooded /market/history.
  static final Map<String, Future<List<Candle>>> _inFlightHistory = {};
  static int _historySeq = 0;

  @override
  Future<List<Candle>> fetchCandles({
    required String symbol,
    required String resolution,
    int? from,
    int? to,
  }) {
    final key = '$symbol|${_cleanResolution(resolution)}|${from ?? ''}|${to ?? ''}';
    final running = _inFlightHistory[key];
    if (running != null) {
      print('fetchCandles: reuse in-flight $key');
      return running;
    }
    // Block body on purpose: `remove` returns this same Future, and a Future
    // returned from whenComplete is awaited — the request would wait on
    // itself forever and the bars would never reach the chart.
    final request = _fetchCandlesNetwork(
      symbol: symbol,
      resolution: resolution,
      from: from,
      to: to,
    ).whenComplete(() {
      _inFlightHistory.remove(key);
    });
    _inFlightHistory[key] = request;
    return request;
  }

  Future<List<Candle>> _fetchCandlesNetwork({
    required String symbol,
    required String resolution,
    int? from,
    int? to,
  }) async {
    final seq = ++_historySeq;
    const count = 500;
    final cleanedRes = _cleanResolution(resolution);
    // Backend contract: symbol=XAUUSD.c&from=..&to=..&count=500&resolution=15
    // with a from/to window of 1000 bars ending now.
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final toSec = to ?? nowSec;
    final fromSec = from ?? (toSec - 1000 * _barSeconds(cleanedRes));

    // `datafeed_symbol` from user/instruments/{account}; loads that API
    // first if it is not cached yet.
    final feedSymbol = await SymbolDetailsCacheService.resolveDatafeedSymbol(
      symbol,
      _accountNumber,
    );
    final uri = Uri.parse('$baseUrl/api/market/history').replace(queryParameters: {
      'symbol': feedSymbol,
      'from': '$fromSec',
      'to': '$toSec',
      'count': '$count',
      'resolution': cleanedRes,
    });

    print('fetchCandles: #$seq GET $uri');
    final res = await _client.get(uri, headers: _headers);
    print('fetchCandles: #$seq status ${res.statusCode}');
    
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map || data['s'] == 'error') {
      throw Exception(data['errmsg'] ?? 'API error');
    }

    final tList = data['t'] as List?;
    if (tList == null || tList.isEmpty) {
      throw Exception('No candle data returned for $symbol/$res');
    }

    final oList = data['o'] as List;
    final hList = data['h'] as List;
    final lList = data['l'] as List;
    final cList = data['c'] as List;
    final vList = data['v'] is List ? data['v'] as List : null;

    final List<Candle> candles = [];
    for (int i = 0; i < tList.length; i++) {
      final open = _asDouble(oList[i]) ?? 0.0;
      final high = _asDouble(hList[i]) ?? 0.0;
      final low = _asDouble(lList[i]) ?? 0.0;
      final close = _asDouble(cList[i]) ?? 0.0;
      
      // Prevent chart Y-axis from stretching to 0 if the backend returns empty/corrupted candles
      if (open == 0 && high == 0) continue;
      
      candles.add(Candle(
        time: _asInt(tList[i]) ?? 0,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: vList != null && i < vList.length ? _asDouble(vList[i]) : null,
      ));
    }

    // Lightweight Charts REQUIRES data to be strictly ascending in time and
    // have NO duplicates. If not, the JS side throws a fatal error and freezes.
    candles.sort((a, b) => a.time.compareTo(b.time));
    final List<Candle> uniqueCandles = [];
    int? lastTime;
    for (final c in candles) {
      if (lastTime == null || c.time > lastTime) {
        uniqueCandles.add(c);
        lastTime = c.time;
      }
    }
    print('fetchCandles: Returning ${uniqueCandles.length} candles (original: ${candles.length})');
    return uniqueCandles;
  }

  // ── fetchSymbols ──────────────────────────────────────────────────────────
  @override
  Future<List<SymbolInfo>> fetchSymbols() async {
    if (_accountNumber.isNotEmpty) {
      try {
        final uri = Uri.parse(
          '$baseUrl/api/user/instruments/$_accountNumber',
        );
        final res = await _client.get(uri, headers: _headers);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = data is List
              ? data
              : (data is Map ? (data['data']?['symbols'] ?? data['data'] ?? []) : []);
          if (list is List && list.isNotEmpty) {
            return list
                .map<SymbolInfo?>((e) {
                  final sym = e is String
                      ? e
                      : (e is Map ? (e['display_symbol'] ?? e['symbol'] ?? e['name'] ?? '') : '').toString();
                  if (sym.isEmpty) return null;
                  final desc = e is Map ? (e['description'] ?? e['name']) : null;
                  return SymbolInfo(
                    symbol: sym,
                    description: desc?.toString(),
                  );
                })
                .whereType<SymbolInfo>()
                .toList();
          }
        }
      } catch (_) {}
    }

    return const [
      SymbolInfo(symbol: 'EURUSD', description: 'Euro / US Dollar', digits: 5),
      SymbolInfo(symbol: 'GBPUSD', description: 'Great Britain Pound / US Dollar', digits: 5),
      SymbolInfo(symbol: 'USDJPY', description: 'US Dollar / Japanese Yen', digits: 3),
      SymbolInfo(symbol: 'XAUUSD', description: 'Gold / US Dollar', digits: 2),
      SymbolInfo(symbol: 'BTCUSD', description: 'Bitcoin / US Dollar', digits: 2),
      SymbolInfo(symbol: 'ETHUSD', description: 'Ethereum / US Dollar', digits: 2),
    ];
  }

  // ── subscribeTicks ────────────────────────────────────────────────────────
  @override
  void Function() subscribeTicks(
    String symbol,
    void Function(Tick tick) onTick,
  ) {
    _tickListeners[symbol] = onTick;
    _ensureSocket();

    // Same async lookup as history: the sync one returns plain `XAUUSD` when
    // user/instruments is not cached yet, and /ws/pricing only streams the
    // datafeed symbol (`XAUUSD.cent`), so the chart got no live ticks.
    var cancelled = false;
    String? feedSymbol;
    SymbolDetailsCacheService.resolveDatafeedSymbol(
      symbol,
      _accountNumber.isEmpty ? null : _accountNumber,
    ).then((resolved) {
      if (cancelled) return;
      feedSymbol = resolved;
      print('TenaxTrace subscribe_chart $resolved (chart $symbol)');
      try {
        _socket?.sink.add(jsonEncode({
          'type': 'subscribe_chart',
          'symbol': resolved,
        }));
      } catch (_) {}
    });

    return () {
      cancelled = true;
      _tickListeners.remove(symbol);
      final subscribed = feedSymbol;
      if (subscribed != null) {
        try {
          _socket?.sink.add(jsonEncode({
            'type': 'unsubscribe_chart',
            'symbol': subscribed,
          }));
        } catch (_) {}
      }
      if (_tickListeners.isEmpty) {
        _socket?.sink.close();
        _socket = null;
      }
    };
  }

  // ── modifyOrder ───────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> modifyOrder({
    required String orderId,
    required String field,
    required double? price,
  }) async {
    try {
      if (Get.isRegistered<TradingController>()) {
        final tradeCtrl = Get.find<TradingController>();
        final posId = int.tryParse(orderId) ?? 0;
        final acc = Get.isRegistered<AccountController>()
            ? Get.find<AccountController>().activeMT5Account?.metaAccountNumber ?? ''
            : '';
        if (field == 'sl') {
          await tradeCtrl.updateTPSL(
            mt5Account: acc,
            positionId: posId,
            stopLoss: price ?? 0.0,
          );
        } else if (field == 'tp') {
          await tradeCtrl.updateTPSL(
            mt5Account: acc,
            positionId: posId,
            takeProfit: price ?? 0.0,
          );
        }
      }
    } catch (_) {}
    return {'id': orderId, field: price};
  }

  // ── closeOrder ────────────────────────────────────────────────────────────
  @override
  Future<void> closeOrder(String orderId) async {
    try {
      if (Get.isRegistered<TradingController>()) {
        await Get.find<TradingController>().closePosition(orderId);
      }
    } catch (_) {}
  }

  // ── placeOrder ────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> request) async {
    if (Get.isRegistered<TradingController>()) {
      final tradeCtrl = Get.find<TradingController>();
      final side = request['side']?.toString().toLowerCase() ?? 'buy';
      final typeStr = request['type']?.toString().toLowerCase() ?? 'market';
      
      OrderType orderType = OrderType.buyMarket;
      if (side == 'buy') {
        if (typeStr == 'limit') orderType = OrderType.buyLimit;
        else if (typeStr == 'stop') orderType = OrderType.buyStop;
        else orderType = OrderType.buyMarket;
      } else {
        if (typeStr == 'limit') orderType = OrderType.sellLimit;
        else if (typeStr == 'stop') orderType = OrderType.sellStop;
        else orderType = OrderType.sellMarket;
      }

      await tradeCtrl.placeTradeOrder(
        orderType: orderType,
        symbol: request['symbol'] ?? '',
        volume: (request['volume'] ?? 0.01).toString(),
        price: (request['price'] ?? '').toString(),
        stopLoss: request['sl']?.toString(),
        takeProfit: request['tp']?.toString(),
      );
    }
    // Return a dummy map so the chart doesn't crash; the real order line will be 
    // drawn when the WebSocket pushes it to TradingController and _syncOrders fires.
    return request;
  }

  // ── WebSocket management ──────────────────────────────────────────────────
  final Set<String> _tracedTickSymbols = {};

  void _ensureSocket() {
    if (_socket != null) return;

    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    _socket = WebSocketChannel.connect(
      Uri.parse('$wsBase/ws/pricing'),
      protocols: ['Bearer $token'],
    );

    _socket!.stream.listen(
      (raw) {
        try {
          final msg = raw is String
              ? jsonDecode(raw)
              : jsonDecode(utf8.decode(raw as List<int>));
          if (msg is! Map) return;

          // /ws/pricing sends compact frames:
          // {"i":"XAGUSD.CENT","t":<ms>,"b":60.627,"a":60.645,"bt":<ms>}
          final sym = (msg['i'] ?? msg['symbol'])?.toString() ?? '';
          if (sym.isEmpty) return;
          // Feed answers with the datafeed symbol (upper-cased, e.g.
          // `XAGUSD.CENT`) while the chart listens on `XAGUSD`.
          final chartSym = _tickListeners.containsKey(sym) ? sym : _cleanSymbol(sym);
          final onTick = _tickListeners[chartSym];
          if (onTick == null) return;

          final bid = _asDouble(msg['b'] ?? msg['bid']);
          final ask = _asDouble(msg['a'] ?? msg['ask']);
          if (bid == null || ask == null) return;

          final tickMs = _asDouble(msg['t']);
          if (kDebugMode && _tracedTickSymbols.add(chartSym)) {
            debugPrint('TenaxTrace first tick $sym → $chartSym b=$bid a=$ask');
          }
          onTick(Tick(
            symbol: chartSym,
            bid: bid,
            ask: ask,
            time: tickMs == null ? null : tickMs ~/ 1000,
          ));

          if (Get.isRegistered<ChartSocketController>()) {
            final chartSocket = Get.find<ChartSocketController>();
            if (chartSocket.matchesSymbol(sym)) {
              chartSocket.updatePriceFromExternal(
                symbol: sym,
                bid: bid,
                ask: ask,
              );
            }
          }
        } catch (_) {}
      },
      onDone: () {
        _socket = null;
        if (_tickListeners.isNotEmpty) {
          Future.delayed(const Duration(seconds: 2), _ensureSocket);
        }
      },
      onError: (_) {
        _socket = null;
        if (_tickListeners.isNotEmpty) {
          Future.delayed(const Duration(seconds: 2), _ensureSocket);
        }
      },
      cancelOnError: true,
    );
  }

  void dispose() {
    _client.close();
    _socket?.sink.close();
    _socket = null;
    _tickListeners.clear();
    _cancelCallbacks.clear();
  }
}
