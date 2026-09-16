import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/home/dashboard_screen.dart';

/// Shows the [DashboardScreen] inside a modal bottom sheet
/// with maximum height capped at 78% of the screen height.
void showDashboardBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) {
      final isDark = AppColors.isDarkMode;
      final cardBg = isDark ? const Color(0xFF161B29) : Colors.white;
      final maxH = MediaQuery.of(ctx).size.height * 0.78;

      return Container(
        height: maxH,
        constraints: BoxConstraints(
          maxHeight: maxH,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28.r),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3854) : AppColors.primary.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Center(
              child: Container(
                width: 48.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3B4769) : Colors.black26,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(22.r),
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
