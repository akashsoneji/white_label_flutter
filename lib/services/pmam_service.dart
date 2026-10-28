import 'package:get/get.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

class PmamService {
  static ApiClient get _api => Get.find<ApiClient>();

  // ──── Manager APIs ────

  static Future<ApiResponse> getManagerStatus() =>
      _api.get(endpoint: 'user/pmam/manager/status');

  static Future<ApiResponse> applyAsManager() => _api.post(
    endpoint: 'user/pmam/manager/apply',
    data: {'terms_accepted': true},
  );

  static Future<ApiResponse> getManagerPlans() =>
      _api.get(endpoint: 'user/pmam/manager/plans');

  static Future<ApiResponse> createPlan(Map<String, dynamic> body) =>
      _api.post(endpoint: 'user/pmam/manager/plans', data: body);

  static Future<ApiResponse> inactivatePlan(int planId) =>
      _api.post(endpoint: 'user/pmam/manager/plans/$planId/inactivate');

  static Future<ApiResponse> getManagerDashboardStats() =>
      _api.get(endpoint: 'user/pmam/manager/dashboard-stats');

  /// Pause a plan — POST /user/pmam/manager/plans/{id}/pause
  /// New investor joins + new trade allocations stop; existing positions
  /// stay open but cannot be closed while paused.
  static Future<ApiResponse> pausePlan(int planId) => _api.post(
        endpoint: 'user/pmam/manager/plans/$planId/pause',
      );

  /// Resume a previously paused plan — POST /user/pmam/manager/plans/{id}/resume
  static Future<ApiResponse> resumePlan(int planId) => _api.post(
        endpoint: 'user/pmam/manager/plans/$planId/resume',
      );

  /// Edit a plan (PUT) — accepts a partial map of fields; only the fields
  /// provided are sent so the API can enforce what is editable in the
  /// current state (e.g. while investors are active only name/strategy/risk).
  static Future<ApiResponse> updatePlan(
    int planId,
    Map<String, dynamic> body,
  ) =>
      _api.put(
        endpoint: 'user/pmam/manager/plans/$planId',
        data: body,
      );

  /// Rich dashboard payload — hero KPIs, main chart (equity/aum/net_pnl),
  /// investor health, plans, payouts, recent trades, alerts. [range] is one
  /// of: today | 7d | 30d | 90d | 1y | all.
  static Future<ApiResponse> getManagerDashboardOverview({
    String range = '30d',
  }) {
    final t = DateTime.now().millisecondsSinceEpoch;
    return _api.get(
      endpoint: 'user/pmam/manager/dashboard-overview?range=$range&_t=$t',
    );
  }

  static Future<ApiResponse> getInvestorRequests(int planId) => _api.get(
    endpoint: 'user/pmam/manager/plans/$planId/investor-requests',
  );

  static Future<ApiResponse> getManagerInvestors() =>
      _api.get(endpoint: 'user/pmam/manager/investors');

  static Future<ApiResponse> approveInvestorRequest(int requestId) =>
      _api.post(
        endpoint: 'user/pmam/manager/investor-requests/$requestId/approve',
      );

  static Future<ApiResponse> rejectInvestorRequest(int requestId) =>
      _api.post(
        endpoint: 'user/pmam/manager/investor-requests/$requestId/reject',
      );

  static Future<ApiResponse> getPlanDetail(int planId) =>
      _api.get(endpoint: 'user/pmam/manager/plans/$planId/detail');

  static Future<ApiResponse> getPlanAllocations(
    int planId, {
    int page = 1,
    int perPage = 15,
    String? dateFrom,
    String? dateTo,
    String? userId,
    String? status,
  }) {
    String p = 'page=$page&per_page=$perPage';
    if (dateFrom != null && dateFrom.isNotEmpty) {
      p += '&date_from=${Uri.encodeComponent(dateFrom)}';
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      p += '&date_to=${Uri.encodeComponent(dateTo)}';
    }
    if (userId != null && userId.isNotEmpty) {
      p += '&user_id=${Uri.encodeComponent(userId)}';
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      p += '&status=${Uri.encodeComponent(status)}';
    }
    return _api.get(
        endpoint: 'user/pmam/manager/plans/$planId/allocations?$p');
  }

  static Future<ApiResponse> getPlanInvestors(
    int planId, {
    int page = 1,
    int perPage = 10,
    String? sortBy,
    String? order,
    String? search,
  }) {
    String p = 'page=$page&per_page=$perPage';
    if (sortBy != null && sortBy.isNotEmpty) p += '&sort_by=$sortBy';
    if (order != null && order.isNotEmpty) p += '&order=$order';
    if (search != null && search.isNotEmpty) {
      p += '&search=${Uri.encodeComponent(search)}';
    }
    return _api.get(
        endpoint: 'user/pmam/manager/plans/$planId/investors?$p');
  }

  static Future<ApiResponse> getManagerInvestorDetail(int investorId) =>
      _api.get(endpoint: 'user/pmam/manager/investors/$investorId/detail');

  /// Manager's own trading accounts that can back a new plan
  /// (web `loadTradingAccounts`).
  static Future<ApiResponse> getManagerEligibleAccounts() =>
      _api.get(endpoint: 'user/pmam/manager/eligible-accounts');

