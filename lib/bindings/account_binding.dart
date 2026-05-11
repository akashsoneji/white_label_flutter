import 'package:get/get.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';

class AccountBinding extends Bindings {
  @override
  void dependencies() {
    // AccountController is already registered in main, just ensure it's available
    Get.lazyPut<AccountController>(() => Get.find<AccountController>());
  }
}