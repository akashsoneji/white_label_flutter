class TradeHistoryResponse {
  final String message;
  final bool status;
  final List<TradeHistoryItem> data;
  final PaginationInfo pagination;
  final TradeHistoryTotals? totals;
  final TradeHistorySummary? summary;

  TradeHistoryResponse({
    required this.message,
    required this.status,
    required this.data,
    required this.pagination,
    this.totals,
    this.summary,
  });

  factory TradeHistoryResponse.fromJson(Map<String, dynamic> json) {
    final dataField = json['data'];
    List<TradeHistoryItem> tradeHistoryItems;
    Map<String, dynamic> paginationData;
    Map<String, dynamic>? totalsData;
    Map<String, dynamic>? summaryData;

    if (dataField is List<dynamic>) {
      // Flat structure: data is directly a list at root level
      tradeHistoryItems = dataField
          .map((item) => TradeHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
      paginationData = json['pagination'] as Map<String, dynamic>? ?? {};
      totalsData  = json['totals']  as Map<String, dynamic>?;
      summaryData = json['summary'] as Map<String, dynamic>?;
    } else if (dataField is Map<String, dynamic>) {
      // Nested structure (backward compatibility)
      final nestedData = dataField['data'] as List<dynamic>?;
      tradeHistoryItems = nestedData
              ?.map((item) => TradeHistoryItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
      paginationData = dataField['pagination'] as Map<String, dynamic>? ?? {};
      totalsData  = dataField['totals']  as Map<String, dynamic>?;
      summaryData = dataField['summary'] as Map<String, dynamic>?;
    } else {
      tradeHistoryItems = [];
      paginationData = json['pagination'] as Map<String, dynamic>? ?? {};
      totalsData  = json['totals']  as Map<String, dynamic>?;
      summaryData = json['summary'] as Map<String, dynamic>?;
    }

    return TradeHistoryResponse(
      message: json['message'] ?? '',
      status: json['status'] ?? false,
      data: tradeHistoryItems,
      pagination: PaginationInfo.fromJson(paginationData),
      totals:  totalsData  != null ? TradeHistoryTotals.fromJson(totalsData)   : null,
      summary: summaryData != null ? TradeHistorySummary.fromJson(summaryData) : null,
    );
  }
}

class TradeHistoryItem {
  final int    mt5Account;
  final int    tradePositionId;
  final String tradeType;
  final String tradeSymbol;
  /// Stored as raw string from API; use [volume] getter for numeric value.
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

  /// Parses [tradeVolume] to double and returns it.
  double get volume => _parseNumericValue(tradeVolume);

  /// Volume formatted to 2 decimal places (e.g. "0.01000000" → "0.01").
  String get volumeFormatted => volume.toStringAsFixed(2);

  /// Volume formatted to 8 decimal places matching MT5 display style (e.g. "0.01000000").
  String get volumeDisplay => volume.toStringAsFixed(8);

  factory TradeHistoryItem.fromJson(Map<String, dynamic> json) {
    String _getProfitValue(Map<String, dynamic> j) {
      final tp = j['trade_profit'];
      if (tp != null) return tp.toString();
      final p = j['profit'];
      if (p != null) return p.toString();
      return '0';
    }

    return TradeHistoryItem(
      mt5Account:      _parseIntValue(json['mt5_account']),
      tradePositionId: _parseIntValue(json['trade_position_id']),
      // Support both 'trade_type' and 'action' keys
      tradeType:       json['trade_type'] ?? json['action'] ?? '',
      tradeSymbol:     json['trade_symbol'] ?? '',
      tradeVolume:     json['trade_volume']?.toString() ?? '0',
      tradePriceOrder: json['trade_price_order']?.toString() ?? '0',
      tradeOpenTime:   json['trade_open_time']  ?? '',
      tradeCloseTime:  json['trade_close_time'] ?? '',
      tradePriceClose: json['trade_price_close']?.toString() ?? '0',
      tradeProfit:     _getProfitValue(json),
      tradePriceTp:    json['trade_price_tp']?.toString() ?? '0',
      tradePriceSl:    json['trade_price_sl']?.toString() ?? '0',
      tradeCommission: json['trade_commission']?.toString() ?? '0',
      swap:            _parseNumericValue(json['swap']),
      duration:        json['duration'] ?? '',
    );
  }

  static double _parseNumericValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
    return 0.0;
  }

  static int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toTradePositionMap() {
    double _parseStr(String v) {
      if (v.isEmpty || v == '0') return 0.0;
      final cleaned = v.replaceAll(',', '').trim();
      final parsed = double.tryParse(cleaned);
      if (parsed != null) return parsed;
      final m = RegExp(r'-?\d+\.?\d*').firstMatch(cleaned);
      return m != null ? double.tryParse(m.group(0) ?? '0') ?? 0.0 : 0.0;
    }

    final profitValue = _parseStr(tradeProfit);

    String normalizedAction = tradeType;
    final lower = tradeType.toLowerCase().trim();
    if (lower.contains('buy') || lower == '0') {
      normalizedAction = 'Buy';
    } else if (lower.contains('sell') || lower == '1') {
      normalizedAction = 'Sell';
    }

    return {
      'symbol':       tradeSymbol,
      'flag':         _getFlagForSymbol(tradeSymbol),
      'action':       normalizedAction,
      'volume':       volume,           // parsed double, not raw string
      'profitLoss':   profitValue,
      'entryPrice':   tradePriceOrder,
      'currentPrice': tradePriceClose,
      'accountId':    mt5Account.toString(),
      'orderId':      tradePositionId.toString(),
      'isFavorite':   false,
      'openTime':     tradeOpenTime,
      'closeTime':    tradeCloseTime,
      'reason':       '',
      'orderNo':      tradePositionId.toString(),
      'commission':   _parseStr(tradeCommission),
      'swap':         swap,
      'takeProfit':   tradePriceTp,
      'stopLoss':     tradePriceSl,
      'mt5Account':   mt5Account.toString(),
      'time':         tradeCloseTime,
      'duration':     duration,
    };
  }

  String _getFlagForSymbol(String symbol) {
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
  final int    currentPage;
  final int    lastPage;
  final int    perPage;
  final int    total;
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
      currentPage:  json['current_page']  ?? 1,
      lastPage:     json['last_page']     ?? 1,
      perPage:      json['per_page']      ?? 10,
      total:        json['total']         ?? 0,
      nextPageUrl:  json['next_page_url'] as String?,
      prevPageUrl:  json['prev_page_url'] as String?,
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
      balance:    _parseDouble(json['balance']),
      commission: _parseDouble(json['commission']),
      deposit:    _parseDouble(json['deposit']),
      profit:     _parseDouble(json['profit']),
      swap:       _parseDouble(json['swap']),
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

/// Summary metadata returned by the API alongside paginated results.
class TradeHistorySummary {
  final int    filteredCount;
  final int    totalDeals;
  final double totalClosedVolume;

  TradeHistorySummary({
    required this.filteredCount,
    required this.totalDeals,
    required this.totalClosedVolume,
  });

  factory TradeHistorySummary.fromJson(Map<String, dynamic> json) {
    return TradeHistorySummary(
      filteredCount:     _parseInt(json['filtered_count']),
      totalDeals:        _parseInt(json['total_deals']),
      totalClosedVolume: _parseDouble(json['total_closed_volume']),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
