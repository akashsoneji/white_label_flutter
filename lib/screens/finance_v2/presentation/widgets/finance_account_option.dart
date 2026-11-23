/// One selectable row of the finance_v2 account picker.
///
/// Deliberately a plain value class so the shared widgets do not depend on
/// any API model; screens map their wallet / MT5 models into it.
class FinanceAccountOption {
  final String id;
  final String title;
  final String? subtitle;
  final String? balanceText;
  final bool isWallet;

  const FinanceAccountOption({
    required this.id,
    required this.title,
    this.subtitle,
    this.balanceText,
    this.isWallet = false,
  });
}
