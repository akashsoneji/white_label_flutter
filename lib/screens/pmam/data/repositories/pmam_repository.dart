import 'package:crm_app/core/network/api_response.dart';

abstract class PmamRepository {
  // Manager
  Future<ApiResponse> getManagerStatus();
  Future<ApiResponse> applyAsManager();
  Future<ApiResponse> getManagerPlans();
  Future<ApiResponse> createPlan(Map<String, dynamic> body);
  Future<ApiResponse> inactivatePlan(int planId);
  Future<ApiResponse> getManagerDashboardStats();
  Future<ApiResponse> getInvestorRequests(int planId);
  Future<ApiResponse> getManagerInvestors();
  Future<ApiResponse> approveInvestorRequest(int requestId);
  Future<ApiResponse> rejectInvestorRequest(int requestId);
  Future<ApiResponse> getPlanDetail(int planId);
  Future<ApiResponse> getPlanAllocations(
    int planId, {
    int page = 1,
    int perPage = 15,
    String? dateFrom,
    String? dateTo,
    String? userId,
    String? status,
  });
  Future<ApiResponse> getPlanInvestors(
    int planId, {
    int page = 1,
    int perPage = 10,
    String? sortBy,
    String? order,
    String? search,
  });
  Future<ApiResponse> getManagerInvestorDetail(int investorId);

  // Investor
  Future<ApiResponse> getAvailablePlans();
  Future<ApiResponse> getEligibleAccounts([int? planId]);
  Future<ApiResponse> getManagersDataTable({
    String search = '',
    int start = 0,
    int length = 50,
    int draw = 1,
  });
  Future<ApiResponse> requestJoin(Map<String, dynamic> body);
  Future<ApiResponse> investorDeposit(Map<String, dynamic> body);
  Future<ApiResponse> unsubscribe(int investorId);
  Future<ApiResponse> getPnlHistory();
  Future<ApiResponse> getMyFundEntries();
  Future<ApiResponse> getInvestorEnrollments();
  Future<ApiResponse> getMyOpenAllocations();
  Future<ApiResponse> getManagerTrades({
    required String managerCode,
    required int planId,
    required String dateFrom,
    required String dateTo,
    int page = 1,
    int perPage = 20,
    int? investorId,
  });
}

