class TradeWinLeaderboardEntryModel {
  final int rank;
  final String name;
  final double lots;
  final bool isMe;

  const TradeWinLeaderboardEntryModel({
    required this.rank,
    required this.name,
    required this.lots,
    this.isMe = false,
  });

  factory TradeWinLeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return TradeWinLeaderboardEntryModel(
      rank: json['rank'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      lots: toDouble(json['lots']),
      isMe: json['is_me'] == true,
    );
  }
}
