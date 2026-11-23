import 'finance_v2_json.dart';

/// A crypto network a withdrawal row accepts for a pasted address.
class CryptoNetworkOption {
  final String slug;
  final String label;

  const CryptoNetworkOption({required this.slug, required this.label});

  factory CryptoNetworkOption.fromJson(Map<String, dynamic> json) {
    final slug = jsonString(json['slug']);
    final label = jsonString(json['label']);
    return CryptoNetworkOption(slug: slug, label: label.isEmpty ? slug : label);
  }
}

/// One row of GET /deposit, GET /withdrawal or
/// GET /finance/payment-types. The three share this model because the type
/// tiles are built from all of them; fields a source does not send stay empty.
class PaymentTypeOption {
  /// Raw code (crypto | bank | upi | card | local). Empty on withdrawal rows,
  /// which carry [methodName] instead.
  final String paymentType;
  final String label;

  /// deposit_slug of a deposit row.
  final String depositSlug;

  /// method_slug of a withdrawal row.
  final String methodSlug;
  final String methodName;
  final String displayName;
  final String icon;
  final bool verificationReq;
  final bool isLocked;

  /// Client currency first, then USD. Only `["USD"]` means no currency choice.
  final List<String> amountCurrencies;
  final int channels;

  /// Misleading server name: true means the client may paste a new address.
  /// The OTP is still required.
  final bool cryptoSkipOtp;
  final List<CryptoNetworkOption> allowedCryptoNetworks;
  final String averageLabel;
  final String feeLabel;
  final String limitsLabel;

  const PaymentTypeOption({
    this.paymentType = '',
    this.label = '',
    this.depositSlug = '',
    this.methodSlug = '',
    this.methodName = '',
    this.displayName = '',
    this.icon = '',
    this.verificationReq = false,
    this.isLocked = false,
    this.amountCurrencies = const <String>[],
    this.channels = 0,
    this.cryptoSkipOtp = false,
    this.allowedCryptoNetworks = const <CryptoNetworkOption>[],
    this.averageLabel = '',
    this.feeLabel = '',
    this.limitsLabel = '',
  });

  factory PaymentTypeOption.fromJson(Map<String, dynamic> json) {
    final label = jsonString(json['label']);
    return PaymentTypeOption(
      paymentType: jsonString(json['payment_type']),
      label: label.isEmpty ? jsonString(json['payment_type_label']) : label,
      depositSlug: jsonString(json['deposit_slug']),
      methodSlug: jsonString(json['method_slug']),
      methodName: jsonString(json['method_name']),
      displayName: jsonString(json['display_name']),
      icon: jsonString(json['icon']),
      verificationReq: jsonBool(json['verification_req']),
      isLocked: jsonBool(json['is_locked']),
      amountCurrencies: jsonStringList(json['amount_currencies']),
      channels: jsonInt(json['channels']),
      cryptoSkipOtp: jsonBool(json['crypto_skip_otp']),
      allowedCryptoNetworks: jsonMapList(json['allowed_crypto_networks'])
          .map(CryptoNetworkOption.fromJson)
          .where((network) => network.slug.isNotEmpty)
          .toList(growable: false),
      averageLabel: jsonString(json['average_label']),
      feeLabel: jsonString(json['fee_label']),
      limitsLabel: jsonString(json['limits_label']),
    );
  }

  /// The slug of the row, whichever flow it belongs to.
  String get slug => depositSlug.isNotEmpty ? depositSlug : methodSlug;

  bool get locked => verificationReq || isLocked;

  /// False when the amount can only be typed in USD.
  bool get hasCurrencyChoice =>
      amountCurrencies.length > 1 ||
      (amountCurrencies.length == 1 &&
          amountCurrencies.first.toUpperCase() != 'USD');
}

/// A type tile with the rows behind it.
class PaymentTypeGroup {
  /// [type] of the closing "Verification required" group.
  static const String lockedType = 'verification_required';

  /// crypto | bank | upi | card | local, or [lockedType].
  final String type;

  /// Server label of the type when payment-types sent one, else empty.
  final String label;
  final List<PaymentTypeOption> rows;
  final bool locked;
  final List<String> amountCurrencies;

  const PaymentTypeGroup({
    required this.type,
    required this.rows,
    this.label = '',
    this.locked = false,
    this.amountCurrencies = const <String>[],
  });
}
