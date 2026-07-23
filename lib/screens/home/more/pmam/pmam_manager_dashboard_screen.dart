import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/pmam/pmam_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:fl_chart/fl_chart.dart';

class PmamManagerDashboardScreen extends StatefulWidget {
  const PmamManagerDashboardScreen({super.key});

  @override
  State<PmamManagerDashboardScreen> createState() =>
      _PmamManagerDashboardScreenState();
}

class _PmamManagerDashboardScreenState extends State<PmamManagerDashboardScreen> {
  late final PmamController _ctrl;
  String _selectedChartTab = 'Equity';

  @override
  void initState() {
    if (Get.isRegistered<PmamController>()) {
      _ctrl = Get.find<PmamController>();
    } else {
      _ctrl = Get.put(PmamController());
    }
    _ctrl.loadManagerDashboard();
    super.initState();
  }

  String _fmt(dynamic val) {
    if (val == null) return '\$0';
    final d = double.tryParse(val.toString()) ?? 0.0;
    if (d.abs() >= 1000000) return '\$${(d / 1000000).toStringAsFixed(1)}M';
    if (d.abs() >= 1000) return '\$${(d / 1000).toStringAsFixed(1)}K';
    return '\$${d.toStringAsFixed(2)}';
  }

  String _fmtNum(dynamic val) {
    if (val == null) return '0';
    final d = double.tryParse(val.toString()) ?? 0.0;
    if (d.abs() >= 1000000) return '${(d / 1000000).toStringAsFixed(1)}M';
    if (d.abs() >= 1000) return '${(d / 1000).toStringAsFixed(1)}K';
    if (d % 1 == 0) return d.toInt().toString();
    return d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   scrolledUnderElevation: 0,
      //   backgroundColor: AppColors.background,
      //   elevation: 0,
      //   title: Text('MANAGER DASHBOARD', style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      //   centerTitle: true,
      //   leading: AppSvgBackButton(
      //     onPressed: () => Get.back(closeOverlays: true),
      //     iconWidth: 30.w,
      //     iconHeight: 30.h,
      //   ),
      //   actions: [
      //     IconButton(
      //       icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 22.sp),
      //       onPressed: _ctrl.loadManagerDashboard,
      //     ),
      //   ],
      // ),
      body: Obx(() {
        if (_ctrl.isLoading.value) {
          return Center(child: CommonLoadingWidget(size: 40, color: AppColors.primary));
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _ctrl.loadManagerDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopFilters(),
                SizedBox(height: 16.h),
                _buildHeroCards(),
                SizedBox(height: 16.h),
                _buildPerformanceChart(),
                SizedBox(height: 16.h),
                _buildInvestorHealth(),
                SizedBox(height: 16.h),
                _buildPlanPerformance(),
                SizedBox(height: 16.h),
                _buildPayouts(),
                SizedBox(height: 16.h),
                _buildRecentTrades(),
                SizedBox(height: 80.h),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTopFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Today', '7d', '30d', '90d', '1y', 'all'].map((range) {
          final isSelected = _ctrl.dashboardRange.value == range;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ChoiceChip(
              label: Text(range.toUpperCase()),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  _ctrl.dashboardRange.value = range;
                  _ctrl.loadManagerDashboard();
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.card,
              labelStyle: AppTextStyles.bodyText.copyWith(
                color: isSelected ? AppColors.onColoredBackground : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border.withOpacity(0.2),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeroCards() {
    final hero = _ctrl.heroStats;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.35,
      children: [
        _HeroCard(
          title: 'Total AUM',
          value: _fmt(hero['aum']?['current']),
          delta: hero['aum']?['delta_pct']?.toString(),
          icon: Icons.account_balance_wallet_outlined,
          sparklineData: hero['aum']?['series']?['data'],
        ),
        _HeroCard(
          title: 'Active Investors',
          value: _fmtNum(hero['investors']?['current']),
          delta: hero['investors']?['delta']?.toString(),
          icon: Icons.people_outline,
          sparklineData: hero['investors']?['series']?['data'],
          deltaIsAbsolute: true,
        ),
        _HeroCard(
          title: 'Commission Earned',
          value: _fmt(hero['earnings']?['current']),
          delta: hero['earnings']?['delta_pct']?.toString(),
          icon: Icons.payments_outlined,
          sparklineData: hero['earnings']?['series']?['data'],
        ),
        _HeroCard(
          title: 'ROI (Window)',
          value: '${_fmtNum(hero['roi']?['current_pct'])}%',
          delta: hero['roi']?['delta_pct']?.toString(),
          icon: Icons.trending_up,
          sparklineData: hero['roi']?['series']?['data'],
        ),
      ],
    );
  }

  Widget _buildPerformanceChart() {
    final chartData = _ctrl.mainChartData;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance Overview',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Equity', 'AUM', 'Net P&L'].map((tab) {
                final isSelected = _selectedChartTab == tab;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedChartTab = tab;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 12.w),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      tab,
                      style: AppTextStyles.bodyText.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 200.h,
            child: _buildLineChart(chartData),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(Map<dynamic, dynamic> chartData) {
    // Determine which data array to use based on selected tab
    String dataKey = 'equity';
    if (_selectedChartTab == 'AUM') dataKey = 'aum';
    if (_selectedChartTab == 'Net P&L') dataKey = 'pnl';

    final series = chartData[dataKey]?['series'];
    if (series == null || series['data'] == null || (series['data'] as List).isEmpty) {
      return Center(
        child: Text('No data available for $_selectedChartTab',
            style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey)),
      );
    }

    final rawData = series['data'] as List;
    final rawLabels = (series['labels'] is List)
        ? (series['labels'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (int i = 0; i < rawData.length; i++) {
      final y = double.tryParse(rawData[i].toString()) ?? 0.0;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }

    if (spots.isEmpty) return SizedBox();

    if (minY == maxY) {
      // Give zero / flat series a tiny visible band.
      final pad = minY.abs() * 0.1;
      minY -= pad == 0 ? 1 : pad;
      maxY += pad == 0 ? 1 : pad;
    }

    final range = maxY - minY;
    final paddedMin = minY - range * 0.15;
    final paddedMax = maxY + range * 0.15;
    final isPositiveTrend =
        spots.last.y >= spots.first.y; // simple end-vs-start trend
    final lineColor = isPositiveTrend ? AppColors.green : AppColors.error;

    // X-axis label sampling — show ~4 dates evenly spaced.
    final labelStep = (spots.length / 4).ceil().clamp(1, spots.length);

    String fmtLabel(double v) {
      final i = v.round();
      if (i < 0 || i >= rawLabels.length) return '';
      final raw = rawLabels[i];
      // raw is "YYYY-MM-DD HH:mm" → return "MMM dd"
      try {
        final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${months[dt.month - 1]} ${dt.day}';
      } catch (_) {
        return raw.split(' ').first;
      }
    }

    String fmtValue(double v) {
      if (_selectedChartTab == 'Net P&L' || _selectedChartTab == 'AUM') {
        if (v.abs() >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
        if (v.abs() >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
        return '\$${v.toStringAsFixed(2)}';
      }
      // Equity → same currency formatting.
      if (v.abs() >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
      return '\$${v.toStringAsFixed(2)}';
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: range / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border.withOpacity(0.25),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22.h,
              interval: labelStep.toDouble(),
              getTitlesWidget: (value, meta) {
                final text = fmtLabel(value);
                if (text.isEmpty) return SizedBox();
                return Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Text(
                    text,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 10.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: paddedMin,
        maxY: paddedMax,
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.92),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding:
                EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            getTooltipItems: (touched) {
              return touched.map((s) {
                final label = fmtLabel(s.x);
                final val = fmtValue(s.y);
                return LineTooltipItem(
                  '$val\n',
                  AppTextStyles.bodyText.copyWith(
                    color: AppColors.onColoredBackground,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.sp,
                  ),
                  children: [
                    TextSpan(
                      text: label,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.onColoredBackground.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (barData, indicators) {
            return indicators.map((i) {
              return TouchedSpotIndicatorData(
                FlLine(color: lineColor.withOpacity(0.4), strokeWidth: 1),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, p, bar, idx) => FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: AppColors.card,
                  ),
                ),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withOpacity(0.22),
                  lineColor.withOpacity(0.02),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildInvestorHealth() {
    final health = _ctrl.investorHealth;
    final active = int.tryParse(health['active']?.toString() ?? '0') ?? 0;
    final pending = int.tryParse(health['pending']?.toString() ?? '0') ?? 0;
    final inactive = int.tryParse(health['inactive']?.toString() ?? '0') ?? 0;
    final total = active + pending + inactive;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investor Health',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              SizedBox(
                width: 100.w,
                height: 100.w,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30.r,
                    sections: total == 0 ? [
                      PieChartSectionData(
                        color: AppColors.textGrey.withOpacity(0.2),
                        value: 1,
                        title: '',
                        radius: 12.r,
                      )
                    ] : [
                      PieChartSectionData(
                        color: AppColors.green,
                        value: active.toDouble(),
                        title: '',
                        radius: 12.r,
                      ),
                      PieChartSectionData(
                        color: AppColors.warning,
                        value: pending.toDouble(),
                        title: '',
                        radius: 12.r,
                      ),
                      PieChartSectionData(
                        color: AppColors.textGrey,
                        value: inactive.toDouble(),
                        title: '',
                        radius: 12.r,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  children: [
                    _HealthRow(color: AppColors.green, label: 'Active', value: active.toString()),
                    SizedBox(height: 8.h),
                    _HealthRow(color: AppColors.warning, label: 'Pending', value: pending.toString()),
                    SizedBox(height: 8.h),
                    _HealthRow(color: AppColors.textGrey, label: 'Inactive', value: inactive.toString()),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(label: 'New (Period)', value: _fmtNum(health['new_this_period'])),
              _StatItem(label: 'Churned', value: _fmtNum(health['churned'])),
              _StatItem(label: 'Avg Age', value: '${_fmtNum(health['avg_age_days'])}d'),
              _StatItem(label: 'Retention', value: '${_fmtNum(health['retention_rate'])}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPerformance() {
    final plans = _ctrl.managerPlans;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plan Performance',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(
                  AppPages.PMAM_MANAGER_PORTAL,
                  arguments: {'initialTab': 1},
                ),
                child: Text(
                  'View All',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (plans.isEmpty)
            Text('No plans available', style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plans.length > 3 ? 3 : plans.length,
              separatorBuilder: (_, __) => Divider(color: AppColors.border.withOpacity(0.1)),
              itemBuilder: (context, i) {
                final p = plans[i];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['plan_name'] ?? 'Unnamed',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '${p['active_investors'] ?? 0} Investors',
                              style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmt(p['total_locked_aum']),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'AUM',
                            style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPayouts() {
    final payouts = _ctrl.payoutsData;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payouts',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Earned (30d)',
                        style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _fmt(payouts['earned_period']),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending',
                        style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _fmt(payouts['pending']),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrades() {
    final trades = _ctrl.recentDashboardTrades;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Trades',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (trades.isEmpty)
            Text('No recent trades', style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trades.length > 5 ? 5 : trades.length,
              separatorBuilder: (_, __) => Divider(color: AppColors.border.withOpacity(0.1)),
              itemBuilder: (context, i) {
                final t = trades[i];
                final pnl = double.tryParse(t['profit']?.toString() ?? '0') ?? 0.0;
                final isProfit = pnl >= 0;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: isProfit ? AppColors.green.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14.sp,
                          color: isProfit ? AppColors.green : AppColors.error,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['symbol'] ?? 'UNKNOWN',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              t['close_time']?.toString().split(' ').first ?? '-',
                              style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmt(pnl),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: isProfit ? AppColors.green : AppColors.error,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Vol: ${t['volume'] ?? 0}',
                            style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _HealthRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 8.w),
            Text(label, style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey)),
          ],
        ),
        Text(value, style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String value;
  final String? delta;
  final IconData icon;
  final dynamic sparklineData;
  final bool deltaIsAbsolute;

  const _HeroCard({
    required this.title,
    required this.value,
    this.delta,
    required this.icon,
    this.sparklineData,
    this.deltaIsAbsolute = false,
  });

  @override
  Widget build(BuildContext context) {
    double d = double.tryParse(delta ?? '0') ?? 0.0;
    bool isPositive = d >= 0;
    Color dColor = isPositive ? AppColors.green : AppColors.error;
    String dText = isPositive ? '+${d.toStringAsFixed(1)}' : d.toStringAsFixed(1);
    if (!deltaIsAbsolute) dText += '%';

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w500),
              ),
              Icon(icon, size: 16.sp, color: AppColors.primary.withOpacity(0.6)),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Spacer(),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: dColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  dText,
                  style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp, fontWeight: FontWeight.bold, color: dColor),
                ),
              ),
              if (sparklineData != null && sparklineData is List && (sparklineData as List).isNotEmpty)
                Expanded(
                  child: SizedBox(
                    height: 20.h,
                    child: _MiniSparkline(data: sparklineData as List, color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List data;
  final Color color;
  const _MiniSparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox();
    
    double minY = double.infinity;
    double maxY = -double.infinity;
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final y = double.tryParse(data[i].toString()) ?? 0.0;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }
    
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    return Padding(
      padding: EdgeInsets.only(left: 8.w),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
