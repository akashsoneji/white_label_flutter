import 'package:crm_app/utils/navigation_helper.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../constants/color.dart';
import '../../../../constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/internal_transfer_history_controller.dart';
import '../../../../widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class InternalTransferHistoryScreen extends StatefulWidget {
  const InternalTransferHistoryScreen({super.key});

  @override
  State<InternalTransferHistoryScreen> createState() =>
      _InternalTransferHistoryScreenState();
}

class _InternalTransferHistoryScreenState
    extends State<InternalTransferHistoryScreen> {
  final InternalTransferHistoryController controller = Get.put(
    InternalTransferHistoryController(),
  );
  final ScrollController _scrollController = ScrollController();
  final DateFormat _displayDateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    controller.fetchHistory();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 180.h;
    if (_scrollController.position.pixels >= threshold) {
      controller.loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading:  AppBackButton(onPressed: () => NavigationHelper.safeBack(context: context),
        ),
        title: Text(
          'Internal Transfer History',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.refreshHistory,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                sliver: SliverToBoxAdapter(child: _buildFilterCard()),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                sliver: SliverToBoxAdapter(child: _buildSummaryHeader()),
              ),
              Obx(() {
                if (controller.isLoading.value && controller.items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CommonLoadingWidget(isFullScreen: true),
                    ),
                  );
                }

                if (controller.items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) {
                      final item = controller.items[index];
                      return _buildTransferCard(item);
                    },
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemCount: controller.items.length,
                  ),
                );
              }),
              SliverToBoxAdapter(child: _buildPaginationFooter()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter History',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => _buildFilterField(
                    label: 'From Date',
                    value: _formatFilterDate(controller.fromDate.value),
                    icon: Icons.calendar_month_outlined,
                    onTap: () => _pickDate(isFromDate: true),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Obx(
                  () => _buildFilterField(
                    label: 'To Date',
                    value: _formatFilterDate(controller.toDate.value),
                    icon: Icons.calendar_month_outlined,
                    onTap: () => _pickDate(isFromDate: false),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Obx(
            () => _buildFilterField(
              label: 'Status',
              value: controller.selectedStatus.value.label,
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: _showStatusSheet,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: controller.applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: TextStyle(
                        color: AppColors.whiteColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              SizedBox(
                height: 44.h,
                child: OutlinedButton(
                  onPressed: controller.clearFilters,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.icongrey.withValues(alpha: 0.22),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.tradeBackgroundCenterColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.icongrey,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, color: AppColors.primary, size: 19.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Obx(() {
      final pagination = controller.pagination.value;
      final showing =
          pagination.total == 0
              ? 'No entries'
              : 'Showing ${pagination.from} to ${pagination.to} of ${pagination.total} entries';

      return Row(
        children: [
          Expanded(
            child: Text(
              showing,
              style: TextStyle(
                color: AppColors.icongrey,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'Page ${pagination.currentPage} of ${pagination.lastPage}',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTransferCard(InternalTransferHistoryItem item) {
    final statusColor = _statusColor(item.status);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: statusColor.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42.w,
                width: 42.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.primary,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.reference.isEmpty
                          ? 'Internal Transfer'
                          : item.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      item.createdAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.icongrey,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.formattedAmount.isEmpty
                        ? '\$${item.amount}'
                        : item.formattedAmount,
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  _buildStatusChip(item.status, statusColor),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.tradeBackgroundCenterColor,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildAccountBlock(
                    title: 'From',
                    account: item.fromAccount,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                ),
                Expanded(
                  child: _buildAccountBlock(
                    title: 'To',
                    account: item.toAccount,
                    alignment: CrossAxisAlignment.end,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          if (item.comment.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              item.comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.icongrey,
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountBlock({
    required String title,
    required TransferAccount? account,
    required CrossAxisAlignment alignment,
    TextAlign textAlign = TextAlign.start,
  }) {
    final displayName = account?.displayName ?? '';
    final number = account?.number ?? '';
    final type = account?.type.toUpperCase() ?? '';

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.icongrey,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          displayName.isEmpty ? 'Account' : displayName,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
       
      ],
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        _titleCase(status.isEmpty ? 'Unknown' : status),
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Obx(() {
      if (controller.isLoadingMore.value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 22.h),
          child: const Center(child: CommonLoadingWidget()),
        );
      }

      if (controller.items.isEmpty) {
        return SizedBox(height: 24.h);
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: Text(
          controller.hasNextPage
              ? 'Scroll down to load more'
              : 'You have reached the end',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.icongrey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 72.w,
            width: 72.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 34.sp,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'No transfer history found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try changing the date or status filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.icongrey,
              fontSize: 13.sp,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    final initialDate =
        isFromDate
            ? controller.fromDate.value ?? DateTime.now()
            : controller.toDate.value ??
                controller.fromDate.value ??
                DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
           colorScheme: ColorScheme.light(
           primary: AppColors.primary,
            onPrimary: AppColors.whiteColor,
              surface: AppColors.whiteColor,
            onSurface: AppColors.textPrimary,
            ),
            ),
            child: child!,
        );
      },
    );

    if (picked == null) return;
    if (isFromDate) {
      controller.setFromDate(picked);
    } else {
      controller.setToDate(picked);
    }
  }

  void _showStatusSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Select Status',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: controller.statusFilters.length,
                      itemBuilder: (context, index) {
                        final status = controller.statusFilters[index];
                        return Obx(() {
                          final isSelected =
                              status.value == controller.selectedStatus.value.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              status.label,
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            trailing:
                                isSelected
                                    ? Icon(Icons.check, color: AppColors.primary)
                                    : null,
                            onTap: () {
                              controller.setStatus(status);
                              Navigator.pop(context);
                            },
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatFilterDate(DateTime? date) {
    return date == null ? 'dd/mm/yyyy' : _displayDateFormat.format(date);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
      case 'success':
        return AppColors.success;
      case 'failed':
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'[\s_-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
