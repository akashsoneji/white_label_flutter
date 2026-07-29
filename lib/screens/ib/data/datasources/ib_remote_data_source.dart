import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

class IbRemoteDataSource {
  final ApiClient _api;
  IbRemoteDataSource(this._api);

  Future<ApiResponse> getIbStatus({Map<String, dynamic>? queryParameters}) {
    return _api.get(endpoint: ApiConstants.ibStatus, queryParameters: queryParameters);
  }

  Future<ApiResponse> submitIbApplication({required Map<String, dynamic> payload}) {
    return _api.post(endpoint: ApiConstants.ibApplication, data: payload);
  }

  Future<ApiResponse> getIbDashboard({Map<String, dynamic>? queryParameters}) {
    return _api.get(endpoint: ApiConstants.ibDashboard, queryParameters: queryParameters);
  }

  Future<ApiResponse> getIbClients({Map<String, dynamic>? queryParameters}) {
    return _api.get(endpoint: ApiConstants.ibClients, queryParameters: queryParameters);
  }

  Future<ApiResponse> getIbSubIbs({
    int? subIbId,
    Map<String, dynamic>? queryParameters,
  }) {
    final endpoint =
        subIbId != null ? '${ApiConstants.ibSubIbSubIbs}$subIbId' : ApiConstants.ibSubIbs;
    return _api.get(endpoint: endpoint, queryParameters: queryParameters);
  }

  Future<ApiResponse> getIbTradeHistory({Map<String, dynamic>? queryParameters}) {
    return _api.get(endpoint: ApiConstants.ibTradeHistory, queryParameters: queryParameters);
  }

  Future<ApiResponse> getIbStats({Map<String, dynamic>? queryParameters}) {
    return _api.get(endpoint: ApiConstants.ibStats, queryParameters: queryParameters);
  }

  Future<ApiResponse> getIbSubIbStats({
    required int subIbId,
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: '${ApiConstants.ibSubIbStats}$subIbId',
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> getIbStructure({Map<String, dynamic>? queryParameters}) {
    return _api.get(endpoint: ApiConstants.ibStructure, queryParameters: queryParameters);
  }

  Future<ApiResponse> getIbSubIbStructure({
    required int subIbId,
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: '${ApiConstants.ibSubIbStructure}$subIbId',
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> getIbApprovalRequests({Map<String, dynamic>? queryParameters}) {
    return _api.get(endpoint: ApiConstants.ibRequestList, queryParameters: queryParameters);
  }

  Future<ApiResponse> getIbApprovalRequestsFallback({
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: ApiConstants.ibSubIbApprovalRequests,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> getCommissionGroups({Map<String, dynamic>? queryParameters}) {
    return _api.get(endpoint: ApiConstants.ibCommissionGroups, queryParameters: queryParameters);
  }

  Future<ApiResponse> manageCommissionGroup({required Map<String, dynamic> payload}) {
    return _api.post(endpoint: ApiConstants.ibManage, data: payload);
  }

  Future<ApiResponse> deleteCommissionGroup({required int groupId}) {
    return _api.delete(endpoint: '${ApiConstants.ibCommissionGroups}/$groupId');
  }

  Future<ApiResponse> updateIbStatusRequest({
    required int requestId,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(endpoint: '${ApiConstants.ibUpdateStatus}$requestId', data: payload);
  }

  // IB Transfer Methods
  Future<ApiResponse> ibTransferInit() {
    return _api.get(endpoint: ApiConstants.ibTransferCreate);
  }

  Future<ApiResponse> searchIbTransferClients({required String query}) {
    return _api.get(
      endpoint: ApiConstants.ibTransferClientsSearch,
      queryParameters: {'search': query},
    );
  }

  Future<ApiResponse> storeIbTransfer({required Map<String, dynamic> payload}) {
    return _api.post(endpoint: ApiConstants.ibTransferStore, data: payload);
  }

  Future<ApiResponse> getIbTransferHistory({Map<String, dynamic>? queryParameters}) {
    return _api.get(
      endpoint: ApiConstants.ibTransferHistory,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> cancelIbTransfer({required int transferId}) {
    // According to REST patterns and postman, it is usually POST or DELETE or just POST with _method=DELETE
    // Depending on backend, let's use POST by default for /cancel, or GET. Wait, the curl says POST or GET. "https://dev.tenaxcodecrm.com/api/user/ib/transfer/1/cancel"
    return _api.post(endpoint: '${ApiConstants.ibTransferCancel}$transferId/cancel');
  }
}

