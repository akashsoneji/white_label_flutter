class PmamManagerInvestorDetailResponse {
  final PmamInvestorSummary investor;
  final List<PmamOpenAllocation> openAllocations;
  final List<PmamDistribution> distributions;
  final List<PmamFundEntry> fundEntries;

  const PmamManagerInvestorDetailResponse({
    required this.investor,
    required this.openAllocations,
    required this.distributions,
    required this.fundEntries,
  });

  static PmamManagerInvestorDetailResponse fromApi(dynamic root) {
    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return <String, dynamic>{};
    }

    final data = asMap(asMap(root)['data']);
    final investor = PmamInvestorSummary.fromJson(data['investor']);

    List<Map<String, dynamic>> listOfMaps(dynamic v) {
      if (v is! List) return const [];
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return PmamManagerInvestorDetailResponse(
      investor: investor,
      openAllocations:
          listOfMaps(data['open_allocations']).map(PmamOpenAllocation.fromJson).toList(),
      distributions:
          listOfMaps(data['distributions']).map(PmamDistribution.fromJson).toList(),
      fundEntries:
          listOfMaps(data['fund_entries']).map(PmamFundEntry.fromJson).toList(),
    );
  }
}

class PmamInvestorSummary {
  final int id;
  final String name;
  final String email;
  final String accountNumber;
  final int planId;
  final String planName;
  final double investedAmount;
  final double totalPnl;
  final double currentValue;
  final double allocationPct;
  final String status;

  const PmamInvestorSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.accountNumber,
    required this.planId,
    required this.planName,
    required this.investedAmount,
    required this.totalPnl,
    required this.currentValue,
    required this.allocationPct,
    required this.status,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  factory PmamInvestorSummary.fromJson(dynamic json) {
    final m = (json is Map) ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    return PmamInvestorSummary(
      id: _toInt(m['id']),
      name: (m['investor_name'] ?? '').toString(),
      email: (m['investor_email'] ?? '').toString(),
      accountNumber: (m['account_number'] ?? '').toString(),
      planId: _toInt(m['plan_id']),
      planName: (m['plan_name'] ?? '').toString(),
      investedAmount: _toDouble(m['invested_amount']),
      totalPnl: _toDouble(m['total_pnl']),
      currentValue: _toDouble(m['current_value']),
      allocationPct: _toDouble(m['allocation_pct']),
      status: (m['status'] ?? '').toString(),
    );
  }
}

class PmamOpenAllocation {
  final int id;
  final int positionId;
  final String symbol;
  final int tradeType;
  final double allocatedLot;
  final double allocationPercentage;
  final double openPrice;
  final DateTime? openTime;
  final String status;

  const PmamOpenAllocation({
    required this.id,
    required this.positionId,
    required this.symbol,
    required this.tradeType,
    required this.allocatedLot,
    required this.allocationPercentage,
    required this.openPrice,
    required this.openTime,
    required this.status,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  factory PmamOpenAllocation.fromJson(Map<String, dynamic> m) {
    return PmamOpenAllocation(
      id: _toInt(m['id']),
      positionId: _toInt(m['position_id']),
      symbol: (m['trade_symbol'] ?? '').toString(),
      tradeType: _toInt(m['trade_type']),
      allocatedLot: _toDouble(m['allocated_lot']),
      allocationPercentage: _toDouble(m['allocation_percentage']),
      openPrice: _toDouble(m['open_price']),
      openTime: _parseDate(m['open_time']),
      status: (m['status'] ?? '').toString(),
    );
  }
}

class PmamDistribution {
  final int id;
  final int tradeId;
  final double grossProfitShare;
  final double commissionCharged;
  final double netProfitCredited;
  final DateTime? settledAt;

  const PmamDistribution({
    required this.id,
    required this.tradeId,
    required this.grossProfitShare,
    required this.commissionCharged,
    required this.netProfitCredited,
    required this.settledAt,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  factory PmamDistribution.fromJson(Map<String, dynamic> m) {
    return PmamDistribution(
      id: _toInt(m['id']),
      tradeId: _toInt(m['trade_id']),
      grossProfitShare: _toDouble(m['gross_profit_share']),
      commissionCharged: _toDouble(m['commission_charged']),
      netProfitCredited: _toDouble(m['net_profit_credited']),
      settledAt: _parseDate(m['settled_at']),
    );
  }
}

class PmamFundEntry {
  final int id;
  final double amount;
  final String type;
  final String typeLabel;
  final DateTime? entryTime;
  final String status;

  const PmamFundEntry({
    required this.id,
    required this.amount,
    required this.type,
    required this.typeLabel,
    required this.entryTime,
    required this.status,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  factory PmamFundEntry.fromJson(Map<String, dynamic> m) {
    return PmamFundEntry(
      id: _toInt(m['id']),
      amount: _toDouble(m['amount']),
      type: (m['type'] ?? '').toString(),
      typeLabel: (m['type_label'] ?? '').toString(),
      entryTime: _parseDate(m['entry_time']),
      status: (m['status'] ?? '').toString(),
    );
  }
}