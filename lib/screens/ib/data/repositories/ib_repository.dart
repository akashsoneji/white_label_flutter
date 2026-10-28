import 'package:crm_app/core/network/api_response.dart';

abstract class IbRepository {
  Future<ApiResponse> getIbStatus({Map<String, dynamic>? queryParameters});
  Future<ApiResponse> submitIbApplication({required Map<String, dynamic> payload});
  Future<ApiResponse> getIbDashboard({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> getIbClients({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> getIbSubIbs({
    int? subIbId,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getIbTradeHistory({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> getIbStats({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> getIbSubIbStats({
    required int subIbId,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getIbStructure({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> getIbSubIbStructure({
    required int subIbId,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getIbApprovalRequests({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> getIbApprovalRequestsFallback({
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getCommissionGroups({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> manageCommissionGroup({required Map<String, dynamic> payload});

  Future<ApiResponse> deleteCommissionGroup({required int groupId});

  Future<ApiResponse> updateIbStatusRequest({
    required int requestId,
    required Map<String, dynamic> payload,
  });

  // IB Transfer Methods
  Future<ApiResponse> ibTransferInit();
  Future<ApiResponse> searchIbTransferClients({required String query});
  Future<ApiResponse> storeIbTransfer({required Map<String, dynamic> payload});
  Future<ApiResponse> getIbTransferHistory({Map<String, dynamic>? queryParameters});
  Future<ApiResponse> cancelIbTransfer({required int transferId});

  Future<ApiResponse> getIbActivities();
  Future<ApiResponse> getIbTreeStructure();
  Future<ApiResponse> getIbDetails({required String userSlug});
  Future<ApiResponse> getTemplateRates({required int templateId});
}

