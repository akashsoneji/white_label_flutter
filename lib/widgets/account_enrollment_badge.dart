import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Small pill on an account card telling whether the account is used by
/// PAMM, copy trading or a demo contest. Tap or long-press shows the reason.
/// Renders nothing when the account has no enrollment flag.
class AccountEnrollmentBadge extends StatelessWidget {
  const AccountEnrollmentBadge({super.key, required this.account});

  final MT5Account account;

  @override
  Widget build(BuildContext context) {
    final badge = account.enrollmentBadge;
    if (badge == null) return const SizedBox.shrink();

    final (labelKey, tooltipKey) = switch (badge) {
      AccountEnrollmentKind.pmamPool => (
        'account_badge_pmam_pool',
        'account_badge_pmam_pool_tooltip',
      ),
      AccountEnrollmentKind.pmamInvestor => (
        'account_badge_pmam_investor',
        'account_badge_pmam_investor_tooltip',
      ),
      AccountEnrollmentKind.copyMaster => (
        'account_badge_copy_master',
        'account_badge_copy_master_tooltip',
      ),
      AccountEnrollmentKind.copySlave => (
        'account_badge_copy_follower',
        'account_badge_copy_follower_tooltip',
      ),
      AccountEnrollmentKind.demoContest => (
        'account_badge_demo_contest',
        'account_badge_demo_contest_tooltip',
      ),
    };
    final label = badge == AccountEnrollmentKind.demoContest
        ? TranslationUtils.trArgs(labelKey, {'name': account.demoContestName})
        : TranslationUtils.tr(labelKey);

    return Tooltip(
      message: TranslationUtils.tr(tooltipKey),
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
