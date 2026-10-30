import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/utils/trl_helper.dart';
import '../../../../constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/transaction_history_controller.dart';
import '../../../../routes/app_pages.dart';
import '../../../../services/language_service.dart';
import '../../../../widgets/common_loading_widget.dart';
import 'package:crm_app/utils/app_picker_theme.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String selectedAccount = 'All';
  DateTime selectedDate = DateTime(2001, 1, 25);
  String selectedTransactionType = 'All';
  String selectedTimePeriod = 'All Time';
  DateTime? customStartDate;
  DateTime? customEndDate;
  final controller = Get.put(TransactionHistoryController());

  late final LanguageService languageService;

  @override
  void initState() {
    super.initState();
    languageService = Get.find<LanguageService>();
    controller.fetchUserTransactions(); // fetch on load
  }

  Widget _buildChip({
    required String text,
    required Color border,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      constraints: BoxConstraints(minHeight: 24.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  String _formatType(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final v = raw.toLowerCase();
    if (v == 'mt5') return 'MT5';
    if (v == 'wallet') return languageService.tr('wallet');
    // Title-case fallback
    return v
        .split('_')
        .join(' ')
        .split(' ')
        .map(
          (w) =>
              w.isEmpty
                  ? w
                  : w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''),
        )
        .join(' ');
  }

  // final List<String> accounts = [
  //   'All',
  //   'MT5 Account',
  //   'app Account',
  //   'Wallet',
  // ];
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

  // Compute filtered transactions - must be called inside Obx
  List<Data> _computeFilteredTransactions(List<Data> allTransactions) {
    List<Data> filtered =
        allTransactions.where((transaction) {
          // Filter by account
          if (selectedAccount != 'All' &&
              (transaction.mt5AccountId ?? '') != selectedAccount) {
            return false;
          }

          // Filter by transaction type
          if (selectedTransactionType != 'All' &&
              (transaction.transactionType?.toLowerCase() ?? '') !=
                  selectedTransactionType.toLowerCase()) {
            return false;
          }

          // Filter by time period
          final transactionDate =
              DateTime.tryParse(transaction.createdAt ?? '')?.toLocal() ?? DateTime(1970);
          if (!_isTransactionInTimePeriod(transactionDate)) {
            return false;
          }

          return true;
        }).toList();

    // Sort by newest first
    filtered.sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAt ?? '')?.toLocal() ?? DateTime(1970);
      final bDate = DateTime.tryParse(b.createdAt ?? '')?.toLocal() ?? DateTime(1970);
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

  /// Universal back handler for BOTH the AppBar arrow and device/swipe back.
  /// If this screen was pushed normally the
  /// navigator can pop, so return to the origin. If it was reached via
  /// `Get.offAllNamed` (the Cregis deposit flow wipes the stack), there is
  /// nothing to pop, so land on the dashboard.
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
        backgroundColor: AppColors.whiteColor,
        appBar: AppBar(
          backgroundColor: AppColors.whiteColor,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: Padding(
            padding: EdgeInsetsDirectional.only(start: 0.w),
            child: AppBackButton(onPressed: _handleBack),
          ),
          title: Text(
            languageService.tr('transaction_history'),
            style: AppTextStyles.screenTitle,
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 24.h),
                // Filter Section
                _buildFilterSection(),

                SizedBox(height: 24.h),
                // Transaction List
                Expanded(child: _buildTransactionList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Period Filter
        _buildTimePeriodFilter(),

        SizedBox(height: 16.h),

        // Custom Date Range (only show if Custom is selected)
        if (selectedTimePeriod == 'Custom') ...[
          _buildCustomDateRange(),
          SizedBox(height: 16.h),
        ],

        // Account and Transaction Type Filters in Row
        Row(
          children: [
            // Expanded(
            //   child: _buildFilterField(
            //     label: 'Account',
            //     value: selectedAccount,
            //     onTap: () => _showAccountDropdown(),
            //     suffixIcon: Icons.arrow_drop_down,
            //   ),
            // ),
            // SizedBox(width: 12.w),
            Expanded(
              child: _buildFilterField(
                label: languageService.tr(
                  'transaction_history_transaction_type',
                ),
                value: _typeLabel(selectedTransactionType),
                onTap: () => _showTransactionTypeDropdown(),
                suffixIcon: Icons.arrow_drop_down,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterField({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData suffixIcon,
  }) {
    return RTLHelper.rtlTextField(
      controller: TextEditingController(text: value),
      readOnly: true,
      onTap: onTap,
      suffixIcon: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: Icon(suffixIcon, color: AppColors.textSecondary, size: 18),
        ),
      ),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildTimePeriodFilter() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        children:
            timePeriods.asMap().entries.map((entry) {
              final index = entry.key;
              final period = entry.value;
              final isSelected = period == selectedTimePeriod;
              final isLast = index == timePeriods.length - 1;

              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        selectedTimePeriod = period;
                        if (period != 'Custom') {
                          customStartDate = null;
                          customEndDate = null;
                        }
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _periodLabel(period),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: AppColors.primary.withOpacity(0.6),
                      indent: 16.w,
                      endIndent: 16.w,
                    ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildCustomDateRange() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showCustomDatePicker(true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  Text(
                    languageService.tr('transaction_history_screen_start_date'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      customStartDate != null
                          ? _formatDate(customStartDate!)
                          : languageService.tr(
                            'transaction_history_screen_select_start_date',
                          ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.pureWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: AppColors.primary.withOpacity(0.6),
            indent: 16.w,
            endIndent: 16.w,
          ),
          InkWell(
            onTap: () => _showCustomDatePicker(false),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  Text(
                    languageService.tr('transaction_history_screen_end_date'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      customEndDate != null
                          ? _formatDate(customEndDate!)
                          : languageService.tr(
                            'transaction_history_screen_select_end_date',
                          ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.pureWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return Obx(() {
      // Show loader while fetching data
      if (controller.isLoading) {
        return Center(child: CommonLoadingWidget(isFullScreen: true));
      }

      // Get filtered and sorted transactions - access observable inside Obx
      final allTransactions = controller.userTransactions;

      // Debug logging
      print('🔍 Transaction List Debug:');
      print('  All Transactions Count: ${allTransactions.length}');
      print('  Selected Account: $selectedAccount');
      print('  Selected Transaction Type: $selectedTransactionType');
      print('  Selected Time Period: $selectedTimePeriod');
      print('  Custom Start Date: $customStartDate');
      print('  Custom End Date: $customEndDate');

      final transactions = _computeFilteredTransactions(allTransactions);

      print('  Filtered Transactions Count: ${transactions.length}');
      if (allTransactions.isNotEmpty && transactions.isEmpty) {
        print('  ⚠️ WARNING: All transactions filtered out!');
        print('  First transaction details:');
        final first = allTransactions.first;
        print('    Type: ${first.transactionType}');
        print('    Account: ${first.mt5AccountId}');
        print('    Created: ${first.createdAt}');
      }

      // Show empty state if no transactions
      if (transactions.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64.w, color: AppColors.primary),
              SizedBox(height: 16.h),
              Text(
                languageService.tr('transaction_history_no_transactions'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                languageService.tr(
                  'transaction_history_screen_try_adjusting_your_filters',
                ),
                style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }

      // Build the ListView for transactions
      return ListView.separated(
        padding: EdgeInsets.only(bottom: 16.h),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => SizedBox(height: 16.h),
        itemBuilder: (_, index) {
          final transaction = transactions[index];
          return _buildTransactionCard(transaction);
        },
      );
    });
  }

  Widget _buildTransactionCard(Data transaction) {
    final bool isDeposit = (transaction.transactionType?.toLowerCase() ?? '')
        .contains('deposit');
    final bool isTransfer = transaction.isInternalTransfer;
    // Transfers move money between the user's own accounts, so they are
    // neither income nor expense: shown neutral, without a minus sign.
    final Color amountColor =
        isTransfer
            ? AppColors.primary
            : (isDeposit ? Colors.green : Colors.red);
    final String amountPrefix = (isDeposit || isTransfer) ? '' : '-';
    final String statusText = (transaction.status ?? '').trim().toLowerCase();
    final bool isApproved = [
      'approved',
      'success',
      'completed',
    ].contains(statusText);
    final String reference =
        (transaction.referenceNumber ?? '').isNotEmpty
            ? transaction.referenceNumber!
            : (transaction.transactionType ?? '');
    final String iconAsset =
        isDeposit
            ? 'assets/svg/deshboard/money-recive.svg'
            : 'assets/svg/deshboard/money-send.svg';

    Color _statusColor() {
      if (isApproved) return Colors.green;
      if (statusText == 'rejected' || statusText == 'failed') return Colors.red;
      return Colors.orange;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _statusColor().withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.h,
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: amountColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child:
                          isTransfer
                              ? Icon(
                                Icons.swap_horiz_rounded,
                                size: 20,
                                color: amountColor,
                              )
                              : SvgPicture.asset(
                                iconAsset,
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  amountColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            transaction.transactionType ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                children: [
                  Text(
                    '$amountPrefix${transaction.amount}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                  Text(
                    _formatDateTime(transaction.createdAt ?? ''),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Tags row: Status, Type, MT5 Account (compact, single row, scrollable)
          SizedBox(
            height: 28.h,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip(
                    text: transaction.status ?? '',
                    border: _statusColor(),
                    bg: _statusColor().withOpacity(0.08),
                    fg: _statusColor(),
                  ),
                  if (((transaction.paymentMethod ??
                              transaction.transactionType) ??
                          '')
                      .isNotEmpty) ...[
                    SizedBox(width: 6.w),
                    _buildChip(
                      text:
                          (transaction.paymentMethod ??
                              transaction.transactionType) ??
                          '',
                      border: Colors.blueGrey.shade300,
                      bg: Colors.blueGrey.withOpacity(0.06),
                      fg: Colors.blueGrey.shade700,
                    ),
                  ],

                  if ((transaction.accountLabel ?? '').isNotEmpty) ...[
                    SizedBox(width: 6.w),
                    _buildChip(
                      text: transaction.accountLabel!,
                      border: Colors.indigo.shade300,
                      bg: Colors.indigo.withOpacity(0.06),
                      fg: Colors.indigo.shade700,
                    ),
                  ] else if ((transaction.mt5AccountId ?? '').isNotEmpty) ...[
                    SizedBox(width: 6.w),
                    _buildChip(
                      text:
                          '${_formatType(transaction.type)}: ${transaction.mt5AccountId}',
                      border: Colors.indigo.shade300,
                      bg: Colors.indigo.withOpacity(0.06),
                      fg: Colors.indigo.shade700,
                    ),
                  ],

                  // Logic Update: Show for ANY transaction with valid ID that is NOT a withdrawal
                  if (controller.showProofColumn.value &&
                      (transaction.id ?? '').isNotEmpty &&
                      !(transaction.amount?.trim().startsWith('-') ?? false) &&
                      (transaction.transactionType?.toLowerCase() ?? '') !=
                          'withdrawal') ...[
                    SizedBox(width: 6.w),
                    InkWell(
                      onTap: () => controller.viewReceipt(transaction.id!),
                      child: Icon(
                        Icons.download_sharp,
                        size: 20.sp,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if ((transaction.rejectReason ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 8.h),
            _buildNoteLine(
              icon: Icons.error_outline_rounded,
              color: Colors.red,
              text:
                  '${languageService.tr('order_history_screen_reason')}: ${transaction.rejectReason!.trim()}',
            ),
          ],
          if ((transaction.commentForClient ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 6.h),
            _buildNoteLine(
              icon: Icons.chat_bubble_outline_rounded,
              color: Colors.grey.shade700,
              text: transaction.commentForClient!.trim(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteLine({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              color: color,
            ),
          ),
        ),
      ],
    );
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

  String _monthShort(int month) =>
      languageService.tr(_monthKeys[month - 1]);

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthShort(date.month)} ${date.year}';
  }

  String _formatDateTime(String dateStr) {
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return dateStr;

    final day = date.day;
    final month = _monthShort(date.month);
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
          // Ensure end date is not before start date
          if (customEndDate != null && customEndDate!.isBefore(picked)) {
            customEndDate = null;
          }
        } else {
          customEndDate = picked;
          // Ensure start date is not after end date
          if (customStartDate != null && customStartDate!.isAfter(picked)) {
            customStartDate = null;
          }
        }
      });
    }
  }

  // (removed unused `_showAccountDropdown`)

  void _showTransactionTypeDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  languageService.tr(
                    'transaction_history_screen_select_transaction_type',
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  height: 200.h,
                  child: ListView.builder(
                    itemCount: transactionTypes.length,
                    itemBuilder: (context, index) {
                      final type = transactionTypes[index];
                      final isSelected = type == selectedTransactionType;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedTransactionType = type;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 16.h,
                            horizontal: 16.w,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _typeLabel(type),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 16.sp,
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
