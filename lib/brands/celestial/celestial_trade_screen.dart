import 'dart:async';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
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
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'celestial_theme.dart';
import 'package:crm_app/services/language_service.dart';

double _d(String? v) => double.tryParse(v ?? '') ?? 0;
String _fmt(double v, int d) => v.toStringAsFixed(d);
String _fmtPL(double v) => '${v < 0 ? '' : '+'}${v.toStringAsFixed(2)}';

/// Trade screen — positions, account summary, order ticket, close, modify.
class CelestialTradeScreen extends StatefulWidget {
  const CelestialTradeScreen({super.key});

  @override
  State<CelestialTradeScreen> createState() => _CelestialTradeScreenState();
}

class _CelestialTradeScreenState extends State<CelestialTradeScreen> {
  TradingController get _c => Get.find<TradingController>();
  int _tab = 0; // 0 Active  1 Pending
  StreamSubscription? _accountChangeSubscription;
  String? _lastAccountNumber;

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
        print(
          'Celestial Trade Screen: Error ensuring WebSocket connections: $e',
        );
      }
    }
  }

  void _listenForAccountChanges() {
    try {
      final accountController = Get.find<AccountController>();
      final currentAccount = accountController.activeMT5Account;
      _lastAccountNumber = currentAccount?.metaAccountNumber;

      _accountChangeSubscription?.cancel();
      _accountChangeSubscription = accountController.activeMT5AccountRx.listen((
        account,
      ) {
        if (!mounted) return;

        final newAccountNumber = account?.metaAccountNumber;
        if (newAccountNumber != null &&
            newAccountNumber != _lastAccountNumber) {
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
                print(
                  'Celestial Trade Screen: Error handling account change: $e',
                );
              }
            }
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print(
          'Celestial Trade Screen: Error setting up account change listener: $e',
        );
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
      backgroundColor: CelTheme.bg(context),
      body: SafeArea(
        child: Obx(() {
          final account = _c.accountInfoRx.value;
          final active = _c.marketPositionsRx;
          final pending = _c.pendingPositions;
          final netPL = active.fold<double>(0, (s, p) => s + p.profitLoss);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, netPL),
              _summary(context, account),
              _tabBar(context, active.length, pending.length),
              Divider(
                height: 1,
                thickness: 0.5,
                color: CelTheme.divider(context),
              ),
              Expanded(
                child:
                    _tab == 0
                        ? _posList(context, active.toList())
                        : _posList(context, pending.toList()),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Net P/L header ────────────────────────────────────────────────────────
  Widget _header(BuildContext c, double netPL) {
    final Color col;
    if (netPL > 0) {
      col = CelTheme.tpGreen;
    } else if (netPL < 0) {
      col = CelTheme.sell(c);
    } else {
      col = CelTheme.mainText(c);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Get.find<LanguageService>().tr('celestial_trade_trades'), style: CelTheme.title(c)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtPL(netPL),
                style: AppTextStyles.bodyText.copyWith(
                  color: col,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(Get.find<LanguageService>().tr('celestial_trade_net_pl'), style: CelTheme.label(c)),
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
          child: Text(lbl, style: CelTheme.label(c).copyWith(fontSize: 12.sp)),
        ),
        Text(
          val,
          style: AppTextStyles.bodyText.copyWith(
            color: CelTheme.mainText(c),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
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
      child: Column(
        children: [
          row2('Balance', f(a?.balance), 'Equity', f(a?.equity)),
          row2('Margin', f(a?.margin), 'Free Margin', f(a?.marginFree)),
          row2(
            'Margin Level',
            '${(a?.marginLevel ?? 0).toStringAsFixed(0)}%',
            'Floating P/L',
            _fmtPL(a?.profit ?? 0),
          ),
        ],
      ),
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
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  color: active ? CelTheme.mainText(c) : CelTheme.subText(c),
                  fontSize: 13.sp,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: active ? CelTheme.buy(c) : CelTheme.softBg(c),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '$count',
                    style: AppTextStyles.bodyText.copyWith(
                      color: active ? Colors.white : CelTheme.subText(c),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
          // + new order button
          GestureDetector(
            onTap: _openOrderTicket,
            child: Icon(
              Icons.add,
              color: CelTheme.mainText(context),
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          // ... three-dot close-positions menu
          GestureDetector(
            onTap: () => _showCloseMenu(context),
            child: Icon(
              Icons.more_horiz,
              color: CelTheme.mainText(context),
              size: 22.sp,
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
            Text(
              _tab == 0 ? 'No open positions' : 'No pending orders',
              style: AppTextStyles.bodyText.copyWith(
                color: CelTheme.subText(c),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      itemCount: positions.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) => _card(c, positions[i], isPending: _tab == 1),
    );
  }

  // ── Position card ──────────────────────────────────────────────────────────
  Widget _card(BuildContext c, TradePosition p, {bool isPending = false}) {
    final isBuy = p.action.toUpperCase().contains('BUY');
    final sideColor = isBuy ? CelTheme.buy(c) : CelTheme.sell(c);
    final plColor = p.profitLoss >= 0 ? CelTheme.tpGreen : CelTheme.sell(c);
    final entry = _d(p.entryPrice);
    final cur = _d(p.currentPrice);
    final tp = _d(p.takeProfit);
    final sl = _d(p.stopLoss);

    return GestureDetector(
      onTap: () => _openDetail(p, isPending: isPending),
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
                Text(
                  p.symbol,
                  style: AppTextStyles.bodyText.copyWith(
                    color: CelTheme.mainText(c),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '${isBuy ? 'BUY' : 'SELL'} ${p.volume.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyText.copyWith(
                      color: sideColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _fmtPL(p.profitLoss),
                  style: AppTextStyles.bodyText.copyWith(
                    color: plColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            // Row 2: entry → current prices
            Row(
              children: [
                // Icon(Icons.arrow_forward, size: 12.sp, color: CelTheme.subText(c)),
                // SizedBox(width: 4.w),
                Text(
                  '${_fmt(entry, p.digits)}  →  ${_fmt(cur, p.digits)}',
                  style: AppTextStyles.bodyText.copyWith(
                    color: CelTheme.subText(c),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  p.time,
                  style: AppTextStyles.bodyText.copyWith(
                    color: CelTheme.subText(c),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
      child: Text(
        '$label $value',
        style: AppTextStyles.bodyText.copyWith(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metaText(BuildContext c, String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: AppTextStyles.bodyText.copyWith(
              color: CelTheme.subText(c),
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: AppTextStyles.bodyText.copyWith(
              color: CelTheme.mainText(c),
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Close all confirm ──────────────────────────────────────────────────────
  void _showCloseMenu(BuildContext ctx) {
    final positions = _c.marketPositions;

    // Determine the dominant symbol in the list for the "All {sym} with loss" item
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
        final bg = CelTheme.card(ctx);
        final text = CelTheme.mainText(ctx);
        final sub = CelTheme.subText(ctx);

        Widget _item(
          String label,
          VoidCallback? onTap, {
          bool isHeader = false,
          bool isCancel = false,
        }) {
          return InkWell(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: sub.withOpacity(.15), width: .5),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  color:
                      isHeader
                          ? sub
                          : isCancel
                          ? sub
                          : text,
                  fontSize: isHeader ? 13.sp : 15.sp,
                  fontWeight: isHeader ? FontWeight.w400 : FontWeight.w400,
                ),
              ),
            ),
          );
        }

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
              _item('Close Positions', null, isHeader: true),
              _item(
                'All',
                positions.isEmpty ? null : () => closeWith(positions),
              ),
              _item('With profit', () {
                final list = positions.where((p) => p.profitLoss > 0).toList();
                closeWith(list);
              }),
              _item('With loss', () {
                final list = positions.where((p) => p.profitLoss < 0).toList();
                closeWith(list);
              }),
              if (dominantSym != null)
                _item('All $dominantSym With Loss', () {
                  final list =
                      positions
                          .where(
                            (p) => p.symbol == dominantSym && p.profitLoss < 0,
                          )
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

  // ── Position detail sheet ──────────────────────────────────────────────────
  void _openDetail(TradePosition p, {bool isPending = false}) {
    if (isPending) {
      _openPendingDetail(p);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _DetailSheet(
            position: p,
            onModify: () {
              Navigator.pop(context);
              _openModify(p);
            },
            onClose: (volume) async {
              Navigator.pop(context);
              final isFullClose =
                  (volume - p.volume).abs() < 0.0001 || volume >= p.volume;
              await _c.closePosition(
                p.orderId,
                volume: isFullClose ? null : volume,
              );
            },
          ),
    );
  }

  // ── Pending order detail sheet ─────────────────────────────────────────────
  void _openPendingDetail(TradePosition p) {
    final ctx = context;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bg = CelTheme.card(ctx);
        final text = CelTheme.mainText(ctx);
        final sub = CelTheme.subText(ctx);

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
                    Text(
                      p.symbol,
                      style: AppTextStyles.bodyText.copyWith(
                        color: text,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      p.action,
                      style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 13.sp),
                    ),
                    const Spacer(),
                    Text(
                      '${p.volume.toStringAsFixed(2)} lot',
                      style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 13.sp),
                    ),
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
                      style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 12.sp),
                    ),
                    if (_d(p.currentPrice) > 0) ...[
                      Text(
                        '  →  ${_fmt(_d(p.currentPrice), p.digits)}',
                        style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 12.sp),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Divider(height: 1, thickness: 0.5, color: sub.withOpacity(.2)),
              // Cancel pending order button
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  final accountController = Get.find<AccountController>();
                  final activeAccount = accountController.activeMT5Account;
                  if (activeAccount == null ||
                      activeAccount.metaAccountNumber.isEmpty) {
                    if (Get.isRegistered<AppNotificationController>()) {
                      Get.find<AppNotificationController>().showError(
                        title: Get.find<LanguageService>().tr('trading_error'),
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
                        title: Get.find<LanguageService>().tr('common_success'),
                        message: Get.find<LanguageService>().tr('celestial_trade_screen_pending_order_cancelled'),
                      );
                    } else {
                      Get.find<AppNotificationController>().showError(
                        title: Get.find<LanguageService>().tr('trading_error'),
                        message: errMsg,
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  alignment: Alignment.center,
                  child: Text(
                    Get.find<LanguageService>().tr('celestial_trade_cancel_order'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: CelTheme.sell(ctx),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: sub.withOpacity(.2)),
              InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  alignment: Alignment.center,
                  child: Text(
                    Get.find<LanguageService>().tr('celestial_trade_dismiss'),
                    style: AppTextStyles.bodyText.copyWith(color: sub, fontSize: 15.sp),
                  ),
                ),
              ),
              SizedBox(height: 16.h + MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        );
      },
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
    final symbol = positions.isNotEmpty ? positions.first.symbol : 'XAUUSD';
    final p = positions.isNotEmpty ? positions.first : null;
    final accountController = Get.find<AccountController>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => CelestialOrderTicket(
            symbol: symbol,
            canChangeSymbol: true,
            bid: _d(p?.entryPrice),
            ask: _d(p?.currentPrice),
            digits: p?.digits ?? 2,
            onSubmit: (selectedSymbol, isSell, type, volume, price, tp, sl) {
              final activeAccount = accountController.activeMT5Account;
              if (activeAccount == null ||
                  activeAccount.metaAccountNumber.isEmpty) {
                if (Get.isRegistered<AppNotificationController>()) {
                  Get.find<AppNotificationController>().showError(
                    title: Get.find<LanguageService>().tr('trading_error'),
                    message: Get.find<LanguageService>().tr('celestial_trade_screen_no_active_trading_account_found'),
                  );
                }
                return Future.value(false);
              }
              return _c.placeTradeOrder(
                mt5Account: activeAccount.metaAccountNumber,
                symbol: selectedSymbol,
                volume: volume.toStringAsFixed(2),
                orderType: type,
                price: price,
                takeProfit: tp,
                stopLoss: sl,
              );
            },
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
typedef _CloseCallback = Future<void> Function(double volume);

class _DetailSheet extends StatefulWidget {
  final TradePosition position;
  final VoidCallback onModify;
  final _CloseCallback onClose;
  const _DetailSheet({
    required this.position,
    required this.onModify,
    required this.onClose,
  });

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late final TextEditingController _volController;

  @override
  void initState() {
    super.initState();
    _volController = TextEditingController(
      text: widget.position.volume.toStringAsFixed(2),
    );
    _volController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _volController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final TradingController _c = Get.find<TradingController>();
    return _Sheet(
      child: Obx(() {
        final p =
            _c.marketPositions.firstWhereOrNull(
              (pos) => pos.orderId == widget.position.orderId,
            ) ??
            _c.pendingPositions.firstWhereOrNull(
              (pos) => pos.orderId == widget.position.orderId,
            ) ??
            widget.position;
        final isBuy = p.action.toUpperCase().contains('BUY');
        final plCol = p.profitLoss >= 0 ? CelTheme.tpGreen : CelTheme.sell(c);
        final side = isBuy ? CelTheme.buy(c) : CelTheme.sell(c);
        final entry = _d(p.entryPrice);
        final cur = _d(p.currentPrice);
        final pct = entry == 0 ? 0.0 : (cur - entry) / entry * 100;
        final tp = _d(p.takeProfit);
        final sl = _d(p.stopLoss);

        return Column(
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
                      Text(
                        p.symbol,
                        style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.mainText(c),
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: side,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '${isBuy ? 'BUY' : 'SELL'} ${p.volume.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyText.copyWith(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Text(
                        '${_fmt(entry, p.digits)}  →  ${_fmt(cur, p.digits)}',
                        style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.mainText(c),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                        style: AppTextStyles.bodyText.copyWith(
                          color: plCol,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        p.profitLoss >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: plCol,
                        size: 18.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _fmtPL(p.profitLoss),
                        style: AppTextStyles.bodyText.copyWith(
                          color: plCol,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                  child: _kv(c, 'COMMISSION', p.commission.toStringAsFixed(2)),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            // Risk management row
            Row(
              children: [
                Text(
                  Get.find<LanguageService>().tr('celestial_trade_risk_management'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: CelTheme.mainText(c),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onModify,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: CelTheme.buyTint(c),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: CelTheme.buy(c),
                          size: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          Get.find<LanguageService>().tr('celestial_trade_modify'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: CelTheme.buy(c),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                  child: _riskBox(
                    c,
                    'Stop Loss',
                    sl > 0 ? _fmt(sl, p.digits) : 'Not Set',
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _riskBox(
                    c,
                    'Take Profit',
                    tp > 0 ? _fmt(tp, p.digits) : 'Not Set',
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            // Volume Input for Partial Close
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: CelTheme.softBg(c),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Text(
                    Get.find<LanguageService>().tr('celestial_trade_volume'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: CelTheme.subText(c),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      final currentVal =
                          double.tryParse(_volController.text) ?? p.volume;
                      final newVal = (currentVal - 0.01).clamp(0.01, p.volume);
                      setState(() {
                        _volController.text = newVal.toStringAsFixed(2);
                      });
                    },
                    child: Icon(
                      Icons.remove,
                      color: CelTheme.subText(c),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  SizedBox(
                    width: 100.w,
                    child: AppTextFormField(
                      controller: _volController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        color: CelTheme.mainText(c),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: CelTheme.card(c),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 8.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: CelTheme.divider(c)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: CelTheme.divider(c)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(
                            color: CelTheme.buy(c),
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        final typedVal = double.tryParse(val);
                        if (typedVal != null) {
                          if (typedVal > p.volume) {
                            _volController.text = p.volume.toStringAsFixed(2);
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 14.w),
                  GestureDetector(
                    onTap: () {
                      final currentVal =
                          double.tryParse(_volController.text) ?? p.volume;
                      final newVal = (currentVal + 0.01).clamp(0.01, p.volume);
                      setState(() {
                        _volController.text = newVal.toStringAsFixed(2);
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: CelTheme.buy(c).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Icon(
                        Icons.add,
                        color: CelTheme.buy(c),
                        size: 16.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _buildCloseButton(c, p),
            SizedBox(height: 8.h),
          ],
        );
      }),
    );
  }

  Widget _buildCloseButton(BuildContext c, TradePosition p) {
    // Parse volume from _volController
    double closeVolume = double.tryParse(_volController.text) ?? p.volume;
    closeVolume = closeVolume.clamp(0.01, p.volume);

    // Calculate proportional profit/loss based on closeVolume
    final totalVolume = p.volume;
    final closeVolumeRatio = totalVolume > 0 ? closeVolume / totalVolume : 0.0;
    final proportionalProfitLoss = p.profitLoss * closeVolumeRatio;
    final isPositive = proportionalProfitLoss >= 0;

    final formattedProfitLoss =
        '\$${PrecisionHelper.formatPnL(proportionalProfitLoss.abs())}';

    final isPartialClose = closeVolume < totalVolume - 0.0001;

    String buttonText;
    if (isPartialClose) {
      buttonText =
          isPositive
              ? 'Close ${PrecisionHelper.formatVolume(closeVolume)} Lots with Profit +$formattedProfitLoss'
              : 'Close ${PrecisionHelper.formatVolume(closeVolume)} Lots with Loss $formattedProfitLoss';
    } else {
      buttonText =
          isPositive
              ? 'Close with Profit +$formattedProfitLoss'
              : 'Close with Loss $formattedProfitLoss';
    }

    final color = isPositive ? CelTheme.tpGreen : CelTheme.slRed;

    return _btn(c, buttonText, color, () async {
      await widget.onClose(closeVolume);
    });
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

    // Format TP/SL according to digits
    _tpController = TextEditingController(
      text: _tpOn ? _fmt(tp, widget.position.digits) : '',
    );
    _slController = TextEditingController(
      text: _slOn ? _fmt(sl, widget.position.digits) : '',
    );

    // Pre-connect/ensure socket connection is active for this symbol
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

  void _incrementValue(
    TextEditingController controller,
    double step,
    bool isTP,
  ) {
    final currentValue =
        double.tryParse(controller.text.replaceAll(',', '')) ??
        (double.tryParse(widget.position.currentPrice) ?? 0.0);
    final newValue = currentValue + step;
    controller.text = _fmt(newValue, widget.position.digits);
    if (!isTP) {
      _calculateTPFromRiskReward();
    }
  }

  void _decrementValue(
    TextEditingController controller,
    double step,
    bool isTP,
  ) {
    final currentValue =
        double.tryParse(controller.text.replaceAll(',', '')) ??
        (double.tryParse(widget.position.currentPrice) ?? 0.0);
    final newValue = (currentValue - step).clamp(0.0, double.infinity);
    controller.text = _fmt(newValue, widget.position.digits);
    if (!isTP) {
      _calculateTPFromRiskReward();
    }
  }

  @override
  Widget build(BuildContext c) {
    return _Sheet(
      child: Obx(() {
        // Find the live position to get real-time price/profit updates
        final p =
            _c.marketPositions.firstWhereOrNull(
              (pos) => pos.orderId == widget.position.orderId,
            ) ??
            _c.pendingPositions.firstWhereOrNull(
              (pos) => pos.orderId == widget.position.orderId,
            ) ??
            widget.position;

        final isBuy = p.action.toUpperCase().contains('BUY');
        final side = isBuy ? CelTheme.buy(c) : CelTheme.sell(c);
        final step = 1 / pow10(p.digits);

        return Column(
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
                  Text(
                    p.symbol,
                    style: AppTextStyles.bodyText.copyWith(
                      color: CelTheme.mainText(c),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: side,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '${isBuy ? 'BUY' : 'SELL'} ${p.volume.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyText.copyWith(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Get.find<LanguageService>().tr('celestial_trade_current'),
                        style: CelTheme.label(c).copyWith(fontSize: 10.sp),
                      ),
                      Text(
                        _fmt(_d(p.currentPrice), p.digits),
                        style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.mainText(c),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                  Text(
                    '#${p.orderId}',
                    style: CelTheme.label(c).copyWith(fontSize: 11.sp),
                  ),
                  Text(
                    p.time,
                    style: CelTheme.label(c).copyWith(fontSize: 11.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            // TP / SL — side by side, switch sits next to each label.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _modifyTpSlCard(
                    c,
                    label: 'TP',
                    color: CelTheme.tpGreen,
                    on: _tpOn,
                    controller: _tpController,
                    onToggle: (v) => setState(() => _tpOn = v),
                    onIncrement:
                        () => _incrementValue(_tpController, step, true),
                    onDecrement:
                        () => _decrementValue(_tpController, step, true),
                    onChanged: (_) {},
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _modifyTpSlCard(
                    c,
                    label: 'SL',
                    color: CelTheme.slRed,
                    on: _slOn,
                    controller: _slController,
                    onToggle: (v) => setState(() => _slOn = v),
                    onIncrement:
                        () => _incrementValue(_slController, step, false),
                    onDecrement:
                        () => _decrementValue(_slController, step, false),
                    onChanged: (_) => _calculateTPFromRiskReward(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            _btn(c, Get.find<LanguageService>().tr('celestial_trade_modify'), CelTheme.buy(c), () async {
              final double takeProfit =
                  _tpOn && _tpController.text.isNotEmpty
                      ? (double.tryParse(
                            _tpController.text.replaceAll(',', ''),
                          ) ??
                          0.0)
                      : 0.0;
              final double stopLoss =
                  _slOn && _slController.text.isNotEmpty
                      ? (double.tryParse(
                            _slController.text.replaceAll(',', ''),
                          ) ??
                          0.0)
                      : 0.0;

              final positionId = int.tryParse(p.orderId) ?? 0;
              final activeAccount =
                  Get.find<AccountController>().activeMT5Account;
              if (activeAccount == null ||
                  activeAccount.metaAccountNumber.isEmpty) {
                if (Get.isRegistered<AppNotificationController>()) {
                  Get.find<AppNotificationController>().showError(
                    title: Get.find<LanguageService>().tr('trading_error'),
                    message: Get.find<LanguageService>().tr('celestial_trade_screen_no_active_trading_account_found'),
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

              if (success) {
                Navigator.pop(c);
              }
            }),
            SizedBox(height: 8.h),
          ],
        );
      }),
    );
  }

  // TP/SL card used in the modify sheet — label + switch on top row,
  // compact +/- and value input below.
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
        color: CelTheme.softBg(c),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  color: on ? color : CelTheme.subText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                          final isJPY =
                              widget.position.symbol.contains('JPY') ||
                              widget.position.symbol.contains('GOLD') ||
                              widget.position.symbol.contains('XAU');
                          if (label == 'TP') {
                            final standardReward = isJPY ? 1.00 : 0.0100;
                            final defaultTP =
                                isBuy
                                    ? entryPrice + standardReward
                                    : entryPrice - standardReward;
                            controller.text = _fmt(
                              defaultTP,
                              widget.position.digits,
                            );
                          } else {
                            final standardRisk = isJPY ? 0.50 : 0.0050;
                            final defaultSL =
                                isBuy
                                    ? entryPrice - standardRisk
                                    : entryPrice + standardRisk;
                            controller.text = _fmt(
                              defaultSL,
                              widget.position.digits,
                            );
                          }
                        }
                      }
                    } else {
                      controller.clear();
                    }
                    if (label == 'SL') {
                      _calculateTPFromRiskReward();
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      color: on ? CelTheme.mainText(c) : CelTheme.subText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: CelTheme.card(c),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 8.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: CelTheme.divider(c)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: CelTheme.divider(c)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Order ticket
// ─────────────────────────────────────────────────────────────────────────────
typedef CelestialSubmitOrder =
    Future<bool> Function(
      String symbol,
      bool isSell,
      OrderType type,
      double vol,
      String? price,
      String? tp,
      String? sl,
    );

class CelestialOrderTicket extends StatefulWidget {
  final String symbol;
  final bool canChangeSymbol;
  final double bid;
  final double ask;
  final int digits;
  final CelestialSubmitOrder onSubmit;
  const CelestialOrderTicket({
    required this.symbol,
    this.canChangeSymbol = false,
    required this.bid,
    required this.ask,
    required this.digits,
    required this.onSubmit,
  });

  @override
  State<CelestialOrderTicket> createState() => _CelestialOrderTicketState();
}

class _CelestialOrderTicketState extends State<CelestialOrderTicket> {
  bool _isSell = true;
  int _orderIdx = 0; // 0 Market  1 Limit  2 Stop  3 Stop Limit
  bool _tp = false;
  bool _sl = false;
  double _vol = 0.01;
  bool _placing = false;
  late String _currentSymbol;
  late int _currentDigits;
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

  LanguageService get languageService => Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    _currentSymbol = widget.symbol;
    _currentDigits = widget.digits;
    _socketController = Get.find<ChartSocketController>();
    _socketController.changeSymbol(_currentSymbol);
    _c = Get.find<TradingController>();

    _priceController = TextEditingController(
      text: (_isSell ? widget.bid : widget.ask).toStringAsFixed(_currentDigits),
    );
    _tpController = TextEditingController();
    _slController = TextEditingController();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _socketController.getSocketData();
      }
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

    _tpController.text = tpPrice.toStringAsFixed(_currentDigits);
  }

  void _showSymbolSelector() {
    final instrumentsController = Get.find<InstrumentsController>();
    showModalBottomSheet(
      context: context,
      backgroundColor: CelTheme.bg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (BuildContext c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  languageService.tr('celestial_select_symbol') ?? 'Select Symbol',
                  style: AppTextStyles.bodyText.copyWith(
                    color: CelTheme.mainText(context),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Divider(height: 1, color: CelTheme.divider(context)),
              Expanded(
                child: Obx(() {
                  final favorites = instrumentsController.instruments.toList();
                  if (favorites.isEmpty) {
                    return Center(
                      child: Text(
                        'No favorites found',
                        style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.subText(context),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final item = favorites[index];
                      return ListTile(
                        title: Text(
                          item.symbol,
                          style: AppTextStyles.bodyText.copyWith(
                            color: CelTheme.mainText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _currentSymbol = item.symbol;
                            _currentDigits = item.digits;
                            _socketController.changeSymbol(_currentSymbol);
                            _priceController.clear();
                            _tpController.clear();
                            _slController.clear();
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext c) {
    return _Sheet(
      child: Obx(() {
        final bid = _socketController.getBidPrice() ?? widget.bid;
        final ask = _socketController.getAskPrice() ?? widget.ask;
        final price = _isSell ? bid : ask;

        if (_orderIdx == 0) {
          _priceController.text = price.toStringAsFixed(_currentDigits);
        } else if (_priceController.text.isEmpty) {
          _priceController.text = price.toStringAsFixed(_currentDigits);
        }

        final color = _isSell ? CelTheme.sell(c) : CelTheme.buy(c);
        // ✅ FIX: Guard ask/bid against NaN/Infinity before .round() — otherwise
        // a transient WS payload with bad prices crashes the build sheet with
        // "UnsupportedError: Infinity or NaN toInt".
        double _safeSpread() {
          if (ask.isNaN || ask.isInfinite || bid.isNaN || bid.isInfinite) {
            return 0.0;
          }
          final delta = (ask - bid).abs() * pow10(_currentDigits);
          if (delta.isNaN || delta.isInfinite) return 0.0;
          return delta.round().toDouble();
        }

        final spread = _safeSpread();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Symbol header
            Container(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
              decoration: BoxDecoration(
                color: _isSell ? CelTheme.pillBg(c) : CelTheme.buyTint(c),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.canChangeSymbol ? _showSymbolSelector : null,
                    child: Row(
                      children: [
                        Text(
                          _currentSymbol,
                          style: AppTextStyles.bodyText.copyWith(
                            color: CelTheme.mainText(c),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        if (widget.canChangeSymbol)
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: CelTheme.subText(c),
                            size: 18.sp,
                          ),
                        SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: CelTheme.card(c),
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Text(
                          'Spread $spread',
                          style: CelTheme.label(c).copyWith(fontSize: 10.sp),
                        ),
                      ),
                    ],
                  ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bidAsk(
                        c,
                        'BID',
                        bid.toStringAsFixed(_currentDigits),
                        CelTheme.sell(c),
                      ),
                      SizedBox(width: 16.w),
                      _bidAsk(
                        c,
                        'ASK',
                        ask.toStringAsFixed(_currentDigits),
                        CelTheme.buy(c),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    child: Row(
                      children: [
                        Text(
                          Get.find<LanguageService>().tr('celestial_trade_column_price'),
                          style: CelTheme.label(c).copyWith(fontSize: 12.sp),
                        ),
                        const Spacer(),
                        if (_orderIdx == 0)
                          Text(
                            price.toStringAsFixed(widget.digits),
                            style: AppTextStyles.bodyText.copyWith(
                              color: color,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          SizedBox(
                            width: 120.w,
                            child: AppTextFormField(
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyText.copyWith(
                                color: color,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: CelTheme.card(c),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 8.h,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(
                                    color: CelTheme.divider(c),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(
                                    color: CelTheme.divider(c),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(
                                    color: color,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: CelTheme.divider(c)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    child: Row(
                      children: [
                        Text(
                          Get.find<LanguageService>().tr('celestial_trade_column_volume'),
                          style: CelTheme.label(c).copyWith(fontSize: 12.sp),
                        ),
                        const Spacer(),
                        _stepBtn(
                          c,
                          Icons.remove,
                          color,
                          () => setState(
                            () => _vol = (_vol - 0.01).clamp(0.01, 100),
                          ),
                        ),
                        SizedBox(width: 18.w),
                        Text(
                          _vol.toStringAsFixed(2),
                          style: AppTextStyles.bodyText.copyWith(
                            color: CelTheme.mainText(c),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 18.w),
                        _stepBtn(
                          c,
                          Icons.add,
                          color,
                          () => setState(() => _vol += 0.01),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            // TP / SL — side by side with switch next to each label
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _tpSlCard(
                    c,
                    label: 'TP',
                    color: CelTheme.tpGreen,
                    on: _tp,
                    controller: _tpController,
                    onToggle: (v) => setState(() => _tp = v),
                    onIncrement: () {
                      final curVal =
                          double.tryParse(
                            _tpController.text.replaceAll(',', ''),
                          ) ??
                          price;
                      final step = 1 / pow10(widget.digits);
                      _tpController.text = (curVal + step).toStringAsFixed(
                        widget.digits,
                      );
                    },
                    onDecrement: () {
                      final curVal =
                          double.tryParse(
                            _tpController.text.replaceAll(',', ''),
                          ) ??
                          price;
                      final step = 1 / pow10(widget.digits);
                      _tpController.text = (curVal - step).toStringAsFixed(
                        widget.digits,
                      );
                    },
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _tpSlCard(
                    c,
                    label: 'SL',
                    color: CelTheme.slRed,
                    on: _sl,
                    controller: _slController,
                    onToggle: (v) => setState(() => _sl = v),
                    onIncrement: () {
                      final curVal =
                          double.tryParse(
                            _slController.text.replaceAll(',', ''),
                          ) ??
                          price;
                      final step = 1 / pow10(widget.digits);
                      _slController.text = (curVal + step).toStringAsFixed(
                        widget.digits,
                      );
                      _calculateTPFromRiskRewardOrderTicket(price);
                    },
                    onDecrement: () {
                      final curVal =
                          double.tryParse(
                            _slController.text.replaceAll(',', ''),
                          ) ??
                          price;
                      final step = 1 / pow10(widget.digits);
                      _slController.text = (curVal - step).toStringAsFixed(
                        widget.digits,
                      );
                      _calculateTPFromRiskRewardOrderTicket(price);
                    },
                    onChanged:
                        (_) => _calculateTPFromRiskRewardOrderTicket(price),
                  ),
                ),
              ],
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
                    final priceStr =
                        _orderIdx == 0 ? null : _priceController.text;
                    final tpStr =
                        _tp && _tpController.text.isNotEmpty
                            ? _tpController.text
                            : null;
                    final slStr =
                        _sl && _slController.text.isNotEmpty
                            ? _slController.text
                            : null;

                    final success = await widget.onSubmit(
                      _currentSymbol,
                      _isSell,
                      _type,
                      _vol,
                      priceStr,
                      tpStr,
                      slStr,
                    );
                    if (mounted) {
                      setState(() => _placing = false);
                      if (success) {
                        Navigator.pop(c);
                      } else {
                        final errMsg = _c.errorMessage;
                        if (Get.isRegistered<AppNotificationController>()) {
                          Get.find<AppNotificationController>().showError(
                            title: 'Error',
                            message:
                                errMsg.isNotEmpty
                                    ? errMsg
                                    : 'Failed to place order',
                          );
                        }
                      }
                    }
                  },
              customChild:
                  _placing
                      ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Column(
                        children: [
                          Text(
                            _isSell ? 'Sell' : 'Buy',
                            style: AppTextStyles.bodyText.copyWith(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${_vol.toStringAsFixed(2)} ${widget.symbol} @ ${['Market', 'Limit', 'Stop', 'Stop Limit'][_orderIdx]}',
                            style: AppTextStyles.bodyText.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11.sp,
                            ),
                          ),
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
    final color = sell ? CelTheme.sell(c) : CelTheme.buy(c);
    return GestureDetector(
      onTap: () => setState(() => _isSell = sell),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 9.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : CelTheme.softBg(c),
          borderRadius: BorderRadius.circular(10.r),
          border: selected ? Border.all(color: color, width: 1) : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            color: selected ? color : CelTheme.subText(c),
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _segment(BuildContext c) {
    final labels = ['Market', 'Limit', 'Stop', 'Stop Limit'];
    return Container(
      decoration: BoxDecoration(
        color: CelTheme.softBg(c),
        borderRadius: BorderRadius.circular(10.r),
      ),
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
                child: Text(
                  labels[i],
                  style: AppTextStyles.bodyText.copyWith(
                    color: active ? CelTheme.mainText(c) : CelTheme.subText(c),
                    fontSize: 13.sp,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // TP/SL card used in the order ticket — label + switch at top, +/-/input below.
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
    final price =
        _isSell
            ? (_socketController.getBidPrice() ?? widget.bid)
            : (_socketController.getAskPrice() ?? widget.ask);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: CelTheme.softBg(c),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  color: on ? color : CelTheme.subText(c),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: on,
                  onChanged: (newVal) {
                    onToggle(newVal);
                    if (newVal) {
                      final isBuy = !_isSell;
                      final isJPY =
                          _currentSymbol.contains('JPY') ||
                          _currentSymbol.contains('GOLD') ||
                          _currentSymbol.contains('XAU');
                      if (label == 'TP') {
                        final standardReward = isJPY ? 1.00 : 0.0100;
                        final defaultTP =
                            isBuy
                                ? price + standardReward
                                : price - standardReward;
                        controller.text = defaultTP.toStringAsFixed(
                          widget.digits,
                        );
                      } else {
                        final standardRisk = isJPY ? 0.50 : 0.0050;
                        final defaultSL =
                            isBuy ? price - standardRisk : price + standardRisk;
                        controller.text = defaultSL.toStringAsFixed(
                          widget.digits,
                        );
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      color: on ? CelTheme.mainText(c) : CelTheme.subText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: CelTheme.card(c),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 8.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: CelTheme.divider(c)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: CelTheme.divider(c)),
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

Widget _kv(BuildContext c, String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: CelTheme.label(c).copyWith(fontSize: 11.sp, letterSpacing: 0.4),
      ),
      SizedBox(height: 2.h),
      Text(
        value,
        style: AppTextStyles.bodyText.copyWith(
          color: CelTheme.mainText(c),
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
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
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            color: CelTheme.mainText(c),
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
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
      Text(
        value,
        style: AppTextStyles.bodyText.copyWith(
          color: color,
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

Widget _btn(
  BuildContext c,
  String label,
  Color color,
  VoidCallback? onTap, {
  Widget? customChild,
}) {
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
      child:
          customChild ??
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
    ),
  );
}

Widget _stepBtn(
  BuildContext c,
  IconData icon,
  Color color,
  VoidCallback onTap,
) {
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
