import 'package:flutter/widgets.dart';

import '../../../pages/payment_methods_screen.dart' as base;

class PaymentMethodsScreen extends StatelessWidget {
  final String accountNumber;

  const PaymentMethodsScreen({super.key, required this.accountNumber});

  @override
  Widget build(BuildContext context) {
    return base.PaymentMethodsScreen(accountNumber: accountNumber);
  }
}

