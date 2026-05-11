import 'dart:ui'; // For ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';

class CopyTradingBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CopyTradingBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.card,
                borderRadius: BorderRadius.circular(32.r),
                border: Border.all(
                  color: AppColors.card.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(
                    context,
                    0,
                    'assets/svg/copy_trading/bottom_navigation/Investment.svg',
                    'assets/svg/copy_trading/bottom_navigation/Investment_bold.svg',
                    'Investment',
                  ),
                  _buildNavItem(
                    context,
                    1,
                    "assets/svg/copy_trading/bottom_navigation/profile-circle.svg",
                    "assets/svg/copy_trading/bottom_navigation/profile-circle_bold.svg",
                    'Rating',
                  ),
                  _buildNavItem(
                    context,
                    2,
                    "assets/svg/bottom_navigation/candle.svg",
                    "assets/svg/bottom_navigation/candle_bold.svg",
                    'Trade',
                  ),
                  _buildNavItem(
                    context,
                    3,
                    "assets/svg/bottom_navigation/setting.svg",
                    "assets/svg/bottom_navigation/setting_bold.svg",
                    'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    String icon,
    String iconActive,
    String label,
  ) {
    final bool isSelected = currentIndex == index;

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
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(50.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              isSelected ? iconActive : icon,
              height: isSelected ? 22.h : 18.h,
              width: isSelected ? 22.w : 18.w,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              style: AppTextStyles.subheading.copyWith(
                fontSize: 11.sp,
                color: isSelected ? AppColors.primary : AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
