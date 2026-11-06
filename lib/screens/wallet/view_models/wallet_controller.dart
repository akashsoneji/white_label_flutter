import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/services/crm_settings_service.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/screens/finance/presentation/pages/deposit_screen.dart';
import 'package:crm_app/screens/wallet/data/repositories/wallet_repository.dart';


import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';

// --- Models ---
class WalletResponse {
  final bool status;
  final String message;
  final List<UserMT5Account> userMT5Accounts;
  final Wallet wallet;
  final IbAccount ibAccount;
  final IbmWallet? ibmWallet;

  WalletResponse({
    required this.status,
    required this.message,
    required this.userMT5Accounts,
    required this.wallet,
    required this.ibAccount,
    this.ibmWallet,
  });

  factory WalletResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final Map<String, dynamic> data = rawData is Map<String, dynamic> ? rawData : {};
    final ibaccountData = data['ibaccount'];
    final ibmWalletData = data['ibmWallet'];

    return WalletResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? "",
      userMT5Accounts:
          (data['userMT5Accounts'] as List? ?? [])
              .map((e) => UserMT5Account.fromJson(e))
              .toList(),
      wallet: Wallet.fromJson(data['wallet'] is Map<String, dynamic> ? data['wallet'] : {}),
      ibAccount:
          ibaccountData is Map<String, dynamic>
              ? IbAccount.fromJson(ibaccountData)
              : IbAccount(
                  id: 0,
                  promotionTool: "",
                  status: "",
                  referenceLinkId: "",
                ),
      ibmWallet: ibmWalletData is Map<String, dynamic>
          ? IbmWallet.fromJson(ibmWalletData)
          : null,
    );
  }
}

class IbmWallet {
  final int id;
  final String referenceLinkId;
  final String balance;
  final String currency;

  IbmWallet({
    required this.id,
    required this.referenceLinkId,
    required this.balance,
    required this.currency,
  });

  factory IbmWallet.fromJson(Map<String, dynamic> json) {
    return IbmWallet(
      id: json['id'] ?? 0,
      referenceLinkId: json['reference_link_id']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '0.0',
      currency: json['currency']?.toString() ?? 'USD',
    );
  }
}

class UserMT5Account {
  final int id;
  final String metaAccountNumber;
  final String metaAccountName;
  final String masterGroupId;
  final String balance;
  final double? availableForTransfer;
  /// Server's reason this account cannot send funds; empty = not blocked.
  final String transferBlockedReason;
  /// USC account: balance and transfer amounts are in cents (100 USC = 1 USD).
  final bool isCentAccount;

  UserMT5Account({
    required this.id,
    required this.metaAccountNumber,
    required this.metaAccountName,
    required this.masterGroupId,
    required this.balance,
    this.availableForTransfer,
    this.transferBlockedReason = '',
    this.isCentAccount = false,
  });

  factory UserMT5Account.fromJson(Map<String, dynamic> json) {
    return UserMT5Account(
      id: json['id'] ?? 0,
      metaAccountNumber: json['meta_account_number']?.toString() ?? '',
      metaAccountName: json['meta_account_name']?.toString() ?? '',
      masterGroupId: json['master_group_id']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '0.0',
      availableForTransfer: double.tryParse(json['available_for_transfer']?.toString() ?? ''),
      transferBlockedReason:
          json['transfer_blocked_reason']?.toString().trim() ?? '',
      isCentAccount: json['is_cent_account'] == true ||
          json['is_cent_account'] == 1 ||
          json['is_cent_account']?.toString() == '1' ||
          json['is_cent_account']?.toString().toLowerCase() == 'true' ||
          json['currency']?.toString().toUpperCase() == 'USC',
    );
  }
}

class Wallet {
  final int id;
  final String walletId;
  final String walletStatus;
  final String walletBalance;

  Wallet({
    required this.id,
    required this.walletId,
    required this.walletStatus,
    required this.walletBalance,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] ?? 0,
      walletId: json['wallet_id']?.toString() ?? '',
      walletStatus: json['wallet_status']?.toString() ?? '',
      walletBalance: json['wallet_balance']?.toString() ?? '0.0',
    );
  }
}

