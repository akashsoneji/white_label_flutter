import 'dart:async';


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/rtl_wrapper.dart';
import 'package:crm_app/widgets/exit_confirmation_wrapper.dart';
import '../../widgets/trading_bottom_navigation.dart';
import 'instruments_screen.dart';
import 'chart_screen.dart';
import 'chart_tab_host.dart';
import 'more/more_screen.dart';
import 'trade_screen.dart';
import 'dashboard_screen.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/flavor_config.dart';
import '../../services/one_click_trading_service.dart';
import '../../services/app_status/app_status_service.dart';
import '../../services/symbol_selection_service.dart';

class TradingMainScreen extends StatefulWidget {
  const TradingMainScreen({super.key});

  @override
  State<TradingMainScreen> createState() => _TradingMainScreenState();
}

class _TradingMainScreenState extends State<TradingMainScreen> {
  int _currentIndex = 0;
  int _preChartIndex = 0;
  late List<Widget> _screens;
  late final bool _isVantage;
  late PageController _pageController;

  // Get the instruments controller
  final InstrumentsController instrumentsController =
      Get.find<InstrumentsController>();

  void _openChartScreenVantage(String symbol) {
    try {
      ChartScreen.setSelectedSymbol(symbol);
      // Track whether the chart was opened via the Chart tab (index 1)
      // vs. the watchlist on Prices (index 0). On pop, we only redirect
      // to Prices if the user was on the Chart tab AND didn't already
      // navigate elsewhere via a tab callback — otherwise leave them on
      // whatever tab the user (or callback) chose.
      final cameFromChartTab = _currentIndex == 1;
      // `_userNavigatedAwayFromChart` flips when onNavigateToTab or
      // onNavigateToTrade fires, so the .then() handler below knows to
      // skip its Prices-redirect (the callback already chose a tab).
      bool userNavigatedAwayFromChart = false;
      Get.to(
        () => ChartScreen(
          onNavigateToTrade: (tabIndex) {
            userNavigatedAwayFromChart = true;
            _switchToTradeTab(tabIndex ?? 0);
            // Pop the chart AFTER tab switch so the PageView is up-to-date.
            // (Calling Get.back() before _switchToTradeTab can briefly
            // expose the transparent Chart tab host on slow frames.)
            Get.back();
          },
          onNavigateToTab: (index) {
            userNavigatedAwayFromChart = true;
            _onTabChanged(index);
            // Pop the chart AFTER tab switch.
            Get.back();
          },
        ),
      )?.then((_) {
        if (cameFromChartTab && !userNavigatedAwayFromChart) {
          // Pop landed us back on the transparent Chart tab host —
          // bounce to the previous screen instead of Prices (0).
          _onTabChanged(_preChartIndex);
        }
      });
    } catch (e) {
      print('🚨 TradingMainScreen: Error opening chart screen: $e');
    }
  }

