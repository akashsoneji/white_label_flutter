import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/copy_trading_dashboard_overview.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class CopyTradingMasterDashboardStats {
  final int plansCount;
  final int activeCopiersCount;
  final num totalAum;
  final num commissionEarned;

  const CopyTradingMasterDashboardStats({
    required this.plansCount,
    required this.activeCopiersCount,
    required this.totalAum,
    required this.commissionEarned,
  });

  factory CopyTradingMasterDashboardStats.fromJson(Map<String, dynamic> json) {
    return CopyTradingMasterDashboardStats(
      plansCount: (json['plans_count'] ?? 0) is num ? (json['plans_count'] as num).toInt() : 0,
      activeCopiersCount:
          (json['active_copiers_count'] ?? 0) is num ? (json['active_copiers_count'] as num).toInt() : 0,
      totalAum: (json['total_aum'] ?? 0) as num? ?? 0,
      commissionEarned: (json['commission_earned'] ?? 0) as num? ?? 0,
    );
  }
}

class CopyTradingPerformanceWindow {
  final int closedTradesCount;
  final num profitFactor;
  final num avgTradeDurationSeconds;
  final num bestTradeProfit;
  final num worstTradeProfit;

  const CopyTradingPerformanceWindow({
    required this.closedTradesCount,
    required this.profitFactor,
    required this.avgTradeDurationSeconds,
    required this.bestTradeProfit,
    required this.worstTradeProfit,
  });

  factory CopyTradingPerformanceWindow.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return CopyTradingPerformanceWindow(
      closedTradesCount: (json['closed_trades_count'] ?? 0) is num
          ? (json['closed_trades_count'] as num).toInt()
          : int.tryParse(json['closed_trades_count']?.toString() ?? '') ?? 0,
      profitFactor: toNum(json['profit_factor']),
      avgTradeDurationSeconds: toNum(json['avg_trade_duration_seconds']),
      bestTradeProfit: toNum(json['best_trade_profit']),
      worstTradeProfit: toNum(json['worst_trade_profit']),
    );
  }
}

class CopyTradingMasterProfile {
  final String masterCode;
  final String masterNickname;
  final String masterName;
  final String serverType;
  final String lpProviderName;
  final String strategyDescription;
  final String riskInformation;
  final int riskScore;
  final String memberSince;
  final int withUsDays;
  final int totalPlans;
  final int totalCopiers;
  final num totalPnl;
  final num totalGain;
  final num totalGainPercent;
  final num winRate;
  final num maxDrawdown;
  final num masterEquity;
  final List<CopyTradingMasterPlanItem> plans;
  final List<dynamic> openPositions;
  final CopyTradingPerformanceWindow? performanceWindow;
  final String timeframe;
  final String profileScope;
  final String selectedPlanId;

  const CopyTradingMasterProfile({
    required this.masterCode,
    required this.masterNickname,
    required this.masterName,
    required this.serverType,
    required this.lpProviderName,
    required this.strategyDescription,
    required this.riskInformation,
    required this.riskScore,
    required this.memberSince,
    required this.withUsDays,
    required this.totalPlans,
    required this.totalCopiers,
    required this.totalPnl,
    required this.totalGain,
    required this.totalGainPercent,
    required this.winRate,
    required this.maxDrawdown,
    required this.masterEquity,
    required this.plans,
    required this.openPositions,
    this.performanceWindow,
    required this.timeframe,
    required this.profileScope,
    required this.selectedPlanId,
  });

