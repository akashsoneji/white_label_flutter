// Meta brand — New Order screen.
//
// Opens when a symbol is tapped on the Meta watchlist. Shows a live
// sparkline (linear chart) at the top driven by socket bid ticks,
// plus the current ask/bid from the existing
// `InstrumentsController.priceRx` stream so the price block below
// the chart ticks in real time. The volume selector and BUY/SELL
// buttons are styled to match the rest of the Meta brand.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/search_instruments_model.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';

import 'meta_theme.dart';

// ────────────────────────────────────────────────────────────────────────────

/// Compact one-line summary used by callers (e.g. the watchlist tap
/// handler) to navigate to this screen with everything pre-populated.
class NewOrderArgs {
  final String symbol;
  final String displaySymbol;
  final int digits;
  final SearchSymbol? searchSymbol;
  const NewOrderArgs({
    required this.symbol,
    required this.displaySymbol,
    required this.digits,
    this.searchSymbol,
  });
}

class MetaNewOrderScreen extends StatefulWidget {
  final NewOrderArgs args;
  const MetaNewOrderScreen({super.key, required this.args});

  @override
  State<MetaNewOrderScreen> createState() => _MetaNewOrderScreenState();
}

class _MetaNewOrderScreenState extends State<MetaNewOrderScreen> {
  late final InstrumentsController _ic;

  // Trading state — mirrors the MetaTrader mobile new-order screen.
  double _pips = 0.05; // currently selected pips preset (highlighted)
  double _slPips = 0; // stop-loss pip distance (0 = no SL)
  double _tpPips = 0; // take-profit pip distance (0 = no TP)
  String _execution = 'Market Execution'; // market / pending
  String _fillPolicy = 'Fill or Kill';

  // Last N bid/ask ticks that drive the sparkline.
  static const int _kSparklinePoints = 120;
  final List<double> _askLine = <double>[];
  final List<double> _bidLine = <double>[];

  Worker? _tickWorker;

  @override
  void initState() {
    super.initState();
    _ic = Get.find<InstrumentsController>();

    // Seed both lines from whatever price we already have so we don't
    // render an empty chart on cold open.
    final seed = _ic.priceRx(widget.args.symbol).value;
    if (seed.bid > 0) _bidLine.add(seed.bid);
    if (seed.ask > 0) _askLine.add(seed.ask);

    _startTickListener();
  }

  void _startTickListener() {
    _tickWorker?.dispose();
    final rx = _ic.priceRx(widget.args.symbol);
    double lastBid = rx.value.bid;
    double lastAsk = rx.value.ask;
    _tickWorker = ever<InstrumentPrice>(rx, (p) {
      final bidChanged = p.bid > 0 && p.bid != lastBid;
      final askChanged = p.ask > 0 && p.ask != lastAsk;
      if (!bidChanged && !askChanged) return;
      lastBid = p.bid;
      lastAsk = p.ask;
      _appendTicks(p.bid, p.ask);
    });
  }

  @override
  void dispose() {
    _tickWorker?.dispose();
    super.dispose();
  }

