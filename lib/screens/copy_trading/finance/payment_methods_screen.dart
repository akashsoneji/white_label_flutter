import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart';

class CopyTradingPaymentMethodsScreen extends StatelessWidget {
  const CopyTradingPaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              TranslationUtils.tr('payment_methods_title'),
              style: AppTextStyles.heading.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'MT5 5013314, \$100',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 24.r,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        children: [
          SizedBox(height: 16.h),
          _PaymentMethodTile(
            label: 'Bitcoin',
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.currency_bitcoin_rounded,
            iconColor: AppColors.warning,
          ),
          _PaymentMethodTile(
            label: 'Litecoin',
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.currency_lira_rounded, // Placeholder for Litecoin
            iconColor: AppColors.blue,
          ),
          _PaymentMethodTile(
            label: 'TRC20',
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.token_rounded,
            iconColor: AppColors.quickActionGreen,
          ),
          _PaymentMethodTile(
            label: 'Ethereum',
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.diamond_rounded, // Placeholder for ETH
            iconColor: AppColors.blue,
          ),
          _PaymentMethodTile(
            label: 'GPay',
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.blue,
          ),
          _PaymentMethodTile(
            label: 'Phone Pe',
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.mobile_friendly_rounded,
            iconColor: AppColors.quickActionPurple,
          ),
          _PaymentMethodTile(
            label: 'Paytm',
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.payments_rounded,
            iconColor: AppColors.blue,
          ),
          _PaymentMethodTile(
            label: 'UPI',
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.account_balance_rounded,
            iconColor: AppColors.warning,
          ),
          _PaymentMethodTile(
            label: TranslationUtils.tr('payment_methods_local_exchange'),
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.currency_exchange_rounded,
            iconColor: AppColors.textGrey,
          ),
          _PaymentMethodTile(
            label: TranslationUtils.tr('payment_methods_local_bank_transfer'),
            sublabel: TranslationUtils.tr('payment_methods_instant_upto_1_hours'),
            icon: Icons.account_balance_outlined,
            iconColor: AppColors.quickActionPurple,
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color iconColor;

  const _PaymentMethodTile({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(vertical: 4.h),
          leading: Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, color: iconColor, size: 24.r),
          ),
          title: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            sublabel,
            style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14.r,
            color: AppColors.textGrey.withValues(alpha: 0.5),
          ),
          onTap: () {},
        ),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.05)),
      ],
    );
  }
}
