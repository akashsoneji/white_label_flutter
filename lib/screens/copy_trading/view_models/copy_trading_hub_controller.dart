import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:get/get.dart';

import 'package:crm_app/screens/copy_trading/view_models/copy_trading_subscribe_controller.dart';

enum CopyTradingMasterApplicationStatus { none, pending, approved, rejected, unknown }

class CopyTradingHubController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final Rx<CopyTradingMasterApplicationStatus> masterStatus =
      CopyTradingMasterApplicationStatus.none.obs;
  final RxString masterCode = ''.obs;

  /// True when the user has at least one active subscription as copier.
  final RxBool hasActiveCopySubscription = false.obs;

  /// Active tab index in CopyTradingMainScreen.
  final RxInt currentTabIndex = 0.obs;

  final RxString masterApplyNicknameDraft = ''.obs;
  final RxString masterApplyStrategyDraft = ''.obs;
  final RxString masterApplyRiskInfoDraft = ''.obs;
  final RxBool masterApplyTermsAccepted = false.obs;

  /// Copier eligible accounts (Become Master — pick MT5 account). GET without `plan_id`.
  final RxList<EligibleCopyAccount> masterApplyEligibleAccounts = <EligibleCopyAccount>[].obs;
  final RxBool masterApplyEligibleLoading = false.obs;
  final RxString masterApplyEligibleError = ''.obs;
  final Rxn<int> masterApplySelectedAccountId = Rxn<int>();

  bool get canSubmitMasterApply {
    if (masterApplyNicknameDraft.value.trim().isEmpty) return false;
    if (masterApplyStrategyDraft.value.trim().isEmpty) return false;
    if (masterApplyRiskInfoDraft.value.trim().isEmpty) return false;
    if (!masterApplyTermsAccepted.value) return false;
    return true;
  }

  void resetMasterApplyForm() {
    masterApplyNicknameDraft.value = '';
    masterApplyStrategyDraft.value = '';
    masterApplyRiskInfoDraft.value = '';
    masterApplyTermsAccepted.value = false;
    masterApplySelectedAccountId.value = null;
  }

  Future<void> loadEligibleAccountsForMasterApply() async {
    masterApplyEligibleLoading.value = true;
    masterApplyEligibleError.value = '';
    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierEligibleAccounts,
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      if (!res.success || res.data == null) {
        masterApplyEligibleAccounts.clear();
        masterApplyEligibleError.value = res.message ?? 'Failed to load accounts';
        return;
      }
      final data = res.data?['data'];
      if (data is! List) {
        masterApplyEligibleAccounts.clear();
        masterApplyEligibleError.value = 'Invalid response';
        return;
      }
      masterApplyEligibleAccounts.assignAll(
        data
            .whereType<Map>()
            .map((e) => EligibleCopyAccount.fromJson(e.cast<String, dynamic>())),
      );
    } catch (e) {
      masterApplyEligibleAccounts.clear();
      masterApplyEligibleError.value = 'Load error: $e';
    } finally {
      masterApplyEligibleLoading.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    refreshAll(showLoading: true);
  }

  Future<void> refreshAll({bool showLoading = false}) async {
    if (showLoading) {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      await Future.wait([_loadMasterStatus(), _loadCopierSubscriptions()]);
    } catch (e) {
      errorMessage.value = 'Failed to load copy trading status: $e';
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  Future<void> _loadMasterStatus() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final res = await ApiService.get(
      endpoint: ApiConstants.copyTradingMasterStatus,
      queryParameters: {'_t': timestamp.toString()},
    );

    if (!res.success || res.data == null) {
      // Treat "not applied yet" as none, but keep message for debugging.
      masterStatus.value = CopyTradingMasterApplicationStatus.none;
      masterCode.value = '';
      return;
    }

    final data = res.data?['data'];
    if (data == null || (data is List && data.isEmpty)) {
      masterStatus.value = CopyTradingMasterApplicationStatus.none;
      masterCode.value = '';
      return;
    }

    if (data is! Map) {
      masterStatus.value = CopyTradingMasterApplicationStatus.unknown;
      masterCode.value = '';
      return;
    }

    final statusStr = (data['status'] ?? '').toString().toLowerCase();
    masterCode.value = (data['master_code'] ?? '').toString();

    switch (statusStr) {
      case 'pending':
        masterStatus.value = CopyTradingMasterApplicationStatus.pending;
        break;
      case 'approved':
      case 'active':
        masterStatus.value = CopyTradingMasterApplicationStatus.approved;
        break;
      case 'rejected':
      case 'declined':
        masterStatus.value = CopyTradingMasterApplicationStatus.rejected;
        break;
      case '':
        masterStatus.value = CopyTradingMasterApplicationStatus.none;
        break;
      default:
        masterStatus.value = CopyTradingMasterApplicationStatus.unknown;
        break;
    }
  }

  Future<void> _loadCopierSubscriptions() async {
    final res = await ApiService.get(
      endpoint: ApiConstants.copyTradingCopierSubscriptionsList(),
    );

    if (!res.success || res.data == null) {
      hasActiveCopySubscription.value = false;
      return;
    }

    final list = res.data?['data'];
    if (list is! List) {
      hasActiveCopySubscription.value = false;
      return;
    }

    hasActiveCopySubscription.value = list.any((e) {
      if (e is! Map) return false;
      final status = (e['status'] ?? '').toString().toLowerCase();
      return status == 'active';
    });
  }


  Future<ApiResponse> applyForMaster({
    int? mt5AccountId,
    required String nickname,
    required bool termsAccepted,
    String? strategy,
    String? riskInfo,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = <String, dynamic>{
        'nickname': nickname,
        'terms_accepted': termsAccepted,
      };
      if (mt5AccountId != null) data['mt5_account_id'] = mt5AccountId;
      if (strategy != null && strategy.trim().isNotEmpty) data['strategy'] = strategy;
      if (riskInfo != null && riskInfo.trim().isNotEmpty) data['risk_info'] = riskInfo;
      final res = await ApiService.post(
        endpoint: ApiConstants.copyTradingMasterApply,
        data: data,
      );
      if (!res.success) {
        errorMessage.value = res.message ?? 'Failed to submit application';
      } else {
        await refreshAll(showLoading: false);
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Apply error: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }
}
