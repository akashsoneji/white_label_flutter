import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_dashboard_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'copy_trading_create_plan_screen.dart';
import 'master_plan_detail_screen.dart';

class MasterDashboardScreen extends StatelessWidget {
  final String masterCode;
  const MasterDashboardScreen({super.key, required this.masterCode});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      CopyTradingMasterDashboardController(masterCode: masterCode),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Master Dashboard',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAll(() => TradingMainScreen()),
        ),
        actions: [
          IconButton(
            onPressed: () => controller.refreshAll(showLoading: true),
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.stats.value == null &&
            controller.profile.value == null &&
            controller.plans.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => controller.refreshAll(showLoading: false),
          child: ListView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 90.h),
            children: [
              Text(
                'Dashboard overview',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Summary of your copy trading activity: plans, copiers, assets under management, and commission.',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textGrey,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 10.h),
              _MasterProfileCard(
                profile: controller.profile.value,
                masterCode: masterCode,
              ),
              SizedBox(height: 10.h),
              _StatsGrid(
                stats: controller.stats.value,
                profile: controller.profile.value,
                plans: controller.plans,
              ),
              SizedBox(height: 10.h),
              _PerformanceStatsCard(profile: controller.profile.value),
              SizedBox(height: 10.h),
              _OpenPositionsCard(controller: controller),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 16.r,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'My Copy Plans',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              if (controller.plans.isEmpty)
                _EmptyPlans(
                  onCreate: () => _openCreatePlanScreen(context, controller),
                )
              else
                ...controller.plans.map(
                  (p) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: _PlanTile(plan: p, controller: controller),
                  ),
                ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      }),
    );
  }

  void _openCreatePlanScreen(
    BuildContext context,
    CopyTradingMasterDashboardController controller,
  ) {
    Get.to(() => CopyTradingCreatePlanScreen(controller: controller));
  }
}

class _MasterProfileCard extends StatelessWidget {
  final CopyTradingMasterProfile? profile;
  final String masterCode;

  const _MasterProfileCard({this.profile, required this.masterCode});

