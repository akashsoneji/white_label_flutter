import 'package:get/get.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';

class MoreBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MoreController>(() => MoreController());
  }
}