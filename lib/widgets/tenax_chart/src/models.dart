/// Data the chart draws. These are the exact JSON shapes the chart's bridge
/// expects — the app builds them from its own broker payload, which is the one
/// translation layer that keeps a single chart working for every broker.
///
/// Every `toJson()` here matches a field the chart reads. Do not rename keys.
library;

/// buy / sell.
enum OrderSide {
  buy,
  sell;

  String get wire => name; // 'buy' | 'sell'
}

/// One candle, time in UNIX **seconds** (not milliseconds).
class Candle {
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;

  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

  Map<String, dynamic> toJson() => {
        'time': time,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        if (volume != null) 'volume': volume,
      };
}

/// A live price tick. Feeds the forming candle + the bid/ask overlay.
class Tick {
  final String symbol;
  final double bid;
  final double ask;

  /// UNIX **seconds**. Defaults to now when omitted.
  final int? time;

  const Tick({
    required this.symbol,
    required this.bid,
    required this.ask,
    this.time,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'bid': bid,
        'ask': ask,
        if (time != null) 'time': time,
      };
}

/// An open position drawn as an entry line with optional SL / TP.
class Position {
  final String id;
  final String symbol;
  final OrderSide side;
  final double volume;
  final double entry;
  final double? sl;
  final double? tp;

  /// Live P/L shown in the order pill. Update it as prices move.
  final double? profit;

  const Position({
    required this.id,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.entry,
    this.sl,
    this.tp,
    this.profit,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'side': side.wire,
        'volume': volume,
        'entry': entry,
        if (sl != null) 'sl': sl,
        if (tp != null) 'tp': tp,
        if (profit != null) 'profit': profit,
      };
}

/// The kind of a pending order.
enum PendingKind {
  buyLimit('buy_limit'),
  sellLimit('sell_limit'),
  buyStop('buy_stop'),
  sellStop('sell_stop');

  const PendingKind(this.wire);
  final String wire;
}

/// A pending (not-yet-filled) order drawn at its trigger price.
class PendingOrder {
  final String id;
  final String symbol;
  final PendingKind kind;
  final double volume;
  final double price;
  final double? sl;
  final double? tp;

  const PendingOrder({
    required this.id,
    required this.symbol,
    required this.kind,
    required this.volume,
    required this.price,
    this.sl,
    this.tp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'kind': kind.wire,
        'volume': volume,
        'price': price,
        if (sl != null) 'sl': sl,
        if (tp != null) 'tp': tp,
      };
}

/// One instrument in the symbol-search list.
class SymbolInfo {
  final String symbol;
  final String? description;
  final int? digits;

  const SymbolInfo({required this.symbol, this.description, this.digits});

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': symbol,
        'ticker': symbol,
        if (description != null) 'description': description,
        if (digits != null) 'digits': digits,
      };
}

/// Which level the trader dragged / removed. Mirrors the chart's `LevelKind`.
enum LevelKind {
  sl,
  tp,
  entry,
  pending;

  static LevelKind fromWire(String v) => switch (v) {
        'sl' => LevelKind.sl,
        'tp' => LevelKind.tp,
        'entry' => LevelKind.entry,
        _ => LevelKind.pending,
      };
}

/// Light or dark. The host page starts light; call setTheme to follow the app.
enum ChartTheme {
  light,
  dark;

  String get wire => name;
}
