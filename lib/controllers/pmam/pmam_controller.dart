import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/pmam_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/models/pmam_model.dart';
import 'package:crm_app/services/language_service.dart';

/// One row of `GET pmam/managers/search` (1.3) or `GET pmam/plans/search`
/// (1.8). Picking one filters the Explore plan table: a manager sets
/// `manager_code`, a plan sets `plan_id` (its `code` is the plan id).
class PmamSearchOption {
  final String title;
  final String subtitle;
  final String managerCode;
  final bool isPlan;
  final int? planId;

  const PmamSearchOption({
    required this.title,
    required this.subtitle,
    required this.managerCode,
    required this.isPlan,
    this.planId,
  });

  factory PmamSearchOption.manager(Map<String, dynamic> json) {
    final code = (json['manager_code'] ?? json['code'] ?? '').toString();
    return PmamSearchOption(
      title: (json['manager_name'] ?? json['name'] ?? code).toString(),
      subtitle: code,
      managerCode: code,
      isPlan: false,
    );
  }

  factory PmamSearchOption.plan(Map<String, dynamic> json) {
    return PmamSearchOption(
      title: (json['name'] ?? json['plan_name'] ?? '').toString(),
      subtitle: (json['meta'] ?? json['manager_name'] ?? '').toString(),
      managerCode: (json['manager_code'] ?? '').toString(),
      isPlan: true,
      planId: int.tryParse('${json['code'] ?? json['id'] ?? ''}'),
    );
  }
}

class PmamController extends GetxController {
  // ── Loading / Error ──
  final RxBool isLoading = false.obs;
  final RxBool isCreatePlanLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isTradesLoading = false.obs;

  // ── Manager state ──
  final RxString managerStatus = ''.obs; // pending | approved | rejected | ''
  final RxString managerCode = ''.obs;

  /// `data.master_enrollments_enabled` from manager/status; false means new
  /// master applications are closed, so Apply is hidden.
  final RxBool masterEnrollmentsEnabled = true.obs;

  final RxMap<String, dynamic> dashboardStats = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> managerPlans =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> investorRequests =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> managerInvestors =
      <Map<String, dynamic>>[].obs; // from GET manager/investors API
  final RxBool isInvestorsLoading = false.obs;

  // ── Manager Dashboard derived state ──
  /// Currently selected dashboard time-range preset (Today / 7d / 30d / 90d / 1y / all)
  final RxString dashboardRange = '30d'.obs;

  /// Hero stat tiles for the manager dashboard. Each block contains
  /// `current`, optional `delta_pct` / `delta`, and `series.data` for sparkline.
  final RxMap<String, dynamic> heroStats = <String, dynamic>{}.obs;

  /// Main performance chart payload — keys: `equity`, `aum`, `pnl`. Each entry
  /// contains a `series` map with `data` list.
  final RxMap<String, dynamic> mainChartData = <String, dynamic>{}.obs;

  /// Investor health breakdown (active / pending / inactive counts + retention stats).
  final RxMap<String, dynamic> investorHealth = <String, dynamic>{}.obs;

  /// Payout summary (earned in period + pending payout amount).
  final RxMap<String, dynamic> payoutsData = <String, dynamic>{}.obs;

  /// Recent trades displayed on the dashboard (placeholder until a dedicated
  /// "recent trades" endpoint exists — currently empty).
  final RxList<Map<String, dynamic>> recentDashboardTrades =
      <Map<String, dynamic>>[].obs;

  // ── Investor state ──
  /// Explore feed rows from `POST plans/datatable` (1.7).
  final RxList<PmamExplorePlan> explorePlans = <PmamExplorePlan>[].obs;
  final RxBool isExploreLoading = false.obs;
  final RxString exploreError = ''.obs;
  final RxInt exploreTotal = 0.obs;

  /// Active Explore filters picked from the search suggestions.
  final Rxn<PmamSearchOption> exploreManagerFilter = Rxn<PmamSearchOption>();
  final Rxn<PmamSearchOption> explorePlanFilter = Rxn<PmamSearchOption>();

  final RxList<Map<String, dynamic>> myInvestments =
      <Map<String, dynamic>>[].obs; // legacy: currently mirrors fundEntries
  final RxList<Map<String, dynamic>> enrollments =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> openAllocations =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> eligibleAccounts =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> pnlHistory = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> fundEntries = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> trades = <Map<String, dynamic>>[].obs;
  final RxInt tradesTotal = 0.obs;
  final RxInt tradesPage = 1.obs;
  final RxInt tradesPerPage = 20.obs;
  final RxInt tradesTotalPages = 1.obs;
  final RxDouble tradesNetPnl = 0.0.obs;
  final RxDouble tradesCommission = 0.0.obs;
  final RxDouble tradesSettledPnl = 0.0.obs;

  // ── Explore search suggestions ──
  final RxList<PmamSearchOption> searchOptions = <PmamSearchOption>[].obs;
  String _lastSearchQuery = '';

  // ── Manager commissions ──
  final RxList<Map<String, dynamic>> commissions = <Map<String, dynamic>>[].obs;
  final RxBool isCommissionsLoading = false.obs;
  final RxString commissionsError = ''.obs;
  final RxInt commissionsPage = 1.obs;
  final RxInt commissionsLastPage = 1.obs;
  final RxInt commissionsTotal = 0.obs;

