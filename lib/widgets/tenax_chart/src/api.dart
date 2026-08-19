import 'models.dart';

/// The one thing a mobile dev must implement. Everything the chart needs from
/// the outside world — history, live prices, and the four order actions — comes
/// through this interface. Wire it to your broker/Trade-Engine API and the chart
/// is fully live; nothing else in this package talks to your backend.
///
/// The golden rule (same on web and mobile): the order actions here must NOT be
/// applied optimistically. The chart already shows the dragged level dashed and
/// waits. You call the broker; on success you confirm by pushing the updated
/// order back (the controller does that for you when your Future completes). If
/// the Future throws, say nothing to the chart and the old level stands.
abstract class TenaxChartApi {
  /// Historical candles for [symbol] at [resolution] (e.g. '1', '5', '60',
  /// '1D'). Return oldest-first. Called on load and on symbol/interval change.
  Future<List<Candle>> fetchCandles({
    required String symbol,
    required String resolution,
    int? from,
    int? to,
  });

  /// Start streaming ticks for [symbol]; call [onTick] for every price update.
  /// The controller manages when this is called — you just push ticks. Return a
  /// cancel callback (called on unsubscribe / symbol change) so you can drop the
  /// upstream subscription. Keep it to ONE socket in your app.
  void Function() subscribeTicks(
    String symbol,
    void Function(Tick tick) onTick,
  );

  /// The instrument list for the search modal. Called once when the chart is
  /// ready; return everything the user may switch to.
  Future<List<SymbolInfo>> fetchSymbols();

  /// Trader dragged an SL / TP / pending level, OR dropped one (price == null
  /// means "remove this level"). Call your broker; RESOLVE with the updated
  /// position/order so the chart settles the dashed line onto the real value.
  /// THROW to reject — the chart keeps the old level.
  ///
  /// [field] is 'sl' | 'tp' | 'pending'. Return the full updated order/position.
  Future<Map<String, dynamic>> modifyOrder({
    required String orderId,
    required String field,
    required double? price,
  });

  /// Trader hit close on a position (or cancel on a pending). Call your broker;
  /// resolve on success (the controller then removes it from the chart). Throw
  /// to keep it on the chart.
  Future<void> closeOrder(String orderId);

  /// Optional: trader placed a NEW order from the chart (future feature — the
  /// order-place UI). Default is unsupported. Override to enable.
  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> request) {
    throw UnsupportedError('placeOrder not implemented by this app');
  }
}
