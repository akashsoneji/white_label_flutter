import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/models/pmam_model.dart';
import 'package:crm_app/screens/pmam/data/repositories/pmam_repository.dart';
import 'package:crm_app/screens/pmam/data/usecases/apply_as_manager.dart';
import 'package:crm_app/screens/pmam/data/usecases/get_manager_status.dart';

class PmamController extends GetxController {
  final GetManagerStatus _getManagerStatus;
  final ApplyAsManager _applyAsManager;
  final PmamRepository _repo;

  PmamController({
    GetManagerStatus? getManagerStatus,
    ApplyAsManager? applyAsManager,
    PmamRepository? repo,
  }) : _getManagerStatus = getManagerStatus ?? Get.find<GetManagerStatus>(),
       _applyAsManager = applyAsManager ?? Get.find<ApplyAsManager>(),
       _repo = repo ?? Get.find<PmamRepository>();

  // ── Loading / Error ──
  final RxBool isLoading = false.obs;
  final RxBool isCreatePlanLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isTradesLoading = false.obs;

  // ── Manager state ──
  final RxString managerStatus = ''.obs; // pending | approved | rejected | ''
  final RxString managerCode = ''.obs;

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
  final RxList<PmamManager> managersList = <PmamManager>[].obs; // from datatable API
  final RxBool isManagersLoading = false.obs;
  final RxInt managersTotal = 0.obs;
  final RxList<Map<String, dynamic>> availablePlans =
      <Map<String, dynamic>>[].obs;
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

