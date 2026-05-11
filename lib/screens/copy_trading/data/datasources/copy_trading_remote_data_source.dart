import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

class CopyTradingRemoteDataSource {
  final ApiClient _api;
  CopyTradingRemoteDataSource(this._api);

  Future<ApiResponse> getMasterStatus({Map<String, dynamic>? queryParameters}) {
    return _api.get(
      endpoint: ApiConstants.copyTradingMasterStatus,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> getCopierSubscriptions({
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: ApiConstants.copyTradingCopierSubscriptions,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> getCopierSubscriptionDetail({
    required int subscriptionId,
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: ApiConstants.copyTradingCopierSubscriptionDetail(subscriptionId),
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> getCopierEligibleAccounts({
    Map<String, dynamic>? queryParameters,
  }) {
    return _api.get(
      endpoint: ApiConstants.copyTradingCopierEligibleAccounts,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> applyForMaster({
    required int mt5AccountId,
    required String nickname,
    required bool termsAccepted,
  }) {
    return _api.post(
      endpoint: ApiConstants.copyTradingMasterApply,
      data: {
        'mt5_account_id': mt5AccountId,
        'nickname': nickname,
        'terms_accepted': termsAccepted ? 1 : 0,
      },
    );
  }

  Future<ApiResponse> getMasters({Map<String, dynamic>? queryParameters}) {
    return _api.get(
      endpoint: ApiConstants.copyTradingMasters,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> subscribeCopier({required Map<String, dynamic> payload}) {
    return _api.post(endpoint: ApiConstants.copyTradingCopierSubscribe, data: payload);
  }

  Future<ApiResponse> updateCopierSubscription({
    required int subscriptionId,
    required Map<String, dynamic> payload,
  }) {
    return _api.put(
      endpoint: ApiConstants.copyTradingCopierSubscriptionUpdate(subscriptionId),
      data: payload,
    );
  }

  // Master dashboard
  Future<ApiResponse> getMasterDashboardStats() {
    return _api.get(endpoint: ApiConstants.copyTradingMasterDashboardStats);
  }

  Future<ApiResponse> getMasterPlans({Map<String, dynamic>? queryParameters}) {
    return _api.get(
      endpoint: ApiConstants.copyTradingMasterPlans,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> createMasterPlan({required Map<String, dynamic> payload}) {
    return _api.post(endpoint: ApiConstants.copyTradingMasterPlans, data: payload);
  }

  Future<ApiResponse> inactivateMasterPlan({required int planId}) {
    final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId/inactivate';
    return _api.post(endpoint: endpoint, data: <String, dynamic>{});
  }

  Future<ApiResponse> getMasterPlanDetail({
    required int planId,
    Map<String, dynamic>? queryParameters,
  }) {
    final endpoint = '${ApiConstants.copyTradingMasterPlans}/$planId';
    return _api.get(endpoint: endpoint, queryParameters: queryParameters);
  }

  // Master details
  Future<ApiResponse> getMasterProfile({required String masterCode}) {
    return _api.get(endpoint: ApiConstants.copyTradingMasterProfile(masterCode));
  }

  // Copier subscriptions actions
  Future<ApiResponse> pauseCopierSubscription({required int subscriptionId}) {
    return _api.post(
      endpoint: ApiConstants.copyTradingCopierSubscriptionPause(subscriptionId),
      data: <String, dynamic>{},
    );
  }

  Future<ApiResponse> resumeCopierSubscription({required int subscriptionId}) {
    return _api.post(
      endpoint: ApiConstants.copyTradingCopierSubscriptionResume(subscriptionId),
      data: <String, dynamic>{},
    );
  }

  Future<ApiResponse> stopCopierSubscription({required int subscriptionId}) {
    return _api.post(
      endpoint: ApiConstants.copyTradingCopierSubscriptionStop(subscriptionId),
      data: <String, dynamic>{},
    );
  }

  Future<ApiResponse> addCapitalToCopierSubscription({
    required int subscriptionId,
    required num amount,
  }) {
    return _api.post(
      endpoint: ApiConstants.copyTradingCopierSubscriptionAddCapital(subscriptionId),
      data: <String, dynamic>{'amount': amount},
    );
  }
}

