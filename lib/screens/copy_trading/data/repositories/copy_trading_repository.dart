import 'package:crm_app/core/network/api_response.dart';

abstract class CopyTradingRepository {
  Future<ApiResponse> getMasterStatus({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> getCopierSubscriptions({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> getCopierSubscriptionsList({
    required int page,
    required int perPage,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getCopierSubscriptionTrades({
    required int subscriptionId,
    required int page,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getMasterCopiersList({
    required int page,
    required int perPage,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getCopierSubscriptionDetail({
    required int subscriptionId,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> getCopierEligibleAccounts({
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> applyForMaster({
    required int mt5AccountId,
    required String nickname,
    required bool termsAccepted,
  });

  Future<ApiResponse> getMasters({Map<String, dynamic>? queryParameters});

  Future<ApiResponse> subscribeCopier({required Map<String, dynamic> payload});

  Future<ApiResponse> updateCopierSubscription({
    required int subscriptionId,
    required Map<String, dynamic> payload,
  });

  // Master dashboard
  Future<ApiResponse> getMasterDashboardStats();
  Future<ApiResponse> getMasterPlans({Map<String, dynamic>? queryParameters});
  Future<ApiResponse> createMasterPlan({required Map<String, dynamic> payload});
  Future<ApiResponse> inactivateMasterPlan({required int planId});
  Future<ApiResponse> getMasterPlanDetail({
    required int planId,
    Map<String, dynamic>? queryParameters,
  });

  // Master details
  Future<ApiResponse> getMasterProfile({required String masterCode});

  // Copier subscriptions actions
  Future<ApiResponse> pauseCopierSubscription({required int subscriptionId});
  Future<ApiResponse> resumeCopierSubscription({required int subscriptionId});
  Future<ApiResponse> stopCopierSubscription({required int subscriptionId});
  Future<ApiResponse> addCapitalToCopierSubscription({
    required int subscriptionId,
    required num amount,
  });
}

