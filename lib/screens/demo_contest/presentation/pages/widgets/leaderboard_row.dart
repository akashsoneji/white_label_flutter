import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/demo_contest/leaderboard_entry_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Row of a leaderboard entry. The first three ranks get coloured
/// medals; the rest get a subtle grey chip. The current user's row
/// is highlighted regardless of rank.
class LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int? highlightRank;
  final VoidCallback? onTap;

  const LeaderboardRow({
    super.key,
    required this.entry,
    this.highlightRank,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = entry.isCurrentUser ||
        (highlightRank != null && entry.rank == highlightRank);
    final medal = _medalFor(entry.rank);
    final pnlColor = entry.pnl >= 0 ? AppColors.success : AppColors.error;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.07)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Row(
            children: [
              SizedBox(
                width: 36.w,
                child: Center(
                  child: medal ??
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${entry.rank}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.displayName,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'YOU',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 9.sp,
                                color: AppColors.whiteColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(
                          '🏅 ${entry.tradesCount} ${TranslationUtils.tr('tw_trades')}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '· ${(entry.winRate * 100).toStringAsFixed(0)}% ${TranslationUtils.tr('dc_win_rate_short')}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${entry.pnlPercent >= 0 ? '+' : ''}${entry.pnlPercent.toStringAsFixed(2)}%',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: pnlColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '\$${entry.pnl.toStringAsFixed(0)}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _medalFor(int rank) {
    if (rank == 1) {
      return _Medal(emoji: '🥇', color: const Color(0xFFFFD54F));
    }
    if (rank == 2) {
      return _Medal(emoji: '🥈', color: const Color(0xFFE0E0E0));
    }
    if (rank == 3) {
      return _Medal(emoji: '🥉', color: const Color(0xFFB87333));
    }
    return null;
  }
}

class _Medal extends StatelessWidget {
  final String emoji;
  final Color color;
  const _Medal({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.25),
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp)),
    );
  }
}
