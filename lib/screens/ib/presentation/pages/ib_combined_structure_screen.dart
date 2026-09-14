import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_structure_screen.dart';
import 'package:crm_app/screens/ib/presentation/pages/my_structure_screen.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class IbCombinedStructureScreen extends StatelessWidget {
  const IbCombinedStructureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.tradeBackgroundCenterColor,
          elevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              "assets/svg/ib_dashboard/home.svg",
              colorFilter: ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => Get.offAllNamed(AppPages.TRADING),
          ),
          // leading: AppSvgBackButton(
          //   onPressed: () => Get.back(closeOverlays: true),
          //   iconWidth: 30.w,
          //   iconHeight: 30.h,
          // ),
          title: Text(
            TranslationUtils.tr('ib_nav_structure'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            labelStyle: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: TranslationUtils.tr('my_structure_screen_my_structure')),
              Tab(text: TranslationUtils.tr('ib_sub_ib_structure')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MyStructureScreen(isEmbedded: true),
            IBStructureScreen(isEmbedded: true),
          ],
        ),
      ),
    );
  }
}
