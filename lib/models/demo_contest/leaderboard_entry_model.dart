/// Leaderboard entry shown on the contest leaderboard screen.
class LeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final String countryCode; // ISO-2 like 'GB', 'IN', 'AE' – used for flag emoji
  final double equity; // current virtual account equity
  final double pnl; // absolute P&L since contest start
  final double pnlPercent; // % gain relative to starting balance
  final int tradesCount;
  final double winRate; // 0.0..1.0
  final bool isCurrentUser;
  final bool isTop3;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.countryCode,
    required this.equity,
    required this.pnl,
    required this.pnlPercent,
    required this.tradesCount,
    required this.winRate,
    this.isCurrentUser = false,
    this.isTop3 = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Trader',
      countryCode: json['country_code']?.toString() ?? '',
      equity: (json['equity'] as num?)?.toDouble() ?? 0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0,
      pnlPercent: (json['pnl_percent'] as num?)?.toDouble() ?? 0,
      tradesCount: (json['trades_count'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
      isTop3: json['is_top3'] as bool? ?? false,
    );
  }
}