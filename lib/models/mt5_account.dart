bool _parseCentFlag(Map<String, dynamic> json) {
  final raw = json['is_cent_account'];
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final v = raw.toLowerCase().trim();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no' || v == '') {
      // fall through to currency/group heuristics
    }
  }
  final currency = (json['currency'] ?? '').toString().toUpperCase();
  if (currency == 'USC' || currency == 'CENT') return true;
  final group = (json['mt5_group_name'] ?? json['masterGroupId'] ?? '')
      .toString()
      .toLowerCase();
  if (group.contains('cent') || group.contains('usc')) return true;
  return false;
}

bool _parseFlag(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final v = raw.toLowerCase().trim();
    return v == 'true' || v == '1' || v == 'yes';
  }
  return false;
}

/// Single badge shown on an account card, from `enrollment` in
/// mt5accounts/get. Declared in the web portal's priority order.
enum AccountEnrollmentKind { pmamPool, pmamInvestor, copyMaster, copySlave, demoContest }

class MT5Account {
  final int userId;
  final String metaAccountNumber;
  final String mt5NickName;
  final String masterGroupId;
  final String mt5GroupName; // Added field for MT5 group name
  final int leverageId;
  final int primaryAccount;
  final String accountType;
  final String balance;
  final String credit;
  final String equity;
  final String margin;
  final String freeMargin;
  final String marginLevel;
  final String profit;
  final int totalDeposit;
  final int totalWithdrawal;
  final int commission;
  final int swap;
  final String tradingServer;
  final String currency;
  final bool isActive;
  final bool isCentAccount;
  final String? tradingPlatform;
  final double minimumTradeSize;
  final double maxLotSize;
  final bool leverageChangeAllowed;
  final int leverageMin;
  final int leverageMax;
  final List<int> leverageOptions;
  final bool pmamInvestor;
  final bool pmamPool;
  final bool copyMaster;
  final bool copySlave;
  final String demoContestName;

  MT5Account({
    required this.isActive,
    required this.userId,
    required this.metaAccountNumber,
    required this.mt5NickName,
    required this.masterGroupId,
    required this.mt5GroupName,
    required this.leverageId,
    required this.primaryAccount,
    required this.accountType,
    required this.balance,
    required this.credit,
    required this.equity,
    required this.margin,
    required this.freeMargin,
    required this.marginLevel,
    required this.profit,
    required this.totalDeposit,
    required this.totalWithdrawal,
    required this.commission,
    required this.swap,
    required this.tradingServer,
    required this.currency,
    required this.isCentAccount,
    this.tradingPlatform,
    this.minimumTradeSize = 0.01,
    this.maxLotSize = 100.0,
    this.leverageChangeAllowed = false,
    this.leverageMin = 100,
    this.leverageMax = 500,
    this.leverageOptions = const [],
    this.pmamInvestor = false,
    this.pmamPool = false,
    this.copyMaster = false,
    this.copySlave = false,
    this.demoContestName = '',
  });

