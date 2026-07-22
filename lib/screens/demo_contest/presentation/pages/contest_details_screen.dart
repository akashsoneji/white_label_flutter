import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/contest_countdown_timer.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Detail page for a single contest. Shows hero info, prize pool,
/// contest rules, requirements and a prominent "Join" / "View Entry"
/// action.
///
/// Route arg: a String contestId (passed from Join Contest, the Demo
/// Contest home, etc.).
class ContestDetailsScreen extends StatefulWidget {
  final String contestId;
  const ContestDetailsScreen({super.key, required this.contestId});

  @override
  State<ContestDetailsScreen> createState() => _ContestDetailsScreenState();
}

class _ContestDetailsScreenState extends State<ContestDetailsScreen> {
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    // If the user already accepted terms for this contest we should
    // reflect that. Read from controller if available.
    final controller = Get.isRegistered<DemoContestController>()
        ? Get.find<DemoContestController>()
        : null;
    if (controller != null && controller.isJoined(widget.contestId)) {
      setState(() => _acceptedTerms = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final controller = Get.find<DemoContestController>();

    return Obx(() {
      final contest = controller.contestById(widget.contestId);
      if (contest == null) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            leading: AppSvgBackButton(onPressed: () => Get.back()),
            title: Text(
              languageService.tr('dc_details_title'),
              style: AppTextStyles.screenTitle,
            ),
            centerTitle: true,
          ),
          body: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w),
              child: Text(
                languageService.tr('dc_contest_not_found'),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.textGrey,
                ),
              ),
            ),
          ),
        );
      }

      final joined = controller.isJoined(contest.id);
      final myEntry = controller.entryFor(contest.id);
      final live = contest.isLive;
      final upcoming = !contest.hasStarted;
      final ended = contest.hasEnded;

      final statusColor = ended
          ? AppColors.textGrey
          : live
              ? AppColors.success
              : AppColors.warning;
      final statusLabel = ended
          ? 'ENDED'
          : live
              ? '● LIVE'
              : 'UPCOMING';

      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          scrolledUnderElevation: 0.0,
          backgroundColor: AppColors.backgroundLight,
          elevation: 0,
          title: Text(
            languageService.tr('dc_details_title'),
            style: AppTextStyles.screenTitle,
          ),
          leading: AppSvgBackButton(onPressed: () => Get.back()),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCard(
                      contest: contest,
                      statusColor: statusColor,
                      statusLabel: statusLabel,
                    ),
                    SizedBox(height: 18.h),
                    if (joined && myEntry != null) ...[
                      _MyEntryCard(myEntry: myEntry, contest: contest),
                      SizedBox(height: 18.h),
                    ],
                    _SectionTitle(text: languageService.tr('dc_prize_pool')),
                    SizedBox(height: 8.h),
                    _PrizeList(contest: contest),
                    SizedBox(height: 18.h),
                    _SectionTitle(
                      text: languageService.tr('dc_contest_rules'),
                    ),
                    SizedBox(height: 8.h),
                    _RulesList(contest: contest),
                    SizedBox(height: 18.h),
                    _SectionTitle(
                      text: languageService.tr('dc_requirements'),
                    ),
                    SizedBox(height: 8.h),
                    _RequirementsList(contest: contest),
                    SizedBox(height: 22.h),
                  ],
                ),
              ),
            ),
            if (!ended)
              Container(
                padding: EdgeInsets.fromLTRB(
                  20.w,
                  10.h,
                  20.w,
                  20.h + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.border.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (!joined)
                      Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _acceptedTerms,
                          onChanged: (v) =>
                              setState(() => _acceptedTerms = v ?? false),
                          activeColor: AppColors.primary,
                          title: Text(
                            languageService.tr('dc_accept_terms'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: joined
                            ? () {
                                Get.toNamed(
                                  AppPages.DEMO_CONTEST_LEADERBOARD,
                                  arguments: contest.id,
                                );
                              }
                            : () => _handleJoin(controller, contest),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:  AppColors.primary,
                          // backgroundColor: joined
                          //     ? AppColors.success
                          //     : AppColors.primary,
                          foregroundColor: AppColors.whiteColor,
                          disabledBackgroundColor: AppColors.icongrey
                              .withValues(alpha: 0.3),
                          disabledForegroundColor:
                              AppColors.whiteColor.withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 0,
                        ),
                        child: Obx(() {
                          final isJoining = controller.isJoining.value;
                          if (isJoining) {
                            return SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: CircularProgressIndicator(
                                color: AppColors.whiteColor,
                                strokeWidth: 2,
                              ),
                            );
                          }
                          return Text(
                            joined
                                ? languageService.tr('dc_view_leaderboard')
                                : upcoming
                                    ? languageService.tr('dc_register_now')
                                    : languageService.tr('dc_join_now'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _handleJoin(
    DemoContestController controller,
    contest,
  ) async {
    if (!_acceptedTerms) {
      CustomToastService.showError(
        message: 'Please accept the contest terms first.',
      );
      return;
    }
    final entry = await controller.joinContest(contest.id);
    if (entry != null) {
      CustomToastService.showSuccess(message: 'Successfully joined!');
      Get.toNamed(
        AppPages.DEMO_CONTEST_DETAILS,
        arguments: contest.id,
      );
    } else if (controller.errorMessage.value.isNotEmpty) {
      CustomToastService.showError(
        message: controller.errorMessage.value,
      );
    }
  }
}

class _HeroCard extends StatelessWidget {
  final dynamic contest;
  final Color statusColor;
  final String statusLabel;
  const _HeroCard({
    required this.contest,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.95),
            AppColors.primary.withValues(alpha: 0.6),
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
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.whiteColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  contest.subtitle,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.whiteColor.withValues(alpha: 0.85),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contest.bannerEmoji,
                style: AppTextStyles.bodyText.copyWith(fontSize: 32.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  contest.title,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.whiteColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            contest.description,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.whiteColor.withValues(alpha: 0.85),
              fontSize: 12.sp,
              height: 1.45,
            ),
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.whiteColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatBlock(
                    label: languageService.tr('dc_prize_pool').toUpperCase(),
                    value:
                        '\$${(contest.prizes.fold<double>(0.0, (double a, dynamic b) => a + (b.amount as double))).toStringAsFixed(0)}',
                    color: AppColors.whiteColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28.h,
                  color: AppColors.whiteColor.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _StatBlock(
                    label: languageService.tr('dc_start_balance').toUpperCase(),
                    value: '\$${(contest.startingBalance as double).toStringAsFixed(0)}',
                    color: AppColors.whiteColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28.h,
                  color: AppColors.whiteColor.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _StatBlock(
                    label: languageService.tr('dc_ends_in').toUpperCase(),
                    value: contest.hasEnded
                        ? '—'
                        : (contest.isLive
                            ? languageService.tr('dc_live').toUpperCase()
                            : languageService
                                .tr('dc_starts_in')
                                .toUpperCase()),
                    color: AppColors.whiteColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          if (!contest.hasEnded)
            Center(
              child: ContestCountdownTimer(
                endsAt: contest.isLive ? contest.endsAt : contest.startsAt,
                textStyle: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.whiteColor,
                ),
                accentColor: AppColors.whiteColor,
              ),
            ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Icons.people_alt_outlined,
                size: 16.sp,
                color: AppColors.whiteColor.withValues(alpha: 0.9),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  '${contest.joinedParticipants} / ${contest.maxParticipants} ${languageService.tr('dc_participants_joined')}',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.whiteColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              minHeight: 6.h,
              backgroundColor:
                  AppColors.whiteColor.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
              value: (contest.joinedParticipants.toDouble() /
                      contest.maxParticipants.toDouble())
                  .clamp(0.0, 1.0),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: color.withValues(alpha: 0.75),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MyEntryCard extends StatelessWidget {
  final dynamic myEntry;
  final dynamic contest;
  const _MyEntryCard({required this.myEntry, required this.contest});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final pnlColor = myEntry.pnl >= 0 ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Text(
                languageService.tr('dc_your_entry'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _SmallStat(
                  label: languageService.tr('dc_pnl'),
                  value:
                      '${myEntry.pnlPercent >= 0 ? '+' : ''}${myEntry.pnlPercent.toStringAsFixed(2)}%',
                  color: pnlColor,
                ),
              ),
              Expanded(
                child: _SmallStat(
                  label: languageService.tr('dc_equity'),
                  value: '\$${(myEntry.equity as double).toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _SmallStat(
                  label: languageService.tr('dc_rank'),
                  value: '#${myEntry.rank}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SmallStat({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textGrey,
          ),
        ),
        SizedBox(height: 4.h),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.textGrey.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _PrizeList extends StatelessWidget {
  final dynamic contest;
  const _PrizeList({required this.contest});

  @override
  Widget build(BuildContext context) {
    final prizes = (contest.prizes as List);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.icongrey.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: List.generate(prizes.length, (i) {
          final prize = prizes[i];
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: i == prizes.length - 1
                      ? Colors.transparent
                      : AppColors.border.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '🏅',
                    style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prize.label,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (prize.extra != null && prize.extra.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          prize.extra,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '\$${prize.amount.toStringAsFixed(0)}',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _RulesList extends StatelessWidget {
  final dynamic contest;
  const _RulesList({required this.contest});

  @override
  Widget build(BuildContext context) {
    final rules = (contest.rules as List);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.icongrey.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: List.generate(rules.length, (i) {
          final rule = rules[i];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 4.h),
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.title,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        rule.description,
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
          );
        }),
      ),
    );
  }
}

class _RequirementsList extends StatelessWidget {
  final dynamic contest;
  const _RequirementsList({required this.contest});

  @override
  Widget build(BuildContext context) {
    final requirements = (contest.requirements as List);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(requirements.length, (i) {
          final req = requirements[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i == requirements.length - 1 ? 0 : 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16.sp,
                  color: AppColors.warning,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    req,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}