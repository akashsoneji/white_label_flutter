import 'package:crm_app/screens/finance/presentation/finance_ui_scope.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/deposit_controller.dart';
import 'package:crm_app/screens/finance/presentation/pages/deposit_instruction_screen.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/utils/navigation_helper.dart';

import '../../../../services/api_service.dart';
import '../../../../services/language_service.dart';
import '../../../../widgets/custom_toast.dart';
import 'package:crm_app/utils/currency_format.dart';
import 'package:crm_app/models/mt5_account.dart' as mt5m;
import 'package:crm_app/screens/trading/view_models/account_controller.dart';

mt5m.MT5Account? _resolveMt5Account(String? metaAccountNumber) {
  if (metaAccountNumber == null || metaAccountNumber.isEmpty) return null;
  if (!Get.isRegistered<AccountController>()) return null;
  for (final acc in Get.find<AccountController>().mt5Accounts) {
    if (acc.metaAccountNumber == metaAccountNumber) return acc;
  }
  return null;
}

String _fmtMt5(dynamic balanceLike, String? metaAccountNumber) {
  final n = double.tryParse(balanceLike?.toString() ?? '') ?? 0;
  return CurrencyFormat.amount(n, _resolveMt5Account(metaAccountNumber));
}

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
  final ApiService apiService = Get.put(ApiService());

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

    // Rebuild "To be deposited" as user types
    amountController.addListener(() {
      if (mounted) setState(() {});
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
            "${account['meta_account_number']} - ${_fmtMt5(account['balance'], account['meta_account_number']?.toString())}";
        selectedAccount = account['meta_account_number'].toString();
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
    // Check if keyboard is visible
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading:
        AppSvgBackButton(
          onPressed: () => NavigationHelper.safeBack(context: context),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
            title: Text(
          languageService.tr('deposit'),
          style: AppTextStyles.screenTitle,
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
        padding: EdgeInsets.only(
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
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      controller: paymentModeController,
      readOnly: true, // field is non-editable
      onTap: null, // disable dropdown tap
      decoration: InputDecoration(
        labelText: TranslationUtils.tr('deposit_payment_mode'),
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
      style: AppTextStyles.bodyText.copyWith(
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
          child: RTLHelper.rtlIcon(Icons.arrow_drop_down, color: AppColors.textGrey),
        ),
      ),
      decoration: InputDecoration(
        labelText: TranslationUtils.tr('deposit_real_deposit_to'),
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
    return Obx(() {
      final m = controller.depositMethod.value;
      double? minLimit;
      double? maxLimit;
      if (m != null) {
        minLimit = double.tryParse(m['min_limit']?.toString() ?? '');
        maxLimit = double.tryParse(m['max_limit']?.toString() ?? '');
      }

      final raw = amountController.text.trim();
      String? error;
      if (raw.isNotEmpty && raw != '0.00') {
        final entered = double.tryParse(raw);
        if (entered != null) {
          final converted = _convertedAmount(entered);
          if (minLimit != null && converted < minLimit) {
            error = TranslationUtils.trArgs(
              'deposit_real_screen_minimum_deposit_is',
              {'amount': '\$${minLimit.toStringAsFixed(2)}'},
            );
          } else if (maxLimit != null && converted > maxLimit) {
            error = TranslationUtils.trArgs(
              'deposit_real_screen_maximum_deposit_is',
              {'amount': '\$${maxLimit.toStringAsFixed(2)}'},
            );
          }
        }
      }

      return RTLHelper.rtlTextField(
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 16.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        controller: amountController,
        focusNode: amountFocusNode,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          _SingleDecimalTextFormatter(),
        ],
        decoration: InputDecoration(
          labelText: _amountLabel(),
          errorText: error,
          errorStyle: TextStyle(color: AppColors.error, fontSize: 12.sp),
          helperText: (minLimit != null && maxLimit != null)
              ? TranslationUtils.trArgs('deposit_real_screen_limit_min_max', {
                'min': '\$${minLimit.toStringAsFixed(2)}',
                'max': '\$${maxLimit.toStringAsFixed(2)}',
              })
              : null,
          helperStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
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
    });
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
      return TranslationUtils.trArgs('deposit_real_screen_amount_currency', {
        'currency': _sourceCurrency,
      });
    }
    return TranslationUtils.tr('deposit_amount');
  }

  /// Converts the entered source-currency amount into the target (USD)
  /// value, which is what min/max limits are expressed in.
  double _convertedAmount(double entered) {
    if (_hasConversion && _conversionRate > 0) {
      return entered / _conversionRate;
    }
    return entered;
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

  Widget _buildFeeDisplay() {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '₹',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            TextSpan(
              text: '${fee.toStringAsFixed(2)}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.icongrey,
              ),
            ),
          ],
        ),
        ),
      ),
    );
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
            TranslationUtils.tr('deposit_to_be_deposited'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textGrey,
            ),
          ),
          Obx(() {
            controller.depositMethod.value; // reactive trigger
            return Text(
              _convertedDepositText(),
              style: AppTextStyles.bodyText.copyWith(
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
        TranslationUtils.tr('confirm'),
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 14.sp,
          height: 1.71,
          fontWeight: FontWeight.w600,
          color: AppColors.whiteColor,
        ),
      ),
    );
  }

  void _handleDeposit() async {
    final raw = amountController.text.trim();
    final entered = double.tryParse(raw);
    if (entered == null || entered <= 0) {
      CustomToastService.showError(
        message: TranslationUtils.tr('deposit_real_please_enter_valid_amount'),
      );
      return;
    }

    final m = controller.depositMethod.value;
    if (m != null) {
      final minLimit = double.tryParse(m['min_limit']?.toString() ?? '');
      final maxLimit = double.tryParse(m['max_limit']?.toString() ?? '');
      final converted = _convertedAmount(entered);
      if (minLimit != null && converted < minLimit) {
        CustomToastService.showError(
          message:
              '${TranslationUtils.tr('deposit_real_amount_less_than_min_limit')} \$${minLimit.toStringAsFixed(2)}',
        );
        return;
      }
      if (maxLimit != null && converted > maxLimit) {
        CustomToastService.showError(
          message:
              '${TranslationUtils.tr('deposit_real_amount_more_than_max_limit')} \$${maxLimit.toStringAsFixed(2)}',
        );
        return;
      }
    }

    // Get.toNamed(AppPages.DEPOSIT_INSTRUCTION_SCREEN,arguments: controller.depositMethod.value);
   
   /// it workin proper
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
      backgroundColor: AppColors.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Obx(() {
          final accounts = controller.transferAccounts;

          if (accounts.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  TranslationUtils.tr('common_no_accounts'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
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
                      "${account['meta_account_number']} - ${_fmtMt5(account['balance'], account['meta_account_number']?.toString())}";
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
                          style: AppTextStyles.bodyText.copyWith(
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
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),

                      // Balance
                      Text(
                        _fmtMt5(account['balance'], account['meta_account_number']?.toString()),
                        style: AppTextStyles.bodyText.copyWith(
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
