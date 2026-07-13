import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'package:crm_app/widgets/AppTextField.dart';
import 'meta_theme.dart';
import 'widgets/meta_native_chart.dart';

double _d(String? v) => double.tryParse(v ?? '') ?? 0;
String _fmt(double v, int d) => v.toStringAsFixed(d);
String _fmtPL(double v) => '${v < 0 ? '' : '+'}${v.toStringAsFixed(2)}';

/// Meta — Trade screen.
///
/// Body layout (matches the MT5 reference):
///   ┌────────────────────────────────────────┐
///   │ ☰  Trade                          ⇅ ⊞  │  ← top bar
///   │     0.85 USD                           │
///   ├────────────────────────────────────────┤
///   │ Balance:       · · ·  99 971.15        │  ← dotted-leader
///   │ Equity:        · · ·  99 972.00        │     summary
///   │ Margin:        · · ·     13.46        │
///   │ Free margin:   · · ·  99 958.54        │
///   │ Margin Level%: · · · 742 734.03        │
///   ├────────────────────────────────────────┤
///   │ Positions                        ···   │  ← section header
///   │ GBPUSD.c, buy 0.02             0.30    │     + position card
///   │ 1.33821  →  1.33836                    │
///   ├────────────────────────────────────────┤
///   │ Orders                          ···   │
///   │ XAUUSD.c, buy limit          placed    │
///   │ 0.01 / 0.00 at 4 035.60                │
///   └────────────────────────────────────────┘
///
/// The bottomsheet flows (close/modify/pending-cancel/new-order) are
/// preserved unchanged — only the in-page layout is restyled.
class MetaTradeScreen extends StatefulWidget {
  const MetaTradeScreen({super.key});

  @override
  State<MetaTradeScreen> createState() => _MetaTradeScreenState();
}

class _MetaTradeScreenState extends State<MetaTradeScreen> {
  TradingController get _c => Get.find<TradingController>();
  StreamSubscription? _accountChangeSubscription;
  String? _lastAccountNumber;
  /// Index into the visible (sorted+filtered) active positions list whose
  /// inline detail row (ticket/open/swap/SL/TP) is currently expanded.
  /// -1 means nothing is expanded.
  int _expandedPosIndex = -1;
  /// Index into the visible active positions list whose blue action strip
  /// (Close / Partial close / Modify / New order) is currently revealed by
  /// a left-swipe gesture. -1 means no action strip is showing.
  int _swipedPosIndex = -1;

