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
        if (controller.isLoading.value && controller.contests.isEmpty) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allContests = controller.contests;
        final myEnrollments = allContests.where((c) => c.isEnrolled).toList();
        final activeNow = allContests.where((c) => c.status == ContestStatus.active).length;
        final upcoming = allContests.where((c) => c.status == ContestStatus.upcoming).length;

        return RefreshIndicator(
          onRefresh: controller.refreshPull,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Column(
                    children: [
                      // Header Stats
                      Row(
                        children: [
                          Expanded(child: _StatCard(title: 'Contests Available', value: allContests.length.toString(), icon: Icons.emoji_events, iconColor: Colors.purple)),
                          SizedBox(width: 8.w),
                          Expanded(child: _StatCard(title: 'My Enrollments', value: myEnrollments.length.toString(), icon: Icons.person, iconColor: Colors.teal)),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(child: _StatCard(title: 'Active Now', value: activeNow.toString(), icon: Icons.bolt, iconColor: Colors.redAccent)),
                          SizedBox(width: 8.w),
                          Expanded(child: _StatCard(title: 'Upcoming', value: upcoming.toString(), icon: Icons.calendar_today, iconColor: Colors.blueAccent)),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      
                      // Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: false,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.r),
                            color: AppColors.primary,
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.textPrimary,
                          labelStyle: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600, fontSize: 13.sp),
                          tabs: [
                            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('All Contests'), SizedBox(width: 4.w), _Badge(allContests.length.toString())])),
                            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('My Enrollments'), SizedBox(width: 4.w), _Badge(myEnrollments.length.toString())])),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
              
              // Content
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
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

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10.r)),
      child: Text(text, style: TextStyle(fontSize: 10.sp, color: Colors.white)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({required this.title, required this.value, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
                Text(value, style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
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
      return Center(child: Text("No contests available.", style: AppTextStyles.bodyText));
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
    final dateFormat = DateFormat('d MMMM yyyy');
    final topPrize = contest.prizes.isNotEmpty ? contest.prizes.first.amount : 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 4))],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image/Gradient
          Container(
            height: 100.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              gradient: LinearGradient(colors: [Colors.purple.shade900, Colors.purple.shade500], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(Icons.workspace_premium, color: Colors.white, size: 40.sp),
                  ),
                ),
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(color: contest.status == ContestStatus.active ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(12.r)),
                    child: Text(contest.status.name.toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
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
                // Title and badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(contest.title, style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    ),
                    if (contest.isEnrolled)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                        child: Text('Enrolled (${contest.myEnrollmentsCount}/${contest.maxParticipations})', style: TextStyle(color: Colors.green, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(contest.subtitle, style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey)),
                SizedBox(height: 16.h),
                
                // Grid details
                Row(
                  children: [
                    Expanded(child: _InfoCell(label: 'STARTING BALANCE', value: '\$${contest.startingBalance.toStringAsFixed(2)}', icon: Icons.account_balance_wallet, iconColor: Colors.purple.shade100)),
                    Expanded(child: _InfoCell(label: 'MAX LEVERAGE', value: contest.tradingMaxLeverage.isNotEmpty ? contest.tradingMaxLeverage : '-', icon: Icons.bolt, iconColor: Colors.purple.shade100)),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(child: _InfoCell(label: 'WIN CRITERIA', value: 'Highest Return %', icon: Icons.emoji_events, iconColor: Colors.purple.shade100)),
                    Expanded(child: _InfoCell(label: 'ENTRY FEE', value: contest.enrollmentType == 'free' ? 'FREE' : '\$${contest.entryFee}', icon: Icons.card_giftcard, iconColor: Colors.green.shade100, valueColor: Colors.green)),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.purple, size: 16.sp),
                    SizedBox(width: 8.w),
                    Text('Top Prize ', style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey)),
                    Text('\$${topPrize.toStringAsFixed(2)}', style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                
                Divider(height: 24.h, color: Colors.grey.withOpacity(0.2)),
                
                // Dates
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('STARTS', style: TextStyle(fontSize: 10.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(dateFormat.format(contest.startsAt), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Icon(Icons.date_range, color: Colors.grey, size: 16.sp),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('ENDS', style: TextStyle(fontSize: 10.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(dateFormat.format(contest.endsAt), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Center(child: Text('Dubai Time (UTC+4)', style: TextStyle(fontSize: 10.sp, color: Colors.grey))),
                SizedBox(height: 16.h),
                
                // Button
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
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
                      backgroundColor: contest.isEnrolled ? AppColors.success : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(contest.isEnrolled ? Icons.dashboard : Icons.add_circle_outline, color: Colors.white, size: 18.sp),
                        SizedBox(width: 8.w),
                        Text(
                          contest.isEnrolled ? 'Go to Dashboard' : 'Join Now',
                          style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold),
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
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;

  const _InfoCell({required this.label, required this.value, required this.icon, required this.iconColor, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          child: Icon(icon, size: 14.sp, color: Colors.black54),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: valueColor ?? AppColors.textPrimary)),
          ],
        )
      ],
    );
  }
}
