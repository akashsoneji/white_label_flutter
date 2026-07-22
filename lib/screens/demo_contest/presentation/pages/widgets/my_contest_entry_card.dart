import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/demo_contest/my_contest_entry_model.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/contest_countdown_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Card used on the "My Contest History" screen.
class MyContestEntryCard extends StatelessWidget {
  final MyContestEntry entry;
  final VoidCallback onTap;
  final String Function(String) translate;

  const MyContestEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.translate,
  });

  @override
  Widget build(BuildContext context) {
    final pnlColor = entry.pnl >= 0 ? AppColors.success : AppColors.error;
    final isLive = entry.isLive;
    final isWinner = entry.isWinner;
    final isFinished = entry.status.name == 'finished';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isWinner
                  ? AppColors.warning
                  : AppColors.icongrey.withValues(alpha: 0.18),
              width: isWinner ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.border.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(16.w),
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
                      color: _badgeColor(entry.status.name).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      translate('dc_status_${entry.statusKey()}').toUpperCase(),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _badgeColor(entry.status.name),
                      ),
                    ),
                  ),
                  Spacer(),
                  if (isWinner)
                    Text(
                      '🏆 #${entry.rank}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                entry.contestTitle,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                entry.contestSubtitle,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.textGrey,
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      label: translate('dc_pnl'),
                      value: '${entry.pnlPercent >= 0 ? '+' : ''}${entry.pnlPercent.toStringAsFixed(2)}%',
                      color: pnlColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32.h,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _StatBlock(
                      label: translate('dc_equity'),
                      value: '\$${entry.equity.toStringAsFixed(0)}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32.h,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _StatBlock(
                      label: translate('dc_rank'),
                      value: '#${entry.rank}',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tradeBackgroundCenterColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLive
                          ? Icons.timer_outlined
                          : isFinished
                              ? Icons.flag_outlined
                              : Icons.event_outlined,
                      size: 14.sp,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        isLive
                            ? '${translate('dc_ends_in')}:'
                            : isFinished
                                ? translate('dc_finished_on')
                                : '${translate('dc_starts_in')}:',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isLive)
                      ContestCountdownTimer(
                        endsAt: entry.endsAt,
                        compact: true,
                      )
                    else if (!isFinished)
                      ContestCountdownTimer(
                        endsAt: entry.endsAt,
                        compact: true,
                      )
                    else
                      Text(
                        _formatDate(entry.endsAt),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              if (entry.hasWithdrawableReward) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        size: 18.sp,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Reward available: \$${entry.prizeAmount?.toStringAsFixed(0) ?? '0'}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      Text(
                        translate('dc_claim'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _badgeColor(String status) {
    switch (status) {
      case 'running':
        return AppColors.success;
      case 'registered':
        return AppColors.primary;
      case 'finished':
        return AppColors.textGrey;
      case 'winner':
        return AppColors.warning;
      default:
        return AppColors.textGrey;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day} ${_monthName(d.month)} ${d.year}';
  }

  String _monthName(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[m - 1];
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatBlock({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textGrey,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
