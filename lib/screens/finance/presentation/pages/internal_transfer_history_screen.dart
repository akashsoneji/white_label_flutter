import 'package:crm_app/utils/navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../constants/color.dart';
import '../../../../constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/internal_transfer_history_controller.dart';
import 'package:crm_app/services/language_service.dart';
import '../../../../widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// Display label for an internal-transfer status filter (raw values are API params).
String _statusLabel(InternalTransferStatusFilter status) {
  switch (status.value) {
    case 'approved':
      return TranslationUtils.tr('kyc_verification_approved');
    case 'pending':
      return TranslationUtils.tr('transaction_history_pending');
    case 'failed':
      return TranslationUtils.tr('transaction_history_failed');
    default:
      return TranslationUtils.tr('ticket_all_status');
  }
}

class InternalTransferHistoryScreen extends GetView<InternalTransferHistoryController> {
  const InternalTransferHistoryScreen({super.key});


  @override
  Widget build(BuildContext context) {
    // Initialize the controller here if not done in routes
    if (!Get.isRegistered<InternalTransferHistoryController>()) {
      Get.put(InternalTransferHistoryController());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: AppBackButton(
          onPressed: () => NavigationHelper.safeBack(context: context),
        ),
        title: Text(
          TranslationUtils.tr('internal_transfer_history'),
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed top part
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.w, 12.h, 20.w, 0),
              child: InternalTransferFilterCard(),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.w, 16.h, 20.w, 10.h),
              child: const InternalTransferSummaryHeader(),
            ),
            // Scrollable list part
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.items.isEmpty) {
                  return const Center(
                    child: CommonLoadingWidget(isFullScreen: false),
                  );
                }

                if (controller.items.isEmpty) {
                  return const InternalTransferEmptyState();
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.refreshHistory,
                  child: ListView.builder(
                    controller: controller.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsetsDirectional.fromSTEB(20.w, 4.h, 20.w, 24.h),
                    itemCount: controller.items.length + 1, // +1 for loading indicator
                    itemBuilder: (context, index) {
                      if (index == controller.items.length) {
                        return const InternalTransferPaginationFooter();
                      }
                      
                      final item = controller.items[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: InternalTransferCard(item: item),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class InternalTransferFilterCard extends GetView<InternalTransferHistoryController> {
  InternalTransferFilterCard({super.key});

  final DateFormat _displayDateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
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
            TranslationUtils.tr(
              'internal_transfer_history_screen_filter_history',
            ),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          Obx(() => Row(
            children: [
              Expanded(
                child: _buildFilterField(
                  label: TranslationUtils.tr(
                    'internal_transfer_history_screen_from_date',
                  ),
                  value: _formatFilterDate(controller.fromDate.value),
                  icon: Icons.calendar_month_outlined,
                  onTap: () => _pickDate(context, isFromDate: true),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildFilterField(
                  label: TranslationUtils.tr(
                    'internal_transfer_history_screen_to_date',
                  ),
                  value: _formatFilterDate(controller.toDate.value),
                  icon: Icons.calendar_month_outlined,
                  onTap: () => _pickDate(context, isFromDate: false),
                ),
              ),
            ],
          )),
          SizedBox(height: 10.h),
          Obx(() => _buildFilterField(
            label: TranslationUtils.tr('common_status'),
            value: _statusLabel(controller.selectedStatus.value),
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () => _showStatusSheet(context),
          )),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: controller.applyFilters,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 0),
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      TranslationUtils.tr(
                        'internal_transfer_history_screen_apply_filters',
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.whiteColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: SizedBox(
                  height: 44.h,
                  child: OutlinedButton(
                    onPressed: controller.clearFilters,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 0),
                      side: BorderSide(
                        color: AppColors.icongrey.withValues(alpha: 0.22),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      TranslationUtils.tr('common_clear'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
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
                    style: AppTextStyles.bodyText.copyWith(
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
                    style: AppTextStyles.bodyText.copyWith(
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

  String _formatFilterDate(DateTime? date) {
    return date == null ? 'dd/mm/yyyy' : _displayDateFormat.format(date);
  }

  Future<void> _pickDate(BuildContext context, {required bool isFromDate}) async {
    final initialDate = isFromDate
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

  void _showStatusSheet(BuildContext context) {
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
              padding: EdgeInsetsDirectional.fromSTEB(20.w, 12.h, 20.w, 20.h),
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
                    TranslationUtils.tr(
                      'internal_transfer_history_screen_select_status',
                    ),
                    style: AppTextStyles.bodyText.copyWith(
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
                        final isSelected =
                            status.value == controller.selectedStatus.value.value;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _statusLabel(status),
                            style: AppTextStyles.bodyText.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            controller.setStatus(status);
                            Navigator.pop(context);
                          },
                        );
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
}

class InternalTransferSummaryHeader extends GetView<InternalTransferHistoryController> {
  const InternalTransferSummaryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pagination = controller.pagination.value;
      final showing = pagination.total == 0
          ? TranslationUtils.tr('internal_transfer_history_screen_no_entries')
          : TranslationUtils.trArgs(
              'internal_transfer_history_screen_showing_from_to_of_total',
              {
                'from': '${pagination.from}',
                'to': '${pagination.to}',
                'total': '${pagination.total}',
              },
            );

      return Row(
        children: [
          Expanded(
            child: Text(
              showing,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.icongrey,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Container(
          //   padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          //   decoration: BoxDecoration(
          //     color: AppColors.primary.withValues(alpha: 0.10),
          //     borderRadius: BorderRadius.circular(20.r),
          //   ),
          //   child: Text(
          //     'Page ${pagination.currentPage} of ${pagination.lastPage}',
          //     style: AppTextStyles.bodyText.copyWith(
          //       color: AppColors.primary,
          //       fontSize: 11.sp,
          //       fontWeight: FontWeight.w700,
          //     ),
          //   ),
          // ),
        ],
      );
    });
  }
}

class InternalTransferCard extends StatelessWidget {
  final InternalTransferHistoryItem item;
  const InternalTransferCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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
                          ? TranslationUtils.tr('internal_transfer')
                          : item.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      _formatDate(item.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
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
                    item.formattedAmount.isNotEmpty
                        ? item.formattedAmount
                        : '\$${item.amount}',
                    style: AppTextStyles.bodyText.copyWith(
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
          SizedBox(height: 12.h),
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
                    title: TranslationUtils.tr('internal_transfer_history_from'),
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
            SizedBox(height: 10.h),
            Text(
              item.comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
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

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          title,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.icongrey,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          displayName.isEmpty
              ? TranslationUtils.tr('settings_account')
              : displayName,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
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
        status.isEmpty
            ? TranslationUtils.tr('internal_transfer_history_screen_unknown')
            : _titleCase(status),
        style: AppTextStyles.bodyText.copyWith(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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
      case 'declined':
        return AppColors.error;
      case 'pending':
      case 'processing':
      case 'in_review':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'[\s_-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      final parsed = DateTime.tryParse(rawDate)?.toLocal();
      if (parsed != null) {
        return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
      }
    } catch (_) {}
    return rawDate;
  }
}

class InternalTransferEmptyState extends StatelessWidget {
  const InternalTransferEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 50.h),
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
            TranslationUtils.tr('master_details_screen_no_data'),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            TranslationUtils.tr(
              'internal_transfer_history_screen_try_changing_the_date_or_status',
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.icongrey,
              fontSize: 13.sp,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class InternalTransferPaginationFooter extends GetView<InternalTransferHistoryController> {
  const InternalTransferPaginationFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingMore.value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 22.h),
          child: const Center(child: CommonLoadingWidget()),
        );
      }

      if (controller.items.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Text(
          controller.hasNextPage
              ? TranslationUtils.tr(
                'internal_transfer_history_screen_scroll_down_to_load_more',
              )
              : TranslationUtils.tr(
                'internal_transfer_history_screen_you_have_reached_the_end',
              ),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.icongrey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    });
  }
}
