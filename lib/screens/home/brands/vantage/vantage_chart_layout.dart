// ============================================================
// VantageChartLayout — Vantage TRADYN-style chart screen
//
// Used by all Vantage-child brands (pipze, baazex, gtxprime, …).
// Mirrors the TRADYN/JSX reference design (pixel-perfect):
//   • Slim header   : ←  SYMBOL ⌄  ●(tick)         [slider pill] top-right
//   • Top-right     : brand-primary icon (light mode) / white icon (dark mode)
//   • Chart area    : TradingView WebView (free widget)
//   • Bottom dock   : Quantity stepper + [pending-pill icon] + bell
//                     ─────────────────────────────────────────
//                     SELL  bid  •  spread  •  ask  BUY
//   • BUY button    : FlavorConfig.primaryColor (purple for Pipze)
//   • SELL button   : AppColors.error (red gradient)
//   • Spread chip   : pip number in the middle
//
// Symbol pill (← SYMBOL ⌄) opens a **favourites dropdown** listing only
// the symbols in FavoritesStorageService. Long-press or the settings
// icon opens the full search screen.
//
// The "pending order" icon between quantity `+` and bell opens the
// Vantage PendingOrderScreen pre-loaded with the current symbol.
//
// Reuses the existing ChartInAppWebView (from lib/widgets/) so the
// datafeed bridge and TradingView JS shim loaded by the legacy
// chart screen are reused unchanged.
//
// Wired into lib/screens/home/chart_screen.dart via
// `if (FlavorConfig.usesVantageUi()) return VantageChartLayout(...)`.
// ============================================================

import 'dart:async';

import 'package:crm_app/widgets/app_svg_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/screens/home/pending_order_screen.dart';
import 'package:crm_app/screens/home/search_instruments_screen.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:crm_app/widgets/advanced_chart_inapp_webview.dart';
import 'package:crm_app/widgets/chart_inapp_webview.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/price_alert_dialog.dart';

class VantageChartLayout extends StatefulWidget {
  /// Called when the user taps a symbol in the favourites dropdown.
  /// Optional — when null, the layout selects the symbol itself.
  final ValueChanged<String>? onSymbolSelected;

  /// Called when the user wants to leave the chart tab for another
  /// bottom-nav destination. Null when shown standalone.
  final ValueChanged<int>? onNavigateToTab;

  const VantageChartLayout({
    super.key,
    this.onSymbolSelected,
    this.onNavigateToTab,
  });

  @override
  State<VantageChartLayout> createState() => _VantageChartLayoutState();
}

class _VantageChartLayoutState extends State<VantageChartLayout> {
  double _volume = 0.01;

  // Bumped on every price tick AND when the active symbol changes so
  // the bottom-dock Obx rebuilds bid/ask/spread for the new symbol.
  final RxInt _tick = 0.obs;
  StreamSubscription<dynamic>? _priceSub;

  // ── Controller shortcuts ─────────────────────────────────────────────
  TradingController get _trade => Get.find<TradingController>();
  ChartSocketController get _socket => Get.find<ChartSocketController>();
  AccountController get _account => Get.find<AccountController>();

  @override
  void initState() {
    super.initState();
    // Push the active symbol into the socket so its bid/ask maps start
    // streaming ticks for the selected instrument.
    final initial = _rawSymbol();
    if (initial.isNotEmpty) {
      _socket.changeSymbol(initial);
    }
    // Live tick → bump _tick so SELL/BUY sub-labels refresh.
    _priceSub = _socket.priceStream.listen((_) {
      if (mounted) _tick.value++;
    });
  }

  @override
  void dispose() {
    _priceSub?.cancel();
    super.dispose();
  }

  // ── Symbol / price helpers ──────────────────────────────────────────
  String _rawSymbol() {
    final s = Get.find<SymbolSelectionService>().currentSymbol;
    if (s.isEmpty) return 'XAUUSD';
    return s;
  }

  String _displaySymbol() {
    final s = _rawSymbol();
    return s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;
  }

