import 'package:crm_app/screens/bonus/presentation/pages/scratch_card_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/home/more/widgets/more_menu_widgets.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/enabled_modules_service.dart';
import 'package:crm_app/utils/demo_contest_menu.dart';
import 'package:crm_app/widgets/trade_win_bottom_navigation.dart';

class PromotionalScreen extends StatelessWidget {
  const PromotionalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final modulesService = Get.find<EnabledModulesService>();

    return Scaffold(
      backgroundColor: AppColors.tradeWinScaffoldBackground,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.tradeWinScaffoldBackground,
        elevation: 0,
        title: Text(
          languageService.tr('general_promotional'),
          style: AppTextStyles.heading,
        ),
        leading: const AppBackButton(),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 8.h),
          child: Obx(() {
            final modules = modulesService.modules.value;
            final showScratch = modules?.scratchcard ?? false;
            final showTradeWin = modules?.tradewin ?? false;

            final tiles = <Widget>[];
            if (showScratch) {
              tiles.add(
                MoreMenuTile(
                  iconName: 'scratch',
                  showIconBackground: false,
                  label: languageService.tr('general_scratch_card'),
                  onTap: () {
                    Get.to(
                      () => const ScratchCardListScreen(),
                      transition: Transition.rightToLeft,
                      duration: const Duration(milliseconds: 300),
                    );
                  },
                  textColor: AppColors.textPrimary,
                ),
              );
            }
            if (showTradeWin) {
              tiles.add(
                MoreMenuTile(
                  iconData: TradeWinBottomNavigation.homeNavIcon,
                  label: languageService.tr('trade_win'),
                  onTap: () => Get.toNamed(AppPages.TRADE_WIN_MAIN),
                  textColor: AppColors.textPrimary,
                ),
              );
            }

            if (DemoContestMenu.showInPromotion) {
              tiles.add(
                MoreMenuTile(
                  iconAssetPath:
                      'assets/svg/more/demo_contest/join-contest.svg',
                  label: DemoContestMenu.label,
                  onTap: () => Get.toNamed(AppPages.DEMO_CONTEST),
                  textColor: AppColors.textPrimary,
                ),
              );
            }

            // Always show Bonus section
            tiles.add(
              MoreMenuTile(
                iconName: 'bonus',
                label: languageService.tr('more_bonus'),
                onTap: () => Get.toNamed(AppPages.BONUS),
                textColor: AppColors.textPrimary,
              ),
            );

            return MoreMenuCardGroup(children: tiles);
          }),
        ),
      ),
    );
  }
}
