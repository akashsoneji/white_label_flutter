import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/demo_contest/leaderboard_entry_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Visual podium for top-3 of a leaderboard.
///
/// Layout order from left → right: 2nd, 1st, 3rd (centre taller).
class LeaderboardPodium extends StatelessWidget {
  final List<LeaderboardEntry> topThree;

  const LeaderboardPodium({super.key, required this.topThree});

  @override
  Widget build(BuildContext context) {
    if (topThree.length < 1) return const SizedBox.shrink();

    // Pad to 3 entries with empty placeholders so the layout stays stable.
    final entries = List<LeaderboardEntry?>.from([
      topThree.length > 1 ? topThree[1] : null,
      topThree.isNotEmpty ? topThree[0] : null,
      topThree.length > 2 ? topThree[2] : null,
    ]);

    final heights = [0.6, 0.85, 0.5];
    final colors = [
      const Color(0xFFE0E0E0),
      const Color(0xFFFFD54F),
      const Color(0xFFB87333),
    ];
    final medalEmojis = ['🥈', '🥇', '🥉'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) {
          final entry = entries[i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: _PodiumColumn(
                entry: entry,
                medal: medalEmojis[i],
                heightFactor: heights[i],
                accentColor: colors[i],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final LeaderboardEntry? entry;
  final String medal;
  final double heightFactor;
  final Color accentColor;

  const _PodiumColumn({
    required this.entry,
    required this.medal,
    required this.heightFactor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasEntry = entry != null;
    final name = entry?.displayName.replaceAll(
          RegExp(r'^[\u{1F1E6}-\u{1F1FF}]{2}\s*', unicode: true),
          '',
        ) ??
        '—';
    final pnlColor = (entry?.pnl ?? 0) >= 0 ? AppColors.success : AppColors.error;
    final pnlText = hasEntry
        ? '${entry!.pnlPercent >= 0 ? '+' : ''}${entry!.pnlPercent.toStringAsFixed(1)}%'
        : '—';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: AppTextStyles.bodyText.copyWith(fontSize: 22.sp)),
        SizedBox(height: 4.h),
        Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: hasEntry ? 0.25 : 0.1),
            border: Border.all(
              color: hasEntry ? accentColor : AppColors.border,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            hasEntry ? name.substring(0, name.length.clamp(0, 1)).toUpperCase() : '·',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: hasEntry ? AppColors.textPrimary : AppColors.textGrey,
            ),
          ),
        ),
        SizedBox(height: 6.h),
        SizedBox(
          width: double.infinity,
          child: Text(
            hasEntry ? name : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          pnlText,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: pnlColor,
          ),
        ),
        SizedBox(height: 8.h),
        // The actual podium block below.
        FractionallySizedBox(
          heightFactor: heightFactor.clamp(0.0, 1.0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accentColor.withValues(alpha: 0.95),
                  accentColor.withValues(alpha: 0.65),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
            ),
            alignment: Alignment.topCenter,
            padding: EdgeInsets.only(top: 12.h),
            child: Text(
              '${entry?.rank ?? 0}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.whiteColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
