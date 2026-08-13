enum OrderType {
  buyMarket(0, 'Instant Execution (Buy)', 'buy', isBuy: true, requiresPrice: false),
  sellMarket(1, 'Instant Execution (Sell)', 'sell', isBuy: false, requiresPrice: false),
  buyLimit(2, 'Buy Limit', 'buy_limit', isBuy: true, requiresPrice: true),
  sellLimit(3, 'Sell Limit', 'sell_limit', isBuy: false, requiresPrice: true),
  buyStop(4, 'Buy Stop', 'buy_stop', isBuy: true, requiresPrice: true),
  sellStop(5, 'Sell Stop', 'sell_stop', isBuy: false, requiresPrice: true),
  buyStopLimit(6, 'Buy Stop Limit', 'buy_stop_limit', isBuy: true, requiresPrice: true),
  sellStopLimit(7, 'Sell Stop Limit', 'sell_stop_limit', isBuy: false, requiresPrice: true);

  final int value;
  final String displayName;
  final String apiString;
  final bool isBuy;
  final bool requiresPrice;

  const OrderType(
    this.value,
    this.displayName,
    this.apiString, {
    required this.isBuy,
    required this.requiresPrice,
  });

  factory OrderType.fromValue(int value) {
    return OrderType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderType.buyMarket, // Default to buy market
    );
  }

  bool get isBuyOrder => isBuy;
  bool get isSellOrder => !isBuy;
}
