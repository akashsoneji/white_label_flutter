import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/demo_contest/demo_contest_model.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/contest_countdown_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Compact card for a contest that the user can / should join.
///
/// Used in the Join Contest screen list, and inside the Demo Contest
/// home menu as a "featured" highlight.
class ContestJoinCard extends StatelessWidget {
  final DemoContest contest;
  final bool joined;
  final VoidCallback onTap;

  const ContestJoinCard({
    super.key,
    required this.contest,
    required this.onTap,
    this.joined = false,
  });

  @override
  Widget build(BuildContext context) {
    final live = contest.isLive;
    final ended = contest.hasEnded;

    final tagColor = ended
        ? AppColors.textGrey
        : live
            ? AppColors.success
            : AppColors.warning;

    final tagLabel = ended
        ? 'ENDED'
        : live
            ? '● LIVE NOW'
            : 'UPCOMING';

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
              color: AppColors.icongrey.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.border.withValues(alpha: 0.04),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      contest.bannerEmoji,
                      style: TextStyle(fontSize: 26.sp),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: tagColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                tagLabel,
                                style: TextStyle(
                                  color: tagColor,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(
                                contest.subtitle,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          contest.title,
                          style: AppTextStyles.black16600,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.attach_money,
                      label: '\$${(contest.prizes.isNotEmpty ? contest.prizes.first.amount : 0).toStringAsFixed(0)}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 26.h,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _Metric(
                      icon: Icons.people_alt_outlined,
                      label: '${(contest.joinedParticipants / 1000).toStringAsFixed(1)}k',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 26.h,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _Metric(
                      icon: Icons.bar_chart,
                      label: '\$${_formatK(contest.startingBalance)}',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16.sp,
                    color: AppColors.textGrey,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    ended
                        ? 'Ended · ${_formatDate(contest.endsAt)}'
                        : live
                            ? 'Ends in'
                            : 'Starts in',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  if (!ended)
                    ContestCountdownTimer(
                      endsAt: live ? contest.endsAt : contest.startsAt,
                      compact: true,
                    ),
                ],
              ),
              SizedBox(height: 14.h),
              SizedBox(
                width: double.infinity,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    // backgroundColor: joined ? AppColors.success : AppColors.primary,
                    foregroundColor: AppColors.whiteColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    joined
                        ? 'View Entry'
                        : ended
                            ? 'View Results'
                            : 'View Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatK(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
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

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Metric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18.sp, color: AppColors.primary),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
