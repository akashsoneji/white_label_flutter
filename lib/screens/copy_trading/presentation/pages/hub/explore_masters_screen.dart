import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:crm_app/widgets/app_select_field.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_masters_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import 'master_details_screen.dart';

class ExploreMastersScreen extends StatelessWidget {
  const ExploreMastersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CopyTradingMastersController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Explore Masters',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAll(() => TradingMainScreen()),
        ),
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
                    onSubmitted:
                        (_) => controller.loadMasters(showLoading: true),
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
                return _LoadingList();
              }

              if (controller.errorMessage.value.isNotEmpty) {
                return _ErrorState(
                  message: controller.errorMessage.value,
                  onRetry: () => controller.loadMasters(showLoading: true),
                );
              }

              if (controller.masters.isEmpty) {
                return _EmptyState();
              }

              final visible = controller.filteredMasters;
              if (visible.isEmpty) {
                return _NoSearchMatchesState(
                  query: controller.search.value.trim(),
                );
              }

              return RefreshIndicator(
                onRefresh: () => controller.loadMasters(showLoading: false),
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 90.h),
                  itemCount: visible.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12.h,
                    crossAxisSpacing: 12.w,
                    childAspectRatio: 0.60,
                  ),
                  itemBuilder: (context, index) {
                    final m = visible[index];
                    return _MasterCard(
                      item: m,
                      onTap:
                          () => Get.to(
                            () => MasterDetailsScreen(
                              masterCode: m.masterCode,
                              masterNickname: m.nickname,
                            ),
                            transition: Transition.rightToLeft,
                            duration: Duration(milliseconds: 250),
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
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.28),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final RxString value;
  final Future<void> Function(String) onChanged;
  const _SortButton({required this.value, required this.onChanged});

  static const List<AppSelectOption<String>> _options = [
    AppSelectOption(value: '', title: 'Default'),
    AppSelectOption(value: 'gain', title: 'Sort by Gain'),
    AppSelectOption(value: 'aum', title: 'Sort by AUM'),
    AppSelectOption(value: 'copiers', title: 'Sort by Copiers'),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SizedBox(
        width: 128.w,
        child: AppSelectField<String>(
          value: value.value,
          hint: 'Sort',
          sheetTitle: 'Sort by',
          borderRadius: 12,
          fontSize: 12.sp,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10.w,
            vertical: 12.h,
          ),
          options: _options,
          onChanged: (v) async {
            if (v == null) return;
            await onChanged(v);
          },
        ),
      );
    });
  }
}

class _MasterCard extends StatelessWidget {
  final CopyTradingMasterListItem item;
  final VoidCallback onTap;
  const _MasterCard({required this.item, required this.onTap});

  Color _getRiskColor(int? risk) {
    if (risk == null) return AppColors.textGrey;
    if (risk <= 2) return AppColors.blue;
    if (risk <= 4) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final gainPercent = item.totalGainPercent;
    final gainColor = gainPercent >= 0 ? AppColors.green : AppColors.error;
    final gainText =
        "${gainPercent >= 0 ? '+' : ''}${gainPercent.toStringAsFixed(2)}%";

    final pnl = item.totalPnl;
    final pnlColor = pnl >= 0 ? AppColors.green : AppColors.error;
    final pnlText = "${pnl >= 0 ? '+' : '-'}\$${pnl.abs().toStringAsFixed(2)}";

    final drawdownText =
        "-${item.maxDrawdown.toStringAsFixed(item.maxDrawdown % 1 == 0 ? 0 : 2)}%";
    final minInvestmentText =
        "\$${item.minInvestment.toStringAsFixed(item.minInvestment % 1 == 0 ? 0 : 2)}";

    final displayName = item.nickname.isNotEmpty ? item.nickname : item.name;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar & Risk Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (displayName.isNotEmpty ? displayName[0] : '?')
                        .toUpperCase(),
                    style: TextStyle(
                      color: AppColors.whiteColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (item.riskScore != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getRiskColor(
                        item.riskScore,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'RISK ${item.riskScore}',
                      style: TextStyle(
                        color: _getRiskColor(item.riskScore),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4.h),

            // Name
            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2.h),

            // Active days
            Text(
              'Active ${item.activeDays}D',
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w400,
              ),
            ),

            // Horizontal Green Bar
            Container(
              height: 3.h,
              margin: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(1.5.r),
              ),
            ),

            // Stats 2x2 Grid using standard Columns and Rows
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL GAIN',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              gainText,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: gainColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MAX DRAWDOWN',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              drawdownText,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL P&L',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              pnlText,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: pnlColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MIN INVESTMENT',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              minInvestmentText,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            Spacer(),

            // Bottom Row: Fee & Copiers
            Row(
              children: [
                Text(
                  'Fee: ',
                  style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
                ),
                Text(
                  '0%',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.sp,
                  ),
                ),
                Spacer(),
                Icon(
                  Icons.people_outline,
                  size: 13.r,
                  color: AppColors.textGrey,
                ),
                SizedBox(width: 2.w),
                Text(
                  item.totalCopiers.toString(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),

            // Copy Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onColoredBackground,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 8.h,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Copy',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.whiteColor,
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

class _LoadingList extends StatelessWidget {
  _LoadingList();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 90.h),
      itemCount: 6,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.48,
      ),
      itemBuilder:
          (_, index) => Container(
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.15),
              ),
            ),
          ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  _EmptyState();

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
              'No Masters Match "$query"',
              textAlign: TextAlign.center,
              style: AppTextStyles.subheading.copyWith(
                color: AppColors.textGrey,
              ),
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
            Icon(Icons.error_outline, size: 40.r, color: AppColors.error),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
