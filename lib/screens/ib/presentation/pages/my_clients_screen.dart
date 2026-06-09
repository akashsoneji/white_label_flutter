import 'dart:async';

import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/models/ib_models.dart';

class MyClientsScreen extends StatefulWidget {
  const MyClientsScreen({super.key});

  @override
  State<MyClientsScreen> createState() => _MyClientsScreenState();
}

class _MyClientsScreenState extends State<MyClientsScreen> {
  int _selectedTabIndex = 0; // 0: Client List, 1: IB List, 2: Trade History
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _tradeHistorySearchFocusNode = FocusNode();
  final ScrollController _pageScrollController = ScrollController();
  bool _statsExpanded = false;
  IBClient? _selectedSubIB;
  List<IBClient> _ibHierarchy =
      []; // Track hierarchy: [Master, Sub-IB, Sub-IB's Sub-IB, ...]
  Map<int, bool> _expandedItems = {}; // Track expanded state for each item
  int _tradeHistoryDisplayLimit = 10; // Show 10 items initially
  bool _isLoadingMoreTrades = false;
  late IBController ibController;
  late AuthController authController;
  final TextEditingController _clientSearchController = TextEditingController();
  Timer? _clientSearchDebounce;

  @override
  void initState() {
    super.initState();
    // Get or create IBController
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    authController = Get.find<AuthController>();
    // Initialize hierarchy
    _ibHierarchy = [];
    _selectedSubIB = null;
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _tradeHistorySearchFocusNode.addListener(_onSearchFocusChanged);
    // Load all data on screen load
    _loadMyClientsData();
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus || _tradeHistorySearchFocusNode.hasFocus) {
      if (_statsExpanded && mounted) {
        setState(() => _statsExpanded = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _tradeHistorySearchFocusNode.removeListener(_onSearchFocusChanged);
    _tradeHistorySearchFocusNode.dispose();
    _pageScrollController.dispose();
    _clientSearchController.dispose();
    _clientSearchDebounce?.cancel();
    super.dispose();
  }

  /// Opens Trade History tab and loads trades for [client].
  Future<void> _openTradeHistoryForClient(IBClient client) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final clientId = client.id;
    if (clientId == null) {
      CustomToastService.showError(
        title: 'Unavailable',
        message: 'Cannot load trade history without a client ID',
      );
      return;
    }

    setState(() {
      _selectedTabIndex = 2;
      _expandedItems.clear();
    });

    await ibController.selectClientForTradeHistory(
      clientId: clientId,
      clientName: client.name ?? 'Client',
    );
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    _expandedItems.clear();
  }

  void _onClientSearchChanged(IBController controller, String value) {
    _clientSearchDebounce?.cancel();
    _clientSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      controller.searchClients(query: value, page: 1);
    });
  }

  Future<void> _loadMyClientsData({int? subIbId}) async {
    // CRITICAL: Clear old data FIRST before loading new data
    // This ensures old data doesn't show when switching sub-IBs
    ibController.ibClients.clear();
    ibController.ibSubIBs.clear();
    ibController.ibTradeHistory.clear();
    ibController.ibStats.value = null;

    setState(() {
      _expandedItems.clear();
      _tradeHistoryDisplayLimit = 10; // Reset to 10 when loading new data
      _isLoadingMoreTrades = false;
    });

    // Set loading state immediately
    ibController.isLoading.value = true;
    ibController.update(); // Update UI to show loading and cleared data

    // Call all APIs sequentially with future tasks (one by one)
    // This ensures proper loading and data consistency
    try {
      print('🔄 Loading data for sub_ib_id: $subIbId');

      if (subIbId == null) {
        // INITIAL LOAD - Call 4 APIs for Master IB
        print('📱 INITIAL LOAD - Loading Master IB data');

        // API 1: /api/user/ib/stats
        print('📞 API 1: Calling getIBStats (Master)');
        await ibController.getIBStats(showLoading: false);
        if (mounted) {
          setState(() {});
          ibController.update();
        }

        // API 2: /api/user/ib/clients
        print('📞 API 2: Calling getIBClients (Master)');
        await ibController.getIBClients(showLoading: false);
        if (mounted) {
          setState(() {});
          ibController.update();
        }

        // API 3: /api/user/ib/sub-ibs
        print('📞 API 3: Calling getIBSubIBs (Master)');
        await ibController.getIBSubIBs(showLoading: false);
        if (mounted) {
          setState(() {});
          ibController.update();
        }

        // API 4: /api/user/ib/trade-history
        print('📞 API 4: Calling getIBTradeHistory (Master)');
        await ibController.getIBTradeHistory(showLoading: false);
        if (mounted) {
          setState(() {});
          ibController.update();
        }

        print('✅ All 4 Master IB APIs loaded successfully');
      } else {
        // SUB-IB SELECTED - Call 4 different APIs with sub_ib_id
        print('📱 SUB-IB SELECTED - Loading Sub-IB data for ID: $subIbId');

        // API 5: /api/user/ib/sub-ib-structure/{id}
        print('📞 API 5: Calling getIBSubIbStructure for sub_ib_id: $subIbId');
        await ibController.getIBSubIbStructure(
          subIbId: subIbId,
          showLoading: false,
        );
        if (mounted) {
          setState(() {});
          ibController.update();
        }

        // API 6: /api/user/ib/sub-ib-sub-ibs/{id}
        print('📞 API 6: Calling getIBSubIBs for sub_ib_id: $subIbId');
        await ibController.getIBSubIBs(subIbId: subIbId, showLoading: false);
        if (mounted) {
          setState(() {});
          ibController.update();
        }

        // API 7: /api/user/ib/sub-ib-stats/{id}
        print('📞 API 7: Calling getIBSubIbStats for sub_ib_id: $subIbId');
        await ibController.getIBSubIbStats(
          subIbId: subIbId,
          showLoading: false,
        );
        if (mounted) {
          setState(() {});
          ibController.update();
        }

        // API 8: /api/user/ib/trade-history?sub_ib_id={id}
        print('📞 API 8: Calling getIBTradeHistory for sub_ib_id: $subIbId');
        await ibController.getIBTradeHistory(
          subIbId: subIbId,
          showLoading: false,
        );
        if (mounted) {
          setState(() {});
          ibController.update();
        }

        print('✅ All 4 Sub-IB APIs loaded successfully for ID: $subIbId');
      }
    } catch (e) {
      // Error handling
      print('❌ Error loading data: $e');
    } finally {
      // Always set loading to false when done
      if (mounted) {
        ibController.isLoading.value = false;
        setState(() {}); // Force UI rebuild
        ibController.update(); // Update GetBuilder
      }
    }

    if (mounted) {
      // First, show first 10 items immediately
      setState(() {
        final allTrades = ibController.ibTradeHistory;
        if (allTrades.length > 10) {
          _tradeHistoryDisplayLimit = 10; // Show only first 10
        } else {
          _tradeHistoryDisplayLimit =
              allTrades.length; // Show all if less than 10
        }
      });
      ibController.update(); // Update GetBuilder to show first 10 items

      // Then load remaining items in background
      _loadMoreTradesInBackground();
    }
  }

  Future<void> _loadMoreTradesInBackground() async {
    if (_isLoadingMoreTrades) return;

    final allTrades = ibController.ibTradeHistory;

    // If we already have all items displayed, no need to load more
    if (allTrades.length <= _tradeHistoryDisplayLimit) {
      return;
    }

    setState(() {
      _isLoadingMoreTrades = true;
    });

    // Wait a bit to ensure first 10 items are rendered
    await Future.delayed(const Duration(milliseconds: 800));

    // Now expand to show all remaining trades
    if (mounted) {
      setState(() {
        _tradeHistoryDisplayLimit = allTrades.length;
        _isLoadingMoreTrades = false;
      });
      ibController.update(); // Update GetBuilder to show all items
    }
  }

  void _onSubIBClicked(IBClient subIB) {
    print('🔄 Switching to Sub-IB: ${subIB.name} (ID: ${subIB.id})');

    setState(() {
      // Add to hierarchy
      if (_selectedSubIB == null) {
        // First level sub-IB
        _ibHierarchy = [subIB];
      } else {
        // Nested sub-IB
        _ibHierarchy.add(subIB);
      }
      _selectedSubIB = subIB;
      _clearSearch();
    });

    // CRITICAL: Clear old data immediately when switching sub-IBs
    // This prevents old data from showing
    ibController.ibClients.clear();
    ibController.ibSubIBs.clear();
    ibController.ibTradeHistory.clear();
    ibController.ibStats.value = null;

    // Force loading state to true immediately to prevent showing old data
    ibController.isLoading.value = true;
    ibController.update(); // Update UI immediately to show loading state

    // Force setState to rebuild UI with loading state
    setState(() {});

    // Call all APIs with this sub_ib_id - ALL APIs will be called again
    // This ensures fresh data is loaded for the selected sub-IB
    print('📞 Calling _loadMyClientsData with sub_ib_id: ${subIB.id}');
    _loadMyClientsData(subIbId: subIB.id);
  }

  void _backToMasterIB() {
    setState(() {
      if (_ibHierarchy.isNotEmpty) {
        _ibHierarchy.removeLast();
        _selectedSubIB = _ibHierarchy.isNotEmpty ? _ibHierarchy.last : null;
      } else {
        _selectedSubIB = null;
      }
      _clearSearch();
    });
    // Load data for the parent level
    final parentId = _ibHierarchy.isNotEmpty ? _ibHierarchy.last.id : null;
    _loadMyClientsData(subIbId: parentId);
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'N/A';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  List<IBClient> _getFilteredClients() {
    // Show all clients (both regular clients and sub-IBs) in the same list
    // Sort: Regular clients first, then sub-IBs (not sub-IBs at top)
    final allClients = ibController.ibClients;
    if (allClients.isEmpty) return [];

    // Separate clients and sub-IBs
    final regularClients = <IBClient>[];
    final subIBs = <IBClient>[];

    for (var client in allClients) {
      if (client.ibType == 'sub-ib' && client.isSubIbApproved == true) {
        subIBs.add(client);
      } else {
        regularClients.add(client);
      }
    }

    // Sort each group alphabetically
    regularClients.sort((a, b) {
      final nameA = (a.name ?? '').toLowerCase();
      final nameB = (b.name ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });

    subIBs.sort((a, b) {
      final nameA = (a.name ?? '').toLowerCase();
      final nameB = (b.name ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });

    // Combine: clients first, then sub-IBs
    final sortedClients = [...regularClients, ...subIBs];

    if (_searchQuery.isEmpty) return sortedClients;
    return sortedClients
        .where(
          (client) =>
              (client.name?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false) ||
              (client.email?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  List<IBClient> _getFilteredSubIBs() {
    // Get sub-IBs from both ibSubIBs and ibClients (where ib_type is 'sub-ib')
    final subIBsFromList = ibController.ibSubIBs;
    final subIBsFromClients =
        ibController.ibClients
            .where(
              (client) =>
                  client.ibType == 'sub-ib' && client.isSubIbApproved == true,
            )
            .toList();

    // Combine and remove duplicates
    final allSubIBs = <IBClient>[];
    final seenIds = <int>{};

    for (var subIB in subIBsFromList) {
      if (subIB.id != null && !seenIds.contains(subIB.id)) {
        allSubIBs.add(subIB);
        seenIds.add(subIB.id!);
      }
    }

    for (var subIB in subIBsFromClients) {
      if (subIB.id != null && !seenIds.contains(subIB.id)) {
        allSubIBs.add(subIB);
        seenIds.add(subIB.id!);
      }
    }

    if (allSubIBs.isEmpty) return [];
    if (_searchQuery.isEmpty) return allSubIBs;
    return allSubIBs
        .where(
          (subIB) =>
              (subIB.name?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false) ||
              (subIB.email?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  void _toggleExpand(int index) {
    setState(() {
      _expandedItems[index] = !(_expandedItems[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: Text(
          'My Client',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset(
            "assets/svg/ib_dashboard/home.svg",
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAll(() => const TradingMainScreen()),
        ),
        centerTitle: true,
        // leading: IconButton(
        //   icon: SvgPicture.asset(
        //     "assets/svg/trade/arro_back.svg",
        //     colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
        //   ),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
      ),
      body: GetBuilder<IBController>(
        builder: (controller) {
          if (controller.isLoading.value) {
            return Center(
              child: CommonLoadingWidget(
                message: 'Loading data...',
                size: 50.0,
                color: AppColors.primary,
              ),
            );
          }

          final stats = controller.ibStats.value;
          final userFullName = authController.userFullName ?? 'User';

          // Check if we have any data at all (clients, sub-IBs, or stats)
          final hasClients = controller.ibClients.isNotEmpty;
          final hasSubIBs = controller.ibSubIBs.isNotEmpty;
          final hasStats = stats != null;
          final hasAnyData = hasClients || hasSubIBs || hasStats;

          // Only show "No Data Found" if we truly have no data and not loading
          if (!hasAnyData && !controller.isLoading.value) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_off_outlined,
                        size: 64.sp,
                        color: AppColors.primary.withOpacity(0.5),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'No Data Found',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'We couldn\'t find any records for this IB. Please check your connection or try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    ElevatedButton.icon(
                      onPressed:
                          () => _loadMyClientsData(subIbId: _selectedSubIB?.id),
                      icon: Icon(Icons.refresh, size: 20.sp),
                      label: Text('Retry Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.whiteColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Obx(() {
            final compactTradeSearch =
                keyboardOpen &&
                _selectedTabIndex == 2 &&
                controller.selectedClientId.value == null;

            // Subscribe to trade-history reactive updates.
            if (_selectedTabIndex == 2) {
              controller.selectedClientId.value;
              controller.isHistoryLoading.value;
              controller.ibTradeHistory.length;
            }

            return SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh:
                    () => _loadMyClientsData(subIbId: _selectedSubIB?.id),
                backgroundColor: AppColors.whiteColor,
                color: AppColors.primary,
                child: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: CustomScrollView(
                    controller: _pageScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: _buildPageSlivers(
                      controller,
                      stats,
                      userFullName,
                      keyboardOpen,
                      compactTradeSearch,
                    ),
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  /// Space so last list row can scroll above the IB floating nav (extendBody).
  double _fabScrollExtent(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 24.h + kBottomNavigationBarHeight;

  List<Widget> _buildPageSlivers(
    IBController controller,
    dynamic stats,
    String userFullName,
    bool keyboardOpen,
    bool compactTradeSearch,
  ) {
    if (compactTradeSearch) {
      return [
        ..._tradeHistorySearchSlivers(controller, keyboardOpen),
        SliverPadding(
          padding: EdgeInsets.only(bottom: _fabScrollExtent(context)),
        ),
      ];
    }

    final slivers = <Widget>[
      SliverToBoxAdapter(child: _buildHierarchyBreadcrumb(userFullName)),
      if (_selectedTabIndex != 2) SliverToBoxAdapter(child: _buildSearchBar()),
      if (stats != null && !keyboardOpen)
        SliverToBoxAdapter(child: _buildStatsExpandable(stats, userFullName)),
      SliverToBoxAdapter(child: _buildTabs()),
      ..._tabContentSlivers(controller, keyboardOpen),
      SliverPadding(
        padding: EdgeInsets.only(bottom: _fabScrollExtent(context)),
      ),
    ];
    return slivers;
  }

  List<Widget> _tabContentSlivers(IBController controller, bool keyboardOpen) {
    switch (_selectedTabIndex) {
      case 0:
        return _clientListSlivers();
      case 1:
        return _ibListSlivers();
      case 2:
        return _tradeHistorySlivers(controller, keyboardOpen);
      default:
        return _clientListSlivers();
    }
  }

  List<Widget> _clientListSlivers() {
    final filteredClients = _getFilteredClients();
    if (filteredClients.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'No clients found',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final client = filteredClients[index];
            final isExpanded = _expandedItems[index] ?? false;
            return _buildExpandableClientCard(client, index, isExpanded);
          }, childCount: filteredClients.length),
        ),
      ),
    ];
  }

  List<Widget> _ibListSlivers() {
    final filteredSubIBs = _getFilteredSubIBs();
    if (filteredSubIBs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'No Sub-IBs found',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final subIB = filteredSubIBs[index];
            final isExpanded = _expandedItems[index] ?? false;
            return _buildExpandableSubIBCard(subIB, index, isExpanded);
          }, childCount: filteredSubIBs.length),
        ),
      ),
    ];
  }

  List<Widget> _tradeHistorySlivers(
    IBController controller,
    bool keyboardOpen,
  ) {
    final selectedId = controller.selectedClientId.value;
    if (selectedId == null) {
      return _tradeHistorySearchSlivers(controller, keyboardOpen);
    }

    final slivers = <Widget>[
      SliverToBoxAdapter(child: _buildTradeHistoryHeader(controller)),
    ];

    if (controller.isHistoryLoading.value &&
        controller.ibTradeHistory.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
      return slivers;
    }

    final trades = controller.ibTradeHistory;
    if (trades.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'No trade history found.',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
            ),
          ),
        ),
      );
      return slivers;
    }

    final hasMore =
        controller.tradeHistoryPage < controller.tradeHistoryTotalPages;
    slivers.add(
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == trades.length) {
              return _buildLoadMoreButton(
                isLoading: controller.isLoadingMoreTrades,
                onTap: () => controller.loadMoreTradeHistory(),
              );
            }
            return _buildTradeDetailCard(trades[index], index, false);
          }, childCount: trades.length + (hasMore ? 1 : 0)),
        ),
      ),
    );
    return slivers;
  }

  Widget _buildTradeHistoryHeader(IBController controller) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              controller.clearClientSelection();
              controller.clearTradeHistory();
            },
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 18.sp, color: AppColors.primary),
                SizedBox(width: 6.w),
                Text(
                  'Select Client',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              controller.selectedClientName.value ?? 'Client',
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyBreadcrumb(String userFullName) {
    final bannerTitle =
        _selectedSubIB == null
            ? '$userFullName (You)'
            : (_selectedSubIB!.name ?? 'Sub IB');

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  color: AppColors.whiteColor,
                  size: 22.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    bannerTitle,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedSubIB != null) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _backToMasterIB,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.primary,
                            size: 14.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            _ibHierarchy.length > 1
                                ? 'Back to Sub IB'
                                : 'Back to Master IB',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '${ibController.ibClients.length} clients under ${_selectedSubIB?.name ?? "Sub IB"}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textGrey,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsExpandable(dynamic stats, String userFullName) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Material(
        color: AppColors.whiteColor,
        elevation: 0,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppColors.border.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _statsExpanded = !_statsExpanded),
                borderRadius: BorderRadius.circular(12.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Show More',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'View statistics & performance overview',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _statsExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 24.sp,
                      ),
                    ],
                  ),
                ),
              ),
              if (_statsExpanded) _buildStatisticsGrid(stats, userFullName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Client List', 0, Icons.person)),
          SizedBox(width: 8.w),
          Expanded(child: _buildTabButton('IB List', 1, Icons.star)),
          SizedBox(width: 8.w),
          Expanded(child: _buildTabButton('Trade History', 2, Icons.list)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() {
          _selectedTabIndex = index;
          _expandedItems.clear();
        });
        if (index == 2) {
          _loadMoreTradesInBackground();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isSelected ? AppColors.whiteColor : AppColors.primary,
            ),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.whiteColor : AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (index == 2 && ibController.isHistoryLoading.value) ...[
              SizedBox(width: 4.w),
              SizedBox(
                width: 10.w,
                height: 10.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSelected ? AppColors.whiteColor : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final String hintText;
    switch (_selectedTabIndex) {
      case 0:
        hintText =
            _selectedSubIB == null
                ? 'Search clients by name or email...'
                : 'Search clients under ${_selectedSubIB!.name ?? "Sub IB"}...';
        break;
      case 1:
        hintText =
            _selectedSubIB == null
                ? 'Search Sub IBs by name or email...'
                : 'Search nested Sub IBs...';
        break;
      default:
        hintText = 'Search trade history...';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: RTLHelper.rtlTextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          hintText: hintText,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _expandedItems.clear();
            });
          },
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22.sp,
            color: AppColors.textGrey,
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    onPressed: () {
                      setState(() => _clearSearch());
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20.sp,
                      color: AppColors.textGrey,
                    ),
                  )
                  : null,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
            filled: true,
            fillColor: AppColors.whiteColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid(dynamic stats, String userFullName) {
    if (stats == null) {
      return const SizedBox.shrink();
    }

    // Count total sub-IBs from the list
    final totalSubIBs = ibController.ibSubIBs.length;

    // Parse available rebate (it's a string in the model)
    final availableRebateValue =
        stats.availableRebate != null
            ? (double.tryParse(stats.availableRebate.toString()) ?? 0.0)
            : 0.0;

    // Parse total rebate generated (it's a string in the model)
    final totalRebateValue =
        stats.totalRebateGenerated != null
            ? (double.tryParse(stats.totalRebateGenerated.toString()) ?? 0.0)
            : 0.0;

    final maxGridHeight = MediaQuery.sizeOf(context).height * 0.32;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxGridHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 0.85,
          children: [
            // Row 1: First card - Show "Master IB" or "Sub IB" based on selection
            _buildStatCard(
              icon: Icons.account_balance_wallet,
              label: _selectedSubIB == null ? 'Master IB' : 'Sub IB',
              value: _selectedSubIB?.name ?? userFullName,
            ),
            _buildStatCard(
              icon: Icons.trending_up,
              label: 'Total Clients',
              value:
                  (stats.totalClients ?? ibController.ibClients.length)
                      .toString(),
            ),
            _buildStatCard(
              icon: Icons.arrow_downward,
              label: 'Total Deposit',
              value: '\$${(stats.totalDeposited ?? 0.0).toStringAsFixed(2)}',
            ),
            _buildStatCard(
              icon: Icons.arrow_upward,
              label: 'Total Withdraw',
              value: '\$${(stats.totalWithdrawal ?? 0.0).toStringAsFixed(2)}',
            ),
            // Row 2: Next 4 cards
            _buildStatCard(
              icon: Icons.account_balance_wallet,
              label: 'Total Equity',
              value: '\$${(stats.totalEquity ?? 0.0).toStringAsFixed(2)}',
            ),
            _buildStatCard(
              icon: Icons.people,
              label: 'Total Sub IB',
              value: totalSubIBs.toString(),
            ),
            _buildStatCard(
              icon: Icons.description,
              label: 'Total Lots',
              value: (stats.totalLots ?? 0.0).toStringAsFixed(2),
            ),
            _buildStatCard(
              icon: Icons.account_balance,
              label: 'Total Rebate',
              value: '\$${totalRebateValue.toStringAsFixed(2)}',
            ),
            // Row 3: Last 2 cards
            _buildStatCard(
              icon: Icons.wallet,
              label: 'Total Withdrawal Rebate',
              value:
                  '\$${(stats.ibWithdrawalRebate ?? 0.0).toStringAsFixed(2)}',
            ),
            _buildStatCard(
              icon: Icons.wallet,
              label: 'Available Rebate',
              value: '\$${availableRebateValue.toStringAsFixed(2)}',
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.successBg : AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border:
            isHighlighted
                ? Border.all(color: AppColors.green, width: 1.5)
                : Border.all(color: AppColors.border.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(icon, size: 18.sp, color: AppColors.primary),
          ),
          SizedBox(height: 6.h),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color:
                      isHighlighted ? AppColors.green : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableClientCard(
    IBClient client,
    int index,
    bool isExpanded,
  ) {
    // Determine if this is a sub-IB or regular client
    final isSubIB = client.ibType == 'sub-ib' && client.isSubIbApproved == true;

    // Get ALL data dynamically from API response
    // Sub-IB count from API
    final subIbCount = isSubIB ? (client.subIbCount ?? 0) : 0;

    // Client count: Count how many regular clients (non-sub-IBs) are in current view
    // When viewing a sub-IB's data, count clients that are NOT sub-IBs
    // Client count from API model
    final clientCount = client.totalClients ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _openTradeHistoryForClient(client),
            onLongPress: () => _toggleExpand(index),
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(client.name),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Name and Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name ?? 'N/A',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          client.email ?? '',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                          ),
                        ),

                        // SizedBox(height: 4.h),
                        // Row(
                        //   children: [
                        //     Icon(
                        //       Icons.person,
                        //       size: 12.sp,
                        //       color: AppColors.textGrey,
                        //     ),
                        //     SizedBox(width: 4.w),
                        //     Text(
                        //       '${clientCount} Clients',
                        //       style: TextStyle(
                        //         fontSize: 11.sp,
                        //         color: AppColors.textGrey,
                        //       ),
                        //     ),
                        //     SizedBox(width: 12.w),
                        //     Icon(
                        //       Icons.star,
                        //       size: 12.sp,
                        //       color: AppColors.textGrey,
                        //     ),
                        //     SizedBox(width: 4.w),
                        //     Text(
                        //       '$subIbCount Sub IBs',
                        //       style: TextStyle(
                        //         fontSize: 11.sp,
                        //         color: AppColors.textGrey,
                        //       ),
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
                  ),
                  // View and Arrow buttons
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: IconButton(
                      iconSize: 20.sp,
                      padding: EdgeInsets.zero,
                      tooltip: 'View details',
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 18.sp,
                        color: AppColors.whiteColor,
                      ),
                      onPressed: () => _toggleExpand(index),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: IconButton(
                      iconSize: 20.sp,
                      padding: EdgeInsets.zero,
                      tooltip: 'Trade history',
                      icon: Icon(
                        Icons.menu,
                        size: 18.sp,
                        color: AppColors.whiteColor,
                      ),
                      onPressed: () => _openTradeHistoryForClient(client),
                    ),
                  ),
                  if (client.ibType == 'sub-ib' &&
                      client.isSubIbApproved == true &&
                      client.id != null) ...[
                    SizedBox(width: 6.w),

                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Open Sub IB',
                        icon: Icon(
                          Icons.arrow_forward,
                          size: 16.sp,
                          color: AppColors.whiteColor,
                        ),
                        onPressed: () => _onSubIBClicked(client),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8.r),
                  bottomRight: Radius.circular(8.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Account Number',
                    client.accountNumber ?? 'N/A',
                  ),
                  _buildDetailRow('Total Clients', '${clientCount}'),
                  _buildDetailRow(
                    'Total Deposit',
                    '\$${(client.deposit ?? client.totalDeposit ?? 0.0).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Total Withdraw',
                    '\$${(client.withdraw ?? 0.0).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Total Rebate',
                    '\$${(client.rebate ?? client.totalRebate ?? 0.0).toStringAsFixed(2)}',
                  ),
                  if (client.lots != null)
                    _buildDetailRow(
                      'Total Lots',
                      client.lots!.toStringAsFixed(2),
                    ),
                  if (client.equity != null)
                    _buildDetailRow(
                      'Total Equity',
                      '\$${client.equity!.toStringAsFixed(2)}',
                    ),
                  _buildDetailRow('Total Sub IBs', '$subIbCount'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSubIBCard(IBClient subIB, int index, bool isExpanded) {
    // Get ALL data dynamically from API response - NO static data
    // Sub-IB count from API
    final subIbCount = subIB.subIbCount ?? 0;

    // Client count: Count how many regular clients (non-sub-IBs) are in current view
    // This is dynamic data from API - when we load data for this sub-IB, we count clients
    // For now, we'll show 0 until data is loaded for this specific sub-IB
    // When user clicks to view this sub-IB, the API will be called with sub_ib_id
    // and then we can count the clients dynamically
    int clientCount = 0;
    // If we're currently viewing this sub-IB's data, count its clients
    if (_selectedSubIB?.id == subIB.id) {
      clientCount =
          ibController.ibClients
              .where((c) => c.ibType != 'sub-ib' || c.isSubIbApproved != true)
              .length;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _openTradeHistoryForClient(subIB),
            onLongPress: () => _toggleExpand(index),
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(subIB.name),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Name and Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subIB.name ?? 'N/A',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          subIB.email ?? '',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 12.sp,
                              color: AppColors.textGrey,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '${clientCount} Clients',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Icon(
                              Icons.star,
                              size: 12.sp,
                              color: AppColors.textGrey,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '$subIbCount Sub IBs',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'View details',
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                    onPressed: () => _toggleExpand(index),
                  ),
                  IconButton(
                    tooltip: 'Trade history',
                    icon: Icon(
                      Icons.history_rounded,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                    onPressed: () => _openTradeHistoryForClient(subIB),
                  ),
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Open Sub IB',
                      icon: Icon(
                        Icons.arrow_forward,
                        size: 16.sp,
                        color: AppColors.whiteColor,
                      ),
                      onPressed: () => _onSubIBClicked(subIB),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8.r),
                  bottomRight: Radius.circular(8.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Account Number',
                    subIB.accountNumber ?? 'N/A',
                  ),
                  _buildDetailRow('Total Clients', '${clientCount}'),
                  _buildDetailRow(
                    'Total Deposit',
                    '\$${(subIB.deposit ?? subIB.totalDeposit ?? 0.0).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Total Withdraw',
                    '\$${(subIB.withdraw ?? 0.0).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Total Rebate',
                    '\$${(subIB.rebate ?? subIB.totalRebate ?? 0.0).toStringAsFixed(2)}',
                  ),
                  if (subIB.lots != null)
                    _buildDetailRow(
                      'Total Lots',
                      subIB.lots!.toStringAsFixed(2),
                    ),
                  if (subIB.equity != null)
                    _buildDetailRow(
                      'Total Equity',
                      '\$${subIB.equity!.toStringAsFixed(2)}',
                    ),
                  _buildDetailRow('Total Sub IBs', '$subIbCount'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _tradeHistorySearchSlivers(
    IBController controller,
    bool keyboardOpen,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _clientSearchController,
                  focusNode: _tradeHistorySearchFocusNode,
                  style: TextStyle(fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: 'Search name, email, or account...',
                    hintStyle: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textGrey,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20.sp,
                      color: AppColors.textGrey,
                    ),
                    filled: true,
                    fillColor: AppColors.whiteColor,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onChanged: (value) {
                    _onClientSearchChanged(controller, value);
                  },
                  onSubmitted: (value) {
                    controller.searchClients(query: value, page: 1);
                  },
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () {
                  controller.searchClients(
                    query: _clientSearchController.text,
                    page: 1,
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.whiteColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ..._tradeHistorySearchResultSlivers(controller, keyboardOpen),
    ];
  }

  List<Widget> _tradeHistorySearchResultSlivers(
    IBController controller,
    bool keyboardOpen,
  ) {
    if (controller.isSearchingClients) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      ];
    }

    final results = controller.clientSearchResults;

    if (results.isEmpty) {
      if (_clientSearchController.text.isNotEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'No clients found for "${_clientSearchController.text}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
                ),
              ),
            ),
          ),
        ];
      }

      if (!keyboardOpen) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_search,
                  size: 40.sp,
                  color: AppColors.textGrey.withValues(alpha: 0.4),
                ),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Text(
                    'Search for a client to view their trade history',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      }

      return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == results.length) {
              return _buildLoadMoreButton(
                isLoading: controller.isLoadingMoreClients,
                onTap: () => controller.loadMoreSearchClients(),
              );
            }
            return _buildClientSelectCard(results[index], controller);
          },
          childCount:
              results.length +
              (controller.clientsPage < controller.clientsTotalPages ? 1 : 0),
        ),
      ),
    ];
  }

  /// Load more button widget
  Widget _buildLoadMoreButton({
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child:
              isLoading
                  ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  )
                  : Text(
                    'Load More',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ),
    );
  }

  /// Client selector card
  Widget _buildClientSelectCard(IBClient client, IBController controller) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          _clientSearchController.clear();
          controller.selectClient(client.id ?? 0, client.name ?? 'Client');
          setState(() {});
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(client.name),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      client.email ?? 'N/A',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        _buildClientBadge(
                          'AC: ${client.accountNumber ?? 'N/A'}',
                          AppColors.blue,
                        ),
                        SizedBox(width: 6.w),
                        _buildClientBadge(
                          'Lots: ${client.lots?.toStringAsFixed(1) ?? '0.0'}',
                          AppColors.primary,
                        ),
                        SizedBox(width: 6.w),
                        _buildClientBadge(
                          'Rebate: \$${client.rebate?.toStringAsFixed(2) ?? '0.00'}',
                          AppColors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textGrey, size: 22.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// Trade detail card (per trade, with expandable details)
  Widget _buildTradeDetailCard(
    IBTradeHistory trade,
    int index,
    bool isExpanded,
  ) {
    final isProfit = (trade.profit ?? 0) >= 0;
    final isBuy = trade.type?.toLowerCase() == 'buy';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () {
              setState(() {
                _expandedItems[index] = !isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  // Type indicator (colored circle)
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color:
                          isBuy
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (trade.symbol?.length ?? 0) > 3
                            ? trade.symbol!.substring(0, 3)
                            : (trade.symbol ?? '--'),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: isBuy ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Symbol and type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              trade.symbol ?? 'N/A',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isBuy
                                        ? AppColors.success.withValues(
                                          alpha: 0.1,
                                        )
                                        : AppColors.error.withValues(
                                          alpha: 0.1,
                                        ),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                trade.type?.toUpperCase() ?? '--',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isBuy
                                          ? AppColors.success
                                          : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Vol: ${trade.volume?.toStringAsFixed(2) ?? '0.00'} | ${_formatDate(trade.openTime)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // P/L and commission column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isProfit ? '+' : ''}\$${trade.profit?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: isProfit ? AppColors.success : AppColors.error,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Comm: \$${trade.commission?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20.sp,
                    color: AppColors.textGrey,
                  ),
                ],
              ),
            ),
          ),
          // Expanded details
          if (isExpanded)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10.r),
                  bottomRight: Radius.circular(10.r),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Account', trade.mt5Account ?? 'N/A'),
                  _buildDetailRow('Open Price', trade.openPrice ?? 'N/A'),
                  _buildDetailRow('Close Price', trade.closePrice ?? 'N/A'),
                  _buildDetailRow(
                    'Volume',
                    '${trade.volume?.toString() ?? '0'} lots',
                  ),
                  _buildDetailRow(
                    'Commission',
                    '\$${trade.commission?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  _buildDetailRow(
                    'P/L',
                    '${isProfit ? '+' : ''}\$${trade.profit?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  _buildDetailRow('Open Time', _formatDateTime(trade.openTime)),
                  _buildDetailRow(
                    'Close Time',
                    _formatDateTime(trade.closeTime),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
