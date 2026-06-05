import 'dart:ui'; // For ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';

class CopyTradingBottomNavItem {
  final String label;
  final String icon;
  final String iconActive;
  const CopyTradingBottomNavItem({
    required this.label,
    required this.icon,
    required this.iconActive,
  });
}

class CopyTradingBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isMaster;

  const CopyTradingBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isMaster = false,
  });

  static const List<CopyTradingBottomNavItem> _copierItems = [
    CopyTradingBottomNavItem(
      label: 'Become Master',
      icon: "assets/svg/copy_trading/bottom_navigation/become_master.svg",
      iconActive: "assets/svg/copy_trading/bottom_navigation/become_master_bold.svg",
    ),
    CopyTradingBottomNavItem(
      label: 'Explore',
      icon: "assets/svg/copy_trading/bottom_navigation/explore.svg",
      iconActive: "assets/svg/copy_trading/bottom_navigation/explore_bold.svg",
    ),
    CopyTradingBottomNavItem(
      label: 'Investments',
      icon: 'assets/svg/copy_trading/bottom_navigation/investments.svg',
      iconActive:
          'assets/svg/copy_trading/bottom_navigation/investments_bold.svg',
    ),
  ];

  static const List<CopyTradingBottomNavItem> _masterItems = [
    CopyTradingBottomNavItem(
      label: 'Dashboard',
      icon: 'assets/svg/copy_trading/bottom_navigation/dashboard.svg',
      iconActive:
          'assets/svg/copy_trading/bottom_navigation/dashboard_bold.svg',
    ),
    CopyTradingBottomNavItem(
      label: 'My Plans',
      icon: "assets/svg/copy_trading/bottom_navigation/my_plans.svg",
      iconActive: "assets/svg/copy_trading/bottom_navigation/my_plans_bold.svg",
    ),
    CopyTradingBottomNavItem(
      label: 'My Copiers',
      icon: "assets/svg/copy_trading/bottom_navigation/my_copiers.svg",
      iconActive:
          "assets/svg/copy_trading/bottom_navigation/my_copiers_bold.svg",
    ),
    CopyTradingBottomNavItem(
      label: 'Explore',
      icon: "assets/svg/copy_trading/bottom_navigation/explore.svg",
      iconActive: "assets/svg/copy_trading/bottom_navigation/explore_bold.svg",
    ),
    CopyTradingBottomNavItem(
      label: 'Investments',
      icon: 'assets/svg/copy_trading/bottom_navigation/investments.svg',
      iconActive:
          'assets/svg/copy_trading/bottom_navigation/investments_bold.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = isMaster ? _masterItems : _copierItems;

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
                padding: EdgeInsets.symmetric(horizontal: isMaster ? 4.w : 8.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(32.r),
                  border: Border.all(
                    color: AppColors.whiteColor.withOpacity(0.35),
                    width: 1,
                  ),
                ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return _buildNavItem(
                        context,
                        idx,
                        item.icon,
                        item.iconActive,
                        item.label,
                      );
                    }).toList(),
              ),
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
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal:
              isSelected ? (isMaster ? 10.w : 26.w) : (isMaster ? 4.w : 10.w),
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
              height: isSelected ? 20.h : 18.h,
              width: isSelected ? 20.w : 18.w,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subheading.copyWith(
                fontSize: 10.sp,
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
