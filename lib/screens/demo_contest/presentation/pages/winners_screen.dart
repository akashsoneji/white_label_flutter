import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/contest_winner_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Hall-of-fame style winners showcase. Lists the top winners of every
/// past contest so traders can see what the prize pool looked like in
/// previous rounds.
class WinnersScreen extends StatelessWidget {
  final String? contestIdArg;
  const WinnersScreen({super.key, this.contestIdArg});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final controller = Get.find<DemoContestController>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: Text(
          languageService.tr('dc_winners_title'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppSvgBackButton(onPressed: () => Get.back()),
        centerTitle: true,
      ),
      body: Obx(() {
        final winners = controller.winners;
        if (controller.isLoading.value && winners.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        // Group winners by contest.
        final grouped = <String, List<ContestWinner>>{};
        for (final w in winners) {
          grouped.putIfAbsent(w.contestId, () => []).add(w);
        }
        final contestIds = grouped.keys.toList();

        return ListView(
          padding: EdgeInsetsDirectional.fromSTEB(16.w, 12.h, 16.w, 32.h),
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.r),
                gradient: LinearGradient(
                  colors: [
                    AppColors.warning.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0.10),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Text('🏆', style: AppTextStyles.bodyText.copyWith(fontSize: 30.sp)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageService.tr('dc_hall_of_fame'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          languageService.tr('dc_hall_of_fame_desc'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            ...contestIds.map((cid) {
              final group = grouped[cid]!;
              final title = group.first.contestTitle;
              return Padding(
                padding: EdgeInsets.only(bottom: 18.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.icongrey.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(14.w, 14.h, 14.w, 8.h),
                        child: Row(
                          children: [
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.warning.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '🏅',
                                style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                title,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...group.map((w) => _WinnerRow(winner: w)),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }),
    );
  }
}

class _WinnerRow extends StatelessWidget {
  final ContestWinner winner;
  const _WinnerRow({required this.winner});

  @override
  Widget build(BuildContext context) {
    final pnlColor = winner.pnlPercent >= 0 ? AppColors.success : AppColors.error;
    final medal = winner.rank <= 3 ? ['🥇', '🥈', '🥉'][winner.rank - 1] : null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28.w,
            child: Center(
              child: medal != null
                  ? Text(medal, style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp))
                  : Text(
                      '#${winner.rank}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              winner.displayName,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '+${winner.pnlPercent.toStringAsFixed(1)}%',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: pnlColor,
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            '\$${winner.prizeAmount.toStringAsFixed(0)}',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}