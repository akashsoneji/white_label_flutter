import 'package:flutter/widgets.dart';

import '../../../pages/withdrawal_screen.dart' as base;

class WithdrawalScreen extends StatelessWidget {
  final String? accountNumber;

  const WithdrawalScreen({super.key, this.accountNumber});

  @override
  Widget build(BuildContext context) {
    return base.WithdrawalScreen(accountNumber: accountNumber);
  }
}

