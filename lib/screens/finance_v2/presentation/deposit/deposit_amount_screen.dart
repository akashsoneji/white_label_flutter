import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

import '../../data/finance_v2_repository.dart';
import '../../data/models/finance_channel.dart';
import '../../data/models/payment_type_option.dart';
import '../widgets/account_picker_field.dart';
import '../widgets/amount_currency_field.dart';
import '../widgets/channel_quote_card.dart';
import '../widgets/finance_v2_error_retry.dart';
import '../widgets/finance_v2_primary_button.dart';
import '../widgets/finance_v2_scaffold.dart';
import '../widgets/finance_v2_shimmer.dart';
import '../widgets/quote_changed_sheet.dart';
import 'deposit_amount_controller.dart';
import 'deposit_details_controller.dart';
import 'deposit_details_screen.dart';
import 'deposit_flow_action.dart';
import 'deposit_navigation.dart';
import 'payment_wait_screen.dart';

/// Second deposit screen: where the money goes, how much, and which priced
/// channel to pay with.
class DepositAmountScreen extends StatefulWidget {
  /// The type tile that was tapped.
  final PaymentTypeGroup group;

  /// Preselected account id, empty when the caller had none.
  final String accountNumber;

  const DepositAmountScreen({
    super.key,
    required this.group,
    this.accountNumber = '',
  });

  @override
  State<DepositAmountScreen> createState() => _DepositAmountScreenState();
}

