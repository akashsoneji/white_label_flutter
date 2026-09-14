import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/labeled_app_text_field.dart';
import 'package:crm_app/services/language_service.dart';

class ChangeProportionScreen extends StatefulWidget {
  final String traderName;
  const ChangeProportionScreen({super.key, required this.traderName});

  @override
  State<ChangeProportionScreen> createState() => _ChangeProportionScreenState();
}

class _ChangeProportionScreenState extends State<ChangeProportionScreen> {
  final TextEditingController _proportionController = TextEditingController(
    text: 'x3',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/trade/arro_back.svg',
            colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          TranslationUtils.tr('change_proportion_screen_change_copy_proportion'),
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          children: [
            _buildHeaderCard(),
            SizedBox(height: 16.h),
            _buildBalanceCard(),
            SizedBox(height: 16.h),
            Text(
              TranslationUtils.tr('change_proportion_screen_copy_proportion'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            LabeledAppTextField(
              label: TranslationUtils.tr('change_proportion_screen_enter_value'),
              controller: _proportionController,
              hintText: TranslationUtils.tr(
                'change_proportion_screen_enter_value',
              ),
            ),
            SizedBox(height: 100.h), // Spacing as per image
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          bottom: MediaQuery.of(context).padding.bottom + 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${TranslationUtils.tr('change_proportion_screen_new_copy_proportion')} : ${_proportionController.text}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  TranslationUtils.tr(
                    'change_proportion_screen_apply_new_proportion',
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.surface),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.0),
        child: Row(
          children: [
            SvgPicture.asset('assets/svg/copy_trading/person_svg.svg'),
            SizedBox(width: 12),
            Text(
              'Prime_traders',
              style: AppTextStyles.bodyText.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.surface),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            TranslationUtils.tr('general_balance'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              SvgPicture.asset(
                'assets/svg/copy_trading/investment/wallet.svg',
                height: 16,
                width: 13,
              ),
              SizedBox(width: 8.w),
              Text(
                TranslationUtils.tr('change_proportion_screen_50_01_usd'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
