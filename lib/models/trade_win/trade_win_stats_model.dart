class TradeWinStatsModel {
  final double totalLots;
  final double lifetimeLots;
  final double spentLots;
  final double totalPoints;
  final double lifetimePoints;
  final double spentPoints;
  final double totalPrizeValueWon;
  final int pastWinsCount;

  const TradeWinStatsModel({
    this.totalLots = 0,
    this.lifetimeLots = 0,
    this.spentLots = 0,
    this.totalPoints = 0,
    this.lifetimePoints = 0,
    this.spentPoints = 0,
    this.totalPrizeValueWon = 0,
    this.pastWinsCount = 0,
  });

  factory TradeWinStatsModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return TradeWinStatsModel(
      totalLots: toDouble(json['total_lots']),
      lifetimeLots: toDouble(json['lifetime_lots']),
      spentLots: toDouble(json['spent_lots']),
      totalPoints: toDouble(json['total_points']),
      lifetimePoints: toDouble(json['lifetime_points']),
      spentPoints: toDouble(json['spent_points']),
      totalPrizeValueWon: toDouble(json['total_prize_value_won']),
      pastWinsCount: toInt(json['past_wins_count']),
    );
  }
}
