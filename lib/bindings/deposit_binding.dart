import 'package:get/get.dart';
import 'package:crm_app/screens/finance/view_models/deposit_controller.dart';

class DepositBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DepositController>(() => DepositController());
  }
}