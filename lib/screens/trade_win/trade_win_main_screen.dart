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

  final List<Widget> _tabs = const [
    TradeWinHomeTab(),
    TradeWinLeaderboardTab(),
    TradeWinMyWinsTab(),
  ];

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TradeWinController>()) {
      Get.put(TradeWinController());
    }
    _controller = Get.find<TradeWinController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeWinScaffoldBackground,
      body: SafeArea(
        child: Obx(() {
          final index = _controller.mainTabIndex.value.clamp(0, _tabs.length - 1);
          return IndexedStack(index: index, children: _tabs);
        }),
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