  /// Settled commission rows, paginated:
  /// `data: {data: [...], current_page, last_page, per_page, total}`.
  static Future<ApiResponse> getManagerCommissions({
    int page = 1,
    int perPage = 25,
  }) =>
      _api.get(
        endpoint: 'user/pmam/manager/commissions?page=$page&per_page=$perPage',
      );

  // ──── Investor APIs ────

  static Future<ApiResponse> getAvailablePlans() =>
      _api.get(endpoint: 'user/pmam/investor/plans');

  static Future<ApiResponse> getEligibleAccounts([int? planId]) => _api.get(
    endpoint:
        'user/pmam/investor/eligible-accounts${planId != null ? "?plan_id=$planId" : ""}',
  );

  static Future<ApiResponse> getManagersDataTable({
    String search = '',
    int start = 0,
    int length = 50,
    int draw = 1,
  }) => _api.post(
    endpoint: 'user/pmam/managers/datatable',
    data: {
      'draw': draw,
      'start': start,
      'length': length,
      'search[value]': search,
      'search[regex]': false,
      'order[0][column]': 6,
      'order[0][dir]': 'desc',
      'columns[0][data]': 'manager_name',
      'columns[0][searchable]': true,
      'columns[1][data]': 'manager_code',
      'columns[1][searchable]': true,
      'columns[2][data]': 'plans_count',
      'columns[3][data]': 'total_aum',
      'columns[4][data]': 'total_investors',
      'columns[5][data]': 'avg_commission',
      'columns[6][data]': 'profit_percentage',
      'columns[7][data]': 'member_since',
    },
  );

  /// Search-box suggestions on Explore (web `searchManagerOptions`).
  static Future<ApiResponse> searchManagers(String query) => _api.get(
        endpoint: 'user/pmam/managers/search?q=${Uri.encodeQueryComponent(query)}',
      );

  /// Search-box plan suggestions on Explore (web `searchPlanOptions`).
  static Future<ApiResponse> searchPlans(String query) => _api.get(
        endpoint: 'user/pmam/plans/search?q=${Uri.encodeQueryComponent(query)}',
      );

  static Future<ApiResponse> requestJoin(Map<String, dynamic> body) =>
      _api.post(endpoint: 'user/pmam/investor/request-join', data: body);

  static Future<ApiResponse> investorDeposit(Map<String, dynamic> body) =>
      _api.post(endpoint: 'user/pmam/investor/deposit', data: body);

  static Future<ApiResponse> unsubscribe(int investorId) =>
      _api.post(endpoint: 'user/pmam/investor/unsubscribe/$investorId');

  static Future<ApiResponse> getPnlHistory() =>
      _api.get(endpoint: 'user/pmam/investor/pnl-history');

  static Future<ApiResponse> getMyFundEntries() =>
      _api.get(endpoint: 'user/pmam/investor/my-fund-entries');

  static Future<ApiResponse> getInvestorEnrollments() =>
      _api.get(endpoint: 'user/pmam/investor/enrollments');

  static Future<ApiResponse> getMyOpenAllocations() =>
      _api.get(endpoint: 'user/pmam/investor/my-open-allocations');

  /// Public fund-manager profile (used by Explore → View Manager screen).
  /// GET /user/pmam/managers/{managerCode}
  static Future<ApiResponse> getManagerProfile(String managerCode) {
    final t = DateTime.now().millisecondsSinceEpoch;
    return _api.get(
      endpoint: 'user/pmam/managers/$managerCode?_t=$t',
    );
  }

  /// Public open positions for a given manager + plan.
  /// GET /user/pmam/managers/{managerCode}/open-positions?plan_id={planId}
  static Future<ApiResponse> getManagerOpenPositions({
    required String managerCode,
    required int planId,
  }) {
    final t = DateTime.now().millisecondsSinceEpoch;
    return _api.get(
      endpoint:
          'user/pmam/managers/$managerCode/open-positions?plan_id=$planId&_t=$t',
    );
  }

  /// Public trade history for a given manager + plan
  /// (no date filter — used by the View Manager screen).
  /// GET /user/pmam/managers/{managerCode}/trades?plan_id={planId}&per_page=9999
  static Future<ApiResponse> getManagerTradesPublic({
    required String managerCode,
    required int planId,
    int perPage = 9999,
  }) {
    final t = DateTime.now().millisecondsSinceEpoch;
    return _api.get(
      endpoint:
          'user/pmam/managers/$managerCode/trades?plan_id=$planId&per_page=$perPage&_t=$t',
    );
  }

  static Future<ApiResponse> getManagerTrades({
    required String managerCode,
    required int planId,
    required String dateFrom,
    required String dateTo,
    int page = 1,
    int perPage = 20,
    int? investorId,
  }) {
    var p = 'plan_id=$planId'
        '&date_from=${Uri.encodeComponent(dateFrom)}'
        '&date_to=${Uri.encodeComponent(dateTo)}'
        '&page=$page'
        '&per_page=$perPage';
    if (investorId != null) {
      p += '&investor_id=$investorId';
    }
    return _api.get(endpoint: 'user/pmam/managers/$managerCode/trades?$p');
  }
}