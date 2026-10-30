import 'dart:ui' as ui show TextDirection;

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_dashboard_controller.dart';
import 'package:crm_app/models/copy_trading_dashboard_overview.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'master_settlements_screen.dart';

/// Mobile-friendly Master Dashboard "Overview" tab.
///
/// Mirrors the latest web design:
///   - Header (title + refresh button)
///   - Range pills: Today / 7D / 30D / 90D / 1Y / All
///   - 4 KPI cards: Total AUM, Active Copiers, My Earnings, Master ROI
///     (each with a trend pill + mini sparkline)
///   - Performance overview chart (Equity / AUM / Net P/L toggle)
///   - Copier health (donut + metrics)
///   - Plan performance
///   - Payouts (earned / pending / upcoming / recent)
///   - Recent trades
///   - Risk alerts
class MasterDashboardOverviewTab extends StatelessWidget {
  const MasterDashboardOverviewTab({super.key});

  // Chip labels map directly to the backend-supported presets.
  static const _rangeChips = ['Today', '7D', '30D', '90D', '1Y', 'All'];

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CopyTradingMasterDashboardController>();

    // Single Obx that reads BOTH `overview` and `isOverviewLoading` so the
    // whole subtree (range pills, KPI cards, performance chart, copier
    // health, plans, payouts, trades, alerts) rebuilds on every range
    // change. Nested Obx widgets were caching old captures and freezing
    // the chart between range switches.
    return Obx(() {
      final overview = ctrl.overview.value;
      final isLoading = ctrl.isOverviewLoading.value;
      final firstLoad = isLoading && overview == null;

      if (firstLoad) {
        return const _LoadingState();
      }
      if (overview == null) {
        return _EmptyState(onRetry: () => ctrl.loadDashboardOverview());
      }

      final from = _fmtDateOrLabel(overview.range.from, null);
      final to = _fmtDateOrLabel(overview.range.to, null);
      final theme = Theme.of(context);
      // ValueKey on the data column forces Flutter to discard the old
      // sub-tree (including any CustomPainter state that holds a cached
      // points list) and build a brand-new one when the range changes.
      final dataKey = ValueKey(
        'overview-${overview.range.preset}-'
        '${overview.range.from}-${overview.range.to}',
      );

      return Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact date-range row + inline "updating" indicator. The
            // "Master Dashboard" title lives in the AppBar; we don't
            // repeat it here.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$from → $to',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child:
                      isLoading
                          ? Row(
                            key: const ValueKey('loading'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                TranslationUtils.tr('master_dashboard_overview_tab_updating'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          )
                          : const SizedBox.shrink(key: ValueKey('idle')),
                ),
              ],
            ),
            SizedBox(height: 10),

            // Range pills — disable taps + dim while a fetch is in flight
            // so users can't queue overlapping requests and get clear
            // visual feedback that the API call is running.
            AnimatedOpacity(
              opacity: isLoading ? 0.55 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: isLoading,
                child: _RangePills(
                  chips: _rangeChips,
                  current: ctrl.overviewRange.value,
                  onChanged: ctrl.changeRange,
                ),
              ),
            ),
            SizedBox(height: 16),

