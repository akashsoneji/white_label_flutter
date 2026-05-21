class TradeWinSpentDetailModel {
  final String group;
  final String symbol;
  final double lots;

  const TradeWinSpentDetailModel({
    required this.group,
    required this.symbol,
    required this.lots,
  });

  factory TradeWinSpentDetailModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return TradeWinSpentDetailModel(
      group: json['group']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      lots: toDouble(json['lots']),
    );
  }
}
