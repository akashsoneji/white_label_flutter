import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/demo_contest_model.dart';
import 'package:crm_app/models/demo_contest/leaderboard_entry_model.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/leaderboard_podium.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/leaderboard_row.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/pill_tab_bar.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Leaderboard screen.
///
/// If a contest id is passed via `Get.arguments` it shows that
/// contest's leaderboard; otherwise it lets the user pick from
/// contests they have joined (or the current live one by default).
class LeaderboardScreen extends StatefulWidget {
  final String? contestIdArg;
  const LeaderboardScreen({super.key, this.contestIdArg});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late String _selectedContestId;
  int _selectedRange = 0;
  bool _initialized = false;

  static const _ranges = ['Today', 'Weekly', 'Monthly', 'All-time'];

  @override
  void initState() {
    super.initState();
    final controller = Get.find<DemoContestController>();
    final passed = widget.contestIdArg;
    if (passed != null && passed.isNotEmpty) {
      _selectedContestId = passed;
    } else {
      // Pick first live contest by default; otherwise the first
      // featured one; otherwise just the first one.
      final live = controller.contests.where((c) => c.isLive).toList();
      final featured = controller.featured;
      if (live.isNotEmpty) {
        _selectedContestId = live.first.id;
      } else if (featured.isNotEmpty) {
        _selectedContestId = featured.first.id;
      } else if (controller.contests.isNotEmpty) {
        _selectedContestId = controller.contests.first.id;
      } else {
        _selectedContestId = '';
      }
    }
    if (_selectedContestId.isNotEmpty) {
      controller.loadLeaderboard(_selectedContestId);
    }
    _initialized = true;
  }

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
          languageService.tr('leaderboard'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppSvgBackButton(onPressed: () => Get.back()),
        centerTitle: true,
      ),
      body: Obx(() {
        if (!_initialized) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (controller.contests.isEmpty) {
          return Center(
            child: Text(
              languageService.tr('dc_empty_all_desc'),
              style: TextStyle(color: AppColors.textGrey, fontSize: 14.sp),
            ),
          );
        }

        final selectedContest =
            controller.contestById(_selectedContestId) ??
                controller.contests.first;

        final entries =
            controller.leaderboards[selectedContest.id] ?? <LeaderboardEntry>[];
        final myEntry = controller.entryFor(selectedContest.id);

        return Column(
          children: [
            _ContestPicker(
              contests: controller.contests,
              selectedId: selectedContest.id,
              onSelect: (id) {
                setState(() => _selectedContestId = id);
                controller.loadLeaderboard(id);
              },
            ),
            _SelectedContestHeader(contest: selectedContest),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: PillTabBar(
                labels: _ranges
                    .map(
                      (r) => r == 'Today'
                          ? languageService.tr('dc_range_today')
                          : r == 'Weekly'
                              ? languageService.tr('dc_range_weekly')
                              : r == 'Monthly'
                                  ? languageService.tr('dc_range_monthly')
                                  : languageService.tr('dc_range_all_time'),
                    )
                    .toList(),
                selectedIndex: _selectedRange,
                onTap: (i) {
                  setState(() => _selectedRange = i);
                  controller.refreshLeaderboard(selectedContest.id);
                },
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () =>
                    controller.refreshLeaderboard(selectedContest.id),
                child: _LeaderboardBody(
                  isLoading: controller.isLoadingLeaderboard.value,
                  entries: entries,
                  myEntry: myEntry,
                  hasContest: selectedContest.acceptingEntries ||
                      selectedContest.isLive,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ContestPicker extends StatelessWidget {
  final List<DemoContest> contests;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _ContestPicker({
    required this.contests,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: contests.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, i) {
          final c = contests[i];
          final selected = c.id == selectedId;
          return InkWell(
            onTap: () => onSelect(c.id),
            borderRadius: BorderRadius.circular(12.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Text(c.bannerEmoji, style: TextStyle(fontSize: 14.sp)),
                  SizedBox(width: 6.w),
                  Text(
                    c.title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedContestHeader extends StatelessWidget {
  final DemoContest contest;
  const _SelectedContestHeader({required this.contest});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final live = contest.isLive;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.95),
              AppColors.primary.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Row(
          children: [
            Text(contest.bannerEmoji, style: TextStyle(fontSize: 26.sp)),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contest.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.whiteColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${contest.joinedParticipants} ${languageService.tr('dc_traders_competing')}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.whiteColor.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: live ? AppColors.success : AppColors.warning,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                live ? '● LIVE' : 'UPCOMING',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.whiteColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  final bool isLoading;
  final List<LeaderboardEntry> entries;
  final dynamic myEntry;
  final bool hasContest;

  const _LeaderboardBody({
    required this.isLoading,
    required this.entries,
    required this.myEntry,
    required this.hasContest,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && entries.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (entries.isEmpty) {
      return _EmptyLeaderboard();
    }

    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 32.h),
      children: [
        LeaderboardPodium(topThree: top3),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.icongrey.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            children: [
              if (myEntry != null && myEntry.rank > 3)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_pin_circle_outlined,
                        size: 18.sp,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Your rank',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '#${myEntry.rank}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ...rest.map(
                (e) => LeaderboardRow(
                  entry: e,
                  highlightRank: myEntry?.rank,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 60.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏁', style: TextStyle(fontSize: 60.sp)),
              SizedBox(height: 14.h),
              Text(
                languageService.tr('dc_no_leaderboard_yet'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                languageService.tr('dc_no_leaderboard_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}