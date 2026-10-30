import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_copier_history_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../widgets/app_back_button.dart';

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
        leading: const AppBackButton(),
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
      body: SafeArea(
        child: Obx(() {
          final periods = controller.periods;
          if (controller.isLoading.value && periods.isEmpty) {
            return const _HistoryShimmer();
          }
          if (controller.errorMessage.value.isNotEmpty && periods.isEmpty) {
            return _StateMessage(
              icon: Icons.error_outline_rounded,
              iconColor: AppColors.error,
              message: controller.errorMessage.value,
              onRetry: controller.load,
            );
          }
        
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 24.h),
              children: [
                _CopierHeader(controller: controller),
                SizedBox(height: 10.h),
                if (periods.isEmpty)
                  _StateMessage(
                    icon: Icons.history_toggle_off_rounded,
                    iconColor: AppColors.textGrey,
                    message: TranslationUtils.tr('copier_history_no_periods'),
                  )
                else
                  for (final period in periods)
                    Padding(
                      key: ValueKey(period.subscriptionNumber),
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: _PeriodCard(period: period),
                    ),
              ],
            ),
          );
        }),
      ),
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

Color _statusColor(String status) => switch (status.toLowerCase()) {
  'active' => AppColors.green,
  'pending' => AppColors.warning,
  'stopped' || 'cancelled' || 'stopped_or_removed' => AppColors.error,
  _ => AppColors.textGrey,
};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

RoundedRectangleBorder _cardShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12.r),
  side: BorderSide(color: AppColors.border.withValues(alpha: 0.15)),
);

class _CopierHeader extends StatelessWidget {
  final CopyTradingCopierHistoryController controller;
  const _CopierHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final periods = controller.periods;
    final totalPnl = periods.fold<num>(0, (sum, p) => sum + p.periodPnl);
    final totalCommission =
        periods.fold<num>(0, (sum, p) => sum + p.periodCommissionPaid);
    final totalTrades = periods.fold<int>(0, (sum, p) => sum + p.tradesCount);
    final subtitle = [controller.planName.value, controller.accountNumber.value]
        .where((s) => s.isNotEmpty)
        .join('  •  ');

    return Material(
      color: AppColors.card,
      shape: _cardShape(),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    _initials(controller.copierName.value),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.copierName.value.isEmpty
                            ? '-'
                            : controller.copierName.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
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
                if (controller.status.value.isNotEmpty) ...[
                  SizedBox(width: 6.w),
                  _StatusPill(status: controller.status.value),
                ],
              ],
            ),
            SizedBox(height: 10.h),
            _MetricsStrip(
              metrics: [
                _KeyMetric(
                  label: TranslationUtils.tr('copy_trading_combined_pnl_upper'),
                  value: _money(totalPnl),
                  valueColor: _pnlColor(totalPnl),
                ),
                _KeyMetric(
                  label: TranslationUtils.tr('copy_trading_commission_paid_upper'),
                  value: _money(totalCommission),
                ),
                _KeyMetric(
                  label: TranslationUtils.trArgs('copier_history_trades', {
                    'count': '',
                  }).replaceAll(RegExp(r'[\s(]*\)?\s*$'), '').toUpperCase(),
                  value: totalTrades.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsStrip extends StatelessWidget {
  final List<Widget> metrics;
  const _MetricsStrip({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.tradeBackgroundCenterColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(children: metrics),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.r,
            height: 5.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 4.w),
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsed by default; tapping the header reveals the period details.
class _PeriodCard extends StatefulWidget {
  final CopierSubscriptionPeriod period;
  const _PeriodCard({required this.period});

  @override
  State<_PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<_PeriodCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    final end = period.unsubscribedAt.isEmpty
        ? TranslationUtils.tr('wallet_active')
        : _formatDate(period.unsubscribedAt);

    return Material(
      color: AppColors.card,
      shape: _cardShape(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 6.w, 10.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              TranslationUtils.trArgs('copier_history_period', {
                                'number': '${period.subscriptionNumber}',
                              }),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            _StatusPill(status: period.status),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${_formatDate(period.subscribedAt)}  →  $end',
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(period.periodPnl),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: _pnlColor(period.periodPnl),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        TranslationUtils.trArgs('copier_history_duration_days', {
                          'days': '${period.durationDays}',
                        }),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 10.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22.r,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _PeriodDetails(period: period)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PeriodDetails extends StatelessWidget {
  final CopierSubscriptionPeriod period;
  const _PeriodDetails({required this.period});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.12)),
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricsStrip(
                metrics: [
                  _KeyMetric(
                    label: TranslationUtils.tr('copier_history_equity_at_start'),
                    value: _money(period.equityAtSubscribe),
                  ),
                  _KeyMetric(
                    label: TranslationUtils.tr('copier_history_period_pnl'),
                    value: _money(period.periodPnl),
                    valueColor: _pnlColor(period.periodPnl),
                  ),
                  _KeyMetric(
                    label: TranslationUtils.tr('copier_history_commission_paid'),
                    value: _money(period.periodCommissionPaid),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 15.r, color: AppColors.primary),
                  SizedBox(width: 6.w),
                  Text(
                    TranslationUtils.trArgs('copier_history_trades', {
                      'count': '${period.tradesCount}',
                    }),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              if (period.trades.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Text(
                    TranslationUtils.tr('investment_detail_screen_no_trade_history_found'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 11.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                )
              else
                for (final trade in period.trades)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: _TradeTile(trade: trade),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeyMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _KeyMetric({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
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
              child: Text(
                value,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeTile extends StatelessWidget {
  final CopierHistoryTrade trade;
  const _TradeTile({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.tradeType.toLowerCase().contains('buy');
    final sideColor = isBuy ? AppColors.green : AppColors.error;
    final time = trade.closeTime.isNotEmpty ? trade.closeTime : trade.openTime;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.tradeBackgroundCenterColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8.r),
        border: BorderDirectional(
          start: BorderSide(color: sideColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trade.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: sideColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '${trade.tradeType.toUpperCase()} ${trade.copierVolume}',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: sideColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  '${trade.openPrice} → ${trade.closePrice}  •  ${_formatDate(time)}',
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
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w800,
              color: _pnlColor(trade.copierProfit),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final Future<void> Function()? onRetry;
  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28.r, color: iconColor),
            ),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                color: AppColors.textGrey,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 12.h),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(TranslationUtils.tr('common_retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.onColoredBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
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

class _HistoryShimmer extends StatelessWidget {
  const _HistoryShimmer();

  @override
  Widget build(BuildContext context) {
    final block = AppColors.card;
    Widget bar(double h) => Container(
      height: h,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(12.r),
      ),
    );

    return Shimmer.fromColors(
      baseColor: AppColors.border.withValues(alpha: 0.12),
      highlightColor: AppColors.card,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 24.h),
        children: [
          bar(110.h),
          SizedBox(height: 10.h),
          for (var i = 0; i < 4; i++) ...[
            bar(56.h),
            SizedBox(height: 8.h),
          ],
        ],
      ),
    );
  }
}
