import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/subscription_detail_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class SubscriptionDetailScreen extends StatefulWidget {
  final int subscriptionId;

  const SubscriptionDetailScreen({
    super.key,
    required this.subscriptionId,
  });

  @override
  State<SubscriptionDetailScreen> createState() => _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final SubscriptionDetailController controller;
  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      SubscriptionDetailController(subscriptionId: widget.subscriptionId),
      tag: 'subscription_detail:${widget.subscriptionId}',
    );
    tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    Get.delete<SubscriptionDetailController>(
      tag: 'subscription_detail:${widget.subscriptionId}',
      force: true,
    );
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
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text(
          'Subscription Details',
          style: AppTextStyles.screenTitle,
        ),
      ),
      body: Obx(() {
        final loading = controller.isLoading.value;
        final error = controller.errorMessage.value;
        final detail = controller.subscriptionDetail.value;

        if (loading) {
          return Center(child: CircularProgressIndicator());
        }

        if (error.isNotEmpty && detail == null) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 40.r, color: AppColors.error),
                  SizedBox(height: 12.h),
                  Text(
                    'Failed to Load',
                    style: AppTextStyles.black16600,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    error,
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  TextButton.icon(
                    onPressed: controller.refresh,
                    icon: Icon(Icons.refresh),
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

        if (detail == null) return SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: Column(
            children: [
              // ── Header Card ──────────────────────────────────────────
              _SubscriptionHeaderCard(detail: detail),

              // ── Action Buttons ────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                child: _SubscriptionActionButtons(
                  detail: detail,
                  controller: controller,
                  onStatusChanged: () => controller.refresh(),
                ),
              ),

              // ── Tabs ──────────────────────────────────────────────────
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TabBar(
                  controller: tabController,
                  indicator: BoxDecoration(
                    color: AppColors.isDarkMode
                        ? AppColors.textPrimaryDark.withValues(alpha: 0.1)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.onColoredBackground,
                  unselectedLabelColor: AppColors.textGrey,
                  labelStyle: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 4.r, vertical: 4.r),
                  tabs: [
                    Tab(text: 'P&L History'),
                    Tab(text: 'Trades'),
                    Tab(text: 'Commission'),
                  ],
                ),
              ),
              SizedBox(height: 10.h),

              // ── Tab Content ──────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [
                    _PnlHistoryTab(controller: controller),
                    _TradesTab(controller: controller),
                    _CommissionTab(controller: controller),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SubscriptionHeaderCard extends StatelessWidget {
  final SubscriptionDetail detail;

  const _SubscriptionHeaderCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.textGrey.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master name + Plan + Status
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.masterName.isNotEmpty ? detail.masterName : 'Master',
                      style: AppTextStyles.black16600.copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${detail.planName}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _statusColor(detail.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  detail.status.toUpperCase(),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(detail.status),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Row 1: Capital, P&L, Commission
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Capital',
                  value: '\$${detail.capitalAmount.toStringAsFixed(2)}',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricTile(
                  label: 'Total P&L',
                  value: '\$${detail.totalPnl.toStringAsFixed(2)}',
                  valueColor: detail.totalPnl >= 0 ? AppColors.green : AppColors.error,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricTile(
                  label: 'Commission',
                  value: '\$${detail.totalCommissionPaid.toStringAsFixed(2)}',
                  valueColor: AppColors.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Row 2: Account, Closed Trades, Copy Ratio
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Account',
                  value: detail.accountNumber,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricTile(
                  label: 'Closed Trades',
                  value: '${detail.closedTradesCount}',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricTile(
                  label: 'Copy Ratio',
                  value: '${detail.copyRatio}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
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
}

class _SubscriptionActionButtons extends StatefulWidget {
  final SubscriptionDetail detail;
  final SubscriptionDetailController controller;
  final VoidCallback onStatusChanged;

  const _SubscriptionActionButtons({
    required this.detail,
    required this.controller,
    required this.onStatusChanged,
  });

  @override
  State<_SubscriptionActionButtons> createState() =>
      _SubscriptionActionButtonsState();
}

class _SubscriptionActionButtonsState
    extends State<_SubscriptionActionButtons> {
  bool _busy = false;

  Future<void> _run(
    Future<bool> Function() action,
    String fallbackError,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onStatusChanged();
      return;
    }
    final message = widget.controller.errorMessage.value.trim();
    CustomToastService.showError(
      title: TranslationUtils.tr('general_error'),
      message: message.isNotEmpty ? message : fallbackError,
      position: SnackPosition.TOP,
    );
  }

  Future<void> _confirmStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              TranslationUtils.tr('investment_detail_stop_investment'),
            ),
            content: Text(
              TranslationUtils.tr('investment_detail_this_is_permanent'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(TranslationUtils.tr('general_cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(TranslationUtils.tr('investment_detail_stop')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await _run(
      widget.controller.stopSubscription,
      TranslationUtils.tr('investment_detail_failed_to_stop'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.detail.status.toLowerCase();
    final canPause = status == 'active';
    final canResume = status == 'paused';
    final canStop = canPause || canResume;

    if (!canStop) return const SizedBox.shrink();

    return Row(
      children: [
        if (canPause)
          Expanded(
            child: _CompactActionButton(
              label: TranslationUtils.tr('my_plans_tab_pause'),
              icon: Icons.pause,
              color: AppColors.warning,
              enabled: !_busy,
              onTap:
                  () => _run(
                    widget.controller.pauseSubscription,
                    TranslationUtils.tr('investment_detail_failed_to_pause'),
                  ),
            ),
          ),
        if (canResume)
          Expanded(
            child: _CompactActionButton(
              label: TranslationUtils.tr('my_plans_tab_resume'),
              icon: Icons.play_arrow,
              color: AppColors.green,
              enabled: !_busy,
              onTap:
                  () => _run(
                    widget.controller.resumeSubscription,
                    TranslationUtils.tr('investment_detail_failed_to_resume'),
                  ),
            ),
          ),
        SizedBox(width: 8.w),
        Expanded(
          child: _CompactActionButton(
            label: TranslationUtils.tr('investment_detail_stop'),
            icon: Icons.stop,
            color: AppColors.error,
            enabled: !_busy,
            onTap: _confirmStop,
          ),
        ),
      ],
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _CompactActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? color : AppColors.textGrey.withValues(alpha: 0.4);
    return Material(
      color: tint.withValues(alpha: enabled ? 0.1 : 0.05),
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 7.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14.r, color: tint),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: tint,
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// P&L HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _PnlHistoryTab extends StatelessWidget {
  final SubscriptionDetailController controller;

  const _PnlHistoryTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.pnlHistory.toList();

      if (items.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up_outlined, size: 40.r, color: AppColors.textGrey),
                SizedBox(height: 12.h),
                Text(
                  'No P&L History',
                  style: AppTextStyles.black16600,
                ),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _PnlHistoryRow(item: items[index]);
        },
      );
    });
  }
}

class _PnlHistoryRow extends StatelessWidget {
  final PnlHistoryItem item;

  const _PnlHistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isProfit = item.grossProfitShare >= 0;
    final statusColor = isProfit ? AppColors.green : AppColors.error;

    return _HistoryCard(
      symbol: item.symbol,
      badgeLabel: item.status.toUpperCase(),
      badgeColor: statusColor,
      amount: _signedUsd(item.grossProfitShare),
      amountColor: statusColor,
      details: [
        _TradeFieldRow(
          left: _TradeField(
            label: TranslationUtils.tr('general_commission'),
            value:
                '\$${item.commissionAccruedDisplay.toDouble().toStringAsFixed(2)}',
          ),
          right: _TradeField(
            label: TranslationUtils.tr('copy_trading_net_credited'),
            value: '\$${item.netCredited.toDouble().toStringAsFixed(2)}',
          ),
        ),
        _TradeFieldRow(
          left: _TradeField(
            label: 'Settled',
            value: _formatDateString(item.settledAt),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRADES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _TradesTab extends StatelessWidget {
  final SubscriptionDetailController controller;

  const _TradesTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.trades.toList();

      if (items.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horiz_outlined, size: 40.r, color: AppColors.textGrey),
                SizedBox(height: 12.h),
                Text(
                  'No Trades',
                  style: AppTextStyles.black16600,
                ),
              ],
            ),
          ),
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 200 &&
                controller.hasMoreTrades &&
                !controller.isLoadingMoreTrades.value) {
              controller.loadMoreTrades();
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
          itemCount: items.length + (controller.isLoadingMoreTrades.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return _SubscriptionTradeRow(item: items[index]);
          },
        ),
      );
    });
  }
}

String _signedUsd(num value) {
  final sign = value >= 0 ? '+' : '-';
  return '$sign\$${value.abs().toDouble().toStringAsFixed(2)}';
}

String _formatDateTime(DateTime dt) => DateFormat('dd/MM/yyyy HH:mm').format(dt);

String _formatDateString(String raw) {
  if (raw.isEmpty) return '-';
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : _formatDateTime(parsed.toLocal());
}

class _SubscriptionTradeRow extends StatelessWidget {
  final TradeDetail item;

  const _SubscriptionTradeRow({required this.item});

  static bool _isXau(String symbol) {
    final upper = symbol.toUpperCase();
    return upper.contains('XAU') || upper.contains('GOLD');
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = item.tradeType.toLowerCase() == 'buy';
    final priceDecimals = _isXau(item.symbol) ? 2 : 5;

    return _HistoryCard(
      symbol: item.symbol,
      volume: item.copierVolume,
      badgeLabel: item.tradeType.toUpperCase(),
      badgeColor: isBuy ? AppColors.green : AppColors.error,
      amount: _signedUsd(item.copierProfit),
      amountColor: item.copierProfit >= 0 ? AppColors.green : AppColors.error,
      details: [
        _TradeFieldRow(
          left: _TradeField(
            label: TranslationUtils.tr('general_commission'),
            value: '\$${item.commissionCharged.toDouble().toStringAsFixed(2)}',
          ),
          right: _TradeField(
            label: TranslationUtils.tr('copy_trading_net_credited'),
            value: '\$${item.netCredited.toDouble().toStringAsFixed(2)}',
          ),
        ),
        _TradeFieldRow(
          left: _TradeField(
            label: TranslationUtils.tr('open_price'),
            value: item.openPrice.toDouble().toStringAsFixed(priceDecimals),
          ),
          right: _TradeField(
            label: TranslationUtils.tr('copy_trading_opened'),
            value: _formatDateTime(item.openTime),
          ),
        ),
        _TradeFieldRow(
          left: _TradeField(
            label: TranslationUtils.tr('close_price'),
            value: item.closePrice.toDouble().toStringAsFixed(priceDecimals),
          ),
          right: _TradeField(
            label: TranslationUtils.tr('ticket_status_closed'),
            value: _formatDateTime(item.closeTime),
          ),
        ),
      ],
    );
  }
}

/// Collapsed: symbol – volume, badge, amount. Tap to reveal [details].
class _HistoryCard extends StatefulWidget {
  final String symbol;
  final num? volume;
  final String badgeLabel;
  final Color badgeColor;
  final String amount;
  final Color amountColor;
  final List<_TradeFieldRow> details;

  const _HistoryCard({
    required this.symbol,
    this.volume,
    required this.badgeLabel,
    required this.badgeColor,
    required this.amount,
    required this.amountColor,
    required this.details,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final headerStyle = AppTextStyles.bodyText.copyWith(
      fontSize: 14.sp,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final volume = widget.volume;

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
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.symbol,
                          style: headerStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (volume != null) ...[
                        SizedBox(width: 5.w),
                        Text(
                          '\u2013',
                          style: headerStyle.copyWith(
                            color: AppColors.textGrey,
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          volume.toDouble().toStringAsFixed(2),
                          style: headerStyle,
                        ),
                      ],
                      if (widget.badgeLabel.isNotEmpty) ...[
                        SizedBox(width: 10.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: widget.badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            widget.badgeLabel,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: widget.badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  widget.amount,
                  style: headerStyle.copyWith(color: widget.amountColor),
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
            if (_expanded)
              for (final row in widget.details) ...[
                SizedBox(height: 10.h),
                row,
              ],
          ],
        ),
      ),
    );
  }
}

class _TradeFieldRow extends StatelessWidget {
  final Widget left;
  final Widget? right;

  const _TradeFieldRow({required this.left, this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const Spacer(),
        Expanded(child: right ?? const SizedBox.shrink()),
      ],
    );
  }
}

class _TradeField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TradeField({required this.label, required this.value, this.valueColor});

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

// ─────────────────────────────────────────────────────────────────────────────
// COMMISSION HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _CommissionTab extends StatelessWidget {
  final SubscriptionDetailController controller;

  const _CommissionTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.commissionHistory.toList();

      if (items.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_outlined, size: 40.r, color: AppColors.textGrey),
                SizedBox(height: 12.h),
                Text(
                  'No Commission History',
                  style: AppTextStyles.black16600,
                ),
              ],
            ),
          ),
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 200 &&
                controller.hasMoreCommission &&
                !controller.isLoadingMoreCommission.value) {
              controller.loadMoreCommission();
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
          itemCount: items.length + (controller.isLoadingMoreCommission.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return _CommissionRow(item: items[index]);
          },
        ),
      );
    });
  }
}

