import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/services/language_service.dart';

import 'celestial_chart_screen.dart';
import 'celestial_history_screen.dart';
import 'celestial_settings_screen.dart';
import 'celestial_theme.dart';
import 'celestial_trade_screen.dart';
import 'celestial_watchlist_screen.dart';

/// Celestial — Main app shell with 5-tab bottom navigation
/// (WatchList, Chart, Trade, History, Settings)
///
/// This is the new "parent" UI design. Wires `CelThemeController.mode` so the
/// settings screen's dark-mode toggle changes the whole app's theme.
class CelestialMainShell extends StatefulWidget {
  const CelestialMainShell({super.key});

  @override
  State<CelestialMainShell> createState() => _CelestialMainShellState();
}

class _CelestialMainShellState extends State<CelestialMainShell> {
  int _index = 0;

  List<Widget> get _screens => [
    CelestialWatchlistScreen(onSymbolTap: (_) => setState(() => _index = 1)),
    CelestialChartScreen(),
    CelestialTradeScreen(),
    CelestialHistoryScreen(),
    CelestialSettingsScreen(
      onNavigateToTab: (i) => setState(() => _index = i),
    ),
  ];

  List<_NavTab> get _tabs => <_NavTab>[
    _NavTab(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: Get.find<LanguageService>().tr('nav_tab_watchlist')),
    _NavTab(icon: Icons.candlestick_chart_outlined, activeIcon: Icons.candlestick_chart, label: Get.find<LanguageService>().tr('nav_tab_charts')),
    _NavTab(icon: Icons.show_chart, activeIcon: Icons.trending_up, label: Get.find<LanguageService>().tr('nav_tab_trade')),
    _NavTab(icon: Icons.history, activeIcon: Icons.history, label: Get.find<LanguageService>().tr('nav_tab_history')),
    _NavTab(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: Get.find<LanguageService>().tr('nav_tab_settings')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CelTheme.bg(context),
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEF1F5),
              width: 1,
            ),
          ),
        ),
        height: 60.h,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = i == _index;
            final tab = _tabs[i];
            final accent = CelTheme.buyBlue;
            final inactive = isDark ? const Color(0xFF6B7280) : const Color(0xFF9AA5B5);
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _index = i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 28.w,
                      height: 2.5.h,
                      child: selected
                          ? Container(color: accent)
                          : const SizedBox.shrink(),
                    ),
                    SizedBox(height: 4.h),
                    Icon(
                      selected ? tab.activeIcon : tab.icon,
                      size: 22.sp,
                      color: selected ? accent : inactive,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: selected ? accent : inactive,
                        fontSize: 10.sp,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
