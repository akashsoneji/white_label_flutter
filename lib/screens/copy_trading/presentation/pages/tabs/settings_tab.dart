import 'package:crm_app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_settings_controller.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:crm_app/flavor_config.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Put or find the controller
    final controller = Get.put(CopyTradingSettingsController());

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,

        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Settings',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: SvgPicture.asset(
            'assets/svg/menu.svg',
            width: 24.w,
            height: 24.h,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Logo Section
            Container(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              width: double.infinity,
              color: AppColors.primary.withOpacity(0.02),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandLogo(
                    source: FlavorConfig.svgLogoAsset,
                    height: 55.h,
                    width: 105.w,
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    children: [
                      SizedBox(height: 15.h),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            _MenuItem(
              svgIconPath: 'assets/svg/bottom_navigation/wallet.svg',
              label: 'Wallet',

              onTap: () => Get.toNamed('/copy-trading-wallet'),
            ),
            _MenuItem(
              svgIconPath: 'assets/svg/deshboard/money-recive.svg',
              label: 'Deposit',
              onTap: () => Get.toNamed(AppPages.FINANCE),
            ),
            _MenuItem(
              svgIconPath: 'assets/svg/ib_dashboard/copy.svg',
              label: 'Copier Area',
              onTap: () {},
            ),
            _MenuItem(
              svgIconPath: 'assets/svg/chart_screen_icon/bell_icon.svg',
              label: 'Notification',
              onTap: () {},
            ),
            _MenuItem(
              svgIconPath: 'assets/svg/copy_trading/setting/trade_win.svg',
              label: 'Trade and Win',
              onTap: () {},
            ),
            _MenuItem(
              svgIconPath: 'assets/svg/copy_trading/setting/share.svg',
              label: 'Invite a Friend',
              onTap: () => Get.toNamed('/copy-trading-invite-friend'),
            ),
            _MenuItem(
              svgIconPath: 'assets/svg/bottom_navigation/setting.svg',
              label: 'Settings',
              onTap: () {},
            ),
            _MenuItem(
              svgIconPath: 'assets/svg/more/ib_dashboard/ib-support.svg',
              label: 'Start a live chat',
              onTap: () {},
            ),
            _MenuItem(
              svgIconPath: 'assets/svg/copy_trading/setting/document-text.svg',
              label: 'Terms & Conditions',
              onTap: () {},
            ),

            SizedBox(height: 100.h), // Bottom nav pad
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String svgIconPath;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.svgIconPath,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          visualDensity: VisualDensity(horizontal: -2, vertical: 0),
          contentPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 0),
          leading: Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: SvgPicture.asset(
              svgIconPath,
              width: 24.w,
              height: 24.h,
              colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
            ),
            // Icon(iconData, color: AppColors.primary, size: 24.r),
          ),
          title: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 16.sp,
              color: AppColors.textPrimary,
            ),
          ),
          trailing:
              trailing ??
              Icon(
                Icons.arrow_forward_ios,
                size: 16.r,
                color: AppColors.textGrey,
              ),
          onTap: onTap,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.border.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}
