// ============================================================
// CelestialChartScreen — TRADYN-style full chart implementation
// Based on ChartScreen.jsx & flutter/chart_screen.dart reference
//
// Features:
//   • TradingView charting_library via WebView (full datafeed bridge)
//   • Live bid/ask horizontal lines drawn on chart
//   • Open position lines (from TradingController)
//   • Pending order lines (from TradingController)
//   • Buy/Sell quick-trade panel
//   • Symbol + timeframe picker in Flutter toolbar
//   • Live price header (bid/ask/H/L) via InstrumentsController
//   • Dark/light theme sync
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/chart_inapp_webview.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';

import 'package:crm_app/brands/celestial/celestial_theme.dart';
import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/tenax_chart_webview.dart';

// ── Resolution map ─────────────────────────────────────────────────────────
const _tfMap = {
  '1m': '1',
  '5m': '5',
  '15m': '15',
  '30m': '30',
  '1h': '60',
  '4h': '240',
  '1d': 'D',
  '1w': 'W',
};

// ═════════════════════════════════════════════════════════════════════════════
// Widget
// ═════════════════════════════════════════════════════════════════════════════

class CelestialChartScreen extends StatefulWidget {
  const CelestialChartScreen({super.key});

  @override
  State<CelestialChartScreen> createState() => _CelestialChartScreenState();
}

