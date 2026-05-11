class WebSocketPriceData {
  final String symbol;
  final double ask;
  final double bid;
  final int digits;
  final double last;
  final double spreadDiff;
  final int volume;
  final int volumeReal;
  final String dataSource;
  final String logo;
  final int timestamp;
  final int spread;
  final bool realtime;
  final int serverTimestamp;

  WebSocketPriceData({
    required this.symbol,
    required this.ask,
    required this.bid,
    required this.digits,
    required this.last,
    required this.spreadDiff,
    required this.volume,
    required this.volumeReal,
    required this.dataSource,
    required this.logo,
    required this.timestamp,
    required this.spread,
    required this.realtime,
    required this.serverTimestamp,
  });

  factory WebSocketPriceData.fromJson(Map<String, dynamic> json) {
    final singleSymbol = json['singleSymbol'] as Map<String, dynamic>;

    return WebSocketPriceData(
      symbol: singleSymbol['Symbol']?.toString() ?? '',
      ask: (singleSymbol['Ask'] as num?)?.toDouble() ?? 0.0,
      bid: (singleSymbol['Bid'] as num?)?.toDouble() ?? 0.0,
      digits: singleSymbol['Digits'] as int? ?? 2,
      last: (singleSymbol['Last'] as num?)?.toDouble() ?? 0.0,
      spreadDiff: (singleSymbol['SpreadDiff'] as num?)?.toDouble() ?? 0.0,
      volume: singleSymbol['Volume'] as int? ?? 0,
      volumeReal: singleSymbol['VolumeReal'] as int? ?? 0,
      dataSource: singleSymbol['data_source']?.toString() ?? '',
      logo: singleSymbol['logo']?.toString() ?? '',
      timestamp: singleSymbol['timestamp'] as int? ?? 0,
      spread: singleSymbol['spread'] as int? ?? 0,
      realtime: json['realtime'] as bool? ?? false,
      serverTimestamp: json['server_timestamp'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'singleSymbolPrice',
      'symbol': symbol,
      'ask': ask,
      'bid': bid,
      'digits': digits,
      'last': last,
      'spreadDiff': spreadDiff,
      'volume': volume,
      'volumeReal': volumeReal,
      'dataSource': dataSource,
      'logo': logo,
      'timestamp': timestamp,
      'spread': spread,
      'realtime': realtime,
      'serverTimestamp': serverTimestamp,
    };
  }

  // Helper methods for easy access
  double get calculatedSpread => ask - bid;
  double get midPrice => (ask + bid) / 2;
  bool get hasValidPrice => ask > 0 && bid > 0;

  @override
  String toString() {
    return 'WebSocketPriceData(symbol: $symbol, ask: $ask, bid: $bid, spread: $calculatedSpread)';
  }
}
