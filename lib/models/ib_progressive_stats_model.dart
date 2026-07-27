class IbProgressiveStatsResponse {
  bool? status;
  bool? success;
  String? message;
  IbProgressiveStatsData? data;

  IbProgressiveStatsResponse({
    this.status,
    this.success,
    this.message,
    this.data,
  });

  factory IbProgressiveStatsResponse.fromJson(Map<String, dynamic> json) {
    return IbProgressiveStatsResponse(
      status: json['status'],
      success: json['success'],
      message: json['message'],
      data: json['data'] != null ? IbProgressiveStatsData.fromJson(json['data']) : null,
    );
  }
}

class IbProgressiveStatsData {
  int? activeClients;
  double? totalDeposit;
  double? totalWithdrawal;
  double? netDeposit;
  int? teamActiveClients;
  double? teamNetDeposit;
  double? totalEarned;
  double? totalLots;
  double? currentTierEarnings;
  String? currentBalance;
  TierInfo? currentTier;
  TierInfo? nextTier;
  List<RebateCategory>? currentRebates;

  IbProgressiveStatsData({
    this.activeClients,
    this.totalDeposit,
    this.totalWithdrawal,
    this.netDeposit,
    this.teamActiveClients,
    this.teamNetDeposit,
    this.totalEarned,
    this.totalLots,
    this.currentTierEarnings,
    this.currentBalance,
    this.currentTier,
    this.nextTier,
    this.currentRebates,
  });

  factory IbProgressiveStatsData.fromJson(Map<String, dynamic> json) {
    return IbProgressiveStatsData(
      activeClients: json['active_clients'] is int ? json['active_clients'] : int.tryParse(json['active_clients']?.toString() ?? ''),
      totalDeposit: json['total_deposit'] is num ? (json['total_deposit'] as num).toDouble() : double.tryParse(json['total_deposit']?.toString() ?? ''),
      totalWithdrawal: json['total_withdrawal'] is num ? (json['total_withdrawal'] as num).toDouble() : double.tryParse(json['total_withdrawal']?.toString() ?? ''),
      netDeposit: json['net_deposit'] is num ? (json['net_deposit'] as num).toDouble() : double.tryParse(json['net_deposit']?.toString() ?? ''),
      teamActiveClients: json['team_active_clients'] is int ? json['team_active_clients'] : int.tryParse(json['team_active_clients']?.toString() ?? ''),
      teamNetDeposit: json['team_net_deposit'] is num ? (json['team_net_deposit'] as num).toDouble() : double.tryParse(json['team_net_deposit']?.toString() ?? ''),
      totalEarned: json['total_earned'] is num ? (json['total_earned'] as num).toDouble() : double.tryParse(json['total_earned']?.toString() ?? ''),
      totalLots: json['total_lots'] is num ? (json['total_lots'] as num).toDouble() : double.tryParse(json['total_lots']?.toString() ?? ''),
      currentTierEarnings: json['current_tier_earnings'] is num ? (json['current_tier_earnings'] as num).toDouble() : double.tryParse(json['current_tier_earnings']?.toString() ?? ''),
      currentBalance: json['current_balance']?.toString(),
      currentTier: json['current_tier'] != null ? TierInfo.fromJson(json['current_tier']) : null,
      nextTier: json['nextTier'] != null ? TierInfo.fromJson(json['nextTier']) : json['next_tier'] != null ? TierInfo.fromJson(json['next_tier']) : null,
      currentRebates: json['current_rebates'] != null
          ? (json['current_rebates'] as List).map((i) => RebateCategory.fromJson(i)).toList()
          : null,
    );
  }
}

class TierInfo {
  String? name;
  int? minClients;
  String? minDeposit;
  String? condition;
  int? clientsNeeded;
  double? depositNeeded;

  TierInfo({
    this.name,
    this.minClients,
    this.minDeposit,
    this.condition,
    this.clientsNeeded,
    this.depositNeeded,
  });

  factory TierInfo.fromJson(Map<String, dynamic> json) {
    return TierInfo(
      name: json['name'],
      minClients: json['min_clients'] is int ? json['min_clients'] : int.tryParse(json['min_clients']?.toString() ?? ''),
      minDeposit: json['min_deposit']?.toString(),
      condition: json['condition'],
      clientsNeeded: json['clients_needed'] is int ? json['clients_needed'] : int.tryParse(json['clients_needed']?.toString() ?? ''),
      depositNeeded: json['deposit_needed'] is num ? (json['deposit_needed'] as num).toDouble() : double.tryParse(json['deposit_needed']?.toString() ?? ''),
    );
  }
}

class RebateCategory {
  int? categoryId;
  String? category;
  String? categoryName;
  List<RebateLevel>? levels;

  RebateCategory({
    this.categoryId,
    this.category,
    this.categoryName,
    this.levels,
  });

  factory RebateCategory.fromJson(Map<String, dynamic> json) {
    return RebateCategory(
      categoryId: json['category_id'] is int ? json['category_id'] : int.tryParse(json['category_id']?.toString() ?? ''),
      category: json['category'],
      categoryName: json['category_name'],
      levels: json['levels'] != null ? (json['levels'] as List).map((i) => RebateLevel.fromJson(i)).toList() : null,
    );
  }
}

class RebateLevel {
  int? level;
  double? rate;

  RebateLevel({
    this.level,
    this.rate,
  });

  factory RebateLevel.fromJson(Map<String, dynamic> json) {
    return RebateLevel(
      level: json['level'] is int ? json['level'] : int.tryParse(json['level']?.toString() ?? ''),
      rate: json['rate'] is num ? (json['rate'] as num).toDouble() : double.tryParse(json['rate']?.toString() ?? ''),
    );
  }
}
