import 'package:crm_app/widgets/dashBorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../investment_detail_screen.dart';

// ─── Mock data model ───────────────────────────────────────────────
class _MasterInvestment {
  final String name;
  final String badge;
  final String profit;
  final String floatProfit;
  final String equity;
  final String gain;

  const _MasterInvestment({
    required this.name,
    required this.badge,
    required this.profit,
    required this.floatProfit,
    required this.equity,
    required this.gain,
  });
}

final _mockMasters = [
  const _MasterInvestment(
    name: 'Prime_traders',
    badge: 'High Achiever',
    profit: r'$0.00',
    floatProfit: r'$0.00',
    equity: r'$70.50',
    gain: '0.00%',
  ),
  const _MasterInvestment(
    name: 'Prime_traders',
    badge: 'High Achiever',
    profit: r'$0.00',
    floatProfit: r'$0.00',
    equity: r'$70.50',
    gain: '0.00%',
  ),
  const _MasterInvestment(
    name: 'Prime_traders',
    badge: 'High Achiever',
    profit: r'$0.00',
    floatProfit: r'$0.00',
    equity: r'$70.50',
    gain: '0.00%',
  ),
];

// ─── Main Tab ──────────────────────────────────────────────────────
class InvestmentTab extends StatefulWidget {
  const InvestmentTab({super.key});

  @override
  State<InvestmentTab> createState() => _InvestmentTabState();
}

class _InvestmentTabState extends State<InvestmentTab> {
  bool _statsExpanded = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── App Bar row ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    Get.back(canPop: true, closeOverlays: true);
                  },
                  icon: SvgPicture.asset('assets/svg/ib_dashboard/home.svg'),
                ),
                Text('Your Investment', style: AppTextStyles.screenTitle),
                SizedBox(width: 13.w), // balance spacer
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8.h),

                  // ── Your Stats card ──
                  _buildStatsCard(),

                  SizedBox(height: 16.h),

                  // ── Masters you copy ──
                  Text(
                    'Masters you copy (${_mockMasters.length})',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // ── Master cards ──
                  ..._mockMasters.map((master) => _MasterCard(master: master)),

                  SizedBox(height: 20.h),

                  // ── History ──
                  Text(
                    'History (0)',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 60.h), // bottom nav padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Your Stats collapsible card ──────────────────────────────────
  Widget _buildStatsCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 0),
      margin: EdgeInsets.symmetric(horizontal: 0.w, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.surface),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTileTheme(
        data: const ListTileThemeData(
          dense: true,
          minVerticalPadding: 0,
          minTileHeight: 40, // Reduces header height further
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            showTrailingIcon: true,
            initiallyExpanded: _statsExpanded,
            onExpansionChanged: (v) => setState(() => _statsExpanded = v),
            iconColor: AppColors.textPrimary,
            collapsedIconColor: AppColors.textGrey,
            tilePadding: EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: EdgeInsets.only(left: 10, right: 16, bottom: 12),
            title: Text(
              'Your Stats',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            children: [
              _buildStatRow('Profit', r'$0.00'),
              _buildStatRow('Float profit', r'$0.00'),
              _buildStatRow('Equity', r'$70.50'),
              _buildStatRow('Gain', r'$0.00'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey),
          ),
          Flexible(
            child: DashedUnderline(
              color: AppColors.dashLineColor,
              dashSpace: 3,
              dashWidth: 3,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Individual Master Card with expand/collapse ──────────────────
class _MasterCard extends StatefulWidget {
  final _MasterInvestment master;
  const _MasterCard({required this.master});

  @override
  State<_MasterCard> createState() => _MasterCardState();
}

class _MasterCardState extends State<_MasterCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.to(
          () => InvestmentDetailScreen(
            subscriptionId: 0,
            traderName: widget.master.name,
            traderBadge: widget.master.badge,
            equity: widget.master.equity,
          ),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.surface),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Avatar + Name/Badge ──
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
              child: Row(
                children: [
                  _TraderAvatar(),
                  SizedBox(width: 5.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.master.name,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.master.badge,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.icongrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: AppColors.surface),

            // ── 2x2 stats grid ──
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCell(
                          label: 'Profit',
                          value: widget.master.profit,
                          valueColor: AppColors.green,
                        ),
                      ),
                      Expanded(
                        child: _StatCell(
                          label: 'Float profit',
                          value: widget.master.floatProfit,
                          valueColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCell(
                          label: 'Equity',
                          value: widget.master.equity,
                          valueColor: AppColors.primary,
                        ),
                      ),
                      Expanded(
                        child: _StatCell(
                          label: 'Gain',
                          value: widget.master.gain,
                          valueColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────
class _TraderAvatar extends StatelessWidget {
  const _TraderAvatar();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/svg/copy_trading/person_svg.svg');
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCell({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 12.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 5.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
