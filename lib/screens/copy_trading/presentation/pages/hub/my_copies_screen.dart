import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_copiers_controller.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/hub/subscribe_to_plan_screen.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_details_controller.dart';

class MyCopiesScreen extends StatefulWidget {
  const MyCopiesScreen({super.key});

  @override
  State<MyCopiesScreen> createState() => _MyCopiesScreenState();
}

class _MyCopiesScreenState extends State<MyCopiesScreen> {
  late final CopyTradingMasterCopiersController controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(CopyTradingMasterCopiersController());
    _searchController.addListener(() {
      final query = _searchController.text;
      if (controller.searchQuery.value != query) {
        controller.searchQuery.value = query;
        controller.currentPage.value = 1;
        controller.load(showLoading: false);
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (controller.hasMore &&
            !controller.isLoadingMore.value &&
            !controller.isLoading.value) {
          controller.loadMore();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    Get.delete<CopyTradingMasterCopiersController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text('My Copiers', style: AppTextStyles.screenTitle),
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAll(() => const TradingMainScreen()),
        ),
        actions: [
          IconButton(
            onPressed: () => controller.load(showLoading: true),
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Sticky Header Section (Filters, Search, Stats Grid) - Outside RefreshIndicator to fix RenderViewportBase._paintContents viewport error
            Container(
              color: AppColors.tradeBackgroundCenterColor,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Portfolio Summary Cards (2x2 Grid)
                  _buildSummaryGrid(context),
                  SizedBox(height: 12.h),

                  // Status Tabs Row with badges and checkmarks
                  _buildStatusTabs(),
                  SizedBox(height: 12.h),

                  // Plan Dropdown and Search input side-by-side
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38.h,
                          decoration: BoxDecoration(
                            color: AppColors.whiteColor,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.12),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search copier...',
                              hintStyle: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textGrey,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 16.r,
                                color: AppColors.textGrey,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10.h,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Obx(() {
                        final plans = controller.masterPlans;
                        return Container(
                          height: 38.h,
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          decoration: BoxDecoration(
                            color: AppColors.whiteColor,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.12),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: controller.planFilter.value,
                              hint: Text(
                                'All plans',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                size: 16.r,
                                color: AppColors.textGrey,
                              ),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              onChanged: (newValue) {
                                controller.planFilter.value = newValue;
                                controller.currentPage.value = 1;
                                controller.load(showLoading: false);
                              },
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    'All plans',
                                    style: TextStyle(fontSize: 12.sp),
                                  ),
                                ),
                                ...plans.map(
                                  (p) => DropdownMenuItem<int?>(
                                    value: p.id,
                                    child: Text(
                                      p.planName,
                                      style: TextStyle(fontSize: 12.sp),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Obx(() {
                final loading = controller.isLoading.value;
                final err = controller.errorMessage.value;
                final allCopiers = controller.copiers;

                if (loading && allCopiers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                Widget listChild;
                if (err.isNotEmpty && allCopiers.isEmpty) {
                  listChild = ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 100.h,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 40.r,
                              color: AppColors.error,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              err,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            ElevatedButton(
                              onPressed:
                                  () => controller.load(showLoading: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: Text(
                                'Retry',
                                style: TextStyle(color: AppColors.whiteColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else if (allCopiers.isEmpty) {
                  listChild = ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 100.h),
                        alignment: Alignment.center,
                        child: Text(
                          'No copiers found matching filters.',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  listChild = ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 80.h),
                    itemCount:
                        allCopiers.length +
                        (controller.isLoadingMore.value ? 1 : 0),
                    separatorBuilder: (_, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      if (index == allCopiers.length) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: SizedBox(
                              width: 20.r,
                              height: 20.r,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }
                      final item = allCopiers[index];
                      return _CopierCardItem(
                        item: item,
                        controller: controller,
                      );
                    },
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => controller.load(showLoading: false),
                  child: listChild,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxWidth = (screenWidth - 32.w - 10.w) / 2;

    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        _summaryBox(
          boxWidth,
          'TOTAL COPIERS',
          controller.summaryTotal.value.toString(),
          'All statuses combined',
        ),
        _summaryBox(
          boxWidth,
          'CAPITAL ALLOCATED',
          '\$${controller.summaryTotalCapital.value.toStringAsFixed(2)}',
          'Across all copiers (portfolio)',
        ),
        _summaryBox(
          boxWidth,
          'COMBINED P&L',
          '\$${controller.summaryTotalPnl.value.toStringAsFixed(2)}',
          'Lifetime copier P&L',
          valueColor:
              controller.summaryTotalPnl.value >= 0
                  ? AppColors.green
                  : AppColors.error,
        ),
        _summaryBox(
          boxWidth,
          'COMMISSION PAID TO YOU',
          '\$${controller.summaryTotalCommissionPaid.value.toStringAsFixed(2)}',
          'Lifetime from copiers',
        ),
      ],
    );
  }

  Widget _summaryBox(
    double width,
    String title,
    String value,
    String desc, {
    Color? valueColor,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textGrey,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            desc,
            style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    final activeStatus = controller.statusFilter.value;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statusTabItem(
            'All',
            'all',
            controller.summaryTotal.value,
            activeStatus,
          ),
          SizedBox(width: 6.w),
          _statusTabItem(
            'Active',
            'active',
            controller.summaryActive.value,
            activeStatus,
          ),
          SizedBox(width: 6.w),
          _statusTabItem(
            'Pending',
            'pending',
            controller.summaryPending.value,
            activeStatus,
          ),
          SizedBox(width: 6.w),
          _statusTabItem(
            'Paused',
            'paused',
            controller.summaryPaused.value,
            activeStatus,
          ),
          SizedBox(width: 6.w),
          _statusTabItem(
            'Stopped / Removed',
            'stopped',
            controller.summaryStoppedOrRemoved.value,
            activeStatus,
          ),
        ],
      ),
    );
  }

  Widget _statusTabItem(
    String label,
    String value,
    int count,
    String activeValue,
  ) {
    final isSelected = activeValue == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          controller.statusFilter.value = value;
          controller.currentPage.value = 1;
        });
        controller.load(showLoading: false);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary
                    : AppColors.border.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 4.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary
                        : AppColors.tradeBackgroundCenterColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.whiteColor : AppColors.textGrey,
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.check,
              size: 10.r,
              color:
                  isSelected
                      ? AppColors.primary
                      : AppColors.textGrey.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopierCardItem extends StatelessWidget {
  final MasterCopierItem item;
  final CopyTradingMasterCopiersController controller;

  const _CopierCardItem({required this.item, required this.controller});

  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return AppColors.green;
      case 'pending':
        return AppColors.warning;
      case 'paused':
        return AppColors.textGrey;
      case 'stopped':
      case 'cancelled':
      case 'stopped_or_removed':
        return AppColors.error;
      default:
        return AppColors.textGrey;
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = item.status;
    final isApproved = status.toLowerCase() == 'active';
    final isPaused = status.toLowerCase() == 'paused';
    final canPauseResume = isApproved || isPaused;
    final canStop = isApproved || isPaused;

    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - 32.w - 24.r - 8.w) / 2;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Purple / Color Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            color: AppColors.primary.withValues(alpha: 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.userName,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Detail line (Plan Name / Commission Type)
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 2.h),
            child: Text(
              '${item.planName}  •  ${item.commissionDisplay}',
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Compact metrics grid
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _metricBox(
                  cellWidth,
                  'CAPITAL ALLOCATED',
                  '\$${item.capitalAmount.toStringAsFixed(2)}',
                ),
                _metricBox(
                  cellWidth,
                  'COMBINED P&L',
                  '\$${item.totalPnl.toStringAsFixed(2)}',
                  valueColor:
                      item.totalPnl >= 0 ? AppColors.green : AppColors.error,
                ),
                _metricBox(
                  cellWidth,
                  'COMMISSION PAID',
                  '\$${item.totalCommissionPaid.toStringAsFixed(2)}',
                ),
                _metricBox(
                  cellWidth,
                  'OPEN TRADES',
                  item.openTradesCount.toString(),
                ),
                _metricBox(
                  cellWidth,
                  'METHOD',
                  item.sizingMethod.replaceAll('_', ' ').toUpperCase(),
                ),
                _metricBox(
                  cellWidth,
                  'LAST UPDATE',
                  _formatDate(item.updatedAt),
                ),
                _metricBox(cellWidth, 'ACCOUNT', item.accountNumber),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.1)),

          // Actions Row
          Padding(
            padding: EdgeInsets.all(8.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final plan = CopyTradingPlan(
                      id: item.planId,
                      planId: item.planId,
                      planName: item.planName,
                      commissionType: 'per_trade',
                      commissionLabel: '',
                      commissionPercentage: 0,
                      subscriptionFee: 0,
                      minimumCapital: 0,
                      copyRatio: item.copyRatio,
                      isFull: false,
                      noFeeDays: 0,
                      subscriptionPeriodDays: 0,
                      activeCopiersCount: 0,
                      totalAum: 0,
                      isEnrolled: false,
                    );
                    await Get.to(
                      () => SubscribeToPlanScreen(
                        masterCode: '',
                        plan: plan,
                        editSubscription: null,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                  ),
                  child: Text(
                    'Edit Settings',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (canPauseResume) ...[
                  SizedBox(width: 4.w),
                  TextButton(
                    onPressed: () => _togglePauseResume(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                    ),
                    child: Text(
                      isPaused ? 'Resume' : 'Pause',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: isPaused ? AppColors.green : AppColors.warning,
                      ),
                    ),
                  ),
                ],
                if (canStop) ...[
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: () => _stopCopier(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.whiteColor,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                    child: Text(
                      'Stop Copy',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(
    double width,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.tradeBackgroundCenterColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textGrey,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _togglePauseResume(BuildContext context) {
    final actionText =
        item.status.toLowerCase() == 'paused'
            ? 'Resume copying'
            : 'Pause copying';
    final confirmationMessage =
        item.status.toLowerCase() == 'paused'
            ? 'Are you sure you want to resume copying for this investor?'
            : 'Are you sure you want to pause copying for this investor? Copying will be suspended.';

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(actionText),
            content: Text(confirmationMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final res =
                      item.status.toLowerCase() == 'paused'
                          ? await controller.resume(item.id)
                          : await controller.pause(item.id);
                  if (res.success) {
                    CustomToastService.showSuccess(
                      title: 'Success',
                      message: res.message ?? 'State updated successfully',
                    );
                  } else {
                    CustomToastService.showError(
                      title: 'Failed',
                      message:
                          res.message ??
                          'Failed to update copier copying state',
                    );
                  }
                },
                child: Text(
                  item.status.toLowerCase() == 'paused' ? 'Resume' : 'Pause',
                  style: TextStyle(
                    color:
                        item.status.toLowerCase() == 'paused'
                            ? AppColors.green
                            : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _stopCopier(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Stop Copy'),
            content: const Text(
              'Are you sure you want to permanently stop copying for this investor? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final res = await controller.stop(item.id);
                  if (res.success) {
                    CustomToastService.showSuccess(
                      title: 'Success',
                      message: res.message ?? 'Copier stopped successfully',
                    );
                  } else {
                    CustomToastService.showError(
                      title: 'Failed',
                      message: res.message ?? 'Failed to stop copier',
                    );
                  }
                },
                child: Text('Stop', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
    );
  }
}
