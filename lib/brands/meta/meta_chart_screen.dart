// ============================================================
// MetaChartScreen — TRADYN-style full chart implementation
// Based on ChartScreen.jsx & flutter/chart_screen.dart reference
//
// Features:
//   • TradingView charting_library via WebView (full datafeed bridge)
//   • Live bid/ask horizontal lines drawn on chart
//   • Open position lines (from TradingController)
//   • Pending order lines (from TradingController)
//   • Buy/Sell quick-trade panel (toggled by the "Trade" pill in the toolbar)
//   • Symbol + timeframe picker in Flutter toolbar
//   • Live price header (bid/ask/H/L) via InstrumentsController
//   • Dark/light theme sync (Meta blue + Meta dark palette)
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'meta_theme.dart';

// ── Resolution map ─────────────────────────────────────────────────────────
const _tfMap = {
  '1m': '1', '5m': '5', '15m': '15', '30m': '30',
  '1h': '60', '4h': '240', '1d': 'D', '1w': 'W',
};


// ═════════════════════════════════════════════════════════════════════════════
// Widget
// ═════════════════════════════════════════════════════════════════════════════

class MetaChartScreen extends StatefulWidget {
  const MetaChartScreen({super.key});

  @override
  State<MetaChartScreen> createState() => _MetaChartScreenState();
}

class _MetaChartScreenState extends State<MetaChartScreen> {
  // ── Controllers ────────────────────────────────────────────────────────
  ChartSocketController get _chart => Get.find<ChartSocketController>();
  InstrumentsController get _inst  => Get.find<InstrumentsController>();
  TradingController     get _trade => Get.find<TradingController>();
  LanguageService       get languageService => Get.find<LanguageService>();

  // ── WebView ────────────────────────────────────────────────────────────
  late final WebViewController _wvc;
  bool _widgetReady = false;

  // ── UI state ───────────────────────────────────────────────────────────
  String _tf        = '1h';
  double _lot       = 0.01;
  bool   _tradeOpen = false;



  // ── Tick subscription ──────────────────────────────────────────────────
  StreamSubscription<Map<String, dynamic>>? _tickSub;
  Worker? _symbolWorker;

