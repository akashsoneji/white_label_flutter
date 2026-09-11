import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/presentation/pages/internal_transfer_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/wallet/view_models/wallet_controller.dart';
import 'package:crm_app/utils/navigation_helper.dart';
import '../../../../services/language_service.dart';
import '../../../../widgets/common_loading_widget.dart';
import '../../../../widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletController controller = Get.put(WalletController());
  final LanguageService languageService = Get.find<LanguageService>();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200.h) {
        controller.loadMoreTransactions();
      }
    });
    // Trigger fresh load on enter
    controller.fetchWalletData();
    controller.fetchWalletHistory(page: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool checkIfDeposit(dynamic tx) {
    final String type = tx.transactionType?.toLowerCase() ?? '';
    final String amountStr = tx.amount?.toString() ?? '';
    if (type == 'deposit') return true;
    if (type == 'withdrawal') return false;
    return !amountStr.contains('-');
  }

  String formatAmount(dynamic amount, bool isDeposit) {
    if (amount == null) return '0.00';
    String amountStr = amount.toString();
    amountStr = amountStr.replaceAll('+', '').replaceAll('-', '').trim();
    String prefix = isDeposit ? '+' : '-';
    if (amountStr.startsWith('\$')) {
      return '$prefix$amountStr';
    }
    return '$prefix\$$amountStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: AppBackButton(
            onPressed: () => NavigationHelper.safeBack(context: context),
          ),
        ),
        title: Text(
          languageService.tr('wallet_title'),
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Obx(() {
              final isInitialLoading =
                  controller.isHistoryLoading.value &&
                  controller.historyTransactions.isEmpty;

              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Balance Card
                  SliverToBoxAdapter(child: _buildPremiumBalanceCard()),

                  // 2. Action buttons
                  SliverToBoxAdapter(child: _buildQuickActions()),

                  // 3. Filter Bar
                  SliverToBoxAdapter(child: _buildFilterBar()),

                  // 4. Initial Loading State
                  if (isInitialLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  // 5. Empty State
                  else if (controller.historyTransactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 40.w,
                            vertical: 40.h,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48.sp,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No transactions found',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  // 6. Transactions List
                  else ...[
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 8.h,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final tx = controller.historyTransactions[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _buildTransactionCard(tx),
                          );
                        }, childCount: controller.historyTransactions.length),
                      ),
                    ),

                    // 7. Load More Loading / No More Items Indicator at bottom
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: Center(
                          child:
                              controller.isLoadingMore.value
                                  ? CircularProgressIndicator(
                                    color: AppColors.primary,
                                  )
                                  : !controller.hasMore.value &&
                                      controller.historyTransactions.isNotEmpty
                                  ? Text(
                                    'No more transactions to show',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.sp,
                                    ),
                                  )
                                  : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),

          // Processing overlay (used for deposit, transfers)
          Obx(
            () =>
                controller.isLoading.value
                    ? CommonLoadingWidget(
                      message: languageService.tr('wallet_processing'),
                      size: 60.0,
                      color: AppColors.primary,
                      isFullScreen: true,
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBalanceCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          colors: [
            AppColors.isDarkMode
                ? AppColors.secondary.withOpacity(0.15)
                : AppColors.primary,
            AppColors.isDarkMode
                ? AppColors.secondary.withOpacity(0.15)
                : AppColors.primary.withOpacity(0.85),
            AppColors.isDarkMode
                ? AppColors.secondary.withOpacity(0.15)
                : AppColors.secondary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDarkMode
                ? Colors.black.withOpacity(0.4)
                : AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
          // Background circles decoration
          Positioned(
            right: -20.w,
            top: -20.h,
            child: CircleAvatar(
              radius: 60.r,
              backgroundColor:
                  AppColors.isDarkMode
                      ? AppColors.secondary.withOpacity(0.15)
                      : Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            left: -40.w,
            bottom: -40.h,
            child: CircleAvatar(
              radius: 80.r,
              backgroundColor:
                  AppColors.isDarkMode
                      ? AppColors.secondary.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageService.tr('wallet_title').toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white.withOpacity(0.8),
                      size: 24.sp,
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Obx(
                  () => Text(
                    '\$${controller.balance.value}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageService.tr('wallet_wallet_id'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 10.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Obx(
                          () => Row(
                            children: [
                              Text(
                                controller.wallet.value?.walletId ?? '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () {
                                  final walletId =
                                      controller.wallet.value?.walletId ?? '';
                                  if (walletId.isNotEmpty) {
                                    Clipboard.setData(
                                      ClipboardData(text: walletId),
                                    );
                                    CustomToastService.showSuccess(
                                      message: TranslationUtils.tr(
                                        'wallet_screen_wallet_id_copied',
                                      ),
                                    );
                                  }
                                },
                                child: Icon(
                                  Icons.copy,
                                  size: 14.sp,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildQuickActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: languageService.tr('wallet_deposit_wallet'),
              icon: Icons.add_circle_outline,
              onPressed: () {
                Get.to(() => PaymentMethodsScreen(accountNumber: ''));
              },
              isPrimary: true,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: _buildActionButton(
              label: languageService.tr('internal_transfer'),
              icon: Icons.swap_horiz,
              onPressed: () {
                Get.to(() => InternalTransferScreen());
              },
              isPrimary: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark || AppColors.isDarkMode;
    return Container(
      height: 48.h,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18.sp,
          color: isPrimary ? AppColors.onPrimary : AppColors.primary,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: isPrimary ? AppColors.onPrimary : AppColors.primary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary
                  ? AppColors.primary
                  : isDark
                  ? AppColors.textFieldBg
                  : AppColors.primary.withOpacity(0.08),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side:
                isPrimary
                    ? BorderSide.none
                    : BorderSide(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1,
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Obx(() {
      final List<Widget> chips = [];

      if (controller.filterType.value != 'All Types') {
        chips.add(
          _buildFilterChip(
            label: 'Type: ${controller.filterType.value}',
            onDeleted: () {
              controller.filterType.value = 'All Types';
              controller.applyFilters();
            },
          ),
        );
      }

      if (controller.filterStatus.value != 'All Status') {
        chips.add(
          _buildFilterChip(
            label: 'Status: ${controller.filterStatus.value}',
            onDeleted: () {
              controller.filterStatus.value = 'All Status';
              controller.applyFilters();
            },
          ),
        );
      }

      if (controller.filterDateFrom.value.isNotEmpty ||
          controller.filterDateTo.value.isNotEmpty) {
        final from =
            controller.filterDateFrom.value.isNotEmpty
                ? controller.filterDateFrom.value
                : 'Any';
        final to =
            controller.filterDateTo.value.isNotEmpty
                ? controller.filterDateTo.value
                : 'Any';
        chips.add(
          _buildFilterChip(
            label: '$from to $to',
            onDeleted: () {
              controller.filterDateFrom.value = '';
              controller.filterDateTo.value = '';
              controller.applyFilters();
            },
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        child: Row(
          children: [
            InkWell(
              onTap: _showFilterBottomSheet,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      size: 16.sp,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child:
                  chips.isEmpty
                      ? Text(
                        'All Transactions',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      )
                      : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              chips
                                  .map(
                                    (c) => Padding(
                                      padding: EdgeInsets.only(right: 6.w),
                                      child: c,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
            ),
            if (chips.isNotEmpty) ...[
              SizedBox(width: 6.w),
              GestureDetector(
                onTap: controller.clearFilters,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.textFieldBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: onDeleted,
            child: Icon(
              Icons.close,
              size: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    final localType = controller.filterType.value.obs;
    final localStatus = controller.filterStatus.value.obs;
    final localDateFrom = controller.filterDateFrom.value.obs;
    final localDateTo = controller.filterDateTo.value.obs;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24.w,
            24.h,
            24.w,
            MediaQuery.of(context).padding.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Transactions',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Divider(color: AppColors.divider),
              SizedBox(height: 16.h),
              Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _buildDateField(
                        label: 'From Date',
                        value: localDateFrom.value,
                        onTap: () async {
                          final picked = await _pickDate(context);
                          if (picked != null) localDateFrom.value = picked;
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Obx(
                      () => _buildDateField(
                        label: 'To Date',
                        value: localDateTo.value,
                        onTap: () async {
                          final picked = await _pickDate(context);
                          if (picked != null) localDateTo.value = picked;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Obx(
                          () => _buildFilterDropdownWidget(
                            value: localType.value,
                            options: [
                              'All Types',
                              'Deposit',
                              'Withdrawal',
                              'Transfer',
                            ],
                            onChanged: (val) {
                              if (val != null) localType.value = val;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Obx(
                          () => _buildFilterDropdownWidget(
                            value: localStatus.value,
                            options: [
                              'All Status',
                              'Approved',
                              'Pending',
                              'Rejected',
                            ],
                            onChanged: (val) {
                              if (val != null) localStatus.value = val;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        localType.value = 'All Types';
                        localStatus.value = 'All Status';
                        localDateFrom.value = '';
                        localDateTo.value = '';
                      },
                      child: Text(
                        'Reset Filters',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        controller.filterType.value = localType.value;
                        controller.filterStatus.value = localStatus.value;
                        controller.filterDateFrom.value = localDateFrom.value;
                        controller.filterDateTo.value = localDateTo.value;
                        controller.applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _pickDate(BuildContext context) async {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark || AppColors.isDarkMode;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                isDark
                    ? ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: Colors.black,
                      surface: AppColors.cardBackground,
                      onSurface: AppColors.textPrimary,
                    )
                    : ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.cardBackground,
                      onSurface: AppColors.textPrimary,
                    ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      return DateFormat('yyyy-MM-dd').format(picked);
    }
    return null;
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.textFieldBg,
          border: Border.all(color: AppColors.border.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? label : value,
                style: TextStyle(
                  fontSize: 12.sp,
                  color:
                      value.isEmpty
                          ? AppColors.textGrey
                          : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.calendar_today, size: 14.sp, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdownWidget({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.textFieldBg,
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: AppColors.cardBackground,
          value: options.contains(value) ? value : options.first,
          items:
              options.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTransactionCard(dynamic tx) {
    final bool isDeposit = checkIfDeposit(tx);
    final bool isApproved = tx.status?.toLowerCase() == 'approved';
    final bool isRejected = tx.status?.toLowerCase() == 'rejected';
    final String amountText = formatAmount(tx.amount, isDeposit);

    IconData iconData;
    Color iconColor;
    Color iconBgColor;

    final String typeStr = tx.transactionType?.toLowerCase() ?? '';
    if (typeStr == 'deposit') {
      iconData = Icons.arrow_downward;
      iconColor = const Color(0xFF22C55E);
      iconBgColor = const Color(0xFF22C55E).withOpacity(0.1);
    } else if (typeStr == 'withdrawal') {
      iconData = Icons.arrow_upward;
      iconColor = const Color(0xFFEF4444);
      iconBgColor = const Color(0xFFEF4444).withOpacity(0.1);
    } else {
      iconData = Icons.swap_horiz;
      iconColor = const Color(0xFF3478F6);
      iconBgColor = const Color(0xFF3478F6).withOpacity(0.1);
    }

    Color statusTextColor;
    Color statusBgColor;
    if (isApproved) {
      statusTextColor = const Color(0xFF15803D);
      statusBgColor = const Color(0xFFECFDF5);
    } else if (isRejected) {
      statusTextColor = const Color(0xFFB91C1C);
      statusBgColor = const Color(0xFFFEF2F2);
    } else {
      statusTextColor = const Color(0xFFB45309);
      statusBgColor = const Color(0xFFFFFBEB);
    }

    return InkWell(
      onTap: () => _showTransactionDetails(tx),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.border.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 20.sp, color: iconColor),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.transactionType ?? 'Transaction',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    tx.referenceNumber ?? 'N/A',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (tx.paymentDetails != null &&
                      tx.paymentDetails!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      tx.paymentDetails!,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: 4.h),
                  Text(
                    tx.createdAt != null
                        ? (() {
                          final parsedDate = DateTime.tryParse(tx.createdAt!);
                          if (parsedDate != null) {
                            return DateFormat(
                              'MMM dd, yyyy hh:mm a',
                            ).format(parsedDate.toLocal());
                          }
                          return tx.createdAt!;
                        })()
                        : '',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color:
                        isDeposit
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    (tx.status ?? 'PENDING').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(dynamic tx) {
    final bool isDeposit = checkIfDeposit(tx);
    final bool isApproved = tx.status?.toLowerCase() == 'approved';
    final bool isRejected = tx.status?.toLowerCase() == 'rejected';
    final String amountText = formatAmount(tx.amount, isDeposit);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24.w,
            24.h,
            24.w,
            MediaQuery.of(context).padding.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Divider(color: AppColors.divider),
              SizedBox(height: 16.h),
              Center(
                child: Column(
                  children: [
                    Text(
                      amountText,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        color:
                            isDeposit
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isApproved
                                ? const Color(0xFFECFDF5)
                                : isRejected
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color:
                              isApproved
                                  ? const Color(0xFFBBF7D0)
                                  : isRejected
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFFEF3C7),
                        ),
                      ),
                      child: Text(
                        (tx.status ?? 'PENDING').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color:
                              isApproved
                                  ? const Color(0xFF15803D)
                                  : isRejected
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              _buildDetailRow('Reference Number', tx.referenceNumber ?? 'N/A'),
              _buildDetailRow('Transaction Type', tx.transactionType ?? 'N/A'),
              _buildDetailRow('Payment Method', tx.paymentMethod ?? 'N/A'),
              _buildDetailRow(
                'Account/Wallet',
                tx.mt5AccountId != null && tx.mt5AccountId.toString().isNotEmpty
                    ? 'MT5: ${tx.mt5AccountId}'
                    : 'Wallet',
              ),
              _buildDetailRow(
                'Date & Time',
                tx.createdAt != null
                    ? (() {
                      final parsedDate = DateTime.tryParse(tx.createdAt!);
                      if (parsedDate != null) {
                        return DateFormat(
                          'MMMM dd, yyyy hh:mm a',
                        ).format(parsedDate.toLocal());
                      }
                      return tx.createdAt!;
                    })()
                    : 'N/A',
              ),
              if (tx.paymentDetails != null && tx.paymentDetails!.isNotEmpty)
                _buildDetailRow('Payment Details', tx.paymentDetails!),

              if (tx.proofUrl != null && tx.proofUrl!.isNotEmpty) ...[
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final Uri uri = Uri.parse(tx.proofUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        CustomToastService.showError(
                          message: 'Could not open proof link',
                        );
                      }
                    },
                    icon: Icon(Icons.receipt_long, color: AppColors.onPrimary),
                    label: Text(
                      'View Proof',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class ExampleNavigationScreen extends StatelessWidget {
  const ExampleNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Get.to(() => WalletScreen()),
          child: Text(languageService.tr('wallet_open_wallet')),
        ),
      ),
    );
  }
}
