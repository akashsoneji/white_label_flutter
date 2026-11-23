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
  static const List<String> _payLineKeys = <String>[
    'holder_name',
    'bank_name',
    'bank_account_no',
    'account_number',
    'ifsc_iban',
    'ifsc_code',
    'swift_code',
    'city',
    'upi_address',
    'crypto_type',
    'network',
    'title',
    'crypto_address',
  ];

  /// Raw depositMethod object.
  final Map<String, dynamic> depositMethod;

  /// gateway_details.type: bank | upi | crypto | local.
  final String type;

  /// paymentGateway.value, decoded.
  final Map<String, dynamic> payDetails;
  final List<DepositPayLine> payLines;

  /// Must be fetched with the bearer token; a plain image URL answers 401.
  final String qrPath;

  /// The broker's rich-text instructions (type local), else the address line.
  final String instructions;
  final bool showProof;
  final bool requireProof;
  final bool showUtr;
  final bool requireUtr;
  final List<PayerField> payerFields;
  final bool clientNoteEnabled;
  final Map<String, dynamic> savedPayer;

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
    this.savedPayer = const <String, dynamic>{},
  });

  /// [json] is the `data` object; the server may nest it one level deeper.
  factory DepositMethodDetail.fromJson(Map<String, dynamic> json) {
    final root = json.containsKey('depositMethod') ? json : jsonMap(json['data']);
    final method = jsonMap(root['depositMethod']);
    final details = jsonMap(jsonMap(method['paymentGateway'])['value']);
    final qr = jsonString(details['qr_path']);

    return DepositMethodDetail(
      depositMethod: method,
      type: jsonString(jsonMap(method['gateway_details'])['type']),
      payDetails: details,
      payLines: _payLineKeys
          .where((key) => jsonString(details[key]).isNotEmpty)
          .map((key) => DepositPayLine(key: key, value: jsonString(details[key])))
          .toList(growable: false),
      qrPath: qr.isEmpty ? jsonString(method['qr_path']) : qr,
      instructions: jsonString(details['address']),
      showProof: jsonBool(method['show_proof']),
      requireProof: jsonBool(method['require_proof']),
      showUtr: jsonBool(method['show_utr']),
      requireUtr: jsonBool(method['require_utr']),
      payerFields: _parsePayerFields(method['payer_fields']),
      clientNoteEnabled: jsonBool(root['client_note_enabled']),
      savedPayer: jsonMap(root['saved_payer']),
    );
  }

  List<String> get payerFieldKeys =>
      payerFields.map((field) => field.key).toList(growable: false);

  /// Payer fields still to ask for: keys already in [savedPayer] are skipped.
  List<PayerField> get payerFieldsToAsk => payerFields
      .where((field) => jsonString(savedPayer[field.key]).isEmpty)
      .toList(growable: false);

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
