import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// One card on Explore Masters — a single plan from `GET copytrading/plans`.
/// `masterCode` opens the master profile; `planId` is the subscribe `plan_id`.
class CopyTradingMasterListItem {
  final int planId;
  final String planName;
  final String masterCode;
  final String nickname;
  final String name;
  final int totalCopiers;
  final num totalAum;
  final int? riskScore;
  final num totalGain;
  final int activeDays;
  final num winRate;
  final bool isEnrolled;
  final bool isFull;
  final String serverType;
  final String accountCurrency;
  final String strategyDescription;
  final num totalPnl;
  final double totalGainPercent;
  final num maxDrawdown;
  final num minInvestment;
  final num minimumCapital;
  final num? commissionPercentage;
  /// Master chose to hide copier counts (`hide_copiers`).
  final bool hideCopiers;

  const CopyTradingMasterListItem({
    required this.planId,
    required this.planName,
    required this.masterCode,
    required this.nickname,
    required this.name,
    required this.totalCopiers,
    required this.totalAum,
    required this.riskScore,
    required this.totalGain,
    required this.activeDays,
    required this.winRate,
    required this.isEnrolled,
    required this.isFull,
    required this.serverType,
    required this.accountCurrency,
    required this.strategyDescription,
    required this.totalPnl,
    required this.totalGainPercent,
    required this.maxDrawdown,
    required this.minInvestment,
    required this.minimumCapital,
    required this.commissionPercentage,
    this.hideCopiers = false,
  });

  /// Copy is possible only for a real plan that still has copier slots.
  bool get canCopy => planId > 0 && !isFull;

  // Backend turns `null` into "" (spec §0.2), so numeric keys can be "" or a
  // numeric string — a plain `as num` cast would throw and fail the whole list.
  static num? _numOrNull(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }

  static num _num(dynamic value) => _numOrNull(value) ?? 0;

  factory CopyTradingMasterListItem.fromJson(Map<String, dynamic> json) {
    final minimumCapital = _num(json['minimum_capital']);
    return CopyTradingMasterListItem(
      planId: _num(json['id'] ?? json['plan_id']).toInt(),
      planName: (json['plan_name'] ?? '').toString(),
      masterCode: (json['master_code'] ?? '').toString(),
      nickname: (json['master_nickname'] ?? '').toString(),
      name: (json['master_name'] ?? '').toString(),
      totalCopiers: _num(json['total_copiers']).toInt(),
      totalAum: _num(json['total_aum']),
      riskScore: _numOrNull(json['risk_score'])?.toInt(),
      totalGain: _num(json['total_gain']),
      activeDays: _num(json['active_days']).toInt(),
      winRate: _num(json['win_rate']),
      isEnrolled: json['is_enrolled'] == true,
      isFull: json['is_full'] == true,
      serverType: (json['server_type'] ?? '').toString(),
      accountCurrency:
          (json['master_account_currency'] ?? json['account_currency'] ?? '')
              .toString(),
      strategyDescription: (json['strategy_description'] ?? '').toString(),
      totalPnl: _num(json['total_pnl']),
      totalGainPercent: _num(json['total_gain_percent']).toDouble(),
      maxDrawdown: _num(json['max_drawdown']),
      minInvestment: _numOrNull(json['min_investment']) ?? minimumCapital,
      minimumCapital: minimumCapital,
      commissionPercentage: _numOrNull(json['commission_percentage']),
      hideCopiers: json['hide_copiers'] == true,
    );
  }
}

/// One row of `GET copytrading/masters/search?q=` — `{code, name, plans_count}`.
class MasterSearchSuggestion {
  final String code;
  final String name;
  final int plansCount;

  const MasterSearchSuggestion({
    required this.code,
    required this.name,
    required this.plansCount,
  });

  factory MasterSearchSuggestion.fromJson(Map<String, dynamic> json) {
    return MasterSearchSuggestion(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      plansCount: int.tryParse('${json['plans_count']}') ?? 0,
    );
  }
}

/// One row of `GET copytrading/plans/search?q=` —
/// `{code: plan id, name: plan name, meta: master name, master_code}`.
class PlanSearchSuggestion {
  final int planId;
  final String name;
  final String masterName;
  final String masterCode;

  const PlanSearchSuggestion({
    required this.planId,
    required this.name,
    required this.masterName,
    required this.masterCode,
  });