  @override
  void initState() {
    super.initState();
    _initializeWebSocketServices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tradingController = Get.find<TradingController>();
      final currentTab = tradingController.selectedTab;
      if (currentTab == 0) {
        tradingController.setSelectedTab(0);
      }

      _initializeTradeScreenWebSockets();
      _listenForAccountChanges();
    });
  }

  void _initializeWebSocketServices() {
    if (!Get.isRegistered<TradingWebSocketService>()) {
      Get.put(TradingWebSocketService(), permanent: true);
    }
    if (!Get.isRegistered<AccountWebSocketService>()) {
      Get.put(AccountWebSocketService(), permanent: true);
    }
  }

  void _initializeTradeScreenWebSockets() {
    try {
      if (Get.isRegistered<TradingWebSocketService>()) {
        final wsService = Get.find<TradingWebSocketService>();
        wsService.ensureOpenPositionsConnection();
        wsService.ensurePendingOrdersConnection();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Meta Trade Screen: Error ensuring WebSocket connections: $e');
      }
    }
  }

  void _listenForAccountChanges() {
    try {
      final accountController = Get.find<AccountController>();
      final currentAccount = accountController.activeMT5Account;
      _lastAccountNumber = currentAccount?.metaAccountNumber;

      _accountChangeSubscription?.cancel();
      _accountChangeSubscription = accountController.activeMT5AccountRx.listen((account) {
        if (!mounted) return;

        final newAccountNumber = account?.metaAccountNumber;
        if (newAccountNumber != null && newAccountNumber != _lastAccountNumber) {
          _lastAccountNumber = newAccountNumber;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            try {
              if (Get.isRegistered<TradingController>()) {
                final tradingController = Get.find<TradingController>();
                tradingController.clearAllTradingData();
              }

              _initializeTradeScreenWebSockets();

              if (mounted) {
                setState(() {});
              }
            } catch (e) {
              if (kDebugMode) {
                print('Meta Trade Screen: Error handling account change: $e');
              }
            }
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Meta Trade Screen: Error setting up account change listener: $e');
      }
    }
  }

  @override
  void dispose() {
    _accountChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaTheme.bg(context),
      body: SafeArea(
        child: Obx(() {
          final account = _c.accountInfoRx.value;
          final active = _c.marketPositionsRx.toList();
          final pending = _c.pendingPositions.toList();
          final netPL = active.fold<double>(0, (s, p) => s + p.profitLoss);
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context, netPL)),
              SliverToBoxAdapter(child: _summary(context, account)),
              SliverToBoxAdapter(
                child: _sectionHeader(
                  context,
                  label: 'Positions',
                  onMenu: () => _showCloseMenu(context),
                ),
              ),
              if (active.isEmpty)
                SliverToBoxAdapter(child: _emptyState(context, 'No open positions'))
              else
                SliverList.builder(
                  itemCount: active.length,
                  itemBuilder: (_, i) {
                    final p = active[i];
                    final isOpen = _swipedPosIndex == i;
                    return _swipeablePosition(
                      context: context,
                      index: i,
                      position: p,
                      isActionStripOpen: isOpen,
                      onTap: () {
                        setState(() {
                          _expandedPosIndex =
                              _expandedPosIndex == i ? -1 : i;
                          // Tapping should also collapse any open swipe.
                          _swipedPosIndex = -1;
                        });
                      },
                      onLongPress: () => _showPositionActionSheet(context, p),
                      onSwipeUpdate: (opened) {
                        setState(() => _swipedPosIndex = opened ? i : -1);
                      },
                      onAction: (action) {
                        // Close the swipe strip first.
                        setState(() => _swipedPosIndex = -1);
                        switch (action) {
                          case _PosAction.close:
                            _openDetail(p);
                            break;
                          case _PosAction.partial:
                            _openDetail(p, partial: true);
                            break;
                          case _PosAction.modify:
                            _openModify(p);
                            break;
                          case _PosAction.newOrder:
                            _openOrderTicket(p.symbol);
                            break;
                        }
                      },
                    );
                  },
                ),
              SliverToBoxAdapter(child: SizedBox(height: 4.h)),
              SliverToBoxAdapter(
                child: _sectionHeader(
                  context,
                  label: 'Orders',
                  onMenu: () => _showCloseMenu(context),
                ),
              ),
              if (pending.isEmpty)
                SliverToBoxAdapter(child: _emptyState(context, 'No pending orders'))
              else
                SliverList.separated(
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => Divider(
                    color: MetaTheme.divider(context),
                    height: 1,
                    thickness: 0.5,
                  ),
                  itemBuilder: (_, i) =>
                      _positionCard(context, pending[i], isPending: true),
                ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),
            ],
          );
        }),
      ),
    );
  }

  // ── Top bar: hamburger + "Trade" + sub-P/L + right icons ─────────────────
  Widget _header(BuildContext c, double netPL) {
    final sub = MetaTheme.subText(c);
    final plColor = netPL < 0 ? MetaTheme.sell(c) : MetaTheme.buy(c);
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 6.h, 12.w, 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: MetaTheme.mainText(c), size: 22.sp),
            onPressed: () => Scaffold.of(c).openDrawer(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Trade',
                    style: TextStyle(
                      color: MetaTheme.mainText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    )),
                SizedBox(height: 2.h),
                Text(_fmtPL(netPL) + ' USD',
                    style: TextStyle(
                      color: plColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    )),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.swap_vert, color: sub, size: 22.sp),
            onPressed: _openOrderTicket,
            tooltip: 'New order',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: 10.w),
          IconButton(
            icon: Icon(Icons.note_add_outlined, color: sub, size: 22.sp),
            onPressed: _openOrderTicket,
            tooltip: 'Add ticket',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Dotted-leader summary (5 rows) ────────────────────────────────────────
  Widget _summary(BuildContext c, AccountInfo? a) {
    final labelColor = MetaTheme.subText(c);
    final valueColor = MetaTheme.mainText(c);
    final plCol = (a?.profit ?? 0) < 0 ? MetaTheme.sell(c) : MetaTheme.buy(c);

    String f(double? v) => (v ?? 0).toStringAsFixed(2);
    String group3(String s) {
      // Insert thin spaces between 3-digit groups for the MT5 look
      // (e.g. "99 971.15"). Falls back gracefully for negative / short values.
      final negative = s.startsWith('-');
      final abs = negative ? s.substring(1) : s;
      final dotIdx = abs.indexOf('.');
      final intPart = dotIdx == -1 ? abs : abs.substring(0, dotIdx);
      final decPart = dotIdx == -1 ? '' : abs.substring(dotIdx);
      final buf = StringBuffer();
      final chars = intPart.split('').reversed.toList();
      for (var i = 0; i < chars.length; i++) {
        if (i != 0 && i % 3 == 0) buf.write(' ');
        buf.write(chars[i]);
      }
      final grouped = buf.toString().split('').reversed.join();
      return '${negative ? '-' : ''}$grouped$decPart';
    }

    Widget row(String label, String value, {Color? color}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                )),
            SizedBox(width: 8.w),
            Expanded(
              child: CustomPaint(
                size: Size(double.infinity, 1),
                painter: _DottedLeaderPainter(
                  color: labelColor.withValues(alpha: 0.35),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(value,
                style: TextStyle(
                  color: color ?? valueColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
      child: Column(
        children: [
          row('Balance:', group3(f(a?.balance))),
          row('Equity:', group3(f(a?.equity))),
          row('Margin:', group3(f(a?.margin))),
          row('Free margin:', group3(f(a?.marginFree))),
          row('Margin Level (%):',
              group3((a?.marginLevel ?? 0).toStringAsFixed(2))),
          // Floating P/L — colored per screenshot if positive/negative
          row(
            'Floating P/L:',
            _fmtPL(a?.profit ?? 0),
            color: plCol,
          ),
        ],
      ),
    );
  }

  // ── Section header (Positions / Orders) ───────────────────────────────────
  Widget _sectionHeader(BuildContext c,
      {required String label, required VoidCallback onMenu}) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF202325) : const Color(0xFFF0F2F5);
    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(16.w, 0.h, 4.w, 0.h),
      child: SizedBox(
        height: 28.h,
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                  color: MetaTheme.subText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                )),
            const Spacer(),
            InkWell(
              onTap: onMenu,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Icon(Icons.more_horiz,
                    color: MetaTheme.subText(c), size: 18.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext c, String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
      child: Text(label,
          style: TextStyle(
            color: MetaTheme.subText(c),
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
          )),
    );
  }

  // ── Swipeable position row ──────────────────────────────────────────────
  Widget _swipeablePosition({
    required BuildContext context,
    required int index,
    required TradePosition position,
    required bool isActionStripOpen,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required ValueChanged<bool> onSwipeUpdate,
    required ValueChanged<_PosAction> onAction,
  }) {
    final accent = MetaTheme.buy(context);
    return _SwipeablePositionRow(
      key: ValueKey('pos-${position.orderId}-$index'),
      actionStrip: _buildActionStrip(context, accent, onAction),
      isActionStripOpen: isActionStripOpen,
      onTap: onTap,
      onLongPress: onLongPress,
      onOpenChange: onSwipeUpdate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _positionCard(context, position, onTap: onTap),
          if (_expandedPosIndex == index)
            _expandedPositionDetail(context, position),
          Divider(
            color: MetaTheme.divider(context),
            height: 1,
            thickness: 0.5,
          ),
        ],
      ),
    );
  }

  Widget _buildActionStrip(
      BuildContext c, Color accent, ValueChanged<_PosAction> onAction) {
    return Container(
      color: accent,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _actionButton(c, Icons.edit_note, 'Close',
              () => onAction(_PosAction.close)),
          _actionButton(c, Icons.edit, 'Partial',
              () => onAction(_PosAction.partial)),
          _actionButton(c, Icons.add_circle_outline, 'Modify',
              () => onAction(_PosAction.modify)),
          _actionButton(c, Icons.show_chart, 'New',
              () => onAction(_PosAction.newOrder)),
        ],
      ),
    );
  }

  Widget _actionButton(
      BuildContext c, IconData icon, String tooltip, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Icon(icon, color: Colors.white, size: 26.sp),
        ),
      ),
    );
  }

  Widget _expandedPositionDetail(BuildContext c, TradePosition p) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    final subtleColor =
        isDark ? const Color(0xFF65676B) : const Color(0xFF8A8D91);
    final valueColor = MetaTheme.mainText(c);
    String fmtSlTp(String raw, int digits) {
      final v = double.tryParse(raw) ?? 0;
      if (v <= 0) return '—';
      return _fmt(v, digits);
    }

    String fmtOpenTime(String iso) {
      if (iso.isEmpty) return '—';
      try {
        final dt = DateTime.parse(iso).toLocal();
        final y = dt.year.toString().padLeft(4, '0');
        final mo = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        final h = dt.hour.toString().padLeft(2, '0');
        final mi = dt.minute.toString().padLeft(2, '0');
        final s = dt.second.toString().padLeft(2, '0');
        return '$y.$mo.$d $h:$mi:$s';
      } catch (_) {
        return iso;
      }
    }

    Widget cell(String label, String value, {Color? color}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$label:',
                style: TextStyle(
                  color: subtleColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                )),
            const Spacer(),
            Text(value,
                style: TextStyle(
                  color: color ?? valueColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      );
    }

    return Container(
      color: MetaTheme.bg(c),
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cell('#${p.orderId}', p.orderId.toString(),
                    color: subtleColor),
                cell('S / L:', fmtSlTp(p.stopLoss, p.digits),
                    color: MetaTheme.sell(c)),
                cell('T / P:', fmtSlTp(p.takeProfit, p.digits),
                    color: MetaTheme.buy(c)),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cell('Open:', fmtOpenTime(p.openTime)),
                cell('Swap:', _fmt(p.swap, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Position / pending-order card (screenshot layout) ────────────────────
  Widget _positionCard(
    BuildContext c,
    TradePosition p, {
    bool isPending = false,
    VoidCallback? onTap,
  }) {
    final isBuy = p.action.toUpperCase().contains('BUY');
    final plColor = p.profitLoss >= 0 ? MetaTheme.buy(c) : MetaTheme.sell(c);

    final entry = _d(p.entryPrice);
    final cur = _d(p.currentPrice);
    final tp = _d(p.takeProfit);

    return InkWell(
      onTap: onTap ?? () => _openDetail(p, isPending: isPending),
      child: Container(
        color: MetaTheme.bg(c),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: symbol + side · · · P/L
            Row(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: p.symbol,
                        style: TextStyle(
                          color: MetaTheme.mainText(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ', ${isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: MetaTheme.buy(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isPending)
                  Text('placed',
                      style: TextStyle(
                        color: MetaTheme.subText(c),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ))
                else
                  Text(_fmtPL(p.profitLoss),
                      style: TextStyle(
                        color: plColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      )),
              ],
            ),
            SizedBox(height: 2.h),
            // Row 2: prices or pending order details
            if (isPending)
              Text(
                '${p.volume.toStringAsFixed(2)} / '
                '${tp.toStringAsFixed(p.digits)} at '
                '${entry.toStringAsFixed(p.digits)}',
                style: TextStyle(
                  color: MetaTheme.subText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Text(
                '${_fmt(entry, p.digits)}  →  ${_fmt(cur, p.digits)}',
                style: TextStyle(
                  color: MetaTheme.subText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Close-all menu (kept from previous implementation) ─────────────────────
  void _showCloseMenu(BuildContext ctx) {
    final positions = _c.marketPositions;

    String? dominantSym;
    if (positions.isNotEmpty) {
      final freq = <String, int>{};
      for (final p in positions) {
        freq[p.symbol] = (freq[p.symbol] ?? 0) + 1;
      }
      dominantSym =
          freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    Future<void> closeWith(List<TradePosition> list) async {
      Navigator.pop(ctx);
      for (final p in list) {
        await _c.closePosition(p.orderId);
      }
    }

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bg = MetaTheme.card(ctx);
        final text = MetaTheme.mainText(ctx);
        final sub = MetaTheme.subText(ctx);

        Widget _item(String label, VoidCallback? onTap,
            {bool isHeader = false, bool isCancel = false}) {
          return InkWell(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: sub.withOpacity(.15), width: .5)),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: isHeader ? sub : (isCancel ? sub : text),
                  fontSize: isHeader ? 13.sp : 15.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(16.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 6.h),
              Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                      color: sub.withOpacity(.3),
                      borderRadius: BorderRadius.circular(2.r))),
              _item('Close Positions', null, isHeader: true),
              _item('All',
                  positions.isEmpty ? null : () => closeWith(positions)),
              _item('With profit', () {
                final list =
                    positions.where((p) => p.profitLoss > 0).toList();
                closeWith(list);
              }),
              _item('With loss', () {
                final list =
                    positions.where((p) => p.profitLoss < 0).toList();
                closeWith(list);
              }),
              if (dominantSym != null)
                _item('All $dominantSym With Loss', () {
                  final list = positions
                      .where((p) =>
                          p.symbol == dominantSym && p.profitLoss < 0)
                      .toList();
                  closeWith(list);
                }),
              _item('Cancel', () => Navigator.pop(ctx), isCancel: true),
              SizedBox(height: 16.h + MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  // ── Detail / pending / modify / new-order sheets (unchanged) ───────────────
  void _openDetail(TradePosition p,
      {bool isPending = false, bool partial = false}) {
    if (isPending) {
      _openPendingDetail(p);
      return;
    }
    // Push the full-screen Close-position screen (MT5-style layout —
    // see _DetailSheet below). It handles back-pressing, partial/full
    // close, and the trailing API call to TradingController. We wrap
    // it in a route callback so onClose fires AFTER the route pops.
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => _DetailSheet(
            position: p,
            initialPartial: partial,
            onModify: () {
              Navigator.pop(context);
              _openModify(p);
            },
            onClose: (volume) async {
              final isFullClose = (volume - p.volume).abs() < 0.0001 ||
                  volume >= p.volume;
              try {
                await _c.closePosition(p.orderId,
                    volume: isFullClose ? null : volume);
              } finally {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          fullscreenDialog: true,
        ))
        .then((_) {
      // No-op — keep _openDetail synchronous to its caller.
    });
  }

  void _openPendingDetail(TradePosition p) {
    final ctx = context;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bg = MetaTheme.card(ctx);
        final text = MetaTheme.mainText(ctx);
        final sub = MetaTheme.subText(ctx);

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 6.h),
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: sub.withOpacity(.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    Text(p.symbol,
                        style: TextStyle(
                            color: text,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 8.w),
                    Text(p.action,
                        style: TextStyle(color: sub, fontSize: 13.sp)),
                    const Spacer(),
                    Text('${p.volume.toStringAsFixed(2)} lot',
                        style: TextStyle(color: sub, fontSize: 13.sp)),
                  ],
                ),
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    Text(
                        'Price: ${_fmt(_d(p.entryPrice), p.digits)}',
                        style: TextStyle(color: sub, fontSize: 12.sp)),
                    if (_d(p.currentPrice) > 0) ...[
                      Text('  →  ${_fmt(_d(p.currentPrice), p.digits)}',
                          style: TextStyle(color: sub, fontSize: 12.sp)),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Divider(height: 1, thickness: 0.5, color: sub.withOpacity(.2)),
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  final accountController = Get.find<AccountController>();
                  final activeAccount = accountController.activeMT5Account;
                  if (activeAccount == null ||
                      activeAccount.metaAccountNumber.isEmpty) {
                    if (Get.isRegistered<AppNotificationController>()) {
                      Get.find<AppNotificationController>().showError(
                        title: 'Error',
                        message: 'No active trading account found',
                      );
                    }
                    return;
                  }
                  await _c.cancelOrderWithImmediateUpdate(
                    mt5Account: activeAccount.metaAccountNumber,
                    orderId: int.tryParse(p.orderId) ?? 0,
                  );
                  final errMsg = _c.errorMessage;
                  if (Get.isRegistered<AppNotificationController>()) {
                    if (errMsg.isEmpty) {
                      Get.find<AppNotificationController>().showSuccess(
                        title: 'Success',
                        message: 'Pending order cancelled',
                      );
                    } else {
                      Get.find<AppNotificationController>().showError(
                        title: 'Error',
                        message: errMsg,
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  alignment: Alignment.center,
                  child: Text('Cancel Order',
                      style: TextStyle(
                          color: MetaTheme.sell(ctx),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: sub.withOpacity(.2)),
              InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  alignment: Alignment.center,
                  child: Text('Dismiss',
                      style: TextStyle(color: sub, fontSize: 15.sp)),
                ),
              ),
              SizedBox(height: 16.h + MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  void _openModify(TradePosition p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModifySheet(position: p),
    );
  }

  void _openOrderTicket([String? prefillSymbol]) {
    final positions = _c.marketPositions;
    String symbol;
    TradePosition? p;
    if (prefillSymbol != null && prefillSymbol.isNotEmpty) {
      // Look up the live quote for the swiped position's symbol so the
      // bid/ask/digits reflect the actual market, not a stale entry price.
      symbol = prefillSymbol;
      final match = positions
          .where((q) => q.symbol == prefillSymbol)
          .toList();
      if (match.isNotEmpty) {
        p = match.first;
      } else if (positions.isNotEmpty) {
        p = positions.first;
      }
    } else {
      symbol = positions.isNotEmpty ? positions.first.symbol : 'XAUUSD';
      p = positions.isNotEmpty ? positions.first : null;
    }
    final accountController = Get.find<AccountController>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderTicket(
        symbol: symbol,
        bid: _d(p?.entryPrice),
        ask: _d(p?.currentPrice),
        digits: p?.digits ?? 2,
        onSubmit: (isSell, type, volume, price, tp, sl) {
          final activeAccount = accountController.activeMT5Account;
          if (activeAccount == null ||
              activeAccount.metaAccountNumber.isEmpty) {
            if (Get.isRegistered<AppNotificationController>()) {
              Get.find<AppNotificationController>().showError(
                title: 'Error',
                message: 'No active trading account found',
              );
            }
            return Future.value(false);
          }
          return _c.placeTradeOrder(
              mt5Account: activeAccount.metaAccountNumber,
              symbol: symbol,
              volume: volume.toStringAsFixed(2),
              orderType: type,
              price: price,
              takeProfit: tp,
              stopLoss: sl);
        },
      ),
    );
  }

  /// Long-press on a position row → show the full action bottom sheet
  /// matching the MT5 mobile screenshot: Close / Modify / New order /
  /// Chart / Bulk Operations.
  void _showPositionActionSheet(BuildContext c, TradePosition p) {
    // Close any open swipe strip first.
    setState(() => _swipedPosIndex = -1);
    showModalBottomSheet(
      context: c,
      backgroundColor: MetaTheme.card(c),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
      ),
      builder: (sheetCtx) {
        final isDark = Theme.of(c).brightness == Brightness.dark;
        final dividerColor = isDark
            ? const Color(0xFF3A3B3C)
            : const Color(0xFFE4E6EB);
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8.h),
              _actionSheetItem(
                sheetCtx,
                icon: Icons.close,
                label: 'Close position',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openDetail(p);
                },
              ),
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: dividerColor,
                  indent: 56.w),
              _actionSheetItem(
                sheetCtx,
                icon: Icons.edit_outlined,
                label: 'Modify position',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openModify(p);
                },
              ),
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: dividerColor,
                  indent: 56.w),
              _actionSheetItem(
                sheetCtx,
                icon: Icons.add_box_outlined,
                label: 'New order',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openOrderTicket(p.symbol);
                },
              ),
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: dividerColor,
                  indent: 56.w),
              _actionSheetItem(
                sheetCtx,
                icon: Icons.show_chart,
                label: 'Chart',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Get.toNamed('/chart', arguments: p.symbol);
                },
              ),
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: dividerColor,
                  indent: 56.w),
              _actionSheetItem(
                sheetCtx,
                icon: Icons.dashboard_customize_outlined,
                label: 'Bulk Operations…',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showCloseMenu(c);
                },
              ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }

  Widget _actionSheetItem(BuildContext c,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: MetaTheme.mainText(c), size: 22.sp),
            SizedBox(width: 18.w),
            Text(label,
                style: TextStyle(
                  color: MetaTheme.mainText(c),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline position-row UI: tap-to-expand details + swipe-left to reveal
// the 4-icon action strip (Close / Partial close / Modify / New order).
// ─────────────────────────────────────────────────────────────────────────────
enum _PosAction { close, partial, modify, newOrder }

/// A horizontal-drag row that reveals an action strip behind it.
/// Unlike `Dismissible`, this widget persists its open/closed offset and
/// animates to a fixed locked position (actionStripWidth) instead of
/// snapping back to 0. A short tap toggles the open state; a drag past
/// the threshold locks the strip open; a drag back past the threshold
/// in the opposite direction locks it closed.
class _SwipeablePositionRow extends StatefulWidget {
  final Widget child;
  final Widget actionStrip;
  final bool isActionStripOpen;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool> onOpenChange;

  const _SwipeablePositionRow({
    super.key,
    required this.child,
    required this.actionStrip,
    required this.isActionStripOpen,
    required this.onTap,
    required this.onOpenChange,
    this.onLongPress,
  });

  @override
  State<_SwipeablePositionRow> createState() => _SwipeablePositionRowState();
}

class _SwipeablePositionRowState extends State<_SwipeablePositionRow> {
  /// Pixel offset applied to the foreground. 0 = fully closed, equal to
  /// the action strip width = fully open. Always non-positive (drags left
  /// to open).
  double _dragOffset = 0;
  double? _actionStripWidth;
  /// True while the user is actively dragging. Used to suppress the
  /// tap recognizer from firing on drag-release.
  bool _isDragging = false;

  @override
  void didUpdateWidget(covariant _SwipeablePositionRow old) {
    super.didUpdateWidget(old);
    if (widget.isActionStripOpen != old.isActionStripOpen) {
      _syncOffsetWithOpen();
    }
  }

  void _syncOffsetWithOpen() {
    final w = _actionStripWidth;
    if (w == null) return; // width not measured yet — next drag will sync
    final target = widget.isActionStripOpen ? -w : 0.0;
    setState(() {
      _dragOffset = target;
    });
  }

  void _onPanStart(DragStartDetails _) {
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // Lazily compute the strip width if LayoutBuilder hasn't run yet.
    _actionStripWidth ??= MediaQuery.sizeOf(context).width * 0.40;
    final w = _actionStripWidth ?? 0.0;
    if (w <= 0) return;
    setState(() {
      _dragOffset = (_dragOffset + d.delta.dx).clamp(-w, 0.0);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    final w = _actionStripWidth ?? 0.0;
    _isDragging = false;
    if (w <= 0) return;

    final v = d.velocity.pixelsPerSecond;
    final velocity = d.primaryVelocity ?? 0;
    final isHorizontalGesture = v.dx.abs() > v.dy.abs();
    final open = widget.isActionStripOpen;
    final ratio = (-_dragOffset) / w;
    final flickedLeft = velocity < -250;
    final flickedRight = velocity > 250;

    bool shouldBeOpen;
    if (!isHorizontalGesture && ratio < 0.10) {
      shouldBeOpen = open;
    } else if (open) {
      shouldBeOpen = ratio >= 0.30 || flickedLeft;
      if (flickedRight) shouldBeOpen = false;
    } else {
      shouldBeOpen = ratio >= 0.30 || flickedLeft;
    }

    final target = shouldBeOpen ? -w : 0.0;
    if (shouldBeOpen != open) {
      widget.onOpenChange(shouldBeOpen);
    }
    // Snap directly without animation — instant lock-in avoids races
    // with the parent rebuild.
    setState(() {
      _dragOffset = target;
    });
  }

  void _onPanCancel() {
    _isDragging = false;
    final w = _actionStripWidth ?? 0.0;
    final target = widget.isActionStripOpen ? -w : 0.0;
    setState(() {
      _dragOffset = target;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = MetaTheme.bg(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _actionStripWidth = constraints.maxWidth * 0.40;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          onTap: _isDragging ? null : widget.onTap,
          onLongPress: _isDragging ? null : widget.onLongPress,
          child: Stack(
            children: [
              // Action strip behind, full-width.
              Positioned.fill(child: widget.actionStrip),
              // Foreground card, dragged left to reveal.
              Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: Container(
                  color: bg,
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DottedLeaderPainter extends CustomPainter {
  final Color color;
  _DottedLeaderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    const dotRadius = 0.8;
    const gap = 3.5;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
      x += gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLeaderPainter old) =>
      old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Position detail bottom sheet (preserved)
// ─────────────────────────────────────────────────────────────────────────────
typedef _CloseCallback = Future<void> Function(double volume);

// ── Close-position sheet (MT5-style) ─────────────────────────────────────
// Replaces the old _DetailSheet entirely. Renders the screenshot layout:
// back-arrow + "Close position #XXX" header, volume pill selector, large
// bid/ask numbers with decimal emphasis, SL/TP side-by-side with
// minus-button rows and colored underlines, Fill policy row, mini chart
// with right-side price ladder, warning text, and "CLOSE WITH PROFIT $X"
// button.
// ── Close-position sheet (MT5-style) ─────────────────────────────────────
class _DetailSheet extends StatefulWidget {
  final TradePosition position;
  final VoidCallback onModify;
  final _CloseCallback onClose;
  /// When true the sheet opens in "partial close" mode — the volume
  /// pill is pre-selected to HALF the position (rounded down to a legal
  /// 0.01 lot) and the bottom button reads "PARTIAL CLOSE $X.XX". When
  /// false (default) the volume is the FULL position and the button
  /// reads "CLOSE WITH PROFIT/LOSS $X.XX".
  final bool initialPartial;
  const _DetailSheet({
    required this.position,
    required this.onModify,
    required this.onClose,
    this.initialPartial = false,
  });

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  // The MT5 screenshot only has volume-REDUCE pills (close a portion of
  // the position). Growing the position volume past `position.volume`
  // doesn't make sense when closing — so the +0.01/+0.1/+0.5 pills are
  // greyed out. The reference shows `position.volume = 0.02` so the
  // center pill displays "0.02" and `−0.01` is the only usable delta.
  // We compute the available -delta values dynamically: a `-X` pill is
  // enabled only if (position.volume − X) >= 0.01 (the minimum lot).
  static const double _minLot = 0.01;

  // Live tick data pulled from the same socket that powers
  // MetaNativeChart. When ticks haven't arrived yet, fall back to the
  // position's stored currentPrice.
  final ChartSocketController _socket = Get.find<ChartSocketController>();
  StreamSubscription<dynamic>? _tickSub;

  double _liveBid = 0;
  double _liveAsk = 0;
  // Live profit projection derived from the latest tick + openPrice.
  // 0 means "no live tick yet, fall back to widget.position.profitLoss".
  double _liveProfit = 0;
  // The chart socket's symbol before we swapped it for this position.
  // Restored in dispose() so the trade screen resumes its previous
  // chart when the close sheet pops.
  String? _previousChartSymbol;
  // (digits come from the position and from MetaNativeChart's own
  // subscription; we don't need to cache them here.)

  double _deltaPreset = 0; // 0 = full close, negative = partial close
  String _fillPolicy = 'Fill or Kill';

  @override
  void initState() {
    super.initState();
    if (widget.initialPartial) {
      // Default partial: half of position rounded down to a legal lot.
      _deltaPreset = -(widget.position.volume / 2).floorToDouble() * -1;
      final half = widget.position.volume / 2.0;
      _deltaPreset = -half;
    } else {
      _deltaPreset = 0;
    }
    // Seed live bid/ask with the position's stored currentPrice so the
    // first paint isn't 0.00000. Once ticks start arriving, real values
    // overwrite these.
    final seedPrice = double.tryParse(widget.position.currentPrice) ?? 0;
    _liveBid = seedPrice;
    _liveAsk = seedPrice + (seedPrice > 0 ? 0.00002 : 0);

    // The chart socket subscribes to ONE symbol at a time. To get live
    // ticks for the position's symbol (which may differ from whatever
    // the trade screen is currently displaying), temporarily swap the
    // socket's symbol to the position's. We restore it in dispose().
    final posSymbol = _stripSuffix(widget.position.symbol);
    final prev = _socket.currentSymbol.value;
    _previousChartSymbol = prev.isEmpty ? null : prev;
    _socket.changeSymbol(posSymbol);

    // Subscribe to live ticks. The socket emits Map<String,dynamic>
    // events with keys 'Symbol'/'symbol', 'Bid'/'bid', 'Ask'/'ask',
    // 'Digits'/'digits'. We filter for our position's symbol (with
    // suffix stripping so GBPUSD.c matches GBPUSD), matching the logic
    // in MetaNativeChart.
    _tickSub = _socket.priceStream.listen((event) {
      final sym = (event['symbol'] ??
              event['Symbol'] ??
              event['SYMBOL'] ??
              '')
          .toString();
      if (_stripSuffix(sym) != posSymbol) return;
      final bid = (event['bid'] ?? event['Bid']) as num?;
      final ask = (event['ask'] ?? event['Ask']) as num?;
      if (bid == null || ask == null) return;
      if (!mounted) return;
      final isBuy = widget.position.action.toUpperCase().contains('BUY');
      final closePrice = isBuy ? bid.toDouble() : ask.toDouble();
      final p = widget.position;
      final openPrice = (p.openPrice as num).toDouble();
      final baseProfit = (p.profitLoss as num).toDouble();
      final storedPrice = double.tryParse(p.currentPrice) ?? openPrice;
      final storedSpread = storedPrice - openPrice;
      double liveProfit = baseProfit;
      if (storedSpread.abs() > 0.0000001) {
        final liveSpread = closePrice - openPrice;
        liveProfit = isBuy
            ? (liveSpread / storedSpread) * baseProfit
            : (-liveSpread / storedSpread) * baseProfit;
      }
      setState(() {
        _liveBid = bid.toDouble();
        _liveAsk = ask.toDouble();
        _liveProfit = liveProfit;
      });
    });
  }

  /// Strip the trailing ".c" / ".i" / ".pro" suffix that brokers add
  /// to symbol names — the chart socket uses the bare symbol.
  String _stripSuffix(String sym) {
    final i = sym.indexOf('.');
    return i < 0 ? sym : sym.substring(0, i);
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    // Restore the trade screen's previous chart symbol. If the user
    // wasn't watching any symbol before the close sheet opened, just
    // disconnect — the trade screen's onResume will reconnect when
    // needed.
    if (_previousChartSymbol != null &&
        _previousChartSymbol!.isNotEmpty) {
      _socket.changeSymbol(_previousChartSymbol!);
    } else {
      _socket.resetController();
    }
    super.dispose();
  }

  /// Volume the user wants to close, derived from _deltaPreset. Always
  /// strictly positive and <= position.volume, snapped to 0.01.
  double get _closeVolume {
    final full = widget.position.volume;
    final v = (full + _deltaPreset).clamp(_minLot, full);
    return (v * 100).round() / 100.0;
  }

  // ── Volume pill model ─────────────────────────────────────────────────
  // The 7-pill row is NOT a "delta" selector. Each pill represents the
  // CLOSE VOLUME it would commit to: tapping -0.01 picks 0.01 lots to
  // close; tapping the center picks the FULL position volume; tapping
  // +0.01 restores 1 step above the current close volume (up to the
  // position's full volume). This matches the MT5 screenshots where the
  // center label updates from "0.02" (full) to "0.01" (after tapping
  // the -0.01 pill), and +0.01 becomes the active pill when in
  // partial-close mode.
  static const List<double> _pillSteps = [-0.5, -0.1, -0.01, 0, 0.01, 0.1, 0.5];

  /// For a given pill at index `i`, return the close volume it would
  /// set when tapped. Pill 3 (center) always sets full close volume.
  /// Pills 0..2 = -X always means "close (full − X) lots"; the label
  /// shows what the close volume WOULD be if you tapped this pill from
  /// full-close mode. Pills 4..6 = +X means "restore X lots above the
  /// current close volume (capped at full)"; these pills only make
  /// sense after a partial-close has been committed.
  double _pillCloseVolume(int i) {
    final full = widget.position.volume;
    if (i == 3) return full;
    final step = _pillSteps[i];
    if (step < 0) {
      // -X pill → close volume = (full − |step|), clamped at _minLot.
      // All -pills always show the close volume from FULL close mode,
      // not from the current partial mode. That way the labels stay
      // stable: -0.5 always reads "would close 0.01 from 0.02", even
      // when the user has already chosen 0.01. (Visually, all the
      // -pills collapse to 0.01 once you\'re past the smallest step.)
      return (full + step).clamp(_minLot, full);
    } else {
      // +X pill → close volume = current + X, capped at full.
      return (_closeVolume + step).clamp(_minLot, full);
    }
  }

  /// Whether a pill at index `i` should be tappable right now.
  bool _isPillEnabled(int i) {
    final full = widget.position.volume;
    if (full <= 0) return false;
    if (i == 3) return true; // center pill = full close, always available
    final step = _pillSteps[i];
    if (step < 0) {
      // -pill enabled if (full + step) >= _minLot
      final wouldClose = (full + step).clamp(_minLot, full);
      final isFresh = (i <= 2) &&
          (wouldClose - _closeVolume).abs() > 0.001 &&
          wouldClose >= _minLot - 0.0001;
      return isFresh || wouldClose <= full - 0.0001;
    } else {
      // +pill enabled only in partial-close mode AND when restore is possible
      if (_closeVolume >= full - 0.0001) return false;
      final wouldClose = (_closeVolume + step).clamp(_minLot, full);
      return wouldClose <= full + 0.0001 && wouldClose > _closeVolume;
    }
  }

  /// Whether the pill at index `i` is the one currently setting
  /// _closeVolume. Only the center pill is highlighted when in
  /// full-close mode; in partial mode a -pill (or the corresponding
  /// +pill that restores) is highlighted.
  bool _isPillActive(int i) {
    final target = _closeVolume;
    final pillValue = _pillCloseVolume(i);
    return (pillValue - target).abs() < 0.0005;
  }

  double get _expectedProfit {
    if (widget.position.volume <= 0) return 0;
    // Prefer the live-tick-derived profit when ticks have arrived
    // (_liveProfit != 0). Otherwise fall back to the position's
    // server-reported profitLoss.
    final fullProfit =
        _liveProfit != 0 ? _liveProfit : widget.position.profitLoss;
    return fullProfit * (_closeVolume / widget.position.volume);
  }

  // ── Bid / Ask visual split ──────────────────────────────────────────────
  // The MT5 screenshot renders each price as e.g. "1.3385" (big, ~26 sp)
  // + "9" (small superscript, ~12 sp). The split point is the LAST
  // decimal digit (1 character shown as superscript); everything before
  // that — including the dot and all other decimals — renders at full
  // size.
  // For digits=5 and price=1.33859:
  //   big   = "1.3385"        // ~26sp
  //   small = "9"             // ~12sp superscript
  // For digits=4 and price=95.108:
  //   big   = "95.10"
  //   small = "8"
  // For digits=2 and price=4056.44: (no superscript room, full size)
  //   big   = "4056.44"
  //   small = ""
  ({String big, String small}) _splitPrice(String s) {
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final dotIdx = body.indexOf('.');
    final intPart = dotIdx < 0 ? body : body.substring(0, dotIdx);
    final decPart = dotIdx < 0 ? '' : body.substring(dotIdx + 1);
    if (decPart.length <= 1) {
      // 0 or 1 decimal: render whole string as big; no superscript.
      return (big: neg ? '-$body' : body, small: '');
    }
    // Split: keep first (decPart.length - 1) chars in big, last 1
    // char becomes superscript.
    final mainDec = decPart.substring(0, decPart.length - 1);
    final sup = decPart.substring(decPart.length - 1);
    final bigStr = '$intPart.$mainDec';
    return (big: neg ? '-$bigStr' : bigStr, small: sup);
  }

  Widget _bidAskColumn(double value, Color color) {
    final parts = _splitPrice(value.toStringAsFixed(widget.position.digits));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Main digits — "1.3385" at full size.
            Text(parts.big,
                style: TextStyle(
                  color: color,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.0,
                )),
            // Last decimal digit shown as small superscript: "9".
            if (parts.small.isNotEmpty)
              Transform.translate(
                offset: Offset(0, -4.h),
                child: Text(parts.small,
                    style: TextStyle(
                      color: color,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    )),
              ),
          ],
        ),
      ],
    );
  }

  /// Render the pill at row index `i`.
  /// - Pills 0..2 (-0.5, -0.1, -0.01) and 4..6 (+0.01, +0.1, +0.5)
  ///   always render their step string (e.g. "-0.01").
  /// - Pill 3 (center) renders the CURRENT close volume, so it shows
  ///   "0.02" at full close and "0.01" after a partial close.
  Widget _volumePill(BuildContext c, int i) {
    final active = _isPillActive(i);
    final enabled = _isPillEnabled(i);
    // Display label: step string for ± pills, current close volume
    // for the center pill.
    String label;
    if (i == 3) {
      label = _closeVolume.toStringAsFixed(2);
    } else {
      final sign = _pillSteps[i] < 0 ? '−' : '+';
      label = '$sign${_pillSteps[i].abs().toStringAsFixed(2)}';
    }
    final color = active
        ? MetaTheme.buy(c)
        : (enabled
            ? MetaTheme.mainText(c).withValues(alpha: 0.55)
            : MetaTheme.subText(c).withValues(alpha: 0.6));
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () => setState(() {
                  // Commit the close volume this pill represents.
                  _deltaPreset = _pillCloseVolume(i) - widget.position.volume;
                })
            : null,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: active
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: MetaTheme.buy(c),
                      width: 2,
                    ),
                  ),
                )
              : null,
          child: Text(label,
              style: TextStyle(
                color: color,
                fontSize: 14.sp,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final p = widget.position;
    final isBuy = p.action.toUpperCase().contains('BUY');
    final isPartial = widget.initialPartial || _deltaPreset < 0;
    final digits = p.digits.clamp(2, 5);
    // Bid/ask: prefer live socket values (real-time ticks). If no
    // tick has arrived yet (live values stay at 0), fall back to the
    // position's last currentPrice as a static placeholder.
    var bid = _liveBid;
    var ask = _liveAsk;
    if (bid <= 0 || ask <= 0) {
      final seed = double.tryParse(p.currentPrice) ?? 0;
      bid = seed;
      ask = seed + 0.00002;
    }

    return Scaffold(
      backgroundColor: MetaTheme.card(c),
      appBar: AppBar(
        backgroundColor: MetaTheme.card(c),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MetaTheme.mainText(c)),
          onPressed: () => Navigator.pop(c),
        ),
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Close position #${p.orderId}',
              style: TextStyle(
                color: MetaTheme.mainText(c),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              '${isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)} ${p.symbol} at ${p.entryPrice}',
              style: TextStyle(
                color: MetaTheme.subText(c),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── Volume pill selector ───────────────────────────────────────
            SizedBox(
              height: 40.h,
              child: Row(
                children: [
                  _volumePill(c, 0),
                  _volumePill(c, 1),
                  _volumePill(c, 2),
                  _volumePill(c, 3),
                  _volumePill(c, 4),
                  _volumePill(c, 5),
                  _volumePill(c, 6),
                ],
              ),
            ),

            // ── Bid / Ask numbers ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
              child: Row(
                children: [
                  Expanded(child: _bidAskColumn(bid, MetaTheme.sell(c))),
                  SizedBox(width: 18.w),
                  Expanded(child: _bidAskColumn(ask, MetaTheme.buy(c))),
                ],
              ),
            ),

            // ── SL / TP side-by-side ──────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _slTpBox(
                      context: c,
                      color: isBuy ? MetaTheme.sell(c) : MetaTheme.buy(c),
                      label: 'SL',
                      digits: digits,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: _slTpBox(
                      context: c,
                      color: MetaTheme.buy(c),
                      label: 'TP',
                      digits: digits,
                    ),
                  ),
                ],
              ),
            ),

            // ── Fill policy row with inline DropdownButton ──────────────────
            // Matches meta_new_order_screen.dart's Expiration dropdown
            // (DropdownButtonHideUnderline + DropdownButton) so the
            // selected policy is editable in-place without a bottom sheet.
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 4.h),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: MetaTheme.subText(c).withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text('Fill policy',
                        style: TextStyle(
                          color: MetaTheme.mainText(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        )),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _fillPolicy,
                        isDense: true,
                        icon: Icon(Icons.expand_more,
                            color: MetaTheme.subText(c), size: 18.sp),
                        iconSize: 18,
                        style: TextStyle(
                          color: MetaTheme.subText(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                        ),
                        dropdownColor: MetaTheme.card(c),
                        items: const [
                          DropdownMenuItem(
                            value: 'Fill or Kill',
                            child: Text('Fill or Kill'),
                          ),
                          DropdownMenuItem(
                            value: 'Immediate or Cancel',
                            child: Text('Immediate or Cancel'),
                          ),
                          DropdownMenuItem(
                            value: 'Book or Cancel',
                            child: Text('Book or Cancel'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _fillPolicy = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Real chart with right-side bid/ask price scale ────────────
            // Use MetaNativeChart so the bid/ask lines are driven by the
            // same socket that powers the new-order chart. It filters by
            // position.symbol, shows "Waiting for ticks…" until data
            // arrives, and uses real digits for precision.
            SizedBox(
              height: 340.h,
              child: MetaNativeChart(
                symbol: p.symbol,
                maxPoints: 220,
              ),
            ),

            // ── Warning text ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
              child: Text(
                'Attention! The trade will be executed at market conditions, '
                'difference with requested price may be significant!',
                style: TextStyle(
                  color: MetaTheme.subText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),

            SizedBox(height: 12.h),

            // ── Close button ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
              child: SizedBox(
                width: double.infinity,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: () => widget.onClose(_closeVolume),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        isPartial
                            ? 'PARTIAL CLOSE'
                            : (_expectedProfit >= 0
                                ? 'CLOSE WITH PROFIT'
                                : 'CLOSE WITH LOSS'),
                        style: TextStyle(
                          color: MetaTheme.buy(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _fmtUSD(_expectedProfit),
                        style: TextStyle(
                          color: MetaTheme.buy(c),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtUSD(double v) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs().toStringAsFixed(2);
    return '$sign$abs';
  }

  Widget _slTpBox({
    required BuildContext context,
    required Color color,
    required String label,
    required int digits,
  }) {
    final c = context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove, color: MetaTheme.mainText(c)),
              onPressed: () {/* decrement SL/TP — wire to modify */},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Expanded(
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      color: MetaTheme.mainText(c),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: MetaTheme.mainText(c)),
              onPressed: () {/* increment SL/TP — wire to modify */},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Container(height: 2, color: color),
      ],
    );
  }

}

class _ModifySheet extends StatefulWidget {
  final TradePosition position;
  const _ModifySheet({required this.position});

  @override
  State<_ModifySheet> createState() => _ModifySheetState();
}

class _ModifySheetState extends State<_ModifySheet> {
  late bool _slOn;
  late bool _tpOn;
  late final TextEditingController _tpController;
  late final TextEditingController _slController;
  late final TradingController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.find<TradingController>();
    final tp = _d(widget.position.takeProfit);
    final sl = _d(widget.position.stopLoss);
    _tpOn = tp > 0;
    _slOn = sl > 0;
    _tpController = TextEditingController(
        text: _tpOn ? _fmt(tp, widget.position.digits) : '');
    _slController = TextEditingController(
        text: _slOn ? _fmt(sl, widget.position.digits) : '');

    try {
      if (Get.isRegistered<ChartSocketController>()) {
        final chartSocketController = Get.find<ChartSocketController>();
        chartSocketController.changeSymbol(widget.position.symbol);
        Future.delayed(const Duration(milliseconds: 100), () {
          chartSocketController.getSocketData();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tpController.dispose();
    _slController.dispose();
    super.dispose();
  }

  void _calculateTPFromRiskReward() {
    if (!_slOn || !_tpOn) return;
    final slPrice =
        double.tryParse(_slController.text.replaceAll(',', '')) ?? 0.0;
    final entryPrice = double.tryParse(widget.position.entryPrice) ?? 0.0;
    if (slPrice <= 0 || entryPrice <= 0) return;
    final isBuy = widget.position.action.toLowerCase() == 'buy';
    double tpPrice;
    if (isBuy) {
      final risk = entryPrice - slPrice;
      tpPrice = entryPrice + (2 * risk);
    } else {
      final risk = slPrice - entryPrice;
      tpPrice = entryPrice - (2 * risk);
    }
    _tpController.text = _fmt(tpPrice, widget.position.digits);
  }

  void _incrementValue(TextEditingController controller, double step, bool isTP) {
    final currentValue = double.tryParse(controller.text.replaceAll(',', '')) ??
        (double.tryParse(widget.position.currentPrice) ?? 0.0);
    final newValue = currentValue + step;
    controller.text = _fmt(newValue, widget.position.digits);
    if (!isTP) _calculateTPFromRiskReward();
  }

  void _decrementValue(TextEditingController controller, double step, bool isTP) {
    final currentValue = double.tryParse(controller.text.replaceAll(',', '')) ??
        (double.tryParse(widget.position.currentPrice) ?? 0.0);
    final newValue = (currentValue - step).clamp(0.0, double.infinity);
    controller.text = _fmt(newValue, widget.position.digits);
    if (!isTP) _calculateTPFromRiskReward();
  }

  @override
  Widget build(BuildContext c) {
    return _Sheet(
      child: Obx(() {
        final p = _c.marketPositions
                .firstWhereOrNull((pos) => pos.orderId == widget.position.orderId) ??
            _c.pendingPositions
                .firstWhereOrNull((pos) => pos.orderId == widget.position.orderId) ??
            widget.position;
        final isBuy = p.action.toUpperCase().contains('BUY');
        final side = isBuy ? MetaTheme.buy(c) : MetaTheme.sell(c);
        final step = 1 / pow10(p.digits);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: MetaTheme.buyTint(c),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Text(p.symbol,
                      style: TextStyle(
                          color: MetaTheme.mainText(c),
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
                      Text('CURRENT',
                          style: MetaTheme.label(c).copyWith(fontSize: 10.sp)),
                      Text(_fmt(_d(p.currentPrice), p.digits),
                          style: TextStyle(
                              color: MetaTheme.mainText(c),
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.only(left: 4.w, right: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('#${p.orderId}',
                      style: MetaTheme.label(c).copyWith(fontSize: 11.sp)),
                  Text(p.time,
                      style: MetaTheme.label(c).copyWith(fontSize: 11.sp)),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _modifyTpSlCard(
                    c,
                    label: 'TP',
                    color: MetaTheme.tpGreen,
                    on: _tpOn,
                    controller: _tpController,
                    onToggle: (v) => setState(() => _tpOn = v),
                    onIncrement: () => _incrementValue(_tpController, step, true),
                    onDecrement: () => _decrementValue(_tpController, step, true),
                    onChanged: (_) {},
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _modifyTpSlCard(
                    c,
                    label: 'SL',
                    color: MetaTheme.slRed,
                    on: _slOn,
                    controller: _slController,
                    onToggle: (v) => setState(() => _slOn = v),
                    onIncrement: () => _incrementValue(_slController, step, false),
                    onDecrement: () => _decrementValue(_slController, step, false),
                    onChanged: (_) => _calculateTPFromRiskReward(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            _btn(c, 'Modify', MetaTheme.buy(c), () async {
              final double takeProfit = _tpOn && _tpController.text.isNotEmpty
                  ? (double.tryParse(_tpController.text.replaceAll(',', '')) ?? 0.0)
                  : 0.0;
              final double stopLoss = _slOn && _slController.text.isNotEmpty
                  ? (double.tryParse(_slController.text.replaceAll(',', '')) ?? 0.0)
                  : 0.0;
              final positionId = int.tryParse(p.orderId) ?? 0;
              final activeAccount = Get.find<AccountController>().activeMT5Account;
              if (activeAccount == null || activeAccount.metaAccountNumber.isEmpty) {
                if (Get.isRegistered<AppNotificationController>()) {
                  Get.find<AppNotificationController>().showError(
                    title: 'Error',
                    message: 'No active trading account found',
                  );
                }
                return;
              }
              final success = await _c.updateTPSL(
                mt5Account: activeAccount.metaAccountNumber,
                positionId: positionId,
                stopLoss: stopLoss,
                takeProfit: takeProfit,
                digits: p.digits,
              );
              if (success) Navigator.pop(c);
            }),
            SizedBox(height: 8.h),
          ],
        );
      }),
    );
  }

  Widget _modifyTpSlCard(
    BuildContext c, {
    required String label,
    required Color color,
    required bool on,
    required TextEditingController controller,
    required ValueChanged<bool> onToggle,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: MetaTheme.softBg(c),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: on ? color : MetaTheme.subText(c),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: on,
                  onChanged: (val) {
                    onToggle(val);
                    if (val) {
                      final currentText = controller.text;
                      final parsed =
                          double.tryParse(currentText.replaceAll(',', '')) ??
                              0.0;
                      if (currentText.isEmpty || parsed == 0.0) {
                        final entryPrice =
                            double.tryParse(widget.position.entryPrice) ?? 0.0;
                        if (entryPrice > 0) {
                          final isBuy =
                              widget.position.action.toLowerCase() == 'buy';
                          final isJPY = widget.position.symbol.contains('JPY') ||
                              widget.position.symbol.contains('GOLD') ||
                              widget.position.symbol.contains('XAU');
                          if (label == 'TP') {
                            final standardReward = isJPY ? 1.00 : 0.0100;
                            final defaultTP = isBuy
                                ? entryPrice + standardReward
                                : entryPrice - standardReward;
                            controller.text =
                                _fmt(defaultTP, widget.position.digits);
                          } else {
                            final standardRisk = isJPY ? 0.50 : 0.0050;
                            final defaultSL = isBuy
                                ? entryPrice - standardRisk
                                : entryPrice + standardRisk;
                            controller.text =
                                _fmt(defaultSL, widget.position.digits);
                          }
                        }
                      }
                    } else {
                      controller.clear();
                    }
                    if (label == 'SL') _calculateTPFromRiskReward();
                  },
                  activeColor: Colors.white,
                  activeTrackColor: color,
                ),
              ),
            ],
          ),
          if (on) ...[
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: on ? onDecrement : null,
                  child: Container(
                    width: 36.w,
                    height: 36.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.remove, color: color, size: 18.sp),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppTextFormField(
                    controller: controller,
                    enabled: on,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: on ? MetaTheme.mainText(c) : MetaTheme.subText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: MetaTheme.card(c),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 4.w, vertical: 8.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: MetaTheme.divider(c)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: MetaTheme.divider(c)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: color, width: 1.5),
                      ),
                    ),
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: on ? onIncrement : null,
                  child: Container(
                    width: 36.w,
                    height: 36.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.add, color: color, size: 18.sp),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Order ticket (preserved) ──────────────────────────────────────────────────
typedef _Submit = Future<bool> Function(bool isSell, OrderType type,
    double vol, String? price, String? tp, String? sl);

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
  int _orderIdx = 0;
  bool _tp = false;
  bool _sl = false;
  double _vol = 0.01;
  bool _placing = false;
  late final ChartSocketController _socketController;
  late final TextEditingController _priceController;
  late final TextEditingController _tpController;
  late final TextEditingController _slController;
  late final TradingController _c;

  OrderType get _type {
    switch (_orderIdx) {
      case 1:
        return _isSell ? OrderType.sellLimit : OrderType.buyLimit;
      case 2:
        return _isSell ? OrderType.sellStop : OrderType.buyStop;
      case 3:
        return _isSell ? OrderType.sellStopLimit : OrderType.buyStopLimit;
      default:
        return _isSell ? OrderType.sellMarket : OrderType.buyMarket;
    }
  }

  @override
  void initState() {
    super.initState();
    _socketController = Get.find<ChartSocketController>();
    _socketController.changeSymbol(widget.symbol);
    _c = Get.find<TradingController>();
    _priceController = TextEditingController(
        text: (_isSell ? widget.bid : widget.ask).toStringAsFixed(widget.digits));
    _tpController = TextEditingController();
    _slController = TextEditingController();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _socketController.getSocketData();
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _tpController.dispose();
    _slController.dispose();
    super.dispose();
  }

  void _calculateTPFromRiskRewardOrderTicket(double entryPrice) {
    if (!_sl || !_tp) return;
    final slPrice =
        double.tryParse(_slController.text.replaceAll(',', '')) ?? 0.0;
    if (slPrice <= 0 || entryPrice <= 0) return;
    final isBuy = !_isSell;
    double tpPrice;
    if (isBuy) {
      final risk = entryPrice - slPrice;
      tpPrice = entryPrice + (2 * risk);
    } else {
      final risk = slPrice - entryPrice;
      tpPrice = entryPrice - (2 * risk);
    }
    _tpController.text = tpPrice.toStringAsFixed(widget.digits);
  }

  @override
  Widget build(BuildContext c) {
    return _Sheet(
      child: Obx(() {
        final bid = _socketController.getBidPrice() ?? widget.bid;
        final ask = _socketController.getAskPrice() ?? widget.ask;
        final price = _isSell ? bid : ask;
        if (_orderIdx == 0) {
          _priceController.text = price.toStringAsFixed(widget.digits);
        } else if (_priceController.text.isEmpty) {
          _priceController.text = price.toStringAsFixed(widget.digits);
        }
        final color = _isSell ? MetaTheme.sell(c) : MetaTheme.buy(c);
        double _safeSpread() {
          if (ask.isNaN || ask.isInfinite || bid.isNaN || bid.isInfinite) {
            return 0.0;
          }
          final delta = (ask - bid).abs() * pow10(widget.digits);
          if (delta.isNaN || delta.isInfinite) return 0.0;
          return delta.round().toDouble();
        }

        final spread = _safeSpread();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
              decoration: BoxDecoration(
                color: _isSell ? MetaTheme.pillBg(c) : MetaTheme.buyTint(c),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.symbol,
                          style: TextStyle(
                              color: MetaTheme.mainText(c),
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800)),
                      SizedBox(width: 2.w),
                      Icon(Icons.keyboard_arrow_down,
                          color: MetaTheme.subText(c), size: 18.sp),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                            color: MetaTheme.card(c),
                            borderRadius: BorderRadius.circular(5.r)),
                        child: Text('Spread $spread',
                            style: MetaTheme.label(c)
                                .copyWith(fontSize: 10.sp)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bidAsk(c, 'BID',
                          bid.toStringAsFixed(widget.digits),
                          MetaTheme.sell(c)),
                      SizedBox(width: 16.w),
                      _bidAsk(c, 'ASK',
                          ask.toStringAsFixed(widget.digits),
                          MetaTheme.buy(c)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(child: _sideBtn(c, 'Sell', true)),
                SizedBox(width: 12.w),
                Expanded(child: _sideBtn(c, 'Buy', false)),
              ],
            ),
            SizedBox(height: 12.h),
            _segment(c),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: MetaTheme.softBg(c),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 10.h),
                    child: Row(
                      children: [
                        Text('PRICE',
                            style:
                                MetaTheme.label(c).copyWith(fontSize: 12.sp)),
                        const Spacer(),
                        if (_orderIdx == 0)
                          Text(price.toStringAsFixed(widget.digits),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800))
                        else
                          SizedBox(
                            width: 120.w,
                            child: AppTextFormField(
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: color,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: MetaTheme.card(c),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 8.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide:
                                      BorderSide(color: MetaTheme.divider(c)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide:
                                      BorderSide(color: MetaTheme.divider(c)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide:
                                      BorderSide(color: color, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: MetaTheme.divider(c)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 10.h),
                    child: Row(
                      children: [
                        Text('VOLUME',
                            style:
                                MetaTheme.label(c).copyWith(fontSize: 12.sp)),
                        const Spacer(),
                        _stepBtn(c, Icons.remove, color,
                            () => setState(() => _vol = (_vol - 0.01).clamp(0.01, 100))),
                        SizedBox(width: 18.w),
                        Text(_vol.toStringAsFixed(2),
                            style: TextStyle(
                                color: MetaTheme.mainText(c),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _tpSlCard(
                    c,
                    label: 'TP',
                    color: MetaTheme.tpGreen,
                    on: _tp,
                    controller: _tpController,
                    onToggle: (v) => setState(() => _tp = v),
                    onIncrement: () {
                      final curVal =
                          double.tryParse(_tpController.text.replaceAll(',', '')) ??
                              price;
                      final step = 1 / pow10(widget.digits);
                      _tpController.text =
                          (curVal + step).toStringAsFixed(widget.digits);
                    },
                    onDecrement: () {
                      final curVal =
                          double.tryParse(_tpController.text.replaceAll(',', '')) ??
                              price;
                      final step = 1 / pow10(widget.digits);
                      _tpController.text =
                          (curVal - step).toStringAsFixed(widget.digits);
                    },
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _tpSlCard(
                    c,
                    label: 'SL',
                    color: MetaTheme.slRed,
                    on: _sl,
                    controller: _slController,
                    onToggle: (v) => setState(() => _sl = v),
                    onIncrement: () {
                      final curVal =
                          double.tryParse(_slController.text.replaceAll(',', '')) ??
                              price;
                      final step = 1 / pow10(widget.digits);
                      _slController.text =
                          (curVal + step).toStringAsFixed(widget.digits);
                      _calculateTPFromRiskRewardOrderTicket(price);
                    },
                    onDecrement: () {
                      final curVal =
                          double.tryParse(_slController.text.replaceAll(',', '')) ??
                              price;
                      final step = 1 / pow10(widget.digits);
                      _slController.text =
                          (curVal - step).toStringAsFixed(widget.digits);
                      _calculateTPFromRiskRewardOrderTicket(price);
                    },
                    onChanged: (_) =>
                        _calculateTPFromRiskRewardOrderTicket(price),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _btn(
              c,
              '',
              color,
              _placing
                  ? null
                  : () async {
                      setState(() => _placing = true);
                      final priceStr =
                          _orderIdx == 0 ? null : _priceController.text;
                      final tpStr = _tp && _tpController.text.isNotEmpty
                          ? _tpController.text
                          : null;
                      final slStr = _sl && _slController.text.isNotEmpty
                          ? _slController.text
                          : null;
                      final success = await widget.onSubmit(
                          _isSell, _type, _vol, priceStr, tpStr, slStr);
                      if (mounted) {
                        setState(() => _placing = false);
                        if (success) {
                          Navigator.pop(c);
                        } else {
                          final errMsg = _c.errorMessage;
                          if (Get.isRegistered<AppNotificationController>()) {
                            Get.find<AppNotificationController>().showError(
                              title: 'Error',
                              message: errMsg.isNotEmpty
                                  ? errMsg
                                  : 'Failed to place order',
                            );
                          }
                        }
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
                            '${_vol.toStringAsFixed(2)} ${widget.symbol} @ ${['Market', 'Limit', 'Stop', 'Stop Limit'][_orderIdx]}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.sp)),
                      ],
                    ),
            ),
            SizedBox(height: 8.h),
          ],
        );
      }),
    );
  }

  Widget _sideBtn(BuildContext c, String label, bool sell) {
    final selected = _isSell == sell;
    final color = sell ? MetaTheme.sell(c) : MetaTheme.buy(c);
    return GestureDetector(
      onTap: () => setState(() => _isSell = sell),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 9.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : MetaTheme.softBg(c),
          borderRadius: BorderRadius.circular(10.r),
          border: selected ? Border.all(color: color, width: 1) : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : MetaTheme.subText(c),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _segment(BuildContext c) {
    final labels = ['Market', 'Limit', 'Stop', 'Stop Limit'];
    return Container(
      decoration: BoxDecoration(
          color: MetaTheme.softBg(c),
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
                  color: active ? MetaTheme.card(c) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        color: active
                            ? MetaTheme.mainText(c)
                            : MetaTheme.subText(c),
                        fontSize: 13.sp,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _tpSlCard(
    BuildContext c, {
    required String label,
    required Color color,
    required bool on,
    required TextEditingController controller,
    required ValueChanged<bool> onToggle,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    ValueChanged<String>? onChanged,
  }) {
    final price = _isSell
        ? (_socketController.getBidPrice() ?? widget.bid)
        : (_socketController.getAskPrice() ?? widget.ask);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: MetaTheme.softBg(c),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: on ? color : MetaTheme.subText(c),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: on,
                  onChanged: (newVal) {
                    onToggle(newVal);
                    if (newVal) {
                      final isBuy = !_isSell;
                      final isJPY = widget.symbol.contains('JPY') ||
                          widget.symbol.contains('GOLD') ||
                          widget.symbol.contains('XAU');
                      if (label == 'TP') {
                        final standardReward = isJPY ? 1.00 : 0.0100;
                        final defaultTP = isBuy
                            ? price + standardReward
                            : price - standardReward;
                        controller.text =
                            defaultTP.toStringAsFixed(widget.digits);
                      } else {
                        final standardRisk = isJPY ? 0.50 : 0.0050;
                        final defaultSL = isBuy
                            ? price - standardRisk
                            : price + standardRisk;
                        controller.text =
                            defaultSL.toStringAsFixed(widget.digits);
                        _calculateTPFromRiskRewardOrderTicket(price);
                      }
                    } else {
                      controller.clear();
                    }
                  },
                  activeColor: Colors.white,
                  activeTrackColor: color,
                ),
              ),
            ],
          ),
          if (on) ...[
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _stepBtn(c, Icons.remove, color, on ? onDecrement : () {}),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppTextFormField(
                    controller: controller,
                    enabled: on,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: on ? MetaTheme.mainText(c) : MetaTheme.subText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: MetaTheme.card(c),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 4.w, vertical: 8.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: MetaTheme.divider(c)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: MetaTheme.divider(c)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: color, width: 1.5),
                      ),
                    ),
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(width: 8.w),
                _stepBtn(c, Icons.add, color, on ? onIncrement : () {}),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared helpers (preserved) ────────────────────────────────────────────────
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
        color: MetaTheme.bg(c),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: child,
          ),
        ),
      ),
    );
  }
}


Widget _bidAsk(BuildContext c, String label, String value, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: MetaTheme.label(c).copyWith(fontSize: 11.sp)),
      SizedBox(height: 2.h),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 20.sp, fontWeight: FontWeight.w800)),
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
        color: onTap == null ? MetaTheme.subText(c) : color,
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
      width: 36.w,
      height: 36.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(icon, color: color, size: 18.sp),
    ),
  );
}