  @override
  Widget build(BuildContext context) {
    final nickname = profile?.masterNickname ?? 'robert';
    final memberSince = profile?.memberSince ?? '—';

    // Initials: e.g. "robert" -> "RO"
    String initials = 'M';
    if (nickname.isNotEmpty) {
      final parts = nickname.trim().split(' ');
      if (parts.length > 1) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else {
        initials =
            nickname.substring(0, nickname.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowAlpha(0.02),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color:
                      AppColors
                          .primary, // Purple theme matching RO initials in screenshot
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.whiteColor,
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
                        Flexible(
                          child: Text(
                            nickname,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successText.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.successText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (memberSince.isNotEmpty && memberSince != '—') ...[
                      SizedBox(height: 2.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textGrey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'Member since $memberSince',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Text(
                'Master code',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  masterCode,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color:
                        AppColors
                            .primary, // Purple text color matching screenshot
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              SizedBox(
                height: 26.h,
                child: OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: masterCode));
                    CustomToastService.showSuccess(
                      message: 'Master code copied to clipboard',
                      title: 'Copied',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                  ),
                  child: Text(
                    'Copy',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 38.h,
            child: ElevatedButton.icon(
              onPressed:
                  () => Get.to(
                    () => CopyTradingCreatePlanScreen(
                      controller:
                          profile != null
                              ? Get.find<CopyTradingMasterDashboardController>()
                              : Get.put(
                                CopyTradingMasterDashboardController(
                                  masterCode: masterCode,
                                ),
                              ),
                    ),
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.whiteColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              icon: Icon(
                Icons.add_circle_outline,
                size: 16.r,
                color: AppColors.whiteColor,
              ),
              label: Text(
                'Create Plan',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.whiteColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final CopyTradingMasterDashboardStats? stats;
  final CopyTradingMasterProfile? profile;
  final List<CopyTradingMasterPlanItem> plans;

  const _StatsGrid({
    required this.stats,
    required this.profile,
    required this.plans,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final p = profile;

    // Fallbacks to profile API data if dashboard stats API returns empty
    final totalPlansValue = s?.plansCount ?? p?.totalPlans ?? plans.length;
    final activeCopiersValue = s?.activeCopiersCount ?? p?.totalCopiers ?? 0;

    num totalAumValue = 0.0;
    if (s != null) {
      totalAumValue = s.totalAum;
    } else if (p != null) {
      if (p.plans.isNotEmpty) {
        totalAumValue = p.plans.fold<num>(
          0.0,
          (sum, plan) => sum + plan.totalCapital,
        );
      } else {
        totalAumValue = p.masterEquity;
      }
    }

    final commissionEarnedValue = s?.commissionEarned ?? 0.0;

    final approvedCount =
        plans.isNotEmpty
            ? plans.where((pl) => pl.status.toLowerCase() == 'approved').length
            : (p != null ? p.plans.length : 0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'TOTAL PLANS',
                value: totalPlansValue.toString(),
                subtitle: '$approvedCount approved',
                description:
                    'Copy plans you create. Each plan has its own rules.',
                icon: Icons.layers_outlined,
                topColor: AppColors.primary,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _StatCard(
                title: 'ACTIVE COPIERS',
                value: activeCopiersValue.toString(),
                subtitle: 'Copying your trades',
                description: 'Investors mirroring your positions dynamically.',
                icon: Icons.people_outline,
                topColor: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'TOTAL EQUITY (AUM)',
                value: '\$${totalAumValue.toStringAsFixed(2)}',
                subtitle: 'Combined copier equity',
                description:
                    'Assets across all copiers following your approved plans.',
                icon: Icons.account_balance_wallet_outlined,
                topColor: AppColors.primary,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _StatCard(
                title: 'COMMISSION EARNED',
                value: '\$${commissionEarnedValue.toStringAsFixed(2)}',
                subtitle: 'Lifetime total credited',
                description: 'Total master commission credited over time.',
                icon: Icons.monetization_on_outlined,
                topColor: Color(0xFF26DE81),
                highlight: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color topColor;
  final bool highlight;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.topColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accent colored top line
          Container(
            height: 3.h,
            width: 32.w,
            decoration: BoxDecoration(
              color: topColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(icon, size: 16.r, color: topColor),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              color: highlight ? AppColors.successText : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            description,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceStatsCard extends StatelessWidget {
  final CopyTradingMasterProfile? profile;

  const _PerformanceStatsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const SizedBox.shrink();

    final winRate = profile!.winRate;
    final totalGainPercent = profile!.totalGainPercent;
    final maxDrawdown = profile!.maxDrawdown;

    final winRateText = '${winRate.toStringAsFixed(1)}%';
    final returnText =
        '${totalGainPercent >= 0 ? '+' : ''}${totalGainPercent.toStringAsFixed(2)}%';
    final returnColor =
        totalGainPercent >= 0 ? AppColors.successText : AppColors.error;

    final pw = profile!.performanceWindow;
    final totalTrades = pw?.closedTradesCount.toString() ?? '—';
    final avgDuration =
        pw != null ? _formatDuration(pw.avgTradeDurationSeconds) : '—';
    final profitFactor = pw?.profitFactor.toStringAsFixed(2) ?? '—';

    final bestProfit = pw?.bestTradeProfit ?? 0.0;
    final worstProfit = pw?.worstTradeProfit ?? 0.0;

    final bestTradeText =
        '${bestProfit >= 0 ? '+' : ''}\$${bestProfit.toStringAsFixed(2)}';
    final worstTradeText = '\$${worstProfit.toStringAsFixed(2)}';

    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowAlpha(0.02),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance stats (30d)',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Results for the last 30 days (same period as the "1M" view on the leaderboard). If you use more than one copy plan, these numbers combine all your plans together—every closed trade in that period is included. Return %, win rate, drawdown, trade count, and the other rows all use the same 30-day period.',
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          SizedBox(height: 8.h),
          Divider(),
          _buildStatRow(
            'Return %',
            returnText,
            'Total profit over the last 30 days as a percentage of your plan equity baselines (combined across plans if you have more than one)',
            valueColor: returnColor,
          ),
          _buildStatRow(
            'Win rate',
            winRateText,
            'Share of closed trades that ended in profit, out of all trades closed in the last 30 days',
          ),
          _buildStatRow(
            'Max drawdown',
            '${maxDrawdown.toStringAsFixed(1)}%',
            'Largest drop from a peak in your equity curve during the last 30 days (risk indicator)',
            valueColor: maxDrawdown > 0 ? AppColors.error : null,
          ),
          _buildStatRow(
            'Total trades',
            totalTrades,
            'How many trades closed in the last 30 days, counting every plan you run',
          ),
          _buildStatRow(
            'Avg. trade duration',
            avgDuration,
            'Average time from open to close for trades closed in the last 30 days',
          ),
          _buildStatRow(
            'Profit factor',
            profitFactor,
            'Gross profit divided by gross loss on closed trades; above 2 is often considered strong',
          ),
          _buildStatRow(
            'Best trade',
            bestTradeText,
            'Largest single-trade profit in the last 30 days',
            valueColor: AppColors.successText,
          ),
          _buildStatRow(
            'Worst trade',
            worstTradeText,
            'Largest single-trade loss in the last 30 days',
            valueColor: AppColors.error,
            isLast: true,
          ),
        ],
      ),
    );
  }

  String _formatDuration(num seconds) {
    if (seconds <= 0) return '—';
    final hrs = seconds / 3600;
    if (hrs < 1) {
      final mins = seconds / 60;
      return '${mins.toStringAsFixed(1)} mins';
    }
    return '${hrs.toStringAsFixed(1)} hrs';
  }

  Widget _buildStatRow(
    String label,
    String value,
    String description, {
    Color? valueColor,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.12)),
      ],
    );
  }
}

class _OpenPositionsCard extends StatelessWidget {
  final CopyTradingMasterDashboardController controller;

  const _OpenPositionsCard({required this.controller});

  String _formatDateTimeString2(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String _formatPrice(num price) {
    final parts = price.toStringAsFixed(2).split('.');
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '$formattedInt.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final positions = controller.openPositions;
      final isLoading = controller.isOpenPositionsLoading.value;

      if (isLoading && positions.isEmpty) {
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open positions',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              Center(
                child: SizedBox(
                  width: 24.r,
                  height: 24.r,
                  child: CircularProgressIndicator(strokeWidth: 2.r),
                ),
              ),
            ],
          ),
        );
      }

      if (positions.isEmpty) {
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open positions',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Live master positions currently mapped for copy trading.',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                alignment: Alignment.center,
                child: Text(
                  'No open positions right now.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final totalPnl = positions.fold<double>(
        0.0,
        (sum, pos) => sum + pos.profit.toDouble(),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                size: 16.r,
                color: AppColors.primary,
              ),
              SizedBox(width: 6.w),
              Text(
                'Open positions',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Live master positions currently mapped for copy trading.',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 10.h),
          
          // Cards list
          ...positions.map((pos) {
            return _OpenPositionItemTile(
              pos: pos,
              formatPrice: _formatPrice,
              formatDateTime2: _formatDateTimeString2,
            );
          }),
          
          SizedBox(height: 4.h),
          _OpenPositionsSummaryCard(
            totalPnl: totalPnl,
            formatPrice: _formatPrice,
          ),
        ],
      );
    });
  }
}

class _OpenPositionItemTile extends StatefulWidget {
  final CopyTradingOpenPositionItem pos;
  final String Function(num) formatPrice;
  final String Function(String) formatDateTime2;

  const _OpenPositionItemTile({
    required this.pos,
    required this.formatPrice,
    required this.formatDateTime2,
  });

  @override
  State<_OpenPositionItemTile> createState() => _OpenPositionItemTileState();
}

class _OpenPositionItemTileState extends State<_OpenPositionItemTile> {
  bool _expanded = false;

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.pos;
    final isBuy = pos.tradeType.toLowerCase() == 'buy';
    final badgeBg = isBuy
        ? Color(0xFFE8F5E9) // Light green
        : Color(0xFFFFEBEE); // Light red
    final badgeTextColor = isBuy
        ? Color(0xFF2E7D32) // Dark green
        : Color(0xFFC62828); // Dark red

    final profit = pos.profit.toDouble();
    final profitColor = profit >= 0 ? AppColors.green : AppColors.error;
    String profitStr;
    if (profit == 0.0) {
      profitStr = '\$0.00';
    } else {
      profitStr = '${profit > 0 ? '+' : '-'}\$${widget.formatPrice(profit.abs())}';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowAlpha(0.02),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row (Clickable)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Side: Symbol – Volume [Badge]
                  Row(
                    children: [
                      Text(
                        '${pos.symbol} – ${pos.masterVolume.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          pos.tradeType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Right Side: Profit/Loss + Chevron
                  Row(
                    children: [
                      Text(
                        profitStr,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: profitColor,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.textGrey,
                        size: 20.r,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Details section with animation
          AnimatedCrossFade(
            firstChild: SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: Column(
                children: [
                  Divider(height: 1, color: AppColors.border.withValues(alpha: 0.08)),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(child: _buildDetailItem('Order ID', '#${pos.id}')),
                      Expanded(child: _buildDetailItem('Volume', pos.masterVolume.toStringAsFixed(2))),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(child: _buildDetailItem('Open Price', widget.formatPrice(pos.openPrice))),
                      Expanded(child: _buildDetailItem('Opened', widget.formatDateTime2(pos.openTime))),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(child: _buildDetailItem('Plan', pos.planName)),
                      Expanded(child: _buildDetailItem('Copier', '${pos.copierName} (${pos.copierAccount})')),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _OpenPositionsSummaryCard extends StatelessWidget {
  final double totalPnl;
  final String Function(num) formatPrice;

  const _OpenPositionsSummaryCard({required this.totalPnl, required this.formatPrice});

  @override
  Widget build(BuildContext context) {
    final profitColor = totalPnl >= 0 ? AppColors.green : AppColors.error;
    String profitStr;
    if (totalPnl == 0.0) {
      profitStr = '\$0.00';
    } else {
      profitStr = '${totalPnl > 0 ? '+' : '-'}\$${formatPrice(totalPnl.abs())}';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowAlpha(0.02),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net floating P/L (open)',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Sum of master P/L on open mapped positions',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Text(
            profitStr,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: profitColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyPlans({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 36.r,
            color: AppColors.textGrey.withValues(alpha: 0.5),
          ),
          SizedBox(height: 8.h),
          Text(
            'No plans yet',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Create your first plan to start accepting copiers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),
          ElevatedButton(
            onPressed: onCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.whiteColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              elevation: 0,
            ),
            child: Text('Create Plan'),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final CopyTradingMasterPlanItem plan;
  final CopyTradingMasterDashboardController controller;

  const _PlanTile({required this.plan, required this.controller});

  @override
  Widget build(BuildContext context) {
    final status = plan.status;
    final statusLower = status.toLowerCase();

    final statusColor =
        statusLower == 'approved'
            ? AppColors.green
            : statusLower.contains('pending')
            ? AppColors.warning
            : statusLower.contains('inactive')
            ? AppColors.textGrey
            : AppColors.error;

    final canInactivate =
        statusLower == 'approved' && plan.activeCopiersCount == 0;
    final planSubtitle =
        (plan.commissionLabel.isNotEmpty
            ? plan.commissionLabel
            : plan.commissionType);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowAlpha(0.02),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 12.w),
          childrenPadding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 10.h),
          initiallyExpanded: false,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.planName,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (planSubtitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        planSubtitle,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.expand_more,
            color: AppColors.textGrey,
            size: 18.r,
          ),
          children: [
            SizedBox(height: 8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metric(
                        label: 'Copiers',
                        value: plan.activeCopiersCount.toString(),
                      ),
                      SizedBox(height: 6.h),
                      _metric(
                        label: 'AUM',
                        value: '\$${plan.totalCapital.toStringAsFixed(2)}',
                      ),
                      SizedBox(height: 6.h),
                      _metric(
                        label: 'Min. capital',
                        value: '\$${plan.minimumCapital.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 100.w,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 30.h,
                        child: OutlinedButton(
                          onPressed: () {
                            Get.to(
                              () => MasterPlanDetailScreen(planId: plan.id),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(0, 30.h),
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.6),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Details',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      SizedBox(
                        width: double.infinity,
                        height: 30.h,
                        child: ElevatedButton(
                          onPressed:
                              canInactivate
                                  ? () async {
                                    final ok = await Get.dialog<bool>(
                                      AlertDialog(
                                        title: Text('Inactivate Plan'),
                                        content: Text(
                                          'This will inactivate the plan. You can only inactivate when status is approved and active copiers = 0.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Get.back(result: false),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Get.back(result: true),
                                            child: Text('Inactivate'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true) return;

                                    final res = await controller.inactivatePlan(
                                      planId: plan.id,
                                    );
                                    if (res.success) {
                                      CustomToastService.showSuccess(
                                        message:
                                            res.message ?? 'Plan inactivated',
                                        title: 'Success',
                                      );
                                    } else {
                                      CustomToastService.showError(
                                        message:
                                            res.message ??
                                            controller.errorMessage.value,
                                        title: 'Error',
                                      );
                                    }
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(0, 30.h),
                            backgroundColor:
                                canInactivate
                                    ? AppColors.error
                                    : AppColors.textGrey.withValues(
                                      alpha: 0.15,
                                    ),
                            foregroundColor:
                                canInactivate
                                    ? AppColors.whiteColor
                                    : AppColors.textGrey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Inactivate',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}

Widget _metric({required String label, required String value}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          color: AppColors.textGrey,
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(height: 2.h),
      Text(
        value,
        style: TextStyle(
          fontSize: 13.sp,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
