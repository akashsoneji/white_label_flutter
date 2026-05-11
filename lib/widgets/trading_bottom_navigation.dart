import 'dart:ui'; // 👈 Needed for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/flavor_config.dart';

class TradingBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const TradingBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final isVantage = FlavorConfig.isVantage();

    return Obx(() {
      if (isVantage) {
        return Container(
          height: 54.h,
          margin: EdgeInsets.fromLTRB(40.w, 0, 40.w, 18.h),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(32.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildVantageNavItem(
                0,
                "assets/svg/bottom_navigation/trend-up.svg",
                "assets/svg/bottom_navigation/trend-up_bold.svg",
                'Prices',
              ),
              _buildVantageNavItem(
                1,
                "assets/svg/bottom_navigation/candle.svg",
                "assets/svg/bottom_navigation/candle_bold.svg",
                'Markets',
              ),
              _buildVantageNavItem(
                2,
                "assets/svg/bottom_navigation/wallet.svg",
                "assets/svg/bottom_navigation/wallet_bold.svg",
                'Accounts',
              ),
              _buildVantageNavItem(
                3,
                "assets/svg/bottom_navigation/setting.svg",
                "assets/svg/bottom_navigation/setting_bold.svg",
                'Settings',
              ),
            ],
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  // Glass effect
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(32.r),
                  border: Border.all(
                    color: AppColors.card.withOpacity(0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(
                      0,
                      "assets/svg/bottom_navigation/trend-up.svg",
                      "assets/svg/bottom_navigation/trend-up_bold.svg",
                      languageService.tr('quote_title'),
                    ),
                    _buildNavItem(
                      1,
                      "assets/svg/bottom_navigation/chart.svg",
                      "assets/svg/bottom_navigation/chart_bold.svg",
                      languageService.tr('chart_title'),
                    ),
                    _buildNavItem(
                      2,
                      "assets/svg/bottom_navigation/candle.svg",
                      "assets/svg/bottom_navigation/candle_bold.svg",
                      languageService.tr('trade_title'),
                    ),
                    _buildNavItem(
                      3,
                      "assets/svg/bottom_navigation/wallet.svg",
                      "assets/svg/bottom_navigation/wallet_bold.svg",
                      languageService.tr('dashboard_title'),
                    ),
                    _buildNavItem(
                      4,
                      "assets/svg/bottom_navigation/setting.svg",
                      "assets/svg/bottom_navigation/setting_bold.svg",
                      languageService.tr('more_title'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });

  }

  Widget _buildNavItem(int index, String icon, String iconBold, String label) {
    final isSelected = currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(50.r),
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 26.w : 8.w,
          vertical: 6.h,
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  // ? AppColors.primary.withOpacity(0.14)
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(50.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              isSelected ? iconBold : icon,
              height: isSelected ? 22.h : 18.h,
              width: isSelected ? 22.w : 18.w,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
            ),
            // if (isSelected) ...[
            SizedBox(height: 1.w),
            Text(
              label,
              style: AppTextStyles.subheading.copyWith(
                fontSize: 11.sp,
                color: isSelected ? AppColors.primary : AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            // ],
          ],
        ),
      ),
    );
  }

  Widget _buildVantageNavItem(int index, String icon, String iconBold, String label) {
    final isSelected = currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(50.r),
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12.w : 8.w,
          vertical: 4.h,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(50.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              isSelected ? iconBold : icon,
              height: 20.h,
              width: 20.w,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
            ),
            if (isSelected) ...[
              SizedBox(width: 6.w),
              Text(
                label,
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 11.sp,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
