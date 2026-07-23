import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_dashboard_controller.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_hub_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/home/more/copytrading/copy_trading_create_plan_screen.dart';
import 'package:crm_app/screens/home/more/copytrading/master_plan_detail_screen.dart';
import 'package:crm_app/screens/home/more/copytrading/copy_trading_edit_plan_screen.dart';

class MyPlansTab extends StatefulWidget {
  const MyPlansTab({super.key});

  @override
  State<MyPlansTab> createState() => _MyPlansTabState();
}

class _MyPlansTabState extends State<MyPlansTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'Newest first';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreatePlanScreen(CopyTradingMasterDashboardController controller) {
    Get.to(
      () => CopyTradingCreatePlanScreen(controller: controller),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }

  List<CopyTradingMasterPlanItem> _getFilteredAndSortedPlans(
    List<CopyTradingMasterPlanItem> plans,
  ) {
    try {
      List<CopyTradingMasterPlanItem> result = List.from(plans);

      if (_searchQuery.isNotEmpty) {
        result =
            result.where((plan) {
              final nameMatch = plan.planName.toLowerCase().contains(
                _searchQuery,
              );
              final idMatch = plan.id.toString().contains(_searchQuery);
              final accountMatch = plan.tradingAccountNumber.contains(
                _searchQuery,
              );
              return nameMatch || idMatch || accountMatch;
            }).toList();
      }

      if (_sortBy == 'Newest first') {
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else if (_sortBy == 'Name A-Z') {
        result.sort(
          (a, b) =>
              a.planName.toLowerCase().compareTo(b.planName.toLowerCase()),
        );
      } else if (_sortBy == 'Highest AUM') {
        result.sort((a, b) => b.totalCapital.compareTo(a.totalCapital));
      }

      return result;
    } catch (e, stack) {
      debugPrint('MyPlansTab: Error in _getFilteredAndSortedPlans: $e\n$stack');
      return plans;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hubController = Get.find<CopyTradingHubController>();
    final controller = Get.put(
      CopyTradingMasterDashboardController(
        masterCode: hubController.masterCode.value,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAllNamed(AppPages.TRADING),
        ),
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'My Copy Plans',
          style: AppTextStyles.screenTitle.copyWith(fontSize: 16.sp),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 14.w),
            child: GestureDetector(
              onTap: () => _openCreatePlanScreen(controller),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 15.sp,
                      color: AppColors.isDarkMode ? AppColors.whiteColorDark : AppColors.whiteColorLight,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Create Plan',
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.isDarkMode ? AppColors.whiteColorDark : AppColors.whiteColorLight ,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Search & Sort bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44.h,
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.border.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search plan name, ID...',
                          hintStyle: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18.r,
                            color: AppColors.textGrey,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    height: 44.h,
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    decoration: BoxDecoration(
                      color: AppColors.whiteColor,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.border.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18.r,
                          color: AppColors.textGrey,
                        ),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _sortBy = newValue;
                            });
                          }
                        },
                        items:
                            <String>[
                              'Newest first',
                              'Name A-Z',
                              'Highest AUM',
                            ].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Obx(() {
                final loading = controller.isLoading.value;
                final allPlans = controller.plans;

                if (loading && allPlans.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2.5,
                        ),
                        SizedBox(height: 14.h),
                        Text(
                          'Loading plans...',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                Widget listChild;

                if (allPlans.isEmpty) {
                  final err = controller.errorMessage.value;
                  if (err.isNotEmpty) {
                    listChild = ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 80.h),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64.r,
                                  height: 64.r,
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.error_outline_rounded,
                                    size: 32.r,
                                    color: AppColors.error,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  err,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 14.sp,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                ElevatedButton.icon(
                                  onPressed:
                                      () => controller.refreshAll(
                                        showLoading: true,
                                      ),
                                  icon: Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                  ),
                                  label: Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor:
                                        AppColors.onColoredBackground,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 10.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    listChild = ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 50.h),
                        _buildEmptyState(controller),
                      ],
                    );
                  }
                } else {
                  final filteredSortedPlans = _getFilteredAndSortedPlans(
                    allPlans,
                  );

                  if (filteredSortedPlans.isEmpty) {
                    listChild = ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 80.h),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40.r,
                                color: AppColors.textGrey.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'No plans match your search',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 14.sp,
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    listChild = ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
                      itemCount: filteredSortedPlans.length,
                      separatorBuilder: (_, index) => SizedBox(height: 14.h),
                      itemBuilder: (context, index) {
                        final plan = filteredSortedPlans[index];
                        return _PlanCardItem(
                          plan: plan,
                          controller: controller,
                        );
                      },
                    );
                  }
                }

                return RefreshIndicator(
                  onRefresh: () => controller.refreshAll(showLoading: false),
                  color: AppColors.primary,
                  child: listChild,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(CopyTradingMasterDashboardController controller) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 38.r,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'No Copy Plans Yet',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Create a copying plan to start sharing\nyour trades with investors.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                color: AppColors.textGrey,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () => _openCreatePlanScreen(controller),
              icon: Icon(Icons.add_rounded, size: 18),
              label: Text('Create First Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onColoredBackground,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                textStyle: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCardItem extends StatelessWidget {
  final CopyTradingMasterPlanItem plan;
  final CopyTradingMasterDashboardController controller;

  const _PlanCardItem({required this.plan, required this.controller});

  // ── Status helpers ───────────────────────────────────────────────────────

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'active':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'pending_admin':
      case 'pending_review':
        return 'Pending Review';
      case 'inactive':
        return 'Inactive';
      case 'rejected':
        return 'Rejected';
      default:
        return s.toUpperCase();
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'active':
        return AppColors.successBg;
      case 'pending':
      case 'pending_admin':
      case 'pending_review':
        return AppColors.warningBg;
      case 'inactive':
      case 'rejected':
        return AppColors.errorBg;
      default:
        return AppColors.chipSurface;
    }
  }

  Color _statusFg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'active':
        return AppColors.successText;
      case 'pending':
      case 'pending_admin':
      case 'pending_review':
        return AppColors.warningText;
      case 'inactive':
      case 'rejected':
        return AppColors.errorText;
      default:
        return AppColors.textGrey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'active':
        return Icons.check_circle_rounded;
      case 'pending':
      case 'pending_admin':
      case 'pending_review':
        return Icons.hourglass_top_rounded;
      case 'inactive':
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  bool get _isApproved {
    final s = plan.status.toLowerCase();
    return s == 'approved' || s == 'active';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = plan.status;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Gradient Header ──────────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.80),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                // Plan icon
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.planName.isEmpty ? 'Unnamed Plan' : plan.planName,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.whiteColor,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(width: 6.h),
                      Row(
                        children: [
                          Text(
                            plan.tradingAccountNumber,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.whiteColor,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Plan ID chip
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    // color: AppColors.cardBackGround.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    '#${plan.id}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.whiteColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Status Row ───────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(status),
                        size: 11.r,
                        color: _statusFg(status),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _statusLabel(status),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: _statusFg(status),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                // Copying state (only if approved)
                if (_isApproved) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          plan.copyingPaused
                              ? AppColors.error.withValues(alpha: 0.08)
                              : AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.r,
                          height: 6.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                plan.copyingPaused
                                    ? AppColors.error
                                    : AppColors.green,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          plan.copyingPaused
                              ? 'Copying Paused'
                              : 'Copying Active',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                plan.copyingPaused
                                    ? AppColors.error
                                    : AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // isFull badge
                if (plan.isFull)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'FULL',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.12),
            ),
          ),

          // ── Metrics Grid ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 4.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.people_alt_outlined,
                        label: 'Copiers',
                        value:
                            plan.maxCopiers != null
                                ? '${plan.activeCopiersCount} / ${plan.maxCopiers}'
                                : '${plan.activeCopiersCount}',
                        iconColor: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.account_balance_outlined,
                        label: 'Total AUM',
                        value: '\$${plan.totalCapital.toStringAsFixed(2)}',
                        iconColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.payments_outlined,
                        label: 'Commission',
                        value:
                            plan.commissionLabel.isNotEmpty
                                ? plan.commissionLabel
                                : '—',
                        iconColor: AppColors.warningText,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.savings_outlined,
                        label: 'Min. Capital',
                        value: '\$${plan.minimumCapital.toStringAsFixed(2)}',
                        iconColor: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Action Row ───────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            child: Row(
              children: [
                // View Details
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Get.to(() => MasterPlanDetailScreen(planId: plan.id));
                    },
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 14.r,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'View Details',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 8.h,
                      ),
                    ),
                  ),
                ),

                // Edit Plan
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Get.to(
                        () => CopyTradingEditPlanScreen(
                          plan: plan,
                          controller: controller,
                        ),
                        transition: Transition.rightToLeft,
                        duration: const Duration(milliseconds: 250),
                      );
                    },
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 14.r,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Edit Plan',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 8.h,
                      ),
                    ),
                  ),
                ),

                // Pause / Resume (only if approved)
                if (_isApproved)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _togglePauseCopying(context),
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 2.h,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        decoration: BoxDecoration(
                          color:
                              plan.copyingPaused
                                  ? AppColors.green.withValues(alpha: 0.1)
                                  : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color:
                                plan.copyingPaused
                                    ? AppColors.green.withValues(alpha: 0.3)
                                    : AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              plan.copyingPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 14.r,
                              color:
                                  plan.copyingPaused
                                      ? AppColors.green
                                      : AppColors.warning,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              plan.copyingPaused ? 'Resume' : 'Pause',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color:
                                    plan.copyingPaused
                                        ? AppColors.green
                                        : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
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

  void _togglePauseCopying(BuildContext context) async {
    final actionText = plan.copyingPaused ? 'Resume Copying' : 'Pause Copying';
    final confirmationMessage =
        plan.copyingPaused
            ? 'Are you sure you want to resume copying for "${plan.planName}"?'
            : 'Are you sure you want to pause copying for "${plan.planName}"? Copying will be suspended until you resume.';

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
            title: Text(
              actionText,
              style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
            content: Text(
              confirmationMessage,
              style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final res =
                      plan.copyingPaused
                          ? await controller.resumePlan(planId: plan.id)
                          : await controller.pausePlan(planId: plan.id);
                  if (res.success) {
                    CustomToastService.showSuccess(
                      title: 'Success',
                      message: res.message ?? 'State updated successfully',
                    );
                  } else {
                    CustomToastService.showError(
                      title: 'Failed',
                      message:
                          res.message ?? 'Failed to update plan copying state',
                    );
                  }
                },
                child: Text(
                  plan.copyingPaused ? 'Resume' : 'Pause',
                  style: AppTextStyles.bodyText.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        plan.copyingPaused
                            ? AppColors.green
                            : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Tile Widget
// ─────────────────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: AppColors.tradeBackgroundCenterColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 28.r,
            height: 28.r,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(icon, size: 14.r, color: iconColor),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
