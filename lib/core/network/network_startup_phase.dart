/// While active, the global HTTP layer suppresses aggressive 401 handling so
/// the initial auth check can finish routing without double-navigation.
///
/// Call [end] after the initial auth check and navigation decision. The phase
/// also expires on its own after [_maxDuration]: the splash widget is brand
/// specific and not every brand routes through the screen that calls [end], so
/// a missed call must not suppress session-expiry handling for the whole run.
abstract final class NetworkStartupPhase {
  static const Duration _maxDuration = Duration(seconds: 10);

  static final DateTime _startedAt = DateTime.now();
  static bool _ended = false;

  static bool get isActive =>
      !_ended && DateTime.now().difference(_startedAt) < _maxDuration;

  static void end() {
    _ended = true;
  }
}
