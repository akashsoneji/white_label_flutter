import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/one_click_trading_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class OneClickTradingDisclaimerScreen extends StatefulWidget {
  const OneClickTradingDisclaimerScreen({super.key});

  @override
  State<OneClickTradingDisclaimerScreen> createState() =>
      _OneClickTradingDisclaimerScreenState();
}

class _OneClickTradingDisclaimerScreenState
    extends State<OneClickTradingDisclaimerScreen> {
  bool _isAccepted = false;
  final OneClickTradingService _oneClickService =
      OneClickTradingService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'One Click Trading',
          style: AppTextStyles.heading.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Disclaimer Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Disclaimer',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            // Disclaimer Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'By clicking "I Accept these Terms and Conditions", you agree to activate One Click Trading mode and are bound by the terms and conditions set forth below.',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'One Click Trading can be activated or deactivated in Chart settings.',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Order submission is a one-step process, triggered by tapping "bid (SELL)" or "ask (BUY)" price buttons on the One Click Trading panel of a chart, or by tapping "Sell, Close, Buy or order placing buttons in the Depth of Market window.',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'THERE WILL BE NO SUBSEQUENT CONFIRMATION PROMPT FOR YOU TO CLICK. YOU WILL NOT BE ABLE TO WITHDRAW OR CHANGE YOUR ORDER ONCE YOU CLICK. UNDER NORMAL MARKET CONDITIONS AND SYSTEM PERFORMANCE, A MARKET ORDER WILL BE PROMPTLY FILLED AFTER SUBMISSION AND YOU WILL HAVE ENTERED INTO A BINDING TRANSACTION.',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'You agree to accept all risks associated with the use of One Click Trading mode.',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
            // Accept Checkbox
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Row(
                children: [
                  Checkbox(
                    value: _isAccepted,
                    onChanged: (value) {
                      setState(() {
                        _isAccepted = value ?? false;
                      });
                    },
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAccepted = !_isAccepted;
                        });
                      },
                      child: Text(
                        'I Accept these Terms and Conditions',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Row(
                children: [
                  // CANCEL Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: AppColors.textPrimary,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'CANCEL',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // OK Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isAccepted
                              ? () async {
                                // Save preference
                                await _oneClickService
                                    .setOneClickTradingEnabled(true);
                                // Navigate back
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isAccepted
                                ? AppColors.primary
                                : Colors.grey.shade300,
                        foregroundColor:
                            _isAccepted ? AppColors.whiteColor : Colors.grey.shade600,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'OK',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 16.sp,
                          color:
                              _isAccepted
                                  ? AppColors.whiteColor
                                  : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
