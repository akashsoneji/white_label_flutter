import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:get/get.dart';

class TradeItem {
  final num id;
  final String symbol;
  final String tradeType;
  final num copierVolume;
  final num openPrice;
  final num closePrice;
  final DateTime openTime;
  final DateTime closeTime;
  final num copierProfit;
  final num commissionCharged;
  final num netCredited;
  final String status;

  const TradeItem({
    required this.id,
    required this.symbol,
    required this.tradeType,
    required this.copierVolume,
    required this.openPrice,
    required this.closePrice,
    required this.openTime,
    required this.closeTime,
    required this.copierProfit,
    required this.commissionCharged,
    required this.netCredited,
    required this.status,
  });

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  static DateTime _dt(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  factory TradeItem.fromJson(Map<String, dynamic> json) {
    return TradeItem(
      id: TradeItem._n(json['id']),
      symbol: (json['symbol'] ?? '').toString(),
      tradeType: (json['trade_type'] ?? '').toString(),
      copierVolume: TradeItem._n(json['copier_volume']),
      openPrice: TradeItem._n(json['open_price']),
      closePrice: TradeItem._n(json['close_price']),
      openTime: TradeItem._dt(json['open_time']),
      closeTime: TradeItem._dt(json['close_time']),
      copierProfit: TradeItem._n(json['copier_profit']),
      commissionCharged: TradeItem._n(json['commission_charged']),
      netCredited: TradeItem._n(json['net_credited']),
      status: (json['status'] ?? '').toString(),
    );
  }

  TradeItem copyWith({
    num? id,
    String? symbol,
    String? tradeType,
    num? copierVolume,
    num? openPrice,
    num? closePrice,
    DateTime? openTime,
    DateTime? closeTime,
    num? copierProfit,
    num? commissionCharged,
    num? netCredited,
    String? status,
  }) {
    return TradeItem(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      tradeType: tradeType ?? this.tradeType,
      copierVolume: copierVolume ?? this.copierVolume,
      openPrice: openPrice ?? this.openPrice,
      closePrice: closePrice ?? this.closePrice,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      copierProfit: copierProfit ?? this.copierProfit,
      commissionCharged: commissionCharged ?? this.commissionCharged,
      netCredited: netCredited ?? this.netCredited,
      status: status ?? this.status,
    );
  }
}

class CopierSubscriptionItem {
  final int id;
  final int planId;
  final String planName;
  final String masterName;
  final String masterCode;
  final String serverType;
  final String accountNumber;
  final num capitalAmount;
  final num copyRatio;
  final String copyMethod;
  final num totalPnl;
  final num totalCommissionPaid;
  final int openTrades;
  final String status; // active | paused | stopped

  // Extended fields from API
  final int userId;
  final String userName;
  final String userEmail;
  final String planStatus;
  final num copyRatio2;
  final String sizingMethod;
  final num lotMultiplier;
  final String fixedLotSize;
  final String mirrorRatio;
  final bool isReverse;
  final String riskPercent;
  final String commissionType;
  final num commissionPercentage;
  final num subscriptionFee;
  final String noFeeUntil;
  final String subscriptionStartedAt;
  final String subscriptionLastBilledAt;
  final String activeSince;
  final String pausedAt;
  final String stoppedAt;
  final String createdAt;
  final String updatedAt;
  final bool copyOpenTrades;
  final bool overridesSlTp;
  final String takeProfit;
  final String stopLoss;
  final String slTpMode;
  final String tradingServer;
  final num accountBalance;

  const CopierSubscriptionItem({
    required this.id,
    required this.planId,
    required this.planName,
    required this.masterName,
    required this.masterCode,
    required this.serverType,
    required this.accountNumber,
    required this.capitalAmount,
    required this.copyRatio,
    required this.copyMethod,
    required this.totalPnl,
    required this.totalCommissionPaid,
    required this.openTrades,
    required this.status,
    this.userId = 0,
    this.userName = '',
    this.userEmail = '',
    this.planStatus = '',
    this.copyRatio2 = 0,
    this.sizingMethod = '',
    this.lotMultiplier = 0,
    this.fixedLotSize = '',
    this.mirrorRatio = '',
    this.isReverse = false,
    this.riskPercent = '',
    this.commissionType = '',
    this.commissionPercentage = 0,
    this.subscriptionFee = 0,
    this.noFeeUntil = '',
    this.subscriptionStartedAt = '',
    this.subscriptionLastBilledAt = '',
    this.activeSince = '',
    this.pausedAt = '',
    this.stoppedAt = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.copyOpenTrades = false,
    this.overridesSlTp = false,
    this.takeProfit = '',
    this.stopLoss = '',
    this.slTpMode = '',
    this.tradingServer = '',
    this.accountBalance = 0,
  });

