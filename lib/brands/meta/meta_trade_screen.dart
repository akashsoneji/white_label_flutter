import 'dart:async';
import 'package:crm_app/constants/text_styles.dart';
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
import 'meta_close_position_screen.dart';
import 'meta_modify_position_screen.dart';
import 'meta_new_order_screen.dart';
import 'package:crm_app/services/language_service.dart';

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
  /// Called from the position row's action sheet when the user picks
  /// "Chart" — the shell is expected to switch to the Chart tab (index 1).
  final ValueChanged<int>? onSwitchTab;

  /// Called when the user taps the hamburger icon in the top-left.
  /// The shell is expected to switch to the Settings tab (index 4).
  final VoidCallback? onHamburgerTap;

  const MetaTradeScreen({
    super.key,
    this.onSwitchTab,
    this.onHamburgerTap,
  });

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
                  label: Get.find<LanguageService>().tr('meta_trade_positions'),
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
                            // Swipe-strip "New order" → push the
                            // dedicated Meta New Order screen pre-filled
                            // with this position's symbol. Same behavior
                            // as the long-press action sheet's
                            // "New order".
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    MetaNewOrderScreen(symbol: p.symbol),
                              ),
                            );
                            break;
                          case _PosAction.chart:
                            // Swipe-strip "Chart" → update the chart
                            // socket's current symbol so the TradingView
                            // WebView re-renders with this symbol, then
                            // ask the shell to switch to the Chart tab.
                            // Matches the long-press action sheet's
                            // "Chart" item.
                            if (p.symbol.isNotEmpty) {
                              try {
                                Get.find<ChartSocketController>()
                                    .currentSymbol
                                    .value = p.symbol;
                              } catch (_) {}
                            }
                            widget.onSwitchTab?.call(1);
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
                  label: Get.find<LanguageService>().tr('meta_trade_orders'),
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
            onPressed: () => widget.onHamburgerTap?.call(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Get.find<LanguageService>().tr('meta_trade_trades'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: MetaTheme.mainText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    )),
                SizedBox(height: 2.h),
                Text(_fmtPL(netPL) + ' USD',
                    style: AppTextStyles.bodyText.copyWith(
                      color: plColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    )),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.note_add_outlined, color: sub, size: 22.sp),
            onPressed: (){
               Navigator.of(c).push(
                    MaterialPageRoute(
                      builder: (_) => MetaNewOrderScreen(),
                    )
               );
            },
            tooltip: Get.find<LanguageService>().tr('meta_trade_add_ticket'),
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
                style: AppTextStyles.bodyText.copyWith(
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
                style: AppTextStyles.bodyText.copyWith(
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
                style: AppTextStyles.bodyText.copyWith(
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
          style: AppTextStyles.bodyText.copyWith(
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
      // Fill the Stack's height (= the position row's natural height,
      // which grows when the row is expanded with detail). This way
      // the strip always matches the row height — no clipping of
      // icons in the collapsed state, no empty space below in the
      // expanded state.
      height: double.infinity,
      alignment: Alignment.center,
      child: Row(
        // Expanded already enforces equal widths, so no extra
        // mainAxisAlignment is needed; using `start` removes the
        // implicit outer gutters that `spaceEvenly` adds.
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _actionButton(c, Icons.edit_note, 'Close',
              () => onAction(_PosAction.close)),
          _actionButton(c, Icons.add_circle_outline, 'Modify',
              () => onAction(_PosAction.modify)),
          _actionButton(c, Icons.add_box_outlined, Get.find<LanguageService>().tr('meta_trade_new_order'),
              () => onAction(_PosAction.newOrder)),
          _actionButton(c, Icons.show_chart, Get.find<LanguageService>().tr('meta_trade_chart'),
              () => onAction(_PosAction.chart)),
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
            Text(
              Get.find<LanguageService>()
                  .tr('meta_trade_label_colon', {'label': '${label}'}),
              style: AppTextStyles.bodyText.copyWith(
                color: subtleColor,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Text(value,
                style: AppTextStyles.bodyText.copyWith(
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
                cell('#', p.orderId.toString(),
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
                        style: AppTextStyles.bodyText.copyWith(
                          color: MetaTheme.mainText(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ', ${isBuy ? 'buy' : 'sell'} ${p.volume.toStringAsFixed(2)}',
                        style: AppTextStyles.bodyText.copyWith(
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
                  Text(Get.find<LanguageService>().tr('meta_trade_screen_placed'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: MetaTheme.subText(c),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ))
                else
                  Text(_fmtPL(p.profitLoss),
                      style: AppTextStyles.bodyText.copyWith(
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
                style: AppTextStyles.bodyText.copyWith(
                  color: MetaTheme.subText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Text(
                '${_fmt(entry, p.digits)}  →  ${_fmt(cur, p.digits)}',
                style: AppTextStyles.bodyText.copyWith(
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
      if (list.isEmpty) return;
      await _c.closePositions(list);
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
                style: AppTextStyles.bodyText.copyWith(
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MetaClosePositionScreen(
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
      ),
    );
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
                        style: AppTextStyles.bodyText.copyWith(
                            color: text,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 8.w),
                    Text(p.action,
                        style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 13.sp)),
                    const Spacer(),
                    Text('${p.volume.toStringAsFixed(2)} lot',
                        style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 13.sp)),
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
                        style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 12.sp)),
                    if (_d(p.currentPrice) > 0) ...[
                      Text('  →  ${_fmt(_d(p.currentPrice), p.digits)}',
                          style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 12.sp)),
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
                        title: Get.find<LanguageService>().tr('meta_trade_error'),
                        message: Get.find<LanguageService>().tr('celestial_trade_screen_no_active_trading_account_found'),
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
                        title: Get.find<LanguageService>().tr('meta_trade_success'),
                        message: Get.find<LanguageService>().tr('celestial_trade_screen_pending_order_cancelled'),
                      );
                    } else {
                      Get.find<AppNotificationController>().showError(
                        title: Get.find<LanguageService>().tr('meta_trade_error'),
                        message: errMsg,
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  alignment: Alignment.center,
                  child: Text(Get.find<LanguageService>().tr('meta_trade_cancel_order'),
                      style: AppTextStyles.bodyText.copyWith(
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
                  child: Text(Get.find<LanguageService>().tr('meta_trade_dismiss'),
                      style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 15.sp)),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MetaModifyPositionScreen(position: p),
        fullscreenDialog: true,
      ),
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
                title: Get.find<LanguageService>().tr('meta_trade_error'),
                message: Get.find<LanguageService>().tr('celestial_trade_screen_no_active_trading_account_found'),
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
                label: Get.find<LanguageService>().tr('meta_trade_close_position'),
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
                label: Get.find<LanguageService>().tr('meta_trade_modify_position'),
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
                label: Get.find<LanguageService>().tr('meta_trade_new_order'),
                onTap: () {
                  final sym = p.symbol;
                  Navigator.pop(sheetCtx);
                  // Push the dedicated Meta New Order screen pre-filled
                  // with this position's symbol (matches the Watchlist's
                  // "New Order" row action).
                  Navigator.of(c).push(
                    MaterialPageRoute(
                      builder: (_) => MetaNewOrderScreen(symbol: sym),
                    ),
                  );
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
                label: Get.find<LanguageService>().tr('meta_trade_chart'),
                onTap: () {
                  final sym = p.symbol;
                  Navigator.pop(sheetCtx);
                  // Update the chart socket's current symbol so the
                  // TradingView WebView re-renders with this symbol,
                  // then ask the shell to switch to the Chart tab.
                  if (sym.isNotEmpty) {
                    try {
                      Get.find<ChartSocketController>()
                          .currentSymbol
                          .value = sym;
                    } catch (_) {}
                  }
                  widget.onSwitchTab?.call(1);
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
                label: Get.find<LanguageService>().tr('meta_trade_bulk_ops'),
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
                style: AppTextStyles.bodyText.copyWith(
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
enum _PosAction {
  close,
  partial,
  modify,
  newOrder,
  chart,
}

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
    // Must match the strip's rendered width (see LayoutBuilder below)
    // so the row slides far enough to reveal all 4 action buttons.
    _actionStripWidth ??= MediaQuery.sizeOf(context).width * 0.62;
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
        // Match the strip's rendered width (also 0.62 of screen) so a
        // full swipe reveals ALL 4 buttons (Close / Partial / Modify /
        // New). When these two values differ, the row only slides far
        // enough to expose the rightmost icons and the leftmost ones
        // (Close, Partial) end up hidden behind the row content.
        _actionStripWidth = constraints.maxWidth * 0.62;
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
              // Action strip behind, anchored to the right edge with
              // a width equal to the swipe target (_actionStripWidth).
              // Using Positioned.fill would make the strip as wide as
              // the whole row, so only the rightmost icons would be
              // visible after the row slides left by _actionStripWidth.
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _actionStripWidth,
                child: widget.actionStrip,
              ),
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

// ── Detail / pending / modify / new-order sheets (moved to separate files) ──

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
                          style: AppTextStyles.bodyText.copyWith(
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
                        child: Text(Get.find<LanguageService>().tr('meta_trade_spread', {'spread': '$spread'}),
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
                        Text(Get.find<LanguageService>().tr('meta_trade_column_price'),
                            style:
                                MetaTheme.label(c).copyWith(fontSize: 12.sp)),
                        const Spacer(),
                        if (_orderIdx == 0)
                          Text(price.toStringAsFixed(widget.digits),
                              style: AppTextStyles.bodyText.copyWith(
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
                              style: AppTextStyles.bodyText.copyWith(
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
                        Text(Get.find<LanguageService>().tr('meta_trade_column_volume'),
                            style:
                                MetaTheme.label(c).copyWith(fontSize: 12.sp)),
                        const Spacer(),
                        _stepBtn(c, Icons.remove, color,
                            () => setState(() => _vol = (_vol - 0.01).clamp(0.01, 100))),
                        SizedBox(width: 18.w),
                        Text(_vol.toStringAsFixed(2),
                            style: AppTextStyles.bodyText.copyWith(
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
                              title: Get.find<LanguageService>().tr('meta_trade_error'),
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
                            style: AppTextStyles.bodyText.copyWith(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800)),
                        Text(
                            '${_vol.toStringAsFixed(2)} ${widget.symbol} @ ${['Market', 'Limit', 'Stop', 'Stop Limit'][_orderIdx]}',
                            style: AppTextStyles.bodyText.copyWith(
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
            style: AppTextStyles.bodyText.copyWith(
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
                    style: AppTextStyles.bodyText.copyWith(
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
                  style: AppTextStyles.bodyText.copyWith(
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
                    style: AppTextStyles.bodyText.copyWith(
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
          style: AppTextStyles.bodyText.copyWith(
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
              style: AppTextStyles.bodyText.copyWith(
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
