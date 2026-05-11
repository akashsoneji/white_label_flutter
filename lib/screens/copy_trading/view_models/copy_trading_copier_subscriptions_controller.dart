import 'package:crm_app/core/network/api_response.dart';
import 'package:get/get.dart';

import 'package:crm_app/screens/copy_trading/data/repositories/copy_trading_repository.dart';

class CopierSubscriptionItem {
  final int id;
  final int planId;
  final String planName;
  final String masterName;
  final String masterCode;
  final String serverType;
  final String accountNumber;
  final num capitalAmount;
  final num copyRatio;
  final String copyMethod;
  final num totalPnl;
  final num totalCommissionPaid;
  final int openTrades;
  final String status; // active | paused | stopped

  const CopierSubscriptionItem({
    required this.id,
    required this.planId,
    required this.planName,
    required this.masterName,
    required this.masterCode,
    required this.serverType,
    required this.accountNumber,
    required this.capitalAmount,
    required this.copyRatio,
    required this.copyMethod,
    required this.totalPnl,
    required this.totalCommissionPaid,
    required this.openTrades,
    required this.status,
  });

  factory CopierSubscriptionItem.fromJson(Map<String, dynamic> json) {
    num _num(dynamic v) => (v is num) ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int _int(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    return CopierSubscriptionItem(
      id: _int(json['id']),
      planId: _int(json['plan_id']),
      planName: (json['plan_name'] ?? '').toString(),
      masterName: (json['master_name'] ?? json['master_nickname'] ?? '').toString(),
      masterCode: (json['master_code'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? json['meta_account_number'] ?? '').toString(),
      capitalAmount: _num(json['capital_amount']),
      copyRatio: _num(json['copy_ratio']),
      copyMethod: (json['copy_method'] ?? json['copying_method'] ?? '').toString(),
      totalPnl: _num(json['total_pnl']),
      totalCommissionPaid: _num(json['total_commission_paid']),
      openTrades: _int(json['open_trades'] ?? json['open_trades_count']),
      status: (json['status'] ?? '').toString(),
    );
  }

  bool get isActive => status.toLowerCase() == 'active';
}

class CopyTradingCopierSubscriptionsController extends GetxController {
  final CopyTradingRepository _repo = Get.find<CopyTradingRepository>();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<CopierSubscriptionItem> subscriptions = <CopierSubscriptionItem>[].obs;
  final RxBool actionLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load(showLoading: true);
  }

  Future<void> load({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await _repo.getCopierSubscriptions(
        queryParameters: {'_t': timestamp.toString()},
      );

      if (!res.success || res.data == null) {
        subscriptions.clear();
        errorMessage.value = res.message ?? 'Failed to load subscriptions';
        return;
      }

      final data = res.data?['data'];
      if (data is! List) {
        subscriptions.clear();
        errorMessage.value = 'Invalid response';
        return;
      }

      final list = data
          .whereType<Map>()
          .map((e) => CopierSubscriptionItem.fromJson(e.cast<String, dynamic>()))
          .toList();
      subscriptions.assignAll(list);
    } catch (e) {
      subscriptions.clear();
      errorMessage.value = 'Load error: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<ApiResponse> pause(int subscriptionId) async {
    actionLoading.value = true;
    try {
      final res = await _repo.pauseCopierSubscription(subscriptionId: subscriptionId);
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Pause error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> resume(int subscriptionId) async {
    actionLoading.value = true;
    try {
      final res = await _repo.resumeCopierSubscription(subscriptionId: subscriptionId);
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Resume error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> stop(int subscriptionId) async {
    actionLoading.value = true;
    try {
      final res = await _repo.stopCopierSubscription(subscriptionId: subscriptionId);
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Stop error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> addCapital({required int subscriptionId, required num amount}) async {
    actionLoading.value = true;
    try {
      final res = await _repo.addCapitalToCopierSubscription(
        subscriptionId: subscriptionId,
        amount: amount,
      );
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Add capital error: $e');
    } finally {
      actionLoading.value = false;
    }
  }
}

