import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/demo_contest/demo_contest_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Big, eye-catching promo card shown at the top of the Join Contest
/// screen. Uses gradient + emoji so it doesn't depend on image assets
/// being provided.
class ContestPromoCard extends StatelessWidget {
  final DemoContest contest;
  final VoidCallback onTap;

  const ContestPromoCard({
    super.key,
    required this.contest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final live = contest.isLive;
    final upcoming = !contest.hasStarted;

    final tagColor = live
        ? AppColors.success
        : upcoming
            ? AppColors.warning
            : AppColors.textGrey;
    final tagLabel = live
        ? '● ${TranslationUtils.tr('dc_live')}'
        : upcoming
            ? TranslationUtils.tr('dc_tab_upcoming').toUpperCase()
            : TranslationUtils.tr('dc_status_ended').toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.95),
                AppColors.primary.withValues(alpha: 0.65),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(18.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: BoxDecoration(
                      color: AppColors.whiteColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      contest.bannerEmoji,
                      style: AppTextStyles.bodyText.copyWith(fontSize: 30.sp),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: tagColor,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                tagLabel,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: AppColors.whiteColor,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              contest.subtitle,
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.whiteColor.withValues(
                                  alpha: 0.85,
                                ),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          contest.title,
                          style: AppTextStyles.black16600.copyWith(
                            color: AppColors.whiteColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.only(left: 2.w),
                child: Text(
                  contest.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.whiteColor.withValues(alpha: 0.85),
                    fontSize: 12.sp,
                    height: 1.45,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  _StatPill(
                    emoji: '👥',
                    label: '${contest.joinedParticipants}/${contest.maxParticipants}',
                  ),
                  SizedBox(width: 8.w),
                  _StatPill(
                    emoji: '💰',
                    label: '\$${(contest.prizes.isNotEmpty ? contest.prizes.first.amount : 0).toStringAsFixed(0)} ${TranslationUtils.tr('dc_prize_suffix')}',
                  ),
                  SizedBox(width: 8.w),
                  _StatPill(
                    emoji: '📈',
                    label: '\$${_formatK(contest.startingBalance)} ${TranslationUtils.tr('dc_start_suffix')}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatK(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;
  const _StatPill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp)),
          SizedBox(width: 4.w),
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.whiteColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
