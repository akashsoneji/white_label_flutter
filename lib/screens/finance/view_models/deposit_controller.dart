import 'package:get/get.dart';
import 'package:crm_app/widgets/custom_toast.dart';

import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
// import your DepositService here when ready

class DepositController extends GetxController {
  final FinanceRepository _repo = Get.find<FinanceRepository>();
  // Observable states
  final _isLoading = false.obs;
  final _errorMessage = ''.obs;
  final _successMessage = ''.obs;

  // Getters
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  String get successMessage => _successMessage.value;

  // Deposit methods list
  final depositMethod = Rxn<Map<String, dynamic>>(); // store single API object
  final selectedPaymentMethod =
      Rxn<Map<String, dynamic>>(); // currently selected one

  // Transfer-to accounts list (depends on deposit_slug)
  final transferAccounts = <Map<String, dynamic>>[].obs;
  final selectedTransferAccount = Rxn<Map<String, dynamic>>();

  @override
  void onInit() {
    super.onInit();
    // fetchDepositPaymentMethodsLists(); // automatically call when controller is created
  }

  /// Call deposit API
  Future<void> submitDepositForTopUpDemo(
    Map<String, dynamic> requestData,
  ) async {
    try {
      _setLoading(true);
      _clearError();

      final token = await SecureStorageService.getAuthToken();

      final response = await _repo.topupDemoAccount(
        token: token ?? '',
        payload: requestData,
      );

      if (response.success) {
        Get.back(closeOverlays: true);
        _setLoading(false);
        CustomToastService.showSuccess(
          message:
              response.message ??
              TranslationUtils.tr('deposit_deposited_successfully'),
        );
      } else {
        _setLoading(false);
        CustomToastService.showError(
          message:
              response.message ??
              TranslationUtils.tr('deposit_deposited_error'),
        );
      }
    } catch (e) {
      _setLoading(false);
      CustomToastService.showError(
        message:
            '${TranslationUtils.tr('deposit_controller_error_while_depositing')}: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Set selected payment method and fetch accounts based on deposit_slug
  void setSelectedPaymentMethod(
    Map<String, dynamic> method, {
    String? preselectedAccountNumber,
  }) {
    selectedPaymentMethod.value = method;
    final slug = method['deposit_slug'];
    if (slug != null) {
      fetchAccountsForPaymentMethod(
        slug,
        preselectedAccountNumber: preselectedAccountNumber,
      );
    }
  }

  Future<void> fetchAccountsForPaymentMethod(
    String slug, {
    String? preselectedAccountNumber,
  }) async {
    // Debug: Log preselected account number with detailed info
    print('========================================');
    print('DepositController: fetchAccountsForPaymentMethod CALLED');
    print('DepositController: slug: $slug');
    print(
      'DepositController: preselectedAccountNumber: "$preselectedAccountNumber"',
    );
    print(
      'DepositController: preselectedAccountNumber is null: ${preselectedAccountNumber == null}',
    );
    print(
      'DepositController: preselectedAccountNumber isEmpty: ${preselectedAccountNumber?.isEmpty ?? true}',
    );
    print(
      'DepositController: preselectedAccountNumber type: ${preselectedAccountNumber.runtimeType}',
    );
    print('========================================');

    final token = await SecureStorageService.getAuthToken();
    final response = await _repo.getDepositMethodDetail(
      token: token ?? '',
      slug: slug,
    );

    if (response.success && response.data != null) {
      final root = response.data as Map<String, dynamic>;
      final data = root['data'] as Map<String, dynamic>?; // go inside "data"

      if (data != null) {
        final depositMethod = data['depositMethod'] as Map<String, dynamic>?;
        if (depositMethod != null) {
          this.depositMethod.value = depositMethod; // store single object
          selectedPaymentMethod.value =
              depositMethod; // set currently selected method
        }

        // Extract MT5 accounts
        List<Map<String, dynamic>> mt5Accounts =
            List<Map<String, dynamic>>.from(data['userMT5Accounts'] ?? []);

        // Add wallet entry if available
        final wallet = data['wallet'];
        if (wallet != null) {
          final walletAccount = {
            "id": wallet['id'],
            "user_id": wallet['user_id'],
            "account_type": "Wallet",
            "master_group_id": "Wallet",
            "meta_account_number": wallet['wallet_id'],
            "mt5_name": "Wallet",
            "balance": wallet['wallet_balance'],
            "currency": "USD",
          };
          mt5Accounts.add(walletAccount);
        }

        // Assign to observable
        transferAccounts.assignAll(mt5Accounts);

        // Debug: Log all available account numbers
        print('DepositController: Available accounts from API:');
        for (var i = 0; i < mt5Accounts.length; i++) {
          final account = mt5Accounts[i];
          final accountNumber =
              account['meta_account_number']?.toString() ?? 'null';
          print(
            '  [$i] Account Number: $accountNumber (type: ${account['meta_account_number'].runtimeType})',
          );
        }

        // Select account based on preselectedAccountNumber or default to first
        if (mt5Accounts.isNotEmpty) {
          if (preselectedAccountNumber != null &&
              preselectedAccountNumber.isNotEmpty) {
            // Normalize preselected account number
            final normalizedPreselected =
                preselectedAccountNumber.toString().trim();
            print(
              'DepositController: Looking for account matching: "$normalizedPreselected"',
            );

            // Try to find the preselected account with normalized comparison
            Map<String, dynamic>? matchingAccount;
            try {
              // Find all matching accounts with detailed logging
              print(
                'DepositController: Starting to search through ${mt5Accounts.length} accounts...',
              );
              final matchingAccounts =
                  mt5Accounts.where((account) {
                    final accountNumber = account['meta_account_number'];
                    if (accountNumber == null) {
                      print(
                        'DepositController: Account has null meta_account_number',
                      );
                      return false;
                    }

                    // Normalize both sides for comparison
                    final normalizedAccount = accountNumber.toString().trim();
                    final normalizedPreselectedTrimmed =
                        normalizedPreselected.trim();

                    // Log each comparison attempt
                    print(
                      'DepositController: Comparing list account "$normalizedAccount" (${accountNumber.runtimeType}) with preselected "$normalizedPreselectedTrimmed"',
                    );

                    // Try multiple comparison methods
                    final isExactMatch =
                        normalizedAccount == normalizedPreselectedTrimmed;

                    final accountInt = int.tryParse(normalizedAccount);
                    final preselectedInt = int.tryParse(
                      normalizedPreselectedTrimmed,
                    );
                    final isIntMatch =
                        accountInt != null &&
                        preselectedInt != null &&
                        accountInt == preselectedInt;

                    final isMatch = isExactMatch || isIntMatch;

                    if (isMatch) {
                      print(
                        'DepositController: ✅ MATCH FOUND! Account "$normalizedAccount" matches preselected "$normalizedPreselectedTrimmed"',
                      );
                    } else {
                      print(
                        'DepositController: ❌ No match - "$normalizedAccount" != "$normalizedPreselectedTrimmed" (exact: $isExactMatch, int: $isIntMatch)',
                      );
                    }

                    return isMatch;
                  }).toList();

              if (matchingAccounts.isNotEmpty) {
                matchingAccount = matchingAccounts.first;
                final matchedAccountNumber =
                    matchingAccount['meta_account_number']?.toString().trim() ??
                    '';
                print(
                  'DepositController: ✅ Successfully matched preselected account: $matchedAccountNumber',
                );
                print(
                  'DepositController: Found ${matchingAccounts.length} matching account(s), using first match',
                );
              } else {
                // No match found, use first account
                matchingAccount = mt5Accounts.first;
                final firstAccountNumber =
                    matchingAccount['meta_account_number']?.toString().trim() ??
                    '';
                print(
                  'DepositController: No match found for "$normalizedPreselected"',
                );
                print(
                  'DepositController: Available account numbers were: ${mt5Accounts.map((a) => a['meta_account_number']?.toString().trim()).join(", ")}',
                );
                print(
                  'DepositController: Falling back to first account: $firstAccountNumber',
                );
              }
            } catch (e) {
              print('DepositController: Error during account matching: $e');
              matchingAccount = mt5Accounts.first;
            }

            // Set the selected account
            selectedTransferAccount.value = matchingAccount;
            print(
              'DepositController: ✅ Set selectedTransferAccount.value to account: ${matchingAccount['meta_account_number']?.toString().trim()}',
            );
          } else {
            // Auto-select first account
            print(
              'DepositController: No preselected account number provided, selecting first account',
            );
            selectedTransferAccount.value = mt5Accounts.first;
          }

          // Debug: Log final selected account
          final selectedAccountNumber =
              selectedTransferAccount.value?['meta_account_number']
                  ?.toString() ??
              'null';
          print(
            'DepositController: Final selected account: $selectedAccountNumber',
          );
        }
      }
    } else {
      transferAccounts.clear();
      Get.back(closeOverlays: true);
      CustomToastService.showError(message: response.message ?? "");
    }
  }

  // Helpers
  void _setLoading(bool loading) {
    _isLoading.value = loading;
  }

  void _clearError() {
    _errorMessage.value = '';
  }

  void clearMessages() {
    _errorMessage.value = '';
    _successMessage.value = '';
  }
}
