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
  });

  factory MT5Account.fromJson(Map<String, dynamic> json) {
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
      isCentAccount: json['is_cent_account'] ?? false,
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
    };
  }

  // Helper method to check if this is a real account
  bool get isRealAccount => accountType == 'live';

  // Helper method to check if this is a demo account
  bool get isDemoAccount => accountType == 'demo';

  // Helper method to check if this is the primary account
  bool get isPrimaryAccount => primaryAccount == 1;

  // Helper method to check if this is a scratchcard account
  bool get isScratchCardAccount => masterGroupId.toLowerCase() == 'scratchcard';
}
