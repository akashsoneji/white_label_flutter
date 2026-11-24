import 'finance_v2_json.dart';

/// One selectable value of a payer field.
class PayerFieldOption {
  final String value;
  final String label;

  const PayerFieldOption({required this.value, required this.label});
}

/// One entry of depositMethod.payer_fields.
class PayerField {
  /// Key as the server names it (e.g. `mobile`).
  final String key;
  final String label;
  final bool required;
  final List<PayerFieldOption> options;

  /// When not empty, the field is shown and required only while the chosen
  /// payment_page is in this list.
  final List<String> requiredWhenPaymentPage;

  const PayerField({
    required this.key,
    this.label = '',
    this.required = false,
    this.options = const <PayerFieldOption>[],
    this.requiredWhenPaymentPage = const <String>[],
  });

  /// The name to send on submit (`mobile` gives `payer_mobile`).
  String get fieldName => 'payer_$key';
}

/// One "pay to" line of the details screen, in display order.
class DepositPayLine {
  /// Raw key of the gateway value (holder_name, upi_address ...).
  final String key;
  final String value;

  const DepositPayLine({required this.key, required this.value});
}

/// GET /deposit/{slug}: everything the deposit details screen needs.
class DepositMethodDetail {
  static const String typeCrypto = 'crypto';

  /// Key of the coin / network pay line of a crypto option.
  static const String networkLineKey = 'network';

  static const List<String> _payLineKeys = <String>[
    'holder_name',
    'bank_name',
    'bank_account_no',
    'ifsc_iban',
    'swift_code',
    'upi_address',
    networkLineKey,
    'crypto_address',
  ];

  /// Raw depositMethod object.
  final Map<String, dynamic> depositMethod;

  /// depositMethod.type: bank | upi | crypto | local for a manual option, the
  /// gateway's own code for an online gateway.
  final String type;

  /// depositMethod.payment_gateway.
  final Map<String, dynamic> payDetails;
  final List<DepositPayLine> payLines;

  /// A full, public URL; empty when the option has no QR.
  final String qrPath;

  /// The broker's rich text: `instructions` of an offline-channel option, or
  /// `address` of a local option.
  final String instructions;
  final bool showProof;
  final bool requireProof;
  final bool showUtr;
  final bool requireUtr;
  final List<PayerField> payerFields;
  final bool clientNoteEnabled;

  const DepositMethodDetail({
    this.depositMethod = const <String, dynamic>{},
    this.type = '',
    this.payDetails = const <String, dynamic>{},
    this.payLines = const <DepositPayLine>[],
    this.qrPath = '',
    this.instructions = '',
    this.showProof = false,
    this.requireProof = false,
    this.showUtr = false,
    this.requireUtr = false,
    this.payerFields = const <PayerField>[],
    this.clientNoteEnabled = false,
  });

  /// [json] is the `data` object; the server may nest it one level deeper.
  factory DepositMethodDetail.fromJson(Map<String, dynamic> json) {
    final root = json.containsKey('depositMethod') ? json : jsonMap(json['data']);
    final method = jsonMap(root['depositMethod']);
    final details = jsonMap(method['payment_gateway']);
    final type = jsonString(method['type']);

    final lineValues = <String, String>{
      for (final key in _payLineKeys) key: jsonString(details[key]),
    };
    // `title` names the coin only on a crypto option; elsewhere it is the
    // option's own display name, not a line to pay to.
    final cryptoType = jsonString(details['crypto_type']);
    lineValues[networkLineKey] = type != typeCrypto
        ? ''
        : (cryptoType.isNotEmpty ? cryptoType : jsonString(details['title']));

    final instructions = jsonString(details['instructions']);

    return DepositMethodDetail(
      depositMethod: method,
      type: type,
      payDetails: details,
      payLines: _payLineKeys
          .where((key) => (lineValues[key] ?? '').isNotEmpty)
          .map((key) => DepositPayLine(key: key, value: lineValues[key] ?? ''))
          .toList(growable: false),
      qrPath: jsonString(details['qr_path']),
      instructions: instructions.isNotEmpty
          ? instructions
          : jsonString(details['address']),
      showProof: jsonBool(method['show_proof']),
      requireProof: jsonBool(method['require_proof']),
      showUtr: jsonBool(method['show_utr']),
      requireUtr: jsonBool(method['require_utr']),
      payerFields: _parsePayerFields(method['payer_fields']),
      clientNoteEnabled: jsonBool(root['client_note_enabled']),
    );
  }

  static List<PayerField> _parsePayerFields(dynamic raw) {
    final fields = jsonMap(raw);
    return fields.entries.map((entry) {
      final config = jsonMap(entry.value);
      final options = jsonMapList(config['options'])
          .map(
            (option) => PayerFieldOption(
              value: jsonString(option['value']),
              label: jsonString(option['label']),
            ),
          )
          .where((option) => option.value.isNotEmpty)
          .toList(growable: false);
      return PayerField(
        key: entry.key,
        label: jsonString(config['label']),
        required: jsonBool(config['required']),
        options: options,
        requiredWhenPaymentPage: jsonStringList(
          jsonMap(config['required_when'])['payment_page'],
        ),
      );
    }).toList(growable: false);
  }
}
