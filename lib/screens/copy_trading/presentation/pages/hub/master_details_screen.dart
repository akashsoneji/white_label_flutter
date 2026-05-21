import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_details_controller.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_hub_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'subscribe_to_plan_screen.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class MasterDetailsScreen extends StatelessWidget {
  final String masterCode;
  final String? masterNickname;
  const MasterDetailsScreen({super.key, required this.masterCode, this.masterNickname});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CopyTradingMasterDetailsController(masterCode: masterCode));

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
        leading: const AppBackButton(),
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
                _MasterHeroCard(
                  profile: profile,
                  masterCode: masterCode,
                ),
                SizedBox(height: 12.h),
                _PerformanceCard(profile: profile),
                SizedBox(height: 12.h),
                _OrdersCard(profile: profile),
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
    final commission = primaryPlan?.commissionLabel.isNotEmpty == true
        ? primaryPlan!.commissionLabel
        : (primaryPlan?.commissionType ?? '');

    final sinceDays = _daysSince(profile.memberSince);
    final withUs = sinceDays == null ? '' : '${sinceDays}d';

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
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
                  (profile.nickname.isNotEmpty ? profile.nickname : profile.name)
                      .trim()
                      .toUpperCase()
                      .padRight(1)
                      .substring(0, 1),
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.nickname.isNotEmpty ? profile.nickname : profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Container(
                          width: 7.r,
                          height: 7.r,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Expert',
                          style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
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
                child: _HeroStat(label: 'Risk score', value: profile.riskScore == null ? '-' : 'Risk ${profile.riskScore}'),
              ),
              Expanded(
                child: _HeroStat(label: 'Equity', value: '\$${profile.masterEquity.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _HeroStat(label: 'Commission', value: commission.isNotEmpty ? commission : '-'),
              ),
              Expanded(
                child: _HeroStat(label: 'With Us', value: withUs.isNotEmpty ? withUs : '-'),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            // height: 44.h,
            child: ElevatedButton(
              onPressed: primaryPlan == null || primaryPlan.isFull || primaryPlan.isEnrolled
                  ? null
                  : () async {
                      if (!Get.isRegistered<CopyTradingHubController>()) {
                        Get.put(CopyTradingHubController());
                      }
                      await Get.to(() => SubscribeToPlanScreen(masterCode: masterCode, plan: primaryPlan));
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.whiteColor,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
            ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: AppColors.tradeBackgroundCenterColor.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.grey.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strategy Description',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
                SizedBox(height: 8.h),
                Text(
                  profile.strategyDescription.trim().isEmpty ? 'No strategy description provided.' : profile.strategyDescription,
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
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
          Text(label, style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey, fontWeight: FontWeight.w700)),
          SizedBox(height: 4.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final CopyTradingMasterProfile profile;
  const _PerformanceCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final gainColor = profile.totalGain >= 0 ? AppColors.green : AppColors.red;
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Performance', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              _TimeChip(label: '2W', selected: false),
              SizedBox(width: 6.w),
              _TimeChip(label: '1M', selected: false),
              SizedBox(width: 6.w),
              _TimeChip(label: '3M', selected: true),
              SizedBox(width: 6.w),
              _TimeChip(label: '6M', selected: false),
              SizedBox(width: 6.w),
              _TimeChip(label: 'ALL', selected: false),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _PerfStat(
                  label: 'Gain (P&L)',
                  value: '${profile.totalGain >= 0 ? '+' : ''}\$${profile.totalGain.toStringAsFixed(2)}',
                  valueColor: gainColor,
                ),
              ),
              Expanded(
                child: _PerfStat(
                  label: 'Copiers',
                  value: profile.totalCopiers.toString(),
                ),
              ),
              Expanded(
                child: _PerfStat(
                  label: 'Win Rate',
                  value: '${profile.winRate.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerfStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _PerfStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey, fontWeight: FontWeight.w700)),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _TimeChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: selected ? AppColors.textPrimary : AppColors.tradeBackgroundCenterColor.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.whiteColor : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _OrdersCard extends StatelessWidget {
  final CopyTradingMasterProfile profile;
  const _OrdersCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final closed = profile.tradeHistory;
    final open = profile.openPositions;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabs: [
              Tab(text: 'Closed orders (${closed.length})'),
              Tab(text: 'Open orders (${open.length})'),
            ],
          ),
          SizedBox(
            height: 360.h,
            child: TabBarView(
              children: [
                _OrdersTable(items: closed, statusLabel: 'Closed'),
                _OrdersTable(items: open, statusLabel: 'Open'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  final List<CopyTradingTradeItem> items;
  final String statusLabel;
  const _OrdersTable({required this.items, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No orders',
          style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        return _OrderCard(item: items[index], statusLabel: statusLabel);
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isBuy = item.side.toUpperCase() == 'BUY';
    final profitColor = item.profit >= 0 ? AppColors.green : AppColors.red;
    final sideColor = isBuy ? AppColors.green : AppColors.red;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: sideColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sideColor.withOpacity(0.22)),
                            ),
                            child: Text(
                              item.side.toUpperCase(),
                              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: sideColor),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            item.volume.toString(),
                            style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        item.symbol,
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month, size: 16.r, color: AppColors.textGrey),
                        SizedBox(width: 6.w),
                        Text(
                          widget.statusLabel,
                          style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '\$${item.profit.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: profitColor),
                    ),
                  ],
                ),
                SizedBox(width: 8.w),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20.r,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            if (_expanded) ...[
              SizedBox(height: 12.h),
              Divider(color: Colors.grey.withOpacity(0.12), height: 1),
              SizedBox(height: 12.h),
              _DetailRow(label: 'Order ID', value: '#${item.id}'),
              _DetailRow(label: 'Open time', value: _formatTime(item.openTime)),
              if (widget.statusLabel.toLowerCase() == 'closed' && item.closeTime.trim().isNotEmpty)
                _DetailRow(label: 'Close time', value: _formatTime(item.closeTime)),
              _DetailRow(label: 'Open price', value: item.openPrice.toString()),
              if (widget.statusLabel.toLowerCase() == 'closed')
                _DetailRow(label: 'Close price', value: item.closePrice.toString()),
              _DetailRow(label: 'Volume', value: item.volume.toString()),
              _DetailRow(
                label: 'Profit',
                value: '\$${item.profit.toStringAsFixed(2)}',
                valueColor: profitColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.sp,
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
            Icon(Icons.error_outline, size: 40.r, color: AppColors.red),
            SizedBox(height: 10.h),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey)),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

