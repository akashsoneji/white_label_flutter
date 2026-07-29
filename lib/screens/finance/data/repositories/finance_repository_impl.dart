import 'dart:io';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

import 'finance_repository.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  final ApiClient _api;
  FinanceRepositoryImpl(this._api);

  @override
  Future<ApiResponse> topupDemoAccount({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(
      endpoint: ApiConstants.topupDemoAccount,
      token: token,
      data: payload,
    );
  }

  @override
  Future<ApiResponse> getDepositMethodDetail({
    required String token,
    required String slug,
  }) {
    return _api.get(
      endpoint: '${ApiConstants.depositList}/$slug',
      token: token,
    );
  }

  @override
  Future<ApiResponse> getDepositMethods({required String token}) {
    return _api.get(endpoint: ApiConstants.depositList, token: token);
  }

  @override
  Future<ApiResponse> submitDepositRequestWithProof({
    required String token,
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
  }) {
    return _api.uploadImageDepositRequest(
      endpoint: endpoint,
      file: file,
      token: token,
      formData: formData,
    );
  }

  @override
  Future<ApiResponse> getWithdrawalMethods({required String token}) {
    return _api.get(endpoint: ApiConstants.withdrawalRequest, token: token);
  }

  @override
  Future<ApiResponse> getWithdrawalMethodDetail({
    required String token,
    required String slug,
  }) {
    return _api.get(
      endpoint: '${ApiConstants.withdrawalMethods}$slug',
      token: token,
    );
  }

  @override
  Future<ApiResponse> sendWithdrawalOtp({
    required String token,
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: ApiConstants.withdrawalSendOTPRequest,
      token: token,
      queryParameters: queryParameters,
    );
  }

  @override
  Future<ApiResponse> submitWithdrawal({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(
      endpoint: ApiConstants.withdrawalSubmitRequest,
      token: token,
      data: payload,
    );
  }

  @override
  Future<ApiResponse> getTransactions({
    required String token,
    int? page,
    int? perPage,
    String? transactionType,
    String? dateFrom,
    String? dateTo,
    String? type,
    String? status,
  }) {
    final Map<String, dynamic> queryParams = {};
    if (page != null) queryParams['page'] = page;
    if (perPage != null) queryParams['perPage'] = perPage;
    if (transactionType != null && transactionType.isNotEmpty) queryParams['transactionType'] = transactionType;
    if (dateFrom != null && dateFrom.isNotEmpty) queryParams['dateFrom'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) queryParams['dateTo'] = dateTo;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    
    // Convert to query string if ApiService supports queryParams, otherwise build URI.
    // Assuming _api.get supports query parameters if we append them to endpoint, or pass them in a proper way.
    // I need to check how `_api.get` handles query parameters.
    // Let's look at `ApiService` first. Wait, I will just append them for now.
    
    final uri = Uri.parse(ApiConstants.getTransactions);
    final endpointWithParams = Uri(
      path: uri.path, // We shouldn't use Uri() to rebuild endpoint since endpoint is just a string without base URL.
      queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
    );
    
    // Instead of Uri(), let's manually append query string to endpoint string.
    String finalEndpoint = ApiConstants.getTransactions;
    if (queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams.map((key, value) => MapEntry(key, value.toString()))).query;
      finalEndpoint = '$finalEndpoint?$queryString';
    }

    return _api.get(endpoint: finalEndpoint, token: token);
  }

  @override
  Future<ApiResponse> getMt5Accounts({required String token}) {
    return _api.get(endpoint: ApiConstants.getMT5Accounts, token: token);
  }

  @override
  Future<ApiResponse> syncMt5Accounts({String? token}) {
    return _api.get(endpoint: ApiConstants.syncMT5Accounts, token: token);
  }

  @override
  Future<ApiResponse> changePrimaryAccount({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.changePrimaryAccount,
      token: token,
      data: data,
    );
  }

  @override
  Future<ApiResponse> createMt5Account({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.createMT5Account,
      token: token,
      data: data,
    );
  }

  @override
  Future<ApiResponse> postRealPlanDetails({
    String? token,
    required Map<String, dynamic> data,
  }) {
    return _api.post(
      endpoint: ApiConstants.realPlanDetails,
      token: token,
      data: data,
    );
  }

  @override
  Future<ApiResponse> postWithdrawalRequestForm({
    required String token,
    required Map<String, dynamic> formData,
  }) {
    return _api.postForm(
      endpoint: ApiConstants.withdrawalRequest,
      token: token,
      formData: formData,
    );
  }
}

