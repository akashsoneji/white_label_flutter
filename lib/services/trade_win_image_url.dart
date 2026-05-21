import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/secure_storage_service.dart';

class TradeWinImageUrl {
  static Future<Map<String, String>> authHeaders() async {
    final token = await SecureStorageService.getAuthToken();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  static String resolve(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return '';
    final path = imagePath.trim().replaceAll('\\', '/');
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = ApiConstants.baseUrl.endsWith('/')
        ? ApiConstants.baseUrl
        : '${ApiConstants.baseUrl}/';
    if (path.startsWith('storage/')) {
      return '$base$path';
    }
    return '${base}storage/$path';
  }
}
