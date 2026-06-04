import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class MyClientsScreen extends StatefulWidget {
  const MyClientsScreen({super.key});

  @override
  State<MyClientsScreen> createState() => _MyClientsScreenState();
}

class _MyClientsScreenState extends State<MyClientsScreen> {
  int _selectedTabIndex = 0; // 0: Client List, 1: IB List, 2: Trade History
  String _searchQuery = '';
  IBClient? _selectedSubIB;
  List<IBClient> _ibHierarchy =
      []; // Track hierarchy: [Master, Sub-IB, Sub-IB's Sub-IB, ...]
  Map<int, bool> _expandedItems = {}; // Track expanded state for each item
  int _tradeHistoryDisplayLimit = 10; // Show 10 items initially
  bool _isLoadingMoreTrades = false;
  late IBController ibController;
  late AuthController authController;

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
    // Load all data on screen load
    _loadMyClientsData();
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
      _expandedItems.clear();
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
      _expandedItems.clear();
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

  List<IBTradeHistory> _getFilteredTradeHistory() {
    final allTradeHistory = ibController.ibTradeHistory;
    if (allTradeHistory.isEmpty) return [];

    List<IBTradeHistory> filtered;

    if (_searchQuery.isEmpty) {
      filtered = allTradeHistory;
    } else {
      filtered =
          allTradeHistory
              .where(
                (trade) =>
                    (trade.clientName?.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ??
                        false) ||
                    (trade.clientEmail?.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ??
                        false) ||
                    (trade.symbol?.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ??
                        false),
              )
              .toList();
    }

    // Limit displayed items (for performance)
    // If search is active, show all filtered results
    if (_searchQuery.isEmpty && filtered.length > _tradeHistoryDisplayLimit) {
      return filtered.take(_tradeHistoryDisplayLimit).toList();
    }
    return filtered;
  }

