import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/home/dashboard_screen.dart';

/// Shows the [DashboardScreen] inside a modal bottom sheet
/// with maximum height capped at 70% of the screen height.
void showDashboardBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = AppColors.isDarkMode;
      final cardBg = isDark ? const Color(0xFF1E1E2C) : AppColors.cardBackground;
      final maxH = MediaQuery.of(ctx).size.height * 0.70;

      return Container(
        height: maxH,
        constraints: BoxConstraints(
          maxHeight: maxH,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24.r),
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black26,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20.r),
                ),
                child: DashboardScreen(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
