enum TenaxSide { buy, sell }

enum TenaxPendingKind { limit, stop, stopLimit }

/// Which level of an order the trader acted on.
enum TenaxLevelKind {
  sl,
  tp,

  /// A pending order's trigger price.
  pending;

  static TenaxLevelKind? tryParse(Object? raw) {
    for (final kind in values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

/// Anything the chart draws as an order (integration.md §2).
sealed class TenaxChartOrder {
  const TenaxChartOrder();

  /// The ticket number.
  String get id;

  Map<String, dynamic> toJson();
}

class TenaxPosition extends TenaxChartOrder {
  const TenaxPosition({
    required this.id,
    required this.side,
    required this.volume,
    required this.entry,
    this.sl,
    this.tp,
    this.profit,
    this.editable = true,
  });

  @override
  final String id;
  final TenaxSide side;

  /// Lots.
  final double volume;
  final double entry;
  final double? sl;
  final double? tp;

  /// Server P&L; null lets the chart estimate it from `contractSize`.
  final double? profit;

  /// False locks the order against dragging.
  final bool editable;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'side': side.name,
        'volume': volume,
        'entry': entry,
        'sl': sl,
        'tp': tp,
        if (profit != null) 'profit': profit,
        'editable': editable,
      };
}

class TenaxPendingOrder extends TenaxChartOrder {
  const TenaxPendingOrder({
    required this.id,
    required this.side,
    required this.kind,
    required this.volume,
    required this.price,
    this.sl,
    this.tp,
    this.editable = true,
  });

  @override
  final String id;
  final TenaxSide side;
  final TenaxPendingKind kind;
  final double volume;

  /// Trigger price.
  final double price;
  final double? sl;
  final double? tp;
  final bool editable;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'side': side.name,
        'kind': kind.name,
        'volume': volume,
        'price': price,
        'sl': sl,
        'tp': tp,
        'editable': editable,
      };
}

/// Full snapshot for the chart's current symbol.
class TenaxOrdersSnapshot {
  const TenaxOrdersSnapshot({
    this.positions = const [],
    this.pendings = const [],
  });

  final List<TenaxPosition> positions;
  final List<TenaxPendingOrder> pendings;
}

/// One live order update for the chart's current symbol.
sealed class TenaxOrderChange {
  const TenaxOrderChange();
}

class TenaxOrderUpsert extends TenaxOrderChange {
  const TenaxOrderUpsert(this.order);
  final TenaxChartOrder order;
}

class TenaxOrderRemove extends TenaxOrderChange {
  const TenaxOrderRemove(this.orderId);
  final String orderId;
}