  void _toggleExpand(int index) {
    setState(() {
      _expandedItems[index] = !(_expandedItems[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Client',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        // leading: IconButton(
        //   icon: SvgPicture.asset("assets/svg/trade/arro_back.svg"),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadMyClientsData(subIbId: _selectedSubIB?.id),
        backgroundColor: AppColors.whiteColor,
        color: AppColors.primary,
        child: GetBuilder<IBController>(
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
                            () =>
                                _loadMyClientsData(subIbId: _selectedSubIB?.id),
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

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hierarchy Breadcrumb at top (Master IB -> Sub IB -> Sub IB's Sub IB)
                  _buildHierarchyBreadcrumb(userFullName),

                  // Search Bar
                  _buildSearchBar(),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Statistics Cards Grid (4 cards in 2x2)
                          Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),

                            child: ExpansionTile(
                              iconColor: AppColors.primary,
                              backgroundColor: AppColors.whiteColor,
                              title: Text("Show More"),
                              children: [
                                _buildStatisticsGrid(stats, userFullName),
                                SizedBox(height: 16.h),
                              ],
                            ),
                          ),

                          // Tabs
                          _buildTabs(),

                          SizedBox(height: 12.h),

                          // Tab Content
                          _getTabContent(controller),

                          // Bottom padding for floating navigation bar (safe area + nav bar height + extra spacing)
                          SizedBox(height: 100.h),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHierarchyBreadcrumb(String userFullName) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // First row: Master IB and Sub IB buttons
          Row(
            children: [
              // Master IB (You)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: AppColors.whiteColor, size: 16.sp),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          '$userFullName (You)',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.whiteColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Show Sub IB if exists
              if (_ibHierarchy.isNotEmpty && _ibHierarchy.length >= 1) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.people, color: AppColors.whiteColor, size: 16.sp),
                    // NOTE: Do NOT wrap label in Flexible here because
                    // ElevatedButton.icon already manages its own Flexible/Expanded
                    // internally. Wrapping Text in another Flexible causes
                    // "Incorrect use of ParentDataWidget" errors.
                    label: Text(
                      _ibHierarchy[0].name ?? 'Sub IB',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.whiteColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              // Show Sub IB's Sub IB if exists (current selected)
              if (_selectedSubIB != null && _ibHierarchy.length >= 2) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.person, color: AppColors.whiteColor, size: 16.sp),
                    // NOTE: Same as above – avoid nesting Flexible inside the
                    // internal Row used by ElevatedButton.icon.
                    label: Text(
                      _selectedSubIB!.name ?? 'Sub IB',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.whiteColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Second row: Back button and client count
          if (_selectedSubIB != null) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                InkWell(
                  onTap: _backToMasterIB,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          AppBackButton.assetPath,
                          width: 16.sp,
                          height: 16.sp,
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            AppColors.primary,
                            BlendMode.srcIn,
                          ),
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
                const Spacer(),
                Text(
                  'Showing ${ibController.ibClients.length} clients under ${_selectedSubIB?.name ?? "Sub IB"}',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
        setState(() {
          _selectedTabIndex = index;
          _expandedItems.clear();
        });
        // If switching to Trade History tab, trigger background loading if needed
        if (index == 2) {
          _loadMoreTradesInBackground();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.primary, width: 1),
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
            Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.whiteColor : AppColors.primary,
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
    String hintText;
    if (_selectedSubIB == null) {
      hintText = 'Search Sub IBs...';
    } else {
      hintText = 'Search Sub IB\'s Sub IBs...';
    }
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _expandedItems.clear();
          });
        },
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search,
            size: 20.sp,
            color: AppColors.textGrey,
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

    // Show 10 cards in 4-column grid (4+4+2 layout) matching the image
    return Container(
      padding: EdgeInsets.all(16.w),
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
            value: '\$${(stats.ibWithdrawalRebate ?? 0.0).toStringAsFixed(2)}',
          ),
          _buildStatCard(
            icon: Icons.wallet,
            label: 'Available Rebate',
            value: '\$${availableRebateValue.toStringAsFixed(2)}',
            isHighlighted: true,
          ),
        ],
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
        color: isHighlighted ? Colors.green.shade50 : AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border:
            isHighlighted
                ? Border.all(color: Colors.green.shade700, width: 1.5)
                : Border.all(color: AppColors.border.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                      isHighlighted
                          ? Colors.green.shade700
                          : AppColors.textPrimary,
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

  Widget _getTabContent(IBController controller) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildClientList(controller);
      case 1:
        return _buildIbList(controller);
      case 2:
        return _buildTradeHistory(controller);
      default:
        return _buildClientList(controller);
    }
  }

  Widget _buildClientList(IBController controller) {
    final filteredClients = _getFilteredClients();
    if (filteredClients.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(20.w),
        child: Center(
          child: Text(
            'No clients found',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 16.h,
      ).copyWith(bottom: 20.h),
      itemCount: filteredClients.length,
      itemBuilder: (context, index) {
        final client = filteredClients[index];
        final isExpanded = _expandedItems[index] ?? false;
        return _buildExpandableClientCard(client, index, isExpanded);
      },
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
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpand(index),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
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
                  IconButton(
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      // View details
                      _toggleExpand(index);
                    },
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
                      icon: Icon(
                        Icons.arrow_forward,
                        size: 16.sp,
                        color: AppColors.whiteColor,
                      ),
                      onPressed: () {
                        // Only navigate if this is a sub-IB
                        if (client.ibType == 'sub-ib' &&
                            client.isSubIbApproved == true &&
                            client.id != null) {
                          _onSubIBClicked(client);
                        }
                      },
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

  Widget _buildIbList(IBController controller) {
    final filteredSubIBs = _getFilteredSubIBs();
    if (filteredSubIBs.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(20.w),
        child: Center(
          child: Text(
            'No Sub-IBs found',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 16.h,
      ).copyWith(bottom: 20.h),
      itemCount: filteredSubIBs.length,
      itemBuilder: (context, index) {
        final subIB = filteredSubIBs[index];
        final isExpanded = _expandedItems[index] ?? false;
        return _buildExpandableSubIBCard(subIB, index, isExpanded);
      },
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
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpand(index),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
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
                  // View and Arrow buttons
                  IconButton(
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      // View details
                    },
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

  Widget _buildTradeHistory(IBController controller) {
    final allTradeHistory = controller.ibTradeHistory;
    final filteredTradeHistory = _getFilteredTradeHistory();
    final hasMore =
        allTradeHistory.length > _tradeHistoryDisplayLimit &&
        _searchQuery.isEmpty;

    // Show loading if controller is loading history and no data yet
    if (controller.isHistoryLoading.value && allTradeHistory.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(40.w),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              SizedBox(height: 16.h),
              Text(
                'Fetching trade history...',
                style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredTradeHistory.isEmpty && !controller.isLoading.value) {
      return Padding(
        padding: EdgeInsets.all(20.w),
        child: Center(
          child: Text(
            'No trade history found',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display filtered trade history (limited to _tradeHistoryDisplayLimit)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ).copyWith(bottom: 20.h),
          itemCount: filteredTradeHistory.length,
          itemBuilder: (context, index) {
            final trade = filteredTradeHistory[index];
            final isExpanded = _expandedItems[index] ?? false;
            return _buildExpandableTradeCard(trade, index, isExpanded);
          },
        ),
        // Show loading indicator if loading more in background (local processing)
        if (_isLoadingMoreTrades && hasMore)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Processing more trades...',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        // Show message if all trades are loaded
        if (!_isLoadingMoreTrades &&
            hasMore &&
            filteredTradeHistory.length >= allTradeHistory.length)
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Text(
              'All ${allTradeHistory.length} trades loaded',
              style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandableTradeCard(
    IBTradeHistory trade,
    int index,
    bool isExpanded,
  ) {
    final isProfit = (trade.profit ?? 0) >= 0;
    // Calculate deposit and withdrawal from trade data
    // Assuming profit > 0 means deposit, profit < 0 means withdrawal
    final deposit = isProfit ? (trade.profit ?? 0) : 0.0;
    final withdrawal = !isProfit ? ((trade.profit ?? 0) * -1) : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpand(index),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(trade.clientName),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Name and Symbol
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trade.clientName ?? 'N/A',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${trade.symbol ?? ''} - ${trade.type ?? ''}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profit/Loss
                  Text(
                    '\$${trade.profit?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isProfit ? Colors.green : Colors.red,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textPrimary,
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
                  _buildDetailRow('Client Email', trade.clientEmail ?? 'N/A'),
                  _buildDetailRow('MT5 Account', trade.mt5Account ?? 'N/A'),
                  _buildDetailRow('Volume', '${trade.volume ?? 0}'),
                  _buildDetailRow(
                    'Commission',
                    '\$${trade.commission ?? '0.00'}',
                  ),
                  if (trade.openTime != null)
                    _buildDetailRow('Open Time', trade.openTime!),
                  if (trade.closeTime != null)
                    _buildDetailRow('Close Time', trade.closeTime!),
                  SizedBox(height: 8.h),
                  // Deposit and Withdrawal with colors
                  if (deposit > 0)
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                size: 16.sp,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Deposit',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '\$${deposit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (withdrawal > 0) ...[
                    if (deposit > 0) SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                size: 16.sp,
                                color: Colors.red,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Withdrawal',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '\$${withdrawal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
