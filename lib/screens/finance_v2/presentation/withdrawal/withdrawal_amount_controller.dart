import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:crm_app/screens/finance_v2/data/finance_v2_repository.dart';
import 'package:crm_app/screens/finance_v2/data/finance_v2_result.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_channel.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_v2_failure.dart';
import 'package:crm_app/screens/finance_v2/data/models/payment_type_option.dart';
import 'package:crm_app/screens/finance_v2/data/models/user_withdrawal_method.dart';
import 'package:crm_app/screens/finance_v2/presentation/shared/finance_v2_accounts.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/channel_quote_card.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_account_option.dart';
import 'package:crm_app/services/language_service.dart';

/// What the channel section of the withdrawal amount screen shows.
enum WithdrawalChannelsState { idle, loading, data, empty, error }

/// Result of a step of the withdrawal submit; the screen navigates and shows
/// toasts from it, the controller only updates its state.
enum WithdrawalOutcome {
  success,

  /// The form or the code is not complete; the message is on the field.
  invalid,

  /// The quote was too old (or changed twice): the cards were loaded again
  /// and nothing was sent.
  quoteRefreshed,
  kycRequired,

  /// The server sent a new quote, kept in
  /// [WithdrawalAmountController.changedQuote], to confirm once.
  quoteChanged,
  financeDisabled,

  /// The message is under the amount and the cards are loading again.
  amountError,

  /// Wrong code: the OTP sheet stays open with the message.
  otpInvalid,

  /// The selected card was greyed and the next eligible one selected.
  channelRejected,

  /// The code could not be sent; the message is in
  /// [WithdrawalAmountController.otpSendError].
  otpSendFailed,

  /// The submit got no business answer (no network, timeout, server error):
  /// nothing changed, the message is in
  /// [WithdrawalAmountController.submitError].
  submitFailed,
}

/// State and logic of the withdrawal amount screen and its OTP sheet
/// (TSK-0119). It never navigates: every submit step answers with a
/// [WithdrawalOutcome].
class WithdrawalAmountController extends GetxController {
  static const String localType = 'local';
  static const String cryptoType = 'crypto';
  static const String defaultCurrency = 'USD';
  static const int otpLength = 6;
  static const int resendDelaySeconds = 30;
  static const int _minAddressLength = 20;

  final PaymentTypeGroup group;

  /// The payment-types entry of the group, when the server sent one.
  final PaymentTypeOption? typeInfo;

  /// Account to preselect, as passed by the screen that opened the flow.
  final String? initialAccountNumber;

  final FinanceV2Repository _repository;
  final Future<List<FinanceAccountOption>> Function() _loadAccounts;
  final String Function(String key) _tr;
  final Duration _debounce;
  final DateTime Function() _now;

  WithdrawalAmountController({
    required this.group,
    this.typeInfo,
    this.initialAccountNumber,
    FinanceV2Repository? repository,
    Future<List<FinanceAccountOption>> Function()? accountsLoader,
    String Function(String key)? translate,
    Duration debounce = const Duration(milliseconds: 300),
    DateTime Function()? now,
  })  : _repository = repository ?? Get.find<FinanceV2Repository>(),
        _loadAccounts = accountsLoader ?? _loadWithdrawalAccounts,
        _tr = translate ?? TranslationUtils.tr,
        _debounce = debounce,
        _now = now ?? DateTime.now;

  static Future<List<FinanceAccountOption>> _loadWithdrawalAccounts() {
    return loadFinanceV2Accounts(forWithdrawal: true);
  }

  final TextEditingController amountController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  final RxBool isLoadingAccounts = true.obs;
  final RxnString accountsError = RxnString();
  final RxList<FinanceAccountOption> accounts = <FinanceAccountOption>[].obs;
  final Rxn<FinanceAccountOption> selectedAccount = Rxn<FinanceAccountOption>();

  final RxString currency = defaultCurrency.obs;
  final RxString amountText = ''.obs;
  final RxnString amountError = RxnString();

  final RxBool isLoadingMethods = false.obs;
  final RxnString methodsError = RxnString();
  final RxList<UserWithdrawalMethod> methods = <UserWithdrawalMethod>[].obs;
  final Rxn<UserWithdrawalMethod> selectedMethod = Rxn<UserWithdrawalMethod>();
  final RxnString payToError = RxnString();

