import 'dart:async';

import 'package:get/get.dart';

import 'package:crm_app/services/language_service.dart';

import '../../data/finance_v2_repository.dart';
import '../../data/finance_v2_result.dart';
import '../../data/models/deposit_submit_result.dart';
import '../../data/models/finance_channel.dart';
import '../../data/models/finance_v2_failure.dart';
import '../shared/finance_v2_accounts.dart';
import '../widgets/finance_account_option.dart';
import 'deposit_flow_action.dart';

const String _defaultCurrency = 'USD';

/// The amount as it is sent: trimmed, `.5` becomes `0.5` and `100.` becomes
/// `100`.
String normalizeDepositAmount(String raw) {
  var amount = raw.trim();
  if (amount.startsWith('.')) amount = '0$amount';
  while (amount.endsWith('.')) {
    amount = amount.substring(0, amount.length - 1);
  }
  return amount;
}

/// The account, amount and currency a deposit was started with.
class DepositSubmitSnapshot {
  final String accountId;
  final String amount;
  final String currency;

  const DepositSubmitSnapshot({
    required this.accountId,
    required this.amount,
    required this.currency,
  });
}

/// State of the deposit amount screen: target account, amount, the priced
/// channel cards and the submit of online (redirect) cards.
///
/// The controller never navigates; [continueDeposit] and [confirmNewQuote]
/// return a [DepositFlowAction] the screen acts on.
class DepositAmountController extends GetxController {
  DepositAmountController({
    required FinanceV2Repository repository,
    required this.paymentType,
    List<String> amountCurrencies = const <String>[],
    this.preselectedAccountId = '',
    Future<List<FinanceAccountOption>> Function()? accountsLoader,
    String Function(String key)? translate,
    this.debounce = const Duration(milliseconds: 300),
  })  : _repository = repository,
        _loadAccounts = accountsLoader ?? loadFinanceV2Accounts,
        _translate = translate ?? TranslationUtils.tr,
        currencies = amountCurrencies.isEmpty
            ? const <String>[_defaultCurrency]
            : List<String>.unmodifiable(amountCurrencies) {
    // Every channel takes USD; a local currency first in the list is not
    // accepted by all of them (card answers 422 to INR).
    currency.value = currencies.firstWhere(
      (code) => code.toUpperCase() == _defaultCurrency,
      orElse: () => currencies.first,
    );
  }

  final FinanceV2Repository _repository;
  final Future<List<FinanceAccountOption>> Function() _loadAccounts;
  final String Function(String key) _translate;

  /// Raw type of the tile that was tapped (crypto, bank, upi, card, local).
  final String paymentType;
  final String preselectedAccountId;
  final List<String> currencies;
  final Duration debounce;

  final accounts = <FinanceAccountOption>[].obs;
  final isLoadingAccounts = true.obs;
  final selectedAccount = Rxn<FinanceAccountOption>();

  final currency = _defaultCurrency.obs;
  final amountText = ''.obs;
  final amountError = RxnString();

  final channels = <FinanceChannel>[].obs;
  final selectedSlug = RxnString();
  final isDebouncing = false.obs;
  final isFetchingChannels = false.obs;

  /// True once a channels call answered for the current amount.
  final hasChannelsAnswer = false.obs;
  final channelsError = RxnString();

  /// False for FINANCE_DISABLED, which a retry cannot fix.
  final canRetryChannels = true.obs;

  /// Cards a submit failed on, with the server's message. They stay greyed
  /// until the amount changes.
  final cardErrors = <String, String>{}.obs;
  final isSubmitting = false.obs;

  /// Set when loading the cards answered KYC_REQUIRED.
  final kycRequired = false.obs;

  Timer? _debounceTimer;
  int _channelsRequest = 0;
  FinanceChannel? _channelAwaitingQuote;
  DepositSubmitSnapshot? _snapshot;

  /// What the last [continueDeposit] froze; null before the first one.
  DepositSubmitSnapshot? get submitSnapshot => _snapshot;

  @override
  void onInit() {
    super.onInit();
    loadAccounts();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    // Drops the answer of a call that is still in flight.
    _channelsRequest++;
    super.onClose();
  }

  bool get hasAmount => (double.tryParse(amountText.value) ?? 0) > 0;

  bool get isLoadingChannels => isDebouncing.value || isFetchingChannels.value;

  FinanceChannel? get selectedChannel {
    final slug = selectedSlug.value;
    if (slug == null) return null;
    return channels.firstWhereOrNull((channel) => channel.slug == slug);
  }

