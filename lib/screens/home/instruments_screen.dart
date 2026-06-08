// lib/presentation/screens/instruments_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/app_back_button.dart';

import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/market_watch_v2_service.dart';
import 'package:crm_app/screens/home/search_instruments_screen.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart'; // ✅ ADD: For account change listener

import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/utils/svg_color_helper.dart';
import '../../widgets/account_header_widget.dart';
import '../../widgets/common_loading_widget.dart';
import 'chart_screen.dart';
import 'dart:developer' as dev;
import '../../services/symbol_selection_service.dart';

class InstrumentsScreen extends StatefulWidget {
  final Function(String)? onNavigateToChart;

  const InstrumentsScreen({super.key, this.onNavigateToChart});

  @override
  State<InstrumentsScreen> createState() => _InstrumentsScreenState();
}

class _InstrumentsScreenState extends State<InstrumentsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  // Filters are now dynamic - use _controller.availableFilters instead
  final List<String> _sortOptions = ['Default', 'Symbol A-Z', 'Symbol Z-A'];
  final InstrumentsController _controller = Get.put(InstrumentsController());
  final SymbolSelectionService _symbolSelectionService = Get.put(
    SymbolSelectionService(),
    permanent: true,
  );

  final LanguageService languageService = Get.put(LanguageService());
  bool _isSearching = false;
  Timer? _searchDebounceTimer;
  static const int _minSearchLength = 2; // Minimum characters before searching

  void _openSearchInstrumentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: AppColors.tradeBackgroundCenterColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              child: SearchInstrumentsScreen(
                onNavigateToChart: widget.onNavigateToChart,
              ),
            ),
          ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);

    // Ensure the last selected symbol is loaded from secure storage
    Future.microtask(() async {
      await _symbolSelectionService.ensureDefault();
    });

    // Listen to real-time price updates from instruments controller
    _listenToPriceUpdates();

    // ✅ FIX: Listen to account changes and refresh instruments
    _listenToAccountChanges();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureMarketWatchV2ForTab();
    });
  }

  Future<void> _ensureMarketWatchV2ForTab() async {
    if (!Get.isRegistered<MarketWatchV2Service>()) return;
    final ic = _controller;
    final deadline = DateTime.now().add(const Duration(milliseconds: 400));
    while (ic.isLoadingFavorites.value && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    final svc = Get.find<MarketWatchV2Service>();
    final syms =
        ic.favoriteInstruments
            .map(MarketWatchV2Service.normalizeSymbol)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
    try {
      if (syms.isNotEmpty) {
        await svc.subscribeSymbols(syms);
      } else {
        await svc.ensureAuthenticatedConnection();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // ✅ FIX: Ensure DashboardController WebSocket is initialized in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (Get.isRegistered<DashboardController>()) {
          final dashboardController = Get.find<DashboardController>();
          dashboardController.ensureWebSocketInitialized();
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            'Instruments Screen: Error ensuring WebSocket initialization: $e',
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      // drawer: const GlobalDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndFilters(),
            Expanded(
              child: Obx(() {
                final controller = _controller;
                // Show loading indicator while WebSocket is connecting and no data yet
                if (controller.allInstruments.isEmpty &&
                    !controller.isConnected.value) {
                  return Center(
                    child: CommonLoadingWidget(
                      message: 'Loading instruments...',
                      size: 50.0,
                      color: AppColors.primary,
                    ),
                  );
                }
                // Build list content (reactive - updates automatically when instruments list changes)
                if (controller.instruments.isEmpty) {
                  return _buildNoData();
                }
                return _buildInstrumentsList(controller.instruments);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_isSearching) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            AppBackButton(
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
                _controller.searchInstruments("");
              },
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textDirection: RTLHelper.textDirection,
                textAlign: RTLHelper.isRTL ? TextAlign.right : TextAlign.left,
                decoration: InputDecoration(
                  hintText: languageService.tr("instruments_search"),
                  hintStyle: AppTextStyles.input.copyWith(
                    color: AppColors.textGrey,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final isVantage = FlavorConfig.isVantage();

      return AccountHeaderWidget(
        layoutStyle:
            isVantage
                ? AccountHeaderLayoutStyle.vantageInstruments
                : AccountHeaderLayoutStyle.defaultLayout,
        showMenuIcon: !isVantage,
        showSearchIcon: !isVantage,
        useTradingFloatingProfit: true,
        rightWidget:
            isVantage
                ? Container(
                  margin: EdgeInsets.only(right: 0),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.search_rounded,
                      size: 20.sp,
                      color: AppColors.primary,
                    ),
                    onPressed: _openSearchInstrumentsSheet,
                    padding: EdgeInsets.all(8.r),
                    constraints: const BoxConstraints(),
                  ),
                )
                : null,
        onSearchTap: isVantage ? null : _openSearchInstrumentsSheet,
      );
    }
  }

  Widget _buildSearchAndFilters() {
    final isVantage = FlavorConfig.isVantage();
    if (isVantage) {
      // Vantage design: keep the header (account + search) only.
      // Hide page title, sort dropdown, and segmented filters for a cleaner, more compact quote list.
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 8.h),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Instruments',
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildSortDropdown(),
            ],
          ),
          SizedBox(height: 10.h),
          _buildFilterButtons(),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Obx(() {
        // Use dynamic filters from controller (based on WebSocket categories)
        // Remove 'All' tab - only show Favorites and category filters
        final filters = [
          'Favorites',
          ..._controller.availableFilters.where(
            (f) => f != 'All' && f != 'Favorites',
          ),
        ];

        return Row(
          children:
              filters.map((filter) {
                final isSelected = filter == _controller.currentFilter.value;
                // Show favorites count for Favorites filter
                final displayText =
                    filter == 'Favorites'
                        ? 'Favorites (${_controller.favoritesCount})'
                        : filter;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: GestureDetector(
                    onTap: () {
                      if (_isSearching) {
                        setState(() {
                          _isSearching = false;
                          _searchController.clear();
                        });
                      }
                      _controller.filterInstruments(filter);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primary
                                : AppColors.tradeBackgroundCenterColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : AppColors.primary,
                        ),
                      ),
                      child: Text(
                        displayText,
                        style: AppTextStyles.input.copyWith(
                          fontSize: 13.sp,
                          height: 22 / 15,
                          color:
                              isSelected
                                  ? AppColors.whiteColor
                                  : AppColors.primary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      }),
    );
  }

  Widget _buildSortDropdown() {
    return GestureDetector(
      onTap: () {
        _showSortBottomSheet();
      },
      child: Obx(() {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'By ${_controller.currentSort.value}',
                style: AppTextStyles.input.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  height: 22 / 15,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16.h,
                color: AppColors.primary,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInstrumentsList(List<ListElement> instruments) {
    final isVantage = FlavorConfig.isVantage();
    final showFavoritesToggle = !isVantage || _isSearching;
    final enableReorder = isVantage && !_isSearching;
    // ✅ PERFORMANCE OPTIMIZATION: Calculate time ONCE for all items
    // Instead of calling DateTime.now() 50+ times (once per item)
    final currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _controller.notifyUserScrollActivity();
        return false;
      },
      child:
          enableReorder
              ? ReorderableListView.builder(
                buildDefaultDragHandles: false,
                physics: const ClampingScrollPhysics(),
                itemExtent: 56.h,
                padding: EdgeInsets.only(
                  bottom: 16.h + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: instruments.length,
                onReorder: (oldIndex, newIndex) {
                  _controller.reorderInstruments(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final instrument = instruments[index];
                  return KeyedSubtree(
                    key: ValueKey(instrument.symbol),
                    child: _buildInstrumentItem(
                      instrument,
                      currentTime,
                      isVantage: isVantage,
                      showFavoritesToggle: showFavoritesToggle,
                      showReorderHandle: true,
                      reorderIndex: index,
                    ),
                  );
                },
              )
              : ListView.builder(
                // Performance optimizations
                cacheExtent: 250,
                physics: const ClampingScrollPhysics(),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemExtent: (isVantage ? 56.0 : 62.0).h,
                padding: EdgeInsets.only(
                  bottom:
                      (isVantage ? 90.h : 77.h) +
                      MediaQuery.of(context).padding.bottom,
                ),
                itemCount: instruments.length,
                itemBuilder: (context, index) {
                  final instrument = instruments[index];
                  return _buildInstrumentItem(
                    instrument,
                    currentTime,
                    isVantage: isVantage,
                    showFavoritesToggle: showFavoritesToggle,
                    showReorderHandle: false,
                  );
                },
              ),
    );
  }

  Widget _buildInstrumentItem(
    ListElement instrument,
    String currentTime, {
    required bool isVantage,
    required bool showFavoritesToggle,
    bool showReorderHandle = false,
    int? reorderIndex,
  }) {
    // ✅ PERFORMANCE: Wrap entire item in RepaintBoundary
    // This isolates repaints - when one item updates, others don't repaint
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          _navigateToChartWithSymbol(instrument.symbol);
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: (isVantage ? 2.0 : 4.0).h,
          ),
          decoration: BoxDecoration(
            // color: AppColors.whiteColor,
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                isVantage
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (showReorderHandle && reorderIndex != null) ...[
                ReorderableDragStartListener(
                  index: reorderIndex,
                  child: Padding(
                    padding: EdgeInsets.only(right: 2.w),
                    child: SizedBox(
                      height: 30.h,
                      width: 24.w,
                      child: Center(
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 18.sp,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Expanded(
                flex: 3,
                child: Row(
                  crossAxisAlignment:
                      isVantage
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: (isVantage ? 36.0 : 40.0).w,
                      constraints: BoxConstraints(
                        minHeight: (isVantage ? 34.0 : 36.0).h,
                      ),
                      alignment: Alignment.center,
                      child: _buildFlagIcon(
                        instrument.symbol,
                        size: (isVantage ? 34.0 : 40.0).w,
                      ),
                    ),
                    SizedBox(width: (isVantage ? 4.0 : 10.0).w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment:
                            isVantage
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                        children: [
                          Text(
                            _removeSymbolSuffix(instrument.symbol),
                            style: (isVantage
                                    ? AppTextStyles.label
                                    : AppTextStyles.input)
                                .copyWith(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w600,
                                  fontSize: (isVantage ? 13.0 : 13.0).sp,
                                  height: 1.15,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          SizedBox(height: (isVantage ? 2.0 : 1.0).h),
                          // ✅ PERFORMANCE FIX: Use pre-calculated time (passed as parameter)
                          Text(
                            currentTime,
                            style: AppTextStyles.caption.copyWith(
                              fontFamily: 'Roboto',
                              fontSize: 10.sp,
                              color: AppColors.textGrey,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: (isVantage ? 2.0 : 1.0).h),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/svg/spread.svg',
                                width: 10.w,
                                height: 10.h,
                                // color: AppColors.textGrey,
                              ),
                              SizedBox(width: 2.w),
                              Flexible(
                                child: Obx(() {
                                  final spreadDiff =
                                      _controller
                                          .priceRx(instrument.symbol)
                                          .value
                                          .spreadDiff;
                                  return Text(
                                    _formatSpreadDiff(spreadDiff),
                                    style: AppTextStyles.caption.copyWith(
                                      fontFamily: 'Roboto',
                                      fontSize: 10.sp,
                                      color: AppColors.textGrey,
                                      height: 1.1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isVantage) SizedBox(width: 8.w),
              // ✅ PERFORMANCE: Extract Bid column into separate widget (reactive)
              Expanded(
                flex: 2,
                child: Align(
                  alignment:
                      isVantage ? Alignment.centerRight : Alignment.center,
                  child: _BidPriceColumn(
                    symbol: instrument.symbol,
                    controller: _controller,
                    dayLow: instrument.dayLow,
                    digits: instrument.digits,
                    compact: isVantage,
                  ),
                ),
              ),
              SizedBox(width: (isVantage ? 14.0 : 6.0).w),
              // ✅ PERFORMANCE: Extract Ask column into separate widget (reactive)
              Expanded(
                flex: 2,
                child: Align(
                  alignment:
                      isVantage ? Alignment.centerRight : Alignment.center,
                  child: _AskPriceColumn(
                    symbol: instrument.symbol,
                    controller: _controller,
                    dayHigh: instrument.dayHigh,
                    digits: instrument.digits,
                    compact: isVantage,
                  ),
                ),
              ),
              // Favorite button - Centered vertically relative to the row
              if (showFavoritesToggle) ...[
                SizedBox(width: 6.w),
                Container(
                  constraints: BoxConstraints(
                    minHeight: (isVantage ? 34.0 : 36.0).h,
                  ),
                  alignment: isVantage ? Alignment.center : Alignment.topCenter,
                  padding:
                      isVantage ? EdgeInsets.zero : EdgeInsets.only(top: 1.h),
                  child: _FavoriteButton(
                    symbol: instrument.symbol,
                    controller: _controller,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChartWithSymbol(String symbol) {
    dev.log('InstrumentsScreen: Navigating to chart with symbol: $symbol');

    _symbolSelectionService.setSymbol(symbol);

    // Set the selected symbol for the chart screen
    ChartScreen.setSelectedSymbol(symbol);
    dev.log('InstrumentsScreen: Set selected symbol to: $symbol');

    // Navigate to chart screen
    if (widget.onNavigateToChart != null) {
      dev.log(
        'InstrumentsScreen: Calling onNavigateToChart callback with symbol: $symbol',
      );
      widget.onNavigateToChart!(symbol);
    } else {
      dev.log('InstrumentsScreen: onNavigateToChart callback is null');
    }
  }

  // Listen to price updates from instruments controller
  void _listenToPriceUpdates() {
    // The instruments controller already handles real-time updates
    // and updates the instruments list automatically
    dev.log('InstrumentsScreen: Listening to price updates from controller');
  }

  // ✅ FIX: Listen to account changes and refresh instruments
  void _listenToAccountChanges() {
    try {
      final accountController = Get.find<AccountController>();
      String? _lastAccountNumber;

      ever(accountController.activeMT5AccountRx, (account) {
        if (account == null) return;

        final newAccountNumber = account.metaAccountNumber;

        // Check if account actually changed
        if (_lastAccountNumber != null &&
            _lastAccountNumber != newAccountNumber) {
          dev.log(
            'InstrumentsScreen: Account changed from $_lastAccountNumber to $newAccountNumber, refreshing...',
          );

          // Force refresh instruments for new account
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            try {
              // Ensure WebSocket is started for new account
              _controller.startWebSocket();

              // Force UI refresh
              setState(() {});
            } catch (e) {
              dev.log(
                'InstrumentsScreen: Error refreshing on account change: $e',
              );
            }
          });
        }

        _lastAccountNumber = newAccountNumber;
      });
    } catch (e) {
      dev.log(
        'InstrumentsScreen: Error setting up account change listener: $e',
      );
    }
  }

  Widget _buildNoData() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SvgPicture.asset('assets/svg/no_imge_icon.svg'),
            FutureBuilder<Widget>(
              future: SvgColorHelper.loadSvgWithColor(
                assetPath: 'assets/svg/no_imge_icon.svg',
                targetColor: AppColors.primary,
                colorToReplace: '#5F259E', // Replace this color in the SVG
                height: 100.h,
                width: 100.w,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData) return snapshot.data!;
                return SizedBox(height: 100.h, width: 100.w);
              },
            ),
            SizedBox(height: 24.h),
            Obx(() {
              final isFavoritesFilter =
                  _controller.currentFilter.value == 'Favorites';
              return Text(
                isFavoritesFilter
                    ? languageService.tr("no_favorites_added")
                    : languageService.tr("common_no_data"),
                style: AppTextStyles.heading.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              );
            }),
            Obx(() {
              final isFavoritesFilter =
                  _controller.currentFilter.value == 'Favorites';
              return Text(
                isFavoritesFilter
                    ? languageService.tr("tap_circle_icon_to_add_instruments")
                    : languageService.tr("common_no_data_description"),
                style: AppTextStyles.subheading.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              );
            }),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(40.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Sort by',
                style: AppTextStyles.heading.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16.h),
              Obx(() {
                return Column(
                  children: [
                    ..._sortOptions.map((option) {
                      return Column(
                        children: [
                          ListTile(
                            title: Row(
                              children: [
                                Container(
                                  width: 24.w,
                                  height: 24.h,
                                  margin: EdgeInsets.all(8.sp),
                                  padding: EdgeInsets.all(2.sp),
                                  child: _getSortIcon(option),
                                ),
                                Text(option, style: AppTextStyles.input),
                              ],
                            ),
                            trailing:
                                option == _controller.currentSort.value
                                    ? Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                    )
                                    : null,
                            onTap: () {
                              _controller.sortInstruments(option);
                              Navigator.pop(context);
                            },
                          ),
                          Divider(color: AppColors.grey, height: 1.h),
                        ],
                      );
                    }).toList(),
                  ],
                );
              }),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 0.1),
            ],
          ),
        );
      },
    );
  }

  Widget _getSortIcon(String option) {
    switch (option) {
      case 'Default':
        return Icon(Icons.view_list, size: 20.h, color: AppColors.textGrey);
      case 'Symbol A-Z':
        return Icon(Icons.sort_by_alpha, size: 20.h, color: AppColors.textGrey);
      case 'Symbol Z-A':
        return Icon(Icons.sort_by_alpha, size: 20.h, color: AppColors.textGrey);
      default:
        return Icon(Icons.sort, size: 20.h, color: AppColors.textGrey);
    }
  }

  // Helper method to remove symbol suffixes (.c, .r, etc.)
  // Handles both cases: symbols WITH suffix (EURUSD.c) and WITHOUT suffix (EURUSD)
  // Returns cleaned symbol for display purposes only
  String _removeSymbolSuffix(String symbol) {
    // If symbol has suffix (contains '.'), remove it
    // If symbol has no suffix, return as-is
    if (symbol.contains('.')) {
      return symbol.substring(0, symbol.lastIndexOf('.'));
    }
    return symbol; // No suffix, return original
  }

  String _formatSpreadDiff(double spreadDiff) {
    // Convert to string and remove leading zeros and decimal point
    String formatted = spreadDiff.toString();

    // Remove leading zeros and decimal point
    // For example: 0.00003 -> 3, 0.03 -> 3, 0.0012 -> 12
    if (formatted.contains('.')) {
      // Split by decimal point
      List<String> parts = formatted.split('.');
      String integerPart = parts[0];
      String decimalPart = parts[1];

      // If integer part is 0, remove it and leading zeros from decimal part
      if (integerPart == '0') {
        // Remove leading zeros from decimal part
        String trimmedDecimal = decimalPart.replaceFirst(RegExp(r'^0+'), '');
        return trimmedDecimal.isEmpty ? '0' : trimmedDecimal;
      } else {
        // If integer part is not 0, return it
        return integerPart;
      }
    }

    return formatted;
  }

  /// Get the flag SVG path based on the instrument symbol
  /// Extracts currency code from symbol (e.g., EURUSD -> EUR)
  /// Returns path like 'assets/svg/flags/eur.svg'
  String _getFlagPath(String symbol) {
    // Remove suffix if present (e.g., EURUSD.c -> EURUSD)
    String cleanSymbol =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;

    // Extract first currency code (typically first 3 characters)
    // For pairs like EURUSD, GBPUSD, etc.
    return 'assets/svg/flags/${cleanSymbol.toLowerCase()}.svg';
  }

  /// Build flag icon widget - Direct rendering for max performance
  Widget _buildFlagIcon(String symbol, {double? size}) {
    final flagPath = _getFlagPath(symbol);
    final double box = (size ?? 40.w).toDouble();

    // Direct rendering without async checks
    // This eliminates the "freezing" caused by file I/O on the UI thread
    return SizedBox(
      width: box,
      height: box,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Padding(
            padding: EdgeInsets.all((box * 0.12).clamp(3.0, 5.0)),
            child: SvgPicture.asset(
              flagPath,
              fit: BoxFit.cover,
              // If asset is missing, it will just log a warning but won't crash/freeze
              placeholderBuilder: (context) => _buildFallbackFlag(),
            ),
          ),
        ),
      ),
    );
  }

  // Helper for fallback flag (used by placeholderBuilder)
  Widget _buildFallbackFlag() {
    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.flag, color: AppColors.primary, size: 20.w),
    );
  }

  void _onSearchTextChanged() {
    final query = _searchController.text;

    // Cancel previous timer if exists
    _searchDebounceTimer?.cancel();

    // If query is less than minimum length, clear search
    if (query.length < _minSearchLength) {
      _controller.searchInstruments('');
      return;
    }

    // Debounce: wait 300ms after user stops typing before searching
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _controller.searchInstruments(query);
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }
}

// ✅ PERFORMANCE: Separate widget for Bid price column
// Isolates repaints to only this column when bid price updates
class _BidPriceColumn extends StatelessWidget {
  final String symbol;
  final InstrumentsController controller;
  final double? dayLow;
  final int digits;
  final bool compact;

  const _BidPriceColumn({
    required this.symbol,
    required this.controller,
    required this.dayLow,
    required this.digits,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ PERFORMANCE FIX: Use Obx to observe only the bid price for this symbol
        // This ensures only the price text updates, not the entire widget
        Obx(() {
          final priceData = controller.priceRx(symbol).value;
          final dayLowValue = priceData.dayLow > 0 ? priceData.dayLow : dayLow;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: _buildPriceTextSpans(
                    priceData.bid,
                    AppColors.red,
                    digits,
                    compact: compact,
                  ),
                ),
              ),
              if (dayLowValue != null) ...[
                SizedBox(height: (compact ? 3.0 : 1.0).h),
                RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'L: ',
                        style: AppTextStyles.caption.copyWith(
                          fontFamily: 'Roboto',
                          fontSize: 9.sp,
                          color: AppColors.textGrey,
                          height: 1.0,
                        ),
                      ),
                      TextSpan(
                        text: PrecisionHelper.formatPrice(
                          dayLowValue,
                          decimals: digits,
                        ),
                        style: AppTextStyles.caption.copyWith(
                          fontFamily: 'Roboto',
                          fontSize: 9.sp,
                          color: AppColors.textGrey,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }

  List<InlineSpan> _buildPriceTextSpans(
    dynamic price,
    Color color,
    int digits, {
    required bool compact,
  }) {
    String priceStr = PrecisionHelper.formatPrice(price, decimals: digits);

    if (priceStr.length < 3) {
      return [
        TextSpan(
          text: priceStr,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: (compact ? 14.5 : 14.0).sp,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ];
    }

    String lastDigit = priceStr.substring(priceStr.length - 1);
    String bigPart = "";
    String prefix = "";

    if (priceStr.length >= 3) {
      bigPart = priceStr.substring(priceStr.length - 3, priceStr.length - 1);
      prefix = priceStr.substring(0, priceStr.length - 3);
    } else {
      prefix = priceStr.substring(0, priceStr.length - 1);
    }

    return [
      TextSpan(
        text: prefix,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: (compact ? 14.5 : 14.0).sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      TextSpan(
        text: bigPart,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: (compact ? 20.0 : 20.0).sp,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: Transform.translate(
          offset: const Offset(0, -4),
          child: Text(
            lastDigit,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: (compact ? 11.0 : 10.0).sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }
}

// ✅ PERFORMANCE: Separate widget for Ask price column
// Isolates repaints to only this column when ask price updates
class _AskPriceColumn extends StatelessWidget {
  final String symbol;
  final InstrumentsController controller;
  final double? dayHigh;
  final int digits;
  final bool compact;

  const _AskPriceColumn({
    required this.symbol,
    required this.controller,
    required this.dayHigh,
    required this.digits,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final Color askColor = compact ? AppColors.primary : AppColors.green;
    return Obx(() {
      final priceData = controller.priceRx(symbol).value;
      final dayHighValue = priceData.dayHigh > 0 ? priceData.dayHigh : dayHigh;
      return Column(
        crossAxisAlignment:
            compact ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: _buildPriceTextSpans(
                priceData.ask,
                askColor,
                digits,
                compact: compact,
              ),
            ),
          ),
          if (dayHighValue != null) ...[
            SizedBox(height: (compact ? 3.0 : 1.0).h),
            RichText(
              textAlign: TextAlign.left,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'H: ',
                    style: AppTextStyles.caption.copyWith(
                      fontFamily: 'Roboto',
                      fontSize: 9.sp,
                      color: AppColors.textGrey,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: PrecisionHelper.formatPrice(
                      dayHighValue,
                      decimals: digits,
                    ),
                    style: AppTextStyles.caption.copyWith(
                      fontFamily: 'Roboto',
                      fontSize: 9.sp,
                      color: AppColors.textGrey,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  List<InlineSpan> _buildPriceTextSpans(
    dynamic price,
    Color color,
    int digits, {
    required bool compact,
  }) {
    String priceStr = PrecisionHelper.formatPrice(price, decimals: digits);

    if (priceStr.length < 3) {
      return [
        TextSpan(
          text: priceStr,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: (compact ? 14.5 : 14.0).sp,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ];
    }

    String lastDigit = priceStr.substring(priceStr.length - 1);
    String bigPart = "";
    String prefix = "";

    if (priceStr.length >= 3) {
      bigPart = priceStr.substring(priceStr.length - 3, priceStr.length - 1);
      prefix = priceStr.substring(0, priceStr.length - 3);
    } else {
      prefix = priceStr.substring(0, priceStr.length - 1);
    }

    return [
      TextSpan(
        text: prefix,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: (compact ? 14.5 : 14.0).sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      TextSpan(
        text: bigPart,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: (compact ? 20.0 : 20.0).sp,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: Transform.translate(
          offset: const Offset(0, -4),
          child: Text(
            lastDigit,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: (compact ? 11.0 : 10.0).sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }
}

class _FavoriteButton extends StatelessWidget {
  final String symbol;
  final InstrumentsController controller;

  const _FavoriteButton({required this.symbol, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        controller.toggleFavorite(symbol);
      },
      child: Obx(() {
        final favs = controller.favoriteInstruments;
        final isFavorite =
            favs.contains(symbol) ||
            favs.contains('$symbol.c') ||
            favs.contains(symbol.replaceAll('.c', ''));
        final Color borderColor =
            isFavorite ? AppColors.primary : AppColors.primary.withOpacity(0.6);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
            color: isFavorite ? AppColors.primary : Colors.transparent,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child:
                isFavorite
                    ? Icon(
                      Icons.check,
                      key: const ValueKey('fav_on'),
                      size: 14.w,
                      color: AppColors.whiteColor,
                    )
                    : Icon(
                      Icons.add,
                      key: const ValueKey('fav_off'),
                      size: 14.w,
                      color: AppColors.primary,
                    ),
          ),
        );
      }),
    );
  }
}
