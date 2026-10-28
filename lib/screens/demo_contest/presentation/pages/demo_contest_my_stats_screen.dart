import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/demo_contest_model.dart';
import 'package:crm_app/models/demo_contest/demo_contest_my_stats_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/contest_activity_card.dart';
import 'package:crm_app/services/demo_contest_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Mobile "My Contest Stats" screen matching the web design at /user/demo-contest/my-stats
class DemoContestMyStatsScreen extends StatefulWidget {
  final String contestId;
  const DemoContestMyStatsScreen({super.key, required this.contestId});

  @override
  State<DemoContestMyStatsScreen> createState() =>
      _DemoContestMyStatsScreenState();
}

class _DemoContestMyStatsScreenState extends State<DemoContestMyStatsScreen> {
  DemoContestMyStats? _stats;
  DemoContest? _contest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Ended contest, still qualified, and no claim submitted yet.
  bool get _canClaim {
    final contest = _contest;
    final participant = _stats?.participant;
    if (contest == null || participant == null) return false;
    return contest.hasEnded &&
        participant.id > 0 &&
        !participant.isDisqualified &&
        participant.claim == null;
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = DemoContestService.instance;
      final controller =
          Get.isRegistered<DemoContestController>()
              ? Get.find<DemoContestController>()
              : null;

      // 1. Resolve contest from cache or API
      DemoContest? contest = controller?.contestById(widget.contestId);
      if (contest == null) {
        final all = await service.fetchContests();
        if (controller != null) {
          controller.contests.assignAll(all);
        }
        contest = all.firstWhereOrNull((c) => c.id == widget.contestId) ??
            (all.isNotEmpty ? all.first : null);
      }

      // 2. Fetch my-stats
      final stats = await service.fetchMyStats(widget.contestId);

      if (!mounted) return;

      setState(() {
        _contest = contest;
        _stats = stats;
        if (_stats == null) {
          _error = TranslationUtils.tr('dc_could_not_load_stats');
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final isDark = AppColors.isDarkMode;
    final cardBg = isDark ? AppColors.card : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        title: Text(
          languageService.tr('more_demo_contest'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppSvgBackButton(onPressed: () => Get.back()),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CommonLoadingWidget(size: 50.0))
          : _error != null && _stats == null
              ? _buildError(isDark)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsetsDirectional.fromSTEB(16.w, 8.h, 16.w, 32.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Back to all contests breadcrumb
                        // InkWell(
                        //   onTap: () => Get.back(),
                        //   borderRadius: BorderRadius.circular(6.r),
                        //   child: Padding(
                        //     padding: EdgeInsets.symmetric(vertical: 6.h),
                        //     child: Row(
                        //       mainAxisSize: MainAxisSize.min,
                        //       children: [
                        //         Icon(
                        //           Icons.arrow_back,
                        //           size: 14.sp,
                        //           color: AppColors.textGrey,
                        //         ),
                        //         SizedBox(width: 6.w),
                        //         Text(
                        //           'Back to all contests',
                        //           style: AppTextStyles.bodyText.copyWith(
                        //             color: AppColors.textGrey,
                        //             fontSize: 12.sp,
                        //             fontWeight: FontWeight.w600,
                        //           ),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // ),
                        // SizedBox(height: 10.h),

                        // 1. Ranking Top Banner
                        _RankingBanner(
                          stats: _stats!,
                          isDark: isDark,
                        ),
                        SizedBox(height: 12.h),

                        // 2. Re-participation Banner
                        if (_contest != null && _contest!.canParticipateAgain) ...[
                          _ParticipateAgainBanner(
                            contest: _contest!,
                            cardBg: cardBg,
                            isDark: isDark,
                          ),
                          SizedBox(height: 12.h),
                        ],

                        // 3. Hero Contest Card
                        if (_contest != null) ...[
                          _HeroContestCard(
                            contest: _contest!,
                            stats: _stats!,
                            isDark: isDark,
                          ),
                          SizedBox(height: 14.h),
                        ],

                        // 4. 4-Stat Grid Cards
                        _StatsGrid(
                          stats: _stats!,
                          cardBg: cardBg,
                          isDark: isDark,
                        ),
                        SizedBox(height: 14.h),

                        if (_canClaim) ...[
                          ClaimPrizeCard(
                            contestId: widget.contestId,
                            cardBg: cardBg,
                            onClaimed: _loadStats,
                          ),
                          SizedBox(height: 14.h),
                        ],

                        ContestActivityCard(
                          contestId: widget.contestId,
                          cardBg: cardBg,
                        ),
                        SizedBox(height: 14.h),

                        // 5. Trading Rules Card
                        _TradingRulesCard(
                          contest: _contest,
                          cardBg: cardBg,
                          isDark: isDark,
                        ),
                        SizedBox(height: 14.h),

                        // 6. Prize Structure Card
                        _PrizeStructureCard(
                          contest: _contest,
                          contestId: widget.contestId,
                          cardBg: cardBg,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: AppColors.textGrey),
            SizedBox(height: 12.h),
            Text(
              _error ?? TranslationUtils.tr('general_something_went_wrong'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textGrey,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: _loadStats,
              child: Text(TranslationUtils.tr('edit_profile_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── 1. Ranking Banner ──────────────────────────

class _RankingBanner extends StatelessWidget {
  final DemoContestMyStats stats;
  final bool isDark;

  const _RankingBanner({
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.4);
    final borderColor = isDark
        ? AppColors.primary.withValues(alpha: 0.4)
        : AppColors.primary.withValues(alpha: 0.4);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(7.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: AppColors.primary,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${TranslationUtils.tr('dc_you_are_ranked')} #${stats.rank}',
                        style: AppTextStyles.bodyText.copyWith(
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _LivePill(isDark: isDark),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  TranslationUtils.tr('dc_keep_trading_tip'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textGrey,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final bool isDark;
  const _LivePill({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            TranslationUtils.tr('dc_live').toUpperCase(),
            style: TextStyle(
              color: const Color(0xFF16A34A),
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── 2. Re-Participation Banner ──────────────────────────

class _ParticipateAgainBanner extends StatelessWidget {
  final DemoContest contest;
  final Color cardBg;
  final bool isDark;

  const _ParticipateAgainBanner({
    required this.contest,
    required this.cardBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: const Color(0xFF4A0E4E),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationUtils.tr('dc_you_can_participate_again'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.h),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textGrey,
                      fontSize: 11.sp,
                    ),
                    children: [
                      TextSpan(text: '${TranslationUtils.tr('dc_youve_used')} '),
                      TextSpan(
                        text: '${contest.myEnrollmentsCount} of ${contest.maxParticipations}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                          text:
                              ' ${TranslationUtils.tr('dc_allowed_participations')} '),
                      TextSpan(
                        text: contest.enrollmentType == 'free'
                            ? TranslationUtils.tr('dc_free_re_entry')
                            : TranslationUtils.tr('dc_entry_fee_applies'),
                        style: TextStyle(
                          color: contest.enrollmentType == 'free'
                              ? const Color(0xFF16A34A)
                              : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton.icon(
            onPressed: () {
              Get.toNamed(AppPages.DEMO_CONTEST_JOIN, arguments: contest.id);
            },
            icon: Icon(Icons.add, size: 14.sp, color: Colors.white),
            label: Text(
              TranslationUtils.tr('dc_participate_again'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A0E4E),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── 3. Hero Contest Card ──────────────────────────

class _HeroContestCard extends StatelessWidget {
  final DemoContest contest;
  final DemoContestMyStats stats;
  final bool isDark;

  const _HeroContestCard({
    required this.contest,
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMMM yyyy');
    final dateRange =
        '${dateFmt.format(contest.startsAt)} - ${dateFmt.format(contest.endsAt)}';

    final totalParticipants =
        contest.pool?['total_participants']?.toString() ??
        '${contest.joinedParticipants}';
    final maxParticipants = contest.maxParticipants > 0
        ? '${contest.maxParticipants}'
        : '1000';
    final poolPrize = contest.pool?['total_prize_pool']?.toString() ?? '0.00';
    final filledPercent = (contest.filledPercent * 100).toStringAsFixed(0);

    final primary = AppColors.primary;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            Color.lerp(primary, Colors.white, 0.12)!,
            Color.lerp(primary, Colors.black, 0.12)!,
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges row
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 11.sp,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      dateRange,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Contest Title & Subtitle
          Text(
            contest.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (contest.subtitle.isNotEmpty || contest.description.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              contest.subtitle.isNotEmpty ? contest.subtitle : contest.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          SizedBox(height: 16.h),

          // Divider
          Divider(
            color: Colors.white.withValues(alpha: 0.18),
            height: 1,
          ),
          SizedBox(height: 12.h),

          // 3 Metric Columns
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  icon: Icons.people_outline,
                  label: TranslationUtils.tr('dc_participants').toUpperCase(),
                  value: '$totalParticipants / $maxParticipants',
                  sub: '$filledPercent% ${TranslationUtils.tr('dc_filled')}',
                ),
              ),
              Container(
                width: 1,
                height: 36.h,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.emoji_events_outlined,
                  label: TranslationUtils.tr('dc_prize_pool').toUpperCase(),
                  value: '\$$poolPrize',
                  sub: TranslationUtils.tr('dc_total_prize_pool'),
                ),
              ),
              Container(
                width: 1,
                height: 36.h,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.access_time_rounded,
                  label: TranslationUtils.tr('dc_days_left').toUpperCase(),
                  value: '${stats.daysLeft} ${TranslationUtils.tr('dc_days')}',
                  sub: TranslationUtils.tr('dc_to_go'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.sp, color: Colors.white.withValues(alpha: 0.8)),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 8.5.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 1.h),
        Text(
          sub,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 9.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── 4. 4-Stat Grid Cards ──────────────────────────

class _StatsGrid extends StatelessWidget {
  final DemoContestMyStats stats;
  final Color cardBg;
  final bool isDark;

  const _StatsGrid({
    required this.stats,
    required this.cardBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final p = stats.participant;
    final isProfit = p.returnPercent >= 0;
    final returnColor = isProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                cardBg: cardBg,
                iconBg: isDark ? const Color(0xFF2A1535) : const Color(0xFFFAF5FF),
                icon: Icons.military_tech_outlined,
                iconColor: const Color(0xFF7C3AED),
                label: TranslationUtils.tr('dc_your_rank'),
                value: '#${stats.rank}',
                valueColor: AppColors.textPrimary,
                subtext: TranslationUtils.tr('dc_current_standing'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _StatCard(
                cardBg: cardBg,
                iconBg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFDCFCE7),
                icon: isProfit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                iconColor: returnColor,
                label: TranslationUtils.tr('dc_your_return'),
                value: p.returnDisplay,
                valueColor: returnColor,
                subtext: TranslationUtils.tr('portfolio_performance'),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                cardBg: cardBg,
                iconBg: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                icon: Icons.account_balance_wallet_outlined,
                iconColor: isDark ? Colors.white70 : const Color(0xFF334155),
                label: TranslationUtils.tr('dc_your_equity'),
                value: '\$${_money(p.currentEquity)}',
                valueColor: AppColors.textPrimary,
                subtext: TranslationUtils.tr('dc_total_account_value'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _StatCard(
                cardBg: cardBg,
                iconBg: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEDE9FE),
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFF7C3AED),
                label: TranslationUtils.tr('dc_days_left'),
                value: '${stats.daysLeft}',
                valueColor: AppColors.textPrimary,
                subtext: TranslationUtils.tr('dc_remaining_time'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _money(double v) {
    final fmt = NumberFormat('#,##0.00');
    return fmt.format(v);
  }
}

class _StatCard extends StatelessWidget {
  final Color cardBg;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final String subtext;

  const _StatCard({
    required this.cardBg,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textGrey,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.bodyText.copyWith(
                    color: valueColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Text(
                  subtext,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textGrey.withValues(alpha: 0.8),
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── 5. Trading Rules Card ──────────────────────────

class _TradingRulesCard extends StatelessWidget {
  final DemoContest? contest;
  final Color cardBg;
  final bool isDark;

  const _TradingRulesCard({
    required this.contest,
    required this.cardBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final rules = contest?.rules ?? [];
    final fallbackRules = [
      (TranslationUtils.tr('dc_max_leverage'), contest?.tradingMaxLeverage.isNotEmpty == true ? contest!.tradingMaxLeverage : '1:200'),
      (TranslationUtils.tr('dc_min_trade_duration'), '3 ${TranslationUtils.tr('dc_minutes_short')}'),
      (TranslationUtils.tr('dc_max_open_positions'), '5'),
      (TranslationUtils.tr('dc_allowed_instruments'), TranslationUtils.tr('dc_all_instruments')),
      (TranslationUtils.tr('dc_max_lots_per_trade'), '10'),
      (TranslationUtils.tr('dc_timezone'), TranslationUtils.tr('dc_dubai_time')),
    ];

    final displayRules = rules.isNotEmpty
        ? rules.map((r) => (r.title, r.description)).toList()
        : fallbackRules;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationUtils.tr('dc_trading_rules'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      TranslationUtils.tr('dc_rules_apply_during_contest'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textGrey,
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Rules List
          for (var i = 0; i < displayRules.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Divider(
                  color: AppColors.icongrey.withValues(alpha: 0.1),
                  height: 1,
                ),
              ),
            Row(
              children: [
                Icon(
                  _ruleIcon(displayRules[i].$1),
                  size: 15.sp,
                  color: AppColors.textGrey,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    displayRules[i].$1,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textGrey,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  displayRules[i].$2,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _ruleIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('leverage')) return Icons.trending_up_rounded;
    if (t.contains('duration')) return Icons.timer_outlined;
    if (t.contains('position')) return Icons.layers_outlined;
    if (t.contains('instrument')) return Icons.format_list_bulleted_rounded;
    if (t.contains('lot')) return Icons.balance_outlined;
    if (t.contains('timezone')) return Icons.schedule_rounded;
    return Icons.check_circle_outline_rounded;
  }
}

// ────────────────────────── 6. Prize Structure Card ──────────────────────────

class _PrizeStructureCard extends StatelessWidget {
  final DemoContest? contest;
  final String contestId;
  final Color cardBg;
  final bool isDark;

  const _PrizeStructureCard({
    required this.contest,
    required this.contestId,
    required this.cardBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final prizes = contest?.prizes ?? [];

    final fallbackPrizes = [
      ContestPrize(label: TranslationUtils.tr('dc_first_place'), amount: 5000),
      ContestPrize(label: TranslationUtils.tr('dc_second_place'), amount: 2500),
      ContestPrize(label: TranslationUtils.tr('dc_third_place'), amount: 1000),
    ];

    final displayPrizes = prizes.isNotEmpty ? prizes : fallbackPrizes;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationUtils.tr('dc_prize_structure'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      TranslationUtils.tr('dc_rewards_for_top_traders'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textGrey,
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Prize List
          for (var i = 0; i < displayPrizes.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Divider(
                  color: AppColors.icongrey.withValues(alpha: 0.1),
                  height: 1,
                ),
              ),
            _PrizeItemRow(
              index: i + 1,
              label: displayPrizes[i].label.toLowerCase().contains('place')
                  ? displayPrizes[i].label
                  : '${displayPrizes[i].label} ${TranslationUtils.tr('dc_place')}',
              amount: displayPrizes[i].amount,
            ),
          ],
          SizedBox(height: 18.h),

          // View Full Leaderboard Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Get.toNamed(
                  AppPages.DEMO_CONTEST_LEADERBOARD,
                  arguments: contestId,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 13.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    TranslationUtils.tr('dc_view_full_leaderboard'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16.sp,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrizeItemRow extends StatelessWidget {
  final int index;
  final String label;
  final double amount;

  const _PrizeItemRow({
    required this.index,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            index < 10 ? '0$index' : '$index',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${fmt.format(amount)}',
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'CASH',
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textGrey,
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
