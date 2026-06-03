import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_dashboard_controller.dart';

class MasterCopierItem {
  final int id;
  final int userId;
  final String userName;
  final String userEmail;
  final int planId;
  final String planName;
  final String planStatus;
  final String accountNumber;
  final String serverType;
  final String status;
  final num capitalAmount;
  final num copyRatio;
  final String copyMethod;
  final num totalPnl;
  final num totalCommissionPaid;
  final String commissionType;
  final num commissionPercentage;
  final num subscriptionFee;
  final String activeSince;
  final String subscriptionStartedAt;
  final String pausedAt;
  final String stoppedAt;
  final String createdAt;
  final String updatedAt;
  final int openTradesCount;
  final bool copyOpenTrades;
  final bool overridesSlTp;
  final String takeProfit;
  final String stopLoss;
  final String slTpMode;
  final String sizingMethod;
  final num lotMultiplier;

  const MasterCopierItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.planId,
    required this.planName,
    required this.planStatus,
    required this.accountNumber,
    required this.serverType,
    required this.status,
    required this.capitalAmount,
    required this.copyRatio,
    required this.copyMethod,
    required this.totalPnl,
    required this.totalCommissionPaid,
    required this.commissionType,
    required this.commissionPercentage,
    required this.subscriptionFee,
    required this.activeSince,
    required this.subscriptionStartedAt,
    required this.pausedAt,
    required this.stoppedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.openTradesCount,
    required this.copyOpenTrades,
    required this.overridesSlTp,
    required this.takeProfit,
    required this.stopLoss,
    required this.slTpMode,
    required this.sizingMethod,
    required this.lotMultiplier,
  });

  factory MasterCopierItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.toInt() ?? 0;
    }

    num asNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return MasterCopierItem(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      userName: (json['user_name'] ?? '').toString(),
      userEmail: (json['user_email'] ?? '').toString(),
      planId: asInt(json['plan_id']),
      planName: (json['plan_name'] ?? '').toString(),
      planStatus: (json['plan_status'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      capitalAmount: asNum(json['capital_amount']),
      copyRatio: asNum(json['copy_ratio'] ?? 1),
      copyMethod: (json['copy_method'] ?? '').toString(),
      totalPnl: asNum(json['total_pnl']),
      totalCommissionPaid: asNum(json['total_commission_paid']),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionPercentage: asNum(json['commission_percentage']),
      subscriptionFee: asNum(json['subscription_fee']),
      activeSince: (json['active_since'] ?? '').toString(),
      subscriptionStartedAt: (json['subscription_started_at'] ?? '').toString(),
      pausedAt: (json['paused_at'] ?? '').toString(),
      stoppedAt: (json['stopped_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      openTradesCount: asInt(json['open_trades_count'] ?? 0),
      copyOpenTrades: json['copy_open_trades'] == true,
      overridesSlTp: json['overrides_sl_tp'] == true,
      takeProfit: (json['take_profit'] ?? '').toString(),
      stopLoss: (json['stop_loss'] ?? '').toString(),
      slTpMode: (json['sl_tp_mode'] ?? '').toString(),
      sizingMethod: (json['sizing_method'] ?? '').toString(),
      lotMultiplier: asNum(json['lot_multiplier']),
    );
  }

  bool get isActive => status.toLowerCase() == 'active';

  String get formattedActiveSince {
    if (activeSince.isEmpty) return '-';
    try {
      final dt = DateTime.parse(activeSince);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return activeSince;
    }
  }

  String get commissionDisplay {
    if (commissionType == 'per_trade') {
      return '${commissionPercentage.toStringAsFixed(0)}% per trade';
    } else if (commissionType == 'subscription') {
      return '\$$subscriptionFee / period';
    }
    return commissionPercentage > 0 ? '${commissionPercentage.toStringAsFixed(0)}%' : '-';
  }

  String get formattedSubscriptionStartedAt {
    if (subscriptionStartedAt.isEmpty) return '-';
    try {
      final dt = DateTime.parse(subscriptionStartedAt);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return subscriptionStartedAt;
    }
  }

  String get initials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }
}

class CopyTradingMasterCopiersController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<MasterCopierItem> copiers = <MasterCopierItem>[].obs;
  final RxBool actionLoading = false.obs;

  // Summary stats
  final RxInt summaryTotal = 0.obs;
  final RxInt summaryPending = 0.obs;
  final RxInt summaryActive = 0.obs;
  final RxInt summaryPaused = 0.obs;
  final RxInt summaryStopped = 0.obs;
  final RxInt summaryCancelled = 0.obs;
  final RxInt summaryStoppedOrRemoved = 0.obs;
  final Rx<num> summaryTotalCapital = 0.0.obs;
  final Rx<num> summaryTotalPnl = 0.0.obs;
  final Rx<num> summaryTotalCommissionPaid = 0.0.obs;

  final RxList<CopyTradingMasterPlanItem> masterPlans = <CopyTradingMasterPlanItem>[].obs;

  // Filter & Pagination States
  final RxString searchQuery = ''.obs;
  final RxString statusFilter = 'all'.obs; // 'all', 'active', 'pending', 'paused', 'stopped'
  final RxnInt planFilter = RxnInt(); // null (all), or a specific plan ID

  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalItemsCount = 0.obs;
  final int perPage = 20;

  bool get hasMore => currentPage.value < totalPages.value;

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await fetchPlans();
    await load(showLoading: true);
  }

  Future<void> fetchPlans() async {
    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingMasterPlans,
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      if (res.success && res.data != null) {
        final data = res.data?['data'];
        if (data is List) {
          masterPlans.assignAll(
            data.whereType<Map>().map((e) => CopyTradingMasterPlanItem.fromJson(e.cast<String, dynamic>())),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> load({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    currentPage.value = 1;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final Map<String, dynamic> params = {
        'page': '1',
        'per_page': perPage.toString(),
        '_t': timestamp.toString(),
      };
      if (searchQuery.value.trim().isNotEmpty) {
        params['search'] = searchQuery.value.trim();
      }
      if (statusFilter.value != 'all') {
        params['status'] = statusFilter.value;
      }
      if (planFilter.value != null) {
        params['plan_id'] = planFilter.value.toString();
      }

      final res = await ApiService.get(
        endpoint: '${ApiConstants.ajax}copytrading/master/copiers',
        queryParameters: params,
      );

      if (!res.success || res.data == null) {
        copiers.clear();
        errorMessage.value = res.message ?? 'Failed to load copiers';
        return;
      }

      final body = res.data?['data'];
      if (body is! Map) {
        copiers.clear();
        errorMessage.value = 'Invalid response format';
        return;
      }

      totalPages.value = int.tryParse(body['total_pages']?.toString() ?? '1') ?? 1;
      totalItemsCount.value = int.tryParse(body['total']?.toString() ?? '0') ?? 0;

      // Parse summary from API
      final apiSummary = body['summary'] as Map<String, dynamic>?;
      if (apiSummary != null) {
        _parseApiSummary(apiSummary);
      }

      final dataList = body['data'];
      if (dataList is List) {
        final list = dataList
            .whereType<Map>()
            .map((e) => MasterCopierItem.fromJson(e.cast<String, dynamic>()))
            .toList();
        copiers.assignAll(list);
      } else {
        copiers.clear();
      }
    } catch (e) {
      copiers.clear();
      errorMessage.value = 'Load error: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore.value || isLoading.value) return;
    isLoadingMore.value = true;
    try {
      final nextPage = currentPage.value + 1;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final Map<String, dynamic> params = {
        'page': nextPage.toString(),
        'per_page': perPage.toString(),
        '_t': timestamp.toString(),
      };
      if (searchQuery.value.trim().isNotEmpty) {
        params['search'] = searchQuery.value.trim();
      }
      if (statusFilter.value != 'all') {
        params['status'] = statusFilter.value;
      }
      if (planFilter.value != null) {
        params['plan_id'] = planFilter.value.toString();
      }

      final res = await ApiService.get(
        endpoint: '${ApiConstants.ajax}copytrading/master/copiers',
        queryParameters: params,
      );

      if (!res.success || res.data == null) return;

      final body = res.data?['data'];
      if (body is! Map) return;

      totalPages.value = int.tryParse(body['total_pages']?.toString() ?? '1') ?? 1;
      totalItemsCount.value = int.tryParse(body['total']?.toString() ?? '0') ?? 0;

      final apiSummary = body['summary'] as Map<String, dynamic>?;
      if (apiSummary != null) {
        _parseApiSummary(apiSummary);
      }

      final dataList = body['data'];
      if (dataList is List) {
        final list = dataList
            .whereType<Map>()
            .map((e) => MasterCopierItem.fromJson(e.cast<String, dynamic>()))
            .toList();
        copiers.addAll(list);
        currentPage.value = nextPage;
      }
    } catch (_) {
    } finally {
      isLoadingMore.value = false;
    }
  }

  void _parseApiSummary(Map<String, dynamic> apiSummary) {
    double asNum(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    summaryTotal.value = asInt(apiSummary['total']);
    summaryPending.value = asInt(apiSummary['pending']);
    summaryActive.value = asInt(apiSummary['active']);
    summaryPaused.value = asInt(apiSummary['paused']);
    summaryStopped.value = asInt(apiSummary['stopped']);
    summaryCancelled.value = asInt(apiSummary['cancelled']);
    summaryStoppedOrRemoved.value = asInt(apiSummary['stopped_or_removed']);
    summaryTotalCapital.value = asNum(apiSummary['total_capital']);
    summaryTotalPnl.value = asNum(apiSummary['total_pnl']);
    summaryTotalCommissionPaid.value = asNum(apiSummary['total_commission_paid']);
  }

  Future<ApiResponse> pause(int copierId) async {
    actionLoading.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingCopierSubscriptionPause(copierId),
        data: <String, dynamic>{},
      );
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Pause error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> resume(int copierId) async {
    actionLoading.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingCopierSubscriptionResume(copierId),
        data: <String, dynamic>{},
      );
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Resume error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> stop(int copierId) async {
    actionLoading.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingCopierSubscriptionStop(copierId),
        data: <String, dynamic>{},
      );
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Stop error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> addCapital({required int copierId, required num amount}) async {
    actionLoading.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingCopierSubscriptionAddCapital(copierId),
        data: <String, dynamic>{'amount': amount},
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
