import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:crm_app/services/language_service.dart';

import '../../data/finance_v2_repository.dart';
import '../../data/finance_v2_result.dart';
import '../../data/models/deposit_method_detail.dart';
import '../../data/models/deposit_submit_result.dart';
import '../../data/models/finance_channel.dart';
import '../../data/models/finance_v2_failure.dart';

import 'deposit_flow_action.dart';
import 'deposit_proof_validator.dart';

/// What the amount screen hands to the details screen.
class DepositDetailsArgs {
  final FinanceChannel channel;
  final ChannelQuote quote;

  /// Raw type of the tile (crypto, bank ...), needed to refresh the quote.
  final String paymentType;
  final String accountId;
  final String amount;
  final String amountCurrency;

  /// Set when the deposit was already created by a direct submit: the screen
  /// then only shows where to pay and the reference.
  final DepositSubmitResult? submitted;

  const DepositDetailsArgs({
    required this.channel,
    required this.quote,
    required this.paymentType,
    required this.accountId,
    required this.amount,
    required this.amountCurrency,
    this.submitted,
  });
}

/// State of the deposit details screen.
///
/// The controller never navigates; [submit] and [confirmNewQuote] return a
/// [DepositFlowAction] the screen acts on.
class DepositDetailsController extends GetxController {
  static const String utrField = 'utr_referce';
  static const String noteField = 'client_note';
  static const String proofField = 'proof';

  /// Key of the payer field that picks the gateway's payment page.
  static const String paymentPageKey = 'payment_page';

  DepositDetailsController({
    required FinanceV2Repository repository,
    required this.args,
    String Function(String key)? translate,
  })  : _repository = repository,
        _translate = translate ?? TranslationUtils.tr,
        quote = args.quote.obs {
    // The server names the UTR field in more than one way (`utr*`).
    _watch(
      utrController,
      (fieldName) => fieldName.toLowerCase().startsWith('utr'),
    );
    _watch(noteController, (fieldName) => fieldName == noteField);
  }

  final FinanceV2Repository _repository;
  final String Function(String key) _translate;
  final DepositDetailsArgs args;

  final Rx<ChannelQuote> quote;
  final isLoading = true.obs;
  final loadError = RxnString();
  final detail = Rxn<DepositMethodDetail>();

  final utrController = TextEditingController();
  final noteController = TextEditingController();

  /// One controller per payer field, keyed by [PayerField.key].
  final Map<String, TextEditingController> payerControllers =
      <String, TextEditingController>{};

  /// The value to send for a payer field that shows an option's label,
  /// keyed by [PayerField.key].
  final Map<String, String> _payerValues = <String, String>{};

  /// Keys of the payer details the server already holds for the client.
  Set<String> _savedPayerKeys = const <String>{};

  final proof = Rxn<File>();
  final proofError = RxnString();

  /// Server messages by field name (utr_referce, payer_mobile ...).
  final fieldErrors = <String, String>{}.obs;
  final isSubmitting = false.obs;

  /// Bumped on every edit so `Obx` readers of [canSubmit] rebuild.
  final _revision = 0.obs;
  bool _isDirty = false;

  bool get isAlreadySubmitted => args.submitted != null;

