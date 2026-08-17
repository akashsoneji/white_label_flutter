import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/utils/precision_helper.dart';

class WebSocketTradingResponse {
  final OpenPositionsData? openPositions;
  final PendingOrdersData? pendingOrders;
  final bool realtime;
  final int serverTimestamp;

  WebSocketTradingResponse({
    this.openPositions,
    this.pendingOrders,
    required this.realtime,
    required this.serverTimestamp,
  });

  factory WebSocketTradingResponse.fromJson(Map<String, dynamic> json) {
    final openPositionsJson = json['openPositions'] ?? json['open_positions'];
    final pendingOrdersJson = json['pendingOrders'] ?? json['pending_orders'];

    return WebSocketTradingResponse(
      openPositions: openPositionsJson != null
          ? OpenPositionsData.fromJson(openPositionsJson)
          : null,
      pendingOrders: pendingOrdersJson != null
          ? PendingOrdersData.fromJson(pendingOrdersJson)
          : null,
      realtime: json['realtime'] ?? false,
      serverTimestamp: json['server_timestamp'] ?? json['serverTimestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (openPositions != null) 'openPositions': openPositions!.toJson(),
      if (pendingOrders != null) 'pendingOrders': pendingOrders!.toJson(),
      'realtime': realtime,
      'server_timestamp': serverTimestamp,
    };
  }
}

class OpenPositionsData {
  final List<TradingPosition> positions;
  final List<AccountInfo> accountinfo;

  OpenPositionsData({required this.positions, required this.accountinfo});

  factory OpenPositionsData.fromJson(Map<String, dynamic> json) {
    return OpenPositionsData(
      positions:
          (json['positions'] as List?)
              ?.map((position) => TradingPosition.fromJson(position))
              .toList() ??
          [],
      accountinfo:
          (json['accountinfo'] as List?)
              ?.map((account) => AccountInfo.fromJson(account))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'positions': positions.map((position) => position.toJson()).toList(),
      'accountinfo': accountinfo.map((account) => account.toJson()).toList(),
    };
  }
}

class PendingOrdersData {
  final List<PendingOrder> pendingOrders;

  PendingOrdersData({required this.pendingOrders});

  factory PendingOrdersData.fromJson(Map<String, dynamic> json) {
    return PendingOrdersData(
      pendingOrders:
          (json['pendingOrders'] as List?)
              ?.map((order) => PendingOrder.fromJson(order))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pendingOrders': pendingOrders.map((order) => order.toJson()).toList(),
    };
  }
}

class PendingOrder {
  final int mt5Account;
  final int order;
  final String action; // "Buy Limit", "Sell Limit", "Buy Stop", "Sell Stop"
  final String symbol;
  final double priceOrder;
  final double priceCurrent;
  final double volume;
  final double priceSL;
  final double priceTP;
  final String timeCreate;
  final String state; // "PLACED", "CANCELLED", etc.
  final String logo;
  final int digits;

  PendingOrder({
    required this.mt5Account,
    required this.order,
    required this.action,
    required this.symbol,
    required this.priceOrder,
    required this.priceCurrent,
    required this.volume,
    required this.priceSL,
    required this.priceTP,
    required this.timeCreate,
    required this.state,
    required this.logo,
    this.digits = 0,
  });

