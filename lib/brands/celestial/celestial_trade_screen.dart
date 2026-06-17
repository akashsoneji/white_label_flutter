import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'celestial_theme.dart';

double _d(String? v) => double.tryParse(v ?? '') ?? 0;
String _fmt(double v, int d) => v.toStringAsFixed(d);
String _fmtPL(double v) =>
    '${v < 0 ? '' : '+'}${v.toStringAsFixed(2)}';

/// Trade screen — positions, account summary, order ticket, close, modify.
class CelestialTradeScreen extends StatefulWidget {
  const CelestialTradeScreen({super.key});

  @override
  State<CelestialTradeScreen> createState() => _CelestialTradeScreenState();
}

class _CelestialTradeScreenState extends State<CelestialTradeScreen> {
  TradingController get _c => Get.find<TradingController>();
  int _tab = 0; // 0 Active  1 Pending

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CelTheme.bg(context),
      body: SafeArea(
        child: Obx(() {
          final account = _c.accountInfoRx.value;
          final active  = _c.marketPositionsRx;
          final pending = _c.pendingPositions;
          final netPL   = active.fold<double>(0, (s, p) => s + p.profitLoss);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, netPL),
              _summary(context, account),
              _tabBar(context, active.length, pending.length),
              Divider(height: 1, thickness: 0.5, color: CelTheme.divider(context)),
              Expanded(child: _tab == 0
                  ? _posList(context, active.toList())
                  : _posList(context, pending.toList())),
            ],
          );
        }),
      ),
    );
  }

  // ── Net P/L header ────────────────────────────────────────────────────────
  Widget _header(BuildContext c, double netPL) {
    final col = netPL < 0 ? CelTheme.sell(c) : CelTheme.buy(c);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trades', style: CelTheme.title(c)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmtPL(netPL),
                  style: TextStyle(
                      color: col, fontSize: 22.sp, fontWeight: FontWeight.w800)),
              Text('Net P/L', style: CelTheme.label(c)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Account summary ───────────────────────────────────────────────────────
  Widget _summary(BuildContext c, AccountInfo? a) {
    String f(double? v) => (v ?? 0).toStringAsFixed(2);
    Widget cell(String lbl, String val) => Row(
      children: [
        Expanded(
            child:
                Text(lbl, style: CelTheme.label(c).copyWith(fontSize: 12.sp))),
        Text(val,
            style: TextStyle(
                color: CelTheme.mainText(c),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600)),
      ],
    );
    Widget row2(String l1, String v1, String l2, String v2) => Padding(
          padding: EdgeInsets.symmetric(vertical: 3.h),
          child: Row(
            children: [
              Expanded(child: cell(l1, v1)),
              SizedBox(width: 24.w),
              Expanded(child: cell(l2, v2)),
            ],
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 4.h),
      child: Column(children: [
        row2('Balance', f(a?.balance), 'Equity', f(a?.equity)),
        row2('Margin', f(a?.margin), 'Free Margin', f(a?.marginFree)),
        row2('Margin Level', '${(a?.marginLevel ?? 0).toStringAsFixed(0)}%',
            'Floating P/L', _fmtPL(a?.profit ?? 0)),
      ]),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _tabBar(BuildContext c, int activeCount, int pendingCount) {
    Widget pill(String label, int count, int idx) {
      final active = _tab == idx;
      return GestureDetector(
        onTap: () {
          setState(() => _tab = idx);
          _c.setSelectedTab(idx);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: active ? CelTheme.mainText(c) : CelTheme.divider(c),
              width: active ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: active ? CelTheme.mainText(c) : CelTheme.subText(c),
                      fontSize: 13.sp,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              if (count > 0) ...[
                SizedBox(width: 6.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: active ? CelTheme.buy(c) : CelTheme.softBg(c),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          color: active ? Colors.white : CelTheme.subText(c),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 12.w, 10.h),
      child: Row(
        children: [
          pill('Active', activeCount, 0),
          SizedBox(width: 10.w),
          pill('Pending', pendingCount, 1),
          const Spacer(),
          // Close all (only active tab)
          if (_tab == 0 && activeCount > 0)
            Obx(() => _c.isLoading
                ? SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CelTheme.sell(context)))
                : GestureDetector(
                    onTap: () => _confirmCloseAll(context),
                    child: Text('Close All',
                        style: TextStyle(
                            color: CelTheme.sell(context),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700)),
                  )),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: _openOrderTicket,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: CelTheme.buy(context),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 14.sp),
                  SizedBox(width: 4.w),
                  Text('Order',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Position list ──────────────────────────────────────────────────────────
  Widget _posList(BuildContext c, List<TradePosition> positions) {
    if (positions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56.sp, color: CelTheme.subText(c)),
            SizedBox(height: 8.h),
            Text(_tab == 0 ? 'No open positions' : 'No pending orders',
                style: TextStyle(
                    color: CelTheme.subText(c),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      itemCount: positions.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) => _card(c, positions[i]),
    );
  }

  // ── Position card ──────────────────────────────────────────────────────────
  Widget _card(BuildContext c, TradePosition p) {
    final isBuy  = p.action.toUpperCase().contains('BUY');
    final sideColor = isBuy ? CelTheme.buy(c) : CelTheme.sell(c);
    final plColor   = p.profitLoss >= 0 ? CelTheme.tpGreen : CelTheme.sell(c);
    final entry  = _d(p.entryPrice);
    final cur    = _d(p.currentPrice);
    final tp     = _d(p.takeProfit);
    final sl     = _d(p.stopLoss);

    return GestureDetector(
      onTap: () => _openDetail(p),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: CelTheme.card(c),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: CelTheme.divider(c), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: symbol + side badge + P/L
            Row(
              children: [
                Text(p.symbol,
                    style: TextStyle(
                        color: CelTheme.mainText(c),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800)),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text('${isBuy ? 'BUY' : 'SELL'} ${p.volume.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: sideColor,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Text(_fmtPL(p.profitLoss),
                    style: TextStyle(
                        color: plColor,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            SizedBox(height: 6.h),
            // Row 2: entry → current prices
            Row(
              children: [
                Icon(Icons.arrow_forward, size: 12.sp, color: CelTheme.subText(c)),
                SizedBox(width: 4.w),
                Text('${_fmt(entry, p.digits)}  →  ${_fmt(cur, p.digits)}',
                    style: TextStyle(
                        color: CelTheme.subText(c),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(p.time,
                    style: TextStyle(
                        color: CelTheme.subText(c),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            // Row 3: TP / SL / Swap / Commission (if set)
            if (tp > 0 || sl > 0 || p.swap != 0 || p.commission != 0) ...[
              SizedBox(height: 6.h),
              Divider(height: 1, thickness: 0.5, color: CelTheme.divider(c)),
              SizedBox(height: 6.h),
              Row(
                children: [
                  if (tp > 0)
                    _metaChip(c, 'TP', _fmt(tp, p.digits), CelTheme.tpGreen),
                  if (tp > 0 && sl > 0) SizedBox(width: 8.w),
                  if (sl > 0)
                    _metaChip(c, 'SL', _fmt(sl, p.digits), CelTheme.slRed),
                  const Spacer(),
                  if (p.swap != 0)
                    _metaText(c, 'Swap', p.swap.toStringAsFixed(2)),
                  if (p.commission != 0) ...[
                    SizedBox(width: 8.w),
                    _metaText(c, 'Comm', p.commission.toStringAsFixed(2)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaChip(BuildContext c, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text('$label $value',
          style: TextStyle(
              color: color, fontSize: 10.sp, fontWeight: FontWeight.w700)),
    );
  }

  Widget _metaText(BuildContext c, String label, String value) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
            text: '$label ',
            style: TextStyle(
                color: CelTheme.subText(c),
                fontSize: 10.sp,
                fontWeight: FontWeight.w500)),
        TextSpan(
            text: value,
            style: TextStyle(
                color: CelTheme.mainText(c),
                fontSize: 10.sp,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── Close all confirm ──────────────────────────────────────────────────────
  void _confirmCloseAll(BuildContext c) {
    showDialog(
      context: c,
      builder: (_) => AlertDialog(
        backgroundColor: CelTheme.card(c),
        title: Text('Close All Positions',
            style: TextStyle(color: CelTheme.mainText(c), fontSize: 16.sp)),
        content: Text(
            'Close all ${_c.marketPositions.length} open position(s)?',
            style: TextStyle(color: CelTheme.subText(c), fontSize: 13.sp)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Cancel',
                  style: TextStyle(color: CelTheme.subText(c)))),
          TextButton(
              onPressed: () async {
                Navigator.pop(c);
                await _c.closeAllPositions();
              },
              child: Text('Close All',
                  style: TextStyle(
                      color: CelTheme.sell(c), fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  // ── Position detail sheet ──────────────────────────────────────────────────
  void _openDetail(TradePosition p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        position: p,
        onModify: () {
          Navigator.pop(context);
          _openModify(p);
        },
        onClose: () async {
          Navigator.pop(context);
          await _c.closePosition(p.orderId);
        },
      ),
    );
  }

  // ── Modify TP/SL sheet ─────────────────────────────────────────────────────
  void _openModify(TradePosition p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModifySheet(position: p),
    );
  }

  // ── New order ticket ────────────────────────────────────────────────────────
  void _openOrderTicket() {
    final positions = _c.marketPositions;
    final symbol   = positions.isNotEmpty ? positions.first.symbol : 'XAUUSD';
    final p        = positions.isNotEmpty ? positions.first : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderTicket(
        symbol: symbol,
        bid: _d(p?.entryPrice),
        ask: _d(p?.currentPrice),
        digits: p?.digits ?? 2,
        onSubmit: (isSell, type, volume, tp, sl) =>
            _c.placeTradeOrder(
                symbol: symbol,
                volume: volume.toStringAsFixed(2),
                orderType: type,
                takeProfit: tp,
                stopLoss: sl),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final TradePosition position;
  final VoidCallback onModify;
  final VoidCallback onClose;
  const _DetailSheet(
      {required this.position, required this.onModify, required this.onClose});

  @override
  Widget build(BuildContext c) {
    final p     = position;
    final isBuy = p.action.toUpperCase().contains('BUY');
    final plCol = p.profitLoss >= 0 ? CelTheme.tpGreen : CelTheme.sell(c);
    final side  = isBuy ? CelTheme.buy(c) : CelTheme.sell(c);
    final entry = _d(p.entryPrice);
    final cur   = _d(p.currentPrice);
    final pct   = entry == 0 ? 0.0 : (cur - entry) / entry * 100;
    final tp    = _d(p.takeProfit);
    final sl    = _d(p.stopLoss);

    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Symbol header card
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: isBuy ? CelTheme.buyTint(c) : CelTheme.pillBg(c),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(p.symbol,
                        style: TextStyle(
                            color: CelTheme.mainText(c),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800)),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                          color: side,
                          borderRadius: BorderRadius.circular(6.r)),
                      child: Text(
                          '${isBuy ? 'BUY' : 'SELL'} ${p.volume.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Text(
                        '${_fmt(entry, p.digits)}  →  ${_fmt(cur, p.digits)}',
                        style: TextStyle(
                            color: CelTheme.mainText(c),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 8.w),
                    Text('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                        style: TextStyle(
                            color: plCol,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Icon(
                        p.profitLoss >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: plCol,
                        size: 18.sp),
                    SizedBox(width: 4.w),
                    Text(_fmtPL(p.profitLoss),
                        style: TextStyle(
                            color: plCol,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          // ID / Time / Swap / Commission
          Row(
            children: [
              Expanded(child: _kv(c, 'ID', p.orderId)),
              Expanded(child: _kv(c, 'TIME', p.time)),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(child: _kv(c, 'SWAP', p.swap.toStringAsFixed(2))),
              Expanded(
                  child: _kv(c, 'COMMISSION', p.commission.toStringAsFixed(2))),
            ],
          ),
          SizedBox(height: 14.h),
          // Risk management row
          Row(
            children: [
              Text('Risk Management',
                  style: TextStyle(
                      color: CelTheme.mainText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: onModify,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: CelTheme.buyTint(c),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          color: CelTheme.buy(c), size: 14.sp),
                      SizedBox(width: 4.w),
                      Text('Modify',
                          style: TextStyle(
                              color: CelTheme.buy(c),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                  child: _riskBox(c, 'Stop Loss',
                      sl > 0 ? _fmt(sl, p.digits) : 'Not Set')),
              SizedBox(width: 12.w),
              Expanded(
                  child: _riskBox(c, 'Take Profit',
                      tp > 0 ? _fmt(tp, p.digits) : 'Not Set')),
            ],
          ),
          SizedBox(height: 16.h),
          _btn(c, 'Close Position', CelTheme.slRed, onClose),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}

// ── Modify TP/SL sheet ────────────────────────────────────────────────────────
class _ModifySheet extends StatefulWidget {
  final TradePosition position;
  const _ModifySheet({required this.position});

  @override
  State<_ModifySheet> createState() => _ModifySheetState();
}

class _ModifySheetState extends State<_ModifySheet> {
  late bool _tpOn;
  late bool _slOn;
  late double _tpVal;
  late double _slVal;

  @override
  void initState() {
    super.initState();
    final tp = _d(widget.position.takeProfit);
    final sl = _d(widget.position.stopLoss);
    _tpOn  = tp > 0;
    _slOn  = sl > 0;
    _tpVal = tp;
    _slVal = sl;
  }

  @override
  Widget build(BuildContext c) {
    final p     = widget.position;
    final isBuy = p.action.toUpperCase().contains('BUY');
    final side  = isBuy ? CelTheme.buy(c) : CelTheme.sell(c);
    final step  = 1 / pow10(p.digits);

    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: CelTheme.buyTint(c),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Text(p.symbol,
                    style: TextStyle(
                        color: CelTheme.mainText(c),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800)),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                      color: side, borderRadius: BorderRadius.circular(4.r)),
                  child: Text(
                      '${isBuy ? 'BUY' : 'SELL'} ${p.volume.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('OPEN',
                        style: CelTheme.label(c).copyWith(fontSize: 10.sp)),
                    Text(_fmt(_d(p.entryPrice), p.digits),
                        style: TextStyle(
                            color: CelTheme.mainText(c),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.only(left: 4.w),
            child: Text('#${p.orderId}',
                style: CelTheme.label(c).copyWith(fontSize: 11.sp)),
          ),
          SizedBox(height: 14.h),
          _stepper(c, 'TAKE PROFIT', _tpOn, _tpVal, CelTheme.tpGreen,
              (v) => setState(() => _tpOn = v),
              () => setState(() => _tpVal = (_tpVal - step).clamp(0, 1e9)),
              () => setState(() => _tpVal += step)),
          SizedBox(height: 10.h),
          _stepper(c, 'STOP LOSS', _slOn, _slVal, CelTheme.slRed,
              (v) => setState(() => _slOn = v),
              () => setState(() => _slVal = (_slVal - step).clamp(0, 1e9)),
              () => setState(() => _slVal += step)),
          SizedBox(height: 18.h),
          _btn(c, 'Modify', CelTheme.buy(c), () => Navigator.pop(c)),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _stepper(BuildContext c, String label, bool on, double val,
      Color color, ValueChanged<bool> toggle, VoidCallback minus,
      VoidCallback plus) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: CelTheme.softBg(c),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            child: Text(label,
                style: TextStyle(
                    color: CelTheme.subText(c),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: on,
            onChanged: toggle,
            activeColor: Colors.white,
            activeTrackColor: color,
          ),
          const Spacer(),
          GestureDetector(
            onTap: on ? minus : null,
            child: Icon(Icons.remove,
                color: on ? CelTheme.subText(c) : CelTheme.divider(c),
                size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Text(val.toStringAsFixed(2),
              style: TextStyle(
                  color: CelTheme.mainText(c),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700)),
          SizedBox(width: 14.w),
          GestureDetector(
            onTap: on ? plus : null,
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: on
                    ? color.withValues(alpha: 0.12)
                    : CelTheme.divider(c).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(Icons.add,
                  color: on ? color : CelTheme.subText(c), size: 16.sp),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order ticket
// ─────────────────────────────────────────────────────────────────────────────
typedef _Submit = Future<bool> Function(
    bool isSell, OrderType type, double vol, String? tp, String? sl);

class _OrderTicket extends StatefulWidget {
  final String symbol;
  final double bid;
  final double ask;
  final int digits;
  final _Submit onSubmit;
  const _OrderTicket(
      {required this.symbol,
      required this.bid,
      required this.ask,
      required this.digits,
      required this.onSubmit});

  @override
  State<_OrderTicket> createState() => _OrderTicketState();
}

class _OrderTicketState extends State<_OrderTicket> {
  bool _isSell = true;
  int _orderIdx = 0; // 0 Market  1 Limit  2 Stop
  bool _tp = false;
  bool _sl = false;
  double _vol = 0.01;
  bool _placing = false;

  OrderType get _type {
    switch (_orderIdx) {
      case 1:
        return _isSell ? OrderType.sellLimit : OrderType.buyLimit;
      case 2:
        return _isSell ? OrderType.sellStop : OrderType.buyStop;
      default:
        return _isSell ? OrderType.sellMarket : OrderType.buyMarket;
    }
  }

  @override
  Widget build(BuildContext c) {
    final color  = _isSell ? CelTheme.sell(c) : CelTheme.buy(c);
    final price  = _isSell ? widget.bid : widget.ask;
    final spread = ((widget.ask - widget.bid).abs() *
            pow10(widget.digits))
        .round();

    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Symbol header
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: _isSell ? CelTheme.pillBg(c) : CelTheme.buyTint(c),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.symbol,
                        style: TextStyle(
                            color: CelTheme.mainText(c),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800)),
                    SizedBox(width: 4.w),
                    Icon(Icons.keyboard_arrow_down,
                        color: CelTheme.subText(c), size: 20.sp),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _bidAsk(c, 'BID',
                        widget.bid.toStringAsFixed(widget.digits),
                        CelTheme.sell(c)),
                    SizedBox(width: 20.w),
                    _bidAsk(c, 'ASK',
                        widget.ask.toStringAsFixed(widget.digits),
                        CelTheme.buy(c)),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                          color: CelTheme.card(c),
                          borderRadius: BorderRadius.circular(6.r)),
                      child: Text('Spread $spread',
                          style: CelTheme.label(c)
                              .copyWith(fontSize: 11.sp)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Sell / Buy buttons
          Row(
            children: [
              Expanded(child: _sideBtn(c, 'Sell', true)),
              SizedBox(width: 12.w),
              Expanded(child: _sideBtn(c, 'Buy', false)),
            ],
          ),
          SizedBox(height: 12.h),
          // Market / Limit / Stop segments
          _segment(c),
          SizedBox(height: 12.h),
          // Price & Volume
          Container(
            decoration: BoxDecoration(
              color: CelTheme.softBg(c),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Text('PRICE',
                          style: CelTheme.label(c).copyWith(fontSize: 12.sp)),
                      const Spacer(),
                      Text(price.toStringAsFixed(widget.digits),
                          style: TextStyle(
                              color: color,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Divider(height: 1, color: CelTheme.divider(c)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  child: Row(
                    children: [
                      Text('VOLUME',
                          style: CelTheme.label(c).copyWith(fontSize: 12.sp)),
                      const Spacer(),
                      _stepBtn(c, Icons.remove, color,
                          () => setState(() => _vol = (_vol - 0.01).clamp(0.01, 100))),
                      SizedBox(width: 18.w),
                      Text(_vol.toStringAsFixed(2),
                          style: TextStyle(
                              color: CelTheme.mainText(c),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800)),
                      SizedBox(width: 18.w),
                      _stepBtn(c, Icons.add, color,
                          () => setState(() => _vol += 0.01)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // TP / SL toggles
          Container(
            decoration: BoxDecoration(
              color: CelTheme.softBg(c),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              children: [
                _toggle(c, 'TAKE PROFIT', _tp, CelTheme.tpGreen,
                    (v) => setState(() => _tp = v)),
                Divider(height: 1, color: CelTheme.divider(c)),
                _toggle(c, 'STOP LOSS', _sl, CelTheme.slRed,
                    (v) => setState(() => _sl = v)),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          // Confirm button
          _btn(
            c,
            '',
            color,
            _placing
                ? null
                : () async {
                    setState(() => _placing = true);
                    await widget.onSubmit(_isSell, _type, _vol, null, null);
                    if (mounted) {
                      setState(() => _placing = false);
                      Navigator.pop(c);
                    }
                  },
            customChild: _placing
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Column(
                    children: [
                      Text(_isSell ? 'Sell' : 'Buy',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800)),
                      Text(
                          '${_vol.toStringAsFixed(2)} ${widget.symbol} @ ${['Market', 'Limit', 'Stop'][_orderIdx]}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11.sp)),
                    ],
                  ),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _sideBtn(BuildContext c, String label, bool sell) {
    final selected = _isSell == sell;
    final color    = sell ? CelTheme.sell(c) : CelTheme.buy(c);
    return GestureDetector(
      onTap: () => setState(() => _isSell = sell),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : CelTheme.softBg(c),
          borderRadius: BorderRadius.circular(10.r),
          border: selected ? Border.all(color: color, width: 1) : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : CelTheme.subText(c),
                fontSize: 16.sp,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _segment(BuildContext c) {
    final labels = ['Market', 'Limit', 'Stop'];
    return Container(
      decoration: BoxDecoration(
          color: CelTheme.softBg(c),
          borderRadius: BorderRadius.circular(10.r)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == _orderIdx;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _orderIdx = i),
              child: Container(
                margin: EdgeInsets.all(4.w),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? CelTheme.card(c) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        color: active
                            ? CelTheme.mainText(c)
                            : CelTheme.subText(c),
                        fontSize: 13.sp,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _toggle(BuildContext c, String label, bool val, Color color,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            child: Text(label,
                style: TextStyle(
                    color: CelTheme.subText(c),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: val,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: color,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
double pow10(int d) {
  double r = 1;
  for (var i = 0; i < d; i++) r *= 10;
  return r;
}

class _Sheet extends StatelessWidget {
  final Widget child;
  const _Sheet({required this.child});

  @override
  Widget build(BuildContext c) {
    return Container(
      decoration: BoxDecoration(
        color: CelTheme.bg(c),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
          child: child,
        ),
      ),
    );
  }
}

Widget _kv(BuildContext c, String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: CelTheme.label(c).copyWith(fontSize: 11.sp, letterSpacing: 0.4)),
      SizedBox(height: 2.h),
      Text(value,
          style: TextStyle(
              color: CelTheme.mainText(c),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700)),
    ],
  );
}

Widget _riskBox(BuildContext c, String label, String value) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
    decoration: BoxDecoration(
      color: CelTheme.softBg(c),
      borderRadius: BorderRadius.circular(10.r),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CelTheme.label(c).copyWith(fontSize: 11.sp)),
        SizedBox(height: 4.h),
        Text(value,
            style: TextStyle(
                color: CelTheme.mainText(c),
                fontSize: 14.sp,
                fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

Widget _bidAsk(BuildContext c, String label, String value, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: CelTheme.label(c).copyWith(fontSize: 11.sp)),
      SizedBox(height: 2.h),
      Text(value,
          style:
              TextStyle(color: color, fontSize: 20.sp, fontWeight: FontWeight.w800)),
    ],
  );
}

Widget _btn(BuildContext c, String label, Color color, VoidCallback? onTap,
    {Widget? customChild}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14.h),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onTap == null ? CelTheme.subText(c) : color,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: customChild ??
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800)),
    ),
  );
}

Widget _stepBtn(BuildContext c, IconData icon, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Icon(icon, color: color, size: 18.sp),
    ),
  );
}
