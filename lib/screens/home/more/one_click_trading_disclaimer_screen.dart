import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
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
          TranslationUtils.tr('more_screen_one_click_trading'),
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
                  TranslationUtils.tr('one_click_trading_disclaimer_title'),
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
                      TranslationUtils.tr(
                        'one_click_trading_disclaimer_by_clicking_accept_these_terms_and',
                      ),
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      TranslationUtils.tr(
                        'one_click_trading_disclaimer_one_click_trading_can_be_activated',
                      ),
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      TranslationUtils.tr('one_click_trading_disclaimer_buy'),
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      TranslationUtils.tr(
                        'one_click_trading_disclaimer_no_confirmation_warning',
                      ),
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      TranslationUtils.tr(
                        'one_click_trading_disclaimer_you_agree_to_accept_all_risks',
                      ),
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
                        TranslationUtils.tr(
                          'one_click_trading_disclaimer_accept_these_terms_and_conditions',
                        ),
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