  factory PendingOrder.fromJson(Map<String, dynamic> json) {
    final rawVolume = json['Volume'] ?? json['volume'];
    final rawPriceOrder = json['PriceOrder'] ?? json['priceOrder'] ?? json['price_order'] ?? json['price'];
    final rawPriceCurrent = json['PriceCurrent'] ?? json['priceCurrent'] ?? json['price_current'];
    final rawPriceSL = json['PriceSL'] ?? json['priceSL'] ?? json['price_sl'] ?? json['stopLoss'] ?? json['stop_loss'];
    final rawPriceTP = json['PriceTP'] ?? json['priceTP'] ?? json['price_tp'] ?? json['takeProfit'] ?? json['take_profit'];
    final rawDigits = json['Digits'] ?? json['digits'];
    final rawMt5Account = json['MT5Account'] ?? json['mt5Account'] ?? json['mt5_account'];
    final rawOrder = json['Order'] ?? json['order'] ?? json['order_id'];

    return PendingOrder(
      mt5Account: rawMt5Account is num
          ? rawMt5Account.toInt()
          : (int.tryParse(rawMt5Account?.toString() ?? '') ?? 0),
      order: rawOrder is num
          ? rawOrder.toInt()
          : (int.tryParse(rawOrder?.toString() ?? '') ?? 0),
      action: json['Action'] ?? json['action'] ?? '',
      symbol: json['Symbol'] ?? json['symbol'] ?? '',
      priceOrder: rawPriceOrder is num
          ? rawPriceOrder.toDouble()
          : (double.tryParse(rawPriceOrder?.toString() ?? '') ?? 0.0),
      priceCurrent: rawPriceCurrent is num
          ? rawPriceCurrent.toDouble()
          : (double.tryParse(rawPriceCurrent?.toString() ?? '') ?? 0.0),
      volume: rawVolume is num
          ? rawVolume.toDouble()
          : (double.tryParse(rawVolume?.toString() ?? '') ?? 0.0),
      priceSL: rawPriceSL is num
          ? rawPriceSL.toDouble()
          : (double.tryParse(rawPriceSL?.toString() ?? '') ?? 0.0),
      priceTP: rawPriceTP is num
          ? rawPriceTP.toDouble()
          : (double.tryParse(rawPriceTP?.toString() ?? '') ?? 0.0),
      timeCreate: json['TimeCreate'] ?? json['timeCreate'] ?? json['time_create'] ?? '',
      state: json['State'] ?? json['state'] ?? '',
      logo: json['Logo'] ?? json['logo'] ?? '',
      digits: rawDigits is num
          ? rawDigits.toInt()
          : (int.tryParse(rawDigits?.toString() ?? '') ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MT5Account': mt5Account,
      'Order': order,
      'Action': action,
      'Symbol': symbol,
      'PriceOrder': priceOrder,
      'PriceCurrent': priceCurrent,
      'Volume': volume,
      'PriceSL': priceSL,
      'PriceTP': priceTP,
      'TimeCreate': timeCreate,
      'State': state,
      'Logo': logo,
      'Digits': digits,
    };
  }

  // Convert to TradePosition for compatibility with existing UI
  TradePosition toTradePosition() {
    // Use digits value from WebSocket for proper price formatting
    // If digits is 0 or not provided, use default of 5 (most forex pairs use 5 decimals)
    final displayDigits = digits > 0 ? digits : 5;

    return TradePosition(
      symbol: symbol.replaceAll('.c', ''), // Remove .c suffix
      flag: logo, // Use the actual logo URL from WebSocket
      action:
          action.contains('Buy')
              ? 'Buy'
              : 'Sell', // Extract Buy/Sell from action
      volume: volume,
      profitLoss: 0.0, // Pending orders don't have profit/loss yet
      entryPrice: PrecisionHelper.formatPrice(
        priceOrder,
        decimals: displayDigits,
      ),
      currentPrice: PrecisionHelper.formatPrice(
        priceCurrent,
        decimals: displayDigits,
      ),
      accountId: mt5Account.toString(),
      orderId: order.toString(),
      openTime: timeCreate,
      closeTime: '',
      takeProfit:
          (priceTP == 0.0 ||
                  priceTP == 0 ||
                  priceTP.toString() == '0' ||
                  priceTP.toString() == '0.0')
              ? ''
              : PrecisionHelper.formatPrice(priceTP, decimals: displayDigits),
      stopLoss:
          (priceSL == 0.0 ||
                  priceSL == 0 ||
                  priceSL.toString() == '0' ||
                  priceSL.toString() == '0.0')
              ? ''
              : PrecisionHelper.formatPrice(priceSL, decimals: displayDigits),
      mt5Account: mt5Account.toString(),
      time: timeCreate,
      digits: displayDigits,
    );
  }
}

class TradingPosition {
  final int mt5Account;
  final int position;
  final String action; // "Buy" or "Sell"
  final String volume;
  final String priceOpen;
  final String priceSL;
  final String priceTP;
  final String priceCurrent;
  final String closeTime;
  final String timeCreate;
  final String symbol;
  final String logo;
  final double profit;
  final int digits;
  final double swap;

