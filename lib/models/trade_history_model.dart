class TradeHistoryResponse {
  final String message;
  final bool status;
  final List<TradeHistoryItem> data;
  final PaginationInfo pagination;
  final TradeHistoryTotals? totals;

  TradeHistoryResponse({
    required this.message,
    required this.status,
    required this.data,
    required this.pagination,
    this.totals,
  });

  factory TradeHistoryResponse.fromJson(Map<String, dynamic> json) {
    // ✅ SIMPLIFIED: Handle flat structure from Laravel API
    // New structure: data (array), pagination, totals, summary at root level
    // Also support nested structure for backward compatibility
    
    final dataField = json['data'];
    List<TradeHistoryItem> tradeHistoryItems;
    Map<String, dynamic> paginationData;
    Map<String, dynamic>? totalsData;

    if (dataField is List<dynamic>) {
      // ✅ NEW FLAT STRUCTURE: data is directly a list at root level
      tradeHistoryItems =
          dataField
              .map(
                (item) =>
                    TradeHistoryItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
      // Pagination and totals are at root level
      paginationData = json['pagination'] as Map<String, dynamic>? ?? {};
      totalsData = json['totals'] as Map<String, dynamic>?;
    } else if (dataField is Map<String, dynamic>) {
      // Nested structure (backward compatibility): data.data, data.pagination, data.totals
      final nestedData = dataField['data'] as List<dynamic>?;
      tradeHistoryItems =
          nestedData
              ?.map(
                (item) =>
                    TradeHistoryItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [];
      paginationData = dataField['pagination'] as Map<String, dynamic>? ?? {};
      totalsData = dataField['totals'] as Map<String, dynamic>?;
    } else {
      // Fallback: empty data
      tradeHistoryItems = [];
      paginationData = json['pagination'] as Map<String, dynamic>? ?? {};
      totalsData = json['totals'] as Map<String, dynamic>?;
    }

    return TradeHistoryResponse(
      message: json['message'] ?? '',
      status: json['status'] ?? false,
      data: tradeHistoryItems,
      pagination: PaginationInfo.fromJson(paginationData),
      totals:
          totalsData != null ? TradeHistoryTotals.fromJson(totalsData) : null,
    );
  }
}

class TradeHistoryItem {
  final int mt5Account;
  final int tradePositionId;
  final String tradeType;
  final String tradeSymbol;
  final String tradeVolume;
  final String tradePriceOrder;
  final String tradeOpenTime;
  final String tradeCloseTime;
  final String tradePriceClose;
  final String tradeProfit;
  final String tradePriceTp;
  final String tradePriceSl;
  final String tradeCommission;
  final double swap;
  final String duration;

  TradeHistoryItem({
    required this.mt5Account,
    required this.tradePositionId,
    required this.tradeType,
    required this.tradeSymbol,
    required this.tradeVolume,
    required this.tradePriceOrder,
    required this.tradeOpenTime,
    required this.tradeCloseTime,
    required this.tradePriceClose,
    required this.tradeProfit,
    required this.tradePriceTp,
    required this.tradePriceSl,
    required this.tradeCommission,
    required this.swap,
    required this.duration,
  });

  factory TradeHistoryItem.fromJson(Map<String, dynamic> json) {
    // Helper to get profit value with fallback
    String _getProfitValue(Map<String, dynamic> json) {
      // Try trade_profit first, then profit, then default to '0'
      final tradeProfit = json['trade_profit'];
      if (tradeProfit != null) {
        return tradeProfit.toString();
      }
      final profit = json['profit'];
      if (profit != null) {
        return profit.toString();
      }
      return '0';
    }

    return TradeHistoryItem(
      mt5Account: _parseIntValue(json['mt5_account']),
      tradePositionId: _parseIntValue(json['trade_position_id']),
      tradeType: json['trade_type'] ?? '',
      tradeSymbol: json['trade_symbol'] ?? '',
      tradeVolume: json['trade_volume'] ?? '0',
      tradePriceOrder: json['trade_price_order'] ?? '0',
      tradeOpenTime: json['trade_open_time'] ?? '',
      tradeCloseTime: json['trade_close_time'] ?? '',
      tradePriceClose: json['trade_price_close'] ?? '0',
      tradeProfit: _getProfitValue(json),
      tradePriceTp: json['trade_price_tp'] ?? '0',
      tradePriceSl: json['trade_price_sl'] ?? '0',
      tradeCommission: json['trade_commission'] ?? '0',
      swap: _parseNumericValue(json['swap']),
      duration: json['duration'] ?? '',
    );
  }

  static double _parseNumericValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Convert to TradePosition for compatibility with existing UI
  Map<String, dynamic> toTradePositionMap() {
    // Helper to parse numeric strings, removing commas if present
    double _parseNumericString(String value) {
      if (value.isEmpty || value == '0') return 0.0;
      // Remove commas and any whitespace, then parse
      final cleaned = value.replaceAll(',', '').trim();
      // Handle negative values correctly
      final parsed = double.tryParse(cleaned);
      if (parsed == null) {
        // If parsing fails, try to extract number from string
        final numberMatch = RegExp(r'-?\d+\.?\d*').firstMatch(cleaned);
        if (numberMatch != null) {
          return double.tryParse(numberMatch.group(0) ?? '0') ?? 0.0;
        }
        return 0.0;
      }
      return parsed;
    }

    // Parse profit with special handling
    final profitValue = _parseNumericString(tradeProfit);

    // Normalize tradeType to "Buy" or "Sell" for filtering
    String normalizedAction = tradeType;
    final tradeTypeLower = tradeType.toLowerCase().trim();
    if (tradeTypeLower.contains('buy') || tradeTypeLower == '0') {
      normalizedAction = 'Buy';
    } else if (tradeTypeLower.contains('sell') || tradeTypeLower == '1') {
      normalizedAction = 'Sell';
    } else {
      // Default fallback - keep original if can't determine
      normalizedAction = tradeType;
    }

    return {
      'symbol': tradeSymbol,
      'flag': _getFlagForSymbol(tradeSymbol),
      'action': normalizedAction,
      'volume': _parseNumericString(tradeVolume),
      'profitLoss': profitValue, // Ensure profit is correctly parsed
      'entryPrice': tradePriceOrder,
      'currentPrice': tradePriceClose,
      'accountId': mt5Account.toString(),
      'orderId': tradePositionId.toString(),
      'isFavorite': false,
      'openTime': tradeOpenTime,
      'closeTime': tradeCloseTime,
      'reason': '',
      'orderNo': tradePositionId.toString(),
      'commission': _parseNumericString(tradeCommission),
      'swap': swap,
      'takeProfit': tradePriceTp,
      'stopLoss': tradePriceSl,
      'mt5Account': mt5Account.toString(),
      'time': tradeCloseTime,
      'duration': duration,
    };
  }

  String _getFlagForSymbol(String symbol) {
    // Map common symbols to flags
    if (symbol.contains('EUR')) return '🇪🇺';
    if (symbol.contains('USD')) return '🇺🇸';
    if (symbol.contains('GBP')) return '🇬🇧';
    if (symbol.contains('JPY')) return '🇯🇵';
    if (symbol.contains('AUD')) return '🇦🇺';
    if (symbol.contains('CAD')) return '🇨🇦';
    if (symbol.contains('CHF')) return '🇨🇭';
    if (symbol.contains('XAU')) return '🥇';
    if (symbol.contains('XAG')) return '🥈';
    if (symbol.contains('BTC')) return '₿';
    if (symbol.contains('ETH')) return 'Ξ';
    return '📈';
  }
}

class PaginationInfo {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final String? nextPageUrl;
  final String? prevPageUrl;

  PaginationInfo({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 10,
      total: json['total'] ?? 0,
      nextPageUrl: json['next_page_url'],
      prevPageUrl: json['prev_page_url'],
    );
  }

  bool get hasNextPage => currentPage < lastPage;
  bool get hasPrevPage => currentPage > 1;
}

class TradeHistoryTotals {
  final double balance;
  final double commission;
  final double deposit;
  final double profit;
  final double swap;
  final double withdrawal;

  TradeHistoryTotals({
    required this.balance,
    required this.commission,
    required this.deposit,
    required this.profit,
    required this.swap,
    required this.withdrawal,
  });

  factory TradeHistoryTotals.fromJson(Map<String, dynamic> json) {
    return TradeHistoryTotals(
      balance: _parseDouble(json['balance']),
      commission: _parseDouble(json['commission']),
      deposit: _parseDouble(json['deposit']),
      profit: _parseDouble(json['profit']),
      swap: _parseDouble(json['swap']),
      withdrawal: _parseDouble(json['withdrawal']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
