//* in sid elike data is not coem sho note visiblefloating profit
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'package:crm_app/widgets/account_header_widget.dart';
import 'package:crm_app/widgets/dashBorder.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/home/edit_order_screen.dart';
import 'package:crm_app/screens/home/close_position_screen.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/utils/date_helper.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/models/trade_history_model.dart';
import 'package:crm_app/utils/svg_color_helper.dart';
import 'package:crm_app/flavor_config.dart';

// Tab-specific metric configuration
class TabMetricConfig {
  final List<String> metricKeys;

  const TabMetricConfig(this.metricKeys);

  static const market = TabMetricConfig([
    'trade_metric_balance',
    'trade_metric_credit',
    'trade_metric_equity',
    'trade_metric_margin',
    'trade_metric_free_margin',
    'trade_metric_margin_level',
  ]);

  static const pending = TabMetricConfig([
    'trade_metric_balance',
    'trade_metric_credit',
    'trade_metric_equity',
    'trade_metric_margin',
    'trade_metric_free_margin',
    'trade_metric_margin_level',
  ]);

  static const history = TabMetricConfig([
    'trade_metric_profit',
    'trade_metric_deposit',
    'trade_metric_withdrawal',
    'trade_metric_swap',
    'trade_metric_commission',
    'trade_metric_balance',
  ]);

  static TabMetricConfig forTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return market;
      case 1:
        return pending;
      case 2:
        return history;
      default:
        return market;
    }
  }
}

class TradeScreen extends StatefulWidget {
  final Function(String)? onNavigateToChart;

  const TradeScreen({super.key, this.onNavigateToChart});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  // Track dismissed positions to prevent Dismissible widget issues
  final Set<String> _dismissedPositions = <String>{};

  // Track expanded cards in Close tab
  final Set<String> _expandedCardIds = <String>{};
  final LanguageService languageService = Get.find<LanguageService>();

  late final Future<Widget> _emptyStateSvgFuture;

  // ScrollController for infinite scroll
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  // ✅ FIX: Track account changes to reinitialize WebSocket connections
  StreamSubscription? _accountChangeSubscription;
  String? _lastAccountNumber;

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket services safely (avoid duplicate registrations)
    _initializeWebSocketServices();

    _emptyStateSvgFuture = SvgColorHelper.loadSvgWithColor(
      assetPath: 'assets/svg/trade/trade_pending_empty.svg',
      targetColor: AppColors.primary,
      colorToReplace: '#5F259E',
      height: 100.h,
      width: 100.w,
    );

    // Initialize ScrollController
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Reset to Market tab (0) when screen is opened
    // But only if tab hasn't been set programmatically (e.g., from pending order placement)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tradingController = Get.find<TradingController>();
      // Only reset to Market tab if we're already on Market tab
      // This allows programmatic navigation (like from pending order) to set the tab first
      // The programmatic navigation will set the tab after this, so we only reset if already on 0
      final currentTab = tradingController.selectedTab;
      if (currentTab == 0) {
        // Already on Market tab, keep it that way (or initialize if unset)
        tradingController.setSelectedTab(0);
      }
      // If currentTab is not 0, it means programmatic navigation already set it, so don't override

      // ✅ CENTRALIZED: Initialize all WebSocket connections for trade screen
      _initializeTradeScreenWebSockets();

      // ✅ FIX: Listen for account changes to reinitialize WebSocket connections
      _listenForAccountChanges();

