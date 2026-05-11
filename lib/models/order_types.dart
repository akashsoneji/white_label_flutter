enum OrderType {
  buyMarket(0, 'Instant Execution (Buy)', isBuy: true, requiresPrice: false),
  sellMarket(1, 'Instant Execution (Sell)', isBuy: false, requiresPrice: false),
  buyLimit(2, 'Buy Limit', isBuy: true, requiresPrice: true),
  sellLimit(3, 'Sell Limit', isBuy: false, requiresPrice: true),
  buyStop(4, 'Buy Stop', isBuy: true, requiresPrice: true),
  sellStop(5, 'Sell Stop', isBuy: false, requiresPrice: true),
  buyStopLimit(6, 'Buy Stop Limit', isBuy: true, requiresPrice: true),
  sellStopLimit(7, 'Sell Stop Limit', isBuy: false, requiresPrice: true);

  final int value;
  final String displayName;
  final bool isBuy;
  final bool requiresPrice;

  const OrderType(
    this.value,
    this.displayName, {
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
