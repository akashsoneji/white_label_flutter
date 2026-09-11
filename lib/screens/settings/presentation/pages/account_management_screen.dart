import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/account_models.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final AccountController accountController = Get.find<AccountController>();
  late final LanguageService languageService;

  @override
  void initState() {
    super.initState();
    languageService = Get.find<LanguageService>();
    accountController.loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Account Management',
          style: AppTextStyles.label.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: const AppBackButton(),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showAddAccountDialog(context),
          ),
        ],
      ),
      body: Obx(() {
        if (accountController.isLoading) {
          return Center(
            child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
          );
        }

        if (accountController.accounts.isEmpty) {
          return Center(
            child: Text(languageService.tr('account_management_no_accounts')),
          );
        }

        return _buildAccountList(
          accountController.accounts,
          accountController.activeAccount,
        );
      }),
    );
  }

  Widget _buildAccountList(
    List<AccountModel> accounts,
    AccountModel? activeAccount,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final isActive = activeAccount?.id == account.id;

        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          child: ListTile(
            contentPadding: EdgeInsets.all(16.w),
            leading: CircleAvatar(
              backgroundColor:
                  isActive ? AppColors.primary : AppColors.textGrey,
              child: Icon(
                account.type == 'REAL'
                    ? Icons.account_balance
                    : Icons.play_arrow,
                color: AppColors.whiteColor,
              ),
            ),
            title: Text(
              '${account.type} Account',
              style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600, fontSize: 16.sp),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID: ${account.id}',
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 12.sp),
                ),
                Text(
                  'Balance: ${account.currency} ${account.balance.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing:
                isActive
                    ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        'Active',
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.whiteColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                    : PopupMenuButton<String>(
                      onSelected:
                          (value) => _handleAccountAction(value, account),
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 'activate',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    languageService.tr(
                                      'account_management_set_active',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: AppTextStyles.bodyText.copyWith(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
            onTap:
                isActive
                    ? null
                    : () {
                      accountController.setActiveAccount(account.id);
                    },
          ),
        );
      },
    );
  }

  void _handleAccountAction(String action, AccountModel account) {
    switch (action) {
      case 'activate':
        accountController.setActiveAccount(account.id);
        break;
      case 'delete':
        _showDeleteConfirmation(account);
        break;
    }
  }

  void _showDeleteConfirmation(AccountModel account) {
    Get.dialog(
      AlertDialog(
        title: Text(
          languageService.tr('account_management_delete_account_title'),
        ),
        content: Text(
          'Are you sure you want to delete ${account.type} account ${account.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(closeOverlays: true),
            child: Text(languageService.tr('general_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(closeOverlays: true);
              accountController.deleteAccount(account.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              languageService.tr('account_management_delete'),
              style: AppTextStyles.bodyText.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final typeController = TextEditingController();
    final balanceController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text(
          languageService.tr('account_management_add_new_account_title'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Account Type'),
              items:
                  ['REAL', 'DEMO'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
              onChanged: (value) {
                typeController.text = value ?? '';
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: balanceController,
              decoration: const InputDecoration(labelText: 'Initial Balance'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(closeOverlays: true),
            child: Text(languageService.tr('general_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (typeController.text.isNotEmpty &&
                  balanceController.text.isNotEmpty) {
                final newAccount = AccountModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  type: typeController.text,
                  balance: double.tryParse(balanceController.text) ?? 0.0,
                  currency: 'USD',
                  isActive: false,
                  createdAt: DateTime.now(),
                  metadata: {},
                );

                accountController.addAccount(newAccount);
                Get.back(closeOverlays: true);
              }
            },
            child: Text(languageService.tr('account_management_add')),
          ),
        ],
      ),
    );
  }
}
