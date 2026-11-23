import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/finance_v2/data/models/payment_type_option.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/account_picker_field.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/amount_currency_field.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_empty_state.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_error_retry.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_primary_button.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_scaffold.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_shimmer.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/quote_changed_sheet.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

import 'withdrawal_amount_controller.dart';
import 'withdrawal_channel_section.dart';
import 'withdrawal_option_sheet.dart';
import 'withdrawal_otp_sheet.dart';
import 'withdrawal_pay_to_section.dart';

/// Second screen of the quote-driven withdrawal flow (TSK-0119): account,
/// amount, where to pay and the priced channel, then the code and the submit.
class WithdrawalAmountScreen extends StatefulWidget {
  final PaymentTypeGroup group;

  /// The payment-types entry of [group], when the server sent one.
  final PaymentTypeOption? typeInfo;

  /// Account to preselect.
  final String? accountNumber;

  const WithdrawalAmountScreen({
    super.key,
    required this.group,
    this.typeInfo,
    this.accountNumber,
  });

  @override
  State<WithdrawalAmountScreen> createState() => _WithdrawalAmountScreenState();
}

class _WithdrawalAmountScreenState extends State<WithdrawalAmountScreen> {
  /// account_type the add-method screen preselects, by withdrawal type. Only
  /// the values of KycBankController.accountTypes are accepted there; any
  /// other type opens the screen without a preselection.
  static const Map<String, String> _addMethodAccountTypes = <String, String>{
    'crypto': 'Crypto',
    'bank': 'Bank',
    'upi': 'UPI',
  };