  factory CopierSubscriptionItem.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.toInt() ?? 0;
    }

    num _n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return CopierSubscriptionItem(
      id: _i(json['id']),
      planId: _i(json['plan_id']),
      planName: (json['plan_name'] ?? '').toString(),
      masterName: (json['user_name'] ?? json['master_nickname'] ?? json['master_name']?? '').toString(),
      masterCode: (json['master_code'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? json['meta_account_number'] ?? '').toString(),
      capitalAmount: _n(json['capital_amount']),
      copyRatio: _n(json['copy_ratio'] ?? 1),
      copyMethod: (json['copy_method'] ?? json['copying_method'] ?? '').toString(),
      totalPnl: _n(json['total_pnl']),
      totalCommissionPaid: _n(json['total_commission_paid']),
      openTrades: _i(json['open_trades'] ?? json['open_trades_count']),
      status: (json['status'] ?? '').toString(),
      userId: _i(json['user_id']),
      userName: (json['user_name'] ?? '').toString(),
      userEmail: (json['user_email'] ?? '').toString(),
      planStatus: (json['plan_status'] ?? '').toString(),
      copyRatio2: _n(json['copy_ratio'] ?? 0),
      sizingMethod: (json['sizing_method'] ?? '').toString(),
      lotMultiplier: _n(json['lot_multiplier']),
      fixedLotSize: (json['fixed_lot_size'] ?? '').toString(),
      mirrorRatio: (json['mirror_ratio'] ?? '').toString(),
      isReverse: json['is_reverse'] == true,
      riskPercent: (json['risk_percent'] ?? '').toString(),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionPercentage: _n(json['commission_percentage']),
      subscriptionFee: _n(json['subscription_fee']),
      noFeeUntil: (json['no_fee_until'] ?? '').toString(),
      subscriptionStartedAt: (json['subscription_started_at'] ?? '').toString(),
      subscriptionLastBilledAt: (json['subscription_last_billed_at'] ?? '').toString(),
      activeSince: (json['active_since'] ?? '').toString(),
      pausedAt: (json['paused_at'] ?? '').toString(),
      stoppedAt: (json['stopped_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      copyOpenTrades: json['copy_open_trades'] == true,
      overridesSlTp: json['overrides_sl_tp'] == true,
      takeProfit: (json['take_profit'] ?? '').toString(),
      stopLoss: (json['stop_loss'] ?? '').toString(),
      slTpMode: (json['sl_tp_mode'] ?? '').toString(),
      tradingServer: (json['trading_server'] ?? '').toString(),
      accountBalance: _n(json['account_balance']),
    );
  }

  bool get isActive => status.toLowerCase() == 'active';

  String get formattedActiveSince {
    if (activeSince.isEmpty) return '-';
    try {
      return _formatDate(activeSince);
    } catch (_) {
      return activeSince;
    }
  }

  String get formattedSubscriptionStartedAt {
    if (subscriptionStartedAt.isEmpty) return '-';
    try {
      return _formatDate(subscriptionStartedAt);
    } catch (_) {
      return subscriptionStartedAt;
    }
  }

  static String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String get commissionDisplay {
    if (commissionType == 'per_trade') {
      return TranslationUtils.trArgs('copy_trading_percent_per_trade', {
        'percent': commissionPercentage.toStringAsFixed(0),
      });
    } else if (commissionType == 'subscription') {
      return '\$$subscriptionFee / period';
    }
    return commissionPercentage > 0 ? '${commissionPercentage.toStringAsFixed(0)}%' : '-';
  }
}

class CopyTradingCopierSubscriptionsController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<CopierSubscriptionItem> subscriptions = <CopierSubscriptionItem>[].obs;
  final RxBool actionLoading = false.obs;

  // Summary data from API response
  final RxInt summaryTotal = 0.obs;
  final RxInt summaryPending = 0.obs;
  final RxInt summaryActive = 0.obs;
  final RxInt summaryPaused = 0.obs;
  final RxInt summaryStopped = 0.obs;
  final RxInt summaryCancelled = 0.obs;
  final Rx<num> summaryTotalCapital = 0.0.obs;
  final Rx<num> summaryTotalPnl = 0.0.obs;
  final Rx<num> summaryTotalCommissionPaid = 0.0.obs;

  // Trade history state
  final RxList<TradeItem> trades = <TradeItem>[].obs;
  final RxBool isLoadingTrades = false.obs;
  final RxBool isLoadingMoreTrades = false.obs;
  final RxString tradeError = ''.obs;

  int _tradeCurrentPage = 1;
  int _tradeTotalPages = 1;
  bool get hasMoreTrades => _tradeCurrentPage < _tradeTotalPages;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool get hasMore => _currentPage < _totalPages;

  @override
  void onInit() {
    super.onInit();
    load(showLoading: true);
  }

  Future<void> load({bool showLoading = false}) async {
    _currentPage = 1;
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionsList(page: 1, perPage: 20),
        queryParameters: {'_t': timestamp.toString()},
      );

      if (!res.success || res.data == null) {
        subscriptions.clear();
      errorMessage.value = res.message ??
          TranslationUtils.tr('copy_trading_failed_to_load_subscriptions');
        return;
      }

      final data = res.data?['data'];
      if (data is! List) {
        subscriptions.clear();
      errorMessage.value = TranslationUtils.tr('copy_trading_invalid_response');
        return;
      }

      _totalPages = int.tryParse(res.data?['total_pages']?.toString() ?? '1') ?? 1;
      _totalCount = int.tryParse(res.data?['total']?.toString() ?? '0') ?? 0;

      final list = data
          .whereType<Map>()
          .map((e) => CopierSubscriptionItem.fromJson(e.cast<String, dynamic>()))
          .toList();

      // Compute summary from loaded items
      _computeSummaryFromList(list, isFirstPage: true);
      subscriptions.assignAll(list);
    } catch (e,t) {
      subscriptions.clear();
      print('Load error: $e\n$t');
      errorMessage.value = 'Load error: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore.value) return;
    isLoadingMore.value = true;
    try {
      final nextPage = _currentPage + 1;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionsList(page: nextPage, perPage: 20),
        queryParameters: {'_t': timestamp.toString()},
      );

      if (!res.success || res.data == null) return;

      final data = res.data?['data'];
      if (data is! List) return;

      final list = data
          .whereType<Map>()
          .map((e) => CopierSubscriptionItem.fromJson(e.cast<String, dynamic>()))
          .toList();

      subscriptions.addAll(list);
      _currentPage = nextPage;
      _totalPages = int.tryParse(res.data?['total_pages']?.toString() ?? '1') ?? 1;
      _totalCount = int.tryParse(res.data?['total']?.toString() ?? '0') ?? 0;
      _computeSummaryFromList(list, isFirstPage: false);
    } catch (_) {
    } finally {
      isLoadingMore.value = false;
    }
  }

  void _computeSummaryFromList(List<CopierSubscriptionItem> list, {required bool isFirstPage}) {
    if (isFirstPage) {
      summaryTotal.value = _totalCount;
      summaryTotalCapital.value = list.fold(0.0, (p, e) => p + e.capitalAmount);
      summaryTotalPnl.value = list.fold(0.0, (p, e) => p + e.totalPnl);
      summaryTotalCommissionPaid.value = list.fold(0.0, (p, e) => p + e.totalCommissionPaid);
      summaryPending.value = list.where((e) => e.status.toLowerCase() == 'pending').length;
      summaryActive.value = list.where((e) => e.status.toLowerCase() == 'active').length;
      summaryPaused.value = list.where((e) => e.status.toLowerCase() == 'paused').length;
      summaryStopped.value = list.where((e) => e.status.toLowerCase() == 'stopped').length;
      summaryCancelled.value = list.where((e) => e.status.toLowerCase() == 'cancelled').length;
    } else {
      summaryTotalCapital.value = subscriptions.fold(0.0, (p, e) => p + e.capitalAmount);
      summaryTotalPnl.value = subscriptions.fold(0.0, (p, e) => p + e.totalPnl);
      summaryTotalCommissionPaid.value = subscriptions.fold(0.0, (p, e) => p + e.totalCommissionPaid);
    }
  }

  Future<void> loadTrades() async {
    if (subscriptions.isEmpty) {
      print('>>> loadTrades SKIPPED: subscriptions is empty (count=${subscriptions.length}), will retry...');
      // Retry after a short delay in case subscriptions are still loading
      await Future.delayed(const Duration(milliseconds: 500));
      if (subscriptions.isEmpty) {
        print('>>> loadTrades ABORTED: still no subscriptions');
        return;
      }
    }
    print('>>> loadTrades starting, subscriptionId=${subscriptions.first.id}');
    _tradeCurrentPage = 1;
    isLoadingTrades.value = true;
    tradeError.value = '';
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionTrades(subscriptions.first.id, page: _tradeCurrentPage, t: t),
      );

      if (!res.success || res.data == null) {
        trades.clear();
        tradeError.value = res.message ?? 'Failed to load trades';
        return;
      }

      // Note: res.data = {status, success, message, data: {data: [...], total, current_page, ...}}
      // So res.data?['data'] = {data: [...], total, ...} and res.data?['data']?['data'] = the trades list
      final nestedData = res.data?['data'];
      final data = nestedData is Map ? nestedData['data'] : null;
      if (data is! List) {
        trades.clear();
        tradeError.value = 'Invalid response';
        return;
      }

      trades.value = data
          .whereType<Map>()
          .map((e) => TradeItem.fromJson(e.cast<String, dynamic>()))
          .toList();
      _tradeTotalPages = int.tryParse(nestedData?['total_pages']?.toString() ?? '1') ?? 1;
      print('>>> loadTrades SUCCESS, trades.count=${trades.length}');
    } catch (e) {
      tradeError.value = e.toString();
      print('>>> loadTrades ERROR: $e');
    } finally {
      print('>>> loadTrades done');
      isLoadingTrades.value = false;
    }
  }

  Future<void> loadMoreTrades() async {
    if (subscriptions.isEmpty || !hasMoreTrades || isLoadingMoreTrades.value) return;
    isLoadingMoreTrades.value = true;
    try {
      final nextPage = _tradeCurrentPage + 1;
      final t = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionTrades(subscriptions.first.id, page: nextPage, t: t),
      );

      if (!res.success || res.data == null) return;

      final nestedData = res.data?['data'];
      final data = nestedData is Map ? nestedData['data'] : null;
      if (data is! List) return;

      final list = data
          .whereType<Map>()
          .map((e) => TradeItem.fromJson(e.cast<String, dynamic>()))
          .toList();

      trades.addAll(list);
      _tradeCurrentPage = nextPage;
      _tradeTotalPages = int.tryParse(nestedData?['total_pages']?.toString() ?? '1') ?? 1;
    } catch (_) {
    } finally {
      isLoadingMoreTrades.value = false;
    }
  }

  Future<ApiResponse> pause(int subscriptionId) async {
    actionLoading.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingCopierSubscriptionPause(subscriptionId),
        data: <String, dynamic>{},
      );
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Pause error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> resume(int subscriptionId) async {
    actionLoading.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingCopierSubscriptionResume(subscriptionId),
        data: <String, dynamic>{},
      );
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Resume error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> stop(int subscriptionId) async {
    actionLoading.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingCopierSubscriptionStop(subscriptionId),
        data: <String, dynamic>{},
      );
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Stop error: $e');
    } finally {
      actionLoading.value = false;
    }
  }

  Future<ApiResponse> addCapital({required int subscriptionId, required num amount}) async {
    actionLoading.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingCopierSubscriptionAddCapital(subscriptionId),
        data: <String, dynamic>{'amount': amount},
      );
      if (res.success) await load(showLoading: false);
      return res;
    } catch (e) {
      return ApiResponse.error('Add capital error: $e');
    } finally {
      actionLoading.value = false;
    }
  }
}