  final Rxn<CryptoNetworkOption> selectedNetwork = Rxn<CryptoNetworkOption>();
  final RxnString networkError = RxnString();
  final RxString addressText = ''.obs;
  final RxnString addressError = RxnString();

  final Rx<WithdrawalChannelsState> channelsState =
      WithdrawalChannelsState.idle.obs;
  final RxList<FinanceChannel> channels = <FinanceChannel>[].obs;
  final RxnString selectedChannelSlug = RxnString();
  final RxnString channelsError = RxnString();

  /// True from the first key of a new amount until its cards arrived, so the
  /// CTA stays locked while debouncing.
  final RxBool isFetchingChannels = false.obs;

  /// Cards the server refused on submit: slug → message. Cleared when the
  /// amount changes.
  final RxMap<String, String> rejectedChannels = <String, String>{}.obs;

  final RxBool isSubmitting = false.obs;

  /// True from a successful [prepareSubmit] until [endSubmission]: the OTP
  /// sheet or the new-quote sheet is open.
  final RxBool isConfirming = false.obs;

  /// Message of a submit that got no business answer.
  final RxnString submitError = RxnString();

  /// True when the cards are locked behind KYC; the section then offers a
  /// button that opens it.
  final RxBool channelsNeedKyc = false.obs;

  /// FINANCE_DISABLED message; the form is replaced by it.
  final RxnString blockingMessage = RxnString();

  final RxBool isSendingOtp = false.obs;
  final RxnString otpSendError = RxnString();

  /// Server message of a refused resend while the code sent before is still
  /// valid (the server throttles sendOTP for a minute).
  final RxnString otpResendNotice = RxnString();

  /// data.channel of the sendOTP answer: mobile | email.
  final RxString otpChannel = ''.obs;
  final RxnString otpError = RxnString();

  /// Bumped when the typed code must be cleared (wrong OTP).
  final RxInt otpClearSignal = 0.obs;
  final RxInt resendSeconds = 0.obs;

  /// The quote of a QUOTE_CHANGED answer waiting for the client's yes.
  ChannelQuote? changedQuote;

  /// Message of the successful submit, when the server sent one.
  String successMessage = '';

  /// Called when loading the cards fails with KYC_REQUIRED.
  VoidCallback? onKycRequired;

  Timer? _debounceTimer;
  Timer? _resendTimer;
  int _channelsRequestId = 0;
  int _methodsRequestId = 0;
  bool _disposed = false;
  bool _kycOpened = false;
  WithdrawalSubmission? _submission;

  /// [WithdrawalSubmission.otpKey] the running resend countdown belongs to.
  String? _otpSentKey;

  /// The frozen values of the submit in progress, if any.
  WithdrawalSubmission? get submission => _submission;

  /// True while the form must not change: a code is being asked for or the
  /// withdrawal is being sent.
  bool get isLocked => isConfirming.value || isSubmitting.value;

  bool get isLocal => group.type == localType;

  bool get isCrypto => group.type == cryptoType;

  /// True when the client may type a new crypto address instead of picking a
  /// saved one (server flag crypto_skip_otp; the code is still asked).
  bool get canPasteAddress {
    if (!isCrypto) return false;
    return (typeInfo?.cryptoSkipOtp ?? false) ||
        group.rows.any((row) => row.cryptoSkipOtp);
  }

  List<CryptoNetworkOption> get networks {
    final fromType = typeInfo?.allowedCryptoNetworks;
    if (fromType != null && fromType.isNotEmpty) return fromType;
    for (final row in group.rows) {
      if (row.allowedCryptoNetworks.isNotEmpty) {
        return row.allowedCryptoNetworks;
      }
    }
    return const <CryptoNetworkOption>[];
  }

  /// True when the typed address, not a saved method, is what gets sent.
  bool get usesPastedAddress => canPasteAddress && selectedMethod.value == null;

  List<String> get currencies {
    final fromGroup = group.amountCurrencies;
    return fromGroup.isEmpty ? const <String>[defaultCurrency] : fromGroup;
  }

  /// The typed amount as it is sent: see [normalizeAmount].
  String get amount => normalizeAmount(amountText.value);

  /// Trims [raw], drops a trailing '.', and leading zeros, and gives a bare
  /// fraction its zero: ' 007.50 ' → '7.50', '5.' → '5', '.5' → '0.5'.
  static String normalizeAmount(String raw) {
    var value = raw.trim();
    if (value.endsWith('.')) value = value.substring(0, value.length - 1);
    if (value.isEmpty) return '';
    value = value.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return value.startsWith('.') ? '0$value' : value;
  }

