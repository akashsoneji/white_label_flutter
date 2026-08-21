class TradingHistoryEntryModel {
  final int id;
  final String tradeSymbol;
  final int tradeType;
  final double tradeVolume;
  final double lots;
  final double tradePriceOrder;
  final double? tradeClosePrice;
  final double tradeProfit;
  final DateTime? tradeOpenTime;
  final DateTime? tradeCloseTime;
  final String tradeOrderStatus;
  final String? tradeComment;

  TradingHistoryEntryModel({
    required this.id,
    required this.tradeSymbol,
    required this.tradeType,
    required this.tradeVolume,
    required this.lots,
    required this.tradePriceOrder,
    this.tradeClosePrice,
    required this.tradeProfit,
    this.tradeOpenTime,
    this.tradeCloseTime,
    required this.tradeOrderStatus,
    this.tradeComment,
  });

  factory TradingHistoryEntryModel.fromJson(Map<String, dynamic> json) {
    return TradingHistoryEntryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tradeSymbol: json['trade_symbol']?.toString() ?? '',
      tradeType: (json['trade_type'] as num?)?.toInt() ?? 0,
      tradeVolume: (json['trade_volume'] as num?)?.toDouble() ?? 0.0,
      lots: (json['lots'] as num?)?.toDouble() ?? 0.0,
      tradePriceOrder: (json['trade_price_order'] as num?)?.toDouble() ?? 0.0,
      tradeClosePrice: (json['trade_close_price'] as num?)?.toDouble(),
      tradeProfit: (json['trade_profit'] as num?)?.toDouble() ?? 0.0,
      tradeOpenTime: json['trade_open_time'] != null ? DateTime.tryParse(json['trade_open_time'].toString()) : null,
      tradeCloseTime: json['trade_close_time'] != null ? DateTime.tryParse(json['trade_close_time'].toString()) : null,
      tradeOrderStatus: json['trade_order_status']?.toString() ?? '',
      tradeComment: json['trade_comment']?.toString(),
    );
  }
}
