import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/deposit_controller.dart';
import 'package:crm_app/screens/finance/presentation/pages/deposit_instruction_screen.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/utils/navigation_helper.dart';

import '../../../../services/language_service.dart';
import '../../../../widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class DepositRealScreen extends StatefulWidget {
  final Map<String, dynamic> object;
  final String? preselectedAccountNumber;

  DepositRealScreen({
    super.key,
    required this.object,
    String? preselectedAccountNumber,
  }) : preselectedAccountNumber =
           // Prioritize Get.arguments first (set during navigation), then fall back to parameter
           (Get.arguments != null && Get.arguments!['accountNumber'] != null
               ? (Get.arguments!['accountNumber'] as String)
               : null) ??
           preselectedAccountNumber {
    // Debug: Log when widget is created
    print('========================================');
    print('DepositRealScreen: WIDGET CONSTRUCTOR CALLED');
    print(
      'DepositRealScreen: constructor parameter: "$preselectedAccountNumber"',
    );
    print('DepositRealScreen: Get.arguments: ${Get.arguments}');
    print(
      'DepositRealScreen: Get.arguments accountNumber: ${Get.arguments?['accountNumber']}',
    );
    print(
      'DepositRealScreen: final preselectedAccountNumber: "${this.preselectedAccountNumber}"',
    );
    print(
      'DepositRealScreen: preselectedAccountNumber is null: ${this.preselectedAccountNumber == null}',
    );
    print(
      'DepositRealScreen: preselectedAccountNumber type: ${this.preselectedAccountNumber.runtimeType}',
    );
    print('========================================');
  }

  @override
  State<DepositRealScreen> createState() => _DepositRealScreenState();
}

class _DepositRealScreenState extends State<DepositRealScreen> {
  late final DepositController controller;

  String selectedPaymentMode = 'UPI';
  String selectedAccount = '0';
  String selectedCurrency = 'USD';
  final TextEditingController amountController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController transferToController = TextEditingController(
    text: '',
  );
  final TextEditingController paymentModeController = TextEditingController(
    text: '',
  );
  final double fee = 20.00; // Fee in INR

  final List<String> accounts = ['0', '0', '0'];
  final List<String> currencies = ['USD', 'EUR', 'GBP'];

  late final LanguageService languageService;
  late final FocusNode amountFocusNode;