  FinanceChannel? get selectedChannel {
    final slug = selectedChannelSlug.value;
    if (slug == null) return null;
    return channels.firstWhereOrNull(
      (channel) => channel.slug == slug && _isSelectable(channel),
    );
  }

  bool get canSubmit {
    if (selectedAccount.value == null || !_isPositive(amount)) return false;
    if (isFetchingChannels.value || isLocked) return false;
    if (selectedChannel == null) return false;
    if (isLocal) return true;
    if (usesPastedAddress) {
      final hasNetwork = networks.isEmpty || selectedNetwork.value != null;
      return hasNetwork && addressText.value.trim().isNotEmpty;
    }
    return selectedMethod.value != null;
  }

  QuoteState quoteStateOf(FinanceChannel channel) {
    if (!_isSelectable(channel)) return QuoteState.ineligible;
    return channel.slug == selectedChannelSlug.value
        ? QuoteState.selected
        : QuoteState.eligible;
  }

  /// Why [channel] cannot be picked: the submit refusal, else the server
  /// reason.
  String? ineligibleReasonOf(FinanceChannel channel) {
    final rejected = rejectedChannels[channel.slug];
    if (rejected != null && rejected.isNotEmpty) return rejected;
    return channel.reason.isEmpty ? null : channel.reason;
  }

  @override
  void onInit() {
    super.onInit();
    currency.value = currencies.first;
    loadAccounts();
    loadMethods();
  }

