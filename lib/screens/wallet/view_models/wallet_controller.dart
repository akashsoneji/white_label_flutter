import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/screens/finance/presentation/pages/deposit_screen.dart';
import 'package:crm_app/screens/wallet/data/repositories/wallet_repository.dart';

// --- Models ---
class WalletResponse {
  final bool status;
  final String message;
  final List<UserMT5Account> userMT5Accounts;
  final Wallet wallet;
  final IbAccount ibAccount;

  WalletResponse({
    required this.status,
    required this.message,
    required this.userMT5Accounts,
    required this.wallet,
    required this.ibAccount,
  });

  factory WalletResponse.fromJson(Map<String, dynamic> json) {
    final ibaccountData = json['data']?['ibaccount'];

    return WalletResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? "",
      userMT5Accounts:
          (json['data']?['userMT5Accounts'] as List? ?? [])
              .map((e) => UserMT5Account.fromJson(e))
              .toList(),
      wallet: Wallet.fromJson(json['data']?['wallet'] ?? {}),
      ibAccount:
          ibaccountData is Map<String, dynamic>
              ? IbAccount.fromJson(ibaccountData)
              : IbAccount(
                id: 0,
                promotionTool: "",
                status: "",
                referenceLinkId: "",
              ),
    );
  }
}

class UserMT5Account {
  final int id;
  final String metaAccountNumber;
  final String metaAccountName;
  final String masterGroupId;
  final String balance;

  UserMT5Account({
    required this.id,
    required this.metaAccountNumber,
    required this.metaAccountName,
    required this.masterGroupId,
    required this.balance,
  });

  factory UserMT5Account.fromJson(Map<String, dynamic> json) {
    return UserMT5Account(
      id: json['id'] ?? 0,
      metaAccountNumber: json['meta_account_number'] ?? '',
      metaAccountName: json['meta_account_name'] ?? '',
      masterGroupId: json['master_group_id'] ?? '',
      balance: json['balance'] ?? '0.0',
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
      walletId: json['wallet_id'] ?? '',
      walletStatus: json['wallet_status'] ?? '',
      walletBalance: json['wallet_balance'] ?? '0.0',
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

  final transferFromController = TextEditingController();
  final transferToController = TextEditingController();
  final amountController = TextEditingController(text: '0.00');

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
    // Set default values
    // transferFromAccount.value = accountOptions[0];
    // transferFromController.text = accountOptions[0];
    // transferToController.text = accountOptions[0];
    // amountController.text = '\$500.00';
    // amount.value = '\$500.00';
    fetchWalletData();
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
        message: 'Please select Transfer From',
      );
      return;
    }

    final rawText = amountController.text.trim();
    if (rawText.isEmpty) {
      CustomToastService.showError(
        message: 'Please enter amount',
      );
      return;
    }

    // Clean currency symbols and commas
    final cleanedText = rawText.replaceAll(RegExp(r'[^0-9.]'), '');

    final parsedAmount = PrecisionHelper.parseDouble(cleanedText);
    if (parsedAmount <= 0.0) {
      CustomToastService.showError(
        message: 'Amount must be greater than 0.00',
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
          message: 'Failed to initiate deposit',
          title: 'Error',
        );
      }
    } finally {
      isLoading.value = false;
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
            message: 'Insufficient balance for this transfer',
          );
        }
        return isValid;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to check balance',
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
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        isOtpSent.value = true;
        otpMessage.value = response.data['message'] ?? 'OTP sent successfully';
        CustomToastService.showSuccess(
          message: 'OTP sent successfully',
        );
        return true;
      } else {
        otpMessage.value = response.message ?? 'Failed to send OTP';
        CustomToastService.showError(
          message: response.message ?? 'Failed to send OTP',
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

  // Submit internal transfer with OTP
  Future<bool> submitInternalTransfer(
    String otp,
    String comment,
    String fromAccountId,
    String toAccountId,
    String amount,
  ) async {
    if (otp.isEmpty) {
      CustomToastService.showError(
        message: 'Please enter OTP',
      );
      return false;
    }

    if (fromAccountId.isEmpty || toAccountId.isEmpty) {
      CustomToastService.showError(
        message: 'Please select both From and To accounts',
      );
      return false;
    }

    if (amount.isEmpty) {
      CustomToastService.showError(
        message: 'Please enter amount',
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
          'otp': otp,
        },
      );

      if (response.success && response.data != null) {
        CustomToastService.showSuccess(
          message: 'Transfer completed successfully',
        );

        // Refresh wallet data to get updated balances
        await fetchWalletData();

        // Reset form and clean all values
        _resetTransferForm();

        return true;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Transfer failed',
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
        message: 'Please select Transfer From',
      );
      return false;
    }

    if (amount.value.isEmpty) {
      CustomToastService.showError(
        message: 'Please Enter amount',
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
        CustomToastService.showSuccess(message: 'OTP sent');
      } else {
        // errorMessage.value = response.message ?? 'Failed to send OTP';
        print('❌ Failed to send OTP: ${response.message}');
        CustomToastService.showError(
          message: response.message ?? 'Failed to send OTP',
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

  Future<void> fetchWalletData() async {
    try {
      isLoading.value = true;

      final token = await SecureStorageService.getAuthToken();
      // Add timestamp parameter as required by API
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _repo.getWalletData(
        token: token ?? '',
        queryParameters: {'_t': timestamp.toString()},
      );

      if (response.success && response.data != null) {
        final parsed = WalletResponse.fromJson(response.data);
        print(
          "Wallet API Parsed Response: ${parsed.message},=======,${parsed.wallet.walletId}",
        );
        mt5Accounts.assignAll(parsed.userMT5Accounts);
        wallet.value = parsed.wallet;
        ibAccount.value = parsed.ibAccount;
        balance.value = parsed.wallet.walletBalance;
      } else {
        print("Failed to fetch wallet data: ${response.message}");
        CustomToastService.showError(
          message: response.message ?? "Something went wrong",
        );
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

    print('WalletController: All wallet data cleared successfully');
  }
}
