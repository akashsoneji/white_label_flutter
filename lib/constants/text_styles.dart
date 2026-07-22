import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';

class AppTextStyles {
  // Screen Title Style
  static TextStyle get screenTitle => TextStyle(
    fontSize: 18.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Heading Style
  static TextStyle get heading => TextStyle(
    fontSize: 18.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
  );

  // Heading Black Style
  static TextStyle get headingblack => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
  );

  // Center Body Heading Style
  static TextStyle get centerbodyHeading => TextStyle(
    fontSize: 22.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
  );

  // Subheading Style
  static TextStyle get subheading => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Label Style
  static TextStyle get label => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Input Style
  static TextStyle get input => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Link Style
  static TextStyle get link => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.underline,
    color: AppColors.primary,
  );

  // Black 14 600 Style
  static TextStyle get black14600 => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Button Style (for buttons on dark backgrounds)
  static TextStyle get button => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.whiteColor,  // Theme-aware: white in light, dark in dark
  );

  // Label On Trade Button Style
  static TextStyle get labelOnTradeButton => TextStyle(
    fontSize: 15.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.whiteColor,  // Theme-aware
    letterSpacing: 2.sp,
  );

  // Text Button Style (for text buttons on light backgrounds)
  static TextStyle get textButton => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.primary,
  );

  // Outlined Button Style
  static TextStyle get outlinedButton => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.primary,
  );

  // Card Title Style
  static TextStyle get cardTitle => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Card Subtitle Style
  static TextStyle get cardSubtitle => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textGrey,
  );

  // Body Text Style
  static TextStyle get bodyText => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Caption Style
  static TextStyle get caption => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textGrey,
  );

  // Hint Text Style
  static TextStyle get hint => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.hint,
  );

  // Error Text Style
  static TextStyle get error => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
  );

  // Success Text Style
  static TextStyle get success => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.success,
  );

  // Warning Text Style
  static TextStyle get warning => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.warning,
  );

  // Label On Trade Quantity Style
  static TextStyle get labelOnTradeQuantity => TextStyle(
    fontSize: 10.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.icongrey,
  );

  // Label On Trade Quantity Digit Style
  static TextStyle get labelOnTradeQuantityDigit => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Label On Trade Difference Style
  static TextStyle get labelOnTradeDifference => TextStyle(
    fontSize: 11.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.tradeTextCenterColor,
  );

  // Label On Trade Price Alert Grey Style
  static TextStyle get labelOnTradePriceAlertGrey => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.tradeTextCenterColor,
  );

  // Label On Trade Price Alert Black Style
  static TextStyle get labelOnTradePriceAlertBlack => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Label On Trade Bottom Title Style
  static TextStyle get labelOnTradeBottomTitle => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Label On Chart Pending Order Style
  static TextStyle get labelOnChartPendingOrder => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.tradeTextCenterColor,
  );

  // Label On Chart Pending Order Bold Style
  static TextStyle get labelOnChartPendingOrderBold => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.primary,
  );

  // Grey 10 400 Style
  static TextStyle get grey10400 => TextStyle(
    fontSize: 10.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.icongrey,
  );

  // Grey 11 400 Style
  static TextStyle get grey11400 => TextStyle(
    fontSize: 11.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.icongrey,
  );

  // Black 11 400 Style
  static TextStyle get black11400 => TextStyle(
    fontSize: 11.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Black 14 500 Style
  static TextStyle get black14500 => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Black 16 400 Height 1.37 Style
  static TextStyle get black16400h37 => TextStyle(
    fontSize: 16.sp,
    height: 1.37,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Black 16 400 Height 1.5 Style
  static TextStyle get black16400h1_5 => TextStyle(
    fontSize: 16.sp,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Black 16 600 Style
  static TextStyle get black16600 => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Grey 14 400 Height 1.57 Style
  static TextStyle get grey14400h57 => TextStyle(
    fontSize: 14.sp,
    height: 1.57,
    fontWeight: FontWeight.w400,
    color: AppColors.icongrey,
  );

  // Black 15 400 Height 1.4 Style
  static TextStyle get black15400h9 => TextStyle(
    fontSize: 15.sp,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Black 14 600 Height 1.71 Style
  static TextStyle get black14600h1_71 => TextStyle(
    fontSize: 15.sp,
    height: 1.71,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Black 24 600 Height 1.42 Style
  static TextStyle get black24600h1_42 => TextStyle(
    fontSize: 24.sp,
    height: 1.42,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Scratch Card Gold Text Style — Roboto, 400, 10sp, center, 100% line-height, 0 letter-spacing, gold/yellow
  /*
   AppTextStyles.scratchCardYellow
   font-family: Roboto;
    font-weight: 400;
    font-style: Regular;
    font-size: 10px;
    leading-trim: NONE;
    line-height: 100%;
    letter-spacing: 0px;
    text-align: center;

  */
  static TextStyle get scratchCardYellow => TextStyle(
    fontSize: 10.sp,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.normal,
    color: AppColors.primary,
    textBaseline: TextBaseline.alphabetic,
    letterSpacing: 0,
    height: 1.0,
  );

}
