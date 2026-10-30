import 'package:crm_app/routes/app_pages.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_dashboard_controller.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_hub_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/home/more/copytrading/copy_trading_create_plan_screen.dart';
import 'package:crm_app/screens/home/more/copytrading/master_plan_detail_screen.dart';
import 'package:crm_app/screens/home/more/copytrading/copy_trading_edit_plan_screen.dart';
import 'package:crm_app/services/language_service.dart';

class MyPlansTab extends StatefulWidget {
  const MyPlansTab({super.key});

  @override
  State<MyPlansTab> createState() => _MyPlansTabState();
}

class _MyPlansTabState extends State<MyPlansTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'Newest first';
  String _statusFilter = 'all';

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

  String _sortLabelKey(String value) {
    switch (value) {
      case 'Name A-Z':
        return 'my_plans_tab_sort_name_a_z';
      case 'Highest AUM':
        return 'my_plans_tab_sort_highest_aum';
      default:
        return 'my_plans_tab_sort_newest_first';
    }
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

      if (_statusFilter != 'all') {
        result =
            result
                .where((plan) => _statusBucket(plan.status) == _statusFilter)
                .toList();
      }

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
          TranslationUtils.tr('my_plans_tab_my_copy_plans'),
          style: AppTextStyles.screenTitle.copyWith(fontSize: 16.sp),
        ),
        actions: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 14.w),
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
                      TranslationUtils.tr('my_plans_tab_create_plan'),
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
                        textAlignVertical: TextAlignVertical.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: TranslationUtils.tr(
                            'my_plans_tab_search_plan_name_id',
                          ),
                          hintStyle: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18.r,
                            color: AppColors.textGrey,
                          ),
                          // The app theme sets enabled/focused borders, so
                          // `border` alone still drew a second outline inside
                          // this container.
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
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
                                child: Text(
                                  TranslationUtils.tr(_sortLabelKey(value)),
                                ),
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
                          TranslationUtils.tr('my_plans_tab_loading_plans'),
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
                                  label: Text(
                                    TranslationUtils.tr('my_plans_tab_try_again'),
                                  ),
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

                  listChild = ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsetsDirectional.fromSTEB(16.w, 4.h, 16.w, 100.h),
                    children: [
                      _PlansSummaryStrip(plans: allPlans),
                      SizedBox(height: 10.h),
                      _StatusFilterChips(
                        plans: allPlans,
                        selected: _statusFilter,
                        onSelected: (bucket) =>
                            setState(() => _statusFilter = bucket),
                      ),
                      SizedBox(height: 12.h),
                      if (filteredSortedPlans.isEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 60.h),
                          child: Column(
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
                                TranslationUtils.tr(
                                  'my_plans_tab_no_plans_match_your_search',
                                ),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 14.sp,
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final plan in filteredSortedPlans)
                          Padding(
                            padding: EdgeInsets.only(bottom: 14.h),
                            child: _PlanCardItem(
                              plan: plan,
                              controller: controller,
                            ),
                          ),
                    ],
                  );
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
              TranslationUtils.tr('my_plans_tab_no_copy_plans_yet'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              TranslationUtils.tr('my_plans_tab_create_a_copying_plan'),
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
              label: Text(
                TranslationUtils.tr('my_plans_tab_create_first_plan'),
              ),
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
        return TranslationUtils.tr('kyc_verification_approved');
      case 'pending':
        return TranslationUtils.tr('kyc_verification_pending');
      case 'pending_admin':
      case 'pending_review':
        return TranslationUtils.tr('copy_trading_hub_screen_pending_review');
      case 'inactive':
        return TranslationUtils.tr('wallet_inactive');
      case 'rejected':
        return TranslationUtils.tr('kyc_verification_rejected');
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

  /// "15% · HWM" — short enough for the tile; falls back to the API label.
  String get _commissionText {
    final type = plan.commissionType.toUpperCase();
    if (plan.commissionPercentage > 0) {
      final pct = '${_trimDecimals(plan.commissionPercentage)}%';
      return type.isEmpty ? pct : '$pct · $type';
    }
    return plan.commissionLabel.isNotEmpty ? plan.commissionLabel : '—';
  }

  /// Web shows "—" when there is no subscription fee.
  String get _subscriptionText {
    if (plan.subscriptionFee <= 0) return '—';
    final fee = _formatUsd(plan.subscriptionFee);
    return plan.subscriptionPeriodDays > 0
        ? '$fee / ${plan.subscriptionPeriodDays}D'
        : fee;
  }

  /// "Tenax · selfHosted" (LP provider + trading server), like the web column.
  String get _serverText {
    final parts = [plan.lpProviderName, plan.tradingServer]
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? '—' : parts.join(' · ');
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
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Name takes all the free width and only ellipsizes when it
                // really doesn't fit; a Spacer here would split the width 50/50.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.planName.isEmpty
                              ? TranslationUtils.tr('my_plans_tab_unnamed_plan')
                              : plan.planName,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onColoredBackground,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (plan.tradingAccountNumber.isNotEmpty) ...[
                        SizedBox(width: 6.w),
                        Text(
                          plan.tradingAccountNumber,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onColoredBackground.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.onColoredBackground.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    '#${plan.id}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onColoredBackground,
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
                              ? TranslationUtils.tr(
                                'my_plans_tab_copying_paused',
                              )
                              : TranslationUtils.tr(
                                'my_plans_tab_copying_active',
                              ),
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
                      TranslationUtils.tr('my_plans_tab_full'),
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
                        label: TranslationUtils.tr('my_plans_tab_copiers'),
                        // Empty max_copiers = no limit, shown as ∞ like web.
                        value:
                            '${plan.activeCopiersCount} / ${plan.maxCopiers ?? '∞'}',
                        iconColor: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.account_balance_outlined,
                        label: TranslationUtils.tr(
                          'pmam_manager_dashboard_screen_total_aum',
                        ),
                        value: _formatUsd(plan.totalCapital),
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
                        label: TranslationUtils.tr('general_commission'),
                        value: _commissionText,
                        iconColor: AppColors.warningText,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.savings_outlined,
                        label: TranslationUtils.tr('my_plans_tab_min_capital'),
                        value: _formatUsd(plan.minimumCapital),
                        iconColor: AppColors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _PlanInfoRow(
                  label: TranslationUtils.tr('my_plans_tab_subscription_fee'),
                  value: _subscriptionText,
                ),
                _PlanInfoRow(
                  label: TranslationUtils.tr('copy_trading_server'),
                  value: _serverText,
                ),
                _PlanInfoRow(
                  label: TranslationUtils.tr('ticket_created'),
                  value: _formatCreatedDate(plan.createdAt),
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
                    onPressed: () async {
                      await Get.to(
                        () => MasterPlanDetailScreen(planId: plan.id),
                      );
                      // Detail can pause/resume/inactivate the plan; reload so
                      // the card doesn't show the pre-change state.
                      controller.refreshAll(showLoading: false);
                    },
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 14.r,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      TranslationUtils.tr('my_clients_screen_view_details'),
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
                      TranslationUtils.tr('edit_plan_bottom_sheet_edit_plan'),
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
                              plan.copyingPaused
                                  ? TranslationUtils.tr('my_plans_tab_resume')
                                  : TranslationUtils.tr('my_plans_tab_pause'),
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
    final actionText =
        plan.copyingPaused
            ? TranslationUtils.tr('my_plans_tab_resume_copying')
            : TranslationUtils.tr('my_plans_tab_pause_copying');
    final confirmationMessage =
        plan.copyingPaused
            ? TranslationUtils.trArgs('my_plans_tab_confirm_resume_copying', {
              'plan': plan.planName,
            })
            : TranslationUtils.trArgs('my_plans_tab_confirm_pause_copying', {
              'plan': plan.planName,
            });

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
                  TranslationUtils.tr('account_management_cancel'),
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
                      title: TranslationUtils.tr('create_account_success'),
                      message:
                          res.message ??
                          TranslationUtils.tr(
                            'my_plans_tab_state_updated_successfully',
                          ),
                    );
                  } else {
                    CustomToastService.showError(
                      title: TranslationUtils.tr('transaction_history_failed'),
                      message:
                          res.message ??
                          TranslationUtils.tr(
                            'my_plans_tab_failed_to_update_copying_state',
                          ),
                    );
                  }
                },
                child: Text(
                  plan.copyingPaused
                      ? TranslationUtils.tr('my_plans_tab_resume')
                      : TranslationUtils.tr('my_plans_tab_pause'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers shared by the summary, filters and plan card (mirrors web My Plans)
// ─────────────────────────────────────────────────────────────────────────────

/// Web tab bucket for a plan `status`: active / pending / rejected / inactive.
String _statusBucket(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
    case 'active':
      return 'active';
    case 'pending':
    case 'pending_admin':
    case 'pending_review':
      return 'pending';
    case 'rejected':
      return 'rejected';
    case 'inactive':
      return 'inactive';
    default:
      return 'other';
  }
}

String _formatUsd(num value) =>
    NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(value);

/// API numbers can be int (15) or float (12.5); keep decimals only when present.
String _trimDecimals(num value) {
  final isWhole = value == value.truncate();
  return value.toStringAsFixed(isWhole ? 0 : 2);
}

String _formatCreatedDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return '—';
  return DateFormat('dd MMM yyyy').format(parsed.toLocal());
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary strip — Total Plans / Active / Pending review / Total AUM / Copiers
// ─────────────────────────────────────────────────────────────────────────────

class _PlansSummaryStrip extends StatelessWidget {
  final List<CopyTradingMasterPlanItem> plans;

  const _PlansSummaryStrip({required this.plans});

  @override
  Widget build(BuildContext context) {
    final activeCount =
        plans.where((p) => _statusBucket(p.status) == 'active').length;
    final pendingCount =
        plans.where((p) => _statusBucket(p.status) == 'pending').length;
    final totalAum = plans.fold<num>(0, (sum, p) => sum + p.totalCapital);
    final totalCopiers =
        plans.fold<int>(0, (sum, p) => sum + p.activeCopiersCount);

    final counts = [
      _SummaryTile(
        icon: Icons.grid_view_rounded,
        label: TranslationUtils.tr('my_plans_tab_total_plans'),
        value: '${plans.length}',
      ),
      _SummaryTile(
        icon: Icons.check_circle_outline_rounded,
        label: TranslationUtils.tr('pmam_active_plans'),
        value: '$activeCount',
      ),
      _SummaryTile(
        icon: Icons.schedule_rounded,
        label: TranslationUtils.tr('copy_trading_hub_screen_pending_review'),
        value: '$pendingCount',
      ),
    ];
    final totals = [
      _SummaryTile(
        icon: Icons.account_balance_wallet_outlined,
        label: TranslationUtils.tr('pmam_manager_dashboard_screen_total_aum'),
        value: _formatUsd(totalAum),
      ),
      _SummaryTile(
        icon: Icons.people_alt_outlined,
        label: TranslationUtils.tr('my_plans_tab_total_copiers'),
        value: '$totalCopiers',
        valueColor: AppColors.green,
      ),
    ];

    // Everything visible at once (no hidden horizontal scroll): one row of 5
    // on tablets/unfolded foldables, 3 counts + 2 totals on phones.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        if (isWide) return _SummaryRow(tiles: [...counts, ...totals]);
        return Column(
          children: [
            _SummaryRow(tiles: counts),
            SizedBox(height: 8.h),
            _SummaryRow(tiles: totals),
          ],
        );
      },
    );
  }
}

/// Equal-width, equal-height tiles with a fixed gap.
class _SummaryRow extends StatelessWidget {
  final List<Widget> tiles;

  const _SummaryRow({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) SizedBox(width: 8.w),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24.r,
            height: 24.r,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(icon, size: 13.r, color: AppColors.onColoredBackground),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
            ),
          ),
          const Spacer(),
          SizedBox(height: 2.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status filter chips — All / Active / Pending review / Rejected / Inactive
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterChips extends StatelessWidget {
  final List<CopyTradingMasterPlanItem> plans;
  final String selected;
  final ValueChanged<String> onSelected;

  const _StatusFilterChips({
    required this.plans,
    required this.selected,
    required this.onSelected,
  });

  static const _filters = <(String, String)>[
    ('all', 'common_all'),
    ('active', 'wallet_active'),
    ('pending', 'copy_trading_hub_screen_pending_review'),
    ('rejected', 'kyc_verification_rejected'),
    ('inactive', 'wallet_inactive'),
  ];

  int _countFor(String bucket) => bucket == 'all'
      ? plans.length
      : plans.where((p) => _statusBucket(p.status) == bucket).length;

  @override
  Widget build(BuildContext context) {
    // Single-row segmented track; scrolls horizontally on narrow screens and
    // the tapped chip scrolls itself into view so no status is hidden.
    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final (bucket, labelKey) in _filters)
              _FilterChip(
                label: TranslationUtils.tr(labelKey),
                count: _countFor(bucket),
                isSelected: selected == bucket,
                onTap: () => onSelected(bucket),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? AppColors.onColoredBackground : AppColors.textGrey;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onTap();
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? fg : AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 5.w),
            Container(
              constraints: BoxConstraints(minWidth: 16.w),
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: isSelected ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
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
// Plan info row — label on the start side, value on the end side
// ─────────────────────────────────────────────────────────────────────────────

class _PlanInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _PlanInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 11.sp,
              color: AppColors.textGrey,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
