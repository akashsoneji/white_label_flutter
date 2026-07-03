import 'package:crm_app/bindings/demo_contest_binding.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/home/more/widgets/more_menu_widgets.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Top-level Demo Contest menu. Today it acts as a launcher for the
/// four pillars of the module — Rules, Join, Leaderboard, History —
/// and shows a "featured" contest highlight banner at the top.
class DemoContestScreen extends StatefulWidget {
  const DemoContestScreen({super.key});

  @override
  State<DemoContestScreen> createState() => _DemoContestScreenState();
}

class _DemoContestScreenState extends State<DemoContestScreen> {
  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<DemoContestController>()) {
      DemoContestBinding().dependencies();
    } else {
      // Always re-fetch on enter so the highlight reflects the latest.
      Get.find<DemoContestController>().refreshAll();
    }
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
          languageService.tr('more_demo_contest'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppSvgBackButton(onPressed: () => Get.back()),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.contests.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.featured.isNotEmpty)
                _FeaturedBanner(
                  featuredContest: controller.featured.first,
                  controller: controller,
                ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(text: languageService.tr('dc_explore')),
                    SizedBox(height: 10.h),
                    MoreMenuCardGroup(
                      children: [
                        MoreMenuTile(
                          iconAssetPath:
                              'assets/svg/more/demo_contest/contest-rules.svg',
                          label: languageService.tr('contest_rule'),
                          onTap: () =>
                              Get.toNamed(AppPages.DEMO_CONTEST_RULES),
                        ),
                        MoreMenuTile(
                          iconAssetPath:
                              'assets/svg/more/demo_contest/join-contest.svg',
                          label: languageService.tr('join_contest'),
                          onTap: () =>
                              Get.toNamed(AppPages.DEMO_CONTEST_JOIN),
                        ),
                        MoreMenuTile(
                          iconAssetPath:
                              'assets/svg/more/demo_contest/demo-leaderboard.svg',
                          label: languageService.tr('leaderboard'),
                          onTap: () =>
                              Get.toNamed(AppPages.DEMO_CONTEST_LEADERBOARD),
                        ),
                        MoreMenuTile(
                          iconAssetPath:
                              'assets/svg/more/demo_contest/my-contest-history.svg',
                          label: languageService.tr('my_contest_history'),
                          onTap: () =>
                              Get.toNamed(AppPages.DEMO_CONTEST_HISTORY),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),
                    _InfoBanner(languageService: languageService),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  final dynamic featuredContest;
  final DemoContestController controller;
  const _FeaturedBanner({required this.featuredContest, required this.controller});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final contest = featuredContest;
    return Padding(
      padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 4.h),
      child: Container(
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
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: BoxDecoration(
                          color: AppColors.whiteColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        languageService.tr('dc_featured'),
                        style: TextStyle(
                          color: AppColors.whiteColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    contest.subtitle ?? '',
                    style: TextStyle(
                      color: AppColors.whiteColor.withValues(alpha: 0.85),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              contest.bannerEmoji ?? '🏆',
              style: TextStyle(fontSize: 28.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              contest.title ?? '',
              style: TextStyle(
                color: AppColors.whiteColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              contest.description ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.whiteColor.withValues(alpha: 0.85),
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.toNamed(
                    AppPages.DEMO_CONTEST_DETAILS,
                    arguments: contest.id,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whiteColor,
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  controller.isJoined(contest.id)
                      ? languageService.tr('dc_view_entry')
                      : languageService.tr('dc_join_now'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textGrey.withValues(alpha: 0.85),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final LanguageService languageService;
  const _InfoBanner({required this.languageService});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'ℹ️',
              style: TextStyle(fontSize: 16.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageService.tr('dc_how_to_play'),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  languageService.tr('dc_how_to_play_desc'),
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.4,
                    color: AppColors.textPrimary,
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
