import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_commission_report_screen.dart';

import 'package:crm_app/screens/ibm/presentation/pages/ibm_payout_report_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_team_funding_report_screen.dart';
import 'package:crm_app/services/language_service.dart';

/// Reports hub — the mobile version of the web sidebar "Reports" group.
/// Each report opens as its own screen (filters → Apply → results), like the
/// web pages.
class IbmReportsScreen extends StatelessWidget {
  /// When true the screen is hosted inside another tab (More) and skips its
  /// own app bar.
  final bool embedded;

  const IbmReportsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ReportItem(
        icon: Icons.south_west_rounded,
        color: Colors.green,
        titleKey: 'ibm_my_team_deposit',
        subtitleKey: 'ibm_my_team_deposit_subtitle',
        open: () => Get.to(
          () => const IbmTeamFundingReportScreen(type: 'deposit'),
        ),
      ),
      _ReportItem(
        icon: Icons.north_east_rounded,
        color: Colors.red,
        titleKey: 'ibm_my_team_withdrawal',
        subtitleKey: 'ibm_my_team_withdrawal_subtitle',
        open: () => Get.to(
          () => const IbmTeamFundingReportScreen(type: 'withdrawal'),
        ),
      ),
      _ReportItem(
        icon: Icons.payments_outlined,
        color: AppColors.primary,
        titleKey: 'ibm_ib_commission',
        subtitleKey: 'ibm_ib_commission_subtitle',
        open: () => Get.to(() => const IbmCommissionReportScreen()),
      ),
      _ReportItem(
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.orange,
        titleKey: 'ibm_ib_withdraw',
        subtitleKey: 'ibm_ib_withdraw_subtitle',
        open: () => Get.to(() => const IbmPayoutReportScreen()),
      ),
    ];

    final list = ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (_, index) => _ReportTile(item: items[index]),
    );

    if (embedded) {
      return Container(color: AppColors.tradeBackgroundCenterColor, child: list);
    }
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor:
            AppColors.isDarkMode ? AppColors.pureBlack : AppColors.whiteColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleSpacing: 0,
        title: Text(
          TranslationUtils.tr('ibm_reports'),
          style: AppTextStyles.heading.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: list,
    );
  }
}

class _ReportItem {
  final IconData icon;
  final Color color;
  final String titleKey;
  final String subtitleKey;
  final VoidCallback open;

  const _ReportItem({
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.subtitleKey,
    required this.open,
  });
}

class _ReportTile extends StatelessWidget {
  final _ReportItem item;

  const _ReportTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: item.open,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(item.icon, color: item.color, size: 20.w),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationUtils.tr(item.titleKey),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      TranslationUtils.tr(item.subtitleKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
