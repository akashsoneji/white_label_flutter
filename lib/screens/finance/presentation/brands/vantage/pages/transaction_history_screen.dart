import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/finance/view_models/transaction_history_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/utils/app_picker_theme.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/screens/home/brands/vantage/vantage_glass_tokens.dart';

class VantageTransactionHistoryScreen extends StatefulWidget {
  const VantageTransactionHistoryScreen({super.key});

  @override
  State<VantageTransactionHistoryScreen> createState() =>
      _VantageTransactionHistoryScreenState();
}

class _VantageTransactionHistoryScreenState
    extends State<VantageTransactionHistoryScreen>
    with TickerProviderStateMixin {
  String selectedAccount = 'All';
  DateTime selectedDate = DateTime(2001, 1, 25);
  String selectedTransactionType = 'All';
  String selectedTimePeriod = 'All Time';
  DateTime? customStartDate;
  DateTime? customEndDate;
  final controller = Get.put(TransactionHistoryController());

  late final LanguageService languageService;

  late AnimationController _filterAnimationController;
  bool _filterExpanded = true;

  final List<String> transactionTypes = [
    'All',
    'Deposit',
    'Withdrawal',
    'Fund Transfer',
  ];

  final List<String> timePeriods = [
    'All Time',
    'Today',
    'Last week',
    'This month',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    languageService = Get.find<LanguageService>();
    controller.fetchUserTransactions();

    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _toggleFilter() {
    setState(() {
      _filterExpanded = !_filterExpanded;
      if (_filterExpanded) {
        _filterAnimationController.reverse();
      } else {
        _filterAnimationController.forward();
      }
    });
  }

  List<Data> _computeFilteredTransactions(List<Data> allTransactions) {
    List<Data> filtered = allTransactions.where((transaction) {
      if (selectedAccount != 'All' &&
          (transaction.mt5AccountId ?? '') != selectedAccount) {
        return false;
      }

      if (selectedTransactionType != 'All' &&
          (transaction.transactionType?.toLowerCase() ?? '') !=
              selectedTransactionType.toLowerCase()) {
        return false;
      }

      final transactionDate =
          DateTime.tryParse(transaction.createdAt ?? '') ?? DateTime.now();
      if (!_isTransactionInTimePeriod(transactionDate)) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAt ?? '') ?? DateTime.now();
      final bDate = DateTime.tryParse(b.createdAt ?? '') ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  bool _isTransactionInTimePeriod(DateTime transactionDate) {
    final now = DateTime.now();

    switch (selectedTimePeriod) {
      case 'Today':
        return transactionDate.year == now.year &&
            transactionDate.month == now.month &&
            transactionDate.day == now.day;

      case 'Last week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return transactionDate.isAfter(weekAgo) &&
            transactionDate.isBefore(now.add(const Duration(days: 1)));

      case 'This month':
        return transactionDate.year == now.year &&
            transactionDate.month == now.month;

      case 'Custom':
        if (customStartDate == null || customEndDate == null) return true;
        return transactionDate.isAfter(
              customStartDate!.subtract(const Duration(days: 1)),
            ) &&
            transactionDate.isBefore(
              customEndDate!.add(const Duration(days: 1)),
            );

      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        backgroundColor: AppColors.isDarkMode
            ? AppColors.backgroundDarkAlt
            : AppColors.backgroundLightAlt,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => controller.fetchUserTransactions(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  _buildSummarySection(),
                  SizedBox(height: 16.h),
                  _buildFilterSection(),
                  SizedBox(height: 20.h),
                  _buildTransactionList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: EdgeInsets.only(left: 8.w),
        child: AppBackButton(
          onPressed: () {
            final fromTab =
                Get.arguments != null && Get.arguments['from'] != null
                    ? Get.arguments['from']
                    : 'dashboard';
            if (fromTab == 'finance') {
              Get.back();
            } else {
              Get.offAllNamed(Routes.TRADING);
            }
          },
        ),
      ),
      title: Text(
        languageService.tr('transaction_history'),
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _toggleFilter,
          icon: AnimatedRotation(
            turns: _filterExpanded ? 0 : 0.5,
            duration: const Duration(milliseconds: 300),
            child: Icon(
              Icons.tune_rounded,
              color: AppColors.primary,
              size: 22.sp,
            ),
          ),
        ),
        SizedBox(width: 8.w),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Obx(() {
      final allTransactions = controller.userTransactions;
      final filtered = _computeFilteredTransactions(allTransactions);

      double totalDeposits = 0;
      double totalWithdrawals = 0;
      int depositCount = 0;
      int withdrawalCount = 0;

      for (final t in filtered) {
        final amount = double.tryParse(
                t.amount?.replaceAll(RegExp(r'[^\d.-]'), '') ?? '0') ??
            0;
        final isDeposit =
            (t.transactionType?.toLowerCase() ?? '').contains('deposit');

        if (isDeposit) {
          totalDeposits += amount;
          depositCount++;
        } else {
          totalWithdrawals += amount;
          withdrawalCount++;
        }
      }

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        padding: EdgeInsets.all(20.w),
        decoration: VantageUiTokens.cardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                label: 'Deposits',
                value: '\$${totalDeposits.toStringAsFixed(2)}',
                count: depositCount,
                icon: Icons.arrow_downward_rounded,
                color: Colors.green,
                bgColor: Colors.green.withValues(alpha: 0.1),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildSummaryItem(
                label: 'Withdrawals',
                value: '\$${totalWithdrawals.toStringAsFixed(2)}',
                count: withdrawalCount,
                icon: Icons.arrow_upward_rounded,
                color: Colors.red,
                bgColor: Colors.red.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '$count transactions',
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _filterExpanded
          ? Container(
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  _buildTimePeriodChips(),
                  SizedBox(height: 12.h),
                  if (selectedTimePeriod == 'Custom') ...[
                    _buildCustomDateRange(),
                    SizedBox(height: 12.h),
                  ],
                  _buildTransactionTypeSelector(),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildTimePeriodChips() {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: VantageUiTokens.pillDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: timePeriods.asMap().entries.map((entry) {
            final period = entry.value;
            final isSelected = period == selectedTimePeriod;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedTimePeriod = period;
                  if (period != 'Custom') {
                    customStartDate = null;
                    customEndDate = null;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomDateRange() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: VantageUiTokens.groupDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _buildDatePickerButton(
              label: 'Start',
              date: customStartDate,
              onTap: () => _showCustomDatePicker(true),
            ),
          ),
          Container(
            width: 1,
            height: 40.h,
            color: AppColors.border,
            margin: EdgeInsets.symmetric(horizontal: 12.w),
          ),
          Expanded(
            child: _buildDatePickerButton(
              label: 'End',
              date: customEndDate,
              onTap: () => _showCustomDatePicker(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14.sp,
              color: AppColors.primary,
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  date != null ? _formatDate(date) : 'Select',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: VantageUiTokens.groupDecoration(),
      child: Row(
        children: [
          Text(
            'Type:',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: transactionTypes.asMap().entries.map((entry) {
                  final type = entry.value;
                  final isSelected = type == selectedTransactionType;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTransactionType = type;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: 8.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : VantageUiTokens.borderColor,
                        ),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return Obx(() {
      if (controller.isLoading) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 60.h),
          child: const Center(child: CommonLoadingWidget(isFullScreen: false)),
        );
      }

      final allTransactions = controller.userTransactions;
      final transactions = _computeFilteredTransactions(allTransactions);

      if (transactions.isEmpty) {
        return _buildEmptyState();
      }

      final groupedTransactions = _groupTransactionsByDate(transactions);

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 16.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ...groupedTransactions.entries.map((entry) {
              return _buildDateGroup(entry.key, entry.value);
            }),
            SizedBox(height: 30.h),
          ],
        ),
      );
    });
  }

  Map<String, List<Data>> _groupTransactionsByDate(List<Data> transactions) {
    final Map<String, List<Data>> grouped = {};

    for (final transaction in transactions) {
      final dateStr = transaction.createdAt ?? '';
      final dateKey =
          _formatDateHeader(DateTime.tryParse(dateStr) ?? DateTime.now());

      if (grouped.containsKey(dateKey)) {
        grouped[dateKey]!.add(transaction);
      } else {
        grouped[dateKey] = [transaction];
      }
    }

    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildDateGroup(String dateLabel, List<Data> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, top: 8.h, bottom: 10.h),
          child: Row(
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${transactions.length}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...transactions.map((t) => _buildModernTransactionCard(t)),
      ],
    );
  }

  Widget _buildModernTransactionCard(Data transaction) {
    final bool isDeposit = (transaction.transactionType?.toLowerCase() ?? '')
        .contains('deposit');
    final Color amountColor = isDeposit ? Colors.green : Colors.red;
    final String amountPrefix = isDeposit ? '+' : '-';
    final String statusText = (transaction.status ?? '').trim().toLowerCase();
    final bool isApproved = ['approved', 'success', 'completed'].contains(statusText);

    Color statusColor() {
      if (isApproved) return Colors.green;
      if (statusText == 'rejected' || statusText == 'failed') return Colors.red;
      return Colors.orange;
    }

    IconData transactionIcon() {
      if ((transaction.transactionType?.toLowerCase() ?? '').contains('deposit')) {
        return Icons.arrow_downward_rounded;
      } else if ((transaction.transactionType?.toLowerCase() ?? '')
          .contains('withdraw')) {
        return Icons.arrow_upward_rounded;
      }
      return Icons.swap_horiz_rounded;
    }

    final hasReceipt = (transaction.id ?? '').isNotEmpty &&
        !(transaction.amount?.trim().startsWith('-') ?? false) &&
        (transaction.transactionType?.toLowerCase() ?? '') != 'withdrawal';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: VantageUiTokens.surface,
        borderRadius: BorderRadius.circular(VantageUiTokens.radiusMd),
        border: Border.all(color: VantageUiTokens.borderColor),
        boxShadow: VantageUiTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon | Type + Date | Amount + Download
          Row(
            children: [
              // Icon
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    transactionIcon(),
                    color: amountColor,
                    size: 20.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Type and Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.transactionType ?? 'N/A',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _formatDateTime(transaction.createdAt ?? ''),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '$amountPrefix${transaction.amount ?? '0.00'}',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              if (hasReceipt) ...[
                SizedBox(width: 10.w),
                GestureDetector(
                  onTap: () => controller.viewReceipt(transaction.id!),
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      size: 16.sp,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          // Row 2: Reference + Account | Status
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_outlined,
                      size: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        transaction.referenceNumber ?? 'N/A',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if ((transaction.mt5AccountId ?? '').isNotEmpty) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transaction.mt5AccountId!,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.w,
                  vertical: 3.h,
                ),
                decoration: BoxDecoration(
                  color: statusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  transaction.status ?? '',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: statusColor(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.all(40.w),
      decoration: VantageUiTokens.cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 40.sp,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'No Transactions Found',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try adjusting your filters to find more transactions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 24.h),
          TextButton.icon(
            onPressed: () {
              setState(() {
                selectedTimePeriod = 'All Time';
                selectedTransactionType = 'All';
                customStartDate = null;
                customEndDate = null;
              });
            },
            icon: Icon(Icons.refresh_rounded, size: 16.sp),
            label: Text(
              'Reset Filters',
              style: TextStyle(fontSize: 13.sp),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final day = date.day;
    final month = _getMonthName(date.month);
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month, $hour:$minute $period';
  }


  void _showCustomDatePicker(bool isStartDate) async {
    final DateTime? picked = await AppPickerTheme.showAppDatePicker(
      context,
      initialDate:
          isStartDate
              ? (customStartDate ??
                  DateTime.now().subtract(const Duration(days: 30)))
              : (customEndDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          customStartDate = picked;
          if (customEndDate != null && customEndDate!.isBefore(picked)) {
            customEndDate = null;
          }
        } else {
          customEndDate = picked;
          if (customStartDate != null && customStartDate!.isAfter(picked)) {
            customStartDate = null;
          }
        }
      });
    }
  }
}