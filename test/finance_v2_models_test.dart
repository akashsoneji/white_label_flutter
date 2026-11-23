import 'package:flutter_test/flutter_test.dart';

import 'package:crm_app/screens/finance_v2/data/finance_v2_grouping.dart';
import 'package:crm_app/screens/finance_v2/data/finance_v2_repository.dart';
import 'package:crm_app/screens/finance_v2/data/models/deposit_method_detail.dart';
import 'package:crm_app/screens/finance_v2/data/models/deposit_status.dart';
import 'package:crm_app/screens/finance_v2/data/models/deposit_submit_result.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_channel.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_v2_failure.dart';
import 'package:crm_app/screens/finance_v2/data/models/payment_type_option.dart';
import 'package:crm_app/screens/finance_v2/data/models/user_withdrawal_method.dart';

void main() {
  test('amount_currency is sent as "usd" or "local" only', () {
    expect(FinanceV2Repository.apiAmountCurrency('USD'), 'usd');
    expect(FinanceV2Repository.apiAmountCurrency(' usd '), 'usd');
    expect(FinanceV2Repository.apiAmountCurrency('INR'), 'local');
    expect(FinanceV2Repository.apiAmountCurrency('inr'), 'local');
    expect(FinanceV2Repository.apiAmountCurrency('KWD'), 'local');
  });

  group('FinanceV2Failure classification', () {
    FinanceV2FailureKind kindOf({
      int? httpCode,
      String? message,
      Map<String, dynamic>? data,
      bool isWithdrawalSubmit = false,
    }) {
      return FinanceV2Failure.from(
        httpCode: httpCode,
        message: message,
        data: data,
        isWithdrawalSubmit: isWithdrawalSubmit,
      ).kind;
    }

    test('403 KYC_REQUIRED is kycRequired, with or without the HTTP code', () {
      const data = <String, dynamic>{'error_code': 'KYC_REQUIRED'};
      expect(kindOf(httpCode: 403, data: data),
          FinanceV2FailureKind.kycRequired);
      expect(kindOf(data: data), FinanceV2FailureKind.kycRequired);
    });

    test('409 QUOTE_CHANGED carries the fresh quote', () {
      final failure = FinanceV2Failure.from(
        httpCode: 409,
        message: 'Price changed',
        data: <String, dynamic>{
          'error_code': 'QUOTE_CHANGED',
          'quote': <String, dynamic>{
            'quote_id': 'new-quote',
            'display': <String, dynamic>{'you_pay': '2,150.00 INR'},
          },
        },
      );
      expect(failure.kind, FinanceV2FailureKind.quoteChanged);
      expect(failure.newQuote?.quoteId, 'new-quote');
      expect(failure.newQuote?.youPay, '2,150.00 INR');
      expect(failure.errorCode, 'QUOTE_CHANGED');
    });

    test('403 FINANCE_DISABLED is financeDisabled', () {
      expect(
        kindOf(
          httpCode: 403,
          data: const <String, dynamic>{'error_code': 'FINANCE_DISABLED'},
        ),
        FinanceV2FailureKind.financeDisabled,
      );
    });

    test('KYC wins over a named field, quote change wins over fields', () {
      expect(
        kindOf(
          httpCode: 403,
          data: const <String, dynamic>{
            'error_code': 'KYC_REQUIRED',
            'field': 'payer_mobile',
          },
        ),
        FinanceV2FailureKind.kycRequired,
      );
      expect(
        kindOf(
          data: const <String, dynamic>{
            'error_code': 'QUOTE_CHANGED',
            'errors': <String, dynamic>{'proof': <String>['Too large']},
          },
        ),
        FinanceV2FailureKind.quoteChanged,
      );
    });

    test('422 with data.field naming a payer field is fieldError', () {
      final failure = FinanceV2Failure.from(
        httpCode: 422,
        message: 'Mobile number is required.',
        data: const <String, dynamic>{'field': 'payer_mobile'},
      );
      expect(failure.kind, FinanceV2FailureKind.fieldError);
      expect(failure.field, 'payer_mobile');
      expect(failure.messageFor('payer_mobile'), 'Mobile number is required.');
      expect(failure.messageFor('proof'), isNull);
    });

    test('422 with data.errors naming details fields is fieldError', () {
      for (final name in <String>[
        'payer_id_number',
        'card_number',
        'utr_referce',
        'proof',
        'screenshot',
        'payment_code',
      ]) {
        final failure = FinanceV2Failure.from(
          httpCode: 422,
          message: 'Invalid',
          data: <String, dynamic>{
            'error_code': 'INVALID_REQUEST',
            'errors': <String, dynamic>{
              name: <String>['Bad $name', 'second'],
            },
          },
        );
        expect(failure.kind, FinanceV2FailureKind.fieldError, reason: name);
        expect(failure.field, name);
        expect(failure.fieldErrors[name], 'Bad $name');
        expect(failure.messageFor(name), 'Bad $name');
      }
    });

    test('a details field is picked even when another field comes first', () {
      final failure = FinanceV2Failure.from(
        httpCode: 422,
        data: const <String, dynamic>{
          'errors': <String, dynamic>{
            'amount': 'Too low',
            'payer_mobile': 'Required',
          },
        },
      );
      expect(failure.kind, FinanceV2FailureKind.fieldError);
      expect(failure.field, 'payer_mobile');
    });

    test('other 422 answers are amountError', () {
      for (final code in <String>[
        'AMOUNT_BELOW_MIN',
        'AMOUNT_ABOVE_MAX',
        'CURRENCY_NOT_SUPPORTED',
        'SOMETHING_NEW',
      ]) {
        expect(
          kindOf(httpCode: 422, data: <String, dynamic>{'error_code': code}),
          FinanceV2FailureKind.amountError,
          reason: code,
        );
      }
      expect(
        kindOf(
          httpCode: 422,
          data: const <String, dynamic>{
            'errors': <String, dynamic>{'crypto_address': 'Required'},
          },
        ),
        FinanceV2FailureKind.amountError,
      );
    });

    test('amount codes classify without an HTTP code', () {
      expect(
        kindOf(data: const <String, dynamic>{'error_code': 'AMOUNT_BELOW_MIN'}),
        FinanceV2FailureKind.amountError,
      );
      expect(
        kindOf(data: const <String, dynamic>{'error_code': 'GATEWAY_FAILED'}),
        FinanceV2FailureKind.other,
      );
    });

    test('422 ROUTE_ENDPOINT_MISMATCH is a card problem, not an amount one', () {
      expect(
        kindOf(
          httpCode: 422,
          data: const <String, dynamic>{
            'error_code': 'ROUTE_ENDPOINT_MISMATCH',
          },
        ),
        FinanceV2FailureKind.other,
      );
    });

    test('wrong OTP: HTTP 200, status false, only on the withdrawal submit', () {
      expect(
        kindOf(
          httpCode: 200,
          message: 'OTP not matched',
          isWithdrawalSubmit: true,
        ),
        FinanceV2FailureKind.otpInvalid,
      );
      expect(
        kindOf(message: 'OTP not matched', isWithdrawalSubmit: true),
        FinanceV2FailureKind.otpInvalid,
      );
      expect(kindOf(httpCode: 200, message: 'OTP not matched'),
          FinanceV2FailureKind.other);
      expect(
        kindOf(
          httpCode: 500,
          message: 'OTP service down',
          isWithdrawalSubmit: true,
        ),
        FinanceV2FailureKind.other,
      );
    });

    test('an amount error on the withdrawal submit is not an OTP error', () {
      expect(
        kindOf(
          httpCode: 422,
          message: 'OTP amount too low',
          data: const <String, dynamic>{'error_code': 'AMOUNT_BELOW_MIN'},
          isWithdrawalSubmit: true,
        ),
        FinanceV2FailureKind.amountError,
      );
    });

    test('anything else is other', () {
      expect(kindOf(httpCode: 500, message: 'Boom'), FinanceV2FailureKind.other);
      expect(
        kindOf(
          httpCode: 404,
          data: const <String, dynamic>{'error_code': 'CHANNEL_UNAVAILABLE'},
        ),
        FinanceV2FailureKind.other,
      );
      expect(kindOf(message: 'Network error'), FinanceV2FailureKind.other);
    });

    test('an error code with the wrong HTTP code is not trusted', () {
      expect(
        kindOf(
          httpCode: 500,
          data: const <String, dynamic>{'error_code': 'KYC_REQUIRED'},
        ),
        FinanceV2FailureKind.other,
      );
    });
  });

  group('DepositStatus outcome', () {
    test('paid statuses, any case', () {
      for (final status in <String>['approved', 'Success', 'COMPLETED', ' approved ']) {
        expect(DepositStatus.outcomeFor(status), DepositOutcome.paid,
            reason: status);
      }
    });

    test('failed statuses', () {
      for (final status in <String>[
        'rejected',
        'failed',
        'cancelled',
        'canceled',
        'Declined',
        'EXPIRED',
      ]) {
        expect(DepositStatus.outcomeFor(status), DepositOutcome.failed,
            reason: status);
      }
    });

    test('everything else keeps polling', () {
      for (final status in <String?>['pending', 'processing', '', null, 'paid?']) {
        expect(DepositStatus.outcomeFor(status), DepositOutcome.pending,
            reason: '$status');
      }
      expect(const DepositStatus.pending('REF1').outcome,
          DepositOutcome.pending);
      expect(const DepositStatus.pending('REF1').referenceNumber, 'REF1');
    });

    test('fromJson reads the by-reference data', () {
      final status = DepositStatus.fromJson(<String, dynamic>{
        'reference_number': 'DEP-1',
        'amount': '99.01',
        'status': 'Approved',
        'mt5_account_id': 1234,
        'gateway_method_id': 'abc',
        'created_at': '2026-11-20T10:00:00Z',
      });
      expect(status.referenceNumber, 'DEP-1');
      expect(status.amount, '99.01');
      expect(status.mt5AccountId, '1234');
      expect(status.createdAt, DateTime.utc(2026, 11, 20, 10));
      expect(status.outcome, DepositOutcome.paid);
    });
  });

  group('DepositSubmitResult nextStep', () {
    test('any payment url is a redirect', () {
      for (final key in <String>['redirect_url', 'checkout_url', 'invoice_url']) {
        final result = DepositSubmitResult.fromJson(<String, dynamic>{
          'reference_number': 'DEP-1',
          key: 'https://pay.example/x',
          'open_in_new_tab': true,
        });
        expect(result.nextStep, DepositNextStep.redirect, reason: key);
        expect(result.paymentUrl, 'https://pay.example/x');
        expect(result.openInNewTab, isTrue);
        expect(result.referenceNumber, 'DEP-1');
      }
    });

    test('a url wins over pay details', () {
      final result = DepositSubmitResult.fromJson(<String, dynamic>{
        'redirect_url': '',
        'checkout_url': 'https://pay.example/c',
        'deposit_address': 'TXYZ',
      });
      expect(result.nextStep, DepositNextStep.redirect);
      expect(result.paymentUrl, 'https://pay.example/c');
    });

    test('address, account number or async_ack open the details', () {
      expect(
        DepositSubmitResult.fromJson(<String, dynamic>{'deposit_address': 'TXYZ'})
            .nextStep,
        DepositNextStep.details,
      );
      expect(
        DepositSubmitResult.fromJson(<String, dynamic>{'account_number': '001'})
            .nextStep,
        DepositNextStep.details,
      );
      expect(
        DepositSubmitResult.fromJson(<String, dynamic>{'async_ack': 1}).nextStep,
        DepositNextStep.details,
      );
    });

    test('none of these is a created request', () {
      expect(
        DepositSubmitResult.fromJson(<String, dynamic>{
          'reference_number': 'DEP-2',
          'async_ack': false,
        }).nextStep,
        DepositNextStep.created,
      );
      expect(DepositSubmitResult.fromJson(<String, dynamic>{}).nextStep,
          DepositNextStep.created);
    });
  });

  group('ChannelQuote', () {
    final now = DateTime.utc(2026, 11, 20, 10);

    ChannelQuote quoteExpiringIn(Duration offset) => ChannelQuote(
          quoteId: 'q',
          expiresAt: now.add(offset),
        );

    test('is expired once expires_at has passed', () {
      expect(quoteExpiringIn(const Duration(seconds: -1)).isExpiredAt(now),
          isTrue);
      expect(quoteExpiringIn(Duration.zero).isExpiredAt(now), isTrue);
    });

    test('is expired inside the safety margin', () {
      expect(quoteExpiringIn(const Duration(seconds: 3)).isExpiredAt(now),
          isTrue);
      expect(
        quoteExpiringIn(const Duration(seconds: 3))
            .isExpiredAt(now, margin: Duration.zero),
        isFalse,
      );
    });

    test('is valid well before expires_at', () {
      expect(quoteExpiringIn(const Duration(seconds: 60)).isExpiredAt(now),
          isFalse);
    });

    test('isExpired uses the clock; no expires_at never expires', () {
      expect(
        ChannelQuote(
          quoteId: 'q',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ).isExpired,
        isTrue,
      );
      expect(
        ChannelQuote(
          quoteId: 'q',
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        ).isExpired,
        isFalse,
      );
      expect(const ChannelQuote(quoteId: 'q').isExpired, isFalse);
    });

    test('fromJson reads the display strings as sent', () {
      final quote = ChannelQuote.fromJson(<String, dynamic>{
        'quote_id': '935e02280b27708ed40f36a7',
        'expires_at': '2026-10-31T10:14:30Z',
        'adjusted': true,
        'fee': <String, dynamic>{'label': '1% + 0.50 USD'},
        'display': <String, dynamic>{
          'you_pay': '2,150.00 INR',
          'you_get': '25.00 USD',
          'rate_line': '1 USD = 83.42 INR',
          'fee_line': 'Fee 1% + 0.50 USD',
        },
      });
      expect(quote.quoteId, '935e02280b27708ed40f36a7');
      expect(quote.expiresAt, DateTime.utc(2026, 10, 31, 10, 14, 30));
      expect(quote.youPay, '2,150.00 INR');
      expect(quote.youGet, '25.00 USD');
      expect(quote.rateLine, '1 USD = 83.42 INR');
      expect(quote.feeLine, 'Fee 1% + 0.50 USD');
      expect(quote.feeLabel, '1% + 0.50 USD');
      expect(quote.adjusted, isTrue);
    });

    test('a bad expires_at and a missing display do not throw', () {
      final quote = ChannelQuote.fromJson(<String, dynamic>{
        'quote_id': 'q',
        'expires_at': 'soon',
      });
      expect(quote.expiresAt, isNull);
      expect(quote.youPay, '');
      expect(ChannelQuote.tryParse(null), isNull);
      expect(ChannelQuote.tryParse(<dynamic>[]), isNull);
    });
  });

  group('FinanceChannel', () {
    test('an eligible redirect gateway submits directly', () {
      final channel = FinanceChannel.fromJson(<String, dynamic>{
        'slug': '9yvQT',
        'label': 'enet one',
        'icon': 'https://cdn.example/enet.png',
        'eligible': true,
        'is_redirect': true,
        'is_offline': false,
        'deposit_api': '/deposit/dynamic/enet',
        'quote': <String, dynamic>{'quote_id': 'q1'},
      });
      expect(channel.name, 'enet one');
      expect(channel.logo, 'https://cdn.example/enet.png');
      expect(channel.isSelectable, isTrue);
      expect(channel.submitsDirectly, isTrue);
      expect(channel.quote?.quoteId, 'q1');
    });

    test('a card that is not eligible keeps its reason and has no quote', () {
      final channel = FinanceChannel.fromJson(<String, dynamic>{
        'slug': 'enet',
        'label': 'Enet',
        'eligible': false,
        'reason_code': 'CURRENCY_NOT_SUPPORTED',
        'reason': 'Works in USD only',
        'is_redirect': true,
        'is_offline': true,
      });
      expect(channel.isSelectable, isFalse);
      expect(channel.reason, 'Works in USD only');
      expect(channel.reasonCode, 'CURRENCY_NOT_SUPPORTED');
      expect(channel.quote, isNull);
      expect(channel.submitsDirectly, isFalse);
    });
  });

  group('groupDepositRows', () {
    PaymentTypeOption row(String type, String slug, {Object? locked}) {
      return PaymentTypeOption.fromJson(<String, dynamic>{
        'payment_type': type,
        'deposit_slug': slug,
        'verification_req': locked,
      });
    }

    final paymentTypes = <PaymentTypeOption>[
      PaymentTypeOption.fromJson(<String, dynamic>{
        'payment_type': 'card',
        'label': 'Card',
        'channels': 2,
        'amount_currencies': <String>['INR', 'USD'],
      }),
      PaymentTypeOption.fromJson(<String, dynamic>{
        'payment_type': 'local',
        'label': 'Local / custom',
        'amount_currencies': <String>['USD'],
      }),
    ];

    test('orders tiles crypto, bank, upi, card, local', () {
      final groups = groupDepositRows(
        <PaymentTypeOption>[
          row('local', 'l1'),
          row('card', 'c1'),
          row('upi', 'u1'),
          row('bank', 'b1'),
          row('crypto', 'x1'),
          row('card', 'c2'),
        ],
        paymentTypes,
      );
      expect(groups.map((group) => group.type).toList(),
          <String>['crypto', 'bank', 'upi', 'card', 'local']);
      expect(groups[3].rows.map((r) => r.depositSlug).toList(),
          <String>['c1', 'c2']);
      expect(groups.every((group) => !group.locked), isTrue);
    });

    test('unknown and missing types fall into local', () {
      final groups = groupDepositRows(
        <PaymentTypeOption>[
          row('wallet', 'w1'),
          row('', 'e1'),
          row('Crypto', 'x1'),
        ],
        const <PaymentTypeOption>[],
      );
      expect(groups.map((group) => group.type).toList(),
          <String>['crypto', 'local']);
      expect(groups.last.rows.map((r) => r.depositSlug).toList(),
          <String>['w1', 'e1']);
    });

    test('rows that need verification go to one closing locked group', () {
      final groups = groupDepositRows(
        <PaymentTypeOption>[
          row('card', 'c1', locked: 1),
          row('bank', 'b1'),
          row('crypto', 'x1', locked: '1'),
          row('card', 'c2', locked: 0),
        ],
        paymentTypes,
      );
      expect(groups.map((group) => group.type).toList(),
          <String>['bank', 'card', PaymentTypeGroup.lockedType]);
      final locked = groups.last;
      expect(locked.locked, isTrue);
      expect(locked.rows.map((r) => r.depositSlug).toList(),
          <String>['c1', 'x1']);
      expect(groups[1].rows.single.depositSlug, 'c2');
    });

    test('tiles take label and currencies from payment-types', () {
      final groups = groupDepositRows(
        <PaymentTypeOption>[row('card', 'c1'), row('bank', 'b1')],
        paymentTypes,
      );
      final card = groups.firstWhere((group) => group.type == 'card');
      expect(card.label, 'Card');
      expect(card.amountCurrencies, <String>['INR', 'USD']);
      final bank = groups.firstWhere((group) => group.type == 'bank');
      expect(bank.label, '');
      expect(bank.amountCurrencies, isEmpty);
    });

    test('no rows gives no tiles', () {
      expect(groupDepositRows(const <PaymentTypeOption>[], paymentTypes),
          isEmpty);
    });

    test('currency choice only when the client currency is offered', () {
      expect(paymentTypes.first.hasCurrencyChoice, isTrue);
      expect(paymentTypes.last.hasCurrencyChoice, isFalse);
    });
  });

  group('withdrawal rows', () {
    test('resolveWithdrawalType keeps bank, upi, crypto and card', () {
      expect(resolveWithdrawalType('bank'), 'bank');
      expect(resolveWithdrawalType('UPI'), 'upi');
      expect(resolveWithdrawalType(' crypto '), 'crypto');
      expect(resolveWithdrawalType('card'), 'card');
    });

    test('resolveWithdrawalType sends everything else to local', () {
      expect(resolveWithdrawalType('local'), 'local');
      expect(resolveWithdrawalType('Skrill'), 'local');
      expect(resolveWithdrawalType(''), 'local');
      expect(resolveWithdrawalType(null), 'local');
    });

    test('groupWithdrawalRows skips rows without method_slug', () {
      final rows = <PaymentTypeOption>[
        PaymentTypeOption.fromJson(<String, dynamic>{
          'method_slug': 'm-bank',
          'method_name': 'bank',
        }),
        PaymentTypeOption.fromJson(<String, dynamic>{
          'method_name': 'upi',
        }),
        PaymentTypeOption.fromJson(<String, dynamic>{
          'method_slug': 'm-crypto',
          'method_name': 'crypto',
          'crypto_skip_otp': true,
          'allowed_crypto_networks': <Map<String, dynamic>>[
            <String, dynamic>{'slug': 'trc20', 'label': 'USDT TRC20'},
            <String, dynamic>{'label': 'no slug'},
          ],
        }),
        PaymentTypeOption.fromJson(<String, dynamic>{
          'method_slug': 'm-skrill',
          'method_name': 'Skrill',
        }),
      ];
      final groups = groupWithdrawalRows(rows, const <PaymentTypeOption>[]);
      expect(groups.map((group) => group.type).toList(),
          <String>['crypto', 'bank', 'local']);
      final crypto = groups.first.rows.single;
      expect(crypto.cryptoSkipOtp, isTrue);
      expect(crypto.allowedCryptoNetworks.single.slug, 'trc20');
      expect(crypto.slug, 'm-crypto');
    });

    test('UserWithdrawalMethod: approved when status is missing or approved', () {
      expect(
        UserWithdrawalMethod.fromJson(<String, dynamic>{
          'withdrawal_slug': 'w1',
          'withdrawal_method': 'upi',
          'upi_address': 'name@upi',
        }).isApproved,
        isTrue,
      );
      expect(
        UserWithdrawalMethod.fromJson(<String, dynamic>{
          'withdrawal_slug': 'w2',
          'status': 'pending',
        }).isApproved,
        isFalse,
      );
      expect(
        UserWithdrawalMethod.fromJson(<String, dynamic>{
          'withdrawal_slug': 'w3',
          'card_last4': '4242',
          'card_brand': 'Visa',
        }).primaryLabel,
        '•••• 4242',
      );
    });
  });

  group('DepositMethodDetail', () {
    test('reads a nested answer with a JSON-string gateway value', () {
      final detail = DepositMethodDetail.fromJson(<String, dynamic>{
        'data': <String, dynamic>{
          'client_note_enabled': true,
          'saved_payer': <String, dynamic>{'id_type': 'passport'},
          'depositMethod': <String, dynamic>{
            'gateway_details': <String, dynamic>{'type': 'bank'},
            'paymentGateway': <String, dynamic>{
              'value':
                  '{"holder_name":"Broker Ltd","bank_account_no":"001","qr_path":"/qr/1"}',
            },
            'show_utr': 1,
            'require_utr': true,
            'show_proof': '1',
            'payer_fields': <String, dynamic>{
              'mobile': <String, dynamic>{'label': 'Mobile', 'required': true},
              'id_type': <String, dynamic>{
                'label': 'ID type',
                'options': <Map<String, dynamic>>[
                  <String, dynamic>{'value': 'passport', 'label': 'Passport'},
                ],
              },
            },
          },
        },
      });
      expect(detail.type, 'bank');
      expect(detail.qrPath, '/qr/1');
      expect(detail.payLines.map((line) => line.key).toList(),
          <String>['holder_name', 'bank_account_no']);
      expect(detail.showUtr, isTrue);
      expect(detail.requireUtr, isTrue);
      expect(detail.showProof, isTrue);
      expect(detail.requireProof, isFalse);
      expect(detail.clientNoteEnabled, isTrue);
      expect(detail.payerFieldKeys, <String>['mobile', 'id_type']);
      expect(detail.payerFieldsToAsk.single.fieldName, 'payer_mobile');
    });

    test('an empty answer gives an empty detail', () {
      final detail = DepositMethodDetail.fromJson(<String, dynamic>{});
      expect(detail.payLines, isEmpty);
      expect(detail.payerFields, isEmpty);
      expect(detail.qrPath, '');
    });
  });

  group('FinanceV2Repository.depositEndpoint', () {
    test('maps a card deposit_api onto the user API path', () {
      expect(FinanceV2Repository.depositEndpoint('/deposit/depositrequest'),
          'user/deposit/depositrequest');
      expect(FinanceV2Repository.depositEndpoint('deposit/cregis'),
          'user/deposit/cregis');
      expect(FinanceV2Repository.depositEndpoint('/api/user/deposit/dynamic/enet'),
          'user/deposit/dynamic/enet');
      expect(
        FinanceV2Repository.depositEndpoint(
          'https://dev.example.com/api/user/deposit/unipayment',
        ),
        'user/deposit/unipayment',
      );
    });
  });
}
