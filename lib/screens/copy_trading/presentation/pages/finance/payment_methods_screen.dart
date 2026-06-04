import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:get/get.dart';

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
              'Payment Methods',
              style: AppTextStyles.heading.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'MT5 5013314, \$100',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        leading: const AppBackButton(),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        children: [
          SizedBox(height: 16.h),
          _PaymentMethodTile(
            label: 'Bitcoin',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.currency_bitcoin_rounded,
            iconColor: Colors.orange,
          ),
          _PaymentMethodTile(
            label: 'Litecoin',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.currency_lira_rounded, // Placeholder for Litecoin
            iconColor: Colors.blue,
          ),
          _PaymentMethodTile(
            label: 'TRC20',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.token_rounded,
            iconColor: Colors.teal,
          ),
          _PaymentMethodTile(
            label: 'Ethereum',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.diamond_rounded, // Placeholder for ETH
            iconColor: Colors.indigo,
          ),
          _PaymentMethodTile(
            label: 'GPay',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: Colors.blue,
          ),
          _PaymentMethodTile(
            label: 'Phone Pe',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.mobile_friendly_rounded,
            iconColor: Colors.purple,
          ),
          _PaymentMethodTile(
            label: 'Paytm',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.payments_rounded,
            iconColor: Colors.blueAccent,
          ),
          _PaymentMethodTile(
            label: 'UPI',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.account_balance_rounded,
            iconColor: Colors.brown,
          ),
          _PaymentMethodTile(
            label: 'Local Exchange',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.currency_exchange_rounded,
            iconColor: Colors.blueGrey,
          ),
          _PaymentMethodTile(
            label: 'Local Bank Transfer',
            sublabel: 'Instant upto 1 hours',
            icon: Icons.account_balance_outlined,
            iconColor: Colors.deepPurple,
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
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
            style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14.r,
            color: Colors.grey.withOpacity(0.5),
          ),
          onTap: () {},
        ),
        Divider(height: 1, color: Colors.grey.withOpacity(0.05)),
      ],
    );
  }
}
