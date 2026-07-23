import 'package:crm_app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';
// import 'package:flutter_svg/svg.dart' as Assets;
import 'package:get/get.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_settings_controller.dart';

class CopyTradingWalletScreen extends StatelessWidget {
  const CopyTradingWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CopyTradingSettingsController>();

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Wallet',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: IconButton(
            icon: Icon(
              Icons.grid_view_rounded,
              color: AppColors.textPrimary,
              size: 24.r,
            ),
            onPressed: () => Get.back(),
          ),
        ),
        actions: [
          Obx(
            () =>
                controller.selectedWalletTab.value == 1
                    ? IconButton(
                      icon: Icon(
                        Icons.filter_alt_outlined,
                        color: AppColors.textPrimary,
                        size: 24.r,
                      ),
                      onPressed: () => _showFilterSheet(context, controller),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          children: [
            SizedBox(height: 16.h),
            // Balance Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 32.h),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Balance',
                    style: AppTextStyles.subheading.copyWith(
                      color: AppColors.textGrey,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Obx(
                    () => Text(
                      controller.walletBalance.value,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Tabs (Actions, History, About)
            Row(
              children: [
                _buildTab(context, 'Actions', 0, controller),
                SizedBox(width: 8.w),
                _buildTab(context, 'History', 1, controller),
                SizedBox(width: 8.w),
                _buildTab(context, 'About', 2, controller),
              ],
            ),

            SizedBox(height: 16.h),

            // Tab Content
            Expanded(
              child: Obx(() {
                if (controller.selectedWalletTab.value == 0) {
                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _ActionItem(
                        iconData: Icons.add_circle_outline_rounded,
                        label: 'Deposit',
                        onTap: () => Get.toNamed(AppPages.FINANCE),
                      ),
                      _ActionItem(
                        iconData: Icons.arrow_circle_up_rounded,
                        label: 'Withdrawal',
                        onTap: () {},
                      ),
                      _ActionItem(
                        iconData: Icons.swap_horizontal_circle_outlined,
                        label: 'Internal Transfer',
                        onTap:
                            () =>
                                Get.toNamed('/copy-trading-internal-transfer'),
                      ),
                      _ActionItem(
                        iconData: Icons.history_rounded,
                        label: 'Internal Transfer History',
                        onTap: () {},
                      ),
                    ],
                  );
                } else if (controller.selectedWalletTab.value == 1) {
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: controller.transactions.length,
                    separatorBuilder:
                        (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      return _HistoryItem(
                        transaction: controller.transactions[index],
                      );
                    },
                  );
                } else {
                  return _AboutTabContent();
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    CopyTradingSettingsController controller,
  ) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: AppTextStyles.heading.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20.sp,
                  ),
                ),
                GestureDetector(
                  onTap: () => controller.resetFilters(),
                  child: Text(
                    'Reset all',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _FilterOption(
              label: 'Transaction Type',
              onTap:
                  () => _showSelectionSheet(
                    context,
                    'Transaction Type',
                    ['All', 'Withdrawal', 'Deposit', 'Copytrading'],
                    controller.selectedTransactionType,
                    controller,
                  ),
            ),
            _FilterOption(
              label: 'Status',
              onTap:
                  () => _showSelectionSheet(
                    context,
                    'Status',
                    ['All', 'Complete', 'Pending', 'Rejected', 'Cancelled'],
                    controller.selectedStatus,
                    controller,
                  ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ).copyWith(
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                ),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectionSheet(
    BuildContext context,
    String title,
    List<String> options,
    RxString selectedValue,
    CopyTradingSettingsController controller,
  ) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTextStyles.heading.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20.sp,
                  ),
                ),
                GestureDetector(
                  onTap: () => controller.resetFilters(),
                  child: Text(
                    'Reset all',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...options.map(
              (option) => Obx(() {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _getOptionIcon(option),
                  title: Text(option, style: AppTextStyles.label),
                  trailing: Radio<String>(
                    value: option,
                    groupValue: selectedValue.value,
                    onChanged: (val) {
                      selectedValue.value = val!;
                      Get.back();
                    },
                    activeColor: AppColors.primary,
                  ),
                  onTap: () {
                    selectedValue.value = option;
                    Get.back();
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getOptionIcon(String option) {
    IconData icon;
    switch (option) {
      case 'All':
        icon = Icons.grid_view_rounded;
        break;
      case 'Withdrawal':
        icon = Icons.arrow_circle_up_rounded;
        break;
      case 'Deposit':
        icon = Icons.arrow_circle_down_rounded;
        break;
      case 'Copytrading':
        icon = Icons.copy_rounded;
        break;
      case 'Complete':
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'Pending':
        icon = Icons.access_time_rounded;
        break;
      case 'Rejected':
        icon = Icons.do_not_disturb_on_outlined;
        break;
      case 'Cancelled':
        icon = Icons.cancel_outlined;
        break;
      default:
        icon = Icons.circle_outlined;
    }
    return Icon(icon, color: AppColors.textPrimary, size: 22.r);
  }

  Widget _buildTab(
    BuildContext context,
    String label,
    int index,
    CopyTradingSettingsController controller,
  ) {
    return Expanded(
      child: Obx(() {
        final isSelected = controller.selectedWalletTab.value == index;
        return GestureDetector(
          onTap: () => controller.selectedWalletTab.value = index,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.whiteColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color:
                    isSelected
                        ? AppColors.primary
                        : AppColors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: isSelected ? AppColors.whiteColor : AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16.r,
        color: AppColors.textGrey,
      ),
      onTap: onTap,
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final WalletTransaction transaction;

  const _HistoryItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isExpanded = transaction.isExpanded.value;
      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withValues(alpha: 0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => transaction.isExpanded.toggle(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _getServiceIcon(transaction.type),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              transaction.type,
                              style: AppTextStyles.black14600,
                            ),
                            Text(
                              transaction.date,
                              style: AppTextStyles.grey10400.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check,
                                  color: AppColors.success,
                                  size: 16.r,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  transaction.title,
                                  style: AppTextStyles.grey11400,
                                ),
                              ],
                            ),
                            Text(
                              transaction.amount,
                              style: AppTextStyles.label.copyWith(
                                color:
                                    transaction.isNegative
                                        ? AppColors.error
                                        : AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textPrimary,
                    size: 24.r,
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              SizedBox(height: 16.h),
              Divider(height: 1, color: AppColors.border.withValues(alpha: 0.1)),
              SizedBox(height: 12.h),
              _DetailRow(label: 'Status', value: transaction.status),
              _DetailRow(label: 'Request ID', value: transaction.requestId),
              _DetailRow(label: 'Account', value: transaction.account),
              if (transaction.paymentMethod != null)
                _DetailRow(
                  label: 'Payment method',
                  value: transaction.paymentMethod!,
                ),
              if (transaction.senderName != null)
                _DetailRow(
                  label: 'Sender name',
                  value: transaction.senderName!,
                ),
              if (transaction.paymentCreated != null)
                _DetailRow(
                  label: 'Payment created',
                  value: transaction.paymentCreated!,
                ),
              if (transaction.created != null)
                _DetailRow(label: 'Created', value: transaction.created!),
              if (transaction.processedOn != null)
                _DetailRow(
                  label: 'Processed on',
                  value: transaction.processedOn!,
                ),
              if (transaction.creditedAmount != null)
                _DetailRow(
                  label: 'Credited amount',
                  value: transaction.creditedAmount!,
                ),
            ],
          ],
        ),
      );
    });
  }

  Widget _getServiceIcon(String type) {
    if (type == 'Copytrading') {
      return Icon(Icons.hub_outlined, color: AppColors.textPrimary, size: 24.r);
    } else if (type == 'USDT') {
      return Container(
        padding: EdgeInsets.all(4.r),
        decoration: const BoxDecoration(
          color: AppColors.quickActionGreen,
          shape: BoxShape.circle,
        ),
        child: Text(
          'T',
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.whiteColor,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Icon(Icons.wallet_rounded, color: AppColors.textPrimary, size: 24.r);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.grey14400h57),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                '..........................................................................................................................................',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: AppTextStyles.bodyText.copyWith(color: AppColors.border.withValues(alpha: 0.3)),
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _AboutTabContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          'We create Wallet for all our clients.',
          style: AppTextStyles.headingblack,
        ),
        SizedBox(height: 16.h),
        _AboutItem(
          svg: 'assets/svg/copy_trading/investment/wallet.svg',
          icon: Icons.account_balance_wallet_outlined,
          title: 'For Everyone',
          description:
              'Use it to make internal transfer, deposits and withdrawals.',
        ),
        _AboutItem(
          icon: Icons.share_outlined,
          title: 'For Copier',
          description:
              'Use the wallet to parcel your investment between masters.',
        ),
        _AboutItem(
          svg: 'assets/svg/copy_trading/investment/coin.svg',
          icon: Icons.layers_outlined,
          title: 'For Masters',
          description: 'Get your commission payouts to the wallet.',
        ),
      ],
    );
  }
}

class _AboutItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String svg;

  const _AboutItem({
    required this.icon,
    required this.title,
    required this.description,
    this.svg = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          (svg.isBlank == true)
              ? Icon(icon, color: AppColors.textPrimary, size: 22.w)
              : SvgPicture.asset(
                svg,
                height: 22.w,
                width: 22.w,
                colorFilter: ColorFilter.mode(
                  AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: AppTextStyles.grey14400h57.copyWith(fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData iconData;
  final String label;
  final VoidCallback onTap;

  const _ActionItem({
    required this.iconData,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(iconData, color: AppColors.primary, size: 28.r),
          title: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16.r,
            color: AppColors.textGrey,
          ),
          onTap: onTap,
        ),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.1)),
      ],
    );
  }
}
