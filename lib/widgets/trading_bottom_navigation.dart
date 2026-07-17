import 'dart:ui'; // 👈 Needed for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/app_svg_icon.dart';

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
    // Baazex is a child of Vantage — it must use Vantage's UI tree (4-tab
    // bottom nav with Prices as the default Chart tab) so the design stays
    // consistent across the child brands.
    final isVantage = FlavorConfig.usesVantageUi();

    if (isVantage) {
      return Container(
          height: 56.h,
          margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 18.h),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(32.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: AppColors.isDarkMode ? 0.18 : 0.15),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildVantageNavItem(
                  0,
                  "assets/svg/bottom_navigation/trend-up.svg",
                  "assets/svg/bottom_navigation/trend-up_bold.svg",
                  'Prices',
                ),
                _buildVantageNavItem(
                  1,
                  "assets/svg/bottom_navigation/chart.svg",
                  "assets/svg/bottom_navigation/chart_bold.svg",
                  'Chart',
                ),
                _buildVantageNavItem(
                  2,
                  "assets/svg/bottom_navigation/candle.svg",
                  "assets/svg/bottom_navigation/candle_bold.svg",
                  'Markets',
                ),
                _buildVantageNavItem(
                  3,
                  "assets/svg/bottom_navigation/wallet.svg",
                  "assets/svg/bottom_navigation/wallet_bold.svg",
                  'Accounts',
                ),
                _buildVantageNavItem(
                  4,
                  "assets/svg/copy_trading/bottom_navigation/dashboard.svg",
                  "assets/svg/copy_trading/bottom_navigation/dashboard_bold.svg",
                  'Dashboard',
                ),
              ],
            ),
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

  Color get _vantageSelectedCapsuleColor =>
      AppColors.primary.withValues(alpha: 0.10);

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
                color: isSelected
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
                      height: (isSelected ? _selectedIconSize : _unselectedIconSize).h,
                      width: (isSelected ? _selectedIconSize : _unselectedIconSize).w,
                      color: isSelected ? AppColors.primary : AppColors.textGrey,
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
                          fontWeight: FontWeight.w700,
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

  Widget _buildVantageNavItem(int index, String icon, String iconBold, String label) {
    final isSelected = currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: _tabCapsuleRadius,
        onTap: () => onTap(index),
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: _tabCapsuleHeight.h,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 12.w : 8.w,
            vertical: 4.h,
          ),
          decoration: BoxDecoration(
            color: isSelected ? _vantageSelectedCapsuleColor : Colors.transparent,
            borderRadius: _tabCapsuleRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSvgIcon(
                assetPath: isSelected ? iconBold : icon,
                height: _selectedIconSize.h,
                width: _selectedIconSize.w,
                color: isSelected ? AppColors.primary : AppColors.textGrey,
              ),
              if (isSelected) ...[
                SizedBox(width: 6.w),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subheading.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}