            // Dim all data sections while a range-change fetch is in
            // flight, so the user sees every chart/card visibly refresh
            // when the new data arrives. ValueKey on the column forces a
            // full sub-tree rebuild on every range switch.
            AnimatedOpacity(
              opacity: isLoading ? 0.45 : 1.0,
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: dataKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KpiGrid(overview: overview),
                  SizedBox(height: 16),
                  _PerformanceChartCard(overview: overview),
                  SizedBox(height: 16),
                  _CopierHealthCard(health: overview.copierHealth),
                  SizedBox(height: 12),
                  _PlanPerformanceCard(plans: overview.plans),
                  SizedBox(height: 12),
                  _PayoutsCard(payouts: overview.payouts),
                  SizedBox(height: 16),
                  _RecentTradesCard(trades: overview.recentTrades),
                  SizedBox(height: 16),
                  _RiskAlertsCard(alerts: overview.alerts),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ===========================================================================
// Formatting helpers
// ===========================================================================

final NumberFormat _money = NumberFormat.currency(
  locale: 'en_US',
  symbol: r'$',
  decimalDigits: 2,
);
final DateFormat _shortDate = DateFormat('d MMM');
final DateFormat _time = DateFormat('HH:mm');

String _fmtMoney(num v) => _money.format(v);

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    // API timestamps are UTC (`+00:00`); show them in the device's time zone.
    return _shortDate.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

String _fmtDateOrLabel(String? iso, String? label) {
  if (label != null && label.isNotEmpty) return label;
  return _fmtDate(iso);
}

// ===========================================================================
// Range pills
// ===========================================================================

/// Maps a raw range preset (kept untranslated because it is sent to the API
/// and compared against `overviewRange`) onto its localized display label.
String _rangeChipLabel(String raw) => switch (raw) {
  'Today' => TranslationUtils.tr('dc_range_today'),
  'All' => TranslationUtils.tr('common_all'),
  _ => raw,
};

class _RangePills extends StatelessWidget {
  const _RangePills({
    required this.chips,
    required this.current,
    required this.onChanged,
  });
  final List<String> chips;
  final String current;
  final ValueChanged<String> onChanged;

  bool _isSelected(String chip) => chip.toLowerCase() == current.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[
            GestureDetector(
              onTap: () => onChanged(chip),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isSelected(chip) ? brand : theme.cardColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        _isSelected(chip)
                            ? brand
                            : theme.dividerColor.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _rangeChipLabel(chip),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        _isSelected(chip)
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color?.withValues(
                              alpha: 0.7,
                            ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// KPI grid (4 cards)
// ===========================================================================

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.overview});
  final CopyTradingDashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final aum = overview.hero.aum;
    final copiers = overview.hero.copiers;
    final earnings = overview.hero.earnings;
    final roi = overview.hero.roi;

    final cards = <Widget>[
      _KpiCard(
        label: TranslationUtils.tr('pmam_manager_dashboard_screen_total_aum'),
        accent: const Color(0xFF2C5FFB),
        accentSoft: const Color(0xFFE8EEFF),
        value: _fmtMoney(aum.current),
        pill: _TrendPill(value: aum.deltaPct),
        sub: TranslationUtils.tr('copy_trading_assets_under_management'),
        spark: aum.series.values,
      ),
      _KpiCard(
        label: TranslationUtils.tr('copy_trading_active_copiers_upper'),
        accent: const Color(0xFF00BFA6),
        accentSoft: const Color(0xFFD7F6F0),
        value: '${copiers.current}',
        pill: _TrendPill(value: copiers.delta, signed: true, isInt: true),
        sub: TranslationUtils.trArgs('copy_trading_net_new_in_window', {
          'value': '${copiers.delta > 0 ? '+' : ''}${copiers.delta}',
        }),
        spark: copiers.series.values,
      ),
      _KpiCard(
        label: TranslationUtils.tr('copy_trading_my_earnings_upper'),
        accent: const Color(0xFF1DB954),
        accentSoft: const Color(0xFFE6F8EE),
        value: _fmtMoney(earnings.current),
        sub:
            earnings.nextPayoutDate.isEmpty
                ? TranslationUtils.tr('copy_trading_lifetime_total_credited')
                : TranslationUtils.trArgs('copy_trading_next_payout_on', {
                  'amount': _fmtMoney(earnings.nextPayoutAmount),
                  'date': _fmtDate(earnings.nextPayoutDate),
                }),
        spark: earnings.series.values,
      ),
      _KpiCard(
        label: TranslationUtils.tr('copy_trading_master_roi_upper'),
        accent: const Color(0xFFF79009),
        accentSoft: const Color(0xFFFFF1E0),
        value: '${roi.currentPct.toStringAsFixed(2)}%',
        pill: _TrendPill(value: roi.currentPct, suffix: '%'),
        sub: TranslationUtils.trArgs('copy_trading_benchmark_value', {
          'value': roi.benchmarkPct.isEmpty ? '—' : roi.benchmarkPct,
        }),
        spark: roi.series.values,
      ),
    ];

    // Use LayoutBuilder so we can pick a tile *height* that fits the
    // content (label + value + 2-line sub + sparkline) regardless of the
    // physical screen width. Earlier we used `childAspectRatio: 1.45`,
    // which produced ~109dp tall tiles on a 360dp-wide phone and made the
    // KPI content (~150dp) overflow by 14-30px.
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        const tileHeight = 158.0;
        final ratio = tileWidth / tileHeight;
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: ratio,
          children: cards,
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.accent,
    required this.accentSoft,
    required this.value,
    required this.sub,
    this.pill,
    this.spark = const <num>[],
  });

  final String label;
  final String value;
  final String sub;
  final Color accent;
  final Color accentSoft;
  final _TrendPill? pill;
  final List<num> spark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pts = spark.map((e) => e.toDouble()).toList(growable: false);
    // Compact KPI tile: top accent stripe (full-width) replaces the old
    // left mini-bar, then label + trend pill, big bold value, tight sub
    // line, and a slim sparkline at the very bottom that hugs the card
    // edge with a soft tint fade — feels like a stock-market widget.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: _cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top accent stripe — pure color, full width.
            Container(height: 3, color: accent),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label row: uppercase label on the left, trend pill on
                  // the right (if any).
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ),
                      if (pill != null) pill!,
                    ],
                  ),
                  SizedBox(height: 6),
                  // Big value.
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      height: 1.1,
                      letterSpacing: -0.3,
                      color: AppColors.textGrey,
                    ),
                  ),
                  SizedBox(height: 2),
                  // Sub.
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      height: 1.25,
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Sparkline strip at the bottom — flush to card edge.
            SizedBox(
              height: 28,
              child:
                  pts.length < 2
                      ? const SizedBox.shrink()
                      : CustomPaint(
                        size: Size.infinite,
                        painter: _SparklinePainter(
                          points: pts,
                          color: accent,
                          fillColor: accentSoft,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({
    required this.value,
    this.suffix = '%',
    this.signed = false,
    this.isInt = false,
  });

  final num value;
  final String suffix;
  final bool signed;
  final bool isInt;

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = positive ? AppColors.successText : AppColors.error;
    final soft = positive ? AppColors.successBg : AppColors.errorBg;

    String text;
    if (isInt) {
      text = '${value >= 0 ? '+' : ''}${value.toInt()}';
    } else {
      final absVal = value.abs().toDouble();
      text =
          '${positive ? '↗' : '↘'} '
          '${absVal.toStringAsFixed(2)}$suffix';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyText.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.color,
    required this.fillColor,
  });
  final List<double> points;
  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (points.length - 1);

    final path = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - ((points[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fillColor.withValues(alpha: 0.6),
            fillColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => true;
}

// ===========================================================================
// Performance overview chart
// ===========================================================================

class _PerformanceChartCard extends StatefulWidget {
  const _PerformanceChartCard({required this.overview});
  final CopyTradingDashboardOverview overview;

  @override
  State<_PerformanceChartCard> createState() => _PerformanceChartCardState();
}

class _PerformanceChartCardState extends State<_PerformanceChartCard> {
  String _series = 'equity'; // equity | aum | pnl

  List<double> _parseSeries(List<dynamic>? raw) {
    if (raw == null) return [];
    return raw
        .where((e) => e != null)
        .map((e) => (e is num) ? e.toDouble() : double.tryParse('$e') ?? 0)
        .toList();
  }

  List<double> get _selectedSeries {
    final c = widget.overview.mainChart;
    switch (_series) {
      case 'aum':
        return _parseSeries(c.aum);
      case 'pnl':
        return _parseSeries(c.netPnl);
      case 'equity':
      default:
        return _parseSeries(c.equity);
    }
  }

  Color get _seriesColor {
    switch (_series) {
      case 'aum':
        return const Color(0xFF00BFA6);
      case 'pnl':
        return const Color(0xFF1DB954);
      case 'equity':
      default:
        return const Color(0xFF2C5FFB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = _selectedSeries;
    final hasData = points.length > 1;
    final labels = widget.overview.mainChart.labels;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationUtils.tr('master_dashboard_overview_tab_performance_overview'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
            ),
          ),
          SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ChartToggle(
                  label: TranslationUtils.tr('general_equity'),
                  selected: _series == 'equity',
                  color: const Color(0xFF2C5FFB),
                  onTap: () => setState(() => _series = 'equity'),
                ),
                SizedBox(width: 8),
                _ChartToggle(
                  label: TranslationUtils.tr('pmam_aum'),
                  selected: _series == 'aum',
                  color: const Color(0xFF00BFA6),
                  onTap: () => setState(() => _series = 'aum'),
                ),
                SizedBox(width: 8),
                _ChartToggle(
                  label: TranslationUtils.tr('meta_trade_net_pl'),
                  selected: _series == 'pnl',
                  color: const Color(0xFF1DB954),
                  onTap: () => setState(() => _series = 'pnl'),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 200,
            child:
                hasData
                    ? CustomPaint(
                      size: Size.infinite,
                      painter: _AreaChartPainter(
                        points: points,
                        color: _seriesColor,
                      ),
                    )
                    : Center(
                      child: Text(
                        TranslationUtils.tr('master_dashboard_overview_tab_no_performance_data_for_this_range'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
          ),
          SizedBox(height: 8),
          if (labels.length >= 2) _ChartXAxis(labels: labels),
        ],
      ),
    );
  }
}

class _ChartToggle extends StatelessWidget {
  const _ChartToggle({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : theme.dividerColor.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.textGreyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.points, required this.color});
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (points.length - 1);

    final gridPaint =
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.05)
          ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (minV < 0 && maxV > 0) {
      final y0 = size.height - ((0 - minV) / range) * size.height;
      final zeroPaint =
          Paint()
            ..color = const Color(0xFF000000).withValues(alpha: 0.15)
            ..strokeWidth = 1;
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), zeroPaint);
    }

    final line = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - ((points[i] - minV) / range) * size.height;
      if (i == 0) {
        line.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  // Always repaint. Painters are cheap and this guarantees the chart
  // refreshes whenever the parent passes a new `points` list (e.g. on
  // range switch or mode toggle). Reference comparison was unreliable
  // because backend lists were occasionally the same length with the
  // same trailing zeros, so the painter cached stale curves.
  @override
  bool shouldRepaint(covariant _AreaChartPainter old) => true;
}

class _ChartXAxis extends StatelessWidget {
  const _ChartXAxis({required this.labels});
  final List<String> labels;

  /// Compact a backend label like "2026-06-01 00:00" → "Jun 01".
  /// Falls back to the original string if parsing fails.
  String _short(String raw, {required bool intraday}) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    // "Today" buckets are hourly within one date, so the day would repeat on
    // every tick; show the bucket time instead.
    if (intraday) return _time.format(dt);
    const monthKeys = [
      'month_short_jan',
      'month_short_feb',
      'month_short_mar',
      'month_short_apr',
      'month_short_may',
      'month_short_jun',
      'month_short_jul',
      'month_short_aug',
      'month_short_sep',
      'month_short_oct',
      'month_short_nov',
      'month_short_dec',
    ];
    final mm = TranslationUtils.tr(monthKeys[dt.month - 1]);
    final dd = dt.day.toString().padLeft(2, '0');
    return '$mm $dd';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (labels.length < 2) return const SizedBox.shrink();

    // Pick 4 evenly-spaced ticks. Using indices instead of stride avoids
    // the last label landing flush-right (and overflowing the chart width).
    const tickCount = 4;
    final picks = <int>{};
    for (var i = 0; i < tickCount; i++) {
      picks.add(((labels.length - 1) * i / (tickCount - 1)).round());
    }
    final indices = picks.toList()..sort();
    final first = DateTime.tryParse(labels.first);
    final last = DateTime.tryParse(labels.last);
    final intraday =
        first != null &&
        last != null &&
        DateUtils.isSameDay(first, last);

    return Row(
      children: [
        for (var n = 0; n < indices.length; n++)
          Expanded(
            child: Text(
              _short(labels[indices[n]], intraday: intraday),
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign:
                  n == 0
                      ? TextAlign.start
                      : (n == indices.length - 1
                          ? TextAlign.end
                          : TextAlign.center),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: AppColors.textGreyDark,
              ),
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// Copier health
// ===========================================================================

class _CopierHealthCard extends StatelessWidget {
  const _CopierHealthCard({required this.health});
  final DashboardCopierHealth health;

  String _avgAgeLabel(int days) {
    if (days <= 0) return '—';
    if (days < 30) return '${days}d';
    if (days < 365) {
      final m = (days / 30).round();
      return '${m}mo';
    }
    final y = (days / 365).toStringAsFixed(1);
    return '${y}y';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = health.active + health.paused + health.stopped;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationUtils.tr('master_dashboard_overview_tab_copier_health'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: [
                      _DonutSegment(health.active, const Color(0xFF1DB954)),
                      _DonutSegment(health.paused, const Color(0xFFF79009)),
                      _DonutSegment(health.stopped, const Color(0xFFE5484D)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$total',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendDot(
                      color: const Color(0xFF1DB954),
                      label: TranslationUtils.tr('wallet_active'),
                      value: health.active,
                    ),
                    SizedBox(height: 6),
                    _LegendDot(
                      color: const Color(0xFFF79009),
                      label: TranslationUtils.tr('copy_trading_paused'),
                      value: health.paused,
                    ),
                    SizedBox(height: 6),
                    _LegendDot(
                      color: const Color(0xFFE5484D),
                      label: TranslationUtils.tr('copy_trading_stopped'),
                      value: health.stopped,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CopierStat(
                  label: TranslationUtils.tr('copy_trading_new_window_upper'),
                  value: '${health.newInWindow}',
                ),
              ),
              Expanded(
                child: _CopierStat(
                  label: TranslationUtils.tr('copy_trading_churned_upper'),
                  value: '${health.churnedInWindow}',
                ),
              ),
              Expanded(
                child: _CopierStat(
                  label: TranslationUtils.tr('copy_trading_avg_age_upper'),
                  value: _avgAgeLabel(health.avgAgeDays),
                ),
              ),
              Expanded(
                child: _CopierStat(
                  label: TranslationUtils.tr('copy_trading_retention_upper'),
                  value: '${health.retentionPct.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutSegment {
  const _DonutSegment(this.value, this.color);
  final int value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments});
  final List<_DonutSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) {
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..color = AppColors.border;
      final rect = Offset.zero & size;
      canvas.drawArc(rect.deflate(6), 0, 6.283, false, paint);
      return;
    }

    final rect = Offset.zero & size;
    const stroke = 12.0;
    var start = -1.5708;
    for (final seg in segments) {
      if (seg.value == 0) continue;
      final sweep = (seg.value / total) * 6.2831853;
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt
            ..color = seg.color;
      canvas.drawArc(rect.deflate(stroke / 2), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          '$value',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CopierStat extends StatelessWidget {
  const _CopierStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Plan performance
// ===========================================================================

class _PlanPerformanceCard extends StatelessWidget {
  const _PlanPerformanceCard({required this.plans});
  final List<DashboardPlanRow> plans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  TranslationUtils.tr('master_dashboard_overview_tab_plan_performance'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (plans.isNotEmpty)
                _CountBadge(count: plans.length),
            ],
          ),
          SizedBox(height: 10),
          if (plans.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                TranslationUtils.tr('master_dashboard_overview_tab_no_plans_yet'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textGrey,
                ),
              ),
            )
          else
            for (var i = 0; i < plans.length; i++) ...[
              if (i > 0) SizedBox(height: 10),
              _PlanRow(plan: plans[i]),
            ],
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// One plan: initial avatar · name + status chip · ROI pill, then AUM and
/// copiers underneath. Everything flexes so long names ellipsize on narrow
/// phones and the tile stretches on folds/tablets.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});
  final DashboardPlanRow plan;

  Color get _roiColor {
    if (plan.roiPct > 0) return AppColors.green;
    if (plan.roiPct < 0) return AppColors.error;
    return AppColors.textGrey;
  }

  Color get _statusColor {
    switch (plan.status.toLowerCase()) {
      case 'approved':
      case 'active':
        return AppColors.green;
      case 'rejected':
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String get _statusLabel => plan.status.isEmpty
      ? '—'
      : plan.status[0].toUpperCase() + plan.status.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = plan.roiPct >= 0;
    final initial =
        plan.planName.trim().isEmpty ? '?' : plan.planName.trim()[0].toUpperCase();

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tradeBackgroundCenterColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  initial,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 5),
                        Text(
                          _statusLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _roiColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Text(
                    '${positive ? '+' : ''}${plan.roiPct.toStringAsFixed(2)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _roiColor,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PlanMiniStat(
                  icon: Icons.account_balance_wallet_outlined,
                  label: TranslationUtils.tr('pmam_manager_dashboard_screen_total_aum'),
                  value: _fmtMoney(plan.totalCapital),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _PlanMiniStat(
                  icon: Icons.people_alt_outlined,
                  label: TranslationUtils.tr('my_plans_tab_copiers'),
                  value: '${plan.activeCopiersCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanMiniStat extends StatelessWidget {
  const _PlanMiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textGrey),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textGrey,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Payouts
// ===========================================================================

class _PayoutsCard extends StatelessWidget {
  const _PayoutsCard({required this.payouts});
  final DashboardPayouts payouts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  TranslationUtils.tr('ibm_payouts'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Get.to(() => const MasterSettlementsScreen()),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TranslationUtils.tr('pmam_fund_manager_view_view_all'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PayoutStat(
                  icon: Icons.trending_up_rounded,
                  color: AppColors.green,
                  label: TranslationUtils.tr('copy_trading_earned_window_upper'),
                  value: _fmtMoney(payouts.earnedInWindow),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _PayoutStat(
                  icon: Icons.hourglass_bottom_rounded,
                  color: AppColors.warning,
                  label: TranslationUtils.tr('copy_trading_pending_upper'),
                  value: _fmtMoney(payouts.pending),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _PayoutSection(
            title: TranslationUtils.tr('copy_trading_upcoming_upper'),
            emptyText: TranslationUtils.tr(
              'master_dashboard_overview_tab_no_upcoming_payouts',
            ),
            items: payouts.upcoming,
          ),
          SizedBox(height: 14),
          _PayoutSection(
            title: TranslationUtils.tr('copy_trading_recent_upper'),
            emptyText: TranslationUtils.tr(
              'master_dashboard_overview_tab_no_recent_payouts',
            ),
            items: payouts.recent,
          ),
        ],
      ),
    );
  }
}

class _PayoutStat extends StatelessWidget {
  const _PayoutStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  // Two lines so "EARNED (WINDOW)" isn't cut on narrow tiles.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutSection extends StatelessWidget {
  const _PayoutSection({
    required this.title,
    required this.emptyText,
    required this.items,
  });
  final String title;
  final String emptyText;
  final List<DashboardPayoutItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textGrey,
          ),
        ),
        SizedBox(height: 6),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tradeBackgroundCenterColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textGrey,
              ),
            ),
          )
        else
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.12),
              ),
            _PayoutRow(item: items[i]),
          ],
      ],
    );
  }
}

/// Status icon · status + date · amount. Paid = green, pending = amber,
/// anything else (failed/cancelled) = red.
class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.item});
  final DashboardPayoutItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item.status.toLowerCase();
    final (Color color, IconData icon, String label) = switch (status) {
      'paid' || 'settled' || 'completed' => (
          AppColors.green,
          Icons.check_circle_rounded,
          TranslationUtils.tr('ibm_status_paid'),
        ),
      'pending' || 'scheduled' || 'upcoming' => (
          AppColors.warning,
          Icons.schedule_rounded,
          TranslationUtils.tr('ibm_status_pending'),
        ),
      _ => (
          AppColors.error,
          Icons.error_outline_rounded,
          item.status.isEmpty ? '—' : item.status.toUpperCase(),
        ),
    };

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  _fmtDate(item.date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            _fmtMoney(item.amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Recent trades
// ===========================================================================

class _RecentTradesCard extends StatelessWidget {
  const _RecentTradesCard({required this.trades});
  final List<DashboardRecentTrade> trades;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationUtils.tr('master_dashboard_overview_tab_recent_trades'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          if (trades.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                TranslationUtils.tr('master_dashboard_overview_tab_no_trades_yet'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < trades.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.12),
                ),
              _TradeRow(trade: trades[i]),
            ],
        ],
      ),
    );
  }
}

