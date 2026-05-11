import 'package:flutter/widgets.dart';

import '../../../pages/deposit_screen.dart' as base;

class DepositScreen extends StatelessWidget {
  final String accountNumber;

  const DepositScreen({super.key, required this.accountNumber});

  @override
  Widget build(BuildContext context) {
    return base.DepositScreen(accountNumber: accountNumber);
  }
}

