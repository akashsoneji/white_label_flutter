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
      plans: plansList != null 
          ? plansList.map((i) => PmamPlan.fromJson(i)).toList() 
          : [],
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