class _CommissionRow extends StatelessWidget {
  final CommissionHistoryItem item;

  const _CommissionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isBuy = item.tradeType.toLowerCase() == 'buy';
    final status =
        item.status.isEmpty
            ? '-'
            : item.status[0].toUpperCase() + item.status.substring(1);

    return _HistoryCard(
      symbol: item.symbol,
      volume: item.copierVolume,
      badgeLabel: item.tradeType.toUpperCase(),
      badgeColor: isBuy ? AppColors.green : AppColors.error,
      amount: '-\$${item.commissionAccruedDisplay.abs().toStringAsFixed(2)}',
      amountColor: AppColors.error,
      details: [
        _TradeFieldRow(
          left: _TradeField(
            label: TranslationUtils.tr('general_profit'),
            value: _signedUsd(item.copierProfit),
            valueColor:
                item.copierProfit >= 0 ? AppColors.green : AppColors.error,
          ),
          right: _TradeField(
            label: TranslationUtils.tr('copy_trading_net_credited'),
            value: '\$${item.netCredited.toDouble().toStringAsFixed(2)}',
          ),
        ),
        _TradeFieldRow(
          left: _TradeField(
            label: 'Rate',
            value: '${item.commissionPercentage.toStringAsFixed(0)}%',
          ),
          right: _TradeField(
            label: TranslationUtils.tr('common_status'),
            value: status,
          ),
        ),
        _TradeFieldRow(
          left: _TradeField(
            label: TranslationUtils.tr('ticket_status_closed'),
            value: _formatDateString(item.closeTime),
          ),
          right: _TradeField(
            label: 'Settled',
            value: _formatDateString(item.settledAt),
          ),
        ),
      ],
    );
  }
}