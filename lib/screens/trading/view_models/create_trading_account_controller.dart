import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart' show CustomToastService;
import 'package:crm_app/widgets/congratulations_dialog.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';

class CreateTradingAccountController extends GetxController {
  var selectedAccountType = '${FlavorConfig.instance.appName} Demo'.obs;
  var depositAmount = '500.00'.obs;
  var tradingPassword = ''.obs;
  var investorPassword = ''.obs;
  var isLoading = false.obs;
  var showTradingPassword = false.obs;
  var showInvestorPassword = true.obs;
  var accountType = 'Demo'.obs; // 'Real' or 'Demo'
  var leverage = ''.obs; // Store selected leverage
  var groupId = 0.obs; // Store selected groupId

  final depositAmountController = TextEditingController();
  final tradingPasswordController = TextEditingController();
  final investorPasswordController = TextEditingController();
  final currencyController = TextEditingController();
  final accounts = ['MT5 Demo', '${FlavorConfig.instance.appName} Demo'];
  final selected = 'MT5 Demo'.obs; // default selected

  /// Two random digits (00–99), regenerated when master password is cleared.
  String _investorRandomSuffix = '';

  // Account type options for dropdown
  final List<String> accountOptions = [
    '${FlavorConfig.instance.appName} Demo',
    'MT5 Demo',
    '${FlavorConfig.instance.appName} Live',
    'MT5 Real',
  ];

  @override
  void onInit() {
    super.onInit();
    // Set default values
    depositAmountController.text = '500.00';
    currencyController.text = 'USD';
  }

  void setAccountType(String type) {
    accountType.value = type;
    // Update default account selection based on type
    if (type == 'Live') {
      selectedAccountType.value = '${FlavorConfig.instance.appName} Live';
    } else {
      selectedAccountType.value = '${FlavorConfig.instance.appName} Demo';
    }
  }

  void setLeverage(String leverageValue) {
    leverage.value = leverageValue;
  }

  void setgroupId(int groupIdValue) {
    groupId.value = groupIdValue;
  }

  void selectAccountType(String account) {
    selectedAccountType.value = account;
    // Update account type based on selection
    if (account.contains('Demo')) {
      accountType.value = 'Demo';
    } else {
      accountType.value = 'Live';
    }
  }

  void toggleTradingPasswordVisibility() {
    showTradingPassword.value = !showTradingPassword.value;
  }

  void toggleInvestorPasswordVisibility() {
    showInvestorPassword.value = !showInvestorPassword.value;
  }

  void updateDepositAmount(String value) {
    depositAmount.value = value;
  }

  void updateTradingPassword(String value) {
    tradingPassword.value = value;
    _syncInvestorFromMaster();
  }

  String _generateTwoDigitSuffix() {
    final n = Random().nextInt(100);
    return n.toString().padLeft(2, '0');
  }

  void _syncInvestorFromMaster() {
    final master = tradingPasswordController.text;
    if (master.isEmpty) {
      _investorRandomSuffix = '';
      investorPasswordController.text = '';
      investorPassword.value = '';
      return;
    }
    if (_investorRandomSuffix.isEmpty) {
      _investorRandomSuffix = _generateTwoDigitSuffix();
    }
    final inv = master + _investorRandomSuffix;
    investorPasswordController.text = inv;
    investorPassword.value = inv;
  }

  void updateInvestorPassword(String value) {
    investorPassword.value = value;
  }

