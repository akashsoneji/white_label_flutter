import 'package:get/get.dart';
import 'package:crm_app/screens/home/more/ticket/ticket_controller.dart';

class TicketBinding extends Bindings {
  @override
  void dependencies() {
    // Reuse the existing controller across list / create / detail screens so
    // that creating a ticket or replying refreshes the same list instance.
    if (Get.isRegistered<TicketController>()) {
      Get.find<TicketController>();
    } else {
      Get.put<TicketController>(TicketController(), permanent: true);
    }
  }
}
