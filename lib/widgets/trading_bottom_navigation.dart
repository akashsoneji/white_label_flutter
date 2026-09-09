import 'dart:ui'; // 👈 Needed for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/app_svg_icon.dart';

import 'package:crm_app/screens/trading/view_models/trading_controller.dart';

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
    final isIquote = FlavorConfig.usesIquoteUi();
    final isVantage = FlavorConfig.usesVantageUi();

    if (isIquote) {
      final isDark = AppColors.isDarkMode;
      final bgColor = AppColors.scaffold;

      return Obx(() {
        final openCount =
            Get.isRegistered<TradingController>()
                ? Get.find<TradingController>().marketPositionsRx.length
                : 0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 6.h,
            bottom: 4.h + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIquoteNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
              _buildIquoteNavItem(
                1,
                Icons.bar_chart_outlined,
                Icons.bar_chart,
                'Markets',
              ),
              _buildIquoteNavItem(
                2,
                Icons.insert_chart_outlined,
                Icons.insert_chart,
                'Charts',
              ),
              _buildIquoteNavItem(
                3,
                Icons.assignment_outlined,
                Icons.assignment,
                'Position',
                badgeCount: openCount,
              ),
              _buildIquoteNavItem(
                4,
                Icons.account_balance_wallet_outlined,
                Icons.account_balance_wallet,
                'Assets',
              ),
            ],
          ),
        );
      });
    }

    if (isVantage) {
      // Solid bottom bar (no bump / no transparent reserved zone → no gray
      // strip above it). Selected tab gets a normal in-bar circle animation.
      // Theme-aware via AppColors.card; safe-area padding handled inline so it
      // sits flush on both Android and iOS.
      final double bottomInset = MediaQuery.of(context).padding.bottom;
      return Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(
                alpha: AppColors.isDarkMode ? 0.30 : 0.10,
              ),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.only(top: 8.h, bottom: 8.h + bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _buildVantageNavItem(
                0,
                "assets/svg/bottom_navigation/trend-up.svg",
                "assets/svg/bottom_navigation/trend-up_bold.svg",
                'Prices',
              ),
            ),
            Expanded(
              child: _buildVantageNavItem(
                1,
                "assets/svg/bottom_navigation/chart.svg",
                "assets/svg/bottom_navigation/chart_bold.svg",
                'Chart',
              ),
            ),
            Expanded(
              child: _buildVantageNavItem(
                2,
                "assets/svg/bottom_navigation/candle.svg",
                "assets/svg/bottom_navigation/candle_bold.svg",
                'Position',
              ),
            ),
            Expanded(
              child: _buildVantageNavItem(
                3,
                "assets/svg/bottom_navigation/wallet.svg",
                "assets/svg/bottom_navigation/wallet_bold.svg",
                'Accounts',
              ),
            ),
            Expanded(
              child: _buildVantageNavItem(
                4,
                "assets/svg/copy_trading/bottom_navigation/dashboard.svg",
                "assets/svg/copy_trading/bottom_navigation/dashboard_bold.svg",
                'Dashboard',
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
        child: Container(
          height: 64.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(
                  alpha: AppColors.isDarkMode ? 0.22 : 0.15,
                ),
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
                height: 64.h,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  // Glass effect
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(32.r),
                  border: Border.all(
                    color: AppColors.card.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildNavItem(
                        0,
                        "assets/svg/bottom_navigation/trend-up.svg",
                        "assets/svg/bottom_navigation/trend-up_bold.svg",
                        languageService.tr('quote_title'),
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        1,
                        "assets/svg/bottom_navigation/chart.svg",
                        "assets/svg/bottom_navigation/chart_bold.svg",
                        languageService.tr('chart_title'),
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        2,
                        "assets/svg/bottom_navigation/candle.svg",
                        "assets/svg/bottom_navigation/candle_bold.svg",
                        languageService.tr('trade_title'),
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        3,
                        "assets/svg/bottom_navigation/wallet.svg",
                        "assets/svg/bottom_navigation/wallet_bold.svg",
                        languageService.tr('dashboard_title'),
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        4,
                        "assets/svg/bottom_navigation/setting.svg",
                        "assets/svg/bottom_navigation/setting_bold.svg",
                        languageService.tr('dashboard_title'),
                      ),
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

  static const double _tabCapsuleHeight = 42;
  static const double _selectedIconSize = 22;
  static const double _unselectedIconSize = 22;

  BorderRadius get _tabCapsuleRadius =>
      BorderRadius.circular((_tabCapsuleHeight / 2).h);

  Widget _buildNavItem(int index, String icon, String iconBold, String label) {
    final isSelected = currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: _tabCapsuleRadius,
        onTap: () => onTap(index),
        splashColor: AppColors.primary.withValues(alpha: 0.22),
        highlightColor: AppColors.primary.withValues(alpha: 0.12),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: _tabCapsuleHeight.h,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 12.w : 8.w,
              ),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                borderRadius: _tabCapsuleRadius,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppSvgIcon(
                      assetPath: isSelected ? iconBold : icon,
                      height:
                          (isSelected ? _selectedIconSize : _unselectedIconSize)
                              .h,
                      width:
                          (isSelected ? _selectedIconSize : _unselectedIconSize)
                              .w,
                      color:
                          isSelected ? AppColors.primary : AppColors.textGrey,
                    ),
                    if (isSelected) ...[
                      SizedBox(width: 8.w),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subheading.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIquoteNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = AppColors.primary;
    final inactiveColor = AppColors.textSecondary;

    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22.r,
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4.h,
                  right: -8.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 14.w,
                      minHeight: 14.h,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$badgeCount',
                      style: AppTextStyles.bodyText.copyWith(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              color: isSelected ? activeColor : inactiveColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400, // Regular font weight
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVantageNavItem(
    int index,
    String icon,
    String iconBold,
    String label,
  ) {
    final isSelected = currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => onTap(index),
      splashColor: AppColors.primary.withValues(alpha: 0.12),
      highlightColor: AppColors.primary.withValues(alpha: 0.06),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selected tab shows a brand circle behind the icon — a normal
          // in-bar animation that stays fully inside the bar (no bump).
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppSvgIcon(
              assetPath: isSelected ? iconBold : icon,
              height: _selectedIconSize.h,
              width: _selectedIconSize.w,
              color: isSelected ? AppColors.whiteColor : AppColors.textGrey,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subheading.copyWith(
              fontSize: 11.sp,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
