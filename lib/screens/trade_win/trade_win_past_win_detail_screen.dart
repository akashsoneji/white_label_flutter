import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/trade_win/trade_win_past_win_model.dart';
import 'package:crm_app/models/trade_win/trade_win_spent_detail_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trade_win_format.dart';
import 'package:crm_app/screens/trade_win/widgets/trade_win_product_image.dart';
import 'package:crm_app/screens/trade_win/widgets/trade_win_status_badge.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class TradeWinPastWinDetailScreen extends StatelessWidget {
  const TradeWinPastWinDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final args = Get.arguments as Map<String, dynamic>?;
    final win = args?['win'] as TradeWinPastWinModel?;

    if (win == null) {
      return Scaffold(
        body: Center(child: Text(languageService.tr('tw_win_not_found'))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.tradeWinScaffoldBackground,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeWinScaffoldBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          languageService.tr('tw_win_details'),
          style: AppTextStyles.heading,
        ),
        leading: const AppBackButton(closeOverlays: true),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppColors.icongrey.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TradeWinProductImage(
                    imagePath: win.imagePath,
                    width: 72.w,
                    height: 72.w,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          win.productName,
                          style: AppTextStyles.headingblack,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          TradeWinFormat.categoryLabel(win.category),
                          style: AppTextStyles.subheading.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '${languageService.tr('tw_reference')}: ${win.referenceCode}',
                          style: AppTextStyles.label.copyWith(fontSize: 13.sp),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          languageService.tr('tw_submitted'),
                          style: AppTextStyles.subheading.copyWith(
                            fontSize: 12.sp,
                          ),
                        ),
                        TradeWinStatusBadge(status: win.status),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              languageService.tr('tw_ledger_details'),
              style: AppTextStyles.headingblack,
            ),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppColors.icongrey.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < win.spentDetailsReadable.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: AppColors.icongrey.withValues(alpha: 0.15),
                      ),
                    _LedgerRow(
                      detail: win.spentDetailsReadable[i],
                      languageService: languageService,
                    ),
                  ],
                  if (win.spentDetailsReadable.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Text(
                        languageService.tr('tw_no_ledger'),
                        style: AppTextStyles.subheading,
                      ),
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

class _LedgerRow extends StatelessWidget {
  final TradeWinSpentDetailModel detail;
  final LanguageService languageService;

  const _LedgerRow({required this.detail, required this.languageService});

  @override
  Widget build(BuildContext context) {
    final lotsLabel = languageService.tr('tw_lots');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: '${languageService.tr('tw_from_account')} ',
                    style: AppTextStyles.subheading,
                    children: [
                      TextSpan(
                        text: detail.group,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '(${detail.symbol} ${languageService.tr('tw_trades')})',
                  style: AppTextStyles.subheading.copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ),
          Text(
            '-${TradeWinFormat.lots(detail.lots)} $lotsLabel',
            style: AppTextStyles.headingblack.copyWith(
              color: AppColors.error,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }
}
