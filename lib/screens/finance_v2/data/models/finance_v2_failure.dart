import 'finance_channel.dart';
import 'finance_v2_json.dart';

/// What the UI does with a failed call. Checked in this order.
enum FinanceV2FailureKind {
  /// 403 KYC_REQUIRED: open the KYC screen.
  kycRequired,

  /// 409 QUOTE_CHANGED: show [FinanceV2Failure.newQuote], ask once, resend.
  quoteChanged,

  /// 403 FINANCE_DISABLED: show the message only, no tiles.
  financeDisabled,

  /// 422 naming a details-screen field: message under that field.
  fieldError,

  /// Any other 422: message under the amount, load the cards again.
  amountError,

  /// Wrong withdrawal code (HTTP 200, status false): keep the sheet open.
  otpInvalid,

  /// Grey that card, select the next eligible one, show the message.
  other,
}

class FinanceV2Failure {
  static const String kycRequiredCode = 'KYC_REQUIRED';
  static const String quoteChangedCode = 'QUOTE_CHANGED';
  static const String financeDisabledCode = 'FINANCE_DISABLED';

  /// A 422 the server sends for a wrong endpoint, which is a card problem and
  /// not something the client can fix by changing the amount.
  static const String routeMismatchCode = 'ROUTE_ENDPOINT_MISMATCH';

  static const Set<String> _amountCodes = <String>{
    'INVALID_REQUEST',
    'INVALID_AMOUNT',
    'AMOUNT_BELOW_MIN',
    'AMOUNT_ABOVE_MAX',
    'AMOUNT_TOO_SMALL',
    'AMOUNT_NOT_REPRESENTABLE',
    'CURRENCY_NOT_SUPPORTED',
    'NO_ROUTE',
  };

  static const List<String> _detailFieldPrefixes = <String>[
    'payer_',
    'card_',
    'utr',
  ];

  static const Set<String> _detailFieldNames = <String>{
    'proof',
    'screenshot',
    'payment_code',
  };

  /// Null when the transport did not expose it (see [FinanceV2Failure.from]).
  final int? httpCode;

  /// Raw data.error_code; never translated or re-cased.
  final String? errorCode;
  final String message;

  /// The details-screen field the error belongs to, for [kind] fieldError;
  /// otherwise data.field as sent.
  final String? field;

  /// data.errors, first message per field.
  final Map<String, String> fieldErrors;

  /// data.quote of a QUOTE_CHANGED answer.
  final ChannelQuote? newQuote;
  final FinanceV2FailureKind kind;

  const FinanceV2Failure({
    required this.message,
    required this.kind,
    this.httpCode,
    this.errorCode,
    this.field,
    this.fieldErrors = const <String, String>{},
    this.newQuote,
  });

  /// Builds a failure from an error answer.
  ///
  /// [data] is the `data` object of the envelope. [httpCode] may be null: the
  /// shared ApiClient drops the HTTP status, so every rule also works from
  /// `data.error_code` and the field names alone. When a code is given it must
  /// agree with the rule.
  factory FinanceV2Failure.from({
    int? httpCode,
    String? message,
    dynamic data,
    bool isWithdrawalSubmit = false,
  }) {
    final payload = jsonMap(data);
    final errorCode = jsonStringOrNull(payload['error_code']);
    final dataField = jsonStringOrNull(payload['field']);
    final fieldErrors = _parseFieldErrors(payload['errors']);
    final text = jsonString(message);

    final namedFields = <String>[
      if (dataField != null) dataField,
      ...fieldErrors.keys,
    ];
    final detailField = namedFields.cast<String?>().firstWhere(
          (name) => isDetailField(name!),
          orElse: () => null,
        );

    bool codeIs(int expected) => httpCode == null || httpCode == expected;

    final FinanceV2FailureKind kind;
    if (errorCode == kycRequiredCode && codeIs(403)) {
      kind = FinanceV2FailureKind.kycRequired;
    } else if (errorCode == quoteChangedCode && codeIs(409)) {
      kind = FinanceV2FailureKind.quoteChanged;
    } else if (errorCode == financeDisabledCode && codeIs(403)) {
      kind = FinanceV2FailureKind.financeDisabled;
    } else if (detailField != null && codeIs(422)) {
      kind = FinanceV2FailureKind.fieldError;
    } else if (_isAmountError(httpCode, errorCode, namedFields)) {
      kind = FinanceV2FailureKind.amountError;
    } else if (_isOtpError(httpCode, errorCode, text, isWithdrawalSubmit)) {
      kind = FinanceV2FailureKind.otpInvalid;
    } else {
      kind = FinanceV2FailureKind.other;
    }

    return FinanceV2Failure(
      httpCode: httpCode,
      errorCode: errorCode,
      message: text,
      field: kind == FinanceV2FailureKind.fieldError ? detailField : dataField,
      fieldErrors: fieldErrors,
      newQuote: ChannelQuote.tryParse(payload['quote']),
      kind: kind,
    );
  }

  /// True for a field shown on the deposit details screen.
  static bool isDetailField(String name) {
    final normalized = name.trim().toLowerCase();
    if (_detailFieldNames.contains(normalized)) return true;
    return _detailFieldPrefixes.any(normalized.startsWith);
  }

  /// The message to show under [name]: its own entry of data.errors, else the
  /// answer's message when the error is about that field.
  String? messageFor(String name) {
    final own = fieldErrors[name];
    if (own != null && own.isNotEmpty) return own;
    return field == name ? message : null;
  }

  static bool _isAmountError(
    int? httpCode,
    String? errorCode,
    List<String> namedFields,
  ) {
    if (errorCode == routeMismatchCode) return false;
    if (httpCode != null) return httpCode == 422;
    return _amountCodes.contains(errorCode) || namedFields.isNotEmpty;
  }

  static bool _isOtpError(
    int? httpCode,
    String? errorCode,
    String message,
    bool isWithdrawalSubmit,
  ) {
    if (!isWithdrawalSubmit || errorCode != null) return false;
    if (httpCode != null && httpCode != 200) return false;
    return message.toLowerCase().contains('otp');
  }

  static Map<String, String> _parseFieldErrors(dynamic raw) {
    final errors = jsonMap(raw);
    final result = <String, String>{};
    for (final entry in errors.entries) {
      final value = entry.value;
      final text = value is List
          ? (value.isEmpty ? '' : jsonString(value.first))
          : jsonString(value);
      result[entry.key] = text;
    }
    return result;
  }

  @override
  String toString() =>
      'FinanceV2Failure($kind, http: $httpCode, code: $errorCode, $message)';
}
