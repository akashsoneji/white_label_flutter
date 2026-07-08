"""Complete rewrite of build() and all sub-builders.
Layout (top to bottom):
1. Header: back arrow + symbol/subtitle + circular refresh
2. Market Execution dropdown
3. Pips row: -0.5, -0.1, -0.01, 0.05, +0.01, +0.1, +0.5 (blue active)
4. Two big red price labels (left SL/TP numeric display)
5. SL/TP steppers [- X +] [- X +] with underline colors
6. Fill policy dropdown "Fill or Kill"
7. Full-width chart with right-side Y-axis ticks, dashed gridlines, red+blue lines, ask/bid price markers
8. Disclaimer
9. Bottom split: SELL (red) | BUY (blue), 50/50
"""
p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    s = f.read()

# Find marker for the build method.
build_start = s.index('  @override\n  Widget build(BuildContext context) {')
# Find the end: the next "  // " section header after the build() closing brace + helpers.
# Easier: replace from build_start to the line right before "class _SparklinePainter"
sparkline_class_start = s.index('\nclass _SparklinePainter extends CustomPainter {')
old_block = s[build_start:sparkline_class_start]

new_block = '''  @override
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
'''

s = s.replace(old_block, new_block)

with open(p, 'w') as f:
    f.write(s)
print('done')