import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance_v2/data/models/payment_type_option.dart';
import 'package:crm_app/screens/finance_v2/data/models/user_withdrawal_method.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_error_retry.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_shimmer.dart';
import 'package:crm_app/services/language_service.dart';

import 'withdrawal_amount_controller.dart';
import 'withdrawal_option_sheet.dart';

/// "Pay to" of the withdrawal amount screen: the client's saved methods of
/// the chosen type and, where the server allows it, a new crypto address.
class WithdrawalPayToSection extends StatelessWidget {
  final WithdrawalAmountController controller;

  /// Opens the screen that adds a withdrawal method.
  final VoidCallback onAddMethod;

  const WithdrawalPayToSection({
    super.key,
    required this.controller,
    required this.onAddMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TranslationUtils.tr('fv2_pay_to'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Obx(() => _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final methods = controller.methods.toList(growable: false);
    final selected = controller.selectedMethod.value;
    final canPasteAddress = controller.canPasteAddress;
    final methodsError = controller.methodsError.value;
    final payToError = controller.payToError.value;

    if (controller.isLoadingMethods.value && methods.isEmpty) {
      return const FinanceV2Shimmer.cards(count: 1);
    }
    if (methods.isEmpty && methodsError != null && !canPasteAddress) {
      return FinanceV2ErrorRetry(
        compact: true,
        message: methodsError.isEmpty
            ? TranslationUtils.tr(
                'withdrawal_screen_please_add_withdrawal_method_to_continue',
              )
            : methodsError,
        onRetry: controller.loadMethods,
      );
    }
    if (methods.isEmpty && !canPasteAddress) {
      return _AddMethodPrompt(onAddMethod: onAddMethod);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final method in methods)
          _PayToRow(
            title: _maskedLabel(method),
            isValueTitle: true,
            subtitle: method.secondaryLabel,
            isSelected: method.withdrawalSlug == selected?.withdrawalSlug,
            onTap: () => controller.selectMethod(method),
          ),
        if (canPasteAddress && methods.isNotEmpty)
          _PayToRow(
            title: TranslationUtils.tr('bank_list_screen_crypto_address'),
            subtitle: '',
            isSelected: selected == null,
            onTap: () => controller.selectMethod(null),
          ),
        if (controller.usesPastedAddress) ...[
          SizedBox(height: 4.h),
          _NewAddressFields(controller: controller),
        ],
        if (payToError != null && payToError.isNotEmpty) ...[
          SizedBox(height: 4.h),
          _FieldError(text: payToError),
        ],
        _AddMethodRow(onAddMethod: onAddMethod),
      ],
    );
  }

  /// Account numbers and addresses are shown shortened; a UPI id is shown
  /// as it is.
  static String _maskedLabel(UserWithdrawalMethod method) {
    if (method.upiAddress.isNotEmpty) return method.upiAddress;
    final account = method.bankAccountNo;
    if (account.isNotEmpty) {
      if (account.length <= 4) return account;
      return '•••• ${account.substring(account.length - 4)}';
    }
    final address = method.cryptoAddress;
    if (address.length > 12) {
      final head = address.substring(0, 6);
      final tail = address.substring(address.length - 4);
      return '$head…$tail';
    }
    return method.primaryLabel;
  }
}

class _AddMethodPrompt extends StatelessWidget {
  final VoidCallback onAddMethod;

