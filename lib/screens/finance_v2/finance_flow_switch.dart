import 'package:crm_app/flavor_config.dart';
import 'package:flutter/widgets.dart';

import 'presentation/deposit/deposit_type_screen.dart';
import 'presentation/withdrawal/withdrawal_type_screen.dart';

/// Picks between the old deposit / withdrawal screens and the quote-driven
/// flow of TSK-0119.
///
/// Call sites keep building their old screen inside [legacy], so a brand with
/// the flag off gets exactly the screen it had before.
abstract final class FinanceFlowSwitch {
  static bool get useNewFlow =>
      FlavorConfig.instance.useNewDepositWithdrawFlow;

  static Widget deposit({
    required String accountNumber,
    required Widget Function() legacy,
  }) {
    if (!useNewFlow) return legacy();
    return DepositTypeScreen(accountNumber: accountNumber);
  }

  static Widget withdrawal({
    String? accountNumber,
    required Widget Function() legacy,
  }) {
    if (!useNewFlow) return legacy();
    return WithdrawalTypeScreen(accountNumber: accountNumber);
  }
}