  @override
  void onClose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _resendTimer?.cancel();
    _channelsRequestId++;
    amountController.dispose();
    addressController.dispose();
    super.onClose();
  }

  Future<void> loadAccounts() async {
    isLoadingAccounts.value = true;
    accountsError.value = null;
    try {
      final loaded = await _loadAccounts();
      if (_disposed) return;
      accounts.assignAll(loaded);
      selectedAccount.value = _accountToSelect(loaded);
    } catch (_) {
      if (_disposed) return;
      accounts.clear();
      selectedAccount.value = null;
      accountsError.value = _tr('account_controller_failed_to_load_accounts');
    } finally {
      if (!_disposed) isLoadingAccounts.value = false;
    }
  }

  /// Loads the client's approved saved methods of this type. Called again
  /// when the client comes back from adding one; the form is kept.
  Future<void> loadMethods() async {
    if (isLocal) return;
    // onInit and the return from the add-method screen can overlap; only the
    // newest load may write.
    final requestId = ++_methodsRequestId;
    isLoadingMethods.value = true;
    methodsError.value = null;

    final previousSlug = selectedMethod.value?.withdrawalSlug;
    final loaded = <String, UserWithdrawalMethod>{};
    FinanceV2Failure? failure;

    final methodSlugs = group.rows.map((row) => row.methodSlug).toSet();
    for (final methodSlug in methodSlugs) {
      final result = await _repository.getUserWithdrawalMethods(methodSlug);
      if (_disposed || requestId != _methodsRequestId) return;
      switch (result) {
        case FinanceV2Ok<List<UserWithdrawalMethod>>(:final value):
          for (final method in value.where(_isOfThisType)) {
            // Without a slug the method cannot be sent.
            if (method.withdrawalSlug.trim().isEmpty) continue;
            loaded[method.withdrawalSlug] = method;
          }
        case FinanceV2Err<List<UserWithdrawalMethod>>(failure: final error):
          failure = error;
      }
    }

    methods.assignAll(loaded.values);
    if (loaded.isEmpty && failure != null) {
      methodsError.value = failure.message;
    }
    selectedMethod.value = loaded[previousSlug] ?? _methodToSelect();
    if (selectedMethod.value != null) payToError.value = null;
    isLoadingMethods.value = false;
  }

  void selectAccount(FinanceAccountOption account) {
    if (isLocked) return;
    selectedAccount.value = account;
  }

  void selectCurrency(String value) {
    if (isLocked || currency.value == value) return;
    currency.value = value;
    amountError.value = null;
    rejectedChannels.clear();
    _scheduleChannels();
  }

  void onAmountChanged(String value) {
    if (isLocked) return;
    amountText.value = value;
    amountError.value = null;
    rejectedChannels.clear();
    _scheduleChannels();
  }

  /// Picks a saved method, or null for a new crypto address.
  void selectMethod(UserWithdrawalMethod? method) {
    if (isLocked) return;
    selectedMethod.value = method;
    payToError.value = null;
    networkError.value = null;
    addressError.value = null;
  }

  void selectNetwork(CryptoNetworkOption network) {
    if (isLocked) return;
    selectedNetwork.value = network;
    networkError.value = null;
  }

  void onAddressChanged(String value) {
    if (isLocked) return;
    addressText.value = value;
    addressError.value = null;
  }

  void pasteAddress(String value) {
    if (isLocked) return;
    final address = value.trim();
    addressController.text = address;
    onAddressChanged(address);
  }

  void selectChannel(FinanceChannel channel) {
    if (isLocked || !_isSelectable(channel)) return;
    selectedChannelSlug.value = channel.slug;
  }

  /// Loads the cards now, dropping any pending debounce and older answer.
  Future<void> refreshChannels() async {
    _debounceTimer?.cancel();
    final requestId = ++_channelsRequestId;

    if (!_isPositive(amount)) {
      _showNoChannels(WithdrawalChannelsState.idle);
      return;
    }

    isFetchingChannels.value = true;
    channelsError.value = null;
    // Cards already on screen stay (dimmed) while the new ones load.
    if (channels.isEmpty) {
      channelsState.value = WithdrawalChannelsState.loading;
    }

    final result = await _repository.getChannels(
      type: FinanceV2Repository.typeWithdrawal,
      paymentType: group.type,
      amount: amount,
      amountCurrency: currency.value,
    );
    if (_disposed || requestId != _channelsRequestId) return;

    isFetchingChannels.value = false;
    switch (result) {
      case FinanceV2Ok<List<FinanceChannel>>(:final value):
        _showChannels(value);
      case FinanceV2Err<List<FinanceChannel>>(:final failure):
        _showChannelsFailure(failure);
    }
  }

  /// First step of a submit. Answers [WithdrawalOutcome.success] when the
  /// code may be requested; an expired quote reloads the cards instead.
  ///
  /// On success the form is frozen into [submission] and stays locked until
  /// [endSubmission].
  Future<WithdrawalOutcome> prepareSubmit() async {
    if (isLocked) return WithdrawalOutcome.invalid;
    if (!_validateForm()) return WithdrawalOutcome.invalid;
    final account = selectedAccount.value;
    final channel = selectedChannel;
    final quote = channel?.quote;
    if (account == null || channel == null || quote == null) {
      return WithdrawalOutcome.invalid;
    }
    if (isFetchingChannels.value) return WithdrawalOutcome.invalid;
    if (_isExpired(quote)) {
      await refreshChannels();
      return WithdrawalOutcome.quoteRefreshed;
    }

    final sendsAddress = usesPastedAddress;
    final sendsSavedMethod = !isLocal && !sendsAddress;
    _submission = WithdrawalSubmission(
      accountId: account.id,
      amount: amount,
      currency: currency.value,
      channelSlug: channel.slug,
      quote: quote,
      withdrawalSlug:
          sendsSavedMethod ? selectedMethod.value?.withdrawalSlug : null,
      cryptoAddress: sendsAddress ? addressController.text.trim() : null,
      cryptoNetwork: sendsAddress ? selectedNetwork.value?.slug : null,
    );
    changedQuote = null;
    otpError.value = null;
    otpSendError.value = null;
    submitError.value = null;
    isConfirming.value = true;
    return WithdrawalOutcome.success;
  }

  /// Unlocks the form and forgets the frozen values. The resend countdown
  /// keeps running, so reopening the sheet for the same account and amount
  /// does not send a second code.
  void endSubmission() {
    _submission = null;
    changedQuote = null;
    if (!_disposed) isConfirming.value = false;
  }

  /// Called when the OTP sheet opens: requests a code unless the one sent for
  /// the same account and amount can still not be resent.
  Future<WithdrawalOutcome> requestOtpOnOpen() {
    final submission = _submission;
    final hasFreshCode = submission != null &&
        resendSeconds.value > 0 &&
        _otpSentKey == submission.otpKey;
    if (hasFreshCode) {
      otpSendError.value = null;
      return Future<WithdrawalOutcome>.value(WithdrawalOutcome.success);
    }
    return sendOtp(keepOtpError: true);
  }

  /// Requests the code (GET /withdrawal/sendOTP) for the frozen account and
  /// amount and starts the resend countdown. [keepOtpError] leaves the
  /// message of a wrong code on the sheet.
  Future<WithdrawalOutcome> sendOtp({bool keepOtpError = false}) async {
    final submission = _submission;
    if (submission == null) {
      otpSendError.value = '';
      return WithdrawalOutcome.otpSendFailed;
    }
    if (isSendingOtp.value) return WithdrawalOutcome.invalid;

    isSendingOtp.value = true;
    otpSendError.value = null;
    otpResendNotice.value = null;
    if (!keepOtpError) otpError.value = null;

    final result = await _repository.sendWithdrawalOtp(
      mt5AccountId: submission.accountId,
      amount: submission.amount,
    );
    if (_disposed) return WithdrawalOutcome.invalid;
    isSendingOtp.value = false;

    switch (result) {
      case FinanceV2Ok<String>(:final value):
        otpChannel.value = value;
        _otpSentKey = submission.otpKey;
        _startResendCountdown();
        return WithdrawalOutcome.success;
      case FinanceV2Err<String>(:final failure):
        final isResendOfSentCode = _otpSentKey == submission.otpKey &&
            failure.kind == FinanceV2FailureKind.other;
        if (isResendOfSentCode) {
          // The code already sent still works: keep the boxes usable.
          otpResendNotice.value = failure.message;
          _startResendCountdown();
          return WithdrawalOutcome.invalid;
        }
        return _onSendOtpFailure(failure);
    }
  }

  /// Sends the frozen withdrawal with [otp]. [withChangedQuote] resends it
  /// once with the quote of a QUOTE_CHANGED answer. A quote that ran out in
  /// the meantime reloads the cards and sends nothing.
  Future<WithdrawalOutcome> submit(
    String otp, {
    bool withChangedQuote = false,
  }) async {
    final code = otp.trim();
    if (code.isEmpty) {
      otpError.value = _tr('kyc_bank_controller_please_enter_otp');
      return WithdrawalOutcome.invalid;
    }
    if (code.length != otpLength) {
      otpError.value = _tr('withdrawal_screen_otp_must_be_six_digits');
      return WithdrawalOutcome.invalid;
    }

    var submission = _submission;
    if (submission == null || isSubmitting.value) {
      return WithdrawalOutcome.invalid;
    }

    if (withChangedQuote) {
      final newQuote = changedQuote;
      if (newQuote == null) return WithdrawalOutcome.invalid;
      changedQuote = null;
      if (_isExpired(newQuote)) return _reloadQuotes();
      submission = submission.withChangedQuote(newQuote);
      _submission = submission;
    }
    if (_isExpired(submission.quote)) return _reloadQuotes();

    isSubmitting.value = true;
    otpError.value = null;
    submitError.value = null;

    final result = await _repository.submitWithdrawal(
      channelSlug: submission.channelSlug,
      paymentType: group.type,
      mt5AccountId: submission.accountId,
      amount: submission.amount,
      amountCurrency: submission.currency,
      quoteId: submission.quote.quoteId,
      otp: code,
      withdrawalSlug: submission.withdrawalSlug,
      cryptoAddress: submission.cryptoAddress,
      cryptoNetwork: submission.cryptoNetwork,
    );
    if (_disposed) return WithdrawalOutcome.invalid;
    isSubmitting.value = false;

    switch (result) {
      case FinanceV2Ok<String>(:final message):
        successMessage = message;
        endSubmission();
        return WithdrawalOutcome.success;
      case FinanceV2Err<String>(:final failure):
        return _onSubmitFailure(failure, submission);
    }
  }

  /// The client did not accept the new quote: forget it and reload the cards.
  Future<void> declineChangedQuote() {
    endSubmission();
    return refreshChannels();
  }

  /// Opens KYC from the locked channel section.
  void openKyc() => onKycRequired?.call();

  Future<WithdrawalOutcome> _reloadQuotes() async {
    endSubmission();
    await refreshChannels();
    return WithdrawalOutcome.quoteRefreshed;
  }

  WithdrawalOutcome _onSendOtpFailure(FinanceV2Failure failure) {
    switch (failure.kind) {
      case FinanceV2FailureKind.kycRequired:
        endSubmission();
        return WithdrawalOutcome.kycRequired;
      case FinanceV2FailureKind.financeDisabled:
        endSubmission();
        blockingMessage.value = failure.message;
        return WithdrawalOutcome.financeDisabled;
      case FinanceV2FailureKind.fieldError:
      case FinanceV2FailureKind.amountError:
        endSubmission();
        _showAmountError(failure.message);
        return WithdrawalOutcome.amountError;
      case FinanceV2FailureKind.quoteChanged:
      case FinanceV2FailureKind.otpInvalid:
      case FinanceV2FailureKind.other:
        otpSendError.value = failure.message;
        return WithdrawalOutcome.otpSendFailed;
    }
  }

  WithdrawalOutcome _onSubmitFailure(
    FinanceV2Failure failure,
    WithdrawalSubmission submission,
  ) {
    switch (failure.kind) {
      case FinanceV2FailureKind.kycRequired:
        endSubmission();
        return WithdrawalOutcome.kycRequired;
      case FinanceV2FailureKind.quoteChanged:
        final newQuote = failure.newQuote;
        // Asked once only: a second change just reloads the cards.
        if (submission.quoteWasChanged || newQuote == null) {
          endSubmission();
          unawaited(refreshChannels());
          return WithdrawalOutcome.quoteRefreshed;
        }
        changedQuote = newQuote;
        return WithdrawalOutcome.quoteChanged;
      case FinanceV2FailureKind.financeDisabled:
        endSubmission();
        blockingMessage.value = failure.message;
        return WithdrawalOutcome.financeDisabled;
      case FinanceV2FailureKind.fieldError:
      case FinanceV2FailureKind.amountError:
        endSubmission();
        _showAmountError(failure.message);
        return WithdrawalOutcome.amountError;
      case FinanceV2FailureKind.otpInvalid:
        otpError.value = failure.message;
        otpClearSignal.value++;
        return WithdrawalOutcome.otpInvalid;
      case FinanceV2FailureKind.other:
        endSubmission();
        if (!_isBusinessFailure(failure)) {
          submitError.value = failure.message;
          return WithdrawalOutcome.submitFailed;
        }
        rejectedChannels[submission.channelSlug] = failure.message;
        selectedChannelSlug.value =
            channels.firstWhereOrNull(_isSelectable)?.slug;
        return WithdrawalOutcome.channelRejected;
    }
  }

  /// True when the server itself refused the channel. A call that never got
  /// a business answer (no network, timeout, 5xx) carries no error_code, and
  /// must not grey a card.
  static bool _isBusinessFailure(FinanceV2Failure failure) {
    final httpCode = failure.httpCode;
    if (httpCode != null && httpCode >= 500) return false;
    final errorCode = failure.errorCode;
    if (errorCode != null && errorCode.isNotEmpty) return true;
    return httpCode != null && failure.message.isNotEmpty;
  }

  void _showAmountError(String message) {
    amountError.value = message;
    unawaited(refreshChannels());
  }

  void _scheduleChannels() {
    _debounceTimer?.cancel();
    // An answer still on its way belongs to the old amount.
    _channelsRequestId++;

    if (!_isPositive(amount)) {
      _showNoChannels(WithdrawalChannelsState.idle);
      return;
    }
    isFetchingChannels.value = true;
    _debounceTimer = Timer(_debounce, refreshChannels);
  }

  void _showChannels(List<FinanceChannel> loaded) {
    final previousSlug = selectedChannelSlug.value;
    channelsNeedKyc.value = false;
    channels.assignAll(loaded);
    final previous = loaded.firstWhereOrNull(
      (channel) => channel.slug == previousSlug && _isSelectable(channel),
    );
    selectedChannelSlug.value =
        (previous ?? loaded.firstWhereOrNull(_isSelectable))?.slug;
    channelsState.value = loaded.isEmpty
        ? WithdrawalChannelsState.empty
        : WithdrawalChannelsState.data;
  }

  void _showChannelsFailure(FinanceV2Failure failure) {
    switch (failure.kind) {
      case FinanceV2FailureKind.financeDisabled:
        _showNoChannels(WithdrawalChannelsState.idle);
        blockingMessage.value = failure.message;
      case FinanceV2FailureKind.fieldError:
      case FinanceV2FailureKind.amountError:
        _showNoChannels(WithdrawalChannelsState.empty);
        amountError.value = failure.message;
      case FinanceV2FailureKind.kycRequired:
        _showNoChannels(WithdrawalChannelsState.error);
        channelsError.value = failure.message;
        channelsNeedKyc.value = true;
        // Typing on would otherwise push the KYC screen on every answer.
        if (!_kycOpened) {
          _kycOpened = true;
          onKycRequired?.call();
        }
      case FinanceV2FailureKind.quoteChanged:
      case FinanceV2FailureKind.otpInvalid:
      case FinanceV2FailureKind.other:
        _showNoChannels(WithdrawalChannelsState.error);
        channelsError.value = failure.message;
    }
  }

  void _showNoChannels(WithdrawalChannelsState state) {
    isFetchingChannels.value = false;
    channelsNeedKyc.value = false;
    channels.clear();
    selectedChannelSlug.value = null;
    channelsState.value = state;
  }

  bool _validateForm() {
    if (selectedAccount.value == null) return false;

    if (amount.isEmpty) {
      amountError.value = _tr('deposit_validation_amount');
      return false;
    }
    if (!_isPositive(amount)) {
      amountError.value =
          _tr('withdrawal_screen_amount_must_be_greater_than_zero');
      return false;
    }
    if (isLocal) return true;

    if (!usesPastedAddress) {
      if (selectedMethod.value != null) return true;
      payToError.value =
          _tr('withdrawal_screen_please_add_withdrawal_method_to_continue');
      return false;
    }

    var isValid = true;
    if (networks.isNotEmpty && selectedNetwork.value == null) {
      networkError.value =
          _tr('deposit_instruction_controller_please_select_network');
      isValid = false;
    }
    if (!_isAddress(addressController.text.trim())) {
      addressError.value = _tr('fv2_enter_valid_address');
      isValid = false;
    }
    return isValid;
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    resendSeconds.value = resendDelaySeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds.value <= 1) {
        resendSeconds.value = 0;
        timer.cancel();
        return;
      }
      resendSeconds.value--;
    });
  }

  FinanceAccountOption? _accountToSelect(List<FinanceAccountOption> loaded) {
    if (loaded.isEmpty) return null;
    final wanted = initialAccountNumber?.trim() ?? '';
    if (wanted.isEmpty) return loaded.first;
    return loaded.firstWhereOrNull(
          (account) => account.id == wanted || account.title == wanted,
        ) ??
        loaded.first;
  }

  /// A saved method is preselected unless the client already typed an
  /// address of their own.
  UserWithdrawalMethod? _methodToSelect() {
    if (methods.isEmpty) return null;
    final typedOwnAddress =
        canPasteAddress && addressController.text.trim().isNotEmpty;
    return typedOwnAddress ? null : methods.first;
  }

  /// A method without withdrawal_method is not assumed to be of this type.
  bool _isOfThisType(UserWithdrawalMethod method) {
    final type = method.withdrawalMethod.trim().toLowerCase();
    return type.isNotEmpty && type == group.type.trim().toLowerCase();
  }

  bool _isSelectable(FinanceChannel channel) {
    return channel.isSelectable && !rejectedChannels.containsKey(channel.slug);
  }

  bool _isExpired(ChannelQuote quote) => quote.isExpiredAt(_now());

  static bool _isPositive(String value) {
    final parsed = double.tryParse(value.trim());
    return parsed != null && parsed > 0;
  }

  static bool _isAddress(String value) {
    return value.length >= _minAddressLength && !value.contains(RegExp(r'\s'));
  }
}

