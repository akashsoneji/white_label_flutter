import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:get/get.dart';

class CopyTradingMasterPlanDetail {
  final int id;
  final String planName;
  final String status;

  final String strategyDescription;
  final String riskInformation;
  final String lpProviderName;
  final String tradingAccountNumber;
  final String serverType;

  final num subscriptionFee;
  final int subscriptionPeriodDays;
  final String settlementCycle;
  final String lastSettledAt;
  final int noFeeDays;
  final num minimumCapital;
  final num copyRatio;
  final int maxCopiers;
  final bool isFull;
  final num roiPct;

  final int activeCopiers;
  final int copiersTotal;
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
  final String initialEquityCapturedAt;
  final String approvedAt;
  final String approvedBy;
  final String rejectionReason;
  final String createdAt;
  final String updatedAt;
  final String tradingServer;

  final List<CopyTradingMasterTradeHistoryItem> tradeHistory;
  final List<CopyTradingMasterCommissionHistoryItem> commissionHistory;
  final List<PlanCopierItem> copiers;
  final List<PlanOpenPositionItem> openPositionsDetail;
  final CopyTradingPlanCommissionSummary commissionSummary;
  final CopyTradingPlanSettlement settlement;
  final CopyTradingPlanPerformance performance;
  final List<CopyTradingPlanEquityCurvePoint> equityCurve;
  final List<CopyTradingPlanActivityFeedItem> activityFeed;
  final List<CopyTradingPlanTimelineItem> timeline;

