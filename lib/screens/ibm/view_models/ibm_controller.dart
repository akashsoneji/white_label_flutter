import 'package:get/get.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/verification_status_dialog.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';

class IbmController extends GetxController {
  final IbmApiProvider _apiProvider = IbmApiProvider();

  // Observable state
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // System status
  final RxString systemMode = ''.obs;
  final RxBool isPartner = false.obs;
  final RxBool canApply = false.obs;
  final RxMap<String, dynamic> partnerRequest = <String, dynamic>{}.obs;

  // Dashboard state
  final RxMap<String, dynamic> dashboardData = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> dashboardActivityData = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> networkData = <String, dynamic>{}.obs;

  // Clients state
  final RxMap<String, dynamic> clientsData = <String, dynamic>{}.obs;
  final RxString clientPeriod = 'this_month'.obs;
  final RxString clientScope = 'direct'.obs;

  // Requests state (Sub-IB requests)
  final RxMap<String, dynamic> requestsData = <String, dynamic>{}.obs;
  final RxString requestStatusFilter = 'all'.obs;

  // Wallet & Transactions state
  final RxMap<String, dynamic> walletData = <String, dynamic>{}.obs;
  final RxList<dynamic> transactionsList = <dynamic>[].obs;
  final RxString transactionFilter = 'Everything'.obs;

  // Commission Plans state
  final RxList<dynamic> plansList = <dynamic>[].obs;
  final RxMap<String, dynamic> planTemplate = <String, dynamic>{}.obs;

  // Referral Links state
  final RxList<dynamic> linksList = <dynamic>[].obs;
  final RxList<dynamic> planGroupsList = <dynamic>[].obs;

  // Shell Navigation
  final RxInt currentTabIndex = 0.obs;

  Map<String, dynamic> _toMap(dynamic val) {
    if (val is Map) {
      return Map<String, dynamic>.from(val);
    }
    return <String, dynamic>{};
  }

