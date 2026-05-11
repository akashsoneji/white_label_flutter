import 'package:flutter/material.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/copy_trading_bottom_navigation.dart';

import 'tabs/investment_tab.dart';
import 'tabs/traders_tab.dart';
import 'tabs/clients_tab.dart';
import 'tabs/settings_tab.dart';

class CopyTradingMainScreen extends StatefulWidget {
  final int? initialIndex;
  const CopyTradingMainScreen({super.key, this.initialIndex});

  @override
  State<CopyTradingMainScreen> createState() => _CopyTradingMainScreenState();
}

class _CopyTradingMainScreenState extends State<CopyTradingMainScreen> {
  // ValueNotifier lets us update the tab index without rebuilding the whole tree.
  // ValueListenableBuilder subscribes only the nav bar + IndexedStack to changes.
  late final ValueNotifier<int> _currentIndex = ValueNotifier<int>(
    widget.initialIndex ?? 1,
  ); // Default: Traders tab

  final List<Widget> _tabs = const [
    InvestmentTab(),
    TradersTab(),
    ClientsTab(),
    SettingsTab(),
  ];

  @override
  void dispose() {
    _currentIndex.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    _currentIndex.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      body: SafeArea(
        // ValueListenableBuilder rebuilds only the IndexedStack when tab changes
        child: ValueListenableBuilder<int>(
          valueListenable: _currentIndex,
          builder: (context, index, _) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: kBottomNavigationBarHeight,
              ),
              child: IndexedStack(index: index, children: _tabs),
            );
          },
        ),
      ),

      // Floating pill navigation — same pattern as TradingMainScreen
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _currentIndex,
        builder: (context, index, _) {
          return CopyTradingBottomNavigation(
            currentIndex: index,
            onTap: _onTabChanged,
          );
        },
      ),
    );
  }
}