  // ── Order handling ────────────────────────────────────────────────
  Future<void> _placeOrder(String side) async {
    final bid = _socket.getBidPrice();
    final ask = _socket.getAskPrice();
    if (bid == null || ask == null) {
      CustomToastService.showWarning(message: 'Waiting for live price...');
      return;
    }
    final active = _account.activeMT5Account;
    if (active == null) {
      CustomToastService.showWarning(message: 'No active trading account.');
      return;
    }

    try {
      final ok = await _trade.placeTradeOrder(
        orderType: side.toLowerCase() == 'buy'
            ? OrderType.buyMarket
            : OrderType.sellMarket,
        symbol: _rawSymbol(),
        volume: _volume.toStringAsFixed(2),
        price: (side.toLowerCase() == 'buy' ? ask : bid).toString(),
      );

      if (!mounted) return;
      CustomToastService.showInfo(
        message: ok
            ? '${side.toUpperCase()} $_volume ${_rawSymbol()} placed.'
            : 'Order failed. Please try again.',
      );
    } catch (e) {
      if (!mounted) return;
      CustomToastService.showError(message: 'Trade error: $e');
    }
  }

  void _bumpVolume(double delta) {
    setState(() {
      _volume = (_volume + delta).clamp(0.01, 100.0);
      _volume = double.parse(_volume.toStringAsFixed(2));
    });
  }

