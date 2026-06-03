import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:get/get.dart';

class CopyTradingMasterPlanDetail {
  final int id;
  final String planName;
  final String status;

  final String strategyDescription;
  final String riskInformation;
  final String lpProviderName;
  final String tradingAccountNumber;

  final num subscriptionFee;
  final int subscriptionPeriodDays;
  final int noFeeDays;
  final num minimumCapital;
  final num copyRatio;
  final int maxCopiers;
  final bool isFull;

  final int activeCopiers;
  final int openPositions;
  final num totalCapital;
  final num totalCommissionEarned;

  final String commissionType;
  final String commissionLabel;
  final num commissionPercentage;

  final num takeProfitPips;
  final num stopLossPips;

  final bool copyingPaused;
  final String copyingPausedAt;

  final String initialEquitySnapshot;
  final String createdAt;
  final String tradingServer;

  final List<CopyTradingMasterTradeHistoryItem> tradeHistory;
  final List<CopyTradingMasterCommissionHistoryItem> commissionHistory;

  const CopyTradingMasterPlanDetail({
    required this.id,
    required this.planName,
    required this.status,
    required this.strategyDescription,
    required this.riskInformation,
    required this.lpProviderName,
    required this.tradingAccountNumber,
    required this.subscriptionFee,
    required this.subscriptionPeriodDays,
    required this.noFeeDays,
    required this.minimumCapital,
    required this.copyRatio,
    required this.maxCopiers,
    required this.activeCopiers,
    required this.openPositions,
    required this.totalCapital,
    required this.totalCommissionEarned,
    required this.commissionType,
    required this.commissionLabel,
    required this.commissionPercentage,
    required this.takeProfitPips,
    required this.stopLossPips,
    required this.copyingPaused,
    required this.copyingPausedAt,
    required this.tradeHistory,
    required this.commissionHistory,
    required this.initialEquitySnapshot,
    required this.createdAt,
    required this.isFull,
    required this.tradingServer,
  });

  factory CopyTradingMasterPlanDetail.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    List<Map<String, dynamic>> toMapList(dynamic v) {
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      return const <Map<String, dynamic>>[];
    }