class IbAccount {
  final int id;
  final String promotionTool;
  final String status;
  final String referenceLinkId;

  IbAccount({
    required this.id,
    required this.promotionTool,
    required this.status,
    required this.referenceLinkId,
  });

  factory IbAccount.fromJson(Map<String, dynamic> json) {
    return IbAccount(
      id: json['id'] ?? 0,
      promotionTool: json['promotion_tool'] ?? '',
      status: json['status'] ?? '',
      referenceLinkId: json['reference_link_id'] ?? '',
    );
  }
}

class WalletController extends GetxController {
  final WalletRepository _repo = Get.find<WalletRepository>();

  var walletId = 'PIPW008'.obs;
  var balance = ''.obs;
  var transferFromAccount = ''.obs;
  var transferToAccount = ''.obs;
  var amount = ''.obs;
  var isLoading = false.obs;
  var showTransferFromDropdown = false.obs;
  final RxBool isOtpSent = false.obs;
  final RxBool isOtpLoading = false.obs;
  final RxBool isTransferLoading = false.obs;
  final RxString otpMessage = ''.obs;
  /// Where the last internal-transfer OTP went (sendOTP `data.channel`).
  final RxString otpChannel = ''.obs;
  /// Set when `GET internaltransfer` fails; empty after a successful load.
  final RxString walletError = ''.obs;
  final Rx<UserMT5Account?> selectedFromAccount = Rxn<UserMT5Account>();
  final Rx<String?> selectedFromAccountType =
      Rxn<String>(); // 'mt5', 'wallet', 'ib'
  final Rx<String?> selectedToAccountType =
      Rxn<String>(); // 'mt5', 'wallet', 'ib'
  final Rx<dynamic> selectedToAccount =
      Rxn<dynamic>(); // Can be UserMT5Account, Wallet, or String for IB

  // Observables for parsed wallet data
  var mt5Accounts = <UserMT5Account>[].obs;
  var wallet = Rxn<Wallet>();
  var ibAccount = Rxn<IbAccount>();
  var ibmWallet = Rxn<IbmWallet>();

  final transferFromController = TextEditingController();
  final transferToController = TextEditingController();
  final amountController = TextEditingController(text: '0.00');

  // History State
  final FinanceRepository _financeRepo = Get.find<FinanceRepository>();
  static const int _historyPerPage = 10;
  int _historyRequestId = 0;
  var isHistoryLoading = false.obs;
  var isLoadingMore = false.obs;
  var hasMore = true.obs;

  final completedTransactions = <WalletHistoryEntry>[].obs;
  final pendingTransactions = <WalletHistoryEntry>[].obs;
  final rejectedTransactions = <WalletHistoryEntry>[].obs;
  final selectedHistoryTab = WalletHistoryTab.completed.obs;
  var currentPage = 1.obs;
  var lastPage = 1.obs;

  // History Filters (yyyy-MM-dd)
  var filterDateFrom = ''.obs;
  var filterDateTo = ''.obs;

  List<WalletHistoryEntry> get visibleHistoryTransactions {
    switch (selectedHistoryTab.value) {
      case WalletHistoryTab.completed:
        return completedTransactions;
      case WalletHistoryTab.pending:
        return pendingTransactions;
      case WalletHistoryTab.rejected:
        return rejectedTransactions;
    }
  }

  // Sample account options for dropdown
  final List<String> accountOptions = [
    'MT5 Account Number',
    'MT4 Account Number',
    'Demo Account',
    'Live Account 001',
    'Live Account 002',
  ];

  @override
  void onInit() {
    super.onInit();
    fetchWalletData();
    fetchWalletHistory();
  }

  void selectTransferFromAccount(String account) {
    transferFromAccount.value = account;
    transferFromController.text = account;
    showTransferFromDropdown.value = false;
  }

  void toggleTransferFromDropdown() {
    showTransferFromDropdown.value = !showTransferFromDropdown.value;
  }

  void updateTransferToAccount(String value) {
    transferToAccount.value = value;
  }

  void updateAmount(String value) {
    amount.value = value;
  }

  Future<void> depositWallet() async {
    if (transferFromAccount.value.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr(
          'wallet_controller_please_select_transfer_from',
        ),
      );
      return;
    }

