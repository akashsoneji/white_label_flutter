import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/deposit_controller.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/utils/navigation_helper.dart';
import '../../../../services/language_service.dart';
import '../../../../widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class DepositScreen extends StatefulWidget {
  final String accountNumber;

  const DepositScreen({super.key, required this.accountNumber});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final DepositController controller = Get.put(DepositController());

  String selectedPaymentMode = 'UPI';
  String selectedAccount = '5013314';
  String selectedCurrency = 'USD';
  final TextEditingController amountController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController transferToController = TextEditingController(
    text: '5013314 MT5 0.00 USD',
  );
  final TextEditingController paymentModeController = TextEditingController(
    text: 'UPI',
  );
  final double fee = 20.00; // Fee in INR

  final List<String> paymentModes = ['UPI', 'Bank Transfer', 'Credit Card'];
  final List<String> accounts = ['5013314', '5013315', '5013316'];
  final List<String> currencies = ['USD', 'EUR', 'GBP'];

  late final LanguageService languageService;

  @override
  void initState() {
    super.initState();
    languageService = Get.find<LanguageService>();
  }

  @override
  void dispose() {
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
        backgroundColor: AppColors.whiteColor,
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

                // Amount Field
                _buildAmountField(),

                // Flexible space to push like button down

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

  Widget _buildAmountField() {
    final FocusNode amountFocusNode = FocusNode();

    amountFocusNode.addListener(() {
      if (amountFocusNode.hasFocus && amountController.text == '0.00') {
        amountController.text = '';
      } else if (!amountFocusNode.hasFocus && amountController.text.isEmpty) {
        amountController.text = '0.00';
      }
    });

    return RTLHelper.rtlTextField(
      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w400),
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
        labelText: 'Amount',
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
        languageService.tr('deposit_confirm_deposit'),
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

    // Call deposit API
    controller.submitDepositForTopUpDemo({
      "amount": amountController.text,
      "meta_account_number": widget.accountNumber,
      // add other required fields
    });
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