  bool get canContinue =>
      selectedAccount.value != null &&
      hasAmount &&
      selectedChannel != null &&
      !isLoadingChannels &&
      !isSubmitting.value;

  bool isSelectable(FinanceChannel channel) =>
      channel.isSelectable && !cardErrors.containsKey(channel.slug);

  /// The text under a card that cannot be picked.
  String reasonFor(FinanceChannel channel) =>
      cardErrors[channel.slug] ?? channel.reason;

  Future<void> loadAccounts() async {
    isLoadingAccounts.value = true;
    List<FinanceAccountOption> loaded;
    try {
      loaded = await _loadAccounts();
    } catch (_) {
      // The picker then shows its empty state.
      loaded = const <FinanceAccountOption>[];
    }
    if (isClosed) return;

    accounts.assignAll(loaded);
    final current = selectedAccount.value;
    selectedAccount.value = loaded.firstWhereOrNull(
          (account) => account.id == (current?.id ?? preselectedAccountId),
        ) ??
        loaded.firstOrNull;
    isLoadingAccounts.value = false;
  }

  void selectAccount(FinanceAccountOption account) {
    if (isSubmitting.value) return;
    selectedAccount.value = account;
  }

  void onAmountChanged(String value) {
    amountText.value = value.trim();
    amountError.value = null;
    cardErrors.clear();
    _scheduleChannels();
  }

  void selectCurrency(String value) {
    if (isSubmitting.value || value == currency.value) return;
    currency.value = value;
    amountError.value = null;
    cardErrors.clear();
    _scheduleChannels();
  }

  void selectChannel(String slug) {
    final channel = channels.firstWhereOrNull((item) => item.slug == slug);
    if (channel == null || !isSelectable(channel)) return;
    selectedSlug.value = slug;
  }

  /// Loads the cards for the typed amount. Called after the debounce, by the
  /// inline Retry and whenever a quote must be refreshed.
  Future<void> fetchChannels() async {
    if (!hasAmount) return;
    final request = ++_channelsRequest;
    isFetchingChannels.value = true;
    channelsError.value = null;
    canRetryChannels.value = true;

    final result = await _repository.getChannels(
      type: FinanceV2Repository.typeDeposit,
      paymentType: paymentType,
      amount: amountText.value,
      amountCurrency: currency.value,
    );
    if (request != _channelsRequest || isClosed) return;

    isFetchingChannels.value = false;
    hasChannelsAnswer.value = true;
    switch (result) {
      case FinanceV2Ok<List<FinanceChannel>>(:final value):
        channels.assignAll(value);
        _selectEligible();
      case FinanceV2Err<List<FinanceChannel>>(:final failure):
        _onChannelsFailure(failure);
    }
  }

  /// Handles the call-to-action. Sends nothing when the quote is stale.
  ///
  /// The account, amount and currency are frozen into [submitSnapshot] here,
  /// so a resend or the details screen cannot pick up a later edit.
  Future<DepositFlowAction> continueDeposit() async {
    if (!hasAmount) {
      amountError.value = _translate('deposit_validation_amount');
      return const DepositFlowNone();
    }
    final channel = selectedChannel;
    final quote = channel?.quote;
    final account = selectedAccount.value;
    if (!canContinue || channel == null || quote == null || account == null) {
      return const DepositFlowNone();
    }
    _snapshot = DepositSubmitSnapshot(
      accountId: account.id,
      amount: normalizeDepositAmount(amountText.value),
      currency: currency.value,
    );

    if (quote.isExpired) {
      await fetchChannels();
      return const DepositFlowRatesUpdated();
    }
    if (!channel.submitsDirectly) {
      return DepositFlowOpenDetails(channel: channel, quote: quote);
    }
    return _submit(channel, quote, isFirstAttempt: true);
  }

  /// Sends the deposit again with the quote the client accepted in the
  /// quote-changed sheet. A second QUOTE_CHANGED only reloads the cards, and
  /// so does a quote that ran out while the sheet was open.
  Future<DepositFlowAction> confirmNewQuote(ChannelQuote quote) async {
    final channel = _channelAwaitingQuote;
    _channelAwaitingQuote = null;
    if (channel == null) return const DepositFlowNone();
    if (quote.isExpired) {
      await fetchChannels();
      return const DepositFlowRatesUpdated();
    }
    return _submit(channel, quote, isFirstAttempt: false);
  }

  /// The quote-changed sheet was cancelled: show fresh cards.
  Future<void> dismissQuoteChange() async {
    _channelAwaitingQuote = null;
    await fetchChannels();
  }

