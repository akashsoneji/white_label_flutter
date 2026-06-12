// lib/models/stream_envelope.dart
//
// Unified envelope model for the single `/ws/stream` multiplexed socket.
// All server binary frames decode to: [tag, payload] — see WEBSOCKET_STREAM_API.md
// Control (JSON) frames use { "type": "...", ... } shape.
//
// This file is the contract every channel-aware piece of code reads from.
// Keep it tiny, immutable, and dependency-free so it can be consumed by:
//   - StreamService (transport)
//   - StreamDispatcher (router)
//   - Channel controllers (positions/orders/account/prices/symbols)
//
import 'dart:typed_data';

/// Tag constants used by the engine for binary envelope type discrimination.
class StreamTags {
  StreamTags._();

  /// Price tick (marketwatch) — [symbol, bid, ask, spread, digits, dayHigh, dayLow, category]
  static const String price = 'p';

  /// Open position — inner tag: 'op' | 'a' | 'u' | 'r'
  static const String position = 'pos';

  /// Pending order — inner tag: 'a' | 'u' | 'r' | 'po'
  static const String pendingOrder = 'po';

  /// Account metrics — inner tag: 'ac'
  static const String account = 'ac';

  /// Reserved (symbols metadata)
  static const String symbols = 'sy';

  /// Inner position action tags.
  static const String posOpen = 'op';
  static const String posAdd = 'a';
  static const String posUpdate = 'u';
  static const String posRemove = 'r';

  /// Inner pending order action tags.
  static const String poAdd = 'a';
  static const String poUpdate = 'u';
  static const String poRemove = 'r';
}

/// Channel name identifiers. These are the values used in
/// `stream_subscribe.channels: [...]` AND in the type field for control
/// messages, so we expose them as constants.
class StreamChannels {
  StreamChannels._();

  static const String prices = 'prices';
  static const String positions = 'positions';
  static const String orders = 'orders';
  static const String accounts = 'accounts';
}

/// Outer envelope wrapping whatever the server sent on a single frame.
///
/// The engine sends two shapes:
///   1. Control frames as JSON text: `{ "type": "...", ... }`
///   2. Data frames as MessagePack binary: `[tag, payload]`
///
/// We normalise both into a single [StreamEnvelope] with a typed [kind].
class StreamEnvelope {
  /// Server-tag for binary envelopes (e.g. `"p"`, `"pos"`, `"po"`, `"ac"`).
  /// `null` for JSON control frames.
  final String? tag;

  /// Decoded payload (a List, Map, or scalar — whatever the server sent).
  final dynamic payload;

  /// The kind of frame we received. Used by the dispatcher to route.
  final StreamEnvelopeKind kind;

  /// Wall-clock arrival time (UTC). Useful for stale-frame filtering.
  final DateTime receivedAt;

  /// True when the frame was binary (MessagePack-decoded).
  final bool wasBinary;

  const StreamEnvelope({
    required this.kind,
    this.tag,
    this.payload,
    required this.receivedAt,
    this.wasBinary = false,
  });

  @override
  String toString() =>
      'StreamEnvelope(tag=$tag, kind=$kind, binary=$wasBinary, payloadType=${payload?.runtimeType})';
}

/// High-level frame category. The dispatcher switches on this once and
/// then dives into the typed [StreamEvent] tree.
enum StreamEnvelopeKind {
  /// Binary data envelope [tag, payload] (e.g. `["p", [...]]`, `["pos", [...]]`).
  data,

  /// `{ "type": "authenticated", ... }`
  authenticated,

  /// `{ "type": "stream_subscribed", channels, ... }`
  streamSubscribed,

  /// `{ "type": "subscription_updated", action, symbols, ... }`
  symbolSubscriptionUpdated,

  /// `{ "type": "unsubscribed", ... }`
  unsubscribed,

  /// `{ "type": "error", message, ... }`
  error,

  /// `{ "type": "pending_orders_init", ... }` (legacy compat, may also be binary)
  pendingOrdersInit,

  /// Catch-all for unknown control messages.
  unknownControl,
}

