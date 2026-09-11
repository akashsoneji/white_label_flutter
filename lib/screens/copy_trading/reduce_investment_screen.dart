import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/labeled_app_text_field.dart';
import 'package:crm_app/services/language_service.dart';

class ReduceInvestmentScreen extends StatefulWidget {
  final String traderName;
  const ReduceInvestmentScreen({super.key, required this.traderName});

  @override
  State<ReduceInvestmentScreen> createState() => _ReduceInvestmentScreenState();
}

class _ReduceInvestmentScreenState extends State<ReduceInvestmentScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: '50.00',
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
          TranslationUtils.tr('reduce_investment_screen_reduce_investment'),
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
            LabeledAppTextField(
              label: TranslationUtils.tr(
                'reduce_investment_screen_i_want_to_disinvest',
              ),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.all(0.w),
                child: Text(
                  r'$',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${TranslationUtils.tr('reduce_investment_screen_available_for_withdrawal')} : \$${_amountController.text}',
                style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
              ),
            ),
            SizedBox(height: 16.h),
            _buildImportantNote(),
            SizedBox(height: 20.h),
            _buildInfoRow(
              'assets/svg/copy_trading/investment/coin.svg',
              TranslationUtils.tr(
                'reduce_investment_screen_remaining_investment_total',
              ),
            ),
            SizedBox(height: 12.h),
            _buildInfoRow(
              'assets/svg/copy_trading/investment/percentage.svg',
              TranslationUtils.tr(
                'reduce_investment_screen_bonus_will_be_cancelled',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          bottom: MediaQuery.of(context).padding.bottom + 16.h,
        ),
        child: SizedBox(
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
              TranslationUtils.tr('general_confirm'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.whiteColor,
              ),
            ),
          ),
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

  Widget _buildImportantNote() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackGround,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.rotate(
                angle: 3.14 / 1,
                child: Icon(Icons.info, color: AppColors.warning, size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Text(
                TranslationUtils.tr('add_investment_screen_important'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 22 / 16,
                  letterSpacing: 0.0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            TranslationUtils.tr(
              'add_investment_screen_enter_the_amount_you_want_to',
            ),
            style: AppTextStyles.bodyText.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.icongrey,
              fontSize: 14.0,
              height: 1.2857, // 18/14
              letterSpacing: 0.0,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(icon, width: 13.w, height: 16.h),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
