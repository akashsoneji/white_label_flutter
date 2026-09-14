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
import 'package:crm_app/services/market_watch_v2_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/language_service.dart';

import 'package:crm_app/services/symbol_selection_service.dart';

import 'package:crm_app/widgets/custom_toast.dart';

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
  LanguageService get _lang => Get.find<LanguageService>();

  IQuoteChartController([String? initialSymbol]) {
    final symService =
        Get.isRegistered<SymbolSelectionService>()
            ? Get.find<SymbolSelectionService>()
            : Get.put(SymbolSelectionService());

    if (initialSymbol != null && initialSymbol.isNotEmpty) {
      symService.setSymbol(initialSymbol);
    } else if (symService.currentSymbol.isEmpty) {
      final instCtrl =
          Get.isRegistered<InstrumentsController>()
              ? Get.find<InstrumentsController>()
              : null;
      if (instCtrl != null && instCtrl.instruments.isNotEmpty) {
        symService.setSymbol(instCtrl.instruments.first.symbol);
      } else {
        symService.setSymbol('EURUSD');
      }
    }
  }

  RxString get symbolRx =>
      Get.isRegistered<SymbolSelectionService>()
          ? Get.find<SymbolSelectionService>().lastSymbolRx
          : Get.put(SymbolSelectionService()).lastSymbolRx;

  String get symbol => symbolRx.value;
  set symbol(String value) {
    if (symbolRx.value != value) {
      if (Get.isRegistered<SymbolSelectionService>()) {
        Get.find<SymbolSelectionService>().setSymbol(value);
      }
      _notifyPersistentWebview(value);
    }
  }

  void forceSwitchSymbol(String newSymbol) {
    if (symbolRx.value != newSymbol) {
      if (Get.isRegistered<SymbolSelectionService>()) {
        Get.find<SymbolSelectionService>().setSymbol(newSymbol);
      }
    } else {
      // Force refresh if it's the same symbol but websocket is stuck
      _hydrateInitial();
      _bindLive();
    }
    _notifyPersistentWebview(newSymbol);
  }

  /// Always called after [symbolRx] is updated so the persistent offstage
  /// webview is told the new symbol.
  /// Called from both the [symbol] setter AND [forceSwitchSymbol] so the
  /// persistent webview stays in sync regardless of how the symbol changed.
  Future<void> _notifyPersistentWebview(String sym) async {
    // Disabled to align with crmapp's clean single-instance WebView design.
  }

  // ── header state ────────────────────────────────────────────────────────
  final currentPrice = Rxn<double>();
  final priceChange = Rxn<double>();
  final priceChangePct = Rxn<double>();
  final lastBid = Rxn<double>();
  final lastAsk = Rxn<double>();
  /// Live spread (in points) as delivered by the price websocket
  /// (`InstrumentPrice.spreadDiff`). 0 when unknown.
  final lastSpread = 0.0.obs;
  /// Last volume the user placed an order with (used by one-click trading).
  final lastVolume = 0.01.obs;
  // Renamed from `digits` to avoid shadowing GetxController.digits.
  final priceDigits = 2.obs;
  final period = '1M'.obs; // Default period
  final isLoading = false.obs;

  // ── candlestick data ───────────────────────────────────────────────────
  final chartData = <CandleData>[].obs;
  final isChartLoading = false.obs;
  final isLoadingOlder = false.obs;
  final resolution =
      60.obs; // Resolution in minutes (default 60M for 12 hours period)
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
    String? _prevSymbol;
    ever<String>(symbolRx, (String next) {
      if (_prevSymbol == next) return;
      _prevSymbol = next;
      _notifyPersistentWebview(next);
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
    if (sym.isNotEmpty) {
      _instruments.syncMarketWatchV2AfterFavoriteChange(
        sym,
        isFavoriteNow: true,
      );
    }
    // Live tick stream — keeps header + chart markers + Buy/Sell pills live.
    _livePriceWorker = ever<InstrumentPrice>(
      _instruments.priceRx(sym),
      _applyQuote,
    );
  }

  void _applyQuote(InstrumentPrice? quote) {
    if (quote == null) return;
    // print("📈 [IQuoteChartController] _applyQuote for $symbol: bid=${quote.bid}, ask=${quote.ask}");
    // InstrumentPrice has bid/ask/digits but no `last` field — derive a
    // mid-price for the header so the big number and MA labels stay live.
    final mid =
        quote.bid == 0 && quote.ask == 0 ? null : (quote.bid + quote.ask) / 2;
    currentPrice.value = mid;
    priceDigits.value = quote.digits;
    lastBid.value = quote.bid;
    lastAsk.value = quote.ask;
    lastSpread.value = quote.spreadDiff;

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
      final int alignedMinutes =
          (minutesSinceEpoch ~/ resolution.value) * resolution.value;
      final alignedTime = DateTime.fromMillisecondsSinceEpoch(
        alignedMinutes * 60 * 1000,
      );

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

  /// Intentionally a no-op. Historical bars are rendered by the persistent
  /// WebView (TradingView widget), which fetches its own
  /// data server-side. The previous /api/market/history REST call fired on
  /// every symbol switch and was redundant + slow. Call sites in onInit,
  /// the symbol-change listener, and changePeriod are kept untouched.
  Future<void> fetchHistoryData() async {}

  // ── load older history on pan-to-start ────────────────────────────────
  /// Intentionally a no-op — see [fetchHistoryData] for rationale. The
  /// TradingView WebView handles older history loading on its own.
  Future<void> loadOlderHistory() async {}

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
  Future<({bool ok, String message, OrderType orderType})> submitOrder({
    required String side,
    required String orderKind,
    required double volume,
    required String price,
    String? stopLimitPrice,
    String? takeProfit,
    String? stopLoss,
    // Pre-formatted lot string that preserves the user's actual decimal
    // precision (e.g. "0.001"). When null we fall back to 2-decimal format.
    String? formattedVolume,
  }) async {
    final acct = activeAccount;
    if (acct == null) {
      return (
        ok: false,
        message: _lang.tr('iquote_no_mt5_account'),
        orderType: _orderType(side, orderKind),
      );
    }
    if (volume <= 0) {
      return (
        ok: false,
        message: _lang.tr('iquote_volume_gt_zero'),
        orderType: _orderType(side, orderKind),
      );
    }

    final kind = orderKind.toLowerCase();
    final orderType = _orderType(side, kind);
    final isStopLimit = kind == 'stop_limit';

    // For stop-limit orders: `price` is the Trigger Price and
    // `stopLimitPrice` is the Limit Price. Both are required.
    if (isStopLimit) {
      if (price.isEmpty ||
          double.tryParse(price) == null ||
          double.parse(price) <= 0) {
        return (
          ok: false,
          message: _lang.tr('iquote_valid_trigger'),
          orderType: orderType,
        );
      }
      if (stopLimitPrice == null ||
          stopLimitPrice.isEmpty ||
          double.tryParse(stopLimitPrice) == null ||
          double.parse(stopLimitPrice) <= 0) {
        return (
          ok: false,
          message: _lang.tr('iquote_valid_limit'),
          orderType: orderType,
        );
      }
    } else if (orderType.requiresPrice &&
        (price.isEmpty ||
            double.tryParse(price) == null ||
            double.parse(price) <= 0)) {
      return (
        ok: false,
        message: _lang.tr('iquote_valid_limit'),
        orderType: orderType,
      );
    }

    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();
      if (token == null || token.isEmpty) {
        return (
          ok: false,
          message: _lang.tr('iquote_auth_token_missing'),
          orderType: orderType,
        );
      }

      final ok = await _trading.placeTradeOrder(
        symbol: symbol,
        volume: (formattedVolume != null && formattedVolume.isNotEmpty)
            ? formattedVolume
            : volume.toStringAsFixed(2),
        orderType: orderType,
        price: orderType.requiresPrice ? price : '',
        stopLimitPrice: isStopLimit ? stopLimitPrice : null,
        takeProfit:
            (takeProfit != null && takeProfit.isNotEmpty) ? takeProfit : null,
        stopLoss: (stopLoss != null && stopLoss.isNotEmpty) ? stopLoss : null,
        mt5Account: acct.metaAccountNumber,
      );

      if (ok) {
        lastVolume.value = volume;
        final cleanSymbol = symbol.split('.').first.toUpperCase();
        final typeName = orderType.requiresPrice
            ? orderType.displayName
            : (orderType.isBuy
                ? _lang.tr('general_buy')
                : _lang.tr('general_sell'));

        final titleStr = orderType.requiresPrice
            ? _lang.tr('iquote_chart_pending_order_placed')
            : _lang.tr('iquote_chart_market_order_placed');
        final messageStr = '$cleanSymbol $typeName ${volume.toStringAsFixed(2)}';

        CustomToastService.showSuccess(
          message: messageStr,
          title: titleStr,
        );
        // Refresh positions + pending orders so the bottom-bar counters
        // update immediately.
        await _trading.refreshTradeHistory();
        _refreshCounts();
        return (ok: true, message: _lang.tr('iquote_order_placed'), orderType: orderType);
      }

      final errorMsg =
          _trading.errorMessage.isEmpty
              ? _lang.tr('iquote_chart_failed_to_place_order')
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
    if (kind == 'limit') {
      return isBuy ? OrderType.buyLimit : OrderType.sellLimit;
    } else if (kind == 'stop') {
      return isBuy ? OrderType.buyStop : OrderType.sellStop;
    } else if (kind == 'stop_limit') {
      return isBuy ? OrderType.buyStopLimit : OrderType.sellStopLimit;
    } else {
      return isBuy ? OrderType.buyMarket : OrderType.sellMarket;
    }
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
