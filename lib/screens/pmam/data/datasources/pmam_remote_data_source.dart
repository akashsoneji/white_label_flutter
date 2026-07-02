import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

class PmamRemoteDataSource {
  final ApiClient _api;

  PmamRemoteDataSource(this._api);

  // ──── Manager APIs ────
  Future<ApiResponse> getManagerStatus() =>
      _api.get(endpoint: 'user/pmam/manager/status');

  Future<ApiResponse> applyAsManager() => _api.post(
        endpoint: 'user/pmam/manager/apply',
        data: {'terms_accepted': true},
      );

  Future<ApiResponse> getManagerPlans() =>
      _api.get(endpoint: 'user/pmam/manager/plans');

  Future<ApiResponse> createPlan(Map<String, dynamic> body) =>
      _api.post(endpoint: 'user/pmam/manager/plans', data: body);

  Future<ApiResponse> inactivatePlan(int planId) => _api.post(
        endpoint: 'user/pmam/manager/plans/$planId/inactivate',
      );

  /// Pause a plan — POST /user/pmam/manager/plans/{id}/pause
  /// New investor joins + new trade allocations stop; existing positions
  /// stay open but cannot be closed while paused.
  Future<ApiResponse> pausePlan(int planId) => _api.post(
        endpoint: 'user/pmam/manager/plans/$planId/pause',
      );

  /// Resume a previously paused plan — POST /user/pmam/manager/plans/{id}/resume
  Future<ApiResponse> resumePlan(int planId) => _api.post(
        endpoint: 'user/pmam/manager/plans/$planId/resume',
      );

  /// Edit a plan (PUT) — accepts a partial map of fields; only the fields
  /// provided are sent so the API can enforce what is editable in the
  /// current state (e.g. while investors are active only name/strategy/risk).
  Future<ApiResponse> updatePlan(int planId, Map<String, dynamic> body) =>
      _api.put(endpoint: 'user/pmam/manager/plans/$planId', data: body);

  /// Rich dashboard payload — hero KPIs, main chart (equity/aum/net_pnl),
  /// investor health, plans, payouts, recent trades, alerts. [range] is one
  /// of: today | 7d | 30d | 90d | 1y | all.
  Future<ApiResponse> getManagerDashboardOverview({String range = '30d'}) {
    final t = DateTime.now().millisecondsSinceEpoch;
    return _api.get(
      endpoint: 'user/pmam/manager/dashboard-overview?range=$range&_t=$t',
    );
  }

  Future<ApiResponse> getManagerDashboardStats() =>
      _api.get(endpoint: 'user/pmam/manager/dashboard-stats');

  Future<ApiResponse> getInvestorRequests(int planId) => _api.get(
        endpoint: 'user/pmam/manager/plans/$planId/investor-requests',
      );

  Future<ApiResponse> getManagerInvestors() =>
      _api.get(endpoint: 'user/pmam/manager/investors');

  Future<ApiResponse> approveInvestorRequest(int requestId) => _api.post(
        endpoint: 'user/pmam/manager/investor-requests/$requestId/approve',
      );

  Future<ApiResponse> rejectInvestorRequest(int requestId) => _api.post(
        endpoint: 'user/pmam/manager/investor-requests/$requestId/reject',
      );

  Future<ApiResponse> getPlanDetail(int planId) =>
      _api.get(endpoint: 'user/pmam/manager/plans/$planId/detail');

  Future<ApiResponse> getPlanAllocations(
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
      endpoint: 'user/pmam/manager/plans/$planId/allocations?$p',
    );
  }

  Future<ApiResponse> getPlanInvestors(
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
      endpoint: 'user/pmam/manager/plans/$planId/investors?$p',
    );
  }

  Future<ApiResponse> getManagerInvestorDetail(int investorId) => _api.get(
        endpoint: 'user/pmam/manager/investors/$investorId/detail',
      );

  // ──── Investor APIs ────
  Future<ApiResponse> getAvailablePlans() =>
      _api.get(endpoint: 'user/pmam/investor/plans');

  Future<ApiResponse> getEligibleAccounts([int? planId]) => _api.get(
        endpoint:
            'user/pmam/investor/eligible-accounts${planId != null ? "?plan_id=$planId" : ""}',
      );

  Future<ApiResponse> getManagersDataTable({
    String search = '',
    int start = 0,
    int length = 50,
    int draw = 1,
  }) =>
      _api.post(
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

  Future<ApiResponse> requestJoin(Map<String, dynamic> body) =>
      _api.post(endpoint: 'user/pmam/investor/request-join', data: body);

  Future<ApiResponse> investorDeposit(Map<String, dynamic> body) =>
      _api.post(endpoint: 'user/pmam/investor/deposit', data: body);

  Future<ApiResponse> unsubscribe(int investorId) =>
      _api.post(endpoint: 'user/pmam/investor/unsubscribe/$investorId');

  Future<ApiResponse> getPnlHistory() =>
      _api.get(endpoint: 'user/pmam/investor/pnl-history');

  Future<ApiResponse> getMyFundEntries() =>
      _api.get(endpoint: 'user/pmam/investor/my-fund-entries');

  Future<ApiResponse> getInvestorEnrollments() =>
      _api.get(endpoint: 'user/pmam/investor/enrollments');

  Future<ApiResponse> getMyOpenAllocations() =>
      _api.get(endpoint: 'user/pmam/investor/my-open-allocations');

  /// Public fund-manager profile (used by Explore → View Manager screen).
  /// GET /user/pmam/managers/{managerCode}
  Future<ApiResponse> getManagerProfile(String managerCode) {
    final t = DateTime.now().millisecondsSinceEpoch;
    return _api.get(
      endpoint: 'user/pmam/managers/$managerCode?_t=$t',
    );
  }

  /// Public open positions for a given manager + plan.
  /// GET /user/pmam/managers/{managerCode}/open-positions?plan_id={planId}
  Future<ApiResponse> getManagerOpenPositions({
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
  Future<ApiResponse> getManagerTradesPublic({
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

  Future<ApiResponse> getManagerTrades({
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
    return _api.get(
      endpoint: 'user/pmam/managers/$managerCode/trades?$p',
    );
  }
}

