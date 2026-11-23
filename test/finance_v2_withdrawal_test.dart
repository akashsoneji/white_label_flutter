import 'package:flutter_test/flutter_test.dart';

import 'package:crm_app/screens/finance_v2/data/finance_v2_repository.dart';
import 'package:crm_app/screens/finance_v2/data/finance_v2_result.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_channel.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_v2_failure.dart';
import 'package:crm_app/screens/finance_v2/data/models/payment_type_option.dart';
import 'package:crm_app/screens/finance_v2/data/models/user_withdrawal_method.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_account_option.dart';
import 'package:crm_app/screens/finance_v2/presentation/withdrawal/withdrawal_amount_controller.dart';

const String _address = 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE';

FinanceChannel _channel(
  String slug, {
  String quoteId = 'q1',
  bool expired = false,
  DateTime? expiresAt,
}) {
  final expiry = expiresAt ??
      (expired
          ? DateTime.now().subtract(const Duration(minutes: 1))
          : DateTime.now().add(const Duration(minutes: 2)));
  return FinanceChannel(
    slug: slug,
    eligible: true,
    quote: ChannelQuote(quoteId: quoteId, expiresAt: expiry),
  );
}

class _FakeRepository extends Fake implements FinanceV2Repository {
  /// Answers of getChannels, in call order; the last one repeats.
  List<List<FinanceChannel>> channelAnswers = <List<FinanceChannel>>[];

  /// When set, getChannels fails with it.
  FinanceV2Failure? channelFailure;
  List<UserWithdrawalMethod> methods = const <UserWithdrawalMethod>[];

  /// Answers of submitWithdrawal, in call order; a missing one is a success.
  List<FinanceV2Failure?> submitFailures = <FinanceV2Failure?>[];

  /// Answers of the sendOTP calls in order; null or missing = success.
  List<FinanceV2Failure?> otpFailures = <FinanceV2Failure?>[];

  int channelCalls = 0;
  final List<String> channelAmounts = <String>[];
  final List<Map<String, String>> otpRequests = <Map<String, String>>[];
  final List<String> methodSlugCalls = <String>[];
  final List<Map<String, String?>> submits = <Map<String, String?>>[];

  int get otpCalls => otpRequests.length;

  @override
  Future<FinanceV2Result<List<FinanceChannel>>> getChannels({
    required String type,
    required String paymentType,
    required String amount,
    required String amountCurrency,
  }) async {
    channelCalls++;
    channelAmounts.add(amount);
    final failure = channelFailure;
    if (failure != null) return FinanceV2Err(failure);
    final index = channelCalls <= channelAnswers.length
        ? channelCalls - 1
        : channelAnswers.length - 1;
    return FinanceV2Ok(channelAnswers[index]);
  }

  @override
  Future<FinanceV2Result<List<UserWithdrawalMethod>>> getUserWithdrawalMethods(
    String methodSlug,
  ) async {
    methodSlugCalls.add(methodSlug);
    return FinanceV2Ok(methods);
  }

  @override
  Future<FinanceV2Result<String>> sendWithdrawalOtp({
    required String mt5AccountId,
    required String amount,
  }) async {
    otpRequests.add(<String, String>{'account': mt5AccountId, 'amount': amount});
    final index = otpRequests.length - 1;
    final failure = index < otpFailures.length ? otpFailures[index] : null;
    if (failure != null) return FinanceV2Err(failure);
    return FinanceV2Ok('email');
  }

