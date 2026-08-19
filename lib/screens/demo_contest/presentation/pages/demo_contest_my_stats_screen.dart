import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/demo_contest_my_stats_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Mobile-friendly "My Contest Stats" screen.
///
/// Mirrors the web design at /user/demo-contest/my-stats but laid out
/// vertically for small screens:
///   • Ranking banner ("You are ranked #-") with LIVE pill
///   • Contest card (status, dates, title, description)
///   • 4-stat row (Rank / Return / Equity / Days Left)
///   • Prize Structure card (1st / 2nd / 3rd)
///   • Contest Rules card
///   • CTA: "View Full Leaderboard"
///
/// Reads `participant` from the local DemoContestService mock today —
/// once the backend endpoint is wired it can be swapped for the same
/// shape via `fetchMyStats(contestId)`.
class DemoContestMyStatsScreen extends StatefulWidget {
  final String contestId;
  const DemoContestMyStatsScreen({super.key, required this.contestId});

  @override
  State<DemoContestMyStatsScreen> createState() =>
      _DemoContestMyStatsScreenState();
}

class _DemoContestMyStatsScreenState extends State<DemoContestMyStatsScreen> {
  DemoContestMyStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = Get.isRegistered<DemoContestController>()
          ? Get.find<DemoContestController>()
          : null;
      final contest = controller?.contestById(widget.contestId);

      if (contest == null) {
        setState(() {
          _loading = false;
          _error = 'Contest not found';
        });
        return;
      }

