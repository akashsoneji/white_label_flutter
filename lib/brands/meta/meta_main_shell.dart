import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'meta_chart_screen.dart';
import 'meta_history_screen.dart';
import 'meta_settings_screen.dart';
import 'meta_theme.dart';
import 'meta_trade_screen.dart';
import 'meta_new_order_screen.dart';
import 'meta_watchlist_screen.dart';

/// Meta — Main app shell with 5-tab bottom navigation
/// (WatchList, Chart, Trade, History, Settings)
///
/// This is Meta's parent UI design (Facebook-blue inspired). Wires
/// `MetaThemeBus.mode` so the settings screen's dark-mode toggle changes
/// the whole app's theme.
class MetaMainShell extends StatefulWidget {
  const MetaMainShell({super.key});

  @override
  State<MetaMainShell> createState() => _MetaMainShellState();
}

class _MetaMainShellState extends State<MetaMainShell> {
  int _index = 0;

  List<Widget> get _screens => [
    MetaWatchlistScreen(
      // "New Order" row-menu action: push the New Order screen on top.
      // Do NOT switch tabs here — the WatchList tab is still selected
      // underneath, so pressing back returns to the WatchList.
      onOpenNewOrder: (item) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MetaNewOrderScreen(
              symbol: item.symbol,
            ),
          ),
        );
      },
      // "Chart" row-menu action: switch to the Chart tab. The chart
      // screen reads `currentSymbol` from ChartSocketController, which
      // the watchlist already updates before invoking this callback.
      onOpenChart: (item) {
        setState(() => _index = 1);
      },
    ),
    MetaChartScreen(),
    MetaTradeScreen(),
    MetaHistoryScreen(),
    MetaSettingsScreen(
      onNavigateToTab: (i) => setState(() => _index = i),
    ),
  ];

  static const List<_NavTab> _tabs = <_NavTab>[
    _NavTab(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'WatchList'),
    _NavTab(icon: Icons.candlestick_chart_outlined, activeIcon: Icons.candlestick_chart, label: 'Chart'),
    _NavTab(icon: Icons.show_chart, activeIcon: Icons.trending_up, label: 'Trade'),
    _NavTab(icon: Icons.history, activeIcon: Icons.history, label: 'History'),
    _NavTab(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaTheme.bg(context),
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
          color: isDark ? const Color(0xFF242526) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
              width: 1,
            ),
          ),
        ),
        height: 60.h,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = i == _index;
            final tab = _tabs[i];
            final accent = MetaTheme.buyBlue;
            final inactive = isDark ? const Color(0xFF65676B) : const Color(0xFF8A8D91);
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