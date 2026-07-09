import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/labeled_app_text_field.dart';

class AddInvestmentScreen extends StatefulWidget {
  final String traderName;
  const AddInvestmentScreen({super.key, required this.traderName});

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: '3.01',
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
        title: Text('Add Investment', style: AppTextStyles.heading),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          children: [
            _buildHeaderCard(),
            SizedBox(height: 16.h),
            LabeledAppTextField(
              label: 'Investing Amount',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                SingleDecimalTextFormatter(),
              ],
              prefixIcon: Padding(
                padding: EdgeInsets.all(0.w),
                child: Text(
                  r'$',
                  style: TextStyle(
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
                '${_amountController.text} USD',
                style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
              ),
            ),
            SizedBox(height: 20.h),
            _buildImportantNote(),
            SizedBox(height: 16.h),
            Row(
              children: [
                SvgPicture.asset(
                  'assets/svg/copy_trading/investment/coin.svg',
                  height: 16,
                  width: 13,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Your investment with this master trader will total \$50.01',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
                ),
              ],
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
              'Confirm',
              style: TextStyle(
                fontSize: 14.sp,
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                'Important',
                style: TextStyle(
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
            'Enter the amount you want to add to your current investment with this master trader.',
            style: TextStyle(
              fontFamily: 'Roboto',
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
}
