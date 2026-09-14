import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/contest_winner_model.dart';
import 'package:crm_app/models/demo_contest/my_contest_entry_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/my_contest_entry_card.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// "My Contest History" screen — shows the user's active + past
/// contest entries grouped by status.
class MyContestHistoryScreen extends StatefulWidget {
  const MyContestHistoryScreen({super.key});

  @override
  State<MyContestHistoryScreen> createState() => _MyContestHistoryScreenState();
}

class _MyContestHistoryScreenState extends State<MyContestHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          languageService.tr('my_contest_history'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppSvgBackButton(onPressed: () => Get.back()),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.bodyText.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13.sp,
          ),
          tabs: [
            Tab(text: languageService.tr('dc_history_active')),
            Tab(text: languageService.tr('dc_history_completed')),
            Tab(text: languageService.tr('dc_history_winners')),
          ],
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.myEntries.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final entries = controller.myEntries;
        final active = entries.where((e) => e.isLive).toList();
        final completed =
            entries.where((e) => !e.isLive && !e.isWinner).toList();
        final winners = entries.where((e) => e.isWinner).toList();

        return TabBarView(
          controller: _tabController,
          children: [
            _HistoryList(
              entries: active,
              emptyTitle: languageService.tr('dc_history_empty_active'),
              emptyDesc: languageService.tr('dc_history_empty_active_desc'),
              languageService: languageService,
              onTap: (e) {
                Get.toNamed(
                  AppPages.DEMO_CONTEST_DETAILS,
                  arguments: e.contestId,
                );
              },
            ),
            _HistoryList(
              entries: completed,
              emptyTitle: languageService.tr('dc_history_empty_completed'),
              emptyDesc: languageService.tr('dc_history_empty_completed_desc'),
              languageService: languageService,
              onTap: (e) {
                Get.toNamed(
                  AppPages.DEMO_CONTEST_LEADERBOARD,
                  arguments: e.contestId,
                );
              },
            ),
            _WinnersTab(
              winners: winners,
              pastWinners: controller.winners,
              languageService: languageService,
              onTap: (e) {
                Get.toNamed(
                  AppPages.DEMO_CONTEST_WINNERS,
                  arguments: e.contestId,
                );
              },
            ),
          ],
        );
      }),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<MyContestEntry> entries;
  final String emptyTitle;
  final String emptyDesc;
  final LanguageService languageService;
  final ValueChanged<MyContestEntry> onTap;

  const _HistoryList({
    required this.entries,
    required this.emptyTitle,
    required this.emptyDesc,
    required this.languageService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyHistory(title: emptyTitle, desc: emptyDesc);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          Get.find<DemoContestController>().refreshPull(),
      child: ListView.separated(
        padding: EdgeInsetsDirectional.fromSTEB(16.w, 16.h, 16.w, 32.h),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => SizedBox(height: 14.h),
        itemBuilder: (context, i) {
          final e = entries[i];
          return MyContestEntryCard(
            entry: e,
            translate: languageService.tr,
            onTap: () => onTap(e),
          );
        },
      ),
    );
  }
}

class _WinnersTab extends StatelessWidget {
  final List<MyContestEntry> winners;
  final List<ContestWinner> pastWinners;
  final LanguageService languageService;
  final ValueChanged<MyContestEntry> onTap;
  const _WinnersTab({
    required this.winners,
    required this.pastWinners,
    required this.languageService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (winners.isEmpty && pastWinners.isEmpty) {
      return _EmptyHistory(
        title: languageService.tr('dc_history_empty_winners'),
        desc: languageService.tr('dc_history_empty_winners_desc'),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => Get.find<DemoContestController>().refreshPull(),
      child: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(16.w, 16.h, 16.w, 32.h),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (winners.isNotEmpty) ...[
            Padding(
              padding: EdgeInsetsDirectional.only(start: 4.w, bottom: 10.h),
              child: Text(
                languageService.tr('dc_your_wins'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ...winners.map(
              (e) => Padding(
                padding: EdgeInsets.only(bottom: 14.h),
                child: MyContestEntryCard(
                  entry: e,
                  translate: languageService.tr,
                  onTap: () => onTap(e),
                ),
              ),
            ),
            SizedBox(height: 10.h),
          ],
          if (pastWinners.isNotEmpty) ...[
            Padding(
              padding: EdgeInsetsDirectional.only(start: 4.w, bottom: 10.h),
              child: Text(
                languageService.tr('dc_recent_winners'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ...pastWinners.take(15).map((w) => _WinnerTile(winner: w)),
          ],
        ],
      ),
    );
  }
}

class _WinnerTile extends StatelessWidget {
  final dynamic winner;
  const _WinnerTile({required this.winner});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '#${winner.rank}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winner.displayName,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  winner.contestTitle,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.textGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${winner.prizeAmount.toStringAsFixed(0)}',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
              Text(
                '+${winner.pnlPercent.toStringAsFixed(1)}%',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final String title;
  final String desc;
  const _EmptyHistory({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📭', style: AppTextStyles.bodyText.copyWith(fontSize: 60.sp)),
            SizedBox(height: 14.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                color: AppColors.textGrey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}