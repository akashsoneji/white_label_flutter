class PmamManager {
  final int id;
  final int userId;
  final String managerCode;
  final String? managerName;
  final String? memberSince;
  final int plansCount;
  final double totalAum;
  final int totalInvestors;
  final double avgCommission;
  final double profitPercentage;
  final double maxDrawdown;
  final bool isEnrolled;
  final List<PmamPlan> plans;

  PmamManager({
    required this.id,
    required this.userId,
    required this.managerCode,
    this.managerName,
    this.memberSince,
    this.plansCount = 0,
    this.totalAum = 0,
    this.totalInvestors = 0,
    this.avgCommission = 0,
    this.profitPercentage = 0,
    this.maxDrawdown = 0,
    this.isEnrolled = false,
    this.plans = const [],
  });

  factory PmamManager.fromJson(Map<String, dynamic> json) {
    var plansList = json['plans'] as List?;
    return PmamManager(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      managerCode: (json['manager_code'] ?? '').toString(),
      managerName: (json['manager_name'] ?? '').toString(),
      memberSince: (json['member_since'] ?? '').toString(),
      plansCount: int.tryParse(json['plans_count']?.toString() ?? '0') ?? 0,
      totalAum: double.tryParse(json['total_aum']?.toString() ?? '0') ?? 0,
      totalInvestors: int.tryParse(json['total_investors']?.toString() ?? '0') ?? 0,
      avgCommission: double.tryParse(json['avg_commission']?.toString() ?? '0') ?? 0,
      profitPercentage: double.tryParse(json['profit_percentage']?.toString() ?? '0') ?? 0,
      maxDrawdown: double.tryParse(json['max_drawdown']?.toString() ?? '0') ?? 0,
      isEnrolled: json['is_enrolled'] == true || json['is_enrolled'] == 1,
      plans: plansList != null 
          ? plansList.map((i) => PmamPlan.fromJson(i)).toList() 
          : [],
    );
  }
}

/// One row of `POST user/pmam/plans/datatable` (doc 1.7) — the Explore feed.
class PmamExplorePlan {
  final int id;
  final String planName;
  final String managerCode;
  final String managerName;
  final String? memberSince;
  final double minimumInvestment;
  final double commissionPercentage;
  final double totalAum;
  final int activeInvestors;
  final bool hideInvestors;
  final double profitPercentage;
  final double maxDrawdown;
  final int riskScore;
  final bool managerBalanceOk;
  final bool isEnrolled;

  const PmamExplorePlan({
    required this.id,
    required this.planName,
    required this.managerCode,
    required this.managerName,
    this.memberSince,
    this.minimumInvestment = 0,
    this.commissionPercentage = 0,
    this.totalAum = 0,
    this.activeInvestors = 0,
    this.hideInvestors = false,
    this.profitPercentage = 0,
    this.maxDrawdown = 0,
    this.riskScore = 1,
    this.managerBalanceOk = true,
    this.isEnrolled = false,
  });

  static double _d(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;
  static bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

  factory PmamExplorePlan.fromJson(Map<String, dynamic> json) {
    final since = (json['member_since'] ?? '').toString();
    return PmamExplorePlan(
      id: int.tryParse('${json['id'] ?? ''}') ?? 0,
      planName: (json['plan_name'] ?? '').toString(),
      managerCode: (json['manager_code'] ?? '').toString(),
      managerName: (json['manager_name'] ?? '').toString(),
      memberSince: since.isEmpty ? null : since,
      minimumInvestment: _d(json['minimum_investment']),
      commissionPercentage: _d(json['commission_percentage']),
      totalAum: _d(json['total_aum']),
      activeInvestors: int.tryParse('${json['active_investors'] ?? ''}') ?? 0,
      hideInvestors: _b(json['hide_investors']),
      profitPercentage: _d(json['profit_percentage']),
      maxDrawdown: _d(json['max_drawdown']),
      riskScore: int.tryParse('${json['risk_score'] ?? ''}') ?? 1,
      // Missing key means the server did not flag a problem.
      managerBalanceOk: json['manager_balance_ok'] == null ||
          _b(json['manager_balance_ok']),
      isEnrolled: _b(json['is_enrolled']),
    );
  }
}

class PmamPlan {
  final int id;
  final int pmamManagerId;
  final String planName;
  final int? tradingAccountId;
  final double commissionPercentage;
  final double managerOwnFund;
  final double minimumInvestment;
  final String? strategyDescription;
  final String? riskInformation;
  final String status;
  final bool isLocked;

