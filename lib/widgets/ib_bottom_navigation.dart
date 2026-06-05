import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

class IbBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const IbBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: AppColors.isDarkMode ? 0.22 : 0.15),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(32.r),
                  border: Border.all(
                    color: AppColors.whiteColor.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(
                      0,
                      "assets/svg/ib_dashboard/dashboard.svg",
                      "assets/svg/ib_dashboard/dashboard_bold.svg",
                      "Dashboard",
                    ),
                    _buildNavItem(
                      1,
                      "assets/svg/ib_dashboard/coin.svg",
                      "assets/svg/ib_dashboard/coin_bold.svg",
                      "Structure",
                    ),
                    _buildNavItem(
                      2,
                      "assets/svg/ib_dashboard/myclient.svg",
                      "assets/svg/ib_dashboard/myclient_bold.svg",
                      "Clients",
                    ),
                    _buildNavItem(
                      3,
                      "assets/svg/ib_dashboard/marketing.svg",
                      "assets/svg/ib_dashboard/marketing_bold.svg",
                      "Requests",
                    ),
                    _buildNavItem(
                      4,
                      "assets/svg/bottom_navigation/setting.svg",
                      "assets/svg/bottom_navigation/setting_bold.svg",
                      "More",
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String icon, String iconbold, String label) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(50.r),
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(50.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                isSelected ? iconbold : icon,
                height: isSelected ? 20.h : 18.h,
                width: isSelected ? 20.w : 18.w,
                color: isSelected ? AppColors.primary : AppColors.textGrey,
              ),
              SizedBox(height: 3.h),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppTextStyles.subheading.copyWith(
                      fontSize: isSelected ? 10.sp : 9.sp,
                      color:
                          isSelected ? AppColors.primary : AppColors.textGrey,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
