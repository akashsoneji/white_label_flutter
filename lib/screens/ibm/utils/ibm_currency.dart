import 'package:intl/intl.dart';

/// Lightweight currency formatter for IB portal screens.
///
/// IBM wallets / commissions are multi-currency — we must not hardcode a `$`
/// prefix. Pass the ISO code from the API (e.g. "USD", "EUR", "GBP", "INR")
/// and we render "USD 1,200.50" / "EUR 1.200,50" / etc. localized.
///
/// Falls back to `defaultCode` when an unknown / null code is passed.
class IbmCurrency {
  IbmCurrency._();

  static String format(
    num? value, {
    String? currencyCode,
    int decimals = 2,
    String fallback = 'USD',
  }) {
    final code = (currencyCode == null || currencyCode.isEmpty)
        ? fallback
        : currencyCode;
    final symbol = _symbolFor(code);
    final formatter = NumberFormat.currency(
      name: code,
      symbol: symbol,
      decimalDigits: decimals,
    );
    final n = value ?? 0;
    return formatter.format(n);
  }

  /// Compact form: "USD 1.2K", "USD 3.4M" for KPI tiles.
  static String formatCompact(
    num? value, {
    String? currencyCode,
    int decimals = 1,
    String fallback = 'USD',
  }) {
    final code = (currencyCode == null || currencyCode.isEmpty)
        ? fallback
        : currencyCode;
    final symbol = _symbolFor(code);
    final formatter = NumberFormat.compactCurrency(
      name: code,
      symbol: symbol,
      decimalDigits: decimals,
    );
    return formatter.format(value ?? 0);
  }

  static String _symbolFor(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
      case 'CAD':
      case 'AUD':
      case 'NZD':
      case 'SGD':
      case 'HKD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
      case 'RMB':
        return '¥';
      case 'INR':
        return '₹';
      case 'NGN':
        return '₦';
      case 'ZAR':
        return 'R';
      case 'CHF':
        return 'CHF ';
      case 'TRY':
        return '₺';
      default:
        return '';
    }
  }
}
