import 'dart:async';
import 'dart:math' as math;

import 'package:crm_app/services/language_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';

/// Native MetaTrader-style chart for the New Order screen.
///
/// Subscribes to the active [ChartSocketController.priceStream] and renders
/// two line series — **ask (red)** on top, **bid (blue)** below — with
/// right-axis price labels, a faint grid, and a last-tick marker badge on
/// the right edge showing the latest ask/bid values.
///
/// Free of any webview. Driven 100% by your MT5 websocket ticks.
///
/// **Data-integrity rules:**
///   • Ticks must include BOTH a non-zero bid AND ask.
///   • Ticks must declare a `symbol` that matches (after suffix stripping).
///   • The chart only renders once we have at least 2 ticks for our symbol
///     (single-tick renders were misleading the user with stale/cached
///     prices from a previous symbol — see screenshot regression).
///   • Until then, a clean "Waiting for ticks…" placeholder is shown.
class MetaNativeChart extends StatefulWidget {
  const MetaNativeChart({
    super.key,
    required this.symbol,
    this.maxPoints = 180,
  });

  final String symbol;

  /// Number of ticks retained in the rolling window.
  final int maxPoints;

  @override
  State<MetaNativeChart> createState() => _MetaNativeChartState();
}

class _MetaNativeChartState extends State<MetaNativeChart> {
  late final ChartSocketController _socket;
  StreamSubscription<Map<String, dynamic>>? _sub;

  /// FIFO ring buffer of ask + bid ticks, captured at chart-open time.
  final List<_Tick> _ticks = <_Tick>[];

  /// Tick counter used as the X coordinate (monotonic).
  int _x = 0;

  @override
  void initState() {
    super.initState();
    _socket = Get.find<ChartSocketController>();

    // ✅ Do NOT seed from realTimePrice — a cached tick from a previous
    // symbol (e.g. USDJPY) would render garbage on the EURJPY chart
    // (collapses Y-axis to ±0.5 or worse). Instead, wait for the first
    // real, symbol-matched tick to arrive over the websocket, then
    // render. The placeholder is much friendlier than a flat red line
    // at y=0 over a 4000-pip Y-range.
    _sub = _socket.priceStream.listen(_onTick);
  }

  void _onTick(Map<String, dynamic> m) {
    if (!mounted) return;
    final a = _asDouble(m['ask']);
    final b = _asDouble(m['bid']);
    // Reject garbage: zero bid/ask or zero/missing symbol.
    if (a == null || b == null || a <= 0 || b <= 0) return;
    if (!_isForOurSymbol(m)) return;
    setState(() => _push(_Tick(_x++, b, a)));
  }

  bool _isForOurSymbol(Map<String, dynamic> m) {
    final s = m['symbol']?.toString();
    // Reject ticks with no symbol declared — they cannot be matched to
    // our symbol reliably and were the source of "phantom" ticks that
    // broke the chart's Y-axis.
    if (s == null || s.isEmpty) return false;
    return s == widget.symbol ||
        s == _stripSuffix(widget.symbol) ||
        _stripSuffix(s) == _stripSuffix(widget.symbol);
  }

  static String _stripSuffix(String s) =>
      s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;