  @override
  void initState() {
    super.initState();
    // Delete any existing instance to ensure fresh state
    if (Get.isRegistered<DepositController>()) {
      Get.delete<DepositController>();
    }
    controller = Get.put(DepositController());

    languageService = Get.find<LanguageService>();

    // Initialize FocusNode for amount field
    amountFocusNode = FocusNode();
    amountFocusNode.addListener(() {
      if (amountFocusNode.hasFocus && amountController.text == '0.00') {
        amountController.text = '';
      } else if (!amountFocusNode.hasFocus && amountController.text.isEmpty) {
        amountController.text = '0.00';
      }
    });
    amountController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    final preselectedAccount = widget.preselectedAccountNumber;
    print('DepositRealScreen: initState called');
    print('DepositRealScreen: preselectedAccountNumber: "$preselectedAccount"');
    print(
      'DepositRealScreen: preselectedAccountNumber is null: ${preselectedAccount == null}',
    );
    print(
      'DepositRealScreen: preselectedAccountNumber isEmpty: ${preselectedAccount?.isEmpty ?? true}',
    );
    print(
      'DepositRealScreen: preselectedAccountNumber type: ${preselectedAccount.runtimeType}',
    );

    paymentModeController.text =
        widget.object['display_name']; // adjust field name per API
    selectedPaymentMode = widget.object['display_name'];

    // CRITICAL: Store account number in a local variable to ensure it's captured
    final accountNumberToPass = preselectedAccount;
    print('DepositRealScreen: Calling fetchAccountsForPaymentMethod');
    print(
      'DepositRealScreen: accountNumberToPass value: "$accountNumberToPass"',
    );
    print(
      'DepositRealScreen: accountNumberToPass is null: ${accountNumberToPass == null}',
    );
    print(
      'DepositRealScreen: accountNumberToPass isEmpty: ${accountNumberToPass?.isEmpty ?? true}',
    );

    if (accountNumberToPass != null && accountNumberToPass.isNotEmpty) {
      print(
        'DepositRealScreen: ✅ Account number is valid, passing to controller: "$accountNumberToPass"',
      );
    } else {
      print('DepositRealScreen: ❌ WARNING: Account number is null or empty!');
      print(
        'DepositRealScreen: widget.preselectedAccountNumber: "${widget.preselectedAccountNumber}"',
      );
    }

    controller.fetchAccountsForPaymentMethod(
      widget.object['deposit_slug'],
      preselectedAccountNumber: accountNumberToPass,
    );

    ever(controller.selectedTransferAccount, (account) {
      if (account != null) {
        final accountNumber =
            account['meta_account_number']?.toString() ?? 'null';
        print(
          'DepositRealScreen: selectedTransferAccount changed to: $accountNumber',
        );
        transferToController.text =
            "${account['meta_account_number']} - \$ ${account['balance'] ?? '0.00'}";
        selectedAccount = account['meta_account_number'].toString();
        
        final currency = account['currency']?.toString() ?? 'USD';
        if (mounted) {
          setState(() {
            selectedCurrency = currency;
          });
        }
        print(
          'DepositRealScreen: Updated transferToController.text to: ${transferToController.text}',
        );
      } else {
        print('DepositRealScreen: selectedTransferAccount is null');
      }
    });
  }

  @override
  void dispose() {
    amountFocusNode.dispose();
    amountController.dispose();
    transferToController.dispose();
    paymentModeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: AppBackButton(onPressed: () => NavigationHelper.safeBack(context: context),
          ),
        ),