  factory PlanSearchSuggestion.fromJson(Map<String, dynamic> json) {
    return PlanSearchSuggestion(
      planId: int.tryParse('${json['code']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      masterName: (json['meta'] ?? '').toString(),
      masterCode: (json['master_code'] ?? '').toString(),
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

  /// Period chip → backend `timeframe`. The backend only knows
  /// 7d / 2w / 1m / 3m / 6m; anything else (incl. `1y`) silently returns
  /// all-time data, so "All Time" sends nothing.
  static const Map<String, String> timeframeByFilter = {
    'Last 7 Days': '7d',
    'Last 2 Weeks': '2w',
    'Last 30 Days': '1m',
    'Last 90 Days': '3m',
    'Last 6 Months': '6m',
  };

  static String? timeframeForFilter(String filter) => timeframeByFilter[filter];

  void selectTimeFilter(String filter) {
    if (timeFilter.value == filter) return;
    timeFilter.value = filter;
    loadMasters(showLoading: true);
  }
  final RxString sortBy = 'Gain %'.obs;

  /// Aliases used by the redesigned UI.
  RxString get searchQuery => search;
  RxList<CopyTradingMasterListItem> get allMasters => masters;
  Future<void> refreshMasters() async => loadMasters();

  /// Dropdown suggestions under the search box, from `GET copytrading/masters/search`
  /// (same as the web Explore page).
  final RxList<MasterSearchSuggestion> masterSuggestions =
      <MasterSearchSuggestion>[].obs;

  /// Master picked from the dropdown; while set, only that master's plans show.
  final Rxn<MasterSearchSuggestion> selectedMaster = Rxn<MasterSearchSuggestion>();

  /// Plan suggestions from `GET copytrading/plans/search` (web
  /// `searchPlanOptions`), shown under the master suggestions.
  final RxList<PlanSearchSuggestion> planSuggestions =
      <PlanSearchSuggestion>[].obs;

  /// Plan picked from the dropdown; while set, only that plan shows.
  final Rxn<PlanSearchSuggestion> selectedPlan = Rxn<PlanSearchSuggestion>();
  String _lastServerQuery = '';

  bool get _hasPickedSuggestion =>
      selectedMaster.value != null || selectedPlan.value != null;

  /// Plans after the tab, search, risk chip and sort chip are applied.
  List<CopyTradingMasterListItem> get visibleMasters {
    final tab = selectedFilter.value;
    final q = search.value.trim().toLowerCase();
    final risk = riskFilter.value;
    final pickedCode = selectedMaster.value?.code;
    final pickedPlanId = selectedPlan.value?.planId;

    final result = masters.where((m) {
      if (tab == MasterFilterTab.enrolled && !m.isEnrolled) return false;
      if (tab == MasterFilterTab.discover && m.isEnrolled) return false;
      if (!_matchesRisk(m.riskScore ?? 0, risk)) return false;
      if (pickedPlanId != null) return m.planId == pickedPlanId;
      if (pickedCode != null) return m.masterCode == pickedCode;
      if (q.isEmpty) return true;
      return m.nickname.toLowerCase().contains(q) ||
          m.name.toLowerCase().contains(q) ||
          m.planName.toLowerCase().contains(q) ||
          m.masterCode.toLowerCase().contains(q);
    }).toList();

    final num Function(CopyTradingMasterListItem) sortKey = switch (sortBy.value) {
      'AUM' => (m) => m.totalAum,
      'Copiers' => (m) => m.totalCopiers,
      'Active Days' => (m) => m.activeDays,
      _ => (m) => m.totalGainPercent,
    };
    result.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
    return result;
  }

  static bool _matchesRisk(int score, String risk) => switch (risk) {
        'Low (1-2)' => score <= 2,
        'Medium (3)' => score == 3,
        'High (4-5)' => score >= 4,
        _ => true,
      };

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
    debounce<String>(
      search,
      _fetchMasterSuggestions,
      time: const Duration(milliseconds: 400),
    );
  }

  /// Picks a dropdown suggestion: the box shows its name and the list is
  /// narrowed to that master's plans.
  void selectMasterSuggestion(MasterSearchSuggestion suggestion) {
    selectedPlan.value = null;
    selectedMaster.value = suggestion;
    masterSuggestions.clear();
    planSuggestions.clear();
    _lastServerQuery = suggestion.name;
    search.value = suggestion.name;
  }

  /// Picks a plan suggestion: the box shows the plan name and the list is
  /// narrowed to that one plan.
  void selectPlanSuggestion(PlanSearchSuggestion suggestion) {
    selectedMaster.value = null;
    selectedPlan.value = suggestion;
    masterSuggestions.clear();
    planSuggestions.clear();
    _lastServerQuery = suggestion.name;
    search.value = suggestion.name;
  }

  void clearSearch() {
    selectedMaster.value = null;
    selectedPlan.value = null;
    masterSuggestions.clear();
    planSuggestions.clear();
    search.value = '';
  }

  /// Typing again after a pick means a new search, so drop the picked master.
  void onSearchTyped(String text) {
    if (selectedMaster.value != null && text != selectedMaster.value!.name) {
      selectedMaster.value = null;
    }
    if (selectedPlan.value != null && text != selectedPlan.value!.name) {
      selectedPlan.value = null;
    }
    search.value = text;
  }

  Future<void> _fetchMasterSuggestions(String rawQuery) async {
    final query = rawQuery.trim();
    if (_hasPickedSuggestion || query == _lastServerQuery) return;
    _lastServerQuery = query;
    if (query.isEmpty) {
      masterSuggestions.clear();
      planSuggestions.clear();
      return;
    }

    final responses = await Future.wait([
      ApiService.get(
        endpoint: ApiConstants.copyTradingMastersSearch,
        queryParameters: {'q': query},
      ),
      ApiService.get(
        endpoint: ApiConstants.copyTradingPlansSearch,
        queryParameters: {'q': query},
      ),
    ]);
    // A newer keystroke (or a pick) already moved on; drop stale results.
    if (query != _lastServerQuery || _hasPickedSuggestion) return;

    masterSuggestions.assignAll(
      _suggestionRows(responses[0])
          .map(MasterSearchSuggestion.fromJson)
          .where((s) => s.code.isNotEmpty),
    );
    planSuggestions.assignAll(
      _suggestionRows(responses[1])
          .map(PlanSearchSuggestion.fromJson)
          .where((s) => s.planId > 0),
    );
  }

  static List<Map<String, dynamic>> _suggestionRows(ApiResponse res) {
    final body = res.data?['data'];
    if (!res.success || body is! List) return const [];
    return body.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> loadMasters({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final qp = <String, dynamic>{};
      if (sort.value.trim().isNotEmpty) qp['sort'] = sort.value.trim();
      final timeframe = timeframeForFilter(timeFilter.value);
      if (timeframe != null) qp['timeframe'] = timeframe;

      if (kDebugMode) {
        AppLogger.api(
          '[CopyTradingMasters] GET ${ApiConstants.copyTradingPlans} '
          'qp=$qp',
        );
      }

      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingPlans,
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

