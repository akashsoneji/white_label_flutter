import 'package:crm_app/core/network/api_response.dart';

import 'ib_repository.dart';
import '../datasources/ib_remote_data_source.dart';

class IbRepositoryImpl implements IbRepository {
  final IbRemoteDataSource _remote;
  IbRepositoryImpl(this._remote);

  @override
  Future<ApiResponse> deleteCommissionGroup({required int groupId}) {
    return _remote.deleteCommissionGroup(groupId: groupId);
  }

  @override
  Future<ApiResponse> getCommissionGroups({Map<String, dynamic>? queryParameters}) {
    return _remote.getCommissionGroups(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbApprovalRequests({Map<String, dynamic>? queryParameters}) {
    return _remote.getIbApprovalRequests(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbApprovalRequestsFallback({Map<String, dynamic>? queryParameters}) {
    return _remote.getIbApprovalRequestsFallback(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbClients({Map<String, dynamic>? queryParameters}) {
    return _remote.getIbClients(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbDashboard({Map<String, dynamic>? queryParameters}) {
    return _remote.getIbDashboard(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbStats({Map<String, dynamic>? queryParameters}) {
    return _remote.getIbStats(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbStatus({Map<String, dynamic>? queryParameters}) {
    return _remote.getIbStatus(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbStructure({Map<String, dynamic>? queryParameters}) {
    return _remote.getIbStructure(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbSubIbStats({
    required int subIbId,
    Map<String, dynamic>? queryParameters,
  }) {
    return _remote.getIbSubIbStats(subIbId: subIbId, queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbSubIbStructure({
    required int subIbId,
    Map<String, dynamic>? queryParameters,
  }) {
    return _remote.getIbSubIbStructure(subIbId: subIbId, queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbSubIbs({int? subIbId, Map<String, dynamic>? queryParameters}) {
    return _remote.getIbSubIbs(subIbId: subIbId, queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getIbTradeHistory({Map<String, dynamic>? queryParameters}) {
    return _remote.getIbTradeHistory(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> manageCommissionGroup({required Map<String, dynamic> payload}) {
    return _remote.manageCommissionGroup(payload: payload);
  }

  @override
  Future<ApiResponse> submitIbApplication({required Map<String, dynamic> payload}) {
    return _remote.submitIbApplication(payload: payload);
  }

  @override
  Future<ApiResponse> updateIbStatusRequest({
    required int requestId,
    required Map<String, dynamic> payload,
  }) {
    return _remote.updateIbStatusRequest(requestId: requestId, payload: payload);
  }
}