  @override
  Future<FinanceV2Result<String>> submitWithdrawal({
    required String channelSlug,
    required String paymentType,
    required String mt5AccountId,
    required String amount,
    required String amountCurrency,
    required String quoteId,
    required String otp,
    String? withdrawalSlug,
    String? cryptoAddress,
    String? cryptoNetwork,
  }) async {
    final failure = submits.length < submitFailures.length
        ? submitFailures[submits.length]
        : null;
    submits.add(<String, String?>{
      'channel': channelSlug,
      'type': paymentType,
      'account': mt5AccountId,
      'amount': amount,
      'currency': amountCurrency,
      'quote': quoteId,
      'otp': otp,
      'slug': withdrawalSlug,
      'address': cryptoAddress,
      'network': cryptoNetwork,
    });
    if (failure != null) return FinanceV2Err(failure);
    return FinanceV2Ok('done', message: 'done');
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<WithdrawalAmountController> _open(
  _FakeRepository repository,
  PaymentTypeGroup group, {
  String amount = '100',
  DateTime Function()? now,
  void Function()? onKycRequired,
}) async {
  final controller = WithdrawalAmountController(
    group: group,
    repository: repository,
    accountsLoader: () async => const <FinanceAccountOption>[
      FinanceAccountOption(id: '1001', title: '1001'),
    ],
    translate: (key) => key,
    debounce: Duration.zero,
    now: now,
  );
  controller.onKycRequired = onKycRequired;
  controller.onInit();
  await _settle();
  controller.amountController.text = amount;
  controller.onAmountChanged(amount);
  await controller.refreshChannels();
  addTearDown(controller.onClose);
  return controller;
}

const PaymentTypeGroup _localGroup = PaymentTypeGroup(
  type: 'local',
  rows: <PaymentTypeOption>[PaymentTypeOption(methodSlug: 'cash')],
);

const PaymentTypeGroup _cryptoPasteGroup = PaymentTypeGroup(
  type: 'crypto',
  rows: <PaymentTypeOption>[
    PaymentTypeOption(
      methodSlug: 'crypto',
      cryptoSkipOtp: true,
      allowedCryptoNetworks: <CryptoNetworkOption>[
        CryptoNetworkOption(slug: 'trc20', label: 'TRC20'),
      ],
    ),
  ],
);

const PaymentTypeGroup _bankGroup = PaymentTypeGroup(
  type: 'bank',
  rows: <PaymentTypeOption>[PaymentTypeOption(methodSlug: 'bank-transfer')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('type local sends no saved method and never loads them', () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cash-desk')],
      ];
    final controller = await _open(repository, _localGroup);

    expect(controller.canSubmit, isTrue);
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.sendOtp(), WithdrawalOutcome.success);
    expect(controller.otpChannel.value, 'email');
    expect(await controller.submit('123456'), WithdrawalOutcome.success);

    expect(repository.methodSlugCalls, isEmpty);
    final sent = repository.submits.single;
    expect(sent['slug'], isNull);
    expect(sent['address'], isNull);
    expect(sent['network'], isNull);
    expect(sent['channel'], 'cash-desk');
    expect(sent['quote'], 'q1');
    expect(sent['account'], '1001');
  });

  test('saved methods are filtered to the type and the slug is sent', () async {
    final repository = _FakeRepository()
      ..methods = const <UserWithdrawalMethod>[
        UserWithdrawalMethod(withdrawalSlug: 'w-upi', withdrawalMethod: 'upi'),
        UserWithdrawalMethod(withdrawalSlug: 'w-bank', withdrawalMethod: 'bank'),
      ]
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('bank-a')],
      ];
    final controller = await _open(repository, _bankGroup);