  const CopyTradingMasterPlanDetail({
    required this.id,
    required this.planName,
    required this.status,
    required this.strategyDescription,
    required this.riskInformation,
    required this.lpProviderName,
    required this.tradingAccountNumber,
    required this.serverType,
    required this.subscriptionFee,
    required this.subscriptionPeriodDays,
    required this.settlementCycle,
    required this.lastSettledAt,
    required this.noFeeDays,
    required this.minimumCapital,
    required this.copyRatio,
    required this.maxCopiers,
    required this.activeCopiers,
    required this.copiersTotal,
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
    required this.copiers,
    required this.openPositionsDetail,
    required this.commissionSummary,
    required this.settlement,
    required this.performance,
    required this.equityCurve,
    required this.activityFeed,
    required this.timeline,
    required this.initialEquitySnapshot,
    required this.initialEquityCapturedAt,
    required this.approvedAt,
    required this.approvedBy,
    required this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    required this.isFull,
    required this.tradingServer,
    required this.roiPct,
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
      serverType: (json['server_type'] ?? '').toString(),
      subscriptionFee: toNum(json['subscription_fee']),
      subscriptionPeriodDays: toInt(json['subscription_period_days']),
      settlementCycle: (json['settlement_cycle'] ?? '').toString(),
      lastSettledAt: (json['last_settled_at'] ?? '').toString(),
      noFeeDays: toInt(json['no_fee_days']),
      minimumCapital: toNum(json['minimum_capital']),
      copyRatio: toNum(json['copy_ratio']),
      maxCopiers: toInt(json['max_copiers']),
      activeCopiers: toInt(json['active_copiers']),
      copiersTotal: toInt(json['copiers_total']),
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
      copiers: toMapList(json['copiers']).map(PlanCopierItem.fromJson).toList(),
      openPositionsDetail: toMapList(json['open_positions_detail']).map(PlanOpenPositionItem.fromJson).toList(),
      commissionSummary: json['commission_summary'] is Map
          ? CopyTradingPlanCommissionSummary.fromJson(
              (json['commission_summary'] as Map).cast<String, dynamic>())
          : const CopyTradingPlanCommissionSummary.empty(),
      settlement: json['settlement'] is Map
          ? CopyTradingPlanSettlement.fromJson(
              (json['settlement'] as Map).cast<String, dynamic>())
          : const CopyTradingPlanSettlement.empty(),
      performance: json['performance'] is Map
          ? CopyTradingPlanPerformance.fromJson(
              (json['performance'] as Map).cast<String, dynamic>())
          : const CopyTradingPlanPerformance.empty(),
      equityCurve: toMapList(json['equity_curve']).map(CopyTradingPlanEquityCurvePoint.fromJson).toList(),
      activityFeed: toMapList(json['activity_feed']).map(CopyTradingPlanActivityFeedItem.fromJson).toList(),
      timeline: toMapList(json['timeline']).map(CopyTradingPlanTimelineItem.fromJson).toList(),
      initialEquitySnapshot: (json['initial_equity_snapshot'] ?? '').toString(),
      initialEquityCapturedAt: (json['initial_equity_captured_at'] ?? '').toString(),
      approvedAt: (json['approved_at'] ?? '').toString(),
      approvedBy: (json['approved_by'] ?? '').toString(),
      rejectionReason: (json['rejection_reason'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      isFull: json['is_full'] == true,
      tradingServer: (json['trading_server'] ?? '').toString(),
      roiPct: toNum(json['roi_pct']),
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
  final num commissionCharged;
  final num masterCommissionCredited;
  final num commissionAccruedDisplay;
  final String distributionStatus;

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
    required this.commissionCharged,
    required this.masterCommissionCredited,
    required this.commissionAccruedDisplay,
    required this.distributionStatus,
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
      commissionCharged: toNum(json['commission_charged']),
      masterCommissionCredited: toNum(json['master_commission_credited']),
      commissionAccruedDisplay: toNum(json['commission_accrued_display']),
      distributionStatus: (json['distribution_status'] ?? '').toString(),
    );
  }
}

class CopyTradingMasterCommissionHistoryItem {
  final int id;
  final int tradeMappingId;
  final String settledAt;
  final String symbol;
  final String direction;
  final String openTime;
  final String closeTime;
  final String copierAccount;
  final String copierName;
  final num grossProfitShare;
  final num commissionCharged;
  final num commissionAccruedDisplay;
  final num masterCommissionCredited;
  final num commissionPreview;
  final bool inGracePeriod;
  final String status;

  const CopyTradingMasterCommissionHistoryItem({
    required this.id,
    required this.tradeMappingId,
    required this.settledAt,
    required this.symbol,
    required this.direction,
    required this.openTime,
    required this.closeTime,
    required this.copierAccount,
    required this.copierName,
    required this.grossProfitShare,
    required this.commissionCharged,
    required this.commissionAccruedDisplay,
    required this.masterCommissionCredited,
    required this.commissionPreview,
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
      tradeMappingId: toInt(json['trade_mapping_id']),
      settledAt: (json['settled_at'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      openTime: (json['open_time'] ?? '').toString(),
      closeTime: (json['close_time'] ?? '').toString(),
      copierAccount: (json['copier_account'] ?? '').toString(),
      copierName: (json['copier_name'] ?? '').toString(),
      grossProfitShare: toNum(json['gross_profit_share']),
      commissionCharged: toNum(json['commission_charged']),
      commissionAccruedDisplay: toNum(json['commission_accrued_display']),
      masterCommissionCredited: toNum(json['master_commission_credited']),
      commissionPreview: toNum(json['commission_preview']),
      inGracePeriod: toBool(json['in_grace_period']),
      status: (json['status'] ?? '').toString(),
    );
  }
}

/// Copier item as returned inside the plan detail API (different shape
/// from the dedicated `/master/copiers` endpoint).
class PlanCopierItem {
  final int id;
  final String userName;
  final String userEmail;
  final String accountNumber;
  final num capitalAmount;
  final num copyRatio;
  final num totalPnl;
  final num totalCommissionPaid;
  final num pendingCommission;
  final int openTradesCount;
  final String status;
  final String activeSince;
  final String joinedAt;

  const PlanCopierItem({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.accountNumber,
    required this.capitalAmount,
    required this.copyRatio,
    required this.totalPnl,
    required this.totalCommissionPaid,
    required this.pendingCommission,
    required this.openTradesCount,
    required this.status,
    required this.activeSince,
    required this.joinedAt,
  });

  factory PlanCopierItem.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return PlanCopierItem(
      id: toInt(json['id']),
      userName: (json['user_name'] ?? '').toString(),
      userEmail: (json['user_email'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? '').toString(),
      capitalAmount: toNum(json['capital_amount']),
      copyRatio: toNum(json['copy_ratio']),
      totalPnl: toNum(json['total_pnl']),
      totalCommissionPaid: toNum(json['total_commission_paid']),
      pendingCommission: toNum(json['pending_commission']),
      openTradesCount: toInt(json['open_trades_count']),
      status: (json['status'] ?? '').toString(),
      activeSince: (json['active_since'] ?? '').toString(),
      joinedAt: (json['joined_at'] ?? '').toString(),
    );
  }
}

/// Lightweight open-position row returned inside plan detail.
class PlanOpenPositionItem {
  final int id;
  final String symbol;
  final String direction;
  final num masterVolume;
  final num copierVolume;
  final num openPrice;
  final num currentPrice;
  final num profit;
  final String openTime;
  final String copierAccount;
  final String copierName;

  const PlanOpenPositionItem({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.masterVolume,
    required this.copierVolume,
    required this.openPrice,
    required this.currentPrice,
    required this.profit,
    required this.openTime,
    required this.copierAccount,
    required this.copierName,
  });

  factory PlanOpenPositionItem.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return PlanOpenPositionItem(
      id: toInt(json['id']),
      symbol: (json['symbol'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      masterVolume: toNum(json['master_volume']),
      copierVolume: toNum(json['copier_volume']),
      openPrice: toNum(json['open_price']),
      currentPrice: toNum(json['current_price']),
      profit: toNum(json['profit']),
      openTime: (json['open_time'] ?? '').toString(),
      copierAccount: (json['copier_account'] ?? '').toString(),
      copierName: (json['copier_name'] ?? '').toString(),
    );
  }
}

class CopyTradingPlanCommissionSummary {
  final num lifetime;
  final num thisMonth;
  final num pending;
  final String pendingSource;
  final num settled;
  final String currency;

  const CopyTradingPlanCommissionSummary({
    required this.lifetime,
    required this.thisMonth,
    required this.pending,
    required this.pendingSource,
    required this.settled,
    required this.currency,
  });

  const CopyTradingPlanCommissionSummary.empty()
      : lifetime = 0,
        thisMonth = 0,
        pending = 0,
        pendingSource = '',
        settled = 0,
        currency = 'USD';

  factory CopyTradingPlanCommissionSummary.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return CopyTradingPlanCommissionSummary(
      lifetime: toNum(json['lifetime']),
      thisMonth: toNum(json['this_month']),
      pending: toNum(json['pending']),
      pendingSource: (json['pending_source'] ?? '').toString(),
      settled: toNum(json['settled']),
      currency: (json['currency'] ?? 'USD').toString(),
    );
  }
}

class CopyTradingPlanSettlement {
  final String cycle;
  final String lastSettledAt;
  final String nextPayoutAt;
  final bool isDue;

  const CopyTradingPlanSettlement({
    required this.cycle,
    required this.lastSettledAt,
    required this.nextPayoutAt,
    required this.isDue,
  });

  const CopyTradingPlanSettlement.empty()
      : cycle = '',
        lastSettledAt = '',
        nextPayoutAt = '',
        isDue = false;

  factory CopyTradingPlanSettlement.fromJson(Map<String, dynamic> json) {
    bool toBool(dynamic v) {
      if (v is bool) return v;
      final s = (v ?? '').toString().toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes';
    }

    return CopyTradingPlanSettlement(
      cycle: (json['cycle'] ?? '').toString(),
      lastSettledAt: (json['last_settled_at'] ?? '').toString(),
      nextPayoutAt: (json['next_payout_at'] ?? '').toString(),
      isDue: toBool(json['is_due']),
    );
  }
}

class CopyTradingPlanPerformance {
  final int closedTrades;
  final int wins;
  final int losses;
  final int breakeven;
  final num winRate;
  final num avgWin;
  final num avgLoss;
  final num profitFactor;
  final num expectancy;
  final num netPnl;
  final num maxDrawdown;
  final num grossProfit;
  final num grossLoss;

  const CopyTradingPlanPerformance({
    required this.closedTrades,
    required this.wins,
    required this.losses,
    required this.breakeven,
    required this.winRate,
    required this.avgWin,
    required this.avgLoss,
    required this.profitFactor,
    required this.expectancy,
    required this.netPnl,
    required this.maxDrawdown,
    required this.grossProfit,
    required this.grossLoss,
  });

  const CopyTradingPlanPerformance.empty()
      : closedTrades = 0,
        wins = 0,
        losses = 0,
        breakeven = 0,
        winRate = 0,
        avgWin = 0,
        avgLoss = 0,
        profitFactor = 0,
        expectancy = 0,
        netPnl = 0,
        maxDrawdown = 0,
        grossProfit = 0,
        grossLoss = 0;

  factory CopyTradingPlanPerformance.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return CopyTradingPlanPerformance(
      closedTrades: toInt(json['closed_trades']),
      wins: toInt(json['wins']),
      losses: toInt(json['losses']),
      breakeven: toInt(json['breakeven']),
      winRate: toNum(json['win_rate']),
      avgWin: toNum(json['avg_win']),
      avgLoss: toNum(json['avg_loss']),
      profitFactor: toNum(json['profit_factor']),
      expectancy: toNum(json['expectancy']),
      netPnl: toNum(json['net_pnl']),
      maxDrawdown: toNum(json['max_drawdown']),
      grossProfit: toNum(json['gross_profit']),
      grossLoss: toNum(json['gross_loss']),
    );
  }
}

class CopyTradingPlanEquityCurvePoint {
  final String date;
  final num equity;

  const CopyTradingPlanEquityCurvePoint({
    required this.date,
    required this.equity,
  });

  factory CopyTradingPlanEquityCurvePoint.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return CopyTradingPlanEquityCurvePoint(
      date: (json['date'] ?? '').toString(),
      equity: toNum(json['equity']),
    );
  }
}

class CopyTradingPlanActivityFeedItem {
  final String type;
  final String at;
  final String title;
  final String subtitle;
  final Map<String, dynamic> meta;

  const CopyTradingPlanActivityFeedItem({
    required this.type,
    required this.at,
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  factory CopyTradingPlanActivityFeedItem.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['meta'];
    final metaMap = metaRaw is Map
        ? metaRaw.cast<String, dynamic>()
        : const <String, dynamic>{};
    return CopyTradingPlanActivityFeedItem(
      type: (json['type'] ?? '').toString(),
      at: (json['at'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      meta: metaMap,
    );
  }
}

class CopyTradingPlanTimelineItem {
  final String at;
  final String kind;
  final String label;
  final String detail;

  const CopyTradingPlanTimelineItem({
    required this.at,
    required this.kind,
    required this.label,
    required this.detail,
  });

  factory CopyTradingPlanTimelineItem.fromJson(Map<String, dynamic> json) {
    return CopyTradingPlanTimelineItem(
      at: (json['at'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
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
      errorMessage.value = res.message ??
          TranslationUtils.tr('copy_trading_failed_to_load_plan_detail');
        update();
        return;
      }

      final data = res.data?['data'];
      if (data is! Map) {
        detail.value = null;
      errorMessage.value = TranslationUtils.tr('copy_trading_invalid_response');
        update();
        return;
      }

      detail.value = CopyTradingMasterPlanDetail.fromJson(data.cast<String, dynamic>());
      update();
    } catch (e) {
      detail.value = null;
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_load_error')}: $e';
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
        errorMessage.value =
            res.message ??
            TranslationUtils.tr('copy_trading_failed_to_pause_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_pause_plan_error')}: $e';
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
        errorMessage.value =
            res.message ??
            TranslationUtils.tr('copy_trading_failed_to_resume_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_resume_plan_error')}: $e';
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
      final res = await ApiService.put(endpoint: endpoint, data: body);
      if (res.success) {
        await loadPlanDetail(showLoading: false);
      } else {
        errorMessage.value =
            res.message ??
            TranslationUtils.tr('copy_trading_failed_to_update_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_update_plan_error')}: $e';
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
        errorMessage.value =
            res.message ??
            TranslationUtils.tr('copy_trading_failed_to_inactivate_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_inactivate_plan_error')}: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
      update();
    }
  }
}
