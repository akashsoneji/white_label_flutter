import 'package:get/get.dart';

import 'package:crm_app/screens/copy_trading/data/repositories/copy_trading_repository.dart';

class CopyTradingTradeItem {
  final int id;
  final String symbol;
  final String side; // BUY/SELL
  final num volume;
  final num openPrice;
  final num closePrice;
  final String openTime;
  final String closeTime;
  final num profit;

  const CopyTradingTradeItem({
    required this.id,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.openPrice,
    required this.closePrice,
    required this.openTime,
    required this.closeTime,
    required this.profit,
  });

  factory CopyTradingTradeItem.fromJson(Map<String, dynamic> json) {
    return CopyTradingTradeItem(
      id: (json['id'] ?? 0) is num ? (json['id'] as num).toInt() : 0,
      symbol: (json['symbol'] ?? '').toString(),
      side: (json['side'] ?? json['direction'] ?? '').toString(),
      volume: (json['volume'] ?? 0) as num? ?? 0,
      openPrice: (json['open_price'] ?? 0) as num? ?? 0,
      closePrice: (json['close_price'] ?? 0) as num? ?? 0,
      openTime: (json['open_time'] ?? '').toString(),
      closeTime: (json['close_time'] ?? '').toString(),
      profit: (json['profit'] ?? 0) as num? ?? 0,
    );
  }
}

class CopyTradingPlan {
  final int id;
  final int planId;
  final String planName;
  final String commissionType;
  final String commissionLabel;
  final num commissionPercentage;
  final num subscriptionFee;
  final num minimumCapital;
  final num copyRatio;
  final bool isFull;
  final int noFeeDays;
  final int subscriptionPeriodDays;
  final int activeCopiersCount;
  final num totalAum;
  final bool isEnrolled;

  const CopyTradingPlan({
    required this.id,
    required this.planId,
    required this.planName,
    required this.commissionType,
    required this.commissionLabel,
    required this.commissionPercentage,
    required this.subscriptionFee,
    required this.minimumCapital,
    required this.copyRatio,
    required this.isFull,
    required this.noFeeDays,
    required this.subscriptionPeriodDays,
    required this.activeCopiersCount,
    required this.totalAum,
    required this.isEnrolled,
  });

  factory CopyTradingPlan.fromJson(Map<String, dynamic> json) {
    return CopyTradingPlan(
      id: (json['id'] ?? 0) is num ? (json['id'] as num).toInt() : 0,
      planId: (json['plan_id'] ?? 0) is num ? (json['plan_id'] as num).toInt() : 0,
      planName: (json['plan_name'] ?? '').toString(),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionLabel: (json['commission_label'] ?? '').toString(),
      commissionPercentage: (json['commission_percentage'] ?? 0) as num? ?? 0,
      subscriptionFee: (json['subscription_fee'] ?? 0) as num? ?? 0,
      minimumCapital: (json['minimum_capital'] ?? 0) as num? ?? 0,
      copyRatio: (json['copy_ratio'] ?? 1) as num? ?? 1,
      isFull: json['is_full'] == true,
      noFeeDays: (json['no_fee_days'] ?? 0) is num ? (json['no_fee_days'] as num).toInt() : 0,
      subscriptionPeriodDays:
          (json['subscription_period_days'] ?? 0) is num ? (json['subscription_period_days'] as num).toInt() : 0,
      activeCopiersCount:
          (json['active_copiers_count'] ?? 0) is num ? (json['active_copiers_count'] as num).toInt() : 0,
      totalAum: (json['total_aum'] ?? 0) as num? ?? 0,
      isEnrolled: json['is_enrolled'] == true,
    );
  }
}

class CopyTradingMasterProfile {
  final String masterCode;
  final String nickname;
  final String name;
  final String serverType;
  final String lpProviderName;
  final String memberSince;
  final int totalPlans;
  final int totalCopiers;
  final num totalGain;
  final num winRate;
  final num masterEquity;
  final String strategyDescription;
  final String riskInformation;
  final int? riskScore;
  final List<CopyTradingPlan> plans;
  final List<CopyTradingTradeItem> tradeHistory;
  final List<CopyTradingTradeItem> openPositions;

