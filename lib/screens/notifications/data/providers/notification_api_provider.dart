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

  Future<NotificationResponse?> getAllNotifications(int page) async {
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.getNotifications,
        queryParameters: {
          'page': page.toString(),
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      if (response.success && response.data != null) {
        return NotificationResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching all notifications: $e');
      return null;
    }
  }
}
