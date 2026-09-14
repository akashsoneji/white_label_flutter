import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/demo_contest_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/widgets/contest_join_card.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Browse + register for active and upcoming contests.
///
/// Tabs separate "Live" from "Upcoming" so the user can quickly find
/// what they can join right now vs. what is opening soon.
class JoinContestScreen extends StatefulWidget {
  const JoinContestScreen({super.key});

  @override
  State<JoinContestScreen> createState() => _JoinContestScreenState();
}

class _JoinContestScreenState extends State<JoinContestScreen>
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
          languageService.tr('join_contest'),
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
            Tab(text: languageService.tr('dc_tab_live')),
            Tab(text: languageService.tr('dc_tab_upcoming')),
            Tab(text: languageService.tr('dc_tab_all')),
          ],
        ),
      ),
      body: Obx(() {
        final contests = controller.contests;
        if (controller.isLoading.value && contests.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final live = contests
            .where((c) => c.isLive && c.acceptingEntries)
            .toList();
        final upcoming = contests
            .where((c) => !c.hasStarted && c.acceptingEntries)
            .toList();
        final all = contests.toList();

        return TabBarView(
          controller: _tabController,
          children: [
            _ContestList(
              contests: live,
              emptyTitle: languageService.tr('dc_empty_live_title'),
              emptyDesc: languageService.tr('dc_empty_live_desc'),
              controller: controller,
            ),
            _ContestList(
              contests: upcoming,
              emptyTitle: languageService.tr('dc_empty_upcoming_title'),
              emptyDesc: languageService.tr('dc_empty_upcoming_desc'),
              controller: controller,
            ),
            _ContestList(
              contests: all,
              emptyTitle: languageService.tr('dc_empty_all_title'),
              emptyDesc: languageService.tr('dc_empty_all_desc'),
              controller: controller,
            ),
          ],
        );
      }),
    );
  }
}

class _ContestList extends StatelessWidget {
  final List<DemoContest> contests;
  final String emptyTitle;
  final String emptyDesc;
  final DemoContestController controller;

  const _ContestList({
    required this.contests,
    required this.emptyTitle,
    required this.emptyDesc,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (contests.isEmpty) {
      return _EmptyState(title: emptyTitle, desc: emptyDesc);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refreshPull,
      child: ListView.separated(
        padding: EdgeInsetsDirectional.fromSTEB(16.w, 16.h, 16.w, 32.h),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: contests.length,
        separatorBuilder: (_, __) => SizedBox(height: 14.h),
        itemBuilder: (context, i) {
          final c = contests[i];
          return ContestJoinCard(
            contest: c,
            joined: controller.isJoined(c.id),
            onTap: () {
              if (controller.isJoined(c.id)) {
                Get.toNamed(
                  AppPages.DEMO_CONTEST_DETAILS,
                  arguments: c.id,
                );
              } else if (!c.acceptingEntries) {
                CustomToastService.showInfo(
                  message: TranslationUtils.tr('dc_contest_has_ended'),
                );
              } else {
                Get.toNamed(
                  AppPages.DEMO_CONTEST_DETAILS,
                  arguments: c.id,
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String desc;
  const _EmptyState({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎯', style: AppTextStyles.bodyText.copyWith(fontSize: 60.sp)),
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