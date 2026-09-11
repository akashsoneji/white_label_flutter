// IQuote chart screen — designed to mirror the trading-app reference.
//
//   ┌─────────────────────────────────────────────────┐
//   │  ←  [DEMO ▾]                  balance  (i)      │  ← header (AccountHeaderWidget)
//   │  🇺🇸 XAU/USD ▾              🔔   🧮   ⊞   ⋮     │  ← symbol row
//   │  Period  1M  5M  15M  30M  More   📅  ⚙  ⛶    │  ← toolbar
//   │  MA5:xx   MA10:xx   MA30:xx                    │  ← MA strip
//   │  ─── candle area (placeholder for now) ───      │
//   │  🕯          [👥][📄]   [Buy][Sell]            │  ← bottom bar (icon-only)
//   └─────────────────────────────────────────────────┘
//
// The chart candles, indicators and fullscreen controls are *placeholders*;
// the rest of the page (header, MA strip text, chart scale, Buy/Sell pills,
// Team + Position counters) is fully live and wires through
// IQuoteChartController → InstrumentsController (live bid/ask) +
// AccountController + TradingController + ChartController.placeTradeOrder
// (the same placeOrder path that pending_order_screen already uses).
//
// Theming: all chart-specific colors flow through [ChartPalette], which
// exposes a light/dark pair and is observed via ThemeService.isDarkModeObs.
// Flipping the global theme (via the existing showThemeBottomSheet) rebuilds
// every sub-widget without dropping live data.
// dart:ui provides FontFeature.tabularFigures() (used on the tile prices and
// change% chip so digits stay column-aligned even when the value changes).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/theme_service.dart';
import 'package:crm_app/widgets/account_header_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/screens/home/brands/iquote/view_models/iquote_chart_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/widgets/chart_inapp_webview.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/one_click_trading_service.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/services/market_watch_v2_service.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/widgets/dashboard_bottom_sheet.dart';
import 'package:crm_app/widgets/tenax_chart_webview.dart';

// ── palette ─────────────────────────────────────────────────────────────────
// MA-line + bullish/bearish colors stay the same across themes — they're
// functional indicator colors (like TradingView's), not surface colors.
const _kBullColor = Color(0xFF33b970);
const _kBearColor = Color(0xFFE65366);

class _ChartPalette {
  const _ChartPalette({
    required this.bg,
    required this.chartAreaBg,
    required this.divider,
    required this.axisText,
    required this.sheetBg,
    required this.sheetFieldBg,
    required this.sheetFieldBorder,
    required this.emptyHintIcon,
    required this.inactiveTabBg,
    required this.inactiveTabBorder,
    required this.inactiveTabText,
    required this.tabAccent,
  });

  final Color bg;
  final Color chartAreaBg;
  final Color divider;
  final Color axisText;
  final Color sheetBg;
  final Color sheetFieldBg;
  final Color sheetFieldBorder;
  final Color emptyHintIcon;
  final Color inactiveTabBg;
  final Color inactiveTabBorder;
  final Color inactiveTabText;
  final Color tabAccent;

  static _ChartPalette of(BuildContext context) {
    final isDark = _isDark(context);
    return isDark ? _dark() : _light();
  }

  static _ChartPalette _dark() => const _ChartPalette(
    bg: Color(0xFF0E1726),
    chartAreaBg: Color(0xFF142033),
    divider: Color(0x22FFFFFF),
    axisText: Color(0xFFAAAACC),
    sheetBg: Color(0xFF111A2E),
    sheetFieldBg: Color(0xFF333333),
    sheetFieldBorder: Color(0x33FFFFFF),
    emptyHintIcon: Color(0xFFAAAACC),
    inactiveTabBg: Color(0xFF333333),
    inactiveTabBorder: Color(0x33FFFFFF),
    inactiveTabText: Color(0xFFAAAACC),
    tabAccent: Color(0xFFF97316),
  );

  static _ChartPalette _light() => const _ChartPalette(
    bg: Color(0xFFF6F7FB),
    chartAreaBg: Color(0xFFFFFFFF),
    divider: Color(0x22000000),
    axisText: Color(0xFF6B7280),
    sheetBg: Color(0xFFFFFFFF),
    sheetFieldBg: Color(0xFFF1F3F8),
    sheetFieldBorder: Color(0xFFE3E6EE),
    emptyHintIcon: Color(0xFF9CA3AF),
    inactiveTabBg: Color(0xFFF1F3F8),
    inactiveTabBorder: Color(0xFFE3E6EE),
    inactiveTabText: Color(0xFF6B7280),
    tabAccent: Color(0xFFF97316),
  );
}

bool _isDark(BuildContext context) {
  if (Get.isRegistered<ThemeService>()) {
    return Get.find<ThemeService>().isDarkResolved;
  }
  return Theme.of(context).brightness == Brightness.dark;
}

class IQuoteChartScreen extends StatefulWidget {
  const IQuoteChartScreen({super.key, this.symbol});

  final String? symbol;

  @override
  State<IQuoteChartScreen> createState() => _IQuoteChartScreenState();
}

class _IQuoteChartScreenState extends State<IQuoteChartScreen> {
  final GlobalKey<ChartInAppWebViewState> _webViewKey =
      GlobalKey<ChartInAppWebViewState>();
  late final IQuoteChartController _ctrl;

  @override
  void initState() {
    super.initState();
    // Ensure the controller is registered and its symbol matches the requested one.
    _ctrl = Get.put(IQuoteChartController(widget.symbol));
    if (widget.symbol != null && widget.symbol!.isNotEmpty) {
      _ctrl.forceSwitchSymbol(widget.symbol!);
    }
  }

