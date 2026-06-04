import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/copy_trading_bottom_navigation.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_hub_controller.dart';

import 'package:crm_app/screens/copy_trading/presentation/pages/tabs/become_master_tab.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/tabs/my_plans_tab.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/hub/master_dashboard_screen.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/hub/my_copies_screen.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/hub/explore_masters_screen.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/hub/my_investments_screen.dart';

class CopyTradingMainScreen extends StatefulWidget {
  final int? initialIndex;
  const CopyTradingMainScreen({super.key, this.initialIndex});

  @override
  State<CopyTradingMainScreen> createState() => _CopyTradingMainScreenState();
}

class _CopyTradingMainScreenState extends State<CopyTradingMainScreen> {
  late final CopyTradingHubController _hubController;

  @override
  void initState() {
    super.initState();
    _hubController = Get.put(CopyTradingHubController());
    final isMaster =
        _hubController.masterStatus.value ==
        CopyTradingMasterApplicationStatus.approved;
    _hubController.currentTabIndex.value =
        widget.initialIndex ?? (isMaster ? 0 : 1);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_hubController.isLoading.value &&
          _hubController.masterStatus.value ==
              CopyTradingMasterApplicationStatus.none) {
        return Scaffold(
          backgroundColor: AppColors.tradeBackgroundCenterColor,
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final isMaster =
          _hubController.masterStatus.value ==
          CopyTradingMasterApplicationStatus.approved;

      final maxIndex = isMaster ? 4 : 2;
      final activeIndex = _hubController.currentTabIndex.value.clamp(0, maxIndex);

      final List<Widget> tabs =
          isMaster
              ? [
                MasterDashboardScreen(
                  masterCode: _hubController.masterCode.value,
                ),
                MyPlansTab(),
                MyCopiesScreen(),
                ExploreMastersScreen(),
                MyInvestmentsScreen(),
              ]
              : [
                BecomeMasterTab(),
                ExploreMastersScreen(),
                MyInvestmentsScreen(),
              ];

      return Scaffold(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: kBottomNavigationBarHeight,
            ),
            child: IndexedStack(index: activeIndex, children: tabs),
          ),
        ),

        // Floating pill navigation — same pattern as TradingMainScreen
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
        floatingActionButton: CopyTradingBottomNavigation(
          currentIndex: activeIndex,
          onTap: (idx) => _hubController.currentTabIndex.value = idx,
          isMaster: isMaster,
        ),
      );
    });
  }
}