  PmamPlan({
    required this.id,
    required this.pmamManagerId,
    required this.planName,
    this.tradingAccountId,
    this.commissionPercentage = 0,
    this.managerOwnFund = 0,
    this.minimumInvestment = 0,
    this.strategyDescription,
    this.riskInformation,
    this.status = '',
    this.isLocked = false,
  });

  factory PmamPlan.fromJson(Map<String, dynamic> json) {
    return PmamPlan(
      id: json['id'] ?? 0,
      pmamManagerId: json['pmam_manager_id'] ?? 0,
      planName: (json['plan_name'] ?? 'N/A').toString(),
      tradingAccountId: json['trading_account_id'],
      commissionPercentage: double.tryParse(json['commission_percentage']?.toString() ?? '0') ?? 0,
      managerOwnFund: double.tryParse(json['manager_own_fund']?.toString() ?? '0') ?? 0,
      minimumInvestment: double.tryParse(json['minimum_investment']?.toString() ?? '0') ?? 0,
      strategyDescription: json['strategy_description'],
      riskInformation: json['risk_information'],
      status: (json['status'] ?? '').toString(),
      isLocked: json['is_locked'] ?? false,
    );
  }
}

/// One paid add-on from `GET investor/purchase-options` (doc 2.4).
class PmamPurchaseOption {
  final int id;
  final String name;
  final double feeInUsd;
  final String description;

  const PmamPurchaseOption({
    required this.id,
    required this.name,
    required this.feeInUsd,
    required this.description,
  });

  factory PmamPurchaseOption.fromJson(Map<String, dynamic> json) {
    return PmamPurchaseOption(
      id: int.tryParse('${json['id'] ?? ''}') ?? 0,
      name: (json['name'] ?? '').toString(),
      feeInUsd: double.tryParse('${json['fee_in_usd'] ?? ''}') ?? 0,
      description: (json['description'] ?? '').toString(),
    );
  }
}

/// `data` of `GET investor/purchase-options`. The dropdown is shown only when
/// [enabled] is true.
class PmamPurchaseOptions {
  final bool enabled;
  final List<PmamPurchaseOption> options;
  final double walletBalance;

  const PmamPurchaseOptions({
    required this.enabled,
    required this.options,
    required this.walletBalance,
  });

  static const PmamPurchaseOptions none =
      PmamPurchaseOptions(enabled: false, options: [], walletBalance: 0);

  bool get isAvailable => enabled && options.isNotEmpty;

  factory PmamPurchaseOptions.fromJson(Map<String, dynamic> json) {
    final raw = json['options'];
    return PmamPurchaseOptions(
      enabled: json['enabled'] == true,
      options: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => PmamPurchaseOption.fromJson(e.cast<String, dynamic>()))
              .where((o) => o.id > 0)
              .toList()
          : const [],
      walletBalance: double.tryParse('${json['wallet_balance'] ?? ''}') ?? 0,
    );
  }
}

/// Outcome of `POST investor/request-join` (doc 2.5). [shortage] is set only
/// for the 422 `insufficient_wallet` error; [purchase] only when an add-on was
/// bought (the server sends `""` otherwise).
class PmamJoinResult {
  final bool ok;
  final String message;
  final double? shortage;
  final Map<String, dynamic>? purchase;

  const PmamJoinResult({
    required this.ok,
    required this.message,
    this.shortage,
    this.purchase,
  });
}
