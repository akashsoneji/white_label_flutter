import 'package:get/get.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // AuthController is already registered in main, just ensure it's available
    Get.lazyPut<AuthController>(() => Get.find<AuthController>());
  }
}