  @override
  void didUpdateWidget(covariant MetaNativeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the symbol changed (e.g. user picked a different instrument),
    // drop the existing tick buffer so the chart starts fresh for the
    // new symbol — never mixing EURJPY ticks with the new USDJPY
    // subscription.
    if (oldWidget.symbol != widget.symbol) {
      _ticks.clear();
      _x = 0;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _push(_Tick t) {
    _ticks.add(t);
    if (_ticks.length > widget.maxPoints) {
      _ticks.removeAt(0);
    }
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int get _digits {
    final d = _socket.realTimePrice['digits'];
    if (d is int) return d;
    if (d is num) return d.toInt();
    if (d is String) return int.tryParse(d) ?? 3;
    return 3;
  }

  String _fmt(double v) {
    final dec = math.max(0, math.min(_digits, 5));
    return v.toStringAsFixed(dec);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Require at least 2 ticks before showing any chart — a single
    // tick produces a horizontal line at one Y value which is
    // uninformative at best and misleading at worst. The "Waiting for
    // ticks…" placeholder flashes for ~1–2 ticks (sub-second).
    if (_ticks.length < 2) {
      return _placeholder();
    }
    // Live bid/ask tick chart: the fl_chart geometry, the right-hand price
    // axis and the price labels are all laid out left-to-right, so this
    // subtree must not be mirrored in Arabic.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.only(right: 8.w, top: 4.h, bottom: 4.h),
        child: _buildChart(),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Text(
        Get.find<LanguageService>().tr('meta_chart_waiting_ticks'),
        style: AppTextStyles.label.copyWith(
          fontSize: 12.sp,
          color: AppColors.textGrey,
        ),
      ),
    );
  }

  // ──── Chart layout ───────────────────────────────────────────────────────

  Widget _buildChart() {
    final askLine = <FlSpot>[];
    final bidLine = <FlSpot>[];
    var minY = double.infinity;
    var maxY = -double.infinity;

    for (final t in _ticks) {
      askLine.add(FlSpot(t.x.toDouble(), t.ask));
      bidLine.add(FlSpot(t.x.toDouble(), t.bid));
      if (t.ask < minY) minY = t.ask;
      if (t.bid < minY) minY = t.bid;
      if (t.ask > maxY) maxY = t.ask;
      if (t.bid > maxY) maxY = t.bid;
    }

    final last = _ticks.last;
    // Pad range so the line never touches the chart edges. Use a
    // pip-aware padding that works for both 4-digit forex pairs and
    // 5-digit FX / 2-digit JPY pairs.
    final range = (maxY - minY).abs();
    if (range < 1e-9) {
      // Defensive: shouldn't happen because we require >= 2 ticks,
      // but keep the branch to avoid NaN/divide-by-zero in fl_chart.
      final pip = math.pow(10, -_digits).toDouble();
      final flatPad = math.max(pip * 50, maxY.abs() * 0.0005 + pip);
      minY -= flatPad;
      maxY += flatPad;
    } else {
      final pad = range * 0.1;
      minY -= pad;
      maxY += pad;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: _ticks.first.x.toDouble(),
              maxX: _ticks.last.x.toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 5,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.border.withOpacity(0.45),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56.w,
                    interval: (maxY - minY) / 5,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: EdgeInsets.only(left: 4.w),
                        child: Text(
                          _fmt(value),
                          textAlign: TextAlign.right,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: bidLine,
                  isCurved: false,
                  barWidth: 1.4.w,
                  color: const Color(0xFF1877F2), // bid = blue
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: askLine,
                  isCurved: false,
                  barWidth: 1.4.w,
                  color: const Color(0xFFD72E1F), // ask = red
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
            duration: Duration.zero,
          ),
        ),
        // Last-tick marker badges on the right edge.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _LastTickMarker(
            value: last.ask,
            color: const Color(0xFFD72E1F),
            fmt: _fmt,
            ratio: ((maxY - last.ask) / (maxY - minY)).clamp(0.0, 1.0),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _LastTickMarker(
            value: last.bid,
            color: const Color(0xFF1877F2),
            fmt: _fmt,
            ratio: ((maxY - last.bid) / (maxY - minY)).clamp(0.0, 1.0),
            offsetDown: 18.h,
          ),
        ),
      ],
    );
  }
}

class _Tick {
  _Tick(this.x, this.bid, this.ask);
  final int x;
  final double bid;
  final double ask;
}

/// Right-edge price tag that tracks its Y position via a ratio (0..1)
/// computed from the data range — same trick MetaTrader mobile uses.
class _LastTickMarker extends StatelessWidget {
  const _LastTickMarker({
    required this.value,
    required this.color,
    required this.fmt,
    required this.ratio,
    this.offsetDown = 0,
  });

  final double value;
  final Color color;
  final String Function(double) fmt;
  final double ratio;
  final double offsetDown;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final usable = c.maxHeight - 24.h; // padding
        final top = (usable * ratio).clamp(0.0, usable) - 9.h + offsetDown;
        return Stack(
          children: [
            Positioned(
              right: 0,
              top: top,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3.r),
                ),
                child: Text(
                  fmt(value),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.whiteColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
