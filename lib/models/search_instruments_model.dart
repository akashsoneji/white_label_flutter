class SearchInstrumentsResponse {
  final bool status;
  final bool success;
  final String message;
  final SearchInstrumentsData? data;

  SearchInstrumentsResponse({
    required this.status,
    required this.success,
    required this.message,
    this.data,
  });

  factory SearchInstrumentsResponse.fromJson(Map<String, dynamic> json) {
    return SearchInstrumentsResponse(
      status: json['status'] ?? false,
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? SearchInstrumentsData.fromJson(json['data']) : null,
    );
  }
}

class SearchInstrumentsData {
  final List<SearchSymbol> symbols;
  final List<InstrumentsDataCategory> categories;
  final String? tradingAccount;

  SearchInstrumentsData({
    required this.symbols,
    this.categories = const [],
    this.tradingAccount,
  });

  factory SearchInstrumentsData.fromJson(Map<String, dynamic> json) {
    return SearchInstrumentsData(
      symbols: (json['symbols'] as List? ?? [])
          .map((item) => SearchSymbol.fromJson(item as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List? ?? [])
          .map((e) =>
              InstrumentsDataCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      tradingAccount: json['trading_account']?.toString(),
    );
  }
}

class InstrumentsDataCategory {
  final int id;
  final String name;

  InstrumentsDataCategory({required this.id, required this.name});

  factory InstrumentsDataCategory.fromJson(Map<String, dynamic> json) {
    return InstrumentsDataCategory(
      id: _parseIntFlexible(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

int _parseIntFlexible(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    final t = value.trim();
    if (t.isEmpty) return 0;
    return int.tryParse(t) ?? double.tryParse(t)?.toInt() ?? 0;
  }
  return 0;
}

double _parseDoubleFlexible(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final t = value.trim();
    if (t.isEmpty) return 0.0;
    return double.tryParse(t) ?? 0.0;
  }
  return 0.0;
}

class SearchSymbol {
  final int symbolId;
  final String displaySymbol;
  final String datafeedSymbol;
  final String name;
  final int categoryId;
  final String categoryName;
  final int digits;
  final double contractSize;
  final bool isActive;
  final bool isSynced;
  final int lpProviderId;
  final int groupId;
  final SpreadConfig spreadConfig;
  final int stopsLevel;

  SearchSymbol({
    required this.symbolId,
    required this.displaySymbol,
    required this.datafeedSymbol,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.digits,
    required this.contractSize,
    required this.isActive,
    required this.isSynced,
    required this.lpProviderId,
    required this.groupId,
    required this.spreadConfig,
    required this.stopsLevel,
  });

  factory SearchSymbol.fromJson(Map<String, dynamic> json) {
    return SearchSymbol(
      symbolId: _parseIntFlexible(json['symbol_id']),
      displaySymbol: json['display_symbol']?.toString() ?? '',
      datafeedSymbol: json['datafeed_symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      categoryId: _parseIntFlexible(json['category_id']),
      categoryName: json['category_name']?.toString() ?? '',
      digits: _parseIntFlexible(json['digits']),
      contractSize: _parseDoubleFlexible(json['contract_size']),
      isActive: json['is_active'] == true,
      isSynced: json['is_synced'] == true,
      lpProviderId: _parseIntFlexible(json['lp_provider_id']),
      groupId: _parseIntFlexible(json['group_id']),
      spreadConfig: SpreadConfig.fromJson(
        (json['spread_config'] is Map<String, dynamic>)
            ? json['spread_config'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      stopsLevel: _parseIntFlexible(json['stops_level']),
    );
  }
}

class SpreadConfig {
  final double spreadDiff;
  final double bidAdjustment;
  final double askAdjustment;
  final String source;

  SpreadConfig({
    required this.spreadDiff,
    required this.bidAdjustment,
    required this.askAdjustment,
    required this.source,
  });

  factory SpreadConfig.fromJson(Map<String, dynamic> json) {
    return SpreadConfig(
      spreadDiff: _parseDoubleFlexible(json['spread_diff']),
      bidAdjustment: _parseDoubleFlexible(json['bid_adjustment']),
      askAdjustment: _parseDoubleFlexible(json['ask_adjustment']),
      source: json['source']?.toString() ?? 'none',
    );
  }
}
