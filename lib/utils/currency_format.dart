import 'package:crm_app/models/mt5_account.dart';

/// Central MT5 account money formatter.
///
/// Cent accounts (`USC`) display with `¢` and the `USC` code; standard
/// accounts use `$` and `USD`. The raw numeric value is NOT converted —
/// MT5 cent accounts already report balance/equity/etc. in cent units,
/// so a value of `10000.00` prints as `¢10,000.00` on a cent account
/// and `$10,000.00` on a standard account.
///
/// Keeps the per-screen `isCentAccount ? '¢' : '\$'` snippets honest and
/// in one place; call-sites just pass the active [MT5Account].
class CurrencyFormat {
  const CurrencyFormat._();

  /// `¢` for cent accounts, `$` otherwise.
  static String symbol(MT5Account? account) =>
      (account?.isCentAccount ?? false) ? '¢' : r'$';

  /// `USC` for cent accounts, otherwise the account currency, falling back
  /// to `USD`.
  static String code(MT5Account? account) {
    final currency = account?.currency ?? '';
    if (account?.isCentAccount ?? false) {
      return currency.isNotEmpty ? currency : 'USC';
    }
    return currency.isNotEmpty ? currency : 'USD';
  }

  /// `¢10,000.00` or `$10,000.00` — no code suffix.
  static String amount(num value, MT5Account? account, {int decimals = 2}) =>
      '${symbol(account)}${_formatNumber(value, decimals)}';

  /// `¢10,000.00 USC` or `$10,000.00 USD` — with code suffix.
  static String amountWithCode(
    num value,
    MT5Account? account, {
    int decimals = 2,
  }) =>
      '${amount(value, account, decimals: decimals)} ${code(account)}';

  /// Signed amount for P&L: `+¢5.00` / `-¢5.00`.
  static String signedAmount(
    num value,
    MT5Account? account, {
    int decimals = 2,
  }) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${symbol(account)}${_formatNumber(value.abs(), decimals)}';
  }

  /// Thousand-separated fixed-decimal format: `1,234,567.89`.
  static String _formatNumber(num value, int decimals) {
    final fixed = value.toStringAsFixed(decimals);
    final dot = fixed.indexOf('.');
    final whole = dot >= 0 ? fixed.substring(0, dot) : fixed;
    final frac = dot >= 0 ? fixed.substring(dot) : '';
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${negative ? '-' : ''}$grouped$frac';
  }
}
