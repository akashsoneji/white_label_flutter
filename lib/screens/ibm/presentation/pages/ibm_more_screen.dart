import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_marketing_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_reports_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_settings_screen.dart';
import 'package:crm_app/services/language_service.dart';

/// Hub for items that don't get their own bottom-nav tab: Marketing Material,
/// Reports and Partner Settings. Reached from the "More" tab on the bottom
/// navigation.
class IbmMoreScreen extends StatelessWidget {
  const IbmMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final IbmController controller = Get.find<IbmController>();
    final languageService = Get.find<LanguageService>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        appBar: AppBar(
          backgroundColor:
              AppColors.isDarkMode ? AppColors.pureBlack : AppColors.whiteColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (ctx) => IconButton(
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
          title: Text(
            languageService.tr('general_more'),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            Obx(() {
              final balance = controller.walletBalance;
              return Padding(
                padding: EdgeInsetsDirectional.only(end: 16.w),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14.w,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(width: 4.w),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '\$$balance',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48.h),
            child: Container(
              color: AppColors.isDarkMode
                  ? AppColors.pureBlack
                  : AppColors.whiteColor,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: Container(
                height: 36.h,
                decoration: BoxDecoration(
                  color: AppColors.isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF1EEF8),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.whiteColor,
                  unselectedLabelColor: AppColors.textGrey,
                  labelStyle: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: [
                    Tab(text: languageService.tr('ibm_reports')),
                    Tab(
                      text: languageService.tr(
                        'settings_notifications_marketing',
                      ),
                    ),
                    Tab(text: languageService.tr('bottom_navigation_settings')),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            IbmReportsScreen(embedded: true),
            IbmMarketingScreen(embedded: true),
            IbmSettingsScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}