import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trade_win/view_models/trade_win_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trade_win_format.dart';

class TradeWinProfileTab extends StatelessWidget {
  const TradeWinProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final controller = Get.find<TradeWinController>();

    return Column(
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(8.w, 8.h, 16.w, 0),
          child: Row(
            children: [
              const AppBackButton(),
              Expanded(
                child: Text(
                  languageService.tr('tw_nav_profile'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading,
                ),
              ),
              SizedBox(width: AppBackButton.leadingSlotSize.w),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            final stats = controller.stats.value;
            if (stats == null) {
              return Center(
                child: Text(
                  languageService.tr('tw_no_data'),
                  style: AppTextStyles.subheading,
                ),
              );
            }

            return ListView(
              padding: EdgeInsetsDirectional.fromSTEB(16.w, 16.h, 16.w, 100.h),
              children: [
                _StatCard(
                  title: languageService.tr('tw_available_points'),
                  value: TradeWinFormat.points(stats.totalPoints),
                  valueColor: AppColors.green,
                ),
                SizedBox(height: 12.h),
                _StatCard(
                  title: languageService.tr('tw_total_lots'),
                  value: TradeWinFormat.lots(stats.totalLots),
                  valueColor: AppColors.primary,
                ),
                SizedBox(height: 12.h),
                _StatCard(
                  title: languageService.tr('tw_lifetime_lots'),
                  value: TradeWinFormat.lots(stats.lifetimeLots),
                  valueColor: AppColors.textPrimary,
                ),
                SizedBox(height: 12.h),
                _StatCard(
                  title: languageService.tr('tw_spent_lots'),
                  value: TradeWinFormat.lots(stats.spentLots),
                  valueColor: AppColors.error,
                ),
                SizedBox(height: 12.h),
                _StatCard(
                  title: languageService.tr('tw_total_prize'),
                  value: TradeWinFormat.currency(stats.totalPrizeValueWon),
                  valueColor: AppColors.quickActionOrange,
                ),
                SizedBox(height: 12.h),
                _StatCard(
                  title: languageService.tr('tw_past_wins'),
                  value: '${stats.pastWinsCount}',
                  valueColor: AppColors.green,
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.label.copyWith(color: AppColors.primary)),
          Text(
            value,
            style: AppTextStyles.headingblack.copyWith(
              color: valueColor,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }
}