    expect(repository.methodSlugCalls, <String>['bank-transfer']);
    expect(controller.methods.map((m) => m.withdrawalSlug), <String>['w-bank']);
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.submit('123456'), WithdrawalOutcome.success);
    expect(repository.submits.single['slug'], 'w-bank');
    expect(repository.submits.single['address'], isNull);
  });

  test('saved methods without a withdrawal slug are skipped', () async {
    final repository = _FakeRepository()
      ..methods = const <UserWithdrawalMethod>[
        UserWithdrawalMethod(withdrawalSlug: '', withdrawalMethod: 'bank'),
        UserWithdrawalMethod(withdrawalSlug: '  ', withdrawalMethod: 'bank'),
        UserWithdrawalMethod(withdrawalSlug: 'w-bank', withdrawalMethod: 'bank'),
      ]
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('bank-a')],
      ];
    final controller = await _open(repository, _bankGroup);

    expect(controller.methods.map((m) => m.withdrawalSlug), <String>['w-bank']);
    expect(controller.selectedMethod.value?.withdrawalSlug, 'w-bank');
  });

  test('a saved method without withdrawal_method is not of the type',
      () async {
    final repository = _FakeRepository()
      ..methods = const <UserWithdrawalMethod>[
        UserWithdrawalMethod(withdrawalSlug: 'w-none', withdrawalMethod: ''),
        UserWithdrawalMethod(withdrawalSlug: 'w-caps', withdrawalMethod: 'BANK'),
      ]
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('bank-a')],
      ];
    final controller = await _open(repository, _bankGroup);

    expect(controller.methods.map((m) => m.withdrawalSlug), <String>['w-caps']);
  });

  test('no saved method blocks the submit with the pay-to message', () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('bank-a')],
      ];
    final controller = await _open(repository, _bankGroup);

    expect(controller.canSubmit, isFalse);
    expect(await controller.prepareSubmit(), WithdrawalOutcome.invalid);
    expect(controller.payToError.value, isNotNull);
    expect(repository.otpCalls, 0);
  });

  test('crypto with a pasted address sends address and network', () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cregis')],
      ];
    final controller = await _open(repository, _cryptoPasteGroup);

    expect(controller.usesPastedAddress, isTrue);

    controller.pasteAddress('short');
    expect(await controller.prepareSubmit(), WithdrawalOutcome.invalid);
    expect(controller.addressError.value, 'fv2_enter_valid_address');
    expect(controller.networkError.value, isNotNull);

    controller.selectNetwork(controller.networks.single);
    controller.pasteAddress('  $_address  ');
    expect(controller.addressController.text, _address);
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.submit('123456'), WithdrawalOutcome.success);

    final sent = repository.submits.single;
    expect(sent['slug'], isNull);
    expect(sent['address'], _address);
    expect(sent['network'], 'trc20');
  });

  test('an expired quote reloads the cards and sends nothing', () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cash-desk', quoteId: 'old', expired: true)],
        <FinanceChannel>[_channel('cash-desk', quoteId: 'fresh')],
      ];
    final controller = await _open(repository, _localGroup);
    expect(repository.channelCalls, 1);

    expect(await controller.prepareSubmit(), WithdrawalOutcome.quoteRefreshed);

    expect(repository.channelCalls, 2);
    expect(repository.otpCalls, 0);
    expect(repository.submits, isEmpty);
    expect(controller.selectedChannel?.quote?.quoteId, 'fresh');
  });

  test('a quote that ran out while the code was typed is not sent', () async {
    var clock = DateTime(2026, 1, 1, 12);
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[
          _channel(
            'cash-desk',
            quoteId: 'old',
            expiresAt: clock.add(const Duration(minutes: 1)),
          ),
        ],
        <FinanceChannel>[
          _channel(
            'cash-desk',
            quoteId: 'fresh',
            expiresAt: clock.add(const Duration(minutes: 10)),
          ),
        ],
      ];
    final controller = await _open(repository, _localGroup, now: () => clock);

    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.sendOtp(), WithdrawalOutcome.success);

    clock = clock.add(const Duration(minutes: 2));
    expect(await controller.submit('123456'), WithdrawalOutcome.quoteRefreshed);

    expect(repository.submits, isEmpty);
    expect(repository.channelCalls, 2);
    expect(controller.selectedChannel?.quote?.quoteId, 'fresh');
    expect(controller.isLocked, isFalse);
  });

  test('a wrong code keeps the form and asks to clear the code', () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cash-desk')],
      ]
      ..submitFailures = <FinanceV2Failure?>[
        const FinanceV2Failure(
          message: 'Invalid OTP',
          kind: FinanceV2FailureKind.otpInvalid,
        ),
      ];
    final controller = await _open(repository, _localGroup);
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);

    expect(await controller.submit('12345'), WithdrawalOutcome.invalid);
    expect(repository.submits, isEmpty);

    expect(await controller.submit('000000'), WithdrawalOutcome.otpInvalid);
    expect(controller.otpError.value, 'Invalid OTP');
    expect(controller.otpClearSignal.value, 1);
    expect(controller.selectedChannel?.slug, 'cash-desk');
    expect(controller.isSubmitting.value, isFalse);

    expect(await controller.submit('123456'), WithdrawalOutcome.success);
    expect(repository.submits, hasLength(2));
  });

  test('a changed quote is resent once with the new quote id', () async {
    const changed = FinanceV2Failure(
      message: 'Rate changed',
      kind: FinanceV2FailureKind.quoteChanged,
      newQuote: ChannelQuote(quoteId: 'q2'),
    );
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cash-desk')],
      ]
      ..submitFailures = <FinanceV2Failure?>[changed, changed];
    final controller = await _open(repository, _localGroup);
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);

    expect(await controller.submit('123456'), WithdrawalOutcome.quoteChanged);
    expect(controller.changedQuote?.quoteId, 'q2');

    expect(
      await controller.submit('123456', withChangedQuote: true),
      WithdrawalOutcome.quoteRefreshed,
    );
    expect(repository.submits.last['quote'], 'q2');
    expect(controller.changedQuote, isNull);
    await _settle();
  });

  test('a changed quote that ran out is not resent', () async {
    var clock = DateTime(2026, 1, 1, 12);
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[
          _channel(
            'cash-desk',
            expiresAt: clock.add(const Duration(minutes: 10)),
          ),
        ],
      ]
      ..submitFailures = <FinanceV2Failure?>[
        FinanceV2Failure(
          message: 'Rate changed',
          kind: FinanceV2FailureKind.quoteChanged,
          newQuote: ChannelQuote(
            quoteId: 'q2',
            expiresAt: clock.add(const Duration(seconds: 30)),
          ),
        ),
      ];
    final controller = await _open(repository, _localGroup, now: () => clock);
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.submit('123456'), WithdrawalOutcome.quoteChanged);

    clock = clock.add(const Duration(minutes: 1));
    expect(
      await controller.submit('123456', withChangedQuote: true),
      WithdrawalOutcome.quoteRefreshed,
    );

    expect(repository.submits, hasLength(1));
    expect(repository.channelCalls, 2);
    expect(controller.changedQuote, isNull);
    expect(controller.isLocked, isFalse);
  });

  test('the code and the submit use the values frozen at submit', () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('first'), _channel('second', quoteId: 'q9')],
      ];
    final controller = await _open(repository, _localGroup, amount: ' 007.50 ');
    expect(repository.channelAmounts.last, '7.50');

    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(controller.isLocked, isTrue);
    expect(controller.canSubmit, isFalse);

    // The inputs refuse changes while locked.
    controller.onAmountChanged('999');
    controller.selectCurrency('EUR');
    controller.selectChannel(controller.channels.last);
    expect(controller.amount, '7.50');
    expect(controller.currency.value, 'USD');
    expect(controller.selectedChannel?.slug, 'first');

    // Even a form that changed under it does not reach the server.
    controller.amountText.value = '999';
    controller.currency.value = 'EUR';
    controller.selectedChannelSlug.value = 'second';
    controller.selectedAccount.value =
        const FinanceAccountOption(id: '2002', title: '2002');

    expect(await controller.sendOtp(), WithdrawalOutcome.success);
    expect(
      repository.otpRequests.single,
      <String, String>{'account': '1001', 'amount': '7.50'},
    );

    expect(await controller.submit('123456'), WithdrawalOutcome.success);
    final sent = repository.submits.single;
    expect(sent['account'], '1001');
    expect(sent['amount'], '7.50');
    expect(sent['currency'], 'USD');
    expect(sent['channel'], 'first');
    expect(sent['quote'], 'q1');
    expect(controller.isLocked, isFalse);
  });

  test('reopening the sheet during the countdown sends no second code',
      () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cash-desk')],
      ];
    final controller = await _open(repository, _localGroup);

    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.requestOtpOnOpen(), WithdrawalOutcome.success);
    expect(repository.otpCalls, 1);
    expect(controller.resendSeconds.value, greaterThan(0));

    controller.endSubmission();
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.requestOtpOnOpen(), WithdrawalOutcome.success);
    expect(repository.otpCalls, 1);

    // Another amount is another code.
    controller.endSubmission();
    controller.onAmountChanged('250');
    await controller.refreshChannels();
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.requestOtpOnOpen(), WithdrawalOutcome.success);
    expect(repository.otpCalls, 2);
  });

  test('a throttled resend keeps the code already sent usable', () async {
    const throttled = FinanceV2Failure(
      message: 'Please wait for 1 minute before resending OTP.',
      kind: FinanceV2FailureKind.other,
    );
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cash-desk')],
      ]
      ..otpFailures = <FinanceV2Failure?>[null, throttled];
    final controller = await _open(repository, _localGroup);

    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.requestOtpOnOpen(), WithdrawalOutcome.success);

    expect(await controller.sendOtp(), isNot(WithdrawalOutcome.otpSendFailed));
    expect(repository.otpCalls, 2);
    expect(controller.otpSendError.value, isNull);
    expect(controller.otpResendNotice.value, throttled.message);
    expect(controller.resendSeconds.value, greaterThan(0));
  });

  test('a first code that cannot be sent shows the failed state', () async {
    const refused = FinanceV2Failure(
      message: 'Please wait for 1 minute before resending OTP.',
      kind: FinanceV2FailureKind.other,
    );
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cash-desk')],
      ]
      ..otpFailures = <FinanceV2Failure?>[refused];
    final controller = await _open(repository, _localGroup);

    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
    expect(await controller.requestOtpOnOpen(), WithdrawalOutcome.otpSendFailed);
    expect(controller.otpSendError.value, refused.message);
    expect(controller.otpResendNotice.value, isNull);
  });

  test('a code asked for without a prepared submit shows the failed state',
      () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('cash-desk')],
      ];
    final controller = await _open(repository, _localGroup);

    expect(await controller.sendOtp(), WithdrawalOutcome.otpSendFailed);
    expect(controller.otpSendError.value, isNotNull);
    expect(repository.otpCalls, 0);
  });

  test('a server refusal greys the card and selects the next one', () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('first'), _channel('second', quoteId: 'q9')],
      ]
      ..submitFailures = <FinanceV2Failure?>[
        const FinanceV2Failure(
          message: 'Channel is busy',
          errorCode: 'CHANNEL_UNAVAILABLE',
          kind: FinanceV2FailureKind.other,
        ),
      ];
    final controller = await _open(repository, _localGroup);
    expect(controller.selectedChannel?.slug, 'first');
    expect(await controller.prepareSubmit(), WithdrawalOutcome.success);

    expect(await controller.submit('123456'), WithdrawalOutcome.channelRejected);
    expect(controller.selectedChannel?.slug, 'second');
    expect(
      controller.ineligibleReasonOf(controller.channels.first),
      'Channel is busy',
    );
  });

  test('a network error or a 5xx keeps the selected card', () async {
    final repository = _FakeRepository()
      ..channelAnswers = <List<FinanceChannel>>[
        <FinanceChannel>[_channel('first'), _channel('second', quoteId: 'q9')],
      ]
      ..submitFailures = <FinanceV2Failure?>[
        const FinanceV2Failure(
          message: 'No internet connection',
          kind: FinanceV2FailureKind.other,
        ),
        const FinanceV2Failure(
          message: 'Server error',
          httpCode: 503,
          errorCode: 'SERVER_ERROR',
          kind: FinanceV2FailureKind.other,
        ),
      ];
    final controller = await _open(repository, _localGroup);

    for (final message in <String>['No internet connection', 'Server error']) {
      expect(await controller.prepareSubmit(), WithdrawalOutcome.success);
      expect(await controller.submit('123456'), WithdrawalOutcome.submitFailed);
      expect(controller.submitError.value, message);
      expect(controller.selectedChannel?.slug, 'first');
      expect(controller.rejectedChannels, isEmpty);
      expect(controller.isLocked, isFalse);
    }
  });

  test('KYC_REQUIRED on the cards opens KYC once per screen', () async {
    var opened = 0;
    final repository = _FakeRepository()
      ..channelFailure = const FinanceV2Failure(
        message: 'Please verify your profile',
        errorCode: FinanceV2Failure.kycRequiredCode,
        kind: FinanceV2FailureKind.kycRequired,
      );
    final controller = await _open(
      repository,
      _localGroup,
      onKycRequired: () => opened++,
    );
    expect(opened, 1);

    await controller.refreshChannels();
    await controller.refreshChannels();

    expect(opened, 1);
    expect(controller.channelsNeedKyc.value, isTrue);
    expect(controller.channelsState.value, WithdrawalChannelsState.error);
    expect(controller.channelsError.value, 'Please verify your profile');

    // The button of the locked state still opens it.
    controller.openKyc();
    expect(opened, 2);
  });

  test('the amount is normalised before it is sent', () {
    const normalize = WithdrawalAmountController.normalizeAmount;

    expect(normalize(' 100 '), '100');
    expect(normalize('5.'), '5');
    expect(normalize('.5'), '0.5');
    expect(normalize('007.50'), '7.50');
    expect(normalize('0.5'), '0.5');
    expect(normalize('000'), '0');
    expect(normalize('00.25'), '0.25');
    expect(normalize('.'), '');
    expect(normalize(''), '');
  });
}
