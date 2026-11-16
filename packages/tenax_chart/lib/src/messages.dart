import 'models/tenax_order.dart';

/// A message from the chart on the `tenaxchart` handler (flutter.md §3).
sealed class TenaxChartEvent {
  const TenaxChartEvent();

  static TenaxChartEvent parse(Object? raw) {
    if (raw is! Map) return TenaxUnknownEvent(type: null, raw: const {});
    final map = Map<String, dynamic>.from(raw);
    final type = map['type']?.toString();
    final orderId = map['orderId']?.toString();
    final kind = TenaxLevelKind.tryParse(map['kind']);

    switch (type) {
      case 'ready':
        return const TenaxReadyEvent();
      case 'orderModify':
        final to = _toDouble(map['to']);
        if (orderId == null || kind == null || to == null) break;
        return TenaxOrderModifyEvent(
          orderId: orderId,
          kind: kind,
          from: _toDouble(map['from']),
          to: to,
        );
      case 'orderClose':
        if (orderId == null) break;
        return TenaxOrderCloseEvent(orderId);
      case 'orderLevelRemove':
        if (orderId == null || kind == null) break;
        return TenaxOrderLevelRemoveEvent(orderId: orderId, kind: kind);
      case 'orderFocus':
        final ids = map['orderIds'];
        return TenaxOrderFocusEvent([
          if (ids is List) ...ids.map((id) => id.toString()),
        ]);
      case 'orderTimeout':
        if (orderId == null) break;
        return TenaxOrderTimeoutEvent(orderId: orderId, kind: kind);
      case 'error':
        return TenaxErrorEvent(map['message']?.toString() ?? '');
      case 'symbol':
        final symbol = map['symbol']?.toString();
        if (symbol == null || symbol.isEmpty) break;
        final interval = map['interval']?.toString();
        return TenaxSymbolChangeEvent(
          symbol: symbol,
          interval: (interval == null || interval.isEmpty) ? null : interval,
        );
    }
    return TenaxUnknownEvent(type: type, raw: map);
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Mounted — push the first data.
class TenaxReadyEvent extends TenaxChartEvent {
  const TenaxReadyEvent();
}

/// The trader dragged or added a level. The chart shows it dashed and waits
/// for an `order upsert`; [from] is null when the level was added.
class TenaxOrderModifyEvent extends TenaxChartEvent {
  const TenaxOrderModifyEvent({
    required this.orderId,
    required this.kind,
    required this.from,
    required this.to,
  });

  final String orderId;
  final TenaxLevelKind kind;
  final double? from;
  final double to;
}

/// ✕ pressed; waits for an `order remove`.
class TenaxOrderCloseEvent extends TenaxChartEvent {
  const TenaxOrderCloseEvent(this.orderId);
  final String orderId;
}

/// 🗑 on an SL/TP pill; waits for an `order upsert` with the level cleared.
class TenaxOrderLevelRemoveEvent extends TenaxChartEvent {
  const TenaxOrderLevelRemoveEvent({required this.orderId, required this.kind});
  final String orderId;
  final TenaxLevelKind kind;
}

class TenaxOrderFocusEvent extends TenaxChartEvent {
  const TenaxOrderFocusEvent(this.orderIds);
  final List<String> orderIds;
}

/// Nobody confirmed in time; the chart has already put the level back.
class TenaxOrderTimeoutEvent extends TenaxChartEvent {
  const TenaxOrderTimeoutEvent({required this.orderId, this.kind});
  final String orderId;
  final TenaxLevelKind? kind;
}

/// The trader picked another symbol or timeframe inside the chart. Not in
/// flutter.md §3, but the 0.2.1 bundle sends it on every timeframe pick; in
/// push mode the page has no data for it until the app loads that series.
class TenaxSymbolChangeEvent extends TenaxChartEvent {
  const TenaxSymbolChangeEvent({required this.symbol, this.interval});
  final String symbol;
  final String? interval;
}

class TenaxErrorEvent extends TenaxChartEvent {
  const TenaxErrorEvent(this.message);
  final String message;
}

/// A type this package does not know yet (newer bundle) or a malformed one.
class TenaxUnknownEvent extends TenaxChartEvent {
  const TenaxUnknownEvent({required this.type, required this.raw});
  final String? type;
  final Map<String, dynamic> raw;
}
