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
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/theme_service.dart';
import 'package:crm_app/widgets/account_header_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/screens/home/brands/iquote/iquote_position_screen.dart';
import 'package:crm_app/screens/home/brands/iquote/view_models/iquote_chart_controller.dart';

// ── palette ─────────────────────────────────────────────────────────────────
// MA-line + bullish/bearish colors stay the same across themes — they're
// functional indicator colors (like TradingView's), not surface colors.
const _kBullColor = Color(0xFF22C55E);
const _kBearColor = Color(0xFFE74C3C);
const _kMa5Color = Color(0xFF3478F6);
const _kMa10Color = Color(0xFFF5A623);
const _kMa30Color = Color(0xFFD91CAC);

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
    sheetFieldBg: Color(0xFF1A2440),
    sheetFieldBorder: Color(0x33FFFFFF),
    emptyHintIcon: Color(0xFFAAAACC),
    inactiveTabBg: Color(0xFF1A2440),
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

class IQuoteChartScreen extends StatelessWidget {
  const IQuoteChartScreen({super.key, required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<IQuoteChartController>(
      init: IQuoteChartController(symbol),
      builder: (ctrl) {
        final palette = _ChartPalette.of(context);
        return Scaffold(
          backgroundColor: palette.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(ctrl: ctrl, palette: palette),
                _SymbolRow(ctrl: ctrl, palette: palette),
                _Toolbar(ctrl: ctrl, palette: palette),
                _MaStrip(ctrl: ctrl, palette: palette),
                Expanded(child: _ChartPlaceholder(palette: palette)),
                _BottomBar(ctrl: ctrl, palette: palette),
              ],
            ),
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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          AppBackButton(
            onPressed: () => Get.back<void>(),
          ),
          SizedBox(width: 8.w),
          _AccountPill(ctrl: ctrl),
          const Spacer(),
          // Live account balance in the top-right (mirrors dashboard top bar).
          Expanded(
            child: AccountHeaderWidget(
              showSearchIcon: false,
              showMenuIcon: false,
              layoutStyle: AccountHeaderLayoutStyle.defaultLayout,
            ),
          ),
          SizedBox(width: 4.w),
          Icon(
            Icons.info_outline,
            size: 20.sp,
            color: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({required this.ctrl});
  final IQuoteChartController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDemo = ctrl.isDemoAccount;
      final color = isDemo
          ? const Color(0xFF3B82F6)
          : const Color(0xFFEF4444);
      final label = isDemo ? 'DEMO' : 'LIVE';
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4.r),
          border: Border.all(color: color, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(Icons.keyboard_arrow_down, size: 14.sp, color: color),
          ],
        ),
      );
    });
  }
}

// ── symbol row (XAU/USD + bell + calc + more) ──────────────────────────────
class _SymbolRow extends StatelessWidget {
  const _SymbolRow({required this.ctrl, required this.palette});
  final IQuoteChartController ctrl;
  final _ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 4.h),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 18.w,
                height: 12.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF),
                  borderRadius: BorderRadius.circular(1.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  '🇺🇸',
                  style: TextStyle(fontSize: 11.sp),
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                ctrl.symbol.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
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
          const Spacer(),
          _CircleIcon(
            svg: 'assets/svg/chart_screen_icon/bell_icon.svg',
            onTap: () {/* notifications list — wired later */},
          ),
          SizedBox(width: 8.w),
          _CircleIcon(
            svg: 'assets/svg/calculator.svg',
            onTap: () {/* open lot calculator — wired later */},
          ),
          SizedBox(width: 8.w),
          _CircleIcon(
            svg: 'assets/svg/chart_screen_icon/beg_icon.svg',
            onTap: () {/* period presets sheet — wired later */},
          ),
          SizedBox(width: 8.w),
          _CircleIcon(
            svg: 'assets/svg/menu.svg',
            onTap: () {/* chart settings sheet — wired later */},
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.svg, this.onTap});
  final String svg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.w,
        height: 28.w,
        alignment: Alignment.center,
        child: SvgPicture.asset(
          svg,
          width: 18.w,
          height: 18.w,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ── toolbar (period selector + extra action icons) ─────────────────────────
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.ctrl, required this.palette});
  final IQuoteChartController ctrl;
  final _ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Row(
        children: [
          Text(
            'Period',
            style: TextStyle(color: palette.axisText, fontSize: 13.sp),
          ),
          SizedBox(width: 14.w),
          ...IQuoteChartController.kPeriods.map(
            (p) => Padding(
              padding: EdgeInsets.only(right: 14.w),
              child: GestureDetector(
                onTap: () => ctrl.changePeriod(p),
                child: Obx(() {
                  final active = ctrl.period.value == p;
                  return Text(
                    p,
                    style: TextStyle(
                      color: active
                          ? AppColors.textPrimary
                          : palette.axisText,
                      fontSize: 13.sp,
                      fontWeight: active
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  );
                }),
              ),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.calendar_today_outlined,
            size: 18.sp,
            color: palette.axisText,
          ),
          SizedBox(width: 14.w),
          Icon(Icons.tune, size: 18.sp, color: palette.axisText),
          SizedBox(width: 14.w),
          Icon(Icons.aspect_ratio, size: 18.sp, color: palette.axisText),
        ],
      ),
    );
  }
}

