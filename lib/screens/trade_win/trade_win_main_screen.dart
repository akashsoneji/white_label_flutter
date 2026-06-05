import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/trade_win/view_models/trade_win_controller.dart';
import 'package:crm_app/widgets/trade_win_bottom_navigation.dart';
import 'package:crm_app/screens/trade_win/tabs/trade_win_home_tab.dart';
import 'package:crm_app/screens/trade_win/tabs/trade_win_leaderboard_tab.dart';
import 'package:crm_app/screens/trade_win/tabs/trade_win_my_wins_tab.dart';
class TradeWinMainScreen extends StatefulWidget {
  const TradeWinMainScreen({super.key});

  @override
  State<TradeWinMainScreen> createState() => _TradeWinMainScreenState();
}

class _TradeWinMainScreenState extends State<TradeWinMainScreen> {
  late final TradeWinController _controller;
  late final PageController _pageController;
  late final Worker _worker;

  final List<Widget> _tabs = const [
    KeepAliveWrapper(child: TradeWinHomeTab()),
    KeepAliveWrapper(child: TradeWinLeaderboardTab()),
    KeepAliveWrapper(child: TradeWinMyWinsTab()),
  ];

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TradeWinController>()) {
      Get.put(TradeWinController());
    }
    _controller = Get.find<TradeWinController>();
    final initialIndex = _controller.mainTabIndex.value.clamp(0, _tabs.length - 1);
    _pageController = PageController(initialPage: initialIndex);
    
    _worker = ever(_controller.mainTabIndex, (int index) {
      if (_pageController.hasClients && _pageController.page?.round() != index) {
        _pageController.jumpToPage(index.clamp(0, _tabs.length - 1));
      }
    });
  }

  @override
  void dispose() {
    _worker.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeWinScaffoldBackground,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (i) => _controller.mainTabIndex.value = i,
          physics: const NeverScrollableScrollPhysics(),
          children: _tabs,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Obx(
        () => TradeWinBottomNavigation(
          currentIndex: _controller.mainTabIndex.value.clamp(0, _tabs.length - 1),
          onTap: (i) => _controller.mainTabIndex.value = i,
        ),
      ),
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

