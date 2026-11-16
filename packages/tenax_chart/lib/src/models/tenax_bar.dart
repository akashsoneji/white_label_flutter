import 'dart:math' as math;

/// One candle. [time] is unix **seconds**, already in the display zone.
class TenaxBar {
  const TenaxBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
    this.closed,
    this.symbol,
    this.interval,
  });

  /// A row of `GET /api/bars`: `[t, o, h, l, c, v]`, prices scaled by
  /// `10^digits` (flutter.md §2b).
  factory TenaxBar.fromEngineRow(
    List<dynamic> row,
    int digits, {
    required bool closed,
    String? symbol,
    String? interval,
  }) {
    final scale = math.pow(10, digits).toDouble();
    return TenaxBar(
      time: (row[0] as num).toInt(),
      open: (row[1] as num) / scale,
      high: (row[2] as num) / scale,
      low: (row[3] as num) / scale,
      close: (row[4] as num) / scale,
      volume: row.length > 5 ? (row[5] as num?)?.toDouble() : null,
      closed: closed,
      symbol: symbol,
      interval: interval,
    );
  }

  /// A `k` frame body from `/ws/stream`:
  /// `[symbol, tf, t, o, h, l, c, v, closed, digits]`. Uses the frame's own
  /// digits, never the history response's — a feed's digits can be corrected
  /// by its first tick.
  factory TenaxBar.fromEngineFrame(List<dynamic> frame) {
    final closedFlag = frame[8];
    return TenaxBar.fromEngineRow(
      frame.sublist(2, 8),
      (frame[9] as num).toInt(),
      closed: closedFlag == true || closedFlag == 1,
      symbol: frame[0].toString(),
      interval: frame[1].toString(),
    );
  }

  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;

  /// True on the frame that ends the bar.
  final bool? closed;

  /// Tags so the chart drops a frame still in flight after a switch.
  final String? symbol;
  final String? interval;

  TenaxBar tagged(String symbol, String interval) => TenaxBar(
        time: time,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
        closed: closed,
        symbol: symbol,
        interval: interval,
      );

  Map<String, dynamic> toJson() => {
        'time': time,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        if (volume != null) 'volume': volume,
        if (closed != null) 'closed': closed,
        if (symbol != null) 'symbol': symbol,
        if (interval != null) 'interval': interval,
      };
}

/// One `GET /api/bars` response.
class TenaxBarsPage {
  const TenaxBarsPage({
    required this.bars,
    required this.digits,
    required this.serverOffsetMinutes,
  });

  /// Parses `{digits, bars: [[t,o,h,l,c,v]…], server_offset_minutes}`. The
  /// last row is the forming bar, every earlier one is closed.
  factory TenaxBarsPage.fromEngineJson(Map<String, dynamic> json) {
    final digits = (json['digits'] as num).toInt();
    final rows = (json['bars'] as List? ?? const []).cast<List<dynamic>>();
    return TenaxBarsPage(
      digits: digits,
      serverOffsetMinutes: (json['server_offset_minutes'] as num?)?.toInt() ?? 0,
      bars: [
        for (var i = 0; i < rows.length; i++)
          TenaxBar.fromEngineRow(rows[i], digits, closed: i != rows.length - 1),
      ],
    );
  }

  final List<TenaxBar> bars;
  final int digits;
  final int serverOffsetMinutes;
}

/// Moves the price lines and order P&L only — never a candle.
class TenaxLastPrice {
  const TenaxLastPrice({required this.bid, this.ask, this.price, this.symbol});

  final double bid;
  final double? ask;
  final double? price;
  final String? symbol;

  Map<String, dynamic> toJson() => {
        'bid': bid,
        if (ask != null) 'ask': ask,
        if (price != null) 'price': price,
        if (symbol != null) 'symbol': symbol,
      };
}