  TradingPosition({
    required this.mt5Account,
    required this.position,
    required this.action,
    required this.volume,
    required this.priceOpen,
    required this.priceSL,
    required this.priceTP,
    required this.priceCurrent,
    required this.closeTime,
    required this.timeCreate,
    required this.symbol,
    required this.logo,
    required this.profit,
    required this.digits,
    this.swap = 0.0,
  });

  factory TradingPosition.fromJson(Map<String, dynamic> json) {
    return TradingPosition(
      mt5Account: json['MT5Account'] ?? 0,
      position: json['Position'] ?? 0,
      action: json['Action'] ?? '',
      volume: json['Volume'] ?? '0',
      priceOpen: json['PriceOpen'] ?? '0',
      priceSL: json['PriceSL'] ?? '0',
      priceTP: json['PriceTP'] ?? '0',
      priceCurrent: json['PriceCurrent'] ?? '0',
      closeTime: json['CloseTime'] ?? '',
      timeCreate: json['TimeCreate'] ?? '',
      symbol: json['Symbol'] ?? '',
      logo: json['Logo'] ?? '',
      profit: (json['Profit'] ?? 0.0).toDouble(),
      digits: json['Digits'] ?? 0,
      swap: (json['Swap'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MT5Account': mt5Account,
      'Position': position,
      'Action': action,
      'Volume': volume,
      'PriceOpen': priceOpen,
      'PriceSL': priceSL,
      'PriceTP': priceTP,
      'PriceCurrent': priceCurrent,
      'CloseTime': closeTime,
      'TimeCreate': timeCreate,
      'Symbol': symbol,
      'Logo': logo,
      'Profit': profit,
      'Digits': digits,
      'Swap': swap,
    };
  }

  // Helper method to get flag emoji based on symbol
  // String get flag {
  //   if (symbol.contains('EUR')) return '🇪🇺';
  //   if (symbol.contains('GBP')) return '🇬🇧';
  //   if (symbol.contains('USD')) return '🇺🇸';
  //   if (symbol.contains('JPY')) return '🇯🇵';
  //   if (symbol.contains('AUD')) return '🇦🇺';
  //   if (symbol.contains('CAD')) return '🇨🇦';
  //   if (symbol.contains('CHF')) return '🇨🇭';
  //   if (symbol.contains('NZD')) return '🇳🇿';
  //   if (symbol.contains('XAU')) return '🥇';
  //   if (symbol.contains('XAG')) return '🥈';
  //   return '💱';
  // }

  // Convert to TradePosition for compatibility
  TradePosition toTradePosition() {
    // Use digits value from WebSocket for proper price formatting
    // If digits is 0 or not provided, use default of 5 (most forex pairs use 5 decimals)
    final displayDigits = digits > 0 ? digits : 5;

    // ✅ FIX: double.tryParse("NaN") returns double.nan (NOT null), so the
    // `?? 0.0` fallback does NOT catch NaN/Infinity strings. Sanitize here
    // so a malformed WS payload can't crash the UI via PrecisionHelper.round.
    double _safe(dynamic v) {
      if (v == null) return 0.0;
      final parsed = v is num ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);
      return (parsed.isNaN || parsed.isInfinite) ? 0.0 : parsed;
    }

    // Parse and format prices with correct decimal places
    final entryPriceDouble = _safe(priceOpen);
    final currentPriceDouble = _safe(priceCurrent);
    final priceSLDouble = _safe(priceSL);
    final priceTPDouble = _safe(priceTP);
    final safeVolume = _safe(volume);
    final safeSwap = (swap.isNaN || swap.isInfinite) ? 0.0 : swap;

    final safeProfit =
        (profit.isNaN || profit.isInfinite) ? 0.0 : profit;

    return TradePosition(
      symbol: symbol,
      // symbol: symbol.replaceAll('.c', ''), // Remove .c suffix
      flag: logo, // Use the actual logo URL from WebSocket
      action: action,
      volume: safeVolume,
      profitLoss: safeProfit,
      entryPrice: PrecisionHelper.formatPrice(
        entryPriceDouble,
        decimals: displayDigits,
      ),
      currentPrice: PrecisionHelper.formatPrice(
        currentPriceDouble,
        decimals: displayDigits,
      ),
      accountId: mt5Account.toString(),
      orderId: position.toString(),
      openTime: timeCreate,
      closeTime: closeTime == '-' ? '' : closeTime,
      time: timeCreate,
      takeProfit:
          (priceTPDouble == 0.0 ||
                  priceTP == '0' ||
                  priceTP == '0.0' ||
                  priceTP == '0.00000' ||
                  priceTP.isEmpty)
              ? ''
              : PrecisionHelper.formatPrice(
                priceTPDouble,
                decimals: displayDigits,
              ),
      stopLoss:
          (priceSLDouble == 0.0 ||
                  priceSL == '0' ||
                  priceSL == '0.0' ||
                  priceSL == '0.00000' ||
                  priceSL.isEmpty)
              ? ''
              : PrecisionHelper.formatPrice(
                priceSLDouble,
                decimals: displayDigits,
              ),
      swap: safeSwap,
      digits: displayDigits,
    );
  }
}

class AccountInfo {
  final double assets;
  final double balance;
  final double blockedCommission;
  final double blockedProfit;
  final double credit;
  final int currencyDigits;
  final double equity;
  final double floating;
  final double liabilities;
  final int login;
  final double margin;
  final double marginFree;
  final double marginInitial;
  final double marginLevel;
  final int marginLeverage;
  final double marginMaintenance;
  final double profit;
  final double soActivation;
  final double soEquity;
  final double soLevel;
  final double soMargin;
  final double soTime;
  final double storage;