        title: Text(
          languageService.tr('deposit'),
          style: AppTextStyles.screenTitle,
        ),
        shape: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300, // divider color
            width: 1, // divider thickness
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 24.h),
                // Payment Mode Field
                _buildPaymentModeField(),

                SizedBox(height: 24.h),

                // Transfer to Field
                _buildTransferToField(),

                SizedBox(height: 24.h),

                // Amount Field
                _buildAmountField(),

                // Fee Display
                SizedBox(height: 26.h),

                // _buildFeeDisplay(),
                SizedBox(height: 10.h),

                // To be deposited Section
                _buildToBeDepositedSection(),

                // Continue Button

                // Flexible space to push like button down
                // SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                // _buildContinueButton(),

                // Dynamic bottom padding based on keyboard visibility
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(
          bottom: kToolbarHeight,
          left: 24.0,
          right: 24.0,
        ),
        child: _buildContinueButton(),
      ),
    );
  }

  Widget _buildPaymentModeField() {
    return RTLHelper.rtlTextField(
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      controller: paymentModeController,
      readOnly: true, // field is non-editable
      onTap: null, // disable dropdown tap
      decoration: InputDecoration(
        labelText: 'Payment Mode',
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildTransferToField() {
    return RTLHelper.rtlTextField(
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      controller: transferToController,
      readOnly: true,
      onTap: () => _showAccountDropdown(),
      suffixIcon: InkWell(
        onTap: () => _showAccountDropdown(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: RTLHelper.rtlIcon(Icons.arrow_drop_down, color: Colors.grey),
        ),
      ),
      decoration: InputDecoration(
        labelText: 'Deposit to',
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return RTLHelper.rtlTextField(
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      controller: amountController,
      focusNode: amountFocusNode,
      keyboardType: TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        _SingleDecimalTextFormatter(),
      ],
      decoration: InputDecoration(
        labelText: _amountLabel(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  bool get _hasConversion {
    final m = controller.depositMethod.value;
    return m != null && m['has_conversion'] == true;
  }

  String get _sourceCurrency {
    final m = controller.depositMethod.value;
    final name = m?['currency_name']?.toString();
    return (name == null || name.isEmpty) ? selectedCurrency : name;
  }

  double get _conversionRate {
    final m = controller.depositMethod.value;
    final raw = m?['conversion_rate'];
    if (raw == null) return 0;
    return double.tryParse(raw.toString()) ?? 0;
  }

  String _amountLabel() {
    if (_hasConversion) {
      return 'Amount ($_sourceCurrency)';
    }
    return 'Amount';
  }

  String _convertedDepositText() {
    final raw = amountController.text.trim();
    final entered = double.tryParse(raw.isEmpty ? '0' : raw) ?? 0;
    if (_hasConversion && _conversionRate > 0) {
      final converted = entered / _conversionRate;
      return '${converted.toStringAsFixed(2)} $selectedCurrency';
    }
    return '${raw.isEmpty ? "0.00" : raw} $selectedCurrency';
  }

  Widget _buildToBeDepositedSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.5.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To be deposited',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.icongrey,
            ),
          ),
          Obx(() {
            controller.depositMethod.value; // reactive trigger
            return Text(
              _convertedDepositText(),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return ElevatedButton(
      onPressed: _handleDeposit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.whiteColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        padding: EdgeInsets.zero,
      ),
      child: Text(
        'Confirm',
        style: TextStyle(
          fontSize: 14.sp,
          height: 1.71,
          fontWeight: FontWeight.w600,
          color: AppColors.whiteColor,
        ),
      ),
    );
  }

  void _handleDeposit() async {
    // Show loading

    if (amountController.text.isEmpty || amountController.text == "0.00") {
      CustomToastService.showError(message: 'Please enter a valid amount');
      return;
    }

    // Get.toNamed(AppPages.DEPOSIT_INSTRUCTION_SCREEN,arguments: controller.depositMethod.value);
    Get.to(
      () => DepositInstructionScreen(
        object: controller.depositMethod.value!,
        amountString: amountController.text,
        selectedMT5AccountID:
            controller.selectedTransferAccount.value!['meta_account_number']
                as String,
        currency: selectedCurrency,
        fromBonus: Get.arguments != null && Get.arguments is Map && Get.arguments['from'] == 'bonus',
      ),
    );

    // Call deposit API
    // controller.submitDepositForTopUpDemo({
    //   "amount": amountController.text,
    //   "accountId": widget.deposit_slug,
    //   // add other required fields
    // });
  }

  void _showAccountDropdown() {
    final controller = Get.find<DepositController>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffold,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Obx(() {
          final accounts = controller.transferAccounts;

          if (accounts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  "No accounts available",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            itemCount: accounts.length,
            separatorBuilder:
                (_, __) => Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final account = accounts[index];

              return InkWell(
                onTap: () {
                  controller.selectedTransferAccount.value = account;
                  transferToController.text =
                      "${account['meta_account_number']} - \$ ${account['balance'] ?? '0.00'}";
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  child: Row(
                    children: [
                      // Group label (Standard / Wallet)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          account['master_group_id'] ?? "N/A",
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),

                      SizedBox(width: 12.w),

                      // Account number
                      Expanded(
                        child: Text(
                          account['meta_account_number'] ?? "-",
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),

                      // Balance
                      Text(
                        "\$ ${account['balance'] ?? '0.00'}",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
      },
    );
  }
}

/// Formatter that keeps digits and a single decimal point.
class _SingleDecimalTextFormatter extends TextInputFormatter {
  const _SingleDecimalTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final sanitized = _sanitize(newValue.text);
    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
  }

  String _sanitize(String value) {
    String clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (clean.contains('.')) {
      final parts = clean.split('.');
      clean =
          parts[0] + (parts.length > 1 ? '.${parts.sublist(1).join('')}' : '');
    }
    return clean;
  }
}
