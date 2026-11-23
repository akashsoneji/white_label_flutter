import 'dart:io';

import 'package:crm_app/screens/finance_v2/data/finance_v2_repository.dart';
import 'package:crm_app/screens/finance_v2/data/finance_v2_result.dart';
import 'package:crm_app/screens/finance_v2/data/models/deposit_method_detail.dart';
import 'package:crm_app/screens/finance_v2/data/models/deposit_status.dart';
import 'package:crm_app/screens/finance_v2/data/models/deposit_submit_result.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_channel.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_v2_failure.dart';
import 'package:crm_app/screens/finance_v2/presentation/deposit/deposit_amount_controller.dart';
import 'package:crm_app/screens/finance_v2/presentation/deposit/deposit_details_controller.dart';
import 'package:crm_app/screens/finance_v2/presentation/deposit/deposit_flow_action.dart';
import 'package:crm_app/screens/finance_v2/presentation/deposit/deposit_proof_validator.dart';
import 'package:crm_app/screens/finance_v2/presentation/deposit/payment_wait_controller.dart';
import 'package:crm_app/screens/finance_v2/presentation/deposit/payment_webview_screen.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_account_option.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _debounce = Duration(milliseconds: 20);
const Duration _settle = Duration(milliseconds: 80);

Map<String, dynamic> _quoteJson(String id, {bool expired = false}) {
  final expiry = DateTime.now().toUtc().add(
        expired ? const Duration(minutes: -5) : const Duration(minutes: 5),
      );
  return <String, dynamic>{
    'quote_id': id,
    'expires_at': expiry.toIso8601String(),
  };
}

FinanceChannel _channel(
  String slug, {
  bool eligible = true,
  bool redirect = true,
  bool offline = false,
  bool expired = false,
  String reason = '',
  String quoteId = 'q1',
}) {
  return FinanceChannel.fromJson(<String, dynamic>{
    'slug': slug,
    'label': slug,
    'eligible': eligible,
    'reason': reason,
    'is_redirect': redirect,
    'is_offline': offline,
    'deposit_api': '/deposit/$slug',
    'quote': _quoteJson(quoteId, expired: expired),
  });
}

FinanceV2Failure _failure(
  FinanceV2FailureKind kind, {
  String message = 'server says no',
  ChannelQuote? newQuote,
}) {
  return FinanceV2Failure(message: message, kind: kind, newQuote: newQuote);
}

/// Records the calls and answers from queues; the last answer repeats.
class _FakeRepository implements FinanceV2Repository {
  List<FinanceV2Result<List<FinanceChannel>>> channelAnswers =
      <FinanceV2Result<List<FinanceChannel>>>[];
  List<FinanceV2Result<DepositSubmitResult>> submitAnswers =
      <FinanceV2Result<DepositSubmitResult>>[];
  DepositOutcome outcome = DepositOutcome.pending;
  bool statusThrows = false;

  /// How long a status call takes; null answers at once.
  Duration? statusDelay;

  int channelCalls = 0;
  int statusCalls = 0;
  final List<String> submittedQuoteIds = <String>[];
  final List<String> submittedAmounts = <String>[];
  final List<String> submittedAccountIds = <String>[];
  String? submittedAccountId;

  @override
  Future<FinanceV2Result<List<FinanceChannel>>> getChannels({
    required String type,
    required String paymentType,
    required String amount,
    required String amountCurrency,
  }) async {
    final index = channelCalls++;
    return channelAnswers[index.clamp(0, channelAnswers.length - 1)];
  }

  @override
  Future<FinanceV2Result<DepositSubmitResult>> submitDeposit(
    String depositApi, {
    required String gatewayMethodId,
    required String mt5AccountId,
    required String amount,
    required String amountCurrency,
    required String quoteId,
    Map<String, dynamic> extraFields = const <String, dynamic>{},
    File? proof,
  }) async {
    final index = submittedQuoteIds.length;
    submittedQuoteIds.add(quoteId);
    submittedAmounts.add(amount);
    submittedAccountIds.add(mt5AccountId);
    submittedAccountId = mt5AccountId;
    return submitAnswers[index.clamp(0, submitAnswers.length - 1)];
  }

