// IQuoteChartController — header / bottom-bar state for the IQuote chart
// screen.
//
// Note: the candle chart itself is rendered as a static placeholder for now
// (per product request — chart wiring lands in a follow-up). All the live
// state around the chart (price header, period selector, MA labels, bottom
// Buy/Sell pills, Team/Position counters) is driven from here and wired to the
// existing InstrumentsController (for live bid/ask), AccountController (for
// the active MT5 account) and TradingController (for positions/pending
// orders + the placeTradeOrder API entry point).
//
// The Buy/Sell pills on the chart both open the same new-order bottom sheet,
// pre-filled for the chosen side. The sheet distinguishes "Buy Market",
// "Sell Market", "Buy Limit", "Sell Limit" — and the typed OrderType enum
// gets sent straight through TradingController.placeTradeOrder so the API
// payload matches what the rest of the app sends.
import 'package:get/get.dart';

import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/services/api_service.dart';

class CandleData {
  final DateTime dateTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  CandleData({
    required this.dateTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class IQuoteChartController extends GetxController {
  IQuoteChartController([String? initialSymbol]) {
    if (initialSymbol != null) {
      symbolRx.value = initialSymbol;
    }
  }

  final symbolRx = 'XAUUSD.c'.obs;
  String get symbol => symbolRx.value;
  set symbol(String value) => symbolRx.value = value;

  // ── header state ────────────────────────────────────────────────────────
  final currentPrice = Rxn<double>();
  final priceChange = Rxn<double>();
  final priceChangePct = Rxn<double>();
  final lastBid = Rxn<double>();
  final lastAsk = Rxn<double>();
  // Renamed from `digits` to avoid shadowing GetxController.digits.
  final priceDigits = 2.obs;
  final period = '1M'.obs; // Default period
  final isLoading = false.obs;

  // ── candlestick data ───────────────────────────────────────────────────
  final chartData = <CandleData>[].obs;
  final isChartLoading = false.obs;
  final isLoadingOlder = false.obs;
  final resolution = 1.obs; // Resolution in minutes (default 1M)
  final customFromDate = Rxn<DateTime>();
  final customToDate = Rxn<DateTime>();

  // ── bottom-bar counters ────────────────────────────────────────────────
  // Mirrors TradingController.marketPositionsRx / pendingPositions so the
  // Team and Position badges reflect the live count.
  final openPositionCount = 0.obs;
  final pendingOrderCount = 0.obs;

  // ── chart scale (right-axis labels + bid/ask marker lines) ────────────
  final chartScaleHigh = Rxn<double>();
  final chartScaleLow = Rxn<double>();
  final chartBidLine = Rxn<double>();
  final chartAskLine = Rxn<double>();

  AccountController get _account => Get.find<AccountController>();
  TradingController get _trading => Get.find<TradingController>();
  InstrumentsController get _instruments => Get.find<InstrumentsController>();

  Worker? _livePriceWorker;

  @override
  void onInit() {
    super.onInit();
    _hydrateInitial();
    _bindLive();
    fetchHistoryData();

    // Open positions drive the Team badge (once)
    ever<List<TradePosition>>(
      _trading.marketPositionsRx,
      (_) => _refreshCounts(),
    );

    // Re-fetch and re-bind if the symbol changes!
    ever(symbolRx, (_) {
      _hydrateInitial();
      _bindLive();
      fetchHistoryData();
    });
  }

  void _hydrateInitial() {
    final quote = _instruments.priceRx(symbol).value;
    _applyQuote(quote);
    _refreshCounts();
  }

  void _bindLive() {
    _livePriceWorker?.dispose();
    final sym = symbol;
    // Live tick stream — keeps header + chart markers + Buy/Sell pills live.
    _livePriceWorker = ever<InstrumentPrice>(_instruments.priceRx(sym), _applyQuote);
  }

  void _applyQuote(InstrumentPrice? quote) {
    if (quote == null) return;
    // InstrumentPrice has bid/ask/digits but no `last` field — derive a
    // mid-price for the header so the big number and MA labels stay live.
    final mid = quote.bid == 0 && quote.ask == 0
        ? null
        : (quote.bid + quote.ask) / 2;
    currentPrice.value = mid;
    priceDigits.value = quote.digits;
    lastBid.value = quote.bid;
    lastAsk.value = quote.ask;

    final dayLow = quote.dayLow;
    final changeVal = dayLow > 0 ? (quote.bid - dayLow) : 0.0;
    final changePct = dayLow > 0 ? ((quote.bid - dayLow) / dayLow * 100) : 0.0;
    priceChange.value = changeVal;
    priceChangePct.value = changePct;

    _pushScaleMarkers(quote.bid, quote.ask, mid);
    if (mid != null) {
      _updateLiveCandle(mid);
    }
  }

  void _updateLiveCandle(double price) {
    if (chartData.isEmpty) return;

    final lastCandle = chartData.last;
    final now = DateTime.now();
    final candleDuration = Duration(minutes: resolution.value);
    final nextCandleTime = lastCandle.dateTime.add(candleDuration);

    if (now.isBefore(nextCandleTime)) {
      // Update the current last candle
      final double newHigh = price > lastCandle.high ? price : lastCandle.high;
      final double newLow = price < lastCandle.low ? price : lastCandle.low;

      chartData[chartData.length - 1] = CandleData(
        dateTime: lastCandle.dateTime,
        open: lastCandle.open,
        high: newHigh,
        low: newLow,
        close: price,
        volume: lastCandle.volume,
      );
    } else {
      // Start a new candle aligned to the resolution minutes boundary
      final int minutesSinceEpoch = now.millisecondsSinceEpoch ~/ (60 * 1000);
      final int alignedMinutes = (minutesSinceEpoch ~/ resolution.value) * resolution.value;
      final alignedTime = DateTime.fromMillisecondsSinceEpoch(alignedMinutes * 60 * 1000);

      final newCandle = CandleData(
        dateTime: alignedTime,
        open: price,
        high: price,
        low: price,
        close: price,
        volume: 0.0,
      );

      chartData.add(newCandle);
      if (chartData.length > 1000) {
        chartData.removeAt(0);
      }
    }
  }

  void _refreshCounts() {
    openPositionCount.value = _trading.marketPositionsRx.length;
    pendingOrderCount.value = _trading.pendingPositions.length;
  }

  void _pushScaleMarkers(double? bid, double? ask, double? price) {
    if (bid == null && ask == null && price == null) return;
    final samples = <double>[
      if (bid != null) bid,
      if (ask != null) ask,
      if (price != null) price,
    ];
    final hi = samples.reduce((a, b) => a > b ? a : b);
    final lo = samples.reduce((a, b) => a < b ? a : b);
    final span = (hi - lo).abs();
    final pad = span < 0.0001 ? hi.abs() * 0.005 : span * 0.4;
    chartScaleHigh.value = hi + pad;
    chartScaleLow.value = lo - pad;
    chartBidLine.value = bid;
    chartAskLine.value = ask;
  }

  Future<void> fetchHistoryData() async {
    try {
      isChartLoading.value = true;
      final sym = symbol; // Preserve case!
      
      int resVal = resolution.value;
      int countVal = 500; // Safe count of bars (fits server retention bounds)
      
      // Calculate from and to timestamps
      int toEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int fromEpoch;
      
      if (period.value == 'More') {
        if (customFromDate.value == null || customToDate.value == null) {
          isChartLoading.value = false;
          return;
        }
        fromEpoch = customFromDate.value!.millisecondsSinceEpoch ~/ 1000;
        toEpoch = customToDate.value!.millisecondsSinceEpoch ~/ 1000;
        countVal = 1000; // Allow larger custom range requests
      } else {
        // Map standard timeframes to durations (fetching approx 500 bars)
        switch (period.value) {
          case '1m':
            resVal = 1;
            countVal = 1; // Default: last 1 minute (60 seconds)
            fromEpoch = toEpoch - (countVal * 60);
            break;
          case '5m':
            resVal = 5;
            countVal = 500;
            fromEpoch = toEpoch - (countVal * 5 * 60); // 2500 minutes ago (~41.6 hours)
            break;
          case '15m':
            resVal = 15;
            countVal = 500;
            fromEpoch = toEpoch - (countVal * 15 * 60); // 7500 minutes ago (~5.2 days)
            break;
          case '30m':
            resVal = 30;
            countVal = 500;
            fromEpoch = toEpoch - (countVal * 30 * 60); // 15000 minutes ago (~10.4 days)
            break;
          default:
            resVal = 15;
            countVal = 500;
            fromEpoch = toEpoch - (countVal * 15 * 60);
        }
        resolution.value = resVal;
      }
      
      final Map<String, String> queryParams = {
        'symbol': sym,
        'from': fromEpoch.toString(),
        'to': toEpoch.toString(),
        'count': countVal.toString(),
        'resolution': resVal.toString(),
      };
      
      print('📈 iQuote Chart: Fetching market history for $sym: $queryParams');
      final response = await ApiService.get(
        endpoint: 'market/history',
        queryParameters: queryParams,
      );
      
      print('📈 iQuote Chart API Success: ${response.success}, HasData: ${response.data != null}');
      if (response.success && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['s'] == 'ok') {
          final tList = data['t'] as List<dynamic>?;
          final oList = data['o'] as List<dynamic>?;
          final hList = data['h'] as List<dynamic>?;
          final lList = data['l'] as List<dynamic>?;
          final cList = data['c'] as List<dynamic>?;
          final vList = data['v'] as List<dynamic>?;
          
          if (tList != null && oList != null && hList != null && lList != null && cList != null) {
            final List<CandleData> parsed = [];
            for (var i = 0; i < tList.length; i++) {
              final int timestamp = (tList[i] as num).toInt();
              final double open = (oList[i] as num).toDouble();
              final double high = (hList[i] as num).toDouble();
              final double low = (lList[i] as num).toDouble();
              final double close = (cList[i] as num).toDouble();
              final double volume = (vList != null && i < vList.length) 
                  ? (vList[i] as num).toDouble() 
                  : 0.0;
              
              parsed.add(CandleData(
                dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
              ));
            }
            chartData.value = parsed;
            print('📈 iQuote Chart: Loaded ${parsed.length} candles.');
          }
        } else {
          print('📈 iQuote Chart API response error: $data');
        }
      } else {
        print('📈 iQuote Chart API failed or no response: ${response.message}');
      }
    } catch (e) {
      print('📈 iQuote Chart Error fetching market history: $e');
    } finally {
      isChartLoading.value = false;
    }
  }

  // ── load older history on pan-to-start ────────────────────────────────
  Future<void> loadOlderHistory() async {
    if (isLoadingOlder.value) return;
    if (chartData.isEmpty) return;
    if (symbol.isEmpty) return;

    isLoadingOlder.value = true;
    try {
      int resVal = 1;
      int countVal = 500;
      final earliestMs = chartData.first.dateTime.millisecondsSinceEpoch;
      // For resolution=1 (1-minute), step back by `countVal * 60` seconds.
      // (Matches the multipliers used in fetchHistoryData.)
      final fromEpoch = (earliestMs ~/ 1000) - (countVal * 60);
      final toEpoch = (earliestMs ~/ 1000);

      final queryParams = <String, String>{
        'symbol': symbol,
        'resolution': resVal.toString(),
        'from': fromEpoch.toString(),
        'to': toEpoch.toString(),
      };

      print('📈 iQuote Chart: Fetching older market history for $symbol: $queryParams');
      final response = await ApiService.get(
        endpoint: 'market/history',
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['s'] == 'ok') {
          final tList = data['t'] as List<dynamic>?;
          final oList = data['o'] as List<dynamic>?;
          final hList = data['h'] as List<dynamic>?;
          final lList = data['l'] as List<dynamic>?;
          final cList = data['c'] as List<dynamic>?;
          final vList = data['v'] as List<dynamic>?;

          if (tList != null && tList.isNotEmpty &&
              oList != null && hList != null && lList != null && cList != null) {
            final List<CandleData> older = [];
            for (var i = 0; i < tList.length; i++) {
              final int timestamp = (tList[i] as num).toInt();
              // Skip if not strictly older than our current earliest.
              if (timestamp * 1000 >= earliestMs) continue;
              older.add(CandleData(
                dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
                open: (oList[i] as num).toDouble(),
                high: (hList[i] as num).toDouble(),
                low: (lList[i] as num).toDouble(),
                close: (cList[i] as num).toDouble(),
                volume: (vList != null && i < vList.length)
                    ? (vList[i] as num).toDouble()
                    : 0.0,
              ));
            }
            if (older.isNotEmpty) {
              chartData.value = [...older, ...chartData];
              print('📈 iQuote Chart: Prepended ${older.length} older candles.');
            }
          }
        }
      }
    } catch (e) {
      print('📈 iQuote Chart Error loading older history: $e');
    } finally {
      isLoadingOlder.value = false;
    }
  }

  // ── account helpers (typed) ────────────────────────────────────────────
  MT5Account? get activeAccount => _account.activeMT5AccountRx.value;
  bool get isDemoAccount =>
      activeAccount == null || activeAccount!.isDemoAccount;

  // ── period selector ────────────────────────────────────────────────────
  static const List<String> kPeriods = ['1m', '5m', '15m', '30m', 'More'];
  void changePeriod(String p) {
    if (kPeriods.contains(p)) {
      period.value = p;
      if (p != 'More') {
        fetchHistoryData();
      }
    }
  }

  // ── order placement ───────────────────────────────────────────────────
  /// Send a market/limit order through TradingController.placeTradeOrder
  /// (the same entry point enhanced_pending_order_content / meta_chart_screen
  /// / celestial_chart_screen use).
  ///
  /// [side]     = "buy" | "sell"
  /// [orderKind] = "market" | "limit"
  /// [price]    = required for limit orders; pass "" for market orders.
  /// Returns ({bool ok, String message, OrderType orderType}).
  Future<
      ({
        bool ok,
        String message,
        OrderType orderType,
      })> submitOrder({
    required String side,
    required String orderKind,
    required double volume,
    required String price,
    String? takeProfit,
    String? stopLoss,
  }) async {
    final acct = activeAccount;
    if (acct == null) {
      return (
        ok: false,
        message: 'No active MT5 account selected.',
        orderType: _orderType(side, orderKind),
      );
    }
    if (volume <= 0) {
      return (
        ok: false,
        message: 'Volume must be greater than 0.',
        orderType: _orderType(side, orderKind),
      );
    }

    final kind = orderKind.toLowerCase();
    final orderType = _orderType(side, kind);
    if (orderType.requiresPrice && (price.isEmpty || double.tryParse(price) == null || double.parse(price) <= 0)) {
      return (
        ok: false,
        message: 'Please enter a valid limit price.',
        orderType: orderType,
      );
    }

    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();
      if (token == null || token.isEmpty) {
        return (
          ok: false,
          message: 'Authentication token missing.',
          orderType: orderType,
        );
      }

      final ok = await _trading.placeTradeOrder(
        symbol: symbol,
        volume: volume.toStringAsFixed(2),
        orderType: orderType,
        price: orderType.requiresPrice ? price : '',
        takeProfit: (takeProfit != null && takeProfit.isNotEmpty)
            ? takeProfit
            : null,
        stopLoss: (stopLoss != null && stopLoss.isNotEmpty)
            ? stopLoss
            : null,
        mt5Account: acct.metaAccountNumber,
      );

      if (ok) {
        CustomToastService.showSuccess(
          message:
              '$orderType ${volume.toStringAsFixed(2)} ${symbol.toUpperCase()}',
          title: 'Order placed',
        );
        // Refresh positions + pending orders so the bottom-bar counters
        // update immediately.
        await _trading.refreshTradeHistory();
        _refreshCounts();
        return (ok: true, message: 'Order placed', orderType: orderType);
      }

      final errorMsg = _trading.errorMessage.isEmpty
          ? 'Failed to place order.'
          : _trading.errorMessage;
      CustomToastService.showError(message: errorMsg);
      return (ok: false, message: errorMsg, orderType: orderType);
    } catch (e) {
      return (ok: false, message: e.toString(), orderType: orderType);
    } finally {
      isLoading.value = false;
    }
  }

  static OrderType _orderType(String side, String kind) {
    final isBuy = side.toLowerCase() == 'buy';
    final isLimit = kind == 'limit';
    if (isBuy && isLimit) return OrderType.buyLimit;
    if (!isBuy && isLimit) return OrderType.sellLimit;
    if (isBuy) return OrderType.buyMarket;
    return OrderType.sellMarket;
  }

  // ── MA labels (driven from the live price so the strip updates as the
  // quote moves; real MA maths lands when the candle series is wired) ────
  String _ma(int n) {
    final p = currentPrice.value;
    if (p == null) return 'MA$n:—';
    return 'MA$n:${p.toStringAsFixed(priceDigits.value)}';
  }

  String get ma5Label => _ma(5);
  String get ma10Label => _ma(10);
  String get ma30Label => _ma(30);
}