/// Typed account metrics. Shape: `[ "ac", account, balance, credit, equity,
/// margin, freeMargin, marginLevel, profit, swap, serverType ]` (10 fields).
/// The legacy 8-field shape (no credit, no swap) is detected at parse time.
class AccountTick {
  final String account;
  final double balance;
  final double credit;
  final double equity;
  final double margin;
  final double freeMargin;
  final double marginLevel;
  final double profit;
  final double swap;
  final String serverType;

  const AccountTick({
    required this.account,
    required this.balance,
    required this.credit,
    required this.equity,
    required this.margin,
    required this.freeMargin,
    required this.marginLevel,
    required this.profit,
    required this.swap,
    required this.serverType,
  });

  /// Heuristic parser that handles both new (10-field) and old (8-field) shapes.
  /// Mirrors the logic from AccountWebSocketService._parseAccountArray.
  static AccountTick? tryParse(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    if (raw[0]?.toString().toLowerCase() != 'ac') return null;
    if (raw.length < 2) return null;

    String asString(dynamic v) => v?.toString() ?? '';
    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    final account = asString(raw.length > 1 ? raw[1] : '');
    final balance = asDouble(raw.length > 2 ? raw[2] : 0);
    final credit = asDouble(raw.length > 3 ? raw[3] : 0);
    final equity = asDouble(raw.length > 4 ? raw[4] : 0);
    final margin = asDouble(raw.length > 5 ? raw[5] : 0);
    final freeMargin = asDouble(raw.length > 6 ? raw[6] : 0);
    final marginLevel = asDouble(raw.length > 7 ? raw[7] : 0);
    final profit = asDouble(raw.length > 8 ? raw[8] : 0);
    final swap = asDouble(raw.length > 9 ? raw[9] : 0);
    final serverType = asString(raw.length > 10 ? raw[10] : 'sh');

    // Detect shape: with credit, Equity ≈ Balance + Credit + Profit + Swap.
    if (raw.length >= 9) {
      final newEq = balance + credit + profit + swap;
      final oldEq = balance + profit + swap;
      final newDiff = (equity - newEq).abs();
      final oldDiff = (equity - oldEq).abs();
      if (newDiff < oldDiff && newDiff < 5.0) {
        return AccountTick(
          account: account, balance: balance, credit: credit,
          equity: equity, margin: margin, freeMargin: freeMargin,
          marginLevel: marginLevel, profit: profit, swap: swap,
          serverType: serverType,
        );
      }
    }
    // Old format fallback: no credit, no swap at indices 3/9.
    return AccountTick(
      account: account, balance: balance, credit: 0,
      equity: raw.length > 3 ? asDouble(raw[3]) : 0,
      margin: raw.length > 4 ? asDouble(raw[4]) : 0,
      freeMargin: raw.length > 5 ? asDouble(raw[5]) : 0,
      marginLevel: raw.length > 6 ? asDouble(raw[6]) : 0,
      profit: raw.length > 7 ? asDouble(raw[7]) : 0,
      swap: raw.length > 8 ? asDouble(raw[8]) : 0,
      serverType: serverType,
    );
  }
}

/// Typed price tick.
class PriceTick {
  final String symbol;
  final double bid;       // parsed from string for math
  final double ask;       // parsed from string for math
  final int spreadPoints;
  final int digits;
  final double dayHigh;
  final double dayLow;
  final String category;

  const PriceTick({
    required this.symbol,
    required this.bid,
    required this.ask,
    required this.spreadPoints,
    required this.digits,
    required this.dayHigh,
    required this.dayLow,
    required this.category,
  });

