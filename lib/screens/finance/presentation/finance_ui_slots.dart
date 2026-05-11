import 'package:flutter/widgets.dart';

abstract class FinanceUiSlots {
  Widget paymentMethods({required String accountNumber});
  Widget deposit({required String accountNumber});
  Widget withdrawal();
  Widget wallet();
  Widget internalTransfer();
  Widget transactionHistory();
}

