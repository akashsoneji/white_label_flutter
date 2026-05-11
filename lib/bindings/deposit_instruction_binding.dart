import 'package:get/get.dart';
import 'package:crm_app/screens/finance/view_models/deposit_instruction_controller.dart';

class DepositInstructionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DepositInstructionController>(
      () => DepositInstructionController(),
    );
  }
}
