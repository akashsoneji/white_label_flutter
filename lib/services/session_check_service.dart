import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/utils/app_logger.dart';

/// Validates the login session with `GET user/session/check` whenever the app
/// returns to the foreground (web: app root `mounted`). A revoked or expired
/// token answers 401, which [ApiService]'s global handler turns into logout +
/// navigation to login; any other failure (offline, 5xx) is ignored so a bad
/// network never logs the user out.
///
/// Cold start is not checked here: AuthCheckScreen already validates the
/// token on launch and the 401 handler is suppressed during that phase.
class SessionCheckService extends GetxService with WidgetsBindingObserver {
  static const _minInterval = Duration(minutes: 1);

  DateTime? _lastCheck;
  bool _inFlight = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkSession();
    }
  }

  Future<void> checkSession() async {
    final now = DateTime.now();
    final last = _lastCheck;
    if (_inFlight || (last != null && now.difference(last) < _minInterval)) {
      return;
    }

    final token = await SecureStorageService.getAuthToken();
    if (token == null || token.isEmpty) return;

    _inFlight = true;
    _lastCheck = now;
    try {
      final response = await ApiService.get(endpoint: ApiConstants.sessionCheck);
      if (!response.success) {
        AppLogger.debug('SessionCheckService: ${response.message}');
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'SessionCheckService: Error',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _inFlight = false;
    }
  }
}
