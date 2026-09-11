import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart';

class CopyTradingInternalTransferScreen extends StatelessWidget {
  const CopyTradingInternalTransferScreen({super.key});

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
          TranslationUtils.tr('internal_transfer'),
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
        padding: EdgeInsets.all(24.r),
        child: Column(
          children: [
            _buildTextField(
              label: TranslationUtils.tr('wallet_transfer_from'),
              value: r'Wallet ($0.00)',
            ),
            SizedBox(height: 20.h),
            _buildTextField(
              label: TranslationUtils.tr('wallet_transfer_to'),
              value: TranslationUtils.tr('create_account_select_account'),
            ),
            SizedBox(height: 20.h),
            _buildTextField(
              label: TranslationUtils.tr('deposit_amount'),
              value: '0.00',
              isNumeric: true,
            ),
            SizedBox(height: 20.h),
            _buildTextField(
              label: TranslationUtils.tr('internal_transfer_screen_comment'),
              value: '',
              maxLines: 3,
            ),

            SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  TranslationUtils.tr('internal_transfer_screen_transfer_now'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.whiteColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    bool isNumeric = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          readOnly: value.isNotEmpty && !isNumeric,
          maxLines: maxLines,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText:
                value.isEmpty
                    ? TranslationUtils.trArgs('common_enter_field', {
                      'field': label,
                    })
                    : value,
            filled: true,
            fillColor: AppColors.border.withValues(alpha: 0.05),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
