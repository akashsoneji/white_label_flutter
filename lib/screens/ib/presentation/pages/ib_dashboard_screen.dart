import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import '../../../../constants/color.dart';
import '../../../../constants/text_styles.dart';
import '../../../../routes/app_pages.dart';
import '../../../../services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class IbDashboardScreen extends StatelessWidget {
  const IbDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: Text(
          languageService.tr('general_finance'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppBackButton(onPressed: ()=> Navigator.of(context).pop(),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MenuItem(
                icon: 'overview',
                label: languageService.tr('general_overview'),
                onTap: () {
                  // Get.toNamed(AppPages.DEPOSIT);
                },
                showTopBorder: true,
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'referral-link',
                label: languageService.tr('referral_link'),
                onTap: () {
                  // Get.toNamed(AppPages.WITHDRAWAL);
                },
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'my-clients',
                label: languageService.tr('my_clients'),
                onTap: () {
                  // Get.toNamed(AppPages.INTERNAL_TRANSFER);
                },
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'commisson-history',
                label: languageService.tr('commisson_history'),
                onTap: () {
                  Get.toNamed(AppPages.WALLET);
                  // Get.toNamed(AppPages.TRANSACTION_HISTORY);
                },
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'payout-request',
                label: languageService.tr('payout_request'),
                onTap: () {
                  Get.toNamed(AppPages.WALLET);
                  // Get.toNamed(AppPages.TRANSACTION_HISTORY);
                },
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'marketing-tools',
                label: languageService.tr('marketing_tools'),
                onTap: () {
                  Get.toNamed(AppPages.WALLET);
                  // Get.toNamed(AppPages.TRANSACTION_HISTORY);
                },
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'ib-support',
                label: languageService.tr('ib_support'),
                onTap: () {
                  Get.toNamed(AppPages.WALLET);
                  // Get.toNamed(AppPages.TRANSACTION_HISTORY);
                },
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool showTopBorder;
  final Color color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.showTopBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top:
                showTopBorder
                    ? BorderSide(color: Colors.grey.shade300, width: 1)
                    : BorderSide.none,
            bottom:
                BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: SizedBox(
          height: 56.h,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 0,
            leading: SvgPicture.asset(
              'assets/svg/more/ib_dashboard/$icon.svg',
              height: 24.h,
              width: 24.w,
              color: AppColors.primary,
            ),
            title: Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                fontFamily: 'Roboto',
                color: color,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_sharp,
              size: 14.h,
              color: AppColors.icongrey,
            ),
            onTap: onTap,
            minLeadingWidth: 10,
            horizontalTitleGap: 8.w,
          ),
        ),
      ),
    );
  }
}

