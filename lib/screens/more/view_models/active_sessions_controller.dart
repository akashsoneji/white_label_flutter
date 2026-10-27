import 'package:get/get.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// A logged-in device/token (GET user/sessions).
class UserSession {
  final int id;
  final String device;
  final String ipAddress;
  final String location;
  final String lastUsedAt;
  final String createdAt;
  final bool isCurrent;

  const UserSession({
    required this.id,
    required this.device,
    required this.ipAddress,
    required this.location,
    required this.lastUsedAt,
    required this.createdAt,
    required this.isCurrent,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key]?.toString() ?? '';
    final device = read('device');
    return UserSession(
      id: json['id'] is int ? json['id'] as int : int.tryParse(read('id')) ?? 0,
      device: device.isNotEmpty ? device : read('name'),
      ipAddress: read('ip_address'),
      location: read('location'),
      lastUsedAt: read('last_used_at'),
      createdAt: read('created_at'),
      isCurrent: json['is_current'] == true,
    );
  }
}

class ActiveSessionsController extends GetxController {
  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final sessions = <UserSession>[].obs;
  final revokingIds = <int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadSessions();
  }

  Future<void> loadSessions() async {
    isLoading(true);
    errorMessage('');
    try {
      final response = await ApiService.get(endpoint: ApiConstants.userSessions);
      final body = response.data;
      final raw = body is Map<String, dynamic> ? body['data'] : null;
      if (!response.success || raw is! List) {
        errorMessage(
          response.message?.isNotEmpty == true
              ? response.message!
              : TranslationUtils.tr('active_sessions_load_failed'),
        );
        return;
      }
      final parsed = raw
          .whereType<Map<String, dynamic>>()
          .map(UserSession.fromJson)
          .toList();
      // Current device first, then most recently used.
      parsed.sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        return b.lastUsedAt.compareTo(a.lastUsedAt);
      });
      sessions.assignAll(parsed);
    } catch (_) {
      errorMessage(TranslationUtils.tr('active_sessions_load_failed'));
    } finally {
      isLoading(false);
    }
  }

  Future<void> revoke(UserSession session) async {
    if (session.isCurrent || revokingIds.contains(session.id)) return;
    revokingIds.add(session.id);
    try {
      final response = await ApiService.delete(
        endpoint: ApiConstants.userSession(session.id),
      );
      if (response.success) {
        sessions.removeWhere((s) => s.id == session.id);
        CustomToastService.showSuccess(
          message: response.message?.isNotEmpty == true
              ? response.message!
              : TranslationUtils.tr('active_sessions_revoked'),
        );
        return;
      }
      CustomToastService.showError(
        message: response.message?.isNotEmpty == true
            ? response.message!
            : TranslationUtils.tr('active_sessions_revoke_failed'),
      );
    } catch (_) {
      CustomToastService.showError(
        message: TranslationUtils.tr('active_sessions_revoke_failed'),
      );
    } finally {
      revokingIds.remove(session.id);
    }
  }
}