      // ✅ PERF: Ensure DashboardController WS is initialized once (not every rebuild)
      try {
        if (Get.isRegistered<DashboardController>()) {
          final dashboardController = Get.find<DashboardController>();
          dashboardController.ensureWebSocketInitialized();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Trade Screen: Error ensuring WebSocket initialization: $e');
        }
      }
    });
  }

  /// ✅ FIX: Listen for account changes and reinitialize WebSocket connections
  /// This ensures data is cleared and connections are re-established when account switches
  void _listenForAccountChanges() {
    try {
      final accountController = Get.find<AccountController>();
      final currentAccount = accountController.activeMT5Account;
      _lastAccountNumber = currentAccount?.metaAccountNumber;

      // Cancel old subscription if exists
      _accountChangeSubscription?.cancel();

      // Listen for account changes
      _accountChangeSubscription = accountController.activeMT5AccountRx.listen((
        account,
      ) {
        if (!mounted) return;

        final newAccountNumber = account?.metaAccountNumber;

        // Check if account actually changed
        if (newAccountNumber != null &&
            newAccountNumber != _lastAccountNumber) {
          _lastAccountNumber = newAccountNumber;

          // ✅ FIX: Clear data first, then reinitialize WebSocket connections
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            try {
              // Clear trading data immediately
              if (Get.isRegistered<TradingController>()) {
                final tradingController = Get.find<TradingController>();
                // ✅ FIX: clearAllTradingData() now automatically preserves History data
                // if we're on History tab, so no need to pass preserveHistoryData
                tradingController.clearAllTradingData();
              }

              // Reinitialize WebSocket connections for new account
              _initializeTradeScreenWebSockets();

              // Force UI refresh
              if (mounted) {
                setState(() {});
              }
            } catch (e) {
              if (kDebugMode) {
                print('Trade Screen: Error handling account change: $e');
              }
            }
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Trade Screen: Error setting up account change listener: $e');
      }
    }
  }

  /// ✅ CENTRALIZED: Initialize all WebSocket services for trade screen
  /// This ensures proper initialization order and error handling
  void _initializeWebSocketServices() {
    // Initialize TradingWebSocketService (handles open positions, pending orders, market watch)
    if (!Get.isRegistered<TradingWebSocketService>()) {
      Get.put(TradingWebSocketService(), permanent: true);
    }
    // Initialize AccountWebSocketService (handles account data)
    if (!Get.isRegistered<AccountWebSocketService>()) {
      Get.put(AccountWebSocketService(), permanent: true);
    }
  }

  /// ✅ CENTRALIZED: Initialize all WebSocket connections for trade screen
  /// Pre-connects to both open positions and pending orders endpoints
  /// This ensures instant data when user switches between Market and Pending tabs
  void _initializeTradeScreenWebSockets() {
    try {
      if (Get.isRegistered<TradingWebSocketService>()) {
        final wsService = Get.find<TradingWebSocketService>();
        // Pre-connect to open positions endpoint (Market tab - shows open positions)
        wsService.ensureOpenPositionsConnection();
        // Pre-connect to pending orders endpoint (Pending tab - shows pending orders)
        // Pending orders now use separate WebSocket connection (/ws/po)
        wsService.ensurePendingOrdersConnection();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Trade Screen: Error ensuring WebSocket connections: $e');
      }
    }
  }

  @override
  void dispose() {
    // ✅ FIX: Cancel account change subscription
    _accountChangeSubscription?.cancel();
    _accountChangeSubscription = null;

    // Clear dismissed positions when screen is disposed
    _dismissedPositions.clear();
    // Clear expanded cards when screen is disposed
    _expandedCardIds.clear();
    // Dispose ScrollController
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Handle scroll events for infinite scroll
  void _onScroll() {
    // Check if scroll position is valid
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Debug logging
    final tradingController = Get.find<TradingController>();
    if (tradingController.selectedTab == 2) {
      print(
        '📜 Scroll - current: $currentScroll, max: $maxScroll, hasMore: ${tradingController.hasMoreHistoryPages}',
      );
    }

    // Trigger load when within 200px of the bottom, or if at the bottom
    if (maxScroll > 0 && currentScroll >= maxScroll - 200) {
      _loadMoreIfNeeded();
    } else if (maxScroll == 0 && currentScroll == 0) {
      // If list is not scrollable (fits on screen), check if we should load more
      // This handles the case where there are only 10 items and they fit on screen
      final tradingController = Get.find<TradingController>();
      if (tradingController.selectedTab == 2 &&
          tradingController.hasMoreHistoryPages &&
          !_isLoadingMore &&
          !tradingController.isLoadingHistory) {
        print('📜 List not scrollable but has more pages - triggering load');
        _loadMoreIfNeeded();
      }
    }
  }

  // Load more data if needed (with debouncing)
  void _loadMoreIfNeeded() {
    final tradingController = Get.find<TradingController>();

    // Only load if:
    // 1. We're on the Close tab (tab 2 - trade history)
    // 2. Not already loading (both local flag and controller state)
    // 3. There are more pages available
    if (tradingController.selectedTab == 2 &&
        !_isLoadingMore &&
        !tradingController.isLoadingHistory &&
        tradingController.hasMoreHistoryPages) {
      print(
        '🔄 Triggering load more - hasMorePages: ${tradingController.hasMoreHistoryPages}',
      );
      _isLoadingMore = true;
      tradingController
          .loadNextPage()
          .then((_) {
            if (mounted) {
              _isLoadingMore = false;
              print('✅ Load more completed');
            }
          })
          .catchError((error) {
            if (mounted) {
              _isLoadingMore = false;
              print('❌ Load more error: $error');
            }
          });
    } else {
      if (tradingController.selectedTab == 2) {
        print(
          '⏸️ Not loading more - isLoadingMore: $_isLoadingMore, isLoadingHistory: ${tradingController.isLoadingHistory}, hasMorePages: ${tradingController.hasMoreHistoryPages}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountController = Get.find<AccountController>();
    final tradingController = Get.find<TradingController>();
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      // drawer: const GlobalDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, accountController, tradingController),
                // DashedUnderline(
                //   dashWidth: 10,
                //   dashSpace: 0,
                //   color: AppColors.isDarkMode ? Colors.transparent : AppColors.grey,
                // ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  child: _buildTabs(tradingController),
                ),
                SizedBox(height: 4.h),
                Expanded(
                  child: GetBuilder<TradingController>(
                    builder: (controller) {
                      final positions = controller.getFilteredPositions();
                      final isLoadingHistory = controller.isLoadingHistory;
                      final hasMorePages = controller.hasMoreHistoryPages;

                      final summaryCard = Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 4.h,
                        ),
                        child: GetBuilder<TradingController>(
                          id: 'account_info',
                          builder: (c) => _buildAccountMetrics(c),
                        ),
                      );

                      final floatingSummary = _buildFloatingSummary(
                        tradingController,
                      );

                      return RefreshIndicator(
                        onRefresh: () async {
                          if (controller.selectedTab == 2) {
                            await controller.refreshTradeHistory();
                          }
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            controller.notifyUserScrollActivity();
                            return false;
                          },
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              SliverToBoxAdapter(child: summaryCard),
                              SliverToBoxAdapter(child: floatingSummary),
                              SliverToBoxAdapter(child: SizedBox(height: 8.h)),
                              if (positions.isEmpty && !isLoadingHistory)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(height: 8.h),
                                        Text(
                                          _getEmptyStateMessage(
                                            controller.selectedTab,
                                          ),
                                          style: AppTextStyles.subheading
                                              .copyWith(
                                                color: AppColors.textGrey,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: EdgeInsets.only(
                                    left: 16.w,
                                    right: 16.w,
                                    bottom:
                                        77.h +
                                        MediaQuery.of(context).padding.bottom,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      final position = positions[index];
                                      return RepaintBoundary(
                                        child: GetBuilder<TradingController>(
                                          id: 'position_${position.orderId}',
                                          builder: (innerController) {
                                            final TradePosition? fresh =
                                                innerController.selectedTab == 0
                                                    ? innerController
                                                        .getMarketPositionById(
                                                          position.orderId,
                                                        )
                                                    : (innerController
                                                                .selectedTab ==
                                                            1
                                                        ? innerController
                                                            .getPendingPositionById(
                                                              position.orderId,
                                                            )
                                                        : innerController
                                                            .getClosedPositionById(
                                                              position.orderId,
                                                            ));

                                            return _buildPositionCard(
                                              innerController,
                                              fresh ?? position,
                                            );
                                          },
                                        ),
                                      );
                                    }, childCount: positions.length),
                                  ),
                                ),
                              if (hasMorePages && controller.selectedTab == 2)
                                SliverToBoxAdapter(
                                  child: Builder(
                                    builder: (context) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted &&
                                                !_isLoadingMore &&
                                                !controller.isLoadingHistory) {
                                              _loadMoreIfNeeded();
                                            }
                                          });
                                      return _buildPaginationLoader(controller);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getEmptyStateMessage(int selectedTab) {
    switch (selectedTab) {
      case 0:
        return 'No Open Trade';
      case 1:
        return 'No Pending Order';
      case 2:
        return 'No Trade History';
      default:
        return 'No Open Trade';
    }
  }

  Widget _buildHeader(
    BuildContext context,
    AccountController accountController,
    TradingController tradingController,
  ) {
    // Create the Close All button widget
    final closeAllButton = Obx(() {
      final positions = tradingController.getFilteredPositions();
      // final totalProfitLoss = positions.fold<double>(
      //   0,
      //   (sum, position) => sum + position.profitLoss,
      // );

      return (positions.isNotEmpty)
          ? (tradingController.selectedTab == 0)
              ? Container(
                decoration:
                    FlavorConfig.isVantage()
                        ? BoxDecoration(
                          color: AppColors.whiteColor,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        )
                        : null,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        FlavorConfig.isVantage() ? 12.r : 10.r,
                      ),
                    ),
                    backgroundColor:
                        FlavorConfig.isVantage()
                            ? AppColors.primary
                            : AppColors.cardBackGround,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                  ),
                  onPressed: () {
                    print('🔘 Close All button clicked!');
                    _showClosePositionsBottomSheet(tradingController);
                  },
                  child: Text(
                    languageService.tr('trade_close_all'),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14.sp,
                      fontWeight:
                          FlavorConfig.isVantage()
                              ? FontWeight.w600
                              : FontWeight.w400,
                      color: AppColors.whiteColor,
                    ),
                  ),
                ),
              )
              : SizedBox.shrink()
          : const SizedBox.shrink();
    });

    // ✅ OPTIMIZATION: Use GetBuilder for incremental account updates (faster than Obx)
    return GetBuilder<TradingController>(
      id: 'account_info', // Same ID as account metrics for synchronized updates
      builder: (controller) {
        // ✅ FIX: Observe active account to ensure header updates when account switches
        final activeAccount = accountController.activeMT5Account;

        // Get floating profit for all tabs (Market, Pending, History)
        // ✅ FIX: Only use floatingProfit if accountInfo exists and matches active account
        final accountInfo = controller.accountInfo;
        final double? floatingProfit =
            (accountInfo != null && activeAccount != null)
                ? accountInfo.profit
                : null;

        final isVantage = FlavorConfig.isVantage();

        return AccountHeaderWidget(
          layoutStyle:
              isVantage
                  ? AccountHeaderLayoutStyle.vantageInstruments
                  : AccountHeaderLayoutStyle.defaultLayout,
          padding:
              isVantage
                  ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h)
                  : null,
          showSearchIcon: false,
          rightWidget: closeAllButton,
          floatingProfit: floatingProfit,
        );
      },
    );
  }

  Widget _buildTabs(TradingController tradingController) {
    if (!FlavorConfig.isVantage()) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 0.w),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.grey.withOpacity(0.2),
              width: 1.w,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildTabItem(tradingController, 0, 'Market'),
            _buildTabItem(tradingController, 1, 'Pending'),
            _buildTabItem(tradingController, 2, 'History'),
          ],
        ),
      );
    }

    return Container(
      height: 40.h,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
      ),
      child: Obx(() {
        final selectedIndex = tradingController.selectedTab;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Sliding Pill Background
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment(-1.0 + (selectedIndex * 1.0), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        AppColors.isDarkMode
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.primary,
                    borderRadius: BorderRadius.circular(17.r),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppColors.isDarkMode
                                ? Colors.black.withOpacity(0.1)
                                : AppColors.primary.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tab Buttons
            Row(
              children: [
                _buildTabItem(tradingController, 0, 'Market'),
                _buildTabItem(tradingController, 1, 'Pending'),
                _buildTabItem(tradingController, 2, 'History'),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSegmentTapTarget({
    required VoidCallback onTap,
    required BorderRadius borderRadius,
    required Color splashColor,
    required Color highlightColor,
    required Widget child,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: splashColor,
        highlightColor: highlightColor,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    TradingController tradingController,
    int index,
    String title,
  ) {
    if (!FlavorConfig.isVantage()) {
      return Obx(() {
        final isSelected = tradingController.selectedTab == index;
        final count = _getPositionCount(tradingController, index);

        return Expanded(
          child: _buildSegmentTapTarget(
            onTap: () => tradingController.setSelectedTab(index),
            borderRadius: BorderRadius.circular(8.r),
            splashColor: AppColors.primary.withValues(alpha: 0.18),
            highlightColor: AppColors.primary.withValues(alpha: 0.10),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2.w,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14.sp,
                      height: 1.57,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color:
                          isSelected
                              ? AppColors.textPrimary
                              : AppColors.textGrey,
                    ),
                  ),
                  if (count > 0 && index != 2) ...[
                    SizedBox(width: 4.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        count.toString(),
                        style: AppTextStyles.label.copyWith(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      });
    }

    return Expanded(
      child: _buildSegmentTapTarget(
        onTap: () => tradingController.setSelectedTab(index),
        borderRadius: BorderRadius.circular(17.r),
        splashColor: Colors.white.withValues(alpha: 0.28),
        highlightColor: Colors.white.withValues(alpha: 0.16),
        child: Obx(() {
          final isSelected = tradingController.selectedTab == index;
          final count = _getPositionCount(tradingController, index);

          final badge =
              count > 0 && index != 2
                  ? Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 1.5.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AppColors.isDarkMode
                              ? AppColors.primary.withOpacity(0.15)
                              : (isSelected
                                  ? Colors.white
                                  : AppColors.primary.withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      count.toString(),
                      style: AppTextStyles.label.copyWith(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? AppColors.primary : AppColors.textGrey,
                      ),
                    ),
                  )
                  : const SizedBox.shrink();

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (count > 0 && index != 2)
                  IgnorePointer(
                    child: Opacity(
                      opacity: 0,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4.w),
                        child: badge,
                      ),
                    ),
                  ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 12.sp,
                    height: 1.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textGrey,
                  ),
                ),
                if (count > 0 && index != 2)
                  Padding(padding: EdgeInsets.only(left: 4.w), child: badge),
              ],
            ),
          );
        }),
      ),
    );
  }

  int _getPositionCount(TradingController tradingController, int tabIndex) {
    switch (tabIndex) {
      case 0:
        return tradingController.marketPositions.length;
      case 1:
        return tradingController.pendingPositions.length;
      case 2:
        return tradingController.closedPositions.length;
      default:
        return 0;
    }
  }

  Widget _buildFloatingSummary(TradingController tradingController) {
    return Obx(() {
      // Hide floating summary for Market tab (tab 0) and Pending tab (tab 1)
      // Show only for History tab (tab 2)
      if (tradingController.selectedTab == 0 ||
          tradingController.selectedTab == 1) {
        return SizedBox.shrink();
      }

      final positions = tradingController.getFilteredPositions();
      // Use profit from account websocket instead of calculating manually
      // profit = unrealized P&L across open positions (from account websocket)
      final accountInfo = tradingController.accountInfo;
      final totalProfitLoss = accountInfo?.profit ?? 0.0;
      final isPositive = totalProfitLoss >= 0;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.cardBackGround,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            width: 1,
            // color: isPositive ? AppColors.success : AppColors.error,
            color: AppColors.cardBackGround,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 8.w),
            tradingController.selectedTab == 2
                ? SizedBox.shrink()
                : RichText(
                  text: TextSpan(
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.icongrey, // base/default color
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text:
                            tradingController.selectedTab == 1
                                ? 'Pending orders:\n'
                                : 'Floating profit:\n',
                      ),
                      TextSpan(
                        text:
                            tradingController.selectedTab == 1
                                ? '${positions.length} orders'
                                : '\$${PrecisionHelper.formatPnL(totalProfitLoss)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              tradingController.selectedTab == 1
                                  ? AppColors.textGrey
                                  : (isPositive
                                      ? AppColors.success
                                      : AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
            Spacer(),
            Row(
              children: [
                // Show calendar icon only for Close tab (History)
                if (tradingController.selectedTab == 2)
                  Obx(() {
                    final hasDateFilter = tradingController.hasDateFilter;
                    final filteredCount = tradingController.getFilteredCount();

                    return InkWell(
                      onTap: () => _showFilterBottomSheet(tradingController),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 35,
                            width: 40,
                            decoration: BoxDecoration(
                              color:
                                  hasDateFilter
                                      ? AppColors.primary.withOpacity(0.1)
                                      : AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            margin: EdgeInsets.all(5),
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          // Badge showing count when filter is active
                          if (hasDateFilter)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.whiteColor,
                                    width: 1,
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16.w,
                                  minHeight: 16.h,
                                ),
                                child: Center(
                                  child: Text(
                                    filteredCount.toString(),
                                    style: TextStyle(
                                      color: AppColors.whiteColor,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                Obx(() {
                  final isInstrumentFilterActive =
                      tradingController.selectedInstruments.isNotEmpty;
                  final filteredCount = tradingController.getFilteredCount();

                  return InkWell(
                    onTap: () => _showInstrumentsBottomSheet(tradingController),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 35,
                          width: 40,
                          decoration: BoxDecoration(
                            color:
                                isInstrumentFilterActive
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          margin: EdgeInsets.all(5),
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Transform.rotate(
                            angle: 1.55,
                            child: SvgPicture.asset(
                              "assets/svg/bottom_navigation/candle_bold.svg",
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        // Badge showing count when filter is active
                        if (isInstrumentFilterActive)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.whiteColor,
                                  width: 1,
                                ),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16.w,
                                minHeight: 16.h,
                              ),
                              child: Center(
                                child: Text(
                                  filteredCount.toString(),
                                  style: TextStyle(
                                    color: AppColors.whiteColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                Obx(() {
                  final currentDirection =
                      tradingController.getCurrentDirectionFilter();
                  final isFilterActive = currentDirection != 'All';
                  final filteredCount = tradingController.getFilteredCount();

                  return InkWell(
                    onTap: () => _showDirectionBottomSheet(tradingController),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 35,
                          width: 40,
                          decoration: BoxDecoration(
                            color:
                                isFilterActive
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          margin: EdgeInsets.all(5),
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SvgPicture.asset(
                            "assets/svg/trade/trade_arrow_icon.svg",
                            color:
                                isFilterActive
                                    ? AppColors.primary
                                    : AppColors.primary,
                          ),
                        ),
                        // Badge showing count when filter is active
                        if (isFilterActive)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.whiteColor,
                                  width: 1,
                                ),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16.w,
                                minHeight: 16.h,
                              ),
                              child: Center(
                                child: Text(
                                  filteredCount.toString(),
                                  style: TextStyle(
                                    color: AppColors.whiteColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                // Reset All Filters button — visible only when any filter is active
                Obx(() {
                  final isAnyActive = tradingController.isAnyFilterActive;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder:
                        (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axis: Axis.horizontal,
                            child: child,
                          ),
                        ),
                    child:
                        isAnyActive
                            ? Padding(
                              key: const ValueKey('reset_btn'),
                              padding: EdgeInsets.only(left: 4.w, right: 2.w),
                              child: InkWell(
                                onTap: () async {
                                  await tradingController.resetAllFilters();
                                },
                                borderRadius: BorderRadius.circular(6.r),
                                child: Container(
                                  height: 35,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundLight,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  margin: EdgeInsets.all(5),
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Icon(
                                    Icons.refresh_rounded,
                                    size: 20.w,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                            : const SizedBox.shrink(
                              key: ValueKey('reset_hidden'),
                            ),
                  );
                }),
              ],
            ),
          ],
        ),
      );
    });
  }

  // NOTE: Positions list is now built using slivers in build()
  // so the header + summary cards scroll together with the list.

  Widget _buildPaginationLoader(TradingController tradingController) {
    // Only show loading indicator when loading, otherwise show nothing
    // The infinite scroll will automatically trigger loading
    if (!tradingController.isLoadingHistory) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 16.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.cardBackGround,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 34.h,
            width: 34.w,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loading more history',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Please wait…',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(
    TradingController tradingController,
    TradePosition position,
  ) {
    final isPositive = position.profitLoss >= 0;
    final isCloseTab = tradingController.selectedTab == 2;
    final isBuy = position.action.toLowerCase() == 'buy';
    final displaySymbol = _removeSymbolSuffixForDisplay(position.symbol);

    // Check if position has been dismissed
    if (_dismissedPositions.contains(position.orderId)) {
      return SizedBox.shrink(); // Return empty widget if dismissed
    }

    // Check if order is being cancelled (for pending orders only)
    // This prevents the widget from freezing when order is removed
    if (tradingController.selectedTab == 1) {
      final orderId = int.tryParse(position.orderId);
      if (orderId != null &&
          tradingController.isOrderBeingCancelled(orderId) &&
          !tradingController.hasPendingOrder(orderId)) {
        // Order is being cancelled and no longer in list - hide widget to prevent freeze
        return SizedBox.shrink();
      }
    }

    // If Close tab, return expandable card with tap functionality and history card design
    if (isCloseTab) {
      final isExpanded = _expandedCardIds.contains(position.orderId);
      return SizedBox(
        width: 40.w,
        child: GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedCardIds.remove(position.orderId);
              } else {
                _expandedCardIds.add(position.orderId);
              }
            });
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 10.h),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: AppColors.border.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vertical color indicator on left edge
                Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    color:
                        isPositive && isBuy
                            ? AppColors.green
                            : (!isPositive
                                ? AppColors.warning
                                : Colors.transparent),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.r),
                      bottomLeft: Radius.circular(12.r),
                    ),
                  ),
                ),
                // Card content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card header with history card design
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left side: Symbol, action, volume on first line; price range on second line
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // First line: Symbol, action, volume
                                  Row(
                                    children: [
                                      Text(
                                        '$displaySymbol ',
                                        style: AppTextStyles.heading.copyWith(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${position.action.toLowerCase()} ${position.volume}',
                                        style: AppTextStyles.heading.copyWith(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              (position.action.toLowerCase() ==
                                                      'buy')
                                                  ? AppColors.green
                                                  : AppColors.red,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Second line: Price range
                                  Text(
                                    '${position.entryPrice} -> ${position.currentPrice}',
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 12.sp,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Right side: Timestamp on top, P/L on bottom
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Timestamp
                                Text(
                                  _formatHistoryTimestamp(
                                    position.closeTime.isNotEmpty
                                        ? position.closeTime
                                        : position.time,
                                  ),
                                  style: AppTextStyles.label.copyWith(
                                    fontSize: 12.sp,
                                    color: AppColors.textGrey,
                                  ),
                                ),

                                // P/L (blue for positive, red for negative)
                                Text(
                                  '\$${PrecisionHelper.formatPnL(position.profitLoss)}',
                                  style: AppTextStyles.heading.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isPositive
                                            ? AppColors.green
                                            : AppColors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Expanded content with animation
                        AnimatedSize(
                          duration: Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child:
                              isExpanded
                                  ? _buildExpandedCardContent(position)
                                  : SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Expand icon
                Padding(
                  padding: EdgeInsets.only(top: 8.h, right: 8.w),
                  child: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textGrey,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // For huge lists (450+), Dismissible on every row causes jank due to gesture + layout overhead.
    // We keep the same close flow via tap → bottom sheet; swipe-to-close stays enabled for smaller lists.
    final bool enableSwipeClose =
        tradingController.marketPositions.length < 350 &&
        tradingController.pendingPositions.length < 350;

    final cardChild = GestureDetector(
      onTap: () => _showPositionDetailsBottomSheet(tradingController, position),
      child: Container(
        margin: EdgeInsets.only(bottom: 6.h),
        decoration:
            FlavorConfig.isVantage()
                ? BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.08),
                    width: 1,
                  ),
                )
                : BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildCardContent(tradingController, position, isPositive),
        ),
      ),
    );

    if (!enableSwipeClose) {
      return SizedBox(width: 40.w, child: cardChild);
    }

    return SizedBox(
      width: 40.w,
      child: Dismissible(
        key: Key(position.orderId.toString()),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: 0.4},
        confirmDismiss: (direction) async {
          return await _showClosePositionConfirmation(
            tradingController,
            position,
          );
        },
        onDismissed: (direction) async {
          setState(() {
            _dismissedPositions.add(position.orderId);
          });
        },
        background: Container(
          margin: EdgeInsets.only(bottom: 16.h),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                Icons.close_rounded,
                color: AppColors.whiteColor,
                size: 24.h,
              ),
              SizedBox(width: 8.w),
              Text(
                'Close',
                style: TextStyle(
                  color: AppColors.whiteColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.only(right: 20.w),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.close_rounded,
            color: AppColors.whiteColor,
            size: 24.h,
          ),
        ),
        child: cardChild,
      ),
    );
  }

  Widget _buildCardContent(
    TradingController tradingController,
    TradePosition position,
    bool isPositive,
  ) {
    final isPendingTab = tradingController.selectedTab == 1;
    final displaySymbol = _removeSymbolSuffixForDisplay(position.symbol);
    final isBuy = position.action.toLowerCase() == 'buy';

    // For pending orders, show status instead of P/L
    // For market positions, show P/L
    final rightSideContent =
        isPendingTab
            ? Text(
              'placed',
              style: AppTextStyles.heading.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey,
              ),
            )
            : Text(
              '${PrecisionHelper.formatPnL(position.profitLoss)}',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: isPositive ? AppColors.green : AppColors.red,
              ),
            );

    if (FlavorConfig.isVantage()) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left side: Icon + Symbol/Action
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: (isBuy ? AppColors.green : AppColors.red)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBuy ? Icons.trending_up : Icons.trending_down,
                      size: 14.sp,
                      color: isBuy ? AppColors.green : AppColors.red,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displaySymbol,
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${position.action.toUpperCase()} ${position.volume}',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: isBuy ? AppColors.green : AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Center: Price Range
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Price Range',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 9.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                  Text(
                    '${position.entryPrice} → ${position.currentPrice}',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Right side: P/L
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPendingTab ? 'Status' : 'Profit',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 9.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                  rightSideContent,
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ORIGINAL DESIGN: 2-column Row for other flavors
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  displaySymbol,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '${position.action.toUpperCase()} ${position.volume}',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: isBuy ? AppColors.green : AppColors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              '${position.entryPrice} -> ${position.currentPrice}',
              style: AppTextStyles.label.copyWith(
                fontSize: 12.sp,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
        rightSideContent,
      ],
    );
  }

  String _removeSymbolSuffixForDisplay(String symbol) {
    final dot = symbol.indexOf('.');
    if (dot <= 0) return symbol;
    return symbol.substring(0, dot);
  }

  void _showInstrumentsBottomSheet(TradingController tradingController) {
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: 350.h,
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 8.h),
                  width: 40.w,
                  height: 2.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 10.h),
                // Text(
                //   "Select Instruments",
                //   style: AppTextStyles.label.copyWith(
                //     fontSize: 16.sp,
                //     fontWeight: FontWeight.w500,
                //   ),
                // ),
                Expanded(
                  child:
                      tradingController.availableInstruments.isEmpty
                          ? Center(
                            child: Text(
                              'No Open Trade',
                              style: AppTextStyles.heading,
                            ),
                          )
                          : Obx(() {
                            // Get unique base symbols (without .c suffix) for display
                            final allInstruments =
                                tradingController.availableInstruments;
                            final baseSymbols = <String>{};
                            final symbolMap =
                                <String, Set<String>>{}; // base -> all variants

                            for (final instrument in allInstruments) {
                              final baseSymbol = _getDisplaySymbol(instrument);
                              baseSymbols.add(baseSymbol);
                              symbolMap
                                  .putIfAbsent(baseSymbol, () => <String>{})
                                  .add(instrument);
                            }

                            final sortedSymbols = baseSymbols.toList()..sort();

                            return ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 0.w),
                              itemCount: sortedSymbols.length,
                              itemBuilder: (context, index) {
                                final baseSymbol = sortedSymbols[index];
                                final variants = symbolMap[baseSymbol] ?? {};

                                return Obx(() {
                                  // Check if any variant is selected - wrapped in Obx for reactivity
                                  final isSelected = variants.any(
                                    (variant) => tradingController
                                        .selectedInstruments
                                        .contains(variant),
                                  );

                                  return ListTile(
                                    leading: _buildPositionFlag(
                                      baseSymbol, // Use base symbol for flag
                                      size: 24.h,
                                    ),
                                    title: Text(
                                      baseSymbol,
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    trailing: Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        if (value == true) {
                                          // Add all variants when selecting base symbol
                                          for (final variant in variants) {
                                            tradingController.addInstrument(
                                              variant,
                                            );
                                          }
                                        } else {
                                          // Remove all variants when deselecting base symbol
                                          for (final variant in variants) {
                                            tradingController.removeInstrument(
                                              variant,
                                            );
                                          }
                                        }
                                      },
                                      activeColor:
                                          AppColors.isDarkMode
                                              ? Colors.white
                                              : AppColors.primary,
                                      checkColor:
                                          AppColors.isDarkMode
                                              ? Colors.black
                                              : Colors.white,
                                      side: BorderSide(
                                        color:
                                            AppColors.isDarkMode
                                                ? Colors.white
                                                : AppColors.primary,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          4.r,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      final currentSelected = variants.any(
                                        (variant) => tradingController
                                            .selectedInstruments
                                            .contains(variant),
                                      );
                                      if (currentSelected) {
                                        // Remove all variants
                                        for (final variant in variants) {
                                          tradingController.removeInstrument(
                                            variant,
                                          );
                                        }
                                      } else {
                                        // Add all variants
                                        for (final variant in variants) {
                                          tradingController.addInstrument(
                                            variant,
                                          );
                                        }
                                      }
                                    },
                                    tileColor:
                                        isSelected
                                            ? AppColors.primary.withValues(
                                              alpha: 0.05,
                                            )
                                            : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  );
                                });
                              },
                            );
                          }),
                ),
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      tradingController.availableInstruments.isEmpty
                          ? SizedBox.shrink()
                          : Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Get.back(closeOverlays: true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                minimumSize: Size(double.infinity, 40.h),
                                // Removed maximumSize to avoid constraint conflicts
                              ),
                              child: Text(
                                'Confirm',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(Get.context!).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDirectionBottomSheet(TradingController tradingController) {
    Get.bottomSheet(
      SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(Get.context!).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag indicator
                Container(
                  margin: EdgeInsets.only(top: 10.h, bottom: 8.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Text(
                    languageService.tr('trade_direction'),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.border),
                // Options list
                SafeArea(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    itemCount: ['All', 'Buy', 'Sell'].length,
                    itemBuilder: (context, index) {
                      final direction = ['All', 'Buy', 'Sell'][index];
                      return Obx(() {
                        final currentDirection =
                            tradingController.getCurrentDirectionFilter();
                        final isSelected = currentDirection == direction;
                        return ListTile(
                          title: Text(
                            direction,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 16.sp,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: Transform.scale(
                            scale: 1.3,
                            child: Radio<String>(
                              value: direction,
                              groupValue: currentDirection,
                              onChanged: (value) {
                                if (value != null) {
                                  final tab = tradingController.selectedTab;
                                  if (tab == 1) {
                                    tradingController.setPendingDirection(
                                      value,
                                    );
                                  } else if (tab == 2) {
                                    tradingController.setClosedDirection(value);
                                  } else {
                                    tradingController.setSelectedDirection(
                                      value,
                                    );
                                  }
                                  Get.back(closeOverlays: true);
                                }
                              },
                              activeColor: AppColors.primary,
                              fillColor: WidgetStateProperty.resolveWith<Color>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.primary;
                                  }
                                  return AppColors.isDarkMode
                                      ? Colors.white
                                      : Colors.grey;
                                },
                              ),
                            ),
                          ),
                          onTap: () {
                            final tab = tradingController.selectedTab;
                            if (tab == 1) {
                              tradingController.setPendingDirection(direction);
                            } else if (tab == 2) {
                              tradingController.setClosedDirection(direction);
                            } else {
                              tradingController.setSelectedDirection(direction);
                            }
                            Get.back(closeOverlays: true);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          tileColor:
                              isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : null,
                        );
                      });
                    },
                  ),
                ),
                // SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(TradingController tradingController) {
    // Pre-select the currently active filter; default to 'today' if none is set
    String selectedFilter = tradingController.activeFilterType ?? 'today';
    DateTime? startDate;
    DateTime? endDate;

    // Pre-populate dates based on the selected filter type
    if (selectedFilter != 'custom') {
      final now = DateTime.now().toUtc();
      if (selectedFilter == 'today') {
        startDate = DateTime.utc(now.year, now.month, now.day);
        endDate = DateTime.utc(now.year, now.month, now.day);
      } else if (selectedFilter == 'thisWeek') {
        // Monday of the current ISO week → today
        endDate = DateTime.utc(now.year, now.month, now.day);
        final weekday = now.weekday; // 1=Mon … 7=Sun
        startDate = endDate.subtract(Duration(days: weekday - 1));
      } else if (selectedFilter == 'thisMonth') {
        // 1st of the current month → today
        endDate = DateTime.utc(now.year, now.month, now.day);
        startDate = DateTime.utc(now.year, now.month, 1);
      }
    }

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    margin: EdgeInsets.only(top: 8.h, bottom: 8.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  // Compact Header
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter History',
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 20.w),
                          onPressed: () => Get.back(closeOverlays: true),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Quick Filter Buttons
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickFilterButton(
                            'Today',
                            selectedFilter == 'today',
                            () {
                              setState(() {
                                selectedFilter = 'today';
                                // Use UTC time for date boundaries
                                final now = DateHelper.nowUtc();
                                // Start of today in UTC (00:00:00)
                                startDate = DateTime.utc(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                // End of today in UTC (same day, will be converted to end of day in timestamp)
                                endDate = DateTime.utc(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildQuickFilterButton(
                            'Last Week',
                            selectedFilter == 'thisWeek',
                            () {
                              setState(() {
                                selectedFilter = 'thisWeek';
                                // Monday of current ISO week → today (UTC)
                                final now = DateHelper.nowUtc();
                                endDate = DateTime.utc(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                final weekday = now.weekday; // 1=Mon … 7=Sun
                                startDate = endDate!.subtract(
                                  Duration(days: weekday - 1),
                                );
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildQuickFilterButton(
                            'Last Month',
                            selectedFilter == 'thisMonth',
                            () {
                              setState(() {
                                selectedFilter = 'thisMonth';
                                // 1st of the current month → today (UTC)
                                final now = DateHelper.nowUtc();
                                endDate = DateTime.utc(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                startDate = DateTime.utc(
                                  now.year,
                                  now.month,
                                  1, // 1st day of this month
                                );
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildQuickFilterButton(
                            'Custom',
                            selectedFilter == 'custom',
                            () {
                              setState(() {
                                selectedFilter = 'custom';
                                startDate = null;
                                endDate = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Custom Date Pickers (shown only when Custom is selected)
                  if (selectedFilter == 'custom')
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        children: [
                          // Start Date - Compact
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate ?? DateHelper.nowUtc(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateHelper.nowUtc(),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: AppColors.primary,
                                          onPrimary: AppColors.whiteColor,
                                          surface: AppColors.whiteColor,
                                          onSurface: AppColors.textPrimary,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    startDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 14.h,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      startDate != null
                                          ? AppColors.primary.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppColors.backgroundLight,
                                  border: Border.all(
                                    color:
                                        startDate != null
                                            ? AppColors.primary
                                            : AppColors.border,
                                    width: startDate != null ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Start',
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 11.sp,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      startDate != null
                                          ? '${startDate!.day}/${startDate!.month}/${startDate!.year}'
                                          : 'Select',
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            startDate != null
                                                ? AppColors.primary
                                                : AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          // End Date - Compact
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate ?? DateHelper.nowUtc(),
                                  firstDate: startDate ?? DateTime(2000),
                                  lastDate: DateHelper.nowUtc(),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: AppColors.primary,
                                          onPrimary: AppColors.whiteColor,
                                          surface: AppColors.whiteColor,
                                          onSurface: AppColors.textPrimary,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    endDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 14.h,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      endDate != null
                                          ? AppColors.primary.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppColors.backgroundLight,
                                  border: Border.all(
                                    color:
                                        endDate != null
                                            ? AppColors.primary
                                            : AppColors.border,
                                    width: endDate != null ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'End',
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 11.sp,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      endDate != null
                                          ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
                                          : 'Select',
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            endDate != null
                                                ? AppColors.primary
                                                : AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 20.h),
                  // Buttons Row: Reset All + Apply Filter
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        // Reset All Button
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 40.h,
                            child: OutlinedButton(
                              onPressed: () async {
                                Get.back(closeOverlays: true);
                                await tradingController.resetHistoryFilter();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.border,
                                  width: 1.5,
                                ),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                'Reset All',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Apply Filter Button
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 40.h,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (selectedFilter == 'custom' &&
                                    (startDate == null || endDate == null)) {
                                  CustomToastService.showError(
                                    message:
                                        'Please select both start and end dates',
                                  );
                                  return;
                                }

                                if (selectedFilter == 'custom' &&
                                    endDate!.isBefore(startDate!)) {
                                  CustomToastService.showError(
                                    message:
                                        'End date must be after start date',
                                  );
                                  return;
                                }

                                // Convert dates to timestamps (UTC)
                                DateTime finalStartDate;
                                DateTime finalEndDate;

                                if (selectedFilter == 'custom') {
                                  // Date picker returns local dates, convert to UTC
                                  finalStartDate =
                                      startDate!.isUtc
                                          ? startDate!
                                          : DateTime.utc(
                                            startDate!.year,
                                            startDate!.month,
                                            startDate!.day,
                                          );
                                  finalEndDate =
                                      endDate!.isUtc
                                          ? endDate!
                                          : DateTime.utc(
                                            endDate!.year,
                                            endDate!.month,
                                            endDate!.day,
                                          );
                                } else {
                                  // Quick filters already use UTC
                                  finalStartDate = startDate!;
                                  finalEndDate = endDate!;
                                }

                                // Convert to UTC timestamps (start of day in UTC)
                                final fromTimestamp =
                                    finalStartDate.millisecondsSinceEpoch ~/
                                    1000;
                                // End of day in UTC (start of next day - 1 second)
                                final toTimestamp =
                                    finalEndDate
                                            .add(const Duration(days: 1))
                                            .millisecondsSinceEpoch ~/
                                        1000 -
                                    1;

                                Get.back(closeOverlays: true);

                                // Load history with date filter and store filter type
                                await tradingController
                                    .loadTradeHistoryWithTimestamps(
                                      page: 1,
                                      refresh: true,
                                      fromTimestamp: fromTimestamp,
                                      toTimestamp: toTimestamp,
                                      filterType: selectedFilter,
                                    );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: EdgeInsets.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                'Apply Filter',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildQuickFilterButton(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.backgroundLight,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 0 : 1,
          ),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  void _showPositionDetailsBottomSheet(
    TradingController tradingController,
    TradePosition position,
  ) {
    final isPositive = position.profitLoss >= 0;

    // Pre-build the bottom sheet content to avoid rebuilding during animation
    final bottomSheetContent = _buildPositionDetailsContent(
      tradingController,
      position,
      isPositive,
    );

    Get.bottomSheet(
      Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(Get.context!).viewInsets.bottom,
        ),
        child: bottomSheetContent,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
    );
  }

  // Helper method to get symbol without .c suffix
  String _getDisplaySymbol(String symbol) {
    return symbol.replaceFirst('.c', '');
  }

  Widget _buildPositionDetailsContent(
    TradingController tradingController,
    TradePosition position,
    bool isPositive,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(top: 8.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          // Position Details Header
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                _buildPositionFlag(position.symbol, size: 32.h),
                SizedBox(width: 12.w),
                Expanded(
                  child: Obx(() {
                    // Get real-time position data filtered by orderId
                    // Check the appropriate list based on tab (Market or Pending)
                    final realTimePosition =
                        tradingController.selectedTab == 1
                            ? tradingController.pendingPositions
                                .firstWhereOrNull(
                                  (p) => p.orderId == position.orderId,
                                )
                            : tradingController.marketPositions
                                .firstWhereOrNull(
                                  (p) => p.orderId == position.orderId,
                                );

                    // Use real-time data if available, otherwise fallback to static position
                    final currentPosition = realTimePosition ?? position;
                    final currentProfitLoss = currentPosition.profitLoss;
                    final currentIsPositive = currentProfitLoss >= 0;

                    // Use openTime from current position (real-time if available, otherwise static)
                    // For pending orders, we want to show the actual time from WebSocket
                    final displayOpenTime =
                        currentPosition.openTime.isNotEmpty
                            ? currentPosition.openTime
                            : position.openTime;
                    final displaySwap = currentPosition.swap;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getDisplaySymbol(currentPosition.symbol),
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              tradingController.selectedTab == 1
                                  ? 'Pending'
                                  : '\$${PrecisionHelper.formatPnL(currentProfitLoss)}',
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color:
                                    tradingController.selectedTab == 1
                                        ? AppColors.textGrey
                                        : (currentIsPositive
                                            ? AppColors.success
                                            : AppColors.error),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SvgPicture.asset(
                                  currentPosition.action == 'Buy'
                                      ? 'assets/svg/trade/green_up_icon.svg'
                                      : 'assets/svg/trade/red_down_icon.svg',
                                  height: 9.h,
                                  width: 9.w,
                                ),
                                SizedBox(width: 6.w),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${currentPosition.action}',
                                        style: AppTextStyles.label.copyWith(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' ${currentPosition.volume}',
                                        style: AppTextStyles.label.copyWith(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.icongrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              tradingController.selectedTab == 1
                                  ? 'Order: ${currentPosition.entryPrice} | Current: ${currentPosition.currentPrice}'
                                  : '${currentPosition.entryPrice} → ${currentPosition.currentPrice}',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 12.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        // SL, TP, and Position ID in bottom sheet
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left side: SL and TP - handle all cases
                            Row(
                              children: [
                                // Show SL if it exists and is not empty/0
                                if (currentPosition.stopLoss.isNotEmpty &&
                                    currentPosition.stopLoss != '-' &&
                                    currentPosition.stopLoss != '0' &&
                                    currentPosition.stopLoss != '0.0') ...[
                                  Text(
                                    'SL: ${currentPosition.stopLoss}',
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                ],
                                // Show TP if it exists and is not empty/0
                                if (currentPosition.takeProfit.isNotEmpty &&
                                    currentPosition.takeProfit != '-' &&
                                    currentPosition.takeProfit != '0' &&
                                    currentPosition.takeProfit != '0.0') ...[
                                  Text(
                                    'TP: ${currentPosition.takeProfit}',
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                                // Show "-" only if both are empty/missing
                                if ((currentPosition.stopLoss.isEmpty ||
                                        currentPosition.stopLoss == '-' ||
                                        currentPosition.stopLoss == '0' ||
                                        currentPosition.stopLoss == '0.0') &&
                                    (currentPosition.takeProfit.isEmpty ||
                                        currentPosition.takeProfit == '-' ||
                                        currentPosition.takeProfit == '0' ||
                                        currentPosition.takeProfit == '0.0'))
                                  Text(
                                    'SL: -  TP: -',
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                              ],
                            ),
                            // Right side: Position ID
                            Text(
                              'ID: ${currentPosition.orderId}',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Open: ${_formatPositionTime(displayOpenTime)}',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textGrey,
                              ),
                            ),
                            Text(
                              'Swap: ${_formatSwapValue(displaySwap)}',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          // Action Options
          ListView(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            children:
                tradingController.selectedTab == 1
                    ? [
                      // Pending order actions
                      _buildActionOption(
                        icon: Icons.cancel,
                        title: 'Cancel Order',
                        subtitle: 'Cancel this pending order',
                        onTap: () async {
                          Get.back(closeOverlays: true);
                          await _showCancelOrderConfirmation(
                            tradingController,
                            position,
                          );
                        },
                        color: AppColors.error,
                      ),
                      _buildActionOption(
                        icon: Icons.edit,
                        title: 'Modify Order',
                        subtitle:
                            'Change order price, stop loss or take profit',
                        onTap: () {
                          Get.back(closeOverlays: true);
                          Get.to(() => EditOrderScreen(position: position));
                        },
                        color: AppColors.primary,
                      ),
                      _buildActionOption(
                        icon: Icons.add,
                        title: 'New Order',
                        subtitle: 'Place a new order for this instrument',
                        onTap: () {
                          Get.back(closeOverlays: true);
                          // Use callback to navigate to chart tab in TradingMainScreen
                          if (widget.onNavigateToChart != null) {
                            widget.onNavigateToChart!(position.symbol);
                          }
                        },
                        color: AppColors.success,
                      ),
                      _buildActionOption(
                        icon: Icons.show_chart,
                        title: 'Chart',
                        subtitle: 'View detailed chart for this instrument',
                        onTap: () {
                          Get.back(closeOverlays: true);
                          // Use callback to navigate to chart tab in TradingMainScreen
                          if (widget.onNavigateToChart != null) {
                            widget.onNavigateToChart!(position.symbol);
                          }
                        },
                        color: AppColors.primary,
                      ),
                    ]
                    : [
                      // Market position actions
                      _buildActionOption(
                        icon: Icons.close,
                        title: 'Close / Modify Position',
                        subtitle: 'Close / Modify this position immediately',
                        onTap: () {
                          Get.back(closeOverlays: true);
                          Get.to(() => ClosePositionScreen(position: position));
                        },
                        color: AppColors.error,
                      ),
                      // _buildActionOption(
                      //   icon: Icons.edit,
                      //   title: 'Modify Position',
                      //   subtitle: 'Change stop loss or take profit',
                      //   onTap: () {
                      //     Get.back(closeOverlays: true);
                      //     Get.to(() => EditOrderScreen(position: position));
                      //   },
                      //   color: AppColors.primary,
                      // ),
                      _buildActionOption(
                        icon: Icons.add,
                        title: 'New Order',
                        subtitle: 'Place a new order for this instrument',
                        onTap: () {
                          Get.back(closeOverlays: true);
                          // Use callback to navigate to chart tab in TradingMainScreen
                          if (widget.onNavigateToChart != null) {
                            widget.onNavigateToChart!(position.symbol);
                          }
                        },
                        color: AppColors.success,
                      ),
                      _buildActionOption(
                        icon: Icons.show_chart,
                        title: 'Chart',
                        subtitle: 'View detailed chart for this instrument',
                        onTap: () {
                          Get.back(closeOverlays: true);
                          // Use callback to navigate to chart tab in TradingMainScreen
                          if (widget.onNavigateToChart != null) {
                            widget.onNavigateToChart!(position.symbol);
                          }
                        },
                        color: AppColors.primary,
                      ),
                    ],
          ),
          SizedBox(height: MediaQuery.of(Get.context!).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildActionOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ListTile(
      title: Text(
        title,
        style: AppTextStyles.label.copyWith(
          fontSize: 15.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.33,
        ),
      ),
      onTap: onTap,
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
    );
  }

  String _formatPositionTime(String time) => _formatIsoDateTimeString(time);

  String _formatSwapValue(double swap) {
    return PrecisionHelper.formatPnL(swap);
  }

  String _formatIsoDateTimeString(String value) {
    // Use UTC timezone for all date formatting
    return DateHelper.formatIsoStringToUtc(value);
  }

  // Format timestamp for history cards: YYYY.MM.DD HH:MM:SS (UTC)
  String _formatHistoryTimestamp(String value) {
    // Use UTC timezone for all date formatting
    return DateHelper.formatIsoStringToUtcHistory(value);
  }

  void _showClosePositionsBottomSheet(TradingController tradingController) {
    print('📋 _showClosePositionsBottomSheet called');
    String selectedOption = 'all_currently_open';

    // Get screen dimensions for proper sizing
    final screenHeight = MediaQuery.of(Get.context!).size.height;
    final screenWidth = MediaQuery.of(Get.context!).size.width;

    print('📊 Screen dimensions: ${screenWidth}x${screenHeight}');
    print('📊 Selected option: $selectedOption');

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.75,
                minHeight: 320.h,
                maxWidth: screenWidth,
              ),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      'Which positions would you like to close at market prices?',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildCloseOption(
                              tradingController,
                              'all_currently_open',
                              'All currently open',
                              () => tradingController.getTotalProfitLoss(),
                              selectedOption == 'all_currently_open',
                              (value) => setState(() => selectedOption = value),
                            ),
                            _buildCloseOption(
                              tradingController,
                              'all_profitable',
                              'All profitable',
                              () =>
                                  tradingController
                                      .getTotalProfitableProfitLoss(),
                              selectedOption == 'all_profitable',
                              (value) => setState(() => selectedOption = value),
                            ),
                            _buildCloseOption(
                              tradingController,
                              'all_losing',
                              'All losing',
                              () =>
                                  tradingController.getTotalLosingProfitLoss(),
                              selectedOption == 'all_losing',
                              (value) => setState(() => selectedOption = value),
                            ),
                            _buildCloseOption(
                              tradingController,
                              'all_long',
                              'All Long',
                              () => tradingController.getTotalLongProfitLoss(),
                              selectedOption == 'all_long',
                              (value) => setState(() => selectedOption = value),
                            ),
                            _buildCloseOption(
                              tradingController,
                              'all_short',
                              'All Short',
                              () => tradingController.getTotalShortProfitLoss(),
                              selectedOption == 'all_short',
                              (value) => setState(() => selectedOption = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // SizedBox(height: 16.h),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16.w,
                        right: 16.w,
                        // bottom: 16.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                minimumSize: Size(double.infinity, 40.h),
                                // Removed maximumSize to avoid constraint conflicts
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          // ✅ ENHANCED: Show P&L in button text, keep original style
                          Expanded(
                            child: Obx(() {
                              // Calculate P&L based on selected option
                              final pnl = _getPnLForOption(
                                selectedOption,
                                tradingController,
                              );
                              final isPositive = pnl >= 0;
                              final isPendingTab =
                                  tradingController.selectedTab == 1;

                              // Button text with P&L
                              String buttonText;
                              if (isPendingTab) {
                                final count =
                                    tradingController.pendingPositions.length;
                                buttonText =
                                    'Confirm ($count order${count != 1 ? 's' : ''})';
                              } else {
                                buttonText =
                                    isPositive
                                        ? 'Confirm (+\$${PrecisionHelper.formatPnL(pnl)})'
                                        : 'Confirm (\$${PrecisionHelper.formatPnL(pnl)})';
                              }

                              return ElevatedButton(
                                onPressed:
                                    tradingController.isLoading
                                        ? null
                                        : () async {
                                          print(
                                            '🔘 Bottom sheet confirm button clicked!',
                                          );
                                          print(
                                            '📊 Selected option: $selectedOption',
                                          );

                                          // Close bottom sheet immediately using Navigator

                                          // ✅ Execute directly without second confirmation
                                          await _executeClosePositionsDirectly(
                                            tradingController,
                                            selectedOption,
                                          );
                                          Navigator.of(context).pop();
                                        },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor:
                                      isPendingTab
                                          ? AppColors.primary
                                          : (isPositive
                                              ? AppColors.success
                                              : AppColors.error),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  minimumSize: Size(double.infinity, 40.h),
                                ),
                                child:
                                    tradingController.isLoading
                                        ? ButtonLoadingWidget(
                                          size: 16.0,
                                          color: AppColors.whiteColor,
                                        )
                                        : Text(
                                          buttonText,
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.label.copyWith(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.whiteColor,
                                          ),
                                        ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
    );
  }

  Widget _buildCloseOption(
    TradingController tradingController,
    String value,
    String title,
    double Function() getProfitLoss,
    bool isSelected,
    Function(String) onChanged,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 0.h),
      child: Row(
        children: [
          // Left side: Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
              ],
            ),
          ),
          // Right side: Price and Radio button
          Row(
            children: [
              // Only wrap the price text in Obx for reactive updates
              Obx(() {
                final profitLoss = getProfitLoss();
                final isPositive = profitLoss >= 0;
                final hasPositions = profitLoss != 0;

                return Text(
                  hasPositions
                      ? '\$${PrecisionHelper.formatPnL(profitLoss)}'
                      : '-',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color:
                        hasPositions
                            ? (isPositive ? AppColors.success : AppColors.error)
                            : AppColors.textGrey,
                  ),
                );
              }),
              Obx(() {
                final profitLoss = getProfitLoss();
                final hasPositions = profitLoss != 0;

                return Radio<String>(
                  value: value,
                  groupValue: isSelected ? value : null,
                  onChanged:
                      hasPositions ? (newValue) => onChanged(newValue!) : null,
                  activeColor: AppColors.primary,
                  fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary;
                    }
                    return AppColors.isDarkMode ? Colors.white : Colors.grey;
                  }),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Get P&L for the selected option
  double _getPnLForOption(String option, TradingController tradingController) {
    if (tradingController.selectedTab == 1) {
      return 0.0; // Pending orders don't have P&L
    }

    switch (option) {
      case 'all_currently_open':
        return tradingController.getTotalProfitLoss();
      case 'all_profitable':
        return tradingController.getTotalProfitableProfitLoss();
      case 'all_losing':
        return tradingController.getTotalLosingProfitLoss();
      case 'all_long':
        return tradingController.getTotalLongProfitLoss();
      case 'all_short':
        return tradingController.getTotalShortProfitLoss();
      default:
        return 0.0;
    }
  }

  /// ✅ NEW: Execute close positions directly without confirmation dialog
  Future<void> _executeClosePositionsDirectly(
    TradingController tradingController,
    String option,
  ) async {
    final accountController = Get.find<AccountController>();
    final activeAccount = accountController.activeMT5Account;

    if (activeAccount == null) {
      CustomToastService.showError(
        title: 'Error',
        message: 'No active account found',
      );
      return;
    }

    try {
      // Call the appropriate API based on option
      if (tradingController.selectedTab == 1) {
        // Handle pending orders
        final pendingOrders = tradingController.pendingPositions;
        final orderIds =
            pendingOrders.map((p) => int.parse(p.orderId)).toList();

        if (orderIds.isNotEmpty) {
          await tradingController.closeMultiplePendingOrders(
            mt5Account: activeAccount.metaAccountNumber,
            orderIds: orderIds,
          );
        }
      } else {
        // Handle market positions
        switch (option) {
          case 'all_currently_open':
            await tradingController.closeAllPositions(
              mt5Account: activeAccount.metaAccountNumber,
            );
            break;
          case 'all_profitable':
            await tradingController.closeAllProfitablePositions(
              mt5Account: activeAccount.metaAccountNumber,
            );
            break;
          case 'all_losing':
            await tradingController.closeAllLosingPositions(
              mt5Account: activeAccount.metaAccountNumber,
            );
            break;
          case 'all_long':
            await tradingController.closeAllLongPositions(
              mt5Account: activeAccount.metaAccountNumber,
            );
            break;
          case 'all_short':
            await tradingController.closeAllShortPositions(
              mt5Account: activeAccount.metaAccountNumber,
            );
            break;
        }
      }

      // Don't show notification here - let the controller show the API response message
      // The controller's _setSuccess/_setError will handle notifications from API response
    } catch (e) {
      // Only show error if controller didn't already show one
      // The controller will show the API response error message
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to close positions: ${e.toString()}',
          title: 'Error',
        );
      }
    }
  }

  // ❌ DELETED: Old methods no longer needed
  // - _executeClosePositions()
  // - _showClosePositionsConfirmation()
  // - _getClosePositionsMessage()

  Future<bool> _showClosePositionConfirmation(
    TradingController tradingController,
    TradePosition position,
  ) async {
    print('🔔 Showing close position confirmation dialog');

    // Check if this is a pending order or market position
    final isPendingOrder = tradingController.selectedTab == 1;

    final result = await Get.dialog<bool>(
      barrierDismissible: true, // Allow dismissal by tapping outside
      barrierColor: Colors.black54, // Semi-transparent background
      Dialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Builder(
          builder:
              (dialogContext) => Container(
                constraints: BoxConstraints(
                  maxWidth: 400.w,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
                ),
                padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      isPendingOrder ? 'Cancel Order' : 'Close Position',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Content - Scrollable to handle long text on small devices
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          isPendingOrder
                              ? 'Are you sure you want to cancel ${_getDisplaySymbol(position.symbol)} ${position.action} ${position.volume} order?'
                              : 'Are you sure you want to close ${_getDisplaySymbol(position.symbol)} ${position.action} ${position.volume}?',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14.sp,
                            color: AppColors.textGrey,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Buttons - Bottom center, same size
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel Button - Equal width with confirm button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              print('🔘 CANCEL BUTTON CLICKED IN DIALOG!');
                              Navigator.of(Get.context!).pop(false);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 12.h,
                              ),
                              minimumSize: Size(0, 44.h),
                              side: BorderSide(
                                color: AppColors.border,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textGrey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Confirm Button - Equal width with cancel button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              print('🔘 CONFIRM BUTTON CLICKED IN DIALOG!');
                              print('📊 Is Pending Order: $isPendingOrder');

                              // Close the dialog first
                              // Close the dialog but return false to Dismissible
                              // This ensures the item stays in the list until success message
                              Navigator.of(Get.context!).pop(false);

                              // Add a small delay to ensure dialog is closed
                              await Future.delayed(Duration(milliseconds: 100));

                              // Call the appropriate API based on order type
                              final accountController =
                                  Get.find<AccountController>();
                              final activeAccount =
                                  accountController.activeMT5Account;

                              if (activeAccount != null) {
                                if (isPendingOrder) {
                                  // This is a pending order - cancel it
                                  print('📞 Calling cancel order API...');
                                  await tradingController
                                      .cancelOrderWithImmediateUpdate(
                                        mt5Account:
                                            activeAccount.metaAccountNumber,
                                        orderId: int.parse(position.orderId),
                                      );
                                  print('✅ Cancel order API completed');
                                } else {
                                  // This is a market position - close it
                                  print('📞 Calling close position API...');
                                  await tradingController
                                      .closePositionWithImmediateUpdate(
                                        mt5Account:
                                            activeAccount.metaAccountNumber,
                                        positionId: int.parse(position.orderId),
                                      );
                                  print('✅ Close position API completed');
                                }
                              } else {
                                print('❌ No active account found');
                                CustomToastService.showError(
                                  title: 'Error',
                                  message: 'No active account found',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 12.h,
                              ),
                              minimumSize: Size(0, 44.h),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isPendingOrder ? 'Cancel Order' : 'Close',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.whiteColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showCancelOrderConfirmation(
    TradingController tradingController,
    TradePosition position,
  ) async {
    print('🔔 Showing cancel order confirmation dialog');

    final result = await Get.dialog<bool>(
      barrierDismissible: true,
      barrierColor: Colors.black54,
      Dialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Builder(
          builder:
              (dialogContext) => Container(
                constraints: BoxConstraints(
                  maxWidth: 400.w,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
                ),
                padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'Cancel Order',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Content - Scrollable to handle long text on small devices
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          'Are you sure you want to cancel ${_getDisplaySymbol(position.symbol)} ${position.action} ${position.volume} order?',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14.sp,
                            color: AppColors.textGrey,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Buttons - Bottom center, same size
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel Button - Equal width with confirm button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              print('🔘 CANCEL BUTTON CLICKED IN DIALOG!');
                              Navigator.of(Get.context!).pop(false);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 12.h,
                              ),
                              minimumSize: Size(0, 44.h),
                              side: BorderSide(
                                color: AppColors.border,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textGrey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Cancel Order Button - Equal width with cancel button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              print(
                                '🔘 CANCEL ORDER BUTTON CLICKED IN DIALOG!',
                              );
                              // Close the dialog but return false to Dismissible
                              // This ensures the item stays in the list until success message
                              Navigator.of(Get.context!).pop(false);

                              await Future.delayed(Duration(milliseconds: 100));

                              final accountController =
                                  Get.find<AccountController>();
                              final activeAccount =
                                  accountController.activeMT5Account;

                              if (activeAccount != null) {
                                print('📞 Calling cancel order API...');
                                await tradingController
                                    .cancelOrderWithImmediateUpdate(
                                      mt5Account:
                                          activeAccount.metaAccountNumber,
                                      orderId: int.parse(position.orderId),
                                    );
                                print('✅ Cancel order API completed');
                              } else {
                                print('❌ No active account found');
                                CustomToastService.showError(
                                  title: 'Error',
                                  message: 'No active account found',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 12.h,
                              ),
                              minimumSize: Size(0, 44.h),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Cancel Order',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.whiteColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
    return result ?? false;
  }

  Widget _buildAccountMetrics(TradingController tradingController) {
    final currentTab = tradingController.selectedTab;
    final config = TabMetricConfig.forTab(currentTab);

    AccountInfo? accountInfo;
    TradeHistoryTotals? totals;

    if (currentTab == 2) {
      totals = tradingController.tradeHistoryTotals;
    } else {
      accountInfo = tradingController.accountInfo;
    }

    final metricKeys =
        config.metricKeys.where((key) {
          if (key == 'trade_metric_credit' && currentTab == 2) return false;
          return true;
        }).toList();

    // INNOVATIVE DESIGN: Grid view with icons for Vantage flavor
    if (FlavorConfig.isVantage()) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final isCompactScreen = screenWidth < 420;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: 2.h),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: isCompactScreen ? 1.75 : 1.95,
          crossAxisSpacing: 4.w,
          mainAxisSpacing: 4.h,
        ),
        itemCount: metricKeys.length,
        itemBuilder: (context, index) {
          final key = metricKeys[index];
          String value;
          Color? valueColor;

          if (currentTab == 2 && totals != null) {
            value = _getMetricValue(key, null, totals);
            valueColor = _getMetricColor(key, null, totals);
          } else if (currentTab != 2 && accountInfo != null) {
            value = _getMetricValue(key, accountInfo, null);
            valueColor = _getMetricColor(key, accountInfo, null);
          } else {
            value = '0.00';
            valueColor = AppColors.textGrey;
          }

          return _buildInnovativeMetricCard(
            languageService.tr(key),
            value,
            key,
            valueColor: valueColor,
            isCompactScreen: isCompactScreen,
          );
        },
      );
    }

    // ORIGINAL DESIGN: Simple list for other flavors
    return Column(
      children:
          metricKeys.map((key) {
            String value;
            Color? valueColor;

            if (currentTab == 2 && totals != null) {
              value = _getMetricValue(key, null, totals);
              valueColor = _getMetricColor(key, null, totals);
            } else if (currentTab != 2 && accountInfo != null) {
              value = _getMetricValue(key, accountInfo, null);
              valueColor = _getMetricColor(key, accountInfo, null);
            } else {
              value = '0.00';
              valueColor = AppColors.textGrey;
            }

            return _buildMetricRow(
              languageService.tr(key),
              value,
              valueColor: valueColor,
            );
          }).toList(),
    );
  }

  String _getMetricValue(
    String key,
    AccountInfo? accountInfo,
    TradeHistoryTotals? totals,
  ) {
    if (accountInfo != null) {
      switch (key) {
        case 'trade_metric_balance':
          return accountInfo.balance.toStringAsFixed(2);
        case 'trade_metric_credit':
          return accountInfo.credit.toStringAsFixed(2);
        case 'trade_metric_equity':
          return accountInfo.equity.toStringAsFixed(2);
        case 'trade_metric_margin':
          return accountInfo.margin.toStringAsFixed(2);
        case 'trade_metric_free_margin':
          return accountInfo.marginFree.toStringAsFixed(2);
        case 'trade_metric_margin_level':
          return accountInfo.marginLevel.toStringAsFixed(2);
      }
    }

    if (totals != null) {
      switch (key) {
        case 'trade_metric_profit':
          return totals.profit.toStringAsFixed(2);
        case 'trade_metric_deposit':
          return totals.deposit.toStringAsFixed(2);
        case 'trade_metric_withdrawal':
          return totals.withdrawal.toStringAsFixed(2);
        case 'trade_metric_swap':
          return totals.swap.toStringAsFixed(2);
        case 'trade_metric_commission':
          return totals.commission.toStringAsFixed(2);
        case 'trade_metric_balance':
          return totals.balance.toStringAsFixed(2);
      }
    }

    return '0.00';
  }

  Color? _getMetricColor(
    String key,
    AccountInfo? accountInfo,
    TradeHistoryTotals? totals,
  ) {
    if (accountInfo != null) {
      if (key == 'trade_metric_balance' && accountInfo.balance < 0) {
        return AppColors.red;
      }
      if (key == 'trade_metric_free_margin' && accountInfo.marginFree < 0) {
        return AppColors.red;
      }
      if (key == 'trade_metric_margin_level' && accountInfo.marginLevel < 90) {
        return AppColors.red;
      }
    }
    if (totals != null) {
      if (key == 'trade_metric_balance' && totals.balance < 0) {
        return AppColors.red;
      }
    }

    if (totals != null) {
      if (key == 'trade_metric_profit' && totals.profit < 0) {
        return AppColors.red;
      }
    }
    return null;
  }

  /// Get the flag SVG path based on the instrument symbol
  /// Extracts currency code from symbol (e.g., EURUSD -> EUR)
  /// Returns path like 'assets/svg/flags/eurusd.svg'
  String _getFlagPath(String symbol) {
    // Remove suffix if present (e.g., EURUSD.c -> EURUSD)
    String cleanSymbol =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;

    // Return path with full symbol lowercase
    return 'assets/svg/flags/${cleanSymbol.toLowerCase()}.svg';
  }

  /// Build flag icon widget with error handling
  Widget _buildPositionFlag(String symbol, {double? size}) {
    final flagSize = size ?? 24.h;
    final containerSize = flagSize + 16.h; // Add padding for container
    final iconSize = flagSize; // Icon size stays the same
    final flagPath = _getFlagPath(symbol);

    return FutureBuilder<String?>(
      future: _checkAssetExists(flagPath),
      builder: (context, snapshot) {
        // If asset exists, show SVG
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: SvgPicture.asset(
                flagPath,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
              ),
            ),
          );
        }

        // If asset doesn't exist or error occurred, show fallback
        return _buildFallbackFlag(flagSize, containerSize, iconSize);
      },
    );
  }

  /// Check if asset exists by trying to load it
  Future<String?> _checkAssetExists(String assetPath) async {
    try {
      await DefaultAssetBundle.of(context).load(assetPath);
      return assetPath;
    } catch (e) {
      return null;
    }
  }

  /// Build fallback flag image widget
  Widget _buildFallbackFlag(
    double flagSize,
    double containerSize,
    double iconSize,
  ) {
    final fontSize = (flagSize * 0.7).clamp(12.0, 28.0);
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: Image.asset(
            'assets/image/noflag.jpeg',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Center(
                  child: Text(
                    '💱',
                    style: TextStyle(fontSize: fontSize),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInnovativeMetricCard(
    String label,
    String value,
    String key, {
    Color? valueColor,
    bool isCompactScreen = false,
  }) {
    final wrapLongLabel =
        isCompactScreen &&
        (key == 'trade_metric_margin_level' ||
            key == 'trade_metric_free_margin');
    final labelMaxLines = wrapLongLabel ? 2 : 1;
    IconData icon;
    switch (key) {
      case 'trade_metric_balance':
        icon = Icons.account_balance_wallet_outlined;
        break;
      case 'trade_metric_equity':
        icon = Icons.show_chart_outlined;
        break;
      case 'trade_metric_margin':
        icon = Icons.pie_chart_outline;
        break;
      case 'trade_metric_free_margin':
        icon = Icons.lock_open_outlined;
        break;
      case 'trade_metric_margin_level':
        icon = Icons.percent_outlined;
        break;
      case 'trade_metric_profit':
        icon = Icons.trending_up_outlined;
        break;
      default:
        icon = Icons.bar_chart_outlined;
    }

    // Format value: strip % suffix from display, add % after negative values
    final displayValue = value.replaceAll('%', '').trim();
    final showPercent =
        valueColor != null &&
        valueColor == AppColors.red &&
        key == 'trade_metric_margin_level';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Icon(icon, size: 12.sp, color: AppColors.primary),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textGrey,
                    height: wrapLongLabel ? 1.15 : null,
                  ),
                  maxLines: labelMaxLines,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(
            showPercent ? '$displayValue%' : displayValue,
            style: AppTextStyles.heading.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        // Label
        Text(
          label + ":",
          style: AppTextStyles.label.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),

        // Flexible space with dashed line
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            child: Container(
              height: 10,
              alignment: Alignment.bottomCenter,
              child: DashedUnderline(
                dashWidth: 2.w,
                dashSpace: 7.w,
                color: AppColors.icongrey,
              ),
            ),
          ),
        ),

        // Value
        Text(
          value,
          style: AppTextStyles.label.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // Build expanded card content for Close tab
  Widget _buildExpandedCardContent(TradePosition position) {
    // Format open/close times
    final formattedOpenTime = _formatIsoDateTimeString(position.openTime);
    final formattedCloseTime = _formatIsoDateTimeString(position.closeTime);

    final durationValue =
        position.duration.isNotEmpty ? position.duration : '-';

    // Format values for S/L and T/P
    String formatValue(String value) {
      if (value.isEmpty || value == '0' || value == '-') return '-';
      try {
        final num = double.tryParse(value.replaceAll(',', ''));
        if (num == null) return value;
        return PrecisionHelper.formatPnL(num);
      } catch (e) {
        return value;
      }
    }

    final formattedStopLoss = formatValue(position.stopLoss);
    final formattedTakeProfit = formatValue(position.takeProfit);
    final formattedSwap = formatValue(position.swap.toString());
    final formattedCommission = formatValue(position.commission.toString());

    return Container(
      padding: EdgeInsets.only(top: 12.h, bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 16.h),

          // Single column layout for all details (matching image design)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildMT5DoubleRow(
                label1: languageService.tr('trade_label_sl'),
                value1: formattedStopLoss,
                label2: languageService.tr('trade_label_tp'),
                value2: formattedTakeProfit,
              ),

              buildMT5DoubleRow(
                label1: languageService.tr('trade_label_open'),
                value1: formattedOpenTime,
                label2: 'Close',
                value2: formattedCloseTime,
              ),

              buildMT5DoubleRow(
                label1: languageService.tr('trade_metric_swap'),
                value1: formattedSwap,
                label2: languageService.tr('trade_metric_commission'),
                value2: formattedCommission,
              ),

              buildMT5DoubleRow(
                label1: languageService.tr('trade_label_id'),
                value1: "#${position.orderId}",
                label2: 'Duration',
                value2: durationValue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build a detail row for expanded content (label and value on same line)
  Widget buildMT5DoubleRow({
    required String label1,
    required String value1,
    required String label2,
    required String value2,
  }) {
    return Row(
      children: [
        // Column 1
        Expanded(
          child: Row(
            children: [
              Text(
                "$label1: ",
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 12),

        // Column 2
        Expanded(
          child: Row(
            children: [
              Text(
                "$label2: ",
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
