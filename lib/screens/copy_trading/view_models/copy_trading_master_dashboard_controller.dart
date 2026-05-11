import 'package:crm_app/models/mt5_account.dart';
import 'package:get/get.dart';

import 'package:crm_app/screens/copy_trading/data/repositories/copy_trading_repository.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/secure_storage_service.dart';

class CopyTradingMasterDashboardStats {
  final int plansCount;
  final int activeCopiersCount;
  final num totalAum;
  final num commissionEarned;

  const CopyTradingMasterDashboardStats({
    required this.plansCount,
    required this.activeCopiersCount,
    required this.totalAum,
    required this.commissionEarned,
  });

  factory CopyTradingMasterDashboardStats.fromJson(Map<String, dynamic> json) {
    return CopyTradingMasterDashboardStats(
      plansCount: (json['plans_count'] ?? 0) is num ? (json['plans_count'] as num).toInt() : 0,
      activeCopiersCount:
          (json['active_copiers_count'] ?? 0) is num ? (json['active_copiers_count'] as num).toInt() : 0,
      totalAum: (json['total_aum'] ?? 0) as num? ?? 0,
      commissionEarned: (json['commission_earned'] ?? 0) as num? ?? 0,
    );
  }
}

class CopyTradingEligibleAccount {
  final int id;
  final String metaAccountNumber;
  final String accountType;
  final num balance;
  final num equity;
  final String tradingServer;
  final String lpProviderName;
  final String serverType;
  final bool isEnrolled;

  const CopyTradingEligibleAccount({
    required this.id,
    required this.metaAccountNumber,
    required this.accountType,
    required this.balance,
    required this.equity,
    required this.tradingServer,
    required this.lpProviderName,
    required this.serverType,
    required this.isEnrolled,
  });

  factory CopyTradingEligibleAccount.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return CopyTradingEligibleAccount(
      id: (json['id'] ?? 0) is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      metaAccountNumber: (json['meta_account_number'] ?? '').toString(),
      accountType: (json['account_type'] ?? '').toString(),
      balance: toNum(json['balance']),
      equity: toNum(json['equity']),
      tradingServer: (json['trading_server'] ?? '').toString(),
      lpProviderName: (json['lp_provider_name'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      isEnrolled: json['is_enrolled'] == true,
    );
  }

  String get maskedAccount => metaAccountNumber;
}

class CopyTradingMasterPlanItem {
  final int id;
  final String planName;
  final String tradingAccountNumber;
  final String tradingServer;
  final String lpProviderName;
  final String serverType;
  final String commissionType;
  final String commissionLabel;
  final num commissionPercentage;
  final num subscriptionFee;
  final num minimumCapital;
  final num copyRatio;
  final int? maxCopiers;
  final int activeCopiersCount;
  final num totalCapital;
  final bool isFull;
  final String status;
  final String createdAt;

  const CopyTradingMasterPlanItem({
    required this.id,
    required this.planName,
    required this.tradingAccountNumber,
    required this.tradingServer,
    required this.lpProviderName,
    required this.serverType,
    required this.commissionType,
    required this.commissionLabel,
    required this.commissionPercentage,
    required this.subscriptionFee,
    required this.minimumCapital,
    required this.copyRatio,
    required this.maxCopiers,
    required this.activeCopiersCount,
    required this.totalCapital,
    required this.isFull,
    required this.status,
    required this.createdAt,
  });

