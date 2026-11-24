import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:tenax_chart/tenax_chart.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/stream_websocket_service.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';

/// Feeds the Tenax chart from this app's one `/ws/stream` socket and the
/// engine's `GET /api/bars`. Used only on brands with
/// `FlavorConfig.instance.useNewChart`: `k` frames exist only on that socket.
class AppTenaxChartDataSource implements TenaxChartDataSource {
  static const Duration _requestTimeout = Duration(seconds: 10);

  StreamWebSocketService get _stream => Get.find<StreamWebSocketService>();
  TradingController get _trading => Get.find<TradingController>();

  MT5Account _requireAccount() {
    final account = Get.find<AccountController>().activeMT5Account;
    if (account == null) throw StateError('No active trading account');
    return account;
  }

  /// The engine serves REST on the same host and path as `/ws/stream`
  /// (`wss://host/trade-engine` → `https://host/trade-engine/api/bars`).
  static Uri _barsUri(Map<String, String> query) {
    final socketBase = ApiConstants.socketUrl.replaceAll(RegExp(r'/+$'), '');
    final httpBase = socketBase.replaceFirst(RegExp('^ws'), 'http');
    return Uri.parse('$httpBase/api/bars').replace(queryParameters: query);
  }

  @override
  Future<TenaxBarsPage> fetchBars(
    String symbol,
    String interval, {
    int limit = 1000,
  }) async {
    // A user without a trading account still gets the chart: the request
    // then carries neither the `account` key nor the account's group.
    final account = Get.isRegistered<AccountController>()
        ? Get.find<AccountController>().activeMT5Account
        : null;
    final token = await SecureStorageService.getAuthToken();
    final mt5AccountNumber = account?.metaAccountNumber.trim() ?? '';
    final hasTradingAccount = account != null && mt5AccountNumber.isNotEmpty;
    // The engine takes the numeric master_group_id. Some CRMs send the group
    // name ("Standard") instead, which the engine rejects with "unknown
    // symbol" — then fall back to the symbol's default series.
    final groupId = hasTradingAccount
        ? int.tryParse(account.masterGroupId.trim())
        : null;
    // The engine serves an MT5 account's own series only when told which
    // account; other platforms keep the group/default series.
    final sendAccount = hasTradingAccount && account.isMT5;
    final uri = _barsUri({
      'symbol': _normalize(symbol),
      'tf': interval,
      'limit': '$limit',
      if (groupId != null) 'group': '$groupId',
      if (sendAccount) 'account': mt5AccountNumber,
    });
    tenaxChartDebugLog('API → GET $uri '
        '(platform=${account?.platformDisplayName}, isMT5=${account?.isMT5})');
    final stopwatch = Stopwatch()..start();
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      tenaxChartDebugLog('API ← ${response.statusCode} in '
          '${stopwatch.elapsedMilliseconds}ms: ${_preview(response.body)}');
      throw http.ClientException(
        'GET /api/bars returned ${response.statusCode}',
        uri,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected /api/bars response');
    }
    final page = TenaxBarsPage.fromEngineJson(body);
    tenaxChartDebugLog('API ← 200 in ${stopwatch.elapsedMilliseconds}ms '
        's=${body['s']} tf=${body['tf']} live=${body['live']} '
        'offset=${page.serverOffsetMinutes} bars=${page.bars.length}'
        '${page.bars.isEmpty ? '' : ' last=${page.bars.last.time}'}');
    return page;
  }

  static String _preview(String body) =>
      body.length <= 200 ? body : '${body.substring(0, 200)}…';

  @override
  Stream<TenaxBar> liveBars(String symbol, String interval) {
    final wanted = _normalize(symbol);
    StreamSubscription<List<dynamic>>? frames;
    late final StreamController<TenaxBar> controller;
    controller = StreamController<TenaxBar>(
      onListen: () {
        tenaxChartDebugLog('WS → subscribe_bars symbol=$wanted tf=$interval');
        _stream.subscribeBars(wanted, interval);
        frames = _stream.bars.listen((frame) {
          if (frame.length < 10) return;
          if (_normalize(frame[0].toString()) != wanted) return;
          if (frame[1].toString() != interval) {
            tenaxChartDebugLog('WS ← k ${frame[0]} tf=${frame[1]} '
                'ignored (chart tf=$interval)');
            return;
          }
          tenaxChartDebugLog('WS ← k ${frame[0]} tf=${frame[1]} '
              'time=${frame[2]} closed=${frame[8]}');
          // Tagged with the chart's own symbol so a broker suffix on the
          // chart side does not make the chart drop the frame.
          controller.add(TenaxBar.fromEngineFrame(frame).tagged(symbol, interval));
        });
      },
      onCancel: () async {
        tenaxChartDebugLog('WS → unsubscribe_bars symbol=$wanted tf=$interval');
        await frames?.cancel();
        _stream.unsubscribeBars(wanted, interval);
      },
    );
    return controller.stream;
  }