class _CelestialChartScreenState extends State<CelestialChartScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  // ── Controllers ────────────────────────────────────────────────────────
  ChartSocketController get _chart => Get.find<ChartSocketController>();
  InstrumentsController get _inst => Get.find<InstrumentsController>();

  LanguageService get languageService => Get.find<LanguageService>();
  TradingController get _trade => Get.find<TradingController>();

  // ── UI state ───────────────────────────────────────────────────────────
  String _tf = '1h';
  double _lot = 0.01;
  bool _tradeOpen = false;

  // ── Tick subscription ──────────────────────────────────────────────────
  StreamSubscription<Map<String, dynamic>>? _tickSub;

  // ─────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────

  String _rawSymbol() {
    if (Get.isRegistered<SymbolSelectionService>()) {
      final s = Get.find<SymbolSelectionService>().currentSymbol;
      if (s.isNotEmpty) return s;
    }
    if (_chart.currentSymbol.value.isNotEmpty) {
      return _chart.currentSymbol.value;
    }
    if (Get.isRegistered<InstrumentsController>()) {
      final inst = Get.find<InstrumentsController>();
      if (inst.instruments.isNotEmpty) {
        return inst.instruments.first.symbol;
      }
    }
    return 'XAUUSD';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initial = _rawSymbol();
    if (initial.isNotEmpty) {
      _chart.changeSymbol(initial);
    }
    _chart.startWebSocket();

    // Subscribe to live tick stream → push bar updates into WebView
    _tickSub = _chart.priceStream.listen(_onTick);

    // Position/order lines are re-rendered from _CelChartArea via its own key
    ever(_trade.marketPositionsRx, (_) => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickSub?.cancel();
    _chart.stopWebSocket();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Lifecycle Overrides
  // ─────────────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_chart.isConnected.value) {
        _chart.handleAppRestart();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Live tick → update price header (bid/ask lines not available in
  // TradingView Widget mode — those require the charting_library datafeed)
  // ─────────────────────────────────────────────────────────────────────

  void _onTick(Map<String, dynamic> tick) {
    // Price header updates automatically via InstrumentsController Obx.
    // No JS push needed for TradingView Widget — it fetches its own data.
  }

  // ─────────────────────────────────────────────────────────────────────
  // Position / Order lines
  // ─────────────────────────────────────────────────────────────────────

  void _renderPositionLines() {
    final sym = _chart.currentSymbol.value;
    final lines =
        _trade.marketPositions
            .where((p) => _matchSymbol(p.symbol, sym))
            .map(
              (p) => {
                'price': double.tryParse(p.openPrice) ?? 0.0,
                'text': 'P&L: ${p.profitLoss.toStringAsFixed(2)}',
                'quantity': '${p.action}: ${p.volume}',
                'color': p.profitLoss >= 0 ? '#22C55E' : '#EF4444',
              },
            )
            .toList();
    _callJS('window.__renderPositionLines(${jsonEncode(lines)});');
  }

  void _renderOrderLines() {
    final sym = _chart.currentSymbol.value;
    final lines =
        _trade.pendingPositions
            .where((o) => _matchSymbol(o.symbol, sym))
            .map(
              (o) => {
                'price': double.tryParse(o.openPrice) ?? 0.0,
                'quantity': '${o.action}: ${o.volume}',
              },
            )
            .toList();
    _callJS('window.__renderOrderLines(${jsonEncode(lines)});');
  }

  // ─────────────────────────────────────────────────────────────────────
  // Place order (Buy / Sell by market)
  // ─────────────────────────────────────────────────────────────────────

  void _placeOrder(String side) {
    // Get primary/active MT5 account
    final accountCtrl = Get.isRegistered<AccountController>()
        ? Get.find<AccountController>()
        : null;
    final mt5Account = accountCtrl?.activeMT5Account?.metaAccountNumber;

    if (mt5Account == null || mt5Account.isEmpty) {
      CustomToastService.showError(
        title: TranslationUtils.tr('general_error'),
        message: TranslationUtils.tr('vantage_chart_layout_no_active_trading_account'),
      );
      return;
    }

    final sym =
        _chart.currentSymbol.value.isEmpty
            ? 'EURUSD'
            : _chart.currentSymbol.value;
    final type = side == 'sell' ? OrderType.sellMarket : OrderType.buyMarket;

    HapticFeedback.mediumImpact();

    // Success/error feedback is shown by the app's unified top popup inside
    // placeTradeOrder — no local spinner or bottom toast here.
    _trade.placeTradeOrder(
      symbol: sym,
      volume: _lot.toStringAsFixed(2),
      orderType: type,
      mt5Account: mt5Account,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _callJS(String js) async {
    // JS is sent via _CelChartArea's key — no-op here (timeframe changes
    // go through _CelChartArea which owns the WebView key).
    debugPrint('[Chart] JS call skipped — webview owned by _CelChartArea: $js');
  }

  String _stripSuffix(String sym) =>
      sym.contains('.') ? sym.substring(0, sym.lastIndexOf('.')) : sym;

  bool _matchSymbol(String a, String b) =>
      a == b || _stripSuffix(a) == _stripSuffix(b);

  // ─────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: CelTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            _toolbar(context),
            // _priceHeader(context),
            if (_tradeOpen) _tradePanel(context),
            Expanded(child: _chartArea(context)),
          ],
        ),
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────
  Widget _toolbar(BuildContext c) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Row(
        children: [
          // Symbol picker
          Obx(() {
            final sym =
                _chart.currentSymbol.value.isEmpty
                    ? 'EURUSD'
                    : _chart.currentSymbol.value;
            return GestureDetector(
              onTap: () => _pickSymbol(c),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sym,
                    style: AppTextStyles.bodyText.copyWith(
                      color: CelTheme.mainText(c),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16.sp,
                    color: CelTheme.subText(c),
                  ),
                ],
              ),
            );
          }),
          SizedBox(width: 10.w),
          // Timeframe picker
          GestureDetector(
            onTap: () => _pickTimeframe(c),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: CelTheme.softBg(c),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                _tf,
                style: AppTextStyles.bodyText.copyWith(
                  color: CelTheme.mainText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Trade toggle button
          GestureDetector(
            onTap: () => setState(() => _tradeOpen = !_tradeOpen),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: CelTheme.buy(context),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                Get.find<LanguageService>().tr('celestial_chart_trade'),
                style: AppTextStyles.bodyText.copyWith(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
    );
  }

  // ── Trade panel — plain inline row, no card/elevation/overlay ────────
  Widget _tradePanel(BuildContext c) {
    return Obx(() {
      final sym =
          _chart.currentSymbol.value.isEmpty
              ? 'EURUSD'
              : _chart.currentSymbol.value;
      final price = _inst.priceRx(sym).value;
      final dig = price.digits > 0 ? price.digits : 2;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Row(
          children: [
            Expanded(
              child: _tradeBtn(
                label: Get.find<LanguageService>().tr('celestial_chart_sell'),
                sub: price.bid.toStringAsFixed(dig),
                color: CelTheme.sell(c),
                onTap: () => _placeOrder('sell'),
              ),
            ),
            SizedBox(width: 6.w),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: CelTheme.subText(c).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    price.spreadDiff.toInt().toString(),
                    style: AppTextStyles.bodyText.copyWith(
                      color: CelTheme.subText(c),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 2.h),
                _lotStepper(c),
              ],
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: _tradeBtn(
                label: Get.find<LanguageService>().tr('celestial_chart_buy'),
                sub: price.ask.toStringAsFixed(dig),
                color: CelTheme.buy(c),
                onTap: () => _placeOrder('buy'),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Chart area — just the WebView, no overlay ─────────────────────────
  Widget _chartArea(BuildContext c) {
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(4.w, 0, 4.w, 4.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: CelTheme.divider(c), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        // ── _CelChartArea seeds the WebView symbol ONCE and updates it via
        // its own GlobalKey — never causes ChartInAppWebView to rebuild.
        // Candle chart: never mirror the price/time axes.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _CelChartArea(isDark: AppColors.chartTheme == 'dark'),
        ),
      ),
    );
  }

  Widget _tradeBtn({
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Thicker buttons — matches image 2
        padding: EdgeInsets.symmetric(vertical: 2.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8.r),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              sub,
              style: AppTextStyles.bodyText.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lot stepper: − | tappable number field | +
  Widget _lotStepper(BuildContext c) {
    return Container(
      decoration: BoxDecoration(
        color: CelTheme.softBg(c),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: CelTheme.divider(c)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus
          GestureDetector(
            onTap:
                () => setState(
                  () => _lot = (_lot - 0.01).clamp(0.01, double.infinity),
                ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
              child: Text(
                '−',
                style: AppTextStyles.bodyText.copyWith(
                  color: CelTheme.mainText(c),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // Tappable number — opens keyboard
          GestureDetector(
            onTap: () => _editLot(c),
            child: Container(
              width: 52.w,
              alignment: Alignment.center,
              child: Text(
                _lot.toStringAsFixed(2),
                style: AppTextStyles.bodyText.copyWith(
                  color: CelTheme.mainText(c),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          // Plus
          GestureDetector(
            onTap: () => setState(() => _lot += 0.01),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
              child: Text(
                '+',
                style: AppTextStyles.bodyText.copyWith(
                  color: CelTheme.mainText(c),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Opens a dialog with a number keyboard to type the lot directly
  void _editLot(BuildContext c) {
    final ctrl = TextEditingController(text: _lot.toStringAsFixed(2));
    showDialog(
      context: c,
      builder:
          (_) => AlertDialog(
            backgroundColor: CelTheme.card(c),
            title: Text(
              Get.find<LanguageService>().tr('celestial_chart_enter_lot_size'),
              style: AppTextStyles.cardTitle.copyWith(
                color: CelTheme.mainText(c),
                fontSize: 15.sp,
              ),
            ),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppTextStyles.heading.copyWith(
                color: CelTheme.mainText(c),
                fontSize: 18.sp,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: CelTheme.softBg(c),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  Get.find<LanguageService>().tr('celestial_chart_cancel'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: CelTheme.subText(c),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final v = double.tryParse(ctrl.text);
                  if (v != null && v >= 0.01) setState(() => _lot = v);
                  Navigator.pop(c);
                },
                child: Text(
                  'OK',
                  style: AppTextStyles.bodyText.copyWith(
                    color: CelTheme.buy(c),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────
  void _pickTimeframe(BuildContext c) {
    showModalBottomSheet(
      context: c,
      backgroundColor: CelTheme.card(c),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder:
          (_) => SafeArea(
            child: Wrap(
              children:
                  _tfMap.entries.map((e) {
                    final active = e.key == _tf;
                    return ListTile(
                      title: Text(
                        e.key,
                        style: AppTextStyles.bodyText.copyWith(
                          color:
                              active ? CelTheme.buy(c) : CelTheme.mainText(c),
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      trailing:
                          active
                              ? Icon(Icons.check, color: CelTheme.buy(c))
                              : null,
                      onTap: () {
                        setState(() => _tf = e.key);
                        {
                          // index.html uses TradingView Widget — recreate with new interval
                          _callJS('''
                    if(chartWidget) {
                      try { chartWidget.remove(); } catch(e) {}
                      chartWidget = null;
                    }
                    (function(){
                      var sym = typeof selectedSymbol !== "undefined" ? selectedSymbol : "EURUSD";
                      var theme = window.__tv_theme || "light";
                      var toolbarBg = theme === "dark" ? "#0F172A" : "#f1f3f6";
                      document.getElementById("chartContainer").innerHTML = "";
                      chartWidget = new TradingView.widget({
                        container_id: "chartContainer",
                        symbol: sym,
                        interval: "${e.value}",
                        timezone: "Etc/UTC",
                        theme: theme,
                        style: "1",
                        locale: "en",
                        toolbar_bg: toolbarBg,
                        enable_publishing: false,
                        allow_symbol_change: false,
                        details: false,
                        autosize: true,
                        hide_volume: true,
                      });
                    })();
                  ''');
                        }
                        Navigator.pop(c);
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  void _pickSymbol(BuildContext c) {
    showModalBottomSheet(
      context: c,
      backgroundColor: CelTheme.card(c),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder:
          (_) => _SymbolPicker(
            instruments: _inst,
            onSelected: (sym) {
              // setSymbol notifies _CelChartArea via its lastSymbolRx listener
              if (Get.isRegistered<SymbolSelectionService>()) {
                Get.find<SymbolSelectionService>().setSymbol(sym);
              }
              _chart.changeSymbol(sym);
              Navigator.pop(c);
            },
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CelChartArea
//
// and subsequently pushes symbol changes via key.currentState?.updateSymbol().
// ChartInAppWebView is NEVER torn down and rebuilt on symbol change — that
// eliminates the "Obx triggers didUpdateWidget → XAUUSD reload" race.
//
// Fix for app-kill + watchlist-tap: if storage hasn't loaded yet (_initialSymbol
// is a fallback), we listen for the first real symbol from SymbolSelectionService
// and force-reload the WebView with the correct URL.
//
// Fix for device-lock (15min) + watchlist-tap: WebView may be blank after OS
// suspension. _onSymbolChanged now force-reloads with the new URL when JS fails.
// ─────────────────────────────────────────────────────────────────────────────
class _CelChartArea extends StatefulWidget {
  final bool isDark;
  const _CelChartArea({required this.isDark});
  @override
  State<_CelChartArea> createState() => _CelChartAreaState();
}

class _CelChartAreaState extends State<_CelChartArea>
    with WidgetsBindingObserver {
  final _webViewKey = GlobalKey<ChartInAppWebViewState>();
  final _tenaxKey = GlobalKey<TenaxChartWebViewState>();

  // The symbol the WebView was built with. May be updated on first storage read.
  late String _initialSymbol;
  // Whether the initial symbol was a fallback (storage not ready yet).
  bool _wasSymbolFallback = false;

  late SymbolSelectionService _symService;
  StreamSubscription<String>? _symSub;

  static String _strip(String s) {
    if (s.isNotEmpty) return s;
    if (Get.isRegistered<InstrumentsController>()) {
      final inst = Get.find<InstrumentsController>();
      if (inst.instruments.isNotEmpty) {
        return inst.instruments.first.symbol;
      }
    }
    return 'XAUUSD';
  }

  String _buildUrl() =>
      '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?theme=${widget.isDark ? 'dark' : 'light'}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _symService =
        Get.isRegistered<SymbolSelectionService>()
            ? Get.find<SymbolSelectionService>()
            : Get.put(SymbolSelectionService());

    final stored = _strip(_symService.currentSymbol);
    if (stored.isNotEmpty) {
      _initialSymbol = stored;
      _wasSymbolFallback = false;
    } else {
      // Storage not loaded yet — use fallback and mark it so we reload
      // when the real symbol arrives via the stream.
      _initialSymbol = _strip('');
      _wasSymbolFallback = true;
    }

    _symSub = _symService.lastSymbolRx.listen(_onSymbolChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _symSub?.cancel();
    super.dispose();
  }

  String _effectiveSymbol(String sym) {
    String? acc;
    if (Get.isRegistered<AccountController>()) {
      acc =
          Get.find<AccountController>().activeMT5Account?.metaAccountNumber
              .toString();
    }
    return SymbolDetailsCacheService.resolveDatafeedSymbolSync(sym, acc);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final sym = _strip(_symService.currentSymbol);
      if (sym.isEmpty) return;
      if (FlavorConfig.instance.useNewChart) {
        _tenaxKey.currentState?.updateSymbol(sym);
      } else {
        final effective = _effectiveSymbol(sym);
        // Try JS symbol update. If it fails (e.g. WebView is blank after OS
        // suspension), fall back to a full URL reload with the correct symbol.
        _webViewKey.currentState?.updateSymbol(effective).then((success) {
          if (!success && mounted) {
            _webViewKey.currentState?.loadUrlWithSymbol(effective);
          }
        });
      }
    }
  }

  void _onSymbolChanged(String newSym) {
    final clean = _strip(newSym);
    if (!mounted || clean.isEmpty) return;

    // Update socket
    if (Get.isRegistered<ChartSocketController>()) {
      Get.find<ChartSocketController>().changeSymbol(newSym);
    }

    if (FlavorConfig.instance.useNewChart) {
      _tenaxKey.currentState?.updateSymbol(clean);
      return;
    }

    final effective = _effectiveSymbol(clean);

    // For InAppWebView:
    // If this was the first real symbol arriving after a fallback initial load
    // (app-kill scenario), force a full URL reload with the correct symbol.
    if (_wasSymbolFallback) {
      _wasSymbolFallback = false;
      _initialSymbol = effective;
      _webViewKey.currentState?.loadUrlWithSymbol(effective);
      return;
    }

    // Otherwise try JS symbol switch first; fall back to URL reload if it fails
    // (device lock / WebView blank after OS suspension).
    _webViewKey.currentState?.updateSymbol(effective).then((success) {
      if (!success && mounted) {
        _webViewKey.currentState?.loadUrlWithSymbol(effective);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (FlavorConfig.instance.useNewChart) {
      return TenaxChartWebView(
        key: _tenaxKey,
        symbol: _initialSymbol,
        isDark: widget.isDark,
      );
    }
    final url = _buildUrl();
    final effective = _effectiveSymbol(_initialSymbol);
    return ChartInAppWebView(key: _webViewKey, symbol: effective, url: url);
  }
}

// ─── Symbol picker sheet ──────────────────────────────────────────────────────
class _SymbolPicker extends StatefulWidget {
  final InstrumentsController instruments;
  final ValueChanged<String> onSelected;
  const _SymbolPicker({required this.instruments, required this.onSelected});
  @override
  State<_SymbolPicker> createState() => _SymbolPickerState();
}

class _SymbolPickerState extends State<_SymbolPicker> {
  String _query = '';

  @override
  Widget build(BuildContext c) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(14.w, 12.h, 14.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Get.find<LanguageService>().tr('celestial_chart_select_symbol'),
            style: AppTextStyles.bodyText.copyWith(
              color: CelTheme.headerText(c),
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            decoration: InputDecoration(
              hintText: Get.find<LanguageService>().tr(
                'celestial_chart_search_hint',
              ),
              prefixIcon: Icon(Icons.search, size: 18),
              filled: true,
              fillColor: CelTheme.softBg(c),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: 6.h,
                horizontal: 8.w,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: AppTextStyles.bodyText.copyWith(
              color: CelTheme.mainText(c),
              fontSize: 13.sp,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
          SizedBox(height: 4.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 0.55.sh),
            child: Obx(() {
              final items =
                  widget.instruments.instruments
                      .where(
                        (i) =>
                            _query.isEmpty ||
                            i.symbol.toLowerCase().contains(_query),
                      )
                      .toList();
              return ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onSelected(item.symbol),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 6.h,
                      ),
                      child: Text(
                        item.symbol,
                        style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.mainText(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
