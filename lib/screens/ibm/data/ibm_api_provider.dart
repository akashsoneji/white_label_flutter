import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/api_service.dart';

class IbmApiProvider {
  /// Calls GET /api/ibm/client/system to check if the user is in IBM or legacy system,
  /// whether they are a partner, etc.
  Future<ApiResponse> getSystemStatus() async {
    return await ApiService.get(endpoint: 'ibm/client/system');
  }

  /// Submit partner request
  Future<ApiResponse> submitPartnerRequest(String message) async {
    return await ApiService.post(
      endpoint: 'ibm/client/partner-request',
      data: {'message': message},
    );
  }

  /// Get partner request status
  Future<ApiResponse> getPartnerRequestStatus() async {
    return await ApiService.get(endpoint: 'ibm/client/partner-request');
  }

  /// Get IBM Portal Dashboard
  Future<ApiResponse> getPortalDashboard({
    String period = 'this_month',
    String scope = 'total',
    String? from,
    String? to,
  }) async {
    final Map<String, dynamic> queryParams = {'period': period, 'scope': scope};
    if (from != null && from.isNotEmpty) queryParams['from'] = from;
    if (to != null && to.isNotEmpty) queryParams['to'] = to;
    return await ApiService.get(
      endpoint: 'ibm/portal/dashboard',
      queryParameters: queryParams,
    );
  }

  /// Get IBM Portal Dashboard Activity
  Future<ApiResponse> getPortalDashboardActivity() async {
    return await ApiService.get(endpoint: 'ibm/portal/dashboard/activity');
  }

  /// Get IBM Portal Clients
  Future<ApiResponse> getPortalClients({
    String period = 'this_month',
    String scope = 'direct',
    int page = 1,
  }) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/clients',
      queryParameters: {
        'period': period,
        'scope': scope,
        'page': page.toString(),
        'per_page': '25',
      },
    );
  }

  /// Get IBM Portal Wallet
  Future<ApiResponse> getPortalWallet() async {
    return await ApiService.get(endpoint: 'ibm/portal/wallet');
  }

  /// Get IBM Portal Wallet Transactions / Earnings Ledger
  Future<ApiResponse> getPortalWalletTransactions({
    String? currency,
    String? type,
    int page = 1,
    int perPage = 25,
  }) async {
    final Map<String, String> query = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (currency != null && currency.isNotEmpty) query['currency'] = currency;
    if (type != null && type.isNotEmpty && type != 'all' && type != 'Everything') query['type'] = type;
    return await ApiService.get(
      endpoint: 'ibm/portal/wallet/transactions',
      queryParameters: query,
    );
  }

  /// Request a payout withdrawal
  Future<ApiResponse> requestWithdrawal({
    required String currency,
    required double amount,
    String? methodSlug,
    int? withdrawalMethodId,
  }) async {
    final data = <String, dynamic>{
      'currency': currency,
      'amount': amount,
    };
    if (methodSlug != null) data['method_slug'] = methodSlug;
    if (withdrawalMethodId != null) data['withdrawal_method_id'] = withdrawalMethodId;
    return await ApiService.post(
      endpoint: 'ibm/portal/wallet/withdraw',
      data: data,
    );
  }

  /// Get Sub-IB Requests
  Future<ApiResponse> getPortalRequests({String status = 'all'}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/requests',
      queryParameters: {'status': status},
    );
  }

  /// Approve Sub-IB Request
  Future<ApiResponse> approveRequest({
    required int requestId,
    required int planId,
    List<int>? planGroupIds,
  }) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/requests/$requestId/approve',
      data: {
        'plan_id': planId,
        if (planGroupIds != null) 'plan_group_ids': planGroupIds,
      },
    );
  }

  /// Reject Sub-IB Request
  Future<ApiResponse> rejectRequest({
    required int requestId,
    String? reason,
  }) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/requests/$requestId/reject',
      data: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  /// Get Partner Commission Plans
  Future<ApiResponse> getPartnerPlans() async {
    return await ApiService.get(endpoint: 'ibm/portal/partner-plans');
  }

  /// Get Partner Plan Template / Symbol Catalog for Plan Builder
  Future<ApiResponse> getPartnerPlanTemplate() async {
    return await ApiService.get(endpoint: 'ibm/portal/partner-plans/template');
  }

  /// Create a new Partner Plan
  Future<ApiResponse> createPartnerPlan(Map<String, dynamic> data) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/partner-plans',
      data: data,
    );
  }

  /// Delete a Partner Plan
  Future<ApiResponse> deletePartnerPlan(int planId) async {
    return await ApiService.delete(endpoint: 'ibm/portal/partner-plans/$planId');
  }

  /// Get Referral Links
  Future<ApiResponse> getReferralLinks() async {
    return await ApiService.get(endpoint: 'ibm/portal/links');
  }

  /// Create Referral Link
  Future<ApiResponse> createReferralLink({
    required String label,
    String? code,
    List<int>? planGroupIds,
    int? defaultPlanGroupId,
  }) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/links',
      data: {
        'label': label,
        if (code != null && code.isNotEmpty) 'code': code,
        if (planGroupIds != null) 'plan_group_ids': planGroupIds,
        if (defaultPlanGroupId != null) 'default_plan_group_id': defaultPlanGroupId,
      },
    );
  }

  // --- Network Profile APIs ---

  /// Get Client Profile Overview
  Future<ApiResponse> getClientOverview(int id, {String period = 'mtd'}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/clients/$id',
      queryParameters: {'period': period},
    );
  }

  /// Get Client Trades
  Future<ApiResponse> getClientTrades(
    int id, {
    String period = 'mtd',
    int page = 1,
    String? type,
    String? symbol,
  }) async {
    final Map<String, String> params = {
      'period': period,
      'page': page.toString(),
    };
    if (type != null && type.isNotEmpty && type != 'All') params['type'] = type.toLowerCase();
    if (symbol != null && symbol.isNotEmpty) params['symbol'] = symbol;

    return await ApiService.get(
      endpoint: 'ibm/portal/clients/$id/trades',
      queryParameters: params,
    );
  }

  /// Get Network Node (for Network tree tab)
  Future<ApiResponse> getNetworkNode(int id, {String period = 'mtd'}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$id/node',
      queryParameters: {'period': period},
    );
  }

  /// Get Symbol-wise Commission
  Future<ApiResponse> getNetworkSymbols(int id, {String period = 'mtd'}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$id/symbols',
      queryParameters: {'period': period},
    );
  }

  /// Get Commission Plan for a node
  Future<ApiResponse> getNetworkPlan(int id) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$id/plan',
    );
  }
}
