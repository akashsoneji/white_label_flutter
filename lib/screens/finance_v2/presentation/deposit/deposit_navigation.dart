import 'package:get/get.dart';

import 'package:crm_app/routes/app_pages.dart';

/// Opens the app's existing verification flow.
Future<void> openDepositKyc() async {
  await Get.toNamed(Routes.KYC_INTRO);
}

/// Leaves the deposit flow for Transaction History, dropping every deposit
/// screen from the stack.
void openDepositTransactionHistory() {
  Get.offNamedUntil(Routes.TRANSACTION_HISTORY, (route) => route.isFirst);
}