  void _switchToTradeTab(int tabIndex) {
    // Vantage 5-tab layout: Trade is at index 2 (Chart shifted in at 1).
    final tradeIndex = _isVantage ? 2 : 2;
    _onTabChanged(tradeIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<TradingController>()) {
        final tradingController = Get.find<TradingController>();
        tradingController.setSelectedTab(tabIndex);
      }
    });
  }

  // Tenax/default: switch to chart tab and set symbol.
  void _switchToChartTab(String symbol) {
    try {
      _onTabChanged(1);
      ChartScreen.setSelectedSymbol(symbol);
    } catch (e) {
      print('🚨 TradingMainScreen: Error switching to chart tab: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _isVantage = FlavorConfig.isVantage();
    
    // ✅ FIX: Check for initial tab index from navigation arguments
    // This allows navigating directly to a specific tab (e.g., dashboard at index 3)
    final arguments = Get.arguments;
    if (arguments != null && arguments is int) {
      // If argument is a valid tab index, set it (vantage: 0-4, default: 0-4)
      final maxIndex = _isVantage ? 4 : 4;
      if (arguments >= 0 && arguments <= maxIndex) {
        _currentIndex = arguments;
        print('TradingMainScreen: Initial tab set to index $arguments');
      }
    }
    
    _pageController = PageController(initialPage: _currentIndex);

    if (_isVantage) {
      // Vantage 5-tab layout (as of 2026-07-09):
      //   0: Prices    → InstrumentsScreen (watchlist)
      //   1: Chart     → ChartTabHost (auto-pushes ChartScreen → VantageChartLayout)
      //   2: Markets   → TradeScreen
      //   3: Accounts  → DashboardScreen
      //   4: Settings  → MoreScreen
      //
      // The Chart tab pushes a full-screen route on top of the PageView,
      // so the bottom nav is naturally hidden while chart is open —
      // matching the existing watchlist → chart flow.
      _screens = [
        KeepAliveWrapper(child: InstrumentsScreen(onNavigateToChart: _openChartScreenVantage)),
        // Chart tab: transparent host. The actual ChartScreen →
        // VantageChartLayout push is driven from `_onTabChanged` when the
        // user navigates to index 1 (via the post-frame callback there).
        // The pushed route sits on top of the PageView so the bottom nav
        // is naturally hidden while chart is open.
        const KeepAliveWrapper(child: ChartTabHost()),
        KeepAliveWrapper(child: TradeScreen(onNavigateToChart: _openChartScreenVantage)),
        KeepAliveWrapper(
          child: DashboardScreen(
            onNavigateToTab: (index) {
              _onTabChanged(index);
            },
          ),
        ),
        const KeepAliveWrapper(child: MoreScreen()),
      ];
    } else {
      // Non-Vantage (5-tab legacy): keep as-is.
      _screens = [
        KeepAliveWrapper(child: InstrumentsScreen(onNavigateToChart: _switchToChartTab)),
        KeepAliveWrapper(
          child: ChartScreen(
            onNavigateToTrade: (tabIndex) {
              _switchToTradeTab(tabIndex ?? 0);
            },
            onNavigateToTab: (index) {
              _onTabChanged(index);
            },
          ),
        ),
        KeepAliveWrapper(child: TradeScreen(onNavigateToChart: _switchToChartTab)),
        KeepAliveWrapper(
          child: DashboardScreen(
            onNavigateToTab: (index) {
              _onTabChanged(index);
            },
          ),
        ),
        const KeepAliveWrapper(child: MoreScreen()),
      ];
    }

    // ✅ WebSocket connections now auto-start and stay active across all screens
    // No need to manually start/stop on tab changes

    // ✅ Safety net: Ensure one-click trading is enabled by default
    _ensureOneClickTradingEnabled();

    // Ensure app update check runs after the main UI is mounted.
    // This covers the "already logged-in" flow where AuthCheckScreen may navigate
    // away quickly and a dialog can be dismissed by route changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (Get.isRegistered<AppStatusService>()) {
          unawaited(Get.find<AppStatusService>().checkAppStatus());
        }
      } catch (_) {}
    });
    
    // ✅ If initial tab is dashboard, refresh accounts (vantage index 3, default index 3)
    final dashboardIndex = _isVantage ? 3 : 3;
    if (_currentIndex == dashboardIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (Get.isRegistered<DashboardController>()) {
            final dashboardController = Get.find<DashboardController>();
            dashboardController.refreshMT5Accounts(force: true);
            dashboardController.unsubscribeAndResubscribe();
          }
        } catch (e) {
          print('Error refreshing dashboard on initial load: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Ensure one-click trading is enabled (safety net)
  Future<void> _ensureOneClickTradingEnabled() async {
    try {
      final isEnabled = await OneClickTradingService.instance.isOneClickTradingEnabled();
      if (!isEnabled) {
        await OneClickTradingService.instance.setOneClickTradingEnabled(true);
        print('TradingMainScreen: One-click trading enabled by default');
      }
    } catch (e) {
      print('TradingMainScreen: Error ensuring one-click trading is enabled: $e');
    }
  }

  // Handle tab changes and manage WebSocket connections
  void _onTabChanged(int index) {
    if (_currentIndex == index) return;

    final int previousIndex = _currentIndex;

    setState(() {
      _currentIndex = index;
      if (index == 1 && previousIndex != 1) {
        _preChartIndex = previousIndex;
      }
    });

    if (_pageController.hasClients && _pageController.page?.round() != index) {
      _pageController.jumpToPage(index);
    }

    // Vantage 5-tab layout: Prices(0), Chart(1), Markets(2), Accounts(3), Settings(4).
    final tradeIndex = _isVantage ? 2 : 2;
    final dashboardIndex = _isVantage ? 3 : 3;
    final moreIndex = _isVantage ? 4 : 4;

    // Vantage UI brands (pipze, baazex, gtxprime, kantara, skyriss,
    // telifox, tenax, vantage): the Chart tab (index 1) is a transparent
    // host that needs to auto-push the chart route when the user lands on
    // it. _screens is built once in initState, so ChartTabHost.isSelected
    // captures the *initial* index (usually 0) and never sees the new
    // value when the user taps the Chart tab. We trigger the push here so
    // it works regardless of the initial tab.
    //
    // We avoid double-pushing if the chart route is already on top by
    // checking Get.currentRoute for an existing ChartScreen entry.
    if (_isVantage && index == 1 && previousIndex != 1) {
      // Defer to post-frame so the PageView transition completes before
      // we push (avoids race with the PageView animation).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Only push if no ChartScreen route is already on the stack.
        final currentRoute = Get.currentRoute;
        // Get.currentRoute returns the route's name (or '/' when none);
        // the ChartScreen route appears here when it's been pushed.
        if (currentRoute.contains('ChartScreen')) return;
        // Resolve the initial symbol. If SymbolSelectionService hasn't
        // been registered yet (cold start edge case), fall back to XAUUSD
        // — ChartScreen will hydrate from instruments data once loaded.
        String initialSymbol = 'XAUUSD';
        if (Get.isRegistered<SymbolSelectionService>()) {
          final svc = Get.find<SymbolSelectionService>();
          if (svc.currentSymbol.isNotEmpty) initialSymbol = svc.currentSymbol;
        }
        _openChartScreenVantage(initialSymbol);
      });
    }

    // Reset to Market tab when switching to Trade screen via bottom navigation
    if (index == tradeIndex && previousIndex != tradeIndex) {
      // User manually switched to Trade screen from another screen via bottom nav
      // Reset to Market tab (default behavior)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.isRegistered<TradingController>()) {
          final tradingController = Get.find<TradingController>();
          tradingController.setSelectedTab(0); // Reset to Market tab (index 0)
        }
      });
    }
    // If previousIndex == 2, we're already on Trade screen, so don't override the tab

    // Dashboard tab: avoid force refresh on every switch (reduces API/WS churn).
    if (index == dashboardIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (Get.isRegistered<AppStatusService>()) {
            unawaited(Get.find<AppStatusService>().checkAppStatus());
          }
        } catch (e) {
          print('Error checking app status on dashboard tab: $e');
        }
      });
    }

    // Refresh More screen data when More tab is tapped
    if (index == moreIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (Get.isRegistered<MoreController>()) {
            Get.find<MoreController>().loadMoreScreenData();
          }
        } catch (e) {
          print('Error refreshing More screen data: $e');
        }
      });
    }

    // ✅ REMOVED: Don't stop/start WebSockets on screen change
    // All WebSocket connections (market watch, open positions, pending orders, account)
    // should remain active across all screens for instant data availability
  }

  // ✅ REMOVED: WebSocket management methods no longer needed
  // All WebSocket connections stay active across all screens

  @override
  Widget build(BuildContext context) {
    return ExitConfirmationWrapper(
      forceExitDialog: true,
      child: RTLWrapper(
        child: Scaffold(
          backgroundColor: AppColors.tradeBackgroundCenterColor,
          // drawer: const GlobalDrawer(),
          body: SafeArea(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onTabChanged,
              physics: const NeverScrollableScrollPhysics(),
              children: _screens,
            ),
          ),

          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
          floatingActionButton: TradingBottomNavigation(
            currentIndex: _currentIndex,
            onTap: (index) {
              _onTabChanged(index);
            },
          ),
        ),
      ),
    );
  }
}

// Placeholder screen for other trading sections
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return RTLWrapper(
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.construction, size: 64.h, color: AppColors.textGrey),
                SizedBox(height: 16.h),
                Text(
                  title,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  TranslationUtils.tr('common_coming_soon'),
                  style: AppTextStyles.subheading.copyWith(
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
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