  // ── Selected plan for investor requests ──
  final RxInt selectedPlanId = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadManagerStatus();
    loadManagerDashboard();
  }

  // ══════════════════════════════════════════
  // MANAGER APIs
  // ══════════════════════════════════════════

  /// `GET manager/status`. "No manager application found" comes back as
  /// `data: {master_enrollments_enabled}` with no `status`, which leaves
  /// [managerStatus] empty (= never applied).
  Future<void> loadManagerStatus() async {
    try {
      isLoading.value = true;
      final response = await PmamService.getManagerStatus();
      final root = response.data is Map ? response.data as Map : const {};
      final inner = root['data'];
      if (inner is Map) {
        managerStatus.value = (inner['status'] ?? '').toString();
        managerCode.value = (inner['manager_code'] ?? '').toString();
        if (inner.containsKey('master_enrollments_enabled')) {
          masterEnrollmentsEnabled.value =
              inner['master_enrollments_enabled'] == true;
        }
      } else if (response.success) {
        managerStatus.value = '';
        managerCode.value = '';
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// `POST manager/apply` (doc 3.2). Shows the server's reason on failure
  /// (IB partner, already applied, applications closed, KYC/profile missing).
  Future<bool> applyAsManager() async {
    try {
      isLoading.value = true;
      final response = await PmamService.applyAsManager();
      if (response.success) {
        managerStatus.value = 'pending';
        CustomToastService.showSuccess(
          message: TranslationUtils.tr(
            'pmam_manager_application_submitted_successfully',
          ),
        );
        return true;
      } else {
        CustomToastService.showError(
          message: friendlyError(
            response.message,
            TranslationUtils.tr('copy_trading_failed_to_submit_application'),
          ),
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(
        message: TranslationUtils.tr('copy_trading_failed_to_submit_application'),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Load the manager dashboard data for the given [range] preset.
  ///
  /// Combines `manager/dashboard-stats` and `manager/plans` into the rich
  /// derived maps consumed by [PmamManagerDashboardScreen]
  /// (`heroStats`, `mainChartData`, `investorHealth`, `payoutsData`,
  /// `recentDashboardTrades`).
  Future<void> loadManagerDashboard({String? range}) async {
    try {
      isLoading.value = true;
      if (range != null && range.isNotEmpty) {
        dashboardRange.value = range;
      }

      final overviewResp = await PmamService.getManagerDashboardOverview(
        range: dashboardRange.value,
      );

      if (overviewResp.success && overviewResp.data != null) {
        final root = overviewResp.data as Map<String, dynamic>;
        final data = (root['data'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(root['data'] as Map<String, dynamic>)
            : <String, dynamic>{};
        dashboardStats.value = data;
        _hydrateFromOverview(data);
      } else {
        errorMessage.value =
            overviewResp.message ??
            TranslationUtils.tr('pmam_failed_to_load_dashboard');
        _hydrateFromOverview(const {});
      }
    } catch (e) {
      errorMessage.value = e.toString();
      if (kDebugMode) debugPrint('[PMAM] loadManagerDashboard error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Map the rich `/manager/dashboard-overview` payload into the maps the
  /// screen reads. Keeps the legacy field names (`series.data`, `pnl`,
  /// `earned_period`, `retention_rate`, `new_this_period`, `churned`) so the
  /// existing dashboard UI does not need to change.
  void _hydrateFromOverview(Map<String, dynamic> data) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;

    List<num> seriesValues(dynamic seriesMap) {
      if (seriesMap is Map) {
        final v = seriesMap['values'] ?? seriesMap['data'];
        if (v is List) return v.map(toNum).toList();
      }
      return const <num>[];
    }

    List<String> seriesLabels(dynamic seriesMap) {
      if (seriesMap is Map) {
        final l = seriesMap['labels'];
        if (l is List) return l.map((e) => e.toString()).toList();
      }
      return const <String>[];
    }

    // ── Hero ──
    final hero = (data['hero'] is Map<String, dynamic>)
        ? data['hero'] as Map<String, dynamic>
        : <String, dynamic>{};

    Map<String, dynamic> heroBlock(String key, {bool absoluteDelta = false}) {
      final block = (hero[key] is Map) ? hero[key] as Map : const {};
      final isRoi = key == 'roi';
      return {
        'current': isRoi ? toNum(block['current_pct']) : toNum(block['current']),
        'previous':
            isRoi ? toNum(block['previous_pct']) : toNum(block['previous']),
        if (isRoi) 'current_pct': toNum(block['current_pct']),
        if (absoluteDelta) 'delta': toNum(block['delta']),
        'delta_pct': toNum(block['delta_pct']),
        'series': {
          'labels': seriesLabels(block['series']),
          // Keep both `values` and `data` so old consumers keep working.
          'values': seriesValues(block['series']),
          'data': seriesValues(block['series']),
        },
      };
    }

    heroStats.assignAll({
      'aum': heroBlock('aum'),
      'investors': heroBlock('investors', absoluteDelta: true),
      'earnings': heroBlock('earnings'),
      'roi': heroBlock('roi'),
    });

    // ── Main performance chart ──
    final mainChart = (data['main_chart'] is Map<String, dynamic>)
        ? data['main_chart'] as Map<String, dynamic>
        : <String, dynamic>{};
    final mainLabels = (mainChart['labels'] is List)
        ? (mainChart['labels'] as List).map((e) => e.toString()).toList()
        : <String>[];

    List<num> mainSeries(String key) {
      final v = mainChart[key];
      return v is List ? v.map(toNum).toList() : const <num>[];
    }

    Map<String, dynamic> chartBlock(List<num> values) => {
          'series': {
            'labels': mainLabels,
            'values': values,
            'data': values, // legacy alias
          },
        };

    final equityVals = mainSeries('equity');
    final aumVals = mainSeries('aum');
    final pnlVals = mainSeries('net_pnl');
    final earningsVals = mainSeries('earnings');

    mainChartData.assignAll({
      'labels': mainLabels,
      'equity': chartBlock(equityVals),
      'aum': chartBlock(aumVals),
      'pnl': chartBlock(pnlVals), // legacy key used by screen
      'net_pnl': chartBlock(pnlVals),
      'earnings': chartBlock(earningsVals),
      'benchmark': mainChart['benchmark'] ?? const [],
    });

    // ── Investor Health ──
    final health = (data['investor_health'] is Map<String, dynamic>)
        ? data['investor_health'] as Map<String, dynamic>
        : <String, dynamic>{};
    investorHealth.assignAll({
      'active': toNum(health['active']).toInt(),
      'pending': toNum(health['pending']).toInt(),
      'inactive': toNum(health['inactive']).toInt(),
      'rejected': toNum(health['rejected']).toInt(),
      // Provide both new + legacy keys used by the UI.
      'new_in_window': toNum(health['new_in_window']).toInt(),
      'new_this_period': toNum(health['new_in_window']).toInt(),
      'churned_in_window': toNum(health['churned_in_window']).toInt(),
      'churned': toNum(health['churned_in_window']).toInt(),
      'avg_age_days': toNum(health['avg_age_days']).toInt(),
      'retention_pct': toNum(health['retention_pct']),
      'retention_rate': toNum(health['retention_pct']),
    });

    // ── Plans ──
    final plans = data['plans'];
    if (plans is List) {
      managerPlans.assignAll(
        plans.whereType<Map>().map((p) {
          final m = Map<String, dynamic>.from(p);
          // Backwards-compat keys for the existing plan card UI.
          m['total_locked_aum'] = m['aum'] ?? m['total_locked_aum'];
          m['active_investors'] = m['investors'] ?? m['active_investors'];
          return m;
        }).toList(),
      );
    } else {
      managerPlans.clear();
    }

    // ── Payouts ──
    final payouts = (data['payouts'] is Map<String, dynamic>)
        ? data['payouts'] as Map<String, dynamic>
        : <String, dynamic>{};
    payoutsData.assignAll({
      'earned_in_window': toNum(payouts['earned_in_window']),
      'earned_period': toNum(payouts['earned_in_window']), // legacy alias
      'pending': toNum(payouts['pending']),
      'upcoming': payouts['upcoming'] ?? const [],
      'recent': payouts['recent'] ?? const [],
    });

    // ── Recent trades ──
    final trades = data['recent_trades'];
    recentDashboardTrades.assignAll(
      trades is List
          ? trades.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const <Map<String, dynamic>>[],
    );
  }

  /// Pause a manager plan. Returns true on success and patches the local
  /// [managerPlans] list so the UI reflects the new status without a reload.
  Future<({bool ok, String message})> pauseManagerPlan(int planId) async {
    try {
      final resp = await PmamService.pausePlan(planId);
      if (resp.success) {
        _patchPlanStatus(planId, status: 'paused', isPaused: true);
        return (
          ok: true,
          message:
              resp.message ??
              TranslationUtils.tr('pmam_plan_paused_successfully'),
        );
      }
      return (
        ok: false,
        message:
            resp.message ?? TranslationUtils.tr('pmam_failed_to_pause_plan'),
      );
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// Resume a paused manager plan. Returns true on success.
  Future<({bool ok, String message})> resumeManagerPlan(int planId) async {
    try {
      final resp = await PmamService.resumePlan(planId);
      if (resp.success) {
        final newStatus =
            (resp.data is Map && (resp.data as Map)['data'] is Map)
                ? ((resp.data as Map)['data'] as Map)['status']?.toString()
                : null;
        _patchPlanStatus(
          planId,
          status: newStatus ?? 'approved',
          isPaused: false,
        );
        return (
          ok: true,
          message:
              resp.message ??
              TranslationUtils.tr('pmam_plan_resumed_successfully'),
        );
      }
      return (
        ok: false,
        message:
            resp.message ?? TranslationUtils.tr('pmam_failed_to_resume_plan'),
      );
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// Update the editable fields of a plan (name / strategy / risk and,
  /// when no active investors, commission + minimum investment).
  /// Returns `(ok, message)` so the UI can show a snackbar.
  Future<({bool ok, String message})> updateManagerPlan(
    int planId,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await PmamService.updatePlan(planId, body);
      if (resp.success) {
        _patchPlanFields(planId, body);
        return (
          ok: true,
          message:
              resp.message ??
              TranslationUtils.tr('pmam_plan_updated_successfully'),
        );
      }
      return (
        ok: false,
        message:
            resp.message ?? TranslationUtils.tr('pmam_failed_to_update_plan'),
      );
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// Merge changed fields back into the local plan so the list reflects the
  /// edit without a full reload.
  void _patchPlanFields(int planId, Map<String, dynamic> changes) {
    final idx = managerPlans.indexWhere((p) => (p['id'] ?? -1) == planId);
    if (idx == -1) return;
    final updated = Map<String, dynamic>.from(managerPlans[idx])
      ..addAll(changes);
    managerPlans[idx] = updated;
    managerPlans.refresh();
  }

  /// In-place update of a single plan inside [managerPlans] so the list
  /// rebuilds without re-hitting the network.
  void _patchPlanStatus(
    int planId, {
    required String status,
    required bool isPaused,
  }) {
    final idx = managerPlans.indexWhere((p) => (p['id'] ?? -1) == planId);
    if (idx == -1) return;
    final updated = Map<String, dynamic>.from(managerPlans[idx]);
    updated['status'] = status;
    updated['is_paused'] = isPaused ? 1 : 0;
    managerPlans[idx] = updated;
    managerPlans.refresh();
  }

  /// `GET manager/plans` — loaded when My Plans, Investors and Commissions
  /// open (per the client-portal flow). Adds the keys the plan cards read.
  Future<void> loadManagerPlans() async {
    try {
      final response = await PmamService.getManagerPlans();
      final list = response.data is Map ? (response.data as Map)['data'] : null;
      if (!response.success || list is! List) return;
      managerPlans.assignAll(
        list.whereType<Map>().map((p) {
          final m = Map<String, dynamic>.from(p);
          m['total_locked_aum'] = m['total_locked'] ?? m['total_locked_aum'];
          return m;
        }).toList(),
      );
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<bool> createPlan(Map<String, dynamic> body) async {
    try {
      isCreatePlanLoading.value = true;
      final response = await PmamService.createPlan(body);
      if (response.success) {
        CustomToastService.showSuccess(
          message:
              response.message ??
              TranslationUtils.tr('pmam_plan_created_successfully'),
        );
        await loadManagerDashboard();
        return true;
      } else {
        CustomToastService.showError(
          message:
              response.message ??
              TranslationUtils.tr('copy_trading_failed_to_create_plan'),
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(
        message: '${TranslationUtils.tr('close_position_error')}: $e',
      );
      return false;
    } finally {
      isCreatePlanLoading.value = false;
    }
  }

  Future<bool> inactivatePlan(int planId) async {
    try {
      isLoading.value = true;
      final response = await PmamService.inactivatePlan(planId);
      if (response.success) {
        CustomToastService.showSuccess(
          message: TranslationUtils.tr('pmam_plan_inactivated_successfully'),
        );
        await loadManagerDashboard();
        return true;
      } else {
        CustomToastService.showError(
          message:
              response.message ??
              TranslationUtils.tr('pmam_cannot_inactivate_plan'),
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(
        message: '${TranslationUtils.tr('close_position_error')}: $e',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadInvestorRequests(int planId) async {
    try {
      selectedPlanId.value = planId;
      isLoading.value = true;
      final response = await PmamService.getInvestorRequests(planId);
      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final list = d['data'];
        if (list is List) {
          investorRequests.assignAll(
            list.whereType<Map<String, dynamic>>().toList(),
          );
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Load all investors for this manager (GET user/pmam/manager/investors)
  Future<void> loadManagerInvestors() async {
    try {
      isInvestorsLoading.value = true;
      final response = await PmamService.getManagerInvestors();
      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final list = d['data'];
        if (list is List) {
          managerInvestors.assignAll(
            list.whereType<Map<String, dynamic>>().toList(),
          );
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isInvestorsLoading.value = false;
    }
  }

  Future<bool> approveInvestorRequest(int requestId) async {
    try {
      final response = await PmamService.approveInvestorRequest(requestId);
      if (response.success) {
        CustomToastService.showSuccess(
          message: TranslationUtils.tr('pmam_investor_request_approved'),
        );
        if (selectedPlanId.value > 0) {
          await loadInvestorRequests(selectedPlanId.value);
        }
        return true;
      } else {
        CustomToastService.showError(
          message:
              response.message ??
              TranslationUtils.tr('pmam_failed_to_approve'),
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(
        message: '${TranslationUtils.tr('close_position_error')}: $e',
      );
      return false;
    }
  }

  Future<bool> rejectInvestorRequest(int requestId) async {
    try {
      final response = await PmamService.rejectInvestorRequest(requestId);
      if (response.success) {
        CustomToastService.showSuccess(
          message: TranslationUtils.tr('pmam_investor_request_rejected'),
        );
        if (selectedPlanId.value > 0) {
          await loadInvestorRequests(selectedPlanId.value);
        }
        return true;
      } else {
        CustomToastService.showError(
          message:
              response.message ?? TranslationUtils.tr('pmam_failed_to_reject'),
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(
        message: '${TranslationUtils.tr('close_position_error')}: $e',
      );
      return false;
    }
  }

  // ══════════════════════════════════════════
  // INVESTOR APIs
  // ══════════════════════════════════════════

  /// Explore feed (`POST plans/datatable`, doc 1.7), filtered by the picked
  /// manager / plan. The reply is DataTables-shaped with no `success` key, so
  /// rows are read straight from `data`.
  Future<void> loadExplorePlans() async {
    try {
      isExploreLoading.value = true;
      exploreError.value = '';
      final response = await PmamService.getPlansDataTable(
        managerCode: exploreManagerFilter.value?.managerCode,
        planId: explorePlanFilter.value?.planId,
      );
      final body = response.data;
      final rows = body is Map ? body['data'] : null;
      if (rows is! List) {
        exploreError.value = friendlyError(
          response.message,
          TranslationUtils.tr('pmam_failed_to_load_plans'),
        );
        return;
      }
      explorePlans.assignAll(
        rows.whereType<Map>().map(
              (e) => PmamExplorePlan.fromJson(e.cast<String, dynamic>()),
            ),
      );
      exploreTotal.value =
          int.tryParse('${(body as Map)['recordsFiltered'] ?? ''}') ??
              explorePlans.length;
    } catch (e) {
      exploreError.value = TranslationUtils.tr('pmam_failed_to_load_plans');
      if (kDebugMode) debugPrint('[PMAM] loadExplorePlans error: $e');
    } finally {
      isExploreLoading.value = false;
    }
  }

  /// Apply a picked search suggestion as an Explore filter and reload.
  /// A manager pick clears a plan filter of another manager.
  Future<void> applyExploreFilter(PmamSearchOption option) async {
    clearSearchOptions();
    if (option.isPlan) {
      explorePlanFilter.value = option;
    } else {
      exploreManagerFilter.value = option;
      final plan = explorePlanFilter.value;
      if (plan != null && plan.managerCode != option.managerCode) {
        explorePlanFilter.value = null;
      }
    }
    await loadExplorePlans();
  }

  Future<void> clearExploreFilter({required bool plan}) async {
    if (plan) {
      explorePlanFilter.value = null;
    } else {
      exploreManagerFilter.value = null;
    }
    await loadExplorePlans();
  }

  /// Server suggestions for the Explore search box: managers and plans
  /// matching [rawQuery], fetched together. Stale replies are dropped.
  Future<void> searchExploreOptions(String rawQuery) async {
    final query = rawQuery.trim();
    if (query == _lastSearchQuery) return;
    _lastSearchQuery = query;
    if (query.isEmpty) {
      searchOptions.clear();
      return;
    }
    final responses = await Future.wait([
      PmamService.searchManagers(query),
      PmamService.searchPlans(
        query,
        managerCode: exploreManagerFilter.value?.managerCode,
      ),
    ]);
    if (query != _lastSearchQuery) return;

    List<Map<String, dynamic>> rows(ApiResponse res) {
      final body = res.data is Map ? (res.data as Map)['data'] : null;
      if (!res.success || body is! List) return const [];
      return body.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }

    searchOptions.assignAll([
      ...rows(responses[0]).map(PmamSearchOption.manager),
      ...rows(responses[1]).map(PmamSearchOption.plan),
    ].where((o) => o.managerCode.isNotEmpty && o.title.isNotEmpty));
  }

  void clearSearchOptions() {
    _lastSearchQuery = '';
    searchOptions.clear();
  }

  /// Server text is shown as-is, except Laravel's raw model-not-found text
  /// ("No query results for model [...]"), which leaks internals (doc 2.6).
  static String friendlyError(String? message, String fallback) {
    final m = (message ?? '').trim();
    if (m.isEmpty) return fallback;
    if (m.startsWith('No query results for model')) {
      return TranslationUtils.tr('pmam_not_found');
    }
    return m;
  }

  /// Manager's own accounts for the Create Plan picker
  /// (`GET manager/eligible-accounts`, not the investor variant).
  Future<void> loadManagerEligibleAccounts() async {
    try {
      final response = await PmamService.getManagerEligibleAccounts();
      final list = response.data is Map ? (response.data as Map)['data'] : null;
      if (response.success && list is List) {
        eligibleAccounts.assignAll(
          list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
        );
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  /// Settled commissions (`GET manager/commissions`). [loadMore] appends the
  /// next page; otherwise page 1 replaces the list.
  Future<void> loadManagerCommissions({bool loadMore = false}) async {
    if (isCommissionsLoading.value) return;
    if (loadMore && commissionsPage.value >= commissionsLastPage.value) return;
    final page = loadMore ? commissionsPage.value + 1 : 1;
    isCommissionsLoading.value = true;
    if (!loadMore) commissionsError.value = '';
    try {
      final response = await PmamService.getManagerCommissions(page: page);
      final root = response.data is Map ? (response.data as Map)['data'] : null;
      if (!response.success || root is! Map) {
        if (!loadMore) {
          commissionsError.value = response.message ??
              TranslationUtils.tr('pmam_commissions_load_failed');
        }
        return;
      }
      final rows = root['data'] is List
          ? (root['data'] as List)
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
          : <Map<String, dynamic>>[];
      if (loadMore) {
        commissions.addAll(rows);
      } else {
        commissions.assignAll(rows);
      }
      commissionsPage.value = int.tryParse('${root['current_page']}') ?? page;
      commissionsLastPage.value = int.tryParse('${root['last_page']}') ?? page;
      commissionsTotal.value =
          int.tryParse('${root['total']}') ?? commissions.length;
    } catch (e) {
      if (!loadMore) {
        commissionsError.value =
            TranslationUtils.tr('pmam_commissions_load_failed');
      }
      if (kDebugMode) debugPrint('[PMAM] loadManagerCommissions error: $e');
    } finally {
      isCommissionsLoading.value = false;
    }
  }

  /// Lightweight: only loads eligible accounts (for Create Plan / Invest sheet)
  Future<void> loadEligibleAccounts([int? planId]) async {
    try {
      final response = await PmamService.getEligibleAccounts(planId);
      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final list = d['data'];
        if (list is List) {
          eligibleAccounts.assignAll(
            list.whereType<Map<String, dynamic>>().toList(),
          );
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<void> loadInvestorPortal({int? planId}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final futures = <Future>[
        PmamService.getPnlHistory(),
        PmamService.getInvestorEnrollments(),
        PmamService.getMyOpenAllocations(),
        PmamService.getMyFundEntries(),
        PmamService.getEligibleAccounts(planId),
      ];
      final results = await Future.wait(futures);

      // pnl-history is paginated: `data: {data: [...], current_page, ...}`.
      final pnlResp = results[0];
      if (pnlResp.success && pnlResp.data is Map) {
        final page = (pnlResp.data as Map)['data'];
        final rows = page is Map ? page['data'] : null;
        pnlHistory.assignAll(
          rows is List ? rows.whereType<Map<String, dynamic>>() : const [],
        );
      }

      final enrollResp = results[1];
      if (enrollResp.success && enrollResp.data != null) {
        final d = enrollResp.data as Map<String, dynamic>;
        final list = d['data'];
        if (list is List) {
          enrollments.assignAll(
            list.whereType<Map<String, dynamic>>().toList(),
          );
        }
      } else if (!enrollResp.success) {
        errorMessage.value =
            enrollResp.message ??
            TranslationUtils.tr('pmam_failed_to_load_enrollments');
      }

      final allocResp = results[2];
      if (allocResp.success && allocResp.data != null) {
        final d = allocResp.data as Map<String, dynamic>;
        final list = d['data'];
        if (list is List) {
          openAllocations.assignAll(
            list.whereType<Map<String, dynamic>>().toList(),
          );
        }
      } else if (!allocResp.success) {
        errorMessage.value =
            allocResp.message ??
            TranslationUtils.tr('pmam_failed_to_load_open_allocations');
      }

      final entriesResp = results[3];
      if (entriesResp.success && entriesResp.data != null) {
        final d = entriesResp.data as Map<String, dynamic>;
        final data = d['data'];
        List<Map<String, dynamic>> rows = [];
        if (data is List) {
          rows = data.whereType<Map<String, dynamic>>().toList();
        } else if (data is Map<String, dynamic>) {
          final nestedCandidates = [
            data['fund_entries'],
            data['fundEntries'],
            data['entries'],
            data['data'],
          ];
          for (final c in nestedCandidates) {
            if (c is List) {
              rows = c.whereType<Map<String, dynamic>>().toList();
              break;
            }
            if (c is Map<String, dynamic>) {
              final inner = c['data'];
              if (inner is List) {
                rows = inner.whereType<Map<String, dynamic>>().toList();
                break;
              }
            }
          }
        }
        fundEntries.assignAll(rows);
        myInvestments.assignAll(rows); // keep legacy binding safe
      } else if (!entriesResp.success) {
        errorMessage.value =
            entriesResp.message ??
            TranslationUtils.tr('pmam_failed_to_load_fund_entries');
      }

      final accountsResp = results[4];
      if (accountsResp.success && accountsResp.data != null) {
        final d = accountsResp.data as Map<String, dynamic>;
        final list = d['data'];
        if (list is List) {
          eligibleAccounts.assignAll(
            list.whereType<Map<String, dynamic>>().toList(),
          );
        }
      } else if (!accountsResp.success) {
        errorMessage.value =
            accountsResp.message ??
            TranslationUtils.tr('copy_trading_failed_to_load_eligible_accounts');
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> depositToEnrollment({
    required int pmamInvestorId,
    required double amount,
  }) async {
    try {
      isLoading.value = true;
      final resp = await PmamService.investorDeposit({
        'pmam_investor_id': pmamInvestorId,
        'amount': amount,
      });
      if (resp.success) {
        CustomToastService.showSuccess(
          message: resp.message ?? TranslationUtils.tr('pmam_deposit_added'),
        );
        await loadInvestorPortal();
        return true;
      }
      CustomToastService.showError(
        message:
            resp.message ?? TranslationUtils.tr('pmam_failed_to_add_funds'),
      );
      return false;
    } catch (e) {
      CustomToastService.showError(
        message: '${TranslationUtils.tr('close_position_error')}: $e',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchTradesForEnrollment({
    required String managerCode,
    required int planId,
    required String dateFrom,
    required String dateTo,
    required int investorId,
    int page = 1,
    int perPage = 20,
    bool append = false,
  }) async {
    try {
      isTradesLoading.value = true;
      tradesPage.value = page;
      tradesPerPage.value = perPage;
      if (kDebugMode) {
        debugPrint(
          '[PMAM] getManagerTrades(managerCode=$managerCode, planId=$planId, investorId=$investorId, date_from=$dateFrom, date_to=$dateTo, page=$page, per_page=$perPage)',
        );
      }
      final resp = await PmamService.getManagerTrades(
        managerCode: managerCode,
        planId: planId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        investorId: investorId,
        page: page,
        perPage: perPage,
      );
      if (resp.success && resp.data != null) {
        final d = resp.data as Map<String, dynamic>;
        final data = d['data'];
        if (data is Map<String, dynamic>) {
          final rows = data['trades'];
          if (rows is List) {
            final parsed = rows.whereType<Map<String, dynamic>>().toList();
            if (append && trades.isNotEmpty) {
              trades.addAll(parsed);
            } else {
              trades.assignAll(parsed);
            }
            tradesTotal.value = int.tryParse((data['total'] ?? 0).toString()) ?? 0;
            tradesPage.value = int.tryParse((data['page'] ?? page).toString()) ?? page;
            tradesPerPage.value =
                int.tryParse((data['per_page'] ?? perPage).toString()) ?? perPage;
            tradesTotalPages.value =
                int.tryParse((data['total_pages'] ?? 1).toString()) ?? 1;
            if (kDebugMode) {
              debugPrint(
                '[PMAM] trades pagination total=${tradesTotal.value} page=${tradesPage.value} per_page=${tradesPerPage.value} total_pages=${tradesTotalPages.value} rows=${parsed.length}',
              );
            }

            double net = 0, comm = 0;
            for (final t in trades) {
              net += double.tryParse((t['profit'] ?? 0).toString()) ?? 0;
              comm +=
                  double.tryParse((t['commission_charged'] ?? 0).toString()) ?? 0;
            }
            tradesNetPnl.value = net;
            tradesCommission.value = comm;
            tradesSettledPnl.value = net - comm;
          } else {
            trades.clear();
            tradesTotal.value = 0;
            tradesTotalPages.value = 1;
            tradesNetPnl.value = 0;
            tradesCommission.value = 0;
            tradesSettledPnl.value = 0;
            if (kDebugMode) {
              debugPrint('[PMAM] trades response missing `data.trades` list');
            }
          }
        } else if (data is List) {
          // Backward-compat if API ever returns a list directly
          final parsed = data.whereType<Map<String, dynamic>>().toList();
          if (append && trades.isNotEmpty) {
            trades.addAll(parsed);
          } else {
            trades.assignAll(parsed);
          }
          tradesTotal.value = parsed.length;
          tradesTotalPages.value = 1;
          if (kDebugMode) {
            debugPrint('[PMAM] trades response is List rows=${parsed.length} (no pagination fields)');
          }
          double net = 0, comm = 0;
          for (final t in trades) {
            net += double.tryParse((t['profit'] ?? 0).toString()) ?? 0;
            comm +=
                double.tryParse((t['commission_charged'] ?? 0).toString()) ?? 0;
          }
          tradesNetPnl.value = net;
          tradesCommission.value = comm;
          tradesSettledPnl.value = net - comm;
        } else {
          trades.clear();
          tradesTotal.value = 0;
          tradesTotalPages.value = 1;
          tradesNetPnl.value = 0;
          tradesCommission.value = 0;
          tradesSettledPnl.value = 0;
          if (kDebugMode) {
            debugPrint('[PMAM] trades response unexpected data type: ${data.runtimeType}');
          }
        }
      } else {
        trades.clear();
        tradesTotal.value = 0;
        tradesTotalPages.value = 1;
        tradesNetPnl.value = 0;
        tradesCommission.value = 0;
        tradesSettledPnl.value = 0;
        if (kDebugMode) {
          debugPrint('[PMAM] getManagerTrades failed success=${resp.success} message=${resp.message}');
        }
      }
    } catch (e) {
      trades.clear();
      tradesTotal.value = 0;
      tradesTotalPages.value = 1;
      tradesNetPnl.value = 0;
      tradesCommission.value = 0;
      tradesSettledPnl.value = 0;
      CustomToastService.showError(
        message: '${TranslationUtils.tr('close_position_error')}: $e',
      );
      if (kDebugMode) debugPrint('[PMAM] getManagerTrades exception: $e');
    } finally {
      isTradesLoading.value = false;
    }
  }

  /// Add-ons + wallet balance for the Invest drawer (doc 2.4). Falls back to
  /// [PmamPurchaseOptions.none] so a failure just hides the dropdown.
  Future<PmamPurchaseOptions> loadPurchaseOptions() async {
    try {
      final response = await PmamService.getPurchaseOptions();
      final data = response.data is Map ? (response.data as Map)['data'] : null;
      if (response.success && data is Map) {
        return PmamPurchaseOptions.fromJson(data.cast<String, dynamic>());
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PMAM] loadPurchaseOptions error: $e');
    }
    return PmamPurchaseOptions.none;
  }

  /// P&L entries of one enrollment (doc 2.9 `investor_id`), for the
  /// per-investment screen. Returns an empty list on failure.
  Future<List<Map<String, dynamic>>> loadPnlHistoryFor(int enrollmentId) async {
    try {
      final response =
          await PmamService.getPnlHistory(enrollmentId: enrollmentId);
      final page = response.data is Map ? (response.data as Map)['data'] : null;
      final rows = page is Map ? page['data'] : null;
      if (response.success && rows is List) {
        return rows.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PMAM] loadPnlHistoryFor error: $e');
    }
    return const [];
  }

  /// Only `GET investor/enrollments` (doc 2.2) — what the manager profile
  /// needs to know whether the user already invests with this manager.
  Future<void> loadEnrollments() async {
    try {
      final response = await PmamService.getInvestorEnrollments();
      final list = response.data is Map ? (response.data as Map)['data'] : null;
      if (response.success && list is List) {
        enrollments.assignAll(
          list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PMAM] loadEnrollments error: $e');
    }
  }

  /// `POST investor/request-join` (doc 2.5). Toasts are left to the caller so
  /// the Invest drawer can stay open on a 422 (wallet shortage, stale add-on).
  Future<PmamJoinResult> requestJoin({
    required int planId,
    required int accountId,
    required double amount,
    int? purchaseOptionId,
  }) async {
    try {
      final response = await PmamService.requestJoin({
        'pmam_plan_id': planId,
        'investor_account_id': accountId,
        'invested_amount': amount,
        if (purchaseOptionId != null) 'purchase_option_id': purchaseOptionId,
      });
      if (response.success) {
        final data = response.data is Map ? (response.data as Map)['data'] : null;
        final purchase = data is Map ? data['purchase'] : null;
        await loadEnrollments();
        return PmamJoinResult(
          ok: true,
          message: friendlyError(
            response.data is Map ? (response.data as Map)['message']?.toString() : null,
            TranslationUtils.tr('pmam_join_request_submitted'),
          ),
          purchase: purchase is Map ? purchase.cast<String, dynamic>() : null,
        );
      }
      final err = response.data;
      final isWalletShort = err is Map && err['code'] == 'insufficient_wallet';
      return PmamJoinResult(
        ok: false,
        message: friendlyError(
          response.message,
          TranslationUtils.tr('pmam_failed_to_submit_join_request'),
        ),
        shortage: isWalletShort
            ? double.tryParse('${err['shortage'] ?? ''}') ?? 0
            : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PMAM] requestJoin error: $e');
      return PmamJoinResult(
        ok: false,
        message: TranslationUtils.tr('pmam_failed_to_submit_join_request'),
      );
    }
  }

  /// Join without add-on, toasting the outcome. Used by the older manager
  /// detail screen; the Invest drawer calls [requestJoin] directly.
  Future<bool> joinPlan(int accountId, int planId, double amount) async {
    final result =
        await requestJoin(planId: planId, accountId: accountId, amount: amount);
    if (result.ok) {
      CustomToastService.showSuccess(message: result.message);
    } else {
      CustomToastService.showError(message: result.message);
    }
    return result.ok;
  }

  /// `POST investor/cancel/{id}` for a `pending` request (doc 2.6). The toast
  /// mentions the add-on refund when `addon_refunded > 0`.
  Future<bool> cancelJoinRequest(int enrollmentId) async {
    try {
      isLoading.value = true;
      final response = await PmamService.cancelRequest(enrollmentId);
      if (!response.success) {
        CustomToastService.showError(
          message: friendlyError(
            response.message,
            TranslationUtils.tr('pmam_cancel_request_failed'),
          ),
        );
        return false;
      }
      final root = response.data is Map ? response.data as Map : const {};
      final data = root['data'];
      final refunded = data is Map
          ? double.tryParse('${data['addon_refunded'] ?? ''}') ?? 0
          : 0.0;
      final base = (root['message'] ?? '').toString().trim().isNotEmpty
          ? root['message'].toString()
          : TranslationUtils.tr('pmam_request_cancelled');
      CustomToastService.showSuccess(
        message: refunded > 0
            ? '$base ${TranslationUtils.trArgs('pmam_addon_refunded', {'amount': refunded.toStringAsFixed(2)})}'
            : base,
      );
      await loadInvestorPortal();
      return true;
    } catch (e) {
      CustomToastService.showError(
        message: TranslationUtils.tr('pmam_cancel_request_failed'),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> unsubscribe(int investorId) async {
    try {
      isLoading.value = true;
      final response = await PmamService.unsubscribe(investorId);
      if (response.success) {
        CustomToastService.showSuccess(
          message: TranslationUtils.tr('pmam_unsubscribe_request_accepted'),
        );
        await loadInvestorPortal();
        return true;
      } else {
        CustomToastService.showError(
          message:
              response.message ??
              TranslationUtils.tr('pmam_failed_to_unsubscribe'),
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(
        message: '${TranslationUtils.tr('close_position_error')}: $e',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