  @override
  Stream<TenaxLastPrice> lastPrice(String symbol) {
    final wanted = _normalize(symbol);
    // Keeps the chart symbol subscribed even when it is not a favourite.
    tenaxChartDebugLog('WS → price subscribe (pinned) symbol=$wanted');
    _stream.pinSymbol(symbol);
    return _stream.prices.expand<TenaxLastPrice>((rows) sync* {
      if (rows is! List) return;
      for (final row in rows) {
        if (row is! List || row.length < 3) continue;
        if (_normalize(row[0].toString()) != wanted) continue;
        final bid = _toDouble(row[1]);
        if (bid == null) continue;
        yield TenaxLastPrice(bid: bid, ask: _toDouble(row[2]), symbol: symbol);
      }
    });
  }

  @override
  Future<TenaxOrdersSnapshot> orders(String symbol) async {
    final snapshot = _snapshot(_normalize(symbol));
    tenaxChartDebugLog('orders (from TradingController, no API) '
        'positions=${snapshot.positions.length} '
        'pendings=${snapshot.pendings.length}');
    return snapshot;
  }

  @override
  Stream<TenaxOrderChange> orderChanges(String symbol) {
    final wanted = _normalize(symbol);
    final subscriptions = <StreamSubscription<dynamic>>[];
    var sent = <String, String>{};
    late final StreamController<TenaxOrderChange> controller;

    Map<String, String> encode(TenaxOrdersSnapshot snapshot) => {
          for (final order in <TenaxChartOrder>[
            ...snapshot.positions,
            ...snapshot.pendings,
          ])
            order.id: jsonEncode(order.toJson()),
        };

    void emitDiff() {
      final snapshot = _snapshot(wanted);
      final next = encode(snapshot);
      for (final order in <TenaxChartOrder>[
        ...snapshot.positions,
        ...snapshot.pendings,
      ]) {
        if (sent[order.id] != next[order.id]) {
          controller.add(TenaxOrderUpsert(order));
        }
      }
      for (final id in sent.keys) {
        if (!next.containsKey(id)) controller.add(TenaxOrderRemove(id));
      }
      sent = next;
    }

    controller = StreamController<TenaxOrderChange>(
      onListen: () {
        // The view has just sent this snapshot; only changes from here on.
        sent = encode(_snapshot(wanted));
        final trading = _trading;
        subscriptions
          ..add(trading.marketPositionsRx.listen((_) => emitDiff()))
          ..add(trading.pendingPositionsRx.listen((_) => emitDiff()));
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<TenaxInstrument>> instruments() async => const [];

  @override
  Future<TenaxOrdersOptions?> instrumentOptions(String symbol) async {
    final account = Get.isRegistered<AccountController>()
        ? Get.find<AccountController>().activeMT5Account
        : null;
    if (account == null || account.metaAccountNumber.trim().isEmpty) {
      debugPrint('📊 TenaxChart instrumentOptions: no trading account, '
          'skipping account-scoped symbol details for $symbol');
      return null;
    }
    final details = await SymbolDetailsCacheService.getSymbolDetails(
      symbol,
      account.metaAccountNumber,
    );
    final digits = (details?['digits'] as num?)?.toInt();
    tenaxChartDebugLog('instrument options (SymbolDetailsCacheService) '
        'symbol=$symbol account=${account.metaAccountNumber} digits=$digits');
    if (digits == null) return null;
    return TenaxOrdersOptions(tickSize: 1 / math.pow(10, digits));
  }

  @override
  Future<TenaxChartOrder> modifyLevel({
    required String orderId,
    required TenaxLevelKind kind,
    required double? price,
  }) async {
    final account = _requireAccount();
    final trading = _trading;
    final id = int.parse(orderId);
    // The update APIs read 0 as "clear this level".
    final value = price ?? 0;

    final position = trading.getMarketPositionById(orderId);
    if (position != null) {
      final current = _toPosition(position);
      if (current == null || kind == TenaxLevelKind.pending) {
        throw StateError('Position $orderId cannot be modified from the chart');
      }
      final ok = await trading.updateTPSL(
        mt5Account: account.metaAccountNumber,
        positionId: id,
        stopLoss: kind == TenaxLevelKind.sl ? value : (current.sl ?? 0),
        takeProfit: kind == TenaxLevelKind.tp ? value : (current.tp ?? 0),
        digits: position.digits,
      );
      if (!ok) throw Exception(trading.errorMessage);
      return TenaxPosition(
        id: current.id,
        side: current.side,
        volume: current.volume,
        entry: current.entry,
        sl: kind == TenaxLevelKind.sl ? price : current.sl,
        tp: kind == TenaxLevelKind.tp ? price : current.tp,
        profit: current.profit,
      );
    }

    final pending = trading.getPendingPositionById(orderId);
    final current = pending == null ? null : _toPending(pending);
    if (pending == null || current == null) {
      throw StateError('Order $orderId not found');
    }
    if (kind == TenaxLevelKind.pending && price == null) {
      throw ArgumentError('A pending order trigger cannot be cleared');
    }
    final ok = await trading.updatePendingOrderTPSL(
      mt5Account: account.metaAccountNumber,
      orderId: id,
      price: kind == TenaxLevelKind.pending ? value : current.price,
      stopLoss: kind == TenaxLevelKind.sl ? value : (current.sl ?? 0),
      takeProfit: kind == TenaxLevelKind.tp ? value : (current.tp ?? 0),
      digits: pending.digits,
    );
    if (!ok) throw Exception(trading.errorMessage);
    return TenaxPendingOrder(
      id: current.id,
      side: current.side,
      kind: current.kind,
      volume: current.volume,
      price: kind == TenaxLevelKind.pending ? value : current.price,
      sl: kind == TenaxLevelKind.sl ? price : current.sl,
      tp: kind == TenaxLevelKind.tp ? price : current.tp,
    );
  }

  @override
  Future<void> closeOrder(String orderId) async {
    final account = _requireAccount();
    final trading = _trading;
    final id = int.parse(orderId);
    if (trading.getMarketPositionById(orderId) != null) {
      final ok = await trading.closePositionById(
        mt5Account: account.metaAccountNumber,
        positionId: id,
      );
      if (!ok) throw Exception(trading.errorMessage);
      return;
    }
    if (trading.getPendingPositionById(orderId) != null) {
      await trading.cancelOrderWithImmediateUpdate(
        mt5Account: account.metaAccountNumber,
        orderId: id,
      );
      return;
    }
    throw StateError('Order $orderId not found');
  }

  // ─── Mapping from the app's trading models ─────────────────────────────

  TenaxOrdersSnapshot _snapshot(String wantedSymbol) {
    final trading = _trading;
    final positions = <TenaxPosition>[];
    for (final p in trading.marketPositions) {
      if (_normalize(p.symbol) != wantedSymbol) continue;
      final mapped = _toPosition(p);
      if (mapped != null) positions.add(mapped);
    }
    final pendings = <TenaxPendingOrder>[];
    for (final p in trading.pendingPositions) {
      if (_normalize(p.symbol) != wantedSymbol) continue;
      final mapped = _toPending(p);
      if (mapped != null) pendings.add(mapped);
    }
    return TenaxOrdersSnapshot(positions: positions, pendings: pendings);
  }

  TenaxPosition? _toPosition(TradePosition p) {
    final entry = _parsePrice(p.entryPrice);
    if (entry == null) return null;
    return TenaxPosition(
      id: p.orderId,
      side: _side(p.action),
      volume: p.volume,
      entry: entry,
      sl: _level(p.stopLoss),
      tp: _level(p.takeProfit),
      profit: p.profitLoss,
    );
  }

  TenaxPendingOrder? _toPending(TradePosition p) {
    final price = _parsePrice(p.entryPrice);
    if (price == null) return null;
    final side = _side(p.action);
    return TenaxPendingOrder(
      id: p.orderId,
      side: side,
      kind: _pendingKind(side, price, _parsePrice(p.currentPrice)),
      volume: p.volume,
      price: price,
      sl: _level(p.stopLoss),
      tp: _level(p.takeProfit),
    );
  }

  /// The trading model keeps only Buy/Sell for pending orders, so the kind is
  /// derived the MT5 way: a buy below the market, or a sell above it, is a
  /// limit; the other side is a stop.
  static TenaxPendingKind _pendingKind(
    TenaxSide side,
    double price,
    double? market,
  ) {
    if (market == null) return TenaxPendingKind.limit;
    final belowMarket = price < market;
    final isBuy = side == TenaxSide.buy;
    return isBuy == belowMarket ? TenaxPendingKind.limit : TenaxPendingKind.stop;
  }

  static TenaxSide _side(String action) =>
      action.trim().toLowerCase().startsWith('buy')
          ? TenaxSide.buy
          : TenaxSide.sell;

  /// Prices in the trading model are display strings (may carry separators).
  static double? _parsePrice(String raw) =>
      double.tryParse(raw.replaceAll(',', '').trim());

  /// Empty or zero means the level is not set.
  static double? _level(String raw) {
    final value = _parsePrice(raw);
    return (value == null || value == 0) ? null : value;
  }

  static double? _toDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw == null) return null;
    return double.tryParse(raw.toString());
  }

  static String _normalize(String symbol) =>
      StreamWebSocketService.normalizeSymbol(symbol);
}