  // ────────────────────────────────────────────────�────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initWebView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chart.currentSymbol.value.isEmpty) {
        _chart.currentSymbol.value = 'XAUUSD';
      }
      _chart.startWebSocket();

      // Subscribe to live tick stream → push bar updates into WebView
      _tickSub = _chart.priceStream.listen(_onTick);

      // Re-render position/order lines when data changes
      ever(_trade.marketPositionsRx, (_) { if (_widgetReady) _renderPositionLines(); });

      // Sync symbol change → tell TradingView (index.html exposes updateSymbol())
      _symbolWorker = ever(_chart.currentSymbol, (String sym) {
        if (sym.isNotEmpty && _widgetReady) {
          _callJS('updateSymbol("${_stripSuffix(sym)}");');
        }
      });
    });
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _symbolWorker?.dispose();
    _chart.stopWebSocket();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // WebView init
  // ─────────────────────────────────────────────────────────────────────

  void _initWebView() {
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _onPageReady(),
      ))
      ..loadFlutterAsset('assets/chart/index.html');
  }

  Future<void> _onPageReady() async {
    // index.html uses TradingView Widget (free CDN tv.js) — no charting_library needed.
    // It reads window.__tv_theme and calls updateSymbol(sym) to init the chart.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sym    = _stripSuffix(
        _chart.currentSymbol.value.isEmpty ? 'XAUUSD' : _chart.currentSymbol.value);

    await _callJS('window.__tv_theme = "${isDark ? 'dark' : 'light'}";');
    // Give tv.js a moment to load, then create the chart for the current symbol
    await _callJS('setTimeout(function(){ updateSymbol("$sym"); }, 300);');

    setState(() => _widgetReady = true);
    _renderPositionLines();
    _renderOrderLines();
  }

  // ─────────────────────────────────────────────────────────────────────
  // JS Bridge — not used by index.html (TradingView Widget, no datafeed)
  // Kept for future charting_library migration.
  // ─────────────────────────────────────────────────────────────────────

  void _onBridgeMessage(JavaScriptMessage msg) {
    // index.html (TradingView Widget) does not send FlutterBridge messages.
    // This handler is a no-op but kept so the channel is registered.
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
    final sym   = _chart.currentSymbol.value;
    final lines = _trade.marketPositions
        .where((p) => _matchSymbol(p.symbol, sym))
        .map((p) => {
              'price':    double.tryParse(p.openPrice) ?? 0.0,
              'text':     'P&L: ${p.profitLoss.toStringAsFixed(2)}',
              'quantity': '${p.action}: ${p.volume}',
              'color':    p.profitLoss >= 0 ? '#22C55E' : '#EF4444',
            })
        .toList();
    _callJS('window.__renderPositionLines(${jsonEncode(lines)});');
  }

  void _renderOrderLines() {
    final sym   = _chart.currentSymbol.value;
    final lines = _trade.pendingPositions
        .where((o) => _matchSymbol(o.symbol, sym))
        .map((o) => {
              'price':    double.tryParse(o.openPrice) ?? 0.0,
              'quantity': '${o.action}: ${o.volume}',
            })
        .toList();
    _callJS('window.__renderOrderLines(${jsonEncode(lines)});');
  }

  // ─────────────────────────────────────────────────────────────────────
  // Place order (Buy / Sell by market)
  // ─────────────────────────────────────────────────────────────────────

  void _placeOrder(String side) {
    // Get primary/active MT5 account
    final accountCtrl = Get.find<AccountController>();
    final mt5Account  = accountCtrl.activeMT5Account?.metaAccountNumber;

    if (mt5Account == null || mt5Account.isEmpty) {
      return;
    }

    final sym  = _chart.currentSymbol.value.isEmpty ? 'XAUUSD' : _chart.currentSymbol.value;
    final type = side == 'sell' ? OrderType.sellMarket : OrderType.buyMarket;

    HapticFeedback.mediumImpact();

    // Success/error feedback is shown by the app's unified top popup inside
    // placeTradeOrder — no local spinner or bottom toast here.
    _trade.placeTradeOrder(
      symbol:     sym,
      volume:     _lot.toStringAsFixed(2),
      orderType:  type,
      mt5Account: mt5Account,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _callJS(String js) async {
    try { await _wvc.runJavaScript(js); }
    catch (e) { debugPrint('[Chart] JS: $e'); }
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
    return Scaffold(
      backgroundColor: MetaTheme.bg(context),
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
            final sym = _chart.currentSymbol.value.isEmpty
                ? 'XAUUSD' : _chart.currentSymbol.value;
            return GestureDetector(
              onTap: () => _pickSymbol(c),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(sym, style: TextStyle(
                    color: MetaTheme.mainText(c), fontSize: 15.sp,
                    fontWeight: FontWeight.w800)),
                SizedBox(width: 2.w),
                Icon(Icons.keyboard_arrow_down,
                    size: 16.sp, color: MetaTheme.subText(c)),
              ]),
            );
          }),
          SizedBox(width: 10.w),
          // Timeframe picker
          GestureDetector(
            onTap: () => _pickTimeframe(c),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: MetaTheme.softBg(c),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(_tf, style: TextStyle(
                  color: MetaTheme.mainText(c), fontSize: 12.sp,
                  fontWeight: FontWeight.w700)),
            ),
          ),
          const Spacer(),
          // Trade toggle button — clicking shows/hides the inline Buy/Sell
          // panel with live bid/ask + lot stepper (matches the screenshot).
          GestureDetector(
            onTap: () => setState(() => _tradeOpen = !_tradeOpen),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color:   MetaTheme.buyBlue ,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text('Trade', style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
    );
  }

  // ── Price header ──────────────────────────────────────────────────────
  Widget _priceHeader(BuildContext c) {
    return Obx(() {
      final sym    = _chart.currentSymbol.value.isEmpty ? 'XAUUSD' : _chart.currentSymbol.value;
      final price  = _inst.priceRx(sym).value;
      final digits = price.digits > 0 ? price.digits : 2;
      final mid    = (price.dayHigh + price.dayLow) / 2;
      final change = mid == 0 ? 0.0 : price.ask - mid;
      final pct    = mid == 0 ? 0.0 : (change / mid) * 100;
      final col    = change >= 0 ? MetaTheme.tpGreen : MetaTheme.sellRed;

      return Padding(
        padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sym, style: TextStyle(
                  color: MetaTheme.subText(c), fontSize: 11.sp,
                  fontWeight: FontWeight.w600)),
              SizedBox(height: 1.h),
              Text(price.ask.toStringAsFixed(digits), style: TextStyle(
                  color: MetaTheme.mainText(c), fontSize: 20.sp,
                  fontWeight: FontWeight.w800)),
            ]),
            SizedBox(width: 8.w),
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(digits)} (${pct.toStringAsFixed(2)}%)',
                style: TextStyle(color: col, fontSize: 12.sp,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('H: ${price.dayHigh.toStringAsFixed(digits)}',
                  style: TextStyle(color: MetaTheme.subText(c), fontSize: 10.sp)),
              Text('L: ${price.dayLow.toStringAsFixed(digits)}',
                  style: TextStyle(color: MetaTheme.subText(c), fontSize: 10.sp)),
            ]),
          ],
        ),
      );
    });
  }

  // ── Trade panel — plain inline row, no card/elevation/overlay ────────
  Widget _tradePanel(BuildContext c) {
    return Obx(() {
      final sym   = _chart.currentSymbol.value.isEmpty ? 'XAUUSD' : _chart.currentSymbol.value;
      final price = _inst.priceRx(sym).value;
      final dig   = price.digits > 0 ? price.digits : 2;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Row(children: [
          Expanded(child: _tradeBtn(
            label: Get.find<LanguageService>().tr('meta_chart_sell'),
            sub:   price.bid.toStringAsFixed(dig),
            color: MetaTheme.sell(c),
            onTap: () => _placeOrder('sell'),
          )),
          SizedBox(width: 6.w),
          _lotStepper(c),
          SizedBox(width: 6.w),
          Expanded(child: _tradeBtn(
            label: Get.find<LanguageService>().tr('meta_chart_buy'),
            sub:   price.ask.toStringAsFixed(dig),
            color: MetaTheme.buy(c),
            onTap: () => _placeOrder('buy'),
          )),
        ]),
      );
    });
  }

  // ── Chart area — just the WebView, no overlay ─────────────────────────
  Widget _chartArea(BuildContext c) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 4.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: MetaTheme.divider(c), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: WebViewWidget(controller: _wvc),
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
            color: color, borderRadius: BorderRadius.circular(8.r)),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
              color: Colors.white, fontSize: 15.sp,
              fontWeight: FontWeight.w800)),
          SizedBox(height: 2.h),
          Text(sub, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.sp, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // Lot stepper: − | tappable number field | +
  Widget _lotStepper(BuildContext c) {
    return Container(
      decoration: BoxDecoration(
        color: MetaTheme.softBg(c),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: MetaTheme.divider(c)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Minus
        GestureDetector(
          onTap: () => setState(
              () => _lot = (_lot - 0.01).clamp(0.01, double.infinity)),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
            child: Text('−', style: TextStyle(
                color: MetaTheme.mainText(c), fontSize: 18.sp,
                fontWeight: FontWeight.w700)),
          ),
        ),
        // Tappable number — opens keyboard
        GestureDetector(
          onTap: () => _editLot(c),
          child: Container(
            width: 52.w,
            alignment: Alignment.center,
            child: Text(_lot.toStringAsFixed(2), style: TextStyle(
                color: MetaTheme.mainText(c), fontSize: 14.sp,
                fontWeight: FontWeight.w800)),
          ),
        ),
        // Plus
        GestureDetector(
          onTap: () => setState(() => _lot += 0.01),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
            child: Text('+', style: TextStyle(
                color: MetaTheme.mainText(c), fontSize: 18.sp,
                fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // Opens a dialog with a number keyboard to type the lot directly
  void _editLot(BuildContext c) {
    final ctrl = TextEditingController(text: _lot.toStringAsFixed(2));
    showDialog(
      context: c,
      builder: (_) => AlertDialog(
        backgroundColor: MetaTheme.card(c),
        title: Text(Get.find<LanguageService>().tr('meta_chart_enter_lot_size'),
            style: TextStyle(color: MetaTheme.mainText(c), fontSize: 15.sp,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: MetaTheme.mainText(c), fontSize: 18.sp,
              fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            filled: true,
            fillColor: MetaTheme.softBg(c),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(Get.find<LanguageService>().tr('meta_chart_cancel'),
                style: TextStyle(color: MetaTheme.subText(c))),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v >= 0.01) setState(() => _lot = v);
              Navigator.pop(c);
            },
            child: Text('OK',
                style: TextStyle(color: MetaTheme.buy(c),
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────
  void _pickTimeframe(BuildContext c) {
    showModalBottomSheet(
      context: c,
      backgroundColor: MetaTheme.card(c),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: _tfMap.entries.map((e) {
            final active = e.key == _tf;
            return ListTile(
              title: Text(e.key, style: TextStyle(
                  color: active ? MetaTheme.buy(c) : MetaTheme.mainText(c),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
              trailing: active ? Icon(Icons.check, color: MetaTheme.buy(c)) : null,
              onTap: () {
                setState(() => _tf = e.key);
                if (_widgetReady) {
                  // index.html uses TradingView Widget — recreate with new interval
                  _callJS('''
                    if(chartWidget) {
                      try { chartWidget.remove(); } catch(e) {}
                      chartWidget = null;
                    }
                    (function(){
                      var sym = typeof selectedSymbol !== "undefined" ? selectedSymbol : "XAUUSD";
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
      backgroundColor: MetaTheme.card(c),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (_) => _SymbolPicker(
        instruments: _inst,
        onSelected: (sym) {
          _chart.currentSymbol.value = sym;
          // Also tell chart directly in case ever() hasn't fired yet
          if (_widgetReady) {
            _callJS('updateSymbol("${_stripSuffix(sym)}");');
          }
          Navigator.pop(c);
        },
      ),
    );
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
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Get.find<LanguageService>().tr('meta_chart_select_symbol'),
              style: TextStyle(
                  color: MetaTheme.headerText(c),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 8.h),
          TextField(
            decoration: InputDecoration(
              hintText: Get.find<LanguageService>().tr('meta_chart_search_hint'),
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: MetaTheme.softBg(c),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(color: MetaTheme.mainText(c), fontSize: 13.sp),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
          SizedBox(height: 4.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 0.55.sh),
            child: Obx(() {
              final items = widget.instruments.instruments
                  .where((i) => _query.isEmpty ||
                      i.symbol.toLowerCase().contains(_query))
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
                          horizontal: 4.w, vertical: 6.h),
                      child: Text(item.symbol,
                          style: TextStyle(
                              color: MetaTheme.mainText(c),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500)),
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