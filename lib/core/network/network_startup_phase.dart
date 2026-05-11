/// While active, the global HTTP layer suppresses aggressive 401 handling so
/// [AuthCheckScreen] can finish routing without double-navigation.
///
/// Call [end] after the initial auth check and navigation decision.
abstract final class NetworkStartupPhase {
  static bool _active = true;

  static bool get isActive => _active;

  static void end() {
    _active = false;
  }
}