  void _scheduleChannels() {
    _debounceTimer?.cancel();
    // A newer amount makes the answer of a running call useless.
    _channelsRequest++;
    isFetchingChannels.value = false;

    if (!hasAmount) {
      isDebouncing.value = false;
      hasChannelsAnswer.value = false;
      channelsError.value = null;
      channels.clear();
      selectedSlug.value = null;
      return;
    }
    isDebouncing.value = true;
    _debounceTimer = Timer(debounce, () {
      isDebouncing.value = false;
      fetchChannels();
    });
  }

  /// Keeps the current card when it can still be picked, else takes the first
  /// eligible one.
  void _selectEligible() {
    final current = selectedChannel;
    if (current != null && isSelectable(current)) return;
    selectedSlug.value = channels.firstWhereOrNull(isSelectable)?.slug;
  }

  void _onChannelsFailure(FinanceV2Failure failure) {
    channels.clear();
    selectedSlug.value = null;
    switch (failure.kind) {
      case FinanceV2FailureKind.kycRequired:
        channelsError.value = failure.message;
        kycRequired.value = true;
      case FinanceV2FailureKind.financeDisabled:
        channelsError.value = failure.message;
        canRetryChannels.value = false;
      case FinanceV2FailureKind.amountError:
        amountError.value = failure.message;
      case FinanceV2FailureKind.quoteChanged:
      case FinanceV2FailureKind.fieldError:
      case FinanceV2FailureKind.otpInvalid:
      case FinanceV2FailureKind.other:
        channelsError.value = failure.message;
    }
  }

  Future<DepositFlowAction> _submit(
    FinanceChannel channel,
    ChannelQuote quote, {
    required bool isFirstAttempt,
  }) async {
    final snapshot = _snapshot;
    if (snapshot == null) return const DepositFlowNone();

    isSubmitting.value = true;
    final result = await _repository.submitDeposit(
      channel.depositApi,
      gatewayMethodId: channel.slug,
      mt5AccountId: snapshot.accountId,
      amount: snapshot.amount,
      amountCurrency: snapshot.currency,
      quoteId: quote.quoteId,
    );
    if (isClosed) return const DepositFlowNone();
    isSubmitting.value = false;

    switch (result) {
      case FinanceV2Ok<DepositSubmitResult>(:final value, :final message):
        return switch (value.nextStep) {
          DepositNextStep.redirect => DepositFlowRedirect(value),
          DepositNextStep.details => DepositFlowShowDetails(
              channel: channel,
              quote: quote,
              result: value,
            ),
          DepositNextStep.created => DepositFlowCreated(message),
        };
      case FinanceV2Err<DepositSubmitResult>(:final failure):
        return _onSubmitFailure(
          channel,
          quote,
          failure,
          isFirstAttempt: isFirstAttempt,
        );
    }
  }

  Future<DepositFlowAction> _onSubmitFailure(
    FinanceChannel channel,
    ChannelQuote quote,
    FinanceV2Failure failure, {
    required bool isFirstAttempt,
  }) async {
    switch (failure.kind) {
      case FinanceV2FailureKind.kycRequired:
        return const DepositFlowKyc();
      case FinanceV2FailureKind.quoteChanged:
        final newQuote = failure.newQuote;
        if (isFirstAttempt && newQuote != null) {
          _channelAwaitingQuote = channel;
          return DepositFlowQuoteChanged(
            newQuote: newQuote,
            oldYouGet: quote.youGet,
          );
        }
        await fetchChannels();
        return const DepositFlowRatesUpdated();
      case FinanceV2FailureKind.financeDisabled:
        return DepositFlowMessage(failure.message);
      case FinanceV2FailureKind.amountError:
        // fetchChannels bumps the counter once when it runs; any other value
        // means the amount or currency changed and the message is stale.
        final expectedRequest =
            hasAmount ? _channelsRequest + 1 : _channelsRequest;
        await fetchChannels();
        if (!isClosed && expectedRequest == _channelsRequest) {
          amountError.value = failure.message;
        }
        return const DepositFlowNone();
      case FinanceV2FailureKind.fieldError:
      case FinanceV2FailureKind.otpInvalid:
      case FinanceV2FailureKind.other:
        cardErrors[channel.slug] = failure.message;
        selectedSlug.value = null;
        _selectEligible();
        // The card note alone is easy to miss after tapping the button.
        return DepositFlowMessage(failure.message);
    }
  }
}