  late final String _tag = 'withdrawal_amount_${identityHashCode(this)}';
  late final WithdrawalAmountController _controller;
  bool _isPreparing = false;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      WithdrawalAmountController(
        group: widget.group,
        typeInfo: widget.typeInfo,
        initialAccountNumber: widget.accountNumber,
      ),
      tag: _tag,
    );
    _controller.onKycRequired = _openKyc;
  }

  @override
  void dispose() {
    Get.delete<WithdrawalAmountController>(tag: _tag);
    super.dispose();
  }

  void _openKyc() {
    Get.toNamed(AppPages.KYC_INTRO);
  }

  /// Opens the app's add-withdrawal-method screen; this screen stays below
  /// it, so the typed amount is still there when the client comes back.
  Future<void> _openAddMethod() async {
    await Get.toNamed(
      AppPages.KYC_BANK,
      arguments: <String, dynamic>{
        'screen_name': 'Withdrawal Method',
        'account_type':
            _addMethodAccountTypes[widget.group.type.trim().toLowerCase()],
        'isFromKYC': false,
      },
    );
    if (!mounted) return;
    await _controller.loadMethods();
  }

  Future<void> _pickAccount() async {
    final picked = await showAccountPickerSheet(
      context,
      accounts: _controller.accounts.toList(growable: false),
      selectedId: _controller.selectedAccount.value?.id,
    );
    if (picked != null) _controller.selectAccount(picked);
  }

  Future<void> _pickCurrency() async {
    final picked = await showWithdrawalOptionSheet<String>(
      context,
      title: TranslationUtils.tr('fv2_amount'),
      options: _controller.currencies,
      labelOf: (currency) => currency,
      selected: _controller.currency.value,
    );
    if (picked != null) _controller.selectCurrency(picked);
  }

  Future<void> _onSubmit() async {
    if (_isPreparing) return;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isPreparing = true);
    final prepared = await _controller.prepareSubmit();
    if (!mounted) return;
    setState(() => _isPreparing = false);

    if (prepared == WithdrawalOutcome.quoteRefreshed) {
      _showRatesUpdated();
      return;
    }
    if (prepared != WithdrawalOutcome.success) return;

    await _askCode();
  }

  /// Opens the OTP sheet for the frozen submission and acts on its result.
  /// The form is unlocked again when the client just closes the sheet.
  Future<void> _askCode() async {
    final result = await showWithdrawalOtpSheet(
      context,
      controller: _controller,
    );
    if (!mounted) return;
    if (result == null) {
      _controller.endSubmission();
      return;
    }
    await _handleOutcome(result.outcome, result.code);
  }

  Future<void> _handleOutcome(WithdrawalOutcome outcome, String code) async {
    switch (outcome) {
      case WithdrawalOutcome.success:
        final message = _controller.successMessage;
        CustomToastService.showSuccess(
          message: message.isEmpty
              ? TranslationUtils.tr('fv2_withdrawal_submitted')
              : message,
        );
        Get.offNamedUntil(
          Routes.TRANSACTION_HISTORY,
          (route) => route.isFirst,
        );
      case WithdrawalOutcome.kycRequired:
        _openKyc();
      case WithdrawalOutcome.quoteChanged:
        await _confirmChangedQuote(code);
      case WithdrawalOutcome.quoteRefreshed:
        _showRatesUpdated();
      case WithdrawalOutcome.channelRejected:
        _showError(_controller.rejectedChannels.values.lastOrNull);
      case WithdrawalOutcome.submitFailed:
        final message = _controller.submitError.value ?? '';
        _showError(
          message.isEmpty
              ? TranslationUtils.tr('general_something_went_wrong')
              : message,
        );
      case WithdrawalOutcome.otpInvalid:
      case WithdrawalOutcome.invalid:
        // Only after a confirmed new quote, when the sheet is already
        // closed: it opens again with the message under the boxes.
        await _askCode();
      case WithdrawalOutcome.financeDisabled:
      case WithdrawalOutcome.amountError:
      case WithdrawalOutcome.otpSendFailed:
        // Already shown on the form.
        _controller.endSubmission();
    }
  }

  /// Shows the new quote and, when the client accepts it, sends the
  /// withdrawal once more with it. The controller refuses a new quote that
  /// ran out while the sheet was open and reloads the cards instead.
  Future<void> _confirmChangedQuote(String code) async {
    final newQuote = _controller.changedQuote;
    if (newQuote == null) {
      _controller.endSubmission();
      return;
    }

    final accepted = await showQuoteChangedSheet(
      context,
      newQuote: newQuote,
      oldYouGet: _controller.submission?.quote.youGet,
    );
    if (!mounted) return;
    if (!accepted) {
      await _controller.declineChangedQuote();
      return;
    }

    final outcome = await _controller.submit(code, withChangedQuote: true);
    if (!mounted) return;
    await _handleOutcome(outcome, code);
  }

  void _showRatesUpdated() {
    CustomToastService.showInfo(
      message: TranslationUtils.tr('fv2_rates_updated'),
    );
  }

  void _showError(String? message) {
    if (message == null || message.isEmpty) return;
    CustomToastService.showError(message: message);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.group.label;

    return FinanceV2Scaffold(
      title: label.isEmpty ? TranslationUtils.tr('withdrawal') : label,
      body: Obx(() {
        final blockingMessage = _controller.blockingMessage.value;
        if (blockingMessage != null) {
          return Center(
            child: FinanceV2EmptyState(
              icon: Icons.info_outline_rounded,
              title: blockingMessage.isEmpty
                  ? TranslationUtils.tr('fv2_no_withdrawal_methods')
                  : blockingMessage,
            ),
          );
        }
        if (_controller.isLoadingAccounts.value) {
          return const SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: FinanceV2Shimmer.form(),
          );
        }
        final accountsError = _controller.accountsError.value;
        if (accountsError != null) {
          return Center(
            child: FinanceV2ErrorRetry(
              message: accountsError,
              onRetry: _controller.loadAccounts,
            ),
          );
        }
        if (_controller.accounts.isEmpty) {
          return Center(
            child: FinanceV2EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: TranslationUtils.tr('common_no_accounts'),
            ),
          );
        }
        return AbsorbPointer(
          // Nothing of a withdrawal being confirmed may change under it.
          absorbing: _controller.isLocked,
          child: _WithdrawalForm(
            controller: _controller,
            onPickAccount: _pickAccount,
            onPickCurrency: _pickCurrency,
            onAddMethod: _openAddMethod,
          ),
        );
      }),
      bottomCta: Obx(() {
        final isBlocked = _controller.blockingMessage.value != null;
        return FinanceV2PrimaryButton(
          label: TranslationUtils.tr('withdrawal_screen_submit_withdrawal'),
          enabled: _controller.canSubmit && !isBlocked,
          isLoading: _isPreparing || _controller.isSubmitting.value,
          onPressed: _onSubmit,
        );
      }),
    );
  }
}

class _WithdrawalForm extends StatelessWidget {
  final WithdrawalAmountController controller;
  final VoidCallback onPickAccount;
  final VoidCallback onPickCurrency;
  final VoidCallback onAddMethod;

  const _WithdrawalForm({
    required this.controller,
    required this.onPickAccount,
    required this.onPickCurrency,
    required this.onAddMethod,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => AccountPickerField(
              label: TranslationUtils.tr('fv2_select_account'),
              selected: controller.selectedAccount.value,
              onTap: onPickAccount,
            ),
          ),
          SizedBox(height: 12.h),
          Obx(
            () => AmountCurrencyField(
              controller: controller.amountController,
              currency: controller.currency.value,
              currencies: controller.currencies,
              onCurrencyTap: onPickCurrency,
              errorText: controller.amountError.value,
              onChanged: controller.onAmountChanged,
            ),
          ),
          if (!controller.isLocal) ...[
            SizedBox(height: 12.h),
            WithdrawalPayToSection(
              controller: controller,
              onAddMethod: onAddMethod,
            ),
          ],
          SizedBox(height: 12.h),
          WithdrawalChannelSection(controller: controller),
        ],
      ),
    );
  }
}
