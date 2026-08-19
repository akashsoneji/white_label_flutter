import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/services/language_service.dart';

import 'meta_chart_screen.dart';
import 'meta_history_screen.dart';
import 'meta_settings_screen.dart';
import 'meta_theme.dart';
import 'meta_trade_screen.dart';
import 'meta_new_order_screen.dart';
import 'meta_watchlist_screen.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/chart_webview_prewarmer.dart';

/// Meta — Main app shell with 5-tab bottom navigation
/// (WatchList, Chart, Trade, History, Messages)
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

  @override
  void initState() {
    super.initState();
    // ✅ PERFORMANCE OPTIMIZATION: Pre-warm the chart WebView in background
    if (!FlavorConfig.instance.useNewChart) {
      ChartWebViewPrewarmer.instance.prewarm(symbol: 'EURUSD');
    }
  }

  /// GlobalKey to the History screen's State so we can invoke its
  /// `refreshHistory()` directly when the user lands on the History
  /// tab via any path (bottom-nav tap, hamburger shortcut, deep link).
  final GlobalKey _historyKey = GlobalKey();

  /// Re-fetches history whenever the History tab becomes active. Safe
  /// to call when the History screen is not yet mounted — the
  /// IndexedStack keeps it alive, so this only fires once the screen
  /// has actually been built.
  void _refreshHistoryIfPossible() {
    final state = _historyKey.currentState as dynamic;
    try {
      state?.refreshHistory();
    } catch (_) {
      // Defensive: if the State API ever changes, swallow rather than
      // crash the tab switch.
    }
  }

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
      // Top-left hamburger shortcut: jump straight to the Settings tab
      // (index 4) instead of opening the side drawer.
      onHamburgerTap: () => setState(() => _index = 4),
    ),
    MetaChartScreen(),
    MetaTradeScreen(
      // "Chart" row-menu action on a position: switch the bottom nav
      // to the Chart tab. The trade screen already sets the chart
      // socket's currentSymbol before invoking this.
      onSwitchTab: (i) => setState(() => _index = i),
      // Top-left hamburger shortcut: jump straight to the Settings tab
      // (index 4) instead of opening the side drawer.
      onHamburgerTap: () => setState(() => _index = 4),
    ),
    MetaHistoryScreen(
      key: _historyKey,
      // Top-left hamburger shortcut: jump straight to the Settings tab
      // (index 4) instead of opening the side drawer.
      onHamburgerTap: () => setState(() => _index = 4),
    ),
    MetaSettingsScreen(
      onNavigateToTab: (i) => setState(() => _index = i),
    ),
  ];

  List<_NavTab> get _tabs => <_NavTab>[
    _NavTab(icon: Icons.swap_vert, activeIcon: Icons.swap_vert, label: Get.find<LanguageService>().tr('nav_tab_quotes')),
    _NavTab(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: Get.find<LanguageService>().tr('nav_tab_charts')),
    _NavTab(icon: Icons.show_chart, activeIcon: Icons.trending_up, label: Get.find<LanguageService>().tr('nav_tab_trade')),
    _NavTab(icon: Icons.history, activeIcon: Icons.history, label: Get.find<LanguageService>().tr('nav_tab_history')),
    _NavTab(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: Get.find<LanguageService>().tr('nav_tab_settings')),
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

  void _onTabTap(int i) {
    setState(() => _index = i);
    // Re-fetch history every time the user lands on the History tab
    // via the bottom nav. The IndexedStack keeps the History screen
    // alive across tab switches, so the GlobalKey's State is always
    // available and `refreshHistory()` always fires the API.
    // Initial mount is handled by `MetaHistoryScreen.initState` itself.
    if (i == 3) {
      _refreshHistoryIfPossible();
    }
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
        height: 65.h,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = i == _index;
            final tab = _tabs[i];
            final accent = MetaTheme.buyBlue;
            final inactive = isDark ? const Color(0xFF65676B) : const Color(0xFF8A8D91);
            return Expanded(
              child: InkWell(
                onTap: () => _onTabTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Icon(
                        selected ? tab.activeIcon : tab.icon,
                        size: 22.sp,
                        color: selected ? accent : inactive,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      tab.label,
                      style: AppTextStyles.bodyText.copyWith(
                        color: selected ? accent : inactive,
                        fontSize: 10.sp,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
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
