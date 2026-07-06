import 'package:get/get.dart';

import '../controllers/demo_contest_controller.dart';

/// Binding for the Demo Contest module. Registered lazily once and
/// shared across every screen in the module (Join, Leaderboard, My
/// History) so joining a contest in one tab immediately updates the
/// leaderboard/history views without a refetch.
class DemoContestBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DemoContestController>(() => DemoContestController());
  }
}