  const _AddMethodPrompt({required this.onAddMethod});

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TranslationUtils.tr(
              'withdrawal_screen_please_add_withdrawal_method_to_continue',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textGrey,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 8.h),
          OutlinedButton.icon(
            onPressed: onAddMethod,
            icon: Icon(Icons.add_rounded, size: 18.sp, color: primary),
            label: Text(
              TranslationUtils.tr('withdrawal_screen_add_method'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                color: primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(96.w, 40.h),
              side: BorderSide(color: primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Last row of the list: adds another saved method.
class _AddMethodRow extends StatelessWidget {
  final VoidCallback onAddMethod;

  const _AddMethodRow({required this.onAddMethod});

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: onAddMethod,
        icon: Icon(Icons.add_rounded, size: 18.sp, color: primary),
        label: Text(
          TranslationUtils.tr('withdrawal_screen_add_method'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            color: primary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: TextButton.styleFrom(
          minimumSize: Size(96.w, 40.h),
          padding: EdgeInsetsDirectional.symmetric(horizontal: 4.w),
        ),
      ),
    );
  }
}

class _PayToRow extends StatelessWidget {
  final String title;

  /// True when [title] is an account number, address or UPI id, which stays
  /// left-to-right in RTL locales; a translated title follows the locale.
  final bool isValueTitle;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PayToRow({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isValueTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12.r);

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: isSelected ? AppColors.surfacePrimary : AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 48.h),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.primary : AppColors.textGrey,
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection:
                              isValueTitle ? TextDirection.ltr : null,
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.textGrey,
                              fontSize: 11.sp,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewAddressFields extends StatelessWidget {
  final WithdrawalAmountController controller;

  const _NewAddressFields({required this.controller});

  Future<void> _pickNetwork(BuildContext context) async {
    final picked = await showWithdrawalOptionSheet<CryptoNetworkOption>(
      context,
      title: TranslationUtils.tr('deposit_instruction_screen_network'),
      options: controller.networks,
      labelOf: (network) => network.label,
      selected: controller.selectedNetwork.value,
    );
    if (picked != null) controller.selectNetwork(picked);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isNotEmpty) controller.pasteAddress(text);
  }

  // Own Obx: the parent's Obx does not see the values read in this build, so
  // a picked network or a cleared error would otherwise not show.
  @override
  Widget build(BuildContext context) => Obx(() => _buildFields(context));

  Widget _buildFields(BuildContext context) {
    final networks = controller.networks;
    final network = controller.selectedNetwork.value;
    final networkError = controller.networkError.value;
    final addressError = controller.addressError.value;
    final hasAddressError = addressError != null && addressError.isNotEmpty;
    final radius = BorderRadius.circular(12.r);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: hasAddressError ? AppColors.error : AppColors.border,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (networks.isNotEmpty) ...[
          Material(
            color: AppColors.textFieldBg,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: networkError == null
                    ? AppColors.border
                    : AppColors.error,
              ),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: () => _pickNetwork(context),
              child: SizedBox(
                height: 48.h,
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: 12.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          network?.label ??
                              TranslationUtils.tr('kyc_crypto_network_hint'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyText.copyWith(
                            color: network == null
                                ? AppColors.hint
                                : AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: network == null
                                ? FontWeight.w400
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textGrey,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (networkError != null && networkError.isNotEmpty) ...[
            SizedBox(height: 4.h),
            _FieldError(text: networkError),
          ],
          SizedBox(height: 8.h),
        ],
        TextField(
          controller: controller.addressController,
          onChanged: controller.onAddressChanged,
          // Addresses stay left-to-right even in RTL locales.
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          cursorColor: AppColors.primary,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 13.sp,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.textFieldBg,
            hintText: TranslationUtils.tr('bank_list_screen_crypto_address'),
            hintStyle: AppTextStyles.bodyText.copyWith(
              color: AppColors.hint,
              fontSize: 13.sp,
            ),
            contentPadding: EdgeInsetsDirectional.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
            suffixIcon: TextButton(
              onPressed: _paste,
              child: Text(
                TranslationUtils.tr('common_paste'),
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.primary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: hasAddressError ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
        ),
        if (hasAddressError) ...[
          SizedBox(height: 4.h),
          _FieldError(text: addressError),
        ],
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  final String text;

  const _FieldError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodyText.copyWith(
        color: AppColors.errorText,
        fontSize: 11.sp,
      ),
    );
  }
}