class _DepositAmountScreenState extends State<DepositAmountScreen> {
  late final String _tag = 'deposit_amount_${identityHashCode(this)}';
  late final DepositAmountController _controller;
  final TextEditingController _amountController = TextEditingController();
  Worker? _kycWorker;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      DepositAmountController(
        repository: Get.find<FinanceV2Repository>(),
        paymentType: widget.group.type,
        amountCurrencies: widget.group.amountCurrencies,
        preselectedAccountId: widget.accountNumber,
      ),
      tag: _tag,
    );
    _kycWorker = ever<bool>(_controller.kycRequired, (required) {
      if (!required) return;
      _controller.kycRequired.value = false;
      openDepositKyc();
    });
  }

  @override
  void dispose() {
    _kycWorker?.dispose();
    Get.delete<DepositAmountController>(tag: _tag);
    _amountController.dispose();
    super.dispose();
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
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => _CurrencySheet(
        currencies: _controller.currencies,
        selected: _controller.currency.value,
      ),
    );
    if (picked != null) _controller.selectCurrency(picked);
  }

  Future<void> _onContinue() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _handle(await _controller.continueDeposit());
  }

  DepositDetailsArgs _detailsArgs(
    FinanceChannel channel,
    ChannelQuote quote, {
    DepositFlowShowDetails? submitted,
  }) {
    // What continueDeposit froze, not what the fields hold by now.
    final snapshot = _controller.submitSnapshot;
    return DepositDetailsArgs(
      channel: channel,
      quote: quote,
      paymentType: _controller.paymentType,
      accountId: snapshot?.accountId ?? '',
      amount: snapshot?.amount ?? '',
      amountCurrency: snapshot?.currency ?? _controller.currency.value,
      submitted: submitted?.result,
    );
  }

  Future<void> _reloadAfterRateChange() async {
    CustomToastService.showInfo(
      message: TranslationUtils.tr('fv2_rates_updated'),
    );
    await _controller.fetchChannels();
  }

  Future<void> _handle(DepositFlowAction action) async {
    if (!mounted) return;
    switch (action) {
      case DepositFlowNone():
      case DepositFlowFieldErrors():
        break;
      case DepositFlowRatesUpdated():
        CustomToastService.showInfo(
          message: TranslationUtils.tr('fv2_rates_updated'),
        );
      case DepositFlowReloadChannels():
        await _reloadAfterRateChange();
      case DepositFlowOpenDetails(:final channel, :final quote):
        final shouldReload = await Get.to<bool>(
          () => DepositDetailsScreen(args: _detailsArgs(channel, quote)),
        );
        if (shouldReload == true && mounted) await _reloadAfterRateChange();
      // The deposit exists from here on: this screen is replaced so that back
      // cannot return to a card that would create a second deposit.
      case DepositFlowShowDetails(:final channel, :final quote):
        await Get.off<void>(
          () => DepositDetailsScreen(
            args: _detailsArgs(channel, quote, submitted: action),
          ),
        );
      case DepositFlowRedirect(:final result):
        await Get.off<void>(
          () => PaymentWaitScreen(
            reference: result.referenceNumber,
            paymentUrl: result.paymentUrl,
          ),
        );
      case DepositFlowCreated(:final message):
        CustomToastService.showSuccess(
          message: message.isNotEmpty
              ? message
              : TranslationUtils.tr('fv2_deposit_submitted'),
        );
        openDepositTransactionHistory();
      case DepositFlowKyc():
        await openDepositKyc();
      case DepositFlowQuoteChanged(:final newQuote, :final oldYouGet):
        final confirmed = await showQuoteChangedSheet(
          context,
          newQuote: newQuote,
          oldYouGet: oldYouGet,
        );
        if (confirmed) {
          await _handle(await _controller.confirmNewQuote(newQuote));
        } else {
          await _controller.dismissQuoteChange();
        }
      case DepositFlowMessage(:final message):
        CustomToastService.showError(message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.group.label;

    return FinanceV2Scaffold(
      title: label.isNotEmpty ? label : TranslationUtils.tr('deposit'),
      bottomCta: Obx(() {
        final isRedirect = _controller.selectedChannel?.submitsDirectly ?? false;
        return FinanceV2PrimaryButton(
          label: TranslationUtils.tr(
            isRedirect ? 'fv2_continue_to_payment' : 'fv2_continue',
          ),
          onPressed: _onContinue,
          isLoading: _controller.isSubmitting.value,
          enabled: _controller.canContinue,
        );
      }),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => AbsorbPointer(
                absorbing: _controller.isSubmitting.value,
                child: AccountPickerField(
                  label: TranslationUtils.tr('fv2_select_account'),
                  selected: _controller.selectedAccount.value,
                  isLoading: _controller.isLoadingAccounts.value,
                  onTap: _pickAccount,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Obx(
              () => AbsorbPointer(
                // The amount, currency and account are frozen once a submit
                // started.
                absorbing: _controller.isSubmitting.value,
                child: AmountCurrencyField(
                  controller: _amountController,
                  currency: _controller.currency.value,
                  currencies: _controller.currencies,
                  onCurrencyTap:
                      _controller.currencies.length > 1 ? _pickCurrency : null,
                  errorText: _controller.amountError.value,
                  onChanged: _controller.onAmountChanged,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            _SectionLabel(text: TranslationUtils.tr('fv2_payment_channel')),
            SizedBox(height: 8.h),
            _ChannelSection(controller: _controller),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyText.copyWith(
        color: AppColors.textSecondary,
        fontSize: 12.sp,
      ),
    );
  }
}

class _ChannelHint extends StatelessWidget {
  final String text;

  const _ChannelHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textGrey,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}

/// The priced cards with their hint, loading, error and empty states.
class _ChannelSection extends StatelessWidget {
  final DepositAmountController controller;

  const _ChannelSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final channels = controller.channels;
      final isLoading = controller.isLoadingChannels;
      final error = controller.channelsError.value;

      if (!controller.hasAmount) {
        return _ChannelHint(text: TranslationUtils.tr('fv2_enter_amount_hint'));
      }
      if (channels.isEmpty && isLoading) {
        return const FinanceV2Shimmer.cards();
      }
      if (error != null && error.isNotEmpty) {
        return controller.canRetryChannels.value
            ? FinanceV2ErrorRetry(
                message: error,
                onRetry: controller.fetchChannels,
                compact: true,
              )
            : _ChannelHint(text: error);
      }
      if (channels.isEmpty) {
        // An amount error is already shown under the amount field.
        return controller.hasChannelsAnswer.value &&
                controller.amountError.value == null
            ? _ChannelHint(
                text: TranslationUtils.tr('fv2_no_channel_for_amount'),
              )
            : const SizedBox.shrink();
      }

      final selectedSlug = controller.selectedSlug.value;
      return IgnorePointer(
        ignoring: isLoading,
        child: Opacity(
          // Old cards stay visible but dimmed while new quotes load.
          opacity: isLoading ? 0.5 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final channel in channels)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _ChannelCard(
                    channel: channel,
                    isSelected: channel.slug == selectedSlug,
                    isSelectable: controller.isSelectable(channel),
                    reason: controller.reasonFor(channel),
                    onTap: () => controller.selectChannel(channel.slug),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _ChannelCard extends StatelessWidget {
  final FinanceChannel channel;
  final bool isSelected;
  final bool isSelectable;
  final String reason;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channel,
    required this.isSelected,
    required this.isSelectable,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final quote = channel.quote;
    final state = !isSelectable
        ? QuoteState.ineligible
        : (isSelected ? QuoteState.selected : QuoteState.eligible);

    return ChannelQuoteCard(
      name: channel.name,
      logoUrl: channel.logo.isEmpty ? null : channel.logo,
      youPay: quote?.youPay ?? '',
      youGet: quote?.youGet ?? '',
      rateLine: quote?.rateLine,
      feeLine: quote?.feeLine,
      state: state,
      ineligibleReason: reason.isEmpty ? null : reason,
      onTap: isSelectable ? onTap : null,
    );
  }
}

class _CurrencySheet extends StatelessWidget {
  final List<String> currencies;
  final String selected;

  const _CurrencySheet({required this.currencies, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: currencies.length,
        itemBuilder: (context, index) {
          final currency = currencies[index];
          return ListTile(
            dense: true,
            title: Text(
              currency,
              textDirection: TextDirection.ltr,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: currency == selected
                ? Icon(
                    Icons.check_rounded,
                    color: AppColors.primary,
                    size: 18.sp,
                  )
                : null,
            onTap: () => Navigator.of(context).pop(currency),
          );
        },
      ),
    );
  }
}
