import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';

class TradeWinBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const TradeWinBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// Same icon as Trade & Win bottom nav "Home" tab (`tw_nav_home`).
  static const IconData homeNavIcon = Icons.card_giftcard_rounded;

  static const _items = [
    _NavItem(
      icon: homeNavIcon,
      labelKey: 'tw_nav_home',
    ),
    _NavItem(
      icon: Icons.emoji_events_rounded,
      labelKey: 'tw_nav_leaderboard',
    ),
    _NavItem(
      icon: Icons.workspace_premium_rounded,
      labelKey: 'tw_nav_my_wins',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(32.r),
                border: Border.all(
                  color: AppColors.icongrey.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(
                  _items.length,
                  (index) => _buildItem(
                    index: index,
                    item: _items[index],
                    label: languageService.tr(_items[index].labelKey),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required _NavItem item,
    required String label,
  }) {
    final selected = currentIndex == index;
    final inactiveColor = AppColors.textGrey;
    final activeColor = AppColors.primary;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(24.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
          decoration: BoxDecoration(
            color:
                selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 40.w : 34.w,
                height: selected ? 40.w : 34.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      selected
                          ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.75),
                            ],
                          )
                          : null,
                  color: selected ? null : AppColors.secondary,
                  border: Border.all(
                    color:
                        selected
                            ? AppColors.primary
                            : AppColors.icongrey.withValues(alpha: 0.2),
                    width: selected ? 0 : 1,
                  ),
                  boxShadow:
                      selected
                          ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                          : null,
                ),
                child: Icon(
                  item.icon,
                  size: selected ? 22.sp : 20.sp,
                  color: selected ? Colors.white : inactiveColor,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 10.sp,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? activeColor : inactiveColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String labelKey;

  const _NavItem({required this.icon, required this.labelKey});
}
