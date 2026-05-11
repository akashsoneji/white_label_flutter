import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class CopyTradingInviteFriendScreen extends StatelessWidget {
  const CopyTradingInviteFriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Invite a Friend',
          style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 24.r,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 24.h),
            // Illustration - Using placeholder icon
            SvgPicture.asset(
              'assets/svg/copy_trading/setting/invite_friend.svg',
              width: 300.w,
              height: 300.h,
            ),

            SizedBox(height: 32.h),
            Text(
              'Share link and get reward',
              style: AppTextStyles.heading.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),

            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 0.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Share Link',
                  style: TextStyle(
                    color: AppColors.whiteColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    height: 24 / 14,
                  ),
                ),
              ),
            ),

            SizedBox(height: 30.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Referral Statistic',
                style: AppTextStyles.label.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 16.h),

            _StatisticItem(
              iconData: Icons.person_outline_rounded,
              label: 'Your clients',
              onTap: () {},
            ),
            _StatisticItem(
              iconData: Icons.show_chart_rounded,
              label: 'Active clients',
              isSvg: true,
              svg: 'assets/svg/copy_trading/setting/diagram.svg',
              onTap: () {},
            ),
            _StatisticItem(
              iconData: Icons.attach_money_rounded,
              isSvg: true,
              svg: 'assets/svg/your_earning.svg',
              label: 'Total profit',
              onTap: () {},
            ),

            SizedBox(height: 48.h),
          ],
        ),
      ),
    );
  }
}

class _StatisticItem extends StatelessWidget {
  final IconData iconData;
  final String label;
  final String svg;
  final bool isSvg;
  final VoidCallback onTap;

  const _StatisticItem({
    required this.iconData,
    required this.label,
    required this.onTap,
    this.isSvg = false,
    this.svg = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity(horizontal: -4, vertical: -4),
          minVerticalPadding: 0,
          leading:
              isSvg
                  ? SvgPicture.asset(
                    svg,
                    width: 24.w,
                    height: 24.h,
                    colorFilter: ColorFilter.mode(
                      AppColors.textGrey,
                      BlendMode.srcIn,
                    ),
                  )
                  : Icon(iconData, color: AppColors.textGrey, size: 24.r),
          title: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textGrey,
            ),
          ),
          onTap: onTap,
        ),
        // Divider(height: 1, color: Colors.grey.withOpacity(0.05)),
      ],
    );
  }
}