/// The values of one withdrawal, frozen when the client pressed submit: the
/// code is requested and the withdrawal is sent with these, whatever the form
/// shows by then.
class WithdrawalSubmission {
  final String accountId;
  final String amount;
  final String currency;
  final String channelSlug;
  final ChannelQuote quote;

  /// True once [quote] is the one of a QUOTE_CHANGED answer.
  final bool quoteWasChanged;
  final String? withdrawalSlug;
  final String? cryptoAddress;
  final String? cryptoNetwork;

  const WithdrawalSubmission({
    required this.accountId,
    required this.amount,
    required this.currency,
    required this.channelSlug,
    required this.quote,
    this.quoteWasChanged = false,
    this.withdrawalSlug,
    this.cryptoAddress,
    this.cryptoNetwork,
  });

  /// What a sent code belongs to.
  String get otpKey => '$accountId|$amount';

  WithdrawalSubmission withChangedQuote(ChannelQuote newQuote) {
    return WithdrawalSubmission(
      accountId: accountId,
      amount: amount,
      currency: currency,
      channelSlug: channelSlug,
      quote: newQuote,
      quoteWasChanged: true,
      withdrawalSlug: withdrawalSlug,
      cryptoAddress: cryptoAddress,
      cryptoNetwork: cryptoNetwork,
    );
  }
}
