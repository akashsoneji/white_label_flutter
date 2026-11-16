import 'models/tenax_orders_options.dart';

/// Mount-time values for the chart page (`window.TENAX_CHART_BOOT`).
///
/// Everything except [displayOffsetMinutes] can also be changed later by
/// message; the view does that when the widget is rebuilt with a new config.
class TenaxChartConfig {
  const TenaxChartConfig({
    required this.symbol,
    this.interval = '15m',
    this.themeMode = 'dark',
    this.displayOffsetMinutes,
    this.orders = const TenaxOrdersOptions(),
    this.persistenceKey = 'tenax.chart.mobile',
    this.themeColors,
  });

  final String symbol;
  final String interval;

  /// 'dark' | 'light' | 'auto' ('auto' only applies at boot).
  final String themeMode;

  /// The series' server clock offset. The page cannot change it after mount
  /// (flutter.md §2b), so when null the view reads `server_offset_minutes`
  /// from the first bars page before it opens the WebView.
  final int? displayOffsetMinutes;

  /// Broker-level order settings; per-symbol values from the data source
  /// (tick size, stop level, contract size) are merged over these.
  final TenaxOrdersOptions orders;

  /// localStorage namespace for layouts and drawings — one per brand so
  /// white labels sharing a device never read each other's state.
  final String persistenceKey;

  /// Per-broker palette sent in the `config` message, e.g. `up`, `down`, `bg`.
  final Map<String, String>? themeColors;

  Map<String, dynamic> toBootJson({required int displayOffsetMinutes}) => {
        'symbol': symbol,
        'interval': interval,
        'themeMode': themeMode,
        'displayOffsetMinutes': displayOffsetMinutes,
        'orders': orders.toJson(),
        'persistence': {'key': persistenceKey},
      };
}
