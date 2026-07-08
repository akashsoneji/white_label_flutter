import 'dart:async';
import 'dart:math' as math;

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
/// right‑axis price labels, a faint grid, and a last‑tick marker badge on
/// the right edge showing the latest ask/bid values.
///
/// Free of any webview. Driven 100% by your MT5 websocket ticks.
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

    // Seed from whatever last known price we have.
    final seed = _socket.realTimePrice;
    final ask = _asDouble(seed['ask']);
    final bid = _asDouble(seed['bid']);
    if (ask != null && bid != null) {
      _push(_Tick(_x++, bid, ask));
    }

    _sub = _socket.priceStream.listen((m) {
      final a = _asDouble(m['ask']);
      final b = _asDouble(m['bid']);
      if (a == null || b == null) return;
      if (!_isForOurSymbol(m)) return;
      setState(() => _push(_Tick(_x++, b, a)));
    });
  }

  bool _isForOurSymbol(Map<String, dynamic> m) {
    final s = m['symbol']?.toString();
    if (s == null || s.isEmpty) return true;
    return s == widget.symbol ||
        s == _stripSuffix(widget.symbol) ||
        _stripSuffix(s) == _stripSuffix(widget.symbol);
  }

  static String _stripSuffix(String s) =>
      s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;

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
    if (d is String) return int.tryParse(d) ?? 5;
    return 5;
  }

  String _fmt(double v) {
    final dec = math.max(0, math.min(_digits, 5));
    return v.toStringAsFixed(dec);
  }

  @override
  Widget build(BuildContext context) {
    if (_ticks.isEmpty) {
      return _placeholder();
    }
    return Padding(
      padding: EdgeInsets.only(right: 8.w, top: 4.h, bottom: 4.h),
      child: _buildChart(),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Text(
        'Waiting for ticks…',
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
    // Pad range so the line never touches the chart edges.
    final pad = (maxY - minY).abs() * 0.1;
    if (pad <= 0) {
      minY -= 0.5;
      maxY += 0.5;
    } else {
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
                  dashArray: const [4, 4],
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
