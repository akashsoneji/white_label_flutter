import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:get/get.dart';

class CopyTradingDepositScreen extends StatelessWidget {
  const CopyTradingDepositScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Deposit',
          style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.w600),
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
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
            // Note Banner
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFB800),
                    ),
                    child: Icon(
                      Icons.priority_high_rounded,
                      color: AppColors.whiteColor,
                      size: 16.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Please note',
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'You need at least 25 USD to start a new investment.',
                          style: AppTextStyles.subheading.copyWith(
                            color: AppColors.textGrey,
                            fontSize: 14.sp,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32.h),
            Text(
              'Payment Method',
              style: AppTextStyles.label.copyWith(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),

            // Payment Methods List
            _PaymentItem(
              label: 'Tether (TRC20)',
              onTap: () => Get.toNamed('/copy-trading-payment-methods'),
            ),
            _PaymentItem(
              label: 'Tether (ERC20)',
              onTap: () => Get.toNamed('/copy-trading-payment-methods'),
            ),
            _PaymentItem(
              label: 'Dogecoin',
              onTap: () => Get.toNamed('/copy-trading-payment-methods'),
            ),
            _PaymentItem(
              label: 'Litecoin',
              onTap: () => Get.toNamed('/copy-trading-payment-methods'),
            ),
            _PaymentItem(
              label: 'Skrill',
              onTap: () => Get.toNamed('/copy-trading-payment-methods'),
            ),
            _PaymentItem(
              label: 'Neteller',
              onTap: () => Get.toNamed('/copy-trading-payment-methods'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PaymentItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textGrey.withOpacity(0.7),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16.r,
            color: Colors.grey.withOpacity(0.3),
          ),
          onTap: onTap,
        ),
        Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
      ],
    );
  }
}
