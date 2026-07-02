import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_details_controller.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_hub_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'subscribe_to_plan_screen.dart';

class MasterDetailsScreen extends StatelessWidget {
  final String masterCode;
  final String? masterNickname;
  const MasterDetailsScreen({
    super.key,
    required this.masterCode,
    this.masterNickname,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      CopyTradingMasterDetailsController(masterCode: masterCode),
    );

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          masterNickname?.isNotEmpty == true ? masterNickname! : 'Master',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading:  AppSvgBackButton(
          onPressed: () => AppSvgBackButton.popRoute(context),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
        
        actions: [
          IconButton(
            onPressed: () => controller.loadProfile(showLoading: true),
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value.isNotEmpty) {
          return _ErrorState(
            message: controller.errorMessage.value,
            onRetry: () => controller.loadProfile(showLoading: true),
          );
        }

        final profile = controller.profile.value;
        if (profile == null) {
          return const Center(child: Text('No data'));
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadProfile(showLoading: false),
          child: DefaultTabController(
            length: 2,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 22.h),
              children: [
                _MasterHeroCard(profile: profile, masterCode: masterCode),
                SizedBox(height: 12.h),
                _ViewByPlanCard(profile: profile, controller: controller),
                SizedBox(height: 12.h),
                _PerformanceCard(
                  profile: profile,
                  controller: controller,
                  masterCode: masterCode,
                ),
                SizedBox(height: 12.h),
                // _PlansCard(profile: profile, masterCode: masterCode),
                // SizedBox(height: 12.h),
                _OrdersCard(profile: profile, controller: controller),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _MasterHeroCard extends StatelessWidget {
  final CopyTradingMasterProfile profile;
  final String masterCode;
  const _MasterHeroCard({required this.profile, required this.masterCode});

  @override
  Widget build(BuildContext context) {
    final primaryPlan = profile.plans.isNotEmpty ? profile.plans.first : null;
    final minInvestment = primaryPlan?.minimumCapital ?? 0;
    final commission =
        primaryPlan?.commissionLabel.isNotEmpty == true
            ? primaryPlan!.commissionLabel
            : (primaryPlan?.commissionType ?? '');

    final sinceDays = profile.withUsDays ?? _daysSince(profile.memberSince);
    final withUs = sinceDays == null ? '' : '${sinceDays}d';

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  (profile.nickname.isNotEmpty
                          ? profile.nickname
                          : profile.name)
                      .trim()
                      .toUpperCase()
                      .padRight(1)
                      .substring(0, 1),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.nickname.isNotEmpty
                          ? profile.nickname
                          : profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Container(
                          width: 7.r,
                          height: 7.r,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Expert',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Risk score',
                  value:
                      profile.riskScore == null
                          ? '-'
                          : 'Risk ${profile.riskScore}',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'Equity',
                  value: '\$${profile.masterEquity.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'Commission',
                  value: commission.isNotEmpty ? commission : '-',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'With Us',
                  value: withUs.isNotEmpty ? withUs : '-',
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            // height: 44.h,
            child: ElevatedButton(
              onPressed:
                  primaryPlan == null ||
                          primaryPlan.isFull ||
                          primaryPlan.isEnrolled
                      ? null
                      : () async {
                        if (!Get.isRegistered<CopyTradingHubController>()) {
                          Get.put(CopyTradingHubController());
                        }
                        await Get.to(
                          () => SubscribeToPlanScreen(
                            masterCode: masterCode,
                            plan: primaryPlan,
                          ),
                        );
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.whiteColor,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Subscribe',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          if (minInvestment > 0)
            Text(
              'Minimum investment \$${minInvestment.toString()}',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: AppColors.tradeBackgroundCenterColor.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strategy Description',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  profile.strategyDescription.trim().isEmpty
                      ? 'No strategy description provided.'
                      : profile.strategyDescription,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
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

int? _daysSince(String isoOrDate) {
  final dt = DateTime.tryParse(isoOrDate);
  if (dt == null) return null;
  final now = DateTime.now();
  final diff = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
  return diff < 0 ? 0 : diff;
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewByPlanCard extends StatelessWidget {
  final CopyTradingMasterProfile profile;
  final CopyTradingMasterDetailsController controller;
  const _ViewByPlanCard({required this.profile, required this.controller});

  @override
  Widget build(BuildContext context) {
    final plans = profile.plans;
    if (plans.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'View by plan',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(
              () => Row(
                children: [
                  _PlanChip(
                    label: 'All plans',
                    selected: controller.selectedPlanId.value.isEmpty,
                    onTap: () => controller.selectPlan(''),
                  ),
                  ...plans.map(
                    (plan) => Padding(
                      padding: EdgeInsets.only(left: 8.w),
                      child: _PlanChip(
                        label: plan.planName,
                        selected:
                            controller.selectedPlanId.value ==
                            plan.planId.toString(),
                        onTap:
                            () => controller.selectPlan(plan.planId.toString()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PlanChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.whiteColor : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final CopyTradingMasterProfile profile;
  final CopyTradingMasterDetailsController controller;
  final String masterCode;
  const _PerformanceCard({
    required this.profile,
    required this.controller,
    required this.masterCode,
  });

  @override
  Widget build(BuildContext context) {
    final gainColor =
        profile.totalGainPercent >= 0 ? AppColors.green : AppColors.error;
    final pnlColor = profile.totalPnl >= 0 ? AppColors.green : AppColors.error;
    final ddColor =
        profile.maxDrawdown > 0 ? AppColors.error : AppColors.textPrimary;
    return Obx(() {
      if (controller.isPlanOrTimeframeLoading.value) {
        return Container(
          height: 80.h,
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: CommonLoadingWidget(size: 32.0, color: AppColors.primary),
          ),
        );
      }
      return Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Obx(
                  () => _TimeChip(
                    label: '7D',
                    selected: controller.selectedTimeframe.value == '7d',
                    onTap: () => controller.selectTimeframe('7d'),
                  ),
                ),
                SizedBox(width: 6.w),
                Obx(
                  () => _TimeChip(
                    label: '2W',
                    selected: controller.selectedTimeframe.value == '2w',
                    onTap: () => controller.selectTimeframe('2w'),
                  ),
                ),
                SizedBox(width: 6.w),
                Obx(
                  () => _TimeChip(
                    label: '1M',
                    selected: controller.selectedTimeframe.value == '1m',
                    onTap: () => controller.selectTimeframe('1m'),
                  ),
                ),
                SizedBox(width: 6.w),
                Obx(
                  () => _TimeChip(
                    label: '3M',
                    selected: controller.selectedTimeframe.value == '3m',
                    onTap: () => controller.selectTimeframe('3m'),
                  ),
                ),
                SizedBox(width: 6.w),
                Obx(
                  () => _TimeChip(
                    label: '6M',
                    selected: controller.selectedTimeframe.value == '6m',
                    onTap: () => controller.selectTimeframe('6m'),
                  ),
                ),
                SizedBox(width: 6.w),
                Obx(
                  () => _TimeChip(
                    label: 'ALL',
                    selected: controller.selectedTimeframe.value == 'all',
                    onTap: () => controller.selectTimeframe('all'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            if (profile.performanceSeries.isNotEmpty)
              _PerformanceChart(series: profile.performanceSeries),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: _PerfStat(
                    label: 'Total Gain',
                    value:
                        '${profile.totalGainPercent >= 0 ? '+' : ''}${profile.totalGainPercent.toStringAsFixed(2)}%',
                    valueColor: gainColor,
                  ),
                ),
                Expanded(
                  child: _PerfStat(
                    label: 'Copiers',
                    value: profile.totalCopiers.toString(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _PerfStat(
                    label: 'Total P&L',
                    value:
                        '${profile.totalPnl >= 0 ? '+' : ''}\$${profile.totalPnl.toStringAsFixed(2)}',
                    valueColor: pnlColor,
                  ),
                ),
                Expanded(
                  child: _PerfStat(
                    label: 'Max drawdown',
                    value: '${profile.maxDrawdown.toStringAsFixed(2)}%',
                    valueColor: ddColor,
                    showUnderline: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _PerfStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool showUnderline;
  const _PerfStat({
    required this.label,
    required this.value,
    this.valueColor,
    this.showUnderline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w700,
              decoration:
                  showUnderline
                      ? TextDecoration.underline
                      : TextDecoration.none,
              decorationColor: AppColors.textGrey,
              decorationStyle: TextDecorationStyle.dotted,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _TimeChip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.textPrimary
                  : AppColors.tradeBackgroundCenterColor.withOpacity(0.35),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.whiteColor : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PerformanceChart extends StatelessWidget {
  final List<PerformanceSeriesPoint> series;

  const _PerformanceChart({required this.series});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();

    final lineSpots = <FlSpot>[];
    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < series.length; i++) {
      lineSpots.add(FlSpot(i.toDouble(), series[i].cumulativeProfit.toDouble()));
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: series[i].profit.toDouble(),
              color: series[i].profit >= 0
                  ? AppColors.green.withValues(alpha: 0.60)
                  : AppColors.error.withValues(alpha: 0.60),
              width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ],
        ),
      );
    }

    final cumulativeValues = series.map((e) => e.cumulativeProfit.toDouble()).toList();
    final tradeValues = series.map((e) => e.profit.toDouble()).toList();
    final allValues = [...cumulativeValues, ...tradeValues];
    final minAll = allValues.reduce((a, b) => a < b ? a : b);
    final maxAll = allValues.reduce((a, b) => a > b ? a : b);
    final totalRange = maxAll - minAll;
    final padding = totalRange * 0.2;

    final firstDate = DateTime.tryParse(series.first.closeTime);
    String dateLabel = series.first.closeTime;
    if (firstDate != null) {
      dateLabel = '${firstDate.day.toString().padLeft(2, '0')} ${_monthName(firstDate.month)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'From master account closed trades (user trade history), not copier copies.',
          style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            _LegendItem(color: AppColors.primary, label: 'Cumulative P&L', outlined: true),
            SizedBox(width: 16.w),
            _LegendItem(color: AppColors.green.withValues(alpha: 0.60), label: 'Trade P&L'),
          ],
        ),
        SizedBox(height: 8.h),
        SizedBox(
          height: 180.h,
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: totalRange > 0 ? totalRange / 4 : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppColors.border.withValues(alpha: 0.35),
                    strokeWidth: 0.5,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  axisNameWidget: Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text('Per trade', style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: totalRange > 0 ? totalRange / 4 : 1,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: EdgeInsets.only(left: 4.w),
                        child: Text(
                          '\$${value.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  axisNameWidget: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text('Cumulative P&L', style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(dateLabel, style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: totalRange > 0 ? totalRange / 4 : 1,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: EdgeInsets.only(right: 4.w),
                        child: Text(
                          '\$${value.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
                        ),
                      );
                    },
                  ),
                ),
              ),
              minY: minAll - padding,
              maxY: maxAll + padding,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.textPrimary,
                  tooltipBorderRadius: BorderRadius.circular(6),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = series[groupIndex];
                    final dt = DateTime.tryParse(point.closeTime);
                    String t = dateLabel;
                    if (dt != null) {
                      t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    }
                    return BarTooltipItem(
                      '$t\nTrade: \$${point.profit.toStringAsFixed(2)}\nCumulative: \$${point.cumulativeProfit.toStringAsFixed(2)}',
                      TextStyle(fontSize: 10.sp, color: AppColors.whiteColor, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: AppColors.textGrey.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month.clamp(1, 12)];
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;

  const _LegendItem({required this.color, required this.label, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            border: outlined ? Border.all(color: color, width: 1.5) : null,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ignore_for_file: unused_element
class _OrdersCard extends StatelessWidget {
  final CopyTradingMasterProfile profile;
  final CopyTradingMasterDetailsController controller;
  const _OrdersCard({required this.profile, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Obx(() => TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabs: [
              Tab(text: 'Closed orders (${controller.tradeHistory.length})'),
              Tab(text: 'Open orders (${controller.profile.value?.openPositions.length ?? 0})'),
            ],
          )),
          SizedBox(
            height: 360.h,
            child: TabBarView(
              children: [
                Obx(() => _OrdersTable(
                  items: controller.tradeHistory.toList(),
                  statusLabel: 'Closed',
                  isLoading: controller.isTradeHistoryLoading.value,
                  hasMore: controller.hasMoreTradeHistory.value,
                  isLoadingMore: controller.isLoadingMoreTradeHistory.value,
                  onLoadMore: () => controller.loadTradeHistory(isLoadMore: true),
                )),
                Obx(() => _OrdersTable(
                  items: controller.profile.value?.openPositions ?? [],
                  statusLabel: 'Open',
                  isLoading: false,
                  hasMore: false,
                  isLoadingMore: false,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatefulWidget {
  final List<CopyTradingTradeItem> items;
  final String statusLabel;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  const _OrdersTable({
    required this.items,
    required this.statusLabel,
    this.isLoading = false,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
  });

  @override
  State<_OrdersTable> createState() => _OrdersTableState();
}

class _OrdersTableState extends State<_OrdersTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (widget.hasMore && !widget.isLoadingMore && widget.onLoadMore != null) {
        widget.onLoadMore!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          'No orders',
          style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        if (index == widget.items.length) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: SizedBox(
                width: 24.r,
                height: 24.r,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            ),
          );
        }
        return _OrderCard(item: widget.items[index], statusLabel: widget.statusLabel);
      },
    );
  }
}

class _OrderCard extends StatefulWidget {
  final CopyTradingTradeItem item;
  final String statusLabel;
  const _OrderCard({required this.item, required this.statusLabel});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _expanded = false;

  bool isXAU(String symbol) =>
      symbol.toUpperCase().contains('XAU') ||
      symbol.toUpperCase().contains('GOLD');

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isBuy = item.side.toUpperCase() == 'BUY';
    final isProfit = item.profit >= 0;
    final sideColor = isBuy ? AppColors.green : AppColors.error;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
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
                            item.symbol,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            '\u2013',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textGrey,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            item.volume.toStringAsFixed(2),
                            style: TextStyle(
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
                              color: sideColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              item.side.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: sideColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isProfit ? '+' : ''}\$${item.profit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isProfit ? AppColors.green : AppColors.error,
                      ),
                    ),
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
              SizedBox(height: 12.h),
              Divider(color: AppColors.border.withValues(alpha: 0.12), height: 1),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _TField(label: 'Order ID', value: '#${item.id}'),
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 2,
                    child: _TField(
                      label: 'Volume',
                      value: item.volume.toStringAsFixed(2),
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
                      value: item.openPrice.toDouble().toStringAsFixed(
                        isXAU(item.symbol) ? 2 : 5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 2,
                    child: _TField(
                      label: 'Opened',
                      value: _formatTime(item.openTime),
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
                      label:
                          widget.statusLabel.toLowerCase() == 'closed'
                              ? 'Close Price'
                              : 'Side',
                      value:
                          widget.statusLabel.toLowerCase() == 'closed'
                              ? item.closePrice.toDouble().toStringAsFixed(
                                isXAU(item.symbol) ? 2 : 5,
                              )
                              : item.side.toUpperCase(),
                      valueColor:
                          widget.statusLabel.toLowerCase() == 'closed'
                              ? null
                              : sideColor,
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 2,
                    child: _TField(
                      label:
                          widget.statusLabel.toLowerCase() == 'closed'
                              ? 'Closed'
                              : 'Status',
                      value:
                          widget.statusLabel.toLowerCase() == 'closed'
                              ? _formatTime(item.closeTime)
                              : widget.statusLabel,
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

  String _formatTime(String iso) {
    if (iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
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
          style: TextStyle(
            fontSize: 10.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40.r, color: AppColors.error),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Strategy & risk disclosure ───────────────────────────

class _StrategyDisclosureCard extends StatelessWidget {
  final CopyTradingMasterProfile profile;
  const _StrategyDisclosureCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final strategy = profile.strategyDescription.trim();
    final hasStrategy = strategy.isNotEmpty;
    final risk = profile.riskInformation.trim();
    final hasRisk = risk.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Strategy & risk disclosure',
            style: AppTextStyles.label.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'STRATEGY',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            hasStrategy ? strategy : 'No strategy description provided.',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              color:
                  hasStrategy ? AppColors.textPrimary : AppColors.textGrey,
            ),
          ),
          if (hasRisk) ...[
            SizedBox(height: 12.h),
            Text(
              'RISK',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textGrey,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              risk,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
