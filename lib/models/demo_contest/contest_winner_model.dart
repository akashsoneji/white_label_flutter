/// Winner of a past contest (used on the winners page / podium in the
/// My Contest History "winner" badge).
class ContestWinner {
  final String contestId;
  final String contestTitle;
  final int rank;
  final String displayName;
  final String countryCode;
  final double pnlPercent;
  final double prizeAmount;
  final String currency;
  final DateTime endedAt;

  const ContestWinner({
    required this.contestId,
    required this.contestTitle,
    required this.rank,
    required this.displayName,
    required this.countryCode,
    required this.pnlPercent,
    required this.prizeAmount,
    required this.currency,
    required this.endedAt,
  });

  factory ContestWinner.fromJson(Map<String, dynamic> json) {
    return ContestWinner(
      contestId: json['contest_id']?.toString() ?? '',
      contestTitle: json['contest_title']?.toString() ?? '',
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      displayName: json['display_name']?.toString() ?? '',
      countryCode: json['country_code']?.toString() ?? '',
      pnlPercent: (json['pnl_percent'] as num?)?.toDouble() ?? 0,
      prizeAmount: (json['prize_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      endedAt: DateTime.tryParse(json['ended_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}