  @override
  void didUpdateWidget(covariant IQuoteChartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.symbol != null && widget.symbol != oldWidget.symbol) {
      _ctrl.forceSwitchSymbol(widget.symbol!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<IQuoteChartController>(
      init: _ctrl,
      builder: (ctrl) {
        final palette = _ChartPalette.of(context);
        return Scaffold(
          backgroundColor: palette.bg,
          body: SafeArea(
            bottom: false,
            child: Obx(() {
              // URL is FIXED — never embed ctrl.symbol in it.
              // Only the `symbol` prop changes, keeping all redraws as JS-only updates.
              final stableUrl =
                  '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?theme=${AppColors.chartTheme}';
              return Column(
                children: [
                  _Header(ctrl: ctrl, palette: palette),
                  Expanded(
                    child: FlavorConfig.instance.useNewChart
                        ? TenaxChartWebView(
                            symbol: ctrl.symbol,
                            isDark: AppColors.chartTheme == 'dark',
                          )
                        : ChartInAppWebView(
                            key: _webViewKey,
                            symbol: ctrl.symbol,
                            url: stableUrl,
                          ),
                  ),
                  _BottomBar(ctrl: ctrl, palette: palette),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

// ── header (back + account pill + balance + info) ──────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.ctrl, required this.palette});
  final IQuoteChartController ctrl;
  final _ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: palette.bg,
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 12.w, 4.h),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            AppBackButton(onPressed: () => Get.back<void>())
          else
            SizedBox(width: 4.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showFavoritesBottomSheet(context, ctrl),
            child: Row(
              children: [
                _FlagIcon(symbol: ctrl.symbol.replaceAll('.c', '')),
                SizedBox(width: 6.w),
                Obx(
                  () => Text(
                    ctrl.symbol.replaceAll('.c', '').toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18.sp,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => showDashboardBottomSheet(context),
            child: Obx(() {
              final accountCtrl = Get.find<AccountController>();
              final active = accountCtrl.activeMT5Account;
              final accNumber = active?.metaAccountNumber ?? '------';
              final rawType = (active?.accountType ?? 'REAL').toUpperCase();
              final isDemo = rawType == 'DEMO';
              final badgeLabel = isDemo ? 'DEMO' : 'LIVE';
              final isDark = AppColors.isDarkMode;

              double? profit;
              if (active != null && Get.isRegistered<DashboardController>()) {
                final dashCtrl = Get.find<DashboardController>();
                profit = dashCtrl.accountInfoMap[active.metaAccountNumber]?.profit;
              }

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF252C41)
                          : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white12
                            : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$accNumber',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDemo
                                ? Colors.orange.withValues(alpha: 0.18)
                                : Colors.green.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: isDemo ? Colors.orange : Colors.green,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (profit != null && profit != 0.0) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: (profit >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          '${profit >= 0 ? '+' : ''}${PrecisionHelper.formatPnL(profit)}',
                          style: TextStyle(
                            color: profit >= 0 ? Colors.green : Colors.red,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18.r,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.ctrl, required this.palette});
  final IQuoteChartController ctrl;
  final _ChartPalette palette;

  Future<void> _confirmCloseSymbolPositions(
    BuildContext context,
    TradingController tradingController,
    List<TradePosition> targets,
    String displaySymbol,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.card,
          insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Close $displaySymbol positions?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${targets.length} position(s) will be closed at market price.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44.h,
                        child: OutlinedButton(
                          onPressed:
                              () => Navigator.of(dialogContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: SizedBox(
                        height: 44.h,
                        child: ElevatedButton(
                          onPressed:
                              () => Navigator.of(dialogContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        final accountController = Get.find<AccountController>();
        final activeAccount = accountController.activeMT5Account;
        if (activeAccount == null) {
          CustomToastService.showError(
            title: Get.find<LanguageService>().tr('trading_error'),
            message: Get.find<LanguageService>().tr('chart_no_active_account'),
          );
          return;
        }
        for (final p in targets) {
          final positionId = int.tryParse(p.orderId) ?? 0;
          if (positionId == 0) continue;
          await tradingController.closePositionById(
            mt5Account: activeAccount.metaAccountNumber,
            positionId: positionId,
          );
        }
        CustomToastService.showSuccess(
          title: Get.find<LanguageService>().tr('common_success'),
          message: Get.find<LanguageService>().tr('iquote_positions_closed_success'),
        );
      } catch (e) {
        CustomToastService.showError(
          title: Get.find<LanguageService>().tr('trading_error'),
          message: '${Get.find<LanguageService>().tr('iquote_failed_close_positions')}: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: palette.sheetBg,
          border: Border(top: BorderSide(color: palette.divider)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Obx(() {
          final bid = ctrl.lastBid.value;
          final ask = ctrl.lastAsk.value;
          final d = ctrl.priceDigits.value;
          // print(
          //   "📊 [IQuoteChartScreen] _BottomBar rebuilding: bid=$bid, ask=$ask",
          // );

          final tradingController =
              Get.isRegistered<TradingController>()
                  ? Get.find<TradingController>()
                  : null;

          List<TradePosition> symbolPositions = [];
          double totalVolume = 0.0;
          double totalPL = 0.0;

          if (tradingController != null) {
            final symbolNorm = MarketWatchV2Service.normalizeSymbol(
              ctrl.symbol,
            );
            symbolPositions =
                tradingController.marketPositionsRx
                    .where(
                      (pos) =>
                          MarketWatchV2Service.normalizeSymbol(pos.symbol) ==
                          symbolNorm,
                    )
                    .toList();
            totalVolume = symbolPositions.fold(
              0.0,
              (sum, pos) => sum + pos.volume,
            );
            totalPL = symbolPositions.fold(
              0.0,
              (sum, pos) => sum + pos.profitLoss,
            );
          }

          final showWidget = symbolPositions.isNotEmpty;

          return Column(
            children: [
              if (showWidget) ...[
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: palette.sheetFieldBg,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: palette.sheetFieldBorder,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDERS',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: palette.axisText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${symbolPositions.length}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 24.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VOLUME,LOT',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: palette.axisText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  totalVolume.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'P/L',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: palette.axisText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${totalPL >= 0 ? '+' : ''}${totalPL.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        totalPL >= 0
                                            ? _kBullColor
                                            : _kBearColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap:
                          () => _confirmCloseSymbolPositions(
                            context,
                            tradingController!,
                            symbolPositions,
                            ctrl.symbol.replaceAll('.c', '').toUpperCase(),
                          ),
                      child: Container(
                        width: 44.h,
                        height: 44.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.sheetFieldBg,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: palette.sheetFieldBorder,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.cancel_outlined,
                          color: _kBearColor,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
              // Buy/Sell side-by-side with overlapping center spread badge —
              // same layout as the iQuote market row (Stack + Positioned).
              // A compact one-click toggle sits to the right.
              Row(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap:
                                    () => _handleOrderTap(context, side: 'buy'),
                                child: Container(
                                  height: 44.h,
                                  decoration: BoxDecoration(
                                    color: _kBullColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(6.r),
                                      bottomLeft: Radius.circular(6.r),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Buy',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      SizedBox(height: 1.h),
                                      Text(
                                        ask != null && ask > 0
                                            ? ask.toStringAsFixed(d)
                                            : '—',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 1.w),
                            Expanded(
                              child: GestureDetector(
                                onTap:
                                    () =>
                                        _handleOrderTap(context, side: 'sell'),
                                child: Container(
                                  height: 44.h,
                                  decoration: BoxDecoration(
                                    color: _kBearColor,
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(6.r),
                                      bottomRight: Radius.circular(6.r),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sell',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      SizedBox(height: 1.h),
                                      Text(
                                        bid != null && bid > 0
                                            ? bid.toStringAsFixed(d)
                                            : '—',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 3.h,
                          child: Obx(
                            () => _SpreadBadge(spread: ctrl.lastSpread.value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _PendingOrderButton(
                    onTap: () => _openNewOrderSheet(context, side: 'buy'),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Buy/Sell tap: if one-click trading is enabled, place a market order
  /// straight away using the last-used volume. Otherwise, fall back to the
  /// existing New Order bottom sheet.
  Future<void> _handleOrderTap(
    BuildContext context, {
    required String side,
  }) async {
    final oneClickOn =
        await OneClickTradingService.instance.isOneClickTradingEnabled();
    if (oneClickOn) {
      final vol = ctrl.lastVolume.value > 0 ? ctrl.lastVolume.value : 0.01;
      await ctrl.submitOrder(
        side: side,
        orderKind: 'market',
        volume: vol,
        price: '',
      );
      return;
    }
    if (!context.mounted) return;
    _openNewOrderSheet(context, side: side);
  }

  void _openNewOrderSheet(BuildContext context, {required String side}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.sheetBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder:
          (_) => _NewOrderSheet(
            ctrl: ctrl,
            side: side,
            pricePreview:
                side == 'buy'
                    ? (ctrl.lastAsk.value ?? 0)
                    : (ctrl.lastBid.value ?? 0),
          ),
    );
  }
}

/// Compact "Pending" order button shown to the right of the Buy/Sell pills.
/// Tapping it opens the standard New Order bottom sheet so the user can
/// place a limit/stop order (with TP/SL) instead of a one-click market order.
class _PendingOrderButton extends StatelessWidget {
  const _PendingOrderButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        Theme.of(context).iconTheme.color?.withOpacity(0.85) ??
        AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note_rounded, size: 22.sp, color: iconColor),
          SizedBox(height: 2.h),
          Text(
            'Pending',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dark spread badge shown between the Buy and Sell pills. Style
/// mirrors the badge on the iQuote market list rows.
class _SpreadBadge extends StatelessWidget {
  const _SpreadBadge({required this.spread});
  final double spread;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = spread > 0 ? spread.toStringAsFixed(0) : '0';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Icon-only badge (no "Team"/"Position" text), with a small red counter on
/// top-right when count > 0. Sized to match the candle button on the left.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.color,
    required this.icon,
    required this.label,
    required this.price,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String label;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.whiteColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    color: AppColors.whiteColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(width: 4.w),
            Icon(icon, size: 18.sp, color: AppColors.whiteColor),
          ],
        ),
      ),
    );
  }
}

// ── new-order sheet (Market / Limit + Volume + TP/SL + placeOrder API) ────
class _NewOrderSheet extends StatefulWidget {
  const _NewOrderSheet({
    required this.ctrl,
    required this.side,
    required this.pricePreview,
  });
  final IQuoteChartController ctrl;
  final String side;
  final double pricePreview;

  @override
  State<_NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends State<_NewOrderSheet> {
  static const _lots = [0.01, 0.10, 0.50, 1.00, 2.00, 5.00];

  late TextEditingController _volumeCtl;
  late TextEditingController _priceCtl;
  late TextEditingController _triggerCtl;
  late TextEditingController _tpCtl;
  late TextEditingController _slCtl;
  late FocusNode _tpFocusNode;
  late FocusNode _slFocusNode;
  // Last auto-computed TP/SL strings (formatted to `priceDigits` digits).
  // The user has gone "custom" only when the controller text differs from
  // this — so re-computing on every bid/ask tick is safe: if the user typed
  // something different we leave it; if they deleted back to our value (or
  // hit a ±-step that lands on it) we resume auto-updating.
  String? _lastAutoTp;
  String? _lastAutoSl;
  Worker? _askWorker;
  Worker? _bidWorker;
  int _tab = 0; // 0 market, 1 limit
  bool _tpSlEnabled = false;

  // ── pending-order order-type dropdown ───────────────────────────────
  // Side × kind × variant. The user picks one of six — never auto-derived
  // from price vs bid/ask (that was the old two-button SELL STOP / BUY
  // LIMIT auto-label behavior, replaced by Vantage-style explicit choice).
  // kind: 'limit' → limit price triggers the order
  //       'stop'  → stop price triggers the order
  //       'stop_limit' → stop price arms the order, then limit price fires it
  String _orderType = 'buy_limit';
  static const List<String> _pendingOrderTypes = [
    'buy_limit',
    'sell_limit',
    'buy_stop',
    'sell_stop',
    'buy_stop_limit',
    'sell_stop_limit',
  ];
  String _labelForOrderType(String t) {
    switch (t) {
      case 'buy_limit':
        return 'Buy Limit';
      case 'sell_limit':
        return 'Sell Limit';
      case 'buy_stop':
        return 'Buy Stop';
      case 'sell_stop':
        return 'Sell Stop';
      case 'buy_stop_limit':
        return 'Buy Stop Limit';
      case 'sell_stop_limit':
        return 'Sell Stop Limit';
      default:
        return t;
    }
  }

  /// Auto-fill the order price based on the chosen order-type:
  /// limit kinds seed from ask (buy) / bid (sell),
  /// stop kinds seed from bid (buy) / ask (sell),
  /// stop_limit kinds leave the price empty for user entry.
  void _onOrderTypeChanged(String newType) {
    setState(() {
      _orderType = newType;
      // Reset cached auto-values so the next tick writes a fresh TP/SL.
      _lastAutoTp = null;
      _lastAutoSl = null;
      final d = widget.ctrl.priceDigits.value;
      final ask = widget.ctrl.lastAsk.value ?? 0.0;
      final bid = widget.ctrl.lastBid.value ?? 0.0;
      double? seed;
      if (newType == 'buy_limit' || newType == 'sell_stop') {
        seed = (newType == 'buy_limit') ? ask : bid;
      } else if (newType == 'sell_limit' || newType == 'buy_stop') {
        seed = (newType == 'sell_limit') ? bid : ask;
      } else if (newType == 'buy_stop_limit' || newType == 'sell_stop_limit') {
        // Stop-limit needs two prices: Trigger (buy→ask / sell→bid) and Limit.
        // Seed both to the same market price so the user only nudges from there.
        seed = (newType == 'buy_stop_limit') ? ask : bid;
        if (seed > 0) {
          _triggerCtl.text = seed.toStringAsFixed(d);
        }
      }
      if (seed != null && seed > 0) {
        _priceCtl.text = seed.toStringAsFixed(d);
      }
      _updateTpSlFromMarketPrice();
    });
  }

  @override
  void initState() {
    super.initState();
    _volumeCtl = TextEditingController(text: '0.01');
    _priceCtl = TextEditingController(
      text:
          widget.pricePreview > 0
              ? widget.pricePreview.toStringAsFixed(
                widget.ctrl.priceDigits.value,
              )
              : '',
    );
    _triggerCtl = TextEditingController();
    _tpCtl = TextEditingController();
    _slCtl = TextEditingController();
    _tpFocusNode = FocusNode();
    _slFocusNode = FocusNode();

    // Custom-vs-auto detection is text-based (see _lastAutoTp/_lastAutoSl).
    // No focus listeners needed — the controller's text is the source of truth.

    _askWorker = ever(widget.ctrl.lastAsk, (_) => _updateTpSlFromMarketPrice());
    _bidWorker = ever(widget.ctrl.lastBid, (_) => _updateTpSlFromMarketPrice());
  }

  @override
  void dispose() {
    _askWorker?.dispose();
    _bidWorker?.dispose();
    _volumeCtl.dispose();
    _priceCtl.dispose();
    _triggerCtl.dispose();
    _tpCtl.dispose();
    _slCtl.dispose();
    _tpFocusNode.dispose();
    _slFocusNode.dispose();
    super.dispose();
  }

  void _updateTpSlFromMarketPrice() {
    if (!_tpSlEnabled) return;
    if (_tpFocusNode.hasFocus || _slFocusNode.hasFocus) return;

    final activePrice =
        widget.side == 'buy'
            ? (widget.ctrl.lastAsk.value ??
                widget.ctrl.lastBid.value ??
                0.0)
            : (widget.ctrl.lastBid.value ??
                widget.ctrl.lastAsk.value ??
                0.0);
    final digits = widget.ctrl.priceDigits.value;
    if (activePrice > 0) {
      final double entryPrice = (_tab == 1 && _price > 0) ? _price : activePrice;
      
      final double offset;
      if (digits <= 2 && entryPrice > 5000) {
        offset = 100.0;
      } else {
        double multiplier = 1.0;
        for (int i = 0; i < digits; i++) {
          multiplier *= 10.0;
        }
        final pipSize = 1.0 / multiplier;
        offset = 100.0 * pipSize;
      }

      final double tp;
      final double sl;
      if (widget.side == 'buy') {
        tp = entryPrice + offset;
        sl = entryPrice - offset;
      } else {
        tp = entryPrice - offset;
        sl = entryPrice + offset;
      }

      final tpStr = tp.toStringAsFixed(digits);
      final slStr = sl.toStringAsFixed(digits);
      // Only auto-overwrite when the field is either empty, or it currently
      // matches the last value we wrote. If the user typed something else,
      // the diff keeps us out of the way — and if they delete back to our
      // value (or a ±-step lands on it), we resume auto-updating on the next
      // tick. Also skip while a field is focused to avoid clobbering an
      // in-progress edit.
      if (!_tpFocusNode.hasFocus &&
          (_tpCtl.text.isEmpty || _tpCtl.text == _lastAutoTp)) {
        _tpCtl.text = tpStr;
      }
      if (!_slFocusNode.hasFocus &&
          (_slCtl.text.isEmpty || _slCtl.text == _lastAutoSl)) {
        _slCtl.text = slStr;
      }
      _lastAutoTp = tpStr;
      _lastAutoSl = slStr;
    }
  }

  double get _volume => double.tryParse(_volumeCtl.text.trim()) ?? 0.01;
  double get _price => double.tryParse(_priceCtl.text.trim()) ?? 0;
  double get _trigger => double.tryParse(_triggerCtl.text.trim()) ?? 0;
  bool get _isStopLimit =>
      _orderType == 'buy_stop_limit' || _orderType == 'sell_stop_limit';
  double get _margin {
    if (_price <= 0) return 0;
    const leverage = 300.0;
    return _price * _volume / leverage;
  }

  double get _fee => 18.0 * _volume;
  double get _total => _margin + _fee;

  @override
  Widget build(BuildContext context) {
    final side = widget.side;
    final color = side == 'buy' ? _kBullColor : _kBearColor;
    final d = widget.ctrl.priceDigits.value;
    final palette = _ChartPalette.of(context);
    final fieldText = AppColors.textPrimary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12.h,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: palette.axisText.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // Market / Limit tabs (Limit/Local hidden)
            Container(
              decoration: BoxDecoration(
                color: palette.inactiveTabBg,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: palette.inactiveTabBorder),
              ),
              child: Row(
                children: [
                  _TabButton(
                    label: Get.find<LanguageService>().tr('iquote_tab_market'),
                    active: _tab == 0,
                    palette: palette,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  _TabButton(
                    label: Get.find<LanguageService>().tr('iquote_tab_pending'),
                    active: _tab == 1,
                    palette: palette,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Volume(Lot)',
              style: TextStyle(color: fieldText, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              decoration: BoxDecoration(
                color: palette.sheetFieldBg,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        final currentVol =
                            double.tryParse(_volumeCtl.text) ?? 1.0;
                        final nextVol = (currentVol - 0.01).clamp(0.01, 99.0);
                        _volumeCtl.text = nextVol.toStringAsFixed(2);
                      });
                    },
                    icon: Icon(Icons.remove, color: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _volumeCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        final currentVol =
                            double.tryParse(_volumeCtl.text) ?? 1.0;
                        final nextVol = (currentVol + 0.01).clamp(0.01, 99.0);
                        _volumeCtl.text = nextVol.toStringAsFixed(2);
                      });
                    },
                    icon: Icon(Icons.add, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children:
                  _lots
                      .map(
                        (lot) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: GestureDetector(
                              onTap:
                                  () => setState(
                                    () =>
                                        _volumeCtl.text = lot.toStringAsFixed(
                                          2,
                                        ),
                                  ),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                decoration: BoxDecoration(
                                  color:
                                      (lot == _volume)
                                          ? AppColors.primary
                                          : palette.sheetFieldBg,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  lot.toStringAsFixed(2),
                                  style: TextStyle(
                                    color:
                                        (lot == _volume)
                                            ? AppColors.whiteColor
                                            : AppColors.textPrimary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            SizedBox(height: 14.h),
            if (_tab == 1) ...[
              // ── Order-type picker (taps open a bottom-sheet list) ──
              InkWell(
                onTap: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: palette.sheetBg,
                    isScrollControlled: true,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16.r)),
                    ),
                    builder: (_) => _OrderTypePickerSheet(
                      options: _pendingOrderTypes,
                      selected: _orderType,
                      labelFor: _labelForOrderType,
                      palette: palette,
                    ),
                  );
                  if (picked != null && picked != _orderType) {
                    _onOrderTypeChanged(picked);
                  }
                },
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: palette.sheetFieldBg,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: palette.sheetFieldBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt,
                          size: 18.sp, color: AppColors.textPrimary),
                      SizedBox(width: 10.w),
                      Text(
                        'Order Type',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _labelForOrderType(_orderType),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down,
                          color: AppColors.textPrimary),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              if (_isStopLimit) ...[
                // ── Stop-limit: two prices (Trigger + Limit), Vantage-style ──
                Text(
                  'When Price Is Trigger Price',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Obx(
                  () => _Field(
                    label: Get.find<LanguageService>().tr('iquote_trigger_price'),
                    controller: _triggerCtl,
                    palette: palette,
                    digits: widget.ctrl.priceDigits.value,
                    prefix: IconButton(
                      onPressed: () {
                        setState(() {
                          final step = 1 / math.pow(10, d);
                          final p = _trigger - step;
                          _triggerCtl.text = p.toStringAsFixed(d);
                        });
                      },
                      icon: Icon(Icons.remove, color: AppColors.textPrimary),
                    ),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          final step = 1 / math.pow(10, d);
                          final p = _trigger + step;
                          _triggerCtl.text = p.toStringAsFixed(d);
                        });
                      },
                      icon: Icon(Icons.add, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'When Price Is Limit Price',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Obx(
                  () => _Field(
                    label: Get.find<LanguageService>().tr('iquote_limit_price'),
                    controller: _priceCtl,
                    palette: palette,
                    digits: widget.ctrl.priceDigits.value,
                    prefix: IconButton(
                      onPressed: () {
                        setState(() {
                          final step = 1 / math.pow(10, d);
                          final p = _price - step;
                          _priceCtl.text = p.toStringAsFixed(d);
                        });
                      },
                      icon: Icon(Icons.remove, color: AppColors.textPrimary),
                    ),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          final step = 1 / math.pow(10, d);
                          final p = _price + step;
                          _priceCtl.text = p.toStringAsFixed(d);
                        });
                      },
                      icon: Icon(Icons.add, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                // Cross-validation: buy → trigger must be above ask,
                // sell → trigger must be below bid. Mirrors Vantage.
                Obx(() {
                  final ask = widget.ctrl.lastAsk.value ?? 0.0;
                  final bid = widget.ctrl.lastBid.value ?? 0.0;
                  final dd = widget.ctrl.priceDigits.value;
                  String? error;
                  if (_orderType == 'buy_stop_limit') {
                    if (ask > 0 && _trigger <= ask) {
                      error =
                          'Trigger price should be above ${ask.toStringAsFixed(dd)}';
                    }
                  } else if (_orderType == 'sell_stop_limit') {
                    if (bid > 0 && _trigger >= bid) {
                      error =
                          'Trigger price should be below ${bid.toStringAsFixed(dd)}';
                    }
                  }
                  if (error == null) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kBearColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ] else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 4.h),
                  child: Obx(
                    () => _Field(
                      label: Get.find<LanguageService>().tr('iquote_order_price'),
                      controller: _priceCtl,
                      palette: palette,
                      digits: widget.ctrl.priceDigits.value,
                      prefix: IconButton(
                        onPressed: () {
                          setState(() {
                            final step = 1 / math.pow(10, d);
                            final p = _price - step;
                            _priceCtl.text = p.toStringAsFixed(d);
                          });
                        },
                        icon: Icon(Icons.remove, color: AppColors.textPrimary),
                      ),
                      suffix: IconButton(
                        onPressed: () {
                          setState(() {
                            final step = 1 / math.pow(10, d);
                            final p = _price + step;
                            _priceCtl.text = p.toStringAsFixed(d);
                          });
                        },
                        icon: Icon(Icons.add, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ),
            ],
            // TP SL HIDDEN
            Row(
              children: [
                Text(
                  'TP/SL',
                  style: TextStyle(color: palette.axisText, fontSize: 13.sp),
                ),
                SizedBox(width: 6.w),
                Icon(Icons.help_outline, size: 14.sp, color: palette.axisText),
                const Spacer(),
                Switch(
                  value: _tpSlEnabled,
                  activeColor: _kBullColor,
                  onChanged: (v) {
                    setState(() {
                      _tpSlEnabled = v;
                      if (v) {
                        // Force a fresh auto-fill on the next update.
                        _lastAutoTp = null;
                        _lastAutoSl = null;
                        _updateTpSlFromMarketPrice();
                      }
                    });
                  },
                ),
              ],
            ),
            if (_tpSlEnabled) ...[
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _Field(
                        label: Get.find<LanguageService>().tr('pending_order_take_profit_label'),
                        controller: _tpCtl,
                        focusNode: _tpFocusNode,
                        palette: palette,
                        digits: widget.ctrl.priceDigits.value,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Obx(
                      () => _Field(
                        label: Get.find<LanguageService>().tr('pending_order_stop_loss_label'),
                        controller: _slCtl,
                        focusNode: _slFocusNode,
                        palette: palette,
                        digits: widget.ctrl.priceDigits.value,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
            ],
            if (_tab == 0) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    flex: 2,
                    child: SizedBox(
                      height: 48.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: AppColors.pureWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        onPressed: widget.ctrl.isLoading.value
                            ? null
                            : () => _submit(side),
                        child: Obx(() {
                          if (widget.ctrl.isLoading.value) {
                            return SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppColors.textPrimary,
                                strokeWidth: 2,
                              ),
                            );
                          }
                          final px =
                              widget.ctrl.lastAsk.value ??
                              widget.ctrl.lastBid.value ??
                              0;
                          final sideLabel = side == 'buy' ? 'Buy' : 'Sell';
                          final kindLabel = 'Market';
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$sideLabel $kindLabel',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (px > 0) ...[
                                SizedBox(width: 6.w),
                                Text(
                                  px.toStringAsFixed(d),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              SizedBox(width: 6.w),
                              Icon(Icons.trending_up, size: 16.sp),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // ── Place pending order (single button, side+kind from dropdown) ──
              Builder(
                builder: (context) {
                  final isBuyOrder =
                      _orderType == 'buy_limit' ||
                      _orderType == 'buy_stop' ||
                      _orderType == 'buy_stop_limit';
                  final btnColor = isBuyOrder ? _kBullColor : _kBearColor;
                  final sideForSubmit = isBuyOrder ? 'buy' : 'sell';
                  return SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        foregroundColor: AppColors.pureWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onPressed: widget.ctrl.isLoading.value
                          ? null
                          : () => _submit(sideForSubmit),
                      child:
                          widget.ctrl.isLoading.value
                              ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: btnColor,
                                  strokeWidth: 2,
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 240),
                                    transitionBuilder: (child, anim) =>
                                        FadeTransition(
                                      opacity: anim,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.92,
                                          end: 1.0,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: anim,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                        child: child,
                                      ),
                                    ),
                                    child: Text(
                                      'Place ${_labelForOrderType(_orderType)} order',
                                      key: ValueKey(_orderType),
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  String _formatAvailable() {
    final acct = widget.ctrl.activeAccount;
    if (acct == null) return '—';
    final balance = double.tryParse(acct.balance);
    return balance == null ? '—' : balance.toStringAsFixed(4);
  }

  Future<void> _submit(String side) async {
    final isPendingTab = _tab == 1;
    final digits = widget.ctrl.priceDigits.value;
    // Stop-limit sends the Trigger Price as `price` and the Limit Price as
    // `stopLimitPrice`; every other kind sends the single Order Price.
    final price = !isPendingTab
        ? ''
        : (_isStopLimit ? _triggerCtl.text.trim() : _priceCtl.text.trim());
    final stopLimitPrice =
        (isPendingTab && _isStopLimit) ? _priceCtl.text.trim() : null;

    // Format volume preserving the user's actual decimal precision
    // (e.g. 0.001 → "0.001", 0.10 → "0.10") — never collapse to 2 decimals.
    final volStr = _volume.toString();
    final dotIdx = volStr.indexOf('.');
    final actualDecimals =
        dotIdx == -1 ? 0 : volStr.length - dotIdx - 1;
    final volDecimals = actualDecimals < 2 ? 2 : actualDecimals;
    final formattedVolume = _volume.toStringAsFixed(volDecimals);

    // Format TP/SL to the live priceDigits — same precision the backend
    // expects (matches Vantage's _placePendingOrder wiring).
    final String? formattedTp = (_tpSlEnabled && _tpCtl.text.trim().isNotEmpty)
        ? PrecisionHelper.formatPrice(
            PrecisionHelper.parseDouble(
              _tpCtl.text.trim(),
              decimals: digits,
            ),
            decimals: digits,
          )
        : null;
    final String? formattedSl = (_tpSlEnabled && _slCtl.text.trim().isNotEmpty)
        ? PrecisionHelper.formatPrice(
            PrecisionHelper.parseDouble(
              _slCtl.text.trim(),
              decimals: digits,
            ),
            decimals: digits,
          )
        : null;

    // Map the user-selected dropdown value to the wire orderKind the
    // controller's _orderType helper understands. The dropdown now controls
    // the order kind explicitly; no more auto-detect from price vs bid/ask.
    String orderKind;
    if (!isPendingTab) {
      orderKind = 'market';
    } else if (_orderType == 'buy_stop_limit' || _orderType == 'sell_stop_limit') {
      orderKind = 'stop_limit';
    } else if (_orderType == 'buy_stop' || _orderType == 'sell_stop') {
      orderKind = 'stop';
    } else {
      orderKind = 'limit';
    }

    final result = await widget.ctrl.submitOrder(
      side: side,
      orderKind: orderKind,
      volume: _volume,
      price: price,
      stopLimitPrice: stopLimitPrice,
      takeProfit: formattedTp,
      stopLoss: formattedSl,
      formattedVolume: formattedVolume,
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop();
    }
    // On failure, the controller already shows a toast with the API error —
    // we intentionally do NOT close the sheet so the user can fix the price
    // or volume and retry without re-opening it.
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
  });
  final String label;
  final bool active;
  final _ChartPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.whiteColor : palette.inactiveTabText,
              fontSize: 14.sp,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.palette,
    this.suffix,
    this.prefix,
    this.focusNode,
    this.digits,
  });
  final String label;
  final TextEditingController controller;
  final _ChartPalette palette;
  final Widget? suffix;
  final Widget? prefix;
  final FocusNode? focusNode;

  /// Optional decimal-digit cap driven by the live websocket
  /// `priceDigits` value. When supplied, the user is prevented from typing
  /// more fractional digits than the symbol supports (and digits update
  /// reactively when the websocket reports a new value).
  final int? digits;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: digits == null
          ? null
          : [_DecimalDigitsFormatter(maxFractionDigits: digits!)],
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
      textAlign:
          prefix != null
              ? TextAlign.center
              : TextAlign.start, // 👈 This centers the text
      decoration: InputDecoration(
        labelText: prefix != null ? null : label,
        prefixIcon: prefix,
        suffixIcon: suffix,
        labelStyle: TextStyle(color: palette.axisText, fontSize: 12.sp),
        filled: true,
        fillColor: palette.sheetFieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: palette.sheetFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: palette.sheetFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: _kBullColor),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.palette,
  });
  final String label;
  final String value;
  final _ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Favorites Bottom Sheet WATCHLIST (rich UX) ──────────────────────────────
//
// V2 replaces the original flat list with:
//   • instant search field + sort menu (A-Z, % change, spread)
//   • category chips (All / Hot / Forex / Crypto / Indices / Commodities /
//     Stocks) for one-tap filtering
//   • rich tile: flag + symbol, live bid, colored change % pill, sparkline
//     fed from a 60-tick rolling window of bid prices, spread below
//   • long-press to remove a symbol from favorites with an Undo snackbar
//   • selected symbol highlighted with the brand primary color
//   • empty state with a star icon and a "Browse Markets" CTA
//
// The sheet is a StatefulWidget that subscribes to ChartSocketController's
// priceStream so the change% and sparkline update live as ticks arrive.
void _showFavoritesBottomSheet(
  BuildContext context,
  IQuoteChartController ctrl,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return _FavoritesWatchlistSheet(
        activeSymbol: ctrl.symbol,
        onPickSymbol: (sym) {
          ctrl.symbol = sym;
          Navigator.of(sheetCtx).pop();
        },
      );
    },
  );
}

// ── sort modes for the watchlist ────────────────────────────────────────────
enum _WatchSort { name, change, spread }

extension on _WatchSort {
  String get label => switch (this) {
    _WatchSort.name => 'Name (A–Z)',
    _WatchSort.change => 'Change %',
    _WatchSort.spread => 'Spread',
  };
}

// Favorites-only view (no category chips). The sheet shows whatever the user
// has starred, with search + sort + sparkline + change%.
class _FavoritesWatchlistSheet extends StatefulWidget {
  const _FavoritesWatchlistSheet({
    required this.activeSymbol,
    required this.onPickSymbol,
  });
  final String activeSymbol;
  final ValueChanged<String> onPickSymbol;

  @override
  State<_FavoritesWatchlistSheet> createState() =>
      _FavoritesWatchlistSheetState();
}

class _FavoritesWatchlistSheetState extends State<_FavoritesWatchlistSheet> {
  static const int _sparkPoints = 60;

  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';
  _WatchSort _sort = _WatchSort.name;

  final Map<String, List<double>> _bidHistory = {};
  String? _lastRemoved;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<ChartSocketController>()) {
      Get.find<ChartSocketController>().priceStream.listen(_onTick);
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _onTick(Map<String, dynamic> m) {
    final sym = m['symbol']?.toString();
    if (sym == null) return;
    final raw = m['bid'] ?? m['Bid'];
    if (raw == null) return;
    final bid = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (bid == null || bid <= 0) return;
    final key = _stripSuffix(sym);
    final hist = _bidHistory.putIfAbsent(key, () => <double>[]);
    if (hist.isEmpty || (hist.last - bid).abs() > 1e-9) {
      hist.add(bid);
      if (hist.length > _sparkPoints) hist.removeAt(0);
      if (mounted) setState(() {});
    }
  }

  static String _stripSuffix(String s) =>
      s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;

  void _removeFromFavorites(String sym, InstrumentsController ic) {
    setState(() => _lastRemoved = sym);
    ic.toggleFavorite(sym);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1F2937),
        content: Text(
          'Removed $sym from favorites',
          style: TextStyle(color: Colors.white, fontSize: 13.sp),
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: Get.find<LanguageService>().tr('common_undo'),
          textColor: const Color(0xFFF97316),
          onPressed: () {
            if (_lastRemoved != null) {
              ic.toggleFavorite(_lastRemoved!);
              setState(() => _lastRemoved = null);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ic = Get.find<InstrumentsController>();
    final palette = _ChartPalette.of(context);
    final isDark = _isDark(context);
    final mediaH = MediaQuery.of(context).size.height;

    return Container(
      height: mediaH * 0.78,
      decoration: BoxDecoration(
        color: palette.sheetBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        border: Border.all(color: palette.divider, width: 0.5),
      ),
      child: Column(
        children: [
          // ── drag handle ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(top: 10.h, bottom: 8.h),
            child: Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: palette.axisText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),
          // ── title row ─────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 8.w, 8.h),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  color: const Color(0xFFF59E0B),
                  size: 20.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Watchlist',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 6.w),
                Obx(() {
                  final count = ic.favoriteInstruments.length;
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: const Color(0xFFF97316),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
                const Spacer(),
                _SortMenu(
                  current: _sort,
                  onChanged: (s) => setState(() => _sort = s),
                  palette: palette,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          // ── search field ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
            child: Container(
              decoration: BoxDecoration(
                color: palette.sheetFieldBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: palette.sheetFieldBorder),
              ),
              child: TextField(
                controller: _searchCtl,
                onChanged:
                    (v) => setState(() => _query = v.trim().toLowerCase()),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13.sp,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                  border: InputBorder.none,
                  hintText: Get.find<LanguageService>().tr('iquote_search_symbols'),
                  hintStyle: TextStyle(
                    color: palette.axisText,
                    fontSize: 13.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18.sp,
                    color: palette.axisText,
                  ),
                  suffixIcon:
                      _query.isEmpty
                          ? null
                          : IconButton(
                            splashRadius: 18,
                            icon: Icon(
                              Icons.close,
                              size: 18.sp,
                              color: palette.axisText,
                            ),
                            onPressed: () {
                              _searchCtl.clear();
                              setState(() => _query = '');
                            },
                          ),
                ),
              ),
            ),
          ),
          // ── list ──────────────────────────────────────────────────
          Divider(color: palette.divider, height: 1),
          Expanded(
            child: Obx(() {
              final all = ic.favoriteInstruments;
              final filtered =
                  all.where((sym) {
                    if (_query.isEmpty) return true;
                    return sym.toLowerCase().contains(_query) ||
                        _stripSuffix(sym).toLowerCase().contains(_query);
                  }).toList();
              _sortList(filtered, ic);
              if (filtered.isEmpty) {
                return _EmptyWatchlist(
                  hasAnyFavorites: all.isNotEmpty,
                  palette: palette,
                  isDark: isDark,
                );
              }
              return ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                itemCount: filtered.length,
                separatorBuilder:
                    (_, __) => Divider(
                      color: palette.divider,
                      height: 1,
                      indent: 16.w,
                    ),
                itemBuilder: (_, i) {
                  final sym = filtered[i];
                  return _WatchlistTile(
                    symbol: sym,
                    isActive: sym == widget.activeSymbol,
                    isDark: isDark,
                    palette: palette,
                    sparkData: _bidHistory[_stripSuffix(sym)] ?? const [],
                    onTap: () => widget.onPickSymbol(sym),
                    onLongPress: () => _removeFromFavorites(sym, ic),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  void _sortList(List<String> list, InstrumentsController ic) {
    switch (_sort) {
      case _WatchSort.name:
        list.sort((a, b) => _stripSuffix(a).compareTo(_stripSuffix(b)));
      case _WatchSort.change:
        list.sort((a, b) {
          final ca = _changePct(a, ic);
          final cb = _changePct(b, ic);
          return cb.compareTo(ca); // desc: best movers first
        });
      case _WatchSort.spread:
        list.sort((a, b) {
          final sa = ic.priceRx(a).value.spreadDiff;
          final sb = ic.priceRx(b).value.spreadDiff;
          return sa.compareTo(sb); // asc: tightest spread first
        });
    }
  }

  double _changePct(String sym, InstrumentsController ic) {
    final p = ic.priceRx(sym).value;
    final dayLow = p.dayLow;
    if (p.bid <= 0 || dayLow <= 0) return 0;
    return ((p.bid - dayLow) / dayLow) * 100;
  }
}

// ── sort menu (icon button → bottom popup) ──────────────────────────────────
class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.current,
    required this.onChanged,
    required this.palette,
    required this.isDark,
  });
  final _WatchSort current;
  final ValueChanged<_WatchSort> onChanged;
  final _ChartPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_WatchSort>(
      tooltip: Get.find<LanguageService>().tr('common_sort'),
      splashRadius: 20,
      color: palette.sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(color: palette.divider),
      ),
      offset: Offset(0, 36.h),
      onSelected: onChanged,
      itemBuilder:
          (_) =>
              _WatchSort.values
                  .map(
                    (s) => PopupMenuItem<_WatchSort>(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            s == current
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color:
                                s == current
                                    ? const Color(0xFFF97316)
                                    : palette.axisText,
                            size: 16.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            s.label,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: palette.sheetFieldBg,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: palette.sheetFieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 16.sp, color: palette.axisText),
            SizedBox(width: 4.w),
            Text(
              'Sort',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── empty state ─────────────────────────────────────────────────────────────
class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist({
    required this.hasAnyFavorites,
    required this.palette,
    required this.isDark,
  });
  final bool hasAnyFavorites;
  final _ChartPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasAnyFavorites
                    ? Icons.search_off_rounded
                    : Icons.star_outline_rounded,
                size: 36.sp,
                color: const Color(0xFFF97316),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              hasAnyFavorites ? 'No matches' : 'No favorites yet',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              hasAnyFavorites
                  ? 'Try a different search or category.'
                  : 'Tap the star on any symbol in Markets to add it to your watchlist.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.axisText,
                fontSize: 12.sp,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── single watchlist tile ───────────────────────────────────────────────────
class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({
    required this.symbol,
    required this.isActive,
    required this.isDark,
    required this.palette,
    required this.sparkData,
    required this.onTap,
    required this.onLongPress,
  });
  final String symbol;
  final bool isActive;
  final bool isDark;
  final _ChartPalette palette;
  final List<double> sparkData;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static String _strip(String s) =>
      s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;

  @override
  Widget build(BuildContext context) {
    final ic = Get.find<InstrumentsController>();
    return Obx(() {
      final p = ic.priceRx(symbol).value;
      final dayLow = p.dayLow;
      final changePct =
          (p.bid > 0 && dayLow > 0) ? ((p.bid - dayLow) / dayLow) * 100 : 0.0;
      final isUp = changePct >= 0;
      final changeColor =
          p.bid <= 0
              ? palette.axisText
              : (isUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444));
      // Tile is symbol-only on the left, sparkline + change% on the right.
      // The bid price and spread pill were removed; bid is still read for change%
      // but the bid/spread text strings are no longer displayed.

      return Material(
        color:
            isActive
                ? const Color(0xFFF97316).withValues(alpha: 0.08)
                : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                _FlagIcon(symbol: _strip(symbol)),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _strip(symbol).toUpperCase(),
                        style: TextStyle(
                          color:
                              isActive
                                  ? const Color(0xFFF97316)
                                  : (isDark ? Colors.white : Colors.black),
                          fontWeight: FontWeight.w800,
                          fontSize: 14.sp,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final existing = ic.allInstruments.firstWhereOrNull(
                            (element) => element.symbol == symbol,
                          );
                          final name =
                              existing?.name ?? ic.favoriteNames[symbol];
                          if (name != null && name.isNotEmpty) {
                            return Padding(
                              padding: EdgeInsets.only(top: 2.h),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: palette.axisText,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // Only the symbol is shown on this side — the .c suffix and the sp X pill
                      // were removed per request to keep the tile clean and symbol-focused.
                    ],
                  ),
                ),
                //                 SizedBox(
                //                   width: 56.w,
                //                   height: 28.h,
                //                   child: CustomPaint(
                //                     painter: _SparklinePainter(
                //                       data: sparkData,
                //                       color: changeColor,
                //                     ),
                //                   ),
                //                 ),
                //                 SizedBox(width: 10.w),
                // // Change % pill only — price + chevron removed per request. The tile now
                // // shows: [Flag] [symbol] …… [sparkline] [±X.XX%].
                //                 Container(
                //                   padding: EdgeInsets.symmetric(
                //                     horizontal: 8.w,
                //                     vertical: 4.h,
                //                   ),
                //                   decoration: BoxDecoration(
                //                     color: changeColor.withValues(alpha: 0.15),
                //                     borderRadius: BorderRadius.circular(8.r),
                //                   ),
                //                   child: Row(
                //                     mainAxisSize: MainAxisSize.min,
                //                     children: [
                //                       Icon(
                //                         p.bid <= 0
                //                             ? Icons.remove
                //                             : (isUp
                //                                 ? Icons.arrow_drop_up
                //                                 : Icons.arrow_drop_down),
                //                         color: changeColor,
                //                         size: 14.sp,
                //                       ),
                //                       SizedBox(width: 2.w),
                //                       Text(
                //                         p.bid <= 0
                //                             ? '0.00%'
                //                             : '${isUp ? '+' : '-'}${changePct.abs().toStringAsFixed(2)}%',
                //                         style: TextStyle(
                //                           color: changeColor,
                //                           fontSize: 11.sp,
                //                           fontWeight: FontWeight.w700,
                //                           fontFeatures: const [FontFeature.tabularFigures()],
                //                         ),
                //                       ),
                //                     ],
                //                   ),
                //                 ),
                //                 SizedBox(width: 8.w),
                Icon(
                  Icons.chevron_right,
                  size: 18.sp,
                  color: palette.axisText.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ── tiny sparkline painter (no extra deps) ──────────────────────────────────
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.data, required this.color});
  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) {
      // Single-point placeholder: a small dot in the middle.
      final dot = Paint()..color = color.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 1.4, dot);
      return;
    }
    double minY = data.first;
    double maxY = data.first;
    for (final v in data) {
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }
    if ((maxY - minY).abs() < 1e-9) {
      // Flat line — draw a faint midline.
      final mid =
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        mid,
      );
      return;
    }
    final dx = size.width / (data.length - 1);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - ((data[i] - minY) / (maxY - minY)) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final stroke =
        Paint()
          ..color = color
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}

// ── Fullscreen WebView Chart Screen ──────────────────────────────────────────
class IQuoteFullscreenChartScreen extends StatelessWidget {
  final String symbol;

  const IQuoteFullscreenChartScreen({super.key, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final chartUrl =
        '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?theme=${AppColors.chartTheme}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        leading: AppBackButton(onPressed: () => Get.back()),
        title: Text(
          '${symbol.replaceAll('.c', '').toUpperCase()} Chart',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: FlavorConfig.instance.useNewChart
            ? TenaxChartWebView(
                symbol: symbol,
                isDark: AppColors.chartTheme == 'dark',
              )
            : ChartInAppWebView(symbol: symbol, url: chartUrl),
      ),
    );
  }
}

class _FlagIcon extends StatelessWidget {
  final String symbol;
  const _FlagIcon({required this.symbol});

  @override
  Widget build(BuildContext context) {
    String clean =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;

    final flagPath = 'assets/svg/flags/${clean.toLowerCase()}.svg';

    return SizedBox(
      width: 24.w,
      height: 24.w,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Padding(
            padding: EdgeInsets.all(3.r),
            child: SvgPicture.asset(
              flagPath,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => Center(
                child: Text(
                  clean.isNotEmpty ? clean[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
);
  }
}

// ── Animated expand-collapse order-type picker ───────────────────────────
// Replaces a native DropdownButton so the option list opens inline with a
// smooth expand-collapse animation (AnimatedSize + chevron rotation +
// staggered option fade-in). Selected option shows a popping radio dot +
// tinted background. Built as a stateless widget driven by parent state.
// ── Bottom-sheet picker for the 6 pending order types ───────────────────
// Opens on top of the New Order sheet when the user taps the order-type
// row. Tapping an option pops the sheet with the chosen kind string;
// the parent rebuilds and runs `_onOrderTypeChanged`.
class _OrderTypePickerSheet extends StatelessWidget {
  const _OrderTypePickerSheet({
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.palette,
  });
  final List<String> options;
  final String selected;
  final String Function(String) labelFor;
  final _ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: palette.axisText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Order Type',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ...options.map((opt) => InkWell(
                  onTap: () => Navigator.of(context).pop(opt),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    child: Row(
                      children: [
                        Icon(
                          opt == selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: opt == selected
                              ? AppColors.primary
                              : AppColors.textGrey,
                          size: 20.sp,
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Text(
                            labelFor(opt),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: opt == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (opt.contains('stop_limit'))
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              '2 prices',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

// ── Decimal-digit clamp formatter (reactive to live priceDigits) ────────
// Used as a `TextInputFormatter` on price/TP/SL fields so the user can
// only type up to `maxFractionDigits` decimals. When the websocket emits a
// new `priceDigits` value for the symbol, the parent rebuilds the field
// with a fresh formatter — no manual input clearing needed.
class _DecimalDigitsFormatter extends TextInputFormatter {
  const _DecimalDigitsFormatter({required this.maxFractionDigits});

  final int maxFractionDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (maxFractionDigits <= 0) return newValue;
    final text = newValue.text;
    if (text.isEmpty || text == '-' || text == '+') return newValue;
    if ('.'.allMatches(text).length > 1) return oldValue;
    final dot = text.indexOf('.');
    if (dot < 0) return newValue;
    final fracLen = text.length - dot - 1;
    if (fracLen <= maxFractionDigits) return newValue;
    final trimmed = text.substring(0, dot + 1 + maxFractionDigits);
    return TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
  }
}