    final rawText = amountController.text.trim();
    if (rawText.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr('internal_transfer_enter_amount'),
      );
      return;
    }

    // Clean currency symbols and commas
    final cleanedText = rawText.replaceAll(RegExp(r'[^0-9.]'), '');

    final parsedAmount = PrecisionHelper.parseDouble(cleanedText);
    if (parsedAmount <= 0.0) {
      CustomToastService.showError(
        message: TranslationUtils.tr('wallet_validation_amount_positive'),
      );
      return;
    }

    try {
      isLoading.value = true;

      // await Future.delayed(const Duration(seconds: 3));

      Get.to(() => DepositScreen(accountNumber: ''));
    } catch (e) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr(
            'wallet_controller_failed_to_initiate_deposit',
          ),
          title: TranslationUtils.tr('close_position_error'),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Same server check as [checkBalance] but without toasts, for the live
  /// "Balance sufficient" banner on the transfer screen.
  Future<({bool valid, String message})> validateBalance(
    String accountNumber,
    double amount,
  ) async {
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.checkBalance(
        token: token ?? '',
        payload: {'account_number': accountNumber, 'amount': amount},
      );
      if (response.success && response.data != null) {
        final responseData = response.data as Map<String, dynamic>?;
        final nestedData = responseData?['data'] as Map<String, dynamic>?;
        final isValid = nestedData?['valid'] == true;
        final apiMessage = responseData?['message']?.toString().trim() ?? '';
        return (
          valid: isValid,
          message: isValid
              ? ''
              : (apiMessage.isNotEmpty
                  ? apiMessage
                  : TranslationUtils.tr(
                      'wallet_controller_insufficient_balance_for_this_transfer',
                    )),
        );
      }
      final message = response.message?.trim() ?? '';
      return (
        valid: false,
        message: message.isNotEmpty
            ? message
            : TranslationUtils.tr('wallet_controller_failed_to_check_balance'),
      );
    } catch (_) {
      return (
        valid: false,
        message: TranslationUtils.tr('wallet_controller_failed_to_check_balance'),
      );
    }
  }

  // Check balance before transfer
  Future<bool> checkBalance(String accountNumber, double amount) async {
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.checkBalance(
        token: token ?? '',
        payload: {'account_number': accountNumber, 'amount': amount},
      );

      if (response.success && response.data != null) {
        // API response structure: {"status": true, "message": "", "data": {"valid": true}}
        // So we need to access response.data['data']['valid']
        final responseData = response.data as Map<String, dynamic>?;
        final nestedData = responseData?['data'] as Map<String, dynamic>?;
        final isValid = nestedData?['valid'] ?? false;

        if (!isValid) {
          CustomToastService.showError(
            message: TranslationUtils.tr(
              'wallet_controller_insufficient_balance_for_this_transfer',
            ),
          );
        }
        return isValid;
      } else {
        CustomToastService.showError(
          message: response.message ??
              TranslationUtils.tr('wallet_controller_failed_to_check_balance'),
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(
        message: 'Error checking balance: $e',
      );
      return false;
    }
  }

  // Send OTP for internal transfer
  Future<bool> sendOTP(String accountNumber) async {
    try {
      isOtpLoading.value = true;
      otpMessage.value = '';

      final token = await SecureStorageService.getAuthToken();
      // Add timestamp parameter
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.sendOtp(
        token: token ?? '',
        queryParameters: {
          'request_type': 'internal_transfer',
          '_t': timestamp.toString(),
        },
      );

      if (response.success && response.data != null) {
        isOtpSent.value = true;
        final otpData = response.data['data'];
        otpChannel.value =
            otpData is Map ? otpData['channel']?.toString() ?? '' : '';
        otpMessage.value = response.data['message'] ??
            TranslationUtils.tr('wallet_controller_otp_sent_successfully');
        CustomToastService.showSuccess(
          message: TranslationUtils.tr(
            'wallet_controller_otp_sent_successfully',
          ),
        );
        return true;
      } else {
        otpMessage.value = response.message ??
            TranslationUtils.tr('auth_controller_failed_to_send_otp');
        CustomToastService.showError(
          message: response.message ??
              TranslationUtils.tr('auth_controller_failed_to_send_otp'),
        );
        return false;
      }
    } catch (e) {
      otpMessage.value = 'Error: $e';
      CustomToastService.showError(
        message: 'Error sending OTP: $e',
      );
      return false;
    } finally {
      isOtpLoading.value = false;
    }
  }

  // Submit internal transfer. Pass `otp: null` when the broker has
  // `internal_transfer_otp_required` off, so no `otp` key is sent.
  Future<bool> submitInternalTransfer(
    String? otp,
    String comment,
    String fromAccountId,
    String toAccountId,
    String amount,
  ) async {
    if (otp != null && otp.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr('kyc_bank_controller_please_enter_otp'),
      );
      return false;
    }

    if (fromAccountId.isEmpty || toAccountId.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr(
          'wallet_controller_please_select_both_from_and_to',
        ),
      );
      return false;
    }

    if (amount.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr('internal_transfer_enter_amount'),
      );
      return false;
    }

    try {
      isTransferLoading.value = true;

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.internalTransfer(
        token: token ?? '',
        payload: {
          'from_account': fromAccountId,
          'to_account': toAccountId,
          'amount': amount,
          'comment': comment,
          if (otp != null) 'otp': otp,
        },
      );

      if (response.success && response.data != null) {
        CustomToastService.showSuccess(
          message: _transferSuccessMessage(response.message),
        );

        // Refresh wallet data to get updated balances
        await fetchWalletData();

        // Reset form and clean all values
        _resetTransferForm();

        return true;
      } else {
        CustomToastService.showError(
          message: response.message ??
              TranslationUtils.tr('wallet_controller_transfer_failed'),
        );
        return false;
      }
    } catch (e) {
      CustomToastService.showError(
        message: 'Error processing transfer: $e',
      );
      return false;
    } finally {
      isTransferLoading.value = false;
    }
  }

  // With approval on, some transfers wait for admin approval, so the API's own
  // message is the accurate one; "completed" would be wrong.
  String _transferSuccessMessage(String? apiMessage) {
    final approvalRequired = Get.isRegistered<CrmSettingsService>() &&
        (Get.find<CrmSettingsService>()
                .current
                ?.financialSettings
                .internalTransferApprovalRequired ??
            false);
    if (approvalRequired) {
      final message = apiMessage?.trim() ?? '';
      return message.isNotEmpty
          ? message
          : TranslationUtils.tr('wallet_controller_transfer_sent_for_approval');
    }
    return TranslationUtils.tr(
      'wallet_controller_transfer_completed_successfully',
    );
  }

  // Reset transfer form
  void _resetTransferForm() {
    selectedFromAccount.value = null;
    selectedFromAccountType.value = null;
    selectedToAccount.value = null;
    selectedToAccountType.value = null;
    transferFromAccount.value = '';
    transferToAccount.value = '';
    amountController.clear();
    isOtpSent.value = false;
    otpMessage.value = '';
  }

  // Validate required fields - Dynamic validation based on account type
  bool _validateRequiredFields() {
    // Common validation
    if (transferFromAccount.value.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr(
          'wallet_controller_please_select_transfer_from',
        ),
      );
      return false;
    }

    if (amount.value.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr('wallet_controller_please_enter_amount'),
      );
      return false;
    }

    return true;
  }

  // Send OTP
  Future<void> sendOtp() async {
    try {
      isLoading.value = true;
      // errorMessage.value = '';

      // Validate required fields based on account type
      if (!_validateRequiredFields()) {
        return;
      }

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.sendOtp(token: token ?? '');

      if (response.success) {
        print('✅ OTP sent successfully');
        isOtpSent.value = true;
        // successMessage.value = 'OTP sent successfully';
        CustomToastService.showSuccess(
          message: TranslationUtils.tr('wallet_controller_otp_sent'),
        );
      } else {
        // errorMessage.value = response.message ?? 'Failed to send OTP';
        print('❌ Failed to send OTP: ${response.message}');
        CustomToastService.showError(
          message: response.message ??
              TranslationUtils.tr('auth_controller_failed_to_send_otp'),
        );
      }
    } catch (e) {
      // err.value = 'Error sending OTP: $e';
      print('❌ Error sending OTP: $e');
      CustomToastService.showError(
        message: 'Error sending OTP: $e',
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    transferFromController.dispose();
    transferToController.dispose();
    amountController.dispose();
    super.onClose();
  }

  /// Rx writes notify every Obx synchronously. This controller is shared by
  /// several screens and is started from initState / Get.put field
  /// initializers, i.e. mid-build, where that notification throws
  /// "markNeedsBuild() called during build". Wait for the frame to finish.
  Future<void> _waitForBuildToFinish() async {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      await scheduler.endOfFrame;
    }
  }

  Future<void> fetchWalletData() async {
    try {
      await _waitForBuildToFinish();
      isLoading.value = true;
      walletError.value = '';

      final token = await SecureStorageService.getAuthToken();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 1. Fetch legacy wallet data (to get mt5Accounts and ibAccount for transfer screen)
      try {
        final legacyResponse = await _repo.getWalletData(
          token: token ?? '',
          queryParameters: {'_t': timestamp.toString()},
        );

        if (legacyResponse.success && legacyResponse.data != null) {
          final parsed = WalletResponse.fromJson(legacyResponse.data);
          mt5Accounts.assignAll(parsed.userMT5Accounts);
          ibAccount.value = parsed.ibAccount;
          ibmWallet.value = parsed.ibmWallet;
          // Fallback wallet & balance
          wallet.value = parsed.wallet;
          balance.value = parsed.wallet.walletBalance;
        } else {
          walletError.value = legacyResponse.message ??
              TranslationUtils.tr('internal_transfer_screen_load_failed');
        }
      } catch (e, stack) {
        walletError.value =
            TranslationUtils.tr('internal_transfer_screen_load_failed');
        print("WalletController: Error fetching legacy wallet data: $e\n$stack");
      }

      // Fallback: If mt5Accounts is empty, populate from DashboardController or AccountController
      if (mt5Accounts.isEmpty) {
        try {
          if (Get.isRegistered<DashboardController>()) {
            final dashCtrl = Get.find<DashboardController>();
            if (dashCtrl.mt5Accounts.isNotEmpty) {
              final mapped = dashCtrl.mt5Accounts.map((acc) {
                return UserMT5Account(
                  id: acc.primaryAccount,
                  metaAccountNumber: acc.metaAccountNumber,
                  metaAccountName: acc.mt5NickName,
                  masterGroupId: acc.masterGroupId,
                  balance: acc.balance,
                );
              }).toList();
              mt5Accounts.assignAll(mapped);
              print("WalletController: Populated ${mapped.length} mt5Accounts from DashboardController fallback");
            }
          }
          if (mt5Accounts.isEmpty && Get.isRegistered<AccountController>()) {
            final acctCtrl = Get.find<AccountController>();
            if (acctCtrl.accounts.isNotEmpty) {
              final mapped = acctCtrl.accounts
                  .where((acc) => acc.type == 'REAL')
                  .map((acc) {
                return UserMT5Account(
                  id: 0,
                  metaAccountNumber: acc.id,
                  metaAccountName: 'MT5 Account',
                  masterGroupId: 'REAL',
                  balance: acc.balance.toString(),
                );
              }).toList();
              mt5Accounts.assignAll(mapped);
              print("WalletController: Populated ${mapped.length} mt5Accounts from AccountController fallback");
            }
          }
        } catch (e) {
          print("WalletController fallback error: $e");
        }
      }

      // 2. Fetch fresh wallet details from the new api/user/wallet endpoint
      try {
        final freshResponse = await _repo.getWalletDetailsNew(
          token: token ?? '',
          queryParameters: {'_t': timestamp.toString()},
        );

        if (freshResponse.success && freshResponse.data != null) {
          final freshData = freshResponse.data;
          if (freshData['data'] != null) {
            final walletMap = freshData['data'] as Map<String, dynamic>;
            final walletIdStr = walletMap['wallet_id']?.toString() ?? '';
            final balanceStr = walletMap['balance']?.toString() ?? '0.0';

            wallet.value = Wallet(
              id: wallet.value?.id ?? 0,
              walletId: walletIdStr,
              walletStatus: wallet.value?.walletStatus ?? 'active',
              walletBalance: balanceStr,
            );
            balance.value = balanceStr;
            print("Fetched wallet Details: ID = $walletIdStr, Balance = $balanceStr");
          }
        } else {
          print("Failed to fetch fresh wallet details: ${freshResponse.message}");
        }
      } catch (e, stack) {
        print("WalletController: Error fetching fresh wallet details: $e\n$stack");
      }
    } catch (e) {
      print("Error fetching wallet data: $e");
      CustomToastService.showError(
        message: "Error while fetching wallet data: $e",
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear all wallet data (called on logout)
  void clearAllWalletData() {
    print('WalletController: Clearing all wallet data...');

    // Clear all wallet data
    mt5Accounts.clear();
    wallet.value = null;
    ibAccount.value = null;
    balance.value = '';

    // Clear transfer form data
    selectedFromAccount.value = null;
    transferFromAccount.value = '';
    transferToAccount.value = '';
    amount.value = '';
    amountController.clear();

    // Clear OTP data
    isOtpSent.value = false;
    isOtpLoading.value = false;
    isTransferLoading.value = false;
    otpMessage.value = '';

    // Clear dropdown state
    showTransferFromDropdown.value = false;

    // Force UI refresh
    mt5Accounts.refresh();
    wallet.refresh();
    ibAccount.refresh();
    balance.refresh();

    print('WalletController: All data cleared.');
  }

  // --- History & Pagination Logic ---

  /// Wallet history comes from `user/finance-activity`, a single paginated
  /// list. The Completed/Pending/Rejected tabs are split client-side by
  /// status.
  Future<void> fetchWalletHistory({int page = 1}) async {
    // A page-1 fetch (initial load, filter change, refresh) starts a new
    // generation; page>1 fetches belong to the current one. Responses from an
    // older generation are dropped — otherwise an unfiltered request still in
    // flight when a date filter is applied lands afterwards and overwrites (or
    // appends to) the filtered list.
    final requestId = page == 1 ? ++_historyRequestId : _historyRequestId;
    bool isStale() => requestId != _historyRequestId;

    try {
      await _waitForBuildToFinish();
      if (isStale()) return;
      if (page == 1) {
        isHistoryLoading.value = true;
        // Any in-flight load-more belongs to the old generation and will be
        // discarded, so release its flag here.
        isLoadingMore.value = false;
        hasMore.value = true;
      } else {
        isLoadingMore.value = true;
      }

      final token = await SecureStorageService.getAuthToken();
      final dateFrom = filterDateFrom.value;
      final dateTo = filterDateTo.value;
      final response = await _financeRepo.getTransactions(
        token: token ?? '',
        page: page,
        perPage: _historyPerPage,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (isStale()) return;

      final body =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : const <String, dynamic>{};
      final rows = body['data'];
      if (!response.success || rows is! List) {
        if (page == 1) _clearHistoryLists();
        hasMore.value = false;
        return;
      }

      final entries =
          rows
              .whereType<Map<String, dynamic>>()
              .map(WalletHistoryEntry.fromFinanceActivity)
              .toList();

      final pagination = body['pagination'];
      final pageInfo =
          pagination is Map<String, dynamic>
              ? pagination
              : const <String, dynamic>{};
      currentPage.value = _toInt(pageInfo['current_page'], page);
      lastPage.value = _toInt(pageInfo['last_page'], currentPage.value);

      if (page == 1) _clearHistoryLists();
      for (final entry in entries) {
        switch (entry.tab) {
          case WalletHistoryTab.completed:
            completedTransactions.add(entry);
            break;
          case WalletHistoryTab.pending:
            pendingTransactions.add(entry);
            break;
          case WalletHistoryTab.rejected:
            rejectedTransactions.add(entry);
            break;
        }
      }

      hasMore.value = entries.isNotEmpty && currentPage.value < lastPage.value;
    } catch (e, stack) {
      print("Error fetching wallet history: $e");
      print(stack);
      if (isStale()) return;
      if (page == 1) _clearHistoryLists();
      hasMore.value = false;
    } finally {
      // A stale request must not reset the flags of the newer one.
      if (!isStale()) {
        isHistoryLoading.value = false;
        isLoadingMore.value = false;
      }
    }
    if (isStale()) return;
    _fillVisibleTab();
  }

  int _toInt(dynamic value, int fallback) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  void _clearHistoryLists() {
    completedTransactions.clear();
    pendingTransactions.clear();
    rejectedTransactions.clear();
  }

  /// Tabs are client-side slices of one paginated list, so the selected tab
  /// can be short (or empty) while later pages still hold its entries. Keep
  /// paging until it has a screenful or the server runs out.
  void _fillVisibleTab() {
    if (visibleHistoryTransactions.length >= _historyPerPage) return;
    loadMoreTransactions();
  }

  void selectHistoryTab(WalletHistoryTab tab) {
    selectedHistoryTab.value = tab;
    _fillVisibleTab();
  }

  void loadMoreTransactions() {
    if (isHistoryLoading.value || isLoadingMore.value || !hasMore.value) {
      return;
    }
    fetchWalletHistory(page: currentPage.value + 1);
  }

  void applyFilters() {
    fetchWalletHistory(page: 1);
  }

  void clearFilters() {
    filterDateFrom.value = '';
    filterDateTo.value = '';
    fetchWalletHistory(page: 1);
  }
}

enum WalletHistoryTab { completed, pending, rejected }

/// One row of `GET user/finance-activity`. The sign of [amount] is the
/// direction: positive = money in, negative = money out.
class WalletHistoryEntry {
  final String id;
  final DateTime? date;
  final String type;
  final String from;
  final String to;
  final double amount;
  final String status;
  final String reference;
  final String reason;

  const WalletHistoryEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.from,
    required this.to,
    required this.amount,
    required this.status,
    required this.reference,
    required this.reason,
  });

  bool get isCredit => amount >= 0;

  /// Processing/approved rows belong to Completed, matching the web tabs.
  WalletHistoryTab get tab {
    final s = status.toLowerCase();
    if (s.contains('reject') ||
        s.contains('fail') ||
        s.contains('cancel') ||
        s.contains('declin')) {
      return WalletHistoryTab.rejected;
    }
    if (s.contains('pending')) return WalletHistoryTab.pending;
    return WalletHistoryTab.completed;
  }

  factory WalletHistoryEntry.fromFinanceActivity(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';

    final type = str('transaction_type').isNotEmpty
        ? str('transaction_type')
        : str('paymentMethod');
    final lowerType = type.toLowerCase();
    final fromAccount = str('from_account');

    // The API sends an unsigned "$100.00"; direction comes from the type,
    // and for transfers from whether the wallet is the source account.
    final bool isOutgoing;
    if (lowerType.contains('withdraw')) {
      isOutgoing = true;
    } else if (lowerType.contains('transfer')) {
      isOutgoing = fromAccount.isNotEmpty && fromAccount == str('wallet_id');
    } else {
      isOutgoing = false;
    }
    final magnitude =
        (double.tryParse(
                  str('amount').replaceAll(RegExp(r'[^0-9.\-]'), ''),
                ) ??
                0)
            .abs();

    // account_label is "WA#123 → TA#456" for transfers, a single account
    // label otherwise; the payment method is the other side.
    final label = str('account_label');
    final method = str('paymentMethod');
    final labelParts =
        label
            .split('\u2192')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
    final String from;
    final String to;
    if (labelParts.length == 2) {
      from = labelParts[0];
      to = labelParts[1];
    } else if (isOutgoing) {
      from = label;
      to = method;
    } else {
      from = method;
      to = label;
    }

    final rejectReason = str('reject_reason');

    return WalletHistoryEntry(
      id: str('id'),
      date:
          DateTime.tryParse(str('created_at_iso')) ??
          DateTime.tryParse(str('created_at')),
      type: type,
      from: from,
      to: to,
      amount: isOutgoing ? -magnitude : magnitude,
      status: str('status'),
      reference: str('reference_number'),
      reason:
          rejectReason.isNotEmpty ? rejectReason : str('comment_for_client'),
    );
  }
}
