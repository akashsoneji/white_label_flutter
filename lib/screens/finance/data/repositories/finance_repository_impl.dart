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
    String? t,
  }) {
    // finance-activity reads the date filter only as `dateRange=from|to`
    // (same contract as the web client); separate dateFrom/dateTo are ignored.
    final from = dateFrom ?? '';
    final to = dateTo ?? '';
    final dateRange = from.isEmpty && to.isEmpty ? '' : '$from|$to';

    final Map<String, dynamic> queryParams = {
      'page': (page ?? 1).toString(),
      'perPage': (perPage ?? 10).toString(),
      'transactionType': transactionType ?? '',
      'includeTraderTransfers': '1',
      'type': type ?? '',
      'status': status ?? '',
      'dateRange': dateRange,
      '_t': t ?? DateTime.now().millisecondsSinceEpoch.toString(),
    };

    return _api.get(
      endpoint: ApiConstants.getFinanceActivity,
      queryParameters: queryParams,
      token: token,
    );
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

