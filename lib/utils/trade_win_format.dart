import 'package:intl/intl.dart';

class TradeWinFormat {
  static final NumberFormat _lotsFormat = NumberFormat('#,##0.####');
  static final NumberFormat _pointsFormat = NumberFormat('#,##0.#');
  static final NumberFormat _currencyFormat = NumberFormat('#,##0');

  static String lots(num value) => '${_lotsFormat.format(value)}';

  static String lotsWithUnit(num value, String unitLabel) =>
      '${lots(value)} $unitLabel';

  static String points(num value) => '${_pointsFormat.format(value)} pts';

  static String pointsValue(num value) => _pointsFormat.format(value);

  static String currency(num value) => '\$${_currencyFormat.format(value)}';

  static String categoryLabel(String category) {
    if (category.isEmpty) return category;
    return category
        .split(RegExp(r'[\s_/]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String categoryTag(String category) =>
      categoryLabel(category).toUpperCase();

  /// Masks names like "Aman T." → "A**** T."
  static String maskName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;

    return trimmed.split(RegExp(r'\s+')).map((part) {
      if (part.isEmpty) return part;
      if (part.length == 1) return '$part****';
      return '${part[0]}${'*' * (part.length - 1)}';
    }).join(' ');
  }
}
