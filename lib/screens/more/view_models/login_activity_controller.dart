import 'package:get/get.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';

/// One row of GET user/settings/activitylog.
class LoginActivity {
  final String id;
  final String title;
  final String description;
  final DateTime? timestamp;
  final String ipAddress;
  final String location;
  final String device;
  final bool isSuccess;

  const LoginActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.ipAddress,
    required this.location,
    required this.device,
    required this.isSuccess,
  });

  factory LoginActivity.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key]?.toString().trim() ?? '';
    return LoginActivity(
      id: read('id'),
      title: read('title'),
      description: read('description'),
      timestamp: DateTime.tryParse(read('timestamp'))?.toLocal(),
      ipAddress: read('ip_address'),
      location: read('location'),
      device: read('device'),
      isSuccess: read('status').toLowerCase() == 'success',
    );
  }
}

class LoginActivityController extends GetxController {
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final errorMessage = ''.obs;
  final activities = <LoginActivity>[].obs;
  final _currentPage = 1.obs;
  final _lastPage = 1.obs;

  bool get hasMore => _currentPage.value < _lastPage.value;

  @override
  void onInit() {
    super.onInit();
    loadActivities();
  }

  Future<void> loadActivities({bool loadMore = false}) async {
    if (loadMore && (isLoadingMore.value || isLoading.value || !hasMore)) return;
    final page = loadMore ? _currentPage.value + 1 : 1;
    if (loadMore) {
      isLoadingMore(true);
    } else {
      isLoading(true);
      errorMessage('');
    }
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.settingsActivityLog,
        queryParameters: {'page': '$page'},
      );
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      final raw = data is Map ? data['activities'] : null;
      if (!response.success || raw is! List) {
        if (!loadMore) {
          errorMessage(
            response.message?.isNotEmpty == true
                ? response.message!
                : TranslationUtils.tr('login_activity_load_failed'),
          );
        }
        return;
      }
      final parsed = raw
          .whereType<Map>()
          .map((e) => LoginActivity.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (loadMore) {
        activities.addAll(parsed);
      } else {
        activities.assignAll(parsed);
      }
      final pagination = data['pagination'];
      if (pagination is Map) {
        _currentPage.value =
            int.tryParse('${pagination['current_page']}') ?? page;
        _lastPage.value = int.tryParse('${pagination['last_page']}') ?? page;
      } else {
        _currentPage.value = page;
        _lastPage.value = page;
      }
    } catch (_) {
      if (!loadMore) {
        errorMessage(TranslationUtils.tr('login_activity_load_failed'));
      }
    } finally {
      isLoading(false);
      isLoadingMore(false);
    }
  }
}