      final c = Get.isRegistered<DemoContestController>()
          ? Get.find<DemoContestController>()
          : null;
      final fetched = c != null ? await c.fetchMyStats(widget.contestId) : null;
      setState(() {
        _stats = fetched;
        _loading = false;
      });
    } catch (e) {
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
    final controller = Get.find<DemoContestController>();
    final contest = controller.contestById(widget.contestId);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.backgroundLight,
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
          : _error != null
              ? _buildError(isDark)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 32.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RankingBanner(
                          stats: _stats!,
                          contest: contest,
                          languageService: languageService,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                          child: _ContestCard(
                            stats: _stats!,
                            contest: contest,
                            languageService: languageService,
                            cardBg: cardBg,
                            isDark: isDark,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                          child: _StatsRow(
                            stats: _stats!,
                            languageService: languageService,
                            cardBg: cardBg,
                            isDark: isDark,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PrizeStructureCard(
                                languageService: languageService,
                                cardBg: cardBg,
                                isDark: isDark,
                              ),
                              SizedBox(height: 16.h),
                              _ContestRulesCard(
                                languageService: languageService,
                                cardBg: cardBg,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                          child: _LeaderboardCta(
                            onTap: () => Get.toNamed(
                              AppPages.DEMO_CONTEST_LEADERBOARD,
                              arguments: widget.contestId,
                            ),
                            languageService: languageService,
                          ),
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
            Icon(
              Icons.error_outline,
              size: 48.sp,
              color: AppColors.textGrey,
            ),
            SizedBox(height: 12.h),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textGrey,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Ranking Banner ──────────────────────────

class _RankingBanner extends StatelessWidget {
  final DemoContestMyStats stats;
  final dynamic contest;
  final LanguageService languageService;

  const _RankingBanner({
    required this.stats,
    required this.contest,
    required this.languageService,
  });

  @override
  Widget build(BuildContext context) {
    final rank = stats.rank;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 18.w, 22.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LivePill(languageService: languageService),
              const Spacer(),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'You are ranked $rank',
            style: AppTextStyles.bodyText.copyWith(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Keep trading and maintain proper risk management to secure or improve your position!',
            style: AppTextStyles.bodyText.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final LanguageService languageService;
  const _LivePill({required this.languageService});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
          SizedBox(width: 5.w),
          Text(
            'LIVE',
            style: AppTextStyles.bodyText.copyWith(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Contest Card ──────────────────────────

class _ContestCard extends StatelessWidget {
  final DemoContestMyStats stats;
  final dynamic contest;
  final LanguageService languageService;
  final Color cardBg;
  final bool isDark;

  const _ContestCard({
    required this.stats,
    required this.contest,
    required this.languageService,
    required this.cardBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMMM yyyy');
    final startsAt = contest?.startsAt as DateTime?;
    final endsAt = contest?.endsAt as DateTime?;
    final dateRange = (startsAt != null && endsAt != null)
        ? '${dateFmt.format(startsAt)} — ${dateFmt.format(endsAt)}'
        : '3 August 2026 — 31 August 2026';

    final title = contest?.title?.toString() ?? 'Contest One';
    final description = contest?.description?.toString() ??
        'Complete contest and win prizes';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.icongrey.withValues(alpha: 0.14),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(label: 'ACTIVE', isDark: isDark),
              const Spacer(),
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('🏆', style: TextStyle(fontSize: 18.sp)),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            dateRange,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textGrey,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title.toLowerCase().contains('contest')
                ? title
                : 'contest ${title.toLowerCase()}',
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            description,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textGrey,
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool isDark;
  const _StatusBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.primary,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ────────────────────────── Stats Row ──────────────────────────

class _StatsRow extends StatelessWidget {
  final DemoContestMyStats stats;
  final LanguageService languageService;
  final Color cardBg;
  final bool isDark;

  const _StatsRow({
    required this.stats,
    required this.languageService,
    required this.cardBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final p = stats.participant;
    final returnColor =
        p.returnPercent >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.icongrey.withValues(alpha: 0.14),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      child: Column(
        children: [
          Row(
            children: [
              _StatItem(
                label: 'YOUR RANK',
                value: '#${stats.rank}',
                color: AppColors.textPrimary,
              ),
              _Divider(isDark: isDark),
              _StatItem(
                label: 'YOUR RETURN',
                value: p.returnDisplay,
                color: returnColor,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Divider(color: AppColors.icongrey.withValues(alpha: 0.18), height: 1),
          ),
          Row(
            children: [
              _StatItem(
                label: 'YOUR EQUITY',
                value: '\$${_money(p.currentEquity)}',
                color: AppColors.textPrimary,
              ),
              _Divider(isDark: isDark),
              _StatItem(
                label: 'DAYS LEFT',
                value: '${stats.daysLeft}',
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _money(double v) {
    final fmt = NumberFormat('#,##0.00');
    return fmt.format(v);
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textGrey,
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              color: color,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28.h,
      color: AppColors.icongrey.withValues(alpha: 0.18),
      margin: EdgeInsets.symmetric(horizontal: 4.w),
    );
  }
}

// ────────────────────────── Prize Structure Card ──────────────────────────

class _PrizeStructureCard extends StatelessWidget {
  final LanguageService languageService;
  final Color cardBg;
  final bool isDark;

  const _PrizeStructureCard({
    required this.languageService,
    required this.cardBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final contestObj = Get.find<DemoContestController>().contestById(Get.arguments?.toString() ?? '');

    return _PanelCard(
      cardBg: cardBg,
      isDark: isDark,
      iconBg: const Color(0xFFFFEDD5),
      iconEmoji: '🏆',
      iconColor: const Color(0xFFEA580C),
      title: 'Prize Structure',
      subtitle: 'Rewards for top-performing traders',
      children: [
        if (contestObj != null && contestObj.prizes.isNotEmpty)
          ...contestObj.prizes.map((prize) => Column(
            children: [
              _PrizeRow(medal: '🏅', rank: prize.label, amount: '\$${prize.amount.toStringAsFixed(2)}'),
              SizedBox(height: 8.h),
            ],
          ))
        else
          const Text('No prizes available.'),
      ],
    );
  }
}

class _PrizeRow extends StatelessWidget {
  final String medal;
  final String rank;
  final String amount;
  const _PrizeRow({
    required this.medal,
    required this.rank,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(medal, style: TextStyle(fontSize: 16.sp)),
        SizedBox(width: 6.w),
        Text(
          '$rank:',
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            '$amount CASH',
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── Contest Rules Card ──────────────────────────

class _ContestRulesCard extends StatelessWidget {
  final LanguageService languageService;
  final Color cardBg;
  final bool isDark;

  const _ContestRulesCard({
    required this.languageService,
    required this.cardBg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final contestObj = Get.find<DemoContestController>().contestById(Get.arguments?.toString() ?? '');
    
    final rules = [
      if (contestObj != null) ...contestObj.rules.map((r) => (r.title, r.description))
    ];

    if (rules.isEmpty) {
      rules.addAll([
        ('Min Trade Duration', '3 minutes — scalping not allowed'),
        ('Max Leverage', '1:200 capped'),
        ('Max Concurrent Positions', 'Capped at 5 positions'),
        ('Max Lots Per Trade', 'Capped at 10 lots'),
        ('Allowed Instruments', 'All Instruments'),
      ]);
    }

    return _PanelCard(
      cardBg: cardBg,
      isDark: isDark,
      iconBg: AppColors.primary.withValues(alpha: 0.12),
      iconEmoji: '🛡️',
      iconColor: AppColors.primary,
      title: 'Contest Rules',
      subtitle: 'Rules that apply during the contest period',
      children: [
        for (var i = 0; i < rules.length; i++) ...[
          if (i > 0) SizedBox(height: 8.h),
          _RuleRow(
            index: i + 1,
            label: rules[i].$1,
            value: rules[i].$2,
          ),
        ],
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  final int index;
  final String label;
  final String value;
  const _RuleRow({
    required this.index,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16.w,
          height: 16.w,
          margin: EdgeInsets.only(top: 1.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.primary,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 1.h),
              Text(
                value,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textGrey,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── Panel Card shell ──────────────────────────

class _PanelCard extends StatelessWidget {
  final Color cardBg;
  final bool isDark;
  final Color iconBg;
  final String iconEmoji;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _PanelCard({
    required this.cardBg,
    required this.isDark,
    required this.iconBg,
    required this.iconEmoji,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.icongrey.withValues(alpha: 0.14),
        ),
      ),
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  iconEmoji,
                  style: TextStyle(fontSize: 14.sp, color: iconColor),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textGrey,
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
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
          ...children,
        ],
      ),
    );
  }
}

// ────────────────────────── Leaderboard CTA ──────────────────────────

class _LeaderboardCta extends StatelessWidget {
  final VoidCallback onTap;
  final LanguageService languageService;
  const _LeaderboardCta({
    required this.onTap,
    required this.languageService,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View Full Leaderboard',
              style: AppTextStyles.bodyText.copyWith(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.arrow_forward, size: 16.sp, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
