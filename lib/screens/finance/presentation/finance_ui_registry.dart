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

const String _activeClient = String.fromEnvironment(
  'CLIENT',
  defaultValue: 'tenax',
);

class FinanceUiRegistry implements FinanceUiSlots {
  const FinanceUiRegistry();

  bool get _isVantage => _activeClient.toLowerCase() == 'vantage';

  @override
  Widget paymentMethods({required String accountNumber}) {
    if (_isVantage) {
      return vantage.PaymentMethodsScreen(accountNumber: accountNumber);
    }
    return base.PaymentMethodsScreen(accountNumber: accountNumber);
  }

  @override
  Widget deposit({required String accountNumber}) {
    if (_isVantage) {
      return vantage.DepositScreen(accountNumber: accountNumber);
    }
    return base.DepositScreen(accountNumber: accountNumber);
  }

  @override
  Widget withdrawal() {
    if (_isVantage) return const vantage.WithdrawalScreen();
    return const base.WithdrawalScreen();
  }

  @override
  Widget wallet() {
    if (_isVantage) return const vantage.WalletScreen();
    return base.WalletScreen();
  }

  @override
  Widget internalTransfer() {
    if (_isVantage) return const vantage.InternalTransferScreen();
    return base.InternalTransferScreen();
  }

  @override
  Widget transactionHistory() {
    if (_isVantage) return const vantage.VantageTransactionHistoryScreen();
    return const base.TransactionHistoryScreen();
  }
}