  /// Parse a single 8-field price array. Returns `null` if shape is wrong.
  static PriceTick? tryParse(dynamic raw) {
    if (raw is! List || raw.length < 8) return null;
    if (raw[0] is! String) return null;
    return PriceTick(
      symbol: raw[0].toString(),
      bid: double.tryParse(raw[1].toString()) ?? 0.0,
      ask: double.tryParse(raw[2].toString()) ?? 0.0,
      spreadPoints: (raw[3] is num) ? (raw[3] as num).toInt() : 0,
      digits: (raw[4] is num) ? (raw[4] as num).toInt() : 5,
      dayHigh: (raw[5] is num) ? (raw[5] as num).toDouble() : 0.0,
      dayLow: (raw[6] is num) ? (raw[6] as num).toDouble() : 0.0,
      category: raw[7]?.toString() ?? '',
    );
  }
}

/// Position actions after parsing the inner tag.
enum PositionAction { open, add, update, remove }

class PositionTick {
  final PositionAction action;
  final int positionId;
  final String account;
  final String symbol;
  final int side; // 0 = BUY, 1 = SELL
  final double volume;
  final double openPrice;
  final double currentPrice;
  final double profit;
  final double swap;
  final double sl;
  final double tp;
  final String serverType;
  final int openTimeSeconds;
  final int digits;
  final double contractSize;

  const PositionTick({
    required this.action,
    required this.positionId,
    required this.account,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.openPrice,
    required this.currentPrice,
    required this.profit,
    required this.swap,
    required this.sl,
    required this.tp,
    required this.serverType,
    required this.openTimeSeconds,
    required this.digits,
    required this.contractSize,
  });

  /// Parse a single position array. Returns `null` for remove frames
  /// (which are short — use [tryParseRemove] for those).
  static PositionTick? tryParse(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final action = raw[0]?.toString();
    if (action == 'r') return null; // handled by tryParseRemove
    if (raw.length < 13) return null;

    int i(int idx) => (raw[idx] is num) ? (raw[idx] as num).toInt() : 0;
    double d(int idx) {
      if (raw[idx] is num) return (raw[idx] as num).toDouble();
      return double.tryParse(raw[idx]?.toString() ?? '') ?? 0.0;
    }
    String s(int idx) => raw[idx]?.toString() ?? '';

    final posAction = switch (action) {
      'op' => PositionAction.open,
      'a' => PositionAction.add,
      'add' => PositionAction.add,
      'u' => PositionAction.update,
      _ => PositionAction.update,
    };

    return PositionTick(
      action: posAction,
      positionId: i(1),
      account: s(2),
      symbol: s(3),
      side: i(4),
      volume: d(5),
      openPrice: d(6),
      currentPrice: d(7),
      profit: d(8),
      swap: raw.length > 9 ? d(9) : 0.0,
      sl: raw.length > 10 ? d(10) : 0.0,
      tp: raw.length > 11 ? d(11) : 0.0,
      serverType: raw.length > 12 ? s(12) : 'sh',
      openTimeSeconds: raw.length > 13 ? i(13) : 0,
      digits: raw.length > 14 ? i(14) : 5,
      contractSize: raw.length > 15 ? d(15) : 0.0,
    );
  }

  /// Parse a remove frame: `['r', account, id1, id2, ...]` or
  /// `['r', account, [id1, id2, ...]]`.
  static List<String> tryParseRemoveIds(dynamic raw) {
    if (raw is! List || raw.isEmpty) return const [];
    if (raw[0]?.toString() != 'r') return const [];
    final out = <String>[];
    if (raw.length == 2) {
      // ['r', id]
      out.add(raw[1].toString());
    } else if (raw.length >= 3) {
      if (raw[2] is List) {
        // ['r', account, [ids]]
        for (final id in (raw[2] as List)) {
          out.add(id.toString());
        }
      } else {
        // ['r', account, id1, id2, ...]
        for (int i = 2; i < raw.length; i++) {
          out.add(raw[i].toString());
        }
      }
    }
    return out;
  }
}

/// Pending order actions.
enum PendingOrderAction { add, update, remove }

class PendingOrderTick {
  final PendingOrderAction action;
  final int orderId;
  final String account;
  final String symbol;
  final int orderType; // 2=BUY_LIMIT, 3=SELL_LIMIT, 4=BUY_STOP, 5=SELL_STOP
  final double volume;
  final double orderPrice;
  final double currentPrice;
  final double sl;
  final double tp;
  final String serverType;
  final int createdAtSeconds;
  final double swap;
  final int digits;

