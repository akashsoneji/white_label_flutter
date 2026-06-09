import 'dart:async';
import 'package:get/get.dart';
import 'package:crm_app/models/app_notification.dart';

/// Global controller to manage app-wide notifications.
class AppNotificationController extends GetxController {
  static const int maxNotifications = 5;
  static const Duration defaultAutoHideDuration = Duration(seconds: 3);
  static const Duration shortAutoHideDuration = Duration(milliseconds: 200);

  final RxList<AppNotification> _notifications = <AppNotification>[].obs;
  final Map<String, Timer> _hideTimers = {};

  List<AppNotification> get notifications => _notifications.toList();

  /// Show a success notification
  String showSuccess({
    required String message,
    String? title,
    Duration? duration,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notification = AppNotification.generic(
      id: id,
      type: NotificationType.success,
      status: NotificationStatus.success,
      title: title,
      message: message,
    );

    _addNotification(notification);
    _scheduleAutoHide(id, duration ?? defaultAutoHideDuration);

    print(
      '📢 AppNotificationController: Showing success notification: $message',
    );
    return id;
  }

  /// Show an error notification
  String showError({
    required String message,
    String? title,
    Duration? duration,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notification = AppNotification.generic(
      id: id,
      type: NotificationType.error,
      status: NotificationStatus.error,
      title: title,
      message: message,
      errorMessage: message,
    );

    _addNotification(notification);
    _scheduleAutoHide(id, duration ?? defaultAutoHideDuration);

    print('📢 AppNotificationController: Showing error notification: $message');
    return id;
  }

  /// Show an info notification
  String showInfo({
    required String message,
    String? title,
    Duration? duration,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notification = AppNotification.generic(
      id: id,
      type: NotificationType.info,
      status: NotificationStatus.success,
      title: title,
      message: message,
    );

    _addNotification(notification);
    _scheduleAutoHide(id, duration ?? defaultAutoHideDuration);

    print('📢 AppNotificationController: Showing info notification: $message');
    return id;
  }

  /// Show a warning notification
  String showWarning({
    required String message,
    String? title,
    Duration? duration,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notification = AppNotification.generic(
      id: id,
      type: NotificationType.warning,
      status: NotificationStatus.success,
      title: title,
      message: message,
    );

    _addNotification(notification);
    _scheduleAutoHide(id, duration ?? defaultAutoHideDuration);

    print(
      '📢 AppNotificationController: Showing warning notification: $message',
    );
    return id;
  }

  /// Add a trading notification (for chart screen compatibility)
  /// Returns the notification ID for later updates
  String addTradingNotification({
    required String symbol,
    required String type,
    required double volume,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notification = AppNotification.trading(
      id: id,
      symbol: symbol,
      tradeType: type,
      volume: volume,
      status: NotificationStatus.loading,
    );

    _addNotification(notification);
    print('📢 AppNotificationController: Added trading notification $id');
    return id;
  }

  /// Update trading notification status (loading -> success/error)
  void updateTradingNotificationStatus({
    required String id,
    required bool isSuccess,
    String? errorMessage,
  }) {
    final index = _notifications.indexWhere((n) => n.id == id);

    if (index == -1) {
      print('⚠️ AppNotificationController: Notification $id not found');
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
      '📢 AppNotificationController: Updated trading notification $id to $newStatus',
    );

    // Schedule auto-hide after short duration (for trading notifications)
    _scheduleAutoHide(id, shortAutoHideDuration);
  }

  /// Add a notification to the list
  void _addNotification(AppNotification notification) {
    // For trading notifications (chart screen), allow multiple notifications
    // For generic notifications (other screens), clear previous generic notifications
    // to prevent overlap and show only one notification at a time
    if (!notification.isTradingNotification) {
      // Clear all previous generic notifications before adding new one
      // This ensures only one generic notification is shown at a time
      final genericNotificationIds =
          _notifications
              .where((n) => !n.isTradingNotification)
              .map((n) => n.id)
              .toList();

      for (final id in genericNotificationIds) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _notifications.removeAt(index);
          _cancelHideTimer(id);
        }
      }

      if (genericNotificationIds.isNotEmpty) {
        print(
          '📢 AppNotificationController: Cleared ${genericNotificationIds.length} previous generic notification(s)',
        );
      }
    } else {
      // For trading notifications, remove oldest trading notification if we're at the limit
      // This maintains the multiple notification behavior for chart screen
      final tradingNotifications =
          _notifications.where((n) => n.isTradingNotification).toList();
      if (tradingNotifications.length >= maxNotifications) {
        final oldest = tradingNotifications.first;
        final index = _notifications.indexWhere((n) => n.id == oldest.id);
        if (index != -1) {
          _notifications.removeAt(index);
          _cancelHideTimer(oldest.id);
        }
      }
    }

    _notifications.add(notification);
  }

  /// Remove a notification by ID
  void removeNotification(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications.removeAt(index);
      _cancelHideTimer(id);
      print('📢 AppNotificationController: Removed notification $id');
    }
  }

  /// Clear all notifications
  void clearAll() {
    for (final notification in _notifications) {
      _cancelHideTimer(notification.id);
    }
    _notifications.clear();
    print('📢 AppNotificationController: Cleared all notifications');
  }

  /// Schedule auto-hide for a notification
  void _scheduleAutoHide(String id, Duration duration) {
    // Cancel any existing timer for this notification
    _cancelHideTimer(id);

    // Schedule new timer
    _hideTimers[id] = Timer(duration, () {
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
