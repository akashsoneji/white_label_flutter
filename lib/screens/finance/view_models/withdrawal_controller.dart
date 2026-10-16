// WithdrawalMethodDetailResponse model
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/bank_withdralList_model.dart'
    show AllowedCryptoNetwork;
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';

class WithdrawalMethodDetailResponse {
  final bool? status;
  final String? message;
  final WithdrawalMethodDetailData? data;

  WithdrawalMethodDetailResponse({this.status, this.message, this.data});

  factory WithdrawalMethodDetailResponse.fromJson(Map<String, dynamic> json) {
    return WithdrawalMethodDetailResponse(
      status: json['status'],
      message: json['message'],
      data:
          json['data'] != null
              ? WithdrawalMethodDetailData.fromJson(json['data'])
              : null,
    );
  }
}

class WithdrawalMethodDetailData {
  final WithdrawalMethod? withdrawalMethod;
  final List<UserWithdrawalMethod>? userWithdrawalMethods;
  final List<MT5Account>? userMT5Accounts;
  final Wallet? wallet;
  final IbAccount? ibaccount;
  final IbmWallet? ibmWallet;

  WithdrawalMethodDetailData({
    this.withdrawalMethod,
    this.userWithdrawalMethods,
    this.userMT5Accounts,
    this.wallet,
    this.ibaccount,
    this.ibmWallet,
  });

  factory WithdrawalMethodDetailData.fromJson(Map<String, dynamic> json) {
    return WithdrawalMethodDetailData(
      withdrawalMethod:
          json['withdrawalMethod'] != null
              ? WithdrawalMethod.fromJson(json['withdrawalMethod'])
              : null,
      userWithdrawalMethods:
          json['userWithdrawalMethods'] != null &&
                  json['userWithdrawalMethods'] is List
              ? List<UserWithdrawalMethod>.from(
                (json['userWithdrawalMethods'] as List).map(
                  (x) =>
                      UserWithdrawalMethod.fromJson(x as Map<String, dynamic>),
                ),
              )
              : [],
      userMT5Accounts:
          json['userMT5Accounts'] != null && json['userMT5Accounts'] is List
              ? List<MT5Account>.from(
                json['userMT5Accounts'].map((x) => MT5Account.fromJson(x)),
              )
              : [],
      wallet: json['wallet'] != null ? Wallet.fromJson(json['wallet']) : null,
      ibaccount:
          json['ibaccount'] != null && json['ibaccount'] is Map<String, dynamic>
              ? IbAccount.fromJson(json['ibaccount'])
              : null,
      ibmWallet:
          json['ibmWallet'] != null && json['ibmWallet'] is Map<String, dynamic>
              ? IbmWallet.fromJson(json['ibmWallet'])
              : null,
    );
  }
}

class UserWithdrawalMethod {
  final String? id;
  final String? withdrawalSlug;
  final String? withdrawalMethod;
  final String? holderName;
  final String? bankName;
  final String? bankAccountNo;
  final String? cryptoAddress;
  final String? upiAddress;
  final String? status;

  UserWithdrawalMethod({
    this.id,
    this.withdrawalSlug,
    this.withdrawalMethod,
    this.holderName,
    this.bankName,
    this.bankAccountNo,
    this.cryptoAddress,
    this.upiAddress,
    this.status,
  });

  factory UserWithdrawalMethod.fromJson(Map<String, dynamic> json) {
    return UserWithdrawalMethod(
      id: json['id']?.toString(),
      withdrawalSlug: json['withdrawal_slug']?.toString(),
      withdrawalMethod: json['withdrawal_method']?.toString(),
      holderName: json['holder_name']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankAccountNo: json['bank_account_no']?.toString(),
      cryptoAddress: json['crypto_address']?.toString(),
      upiAddress: json['upi_address']?.toString(),
      status: json['status']?.toString(),
    );
  }

  String get toAccountDisplayLabel {
    final method = withdrawalMethod?.toLowerCase() ?? '';
    if (method == 'crypto') {
      return 'Crypto (${cryptoAddress ?? ''})';
    }
    if (method == 'bank') {
      final label = bankName?.isNotEmpty == true ? bankName! : holderName ?? '';
      if (label.isNotEmpty && (bankAccountNo?.isNotEmpty ?? false)) {
        return '$label (${bankAccountNo!})';
      }
      return label.isNotEmpty
          ? label
          : (bankAccountNo ??
              TranslationUtils.tr('withdrawal_screen_bank_account'));
    }
    if (method == 'upi') {
      return 'UPI (${upiAddress ?? ''})';
    }
    return holderName ?? id ?? TranslationUtils.tr('settings_account');
  }

  bool get isApproved =>
      status == null || status!.isEmpty || status!.toLowerCase() == 'approved';
}

class Wallet {
  final int? id;
  final String? walletId;
  final String? walletStatus;
  final String? walletBalance;

