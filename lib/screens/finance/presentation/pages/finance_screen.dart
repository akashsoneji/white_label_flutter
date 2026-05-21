import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/home/more/widgets/more_menu_widgets.dart';
import 'package:crm_app/widgets/app_back_button.dart';

import '../../../../constants/color.dart';
import '../../../../constants/text_styles.dart';
import '../../../../routes/app_pages.dart';
import '../finance_ui_scope.dart';
import '../../../../services/language_service.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        title: Text(
          languageService.tr('general_finance'),
          style: AppTextStyles.screenTitle,
        ),
        leading: const AppBackButton(),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoreMenuCardGroup(
                children: [
                  MoreMenuTile(
                    iconName: 'deposit',
                    label: languageService.tr('general_deposit'),
                    onTap: () {
                      Get.to(
                        () => FinanceUiScope.widgets.paymentMethods(
                          accountNumber: '',
                        ),
                      );
                    },
                    textColor: AppColors.textPrimary,
                  ),
                  MoreMenuTile(
                    iconName: 'withdrawal',
                    label: languageService.tr('general_withdrawal'),
                    onTap: () {
                      Get.toNamed(AppPages.WITHDRAWAL);
                    },
                    textColor: AppColors.textPrimary,
                  ),
                  MoreMenuTile(
                    iconName: 'internal-transfer',
                    label: languageService.tr('internal_transfer'),
                    onTap: () {
                      Get.toNamed(AppPages.INTERNAL_TRANSFER);
                    },
                    textColor: AppColors.textPrimary,
                  ),
                  MoreMenuTile(
                    iconName: 'transaction_history',
                    label: languageService.tr('internal_transfer_history'),
                    onTap: () {
                      Get.toNamed(AppPages.INTERNAL_TRANSFER_HISTORY);
                    },
                    textColor: AppColors.textPrimary,
                  ),
                  MoreMenuTile(
                    iconName: 'wallet',
                    label: languageService.tr('wallet'),
                    onTap: () {
                      Get.toNamed(AppPages.WALLET);
                    },
                    // textColor: AppColors.textPrimary,
                  ),
                  MoreMenuTile(
                    iconName: 'wallet',
                    label: 'Withdrawal Method',
                    onTap: () {
                      Get.toNamed(AppPages.BANK_LIST);
                    },
                    textColor: AppColors.textPrimary,
                  ),
                  MoreMenuTile(
                    iconName: 'clock',
                    label: languageService.tr('transaction_history'),
                    onTap: () {
                      Get.to(
                        () => FinanceUiScope.widgets.transactionHistory(),
                        arguments: {'from': 'finance'},
                      );
                    },
                    textColor: AppColors.textPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
