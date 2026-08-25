import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/widgets/dashboard_bottom_sheet.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/utils/date_helper.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/home/close_position_screen.dart';
import 'package:crm_app/screens/home/edit_order_screen.dart';
import 'package:crm_app/screens/home/brands/iquote/iquote_order_details_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/withdrawal_screen.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/home/brands/iquote/history_filter_sheet.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class IQuotePositionScreen extends StatefulWidget {
  final Function(String)? onNavigateToChart;

  const IQuotePositionScreen({super.key, this.onNavigateToChart});

  @override
  State<IQuotePositionScreen> createState() => _IQuotePositionScreenState();
}

class _IQuotePositionScreenState extends State<IQuotePositionScreen> {
  // Theme-aware tokens — values flip with AppColors.isDarkMode.
  static Color get _bgColor => AppColors.background;
  static Color get _cardColor => AppColors.card;
  static Color get _chipBgColor => AppColors.iconBgTertiary;
  static Color get _accent => AppColors.primary;
  static Color get _green => AppColors.statusGreen;
  static Color get _red => AppColors.statusRed;

  final LanguageService languageService = Get.find<LanguageService>();

  late ScrollController _scrollController;
  bool _isLoadingMore = false;
  StreamSubscription? _accountChangeSubscription;
  String? _lastAccountNumber;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _initializeWebSocketServices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<TradingController>()) return;
      final tradingController = Get.find<TradingController>();

      // Force tab selection to 0 to trigger the same WebSocket refresh that TradeScreen uses
      tradingController.setSelectedTab(0);

      _initializeTradeScreenWebSockets();
      _listenForAccountChanges();

      // ✅ PERF: Ensure DashboardController WS is initialized (same as Vantage TradeScreen)
      try {
        if (Get.isRegistered<DashboardController>()) {
          final dashboardController = Get.find<DashboardController>();
          dashboardController.ensureWebSocketInitialized();
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            'IQuotePositionScreen: Error ensuring WebSocket initialization: $e',
          );
        }
      }
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
      if (kDebugMode) print('IQuotePosition: WS init error: $e');
    }
  }

  void _listenForAccountChanges() {
    try {
      final accountController = Get.find<AccountController>();
      _lastAccountNumber =
          accountController.activeMT5Account?.metaAccountNumber;
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
                Get.find<TradingController>().clearAllTradingData();
              }
              _initializeTradeScreenWebSockets();
              if (mounted) setState(() {});
            } catch (e) {
              if (kDebugMode) print('IQuotePosition: account switch error: $e');
            }
          });
        }
      });
    } catch (e) {
      if (kDebugMode) print('IQuotePosition: account listener error: $e');
    }
  }

  @override
  void dispose() {
    _accountChangeSubscription?.cancel();
    _accountChangeSubscription = null;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    final tradingController = Get.find<TradingController>();
    if (tradingController.selectedTab == 2 && max > 0 && current >= max - 200) {
      _loadMoreIfNeeded();
    }
  }

  void _loadMoreIfNeeded() {
    final tradingController = Get.find<TradingController>();
    if (tradingController.selectedTab == 2 &&
        !_isLoadingMore &&
        !tradingController.isLoadingHistory &&
        tradingController.hasMoreHistoryPages) {
      _isLoadingMore = true;
      tradingController
          .loadNextPage()
          .then((_) {
            if (mounted) _isLoadingMore = false;
          })
          .catchError((_) {
            if (mounted) _isLoadingMore = false;
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // _buildFromRealStrip(),
            // SizedBox(height: 8.h),
            _buildPillTabs(),
            _buildDateFilter(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GetBuilder<TradingController>(
      id: 'account_info',
      builder: (tradingController) {
        final accountInfo = tradingController.accountInfo;
        final balance = accountInfo?.balance ?? 0.00;
        final profit = accountInfo?.profit ?? 0.00;
        final isProfitPositive = profit >= 0;
        final pnlPercent = balance != 0 ? (profit / balance * 100) : 0.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Account chip → opens dashboard bottom sheet (mirrors market tab)
                  GestureDetector(
                    onTap: () => showDashboardBottomSheet(context),
                    child: Obx(() {
                      final active =
                          Get.find<AccountController>().activeMT5Account;
                      final accNumber = active?.metaAccountNumber ?? '------';
                      final rawType =
                          (active?.accountType ?? 'REAL').toUpperCase();
                      final isDemo = rawType == 'DEMO';
                      final badgeLabel = isDemo ? 'DEMO' : 'LIVE';

                      double? profit;
                      if (active != null && Get.isRegistered<DashboardController>()) {
                        final dashCtrl = Get.find<DashboardController>();
                        profit = dashCtrl.accountInfoMap[active.metaAccountNumber]?.profit;
                      }

                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.isDarkMode
                                  ? const Color(0xFF252C41)
                                  : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color:
                                AppColors.isDarkMode
                                    ? Colors.white12
                                    : AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$accNumber',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDemo
                                        ? Colors.orange.withValues(alpha: 0.18)
                                        : Colors.green.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: isDemo ? Colors.orange : Colors.green,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (profit != null && profit != 0.0) ...[
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: (profit >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  '${profit >= 0 ? '+' : ''}${PrecisionHelper.formatPnL(profit)}',
                                  style: TextStyle(
                                    color: profit >= 0 ? Colors.green : Colors.red,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18.r,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Text(
                    balance.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${isProfitPositive ? '+' : '-'}${profit.abs().toStringAsFixed(2)} (${pnlPercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isProfitPositive ? _green : _red,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              _buildMarginBar(),
              _buildAccountMetrics(tradingController),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarginBar() {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(2.r)),
            ),
          ),
        ),
        Expanded(flex: 3, child: Container(height: 3.h, color: _accent)),
        Expanded(
          flex: 1,
          child: Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.horizontal(
                right: Radius.circular(2.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountMetrics(TradingController controller) {
    final currentTab = controller.selectedTab;
    final isHistory = currentTab == 2;

    final accountInfo = controller.accountInfo;
    final totals = controller.tradeHistoryTotals;

    Widget buildItem(String labelKey, String value) {
      return Container(
        width: 100.w, // Allows 3 items per row on typical phone screen
        margin: EdgeInsets.only(bottom: 6.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageService.tr(labelKey),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    List<Widget> children = [];

    if (isHistory) {
      final profit = totals?.profit ?? 0.0;
      final deposit = totals?.deposit ?? 0.0;
      final withdrawal = totals?.withdrawal ?? 0.0;
      final swap = totals?.swap ?? 0.0;
      final commission = totals?.commission ?? 0.0;
      final balance = totals?.balance ?? 0.0;

      children = [
        buildItem('trade_metric_profit', profit.toStringAsFixed(2)),
        buildItem('trade_metric_deposit', deposit.toStringAsFixed(2)),
        buildItem('trade_metric_withdrawal', withdrawal.toStringAsFixed(2)),
        buildItem('Swap', swap.toStringAsFixed(2)),
        buildItem('Commissions', commission.toStringAsFixed(2)),
        buildItem('trade_metric_balance', balance.toStringAsFixed(2)),
      ];
    } else {
      final balance = accountInfo?.balance ?? 0.0;
      final credit = accountInfo?.credit ?? 0.0;
      final equity = accountInfo?.equity ?? 0.0;
      final margin = accountInfo?.margin ?? 0.0;
      final freeMargin = accountInfo?.marginFree ?? 0.0;
      final marginLevel = accountInfo?.marginLevel ?? 0.0;

      children = [
        buildItem('trade_metric_balance', balance.toStringAsFixed(2)),
        buildItem('trade_metric_credit', credit.toStringAsFixed(2)),
        buildItem('trade_metric_equity', equity.toStringAsFixed(2)),
        buildItem('trade_metric_margin', margin.toStringAsFixed(2)),
        buildItem('trade_metric_free_margin', freeMargin.toStringAsFixed(2)),
        buildItem(
          'trade_metric_margin_level',
          marginLevel > 0 ? '${marginLevel.toStringAsFixed(2)}%' : '0.00%',
        ),
      ];
    }

    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Wrap(spacing: 12.w, runSpacing: 8.h, children: children),
    );
  }

  /// "From Real" ticker strip showing a sample trade / broadcast row.
  Widget _buildFromRealStrip() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        child: Row(
          children: [
            Text(
              'From Real',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp),
            ),
            SizedBox(width: 12.w),
            Text(
              'arie***',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            ),
            SizedBox(width: 8.w),
            Text(
              'EUR',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: _green, width: 1),
              ),
              child: Text(
                'Buy 1',
                style: TextStyle(
                  color: _green,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Profit \$ 0.04',
              style: TextStyle(color: _green, fontSize: 12.sp),
            ),
            SizedBox(width: 10.w),
            Text(
              _currentTimeHms(),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  String _currentTimeHms() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  Widget _buildPillTabs() {
    final tradingController = Get.find<TradingController>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Obx(() {
        final selected = tradingController.selectedTab;
        final positionCount = tradingController.marketPositions.length;
        final pendingCount = tradingController.pendingPositions.length;
        return Row(
          children: [
            _tabText(
              'Position',
              selected == 0,
              () => tradingController.setSelectedTab(0),
              count: positionCount,
            ),
            SizedBox(width: 28.w),
            _tabText(
              'Pending',
              selected == 1,
              () => tradingController.setSelectedTab(1),
              count: pendingCount,
            ),
            SizedBox(width: 28.w),
            _tabText(
              'History',
              selected == 2,
              () => tradingController.setSelectedTab(2),
            ),
            const Spacer(),

            if (selected == 0) ...[
              InkWell(
                borderRadius: BorderRadius.circular(20.r),
                onTap: () {
                  if (selected == 0 &&
                      tradingController.marketPositions.isNotEmpty) {
                    _showBulkOperationsSheet(tradingController);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(
                    Icons.more_horiz,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _tabText(
    String label,
    bool active,
    VoidCallback onTap, {
    int count = 0,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color:
                        active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                  ),
                ),
                if (count > 0)
                  TextSpan(
                    text: ' ($count)',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Container(
            height: 3.h,
            width: 22.w,
            decoration: BoxDecoration(
              color: active ? _accent : Colors.transparent,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    final tradingController = Get.find<TradingController>();
    return Obx(() {
      if (tradingController.selectedTab != 2) return const SizedBox.shrink();

      return GetBuilder<TradingController>(
        id: 'history_filter',
        builder: (controller) {
          if (!controller.historyFilterInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Get.find<TradingController>().historyFilterInitialized) {
                return;
              }
              Get.find<TradingController>().applyHistoryFilter();
            });
          }

          final start = controller.historyStartDate;
          final end = controller.historyEndDate;
          final period = controller.historyFilterPeriod;
          final direction = controller.closedDirection;
          final symbols = controller.historySelectedSymbols;
          final symbolCount = symbols.where((s) => s != 'all').length;
          final hasAllSymbols =
              symbols.contains('all') || symbols.isEmpty;

          var activeCount = 0;
          if (period != 'today') activeCount++;
          if (direction != 'All') activeCount++;
          if (!hasAllSymbols && symbolCount > 0) activeCount++;

          final periodLabel = _periodLabel(period, start, end);
          final summary = <String>[
            periodLabel,
            if (direction != 'All') direction,
            if (!hasAllSymbols && symbolCount > 0)
              '$symbolCount symbol${symbolCount == 1 ? '' : 's'}',
          ].join('  •  ');

          return Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
            child: InkWell(
              onTap: _openHistoryFilterSheet,
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: activeCount > 0
                        ? _accent.withValues(alpha: 0.6)
                        : AppColors.divider,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(7.w),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.filter_alt_outlined,
                        color: _accent,
                        size: 15.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'History filter',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (activeCount > 0) ...[
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 1.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    '$activeCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.tune_rounded,
                      color: AppColors.textSecondary,
                      size: 18.sp,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  String _periodLabel(String period, DateTime? start, DateTime? end) {
    switch (period) {
      case 'week':
        return 'Last 7 days';
      case 'month':
        return 'Last month';
      case 'threeMonth':
        return 'Last 3 months';
      case 'custom':
        if (start != null && end != null) {
          return '${_shortDate(start)} — ${_shortDate(end)}';
        }
        return 'Custom range';
      case 'today':
      default:
        return 'Today';
    }
  }

  String _shortDate(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[(d.month - 1).clamp(0, 11)]}';
  }

  void _openHistoryFilterSheet() {
    final controller = Get.find<TradingController>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return HistoryFilterScreen(
          initialPeriod: controller.historyFilterPeriod,
          initialDirection: controller.closedDirection,
          initialSymbols: controller.historySelectedSymbols,
          initialStart: controller.historyStartDate,
          initialEnd: controller.historyEndDate,
          onConfirm: (period, symbols, direction, customStart, customEnd) async {
            await controller.applyHistoryFilter(
              period: period,
              symbols: symbols,
              direction: direction,
              customStart: customStart,
              customEnd: customEnd,
            );
          },
          onReset: () async {
            await controller.resetHistoryFilter();
          },
        );
      },
    );
  }

  Widget _buildBody() {
    return GetBuilder<TradingController>(
      builder: (controller) {
        final positions = controller.getFilteredPositions();
        final isLoadingHistory = controller.isLoadingHistory;
        final selectedTab = controller.selectedTab;

        if (selectedTab != 2 && positions.isEmpty) return _buildEmptyState();
        if (selectedTab == 2 && positions.isEmpty && !isLoadingHistory) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (controller.selectedTab == 2) {
              await controller.refreshTradeHistory();
            }
          },
          child: ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 90.h),
            itemCount:
                positions.length +
                (controller.hasMoreHistoryPages && selectedTab == 2 ? 1 : 0),
            separatorBuilder: (_, __) => SizedBox(height: 4.h),
            itemBuilder: (context, index) {
              if (index >= positions.length) return _buildPaginationLoader();
              final position = positions[index];
              return RepaintBoundary(
                child: GetBuilder<TradingController>(
                  id: 'position_${position.orderId}',
                  builder: (innerController) {
                    final TradePosition? fresh =
                        innerController.selectedTab == 0
                            ? innerController.getMarketPositionById(
                              position.orderId,
                            )
                            : (innerController.selectedTab == 1
                                ? innerController.getPendingPositionById(
                                  position.orderId,
                                )
                                : innerController.getClosedPositionById(
                                  position.orderId,
                                ));
                    return _buildPositionCard(
                      innerController,
                      fresh ?? position,
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final tradingController = Get.find<TradingController>();
    final tab = tradingController.selectedTab;
    final message =
        tab == 1
            ? 'No Pending Orders'
            : tab == 2
            ? 'No Trade History'
            : 'No Open Positions';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 44.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationLoader() {
    if (!Get.find<TradingController>().isLoadingHistory) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      alignment: Alignment.center,
      child: SizedBox(
        height: 24.w,
        width: 24.w,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: _accent),
      ),
    );
  }

  Widget _buildPositionCard(
    TradingController tradingController,
    TradePosition position,
  ) {
    final isPositive = position.profitLoss >= 0;
    final isHistory = tradingController.selectedTab == 2;
    final isBuy = position.action.toLowerCase() == 'buy';
    final symbol = _formatSymbol(position.symbol);
    final leverage = _leverageLabel(position);

    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: () {
        if (isHistory) {
          Get.to(
            () => IQuoteOrderDetailsScreen(
              data: IQuoteOrderData(
                orderNo: position.orderId,
                symbol: symbol,
                buySell: position.action,
                lots: position.volume.toString(),
                contractSize: '—',
                leverage: leverage,
                profit: PrecisionHelper.formatPnL(position.profitLoss),
                openTime: position.openTime,
                openPrice: position.entryPrice,
                closeTime: position.closeTime,
                closePrice: position.currentPrice,
                closingMethod:
                    position.closeTime.isNotEmpty ? 'Closed by Trader' : '',
                swap: PrecisionHelper.formatPnL(position.swap),
                commission: position.commission.toString(),
                takeProfit: position.takeProfit,
                stopLoss: position.stopLoss,
              ),
            ),
          );
        } else {
          // Open the shared modify screens so the layout matches the rest of
          // the app: pending orders → Edit Order, open positions →
          // Close / Modify Position (with live P&L + chart).
          final isPending = tradingController.selectedTab == 1;
          if (isPending) {
            Get.to<void>(() => EditOrderScreen(position: position));
          } else {
            Get.to<void>(() => ClosePositionScreen(position: position));
          }
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(10.w, 5.h, 4.w, 5.h),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: side chip • symbol • volume ─── PnL • close
            Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: (isBuy ? _green : _red).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: Text(
                    isBuy ? 'Buy' : 'Sell',
                    style: TextStyle(
                      color: isBuy ? _green : _red,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                // Symbol gets its natural width so long names show fully;
                // if the row overflows, volume/PnL area is what shrinks.
                Text(
                  symbol,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  '${position.volume}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${isPositive ? '' : '-'}${position.profitLoss.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isPositive ? _green : _red,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isHistory)
                  InkWell(
                    borderRadius: BorderRadius.circular(20.r),
                    onTap: () {
                      if (tradingController.selectedTab == 1) {
                        _showCancelPendingDialog(tradingController, position);
                      } else {
                        _showCloseConfirmDialog(tradingController, position);
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.only(left: 4.w, right: 2.w),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                        size: 18.sp,
                      ),
                    ),
                  )
                else
                  SizedBox(width: 4.w),
              ],
            ),
            SizedBox(height: 2.h),
            // Row 2: entry→current (left) • TP/SL (center) • close time (right, history)
            Row(
              children: [
                Text(
                  position.entryPrice,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(width: 3.w),
                Icon(
                  Icons.arrow_forward,
                  color: AppColors.textSecondary,
                  size: 10.sp,
                ),
                SizedBox(width: 3.w),
                Text(
                  position.currentPrice,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (_hasMeaningfulPrice(position.takeProfit))
                        _tpSlChip('TP', position.takeProfit, _green),
                      if (_hasMeaningfulPrice(position.takeProfit) &&
                          _hasMeaningfulPrice(position.stopLoss))
                        SizedBox(width: 6.w),
                      if (_hasMeaningfulPrice(position.stopLoss))
                        _tpSlChip('SL', position.stopLoss, _red),
                    ],
                  ),
                ),
                if (isHistory && position.closeTime.isNotEmpty)
                  Text(
                    DateHelper.formatIsoStringToUtcHistory(position.closeTime),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact colored pill used inline in the position card to show TP/SL
  /// without eating a whole row. Kept tiny on purpose so the list stays dense.
  Widget _tpSlChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 3.w),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// True when the price string represents a real TP/SL value
  /// (non-empty and not 0 / 0.0 / 0.00000 / "-").
  bool _hasMeaningfulPrice(String v) {
    if (v.isEmpty) return false;
    final t = v.trim();
    if (t == '-' || t == '---') return false;
    final n = double.tryParse(t.replaceAll(',', ''));
    if (n == null) return true;
    return n != 0;
  }

  Widget _buildVipBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        gradient: LinearGradient(
          colors: [_accent.withOpacity(0.9), _accent.withOpacity(0.5)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'V',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(width: 3.w),
          Text(
            'VIP 0',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 9.sp,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSymbol(String raw) {
    final noSuffix =
        raw.contains('.') ? raw.substring(0, raw.indexOf('.')) : raw;
    if (noSuffix.length == 6) {
      return '${noSuffix.substring(0, 3)}/${noSuffix.substring(3)}';
    }
    return noSuffix;
  }

  String _leverageLabel(TradePosition position) {
    try {
      final acc = Get.find<AccountController>().activeMT5Account;
      final lev = acc?.leverageMax ?? 0;
      if (lev == 0) return '';
      return '${lev}X';
    } catch (_) {
      return '';
    }
  }

  String _formatSwap(double swap) {
    final abs = swap.abs().toStringAsFixed(2);
    return swap >= 0 ? abs : '-$abs';
  }

  String _activeAccountLabel() {
    try {
      final acc = Get.find<AccountController>().activeMT5Account;
      if (acc == null) return 'DEMO';
      return acc.isRealAccount ? 'REAL' : 'DEMO';
    } catch (_) {
      return 'DEMO';
    }
  }

  void _showActionSheet(
    TradingController tradingController,
    TradePosition position,
  ) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          color: AppColors.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Close Position'),
                onTap: () {
                  Get.back();
                  Get.to(() => ClosePositionScreen(position: position));
                },
              ),
              ListTile(
                title: const Text('Edit Order'),
                onTap: () {
                  Get.back();
                  Get.to(() => EditOrderScreen(position: position));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bulk Operations bottom sheet (Position tab)
  // ─────────────────────────────────────────────────────────────────────────
  void _showBulkOperationsSheet(TradingController tradingController) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        padding: EdgeInsets.fromLTRB(0, 12.h, 0, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Bulk Operations',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 24.h),
            _bulkTile(
              label: 'Close Losing Positions',
              chipLabel: 'Loss',
              chipColor: _red,
              onTap: () {
                Get.back();
                _confirmBulkClose(
                  tradingController,
                  title: 'Close all losing positions?',
                  filter: (p) => p.profitLoss < 0,
                );
              },
            ),
            _bulkTile(
              label: 'Close Profitable Positions',
              chipLabel: 'Profitable',
              chipColor: _green,
              onTap: () {
                Get.back();
                _confirmBulkClose(
                  tradingController,
                  title: 'Close all profitable positions?',
                  filter: (p) => p.profitLoss > 0,
                );
              },
            ),
            _bulkTile(
              label: 'Close All Positions',
              chipLabel: 'ALL',
              chipColor: _accent,
              onTap: () {
                Get.back();
                _confirmBulkClose(
                  tradingController,
                  title: 'Close all positions?',
                  filter: (_) => true,
                );
              },
            ),
          ],
        ),
      ),
      isScrollControlled: false,
    );
  }

  Widget _bulkTile({
    required String label,
    required String chipLabel,
    required Color chipColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 10.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                chipLabel,
                style: TextStyle(
                  color: chipColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBulkClose(
    TradingController tradingController, {
    required String title,
    required bool Function(TradePosition) filter,
  }) async {
    final targets = tradingController.marketPositions.where(filter).toList();
    if (targets.isEmpty) {
      CustomToastService.showInfo(
        title: 'No positions',
        message: 'No positions matched the selected filter',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _cardColor,
          insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${targets.length} position(s) will be closed at market price.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44.h,
                        child: OutlinedButton(
                          onPressed:
                              () => Navigator.of(dialogContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _accent, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: SizedBox(
                        height: 44.h,
                        child: ElevatedButton(
                          onPressed:
                              () => Navigator.of(dialogContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    await _executeBulkClose(tradingController, targets);
  }

  Future<void> _executeBulkClose(
    TradingController tradingController,
    List<TradePosition> targets,
  ) async {
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;
      if (activeAccount == null) {
        CustomToastService.showError(
          title: 'Error',
          message: 'No active account found',
        );
        return;
      }
      for (final p in targets) {
        final positionId = int.tryParse(p.orderId) ?? 0;
        if (positionId == 0) continue;
        await tradingController.closePositionById(
          mt5Account: activeAccount.metaAccountNumber,
          positionId: positionId,
        );
      }
    } catch (e) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to close positions: $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Close-position confirmation dialog (matches iQuote design)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _showCloseConfirmDialog(
    TradingController tradingController,
    TradePosition position,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return GetBuilder<TradingController>(
          id: 'position_${position.orderId}',
          builder: (controller) {
            final fresh = controller.getMarketPositionById(position.orderId) ?? position;
            final symbol = _formatSymbol(fresh.symbol);
            final leverage = _leverageLabel(fresh);
            final isBuy = fresh.action.toLowerCase() == 'buy';
            final isPositive = fresh.profitLoss >= 0;
            final closePrice = fresh.currentPrice;

            return Dialog(
              backgroundColor: _cardColor,
              insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Close $symbol positions at market price?',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // Side chip + symbol
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: (isBuy ? _green : _red).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            isBuy ? 'Buy' : 'Sell',
                            style: TextStyle(
                              color: isBuy ? _green : _red,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          symbol,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    // Lot + leverage • close price
                    Row(
                      children: [
                        Text(
                          '${fresh.volume}Lot',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (leverage.isNotEmpty) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.r),
                              border: Border.all(
                                color: AppColors.textSecondary,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              leverage,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          closePrice,
                          style: TextStyle(
                            color: isPositive ? _green : _red,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44.h,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _accent, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: SizedBox(
                            height: 44.h,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                _confirmClosePosition(tradingController, fresh);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _confirmClosePosition(
    TradingController tradingController,
    TradePosition position,
  ) async {
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;
      if (activeAccount == null) {
        CustomToastService.showError(
          title: 'Error',
          message: 'No active account found',
        );
        return;
      }
      final positionId = int.tryParse(position.orderId) ?? 0;
      await tradingController.closePositionById(
        mt5Account: activeAccount.metaAccountNumber,
        positionId: positionId,
      );
    } catch (e) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to close position: $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cancel-pending confirmation dialog (matches iQuote design)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _showCancelPendingDialog(
    TradingController tradingController,
    TradePosition position,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _cardColor,
          insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 14.h),
                child: Center(
                  child: Text(
                    'Cancel pending',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Divider(color: AppColors.divider, height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You will cancel Pending Order',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44.h,
                            child: OutlinedButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _accent, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: SizedBox(
                            height: 44.h,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                _confirmCancelPending(
                                  tradingController,
                                  position,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: AppColors.onPrimary,
                                padding: EdgeInsets.symmetric(horizontal: 8.w),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                elevation: 0,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Cancel pending',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelPending(
    TradingController tradingController,
    TradePosition position,
  ) async {
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;
      if (activeAccount == null) {
        CustomToastService.showError(
          title: 'Error',
          message: 'No active account found',
        );
        return;
      }
      final orderId = int.tryParse(position.orderId) ?? 0;
      await tradingController.cancelOrderWithImmediateUpdate(
        mt5Account: activeAccount.metaAccountNumber,
        orderId: orderId,
      );
    } catch (e) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to cancel order: $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Switch-account bottom sheet (REAL / DEMO)
  // ─────────────────────────────────────────────────────────────────────────
  void _openSwitchAccountSheet() {
    Get.bottomSheet(
      _SwitchAccountSheet(onCancel: () => Get.back()),
      backgroundColor: _bgColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
    );
  }
}

/// Bottom sheet body shown when the DEMO/LIVE chip is tapped.
/// Lists REAL and DEMO account rows with a Switch action.
class _SwitchAccountSheet extends StatefulWidget {
  final VoidCallback onCancel;
  const _SwitchAccountSheet({required this.onCancel});

  @override
  State<_SwitchAccountSheet> createState() => _SwitchAccountSheetState();
}

class _SwitchAccountSheetState extends State<_SwitchAccountSheet> {
  String? _selectedAccountNumber;

  @override
  void initState() {
    super.initState();
    try {
      _selectedAccountNumber =
          Get.find<AccountController>().activeMT5Account?.metaAccountNumber;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 14.h),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            GetBuilder<DashboardController>(
              builder: (dashboard) {
                final accounts = <MT5Account>[
                  ...dashboard.realMT5Accounts,
                  ...dashboard.demoMT5Accounts,
                ];
                if (accounts.isEmpty) {
                  return Text(
                    'No accounts linked',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final acc in accounts)
                      _AccountRow(
                        account: acc,
                        isActive:
                            acc.metaAccountNumber == _selectedAccountNumber,
                        onTap: () {
                          if (acc.metaAccountNumber == _selectedAccountNumber)
                            return;
                          setState(
                            () =>
                                _selectedAccountNumber = acc.metaAccountNumber,
                          );
                        },
                        onDeposit: () {
                          Get.back();
                          Get.to(
                            () => PaymentMethodsScreen(
                              accountNumber: acc.metaAccountNumber,
                            ),
                          );
                        },
                        onWithdraw: () {
                          Get.back();
                          Get.to(
                            () => WithdrawalScreen(
                              accountNumber: acc.metaAccountNumber,
                            ),
                          );
                        },
                        onSwitch: () async {
                          Get.back();
                          try {
                            await Get.find<AccountController>()
                                .setActiveMT5Account(acc.metaAccountNumber);
                          } catch (e) {
                            if (kDebugMode) {
                              print('Switch account error: $e');
                            }
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One account card inside the switch-account bottom sheet.
/// Layout mirrors the iQuote dashboard account card.
class _AccountRow extends StatelessWidget {
  final MT5Account account;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onSwitch;

  const _AccountRow({
    required this.account,
    required this.isActive,
    required this.onTap,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final profit = double.tryParse(account.profit) ?? 0.0;
    final balance = double.tryParse(account.balance) ?? 0.0;
    final equity = double.tryParse(account.equity) ?? balance;
    final isDemo = account.accountType.toLowerCase() == 'demo';
    final leverage =
        account.leverageMax > 0 ? '1:${account.leverageMax}' : '1:500';
    final accountNumber = account.metaAccountNumber;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
        decoration: BoxDecoration(
          color:
              isActive ? AppColors.primary.withOpacity(0.10) : AppColors.card,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color:
                isActive
                    ? AppColors.primary
                    : AppColors.divider.withOpacity(0.45),
            width: isActive ? 1.3 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: #account · LIVE/DEMO chip · ACTIVE chip · balance · 3-dot
            Row(
              children: [
                Text(
                  '#$accountNumber',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color:
                        isDemo
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    isDemo ? 'DEMO' : 'LIVE',
                    style: TextStyle(
                      color: isDemo ? Colors.orange : Colors.green,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isActive) ...[
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Equity
                Text(
                  '\$${equity.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // P&L + leverage
            Row(
              children: [
                Text(
                  'Eq: \$${equity.toStringAsFixed(2)} • P&L: ${profit >= 0 ? '+' : '-'}\$${profit.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (leverage.isNotEmpty) ...[
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                        color: AppColors.textSecondary,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      leverage,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 12.h),
            // Actions
            if (isActive) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36.h,
                      child: ElevatedButton(
                        onPressed: onDeposit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Deposit',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: SizedBox(
                      height: 36.h,
                      child: ElevatedButton(
                        onPressed: onWithdraw,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusRed.withOpacity(
                            0.12,
                          ),
                          foregroundColor: AppColors.statusRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Withdraw',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 36.h,
                child: ElevatedButton(
                  onPressed: onSwitch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Switch',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