  factory CopyTradingMasterPlanItem.fromJson(Map<String, dynamic> json) {
    return CopyTradingMasterPlanItem(
      id: (json['id'] ?? 0) is num ? (json['id'] as num).toInt() : 0,
      planName: (json['plan_name'] ?? json['name'] ?? '').toString(),
      tradingAccountNumber: (json['trading_account_number'] ?? '').toString(),
      tradingServer: (json['trading_server'] ?? '').toString(),
      lpProviderName: (json['lp_provider_name'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionLabel: (json['commission_label'] ?? '').toString(),
      commissionPercentage: (json['commission_percentage'] ?? 0) as num? ?? 0,
      subscriptionFee: (json['subscription_fee'] ?? 0) as num? ?? 0,
      minimumCapital: (json['minimum_capital'] ?? 0) as num? ?? 0,
      copyRatio: (json['copy_ratio'] ?? 1) as num? ?? 1,
      maxCopiers: (json['max_copiers'] is num) ? (json['max_copiers'] as num).toInt() : int.tryParse((json['max_copiers'] ?? '').toString()),
      activeCopiersCount:
          (json['active_copiers_count'] ?? 0) is num ? (json['active_copiers_count'] as num).toInt() : 0,
      totalCapital: (json['total_capital'] ?? json['total_aum'] ?? 0) as num? ?? 0,
      isFull: json['is_full'] == true,
      status: (json['status'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class CopyTradingMasterDashboardController extends GetxController {
  final CopyTradingRepository _repo = Get.find<CopyTradingRepository>();
  final FinanceRepository _financeRepo = Get.find<FinanceRepository>();
  final String masterCode;
  CopyTradingMasterDashboardController({required this.masterCode});

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final Rxn<CopyTradingMasterDashboardStats> stats = Rxn<CopyTradingMasterDashboardStats>();
  final RxList<CopyTradingMasterPlanItem> plans = <CopyTradingMasterPlanItem>[].obs;

  final RxList<MT5Account> mt5Accounts = <MT5Account>[].obs;

  // Create-plan account picker should use eligible accounts API (reference: COPYTRADING_API.md)
  final RxBool eligibleAccountsLoading = false.obs;
  final RxString eligibleAccountsError = ''.obs;
  final RxList<CopyTradingEligibleAccount> eligibleAccounts =
      <CopyTradingEligibleAccount>[].obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll(showLoading: true);
  }

  Future<void> refreshAll({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      await Future.wait([_loadStats(), _loadPlans(), _loadMt5Accounts()]);
    } catch (e) {
      errorMessage.value = 'Failed to load dashboard: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> _loadStats() async {
    final res = await _repo.getMasterDashboardStats();
    if (!res.success || res.data == null) {
      stats.value = null;
      return;
    }
    final data = res.data?['data'];
    if (data is Map) {
      stats.value = CopyTradingMasterDashboardStats.fromJson(data.cast<String, dynamic>());
    }
  }

  Future<void> _loadPlans() async {
    final res = await _repo.getMasterPlans(
      queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
    );
    if (!res.success || res.data == null) {
      plans.clear();
      return;
    }
    final data = res.data?['data'];
    if (data is List) {
      plans.assignAll(
        data.whereType<Map>().map((e) => CopyTradingMasterPlanItem.fromJson(e.cast<String, dynamic>())),
      );
    } else {
      plans.clear();
    }
  }

  Future<void> _loadMt5Accounts() async {
    final token = await SecureStorageService.getAuthToken();
    final res = await _financeRepo.getMt5Accounts(token: token ?? '');
    if (!res.success || res.data == null) {
      mt5Accounts.clear();
      return;
    }
    final data = res.data?['data'];
    if (data is List) {
      mt5Accounts.assignAll(data.whereType<Map>().map((e) => MT5Account.fromJson(e.cast<String, dynamic>())).toList());
    } else {
      mt5Accounts.clear();
    }
  }

  Future<void> loadEligibleAccountsForCreatePlan() async {
    eligibleAccountsLoading.value = true;
    eligibleAccountsError.value = '';
    try {
      final res = await _repo.getCopierEligibleAccounts(
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      if (!res.success || res.data == null) {
        eligibleAccounts.clear();
        eligibleAccountsError.value = res.message ?? 'Failed to load eligible accounts';
        return;
      }
      final data = res.data?['data'];
      if (data is List) {
        eligibleAccounts.assignAll(
          data.whereType<Map>().map((e) => CopyTradingEligibleAccount.fromJson(e.cast<String, dynamic>())),
        );
      } else {
        eligibleAccounts.clear();
      }
    } catch (e) {
      eligibleAccountsError.value = 'Failed to load eligible accounts: $e';
      eligibleAccounts.clear();
    } finally {
      eligibleAccountsLoading.value = false;
    }
  }

  Future<ApiResponse> createPlan(Map<String, dynamic> body) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await _repo.createMasterPlan(payload: body);
      if (res.success) {
        await _loadPlans();
        await _loadStats();
      } else {
        errorMessage.value = res.message ?? 'Failed to create plan';
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Create plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Inactivate a master plan (only allowed when plan is `approved` and `active_copiers_count = 0`)
  Future<ApiResponse> inactivatePlan({required int planId}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await _repo.inactivateMasterPlan(planId: planId);
      if (res.success) {
        await _loadPlans();
        await _loadStats();
      } else {
        errorMessage.value = res.message ?? 'Failed to inactivate plan';
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Inactivate plan error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }
}

