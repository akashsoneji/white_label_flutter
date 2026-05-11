import 'package:crm_app/core/network/api_response.dart';
import 'pmam_repository.dart';
import '../datasources/pmam_remote_data_source.dart';

class PmamRepositoryImpl implements PmamRepository {
  final PmamRemoteDataSource _remote;

  PmamRepositoryImpl(this._remote);

  @override
  Future<ApiResponse> getManagerStatus() => _remote.getManagerStatus();

  @override
  Future<ApiResponse> applyAsManager() => _remote.applyAsManager();

  @override
  Future<ApiResponse> getManagerPlans() => _remote.getManagerPlans();

  @override
  Future<ApiResponse> createPlan(Map<String, dynamic> body) =>
      _remote.createPlan(body);

  @override
  Future<ApiResponse> inactivatePlan(int planId) => _remote.inactivatePlan(planId);

  @override
  Future<ApiResponse> getManagerDashboardStats() => _remote.getManagerDashboardStats();

  @override
  Future<ApiResponse> getInvestorRequests(int planId) => _remote.getInvestorRequests(planId);

  @override
  Future<ApiResponse> getManagerInvestors() => _remote.getManagerInvestors();

  @override
  Future<ApiResponse> approveInvestorRequest(int requestId) =>
      _remote.approveInvestorRequest(requestId);

  @override
  Future<ApiResponse> rejectInvestorRequest(int requestId) =>
      _remote.rejectInvestorRequest(requestId);

  @override
  Future<ApiResponse> getPlanDetail(int planId) => _remote.getPlanDetail(planId);

  @override
  Future<ApiResponse> getPlanAllocations(
    int planId, {
    int page = 1,
    int perPage = 15,
    String? dateFrom,
    String? dateTo,
    String? userId,
    String? status,
  }) =>
      _remote.getPlanAllocations(
        planId,
        page: page,
        perPage: perPage,
        dateFrom: dateFrom,
        dateTo: dateTo,
        userId: userId,
        status: status,
      );

  @override
  Future<ApiResponse> getPlanInvestors(
    int planId, {
    int page = 1,
    int perPage = 10,
    String? sortBy,
    String? order,
    String? search,
  }) =>
      _remote.getPlanInvestors(
        planId,
        page: page,
        perPage: perPage,
        sortBy: sortBy,
        order: order,
        search: search,
      );

  @override
  Future<ApiResponse> getManagerInvestorDetail(int investorId) =>
      _remote.getManagerInvestorDetail(investorId);

  @override
  Future<ApiResponse> getAvailablePlans() => _remote.getAvailablePlans();

  @override
  Future<ApiResponse> getEligibleAccounts([int? planId]) =>
      _remote.getEligibleAccounts(planId);

  @override
  Future<ApiResponse> getManagersDataTable({
    String search = '',
    int start = 0,
    int length = 50,
    int draw = 1,
  }) =>
      _remote.getManagersDataTable(
        search: search,
        start: start,
        length: length,
        draw: draw,
      );

  @override
  Future<ApiResponse> requestJoin(Map<String, dynamic> body) =>
      _remote.requestJoin(body);

  @override
  Future<ApiResponse> investorDeposit(Map<String, dynamic> body) =>
      _remote.investorDeposit(body);

  @override
  Future<ApiResponse> unsubscribe(int investorId) => _remote.unsubscribe(investorId);

  @override
  Future<ApiResponse> getPnlHistory() => _remote.getPnlHistory();

  @override
  Future<ApiResponse> getMyFundEntries() => _remote.getMyFundEntries();

  @override
  Future<ApiResponse> getInvestorEnrollments() => _remote.getInvestorEnrollments();

  @override
  Future<ApiResponse> getMyOpenAllocations() => _remote.getMyOpenAllocations();

  @override
  Future<ApiResponse> getManagerTrades({
    required String managerCode,
    required int planId,
    required String dateFrom,
    required String dateTo,
    int page = 1,
    int perPage = 20,
    int? investorId,
  }) =>
      _remote.getManagerTrades(
        managerCode: managerCode,
        planId: planId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
        investorId: investorId,
      );
}

