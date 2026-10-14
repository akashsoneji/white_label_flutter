import 'dart:typed_data';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/http_client_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';

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
    String period = 'mtd',
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
  Future<ApiResponse> getPortalDashboardActivity({int limit = 5}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/dashboard/activity',
      queryParameters: {'limit': limit.toString()},
    );
  }

  /// Get IBM Portal Network (Sub-IBs)
  Future<ApiResponse> getPortalNetwork({
    String period = 'mtd',
    int page = 1,
  }) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/network',
      queryParameters: {
        'period': period,
        'page': page.toString(),
        'per_page': '5',
      },
    );
  }

  /// Get IBM Portal Clients
  Future<ApiResponse> getPortalClients({
    String period = 'mtd',
    String scope = 'direct',
    int page = 1,
    int perPage = 25,
    String? search,
    String? status,
    String? linkId,
    String? from,
    String? to,
  }) async {
    final Map<String, String> query = {
      'period': period,
      'scope': scope,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (linkId != null && linkId.isNotEmpty) query['link_id'] = linkId;
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;
    return await ApiService.get(
      endpoint: 'ibm/portal/clients',
      queryParameters: query,
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
    String? search,
    int page = 1,
    int perPage = 25,
  }) async {
    final Map<String, String> query = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (currency != null && currency.isNotEmpty) query['currency'] = currency;
    if (type != null && type.isNotEmpty && type != 'all' && type != 'Everything') query['type'] = type;
    if (search != null && search.isNotEmpty) query['search'] = search;
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

  /// Get details of an existing Partner Plan
  Future<ApiResponse> getPartnerPlanDetail(int planId) async {
    return await ApiService.get(endpoint: 'ibm/portal/partner-plans/$planId');
  }

  /// Create a new Partner Plan
  Future<ApiResponse> createPartnerPlan(Map<String, dynamic> data) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/partner-plans',
      data: data,
    );
  }

  /// Update an existing Partner Plan
  Future<ApiResponse> updatePartnerPlan(int planId, Map<String, dynamic> data) async {
    return await ApiService.put(
      endpoint: 'ibm/portal/partner-plans/$planId',
      data: data,
    );
  }

  /// Commission distribution form data (balance, currency, limits)
  Future<ApiResponse> getDistributionFormData() async {
    return await ApiService.get(
      endpoint: 'ibm/portal/commission-distributions/create',
    );
  }

  /// Search the IB's own clients for the distribution picker
  Future<ApiResponse> searchDistributionClients({String search = ''}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/commission-distributions/clients',
      queryParameters: {if (search.isNotEmpty) 'search': search},
    );
  }

  /// Send commission to a client; created as pending broker approval
  Future<ApiResponse> createDistribution({
    required int clientUserId,
    required num amount,
    String? comment,
  }) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/commission-distributions',
      data: {
        'client_user_id': clientUserId,
        'amount': amount,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }

  /// Past commission distributions (paginated)
  Future<ApiResponse> getDistributionHistory({
    int page = 1,
    int perPage = 25,
  }) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/commission-distributions',
      queryParameters: {'page': '$page', 'per_page': '$perPage'},
    );
  }

  /// Cancel a pending distribution; held amount returns to the IB wallet
  Future<ApiResponse> cancelDistribution(int distributionId) async {
    return await ApiService.delete(
      endpoint: 'ibm/portal/commission-distributions/$distributionId',
    );
  }

  /// Team deposits / withdrawals of the IB's clients.
  /// `type`: deposit | withdrawal (null = both). Dates are Y-m-d, optional.
  Future<ApiResponse> getClientFunding({
    String? from,
    String? to,
    String? type,
    int page = 1,
    int perPage = 25,
  }) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/client-funding',
      queryParameters: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (type != null) 'type': type,
        'page': '$page',
        'per_page': '$perPage',
      },
    );
  }

  /// Commission earned per trade or per account. `from`/`to` are required.
  /// `type` is the trade side: buy | sell.
  Future<ApiResponse> getCommissionReport({
    required String from,
    required String to,
    String view = 'trade',
    String? mt5Account,
    String? symbol,
    String? type,
    int page = 1,
    int perPage = 25,
  }) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/commission-report',
      queryParameters: {
        'from': from,
        'to': to,
        'view': view,
        if (mt5Account != null && mt5Account.isNotEmpty)
          'mt5_account': mt5Account,
        if (symbol != null && symbol.isNotEmpty) 'symbol': symbol,
        if (type != null && type.isNotEmpty) 'type': type,
        'page': '$page',
        'per_page': '$perPage',
      },
    );
  }

  /// IB's own payout requests. `from`/`to` are required.
  Future<ApiResponse> getPayoutReport({
    required String from,
    required String to,
    String? status,
    int page = 1,
    int perPage = 25,
  }) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/payout-report',
      queryParameters: {
        'from': from,
        'to': to,
        if (status != null && status.isNotEmpty) 'status': status,
        'page': '$page',
        'per_page': '$perPage',
      },
    );
  }

  /// Exports the IB started, newest first
  Future<ApiResponse> getExports() async {
    return await ApiService.get(endpoint: 'ibm/portal/exports');
  }

  /// Queue a CSV build. `kind`: commission_history | client_funding | ib_payouts.
  /// `filters` may hold from, to, type, status, view, symbol, side.
  Future<ApiResponse> startExport({
    required String kind,
    Map<String, dynamic> filters = const {},
  }) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/exports',
      data: {
        'kind': kind,
        for (final e in filters.entries)
          if (e.value != null) e.key: e.value,
      },
    );
  }

  /// Poll one export until `status` is ready
  Future<ApiResponse> getExportStatus(int exportId) async {
    return await ApiService.get(endpoint: 'ibm/portal/exports/$exportId');
  }

  /// Download the CSV. The endpoint returns text/csv, not the JSON envelope,
  /// so it bypasses ApiService parsing. Returns null on a non-200 response.
  Future<Uint8List?> downloadExport(int exportId) async {
    final token = await SecureStorageService.getAuthToken();
    final response = await HttpClientService.instance.client
        .get(
          Uri.parse(
            '${ApiConstants.baseUrl}ibm/portal/exports/$exportId/download',
          ),
          headers: {
            'Accept': 'text/csv',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 60));
    return response.statusCode == 200 ? response.bodyBytes : null;
  }

  /// Rename a Partner Plan (name/description only)
  Future<ApiResponse> renamePartnerPlan(
    int planId, {
    required String planName,
    String? description,
  }) async {
    return await ApiService.patch(
      endpoint: 'ibm/portal/partner-plans/$planId/rename',
      data: {
        'plan_name': planName,
        if (description != null) 'description': description,
      },
    );
  }

  /// Delete a Partner Plan
  Future<ApiResponse> deletePartnerPlan(int planId) async {
    return await ApiService.delete(endpoint: 'ibm/portal/partner-plans/$planId');
  }

  /// Get Assignable Sub-IBs for a plan
  Future<ApiResponse> getAssignableSubIbs() async {
    return await ApiService.get(endpoint: 'ibm/portal/partner-plans/sub-ibs');
  }

  /// Assign a plan to a Sub-IB
  Future<ApiResponse> assignPartnerPlan(int planId, int ibUserId) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/partner-plans/$planId/assign',
      data: {'ib_user_id': ibUserId},
    );
  }

  /// Get Referral Links
  Future<ApiResponse> getReferralLinks() async {
    return await ApiService.get(endpoint: 'ibm/portal/links');
  }

  /// Get Portal Plan Groups
  Future<ApiResponse> getPortalPlanGroups() async {
    return await ApiService.get(endpoint: 'ibm/portal/plan/groups');
  }

  /// Create Referral Link
  Future<ApiResponse> createReferralLink({
    required String label,
    String? code,
    List<int>? planGroupIds,
    int? defaultPlanGroupId,
    String? expiresAt,
  }) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/links',
      data: {
        'label': label,
        if (code != null && code.isNotEmpty) 'code': code,
        if (planGroupIds != null) 'plan_group_ids': planGroupIds,
        if (defaultPlanGroupId != null) 'default_plan_group_id': defaultPlanGroupId,
        if (expiresAt != null && expiresAt.isNotEmpty) 'expires_at': expiresAt,
      },
    );
  }

  /// Update Referral Link
  Future<ApiResponse> updateReferralLink({
    required int linkId,
    String? label,
    List<int>? planGroupIds,
    int? defaultPlanGroupId,
    bool? isActive,
    String? expiresAt,
  }) async {
    final Map<String, dynamic> data = {};
    if (label != null) data['label'] = label;
    if (planGroupIds != null) data['plan_group_ids'] = planGroupIds;
    if (defaultPlanGroupId != null) data['default_plan_group_id'] = defaultPlanGroupId;
    if (isActive != null) data['is_active'] = isActive;
    if (expiresAt != null) data['expires_at'] = expiresAt;

    return await ApiService.put(
      endpoint: 'ibm/portal/links/$linkId',
      data: data,
    );
  }

  /// Delete Referral Link
  Future<ApiResponse> deleteReferralLink(int linkId) async {
    return await ApiService.delete(endpoint: 'ibm/portal/links/$linkId');
  }

  // --- Network Profile APIs ---

  /// Get Client Profile Overview
  Future<ApiResponse> getClientOverview(
    int id, {
    String period = 'mtd',
    String? from,
    String? to,
  }) async {
    final Map<String, String> query = {'period': period};
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;
    return await ApiService.get(
      endpoint: 'ibm/portal/clients/$id',
      queryParameters: query,
    );
  }

  /// Get Client Trades
  Future<ApiResponse> getClientTrades(
    int id, {
    String period = 'mtd',
    String? from,
    String? to,
    int page = 1,
    String? type,
    String? symbol,
  }) async {
    final Map<String, String> params = {
      'period': period,
      'page': page.toString(),
    };
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;
    if (type != null && type.isNotEmpty && type != 'All') params['type'] = type.toLowerCase();
    if (symbol != null && symbol.isNotEmpty) params['symbol'] = symbol;

    return await ApiService.get(
      endpoint: 'ibm/portal/clients/$id/trades',
      queryParameters: params,
    );
  }

  /// Get Network Node (for Network tree tab)
  Future<ApiResponse> getNetworkNode(
    int id, {
    String period = 'mtd',
    String? from,
    String? to,
  }) async {
    final Map<String, String> query = {'period': period};
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$id/node',
      queryParameters: query,
    );
  }

  /// Get Symbol-wise Commission
  Future<ApiResponse> getNetworkSymbols(
    int id, {
    String period = 'mtd',
    String? from,
    String? to,
    String? q,
  }) async {
    final Map<String, String> query = {'period': period};
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;
    if (q != null && q.isNotEmpty) query['q'] = q;
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$id/symbols',
      queryParameters: query,
    );
  }

  /// Get Commission Plan for a node
  Future<ApiResponse> getNetworkPlan(int id) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$id/plan',
    );
  }

  /// Get Client Visibility
  Future<ApiResponse> getClientVisibility() async {
    return await ApiService.get(
      endpoint: 'ibm/portal/client-visibility',
    );
  }

  /// Update Client Visibility
  Future<ApiResponse> updateClientVisibility({
    required List<int> planGroupIds,
    int? defaultPlanGroupId,
  }) async {
    final Map<String, dynamic> data = {
      'plan_group_ids': planGroupIds,
    };
    if (defaultPlanGroupId != null) {
      data['default_plan_group_id'] = defaultPlanGroupId;
    }
    return await ApiService.post(
      endpoint: 'ibm/portal/client-visibility',
      data: data,
    );
  }

  /// Get Marketing Materials
  Future<ApiResponse> getMarketingMaterials({
    String? category,
    String? q,
  }) async {
    final Map<String, String> query = {};
    if (category != null && category.isNotEmpty && category != 'all') {
      query['category'] = category;
    }
    if (q != null && q.isNotEmpty) {
      query['q'] = q;
    }
    return await ApiService.get(
      endpoint: 'ibm/portal/marketing',
      queryParameters: query.isNotEmpty ? query : null,
    );
  }

  /// Download Marketing Material (stream URL or binary)
  Future<ApiResponse> downloadMarketingMaterial(int materialId) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/marketing/$materialId/download',
    );
  }

  /// Get IBM Portal Network Summary (direct / network / total scopes)
  Future<ApiResponse> getPortalNetworkSummary({String period = 'this_month'}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/network/summary',
      queryParameters: {'period': period},
    );
  }

  /// Get IBM Portal Network Tree Summary
  Future<ApiResponse> getPortalNetworkTreeSummary({String? period}) async {
    final Map<String, String> query = {};
    if (period != null && period.isNotEmpty) query['period'] = period;
    return await ApiService.get(
      endpoint: 'ibm/portal/network/tree-summary',
      queryParameters: query.isNotEmpty ? query : null,
    );
  }

  /// Get IBM Portal Network Performance (Ranked Partners)
  Future<ApiResponse> getPortalNetworkPerformance({
    String period = 'mtd',
    String? sort,
    String? dir,
    String? q,
    String? from,
    String? to,
    int page = 1,
    int perPage = 25,
  }) async {
    final Map<String, String> query = {
      'period': period,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (sort != null && sort.isNotEmpty) query['sort'] = sort;
    if (dir != null && dir.isNotEmpty) query['dir'] = dir;
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;
    return await ApiService.get(
      endpoint: 'ibm/portal/network/performance',
      queryParameters: query,
    );
  }

  /// Get Partner Detail (Show)
  Future<ApiResponse> getPartnerDetail(int partnerUserId, {String? period}) async {
    final Map<String, String> query = {};
    if (period != null && period.isNotEmpty) query['period'] = period;
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$partnerUserId',
      queryParameters: query.isNotEmpty ? query : null,
    );
  }

  /// Get Partner Wallet
  Future<ApiResponse> getPartnerWallet(
    int partnerUserId, {
    String? period,
  }) async {
    final Map<String, String> query = {};
    if (period != null && period.isNotEmpty) query['period'] = period;
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$partnerUserId/wallet',
      queryParameters: query.isNotEmpty ? query : null,
    );
  }

  /// Get Partner Referral Links
  Future<ApiResponse> getPartnerLinks(int partnerUserId) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/network/$partnerUserId/links',
    );
  }

  /// Get Clients Network Tree
  Future<ApiResponse> getClientsNetworkTree({
    String period = 'today',
    String? from,
    String? to,
  }) async {
    final Map<String, String> query = {};
    if (period.isNotEmpty) query['period'] = period;
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;
    return await ApiService.get(
      endpoint: 'ibm/portal/clients/network-tree',
      queryParameters: query.isNotEmpty ? query : null,
    );
  }

  /// Get Client Accounts
  Future<ApiResponse> getClientAccounts(int clientId) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/clients/$clientId/accounts',
    );
  }

  /// Get Client Trades for a specific account
  Future<ApiResponse> getClientAccountTrades(
    int clientId,
    int accountId, {
    int page = 1,
    int perPage = 50,
  }) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/clients/$clientId/accounts/$accountId/trades',
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      },
    );
  }

  /// Move Client under a different Sub-IB
  Future<ApiResponse> moveClient(int clientId, int targetIbId) async {
    return await ApiService.post(
      endpoint: 'ibm/portal/clients/$clientId/move',
      data: {'target_ib_id': targetIbId},
    );
  }

  /// Get My Commission Plan
  Future<ApiResponse> getMyPlan() async {
    return await ApiService.get(endpoint: 'ibm/portal/plan');
  }

  /// Cancel Payout Request
  Future<ApiResponse> cancelPayout(int payoutId, {String? reason}) async {
    return await ApiService.delete(
      endpoint: 'ibm/portal/wallet/payout/$payoutId',
      data: (reason != null && reason.isNotEmpty) ? {'reason': reason} : null,
    );
  }

  /// Get Referral Link Stats
  Future<ApiResponse> getLinkStats(int linkId, {String period = '30d'}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/links/$linkId/stats',
      queryParameters: {'period': period},
    );
  }

  /// Get Referral Link Clients
  Future<ApiResponse> getLinkClients(int linkId, {String period = 'all'}) async {
    return await ApiService.get(
      endpoint: 'ibm/portal/links/$linkId/clients',
      queryParameters: {'period': period},
    );
  }
}
