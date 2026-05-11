import 'package:get/get.dart';
import 'package:crm_app/screens/finance/view_models/payment_method_controller.dart';

class PaymentMethodBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentMethodController>(() => PaymentMethodController());
  }
}