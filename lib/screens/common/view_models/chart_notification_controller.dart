import 'dart:async';
import 'package:get/get.dart';
import 'package:crm_app/models/chart_notification.dart';

/// Controller to manage chart trading notifications
class ChartNotificationController extends GetxController {
  static const int maxNotifications = 5;
  static const Duration autoHideDuration = Duration(milliseconds: 200);

  final RxList<ChartNotification> _notifications = <ChartNotification>[].obs;
  final Map<String, Timer> _hideTimers = {};

  /// Observable list of notifications
  List<ChartNotification> get notifications => _notifications.toList();

  /// Add a new notification with loading status
  /// Returns the notification ID for later updates
  String addNotification({
    required String symbol,
    required String type,
    required double volume,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final notification = ChartNotification(
      id: id,
      symbol: symbol,
      type: type,
      volume: volume,
      status: NotificationStatus.loading,
    );

    // Remove oldest notification if we're at the limit
    if (_notifications.length >= maxNotifications) {
      final oldest = _notifications.removeAt(0);
      _cancelHideTimer(oldest.id);
    }

    _notifications.add(notification);

    print('📢 ChartNotificationController: Added notification $id');

    return id;
  }

  /// Update notification status (loading -> success/error)
  void updateNotificationStatus({
    required String id,
    required bool isSuccess,
    String? errorMessage,
  }) {
    final index = _notifications.indexWhere((n) => n.id == id);

    if (index == -1) {
      print('⚠️ ChartNotificationController: Notification $id not found');
      return;
    }

    final notification = _notifications[index];
    final newStatus =
        isSuccess ? NotificationStatus.success : NotificationStatus.error;

    _notifications[index] = notification.copyWith(
      status: newStatus,
      errorMessage: errorMessage,
    );

    print(
      '📢 ChartNotificationController: Updated notification $id to $newStatus',
    );

    // Schedule auto-hide after 0.2 seconds
    _scheduleAutoHide(id);
  }

  /// Remove a notification by ID
  void removeNotification(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications.removeAt(index);
      _cancelHideTimer(id);
      print('📢 ChartNotificationController: Removed notification $id');
    }
  }

  /// Clear all notifications
  void clearAll() {
    for (final notification in _notifications) {
      _cancelHideTimer(notification.id);
    }
    _notifications.clear();
    print('📢 ChartNotificationController: Cleared all notifications');
  }

  /// Schedule auto-hide for a notification
  void _scheduleAutoHide(String id) {
    // Cancel any existing timer for this notification
    _cancelHideTimer(id);

    // Schedule new timer
    _hideTimers[id] = Timer(autoHideDuration, () {
      removeNotification(id);
      _hideTimers.remove(id);
    });
  }

  /// Cancel hide timer for a notification
  void _cancelHideTimer(String id) {
    _hideTimers[id]?.cancel();
    _hideTimers.remove(id);
  }

  @override
  void onClose() {
    // Cancel all timers
    for (final timer in _hideTimers.values) {
      timer.cancel();
    }
    _hideTimers.clear();
    _notifications.clear();
    super.onClose();
  }
}
