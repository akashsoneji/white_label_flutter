import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_copier_history_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Master view of one copier's subscribe/unsubscribe periods and the trades
/// copied in each (`GET master/copiers/{copierId}/subscription-history`).
class CopierSubscriptionHistoryScreen extends StatefulWidget {
  final int copierId;
  const CopierSubscriptionHistoryScreen({super.key, required this.copierId});

  @override
  State<CopierSubscriptionHistoryScreen> createState() =>
      _CopierSubscriptionHistoryScreenState();
}

class _CopierSubscriptionHistoryScreenState
    extends State<CopierSubscriptionHistoryScreen> {
  late final CopyTradingCopierHistoryController controller;
  late final String _tag;

  @override
  void initState() {
    super.initState();
    _tag = 'copier-history-${widget.copierId}';
    controller = Get.put(
      CopyTradingCopierHistoryController(copierId: widget.copierId),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<CopyTradingCopierHistoryController>(tag: _tag, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('copier_history_screen_title'),
          style: AppTextStyles.screenTitle,
        ),
        actions: [
          IconButton(
            onPressed: controller.load,
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.periods.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value.isNotEmpty &&
            controller.periods.isEmpty) {
          return _ErrorView(
            message: controller.errorMessage.value,
            onRetry: controller.load,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 40.h),
            children: [
              _CopierHeader(controller: controller),
              SizedBox(height: 12.h),
              if (controller.periods.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 80.h),
                  child: Text(
                    TranslationUtils.tr('copier_history_no_periods'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                )
              else
                ...controller.periods.map(
                  (p) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _PeriodCard(period: p),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

String _formatDate(String iso) {
  if (iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  return dt == null ? iso : DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
}

String _money(num v) => '\$${v.toStringAsFixed(2)}';

Color _pnlColor(num v) => v >= 0 ? AppColors.green : AppColors.error;

class _CopierHeader extends StatelessWidget {
  final CopyTradingCopierHistoryController controller;
  const _CopierHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.copierName.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${controller.planName.value}  •  ${controller.accountNumber.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(status: controller.status.value),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'active' => AppColors.green,
      'pending' => AppColors.warning,
      'stopped' || 'cancelled' => AppColors.error,
      _ => AppColors.textGrey,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 9.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final CopierSubscriptionPeriod period;
  const _PeriodCard({required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14.w),
          childrenPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  TranslationUtils.trArgs('copier_history_period', {
                    'number': '${period.subscriptionNumber}',
                  }),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(status: period.status),
            ],
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              '${_formatDate(period.subscribedAt)} → '
              '${period.unsubscribedAt.isEmpty ? '…' : _formatDate(period.unsubscribedAt)}'
              '  •  ${TranslationUtils.trArgs('copier_history_duration_days', {'days': '${period.durationDays}'})}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.5.sp,
                color: AppColors.textGrey,
              ),
            ),
          ),
          children: [
            _MetricsRow(period: period),
            SizedBox(height: 10.h),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                TranslationUtils.trArgs('copier_history_trades', {
                  'count': '${period.tradesCount}',
                }),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            if (period.trades.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Text(
                  TranslationUtils.tr('investment_detail_screen_no_trade_history_found'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              )
            else
              ...period.trades.map((t) => _TradeRow(trade: t)),
          ],
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final CopierSubscriptionPeriod period;
  const _MetricsRow({required this.period});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: TranslationUtils.tr('copier_history_equity_at_start'),
            value: _money(period.equityAtSubscribe),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _Metric(
            label: TranslationUtils.tr('copier_history_period_pnl'),
            value: _money(period.periodPnl),
            valueColor: _pnlColor(period.periodPnl),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _Metric(
            label: TranslationUtils.tr('copier_history_commission_paid'),
            value: _money(period.periodCommissionPaid),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Metric({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.tradeBackgroundCenterColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
            ),
          ),
          SizedBox(height: 3.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeRow extends StatelessWidget {
  final CopierHistoryTrade trade;
  const _TradeRow({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.tradeType.toLowerCase().contains('buy');
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trade.symbol}  ${trade.tradeType.toUpperCase()}  ${trade.copierVolume}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: isBuy ? AppColors.green : AppColors.error,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${trade.openPrice} → ${trade.closePrice}  •  ${_formatDate(trade.closeTime.isNotEmpty ? trade.closeTime : trade.openTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            _money(trade.copierProfit),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _pnlColor(trade.copierProfit),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40.r, color: AppColors.error),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
              ),
              child: Text(
                TranslationUtils.tr('common_retry'),
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.onColoredBackground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