  @override
  Future<FinanceV2Result<DepositMethodDetail>> getDepositMethodDetail(
    String slug,
  ) async {
    return FinanceV2Ok(
      DepositMethodDetail.fromJson(<String, dynamic>{
        'depositMethod': <String, dynamic>{},
      }),
    );
  }

  @override
  Future<FinanceV2Result<DepositStatus>> getDepositByReference(
    String reference,
  ) async {
    statusCalls++;
    final delay = statusDelay;
    if (delay != null) await Future<void>.delayed(delay);
    if (statusThrows) throw const SocketException('offline');
    final status = switch (outcome) {
      DepositOutcome.paid => 'approved',
      DepositOutcome.failed => 'rejected',
      DepositOutcome.pending => 'pending',
    };
    return FinanceV2Ok(
      DepositStatus.fromJson(<String, dynamic>{
        'reference_number': reference,
        'status': status,
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const List<FinanceAccountOption> _accounts = <FinanceAccountOption>[
  FinanceAccountOption(id: 'W1', title: 'Wallet', isWallet: true),
  FinanceAccountOption(id: '5001', title: '5001'),
];

DepositAmountController _amountController(
  _FakeRepository repository, {
  String preselected = '',
}) {
  final controller = DepositAmountController(
    repository: repository,
    paymentType: 'crypto',
    preselectedAccountId: preselected,
    accountsLoader: () async => _accounts,
    translate: (key) => key,
    debounce: _debounce,
  );
  addTearDown(controller.onClose);
  return controller;
}

/// Loads the accounts, types an amount and waits for the cards.
Future<void> _typeAmount(DepositAmountController controller) async {
  await controller.loadAccounts();
  controller.onAmountChanged('100');
  await Future<void>.delayed(_settle);
}

void main() {
  group('deposit proof', () {
    test('accepts a JPG or PNG up to 2 MB', () {
      expect(isValidDepositProof(fileName: 'a.JPG', sizeBytes: 1024), isTrue);
      expect(
        isValidDepositProof(fileName: 'a.png', sizeBytes: depositProofMaxBytes),
        isTrue,
      );
    });

    test('rejects other types, empty files and files over 2 MB', () {
      expect(isValidDepositProof(fileName: 'a.pdf', sizeBytes: 1024), isFalse);
      expect(isValidDepositProof(fileName: 'noext', sizeBytes: 1024), isFalse);
      expect(isValidDepositProof(fileName: 'a.png', sizeBytes: 0), isFalse);
      expect(
        isValidDepositProof(
          fileName: 'a.png',
          sizeBytes: depositProofMaxBytes + 1,
        ),
        isFalse,
      );
    });
  });

  group('deposit amount', () {
    test('is sent trimmed, without a dangling point', () {
      expect(normalizeDepositAmount(' 100 '), '100');
      expect(normalizeDepositAmount('100.'), '100');
      expect(normalizeDepositAmount('.5'), '0.5');
      expect(normalizeDepositAmount('12.50'), '12.50');
      expect(normalizeDepositAmount('.'), '0');
    });
  });

  group('payment page', () {
    test('closes only on the dashboard fragment', () {
      expect(isPaymentReturnUrl('https://portal.example/#/dashboard'), isTrue);
      expect(
        isPaymentReturnUrl('https://portal.example/#/dashboard?paid=1'),
        isTrue,
      );
      expect(isPaymentReturnUrl('https://pay.example/#/checkout'), isFalse);
      expect(
        isPaymentReturnUrl('https://pay.example/cb?return=/dashboard'),
        isFalse,
      );
      expect(
        isPaymentReturnUrl(
          'https://pay.example/cb?next=https%3A%2F%2Fportal.example%2F%23%2Fdashboard',
        ),
        isFalse,
      );
      expect(isPaymentReturnUrl('upi://pay#/dashboard'), isFalse);
    });

    test('keeps web pages, hands apps to the system, drops the rest', () {
      expect(
        classifyPaymentNavigation('https://pay.example/3ds'),
        PaymentNavigation.allow,
      );
      expect(
        classifyPaymentNavigation('https://portal.example/#/dashboard'),
        PaymentNavigation.close,
      );
      expect(
        classifyPaymentNavigation('upi://pay?pa=shop@bank'),
        PaymentNavigation.external,
      );
      expect(
        classifyPaymentNavigation('tel:+911234567890'),
        PaymentNavigation.external,
      );
      expect(
        classifyPaymentNavigation('intent://pay#Intent;scheme=upi;end'),
        PaymentNavigation.external,
      );
      expect(
        classifyPaymentNavigation('javascript:alert(1)'),
        PaymentNavigation.block,
      );
      expect(
        classifyPaymentNavigation('file:///data/secret'),
        PaymentNavigation.block,
      );
    });

    test('an Android intent address becomes the app address', () {
      final uri = externalPaymentUri(
        'intent://pay?pa=shop#Intent;scheme=upi;package=com.bank;end',
      );
      expect(uri?.scheme, 'upi');
      expect(uri?.host, 'pay');
      expect(uri?.queryParameters['pa'], 'shop');
      expect(uri?.hasFragment, isFalse);

      expect(
        externalPaymentUri('intent://x#Intent;scheme=javascript;end'),
        isNull,
      );
      expect(externalPaymentUri('intent://x#Intent;end'), isNull);
    });
  });

  group('DepositAmountController', () {
    test('preselects the account it was opened with, else the first', () async {
      final preselected = _amountController(_FakeRepository(), preselected: '5001');
      await preselected.loadAccounts();
      expect(preselected.selectedAccount.value?.id, '5001');

      final unknown = _amountController(_FakeRepository(), preselected: 'nope');
      await unknown.loadAccounts();
      expect(unknown.selectedAccount.value?.id, 'W1');
    });

    test('debounces typing into one channels call', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('a')]),
        ];
      final controller = _amountController(repository);

      controller.onAmountChanged('1');
      controller.onAmountChanged('10');
      controller.onAmountChanged('100');
      expect(controller.isLoadingChannels, isTrue);
      await Future<void>.delayed(_settle);

      expect(repository.channelCalls, 1);
      expect(controller.isLoadingChannels, isFalse);
    });

    test('selects the first card that can be picked', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[
            _channel('blocked', eligible: false, reason: 'Below minimum'),
            _channel('open'),
          ]),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      expect(controller.selectedSlug.value, 'open');
      controller.selectChannel('blocked');
      expect(controller.selectedSlug.value, 'open');
      expect(controller.canContinue, isTrue);
    });

    test('clearing the amount drops the cards', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('a')]),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      controller.onAmountChanged('');
      expect(controller.channels, isEmpty);
      expect(controller.canContinue, isFalse);
    });

    test('a stale quote reloads the cards and sends nothing', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('a', expired: true)]),
          FinanceV2Ok(<FinanceChannel>[_channel('a', quoteId: 'q2')]),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      final action = await controller.continueDeposit();

      expect(action, isA<DepositFlowRatesUpdated>());
      expect(repository.submittedQuoteIds, isEmpty);
      expect(repository.channelCalls, 2);
      expect(controller.selectedChannel?.quote?.quoteId, 'q2');
    });

    test('an offline card opens the details screen without a submit', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[
            _channel('bank', redirect: false, offline: true),
          ]),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      final action = await controller.continueDeposit();

      expect(action, isA<DepositFlowOpenDetails>());
      expect(repository.submittedQuoteIds, isEmpty);
    });

    test('a redirect card submits and hands back the payment page', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ]
        ..submitAnswers = [
          FinanceV2Ok(
            DepositSubmitResult.fromJson(<String, dynamic>{
              'reference_number': 'REF1',
              'redirect_url': 'https://pay.example/1',
            }),
          ),
        ];
      final controller = _amountController(repository, preselected: '5001');
      await _typeAmount(controller);

      final action = await controller.continueDeposit();

      expect(action, isA<DepositFlowRedirect>());
      expect((action as DepositFlowRedirect).result.referenceNumber, 'REF1');
      expect(repository.submittedQuoteIds, <String>['q1']);
      expect(repository.submittedAccountId, '5001');
    });

    test('a submit without a payment page means the request was created',
        () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ]
        ..submitAnswers = [
          FinanceV2Ok(
            DepositSubmitResult.fromJson(<String, dynamic>{}),
            message: 'Saved',
          ),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      final action = await controller.continueDeposit();

      expect(action, isA<DepositFlowCreated>());
      expect((action as DepositFlowCreated).message, 'Saved');
    });

    test('KYC_REQUIRED on submit asks for verification', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ]
        ..submitAnswers = [
          FinanceV2Err(_failure(FinanceV2FailureKind.kycRequired)),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      expect(await controller.continueDeposit(), isA<DepositFlowKyc>());
    });

    test('QUOTE_CHANGED is confirmed once, then only reloads', () async {
      final newQuote = ChannelQuote.tryParse(_quoteJson('q2'));
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ]
        ..submitAnswers = [
          FinanceV2Err(
            _failure(FinanceV2FailureKind.quoteChanged, newQuote: newQuote),
          ),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      final first = await controller.continueDeposit();
      expect(first, isA<DepositFlowQuoteChanged>());

      final second = await controller.confirmNewQuote(
        (first as DepositFlowQuoteChanged).newQuote,
      );
      expect(second, isA<DepositFlowRatesUpdated>());
      expect(repository.submittedQuoteIds, <String>['q1', 'q2']);
      expect(repository.channelCalls, 2);
    });

    test('a resend after QUOTE_CHANGED uses what the deposit started with',
        () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ]
        ..submitAnswers = [
          FinanceV2Err(
            _failure(
              FinanceV2FailureKind.quoteChanged,
              newQuote: ChannelQuote.tryParse(_quoteJson('q2')),
            ),
          ),
          FinanceV2Ok(DepositSubmitResult.fromJson(<String, dynamic>{})),
        ];
      final controller = _amountController(repository);
      await controller.loadAccounts();
      controller.onAmountChanged('.5');
      await Future<void>.delayed(_settle);

      final first = await controller.continueDeposit();
      expect(first, isA<DepositFlowQuoteChanged>());
      expect(controller.submitSnapshot?.amount, '0.5');

      // Edits made while the quote-changed sheet is open.
      controller.selectAccount(_accounts.last);
      controller.amountText.value = '250';

      final second = await controller.confirmNewQuote(
        (first as DepositFlowQuoteChanged).newQuote,
      );

      expect(second, isA<DepositFlowCreated>());
      expect(repository.submittedQuoteIds, <String>['q1', 'q2']);
      expect(repository.submittedAmounts, <String>['0.5', '0.5']);
      expect(repository.submittedAccountIds, <String>['W1', 'W1']);
    });

    test('an accepted quote that ran out reloads the cards, sends nothing',
        () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ]
        ..submitAnswers = [
          FinanceV2Err(
            _failure(
              FinanceV2FailureKind.quoteChanged,
              newQuote: ChannelQuote.tryParse(_quoteJson('q2', expired: true)),
            ),
          ),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      final first = await controller.continueDeposit();
      final second = await controller.confirmNewQuote(
        (first as DepositFlowQuoteChanged).newQuote,
      );

      expect(second, isA<DepositFlowRatesUpdated>());
      expect(repository.submittedQuoteIds, <String>['q1']);
      expect(repository.channelCalls, 2);
    });

    test('changing the currency clears the amount error', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ];
      final controller = DepositAmountController(
        repository: repository,
        paymentType: 'crypto',
        amountCurrencies: const <String>['USD', 'INR'],
        accountsLoader: () async => _accounts,
        translate: (key) => key,
        debounce: _debounce,
      );
      addTearDown(controller.onClose);
      await _typeAmount(controller);

      controller.amountError.value = 'Too low';
      controller.selectCurrency('INR');

      expect(controller.amountError.value, isNull);
    });

    test('FINANCE_DISABLED on submit gives the server message', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ]
        ..submitAnswers = [
          FinanceV2Err(
            _failure(FinanceV2FailureKind.financeDisabled, message: 'Closed'),
          ),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      final action = await controller.continueDeposit();

      expect(action, isA<DepositFlowMessage>());
      expect((action as DepositFlowMessage).message, 'Closed');
    });

    test('an amount error lands under the amount field', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('card')]),
        ]
        ..submitAnswers = [
          FinanceV2Err(
            _failure(FinanceV2FailureKind.amountError, message: 'Too low'),
          ),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      expect(await controller.continueDeposit(), isA<DepositFlowNone>());
      expect(controller.amountError.value, 'Too low');
    });

    test('any other submit error greys the card and moves the selection',
        () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[_channel('first'), _channel('second')]),
        ]
        ..submitAnswers = [
          FinanceV2Err(
            _failure(FinanceV2FailureKind.other, message: 'Gateway down'),
          ),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);
      expect(controller.selectedSlug.value, 'first');

      expect(
        await controller.continueDeposit(),
        isA<DepositFlowMessage>().having(
          (action) => action.message,
          'message',
          'Gateway down',
        ),
      );

      final first = controller.channels.first;
      expect(controller.isSelectable(first), isFalse);
      expect(controller.reasonFor(first), 'Gateway down');
      expect(controller.selectedSlug.value, 'second');
    });

    test('KYC_REQUIRED while loading the cards raises the KYC flag', () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Err(_failure(FinanceV2FailureKind.kycRequired)),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      expect(controller.kycRequired.value, isTrue);
      expect(controller.canContinue, isFalse);
    });

    test('FINANCE_DISABLED while loading the cards cannot be retried',
        () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Err(
            _failure(FinanceV2FailureKind.financeDisabled, message: 'Closed'),
          ),
        ];
      final controller = _amountController(repository);
      await _typeAmount(controller);

      expect(controller.channelsError.value, 'Closed');
      expect(controller.canRetryChannels.value, isFalse);
    });
  });

  group('DepositDetailsController', () {
    DepositDetailsController detailsController(
      _FakeRepository repository, {
      bool expired = false,
    }) {
      final channel = _channel(
        'bank',
        redirect: false,
        offline: true,
        expired: expired,
      );
      final controller = DepositDetailsController(
        repository: repository,
        args: DepositDetailsArgs(
          channel: channel,
          quote: channel.quote!,
          paymentType: 'bank',
          accountId: '5001',
          amount: '100',
          amountCurrency: 'USD',
        ),
        translate: (key) => key,
      );
      addTearDown(controller.onClose);
      return controller;
    }

    test('keeps only a valid proof file', () async {
      final controller = detailsController(_FakeRepository());

      expect(
        await controller.setProof(File('/tmp/slip.pdf'), sizeBytes: 100),
        isFalse,
      );
      expect(controller.proof.value, isNull);
      expect(controller.proofError.value, 'fv2_proof_invalid');

      expect(
        await controller.setProof(
          File('/tmp/slip.png'),
          sizeBytes: depositProofMaxBytes + 1,
        ),
        isFalse,
      );
      expect(controller.proof.value, isNull);

      expect(
        await controller.setProof(File('/tmp/slip.jpg'), sizeBytes: 100),
        isTrue,
      );
      expect(controller.proof.value?.path, '/tmp/slip.jpg');
      expect(controller.proofError.value, isNull);
      expect(controller.isDirty, isTrue);
    });

    test('submits with the quote and reports the created request', () async {
      final repository = _FakeRepository()
        ..submitAnswers = [
          FinanceV2Ok(
            DepositSubmitResult.fromJson(<String, dynamic>{}),
            message: 'Saved',
          ),
        ];
      final controller = detailsController(repository);
      await controller.load();

      final action = await controller.submit();

      expect(action, isA<DepositFlowCreated>());
      expect(repository.submittedQuoteIds, <String>['q1']);
      expect(repository.submittedAccountId, '5001');
    });

    test('a stale quote is refreshed and confirmed before anything is sent',
        () async {
      final repository = _FakeRepository()
        ..channelAnswers = [
          FinanceV2Ok(<FinanceChannel>[
            _channel('bank', redirect: false, offline: true, quoteId: 'q2'),
          ]),
        ]
        ..submitAnswers = [
          FinanceV2Ok(DepositSubmitResult.fromJson(<String, dynamic>{})),
        ];
      final controller = detailsController(repository, expired: true);
      await controller.load();

      final action = await controller.submit();

      expect(action, isA<DepositFlowQuoteChanged>());
      expect(repository.submittedQuoteIds, isEmpty);

      await controller.confirmNewQuote(
        (action as DepositFlowQuoteChanged).newQuote,
      );
      expect(repository.submittedQuoteIds, <String>['q2']);
    });

    test('an accepted quote that ran out goes back for fresh cards', () async {
      final repository = _FakeRepository();
      final controller = detailsController(repository);
      await controller.load();

      final action = await controller.confirmNewQuote(
        ChannelQuote.tryParse(_quoteJson('q2', expired: true))!,
      );

      expect(action, isA<DepositFlowReloadChannels>());
      expect(repository.submittedQuoteIds, isEmpty);
      expect(controller.quote.value.quoteId, 'q1');
    });

    test('a second QUOTE_CHANGED never swaps the quote by itself', () async {
      final repository = _FakeRepository()
        ..submitAnswers = [
          FinanceV2Err(
            _failure(
              FinanceV2FailureKind.quoteChanged,
              newQuote: ChannelQuote.tryParse(_quoteJson('q2')),
            ),
          ),
          FinanceV2Err(
            _failure(
              FinanceV2FailureKind.quoteChanged,
              newQuote: ChannelQuote.tryParse(_quoteJson('q3')),
            ),
          ),
        ];
      final controller = detailsController(repository);
      await controller.load();

      final first = await controller.submit();
      final second = await controller.confirmNewQuote(
        (first as DepositFlowQuoteChanged).newQuote,
      );

      expect(second, isA<DepositFlowReloadChannels>());
      expect(repository.submittedQuoteIds, <String>['q1', 'q2']);
      expect(controller.quote.value.quoteId, 'q2');
    });

    test('a field error is kept under its field', () async {
      final repository = _FakeRepository()
        ..submitAnswers = [
          FinanceV2Err(
            const FinanceV2Failure(
              message: 'UTR is required',
              kind: FinanceV2FailureKind.fieldError,
              field: 'utr_referce',
            ),
          ),
        ];
      final controller = detailsController(repository);
      await controller.load();

      expect(await controller.submit(), isA<DepositFlowFieldErrors>());
      expect(controller.utrError, 'UTR is required');

      controller.utrController.text = 'UTR123';
      expect(controller.utrError, isNull);
    });
  });

  group('PaymentWaitController', () {
    PaymentWaitController waitController(
      _FakeRepository repository, {
      String reference = 'REF1',
      Duration pollInterval = const Duration(milliseconds: 10),
    }) {
      final controller = PaymentWaitController(
        repository: repository,
        reference: reference,
        pollInterval: pollInterval,
        timeout: const Duration(milliseconds: 60),
      );
      addTearDown(controller.onClose);
      return controller;
    }

    test('a paid deposit ends the wait', () async {
      final repository = _FakeRepository()..outcome = DepositOutcome.paid;
      final controller = waitController(repository)..start();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(controller.status.value, PaymentWaitStatus.paid);
      final calls = repository.statusCalls;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(repository.statusCalls, calls);
    });

    test('a rejected deposit is shown as failed', () async {
      final repository = _FakeRepository()..outcome = DepositOutcome.failed;
      final controller = waitController(repository)..start();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(controller.status.value, PaymentWaitStatus.failed);
    });

    test('running out of time means processing, never failed', () async {
      final repository = _FakeRepository();
      final controller = waitController(repository)..start();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(controller.status.value, PaymentWaitStatus.processing);
      expect(repository.statusCalls, greaterThan(0));
    });

    test('a failed status call keeps the wait going', () async {
      final repository = _FakeRepository()..statusThrows = true;
      final controller = waitController(repository)..start();
      await Future<void>.delayed(const Duration(milliseconds: 35));

      expect(controller.status.value, PaymentWaitStatus.waiting);
      expect(repository.statusCalls, greaterThan(0));
    });

    test('without a reference it is processing at once', () async {
      final repository = _FakeRepository();
      final controller = waitController(repository, reference: '')..start();

      expect(controller.status.value, PaymentWaitStatus.processing);
      await controller.pollNow();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(repository.statusCalls, 0);
    });

    test('a poll asked for during a running one follows it', () async {
      final repository = _FakeRepository()
        ..statusDelay = const Duration(milliseconds: 20);
      final controller = waitController(
        repository,
        pollInterval: const Duration(seconds: 30),
      )..start();

      final running = controller.pollNow();
      await controller.pollNow();
      expect(repository.statusCalls, 1);

      await running;
      expect(repository.statusCalls, 2);
    });

    test('stop ends the polling', () async {
      final repository = _FakeRepository();
      final controller = waitController(repository)..start();
      controller.stop();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(repository.statusCalls, 0);
      expect(controller.status.value, PaymentWaitStatus.waiting);
    });
  });
}
