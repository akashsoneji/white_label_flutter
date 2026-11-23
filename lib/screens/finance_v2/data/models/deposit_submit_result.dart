import 'finance_v2_json.dart';

/// What the app does after a deposit submit succeeded.
enum DepositNextStep {
  /// Open [DepositSubmitResult.paymentUrl], then poll by reference.
  redirect,

  /// Show the pay details with the reference number.
  details,

  /// Request created: go to Transaction History.
  created,
}

/// `data` of a successful POST to a card's deposit_api.
class DepositSubmitResult {
  final String referenceNumber;

  /// redirect_url, checkout_url or invoice_url, whichever the gateway sent.
  final String paymentUrl;
  final String depositAddress;
  final String accountNumber;
  final bool asyncAck;

  /// The gateway never sends the client back; only polling tells the result.
  final bool openInNewTab;

  const DepositSubmitResult({
    this.referenceNumber = '',
    this.paymentUrl = '',
    this.depositAddress = '',
    this.accountNumber = '',
    this.asyncAck = false,
    this.openInNewTab = false,
  });

  factory DepositSubmitResult.fromJson(Map<String, dynamic> json) {
    final paymentUrl = <dynamic>[
      json['redirect_url'],
      json['checkout_url'],
      json['invoice_url'],
    ].map(jsonString).firstWhere((url) => url.isNotEmpty, orElse: () => '');

    return DepositSubmitResult(
      referenceNumber: jsonString(json['reference_number']),
      paymentUrl: paymentUrl,
      depositAddress: jsonString(json['deposit_address']),
      accountNumber: jsonString(json['account_number']),
      asyncAck: jsonBool(json['async_ack']),
      openInNewTab: jsonBool(json['open_in_new_tab']),
    );
  }

  DepositNextStep get nextStep {
    if (paymentUrl.isNotEmpty) return DepositNextStep.redirect;
    if (depositAddress.isNotEmpty || accountNumber.isNotEmpty || asyncAck) {
      return DepositNextStep.details;
    }
    return DepositNextStep.created;
  }
}
