import 'package:crm_app/widgets/custom_toast.dart';
import 'package:get/get.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/screens/ib/data/repositories/ib_repository.dart';
import 'package:crm_app/core/network/api_response.dart';

class IBController extends GetxController {
  final IbRepository _repo = Get.find<IbRepository>();
  final RxBool isLoading = false.obs;
  final RxBool isHistoryLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Selected Sub-IB ID for hierarchy navigation
  int? selectedSubIBId;

  // IB Status
  final Rx<IBStatusResponse?> ibStatusResponse = Rxn<IBStatusResponse>();

  // IB Dashboard
  final Rx<IBDashboardResponse?> ibDashboardResponse =
      Rxn<IBDashboardResponse>();

  // IB Dashboard Data (extracted for easier access)
  final Rx<UserIBDetails?> ibDashboardData = Rxn<UserIBDetails>();

  // IB Clients
  final RxList<IBClient> ibClients = <IBClient>[].obs;

  // IB Sub-IBs
  final RxList<IBClient> ibSubIBs = <IBClient>[].obs;

  // IB Trade History
  final RxList<IBTradeHistory> ibTradeHistory = <IBTradeHistory>[].obs;

  // IB Stats
  final Rx<IBStatsData?> ibStats = Rxn<IBStatsData>();

  // IB Structure
  final Rx<IBStructureData?> ibStructureData = Rxn<IBStructureData>();

  // IB Approval Requests
  final RxList<IBApprovalRequest> ibApprovalRequests =
      <IBApprovalRequest>[].obs;

  // Commission Groups
  final RxList<CommissionGroup> commissionGroups = <CommissionGroup>[].obs;
  final RxBool isCommissionGroupsLoading = false.obs;

  // ------------------------------
  // IB Clients Screen UI State
  // ------------------------------

  /// Selected tab index for IB Clients screen
  /// 0: Clients, 1: Sub-IBs, 2: Trades
  final RxInt clientsTabIndex = 0.obs;

  /// Search text for filtering clients / sub-IBs / trades
  final RxString clientsSearchQuery = ''.obs;

  /// Currently selected Sub-IB (for hierarchy navigation)
  final Rx<IBClient?> clientsSelectedSubIB = Rxn<IBClient>();

  /// Hierarchy stack from Master IB -> nested Sub-IBs
  final RxList<IBClient> clientsHierarchy = <IBClient>[].obs;

  /// Expanded state for cards (by list index)
  final RxMap<int, bool> clientsExpandedItems = <int, bool>{}.obs;

  /// Key to force list rebuilds when data changes
  final RxInt clientsDataKey = 0.obs;

