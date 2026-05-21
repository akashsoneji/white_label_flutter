import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/services/enabled_modules_service.dart';
import 'package:crm_app/routes/app_pages.dart';

import '../../../../constants/color.dart';
import '../../../../constants/text_styles.dart';
import '../../../../services/language_service.dart';

class BonusScreen extends StatelessWidget {
  const BonusScreen({super.key});

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
          languageService.tr('more_bonus'),
          style: AppTextStyles.screenTitle,
        ),
        leading: const AppBackButton(),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 8.h),
          child: Obx(() {
            final modules = Get.find<EnabledModulesService>().modules.value;
            final showTradeWin = modules?.tradewin ?? false;

            final items = <Widget>[
              _MenuItem(
                icon: 'deposit-bonus',
                label: languageService.tr('deposit_bonus'),
                onTap: () {},
                showTopBorder: true,
                color: AppColors.textPrimary,
              ),
            ];

            if (showTradeWin) {
              items.add(
                _MenuItem(
                  icon: 'trade-win',
                  label: languageService.tr('trade_win'),
                  onTap: () => Get.toNamed(AppPages.TRADE_WIN_MAIN),
                  color: AppColors.textPrimary,
                ),
              );
            }

            items.addAll([
              _MenuItem(
                icon: 'tour-offer',
                label: languageService.tr('tour_offer'),
                onTap: () {},
                color: AppColors.textPrimary,
              ),
              _MenuItem(
                icon: 'promo-code',
                label: languageService.tr('promo_code'),
                onTap: () {},
                color: AppColors.textPrimary,
              ),
            ]);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items,
            );
          }),
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
    this.showTopBorder = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 4.w),
        decoration: BoxDecoration(
          border: Border(
            top:
                showTopBorder
                    ? BorderSide(color: AppColors.border, width: 1)
                    : BorderSide.none,
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/svg/more/bonus/$icon.svg',
              width: 24.w,
              height: 24.h,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.subheading.copyWith(color: color),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textGrey, size: 20.sp),
          ],
        ),
      ),
    );
  }
}