  factory MT5Account.fromJson(Map<String, dynamic> json) {
    final enrollment = json['enrollment'] is Map
        ? Map<String, dynamic>.from(json['enrollment'] as Map)
        : const <String, dynamic>{};
    return MT5Account(
      userId: _parseInt(json['user_id']) ?? 0,
      metaAccountNumber: json['meta_account_number']?.toString() ?? '',
      mt5NickName: json['mt5_nick_name']?.toString() ?? '',
      masterGroupId: json['master_group_id']?.toString() ?? '',
      mt5GroupName: json['mt5_group_name']?.toString() ?? '',
      leverageId: _parseInt(json['leverage_id']) ?? 0,
      primaryAccount: _parseInt(json['primary_account']) ?? 0,
      accountType: json['account_type']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '0.00',
      credit: json['credit']?.toString() ?? '0.00',
      equity: json['equity']?.toString() ?? '0.00',
      margin: json['margin']?.toString() ?? '0.00',
      freeMargin: json['free_margin']?.toString() ?? '0.00',
      marginLevel: json['margin_level']?.toString() ?? '0.00',
      profit: json['profit']?.toString() ?? '0.00',
      totalDeposit: _parseInt(json['total_deposit']) ?? 0,
      totalWithdrawal: _parseInt(json['total_withdrawal']) ?? 0,
      commission: _parseInt(json['commission']) ?? 0,
      swap: _parseInt(json['swap']) ?? 0,
      tradingServer: json['trading_server']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'USD',
      isActive: json['is_active'] ?? false,
      isCentAccount: _parseCentFlag(json),
      tradingPlatform: json['trading_platform']?.toString(),
      minimumTradeSize: _parseDouble(json['minimum_trade_size']) ?? 0.01,
      maxLotSize: _parseDouble(json['max_lot_size']) ?? 100.0,
      leverageChangeAllowed: json['leverage_change_allowed'] ?? false,
      leverageMin: _parseInt(json['leverage_min']) ?? 100,
      leverageMax: _parseInt(json['leverage_max']) ?? 500,
      leverageOptions: (json['leverage_options'] as List?)
              ?.map((e) => _parseInt(e))
              .whereType<int>()
              .toList() ??
          const [],
      pmamInvestor: _parseFlag(enrollment['pmam_investor']),
      pmamPool: _parseFlag(enrollment['pmam_pool']),
      copyMaster: _parseFlag(enrollment['copy_master']),
      copySlave: _parseFlag(enrollment['copy_slave']),
      demoContestName: enrollment['demo_contest_name']?.toString().trim() ?? '',
    );
  }

