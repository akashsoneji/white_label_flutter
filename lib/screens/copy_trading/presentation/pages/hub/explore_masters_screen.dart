import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_masters_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'master_details_screen.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class ExploreMastersScreen extends StatelessWidget {
  const ExploreMastersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CopyTradingMastersController());

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Explore Masters',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: const AppBackButton(),
        actions: [
          IconButton(
            onPressed: () => controller.loadMasters(showLoading: true),
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
            child: Row(
              children: [
                Expanded(
                  child: _SearchField(
                    onChanged: (v) {
                      controller.search.value = v;
                    },
                    onSubmitted: (_) => controller.loadMasters(showLoading: true),
                  ),
                ),
                SizedBox(width: 10.w),
                _SortButton(
                  value: controller.sort,
                  onChanged: (v) async {
                    controller.sort.value = v;
                    await controller.loadMasters(showLoading: true);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const _LoadingList();
              }

              if (controller.errorMessage.value.isNotEmpty) {
                return _ErrorState(
                  message: controller.errorMessage.value,
                  onRetry: () => controller.loadMasters(showLoading: true),
                );
              }

              if (controller.masters.isEmpty) {
                return const _EmptyState();
              }

              final visible = controller.filteredMasters;
              if (visible.isEmpty) {
                return _NoSearchMatchesState(query: controller.search.value.trim());
              }

              return RefreshIndicator(
                onRefresh: () => controller.loadMasters(showLoading: false),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 90.h),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final m = visible[index];
                    return _MasterCard(
                      item: m,
                      onTap: () => Get.to(
                        () => MasterDetailsScreen(masterCode: m.masterCode, masterNickname: m.nickname),
                        transition: Transition.rightToLeft,
                        duration: const Duration(milliseconds: 250),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  const _SearchField({required this.onChanged, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search by nickname',
        prefixIcon: Icon(Icons.search, size: 20.r, color: AppColors.textGrey),
        filled: true,
        fillColor: AppColors.whiteColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.55)),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final RxString value;
  final ValueChanged<String> onChanged;
  const _SortButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return PopupMenuButton<String>(
        onSelected: onChanged,
        itemBuilder: (_) => const [
          PopupMenuItem(value: '', child: Text('Default')),
          PopupMenuItem(value: 'gain', child: Text('Sort by Gain')),
          PopupMenuItem(value: 'aum', child: Text('Sort by AUM')),
          PopupMenuItem(value: 'copiers', child: Text('Sort by Copiers')),
        ],
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort, size: 18.r, color: AppColors.primary),
              SizedBox(width: 6.w),
              Text('Sort', style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary)),
            ],
          ),
        ),
      );
    });
  }
}

class _MasterCard extends StatelessWidget {
  final CopyTradingMasterListItem item;
  final VoidCallback onTap;
  const _MasterCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gain = item.totalGain.toStringAsFixed(2);
    final gainColor = item.totalGain >= 0 ? AppColors.green : AppColors.red;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.only(bottom: 10.h, top: 4.h),
            title: Row(
              children: [
                Container(
                  width: 42.r,
                  height: 42.r,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.person, color: AppColors.primary, size: 22.r),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nickname.isNotEmpty ? item.nickname : item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${item.planCount} plan • ${item.activeDays} days',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                if (item.isEnrolled)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.statusGreen.withOpacity(0.25)),
                    ),
                    child: Text(
                      'Enrolled',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusGreen,
                      ),
                    ),
                  ),
              ],
            ),
            children: [
              Row(
                children: [
                  _MiniStat(label: 'Gain', value: '$gain%', valueColor: gainColor),
                  SizedBox(width: 10.w),
                  _MiniStat(label: 'Copiers', value: item.totalCopiers.toString()),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  _MiniStat(label: 'AUM', value: item.totalAum.toStringAsFixed(2)),
                  SizedBox(width: 10.w),
                  _MiniStat(label: 'Risk', value: (item.riskScore ?? 0).toString()),
                ],
              ),
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: onTap,
                  child: Text('View details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _MiniStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.tradeBackgroundCenterColor.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: 
              AppColors.primary.withOpacity(0.10),
              blurRadius: 1,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey)),
            SizedBox(height: 4.h),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 90.h),
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (_, __) => Container(
        height: 92.h,
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Text(
          'No masters found',
          style: AppTextStyles.subheading.copyWith(color: AppColors.textGrey),
        ),
      ),
    );
  }
}

class _NoSearchMatchesState extends StatelessWidget {
  final String query;
  const _NoSearchMatchesState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40.r, color: AppColors.textGrey),
            SizedBox(height: 10.h),
            Text(
              'No Masters Match "${query}"',
              textAlign: TextAlign.center,
              style: AppTextStyles.subheading.copyWith(color: AppColors.textGrey),
            ),
            SizedBox(height: 6.h),
            Text(
              'Try a different nickname or clear the search.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40.r, color: AppColors.red),
            SizedBox(height: 10.h),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey)),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

