import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/screens/copy_trading/data/repositories/copy_trading_repository.dart';
import 'package:get/get.dart';

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
    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.toInt() ?? 0;
    }

    num _n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return MasterCopierItem(
      id: _i(json['id']),
      userId: _i(json['user_id']),
      userName: (json['user_name'] ?? '').toString(),
      userEmail: (json['user_email'] ?? '').toString(),
      planId: _i(json['plan_id']),
      planName: (json['plan_name'] ?? '').toString(),
      planStatus: (json['plan_status'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      capitalAmount: _n(json['capital_amount']),
      copyRatio: _n(json['copy_ratio'] ?? 1),
      copyMethod: (json['copy_method'] ?? '').toString(),
      totalPnl: _n(json['total_pnl']),
      totalCommissionPaid: _n(json['total_commission_paid']),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionPercentage: _n(json['commission_percentage']),
      subscriptionFee: _n(json['subscription_fee']),
      activeSince: (json['active_since'] ?? '').toString(),
      subscriptionStartedAt: (json['subscription_started_at'] ?? '').toString(),
      pausedAt: (json['paused_at'] ?? '').toString(),
      stoppedAt: (json['stopped_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      openTradesCount: _i(json['open_trades_count'] ?? 0),
      copyOpenTrades: json['copy_open_trades'] == true,
      overridesSlTp: json['overrides_sl_tp'] == true,
      takeProfit: (json['take_profit'] ?? '').toString(),
      stopLoss: (json['stop_loss'] ?? '').toString(),
      slTpMode: (json['sl_tp_mode'] ?? '').toString(),
      sizingMethod: (json['sizing_method'] ?? '').toString(),
      lotMultiplier: _n(json['lot_multiplier']),
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
  final CopyTradingRepository _repo = Get.find<CopyTradingRepository>();
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<MasterCopierItem> copiers = <MasterCopierItem>[].obs;
  final RxBool actionLoading = false.obs;

  // Summary from API /master/copiers response
  final RxInt summaryTotal = 0.obs;
  final RxInt summaryPending = 0.obs;
  final RxInt summaryActive = 0.obs;
  final RxInt summaryPaused = 0.obs;
  final RxInt summaryStopped = 0.obs;
  final RxInt summaryCancelled = 0.obs;
  final Rx<num> summaryTotalCapital = 0.0.obs;
  final Rx<num> summaryTotalPnl = 0.0.obs;
  final Rx<num> summaryTotalCommissionPaid = 0.0.obs;

  int _currentPage = 1;
  int _totalPages = 1;
  bool get hasMore => _currentPage < _totalPages;

  @override
  void onInit() {
    super.onInit();
    load(showLoading: true);
  }

  Future<void> load({bool showLoading = false}) async {
    _currentPage = 1;
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await _repo.getMasterCopiersList(
        page: 1,
        perPage: 20,
        queryParameters: {'_t': timestamp.toString()},
      );

      if (!res.success || res.data == null) {
        copiers.clear();
        errorMessage.value = res.message ?? 'Failed to load copiers';
        return;
      }

      final summary = res.data?['data'];
      if (summary is! Map) {
        copiers.clear();
        errorMessage.value = 'Invalid response';
        return;
      }

      final data = summary['data'];
      if (data is! List) {
        copiers.clear();
        errorMessage.value = 'Invalid response';
        return;
      }

      _totalPages = int.tryParse(summary['total_pages']?.toString() ?? '1') ?? 1;

      // Parse summary from API
      final apiSummary = summary['summary'] as Map<String, dynamic>?;
      if (apiSummary != null) {
        _parseApiSummary(apiSummary);
      }

      final list = data
          .whereType<Map>()
          .map((e) => MasterCopierItem.fromJson(e.cast<String, dynamic>()))
          .toList();
      copiers.assignAll(list);
    } catch (e,t) {
      copiers.clear();
            print('Load error: $e\n$t');

      errorMessage.value = 'Load error: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore.value) return;
    isLoadingMore.value = true;
    try {
      final nextPage = _currentPage + 1;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await _repo.getMasterCopiersList(
        page: nextPage,
        perPage: 20,
        queryParameters: {'_t': timestamp.toString()},
      );

      if (!res.success || res.data == null) return;

      final summary = res.data?['data'] as Map<String, dynamic>?;
      if (summary == null) return;

      final data = summary['data'];
      if (data is! List) return;

      _currentPage = nextPage;
      _totalPages = int.tryParse(summary['total_pages']?.toString() ?? '1') ?? 1;

      final apiSummary = summary['summary'] as Map<String, dynamic>?;
      if (apiSummary != null) _parseApiSummary(apiSummary);

      final list = data
          .whereType<Map>()
          .map((e) => MasterCopierItem.fromJson(e.cast<String, dynamic>()))
          .toList();
      copiers.addAll(list);
    } catch (_) {
    } finally {
      isLoadingMore.value = false;
    }
  }

  void _parseApiSummary(Map<String, dynamic> apiSummary) {
    double _n(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    summaryTotal.value = _i(apiSummary['total']);
    summaryPending.value = _i(apiSummary['pending']);
    summaryActive.value = _i(apiSummary['active']);
    summaryPaused.value = _i(apiSummary['paused']);
    summaryStopped.value = _i(apiSummary['stopped']);
    summaryCancelled.value = _i(apiSummary['cancelled']);
    summaryTotalCapital.value = _n(apiSummary['total_capital']);
    summaryTotalPnl.value = _n(apiSummary['total_pnl']);
    summaryTotalCommissionPaid.value = _n(apiSummary['total_commission_paid']);
  }

  Future<ApiResponse> pause(int copierId) async {
    actionLoading.value = true;
    try {
      final res = await _repo.pauseCopierSubscription(subscriptionId: copierId);
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
      final res = await _repo.resumeCopierSubscription(subscriptionId: copierId);
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
      final res = await _repo.stopCopierSubscription(subscriptionId: copierId);
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
      final res = await _repo.addCapitalToCopierSubscription(
        subscriptionId: copierId,
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
