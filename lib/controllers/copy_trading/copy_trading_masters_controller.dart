import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class CopyTradingMasterListItem {
  final String masterCode;
  final String nickname;
  final String name;
  final int planCount;
  final int totalCopiers;
  final num totalAum;
  final int? riskScore;
  final num totalGain;
  final int activeDays;
  final num winRate;
  final bool isEnrolled;
  final String serverType;
  final String strategyDescription;
  final num totalPnl;
  final double totalGainPercent;
  final num maxDrawdown;
  final num minInvestment;
  final num minimumCapital;

  const CopyTradingMasterListItem({
    required this.masterCode,
    required this.nickname,
    required this.name,
    required this.planCount,
    required this.totalCopiers,
    required this.totalAum,
    required this.riskScore,
    required this.totalGain,
    required this.activeDays,
    required this.winRate,
    required this.isEnrolled,
    required this.serverType,
    required this.strategyDescription,
    required this.totalPnl,
    required this.totalGainPercent,
    required this.maxDrawdown,
    required this.minInvestment,
    required this.minimumCapital,
  });

  static double _parseGainPercent(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.trim().isEmpty) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  factory CopyTradingMasterListItem.fromJson(Map<String, dynamic> json) {
    return CopyTradingMasterListItem(
      masterCode: (json['master_code'] ?? '').toString(),
      nickname: (json['master_nickname'] ?? '').toString(),
      name: (json['master_name'] ?? '').toString(),
      planCount: (json['plan_count'] ?? 0) is num ? (json['plan_count'] as num).toInt() : 0,
      totalCopiers:
          (json['total_copiers'] ?? 0) is num ? (json['total_copiers'] as num).toInt() : 0,
      totalAum: (json['total_aum'] ?? 0) as num? ?? 0,
      riskScore: json['risk_score'] is num ? (json['risk_score'] as num).toInt() : null,
      totalGain: (json['total_gain'] ?? 0) as num? ?? 0,
      activeDays:
          (json['active_days'] ?? 0) is num ? (json['active_days'] as num).toInt() : 0,
      winRate: (json['win_rate'] ?? 0) as num? ?? 0,
      isEnrolled: json['is_enrolled'] == true,
      serverType: (json['server_type'] ?? '').toString(),
      strategyDescription: (json['strategy_description'] ?? '').toString(),
      totalPnl: (json['total_pnl'] ?? 0) as num? ?? 0,
      totalGainPercent: _parseGainPercent(json['total_gain_percent']),
      maxDrawdown: (json['max_drawdown'] ?? 0) as num? ?? 0,
      minInvestment: (json['min_investment'] ?? 0) as num? ?? 0,
      minimumCapital: (json['minimum_capital'] ?? 0) as num? ?? 0,
    );
  }
}

/// Top-level filter tab on the Explore Masters screen.
enum MasterFilterTab { all, enrolled, discover }

class CopyTradingMastersController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<CopyTradingMasterListItem> masters =
      <CopyTradingMasterListItem>[].obs;

  final RxString search = ''.obs;
  final RxString sort = ''.obs; // aum | copiers | gain

  /// Top-level tabs on Explore Masters: All / Enrolled / Discover.
  final Rx<MasterFilterTab> selectedFilter = MasterFilterTab.all.obs;

  /// Filter chips shown under the tab bar.
  final RxString riskFilter = 'All Risks'.obs;
  final RxString timeFilter = 'All Time'.obs;
  final RxString sortBy = 'Gain %'.obs;

  /// Aliases used by the redesigned UI.
  RxString get searchQuery => search;
  RxList<CopyTradingMasterListItem> get allMasters => masters;
  Future<void> refreshMasters() async => loadMasters();

  /// Masters from API; [search] filters this list **client-side** (nickname / name / code).
  List<CopyTradingMasterListItem> get filteredMasters {
    search.value;
    final q = search.value.trim().toLowerCase();
    if (q.isEmpty) return masters.toList();
    return masters.where((m) {
      final nick = m.nickname.toLowerCase();
      final name = m.name.toLowerCase();
      final code = m.masterCode.toLowerCase();
      return nick.contains(q) || name.contains(q) || code.contains(q);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    if (kDebugMode) {
      AppLogger.api(
        '[CopyTradingMasters] onInit() — scheduling loadMasters()',
      );
    }
    // Defer to the next microtask so the controller is fully wired and
    // the screen has had a chance to register its Obx listeners before
    // the first assignAll() runs (avoids any race on the very first
    // build).
    Future.microtask(() => loadMasters(showLoading: true));
  }

  Future<void> loadMasters({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final qp = <String, dynamic>{};
      if (sort.value.trim().isNotEmpty) qp['sort'] = sort.value.trim();

      if (kDebugMode) {
        AppLogger.api(
          '[CopyTradingMasters] GET ${ApiConstants.copyTradingMasters} '
          'qp=$qp',
        );
      }

      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingMasters,
        queryParameters: qp,
      );
      if (kDebugMode) {
        AppLogger.api(
          '[CopyTradingMasters] ← success=${res.success} '
          'hasData=${res.data != null} '
          'message=${res.message}',
        );
      }
      if (!res.success || res.data == null) {
        masters.clear();
      errorMessage.value =
          res.message ?? TranslationUtils.tr('copy_trading_failed_to_load_masters');
        return;
      }

      // The backend may return either:
      //   1) { data: [ ... ] }      ← standard wrapped payload
      //   2) [ ... ]                ← raw array
      //   3) { data: { masters: [ ... ] } }   ← nested wrapper
      // Try each shape in order.
      dynamic body = res.data?['data'];
      List<dynamic> raw = const [];
      if (body is List) {
        raw = body;
      } else if (body is Map &&
          body['masters'] is List) {
        raw = body['masters'] as List;
      } else if (body is Map &&
          body['items'] is List) {
        raw = body['items'] as List;
      } else if (res.data is List) {
        raw = res.data as List;
      } else {
        if (kDebugMode) {
          AppLogger.error(
            '[CopyTradingMasters] unexpected response shape; '
            'res.data keys=${res.data is Map ? (res.data as Map).keys.toList() : 'not-a-map'}',
          );
        }
        masters.clear();
      errorMessage.value = TranslationUtils.tr('copy_trading_invalid_response');
        return;
      }

      final parsed = raw
          .whereType<Map>()
          .map(
            (e) => CopyTradingMasterListItem.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList();
      masters.assignAll(parsed);
      if (kDebugMode) {
        AppLogger.api(
          '[CopyTradingMasters] ← loaded ${parsed.length} master(s)',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        AppLogger.error(
          '[CopyTradingMasters] loadMasters threw: $e',
          error: e,
          stackTrace: st,
        );
      }
      masters.clear();
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_load_error')}: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }
}

