import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/kyc/data/repositories/kyc_repository.dart';
import 'package:crm_app/services/app_settings_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// Admin "Force KYC before access" (`app-settings.force_kyc_before_access`).
/// Wraps the post-login main screen: while KYC is not complete the user is
/// sent to the KYC flow with the dashboard removed from the stack, so back
/// cannot reach it. Every login / splash / success path lands on the same
/// route, so one gate covers them all.
class KycLockGate extends StatefulWidget {
  final Widget child;

  const KycLockGate({super.key, required this.child});

  @override
  State<KycLockGate> createState() => _KycLockGateState();
}

class _KycLockGateState extends State<KycLockGate> {
  static const _completeStatuses = {'completed', 'approved', 'verified'};

  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checking = _lockEnabledOrUnknown();
    if (_checking) _check();
  }

  bool _lockEnabledOrUnknown() {
    if (!Get.isRegistered<AppSettingsService>()) return false;
    final service = Get.find<AppSettingsService>();
    return service.settings.value == null ||
        service.current.forceKycBeforeAccess;
  }

  Future<void> _check() async {
    final mustComplete = await _isKycRequiredAndIncomplete();
    if (!mounted) return;
    if (mustComplete) {
      Get.offAllNamed(AppPages.KYC_INTRO);
      return;
    }
    setState(() => _checking = false);
  }

  Future<bool> _isKycRequiredAndIncomplete() async {
    try {
      final settings = await Get.find<AppSettingsService>().fetchAppSettings();
      if (settings == null || !settings.forceKycBeforeAccess) return false;
      if (!Get.isRegistered<KycRepository>()) return false;

      final token = await SecureStorageService.getAuthToken() ?? '';
      final response = await Get.find<KycRepository>().getKycStatus(
        token: token,
      );
      final data = response.data;
      // Unknown status (network / shape) never locks the user out.
      if (!response.success || data is! Map) return false;
      final details = data['data'] is Map ? data['data']['user_details'] : null;
      if (details is! Map) return false;
      final status = details['kyc_status']?.toString().toLowerCase() ?? '';
      return !_completeStatuses.contains(status);
    } catch (e, stackTrace) {
      AppLogger.error('KycLockGate: check failed', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CommonLoadingWidget()));
    }
    return widget.child;
  }
}
