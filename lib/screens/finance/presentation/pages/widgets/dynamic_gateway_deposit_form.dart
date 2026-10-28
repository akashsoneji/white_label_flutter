import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/deposit_instruction_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// Deposit form for admin-configured "dynamic" gateways
/// (`POST deposit/dynamic/{gatewaySlug}`). Card fields are shown for direct
/// card gateways (`enet_*`) and a payer mobile field for push-prompt
/// gateways (`enove*`), matching the web client portal.
class DynamicGatewayDepositForm extends StatefulWidget {
  const DynamicGatewayDepositForm({
    super.key,
    required this.gatewaySlug,
    required this.gatewayMethodId,
    required this.amount,
    required this.mt5AccountId,
  });

  final String gatewaySlug;
  final String gatewayMethodId;
  final String amount;
  final String mt5AccountId;

  @override
  State<DynamicGatewayDepositForm> createState() =>
      _DynamicGatewayDepositFormState();
}

class _DynamicGatewayDepositFormState extends State<DynamicGatewayDepositForm> {
  final DepositInstructionController _controller =
      Get.find<DepositInstructionController>();
  final LanguageService _lang = Get.find<LanguageService>();

  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _payerMobileController = TextEditingController();

  final Map<String, String> _errors = {};

  bool get _isCardGateway => widget.gatewaySlug.startsWith('enet_');
  bool get _isPushPromptGateway => widget.gatewaySlug.startsWith('enove');

  @override
  void initState() {
    super.initState();
    _controller.dynamicBankResult.value = null;
  }

  @override
  void dispose() {
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _payerMobileController.dispose();
    super.dispose();
  }

  bool _validate() {
    _errors.clear();
    if (_isCardGateway) {
      final cardNumber = _cardNumberController.text.replaceAll(' ', '');
      if (_cardNameController.text.trim().isEmpty) {
        _errors['card_name'] = _lang.tr('deposit_dynamic_invalid_card_name');
      }
      if (cardNumber.length < 13) {
        _errors['card_number'] = _lang.tr('deposit_dynamic_invalid_card_number');
      }
      if (_cardExpiryController.text.length != 4) {
        _errors['card_expiry'] = _lang.tr('deposit_dynamic_invalid_card_expiry');
      }
      if (_cardCvvController.text.length < 3) {
        _errors['card_cvv'] = _lang.tr('deposit_dynamic_invalid_card_cvv');
      }
    }
    if (_isPushPromptGateway) {
      final digits = _payerMobileController.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7 || digits.length > 15) {
        _errors['payer_mobile'] = _lang.tr('deposit_dynamic_invalid_mobile');
      }
    }
    setState(() {});
    return _errors.isEmpty;
  }

  void _submit() {
    if (!_validate()) return;
    final extraFields = <String, String>{
      if (_isCardGateway) ...{
        'card_name': _cardNameController.text.trim(),
        'card_number': _cardNumberController.text.replaceAll(' ', ''),
        'card_expiry': _cardExpiryController.text,
        'card_cvv': _cardCvvController.text,
      },
      if (_isPushPromptGateway)
        'payer_mobile': _payerMobileController.text.trim(),
    };
    _controller.submitDynamicDeposit(
      gatewaySlug: widget.gatewaySlug,
      gatewayMethodId: widget.gatewayMethodId,
      amount: widget.amount,
      mt5AccountId: widget.mt5AccountId,
      extraFields: extraFields,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AmountRow(
            label: _lang.tr('deposit_dynamic_amount'),
            amount: widget.amount,
          ),
          SizedBox(height: 16.h),
          if (_isCardGateway) ...[
            _LabeledField(
              label: _lang.tr('deposit_dynamic_card_name'),
              controller: _cardNameController,
              error: _errors['card_name'],
              keyboardType: TextInputType.name,
            ),
            _LabeledField(
              label: _lang.tr('deposit_dynamic_card_number'),
              controller: _cardNumberController,
              error: _errors['card_number'],
              keyboardType: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabeledField(
                    label: _lang.tr('deposit_dynamic_card_expiry'),
                    controller: _cardExpiryController,
                    error: _errors['card_expiry'],
                    keyboardType: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _LabeledField(
                    label: _lang.tr('deposit_dynamic_card_cvv'),
                    controller: _cardCvvController,
                    error: _errors['card_cvv'],
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (_isPushPromptGateway)
            _LabeledField(
              label: _lang.tr('deposit_dynamic_payer_mobile'),
              hint: _lang.tr('deposit_dynamic_payer_mobile_hint'),
              controller: _payerMobileController,
              error: _errors['payer_mobile'],
              keyboardType: TextInputType.phone,
              formatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                LengthLimitingTextInputFormatter(16),
              ],
            ),
          Obx(() {
            final bank = _controller.dynamicBankResult.value;
            if (bank == null) return const SizedBox.shrink();
            return _BankResultCard(bank: bank, lang: _lang);
          }),
          SizedBox(height: 8.h),
          Obx(() {
            final isSubmitting = _controller.isLoading.value;
            final isDone = _controller.dynamicBankResult.value != null;
            if (isDone) return const SizedBox.shrink();
            return SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: isSubmitting
                    ? ButtonLoadingWidget(
                        size: 20.0,
                        color: AppColors.whiteColor,
                      )
                    : Text(
                        _lang.tr('deposit_dynamic_pay_now'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.whiteColor,
                        ),
                      ),
              ),
            );
          }),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.keyboardType,
    this.formatters,
    this.obscureText = false,
  });

  final String label;
  final String? hint;
  final String? error;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: BorderSide(color: AppColors.border),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 6.h),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            obscureText: obscureText,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              errorText: error,
              errorMaxLines: 2,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankResultCard extends StatelessWidget {
  const _BankResultCard({required this.bank, required this.lang});

  final Map<String, dynamic> bank;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('deposit_dynamic_amount', '${bank['pay_amount'] ?? ''}'),
      MapEntry('deposit_dynamic_bank_name', '${bank['bank_name'] ?? ''}'),
      MapEntry('deposit_dynamic_account_name', '${bank['account_name'] ?? ''}'),
      MapEntry(
        'deposit_dynamic_account_number',
        '${bank['account_number'] ?? ''}',
      ),
      MapEntry('deposit_dynamic_reference', '${bank['reference_number'] ?? ''}'),
      MapEntry('deposit_dynamic_expiry', '${bank['pay_expiry'] ?? ''}'),
    ].where((row) => row.value.isNotEmpty && row.value != 'null').toList();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('deposit_dynamic_bank_hint'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          for (final row in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      lang.tr(row.key),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: SelectableText(
                      row.value,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