  Future<void> loadManagerStatus() async {
    try {
      isLoading.value = true;
      final response = await _getManagerStatus();
      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          managerStatus.value = (inner['status'] ?? '').toString();
          managerCode.value = (inner['manager_code'] ?? '').toString();
        } else {
          managerStatus.value = '';
          managerCode.value = '';
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> applyAsManager() async {
    try {
      isLoading.value = true;
      final response = await _applyAsManager();
      if (response.success) {
        managerStatus.value = 'pending';
        CustomToastService.showSuccess(
          message: 'Manager application submitted successfully!',
        );
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to submit application',
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Load the manager dashboard data for the given [range] preset.
  ///
  /// Hits `manager/dashboard-overview` and maps the rich payload into the
  /// derived maps consumed by the manager dashboard screen
  /// (`heroStats`, `mainChartData`, `investorHealth`, `payoutsData`,
  /// `recentDashboardTrades`).
  Future<void> loadManagerDashboard({String? range}) async {
    try {
      isLoading.value = true;
      if (range != null && range.isNotEmpty) {
        dashboardRange.value = range;
      }

      final overviewResp = await _repo.getManagerDashboardOverview(
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
        errorMessage.value = overviewResp.message ?? 'Failed to load dashboard';
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
      final resp = await _repo.pausePlan(planId);
      if (resp.success) {
        _patchPlanStatus(planId, status: 'paused', isPaused: true);
        return (ok: true, message: resp.message ?? 'Plan paused successfully.');
      }
      return (ok: false, message: resp.message ?? 'Failed to pause plan.');
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// Resume a paused manager plan. Returns true on success.
  Future<({bool ok, String message})> resumeManagerPlan(int planId) async {
    try {
      final resp = await _repo.resumePlan(planId);
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
          message: resp.message ?? 'Plan resumed successfully.',
        );
      }
      return (ok: false, message: resp.message ?? 'Failed to resume plan.');
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
      final resp = await _repo.updatePlan(planId, body);
      if (resp.success) {
        _patchPlanFields(planId, body);
        return (ok: true, message: resp.message ?? 'Plan updated successfully.');
      }
      return (ok: false, message: resp.message ?? 'Failed to update plan.');
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

  Future<bool> createPlan(Map<String, dynamic> body) async {
    try {
      isCreatePlanLoading.value = true;
      final response = await _repo.createPlan(body);
      if (response.success) {
        CustomToastService.showSuccess(
          message: response.message ?? 'Plan created successfully!',
        );
        await loadManagerDashboard();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to create plan',
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
      return false;
    } finally {
      isCreatePlanLoading.value = false;
    }
  }

  Future<bool> inactivatePlan(int planId) async {
    try {
      isLoading.value = true;
      final response = await _repo.inactivatePlan(planId);
      if (response.success) {
        CustomToastService.showSuccess(
          message: 'Plan inactivated successfully',
        );
        await loadManagerDashboard();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Cannot inactivate plan',
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadInvestorRequests(int planId) async {
    try {
      selectedPlanId.value = planId;
      isLoading.value = true;
      final response = await _repo.getInvestorRequests(planId);
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
      final response = await _repo.getManagerInvestors();
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
      final response = await _repo.approveInvestorRequest(requestId);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Investor request approved');
        if (selectedPlanId.value > 0) {
          await loadInvestorRequests(selectedPlanId.value);
        }
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to approve',
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  Future<bool> rejectInvestorRequest(int requestId) async {
    try {
      final response = await _repo.rejectInvestorRequest(requestId);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Investor request rejected');
        if (selectedPlanId.value > 0) {
          await loadInvestorRequests(selectedPlanId.value);
        }
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to reject',
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════
  // INVESTOR APIs
  // ══════════════════════════════════════════

  /// Load managers list via datatable POST API (supports server-side search)
  Future<void> loadManagersDataTable({String search = ''}) async {
    try {
      isManagersLoading.value = true;
      final response = await _repo.getManagersDataTable(search: search);
      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final list = d['data'];
        managersTotal.value = (d['recordsTotal'] ?? 0) as int;
        if (list is List) {
          managersList.assignAll(
            list.map((i) => PmamManager.fromJson(i as Map<String, dynamic>)).toList(),
          );
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isManagersLoading.value = false;
    }
  }

  /// Lightweight: only loads eligible accounts (for Create Plan / Invest sheet)
  Future<void> loadEligibleAccounts([int? planId]) async {
    try {
      final response = await _repo.getEligibleAccounts(planId);
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
        _repo.getAvailablePlans(),
        _repo.getInvestorEnrollments(),
        _repo.getMyOpenAllocations(),
        _repo.getMyFundEntries(),
        if (planId != null) _repo.getEligibleAccounts(planId),
      ];
      final results = await Future.wait(futures);

      final plansResp = results[0];
      if (plansResp.success && plansResp.data != null) {
        final d = plansResp.data as Map<String, dynamic>;
        final list = d['data'];
        if (list is List) {
          availablePlans.assignAll(
            list.whereType<Map<String, dynamic>>().toList(),
          );
        }
      } else if (!plansResp.success) {
        errorMessage.value = plansResp.message ?? 'Failed to load plans';
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
            enrollResp.message ?? 'Failed to load enrollments';
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
            allocResp.message ?? 'Failed to load open allocations';
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
            entriesResp.message ?? 'Failed to load fund entries';
      }

      if (planId != null && results.length > 4) {
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
              accountsResp.message ?? 'Failed to load eligible accounts';
        }
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
      final resp = await _repo.investorDeposit({
        'pmam_investor_id': pmamInvestorId,
        'amount': amount,
      });
      if (resp.success) {
        CustomToastService.showSuccess(message: resp.message ?? 'Deposit added');
        await loadInvestorPortal();
        return true;
      }
      CustomToastService.showError(
        message: resp.message ?? 'Failed to add funds',
      );
      return false;
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
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
      final resp = await _repo.getManagerTrades(
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
      CustomToastService.showError(message: 'Error: $e');
      if (kDebugMode) debugPrint('[PMAM] getManagerTrades exception: $e');
    } finally {
      isTradesLoading.value = false;
    }
  }

  Future<bool> requestJoin({
    required int planId,
    required int accountId,
    required double amount,
  }) async {
    try {
      isLoading.value = true;
      final response = await _repo.requestJoin({
        'pmam_plan_id': planId,
        'investor_account_id': accountId,
        'invested_amount': amount,
      });
      if (response.success) {
        CustomToastService.showSuccess(
          message: 'Join request submitted! Waiting for manager approval.',
        );
        await loadInvestorPortal(planId: planId);
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to submit join request',
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Alias for requestJoin used in UI
  Future<bool> joinPlan(int accountId, int planId, double amount) =>
      requestJoin(planId: planId, accountId: accountId, amount: amount);

  Future<bool> unsubscribe(int investorId) async {
    try {
      isLoading.value = true;
      final response = await _repo.unsubscribe(investorId);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Unsubscribe request accepted');
        await loadInvestorPortal();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to unsubscribe',
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