  /// Get IB Status
  Future<IBStatusResponse?> getIBStatus({bool showLoading = true}) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.getIbStatus(
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        ibStatusResponse.value = IBStatusResponse.fromJson(response.data!);
        return ibStatusResponse.value;
      } else {
        errorMessage.value = response.message ?? 'Failed to get IB status';
        ibStatusResponse.value = null;
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting IB status: $e';
      ibStatusResponse.value = null;
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  /// Submit IB Application
  Future<bool> submitIBApplication({required bool termsAccepted}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _repo.submitIbApplication(
        payload: {'terms_accepted': termsAccepted},
      );

      if (response.success && response.data != null) {
        final applicationResponse = IBApplicationResponse.fromJson(
          response.data!,
        );
        if (applicationResponse.status == true) {
          CustomToastService.showSuccess(
            message:
                applicationResponse.message ??
                'IB application submitted successfully',
          );
          return true;
        } else {
          errorMessage.value =
              applicationResponse.message ?? 'Failed to submit application';
          CustomToastService.showError(message: errorMessage.value);
          return false;
        }
      } else {
        errorMessage.value = response.message ?? 'Failed to submit application';
        CustomToastService.showError(message: errorMessage.value);
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Error submitting IB application: $e';
      CustomToastService.showError(message: errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get IB Dashboard
  Future<IBDashboardResponse?> getIBDashboard({bool showLoading = true}) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.getIbDashboard(
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        ibDashboardResponse.value = IBDashboardResponse.fromJson(
          response.data!,
        );
        ibDashboardData.value = ibDashboardResponse.value?.data?.userIBDetails;
        update(['ib_dashboard']); // Trigger GetBuilder update with specific ID
        return ibDashboardResponse.value;
      } else {
        errorMessage.value = response.message ?? 'Failed to get IB dashboard';
        ibDashboardResponse.value = null;
        ibDashboardData.value = null;
        update(['ib_dashboard']); // Trigger GetBuilder update with specific ID
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting IB dashboard: $e';
      ibDashboardResponse.value = null;
      ibDashboardData.value = null;
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
      update(['ib_dashboard']); // Trigger GetBuilder update with specific ID
    }
  }

  /// Get IB Clients
  Future<List<IBClient>?> getIBClients({
    int? subIbId,
    bool showLoading = true,
  }) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final queryParams = {'_t': timestamp.toString()};
      if (subIbId != null) {
        queryParams['sub_ib_id'] = subIbId.toString();
      }

      final response = await _repo.getIbClients(queryParameters: queryParams);

      if (response.success && response.data != null) {
        final clientsResponse = IBClientsResponse.fromJson(response.data!);
        ibClients.assignAll(clientsResponse.data ?? []);
        update(['ib_clients']); // Trigger GetBuilder update with specific ID
        return ibClients;
      } else {
        errorMessage.value = response.message ?? 'Failed to get IB clients';
        ibClients.clear();
        update(['ib_clients']); // Trigger GetBuilder update with specific ID
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting IB clients: $e';
      ibClients.clear();
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  /// Get IB Sub-IBs
  Future<List<IBClient>?> getIBSubIBs({
    int? subIbId,
    bool showLoading = true,
  }) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final queryParams = {'_t': timestamp.toString()};

      final response = await _repo.getIbSubIbs(
        subIbId: subIbId,
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final subIBsResponse = IBSubIBsResponse.fromJson(response.data!);
        ibSubIBs.assignAll(subIBsResponse.data ?? []);
        update(['ib_clients', 'ib_structure']); // Trigger GetBuilder updates
        return ibSubIBs;
      } else {
        errorMessage.value = response.message ?? 'Failed to get IB Sub-IBs';
        ibSubIBs.clear();
        update(['ib_clients', 'ib_structure']); // Trigger GetBuilder updates
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting IB Sub-IBs: $e';
      ibSubIBs.clear();
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  /// Get IB Trade History
  Future<List<IBTradeHistory>?> getIBTradeHistory({
    int? subIbId,
    bool showLoading = true,
  }) async {
    try {
      if (showLoading) {
        isHistoryLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final queryParams = {'_t': timestamp.toString()};
      if (subIbId != null) {
        queryParams['sub_ib_id'] = subIbId.toString();
      }

      final response = await _repo.getIbTradeHistory(queryParameters: queryParams);

      if (response.success && response.data != null) {
        final tradeHistoryResponse = IBTradeHistoryResponse.fromJson(
          response.data!,
        );
        ibTradeHistory.assignAll(tradeHistoryResponse.data ?? []);
        update(['ib_clients']); // Trigger GetBuilder update with specific ID
        return ibTradeHistory;
      } else {
        errorMessage.value =
            response.message ?? 'Failed to get IB trade history';
        ibTradeHistory.clear();
        update(['ib_clients']); // Trigger GetBuilder update with specific ID
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting IB trade history: $e';
      ibTradeHistory.clear();
      return null;
    } finally {
      if (showLoading) {
        isHistoryLoading.value = false;
      }
    }
  }

  /// Get IB Stats
  Future<IBStatsData?> getIBStats({bool showLoading = true}) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.getIbStats(
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        final statsResponse = IBStatsResponse.fromJson(response.data!);
        ibStats.value = statsResponse.data;
        update(['ib_dashboard', 'ib_structure']); // Trigger GetBuilder updates
        return ibStats.value;
      } else {
        errorMessage.value = response.message ?? 'Failed to get IB stats';
        ibStats.value = null;
        update(['ib_dashboard', 'ib_structure']); // Trigger GetBuilder updates
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting IB stats: $e';
      ibStats.value = null;
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  /// Get Sub-IB Stats (stats for a specific Sub-IB)
  Future<IBStatsData?> getIBSubIbStats({
    required int subIbId,
    bool showLoading = true,
  }) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.getIbSubIbStats(
        subIbId: subIbId,
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        final statsResponse = IBStatsResponse.fromJson(response.data!);
        ibStats.value = statsResponse.data;
        update(['ib_dashboard', 'ib_structure', 'ib_clients']);
        return ibStats.value;
      } else {
        errorMessage.value = response.message ?? 'Failed to get Sub-IB stats';
        ibStats.value = null;
        update(['ib_dashboard', 'ib_structure', 'ib_clients']);
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting Sub-IB stats: $e';
      ibStats.value = null;
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  /// Load all My Clients data (clients, sub-ibs, trade-history, stats)
  Future<void> loadMyClientsData({int? subIbId}) async {
    try {
      isLoading.value = true;
      isHistoryLoading.value = true; // Also indicate history is starting
      errorMessage.value = '';

      // Step 0: Clear CURRENT data to ensure UI resets for the new IB
      ibClients.clear();
      ibSubIBs.clear();
      ibTradeHistory.clear();
      ibStats.value = null;
      clientsExpandedItems.clear();
      selectedSubIBId = subIbId;

      update(); // Update GetBuilder to show loading state and cleared data

      if (subIbId == null) {
        // Master IB: match APIs 1–4
        // 1) /api/user/ib/stats
        await getIBStats(showLoading: false);
        // 2) /api/user/ib/clients
        await getIBClients(showLoading: false);
        // 3) /api/user/ib/sub-ibs
        await getIBSubIBs(showLoading: false);
        // 4) /api/user/ib/trade-history
        await getIBTradeHistory(showLoading: false);
      } else {
        // Sub-IB: match APIs 5–8
        // 5) /api/user/ib/sub-ib-structure/{id}
        await getIBSubIbStructure(subIbId: subIbId, showLoading: false);
        // 6) /api/user/ib/sub-ib-sub-ibs/{id}
        await getIBSubIBs(subIbId: subIbId, showLoading: false);
        // 7) /api/user/ib/sub-ib-stats/{id}
        await getIBSubIbStats(subIbId: subIbId, showLoading: false);
        // 8) /api/user/ib/trade-history?sub_ib_id={id}
        await getIBTradeHistory(subIbId: subIbId, showLoading: false);
      }
    } catch (e) {
      errorMessage.value = 'Error loading My Clients data: $e';
    } finally {
      isLoading.value = false;
      isHistoryLoading.value = false;
      clientsDataKey.value = clientsDataKey.value + 1;
      update(); // Final update when all background tasks are done
    }
  }

  /// Load all Dashboard data (dashboard, stats)
  Future<void> loadDashboardData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      update();

      await Future.wait([
        getIBDashboard(showLoading: false),
        getIBStats(showLoading: false),
      ]);
    } catch (e) {
      errorMessage.value = 'Error loading Dashboard data: $e';
    } finally {
      isLoading.value = false;
      update();
    }
  }

  /// Get IB Structure
  Future<IBStructureData?> getIBStructure({bool showLoading = true}) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.getIbStructure(
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        final structureResponse = IBStructureResponse.fromJson(response.data!);
        ibStructureData.value = structureResponse.data;
        update(['ib_structure', 'ib_more']); // Trigger GetBuilder updates
        return ibStructureData.value;
      } else {
        errorMessage.value = response.message ?? 'Failed to get IB structure';
        ibStructureData.value = null;
        update(['ib_structure', 'ib_more']); // Trigger GetBuilder updates
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting IB structure: $e';
      ibStructureData.value = null;
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  /// Get Sub-IB Structure (for a specific Sub-IB)
  Future<IBStructureData?> getIBSubIbStructure({
    required int subIbId,
    bool showLoading = true,
  }) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.getIbSubIbStructure(
        subIbId: subIbId,
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        final structureResponse = IBStructureResponse.fromJson(response.data!);
        ibStructureData.value = structureResponse.data;
        update(['ib_structure', 'ib_more']); // Trigger GetBuilder updates
        return ibStructureData.value;
      } else {
        errorMessage.value =
            response.message ?? 'Failed to get Sub-IB structure';
        ibStructureData.value = null;
        update(['ib_structure', 'ib_more']); // Trigger GetBuilder updates
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting Sub-IB structure: $e';
      ibStructureData.value = null;
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  /// Get IB Approval Requests
  Future<List<IBApprovalRequest>?> getIBApprovalRequests({
    bool showLoading = true,
  }) async {
    try {
      if (showLoading) {
        isLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Prefer the newer web/datatable endpoint; fall back to legacy endpoint.
      ApiResponse response = await _repo.getIbApprovalRequests(
        queryParameters: {'_t': timestamp.toString()},
      );

      if (!response.success || response.data == null) {
        response = await _repo.getIbApprovalRequestsFallback(
          queryParameters: {'_t': timestamp.toString()},
        );
      }

      if (response.success && response.data != null) {
        final approvalRequestsResponse = IBApprovalRequestsResponse.fromJson(
          response.data!,
        );
        ibApprovalRequests.assignAll(approvalRequestsResponse.data ?? []);
        update(['ib_requests']); // Trigger GetBuilder update with specific ID
        return ibApprovalRequests;
      } else {
        errorMessage.value =
            response.message ?? 'Failed to get IB approval requests';
        ibApprovalRequests.clear();
        update(['ib_requests']); // Trigger GetBuilder update with specific ID
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting IB approval requests: $e';
      ibApprovalRequests.clear();
      return null;
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  // ------------------------------
  // IB Clients Screen helpers
  // ------------------------------

  /// Update selected tab and clear expanded state
  void setClientsTabIndex(int index) {
    clientsTabIndex.value = index;
    clientsExpandedItems.clear();
  }

  /// Update search query and clear expanded state
  void setClientsSearchQuery(String value) {
    clientsSearchQuery.value = value;
    clientsExpandedItems.clear();
  }

  /// Toggle expand/collapse for a given item index
  void toggleClientExpand(int index) {
    final current = clientsExpandedItems[index] ?? false;
    clientsExpandedItems[index] = !current;
  }

  /// Reset hierarchy to Master IB level
  void resetClientsHierarchy() {
    clientsHierarchy.clear();
    clientsSelectedSubIB.value = null;
    clientsExpandedItems.clear();
  }

  /// Navigate to a specific Sub-IB and load its data
  Future<void> navigateToSubIB(IBClient subIB) async {
    if (clientsSelectedSubIB.value == null) {
      clientsHierarchy.assignAll([subIB]);
    } else {
      clientsHierarchy.add(subIB);
    }
    clientsSelectedSubIB.value = subIB;
    clientsExpandedItems.clear();
    clientsTabIndex.value = 0;

    // Load data for this Sub-IB (clears lists & calls sub-IB APIs)
    await loadMyClientsData(subIbId: subIB.id);
  }

  /// Navigate back to parent IB in hierarchy and reload data
  Future<void> backToParentIB() async {
    if (clientsHierarchy.isNotEmpty) {
      clientsHierarchy.removeLast();
      clientsSelectedSubIB.value =
          clientsHierarchy.isNotEmpty ? clientsHierarchy.last : null;
    } else {
      clientsSelectedSubIB.value = null;
    }
    clientsExpandedItems.clear();

    final parentId =
        clientsHierarchy.isNotEmpty ? clientsHierarchy.last.id : null;

    // If parentId is null → Master IB (top level)
    await loadMyClientsData(subIbId: parentId);
  }

  /// Load IB Data for selected Sub-IB
  Future<void> loadIBData({int? subIbId}) async {
    try {
      selectedSubIBId = subIbId;
      isLoading.value = true;
      errorMessage.value = '';

      // Clear old data
      ibClients.clear();
      ibSubIBs.clear();
      ibTradeHistory.clear();
      ibStats.value = null;
      clientsExpandedItems.clear();

      // Update UI immediately to show loading state
      update(['ib_clients', 'ib_structure']);

      // Load all data
      await Future.wait([
        getIBClients(subIbId: subIbId, showLoading: false),
        getIBSubIBs(subIbId: subIbId, showLoading: false),
        if (subIbId == null)
          getIBStats(showLoading: false)
        else
          getIBSubIbStats(subIbId: subIbId, showLoading: false),
      ]);

      isLoading.value = false;
      update(['ib_clients', 'ib_structure']);

      // Load trade history in background
      await getIBTradeHistory(subIbId: subIbId, showLoading: false);
    } catch (e) {
      errorMessage.value = 'Error loading IB data: $e';
      isLoading.value = false;
    } finally {
      isLoading.value = false;
      clientsDataKey.value = clientsDataKey.value + 1;
      update(['ib_clients', 'ib_structure']);
    }
  }

  /// Get Commission Groups
  Future<List<CommissionGroup>?> getCommissionGroups({
    bool showLoading = true,
  }) async {
    try {
      if (showLoading) {
        isCommissionGroupsLoading.value = true;
      }
      errorMessage.value = '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.getCommissionGroups(
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        final groupsResponse = IBCommissionGroupsResponse.fromJson(
          response.data!,
        );
        final groups = groupsResponse.data ?? [];
        commissionGroups.assignAll(groups);
        update(['commission_groups', 'ib_structure']);
        return commissionGroups;
      } else {
        errorMessage.value =
            response.message ?? 'Failed to get commission groups';
        commissionGroups.clear();
        update(['commission_groups']);
        return null;
      }
    } catch (e) {
      errorMessage.value = 'Error getting commission groups: $e';
      commissionGroups.clear();
      return null;
    } finally {
      if (showLoading) {
        isCommissionGroupsLoading.value = false;
      }
    }
  }

  /// Create or Update Commission Group
  Future<bool> manageCommissionGroup({
    required String groupName,
    required List<int> masterIds,
    required String structureType,
    required Map<String, dynamic> commissionRates,
    int? groupId,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final payload = {
        'group_name': groupName,
        'master_ids': masterIds,
        'structure_type': structureType,
        ...commissionRates,
      };

      if (groupId != null) {
        payload['id'] =
            groupId.toString(); // Send as string as per API requirement
      }

      final response = await _repo.manageCommissionGroup(payload: payload);

      if (response.success) {
        CustomToastService.showSuccess(
          message:
              groupId != null
                  ? 'Commission group updated successfully'
                  : 'Commission group created successfully',
        );
        await getCommissionGroups(showLoading: false);
        return true;
      } else {
        errorMessage.value =
            response.message ?? 'Failed to manage commission group';
        CustomToastService.showError(message: errorMessage.value);
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Error managing commission group: $e';
      CustomToastService.showError(message: errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete Commission Group
  Future<bool> deleteCommissionGroup({required int groupId}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _repo.deleteCommissionGroup(groupId: groupId);

      if (response.success) {
        CustomToastService.showSuccess(
          message: 'Commission group deleted successfully',
        );
        await getCommissionGroups(showLoading: false);
        return true;
      } else {
        errorMessage.value =
            response.message ?? 'Failed to delete commission group';
        CustomToastService.showError(message: errorMessage.value);
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Error deleting commission group: $e';
      CustomToastService.showError(message: errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear all IB data
  void clearAllData() {
    selectedSubIBId = null;
    ibStatusResponse.value = null;
    ibDashboardResponse.value = null;
    ibDashboardData.value = null;
    ibClients.clear();
    ibSubIBs.clear();
    ibTradeHistory.clear();
    ibStats.value = null;
    ibStructureData.value = null;
    ibApprovalRequests.clear();
    commissionGroups.clear();
    errorMessage.value = '';
  }

  /// Update IB Request Status (Approve/Reject/etc)
  Future<bool> updateIBStatusRequest({
    required int requestId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _repo.updateIbStatusRequest(
        requestId: requestId,
        payload: payload,
      );

      if (response.success) {
        CustomToastService.showSuccess(
          message: response.message ?? 'Status updated successfully',
        );
        await getIBApprovalRequests(showLoading: false);
        return true;
      } else {
        errorMessage.value = response.message ?? 'Failed to update status';
        CustomToastService.showError(message: errorMessage.value);
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Error updating status: $e';
      CustomToastService.showError(message: errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