  factory CopyTradingMasterProfile.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    var plansList = json['plans'] as List? ?? [];
    return CopyTradingMasterProfile(
      masterCode: (json['master_code'] ?? '').toString(),
      masterNickname: (json['master_nickname'] ?? '').toString(),
      masterName: (json['master_name'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      lpProviderName: (json['lp_provider_name'] ?? '').toString(),
      strategyDescription: (json['strategy_description'] ?? '').toString(),
      riskInformation: (json['risk_information'] ?? '').toString(),
      riskScore: (json['risk_score'] ?? 0) is num
          ? (json['risk_score'] as num).toInt()
          : int.tryParse(json['risk_score']?.toString() ?? '') ?? 0,
      memberSince: (json['member_since'] ?? '').toString(),
      withUsDays: (json['with_us_days'] ?? 0) is num
          ? (json['with_us_days'] as num).toInt()
          : int.tryParse(json['with_us_days']?.toString() ?? '') ?? 0,
      totalPlans: (json['total_plans'] ?? 0) is num
          ? (json['total_plans'] as num).toInt()
          : int.tryParse(json['total_plans']?.toString() ?? '') ?? 0,
      totalCopiers: (json['total_copiers'] ?? 0) is num
          ? (json['total_copiers'] as num).toInt()
          : int.tryParse(json['total_copiers']?.toString() ?? '') ?? 0,
      totalPnl: toNum(json['total_pnl']),
      totalGain: toNum(json['total_gain']),
      totalGainPercent: toNum(json['total_gain_percent']),
      winRate: toNum(json['win_rate']),
      maxDrawdown: toNum(json['max_drawdown']),
      masterEquity: toNum(json['master_equity']),
      plans: plansList.whereType<Map>().map((p) => CopyTradingMasterPlanItem.fromJson(p.cast<String, dynamic>())).toList(),
      openPositions: json['open_positions'] as List? ?? [],
      performanceWindow: json['performance_window'] != null
          ? CopyTradingPerformanceWindow.fromJson(json['performance_window'].cast<String, dynamic>())
          : null,
      timeframe: (json['timeframe'] ?? '').toString(),
      profileScope: (json['profile_scope'] ?? '').toString(),
      selectedPlanId: (json['selected_plan_id'] ?? '').toString(),
    );
  }
}


class CopyTradingEligibleAccount {
  final int id;
  final String metaAccountNumber;
  final String accountType;
  final num balance;
  final num equity;
  final String tradingServer;
  final String lpProviderName;
  final String serverType;
  final bool isEnrolled;

  const CopyTradingEligibleAccount({
    required this.id,
    required this.metaAccountNumber,
    required this.accountType,
    required this.balance,
    required this.equity,
    required this.tradingServer,
    required this.lpProviderName,
    required this.serverType,
    required this.isEnrolled,
  });

  factory CopyTradingEligibleAccount.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return CopyTradingEligibleAccount(
      id: (json['id'] ?? 0) is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      metaAccountNumber: (json['meta_account_number'] ?? '').toString(),
      accountType: (json['account_type'] ?? '').toString(),
      balance: toNum(json['balance']),
      equity: toNum(json['equity']),
      tradingServer: (json['trading_server'] ?? '').toString(),
      lpProviderName: (json['lp_provider_name'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      isEnrolled: json['is_enrolled'] == true,
    );
  }

  String get maskedAccount => metaAccountNumber;
}

class CopyTradingMasterPlanItem {
  final int id;
  final String planName;
  final String tradingAccountNumber;
  final String tradingServer;
  final String lpProviderName;
  final String serverType;
  final String commissionType;
  final String commissionLabel;
  final num commissionPercentage;
  final num subscriptionFee;
  final int subscriptionPeriodDays;
  final String settlementCycle;
  final String lastSettledAt;
  final num minimumCapital;
  final num copyRatio;
  final int? maxCopiers;
  final int activeCopiersCount;
  final num totalCapital;
  final num roiPct;
  final bool isFull;
  final String status;
  final bool copyingPaused;
  final String copyingPausedAt;
  final String strategyDescription;
  final String riskInformation;
  final int noFeeDays;
  final String createdAt;

  const CopyTradingMasterPlanItem({
    required this.id,
    required this.planName,
    required this.tradingAccountNumber,
    required this.tradingServer,
    required this.lpProviderName,
    required this.serverType,
    required this.commissionType,
    required this.commissionLabel,
    required this.commissionPercentage,
    required this.subscriptionFee,
    required this.subscriptionPeriodDays,
    required this.settlementCycle,
    required this.lastSettledAt,
    required this.minimumCapital,
    required this.copyRatio,
    required this.maxCopiers,
    required this.activeCopiersCount,
    required this.totalCapital,
    required this.roiPct,
    required this.isFull,
    required this.status,
    required this.copyingPaused,
    required this.copyingPausedAt,
    required this.strategyDescription,
    required this.riskInformation,
    required this.noFeeDays,
    required this.createdAt,
  });

