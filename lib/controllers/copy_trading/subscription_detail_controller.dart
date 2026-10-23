import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:get/get.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionDetail {
  final int id;
  final int planId;
  final String planName;
  final String masterName;
  final String masterCode;
  final String commissionType;
  final num commissionPercentage;
  final String accountNumber;
  final String accountCurrency;
  final num capitalAmount;
  final num copyRatio;
  final String copyMethod;
  final String sizingMethod;
  final num totalPnl;
  final num totalCommissionPaid;
  final num pendingCommission;
  final num netPnl;
  final int openTradesCount;
  final int closedTradesCount;
  final String status;
  final String masterStatus;
  final String activeSince;
  final String stoppedAt;
  final num lotMultiplier;

  const SubscriptionDetail({
    required this.id,
    required this.planId,
    required this.planName,
    required this.masterName,
    required this.masterCode,
    required this.commissionType,
    required this.commissionPercentage,
    required this.accountNumber,
    required this.accountCurrency,
    required this.capitalAmount,
    required this.copyRatio,
    required this.copyMethod,
    required this.sizingMethod,
    required this.totalPnl,
    required this.totalCommissionPaid,
    required this.pendingCommission,
    required this.netPnl,
    required this.openTradesCount,
    required this.closedTradesCount,
    required this.status,
    required this.masterStatus,
    required this.activeSince,
    required this.stoppedAt,
    required this.lotMultiplier,
  });

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory SubscriptionDetail.fromJson(Map<String, dynamic> json) {
    return SubscriptionDetail(
      id: _i(json['id']),
      planId: _i(json['plan_id']),
      planName: (json['plan_name'] ?? '').toString(),
      masterName: (json['master_name'] ?? '').toString(),
      masterCode: (json['master_code'] ?? '').toString(),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionPercentage: _n(json['commission_percentage']),
      accountNumber: (json['account_number'] ?? '').toString(),
      accountCurrency: (json['account_currency'] ?? '').toString(),
      capitalAmount: _n(json['capital_amount']),
      copyRatio: _n(json['copy_ratio']),
      copyMethod: (json['copy_method'] ?? '').toString(),
      sizingMethod: (json['sizing_method'] ?? '').toString(),
      totalPnl: _n(json['total_pnl']),
      totalCommissionPaid: _n(json['total_commission_paid']),
      pendingCommission: _n(json['pending_commission']),
      netPnl: _n(json['net_pnl']),
      openTradesCount: _i(json['open_trades_count']),
      closedTradesCount: _i(json['closed_trades_count']),
      status: (json['status'] ?? '').toString(),
      masterStatus: (json['master_status'] ?? '').toString(),
      activeSince: (json['active_since'] ?? '').toString(),
      stoppedAt: (json['stopped_at'] ?? '').toString(),
      lotMultiplier: _n(json['lot_multiplier']),
    );
  }
}

class PnlHistoryItem {
  final int id;
  final String symbol;
  final num grossProfitShare;
  final num commissionCharged;
  final num commissionAccruedDisplay;
  final num netCredited;
  final String status;
  final String settledAt;

  const PnlHistoryItem({
    required this.id,
    required this.symbol,
    required this.grossProfitShare,
    required this.commissionCharged,
    required this.commissionAccruedDisplay,
    required this.netCredited,
    required this.status,
    required this.settledAt,
  });

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  factory PnlHistoryItem.fromJson(Map<String, dynamic> json) {
    return PnlHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      symbol: (json['symbol'] ?? '').toString(),
      grossProfitShare: _n(json['gross_profit_share']),
      commissionCharged: _n(json['commission_charged']),
      commissionAccruedDisplay: _n(json['commission_accrued_display']),
      netCredited: _n(json['net_credited']),
      status: (json['status'] ?? '').toString(),
      settledAt: (json['settled_at'] ?? '').toString(),
    );
  }
}

class TradeDetail {
  final int id;
  final String symbol;
  final String tradeType;
  final num copierVolume;
  final num openPrice;
  final num closePrice;
  final DateTime openTime;
  final DateTime closeTime;
  final num copierProfit;
  final num commissionCharged;
  final num commissionAccruedDisplay;
  final num netCredited;
  final String distributionStatus;
  final String status;

