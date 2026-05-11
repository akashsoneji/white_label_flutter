import 'package:get/get.dart';
import 'package:crm_app/screens/pmam/data/repositories/pmam_repository.dart';

class PmamManagerPlanDetailController extends GetxController {
  final int planId;
  PmamManagerPlanDetailController(this.planId);

  final PmamRepository _repo = Get.find<PmamRepository>();

  final RxBool isLoadingDetails = false.obs;
  final RxString errorMessage = ''.obs;

  // Plan Details
  final RxMap<String, dynamic> planDetails = <String, dynamic>{}.obs;
  final RxBool isStatsExpanded = false.obs;

  // Allocations Pagination
  final RxList<Map<String, dynamic>> allocations = <Map<String, dynamic>>[].obs;
  final RxBool isAllocationsLoading = false.obs;
  int allocationsPage = 1;
  int allocationsTotalPages = 1;
  bool hasMoreAllocations = true;

  final RxString allocDateFrom = ''.obs;
  final RxString allocDateTo = ''.obs;
  final RxString allocFilterInvestor = ''.obs; // Stores user_id
  final RxString allocStatus = 'all'.obs;

  // All investors for dropdown
  final RxList<Map<String, dynamic>> allPlanInvestors =
      <Map<String, dynamic>>[].obs;

  // Investors Pagination
  final RxList<Map<String, dynamic>> investors = <Map<String, dynamic>>[].obs;
  final RxBool isInvestorsLoading = false.obs;
  int investorsPage = 1;
  int investorsTotalPages = 1;
  bool hasMoreInvestors = true;

  final RxString invSortBy = 'active_since'.obs;
  final RxString invOrder = 'desc'.obs;
  final RxString invSearch = ''.obs;
  final RxInt invPerPage = 10.obs;

  @override
  void onInit() {
    super.onInit();
    loadPlanDetails();
    loadAllPlanInvestors();
    loadAllocations(refresh: true);
    loadInvestors(refresh: true);
  }

  Future<void> loadAllPlanInvestors() async {
    try {
      final response = await _repo.getPlanInvestors(
        planId,
        page: 1,
        perPage: 1000,
        sortBy: 'active_since',
        order: 'desc',
      );
      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final inner = d['data'];
        if (inner != null && inner['data'] is List) {
          final list =
              (inner['data'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList();

          // Deduplicate based on investor_user_id, user_id, or investor_id fallback
          final Map<String, Map<String, dynamic>> uniqueInvestors = {};
          for (var inv in list) {
            final valId =
                inv['investor_user_id'] ??
                inv['user_id'] ??
                inv['investor_id'] ??
                inv['id'];
            if (valId != null &&
                inv['investor_name'] != null &&
                inv['investor_name'].toString().isNotEmpty) {
              uniqueInvestors[valId.toString()] = inv;
            }
          }
          if (allPlanInvestors.isEmpty) {
            allPlanInvestors.assignAll(uniqueInvestors.values.toList());
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> loadPlanDetails() async {
    try {
      isLoadingDetails.value = true;
      final response = await _repo.getPlanDetail(planId);
      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        planDetails.value = Map<String, dynamic>.from(d['data'] ?? {});

        if (planDetails['unique_investors'] != null) {
          final uiList =
              (planDetails['unique_investors'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList();
          allPlanInvestors.assignAll(uiList);
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingDetails.value = false;
    }
  }

  // ALLOCATIONS
  Future<void> loadAllocations({bool refresh = false}) async {
    if (refresh) {
      allocationsPage = 1;
      allocations.clear();
      hasMoreAllocations = true;
    }
    if (!hasMoreAllocations || isAllocationsLoading.value) return;

    try {
      isAllocationsLoading.value = true;
      final response = await _repo.getPlanAllocations(
        planId,
        page: allocationsPage,
        perPage: 15,
        dateFrom: allocDateFrom.value.isEmpty ? null : allocDateFrom.value,
        dateTo: allocDateTo.value.isEmpty ? null : allocDateTo.value,
        userId:
            allocFilterInvestor.value.isEmpty
                ? null
                : allocFilterInvestor.value,
        status: allocStatus.value,
      );

      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final inner = d['data'];
        if (inner != null && inner['data'] is List) {
          final list =
              (inner['data'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList();
          allocations.addAll(list);
          allocationsTotalPages = inner['total_pages'] ?? 1;

          if (allocationsPage >= allocationsTotalPages) {
            hasMoreAllocations = false;
          } else {
            allocationsPage++;
          }
        } else {
          hasMoreAllocations = false;
        }
      } else {
        hasMoreAllocations = false;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isAllocationsLoading.value = false;
    }
  }

  void applyAllocationsFilter({
    String? df,
    String? dt,
    String? inv,
    String? status,
  }) {
    if (df != null) allocDateFrom.value = df;
    if (dt != null) allocDateTo.value = dt;
    if (inv != null) allocFilterInvestor.value = inv;
    if (status != null) allocStatus.value = status;
    loadAllocations(refresh: true);
  }

  // INVESTORS
  Future<void> loadInvestors({bool refresh = false}) async {
    if (refresh) {
      investorsPage = 1;
      investors.clear();
      hasMoreInvestors = true;
    }
    if (!hasMoreInvestors || isInvestorsLoading.value) return;

    try {
      isInvestorsLoading.value = true;
      final response = await _repo.getPlanInvestors(
        planId,
        page: investorsPage,
        perPage: invPerPage.value,
        sortBy: invSortBy.value,
        order: invOrder.value,
        search: invSearch.value,
      );

      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final inner = d['data'];
        if (inner != null && inner['data'] is List) {
          final list =
              (inner['data'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList();
          investors.addAll(list);
          investorsTotalPages = inner['total_pages'] ?? 1;

          if (investorsPage >= investorsTotalPages) {
            hasMoreInvestors = false;
          } else {
            investorsPage++;
          }
        } else {
          hasMoreInvestors = false;
        }
      } else {
        hasMoreInvestors = false;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isInvestorsLoading.value = false;
    }
  }

  void applyInvestorsFilter({
    String? sort,
    String? order,
    int? perPage,
    String? search,
  }) {
    if (sort != null) invSortBy.value = sort;
    if (order != null) invOrder.value = order;
    if (perPage != null) invPerPage.value = perPage;
    if (search != null) invSearch.value = search;
    loadInvestors(refresh: true);
  }
}
