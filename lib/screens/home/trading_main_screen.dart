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

class TradingMainScreen extends StatefulWidget {
  const TradingMainScreen({super.key});

  @override
  State<TradingMainScreen> createState() => _TradingMainScreenState();
}

class _TradingMainScreenState extends State<TradingMainScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  late final bool _isVantage;

  // Get the instruments controller
  final InstrumentsController instrumentsController =
      Get.find<InstrumentsController>();

  void _openChartScreenVantage(String symbol) {
    try {
      ChartScreen.setSelectedSymbol(symbol);
      Get.toNamed('/chart');
    } catch (e) {
      print('🚨 TradingMainScreen: Error opening chart screen: $e');
    }
  }

  // Tenax/default: switch to chart tab and set symbol.
  void _switchToChartTab(String symbol) {
    try {
      setState(() {
        _currentIndex = 1; // Chart tab index (Tenax/default)
      });
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
      // If argument is a valid tab index, set it (vantage: 0-3, default: 0-4)
      final maxIndex = _isVantage ? 3 : 4;
      if (arguments >= 0 && arguments <= maxIndex) {
        _currentIndex = arguments;
        print('TradingMainScreen: Initial tab set to index $arguments');
      }
    }
    
    if (_isVantage) {
      _screens = [
        InstrumentsScreen(onNavigateToChart: _openChartScreenVantage),
        TradeScreen(onNavigateToChart: _openChartScreenVantage),
        DashboardScreen(
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        const MoreScreen(),
      ];
    } else {
      _screens = [
        InstrumentsScreen(onNavigateToChart: _switchToChartTab),
        ChartScreen(
          onNavigateToTrade: (tabIndex) {
            setState(() {
              _currentIndex = 2; // Trade tab index (Tenax/default)
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final tradingController = Get.find<TradingController>();
              tradingController.setSelectedTab(tabIndex ?? 0);
            });
          },
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        TradeScreen(onNavigateToChart: _switchToChartTab),
        DashboardScreen(
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        const MoreScreen(),
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
    
    // ✅ If initial tab is dashboard, refresh accounts (vantage index 2, default index 3)
    final dashboardIndex = _isVantage ? 2 : 3;
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
    final int previousIndex = _currentIndex;

    setState(() {
      _currentIndex = index;
    });

    final tradeIndex = _isVantage ? 1 : 2;
    final dashboardIndex = _isVantage ? 2 : 3;
    final moreIndex = _isVantage ? 3 : 4;

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
            child: IndexedStack(index: _currentIndex, children: _screens),
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