  const TradeDetail({
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
    required this.commissionAccruedDisplay,
    required this.netCredited,
    required this.distributionStatus,
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

  factory TradeDetail.fromJson(Map<String, dynamic> json) {
    return TradeDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      symbol: (json['symbol'] ?? '').toString(),
      tradeType: (json['trade_type'] ?? '').toString(),
      copierVolume: _n(json['copier_volume']),
      openPrice: _n(json['open_price']),
      closePrice: _n(json['close_price']),
      openTime: _dt(json['open_time']),
      closeTime: _dt(json['close_time']),
      copierProfit: _n(json['copier_profit']),
      commissionCharged: _n(json['commission_charged']),
      commissionAccruedDisplay: _n(json['commission_accrued_display']),
      netCredited: _n(json['net_credited']),
      distributionStatus: (json['distribution_status'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class CommissionHistoryItem {
  final int id;
  final String symbol;
  final String tradeType;
  final num copierVolume;
  final num copierProfit;
  final String closeTime;
  final num commissionCharged;
  final num commissionAccruedDisplay;
  final num netCredited;
  final num commissionPercentage;
  final bool inGracePeriod;
  final String status;
  final String settledAt;

  const CommissionHistoryItem({
    required this.id,
    required this.symbol,
    required this.tradeType,
    required this.copierVolume,
    required this.copierProfit,
    required this.closeTime,
    required this.commissionCharged,
    required this.commissionAccruedDisplay,
    required this.netCredited,
    required this.commissionPercentage,
    required this.inGracePeriod,
    required this.status,
    required this.settledAt,
  });

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  factory CommissionHistoryItem.fromJson(Map<String, dynamic> json) {
    return CommissionHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      symbol: (json['symbol'] ?? '').toString(),
      tradeType: (json['trade_type'] ?? '').toString(),
      copierVolume: _n(json['copier_volume']),
      copierProfit: _n(json['copier_profit']),
      closeTime: (json['close_time'] ?? '').toString(),
      commissionCharged: _n(json['commission_charged']),
      commissionAccruedDisplay: _n(json['commission_accrued_display']),
      netCredited: _n(json['net_credited']),
      commissionPercentage: _n(json['commission_percentage']),
      inGracePeriod: json['in_grace_period'] == true,
      status: (json['status'] ?? '').toString(),
      settledAt: (json['settled_at'] ?? '').toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionDetailController extends GetxController {
  final int subscriptionId;

  SubscriptionDetailController({required this.subscriptionId});

  // States
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rx<SubscriptionDetail?> subscriptionDetail = Rx<SubscriptionDetail?>(null);
  final RxList<PnlHistoryItem> pnlHistory = <PnlHistoryItem>[].obs;
  final RxList<TradeDetail> trades = <TradeDetail>[].obs;
  final RxList<CommissionHistoryItem> commissionHistory = <CommissionHistoryItem>[].obs;

  // Pagination
  int _currentTradesPage = 1;
  int _totalTradesPages = 1;
  bool get hasMoreTrades => _currentTradesPage < _totalTradesPages;

  int _currentCommissionPage = 1;
  int _totalCommissionPages = 1;
  bool get hasMoreCommission => _currentCommissionPage < _totalCommissionPages;

  final RxBool isLoadingMoreTrades = false.obs;
  final RxBool isLoadingMoreCommission = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadAll();
  }

  Future<void> _loadAll() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await Future.wait([
        _fetchDetail(),
        _fetchTrades(),
        _fetchCommissionHistory(),
      ]);
    } catch (e) {
      errorMessage.value = 'Failed to load data: $e';
      print('Error loading subscription detail: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionDetail(subscriptionId),
        queryParameters: {'_t': timestamp.toString()},
      );

      if (res.success && res.data != null) {
        final detailData = res.data?['data']?['subscription'];
        if (detailData != null) {
          subscriptionDetail.value = SubscriptionDetail.fromJson(detailData);

          // Also load PnL history from the detail response
          final pnlList = res.data?['data']?['pnl_history'];
          if (pnlList is List) {
            pnlHistory.assignAll(
              pnlList
                  .whereType<Map>()
                  .map((e) => PnlHistoryItem.fromJson(e.cast<String, dynamic>()))
                  .toList(),
            );
          }
        }
      }
    } catch (e) {
      print('Error fetching subscription detail: $e');
    }
  }

  Future<void> _fetchTrades({int page = 1}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionTrades(
          subscriptionId,
          page: page,
          limit: 100,
          t: timestamp,
        ),
      );

      if (res.success && res.data != null) {
        final nestedData = res.data?['data'];
        final tradesList = nestedData is Map ? nestedData['data'] : null;

        if (tradesList is List) {
          final parsedTrades = tradesList
              .whereType<Map>()
              .map((e) => TradeDetail.fromJson(e.cast<String, dynamic>()))
              .toList();

          if (page == 1) {
            trades.assignAll(parsedTrades);
          } else {
            trades.addAll(parsedTrades);
          }

          _totalTradesPages = int.tryParse(nestedData?['total_pages']?.toString() ?? '1') ?? 1;
          _currentTradesPage = page;
        }
      }
    } catch (e) {
      print('Error fetching trades: $e');
    }
  }

  Future<void> _fetchCommissionHistory({int page = 1}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiService.get(
        endpoint: '${ApiConstants.ajax}copytrading/copier/subscriptions/$subscriptionId/commission-history',
        queryParameters: {
          'per_page': '100',
          'page': page.toString(),
          '_t': timestamp.toString(),
        },
      );

      if (res.success && res.data != null) {
        final nestedData = res.data?['data'];
        final commList = nestedData is Map ? nestedData['data'] : null;

        if (commList is List) {
          final parsedComm = commList
              .whereType<Map>()
              .map((e) => CommissionHistoryItem.fromJson(e.cast<String, dynamic>()))
              .toList();

          if (page == 1) {
            commissionHistory.assignAll(parsedComm);
          } else {
            commissionHistory.addAll(parsedComm);
          }

          _totalCommissionPages = int.tryParse(nestedData?['total_pages']?.toString() ?? '1') ?? 1;
          _currentCommissionPage = page;
        }
      }
    } catch (e) {
      print('Error fetching commission history: $e');
    }
  }

  Future<void> loadMoreTrades() async {
    if (!hasMoreTrades || isLoadingMoreTrades.value) return;
    isLoadingMoreTrades.value = true;
    try {
      await _fetchTrades(page: _currentTradesPage + 1);
    } finally {
      isLoadingMoreTrades.value = false;
    }
  }

  Future<void> loadMoreCommission() async {
    if (!hasMoreCommission || isLoadingMoreCommission.value) return;
    isLoadingMoreCommission.value = true;
    try {
      await _fetchCommissionHistory(page: _currentCommissionPage + 1);
    } finally {
      isLoadingMoreCommission.value = false;
    }
  }

  Future<void> refresh() async {
    _currentTradesPage = 1;
    _currentCommissionPage = 1;
    await _loadAll();
  }

  Future<bool> pauseSubscription() async {
    try {
      final res = await ApiService.post(
        endpoint: '${ApiConstants.ajax}copytrading/copier/subscriptions/$subscriptionId/pause',
      );
      if (res.success) {
        subscriptionDetail.value = subscriptionDetail.value?.copyWith(status: 'paused');
        return true;
      }
      errorMessage.value = res.message ?? 'Failed to pause subscription';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return false;
    }
  }

  Future<bool> resumeSubscription() async {
    try {
      final res = await ApiService.post(
        endpoint: '${ApiConstants.ajax}copytrading/copier/subscriptions/$subscriptionId/resume',
      );
      if (res.success) {
        subscriptionDetail.value = subscriptionDetail.value?.copyWith(status: 'active');
        return true;
      }
      errorMessage.value = res.message ?? 'Failed to resume subscription';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return false;
    }
  }

  Future<bool> stopSubscription() async {
    try {
      final res = await ApiService.post(
        endpoint: '${ApiConstants.ajax}copytrading/copier/subscriptions/$subscriptionId/stop',
      );
      if (res.success) {
        subscriptionDetail.value = subscriptionDetail.value?.copyWith(status: 'stopped');
        return true;
      }
      errorMessage.value = res.message ?? 'Failed to stop subscription';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      return false;
    }
  }
}

extension on SubscriptionDetail {
  SubscriptionDetail copyWith({String? status}) {
    return SubscriptionDetail(
      id: id,
      planId: planId,
      planName: planName,
      masterName: masterName,
      masterCode: masterCode,
      commissionType: commissionType,
      commissionPercentage: commissionPercentage,
      accountNumber: accountNumber,
      accountCurrency: accountCurrency,
      capitalAmount: capitalAmount,
      copyRatio: copyRatio,
      copyMethod: copyMethod,
      sizingMethod: sizingMethod,
      totalPnl: totalPnl,
      totalCommissionPaid: totalCommissionPaid,
      pendingCommission: pendingCommission,
      netPnl: netPnl,
      openTradesCount: openTradesCount,
      closedTradesCount: closedTradesCount,
      status: status ?? this.status,
      masterStatus: masterStatus,
      activeSince: activeSince,
      stoppedAt: stoppedAt,
      lotMultiplier: lotMultiplier,
    );
  }
}
