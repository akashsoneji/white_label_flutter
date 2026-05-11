import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../../../../constants/color.dart';
import '../../../../constants/text_styles.dart';
import '../../../../services/language_service.dart';

class DemoContestScreen extends StatelessWidget {
  const DemoContestScreen({super.key});

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
          languageService.tr('more_demo_contest'),
          style: AppTextStyles.screenTitle,
        ),
        leading: IconButton(
          icon: SvgPicture.asset("assets/svg/trade/arro_back.svg"),
          onPressed: () => Navigator.of(context).pop(),
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
                icon: 'contest-rules',
                label: languageService.tr('contest_rule'),
                onTap: () {
                  // Get.toNamed(AppPages.DEPOSIT);
                },
                showTopBorder: true,
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'join-contest',
                label: languageService.tr('join_contest'),
                onTap: () {
                  // Get.toNamed(AppPages.WITHDRAWAL);
                },
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'demo-leaderboard',
                label: languageService.tr('leaderboard'),
                onTap: () {
                  // Get.toNamed(AppPages.INTERNAL_TRANSFER);
                },
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'my-contest-history',
                label: languageService.tr('my_contest_history'),
                onTap: () {
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
            top: showTopBorder
                ? BorderSide(color: Colors.grey.shade300, width: 1)
                : BorderSide.none,
            bottom: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: SizedBox(
          height: 56.h,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 0,
            leading: SvgPicture.asset(
              'assets/svg/more/demo_contest/$icon.svg',
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