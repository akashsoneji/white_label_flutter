import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_copier_subscriptions_controller.dart'
    show
        CopierSubscriptionItem,
        CopyTradingCopierSubscriptionsController,
        TradeItem;
import 'package:crm_app/screens/home/more/copytrading/explore_masters_screen.dart';
import 'package:crm_app/screens/home/more/copytrading/master_details_screen.dart';
import 'package:crm_app/screens/home/more/copytrading/subscribe_to_plan_screen.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_details_controller.dart'
    show CopyTradingPlan;
import 'package:crm_app/controllers/copy_trading/copy_trading_hub_controller.dart';
import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class MyInvestmentsScreen extends StatefulWidget {
  const MyInvestmentsScreen({super.key});

  @override
  State<MyInvestmentsScreen> createState() => _MyInvestmentsScreenState();
}

class _MyInvestmentsScreenState extends State<MyInvestmentsScreen>
    with SingleTickerProviderStateMixin {
  late final CopyTradingCopierSubscriptionsController controller;
  late final TabController tabController;
  bool _tradesLoaded = false;

  void _toastError(String message) {
    final msg = message.trim();
    if (msg.isEmpty || msg == 'null') return;
    CustomToastService.showError(
      title: 'Error',
      message: msg,
      duration: const Duration(milliseconds: 2500),
      position: SnackPosition.TOP,
    );
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    controller = Get.put(
      CopyTradingCopierSubscriptionsController(),
      tag: 'copytrading:my_investments',
    );
    tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!tabController.indexIsChanging &&
        tabController.index == 1 &&
        !_tradesLoaded) {
      _tradesLoaded = true;
      print('>>> _onTabChanged firing loadTrades');
      controller.loadTrades();
    }
  }

  @override
  void dispose() {
    tabController.removeListener(_onTabChanged);
    Get.delete<CopyTradingCopierSubscriptionsController>(
      tag: 'copytrading:my_investments',
      force: true,
    );
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAllNamed(AppPages.TRADING),
        ),
        centerTitle: true,
        title: Text('My Investments', style: AppTextStyles.screenTitle),
        automaticallyImplyLeading: false,
        actions: [
          // Padding(
          //   padding: EdgeInsets.only(right: 12.w),
          //   child: TextButton.icon(
          //     onPressed: () {
          //       if (Get.isRegistered<CopyTradingHubController>()) {
          //         final hub = Get.find<CopyTradingHubController>();
          //         final isApprovedMaster =
          //             hub.masterStatus.value ==
          //             CopyTradingMasterApplicationStatus.approved;
          //         hub.currentTabIndex.value = isApprovedMaster ? 3 : 1;
          //       } else {
          //         Get.back();
          //       }
          //     },
          //     icon: Icon(
          //       Icons.explore_outlined,
          //       size: 16.r,
          //       color: AppColors.primary,
          //     ),
          //     label: Text(
          //       'Explore Masters',
          //       style: AppTextStyles.bodyText.copyWith(
          //         fontSize: 12.sp,
          //         fontWeight: FontWeight.w600,
          //         color: AppColors.primary,
          //       ),
          //     ),
          //     style: TextButton.styleFrom(
          //       backgroundColor: AppColors.primary.withOpacity(0.1),
          //       padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(20.r),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
      body: Obx(() {
        final loading = controller.isLoading.value;
        final err = controller.errorMessage.value;
        final list = controller.subscriptions.toList();

        if (loading && list.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              controller.load(showLoading: false),
              controller.loadTrades(),
            ]);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final metrics = notification.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 200 &&
                    controller.hasMore &&
                    !controller.isLoadingMore.value &&
                    !controller.isLoading.value) {
                  controller.loadMore();
                }
              }
              return false;
            },
            child: Column(
              children: [
                if (err.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                    child: _InlineError(
                      message: err,
                      onRetry: () => controller.load(showLoading: true),
                    ),
                  ),

                // ── Summary Cards ───────────────────────────────────────────────
                _SummarySection(controller: controller),

                // ── Tabs ──────────────────────────────────────────────────────
                Container(
                  margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  height: 38,
                  child: TabBar(
                    controller: tabController,
                    indicator: BoxDecoration(
                      color:
                          AppColors.isDarkMode
                              ? AppColors.textPrimaryDark.withValues(alpha: 0.1)
                              : AppColors.primary,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor:
                        AppColors.isDarkMode
                            ? AppColors.textPrimaryDark
                            : AppColors.onColoredBackground,
                    unselectedLabelColor: AppColors.textGrey,
                    labelStyle: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.r,
                      vertical: 4.r,
                    ),
                    tabs: [
                      Tab(text: 'My Subscriptions (${list.length})'),
                      const Tab(text: 'Trade History'),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // ── Tab Content ─────────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      // My Subscriptions Tab
                      _SubscriptionsTab(
                        items: list,
                        controller: controller,
                        onAddCapital: (id) => _showAddCapitalDialog(id),
                        onPause: (id) => _pause(id),
                        onResume: (id) => _resume(id),
                        onStop: (id) => _stop(id),
                        onEdit: (id) => _edit(id),
                        onView: (id) => _view(id),
                      ),
                      // Trade History Tab
                      _TradeHistoryTab(controller: controller),
                    ],
                  ),
                ),

                // Load more indicator
                Obx(() {
                  if (!controller.isLoadingMore.value)
                    return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24.r,
                          height: 24.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text('Loading more...', style: AppTextStyles.caption),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showAddCapitalDialog(int subscriptionId) async {
    final amountCtrl = TextEditingController();
    final amount = await showDialog<num?>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Add capital'),
            content: TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'Amount (USD)'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final v = num.tryParse(amountCtrl.text.trim());
                  // Don't close dialog for invalid amount.
                  if (v == null || v <= 0) return;
                  Navigator.of(ctx).pop(v);
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
    // Cancel pressed -> amount is null. Don't show any error.
    if (amount == null) return;
    final res = await controller.addCapital(
      subscriptionId: subscriptionId,
      amount: amount,
    );
    if (!res.success) {
      _toastError(res.message ?? 'Failed to add capital');
    }
  }

  void _pause(int id) async {
    final res = await controller.pause(id);
    if (!res.success) _toastError(res.message ?? 'Failed to pause');
  }

  void _resume(int id) async {
    final res = await controller.resume(id);
    if (!res.success) _toastError(res.message ?? 'Failed to resume');
  }

  void _stop(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Stop investment?'),
            content: Text('This is permanent. You\'ll need to re-subscribe.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Stop'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final res = await controller.stop(id);
    if (!res.success) _toastError(res.message ?? 'Failed to stop');
  }

  void _view(int id) {
    final sub = controller.subscriptions.firstWhereOrNull((e) => e.id == id);
    if (sub == null) return;

    Get.to(
      () => MasterDetailsScreen(
        masterCode: sub.masterCode,
        masterNickname:
            sub.masterName.isNotEmpty ? sub.masterName : sub.masterCode,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _edit(int id) async {
    final sub = controller.subscriptions.firstWhereOrNull((e) => e.id == id);
    if (sub == null) return;

    if (!Get.isRegistered<CopyTradingHubController>()) {
      Get.put(CopyTradingHubController());
    }

    final dummyPlan = CopyTradingPlan(
      id: 0,
      planId: sub.planId,
      planName: sub.planName,
      commissionType: sub.commissionType,
      commissionLabel: '',
      commissionPercentage: sub.commissionPercentage,
      subscriptionFee: sub.subscriptionFee,
      minimumCapital: 0,
      copyRatio: sub.copyRatio,
      isFull: false,
      noFeeDays: 0,
      subscriptionPeriodDays: 0,
      activeCopiersCount: 0,
      totalAum: 0,
      isEnrolled: false,
    );

    await Get.to(
      () => SubscribeToPlanScreen(
        masterCode: sub.masterCode,
        plan: dummyPlan,
        editSubscription: sub,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 250),
    );

    controller.load(showLoading: false);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _SummarySection extends StatelessWidget {
  final CopyTradingCopierSubscriptionsController controller;
  const _SummarySection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.summaryActive.value;
      final totalCapital = controller.summaryTotalCapital.value;
      final totalPnl = controller.summaryTotalPnl.value;
      final totalCommission = controller.summaryTotalCommissionPaid.value;

      return Container(
        margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
        child: Column(
          children: [
            // Status chips
            Container(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.10),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 15.r,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'My Investments',
                        style: AppTextStyles.labelOnChartPendingOrderBold,
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          '$active active',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // 2x2 metrics grid
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryMetricTile(
                          label: 'Total Invested',
                          value: '\$${totalCapital.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _SummaryMetricTile(
                          label: 'Total P&L',
                          value: '\$${totalPnl.toStringAsFixed(2)}',
                          icon: Icons.trending_up,
                          iconColor:
                              totalPnl >= 0 ? AppColors.green : AppColors.error,
                          valueColor:
                              totalPnl >= 0 ? AppColors.green : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryMetricTile(
                          label: 'Active Investments',
                          value: '$active',
                          icon: Icons.check_circle_outline,
                          iconColor: AppColors.green,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _SummaryMetricTile(
                          label: 'Commissions Paid',
                          value:
                              '-\$${totalCommission.abs().toStringAsFixed(2)}',
                          icon: Icons.payments_outlined,
                          iconColor: AppColors.error,
                          valueColor: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      );
    });
  }
}

class _SummaryMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;
  const _SummaryMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 14.r, color: iconColor),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 9.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppColors.textPrimary,
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

// ─────────────────────────────────────────────────────────────────────────────
// SUBSCRIPTIONS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _SubscriptionsTab extends StatelessWidget {
  final List<CopierSubscriptionItem> items;
  final CopyTradingCopierSubscriptionsController controller;
  final void Function(int id) onAddCapital;
  final void Function(int id) onPause;
  final void Function(int id) onResume;
  final void Function(int id) onStop;
  final void Function(int id) onEdit;
  final void Function(int id) onView;

  const _SubscriptionsTab({
    required this.items,
    required this.controller,
    required this.onAddCapital,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onEdit,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyInvestmentsState();
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 90.h),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return _InvestmentRow(
          item: item,
          onAddCapital: () => onAddCapital(item.id),
          onPause: () => onPause(item.id),
          onResume: () => onResume(item.id),
          onStop: () => onStop(item.id),
          onEdit: () => onEdit(item.id),
          onView: () => onView(item.id),
        );
      },
    );
  }
}

class _InvestmentRow extends StatelessWidget {
  final CopierSubscriptionItem item;
  final VoidCallback onAddCapital;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onEdit;
  final VoidCallback onView;

  const _InvestmentRow({
    required this.item,
    required this.onAddCapital,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onEdit,
    required this.onView,
  });

  static String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty)
      return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    return '?';
  }

  static String _formatStatus(String s) {
    if (s.isEmpty) return 'Unknown';
    return '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
  }

  Color get _statusColor {
    switch (item.status.toLowerCase()) {
      case 'active':
        return AppColors.green;
      case 'paused':
        return AppColors.warning;
      case 'stopped':
        return AppColors.error;
      default:
        return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = item.status.toLowerCase();
    final canPause = status == 'active';
    final canResume = status == 'paused';
    final canStop = status == 'active' || status == 'paused';
    final canEdit = canPause || canResume;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.textGrey.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              children: [
                // Master + Status row (tappable to view details)
                InkWell(
                  onTap: onView,
                  borderRadius: BorderRadius.circular(10.r),
                  child: Row(
                    children: [
                      Container(
                        width: 40.r,
                        height: 40.r,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.brandPrimary,
                              AppColors.brandPrimary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(
                              item.masterName.isNotEmpty
                                  ? item.masterName
                                  : item.masterCode,
                            ),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.onColoredBackground,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                                  item.masterName.isNotEmpty
                                      ? item.masterName
                                      : item.masterCode,
                                  style: AppTextStyles.black16600.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _formatStatus(status),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor,
                                    ),
                                  ),
                                ),
                                Spacer(), // Expanded(child: _FieldChip(label: 'P&L', value: '\$${item.totalPnl.toStringAsFixed(2)}', valueColor: item.totalPnl >= 0 ? AppColors.green : AppColors.error)),
                                Text(
                                  '\$${item.totalPnl.toStringAsFixed(2)}',
                                  style: AppTextStyles.black16600.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        item.totalPnl >= 0
                                            ? AppColors.green
                                            : AppColors.error,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                //  style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, fontWeight: FontWeight.w600, color: item.totalPnl >= 0 ? AppColors.green : AppColors.error), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                if (item.serverType.isNotEmpty)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 1.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      item.serverType.toUpperCase(),
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.blue,
                                      ),
                                    ),
                                  ),
                                if (item.planName.isNotEmpty) ...[
                                  SizedBox(width: 5.w),
                                  Flexible(
                                    child: Text(
                                      item.planName,
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 10.sp,
                                        color: AppColors.textGrey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // Account + Capital
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _FieldChip(
                        label: 'Account',
                        value: item.accountNumber,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _FieldChip(
                        label: 'Capital',
                        value: '\$${item.capitalAmount.toStringAsFixed(2)}',
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _FieldChip(
                        label: 'Comm.',
                        value:
                            '\$${item.totalCommissionPaid.toStringAsFixed(2)}',
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _FieldChip(
                        label: 'Trades',
                        value: '${item.openTrades}',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _SmallActionBtn(
                        label: 'View',
                        icon: Icons.visibility_outlined,
                        color: AppColors.primary,
                        enabled: true,
                        onTap: onView,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: _SmallActionBtn(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        color: AppColors.textGrey,
                        enabled: canEdit,
                        onTap: onEdit,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    if (canPause)
                      Expanded(
                        child: _SmallActionBtn(
                          label: 'Pause',
                          icon: Icons.pause,
                          color: AppColors.warning,
                          enabled: true,
                          onTap: onPause,
                        ),
                      )
                    else if (canResume)
                      Expanded(
                        child: _SmallActionBtn(
                          label: 'Resume',
                          icon: Icons.play_arrow,
                          color: AppColors.green,
                          enabled: true,
                          onTap: onResume,
                        ),
                      )
                    else
                      const Expanded(child: SizedBox.shrink()),
                    SizedBox(width: 4.w),
                    if (canStop)
                      Expanded(
                        child: _SmallActionBtn(
                          label: 'Stop',
                          icon: Icons.stop,
                          color: AppColors.error,
                          enabled: true,
                          onTap: onStop,
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
  }
}

class _FieldChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _FieldChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 10.sp,
            color: AppColors.textGrey,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _SmallActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : AppColors.textGrey.withOpacity(0.4);
    return Material(
      color: c.withOpacity(enabled ? 0.1 : 0.05),
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 7.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14.r, color: c),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRADE HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────
class _TradeHistoryTab extends StatelessWidget {
  final CopyTradingCopierSubscriptionsController controller;
  const _TradeHistoryTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isLoadingTrades.value;
      final err = controller.tradeError.value;
      final trades = controller.trades.toList();

      if (loading && trades.isEmpty) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      if (err.isNotEmpty && trades.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40.r, color: AppColors.error),
                SizedBox(height: 12.h),
                Text('Failed to load trades', style: AppTextStyles.black16600),
                SizedBox(height: 4.h),
                Text(
                  err,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16.h),
                TextButton.icon(
                  onPressed: controller.loadTrades,
                  icon: Icon(Icons.refresh, size: 16),
                  label: Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (trades.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48.r,
                color: AppColors.textGrey.withOpacity(0.5),
              ),
              SizedBox(height: 12.h),
              Text('No trades yet', style: AppTextStyles.black16600),
              SizedBox(height: 4.h),
              Text(
                'Your trade history will appear here',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 200 &&
                controller.hasMoreTrades &&
                !controller.isLoadingMoreTrades.value &&
                !controller.isLoadingTrades.value) {
              controller.loadMoreTrades();
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 90.h),
          itemCount:
              trades.length + (controller.isLoadingMoreTrades.value ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == trades.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Center(
                  child: SizedBox(
                    width: 24.r,
                    height: 24.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }
            return _TradeRow(item: trades[i]);
          },
        ),
      );
    });
  }
}

class _TradeRow extends StatefulWidget {
  final TradeItem item;
  const _TradeRow({required this.item});

  @override
  State<_TradeRow> createState() => _TradeRowState();
}

class _TradeRowState extends State<_TradeRow>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  static String _fmtDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  bool isXAU(String symbol) =>
      symbol.toUpperCase().contains('XAU') ||
      symbol.toUpperCase().contains('GOLD');

  @override
  Widget build(BuildContext context) {
    final isBuy = widget.item.tradeType.toLowerCase() == 'buy';
    final isProfit = widget.item.netCredited.toDouble() >= 0;
    final badgeColor = isBuy ? AppColors.green : AppColors.error;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.textGrey.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            // ── Always-visible header row ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.item.symbol,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            '\u2013',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textGrey,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            widget.item.copierVolume.toDouble().toStringAsFixed(
                              2,
                            ),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              widget.item.tradeType.toUpperCase(),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // SizedBox(height: 2.h),
                      // Text(widget.item.status.toUpperCase(), style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isProfit ? '+' : ''}\$${widget.item.copierProfit.toDouble().toStringAsFixed(2)}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isProfit ? AppColors.green : AppColors.error,
                      ),
                    ),
                    // Text('P&L', style: AppTextStyles.bodyText.copyWith(fontSize: 9.sp, color: AppColors.textGrey)),
                  ],
                ),
                SizedBox(width: 8.w),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: _expanded ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textGrey,
                    size: 20.r,
                  ),
                ),
              ],
            ),

            // ── Expanded details ──────────────────────────────────────
            if (_expanded) ...[
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _TField(
                      label: 'Commission',
                      value:
                          '\$${widget.item.commissionCharged.toDouble().toStringAsFixed(2)}',
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    child: _TField(
                      label: 'Net Credited',
                      value:
                          '\$${widget.item.netCredited.toDouble().toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _TField(
                      label: 'Open Price',
                      value: widget.item.openPrice.toDouble().toStringAsFixed(
                        isXAU(widget.item.symbol) ? 2 : 5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    child: _TField(
                      label: 'Opened',
                      value: _fmtDateTime(widget.item.openTime),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _TField(
                      label: 'Close Price',
                      value: widget.item.closePrice.toDouble().toStringAsFixed(
                        isXAU(widget.item.symbol) ? 2 : 5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    child: _TField(
                      label: 'Closed',
                      value: _fmtDateTime(widget.item.closeTime),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _TField({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 10.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyInvestmentsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.show_chart,
                size: 40.r,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 16.h),
            Text('No investments yet', style: AppTextStyles.headingblack),
            SizedBox(height: 8.h),
            Text(
              'Start copying successful traders to grow your portfolio.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () {
                if (Get.isRegistered<CopyTradingHubController>()) {
                  final hub = Get.find<CopyTradingHubController>();
                  final isApprovedMaster =
                      hub.masterStatus.value ==
                      CopyTradingMasterApplicationStatus.approved;
                  hub.currentTabIndex.value = isApprovedMaster ? 3 : 1;
                } else {
                  Get.to(() => const ExploreMastersScreen());
                }
              },
              icon: Icon(Icons.explore_outlined, size: 16.r),
              label: Text(
                'Explore Masters',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.whiteColor,
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                    AppColors.isDarkMode
                        ? AppColors.textPrimaryDark.withValues(alpha: 0.1)
                        : AppColors.primary,
                foregroundColor:
                    AppColors.isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.onColoredBackground,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE ERROR
// ─────────────────────────────────────────────────────────────────────────────
class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.error.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 18.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text('Retry', style: AppTextStyles.textButton),
          ),
        ],
      ),
    );
  }
}
