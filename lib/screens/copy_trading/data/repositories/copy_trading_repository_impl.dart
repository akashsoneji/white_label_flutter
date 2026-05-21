import 'package:crm_app/core/network/api_response.dart';

import 'copy_trading_repository.dart';
import '../datasources/copy_trading_remote_data_source.dart';

class CopyTradingRepositoryImpl implements CopyTradingRepository {
  final CopyTradingRemoteDataSource _remote;
  CopyTradingRepositoryImpl(this._remote);

  @override
  Future<ApiResponse> applyForMaster({
    required int mt5AccountId,
    required String nickname,
    required bool termsAccepted,
  }) {
    return _remote.applyForMaster(
      mt5AccountId: mt5AccountId,
      nickname: nickname,
      termsAccepted: termsAccepted,
    );
  }

  @override
  Future<ApiResponse> getCopierEligibleAccounts({Map<String, dynamic>? queryParameters}) {
    return _remote.getCopierEligibleAccounts(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getCopierSubscriptions({Map<String, dynamic>? queryParameters}) {
    return _remote.getCopierSubscriptions(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getCopierSubscriptionsList({
    required int page,
    required int perPage,
    Map<String, dynamic>? queryParameters,
  }) {
    return _remote.getCopierSubscriptionsList(
      page: page,
      perPage: perPage,
      queryParameters: queryParameters,
    );
  }

  @override
  Future<ApiResponse> getCopierSubscriptionTrades({
    required int subscriptionId,
    required int page,
    Map<String, dynamic>? queryParameters,
  }) {
    return _remote.getCopierSubscriptionTrades(
      subscriptionId: subscriptionId,
      page: page,
      queryParameters: queryParameters,
    );
  }

  @override
  Future<ApiResponse> getMasterCopiersList({
    required int page,
    required int perPage,
    Map<String, dynamic>? queryParameters,
  }) {
    return _remote.getMasterCopiersList(
      page: page,
      perPage: perPage,
      queryParameters: queryParameters,
    );
  }

  @override
  Future<ApiResponse> getCopierSubscriptionDetail({
    required int subscriptionId,
    Map<String, dynamic>? queryParameters,
  }) {
    return _remote.getCopierSubscriptionDetail(
      subscriptionId: subscriptionId,
      queryParameters: queryParameters,
    );
  }

  @override
  Future<ApiResponse> getMasterStatus({Map<String, dynamic>? queryParameters}) {
    return _remote.getMasterStatus(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getMasters({Map<String, dynamic>? queryParameters}) {
    return _remote.getMasters(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> subscribeCopier({required Map<String, dynamic> payload}) {
    return _remote.subscribeCopier(payload: payload);
  }

  @override
  Future<ApiResponse> updateCopierSubscription({
    required int subscriptionId,
    required Map<String, dynamic> payload,
  }) {
    return _remote.updateCopierSubscription(subscriptionId: subscriptionId, payload: payload);
  }

  @override
  Future<ApiResponse> getMasterDashboardStats() => _remote.getMasterDashboardStats();

  @override
  Future<ApiResponse> getMasterPlans({Map<String, dynamic>? queryParameters}) {
    return _remote.getMasterPlans(queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> createMasterPlan({required Map<String, dynamic> payload}) {
    return _remote.createMasterPlan(payload: payload);
  }

  @override
  Future<ApiResponse> inactivateMasterPlan({required int planId}) {
    return _remote.inactivateMasterPlan(planId: planId);
  }

  @override
  Future<ApiResponse> getMasterPlanDetail({
    required int planId,
    Map<String, dynamic>? queryParameters,
  }) {
    return _remote.getMasterPlanDetail(planId: planId, queryParameters: queryParameters);
  }

  @override
  Future<ApiResponse> getMasterProfile({required String masterCode}) {
    return _remote.getMasterProfile(masterCode: masterCode);
  }

  @override
  Future<ApiResponse> pauseCopierSubscription({required int subscriptionId}) {
    return _remote.pauseCopierSubscription(subscriptionId: subscriptionId);
  }

  @override
  Future<ApiResponse> resumeCopierSubscription({required int subscriptionId}) {
    return _remote.resumeCopierSubscription(subscriptionId: subscriptionId);
  }

  @override
  Future<ApiResponse> stopCopierSubscription({required int subscriptionId}) {
    return _remote.stopCopierSubscription(subscriptionId: subscriptionId);
  }

  @override
  Future<ApiResponse> addCapitalToCopierSubscription({
    required int subscriptionId,
    required num amount,
  }) {
    return _remote.addCapitalToCopierSubscription(
      subscriptionId: subscriptionId,
      amount: amount,
    );
  }
}