  // ─�� Symbol dropdown (all instruments, scrollable) ──────────────────────
  Future<void> _openFavouritesDropdown() async {
    if (!mounted) return;

    // Dark-mode-aware colors for the bottom sheet.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;
    final sheetBg = isDark ? const Color(0xFF1A1A20) : Colors.white;
    final rowBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F5);
    final dividerColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F5);
    final handleColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E5);
    final muted = isDark ? Colors.white60 : const Color(0xFF6B6B7A);
    final fg = isDark ? Colors.white : const Color(0xFF111114);

    // Active symbol so we can highlight it in the list.
    final active = _displaySymbol();

    // Pull ALL instruments from the live instruments stream.
    final instruments =
        Get.find<InstrumentsController>().allInstruments.toList();

    if (!mounted) return;

    if (instruments.isEmpty) {
      // Nothing loaded yet — fall back to the full search screen so the
      // user can still pick a symbol (and trigger instruments load).
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SearchInstrumentsScreen(),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    // Sort alphabetically by display symbol for predictable ordering.
    final sorted = [...instruments]
      ..sort((a, b) => _stripSuffix(a.symbol)
          .toUpperCase()
          .compareTo(_stripSuffix(b.symbol).toUpperCase()));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grab handle
                Container(
                  margin: EdgeInsets.only(top: 8.h, bottom: 4.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                // Scrollable list of ALL symbols only
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: dividerColor),
                    itemBuilder: (_, i) {
                      final raw = sorted[i].symbol;
                      final sym = _stripSuffix(raw);
                      final isActive = sym == active;
                      return InkWell(
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          Get.find<SymbolSelectionService>().setSymbol(raw);
                          widget.onSymbolSelected?.call(raw);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 12.h),
                          child: Row(
                            children: [
                              Container(
                                width: 28.w,
                                height: 28.h,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? primary.withValues(alpha: 0.12)
                                      : rowBg,
                                  borderRadius: BorderRadius.circular(7.r),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.show_chart,
                                  size: 16.sp,
                                  color: isActive ? primary : muted,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  sym,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive ? primary : fg,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Icon(Icons.check,
                                    size: 18.sp, color: primary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _stripSuffix(String symbol) {
    return symbol.contains('.')
        ? symbol.substring(0, symbol.lastIndexOf('.'))
        : symbol;
  }

  void _openPendingOrderScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PendingOrderScreen(symbol: _rawSymbol()),
      ),
    );
  }

  // ── Price alert bottom sheet (reuses the legacy PriceAlertDialog) ──────
  void _openPriceAlertSheet() {
    final symbol = _rawSymbol();
    final marketPrice = _socket.getMarketPrice() ?? 0.0;
    if (marketPrice == 0.0) {
      CustomToastService.showWarning(message: 'Waiting for live price...');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (_) => PriceAlertDialog(
        symbol: symbol,
        currentPrice: marketPrice,
      ),
    );
  }

  // ── Layout ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // AppColors.primary automatically returns darkPrimaryColor when dark mode
    // is on, so the BUY button + top-right pill + qty bar stay on-brand.
    final primary = AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              symbol: _displaySymbol(),
              primary: primary,
              isDark: isDark,
              onBack: () => Navigator.of(context).maybePop(),
              onSymbolTap: _openFavouritesDropdown,
              // Top-right button jumps to the Vantage "Trade" tab
              // (Vantage 4-tab nav: Prices(0), Markets(1)=Trade, Accounts(2), Settings(3)).
              onSettingsTap: () {
                if (widget.onNavigateToTab != null) {
                  Navigator.of(context).maybePop();
                  widget.onNavigateToTab!(1);
                } else {
                  CustomToastService.showInfo(
                    message: 'Trade tab is not available in this context.',
                  );
                }
              },
            ),
            // hairline divider exactly as in the TRADYN reference
            Container(height: 1, color: const Color(0x14000000)),
            Expanded(child: _ChartArea(isDark: isDark)),
            Container(height: 1, color: const Color(0x14000000)),
            _BottomDock(
              primary: primary,
              isDark: isDark,
              volume: _volume,
              tick: _tick,
              onMinus: () => _bumpVolume(-0.01),
              onPlus: () => _bumpVolume(0.01),
              onPending: _openPendingOrderScreen,
              onSell: () => _placeOrder('sell'),
              onBuy: () => _placeOrder('buy'),
              onBell: _openPriceAlertSheet,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Header  :  ←  SYMBOL ⌄  ●  +  brand-primary (light) / white (dark)
//              top-right pill icon
// ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String symbol;
  final Color primary;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSymbolTap;
  final VoidCallback onSettingsTap;

  const _Header({
    required this.symbol,
    required this.primary,
    required this.isDark,
    required this.onBack,
    required this.onSymbolTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111114);
    final muted = isDark ? Colors.white60 : const Color(0xFF6B6B7A);
    // Top-right icon tint rule:
    //   • Light mode → brand's configured primary color (whatever the
    //     flavor sets as primaryColor — NOT darkPrimaryColor).
    //   • Dark mode  → pure white.
    // Note: deliberately NOT `AppColors.primary` here, because that
    // getter auto-switches to darkPrimaryColor in dark mode, which is
    // exactly what the user wants to avoid for this button.
    final iconColor =
        isDark ? Colors.white : FlavorConfig.instance.primaryColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      child: Row(
        children: [
          // Back arrow
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, size: 22.sp, color: fg),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: 6.w),
          // Symbol pill
          Expanded(
            child: InkWell(
              onTap: onSymbolTap,
              borderRadius: BorderRadius.circular(8.r),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Slightly bolder font for the symbol, like the reference
                  Text(
                    symbol,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(Icons.keyboard_arrow_down, size: 22.sp, color: muted),

                ],
              ),
            ),
          ),
          // Top-right settings/sound icon
          InkResponse(
            onTap: onSettingsTap,
            radius: 24,
            child: Container(
              width: 36.w,
              height: 36.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: AppSvgIcon(
                assetPath: 'assets/svg/bottom_navigation/candle_bold.svg',
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Chart area  :  TradingView WebView (free widget if enabled)
// ────────────────────────────────────────────────────────────────────
class _ChartArea extends StatelessWidget {
  final bool isDark;
  const _ChartArea({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final useNew = FlavorConfig.instance.useNewChart;
    final sym = Get.find<SymbolSelectionService>().currentSymbol;
    final raw = sym.contains('.')
        ? sym.substring(0, sym.lastIndexOf('.'))
        : (sym.isEmpty ? 'XAUUSD' : sym);

    if (useNew) {
      return AdvancedChartInAppWebView(
        key: ValueKey('vantage_adv_$raw'),
        symbol: raw,
        theme: isDark ? 'dark' : 'light',
      );
    }
    // Match the URL pattern used in chart_screen.dart so the same
    // server-side mobile-chart loader picks up the symbol on first paint.
    final url =
        '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?symbol=$raw&theme=${isDark ? 'dark' : 'light'}';
    return ChartInAppWebView(
      key: ValueKey('vantage_chart_$raw'),
      symbol: raw,
      url: url,
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Bottom dock  :  Quantity stepper + SELL • spread • BUY
// ────────────────────────────────────────────────────────────────────
class _BottomDock extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final double volume;
  final RxInt tick;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onPending;
  final VoidCallback onSell;
  final VoidCallback onBuy;
  final VoidCallback onBell;

  const _BottomDock({
    required this.primary,
    required this.isDark,
    required this.volume,
    required this.tick,
    required this.onMinus,
    required this.onPlus,
    required this.onPending,
    required this.onSell,
    required this.onBuy,
    required this.onBell,
  });

  /// Strip trailing zeros (and a dangling `.`) so 20.00 -> "20",
  /// 20.50 -> "20.5", 1.08000 -> "1.08". Used to display
  /// bid/ask/spreadDiff as the server sent them, without a forced
  /// fixed-decimal count.
  static String _trimTrailingZeros(double value) {
    var s = value.toString();
    if (!s.contains('.')) return s;
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F12) : Colors.white,
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 12,
              offset: Offset(0, -2)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 14.h),
      child: Obx(() {
        // ──────────────────────────────────────────�───────────────
        // ignore: unused_local_variable
        final _ = tick.value;
        final socket = Get.find<ChartSocketController>();
        // ignore: invalid_use_of_protected_member
        final priceMap = socket.realTimePrice.value;

        // Direct display - no digit-rounding, no pip-conversion.
        // The server already sends bid/ask at the symbol's natural
        // precision (5 digits for EURUSD, 2 for XAUUSD/JPY pairs,
        // 3 for JPY crosses). bid.toString() preserves those
        // decimals exactly.
        // spreadDiff comes from the WS pre-converted to *points*
        // (the controller's // spread_points comment). Display
        // it as-is - no extra /pip math.
        final bid = priceMap['bid'] is num
            ? (priceMap['bid'] as num).toDouble()
            : null;
        final ask = priceMap['ask'] is num
            ? (priceMap['ask'] as num).toDouble()
            : null;
        final spreadDiff = priceMap['spreadDiff'] is num
            ? (priceMap['spreadDiff'] as num).toDouble()
            : null;

        final bidStr = (bid != null && bid != 0.0)
            ? _trimTrailingZeros(bid)
            : '—';
        final askStr = (ask != null && ask != 0.0)
            ? _trimTrailingZeros(ask)
            : '—';
        final spreadStr = (spreadDiff != null && spreadDiff > 0)
            ? _trimTrailingZeros(spreadDiff)
            : '—';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuantityBar(
              primary: primary,
              isDark: isDark,
              volume: volume,
              onMinus: onMinus,
              onPlus: onPlus,
              onPending: onPending,
              onBell: onBell,
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: _SideButton(
                    label: 'SELL',
                    sub: bidStr,
                    color: AppColors.error,
                    onTap: onSell,
                  ),
                ),
                Container(
                  width: 56.w,
                  height: 56.h,
                  margin: EdgeInsets.symmetric(horizontal: 6.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A20)
                        : const Color(0xFFF6F4F8),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    spreadStr,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  child: _SideButton(
                    label: 'BUY',
                    sub: askStr,
                    color: primary,
                    onTap: onBuy,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Quantity bar  :  [−]  Quantity (lots) 0.01  [+]  [📋]  [🔔]
// ────────────────────────────────────────────────────────────────────
class _QuantityBar extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final double volume;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onPending;
  final VoidCallback onBell;

  const _QuantityBar({
    required this.primary,
    required this.isDark,
    required this.volume,
    required this.onMinus,
    required this.onPlus,
    required this.onPending,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? Colors.white60 : const Color(0xFF6B6B7A);
    final fg = isDark ? Colors.white : const Color(0xFF111114);

    return Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A20) : const Color(0xFFF6F4F8),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          _QtyBtn(icon: Icons.remove, color: primary, onTap: onMinus),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Quantity (lots)',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: muted,
                    ),
                  ),
                  Text(
                    volume.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _QtyBtn(icon: Icons.add, color: primary, onTap: onPlus),
          // Pending order (pen + note) icon — opens the pending screen
          _QtyBtn(
            icon: Icons.edit_note,
            color: primary,
            onTap: onPending,
          ),
          _QtyBtn(
            icon: Icons.notifications_none,
            color: primary,
            onTap: onBell,
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QtyBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 44.w,
        height: 44.h,
        alignment: Alignment.center,
        child: Icon(icon, size: 22.sp, color: color),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  const _SideButton({
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16.r),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.whiteColor,
                  letterSpacing: 0.5,
                )),
            SizedBox(height: 2.h),
            Text(sub,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.whiteColor,
                )),
          ],
        ),
      ),
    );
  }
}