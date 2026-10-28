import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import '../models/notification_model.dart';

class NotificationApiProvider {
  Future<NotificationResponse?> getNotifications() async {
    try {
      final response = await ApiService.get(endpoint: ApiConstants.getNotifications);
      if (response.success && response.data != null) {
        return NotificationResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching notifications: $e');
      return null;
    }
  }

  /// Full list for the Notifications screen (`GET user/notifications/all`,
  /// web `loadNotifications`). Falls back to `user/notifications` when the
  /// `/all` route fails or its body has no list, since its response shape is
  /// not confirmed in the API docs.
  Future<NotificationResponse?> getAllNotifications() async {
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.allNotifications,
        queryParameters: {
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        // NotificationController@all only returns JSON for ajax requests;
        // without this header it renders the admin HTML view and 500s.
        extraHeaders: const {'X-Requested-With': 'XMLHttpRequest'},
      );
      if (response.success && response.data is Map) {
        final parsed = NotificationResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        if (parsed.notifications != null) return parsed;
      }
    } catch (e) {
      print('Error fetching all notifications: $e');
    }
    return getNotifications();
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.markAllNotificationsRead,
      );
      return response.success;
    } catch (e) {
      print('Error marking all notifications read: $e');
      return false;
    }
  }

  Future<bool> markAsRead(int id) async {
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.markNotificationRead(id),
      );
      return response.success;
    } catch (e) {
      print('Error marking notification $id read: $e');
      return false;
    }
  }

  /// These endpoints answer `{ok: ...}` with no `status`/`success` field, so
  /// ApiService reports them as successful and `ok` has to be checked here.
  Future<Mt5CredentialsResult> getMt5Credentials(int id) async {
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.mt5CredentialsNotification(id),
      );
      final body = response.data;
      if (!response.success || body is! Map<String, dynamic>) {
        return Mt5CredentialsResult(message: response.message);
      }
      if (body['ok'] == true) {
        return Mt5CredentialsResult(
          credentials: Mt5Credentials.fromJson(body),
        );
      }
      final code = body['code']?.toString();
      final message = body['message']?.toString();
      return Mt5CredentialsResult(
        alreadyShown: code == 'already_shown',
        notFound: code != 'already_shown' && message == 'Not found',
        message: message,
      );
    } catch (e) {
      print('Error fetching MT5 credentials $id: $e');
      return const Mt5CredentialsResult();
    }
  }

  Future<bool> ackMt5Credentials(int id) async {
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.mt5CredentialsAck(id),
      );
      final body = response.data;
      return response.success && body is Map<String, dynamic> && body['ok'] == true;
    } catch (e) {
      print('Error acknowledging MT5 credentials $id: $e');
      return false;
    }
  }
}
