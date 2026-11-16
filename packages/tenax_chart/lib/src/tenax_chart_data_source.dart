import 'models/tenax_bar.dart';
import 'models/tenax_instrument.dart';
import 'models/tenax_order.dart';
import 'models/tenax_orders_options.dart';

/// Everything the chart needs from the host app. The package itself opens no
/// socket and makes no HTTP call: the app already holds the session and the
/// one stream socket, and relays from them (flutter.md §2b).
abstract class TenaxChartDataSource {
  /// History from the REST API (`GET /api/bars`), oldest first, forming bar
  /// last. Called with `limit: 3` every 2 s to repair any dropped frame.
  Future<TenaxBarsPage> fetchBars(
    String symbol,
    String interval, {
    int limit = 1000,
  });

  /// Server-built bars from the app's stream socket (`k` frames), tagged with
  /// symbol and interval. Subscribe on listen, unsubscribe on cancel.
  Stream<TenaxBar> liveBars(String symbol, String interval);

  /// Bid/ask for the price lines and P&L, from the app's stream socket.
  Stream<TenaxLastPrice> lastPrice(String symbol);

  /// Open positions and pending orders on [symbol].
  Future<TenaxOrdersSnapshot> orders(String symbol);

  /// Live order changes on [symbol].
  Stream<TenaxOrderChange> orderChanges(String symbol);

  /// The symbol search list.
  Future<List<TenaxInstrument>> instruments();

  /// Per-symbol order settings (tick size, stop level, contract size). Null
  /// keeps the broker-level values from the config.
  Future<TenaxOrdersOptions?> instrumentOptions(String symbol);

  /// Sets ([price] non-null) or clears ([price] null) one level through the
  /// broker. Returns the order as it now stands; throws when refused.
  Future<TenaxChartOrder> modifyLevel({
    required String orderId,
    required TenaxLevelKind kind,
    required double? price,
  });

  /// Closes the order through the broker; throws when refused.
  Future<void> closeOrder(String orderId);
}
