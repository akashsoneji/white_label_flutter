import 'demo_contest_model.dart';

/// Represents the current user joining/participating in a contest.
/// Used by the "My Contest History" screen and the registered/contest
/// details header on Join Contest.
class MyContestEntry {
  final String contestId;
  final String contestTitle;
  final String contestSubtitle;
  final ContestEntryStatus status;
  final DateTime joinedAt;
  final DateTime endsAt;
  final double startingBalance;
  final double equity;
  final double pnl;
  final double pnlPercent;
  final int rank;
  final int totalParticipants;
  final int tradesCount;
  final double winRate;
  final double? prizeAmount;
  final String currency;
  final bool hasWithdrawableReward;

  const MyContestEntry({
    required this.contestId,
    required this.contestTitle,
    required this.contestSubtitle,
    required this.status,
    required this.joinedAt,
    required this.endsAt,
    required this.startingBalance,
    required this.equity,
    required this.pnl,
    required this.pnlPercent,
    required this.rank,
    required this.totalParticipants,
    required this.tradesCount,
    required this.winRate,
    this.prizeAmount,
    this.currency = 'USD',
    this.hasWithdrawableReward = false,
  });

  Duration get remaining {
    final now = DateTime.now();
    if (now.isAfter(endsAt)) return Duration.zero;
    return endsAt.difference(now);
  }

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(joinedAt) && now.isBefore(endsAt);
  }

  bool get isWinner => status == ContestEntryStatus.winner;

  /// Concise status text used by badges and list tiles.
  /// Mirrors values defined in translations (dc_status_*).
  String statusKey() {
    switch (status) {
      case ContestEntryStatus.notJoined:
        return 'not_joined';
      case ContestEntryStatus.registered:
        return 'registered';
      case ContestEntryStatus.running:
        return 'running';
      case ContestEntryStatus.finished:
        return 'finished';
      case ContestEntryStatus.winner:
        return 'winner';
    }
  }

  factory MyContestEntry.fromJson(Map<String, dynamic> json) {
    return MyContestEntry(
      contestId: json['contest_id']?.toString() ?? '',
      contestTitle: json['contest_title']?.toString() ?? '',
      contestSubtitle: json['contest_subtitle']?.toString() ?? '',
      status: ContestEntryStatus.values.firstWhere(
        (s) => s.name == (json['status']?.toString() ?? 'registered'),
        orElse: () => ContestEntryStatus.registered,
      ),
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      startingBalance:
          (json['starting_balance'] as num?)?.toDouble() ?? 10000,
      equity: (json['equity'] as num?)?.toDouble() ?? 0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0,
      pnlPercent: (json['pnl_percent'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      totalParticipants: (json['total_participants'] as num?)?.toInt() ?? 0,
      tradesCount: (json['trades_count'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      prizeAmount: (json['prize_amount'] as num?)?.toDouble(),
      currency: json['currency']?.toString() ?? 'USD',
      hasWithdrawableReward: json['has_withdrawable_reward'] as bool? ?? false,
    );
  }
}