// ── MA strip ───────────────────────────────────────────────────────────────
class _MaStrip extends StatelessWidget {
  const _MaStrip({required this.ctrl, required this.palette});
  final IQuoteChartController ctrl;
  final _ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Obx(
        () => Row(
          children: [
            _MaLabel(text: ctrl.ma5Label, color: _kMa5Color),
            SizedBox(width: 14.w),
            _MaLabel(text: ctrl.ma10Label, color: _kMa10Color),
            SizedBox(width: 14.w),
            _MaLabel(text: ctrl.ma30Label, color: _kMa30Color),
          ],
        ),
      ),
    );
  }
}

class _MaLabel extends StatelessWidget {
  const _MaLabel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── candle area placeholder ────────────────────────────────────────────────
// Static area sized to fit the rest of the screen, with the live bid/ask
// horizontal marker lines and the right-axis price scale rendered so the page
// still looks correct before the real chart hook lands.
class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.palette});
  final _ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<IQuoteChartController>();
    return Container(
      width: double.infinity,
      color: palette.chartAreaBg,
      child: Obx(() {
        final hi = ctrl.chartScaleHigh.value;
        final lo = ctrl.chartScaleLow.value;
        final bid = ctrl.chartBidLine.value;
        final ask = ctrl.chartAskLine.value;
        final d = ctrl.priceDigits.value;

        final ticks = <double>[];
        if (hi != null && lo != null && hi > lo) {
          for (var i = 0; i < 5; i++) {
            final t = lo + (hi - lo) * (i / 4.0);
            ticks.add(t);
          }
        }

        double yFor(double price) {
          if (hi == null || lo == null || hi <= lo) return 0;
          final frac = (price - lo) / (hi - lo);
          return 1 - frac;
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: palette.divider, width: 1),
                    bottom: BorderSide(color: palette.divider, width: 1),
                  ),
                ),
              ),
            ),
            ...List.generate(5, (i) {
              return Positioned(
                left: 0,
                right: 0,
                top:
                    MediaQuery.of(context).size.height *
                    0 +
                    (i + 1) *
                        (1 / 6.0) *
                        (MediaQuery.of(context).size.height * 0.42),
                child: Divider(color: palette.divider, height: 1),
              );
            }),
            ...ticks.map((price) {
              return Positioned(
                right: 8.w,
                top:
                    MediaQuery.of(context).size.height *
                    0 +
                    yFor(price).clamp(0.0, 1.0) *
                        (MediaQuery.of(context).size.height * 0.42) -
                    8,
                child: Text(
                  price.toStringAsFixed(d),
                  style: TextStyle(color: palette.axisText, fontSize: 11.sp),
                ),
              );
            }),
            if (ask != null && hi != null && lo != null && hi > lo)
              Positioned(
                left: 0,
                right: 0,
                top:
                    MediaQuery.of(context).size.height *
                    0 +
                    yFor(ask).clamp(0.0, 1.0) *
                        (MediaQuery.of(context).size.height * 0.42),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: _kBullColor.withValues(alpha: 0.7),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      color: _kBullColor,
                      child: Text(
                        ask.toStringAsFixed(d),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (bid != null && hi != null && lo != null && hi > lo)
              Positioned(
                left: 0,
                right: 0,
                top:
                    MediaQuery.of(context).size.height *
                    0 +
                    yFor(bid).clamp(0.0, 1.0) *
                        (MediaQuery.of(context).size.height * 0.42),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: _kBearColor.withValues(alpha: 0.7),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      color: _kBearColor,
                      child: Text(
                        bid.toStringAsFixed(d),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 36.sp,
                    color: palette.emptyHintIcon.withValues(alpha: 0.6),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Live chart placeholder',
                    style: TextStyle(color: palette.axisText, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── bottom bar (candle icon + icon-only Team/Position + Buy/Sell) ──────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.ctrl, required this.palette});
  final IQuoteChartController ctrl;
  final _ChartPalette palette;

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
          final positionCount = ctrl.openPositionCount.value;
          final pendingCount = ctrl.pendingOrderCount.value;
          final bid = ctrl.lastBid.value;
          final ask = ctrl.lastAsk.value;
          final d = ctrl.priceDigits.value;

          return Column(
            children: [
              Row(
                children: [
                  // Candle-type icon (left).
                  Container(
                    width: 36.w,
                    height: 36.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.sheetFieldBg,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Icon(
                      Icons.candlestick_chart_outlined,
                      size: 18.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  // Team (open positions) — icon + badge only.
                  _IconOnlyBadge(
                    icon: Icons.group_outlined,
                    badge: positionCount,
                    palette: palette,
                    onTap: () =>
                        Get.to<void>(() => const IQuotePositionScreen()),
                  ),
                  SizedBox(width: 6.w),
                  // Position (pending orders) — icon + badge only.
                  _IconOnlyBadge(
                    icon: Icons.assignment,
                    badge: pendingCount,
                    palette: palette,
                    onTap: () =>
                        Get.to<void>(() => const IQuotePositionScreen()),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 5,
                    child: _ActionPill(
                      color: _kBullColor,
                      icon: Icons.trending_up,
                      label: 'Buy',
                      price: ask != null
                          ? ask.toStringAsFixed(d)
                          : '—',
                      onTap: () => _openNewOrderSheet(context, side: 'buy'),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    flex: 5,
                    child: _ActionPill(
                      color: _kBearColor,
                      icon: Icons.trending_down,
                      label: 'Sell',
                      price: bid != null
                          ? bid.toStringAsFixed(d)
                          : '—',
                      onTap: () => _openNewOrderSheet(context, side: 'sell'),
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  void _openNewOrderSheet(BuildContext context, {required String side}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.sheetBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => _NewOrderSheet(
        ctrl: ctrl,
        side: side,
        pricePreview: side == 'buy'
            ? (ctrl.lastAsk.value ?? 0)
            : (ctrl.lastBid.value ?? 0),
      ),
    );
  }
}

/// Icon-only badge (no "Team"/"Position" text), with a small red counter on
/// top-right when count > 0. Sized to match the candle button on the left.
class _IconOnlyBadge extends StatelessWidget {
  const _IconOnlyBadge({
    required this.icon,
    required this.badge,
    required this.palette,
    required this.onTap,
  });
  final IconData icon;
  final int badge;
  final _ChartPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36.w,
        height: 36.w,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.sheetFieldBg,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(icon, size: 18.sp, color: AppColors.textPrimary),
            ),
            if (badge > 0)
              Positioned(
                right: -2.w,
                top: -2.h,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5.w,
                    vertical: 1.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: palette.sheetBg,
                      width: 1.2,
                    ),
                  ),
                  constraints: BoxConstraints(minWidth: 16.w),
                  alignment: Alignment.center,
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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

  late double _volume;
  late TextEditingController _priceCtl;
  late TextEditingController _tpCtl;
  late TextEditingController _slCtl;
  int _tab = 0; // 0 market, 1 limit
  bool _tpSlEnabled = false;

  @override
  void initState() {
    super.initState();
    _volume = 1.00;
    _priceCtl = TextEditingController(
      text: widget.pricePreview > 0
          ? widget.pricePreview.toStringAsFixed(widget.ctrl.priceDigits.value)
          : '',
    );
    _tpCtl = TextEditingController();
    _slCtl = TextEditingController();
  }

  @override
  void dispose() {
    _priceCtl.dispose();
    _tpCtl.dispose();
    _slCtl.dispose();
    super.dispose();
  }

  double get _price => double.tryParse(_priceCtl.text.trim()) ?? 0;
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

    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 12.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12.h,
      ),
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
          // Market / Limit tabs
          Container(
            decoration: BoxDecoration(
              color: palette.inactiveTabBg,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: palette.inactiveTabBorder),
            ),
            child: Row(
              children: [
                _TabButton(
                  label: 'Market',
                  active: _tab == 0,
                  palette: palette,
                  onTap: () => setState(() => _tab = 0),
                ),
                _TabButton(
                  label: 'Limit',
                  active: _tab == 1,
                  palette: palette,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Volume(Lot)',
                  style: TextStyle(color: fieldText, fontSize: 13.sp),
                ),
              ),
              Text(
                'Leverage',
                style: TextStyle(color: fieldText, fontSize: 13.sp),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  decoration: BoxDecoration(
                    color: palette.sheetFieldBg,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: palette.sheetFieldBorder),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _volume = (_volume - 0.01).clamp(0.01, 99.0);
                          });
                        },
                        icon:  Icon(Icons.remove, color: AppColors.textPrimary),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _volume.toStringAsFixed(2),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _volume = (_volume + 0.01).clamp(0.01, 99.0);
                          });
                        },
                        icon:  Icon(Icons.add, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: palette.sheetFieldBg,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: palette.sheetFieldBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '300X',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16.sp,
                      color: palette.axisText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: _lots
                .map(
                  (lot) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 6.w),
                      child: GestureDetector(
                        onTap: () => setState(() => _volume = lot),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            color: (lot == _volume)
                                ? palette.tabAccent
                                : palette.sheetFieldBg,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: palette.sheetFieldBorder),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            lot.toStringAsFixed(2),
                            style: TextStyle(
                              color: (lot == _volume)
                                ?AppColors.whiteColor:AppColors.textPrimary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
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
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: palette.sheetFieldBg,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: palette.sheetFieldBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                    ),
                  ),
                  Text(
                    'USDT',
                    style: TextStyle(color: palette.axisText, fontSize: 13.sp),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        final p = _price - 0.01;
                        _priceCtl.text = p.toStringAsFixed(d);
                      });
                    },
                    icon:  Icon(Icons.remove, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        final p = _price + 0.01;
                        _priceCtl.text = p.toStringAsFixed(d);
                      });
                    },
                    icon:  Icon(Icons.add, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
          ],
          Row(
            children: [
              Text(
                'TP/SL',
                style: TextStyle(color: palette.axisText, fontSize: 13.sp),
              ),
              SizedBox(width: 6.w),
              Icon(
                Icons.help_outline,
                size: 14.sp,
                color: palette.axisText,
              ),
              const Spacer(),
              Switch(
                value: _tpSlEnabled,
                activeColor: _kBullColor,
                onChanged: (v) => setState(() => _tpSlEnabled = v),
              ),
            ],
          ),
          if (_tpSlEnabled) ...[
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Take profit',
                    controller: _tpCtl,
                    palette: palette,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _Field(
                    label: 'Stop loss',
                    controller: _slCtl,
                    palette: palette,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
          ],
          _SummaryRow(
            label: 'Margin',
            value: _margin.toStringAsFixed(4),
            palette: palette,
          ),
          SizedBox(height: 6.h),
          _SummaryRow(
            label: 'Fee',
            value: _fee.toStringAsFixed(4),
            palette: palette,
          ),
          SizedBox(height: 6.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ${_total.toStringAsFixed(4)}',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: fieldText,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Available:${_formatAvailable()}',
                      style: TextStyle(
                        color: palette.axisText,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 130.w,
                height: 44.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: () => _submit(side),
                  child: Obx(() {
                    if (widget.ctrl.isLoading.value) {
                      return  SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.textPrimary,
                          strokeWidth: 2,
                        ),
                      );
                    }
                    final px = _tab == 0
                        ? (widget.ctrl.lastAsk.value ??
                            widget.ctrl.lastBid.value ??
                            0)
                        : _price;
                    final sideLabel = side == 'buy' ? 'Buy' : 'Sell';
                    final kindLabel = _tab == 1 ? 'Limit' : 'Market';
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
            ],
          ),
        ],
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
    final isLimit = _tab == 1;
    final price = isLimit ? _priceCtl.text.trim() : '';
    final result = await widget.ctrl.submitOrder(
      side: side,
      orderKind: isLimit ? 'limit' : 'market',
      volume: _volume,
      price: price,
      takeProfit: _tpSlEnabled ? _tpCtl.text.trim() : null,
      stopLoss: _tpSlEnabled ? _slCtl.text.trim() : null,
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
            color: active ? palette.tabAccent : Colors.transparent,
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
  });
  final String label;
  final TextEditingController controller;
  final _ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
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