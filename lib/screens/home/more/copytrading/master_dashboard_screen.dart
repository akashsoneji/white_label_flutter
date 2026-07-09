import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_dashboard_controller.dart';
import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import 'master_dashboard_overview_tab.dart';

/// Master Dashboard screen.
///
/// All legacy blocks (intro + profile + stats grid + my-copy-plans +
/// performance stats + open positions) have been removed. The full screen
/// is now the web-style overview block (`MasterDashboardOverviewTab`):
/// range pills, KPI cards, performance chart, copier health, plan
/// performance, payouts, recent trades, risk alerts.
class MasterDashboardScreen extends StatelessWidget {
  final String masterCode;
  const MasterDashboardScreen({super.key, required this.masterCode});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      CopyTradingMasterDashboardController(masterCode: masterCode),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Master Dashboard',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAll(() => const TradingMainScreen()),
        ),
        actions: [
          IconButton(
            onPressed: () => controller.refreshAll(showLoading: true),
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.stats.value == null &&
            controller.profile.value == null &&
            controller.plans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // MasterDashboardOverviewTab renders a non-scrolling Column, so
        // we provide the scroll + pull-to-refresh here.
        return RefreshIndicator(
          onRefresh: () => controller.refreshAll(showLoading: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: 90.h),
            child: const MasterDashboardOverviewTab(),
          ),
        );
      }),
    );
  }
}