    return CopyTradingMasterPlanDetail(
      id: toInt(json['id']),
      planName: (json['plan_name'] ?? json['planName'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      strategyDescription: (json['strategy_description'] ?? '').toString(),
      riskInformation: (json['risk_information'] ?? '').toString(),
      lpProviderName: (json['lp_provider_name'] ?? '').toString(),
      tradingAccountNumber: (json['trading_account_number'] ?? '').toString(),
      subscriptionFee: toNum(json['subscription_fee']),
      subscriptionPeriodDays: toInt(json['subscription_period_days']),
      noFeeDays: toInt(json['no_fee_days']),
      minimumCapital: toNum(json['minimum_capital']),
      copyRatio: toNum(json['copy_ratio']),
      maxCopiers: toInt(json['max_copiers']),
      activeCopiers: toInt(json['active_copiers']),
      openPositions: toInt(json['open_positions']),
      totalCapital: toNum(json['total_capital']),
      totalCommissionEarned: toNum(json['total_commission_earned']),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionLabel: (json['commission_label'] ?? '').toString(),
      commissionPercentage: toNum(json['commission_percentage']),
      takeProfitPips: toNum(json['take_profit_pips']),
      stopLossPips: toNum(json['stop_loss_pips']),
      copyingPaused: json['copying_paused'] == true,
      copyingPausedAt: (json['copying_paused_at'] ?? '').toString(),
      tradeHistory: toMapList(json['trade_history']).map(CopyTradingMasterTradeHistoryItem.fromJson).toList(),
      commissionHistory: toMapList(json['commission_history']).map(CopyTradingMasterCommissionHistoryItem.fromJson).toList(),
      initialEquitySnapshot: (json['initial_equity_snapshot'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      isFull: json['is_full'] == true,
      tradingServer: (json['trading_server'] ?? '').toString(),
    );
  }
}

class CopyTradingMasterTradeHistoryItem {
  final int id;
  final String symbol;
  final String direction;
  final num masterVolume;
  final num copierVolume;
  final num openPrice;
  final num closePrice;
  final String openTime;
  final String closeTime;
  final String status;
  final num masterProfit;
  final num copierProfit;
  final String copierAccount;
  final String copierName;

  const CopyTradingMasterTradeHistoryItem({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.masterVolume,
    required this.copierVolume,
    required this.openPrice,
    required this.closePrice,
    required this.openTime,
    required this.closeTime,
    required this.status,
    required this.masterProfit,
    required this.copierProfit,
    required this.copierAccount,
    required this.copierName,
  });

  factory CopyTradingMasterTradeHistoryItem.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return CopyTradingMasterTradeHistoryItem(
      id: toInt(json['id']),
      symbol: (json['symbol'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      masterVolume: toNum(json['master_volume']),
      copierVolume: toNum(json['copier_volume']),
      openPrice: toNum(json['open_price']),
      closePrice: toNum(json['close_price']),
      openTime: (json['open_time'] ?? '').toString(),
      closeTime: (json['close_time'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      masterProfit: toNum(json['master_profit']),
      copierProfit: toNum(json['copier_profit']),
      copierAccount: (json['copier_account'] ?? '').toString(),
      copierName: (json['copier_name'] ?? '').toString(),
    );
  }
}

class CopyTradingMasterCommissionHistoryItem {
  final int id;
  final String settledAt;
  final String symbol;
  final String copierAccount;
  final String copierName;
  final num grossProfitShare;
  final num commissionCharged;
  final num masterCommissionCredited;
  final bool inGracePeriod;
  final String status;

  const CopyTradingMasterCommissionHistoryItem({
    required this.id,
    required this.settledAt,
    required this.symbol,
    required this.copierAccount,
    required this.copierName,
    required this.grossProfitShare,
    required this.commissionCharged,
    required this.masterCommissionCredited,
    required this.inGracePeriod,
    required this.status,
  });

  factory CopyTradingMasterCommissionHistoryItem.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    bool toBool(dynamic v) {
      if (v is bool) return v;
      final s = (v ?? '').toString().toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes';
    }

    return CopyTradingMasterCommissionHistoryItem(
      id: toInt(json['id']),
      settledAt: (json['settled_at'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      copierAccount: (json['copier_account'] ?? '').toString(),
      copierName: (json['copier_name'] ?? '').toString(),
      grossProfitShare: toNum(json['gross_profit_share']),
      commissionCharged: toNum(json['commission_charged']),
      masterCommissionCredited: toNum(json['master_commission_credited']),
      inGracePeriod: toBool(json['in_grace_period']),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class CopyTradingMasterPlanDetailController extends GetxController {
  final int planId;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<CopyTradingMasterPlanDetail> detail = Rxn<CopyTradingMasterPlanDetail>();

  CopyTradingMasterPlanDetailController({required this.planId});

  @override
  void onInit() {
    super.onInit();
    loadPlanDetail(showLoading: true);
  }

  Future<void> loadPlanDetail({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    update();
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId';
      final res = await ApiService.get(endpoint: endpoint, queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()});
      if (!res.success || res.data == null) {
        detail.value = null;
        errorMessage.value = res.message ?? 'Failed to load plan detail';
        update();
        return;
      }

      final data = res.data?['data'];
      if (data is! Map) {
        detail.value = null;
        errorMessage.value = 'Invalid response';
        update();
        return;
      }

      detail.value = CopyTradingMasterPlanDetail.fromJson(data.cast<String, dynamic>());
      update();
    } catch (e) {
      detail.value = null;
      errorMessage.value = 'Load error: $e';
      update();
    } finally {
      if (showLoading) isLoading.value = false;
      update();
    }
  }

  /// Pause a master plan copying
  Future<ApiResponse> pausePlan() async {
    isLoading.value = true;
    update();
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId/pause';
      final res = await ApiService.post(endpoint: endpoint, data: <String, dynamic>{});
      if (res.success) {
        await loadPlanDetail(showLoading: false);
      } else {
        errorMessage.value = res.message ?? 'Failed to pause plan';
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Pause plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
      update();
    }
  }

  /// Resume a master plan copying
  Future<ApiResponse> resumePlan() async {
    isLoading.value = true;
    update();
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId/resume';
      final res = await ApiService.post(endpoint: endpoint, data: <String, dynamic>{});
      if (res.success) {
        await loadPlanDetail(showLoading: false);
      } else {
        errorMessage.value = res.message ?? 'Failed to resume plan';
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Resume plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
      update();
    }
  }

  /// Update a master plan (name, strategy, risk)
  Future<ApiResponse> updatePlan({required Map<String, dynamic> body}) async {
    isLoading.value = true;
    update();
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId';
      final res = await ApiService.post(endpoint: endpoint, data: body);
      if (res.success) {
        await loadPlanDetail(showLoading: false);
      } else {
        errorMessage.value = res.message ?? 'Failed to update plan';
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Update plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
      update();
    }
  }

  /// Inactivate a master plan
  Future<ApiResponse> inactivatePlan() async {
    isLoading.value = true;
    update();
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId/inactivate';
      final res = await ApiService.post(endpoint: endpoint, data: <String, dynamic>{});
      if (res.success) {
        await loadPlanDetail(showLoading: false);
      } else {
        errorMessage.value = res.message ?? 'Failed to inactivate plan';
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Inactivate plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
      update();
    }
  }
}
