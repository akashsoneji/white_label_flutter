import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/finance/presentation/pages/proof_viewer_screen.dart';

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

  /// Cards the user has opened; keyed by [_transactionKey].
  final Set<String> _expandedIds = <String>{};

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

  /// Display label for a transaction-type logic value.
  String _typeLabel(String type) {
    switch (type) {
      case 'All':
        return languageService.tr('common_all');
      case 'Deposit':
        return languageService.tr('common_deposit');
      case 'Withdrawal':
        return languageService.tr('general_withdrawal');
      case 'Fund Transfer':
        return languageService.tr('transaction_history_transaction_type_transfer');
    }
    return type;
  }

  /// Display label for a time-period logic value.
  String _periodLabel(String period) {
    switch (period) {
      case 'All Time':
        return languageService.tr('transaction_history_period_all_time');
      case 'Today':
        return languageService.tr('dc_range_today');
      case 'Last week':
        return languageService.tr('transaction_history_period_last_week');
      case 'This month':
        return languageService.tr('time_this_month');
      case 'Custom':
        return languageService.tr('transaction_history_period_custom');
    }
    return period;
  }

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
    List<Data> filtered =
        allTransactions.where((transaction) {
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
              DateTime.tryParse(transaction.createdAt ?? '')?.toLocal() ??
              DateTime.now();
          if (!_isTransactionInTimePeriod(transactionDate)) {
            return false;
          }

          return true;
        }).toList();

    filtered.sort((a, b) {
      final aDate =
          DateTime.tryParse(a.createdAt ?? '')?.toLocal() ?? DateTime.now();
      final bDate =
          DateTime.tryParse(b.createdAt ?? '')?.toLocal() ?? DateTime.now();
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

  /// Universal back handler used by BOTH the AppBar arrow and device/swipe
  /// back. If a normal push put us here, `Navigator.canPop()` is true and
  /// `Get.back()` returns to the origin.
  /// If the screen was reached via `Get.offAllNamed(...)` (Cregis flow wipes
  /// the stack), `canPop()` is false and we send the user to the dashboard.
  void _handleBack() {
    final args = Get.arguments;
    if (args != null && args is Map && args['from'] != null) {
      Get.offAllNamed(Routes.TRADING, arguments: 4);
      return;
    }
    if (Navigator.of(context).canPop()) {
      Get.back();
      return;
    }
    Get.offAllNamed(Routes.TRADING);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor:
            AppColors.isDarkMode
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
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: EdgeInsetsDirectional.only(start: 8.w),
        child: AppBackButton(
          onPressed: _handleBack,
        ),
      ),
      title: Text(
        languageService.tr('transaction_history'),
        style: AppTextStyles.bodyText.copyWith(
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
        final amount =
            double.tryParse(
              t.amount?.replaceAll(RegExp(r'[^\d.-]'), '') ?? '0',
            ) ??
            0;
        final isDeposit = (t.transactionType?.toLowerCase() ?? '').contains(
          'deposit',
        );

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
                label: languageService.tr('transaction_history_deposits'),
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
                label: languageService.tr('transaction_history_withdrawals'),
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
                style: AppTextStyles.bodyText.copyWith(
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
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            languageService.tr('transaction_history_screen_count_transactions', {
              'count': '$count',
            }),
            style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child:
          _filterExpanded
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
          children:
              timePeriods.asMap().entries.map((entry) {
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.textPrimary
                              : AppColors.whiteColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _periodLabel(period),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected
                                ? AppColors.whiteColor
                                : AppColors.textPrimary,
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
              label: languageService.tr('transaction_history_start'),
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
              label: languageService.tr('transaction_history_end'),
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
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  date != null ? _formatDate(date) : languageService.tr('common_select'),
                  style: AppTextStyles.bodyText.copyWith(
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
            languageService.tr('transaction_history_type_label'),
            style: AppTextStyles.bodyText.copyWith(
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
                children:
                    transactionTypes.asMap().entries.map((entry) {
                      final type = entry.value;
                      final isSelected = type == selectedTransactionType;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTransactionType = type;
                          });
                        },
                        child: Container(
                          margin: EdgeInsetsDirectional.only(end: 8.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.whiteColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.transparent
                                      : VantageUiTokens.borderColor,
                            ),
                          ),
                          child: Text(
                            _typeLabel(type),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected
                                      ? AppColors.whiteColor
                                      : AppColors.textSecondary,
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
          child: Center(child: CommonLoadingWidget(isFullScreen: false)),
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
              padding: EdgeInsetsDirectional.only(start: 4.w, bottom: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 16.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    languageService.tr('transaction_history_screen_recent_transactions'),
                    style: AppTextStyles.bodyText.copyWith(
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
      final dateKey = _formatDateHeader(
        DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now(),
      );

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
      return languageService.tr('dc_range_today');
    } else if (transactionDate == yesterday) {
      return languageService.tr('time_yesterday');
    } else {
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    }
  }

  static const List<String> _monthKeys = [
    'month_short_jan',
    'month_short_feb',
    'month_short_mar',
    'month_short_apr',
    'month_short_may',
    'month_short_jun',
    'month_short_jul',
    'month_short_aug',
    'month_short_sep',
    'month_short_oct',
    'month_short_nov',
    'month_short_dec',
  ];

  String _getMonthName(int month) {
    return languageService.tr(_monthKeys[month - 1]);
  }

  Widget _buildDateGroup(String dateLabel, List<Data> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: 4.w, top: 8.h, bottom: 10.h),
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
                style: AppTextStyles.bodyText.copyWith(
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
                  style: AppTextStyles.bodyText.copyWith(
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

  String _transactionKey(Data t) =>
      t.id ?? t.referenceNumber ?? '${t.createdAt}|${t.amount}';

  void _toggleExpanded(String key) {
    setState(() {
      if (!_expandedIds.remove(key)) _expandedIds.add(key);
    });
  }

  /// Account the money landed in (or left from): `WA#…` / `TA#…` label when
  /// the API sends one, else the raw account id.
  String _accountOf(Data t) {
    final label = (t.accountLabel ?? '').trim();
    return label.isNotEmpty ? label : (t.mt5AccountId ?? '').trim();
  }

  /// Same Source / Destination split as the web table: a deposit flows from
  /// the payment method into the account, a withdrawal the other way round,
  /// and a transfer between the user's own accounts.
  ({String source, String destination}) _flowOf(Data t) {
    final account = _accountOf(t);
    final method = (t.paymentMethod ?? '').trim();
    if (t.isInternalTransfer) {
      final from = (t.fromAccount ?? '').trim();
      final to = (t.toAccount ?? '').trim();
      return (
        source: from.isNotEmpty ? from : account,
        destination: to,
      );
    }
    final isWithdrawal =
        (t.transactionType ?? '').toLowerCase().contains('withdraw');
    return isWithdrawal
        ? (source: account, destination: method)
        : (source: method, destination: account);
  }

  Widget _buildModernTransactionCard(Data transaction) {
    final bool isDeposit = (transaction.transactionType?.toLowerCase() ?? '')
        .contains('deposit');
    final Color amountColor = isDeposit ? Colors.green : Colors.red;
    final String amountPrefix = isDeposit ? '+' : '-';
    final String statusText = (transaction.status ?? '').trim().toLowerCase();
    final bool isApproved = [
      'approved',
      'success',
      'completed',
    ].contains(statusText);

    Color statusColor() {
      if (isApproved) return Colors.green;
      if (statusText == 'rejected' || statusText == 'failed') return Colors.red;
      return Colors.orange;
    }

    IconData transactionIcon() {
      if ((transaction.transactionType?.toLowerCase() ?? '').contains(
        'deposit',
      )) {
        return Icons.arrow_downward_rounded;
      } else if ((transaction.transactionType?.toLowerCase() ?? '').contains(
        'withdraw',
      )) {
        return Icons.arrow_upward_rounded;
      }
      return Icons.swap_horiz_rounded;
    }

    final hasReceipt =
        controller.showProofColumn.value &&
        transaction.hasProof &&
        (transaction.id ?? '').isNotEmpty &&
        !(transaction.amount?.trim().startsWith('-') ?? false) &&
        (transaction.transactionType?.toLowerCase() ?? '') != 'withdrawal';

    final key = _transactionKey(transaction);
    final isExpanded = _expandedIds.contains(key);
    final account = _accountOf(transaction);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: VantageUiTokens.surface,
        borderRadius: BorderRadius.circular(VantageUiTokens.radiusMd),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withValues(alpha: 0.35)
              : VantageUiTokens.borderColor,
        ),
        boxShadow: VantageUiTokens.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(VantageUiTokens.radiusMd),
          onTap: () => _toggleExpanded(key),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Icon | Type + Date | Amount + Status
                Row(
                  children: [
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.transactionType ?? 'N/A',
                            style: AppTextStyles.bodyText.copyWith(
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
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$amountPrefix${transaction.amount ?? '0.00'}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            transaction.status ?? '',
                            style: AppTextStyles.bodyText.copyWith(
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
                SizedBox(height: 10.h),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: VantageUiTokens.borderColor,
                ),
                SizedBox(height: 10.h),
                // Row 2: Reference + Account | Proof | expand chevron
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
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.sp,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (account.isNotEmpty) ...[
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
                                account,
                                style: AppTextStyles.bodyText.copyWith(
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
                    if (hasReceipt) ...[
                      SizedBox(width: 8.w),
                      _buildProofButton(transaction.id!),
                    ],
                    SizedBox(width: 6.w),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: isExpanded
                      ? _buildTransactionDetails(transaction)
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProofButton(String transactionId) {
    return InkWell(
      onTap: () => Get.to(() => ProofViewerScreen(transactionId: transactionId)),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 12.sp,
              color: AppColors.primary,
            ),
            SizedBox(width: 4.w),
            Text(
              languageService.tr('transaction_history_view_proof'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Expanded part: Source → Destination, then every other web-table column
  /// that has a value. A value identical to one already shown (e.g. payment
  /// details repeating the method for commission rows) is not repeated.
  Widget _buildTransactionDetails(Data t) {
    final flow = _flowOf(t);
    final method = (t.paymentMethod ?? '').trim();
    final paymentDetails = (t.paymentDetails ?? '').trim();
    final transactionId = (t.transactionId ?? '').trim();
    final updatedAt = (t.updatedAt ?? '').trim();
    final reason = (t.rejectReason ?? '').trim();
    final comment = (t.commentForClient ?? '').trim();

    final showMethod = method.isNotEmpty &&
        method != flow.source &&
        method != flow.destination;
    final showPaymentDetails = paymentDetails.isNotEmpty &&
        paymentDetails != method;

    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (flow.source.isNotEmpty || flow.destination.isNotEmpty)
            _buildFlowBox(flow),
          if (showMethod)
            _buildDetailRow(
              languageService.tr('deposit_screen_payment_method'),
              method,
            ),
          if (transactionId.isNotEmpty)
            _buildDetailRow(
              languageService.tr('transaction_history_transaction_id'),
              transactionId,
              copyable: true,
            ),
          if (showPaymentDetails)
            _buildDetailRow(
              languageService.tr('wallet_screen_payment_details'),
              paymentDetails,
            ),
          if (updatedAt.isNotEmpty)
            _buildDetailRow(
              languageService.tr('transaction_history_updated_date'),
              _formatDateTime(updatedAt),
            ),
          if (reason.isNotEmpty)
            _buildNoteBox(
              icon: Icons.error_outline_rounded,
              color: Colors.red,
              text: '${languageService.tr('order_history_screen_reason')}: $reason',
            ),
          if (comment.isNotEmpty)
            _buildNoteBox(
              icon: Icons.chat_bubble_outline_rounded,
              color: AppColors.textSecondary,
              text: comment,
            ),
        ],
      ),
    );
  }

  Widget _buildFlowBox(({String source, String destination}) flow) {
    Widget side(String label, String value, {required bool alignEnd}) {
      return Expanded(
        child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              value.isEmpty ? '—' : value,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          side(
            languageService.tr('transaction_history_source'),
            flow.source,
            alignEnd: false,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16.sp,
              color: AppColors.primary,
            ),
          ),
          side(
            languageService.tr('transaction_history_destination'),
            flow.destination,
            alignEnd: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (copyable) ...[
            SizedBox(width: 6.w),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                CustomToastService.showSuccess(
                  message: languageService.tr('deposit_instruction_copied'),
                );
              },
              child: Icon(
                Icons.copy_rounded,
                size: 14.sp,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteBox({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 10.h),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                color: color,
              ),
            ),
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
            languageService.tr('transaction_history_no_transactions'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            languageService.tr('transaction_history_adjust_filters'),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textSecondary),
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
            label: Text(languageService.tr('transaction_history_screen_reset_filters'), style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(String dateStr) {
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return '';
    final day = date.day;
    final month = _getMonthName(date.month);
    final hour24 = date.hour;
    final hour = hour24 > 12 ? hour24 - 12 : (hour24 == 0 ? 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
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