  const PendingOrderTick({
    required this.action,
    required this.orderId,
    required this.account,
    required this.symbol,
    required this.orderType,
    required this.volume,
    required this.orderPrice,
    required this.currentPrice,
    required this.sl,
    required this.tp,
    required this.serverType,
    required this.createdAtSeconds,
    required this.swap,
    required this.digits,
  });

  static PendingOrderTick? tryParse(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final action = raw[0]?.toString();
    if (action == 'r') return null;
    if (raw.length < 12) return null;

    int i(int idx) => (raw[idx] is num) ? (raw[idx] as num).toInt() : 0;
    double d(int idx) {
      if (raw[idx] is num) return (raw[idx] as num).toDouble();
      return double.tryParse(raw[idx]?.toString() ?? '') ?? 0.0;
    }
    String s(int idx) => raw[idx]?.toString() ?? '';

    return PendingOrderTick(
      action: action == 'a' || action == 'add'
          ? PendingOrderAction.add
          : PendingOrderAction.update,
      orderId: i(1),
      account: s(2),
      symbol: s(3),
      orderType: i(4),
      volume: d(5),
      orderPrice: d(6),
      currentPrice: d(7),
      sl: raw.length > 8 ? d(8) : 0.0,
      tp: raw.length > 9 ? d(9) : 0.0,
      serverType: raw.length > 10 ? s(10) : 'sh',
      createdAtSeconds: raw.length > 11 ? i(11) : 0,
      swap: raw.length > 12 ? d(12) : 0.0,
      digits: raw.length > 13 ? i(13) : 5,
    );
  }

  /// ['r', account, orderId] / ['r', orderId]
  static List<String> tryParseRemoveIds(dynamic raw) {
    if (raw is! List || raw.isEmpty) return const [];
    if (raw[0]?.toString() != 'r') return const [];
    final out = <String>[];
    for (int i = 1; i < raw.length; i++) {
      out.add(raw[i].toString());
    }
    return out;
  }
}

/// One parsed event of any kind — what the dispatcher hands to listeners.
sealed class StreamEvent {
  const StreamEvent();
}

class AuthenticatedEvent extends StreamEvent {
  final String tradingAccount;
  final int? groupId;
  final String? userSlug;
  const AuthenticatedEvent({
    required this.tradingAccount,
    this.groupId,
    this.userSlug,
  });
}

class StreamSubscribedEvent extends StreamEvent {
  final List<String> channels;
  const StreamSubscribedEvent(this.channels);
}

class SymbolSubscriptionUpdatedEvent extends StreamEvent {
  final String action; // 'subscribe' | 'unsubscribe'
  final List<String> symbols;
  final int totalSubscribed;
  const SymbolSubscriptionUpdatedEvent({
    required this.action,
    required this.symbols,
    required this.totalSubscribed,
  });
}

class UnsubscribedEvent extends StreamEvent {
  final String dataType;
  final String? message;
  const UnsubscribedEvent(this.dataType, [this.message]);
}

class ErrorEvent extends StreamEvent {
  final String message;
  const ErrorEvent(this.message);
}

/// Account snapshot/updates (binary or initial JSON envelope).
class AccountEvent extends StreamEvent {
  final List<AccountTick> accounts; // batch
  const AccountEvent(this.accounts);
}

/// Price ticks (batch or single). Single and batch share a list.
class PriceEvent extends StreamEvent {
  final List<PriceTick> ticks;
  const PriceEvent(this.ticks);
}

/// Position updates batched by action.
class PositionEvent extends StreamEvent {
  final List<PositionTick> upserts; // open/add/update
  final List<String> removeIds; // position ids removed
  const PositionEvent({required this.upserts, required this.removeIds});
}

class PendingOrderEvent extends StreamEvent {
  final List<PendingOrderTick> upserts;
  final List<String> removeIds;
  const PendingOrderEvent({required this.upserts, required this.removeIds});
}
