import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_settlements_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Commission actually credited to the Master's wallet
/// (`GET master/settlements`, spec 9.1).
class MasterSettlementsScreen extends StatefulWidget {
  const MasterSettlementsScreen({super.key});

  @override
  State<MasterSettlementsScreen> createState() =>
      _MasterSettlementsScreenState();
}

class _MasterSettlementsScreenState extends State<MasterSettlementsScreen> {
  late final CopyTradingSettlementsController controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(CopyTradingSettlementsController());
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    Get.delete<CopyTradingSettlementsController>(force: true);
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
        title: Text(
          TranslationUtils.tr('settlements_screen_title'),
          style: AppTextStyles.screenTitle,
        ),
        actions: [
          IconButton(
            onPressed: controller.load,
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Obx(() {
        final items = controller.settlements;
        if (controller.isLoading.value && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value.isNotEmpty && items.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 40.r, color: AppColors.error),
                  SizedBox(height: 10.h),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: controller.load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                    ),
                    child: Text(
                      TranslationUtils.tr('common_retry'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.onColoredBackground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final showLoader = controller.isLoadingMore.value;
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 40.h),
            itemCount: 1 + (items.isEmpty ? 1 : items.length) + (showLoader ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _SummaryCard(controller: controller),
                );
              }
              if (items.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 80.h),
                  child: Text(
                    TranslationUtils.tr('settlements_empty'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                );
              }
              final itemIndex = index - 1;
              if (itemIndex >= items.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _SettlementTile(item: items[itemIndex]),
              );
            },
          ),
        );
      }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CopyTradingSettlementsController controller;
  const _SummaryCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              label: TranslationUtils.tr('settlements_total_credited'),
              value: '\$${controller.totalCredited.value.toStringAsFixed(2)}',
              valueColor: AppColors.green,
            ),
          ),
          Expanded(
            child: _SummaryValue(
              label: TranslationUtils.tr('settlements_entries'),
              value: '${controller.entryCount.value}',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryValue({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textGrey,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SettlementTile extends StatelessWidget {
  final MasterSettlementItem item;
  const _SettlementTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final credited = DateTime.tryParse(item.creditedAt);
    final dateText = credited == null
        ? item.creditedAtDate
        : DateFormat('dd MMM yyyy, HH:mm').format(credited.toLocal());
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description.isNotEmpty ? item.description : item.sourceRef,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  dateText,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.5.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '+\$${item.amount.toStringAsFixed(2)}',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}