  /// Check system status and navigate to the appropriate screen
  Future<void> checkSystemAndNavigate() async {
    try {
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );

      final response = await _apiProvider.getSystemStatus();

      Get.back(closeOverlays: true);

      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;

        systemMode.value = data['system']?.toString() ?? 'none';
        isPartner.value =
            (data['is_partner'] == true ||
                data['is_partner'] == 1 ||
                data['is_partner'] == '1' ||
                data['is_partner'] == 'true');
        canApply.value =
            (data['can_apply'] == true ||
                data['can_apply'] == 1 ||
                data['can_apply'] == '1' ||
                data['can_apply'] == 'true');
        if (data['partner_request'] != null && data['partner_request'] is Map) {
          partnerRequest.value = _toMap(data['partner_request']);
        } else {
          partnerRequest.clear();
        }

        // Logic based on system mode
        if (systemMode.value == 'ibm') {
          if (isPartner.value) {
            Get.toNamed(Routes.IBM_MANAGER_PORTAL);
          } else {
            if (partnerRequest.isNotEmpty) {
              final status = partnerRequest['status'];
              if (status == 'rejected') {
                CustomToastService.showError(
                  message:
                      'Your IB application has been rejected. Please contact support for more information.',
                );
                return;
              }
            }
            // If not partner and not rejected, go to application form
            Get.toNamed(Routes.IBM_APPLICATION);
          }
        } else {
          // legacy mode handles all states (partner, not applied, rejected)
          _navigateToLegacyIb();
        }
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to get system status',
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back(closeOverlays: true);
      }
      CustomToastService.showError(message: 'Error checking IBM system: $e');
    }
  }

  void _navigateToLegacyIb() async {
    // This replicates the legacy IB flow call
    IBController ibController;
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }

    Get.dialog(
      Center(child: CommonLoadingWidget(size: 50.0, color: AppColors.primary)),
      barrierDismissible: false,
    );

    final ibStatusResponse = await ibController.getIBStatus();

    Get.back(closeOverlays: true);

    if (ibStatusResponse != null && ibStatusResponse.status == true) {
      final ibStatus = ibStatusResponse.data?.ibStatus;
      final isApproved = ibStatusResponse.data?.isApproved ?? false;
      final profileCompletion = ibStatusResponse.data?.profileCompletion ?? 0;

      if (ibStatus == 'rejected') {
        CustomToastService.showError(
          message:
              'Your IB application has been rejected. Please contact support for more information.',
        );
        return;
      }
      if (ibStatus == 'inreview') {
        Get.dialog(
          VerificationStatusDialog(
            stageCompletion: ibStatusResponse.data?.stageCompletion,
            ibStatus: ibStatus ?? 'inreview',
          ),
          barrierDismissible: true,
        );
        return;
      }
      if (ibStatus == 'not_applied') {
        Get.toNamed(AppPages.PARTNERSHIP_PROGRAM);
      } else if (ibStatus == 'approved' && isApproved == true) {
        Get.toNamed(AppPages.IB_MAIN);
      } else if (profileCompletion == 100) {
        Get.toNamed(AppPages.PARTNERSHIP_PROGRAM);
      } else {
        CustomToastService.showError(
          duration: const Duration(seconds: 2),
          message:
              ibStatusResponse.message ??
              'Profile is not complete. Please complete your profile first.',
        );
      }
    } else {
      String errorMsg =
          ibStatusResponse?.message ?? ibController.errorMessage.value;
      if (errorMsg.isEmpty)
        errorMsg = 'Failed to check IB status. Please try again.';
      CustomToastService.showError(message: errorMsg);
    }
  }

  void changeTab(int index) {
    currentTabIndex.value = index;
    update(['ibm_shell']); // Used for GetBuilder

    switch (index) {
      case 0:
        fetchDashboard();
        break;
      case 1:
        fetchClients();
        fetchRequests();
        fetchPlans();
        break;
      case 2:
        fetchWallet();
        fetchTransactions();
        fetchPlans();
        break;
      case 3:
        fetchLinks();
        break;
    }
  }

  Future<void> fetchDashboard({
    String? period,
    String? scope,
    String? from,
    String? to,
  }) async {
    try {
      isLoading.value = true;
      final response = await _apiProvider.getPortalDashboard(
        period: period ?? 'this_month',
        scope: scope ?? 'total',
        from: from,
        to: to,
      );
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        dashboardData.assignAll(data);
      }

      final activityResponse = await _apiProvider.getPortalDashboardActivity(
        limit: 5,
      );
      if (activityResponse.success && activityResponse.data != null) {
        final Map<String, dynamic> root = _toMap(activityResponse.data);
        final Map<String, dynamic> actData =
            root['data'] is Map ? _toMap(root['data']) : root;
        dashboardActivityData.assignAll(actData);
      }

      await fetchWallet();
      await fetchRequests();
      await fetchNetwork(period: period);

      update(['ibm_dashboard']);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchNetwork({String? period}) async {
    try {
      final response = await _apiProvider.getPortalNetwork(
        period: period ?? 'mtd',
      );
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        networkData.assignAll(data);
      }
    } catch (e) {
      // Silently catch error for dashboard network list
    }
  }

  Future<void> fetchClients({String? period, String? scope}) async {
    try {
      isLoading.value = true;
      if (period != null) clientPeriod.value = period;
      if (scope != null) clientScope.value = scope;

      final response = await _apiProvider.getPortalClients(
        period: clientPeriod.value,
        scope: clientScope.value,
      );
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        clientsData.assignAll(data);
        update(['ibm_clients']);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchRequests({String? status}) async {
    try {
      isLoading.value = true;
      if (status != null) requestStatusFilter.value = status;

      final response = await _apiProvider.getPortalRequests(
        status: requestStatusFilter.value,
      );
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        requestsData.assignAll(data);
        update(['ibm_requests']);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> approveSubIbRequest({
    required int requestId,
    required int planId,
  }) async {
    try {
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );
      final response = await _apiProvider.approveRequest(
        requestId: requestId,
        planId: planId,
      );
      Get.back(closeOverlays: true);
      if (response.success) {
        CustomToastService.showSuccess(
          message: 'Request approved successfully',
        );
        fetchRequests();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to approve request',
        );
        return false;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(closeOverlays: true);
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  Future<bool> rejectSubIbRequest({
    required int requestId,
    String? reason,
  }) async {
    try {
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );
      final response = await _apiProvider.rejectRequest(
        requestId: requestId,
        reason: reason,
      );
      Get.back(closeOverlays: true);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Request rejected');
        fetchRequests();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to reject request',
        );
        return false;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(closeOverlays: true);
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  Future<void> fetchWallet() async {
    try {
      isLoading.value = true;
      final response = await _apiProvider.getPortalWallet();
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        walletData.assignAll(data);
        update(['ibm_wallet']);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchTransactions({String? type}) async {
    try {
      isLoading.value = true;
      if (type != null) transactionFilter.value = type;
      final response = await _apiProvider.getPortalWalletTransactions(
        type: transactionFilter.value,
      );
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        final list = data['rows'] ?? data['data'] ?? [];
        if (list is List) {
          transactionsList.assignAll(list);
        }
        update(['ibm_transactions']);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPlans() async {
    try {
      isLoading.value = true;
      final response = await _apiProvider.getPartnerPlans();
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        final list = data['plans'] ?? data['data'] ?? [];
        if (list is List) {
          plansList.assignAll(list);
        }
        update(['ibm_plans']);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchLinks() async {
    try {
      isLoading.value = true;

      // Fetch plan groups alongside links
      if (planGroupsList.isEmpty) {
        fetchPlanGroups();
      }

      final response = await _apiProvider.getReferralLinks();
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        final list = data['links'] ?? data['data'] ?? [];
        if (list is List) {
          linksList.assignAll(list);
        }
        update(['ibm_links']);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPlanGroups() async {
    try {
      final response = await _apiProvider.getPortalPlanGroups();
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        final list = data['groups'] ?? data['data'] ?? [];
        if (list is List) {
          planGroupsList.assignAll(list);
        }
      }
    } catch (e) {
      // Handle silently
    }
  }

  Future<bool> createReferralLink({
    required String label,
    String? code,
    List<int>? planGroupIds,
    int? defaultPlanGroupId,
  }) async {
    try {
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );
      final response = await _apiProvider.createReferralLink(
        label: label,
        code: code,
        planGroupIds: planGroupIds,
        defaultPlanGroupId: defaultPlanGroupId,
      );
      Get.back(closeOverlays: true);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Referral link created!');
        fetchLinks();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to create link',
        );
        return false;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(closeOverlays: true);
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  Future<bool> updateReferralLink({
    required int linkId,
    String? label,
    List<int>? planGroupIds,
    int? defaultPlanGroupId,
    bool? isActive,
  }) async {
    try {
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );
      final response = await _apiProvider.updateReferralLink(
        linkId: linkId,
        label: label,
        planGroupIds: planGroupIds,
        defaultPlanGroupId: defaultPlanGroupId,
        isActive: isActive,
      );
      Get.back(closeOverlays: true);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Referral link updated!');
        fetchLinks();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to update link',
        );
        return false;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(closeOverlays: true);
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  Future<bool> deleteReferralLink(int linkId) async {
    try {
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );
      final response = await _apiProvider.deleteReferralLink(linkId);
      Get.back(closeOverlays: true);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Referral link deleted!');
        fetchLinks();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to delete link',
        );
        return false;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(closeOverlays: true);
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  Future<bool> createPartnerPlan(Map<String, dynamic> planData) async {
    try {
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );
      final response = await _apiProvider.createPartnerPlan(planData);
      Get.back(closeOverlays: true);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Commission plan created!');
        fetchPlans();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to create plan',
        );
        return false;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(closeOverlays: true);
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  Future<bool> deletePartnerPlan(int planId) async {
    try {
      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );
      final response = await _apiProvider.deletePartnerPlan(planId);
      Get.back(closeOverlays: true);
      if (response.success) {
        CustomToastService.showSuccess(message: 'Plan deleted');
        fetchPlans();
        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to delete plan',
        );
        return false;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(closeOverlays: true);
      CustomToastService.showError(message: 'Error: $e');
      return false;
    }
  }

  // --- Network Profile Methods ---

  // Profile State
  final RxMap<String, dynamic> currentClientOverview = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> currentClientTrades = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> currentNetworkNode = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> currentNetworkSymbols = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> currentNetworkPlan = <String, dynamic>{}.obs;
  final RxBool isProfileLoading = false.obs;
  final RxString profileErrorMessage = ''.obs;

  Future<void> fetchClientOverview(int id, {String period = 'mtd'}) async {
    try {
      isProfileLoading.value = true;
      profileErrorMessage.value = '';
      final response = await _apiProvider.getClientOverview(id, period: period);
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        currentClientOverview.assignAll(data);
      } else {
        profileErrorMessage.value =
            response.message ?? 'Error loading overview';
      }
    } catch (e) {
      profileErrorMessage.value = e.toString();
    } finally {
      isProfileLoading.value = false;
    }
  }

  Future<void> fetchClientTrades(
    int id, {
    String period = 'mtd',
    int page = 1,
    String? type,
    String? symbol,
  }) async {
    try {
      isProfileLoading.value = true;
      final response = await _apiProvider.getClientTrades(
        id,
        period: period,
        page: page,
        type: type,
        symbol: symbol,
      );
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        currentClientTrades.assignAll(data);
      }
    } catch (e) {
      profileErrorMessage.value = e.toString();
    } finally {
      isProfileLoading.value = false;
    }
  }

  Future<void> fetchNetworkNode(int id, {String period = 'mtd'}) async {
    try {
      isProfileLoading.value = true;
      final response = await _apiProvider.getNetworkNode(id, period: period);
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        currentNetworkNode.assignAll(data);
      }
    } catch (e) {
      profileErrorMessage.value = e.toString();
    } finally {
      isProfileLoading.value = false;
    }
  }

  Future<void> fetchNetworkSymbols(int id, {String period = 'mtd'}) async {
    try {
      isProfileLoading.value = true;
      final response = await _apiProvider.getNetworkSymbols(id, period: period);
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        currentNetworkSymbols.assignAll(data);
      }
    } catch (e) {
      profileErrorMessage.value = e.toString();
    } finally {
      isProfileLoading.value = false;
    }
  }

  Future<void> fetchNetworkPlan(int id) async {
    try {
      isProfileLoading.value = true;
      final response = await _apiProvider.getNetworkPlan(id);
      if (response.success && response.data != null) {
        final Map<String, dynamic> root = _toMap(response.data);
        final Map<String, dynamic> data =
            root['data'] is Map ? _toMap(root['data']) : root;
        currentNetworkPlan.assignAll(data);
      }
    } catch (e) {
      profileErrorMessage.value = e.toString();
    } finally {
      isProfileLoading.value = false;
    }
  }
}