  /// True once the client typed or attached something.
  bool get isDirty => _isDirty;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    utrController.dispose();
    noteController.dispose();
    for (final controller in payerControllers.values) {
      controller.dispose();
    }
    super.onClose();
  }

  Future<void> load() async {
    if (isAlreadySubmitted) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    loadError.value = null;

    final (result, savedPayer) = await (
      _repository.getDepositMethodDetail(args.channel.slug),
      _repository.getSavedPayerKeys(),
    ).wait;
    if (isClosed) return;

    // A failed saved-payer call does not block the deposit: every payer field
    // is then asked for.
    _savedPayerKeys = switch (savedPayer) {
      FinanceV2Ok<Set<String>>(:final value) => value,
      FinanceV2Err<Set<String>>() => const <String>{},
    };

    switch (result) {
      case FinanceV2Ok<DepositMethodDetail>(:final value):
        _applyDetail(value);
      case FinanceV2Err<DepositMethodDetail>(:final failure):
        loadError.value = failure.message;
    }
    isLoading.value = false;
  }

  /// The payment page in force: the only one the option has, else the one the
  /// client picked.
  String get _chosenPaymentPage {
    final field = detail.value?.payerFields.firstWhereOrNull(
      (item) => item.key == paymentPageKey,
    );
    if (field == null) return '';
    if (field.options.length == 1) return field.options.single.value;
    return _payerValues[paymentPageKey] ?? '';
  }

  /// A payer field is asked for unless the server already holds its value, it
  /// is a payment page with nothing to choose, or it belongs to another
  /// payment page than the chosen one.
  bool isVisible(PayerField field) {
    if (_savedPayerKeys.contains(field.key)) return false;
    if (field.key == paymentPageKey) return field.options.length >= 2;
    if (field.requiredWhenPaymentPage.isEmpty) return true;
    return field.requiredWhenPaymentPage.contains(_chosenPaymentPage);
  }

  /// A field tied to the chosen payment page is always required while shown.
  bool isRequired(PayerField field) =>
      isVisible(field) &&
      (field.required || field.requiredWhenPaymentPage.isNotEmpty);

  /// The payer fields to show, in the server's order.
  List<PayerField> get visiblePayerFields {
    _revision.value;
    final fields = detail.value?.payerFields ?? const <PayerField>[];
    return fields.where(isVisible).toList(growable: false);
  }

  String? errorFor(String fieldName) {
    final message = fieldErrors[fieldName];
    return message == null || message.isEmpty ? null : message;
  }

  /// The server names the UTR field in more than one way (`utr*`).
  String? get utrError {
    for (final entry in fieldErrors.entries) {
      if (entry.key.toLowerCase().startsWith('utr') && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    return null;
  }

  bool get canSubmit {
    _revision.value;
    final detail = this.detail.value;
    if (detail == null || isSubmitting.value) return false;
    if (detail.showUtr &&
        detail.requireUtr &&
        utrController.text.trim().isEmpty) {
      return false;
    }
    if (detail.showProof && detail.requireProof && proof.value == null) {
      return false;
    }
    return visiblePayerFields.every(
      (field) =>
          !isRequired(field) ||
          (payerControllers[field.key]?.text.trim().isNotEmpty ?? false),
    );
  }

  /// Accepts [file] as the payment proof when it is a JPG or PNG of at most
  /// 2 MB; otherwise keeps no file and sets [proofError]. [sizeBytes] is read
  /// from disk when not given, which throws when the file cannot be read.
  Future<bool> setProof(File file, {int? sizeBytes}) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final size = sizeBytes ?? await file.length();
    if (isClosed) return false;

    final isValid = isValidDepositProof(fileName: fileName, sizeBytes: size);
    proof.value = isValid ? file : null;
    proofError.value = isValid ? null : _translate('fv2_proof_invalid');
    _onEdited();
    return isValid;
  }

  void removeProof() {
    proof.value = null;
    proofError.value = null;
    _revision.value++;
  }

  /// Sends the deposit. A stale quote is refreshed first and goes through the
  /// quote-changed confirmation instead of being sent.
  Future<DepositFlowAction> submit() async {
    final detail = this.detail.value;
    if (detail == null || isSubmitting.value) return const DepositFlowNone();
    if (detail.showProof && detail.requireProof && proof.value == null) {
      proofError.value = _translate(
        'deposit_instruction_controller_please_upload_payment_proof_file',
      );
      return const DepositFlowNone();
    }
    if (!canSubmit) return const DepositFlowNone();

    if (quote.value.isExpired) return _refreshQuote();
    return _send(quote.value, isFirstAttempt: true);
  }

  /// Sends the deposit with the quote accepted in the quote-changed sheet.
  /// A second QUOTE_CHANGED is not asked again, and a quote that ran out
  /// while the sheet was open is not sent: both go back to fresh cards.
  Future<DepositFlowAction> confirmNewQuote(ChannelQuote newQuote) async {
    if (newQuote.isExpired) return const DepositFlowReloadChannels();
    quote.value = newQuote;
    return _send(newQuote, isFirstAttempt: false);
  }

  /// Puts [value] into a payer field. A value that is one of the field's
  /// options is shown by its label, while the value itself is what is sent.
  void selectPayerValue(PayerField field, String value) {
    final controller = payerControllers[field.key];
    if (controller == null) return;

    final option = field.options.firstWhereOrNull(
      (item) => item.value == value,
    );
    // Stored before the text changes: the text listener rebuilds the form,
    // and the fields shown depend on the chosen payment page.
    if (option == null) {
      _payerValues.remove(field.key);
    } else {
      _payerValues[field.key] = value;
    }
    final label = option?.label ?? '';
    controller.text = label.isNotEmpty ? label : value;
  }

  void _applyDetail(DepositMethodDetail value) {
    for (final field in value.payerFields) {
      if (!payerControllers.containsKey(field.key)) {
        final controller = TextEditingController();
        _watch(controller, (fieldName) => fieldName == field.fieldName);
        payerControllers[field.key] = controller;
      }
    }
    detail.value = value;
  }

  /// Reports an edit whenever the text of [controller] changes. [ownsError]
  /// names the server messages that described the old text.
  void _watch(
    TextEditingController controller,
    bool Function(String fieldName) ownsError,
  ) {
    var lastText = controller.text;
    controller.addListener(() {
      // Moving the cursor notifies too, and is not an edit.
      if (controller.text == lastText) return;
      lastText = controller.text;
      _onEdited(ownsError);
    });
  }

  /// Marks the form edited and drops the server messages [ownsError] matches.
  void _onEdited([bool Function(String fieldName)? ownsError]) {
    if (ownsError != null) {
      fieldErrors.removeWhere((fieldName, _) => ownsError(fieldName));
    }
    _isDirty = true;
    _revision.value++;
  }

  Future<DepositFlowAction> _refreshQuote() async {
    isSubmitting.value = true;
    final result = await _repository.getChannels(
      type: FinanceV2Repository.typeDeposit,
      paymentType: args.paymentType,
      amount: args.amount,
      amountCurrency: args.amountCurrency,
    );
    if (isClosed) return const DepositFlowNone();
    isSubmitting.value = false;

    switch (result) {
      case FinanceV2Ok<List<FinanceChannel>>(:final value):
        final fresh = value.firstWhereOrNull(
          (channel) => channel.slug == args.channel.slug,
        );
        final freshQuote = fresh?.quote;
        if (fresh == null || !fresh.isSelectable || freshQuote == null) {
          final reason = fresh?.reason ?? '';
          return DepositFlowMessage(
            reason.isNotEmpty ? reason : _translate('fv2_no_channel_for_amount'),
          );
        }
        return DepositFlowQuoteChanged(
          newQuote: freshQuote,
          oldYouGet: quote.value.youGet,
        );
      case FinanceV2Err<List<FinanceChannel>>(:final failure):
        return failure.kind == FinanceV2FailureKind.kycRequired
            ? const DepositFlowKyc()
            : DepositFlowMessage(failure.message);
    }
  }

  Map<String, dynamic> _extraFields(DepositMethodDetail detail) {
    return <String, dynamic>{
      if (detail.showUtr) utrField: utrController.text.trim(),
      if (detail.clientNoteEnabled) noteField: noteController.text.trim(),
      for (final field in detail.payerFields)
        if (_isSent(field)) field.fieldName: _payerValue(field),
    };
  }

  /// Saved fields are never sent: the server adds its own value, and the
  /// saved id number is masked. A payment page with a single option is sent
  /// although it is not shown.
  bool _isSent(PayerField field) {
    if (_savedPayerKeys.contains(field.key)) return false;
    return isVisible(field) || field.key == paymentPageKey;
  }

  String _payerValue(PayerField field) {
    if (field.key == paymentPageKey) return _chosenPaymentPage;

    final value = _payerValues[field.key] ??
        payerControllers[field.key]?.text.trim() ??
        '';
    return switch (field.key) {
      'account_no' => value.replaceAll(RegExp(r'\s'), ''),
      'id_country' => value.toUpperCase(),
      'id_number' when _payerValues['id_type'] == 'passport' =>
        value.toUpperCase(),
      _ => value,
    };
  }

  Future<DepositFlowAction> _send(
    ChannelQuote sendQuote, {
    required bool isFirstAttempt,
  }) async {
    final detail = this.detail.value;
    if (detail == null) return const DepositFlowNone();

    fieldErrors.clear();
    isSubmitting.value = true;
    final result = await _repository.submitDeposit(
      args.channel.depositApi,
      gatewayMethodId: args.channel.slug,
      mt5AccountId: args.accountId,
      amount: args.amount,
      amountCurrency: args.amountCurrency,
      quoteId: sendQuote.quoteId,
      extraFields: _extraFields(detail),
      proof: detail.showProof ? proof.value : null,
    );
    if (isClosed) return const DepositFlowNone();
    isSubmitting.value = false;

    switch (result) {
      case FinanceV2Ok<DepositSubmitResult>(:final value, :final message):
        return value.nextStep == DepositNextStep.redirect
            ? DepositFlowRedirect(value)
            : DepositFlowCreated(message);
      case FinanceV2Err<DepositSubmitResult>(:final failure):
        return _onSubmitFailure(failure, isFirstAttempt: isFirstAttempt);
    }
  }

  DepositFlowAction _onSubmitFailure(
    FinanceV2Failure failure, {
    required bool isFirstAttempt,
  }) {
    switch (failure.kind) {
      case FinanceV2FailureKind.kycRequired:
        return const DepositFlowKyc();
      case FinanceV2FailureKind.quoteChanged:
        final newQuote = failure.newQuote;
        if (isFirstAttempt && newQuote != null) {
          return DepositFlowQuoteChanged(
            newQuote: newQuote,
            oldYouGet: quote.value.youGet,
          );
        }
        // A second change is never accepted on the client's behalf: the
        // amount screen shows the new cards instead.
        return const DepositFlowReloadChannels();
      case FinanceV2FailureKind.fieldError:
        _applyFieldErrors(failure);
        return const DepositFlowFieldErrors();
      case FinanceV2FailureKind.financeDisabled:
      case FinanceV2FailureKind.amountError:
      case FinanceV2FailureKind.otpInvalid:
      case FinanceV2FailureKind.other:
        return DepositFlowMessage(failure.message);
    }
  }

  void _applyFieldErrors(FinanceV2Failure failure) {
    final errors = <String, String>{...failure.fieldErrors};
    final field = failure.field;
    if (field != null && (errors[field] ?? '').isEmpty) {
      errors[field] = failure.message;
    }
    fieldErrors.assignAll(errors);

    final proofMessage = errors[proofField] ?? errors['screenshot'];
    if (proofMessage != null && proofMessage.isNotEmpty) {
      proofError.value = proofMessage;
    }
  }
}
