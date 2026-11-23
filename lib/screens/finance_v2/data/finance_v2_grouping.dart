import 'models/payment_type_option.dart';

/// Tile order of screen 1. Unknown types fall into `local`.
const List<String> financeV2TypeOrder = <String>[
  'crypto',
  'bank',
  'upi',
  'card',
  'local',
];

const String _fallbackType = 'local';

String _knownTypeOrLocal(String raw) {
  final normalized = raw.trim().toLowerCase();
  return financeV2TypeOrder.contains(normalized) ? normalized : _fallbackType;
}

/// Type of a GET /withdrawal row, which has no payment_type: its method_name
/// when that is bank, upi, crypto or card, otherwise local.
String resolveWithdrawalType(String? methodName) {
  final normalized = (methodName ?? '').trim().toLowerCase();
  if (normalized == _fallbackType) return _fallbackType;
  return _knownTypeOrLocal(normalized);
}

/// Groups GET /deposit rows into type tiles ordered crypto, bank, upi, card,
/// local. Rows that need verification go to one closing locked group.
/// [paymentTypes] (GET /finance/payment-types) gives each tile its label and
/// the currencies its amount may be typed in.
List<PaymentTypeGroup> groupDepositRows(
  List<PaymentTypeOption> rows,
  List<PaymentTypeOption> paymentTypes,
) {
  return _groupRows(
    rows,
    paymentTypes,
    typeOf: (row) => _knownTypeOrLocal(row.paymentType),
  );
}

/// Same tiles for GET /withdrawal rows. Rows without method_slug are skipped.
List<PaymentTypeGroup> groupWithdrawalRows(
  List<PaymentTypeOption> rows,
  List<PaymentTypeOption> paymentTypes,
) {
  return _groupRows(
    rows.where((row) => row.methodSlug.isNotEmpty).toList(growable: false),
    paymentTypes,
    typeOf: (row) => resolveWithdrawalType(row.methodName),
  );
}

List<PaymentTypeGroup> _groupRows(
  List<PaymentTypeOption> rows,
  List<PaymentTypeOption> paymentTypes, {
  required String Function(PaymentTypeOption row) typeOf,
}) {
  final typeInfo = <String, PaymentTypeOption>{
    for (final type in paymentTypes) _knownTypeOrLocal(type.paymentType): type,
  };
  final byType = <String, List<PaymentTypeOption>>{};
  final lockedRows = <PaymentTypeOption>[];

  for (final row in rows) {
    if (row.locked) {
      lockedRows.add(row);
      continue;
    }
    byType.putIfAbsent(typeOf(row), () => <PaymentTypeOption>[]).add(row);
  }

  return <PaymentTypeGroup>[
    for (final type in financeV2TypeOrder)
      if (byType[type] != null)
        PaymentTypeGroup(
          type: type,
          label: typeInfo[type]?.label ?? '',
          rows: List<PaymentTypeOption>.unmodifiable(byType[type]!),
          amountCurrencies: typeInfo[type]?.amountCurrencies ?? const <String>[],
        ),
    if (lockedRows.isNotEmpty)
      PaymentTypeGroup(
        type: PaymentTypeGroup.lockedType,
        rows: List<PaymentTypeOption>.unmodifiable(lockedRows),
        locked: true,
      ),
  ];
}
