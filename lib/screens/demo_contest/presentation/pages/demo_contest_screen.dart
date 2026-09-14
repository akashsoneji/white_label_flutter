import 'package:crm_app/bindings/demo_contest_binding.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/demo_contest_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class DemoContestScreen extends StatefulWidget {
  const DemoContestScreen({super.key});

  @override
  State<DemoContestScreen> createState() => _DemoContestScreenState();
}

class _DemoContestScreenState extends State<DemoContestScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (!Get.isRegistered<DemoContestController>()) {
      DemoContestBinding().dependencies();
    } else {
      Get.find<DemoContestController>().refreshAll();
    }
  }

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
          languageService.tr('more_demo_contest'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppSvgBackButton(onPressed: () => Get.back()),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.errorMessage.isNotEmpty && controller.contests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(controller.errorMessage.value, style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        if (controller.isLoading.value && controller.contests.isEmpty) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allContests = controller.contests;
        final myEnrollments = allContests.where((c) => c.isEnrolled).toList();

        return RefreshIndicator(
          onRefresh: controller.refreshPull,
          color: AppColors.primary,
          child: Column(
            children: [
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    _PillTab(
                      title: languageService.tr('dc_all_contests'),
                      count: allContests.length,
                      isSelected: _tabController.index == 0,
                      onTap: () => setState(() => _tabController.animateTo(0)),
                    ),
                    SizedBox(width: 8.w),
                    _PillTab(
                      title: languageService.tr('dc_my_enrollments'),
                      count: myEnrollments.length,
                      isSelected: _tabController.index == 1,
                      onTap: () => setState(() => _tabController.animateTo(1)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(), // handle scrolling inside
                  children: [
                    _ContestList(contests: allContests, languageService: languageService),
                    _ContestList(contests: myEnrollments, languageService: languageService),
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

class _PillTab extends StatelessWidget {
  final String title;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _PillTab({required this.title, required this.count, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.card : Colors.white),
          borderRadius: BorderRadius.circular(8.r),
          border: isSelected ? null : Border.all(color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: AppTextStyles.bodyText.copyWith(
                color: isSelected ? (isDark ? AppColors.pureBlack : Colors.white) : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContestList extends StatelessWidget {
  final List<DemoContest> contests;
  final LanguageService languageService;

  const _ContestList({required this.contests, required this.languageService});

  @override
  Widget build(BuildContext context) {
    if (contests.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(child: Text(languageService.tr('dc_no_contests_available'), style: AppTextStyles.bodyText)),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: contests.length,
      itemBuilder: (context, index) {
        final contest = contests[index];
        return _ContestCard(contest: contest, languageService: languageService);
      },
    );
  }
}

class _ContestCard extends StatelessWidget {
  final DemoContest contest;
  final LanguageService languageService;

  const _ContestCard({required this.contest, required this.languageService});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final cardBg = isDark ? AppColors.card : Colors.white;
    final dateFormat = DateFormat('d MMMM yyyy');
    final topPrize = contest.prizes.isNotEmpty ? contest.prizes.first.amount : 0.0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: isDark ? Border.all(color: Colors.white12) : null,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Gradient
          Container(
            height: 90.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              gradient: const LinearGradient(
                colors: [Color(0xFF6A2A85), Color(0xFFB570D0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(contest.bannerEmoji, style: TextStyle(fontSize: 22.sp))),
                  ),
                ),
                PositionedDirectional(
                  top: 16.h,
                  end: 16.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: contest.status == ContestStatus.active ? const Color(0xFF10B981) : Colors.orange,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4.w,
                          height: 4.w,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          contest.status.name.toUpperCase(),
                          style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        contest.title,
                        style: AppTextStyles.bodyText.copyWith(fontSize: 20.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (contest.isEnrolled)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: const Color(0xFF2E7D32), size: 12.sp),
                            SizedBox(width: 4.w),
                            Text(
                              '${languageService.tr('dc_enrolled')} (${contest.myEnrollmentsCount}/${contest.maxParticipations})',
                              style: TextStyle(color: const Color(0xFF2E7D32), fontSize: 10.sp, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  contest.subtitle,
                  style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey),
                ),
                SizedBox(height: 16.h),
                
                // Outlined Info Box
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _InfoCell(label: languageService.tr('dc_starting_balance_caps'), value: '\$${contest.startingBalance.toStringAsFixed(0)}', iconData: Icons.account_balance_wallet, iconBg: const Color(0xFFF3E5F5), iconColor: const Color(0xFF7B1FA2))),
                          Expanded(child: _InfoCell(label: languageService.tr('dc_max_leverage_caps'), value: contest.tradingMaxLeverage.isNotEmpty ? contest.tradingMaxLeverage : '-', iconData: Icons.bolt, iconBg: const Color(0xFFF3E5F5), iconColor: const Color(0xFF7B1FA2))),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(child: _InfoCell(label: languageService.tr('dc_win_criteria'), value: contest.rankingBy.isNotEmpty ? contest.rankingBy.replaceAll('_', ' ') : languageService.tr('dc_highest_return_percent'), iconData: Icons.emoji_events, iconBg: const Color(0xFFF3E5F5), iconColor: const Color(0xFF7B1FA2))),
                          Expanded(child: _InfoCell(label: languageService.tr('dc_entry_fee'), value: contest.enrollmentType == 'free' ? languageService.tr('dc_free').toUpperCase() : '\$${contest.entryFee}', iconData: Icons.card_giftcard, iconBg: const Color(0xFFE8F5E9), iconColor: const Color(0xFF2E7D32), valueColor: const Color(0xFF10B981))),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: const BoxDecoration(color: Color(0xFFF3E5F5), shape: BoxShape.circle),
                            child: Icon(Icons.emoji_events, color: const Color(0xFF7B1FA2), size: 14.sp),
                          ),
                          SizedBox(width: 10.w),
                          Text('${languageService.tr('dc_top_prize')} ', style: TextStyle(fontSize: 11.sp, color: AppColors.textPrimary)),
                          Text('\$${topPrize.toStringAsFixed(0)}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                
                // Dates
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(languageService.tr('dc_starts').toUpperCase(), style: TextStyle(fontSize: 10.sp, color: AppColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        SizedBox(height: 4.h),
                        Text(dateFormat.format(contest.startsAt), style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade300, indent: 8.w, endIndent: 8.w)),
                          Icon(Icons.calendar_month, color: isDark ? Colors.white60 : Colors.grey.shade600, size: 16.sp),
                          Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade300, indent: 8.w, endIndent: 8.w)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(languageService.tr('dc_ends').toUpperCase(), style: TextStyle(fontSize: 10.sp, color: AppColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        SizedBox(height: 4.h),
                        Text(dateFormat.format(contest.endsAt), style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language, size: 14.sp, color: isDark ? Colors.white60 : Colors.grey.shade600),
                      SizedBox(width: 4.w),
                      Text(languageService.tr('dc_dubai_time'), style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                
                // Button
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      if (contest.isEnrolled) {
                        Get.toNamed(AppPages.DEMO_CONTEST_MY_STATS, arguments: contest.id);
                      } else {
                        // In real app, this should join or go to join screen
                        Get.find<DemoContestController>().joinContest(contest.id).then((_) {
                           Get.toNamed(AppPages.DEMO_CONTEST_MY_STATS, arguments: contest.id);
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(contest.isEnrolled ? Icons.show_chart : Icons.arrow_forward, color: isDark ? AppColors.pureBlack : Colors.white, size: 18.sp),
                        SizedBox(width: 8.w),
                        Text(
                          contest.isEnrolled
                              ? languageService.tr('dc_view_dashboard')
                              : (contest.maxParticipations > 1
                                  ? '${languageService.tr('dc_participate_now')} (${contest.myEnrollmentsCount}/${contest.maxParticipations})'
                                  : languageService.tr('dc_participate_now')),
                          style: TextStyle(color: isDark ? AppColors.pureBlack : Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                        ),
                        if (contest.isEnrolled)
                          Padding(
                            padding: EdgeInsetsDirectional.only(start: 4.w),
                            child: Icon(Icons.arrow_forward, color: isDark ? AppColors.pureBlack : Colors.white, size: 16.sp),
                          ),
                      ],
                    ),
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

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData iconData;
  final Color iconBg;
  final Color iconColor;
  final Color? valueColor;

  const _InfoCell({
    required this.label,
    required this.value,
    required this.iconData,
    required this.iconBg,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(iconData, size: 14.sp, color: iconColor),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 8.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w600, height: 1.2),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: valueColor ?? AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
      ],
    );
  }
}
