import 'dart:io';

import 'package:get/get.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/price_alert_monitor_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// One row of `GET price-alerts` → `data.alerts[]`.
class ServerPriceAlert {
  final int id;
  final String symbol;
  final double targetPrice;
  final String condition;
  final bool isActive;
  final bool isTriggered;
  final String accountNumber;

  const ServerPriceAlert({
    required this.id,
    required this.symbol,
    required this.targetPrice,
    required this.condition,
    required this.isActive,
    required this.isTriggered,
    required this.accountNumber,
  });

  factory ServerPriceAlert.fromJson(Map<String, dynamic> json) {
    return ServerPriceAlert(
      id: int.tryParse('${json['id']}') ?? 0,
      symbol: json['symbol']?.toString() ?? '',
      targetPrice: double.tryParse('${json['target_price']}') ?? 0,
      condition: json['condition']?.toString() ?? 'above',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      isTriggered: json['is_triggered'] == true || json['is_triggered'] == 1,
      accountNumber: json['account_number']?.toString() ?? '',
    );
  }

  ServerPriceAlert copyWith({
    double? targetPrice,
    String? condition,
    bool? isActive,
  }) {
    return ServerPriceAlert(
      id: id,
      symbol: symbol,
      targetPrice: targetPrice ?? this.targetPrice,
      condition: condition ?? this.condition,
      isActive: isActive ?? this.isActive,
      isTriggered: isTriggered,
      accountNumber: accountNumber,
    );
  }
}

/// Server-side price alerts: list (`GET price-alerts`), edit / pause
/// (`PUT price-alerts/{id}`) and delete (`DELETE price-alerts/{id}`).
/// Every change is mirrored onto the local monitor so this device stops or
/// keeps firing the alert accordingly.
class PriceAlertsController extends GetxController {
  final alerts = <ServerPriceAlert>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final busyIds = <int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final response = await ApiService.get(endpoint: ApiConstants.priceAlerts);
      if (!response.success) {
        errorMessage.value =
            response.message ?? TranslationUtils.tr('price_alerts_load_failed');
        return;
      }
      alerts.assignAll(_parseAlerts(response.data));
    } catch (e, stackTrace) {
      AppLogger.error(
        'PriceAlertsController: load failed',
        error: e,
        stackTrace: stackTrace,
      );
      errorMessage.value = TranslationUtils.tr('price_alerts_load_failed');
    } finally {
      isLoading.value = false;
    }
  }

  List<ServerPriceAlert> _parseAlerts(dynamic body) {
    if (body is! Map) return [];
    final data = body['data'] is Map ? body['data'] as Map : body;
    final rawList = data['alerts'];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map((raw) => ServerPriceAlert.fromJson(Map<String, dynamic>.from(raw)))
        .where((alert) => alert.id > 0)
        .toList();
  }

  Future<bool> updateAlert(
    ServerPriceAlert alert, {
    double? targetPrice,
    String? condition,
    bool? isActive,
  }) async {
    if (busyIds.contains(alert.id)) return false;
    busyIds.add(alert.id);
    try {
      final fcmToken = await SecureStorageService.getFcmToken();
      final response = await ApiService.put(
        endpoint: '${ApiConstants.priceAlerts}/${alert.id}',
        data: {
          'symbol': alert.symbol,
          'target_price': targetPrice ?? alert.targetPrice,
          'condition': condition ?? alert.condition,
          'is_active': isActive ?? alert.isActive,
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
          'device_type': Platform.isIOS ? 'ios' : 'android',
        },
      );
      if (!response.success) {
        CustomToastService.showError(
          message:
              response.message ?? TranslationUtils.tr('price_alerts_update_failed'),
        );
        return false;
      }

      final updated = alert.copyWith(
        targetPrice: targetPrice,
        condition: condition,
        isActive: isActive,
      );
      final index = alerts.indexWhere((a) => a.id == alert.id);
      if (index != -1) alerts[index] = updated;
      await _syncLocal(
        alert.id,
        targetPrice: updated.targetPrice,
        condition: updated.condition,
        isActive: updated.isActive,
      );
      CustomToastService.showSuccess(
        message: response.message ?? TranslationUtils.tr('price_alerts_updated'),
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'PriceAlertsController: update failed',
        error: e,
        stackTrace: stackTrace,
      );
      CustomToastService.showError(
        message: TranslationUtils.tr('price_alerts_update_failed'),
      );
      return false;
    } finally {
      busyIds.remove(alert.id);
    }
  }

  Future<void> deleteAlert(ServerPriceAlert alert) async {
    if (busyIds.contains(alert.id)) return;
    busyIds.add(alert.id);
    try {
      final response = await ApiService.delete(
        endpoint: '${ApiConstants.priceAlerts}/${alert.id}',
      );
      if (!response.success) {
        CustomToastService.showError(
          message:
              response.message ?? TranslationUtils.tr('price_alerts_delete_failed'),
        );
        return;
      }
      alerts.removeWhere((a) => a.id == alert.id);
      await _syncLocal(alert.id, isActive: false);
      CustomToastService.showSuccess(
        message: response.message ?? TranslationUtils.tr('price_alerts_deleted'),
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'PriceAlertsController: delete failed',
        error: e,
        stackTrace: stackTrace,
      );
      CustomToastService.showError(
        message: TranslationUtils.tr('price_alerts_delete_failed'),
      );
    } finally {
      busyIds.remove(alert.id);
    }
  }

  Future<void> _syncLocal(
    int serverId, {
    double? targetPrice,
    String? condition,
    bool? isActive,
  }) async {
    if (!Get.isRegistered<PriceAlertMonitorService>()) return;
    await Get.find<PriceAlertMonitorService>().syncLocalAlertFromServer(
      serverId: serverId,
      targetPrice: targetPrice,
      condition: condition,
      isActive: isActive,
    );
  }
}
