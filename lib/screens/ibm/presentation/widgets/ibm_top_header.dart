import 'package:crm_app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';

class IbmTopHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int? badgeCount;
  final bool showBackButton;
  final List<Widget>? extraActions;
  final bool hideWallet;

  const IbmTopHeader({
    super.key,
    required this.title,
    this.badgeCount,
    this.showBackButton = true,
    this.extraActions,
    this.hideWallet = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(60.h);

  @override
  Widget build(BuildContext context) {
    final IbmController controller = Get.find<IbmController>();

    return AppBar(
      backgroundColor: AppColors.isDarkMode ? AppColors.card : AppColors.whiteColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? GestureDetector(
              onTap: () => Get.back(),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18.w,
                color: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            )
          : Builder(
              builder: (ctx) =>  IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAllNamed(AppPages.TRADING),
        ),
            ),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.heading.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          if (badgeCount != null && badgeCount! > 0) ...[
            SizedBox(width: 4.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (extraActions != null) ...extraActions!,
        if (!hideWallet)
        // Wallet Balance Chip
        Obx(() {
          final balance = controller.walletData['balance'] ?? '0.00';
          return Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.isDarkMode ? Colors.grey[900] : AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.isDarkMode ? Colors.grey[800]! : AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 14.w,
                    color: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '\$$balance',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1.h),
        child: Container(color: AppColors.divider, height: 1.h),
      ),
    );
  }
}