/// One recent trade: side icon · symbol + BUY/SELL chip · date/time/lots · P&L.
/// Only the P&L has an intrinsic width; everything else flexes, so long
/// symbols ellipsize instead of wrapping on narrow phones.
class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.trade});
  final DashboardRecentTrade trade;

  /// `ts` is UTC (`+00:00`); null when it can't be parsed.
  DateTime? get _localTs => DateTime.tryParse(trade.ts)?.toLocal();

  String _lotsLabel() {
    final lots = trade.lots;
    if (lots == 0) return '0';
    // Trim trailing zeros: 0.20 → 0.2, 1.00 → 1
    final s = lots.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  String _pnlLabel() {
    final v = trade.pnl;
    final sign = v > 0 ? '+' : (v < 0 ? '-' : '');
    return '$sign\$${v.abs().toStringAsFixed(2)}';
  }

  String _metaLabel() {
    final ts = _localTs;
    final when = ts == null
        ? trade.ts
        : '${_shortDate.format(ts)} · ${_time.format(ts)}';
    return '$when · ${_lotsLabel()} ${TranslationUtils.tr('trading_order_lots')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBuy = trade.side.toLowerCase() == 'buy';
    final sideColor = isBuy ? AppColors.green : AppColors.error;
    final pnlColor = trade.pnl > 0
        ? AppColors.green
        : trade.pnl < 0
            ? AppColors.error
            : AppColors.textPrimary;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: sideColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isBuy ? Icons.north_east_rounded : Icons.south_east_rounded,
              size: 18,
              color: sideColor,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trade.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: sideColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBuy ? 'BUY' : 'SELL',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: sideColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  _metaLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            _pnlLabel(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: pnlColor,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Risk alerts
// ===========================================================================

class _RiskAlertsCard extends StatelessWidget {
  const _RiskAlertsCard({required this.alerts});
  final List<DashboardAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationUtils.tr('master_dashboard_overview_tab_risk_alerts'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 10),
          if (alerts.isEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.successText,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      TranslationUtils.tr('master_dashboard_overview_tab_all_clear_no_risk_alerts_in'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            ...alerts.map((a) => _AlertRow(alert: a)),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final DashboardAlert alert;

  Color get _soft {
    switch (alert.level) {
      case 'critical':
        return AppColors.errorBg;
      case 'warning':
        return AppColors.warningBg;
      case 'info':
        return AppColors.primary.withValues(alpha: 0.10);
      default:
        return AppColors.warningBg;
    }
  }

  Color get _accent {
    switch (alert.level) {
      case 'critical':
        return AppColors.error;
      case 'info':
        return AppColors.primary;
      case 'warning':
      default:
        return AppColors.warningText;
    }
  }

  IconData get _icon {
    switch (alert.level) {
      case 'critical':
        return Icons.error_outline_rounded;
      case 'info':
        return Icons.info_outline_rounded;
      case 'warning':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _accent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              alert.message,
              style: theme.textTheme.bodyMedium?.copyWith(color: _accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Misc
// ===========================================================================

// Cards: pure white surface + 1px shadow-tinted hairline border + soft drop
// shadow. The border is the same color family as the shadow (a low-alpha
// black), so the edge reads as the "outer shadow line" — gives the card a
// crisp, modern, slightly elevated look without feeling boxed-in.
BoxDecoration _cardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: AppColors.textPrimary.withValues(alpha: 0.06),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: AppColors.textPrimary.withValues(alpha: 0.03),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 48),
            SizedBox(height: 8),
            Text(
              TranslationUtils.tr(
                'master_dashboard_overview_tab_no_overview_data_available',
              ),
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: Text(TranslationUtils.tr('common_retry')),
            ),
          ],
        ),
      ),
    );
  }
}