  factory CopyTradingMasterPlanItem.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return CopyTradingMasterPlanItem(
      id: toInt(json['id']),
      planName: (json['plan_name'] ?? json['name'] ?? '').toString(),
      tradingAccountNumber: (json['trading_account_number'] ?? '').toString(),
      tradingServer: (json['trading_server'] ?? '').toString(),
      lpProviderName: (json['lp_provider_name'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionLabel: (json['commission_label'] ?? '').toString(),
      commissionPercentage: toNum(json['commission_percentage']),
      subscriptionFee: toNum(json['subscription_fee']),
      subscriptionPeriodDays: toInt(json['subscription_period_days']),
      settlementCycle: (json['settlement_cycle'] ?? '').toString(),
      lastSettledAt: (json['last_settled_at'] ?? '').toString(),
      minimumCapital: toNum(json['minimum_capital']),
      copyRatio: toNum(json['copy_ratio'] ?? 1),
      maxCopiers: json['max_copiers'] is num
          ? (json['max_copiers'] as num).toInt()
          : int.tryParse((json['max_copiers'] ?? '').toString()),
      activeCopiersCount: toInt(json['active_copiers_count']),
      totalCapital: toNum(json['total_capital'] ?? json['total_aum']),
      roiPct: toNum(json['roi_pct']),
      isFull: json['is_full'] == true,
      status: (json['status'] ?? '').toString(),
      copyingPaused: json['copying_paused'] == true,
      copyingPausedAt: (json['copying_paused_at'] ?? '').toString(),
      strategyDescription: (json['strategy_description'] ?? '').toString(),
      riskInformation: (json['risk_information'] ?? '').toString(),
      noFeeDays: toInt(json['no_fee_days']),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class CopyTradingOpenPositionItem {
  final int id;
  final String symbol;
  final String tradeType;
  final num masterVolume;
  final num copierVolume;
  final num openPrice;
  final String openTime;
  final String copierName;
  final String copierAccount;
  final String status;
  final int planId;
  final String planName;
  final num profit;

  const CopyTradingOpenPositionItem({
    required this.id,
    required this.symbol,
    required this.tradeType,
    required this.masterVolume,
    required this.copierVolume,
    required this.openPrice,
    required this.openTime,
    required this.copierName,
    required this.copierAccount,
    required this.status,
    required this.planId,
    required this.planName,
    required this.profit,
  });

  factory CopyTradingOpenPositionItem.fromJson(
    Map<String, dynamic> json, {
    required int planId,
    required String planName,
  }) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0.0;
    return CopyTradingOpenPositionItem(
      id: (json['id'] ?? 0) is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      symbol: (json['symbol'] ?? '').toString(),
      tradeType: (json['trade_type'] ?? '').toString(),
      masterVolume: toNum(json['master_volume'] ?? json['volume'] ?? 0.0),
      copierVolume: toNum(json['copier_volume'] ?? 0.0),
      openPrice: toNum(json['open_price'] ?? 0.0),
      openTime: (json['open_time'] ?? '').toString(),
      copierName: (json['copier_name'] ?? '').toString(),
      copierAccount: (json['copier_account'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      planId: planId,
      planName: planName,
      profit: toNum(json['profit'] ?? json['pnl'] ?? json['floating_pnl'] ?? json['pl'] ?? 0.0),
    );
  }
}

class CopyTradingMasterDashboardController extends GetxController {
  final String masterCode;
  CopyTradingMasterDashboardController({required this.masterCode});

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final Rxn<CopyTradingMasterDashboardStats> stats = Rxn<CopyTradingMasterDashboardStats>();
  final Rxn<CopyTradingMasterProfile> profile = Rxn<CopyTradingMasterProfile>();
  final RxList<CopyTradingMasterPlanItem> plans = <CopyTradingMasterPlanItem>[].obs;

  final RxList<MT5Account> mt5Accounts = <MT5Account>[].obs;

  final RxList<CopyTradingOpenPositionItem> openPositions = <CopyTradingOpenPositionItem>[].obs;
  final RxBool isOpenPositionsLoading = false.obs;

  // Create-plan account picker should use eligible accounts API (reference: COPYTRADING_API.md)
  final RxBool eligibleAccountsLoading = false.obs;
  final RxString eligibleAccountsError = ''.obs;
  final RxList<CopyTradingEligibleAccount> eligibleAccounts =
      <CopyTradingEligibleAccount>[].obs;

  /// Currently selected overview time-range preset (e.g. '1m', '3m', '6m', 'all').
  final RxString overviewRange = RxString('1m');

  /// True while [loadDashboardOverview] is in-flight. Lets the overview tab
  /// show its own spinner without interfering with the rest of the dashboard.
  final RxBool isOverviewLoading = false.obs;

  /// Default-empty overview so legacy getters on existing screens keep working.
  /// Set to a real [CopyTradingDashboardOverview] once the backend ships the
  /// overview endpoint.
  final Rxn<CopyTradingDashboardOverview> overview =
      Rxn<CopyTradingDashboardOverview>();

  /// Derived metrics used by the redesigned dashboard cards.
  CopyTradingDerivedDashboardMetrics get derivedMetrics {
    final s = stats.value;
    final planList = plans.toList();

    int approved = 0, pending = 0, paused = 0, inactive = 0, activeCopiers = 0;
    num totalAum = 0;
    num roiSum = 0;
    int roiCount = 0;
    num commissionPctSum = 0;
    num subscriptionFeeSum = 0;

    for (final plan in planList) {
      final status = plan.status.toLowerCase();
      if (status == 'approved') {
        approved++;
      } else if (status == 'pending' ||
          status == 'pending_admin' ||
          status == 'pending_admin_approval' ||
          status == 'awaiting_approval') {
        pending++;
      } else if (status == 'rejected' ||
          status == 'inactive' ||
          status == 'inactivated' ||
          status == 'cancelled') {
        inactive++;
      }

      if (plan.copyingPaused) paused++;

      activeCopiers += plan.activeCopiersCount;
      totalAum += plan.totalCapital;
      if (plan.roiPct != 0) {
        roiSum += plan.roiPct;
        roiCount++;
      }
      commissionPctSum += plan.commissionPercentage;
      subscriptionFeeSum += plan.subscriptionFee;
    }

    return CopyTradingDerivedDashboardMetrics(
      plansCount: planList.length,
      approvedPlansCount: approved,
      pendingPlansCount: pending,
      pausedPlansCount: paused,
      inactivePlansCount: inactive,
      activeCopiersCount: s?.activeCopiersCount ?? activeCopiers,
      totalAum: s?.totalAum ?? totalAum,
      averageRoiPct: roiCount > 0 ? roiSum / roiCount : 0,
      commissionEarnedTotal: s?.commissionEarned ?? 0,
      totalCommissionAcrossPlans: commissionPctSum,
      totalSubscriptionFee: subscriptionFeeSum,
    );
  }

  /// Map a chip label (Today / 7D / 30D / 90D / 1Y / All) to the API range
  /// preset the overview endpoint expects.
  static String chipToRangePreset(String chip) {
    switch (chip) {
      case 'Today':
        return 'today';
      case '7D':
        return '7d';
      case '30D':
        return '30d';
      case '90D':
        return '90d';
      case '1Y':
        return '1y';
      case 'All':
      default:
        return 'all';
    }
  }

  /// Apply a new overview time-range preset and reload relevant data.
  ///
  /// Accepts either a chip label (`Today`, `7D`, `30D`, `90D`, `1Y`, `All`)
  /// or a backend preset string (`today`, `7d`, `30d`, `90d`, `1y`, `all`,
  /// `1m`, `3m`, `6m`).
  Future<void> changeRange(String presetOrChip) async {
    final p = presetOrChip.trim();
    String normalised = p.toLowerCase();
    // If it looks like a chip label (mixed case + trailing letter), map it.
    if (p == 'Today' || p == '7D' || p == '30D' || p == '90D' || p == '1Y' || p == 'All') {
      normalised = chipToRangePreset(p);
    }
    debugPrint('[MasterDashboard] changeRange chip="$presetOrChip" '
        '→ preset="$normalised" (was: "${overviewRange.value}")');
    overviewRange.value = normalised;
    await loadDashboardOverview();
  }

  @override
  void onInit() {
    super.onInit();
    refreshAll(showLoading: true);
  }

  /// Reload every panel of the master dashboard: stats, profile, plans,
  /// MT5 accounts, open positions, AND the redesigned overview block.
  Future<void> refreshAll({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      await Future.wait([
        _loadStats(),
        _loadProfile(),
        _loadPlans(),
        _loadMt5Accounts(),
        loadDashboardOverview(),
      ]);
      await _loadOpenPositions();
    } catch (e) {
      errorMessage.value = 'Failed to load dashboard: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  /// Fetch the redesigned `master/dashboard-overview` panel
  /// (range, hero, main_chart, copier_health, plans, payouts,
  /// recent_trades, alerts). Populates [overview]; non-fatal on failure.
  Future<void> loadDashboardOverview() async {
    isOverviewLoading.value = true;
    // IMPORTANT: do NOT embed `?range=` in the endpoint path.
    // `ApiService.get` uses `Uri.replace(queryParameters: ...)`, which
    // *wipes* any query string already in the endpoint string. So we
    // pass both the range and the cache-buster in queryParameters here.
    // (Bug: previously the endpoint was `...dashboard-overview?range=7d`
    // and `queryParameters: {_t: ...}` overwrote it → API always
    // received only `_t`, returned the default 30d window, so every
    // chip felt like it returned the same data.)
    final range = overviewRange.value;
    final endpoint = ApiConstants.copyTradingMasterDashboardOverviewPath;
    final queryParameters = {
      'range': range,
      '_t': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    debugPrint(
      '[MasterDashboard] loadDashboardOverview → range="$range" '
      'endpoint="$endpoint" query=$queryParameters',
    );
    try {
      final res = await ApiService.get(
        endpoint: endpoint,
        queryParameters: queryParameters,
      );
      debugPrint(
        '[MasterDashboard] loadDashboardOverview ← success=${res.success} '
        'hasData=${res.data != null}',
      );
      debugPrint(
        '[MasterDashboard] loadDashboardOverview ← success=${res.success} '
        'hasData=${res.data != null}',
      );
      if (!res.success || res.data == null) {
        // Non-fatal — many screens fall back to derived metrics.
        return;
      }
      final body = res.data?['data'];
      if (body is Map) {
        overview.value = CopyTradingDashboardOverview.fromJson(
          body.cast<String, dynamic>(),
        );
      }
    } catch (e) {
      debugPrint('loadDashboardOverview error: $e');
    } finally {
      isOverviewLoading.value = false;
    }
  }

  Future<void> _loadOpenPositions() async {
    isOpenPositionsLoading.value = true;
    try {
      if (plans.isEmpty) {
        openPositions.clear();
        return;
      }

      final List<CopyTradingOpenPositionItem> allPositions = [];
      final List<Future<void>> futures = [];

      for (final plan in plans) {
        final status = plan.status.toLowerCase();
        if (status != 'approved' && status != 'active') continue;

        futures.add(() async {
          try {
            final res = await ApiService.get(
              endpoint: ApiConstants.copyTradingMasterOpenPositions(plan.id),
              queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
            );
            if (res.success && res.data != null) {
              final data = res.data?['data'];
              if (data is List) {
                final items = data.whereType<Map>().map((e) {
                  return CopyTradingOpenPositionItem.fromJson(
                    e.cast<String, dynamic>(),
                    planId: plan.id,
                    planName: plan.planName,
                  );
                }).toList();
                allPositions.addAll(items);
              }
            }
          } catch (e) {
            debugPrint('Error loading open positions for plan ${plan.id}: $e');
          }
        }());
      }

      await Future.wait(futures);
      allPositions.sort((a, b) => b.openTime.compareTo(a.openTime));
      openPositions.assignAll(allPositions);
    } catch (e) {
      debugPrint('Error loading open positions: $e');
    } finally {
      isOpenPositionsLoading.value = false;
    }
  }

  Future<void> _loadStats() async {
    final res = await ApiService.get(endpoint: ApiConstants.copyTradingMasterDashboardStats);
    if (!res.success || res.data == null) {
      stats.value = null;
      return;
    }
    final data = res.data?['data'];
    if (data is Map) {
      stats.value = CopyTradingMasterDashboardStats.fromJson(data.cast<String, dynamic>());
    }
  }

  Future<void> _loadProfile() async {
    final res = await ApiService.get(
      endpoint: ApiConstants.copyTradingMasterProfile(masterCode, timeframe: overviewRange.value),
      queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
    );
    if (!res.success || res.data == null) {
      profile.value = null;
      return;
    }
    final data = res.data?['data'];
    if (data is Map) {
      profile.value = CopyTradingMasterProfile.fromJson(data.cast<String, dynamic>());
    } else {
      profile.value = null;
    }
  }

  Future<void> _loadPlans() async {
    final res = await ApiService.get(
      endpoint: ApiConstants.copyTradingMasterPlans,
      queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
    );
    if (!res.success || res.data == null) {
      plans.clear();
      return;
    }
    final data = res.data?['data'];
    if (data is List) {
      plans.assignAll(
        data.whereType<Map>().map((e) => CopyTradingMasterPlanItem.fromJson(e.cast<String, dynamic>())),
      );
    } else {
      plans.clear();
    }
  }

  Future<void> _loadMt5Accounts() async {
    final res = await ApiService.get(endpoint: ApiConstants.getMT5Accounts);
    if (!res.success || res.data == null) {
      mt5Accounts.clear();
      return;
    }
    final data = res.data?['data'];
    if (data is List) {
      mt5Accounts.assignAll(data.whereType<Map>().map((e) => MT5Account.fromJson(e.cast<String, dynamic>())).toList());
    } else {
      mt5Accounts.clear();
    }
  }

  Future<void> loadEligibleAccountsForCreatePlan() async {
    eligibleAccountsLoading.value = true;
    eligibleAccountsError.value = '';
    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierEligibleAccounts,
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      if (!res.success || res.data == null) {
        eligibleAccounts.clear();
        eligibleAccountsError.value = res.message ??
            TranslationUtils.tr('copy_trading_failed_to_load_eligible_accounts');
        return;
      }
      final data = res.data?['data'];
      if (data is List) {
        eligibleAccounts.assignAll(
          data.whereType<Map>().map((e) => CopyTradingEligibleAccount.fromJson(e.cast<String, dynamic>())),
        );
      } else {
        eligibleAccounts.clear();
      }
    } catch (e) {
      eligibleAccountsError.value = 'Failed to load eligible accounts: $e';
      eligibleAccounts.clear();
    } finally {
      eligibleAccountsLoading.value = false;
    }
  }

  Future<ApiResponse> createPlan(Map<String, dynamic> body) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await ApiService.post(endpoint: ApiConstants.copyTradingMasterPlans, data: body);
      if (res.success) {
        await _loadPlans();
        await _loadStats();
      } else {
        errorMessage.value =
            res.message ?? TranslationUtils.tr('copy_trading_failed_to_create_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Create plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Inactivate a master plan (only allowed when plan is `approved` and `active_copiers_count = 0`)
  Future<ApiResponse> inactivatePlan({required int planId}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId/inactivate';
      final res = await ApiService.post(endpoint: endpoint, data: <String, dynamic>{});
      if (res.success) {
        await _loadPlans();
        await _loadStats();
      } else {
        errorMessage.value = res.message ??
            TranslationUtils.tr('copy_trading_failed_to_inactivate_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Inactivate plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Pause a master plan copying
  Future<ApiResponse> pausePlan({required int planId}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId/pause';
      final res = await ApiService.post(endpoint: endpoint, data: <String, dynamic>{});
      if (res.success) {
        await _loadPlans();
        await _loadStats();
      } else {
        errorMessage.value =
            res.message ?? TranslationUtils.tr('copy_trading_failed_to_pause_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Pause plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Resume a master plan copying
  Future<ApiResponse> resumePlan({required int planId}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId/resume';
      final res = await ApiService.post(endpoint: endpoint, data: <String, dynamic>{});
      if (res.success) {
        await _loadPlans();
        await _loadStats();
      } else {
        errorMessage.value =
            res.message ?? TranslationUtils.tr('copy_trading_failed_to_resume_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Resume plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Update a master plan (name, strategy, risk)
  Future<ApiResponse> updatePlan({required int planId, required Map<String, dynamic> body}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId';
      final res = await ApiService.post(endpoint: endpoint, data: body);
      if (res.success) {
        await _loadPlans();
        await _loadStats();
      } else {
        errorMessage.value =
            res.message ?? TranslationUtils.tr('copy_trading_failed_to_update_plan');
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Update plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }
}

/// Compact dashboard metrics card derived from `plans` + `profile`.
class CopyTradingDerivedDashboardMetrics {
  final int plansCount;
  final int approvedPlansCount;
  final int pendingPlansCount;
  final int pausedPlansCount;
  final int inactivePlansCount;
  final int activeCopiersCount;
  final num totalAum;
  final num averageRoiPct;
  final num commissionEarnedTotal;
  final num totalCommissionAcrossPlans;
  final num totalSubscriptionFee;

  const CopyTradingDerivedDashboardMetrics({
    required this.plansCount,
    required this.approvedPlansCount,
    required this.pendingPlansCount,
    required this.pausedPlansCount,
    required this.inactivePlansCount,
    required this.activeCopiersCount,
    required this.totalAum,
    required this.averageRoiPct,
    required this.commissionEarnedTotal,
    required this.totalCommissionAcrossPlans,
    required this.totalSubscriptionFee,
  });

  factory CopyTradingDerivedDashboardMetrics.empty() => const CopyTradingDerivedDashboardMetrics(
        plansCount: 0,
        approvedPlansCount: 0,
        pendingPlansCount: 0,
        pausedPlansCount: 0,
        inactivePlansCount: 0,
        activeCopiersCount: 0,
        totalAum: 0,
        averageRoiPct: 0,
        commissionEarnedTotal: 0,
        totalCommissionAcrossPlans: 0,
        totalSubscriptionFee: 0,
      );
}
