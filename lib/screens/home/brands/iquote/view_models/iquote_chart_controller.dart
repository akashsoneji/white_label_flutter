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

class IQuoteChartController extends GetxController {
  IQuoteChartController(this.symbol);

  final String symbol;

  // ── header state ────────────────────────────────────────────────────────
  final currentPrice = Rxn<double>();
  final priceChange = Rxn<double>();
  final priceChangePct = Rxn<double>();
  final lastBid = Rxn<double>();
  final lastAsk = Rxn<double>();
  // Renamed from `digits` to avoid shadowing GetxController.digits.
  final priceDigits = 2.obs;
  final period = '1M'.obs;
  final isLoading = false.obs;

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

  @override
  void onInit() {
    super.onInit();
    _hydrateInitial();
    _bindLive();
  }

  void _hydrateInitial() {
    final quote = _instruments.priceRx(symbol.toUpperCase()).value;
    _applyQuote(quote);
    _refreshCounts();
  }

  void _bindLive() {
    final sym = symbol.toUpperCase();
    // Live tick stream — keeps header + chart markers + Buy/Sell pills live.
    ever<InstrumentPrice>(_instruments.priceRx(sym), _applyQuote);
    // Open positions drive the Team badge.
    ever<List<TradePosition>>(
      _trading.marketPositionsRx,
      (_) => _refreshCounts(),
    );
    // pendingPositions is a plain List, so we also poll its length inside
    // _refreshCounts() — the WS may not expose an RxList for it.
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
    _pushScaleMarkers(quote.bid, quote.ask, mid);
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

  // ── account helpers (typed) ────────────────────────────────────────────
  MT5Account? get activeAccount => _account.activeMT5AccountRx.value;
  bool get isDemoAccount =>
      activeAccount == null || activeAccount!.isDemoAccount;

  // ── period selector ────────────────────────────────────────────────────
  static const List<String> kPeriods = ['1M', '5M', '15M', '30M', 'More'];
  void changePeriod(String p) {
    if (kPeriods.contains(p)) period.value = p;
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