  Future<void> createAccount() async {
    // Basic validation
    if (depositAmount.value.isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr(
            'create_trading_account_controller_please_enter_deposit_amount',
          ),
          title: TranslationUtils.tr('general_error'),
        );
      }
      return;
    }
    if (investorPassword.value == tradingPassword.value) {
      CustomToastService.showError(
        title: TranslationUtils.tr('close_position_error'),
        message: TranslationUtils.tr('create_trading_account_controller_investor_password_and_trading_password_cannot'),
      );
      return;
    }

    if (tradingPassword.value.isEmpty || tradingPassword.value == 'xxxxxxxxx') {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr('create_trading_account_controller_please_enter_trading_password'),
          title: TranslationUtils.tr('close_position_error'),
        );
      }
      return;
    }

    if (investorPassword.value.isEmpty ||
        investorPassword.value == 'xxxxxxxxx') {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr('create_trading_account_controller_please_enter_investor_password'),
          title: TranslationUtils.tr('close_position_error'),
        );
      }
      return;
    }

    try {
      isLoading.value = true;

      // Get account controller (create if not exists)
      if (!Get.isRegistered<AccountController>()) {
        Get.put<AccountController>(AccountController(), permanent: true);
        print('CreateTradingAccountController: AccountController created');
      }
      final accountController = Get.find<AccountController>();

      // Determine account type and group ID
      String accountType = 'live'; // Default to demo

      // if (selectedAccountType.value.contains('Real')) {
      //   accountType = 'real';
      //   groupId = 2; // Different group ID for real accounts
      // }

      print('Creating MT5 account with:');
      print('Group ID: ${groupId.value}');
      print('Main Password: ${tradingPassword.value}');
      print('Investor Password: ${investorPassword.value}');
      print('Account Type: $accountType');

      // Call the real API
      final accountData = await accountController.createMT5Account(
        groupId: groupId.value,
        mainPassword: tradingPassword.value,
        investorPassword: investorPassword.value,
        leverage: leverage.value.isNotEmpty ? leverage.value : null,
      );

      if (accountData != null) {
        // Show success message
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showSuccess(
            message: TranslationUtils.tr('create_account_success_created'),
            title: TranslationUtils.tr('create_account_success'),
          );
        }

        print('accountData wehn we crete new account plese : $accountData');

        // Show congratulations popup with real account data
        Get.dialog(
          CongratulationsDialog(
            accountNumber:
                accountData['data']['account_number']?.toString() ??
                TranslationUtils.tr('dashboard_new_account_title'),
            serverName: accountData['data']['group_name']?.toString() ?? '-',
            accountType:
                accountData['data']['account_type']?.toString() ?? 'live',
            leverage: accountData['data']['leverage']?.toString() ?? '',
          ),
          barrierDismissible: false,
        );
      } else {
        // Error message is already shown by DashboardController via CustomToastService
        // No need to show duplicate error notification
      }
    } catch (e) {
      print('Error creating account: $e');
      // Error message is already shown by DashboardController via CustomToastService
      // No need to show duplicate error notification
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createDemoAccount() async {
    // Basic validation
    if (depositAmount.value.isEmpty) {
      CustomToastService.showError(
        title: TranslationUtils.tr('close_position_error'),
        message: TranslationUtils.tr('create_trading_account_controller_please_enter_deposit_amount'),
      );
      return;
    }

    if (tradingPassword.value.isEmpty || tradingPassword.value == 'xxxxxxxxx') {
      CustomToastService.showError(
        title: TranslationUtils.tr('close_position_error'),
        message: TranslationUtils.tr('create_trading_account_controller_please_enter_trading_password'),
      );
      return;
    }

    if (investorPassword.value.isEmpty ||
        investorPassword.value == 'xxxxxxxxx') {
      CustomToastService.showError(
        title: TranslationUtils.tr('close_position_error'),
        message: TranslationUtils.tr('create_trading_account_controller_please_enter_investor_password'),
      );
      return;
    }
    if (investorPassword.value == tradingPassword.value) {
      CustomToastService.showError(
        title: TranslationUtils.tr('close_position_error'),
        message: TranslationUtils.tr('create_trading_account_controller_investor_password_and_trading_password_cannot'),
      );
      return;
    }

    try {
      isLoading.value = true;

      // Get account controller (create if not exists)
      if (!Get.isRegistered<AccountController>()) {
        Get.put<AccountController>(AccountController(), permanent: true);
        print('CreateTradingAccountController: AccountController created');
      }
      final accountController = Get.find<AccountController>();

      // Determine account type and group ID
      // String accountType = 'demo'; // Default to demo

      print('Creating MT5 account with:');
      print('Group ID: $groupId');
      print('Main Password: ${tradingPassword.value}');
      print('Investor Password: ${investorPassword.value}');
      print('Account Type: $accountType');

      // Call the real API
      final accountData = await accountController.createMT5Account(
        groupId: null,
        mainPassword: tradingPassword.value,
        investorPassword: investorPassword.value,
        leverage: leverage.value.isNotEmpty ? leverage.value : null,
      );

      if (accountData != null) {
        // Show success message
        CustomToastService.showSuccess(
          title: TranslationUtils.tr('create_account_success'),
          message: TranslationUtils.tr('create_account_success_created'),
        );

        // // Show congratulations popup with real account data
        // Get.dialog(
        //   CongratulationsDialog(
        //     accountNumber:
        //         accountData['account_number']?.toString() ?? 'New Account',
        //     serverName: accountData['group_name']?.toString() ?? '-',
        //     accountType: accountData['account_type']?.toString() ?? 'demo',
        //     leverage: accountData['leverage']?.toString() ?? '',
        //   ),
        //   barrierDismissible: false,
        // );

        Get.back(closeOverlays: true);
        Get.until((route) => route.isFirst);
      } else {
        // Show error message
        CustomToastService.showError(
          title: TranslationUtils.tr('close_position_error'),
          message:
              accountController.errorMessage.isNotEmpty
                  ? accountController.errorMessage
                  : TranslationUtils.tr('create_trading_account_controller_failed_to_create_account_please_try'),
        );
      }
    } catch (e) {
      print('Error creating account: $e');
      CustomToastService.showError(
        title: TranslationUtils.tr('close_position_error'),
        message: TranslationUtils.tr('create_trading_account_controller_failed_to_create_account_please_try'),
      );
    } finally {
      isLoading.value = false;
    }
    // try {
    //   isLoading.value = true;

    //   // Simulate API call
    //   await Future.delayed(Duration(seconds: 2));

    //   // Show congratulations popup
    //   Get.back(closeOverlays: true);
    //   Get.until((route) => route.isFirst);
    // } catch (e) {
    //   Get.snackbar(
    //     'Error',
    //     'Failed to create account. Please try again.',
    //     snackPosition: SnackPosition.BOTTOM,
    //     backgroundColor: Colors.red,
    //     colorText: AppColors.whiteColor,
    //   );
    // } finally {
    //   isLoading.value = false;
    // }
  }

  @override
  void onClose() {
    depositAmountController.dispose();
    tradingPasswordController.dispose();
    investorPasswordController.dispose();
    super.onClose();
  }
}