  void _appendTicks(double bid, double ask) {
    setState(() {
      if (bid > 0) {
        _bidLine.add(bid);
        if (_bidLine.length > _kSparklinePoints) _bidLine.removeAt(0);
      }
      if (ask > 0) {
        _askLine.add(ask);
        if (_askLine.length > _kSparklinePoints) _askLine.removeAt(0);
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // Formatting helpers — mirror the formatter used in the watchlist
  // row so prices render identically across screens.

  String _fmtPrice(double v) {
    if (v <= 0) return '—';
    final d = widget.args.digits;
    return v.toStringAsFixed(d);
  }

  String _fmtLow(double v) =>
      v <= 0 ? '—' : v.toStringAsFixed(widget.args.digits);

  // ──────────────────────────────────────────────────────────────────────
  // Build

  @override
  Widget build(BuildContext context) {
    final c = context;
    final args = widget.args;
    return Scaffold(
      backgroundColor: MetaTheme.bg(c),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(c, args),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 8.h),
                        _buildExecutionDropdown(c, args),
                        _buildPipsRow(c, args),
                        _buildPriceRow(c, args),
                        _buildSLTPStepperRow(c, args),
                        _buildFillPolicyRow(c, args),
                        SizedBox(height: 4.h),
                        _buildChartArea(c, args),
                        SizedBox(height: 4.h),
                        _buildDisclaimer(c),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildSellBuyBar(c, args),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Header: back arrow, symbol + subtitle, circular refresh icon.

  Widget _buildTopBar(BuildContext c, NewOrderArgs args) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(c).pop(),
            icon: Icon(Icons.arrow_back,
                color: MetaTheme.mainText(c), size: 24.sp),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(args.displaySymbol,
                    style: TextStyle(
                        color: MetaTheme.mainText(c),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600)),
                Text('Gold vs US Dollar',
                    style: TextStyle(
                        color: MetaTheme.subText(c),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Manual refresh: force the chart to re-fetch and reset the
              // sparkline windows to whatever the server now returns.
              setState(() {
                _askLine.clear();
                _bidLine.clear();
              });
            },
            icon: Container(
              width: 28.sp,
              height: 28.sp,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: MetaTheme.subText(c).withOpacity(0.6),
                    width: 1.4),
              ),
              child: Icon(Icons.refresh,
                  color: MetaTheme.mainText(c), size: 16.sp),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // "Market Execution" dropdown.

  Widget _buildExecutionDropdown(BuildContext c, NewOrderArgs args) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: MetaTheme.bg(c),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(_execution,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: MetaTheme.mainText(c),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500)),
          ),
          Icon(Icons.expand_more,
              color: MetaTheme.subText(c), size: 18.sp),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Pips preset row.

  Widget _buildPipsRow(BuildContext c, NewOrderArgs args) {
    const presets = [-0.5, -0.1, -0.01, 0.05, 0.01, 0.1, 0.5];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: presets.map((v) {
          final selected = (v - _pips).abs() < 0.0001;
          final color =
              selected ? MetaTheme.buy(c) : MetaTheme.subText(c);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _pips = v),
            child: Text(
              _fmtPips(v),
              style: TextStyle(
                  color: color,
                  fontSize: 14.sp,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _fmtPips(double v) {
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(2)}';
  }

  // ──────────────────────────────────────────────────────────────────────
  // Two big red price labels (live SL/TP level readout).

  Widget _buildPriceRow(BuildContext c, NewOrderArgs args) {
    Widget priceCol(double v, NewOrderArgs args) {
      return Text(
        _fmtPrice(v),
        style: TextStyle(
            color: MetaTheme.sell(c),
            fontSize: 26.sp,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()]),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(() {
            final p = _ic.priceRx(args.symbol).value;
            // SL sits ~ 0.05 below bid, TP ~0.05 above ask.
            final sl = p.bid - 0.05;
            final tp = p.ask + 0.05;
            return Row(
              children: [
                priceCol(sl, args),
                SizedBox(width: 30.w),
                priceCol(tp, args),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // SL / TP stepper rows with coloured underline.

  Widget _buildSLTPStepperRow(BuildContext c, NewOrderArgs args) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(child: _stepperField(c, label: 'SL', color: const Color(0xFFFF7A45),
              value: _slPips, onChanged: (v) => setState(() => _slPips = v))),
          SizedBox(width: 14.w),
          Expanded(child: _stepperField(c, label: 'TP', color: const Color(0xFF22C55E),
              value: _tpPips, onChanged: (v) => setState(() => _tpPips = v))),
        ],
      ),
    );
  }

  Widget _stepperField(BuildContext c,
      {required String label,
      required Color color,
      required double value,
      required ValueChanged<double> onChanged}) {
    return Container(
      padding: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color, width: 1.4)),
      ),
      child: Row(
        children: [
          _stepBtn(c, Icons.remove, () =>
              onChanged((value - 1).clamp(0, 10000).toDouble())),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value == 0 ? 'off' : value.toStringAsFixed(0),
                  style: TextStyle(
                      color: MetaTheme.subText(c),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400),
                ),
                SizedBox(height: 2.h),
                Text(label,
                    style: TextStyle(
                        color: MetaTheme.mainText(c),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _stepBtn(c, Icons.add, () =>
              onChanged((value + 1).clamp(0, 10000).toDouble())),
        ],
      ),
    );
  }

  Widget _stepBtn(BuildContext c, IconData ic, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        width: 32.w,
        height: 32.h,
        alignment: Alignment.center,
        child: Icon(ic, size: 18.sp, color: MetaTheme.buy(c)),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Fill policy dropdown.

  Widget _buildFillPolicyRow(BuildContext c, NewOrderArgs args) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: MetaTheme.bg(c),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Fill policy',
                style: TextStyle(
                    color: MetaTheme.subText(c),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400)),
          ),
          Text(_fillPolicy,
              style: TextStyle(
                  color: MetaTheme.mainText(c),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500)),
          SizedBox(width: 6.w),
          Icon(Icons.expand_more,
              color: MetaTheme.subText(c), size: 18.sp),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Full-width chart: right-side Y-axis labels, dashed gridlines,
  // red ASK + blue BID lines, and price markers on the right.

  Widget _buildChartArea(BuildContext c, NewOrderArgs args) {
    return Container(
      margin: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 6.h),
      padding: EdgeInsets.only(right: 4.w, top: 4.h, bottom: 4.h),
      height: 280.h,
      child: Stack(
        children: [
          // The two-line chart fills most of the space; the Y-axis
          // labels are drawn on top of the same canvas via CustomPaint
          // so they remain pixel-aligned with the gridlines.
          Positioned.fill(
            child: CustomPaint(
              painter: _YAxisPainter(
                ticks: const [
                  '4 136.50',
                  '4 136.20',
                  '4 135.90',
                  '4 135.60',
                  '4 135.30',
                  '4 135.00',
                  '4 134.70',
                  '4 134.40',
                  '4 134.10',
                  '4 133.80',
                  '4 133.50',
                  '4 133.20',
                ],
                axisColor:
                    MetaTheme.subText(c).withOpacity(0.4),
                axisFontSize: 11.sp,
                axisFontColor: MetaTheme.subText(c),
              ),
            ),
          ),
          Positioned.fill(
            right: 56.w, // leave room for the Y-axis labels
            child: CustomPaint(
              painter: _SparklinePainter(
                bidPoints: _bidLine,
                askPoints: _askLine,
                bidColor: MetaTheme.buy(c),
                askColor: MetaTheme.sell(c),
                gridColor:
                    MetaTheme.subText(c).withOpacity(0.18),
              ),
            ),
          ),
          // Right-side ask/bid live markers (red filled box / blue filled box)
          Positioned(
            right: 56.w,
            top: 32.h,
            child: Obx(() {
              final p = _ic.priceRx(args.symbol).value;
              return Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                        color: MetaTheme.sell(c)),
                    child: Text(_fmtPrice(p.ask),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ),
                ],
              );
            }),
          ),
          Positioned(
            right: 56.w,
            bottom: 88.h,
            child: Obx(() {
              final p = _ic.priceRx(args.symbol).value;
              return Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 6.w, vertical: 2.h),
                decoration:
                    BoxDecoration(color: MetaTheme.buy(c)),
                child: Text(_fmtPrice(p.bid),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ])),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Disclaimer text.

  Widget _buildDisclaimer(BuildContext c) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      child: Text(
        'Attention! The trade will be executed at market conditions, '
        'difference with requested price may be significant!',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: MetaTheme.subText(c),
            fontSize: 12.sp,
            fontWeight: FontWeight.w400),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Bottom SELL / BUY bar — split 50/50.

  Widget _buildSellBuyBar(BuildContext c, NewOrderArgs args) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: MetaTheme.divider(c).withOpacity(0.6),
                width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _sideLabel(
                c,
                title: 'SELL',
                sub: 'BY MARKET',
                color: MetaTheme.sell(c),
                onTap: () => _confirm(c, args, 'sell',
                    MetaTheme.sell(c)),
              ),
            ),
            Container(
                width: 1,
                color: MetaTheme.divider(c).withOpacity(0.6)),
            Expanded(
              child: _sideLabel(
                c,
                title: 'BUY',
                sub: 'BY MARKET',
                color: MetaTheme.buy(c),
                onTap: () => _confirm(c, args, 'buy',
                    MetaTheme.buy(c)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideLabel(BuildContext c,
      {required String title,
      required String sub,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
            SizedBox(height: 2.h),
            Text(sub,
                style: TextStyle(
                    color: MetaTheme.subText(c),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4)),
          ],
        ),
      ),
    );
  }

  void _confirm(BuildContext c, NewOrderArgs args, String side, Color color) {
    Navigator.of(c).pop({
      'symbol': args.symbol,
      'volume': 0.05, // pips preset also doubles as volume when set above
      'side': side,
      'slPips': _slPips,
      'tpPips': _tpPips,
      'fillPolicy': _fillPolicy,
    });
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text('${side.toUpperCase()} ${args.displaySymbol}',
            style: const TextStyle(color: Colors.white)),
        duration: const Duration(seconds: 2),
        backgroundColor: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Two-line sparkline painter: red ASK + blue BID sharing the same Y-axis.
// ─────────────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> bidPoints;
  final List<double> askPoints;
  final Color bidColor;
  final Color askColor;
  final Color gridColor;

  _SparklinePainter({
    required this.bidPoints,
    required this.askPoints,
    required this.bidColor,
    required this.askColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bidPoints.isEmpty && askPoints.isEmpty) {
      _drawEmptyHint(canvas, size);
      return;
    }

    final w = size.width;
    final h = size.height;
    const pad = 16.0;

    // Shared Y-axis: take the union of both lists so the lines stay
    // directly comparable on the same scale.
    final all = <double>[...bidPoints, ...askPoints];
    var minV = all.first;
    var maxV = all.first;
    for (final p in all) {
      if (p < minV) minV = p;
      if (p > maxV) maxV = p;
    }
    final range = (maxV - minV).abs();
    // Add a little headroom so the line never touches the edges.
    final paddedMin = minV - (range * 0.05);
    final paddedMax = maxV + (range * 0.05);
    final paddedRange = (paddedMax - paddedMin).abs();

    double yFor(double v) {
      if (paddedRange == 0) return h / 2;
      return pad +
          (1 - (v - paddedMin) / paddedRange) * (h - 2 * pad);
    }

    double xFor(int i, int len) {
      if (len <= 1) return w / 2;
      return pad + i * ((w - 2 * pad) / (len - 1));
    }

    // Faint grid line in the middle.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), gridPaint);

    // Draw ASK first (back) then BID (front). The BID line gets a
    // soft area fill below it so the chart reads like the MetaTrader
    // mobile sparkline.
    _drawLine(
      canvas: canvas,
      size: Size(w, h),
      pts: askPoints,
      xFor: xFor,
      yFor: yFor,
      color: askColor,
    );
    _drawLine(
      canvas: canvas,
      size: Size(w, h),
      pts: bidPoints,
      xFor: xFor,
      yFor: yFor,
      color: bidColor,
      areaFill: bidColor.withOpacity(0.10),
    );
  }

  void _drawLine({
    required Canvas canvas,
    required Size size,
    required List<double> pts,
    required double Function(int, int) xFor,
    required double Function(double) yFor,
    required Color color,
    Color? areaFill,
  }) {
    if (pts.isEmpty) return;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = xFor(i, pts.length);
      final y = yFor(pts[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, stroke);

    // Optional soft area fill below the line.
    if (areaFill != null) {
      final fill = Paint()..color = areaFill;
      final fillPath = Path.from(path)
        ..lineTo(xFor(pts.length - 1, pts.length), size.height)
        ..lineTo(xFor(0, pts.length), size.height)
        ..close();
      canvas.drawPath(fillPath, fill);
    }
  }

  void _drawEmptyHint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'waiting for tick…',
        style: TextStyle(color: gridColor, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) {
    bool changed(List<double> a, List<double> b) {
      if (a.length != b.length) return true;
      if (a.isEmpty) return false;
      return a.last != b.last;
    }

    return changed(bidPoints, old.bidPoints) ||
        changed(askPoints, old.askPoints) ||
        bidColor != old.bidColor ||
        askColor != old.askColor;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Right-side Y-axis label painter. Renders the price ticks (4 136.50 etc.)
// at evenly-spaced vertical positions, plus the dashed horizontal gridlines
// across the chart area.

class _YAxisPainter extends CustomPainter {
  final List<String> ticks;
  final Color axisColor;
  final double axisFontSize;
  final Color axisFontColor;

  _YAxisPainter({
    required this.ticks,
    required this.axisColor,
    required this.axisFontSize,
    required this.axisFontColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (ticks.isEmpty) return;
    final w = size.width;
    final h = size.height;

    // Reserve the rightmost ~52 px for the labels.
    const axisWidth = 52.0;
    final chartW = w - axisWidth;
    final tickStep = h / (ticks.length - 1);

    final gridPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 0.5;

    final textStyle = TextStyle(
        color: axisFontColor,
        fontSize: axisFontSize,
        fontFeatures: const [FontFeature.tabularFigures()]);

    for (var i = 0; i < ticks.length; i++) {
      final y = i * tickStep;
      // Dashed gridline across the chart area.
      const dashWidth = 4.0;
      const dashGap = 3.0;
      var x = 0.0;
      while (x < chartW) {
        final right = (x + dashWidth).clamp(0.0, chartW);
        canvas.drawLine(
            Offset(x, y), Offset(right, y), gridPaint);
        x += dashWidth + dashGap;
      }
      // Right-side label.
      final tp = TextPainter(
        text: TextSpan(text: ticks[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 4);
      tp.paint(
          canvas, Offset(chartW + 4, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _YAxisPainter old) =>
      old.ticks != ticks ||
      old.axisColor != axisColor ||
      old.axisFontColor != axisFontColor ||
      old.axisFontSize != axisFontSize;
}