  // Helper method to safely parse int from dynamic value
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) return value.toInt();
    return null;
  }

  // Helper method to safely parse double from dynamic value
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'meta_account_number': metaAccountNumber,
      'mt5_nick_name': mt5NickName,
      'master_group_id': masterGroupId,
      'mt5_group_name': mt5GroupName,
      'leverage_id': leverageId,
      'primary_account': primaryAccount,
      'account_type': accountType,
      'balance': balance,
      'credit': credit,
      'equity': equity,
      'margin': margin,
      'free_margin': freeMargin,
      'margin_level': marginLevel,
      'profit': profit,
      'total_deposit': totalDeposit,
      'total_withdrawal': totalWithdrawal,
      'commission': commission,
      'swap': swap,
      'trading_server': tradingServer,
      'currency': currency,
      'is_active': isActive,
      'is_cent_account': isCentAccount,
      'trading_platform': tradingPlatform,
      'minimum_trade_size': minimumTradeSize,
      'max_lot_size': maxLotSize,
      'leverage_change_allowed': leverageChangeAllowed,
      'leverage_min': leverageMin,
      'leverage_max': leverageMax,
      'leverage_options': leverageOptions,
      'enrollment': {
        'pmam_investor': pmamInvestor,
        'pmam_pool': pmamPool,
        'copy_master': copyMaster,
        'copy_slave': copySlave,
        'demo_contest_name': demoContestName,
      },
    };
  }

  /// First flag that is set, in the web portal's order; null shows no badge.
  AccountEnrollmentKind? get enrollmentBadge {
    if (pmamPool) return AccountEnrollmentKind.pmamPool;
    if (pmamInvestor) return AccountEnrollmentKind.pmamInvestor;
    if (copyMaster) return AccountEnrollmentKind.copyMaster;
    if (copySlave) return AccountEnrollmentKind.copySlave;
    if (demoContestName.isNotEmpty) return AccountEnrollmentKind.demoContest;
    return null;
  }

  // Helper method to check if this is a real account
  bool get isRealAccount => accountType == 'live';

  // Helper method to check if this is a demo account
  bool get isDemoAccount => accountType == 'demo';

  // Helper method to check if this is the primary account
  bool get isPrimaryAccount => primaryAccount == 1;

  // Helper method to check if this is a scratchcard account
  bool get isScratchCardAccount => masterGroupId.toLowerCase() == 'scratchcard';

  /// Returns the formatted display name of the account's trading platform
  /// (e.g., 'MT5', 'MT4', 'Vertex', 'ActTrader', etc.).
  String get platformDisplayName {
    final raw = tradingPlatform?.trim();
    if (raw != null && raw.isNotEmpty) {
      final upper = raw.toUpperCase();
      if (upper == 'MT5' || upper == 'MT4') return upper;
      if (upper == 'WEB_TRADER' || upper == 'WEBTRADER') return 'WebTrader';
      if (upper == 'ACT_TRADER' || upper == 'ACTTRADER') return 'ActTrader';
      if (upper == 'VERTEX') return 'Vertex';
      if (upper == 'CTRADER') return 'cTrader';
      return raw;
    }

    final lowerServer = tradingServer.toLowerCase();
    final lowerGroup = mt5GroupName.toLowerCase();
    final lowerMaster = masterGroupId.toLowerCase();
    final lowerNick = mt5NickName.toLowerCase();

    if (lowerServer.contains('mt4') ||
        lowerGroup.contains('mt4') ||
        lowerMaster.contains('mt4') ||
        lowerNick.contains('mt4')) {
      return 'MT4';
    }
    if (lowerServer.contains('vertex') || lowerGroup.contains('vertex')) {
      return 'Vertex';
    }
    if (lowerServer.contains('acttrader') || lowerGroup.contains('acttrader')) {
      return 'ActTrader';
    }
    if (lowerServer.contains('ctrader') || lowerGroup.contains('ctrader')) {
      return 'cTrader';
    }

    // Default to MT5 as this is an MT5Account model from mt5accounts/get
    return 'MT5';
  }

  bool get isMT5 => platformDisplayName.toUpperCase() == 'MT5';

  MT5Account copyWith({
    int? userId,
    String? metaAccountNumber,
    String? mt5NickName,
    String? masterGroupId,
    String? mt5GroupName,
    int? leverageId,
    int? primaryAccount,
    String? accountType,
    String? balance,
    String? credit,
    String? equity,
    String? margin,
    String? freeMargin,
    String? marginLevel,
    String? profit,
    int? totalDeposit,
    int? totalWithdrawal,
    int? commission,
    int? swap,
    String? tradingServer,
    String? currency,
    bool? isActive,
    bool? isCentAccount,
    String? tradingPlatform,
    double? minimumTradeSize,
    double? maxLotSize,
    bool? leverageChangeAllowed,
    int? leverageMin,
    int? leverageMax,
    List<int>? leverageOptions,
    bool? pmamInvestor,
    bool? pmamPool,
    bool? copyMaster,
    bool? copySlave,
    String? demoContestName,
  }) {
    return MT5Account(
      userId: userId ?? this.userId,
      metaAccountNumber: metaAccountNumber ?? this.metaAccountNumber,
      mt5NickName: mt5NickName ?? this.mt5NickName,
      masterGroupId: masterGroupId ?? this.masterGroupId,
      mt5GroupName: mt5GroupName ?? this.mt5GroupName,
      leverageId: leverageId ?? this.leverageId,
      primaryAccount: primaryAccount ?? this.primaryAccount,
      accountType: accountType ?? this.accountType,
      balance: balance ?? this.balance,
      credit: credit ?? this.credit,
      equity: equity ?? this.equity,
      margin: margin ?? this.margin,
      freeMargin: freeMargin ?? this.freeMargin,
      marginLevel: marginLevel ?? this.marginLevel,
      profit: profit ?? this.profit,
      totalDeposit: totalDeposit ?? this.totalDeposit,
      totalWithdrawal: totalWithdrawal ?? this.totalWithdrawal,
      commission: commission ?? this.commission,
      swap: swap ?? this.swap,
      tradingServer: tradingServer ?? this.tradingServer,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      isCentAccount: isCentAccount ?? this.isCentAccount,
      tradingPlatform: tradingPlatform ?? this.tradingPlatform,
      minimumTradeSize: minimumTradeSize ?? this.minimumTradeSize,
      maxLotSize: maxLotSize ?? this.maxLotSize,
      leverageChangeAllowed: leverageChangeAllowed ?? this.leverageChangeAllowed,
      leverageMin: leverageMin ?? this.leverageMin,
      leverageMax: leverageMax ?? this.leverageMax,
      leverageOptions: leverageOptions ?? this.leverageOptions,
      pmamInvestor: pmamInvestor ?? this.pmamInvestor,
      pmamPool: pmamPool ?? this.pmamPool,
      copyMaster: copyMaster ?? this.copyMaster,
      copySlave: copySlave ?? this.copySlave,
      demoContestName: demoContestName ?? this.demoContestName,
    );
  }
}