  AccountInfo({
    required this.assets,
    required this.balance,
    required this.blockedCommission,
    required this.blockedProfit,
    required this.credit,
    required this.currencyDigits,
    required this.equity,
    required this.floating,
    required this.liabilities,
    required this.login,
    required this.margin,
    required this.marginFree,
    required this.marginInitial,
    required this.marginLevel,
    required this.marginLeverage,
    required this.marginMaintenance,
    required this.profit,
    required this.soActivation,
    required this.soEquity,
    required this.soLevel,
    required this.soMargin,
    required this.soTime,
    required this.storage,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      assets: (json['Assets'] ?? 0.0).toDouble(),
      balance: (json['Balance'] ?? 0.0).toDouble(),
      blockedCommission: (json['BlockedCommission'] ?? 0.0).toDouble(),
      blockedProfit: (json['BlockedProfit'] ?? 0.0).toDouble(),
      credit: (json['Credit'] ?? 0.0).toDouble(),
      currencyDigits: json['CurrencyDigits'] ?? 2,
      equity: (json['Equity'] ?? 0.0).toDouble(),
      floating: (json['Floating'] ?? 0.0).toDouble(),
      liabilities: (json['Liabilities'] ?? 0.0).toDouble(),
      login: json['Login'] ?? 0,
      margin: (json['Margin'] ?? 0.0).toDouble(),
      marginFree: (json['MarginFree'] ?? 0.0).toDouble(),
      marginInitial: (json['MarginInitial'] ?? 0.0).toDouble(),
      marginLevel: (json['MarginLevel'] ?? 0.0).toDouble(),
      marginLeverage: json['MarginLeverage'] ?? 0,
      marginMaintenance: (json['MarginMaintenance'] ?? 0.0).toDouble(),
      profit: (json['Profit'] ?? 0.0).toDouble(),
      soActivation: (json['SOActivation'] ?? 0.0).toDouble(),
      soEquity: (json['SOEquity'] ?? 0.0).toDouble(),
      soLevel: (json['SOLevel'] ?? 0.0).toDouble(),
      soMargin: (json['SOMargin'] ?? 0.0).toDouble(),
      soTime: (json['SOTime'] ?? 0.0).toDouble(),
      storage: (json['Storage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Assets': assets,
      'Balance': balance,
      'BlockedCommission': blockedCommission,
      'BlockedProfit': blockedProfit,
      'Credit': credit,
      'CurrencyDigits': currencyDigits,
      'Equity': equity,
      'Floating': floating,
      'Liabilities': liabilities,
      'Login': login,
      'Margin': margin,
      'MarginFree': marginFree,
      'MarginInitial': marginInitial,
      'MarginLevel': marginLevel,
      'MarginLeverage': marginLeverage,
      'MarginMaintenance': marginMaintenance,
      'Profit': profit,
      'SOActivation': soActivation,
      'SOEquity': soEquity,
      'SOLevel': soLevel,
      'SOMargin': soMargin,
      'SOTime': soTime,
      'Storage': storage,
    };
  }
}
