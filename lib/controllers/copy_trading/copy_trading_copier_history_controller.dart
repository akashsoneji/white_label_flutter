import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:get/get.dart';

num _asNum(dynamic v) {
  if (v is num) return v;
  if (v == null) return 0;
  return num.tryParse(v.toString()) ?? 0;
}

String _asString(dynamic v) => (v ?? '').toString();

/// One copied trade inside a subscription period.
class CopierHistoryTrade {
  final String symbol;
  final String tradeType;
  final num masterVolume;
  final num copierVolume;
  final num openPrice;
  final num closePrice;
  final num masterProfit;
  final num copierProfit;
  final String status;
  final String openTime;
  final String closeTime;

  const CopierHistoryTrade({
    required this.symbol,
    required this.tradeType,
    required this.masterVolume,
    required this.copierVolume,
    required this.openPrice,
    required this.closePrice,
    required this.masterProfit,
    required this.copierProfit,
    required this.status,
    required this.openTime,
    required this.closeTime,
  });

  factory CopierHistoryTrade.fromJson(Map<String, dynamic> json) {
    return CopierHistoryTrade(
      symbol: _asString(json['symbol']),
      tradeType: _asString(json['trade_type']),
      masterVolume: _asNum(json['master_volume']),
      copierVolume: _asNum(json['copier_volume']),
      openPrice: _asNum(json['open_price']),
      closePrice: _asNum(json['close_price']),
      masterProfit: _asNum(json['master_profit']),
      copierProfit: _asNum(json['copier_profit']),
      status: _asString(json['status']),
      openTime: _asString(json['open_time']),
      closeTime: _asString(json['close_time']),
    );
  }
}

/// One subscribe → unsubscribe cycle of a copier.
class CopierSubscriptionPeriod {
  final int subscriptionNumber;
  final String subscribedAt;
  final String unsubscribedAt;
  final String status;
  final int durationDays;
  final num equityAtSubscribe;
  final num periodPnl;
  final num periodCommissionPaid;
  final int tradesCount;
  final List<CopierHistoryTrade> trades;

  const CopierSubscriptionPeriod({
    required this.subscriptionNumber,
    required this.subscribedAt,
    required this.unsubscribedAt,
    required this.status,
    required this.durationDays,
    required this.equityAtSubscribe,
    required this.periodPnl,
    required this.periodCommissionPaid,
    required this.tradesCount,
    required this.trades,
  });

  factory CopierSubscriptionPeriod.fromJson(Map<String, dynamic> json) {
    final rawTrades = json['trades'];
    return CopierSubscriptionPeriod(
      subscriptionNumber: _asNum(json['subscription_number']).toInt(),
      subscribedAt: _asString(json['subscribed_at']),
      unsubscribedAt: _asString(json['unsubscribed_at']),
      status: _asString(json['status']),
      durationDays: _asNum(json['duration_days']).toInt(),
      equityAtSubscribe: _asNum(json['equity_at_subscribe']),
      periodPnl: _asNum(json['period_pnl']),
      periodCommissionPaid: _asNum(json['period_commission_paid']),
      tradesCount: _asNum(json['trades_count']).toInt(),
      trades: rawTrades is List
          ? rawTrades
              .whereType<Map>()
              .map((e) => CopierHistoryTrade.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

class CopyTradingCopierHistoryController extends GetxController {
  final int copierId;
  CopyTradingCopierHistoryController({required this.copierId});

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString copierName = ''.obs;
  final RxString accountNumber = ''.obs;
  final RxString planName = ''.obs;
  final RxString status = ''.obs;
  final RxList<CopierSubscriptionPeriod> periods =
      <CopierSubscriptionPeriod>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await ApiService.get(
        endpoint:
            ApiConstants.copyTradingMasterCopierSubscriptionHistory(copierId),
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      final body = res.data?['data'];
      if (!res.success || body is! Map) {
        periods.clear();
        errorMessage.value = res.message ??
            TranslationUtils.tr('copy_trading_invalid_response_format');
        return;
      }

      final copier = body['copier'];
      if (copier is Map) {
        copierName.value = _asString(copier['user_name']);
        accountNumber.value = _asString(copier['account_number']);
        planName.value = _asString(copier['plan_name']);
        status.value = _asString(copier['status']);
      }

      final rawPeriods = body['periods'];
      periods.assignAll(
        rawPeriods is List
            ? rawPeriods.whereType<Map>().map(
                (e) => CopierSubscriptionPeriod.fromJson(
                  e.cast<String, dynamic>(),
                ),
              )
            : const <CopierSubscriptionPeriod>[],
      );
    } catch (e) {
      periods.clear();
      errorMessage.value = '${TranslationUtils.tr('copy_trading_load_error')}: $e';
    } finally {
      isLoading.value = false;
    }
  }
}