  Wallet({this.id, this.walletId, this.walletStatus, this.walletBalance});

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id']?.toString() ?? ''),
      walletId: json['wallet_id']?.toString(),
      walletStatus: json['wallet_status']?.toString(),
      walletBalance: json['wallet_balance']?.toString(),
    );
  }
}

class IbAccount {
  final int? id;
  final String? promotionTool;
  final String? status;

  IbAccount({this.id, this.promotionTool, this.status});

  factory IbAccount.fromJson(Map<String, dynamic> json) {
    return IbAccount(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id']?.toString() ?? ''),
      promotionTool: json['promotion_tool']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class IbmWallet {
  final int? id;
  final String? referenceLinkId;
  final num? balance;
  final String? currency;

  IbmWallet({this.id, this.referenceLinkId, this.balance, this.currency});

  factory IbmWallet.fromJson(Map<String, dynamic> json) {
    return IbmWallet(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      referenceLinkId: json['reference_link_id']?.toString(),
      balance: json['balance'] is num
          ? json['balance']
          : num.tryParse(json['balance']?.toString() ?? ''),
      currency: json['currency']?.toString(),
    );
  }
}

// WithdrawalMethodResponse model
class WithdrawalMethodResponse {
  final bool status;
  final String message;
  final List<WithdrawalMethod> data;

  WithdrawalMethodResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory WithdrawalMethodResponse.fromJson(Map<String, dynamic> json) {
    return WithdrawalMethodResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => WithdrawalMethod.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'data': data.map((e) => e.toJson()).toList(),
  };
}

// WithdrawalMethod model
class WithdrawalMethod {
  final int? id;
  final String? methodName;
  final String? methodSlug;
  final String? averageLabel;
  final String? uptoLabel;
  final String? minLimit;
  final String? maxLimit;
  final String? fees;
  final String? status;
  final int? updatedBy;
  final String? role;
  final String? icon;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final bool? cryptoMethod;
  final List<AllowedCryptoNetwork>? allowedCryptoNetworks;
  final String? currencyName;
  final String? conversionRate;
  final bool? hasConversion;
  final num? withdrawalMargin;

  WithdrawalMethod({
    this.id,
    this.methodName,
    this.methodSlug,
    this.averageLabel,
    this.uptoLabel,
    this.minLimit,
    this.maxLimit,
    this.fees,
    this.status,
    this.updatedBy,
    this.role,
    this.icon,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.cryptoMethod,
    this.allowedCryptoNetworks,
    this.currencyName,
    this.conversionRate,
    this.hasConversion,
    this.withdrawalMargin,
  });

  factory WithdrawalMethod.fromJson(Map<String, dynamic> json) {
    return WithdrawalMethod(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id']?.toString() ?? ''),
      methodName: json['method_name']?.toString(),
      methodSlug: json['method_slug']?.toString(),
      averageLabel: json['average_label']?.toString(),
      uptoLabel: json['upto_label']?.toString(),
      minLimit: json['min_limit']?.toString(),
      maxLimit: json['max_limit']?.toString(),
      fees: json['fees']?.toString(),
      status: json['status']?.toString(),
      updatedBy:
          json['updated_by'] is int
              ? json['updated_by']
              : int.tryParse(json['updated_by']?.toString() ?? ''),
      role: json['role']?.toString(),
      icon: json['icon']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
      cryptoMethod: json['crypto_method'] == true,
      allowedCryptoNetworks:
          json['allowed_crypto_networks'] != null
              ? (json['allowed_crypto_networks'] as List)
                  .map(
                    (e) => AllowedCryptoNetwork.fromJson(
                      e as Map<String, dynamic>,
                    ),
                  )
                  .toList()
              : [],
      currencyName: json['currency_name']?.toString(),
      conversionRate: json['conversion_rate']?.toString(),
      hasConversion: json['has_conversion'] == true,
      withdrawalMargin:
          json['withdrawal_margin'] is num
              ? json['withdrawal_margin']
              : num.tryParse(json['withdrawal_margin']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'method_name': methodName,
    'method_slug': methodSlug,
    'average_label': averageLabel,
    'upto_label': uptoLabel,
    'min_limit': minLimit,
    'max_limit': maxLimit,
    'fees': fees,
    'status': status,
    'updated_by': updatedBy,
    'role': role,
    'icon': icon,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
    'crypto_method': cryptoMethod,
    'allowed_crypto_networks':
        allowedCryptoNetworks?.map((e) => e.toJson()).toList(),
  };
}

class WithdrawalController extends GetxController {
  final FinanceRepository _repo = Get.find<FinanceRepository>();
  final _isLoading = false.obs;
  final errorMessage = ''.obs; // Made public for reactive listening
  final successMessage = ''.obs; // Made public for reactive listening

  bool get isLoading => _isLoading.value;

  var withdrawalMethods = <WithdrawalMethod>[].obs;
  final selectedAccount = Rxn<String>();
  final selectedBankAccount = Rxn<String>();
  final selectedCryptoAccount = Rxn<String>();
  final withdrawalAmount = ''.obs;
  final selectedPaymentMethod = ''.obs;
  final selectedWithdrawalMethod =
      Rxn<
        WithdrawalMethod
      >(); // Add this to hold the complete withdrawal method object
  String? _preselectedAccountNumber; // Store preselected account number
  final isOtpSent = false.obs;
  final isOtpLoading = false.obs;

  var userMT5Accounts = <MT5Account>[].obs;
  var wallet = Rxn<Wallet>();
  var ibAccount = Rxn<IbAccount>();
  var ibmWallet = Rxn<IbmWallet>();
  var withdrawalMethodDetail = Rxn<WithdrawalMethodDetailResponse>();

  // Flag to show "no data" view when API returns status: false with message
  final showNoDataView = false.obs;
  final noDataMessage = ''.obs;

  // Flag to track if we've received the initial response (prevents flash of form)
  final hasReceivedInitialResponse = false.obs;

  List<UserWithdrawalMethod> get userWithdrawalMethods =>
      withdrawalMethodDetail.value?.data?.userWithdrawalMethods ?? [];

  UserWithdrawalMethod? get selectedCryptoMethod {
    final id = selectedCryptoAccount.value;
    if (id == null || id.isEmpty) return null;
    try {
      return userWithdrawalMethods.firstWhere((method) => method.id == id);
    } catch (_) {
      return null;
    }
  }

  String get selectedCryptoDisplayLabel =>
      selectedCryptoMethod?.toAccountDisplayLabel ?? '';

  UserWithdrawalMethod? get selectedBankMethod {
    final selected = selectedBankAccount.value;
    if (selected == null || selected.isEmpty) return null;
    for (final method in userWithdrawalMethods) {
      if (method.bankAccountNo == selected || method.id == selected) {
        return method;
      }
    }
    return null;
  }

  WithdrawalMethod? get _methodDetail =>
      withdrawalMethodDetail.value?.data?.withdrawalMethod;

  /// Payout currency of the selected method (e.g. INR), from the detail API.
  String get payoutCurrency => _methodDetail?.currencyName ?? '';

  /// Units of [payoutCurrency] per 1 USD; 0 when the method has no conversion.
  double get conversionRate {
    final method = _methodDetail;
    if (method == null || method.hasConversion != true) return 0;
    return double.tryParse(method.conversionRate ?? '') ?? 0;
  }

  bool get hasConversion => conversionRate > 0 && payoutCurrency.isNotEmpty;

  bool get isSelectedAccountCent {
    final selected = selectedAccount.value;
    if (selected == null) return false;
    for (final account in userMT5Accounts) {
      if (account.metaAccountNumber == selected) return account.isCentAccount;
    }
    return false;
  }

  /// Currency the entered amount is denominated in (the source account's).
  String get sourceCurrency => isSelectedAccountCent ? 'USC' : 'USD';

  /// Cent accounts (USC) hold 100 units per USD.
  double toUsd(double amount) => isSelectedAccountCent ? amount / 100 : amount;

  /// Converts an amount entered in the source account's currency into the
  /// payout currency.
  double convertToPayoutCurrency(double amount) =>
      toUsd(amount) * conversionRate;


  String get selectedPaymentMethodDisplayLabel {
    final method = selectedWithdrawalMethod.value;
    if (method == null) return selectedPaymentMethod.value;
    final name = _formatPaymentMethodName(method.methodName ?? '');
    final slug = method.methodSlug ?? '';
    if (slug.isEmpty) return name;
    return '$name ($slug)';
  }

  String _formatPaymentMethodName(String methodName) {
    if (methodName.isEmpty) return methodName;
    return methodName[0].toUpperCase() + methodName.substring(1).toLowerCase();
  }

  double _parseWithdrawalAmount(String value) {
    final cleaned = value.replaceAll('\$', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  void _autoSelectDefaultToAccount() {
    final methods = userWithdrawalMethods;
    if (methods.isEmpty) return;

    final paymentMethod = selectedPaymentMethod.value.toLowerCase();
    if (paymentMethod == 'crypto') {
      final approvedMethods = methods.where((m) => m.isApproved).toList();
      final selectableMethods =
          approvedMethods.isNotEmpty ? approvedMethods : methods;
      selectedCryptoAccount.value = selectableMethods.first.id;
      return;
    }

    if (paymentMethod == 'bank') {
      final firstMethod = methods.first;
      selectedBankAccount.value =
          firstMethod.bankAccountNo?.isNotEmpty == true
              ? firstMethod.bankAccountNo
              : firstMethod.id;
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Initialize flags
    hasReceivedInitialResponse.value = false;
    showNoDataView.value = false;
    fetchWithdrawalAccounts();
  }

  Future<void> fetchWithdrawalAccounts() async {
    try {
      _setLoading(true);
      _clearError();

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.getWithdrawalMethods(token: token ?? '');

      if (response.success && response.data != null) {
        final data = response.data;
        final withdrawalMethodResponse = WithdrawalMethodResponse.fromJson(
          data,
        );
        if (withdrawalMethodResponse.status &&
            withdrawalMethodResponse.data.isNotEmpty) {
          withdrawalMethods.assignAll(withdrawalMethodResponse.data);

          print("Loaded ${withdrawalMethods.length} withdrawal methods");

          // Auto-select the first withdrawal method and load its details
          final firstMethod = withdrawalMethodResponse.data.first;
          selectedPaymentMethod.value = firstMethod.methodName ?? '';
          selectedWithdrawalMethod.value =
              firstMethod; // Set the complete withdrawal method object
          print(
            "Auto-selected method: ${firstMethod.methodName} with slug: ${firstMethod.methodSlug}",
          );

          if (firstMethod.methodSlug != null) {
            fetchWithdrawalMethodDetails(
              firstMethod.methodSlug!,
              preselectedAccountNumber: _preselectedAccountNumber,
            );
          }
        } else {
          errorMessage.value =
              withdrawalMethodResponse.message.isNotEmpty
                  ? withdrawalMethodResponse.message
                  : TranslationUtils.tr('finance_something_went_wrong');
          Get.back(closeOverlays: true);
        }
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr('finance_something_went_wrong');
        Get.back(closeOverlays: true);
      }
    } catch (e) {
      errorMessage.value = "Error while fetching withdrawal methods: $e";
      Get.back(closeOverlays: true);
    } finally {
      _setLoading(false);
    }
  }

  // Method to set preselected account number (called from screen)
  void setPreselectedAccountNumber(String? accountNumber) {
    _preselectedAccountNumber = accountNumber;
    print(
      "WithdrawalController: Set preselected account number: \"$accountNumber\"",
    );
  }

  Future<void> fetchWithdrawalMethodDetails(
    String slug, {
    String? preselectedAccountNumber,
  }) async {
    // Use the passed parameter or fall back to stored value
    final accountNumberToUse =
        preselectedAccountNumber ?? _preselectedAccountNumber;
    print(
      "WithdrawalController: fetchWithdrawalMethodDetails called with slug: $slug, preselectedAccountNumber: \"$preselectedAccountNumber\", stored: \"$_preselectedAccountNumber\", using: \"$accountNumberToUse\"",
    );
    try {
      _setLoading(true);
      _clearError();

      // Reset flags initially
      showNoDataView.value = false;
      noDataMessage.value = '';
      hasReceivedInitialResponse.value = false;

      // Clear selected crypto and bank accounts when method changes
      selectedCryptoAccount.value = null;
      selectedBankAccount.value = null;

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.getWithdrawalMethodDetail(
        token: token ?? '',
        slug: slug,
      );

      print("response is on withdraelae Controller-->${response.data}");
      print("response.success: ${response.success}");
      print("userMT5Accounts length: ${userMT5Accounts.length}");
      print("wallet data: ${wallet.value?.walletBalance}");

      // Process response and set all state BEFORE setting loading to false
      bool shouldShowNoData = false;
      String noDataMsg = '';

      // First, check if response is successful and has valid data
      if (response.success && response.data != null) {
        try {
          final data = WithdrawalMethodDetailResponse.fromJson(response.data);
          if (data.status == true) {
            // Success - hide no data view and show form
            print("Success - hiding no data view, showing form");
            shouldShowNoData = false;
            noDataMsg = '';

            withdrawalMethodDetail.value = data;
            userMT5Accounts.assignAll(data.data?.userMT5Accounts ?? []);
            wallet.value = data.data?.wallet;
            ibAccount.value = data.data?.ibaccount;
            ibmWallet.value = data.data?.ibmWallet;

            print(
              "After loading - userMT5Accounts length: ${userMT5Accounts.length}",
            );
            print(
              "After loading - wallet balance: ${wallet.value?.walletBalance}",
            );

            // Auto-select account if preselectedAccountNumber is provided
            final accountNumberToUse =
                preselectedAccountNumber ?? _preselectedAccountNumber;
            if (accountNumberToUse != null && accountNumberToUse.isNotEmpty) {
              // Normalize preselected account number
              final normalizedPreselected =
                  accountNumberToUse.toString().trim();
              print(
                "WithdrawalController: Attempting to pre-select account: \"$normalizedPreselected\"",
              );
              print(
                "WithdrawalController: Starting to search through ${userMT5Accounts.length} accounts...",
              );

              // Try to find matching MT5 account
              MT5Account? matchingAccount;
              try {
                final matchingAccounts =
                    userMT5Accounts.where((account) {
                      final accountNumber =
                          account.metaAccountNumber.toString();
                      if (accountNumber.isEmpty) {
                        print(
                          "WithdrawalController: Account has empty metaAccountNumber",
                        );
                        return false;
                      }

                      // Normalize both sides for comparison
                      final normalizedAccount = accountNumber.trim();

                      // Log each comparison attempt
                      print(
                        'WithdrawalController: Comparing list account "$normalizedAccount" (${account.metaAccountNumber.runtimeType}) with preselected "$normalizedPreselected"',
                      );

                      // Try multiple comparison methods
                      final isExactMatch =
                          normalizedAccount == normalizedPreselected;
                      final accountInt = int.tryParse(normalizedAccount);
                      final preselectedInt = int.tryParse(
                        normalizedPreselected,
                      );
                      final isIntMatch =
                          accountInt != null &&
                          preselectedInt != null &&
                          accountInt == preselectedInt;

                      final isMatch = isExactMatch || isIntMatch;

                      if (isMatch) {
                        print(
                          'WithdrawalController: ✅ MATCH FOUND! Account "$normalizedAccount" matches preselected "$normalizedPreselected"',
                        );
                      } else {
                        print(
                          'WithdrawalController: ❌ No match - "$normalizedAccount" != "$normalizedPreselected" (exact: $isExactMatch, int: $isIntMatch)',
                        );
                      }

                      return isMatch;
                    }).toList();

                if (matchingAccounts.isNotEmpty) {
                  matchingAccount = matchingAccounts.first;
                  final matchedAccountNumber =
                      matchingAccount.metaAccountNumber.toString().trim();
                  print(
                    "WithdrawalController: ✅ Successfully matched preselected account: $matchedAccountNumber",
                  );
                  print(
                    "WithdrawalController: Found ${matchingAccounts.length} matching account(s), using first match",
                  );
                } else {
                  print(
                    'WithdrawalController: ❌ No match found for "$normalizedPreselected"',
                  );
                  print(
                    'WithdrawalController: Available account numbers were: ${userMT5Accounts.map((a) => a.metaAccountNumber.toString().trim()).join(", ")}',
                  );
                }
              } catch (e) {
                print(
                  "WithdrawalController: Error during account matching: $e",
                );
              }

              if (matchingAccount != null) {
                selectedAccount.value = matchingAccount.metaAccountNumber;
                print(
                  "WithdrawalController: ✅ Set selectedAccount.value to: ${matchingAccount.metaAccountNumber}",
                );
              } else {
                // Check if it matches wallet ID
                if (wallet.value != null && wallet.value!.walletId != null) {
                  final walletId = wallet.value!.walletId!.trim();
                  if (walletId == normalizedPreselected) {
                    selectedAccount.value = wallet.value!.walletId;
                    print(
                      "WithdrawalController: ✅ Pre-selected wallet: ${wallet.value!.walletId}",
                    );
                  } else {
                    print(
                      "WithdrawalController: ⚠️ Account \"$normalizedPreselected\" not found in available accounts or wallet",
                    );
                    print("WithdrawalController: Wallet ID is: \"$walletId\"");
                    // Don't set selectedAccount if no match found - let it remain unselected
                    // or fall through to default selection below
                  }
                } else {
                  print(
                    "WithdrawalController: ⚠️ Account \"$normalizedPreselected\" not found in available accounts (no wallet available)",
                  );
                  // Don't set selectedAccount if no match found
                }
              }
            } else {
              // If no preselected account, select first available account (existing behavior)
              if (userMT5Accounts.isNotEmpty) {
                selectedAccount.value = userMT5Accounts.first.metaAccountNumber;
                print(
                  "WithdrawalController: Auto-selected first MT5 account: ${userMT5Accounts.first.metaAccountNumber}",
                );
              } else if (wallet.value != null &&
                  wallet.value!.walletId != null &&
                  wallet.value!.walletId!.isNotEmpty) {
                selectedAccount.value = wallet.value!.walletId;
                print(
                  "WithdrawalController: Auto-selected wallet: ${wallet.value!.walletId}",
                );
              }
            }

            _autoSelectDefaultToAccount();
          } else {
            // API returned status: false - show no data view with message
            print("Status false - showing no data view: ${data.message}");
            shouldShowNoData = true;
            noDataMsg =
                data.message ??
                TranslationUtils.tr('finance_something_went_wrong');
            errorMessage.value =
                data.message ??
                TranslationUtils.tr('finance_something_went_wrong');
            // Clear account data
            userMT5Accounts.clear();
            wallet.value = null;
            ibAccount.value = null;
            ibmWallet.value = null;
            withdrawalMethodDetail.value = null;
            // DO NOT call Get.back(closeOverlays: true) - stay on screen and show message
          }
        } catch (parseError) {
          print("JSON parsing error: $parseError");
          errorMessage.value = TranslationUtils.tr(
            'finance_error_parsing_response_data',
          );
          // If parsing fails, don't show no data view, just show error toast
          shouldShowNoData = false;
        }
      } else {
        // Response not successful - this handles 403 and other error status codes
        // For 403 with status: false, the client returns ApiResponse.error()
        // with message containing the API message, but data might be null

        // Check if response.data exists and contains status: false
        Map<String, dynamic>? responseData;
        bool hasStatusFalse = false;

        if (response.data != null) {
          if (response.data is Map<String, dynamic>) {
            responseData = response.data as Map<String, dynamic>;
            hasStatusFalse = responseData['status'] == false;
          }
        }

        // If we have a message from the API (parsed by the network client),
        // and either:
        // 1. response.data has status: false, OR
        // 2. The message indicates a verification/requirement error
        // Then show the no data view
        if (response.message != null && response.message!.isNotEmpty) {
          final message = response.message!.toLowerCase();
          final isVerificationError =
              message.contains('kyc') ||
              message.contains('verification') ||
              message.contains('required') ||
              message.contains('not allowed') ||
              message.contains('cannot');

          if (hasStatusFalse || isVerificationError) {
            // Show no data view with message from API
            print("Showing no data view with message: ${response.message}");
            shouldShowNoData = true;
            noDataMsg =
                response.message ??
                TranslationUtils.tr('finance_something_went_wrong');
            errorMessage.value =
                response.message ??
                TranslationUtils.tr('finance_something_went_wrong');
            // Clear account data
            userMT5Accounts.clear();
            wallet.value = null;
            ibAccount.value = null;
            ibmWallet.value = null;
            withdrawalMethodDetail.value = null;
            // DO NOT call Get.back(closeOverlays: true) - stay on screen and show message
          } else {
            // Other errors - error message will be shown automatically
            print("Response not successful, message: ${response.message}");
            errorMessage.value =
                response.message ??
                TranslationUtils.tr('finance_something_went_wrong');
            // Don't show no data view for other errors
            shouldShowNoData = false;
          }
        } else {
          // No message - don't show no data view
          shouldShowNoData = false;
        }
      }

      // Set all state values BEFORE setting loading to false
      // This ensures UI updates happen atomically
      showNoDataView.value = shouldShowNoData;
      noDataMessage.value = noDataMsg;
      hasReceivedInitialResponse.value = true;
    } catch (e, t) {
      print(" erorore is on withdraelae Controller-->$t");
      errorMessage.value = "Error while fetching withdrawal method details: $e";
      // DO NOT call Get.back(closeOverlays: true) - error message will be shown automatically
      // Don't show no data view for exceptions
      showNoDataView.value = false;
      hasReceivedInitialResponse.value = true;
    } finally {
      // Set loading to false AFTER all state is updated
      _setLoading(false);
    }
  }

  Future<void> submitWithdrawal() async {
    try {
      isOtpLoading.value = true;
      _clearError();

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.sendWithdrawalOtp(
        token: token ?? '',
        queryParameters: {
          "account_number": selectedAccount.value ?? '',
          "amount":
              withdrawalAmount.value
                  .replaceFirst('\$', "")
                  .replaceFirst(' ', "")
                  .trim(),
          "withdrawalMethod": selectedPaymentMethod.value,
        },
      );

      if (response.success && response.data != null) {
        final data = response.data;

        // Check if data is a Map (object) and has status field
        if (data is Map<String, dynamic> && data.containsKey('status')) {
          if (data['status'] == true) {
            successMessage.value = data['message'] ?? "OTP sent successfully";
            // Set OTP sent flag to show OTP input field
            isOtpSent.value = true;
          } else {
            errorMessage.value = data['message'] ?? "Failed to send OTP";
          }
        } else {
          // Handle case where data is empty array or unexpected format
          errorMessage.value = TranslationUtils.tr(
            'finance_invalid_response_format',
          );
        }
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr('finance_something_went_wrong');
      }
    } catch (e) {
      errorMessage.value = "Error while submitting withdrawal: $e";
    } finally {
      isOtpLoading.value = false;
    }
  }

  // Add withdrawal method (Bank, UPI, Crypto, Local) - Updated to match KYC controller logic
  Future<void> addWithdrawalMethod({
    required String withdrawalMethod, // bank, upi, crypto, local
    required String currency, // USD, INR, etc.
    required String otp,
    required String relationship,
    String? bankHolderName,
    String? bankName,
    String? bankAccountNo,
    String? confirmBankAccountNo,
    String? ifscIban,
    String? bankSwiftCode,
    String? upiHolderName,
    String? upiAddress,
    String? cryptoHolderName,
    String? cryptoAddress,
    String? cryptoNetwork,
    String? localHolderName,
    String? proofImagePath, // Path to image file
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final token = await SecureStorageService.getAuthToken();

      // Build request parameters using the same logic as KYC controller
      Map<String, dynamic> requestParams = _buildWithdrawalMethodParams(
        withdrawalMethod: withdrawalMethod,
        currency: currency,
        otp: otp,
        relationship: relationship,
        bankHolderName: bankHolderName,
        bankName: bankName,
        bankAccountNo: bankAccountNo,
        confirmBankAccountNo: confirmBankAccountNo,
        ifscIban: ifscIban,
        bankSwiftCode: bankSwiftCode,
        upiHolderName: upiHolderName,
        upiAddress: upiAddress,
        cryptoHolderName: cryptoHolderName,
        cryptoAddress: cryptoAddress,
        cryptoNetwork: cryptoNetwork,
        localHolderName: localHolderName,
        proofImagePath: proofImagePath,
      );

      // Use the same approach as KYC controller - always use multipart/form-data
      ApiResponse response;
      if (withdrawalMethod.toLowerCase() == 'local' ||
          proofImagePath == null ||
          proofImagePath.isEmpty) {
        // For local method, use postForm (multipart without file)
        response = await _repo.postWithdrawalRequestForm(
          token: token ?? '',
          formData: requestParams,
        );
      } else {
        // For methods requiring file upload, use custom multipart method
        response = await _uploadWithdrawalMethodFile(
          endpoint: ApiConstants.withdrawalRequest,
          token: token,
          file: File(proofImagePath),
          formData: requestParams,
          fileFieldName: _getFileFieldName(withdrawalMethod),
        );
      }

      if (response.success && response.data != null) {
        final data = response.data;

        if (data is Map<String, dynamic> && data.containsKey('status')) {
          if (data['status'] == true) {
            successMessage.value =
                data['message'] ?? "Withdrawal method added successfully";
            // Refresh withdrawal methods list
            await fetchWithdrawalAccounts();
            Get.back(closeOverlays: true);
          } else {
            errorMessage.value =
                data['message'] ?? "Failed to add withdrawal method";
          }
        } else {
          errorMessage.value = TranslationUtils.tr(
            'finance_invalid_response_format',
          );
        }
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr('finance_something_went_wrong');
      }
    } catch (e) {
      errorMessage.value = "Error while adding withdrawal method: $e";
    } finally {
      _setLoading(false);
    }
  }

  // Get OTP for withdrawal method addition
  Future<void> sendWithdrawalMethodOTP() async {
    try {
      isOtpLoading.value = true;
      _clearError();

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.sendWithdrawalOtp(token: token ?? '');

      if (response.success && response.data != null) {
        final data = response.data;

        if (data is Map<String, dynamic> && data.containsKey('status')) {
          if (data['status'] == true) {
            isOtpSent.value = true;
            successMessage.value = data['message'] ?? "OTP sent successfully";
          } else {
            errorMessage.value = data['message'] ?? "Failed to send OTP";
          }
        } else {
          errorMessage.value = TranslationUtils.tr(
            'finance_invalid_response_format',
          );
        }
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr('finance_something_went_wrong');
      }
    } catch (e) {
      errorMessage.value = "Error while sending OTP: $e";
    } finally {
      isOtpLoading.value = false;
    }
  }

  // Helper method to get the correct file field name based on withdrawal method
  String _getFileFieldName(String withdrawalMethod) {
    // Use the same field name as KYC controller
    return 'deposit_proof';
  }

  // Build withdrawal method request parameters - Based on KYC controller logic
  Map<String, dynamic> _buildWithdrawalMethodParams({
    required String withdrawalMethod,
    required String currency,
    required String otp,
    required String relationship,
    String? bankHolderName,
    String? bankName,
    String? bankAccountNo,
    String? confirmBankAccountNo,
    String? ifscIban,
    String? bankSwiftCode,
    String? upiHolderName,
    String? upiAddress,
    String? cryptoHolderName,
    String? cryptoAddress,
    String? cryptoNetwork,
    String? localHolderName,
    String? proofImagePath,
  }) {
    final params = <String, dynamic>{};

    // Add conditional parameters based on withdrawal method
    if (withdrawalMethod.toLowerCase() == "bank") {
      params.addAll({
        "ifsc_iban": ifscIban ?? '',
        "bank_name": bankName ?? '',
        "bank_holder_name": bankHolderName ?? '',
        "bank_account_no": bankAccountNo ?? '',
        "confirm_bank_account_no": confirmBankAccountNo ?? '',
        "swift_code": bankSwiftCode ?? '',
        "optradio": "IFSC", // Default to IFSC
      });
    } else if (withdrawalMethod.toLowerCase() == "crypto") {
      params.addAll({
        "crypto_holder_name": cryptoHolderName ?? '',
        "crypto_address": cryptoAddress ?? '',
        "crypto_network": cryptoNetwork ?? '',
      });
    } else if (withdrawalMethod.toLowerCase() == "upi") {
      params.addAll({
        "upi_holder_name": upiHolderName ?? '',
        "upi_address": upiAddress ?? '',
      });
    } else if (withdrawalMethod.toLowerCase() == "local") {
      params.addAll({"local_holder_name": localHolderName ?? ''});
    }

    // Add common parameters - matching KYC controller structure
    params.addAll({
      "withdrawal_method": withdrawalMethod.toLowerCase(),
      "selectedMethod":
          withdrawalMethod.toLowerCase(), // Must match withdrawal_method
      "currency": currency,
      "belogns_to":
          "", // Note: keeping the typo as it appears in KYC controller
      "relationship": relationship,
      "holder_name":
          bankHolderName ??
          upiHolderName ??
          cryptoHolderName ??
          localHolderName ??
          '',
      "otp": otp,
    });

    // Add proof file path if provided
    if (proofImagePath != null && proofImagePath.isNotEmpty) {
      params['deposit_proof'] = proofImagePath;
    }

    return params;
  }

  // Custom method for uploading withdrawal method files with correct field names
  Future<ApiResponse> _uploadWithdrawalMethodFile({
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
    required String fileFieldName,
    String? token,
  }) async {
    try {
      // If no token provided, try to get from secure storage
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      final headers = {
        'Accept': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request =
          http.MultipartRequest('POST', uri)
            ..headers.addAll(headers)
            ..fields.addAll(
              formData.map((key, value) => MapEntry(key, value.toString())),
            );

      // Check if file exists and is readable
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File is empty: ${file.path}');
      }

      // Add file with the correct field name for withdrawal methods
      request.files.add(
        await http.MultipartFile.fromPath(
          fileFieldName, // Use the correct field name (bank_proof_img, upi_proof_img, etc.)
          file.path,
        ),
      );

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      // Check for 401 status code
      if (response.statusCode == 401) {
        return ApiResponse(success: false, message: 'Unauthorized', data: null);
      }

      // Parse response
      try {
        final responseData = jsonDecode(response.body);
        return ApiResponse(
          success: response.statusCode >= 200 && response.statusCode < 300,
          message: responseData['message'] ?? 'Request completed',
          data: responseData,
        );
      } catch (e) {
        return ApiResponse(
          success: false,
          message: 'Invalid response format: $e',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Upload failed: $e',
        data: null,
      );
    }
  }

  Future<void> submitWithdrawalWithOtp(String otp) async {
    try {
      _setLoading(true);
      _clearError();

      final token = await SecureStorageService.getAuthToken();
      final paymentMethod = selectedPaymentMethod.value.toLowerCase();
      final amount = _parseWithdrawalAmount(withdrawalAmount.value);

      // Server now validates the method identity alongside the OTP, so
      // every request carries method name + saved-method id + method slug.
      final String withdrawalMethodId;
      final String withdrawalMethodSlug;
      if (paymentMethod == 'local') {
        withdrawalMethodId = 'local-method';
        withdrawalMethodSlug = 'local-method';
      } else {
        withdrawalMethodId =
            paymentMethod == 'crypto'
                ? (selectedCryptoAccount.value ?? '')
                : (selectedBankMethod?.id ?? '');
        withdrawalMethodSlug = selectedWithdrawalMethod.value?.methodSlug ?? '';
      }

      final payload = <String, dynamic>{
        'mt5_account_id': selectedAccount.value ?? '',
        'amount': amount,
        'otp': otp,
        'withdrawal_method': paymentMethod,
        'withdrawal_method_id': withdrawalMethodId,
        'withdrawal_method_slug': withdrawalMethodSlug,
        'payout_mobile': '',
        'client_note': '',
      };

      final response = await _repo.submitWithdrawal(
        token: token ?? '',
        payload: payload,
      );

      if (response.success && response.data != null) {
        final data = response.data;

        // Check if data is a Map (object) and has status field
        if (data is Map<String, dynamic> && data.containsKey('status')) {
          if (data['status'] == true) {
            successMessage.value =
                data['message'] ?? "Withdrawal submitted successfully";
            // Reset OTP sent flag
            isOtpSent.value = false;
            // Wait a bit for the toast to be visible before navigating back
            Future.delayed(const Duration(milliseconds: 1500), () {
              Get.back(closeOverlays: true);
            });
          } else {
            errorMessage.value = data['message'] ?? "Withdrawal failed";
          }
        } else {
          // Handle case where data is empty array or unexpected format
          // Also check if status and message are at root level (alternative response format)
          if (data is Map<String, dynamic>) {
            // Try to get status and message from root level
            final rootStatus = data['status'];
            final rootMessage = data['message'];

            if (rootStatus == true && rootMessage != null) {
              successMessage.value = rootMessage;
              isOtpSent.value = false;
              // Wait a bit for the toast to be visible before navigating back
              Future.delayed(const Duration(milliseconds: 1500), () {
                Get.back(closeOverlays: true);
              });
            } else {
              errorMessage.value = TranslationUtils.tr(
                'finance_invalid_response_format',
              );
            }
          } else {
            errorMessage.value = TranslationUtils.tr(
              'finance_invalid_response_format',
            );
          }
        }
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr('finance_something_went_wrong');
      }
    } catch (e) {
      errorMessage.value = "Error while submitting withdrawal: $e";
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading.value = loading;
  }

  void _clearError() {
    errorMessage.value = '';
  }

  void clearMessages() {
    errorMessage.value = '';
    successMessage.value = '';
  }
}
