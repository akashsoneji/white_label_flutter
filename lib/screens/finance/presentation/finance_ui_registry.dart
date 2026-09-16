import 'package:flutter/widgets.dart';

import 'finance_ui_slots.dart';

import 'pages/deposit_screen.dart' as base;
import 'pages/internal_transfer_screen.dart' as base;
import 'pages/payment_methods_screen.dart' as base;
import 'pages/transaction_history_screen.dart' as base;
import 'pages/wallet_screen.dart' as base;
import 'pages/withdrawal_screen.dart' as base;

import 'brands/vantage/pages/deposit_screen.dart' as vantage;
import 'brands/vantage/pages/internal_transfer_screen.dart' as vantage;
import 'brands/vantage/pages/payment_methods_screen.dart' as vantage;
import 'brands/vantage/pages/transaction_history_screen.dart' as vantage;
import 'brands/vantage/pages/wallet_screen.dart' as vantage;
import 'brands/vantage/pages/withdrawal_screen.dart' as vantage;

/// Build-time selected client (no runtime switching).
///
const String _activeClient = String.fromEnvironment(
 'CLIENT',
 defaultValue: 'tenax',
);

class FinanceUiRegistry implements FinanceUiSlots {
 const FinanceUiRegistry();

  bool get _usesVantageUi =>
      _activeClient.toLowerCase() == 'vantage' ||
      _activeClient.toLowerCase() == 'baazex' ||
      _activeClient.toLowerCase() == 'gtxprime' ||
      _activeClient.toLowerCase() == 'iquote' ||
      _activeClient.toLowerCase() == 'kantara' ||
      _activeClient.toLowerCase() == 'pipze' ||
      _activeClient.toLowerCase() == 'riyadex' ||
      _activeClient.toLowerCase() == 'skyriss' ||
      _activeClient.toLowerCase() == 'telifox' ||
      _activeClient.toLowerCase() == 'tenax';
  // NOTE: `celestial` and `meta` are PARENT brands with their own UI tree
  // (CelestialMainShell / MetaMainShell). They deliberately do NOT use
  // Vantage's finance screens — so they are intentionally omitted here.

  @override
  Widget paymentMethods({required String accountNumber}) {
    if (_usesVantageUi) {
      return vantage.PaymentMethodsScreen(accountNumber: accountNumber);
    }
    return base.PaymentMethodsScreen(accountNumber: accountNumber);
  }

  @override
  Widget deposit({required String accountNumber}) {
    if (_usesVantageUi) {
      return vantage.DepositScreen(accountNumber: accountNumber);
    }
    return base.DepositScreen(accountNumber: accountNumber);
  }

  @override
  Widget withdrawal() {
    if (_usesVantageUi) return const vantage.WithdrawalScreen();
    return const base.WithdrawalScreen();
  }

  @override
  Widget wallet() {
    if (_usesVantageUi) return const vantage.WalletScreen();
    return base.WalletScreen();
  }

  @override
  Widget internalTransfer() {
    if (_usesVantageUi) return const vantage.InternalTransferScreen();
    return base.InternalTransferScreen();
  }

  @override
  Widget transactionHistory() {
    if (_usesVantageUi) return const vantage.VantageTransactionHistoryScreen();
    return const base.TransactionHistoryScreen();
  }
}