  const CopyTradingMasterProfile({
    required this.masterCode,
    required this.nickname,
    required this.name,
    required this.serverType,
    required this.lpProviderName,
    required this.memberSince,
    required this.totalPlans,
    required this.totalCopiers,
    required this.totalGain,
    required this.winRate,
    required this.masterEquity,
    required this.strategyDescription,
    required this.riskInformation,
    required this.riskScore,
    required this.plans,
    required this.tradeHistory,
    required this.openPositions,
  });

  factory CopyTradingMasterProfile.fromJson(Map<String, dynamic> json) {
    final plansRaw = (json['approved_plans'] ?? json['plans'] ?? []) as Object?;
    final plansList =
        plansRaw is List ? plansRaw.whereType<Map>().map((e) => CopyTradingPlan.fromJson(e.cast<String, dynamic>())).toList() : <CopyTradingPlan>[];

    final tradeHistoryRaw = json['trade_history'];
    final openPositionsRaw = json['open_positions'];
    final tradeHistoryList = tradeHistoryRaw is List
        ? tradeHistoryRaw.whereType<Map>().map((e) => CopyTradingTradeItem.fromJson(e.cast<String, dynamic>())).toList()
        : <CopyTradingTradeItem>[];
    final openPositionsList = openPositionsRaw is List
        ? openPositionsRaw.whereType<Map>().map((e) => CopyTradingTradeItem.fromJson(e.cast<String, dynamic>())).toList()
        : <CopyTradingTradeItem>[];

    return CopyTradingMasterProfile(
      masterCode: (json['master_code'] ?? '').toString(),
      nickname: (json['master_nickname'] ?? '').toString(),
      name: (json['master_name'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      lpProviderName: (json['lp_provider_name'] ?? '').toString(),
      memberSince: (json['member_since'] ?? '').toString(),
      totalPlans: (json['total_plans'] ?? json['total_plans'] ?? 0) is num ? (json['total_plans'] as num).toInt() : 0,
      totalCopiers: (json['total_copiers'] ?? 0) is num ? (json['total_copiers'] as num).toInt() : 0,
      totalGain: (json['total_gain'] ?? 0) as num? ?? 0,
      winRate: (json['win_rate'] ?? 0) as num? ?? 0,
      masterEquity: (json['master_equity'] ?? 0) as num? ?? 0,
      strategyDescription: (json['strategy_description'] ?? '').toString(),
      riskInformation: (json['risk_information'] ?? '').toString(),
      riskScore: json['risk_score'] is num ? (json['risk_score'] as num).toInt() : null,
      plans: plansList,
      tradeHistory: tradeHistoryList,
      openPositions: openPositionsList,
    );
  }
}

class CopyTradingMasterDetailsController extends GetxController {
  final CopyTradingRepository _repo = Get.find<CopyTradingRepository>();
  final String masterCode;
  CopyTradingMasterDetailsController({required this.masterCode});

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<CopyTradingMasterProfile> profile = Rxn<CopyTradingMasterProfile>();

  @override
  void onInit() {
    super.onInit();
    loadProfile(showLoading: true);
  }

  Future<void> loadProfile({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await _repo.getMasterProfile(masterCode: masterCode);
      if (!res.success || res.data == null) {
        profile.value = null;
        errorMessage.value = res.message ?? 'Failed to load master profile';
        return;
      }
      final data = res.data?['data'];
      if (data is! Map) {
        profile.value = null;
        errorMessage.value = 'Invalid response';
        return;
      }
      profile.value = CopyTradingMasterProfile.fromJson(data.cast<String, dynamic>());
    } catch (e) {
      profile.value = null;
      errorMessage.value = 'Load error: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }
}

