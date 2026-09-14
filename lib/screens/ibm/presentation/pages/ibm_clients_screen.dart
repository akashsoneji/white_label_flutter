import 'package:crm_app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_client_profile_screen.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_shimmer_loading.dart';
import 'package:crm_app/services/language_service.dart';

class IbmClientsScreen extends StatefulWidget {
  const IbmClientsScreen({super.key});

  @override
  State<IbmClientsScreen> createState() => _IbmClientsScreenState();
}

class _IbmClientsScreenState extends State<IbmClientsScreen>
    with SingleTickerProviderStateMixin {
  final IbmController controller = Get.find<IbmController>();
  late TabController _sectionTabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _dateFilters = [
    'Today',
    '7D',
    '30D',
    'MTD',
    'All',
    'Custom',
  ];
  String _selectedDateFilter = 'MTD';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Selected Focused Sub-IB node for drilldown 8-card view
  Map<String, dynamic>? _selectedFocusNode;

  // Track expand/collapse state for tree nodes
  bool _isAllExpanded = false;
  final Set<String> _collapsedNodeKeys = {};

  // Lazy loading state for tree nodes
  final Map<String, List<Map<String, dynamic>>> _lazyChildrenCache = {};
  final Set<String> _lazyLoadingKeys = {};

  // Per-node figures keyed by user_id, populated from every
  // /portal/network/{id}/node `people[]` fetch (master + each expand).
  // A node's own figures (deposits/net/lots/earned/branch) live on its
  // PARENT's /node people[] entry, so we index by user_id and overlay at
  // render time. Keyed by int, not a synthesized string, so identity is
  // stable across builds and field name differences.
  final Map<int, Map<String, dynamic>> _nodeFiguresById = {};

  final List<String> _requestTabs = [
    'Waiting on you',
    'With the broker',
    'Approved',
    'Declined',
    'All',
  ];
  String _selectedRequestTab = 'Waiting on you';

  static const Map<String, String> _dateFilterKeys = {
    'Today': 'dc_range_today',
    'All': 'common_all',
    'Custom': 'transaction_history_period_custom',
  };

  static const Map<String, String> _requestTabKeys = {
    'Waiting on you': 'ibm_waiting_on_you_tab',
    'With the broker': 'ibm_with_the_broker',
    'Approved': 'kyc_verification_approved',
    'Declined': 'ibm_declined',
    'All': 'common_all',
  };

  String _dateFilterLabel(String name) {
    final key = _dateFilterKeys[name];
    return key == null ? name : TranslationUtils.tr(key);
  }

  String _requestTabLabel(String name) =>
      TranslationUtils.tr(_requestTabKeys[name] ?? name);

  @override
  void initState() {
    super.initState();
    _sectionTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
      controller.fetchRequests();
    });
  }

  void _refreshAllData() {
    final p = _mapFilterToApi(_selectedDateFilter);
    final from =
        _customStartDate != null
            ? DateFormat('yyyy-MM-dd').format(_customStartDate!)
            : null;
    final to =
        _customEndDate != null
            ? DateFormat('yyyy-MM-dd').format(_customEndDate!)
            : null;

    controller.fetchClients(period: p);
    controller
        .fetchClientsNetworkTree(period: p, from: from, to: to)
        .then((_) => _enrichVisibleTreeRows());
    controller.fetchNetworkTreeSummary();
    controller.fetchNetworkPerformance(period: p);
    controller.fetchNetwork(period: p);
  }

  /// Eagerly fetch `/portal/network/{id}/node` for every sub-IB currently
  /// visible in the tree so row cards show deposits/net/lots/earned/branch
  /// immediately on first paint — matching what the web shows. Network-tree
  /// only returns child counts; the rich per-row figures come from the
  /// per-node endpoint. We previously only fetched on expand, which is why
  /// initial cards rendered with all zeros (looking like blank white cards).
  /// `/portal/network/{id}/node` returns id's direct downline in
  /// `data.people[]`, each entry shaped like the row builder expects
  /// (name, user_id, own[], branch[], sub_ibs, clients_tree). Indexing
  /// figures by user_id lets the row builder overlay them onto the node
  /// regardless of which endpoint the node came from, and avoids the
  /// bug where cached.first (the first CHILD) was copied onto the
  /// parent (causing every row to show identical figures).
  void _applyNodeResponse(int id, List<Map<String, dynamic>> children) {
    final cacheKey = 'node_$id';
    final cleaned = <Map<String, dynamic>>[];
    for (final raw in children) {
      final normalised = _normaliseTreeNode(Map<String, dynamic>.from(raw));
      final uid = int.tryParse(normalised['user_id']?.toString() ?? '');
      if (uid != null && uid > 0) {
        _nodeFiguresById[uid] = normalised;
        cleaned.add(normalised);
      }
    }
    _lazyChildrenCache[cacheKey] = cleaned;
  }

  void _enrichVisibleTreeRows() {
    final treeData = controller.clientsNetworkTreeData;
    if (treeData.isEmpty) return;
    final period = _mapFilterToApi(_selectedDateFilter);

    int? masterId;
    final nodes = treeData['nodes'];
    if (nodes is List && nodes.isNotEmpty && nodes.first is Map) {
      final first = nodes.first as Map;
      masterId =
          int.tryParse(first['ib_user_id']?.toString() ?? '') ??
          int.tryParse(first['user_id']?.toString() ?? '');
    }
    if (masterId == null || masterId <= 0) return;

    final key = 'node_$masterId';
    if (_lazyLoadingKeys.contains(key)) return;
    _lazyLoadingKeys.add(key);
    controller.getNetworkNodeChildren(masterId, period: period).then((people) {
      if (!mounted) {
        _lazyLoadingKeys.remove(key);
        return;
      }
      setState(() {
        _applyNodeResponse(masterId!, people);
        _lazyLoadingKeys.remove(key);
      });
      // Prefetch every L1 sub-IB's own /node so L2 rows render with real
      // name/email/figures on first paint (no expand tap needed).
      for (final row in people) {
        final childId = int.tryParse(row['user_id']?.toString() ?? '') ?? 0;
        final hasDownline =
            (row['sub_ibs'] ?? 0).toString() != '0' ||
            (row['clients_tree'] ?? 0).toString() != '0';
        if (childId <= 0 || !hasDownline) continue;
        final childKey = 'node_$childId';
        if (_lazyChildrenCache.containsKey(childKey) ||
            _lazyLoadingKeys.contains(childKey))
          continue;
        _lazyLoadingKeys.add(childKey);
        controller.getNetworkNodeChildren(childId, period: period).then((
          grand,
        ) {
          if (!mounted) {
            _lazyLoadingKeys.remove(childKey);
            return;
          }
          setState(() {
            _applyNodeResponse(childId, grand);
            _lazyLoadingKeys.remove(childKey);
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _sectionTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor:
            AppColors.isDarkMode ? AppColors.pureBlack : AppColors.whiteColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder:
              (ctx) => IconButton(
                icon: SvgPicture.asset(
                  'assets/svg/ib_dashboard/home.svg',
                  colorFilter: ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: () => Get.offAllNamed(AppPages.TRADING),
              ),
        ),
        titleSpacing: 0,
        title: Text(
          TranslationUtils.tr('ibm_clients_and_network'),
          style: AppTextStyles.heading.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Obx(() {
            final balance = controller.walletBalance;
            return Padding(
              padding: EdgeInsetsDirectional.only(end: 16.w),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 14.w,
                      color: AppColors.textPrimary,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '\$$balance',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Container(
            color:
                AppColors.isDarkMode
                    ? AppColors.pureBlack
                    : AppColors.whiteColor,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            child: Container(
              height: 36.h,
              decoration: BoxDecoration(
                color:
                    AppColors.isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF1EEF8),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: TabBar(
                controller: _sectionTabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18.r),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.whiteColor,
                unselectedLabelColor: AppColors.textGrey,
                labelStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
                tabs: [
                  Tab(text: TranslationUtils.tr('my_clients')),
                  Tab(
                    child: Obx(() {
                      final reqs =
                          controller.requestsData['waiting_count'] ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(TranslationUtils.tr('ibm_sub_ib_requests_tab')),
                          if (reqs > 0) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$reqs',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: AppColors.whiteColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _sectionTabController,
        children: [_buildMyClientsTab(), _buildSubIbRequestsTab()],
      ),
    );
  }

  // ==========================================
  // TAB 1: MY CLIENTS / MY NETWORK
  // ==========================================
  Widget _buildMyClientsTab() {
    return Obx(() {
      final isNetwork = controller.clientScope.value == 'network';

      if (controller.isLoading.value &&
          controller.clientsData.isEmpty &&
          controller.clientsNetworkTreeData.isEmpty) {
        return const IbmClientsShimmerLoading();
      }

      final data = controller.clientsData;
      final treeData = controller.clientsNetworkTreeData;
      final summary = data['summary'] ?? {};
      final treeSummary = controller.networkTreeSummaryData;

      final totalClients = summary['total'] ?? 0;
      final activeClients =
          isNetwork ? (treeSummary['active'] ?? 0) : (summary['active'] ?? 0);
      final newClients = summary['new_in_period'] ?? 0;
      final commission =
          summary['commission'] is Map
              ? summary['commission']['USD'] ?? 0.0
              : (double.tryParse((summary['commission'] ?? 0).toString()) ??
                  0.0);

      final directPartners = treeSummary['direct'] ?? 0;
      final totalPartners = treeSummary['total'] ?? treeSummary['sub_ibs'] ?? 0;
      final totalNetworkClients =
          treeSummary['clients'] ?? treeSummary['network_clients'] ?? 3;
      final networkEarned = (double.tryParse(
                (treeSummary['earned'] ?? treeSummary['you_earned'] ?? 0.09)
                    .toString(),
              ) ??
              0.09)
          .toStringAsFixed(2);

      final List<dynamic> rows = data['rows'] ?? [];

      final filteredRows =
          rows.where((r) {
            if (_searchQuery.isEmpty) return true;
            final name = (r['name'] ?? '').toString().toLowerCase();
            final email = (r['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase());
          }).toList();

      final subtitle =
          isNetwork
              ? TranslationUtils.trArgs('ibm_direct_sub_ibs_summary', {
                'direct': '$directPartners',
                'total': '$totalPartners',
                'clients': '$totalNetworkClients',
              })
              : TranslationUtils.trArgs('ibm_clients_assigned_to_you', {
                'count': '$totalClients',
              });

      // Parse Tree list from treeData or fallback
      final treeList = _extractTreeNodes(treeData);

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          _refreshAllData();
        },
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          children: [
            // Header text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TranslationUtils.tr('my_clients'),
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Date filter segmented control (Screenshot 1 & Web)
            _buildDateFilterSegmentedControl(),
            SizedBox(height: 16.h),

            // Direct Clients vs Network sub-tabs
            Row(
              children: [
                _buildSubTabBadge(
                  label: TranslationUtils.tr('ibm_direct_clients'),
                  count: totalClients,
                  isSelected: !isNetwork,
                  onTap: () {
                    setState(() => _selectedFocusNode = null);
                    controller.fetchClients(scope: 'direct');
                  },
                ),
                SizedBox(width: 8.w),
                _buildSubTabBadge(
                  label: TranslationUtils.tr('ibm_nav_network'),
                  count: totalNetworkClients,
                  isSelected: isNetwork,
                  onTap: () {
                    controller.fetchClients(scope: 'network');
                    _refreshAllData();
                  },
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Top Metric Cards:
            if (!isNetwork) ...[
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileMetricCard(
                          title: TranslationUtils.tr(
                            'ib_dashboard_new_screen_total_clients',
                          ),
                          subtitle: TranslationUtils.tr(
                            'ibm_assigned_straight_to_you',
                          ),
                          value: '$totalClients',
                          icon: Icons.people_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildMobileMetricCard(
                          title: TranslationUtils.tr('chart_active'),
                          subtitle: TranslationUtils.tr(
                            'ibm_traded_this_period',
                          ),
                          value: '$activeClients',
                          icon: Icons.person_rounded,
                          color: const Color(0xFF00C48C),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileMetricCard(
                          title: TranslationUtils.tr('ibm_new'),
                          subtitle: TranslationUtils.tr(
                            'ibm_joined_this_period',
                          ),
                          value: '$newClients',
                          icon: Icons.person_add_rounded,
                          color: const Color(0xFF2D9CDB),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildMobileMetricCard(
                          title: TranslationUtils.tr(
                            'pmam_manager_dashboard_screen_commission_earned',
                          ),
                          subtitle: TranslationUtils.tr(
                            'ibm_from_these_clients',
                          ),
                          value: '\$${commission.toStringAsFixed(2)}',
                          icon: Icons.monetization_on_rounded,
                          color: const Color(0xFFF2994A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (_selectedFocusNode != null) ...[
              _buildFocusedNodeSummaryCards(_selectedFocusNode!),
            ] else ...[
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileMetricCard(
                          title: TranslationUtils.tr('ibm_sub_ibs'),
                          subtitle: TranslationUtils.trArgs(
                            'ibm_directly_under_you',
                            {'count': '$directPartners'},
                          ),
                          value: '$totalPartners',
                          icon: Icons.account_tree_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildMobileMetricCard(
                          title: TranslationUtils.tr('ibm_network_clients'),
                          subtitle: TranslationUtils.tr(
                            'ibm_you_and_your_partners',
                          ),
                          value: '$totalNetworkClients',
                          icon: Icons.groups_rounded,
                          color: const Color(0xFF00C48C),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileMetricCard(
                          title: TranslationUtils.tr('chart_active'),
                          subtitle: TranslationUtils.tr(
                            'ibm_traded_this_period',
                          ),
                          value: '$activeClients',
                          icon: Icons.person_outline_rounded,
                          color: const Color(0xFF2D9CDB),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildMobileMetricCard(
                          title: TranslationUtils.tr('ibm_earned'),
                          subtitle: TranslationUtils.tr(
                            'ibm_across_the_network',
                          ),
                          value: '\$$networkEarned',
                          icon: Icons.monetization_on_rounded,
                          color: const Color(0xFFF2994A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            SizedBox(height: 16.h),

            // Search bar & Expand / Collapse actions
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40.h,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            isNetwork
                                ? TranslationUtils.tr(
                                  'ibm_search_anyone_in_your_network',
                                )
                                : TranslationUtils.tr(
                                  'ibm_search_name_or_email',
                                ),
                        hintStyle: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20.w,
                          color: AppColors.textGrey,
                        ),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 18.w,
                                    color: AppColors.textGrey,
                                  ),
                                )
                                : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                    ),
                  ),
                ),
                if (isNetwork) ...[
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAllExpanded = true;
                        _collapsedNodeKeys.clear();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        TranslationUtils.tr('ibm_expand_all'),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAllExpanded = false;
                        _collapsedNodeKeys.addAll(_getAllNodeKeys(treeList));
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        TranslationUtils.tr('ibm_collapse'),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 14.h),

            if (isNetwork) ...[
              // Legend
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    Wrap(
                      spacing: 12.w,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              TranslationUtils.tr('ib_clients_screen_sub_ib'),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00C48C),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              TranslationUtils.tr('ibm_your_own_client'),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF2994A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              TranslationUtils.tr('ibm_a_sub_ibs_client'),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Network Tree (Root node "You" + Recursive cascade children)
              _buildNetworkRootYouNode(treeData, treeSummary),
              SizedBox(height: 8.h),

              if (treeList.isEmpty)
                _buildEmptyPlaceholder(
                  icon: Icons.account_tree_outlined,
                  title: TranslationUtils.tr('ibm_no_network_partners_found'),
                  subtitle: TranslationUtils.tr('ibm_no_partners_match_search'),
                )
              else
                ...treeList.map((node) => _buildTreeNodeWidget(node, level: 1)),
            ] else ...[
              // Direct Clients Cards List
              if (filteredRows.isEmpty)
                _buildEmptyPlaceholder(
                  icon: Icons.person_off_outlined,
                  title: TranslationUtils.tr(
                    'my_clients_screen_no_clients_found',
                  ),
                  subtitle: TranslationUtils.tr('ibm_no_clients_match_filter'),
                )
              else
                ...filteredRows.map((row) => _buildClientRowCard(row)),
            ],
          ],
        ),
      );
    });
  }

  // ==========================================
  // DATE FILTER SEGMENTED CONTROL
  // ==========================================
  Widget _buildDateFilterSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.isDarkMode ? AppColors.surface : AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_dateFilters.length, (index) {
            final filter = _dateFilters[index];
            final isSelected = _selectedDateFilter == filter;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    if (filter == 'Custom') {
                      final now = DateTime.now();
                      final DateTime? start = await showDatePicker(
                        context: context,
                        helpText: TranslationUtils.tr('ibm_select_start_date'),
                        initialDate:
                            _customStartDate ??
                            now.subtract(const Duration(days: 30)),
                        firstDate: DateTime(2000),
                        lastDate: now,
                        builder:
                            (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.black,
                                ),
                              ),
                              child: child!,
                            ),
                      );
                      if (start == null) return;
                      final DateTime? end = await showDatePicker(
                        context: context,
                        helpText: TranslationUtils.tr('ibm_select_end_date'),
                        initialDate: start,
                        firstDate: start,
                        lastDate: now,
                        builder:
                            (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.black,
                                ),
                              ),
                              child: child!,
                            ),
                      );
                      if (end == null) return;
                      setState(() {
                        _customStartDate = start;
                        _customEndDate = end;
                        _selectedDateFilter = 'Custom';
                      });
                      _refreshAllData();
                    } else {
                      setState(() {
                        _selectedDateFilter = filter;
                        _customStartDate = null;
                        _customEndDate = null;
                      });
                      _refreshAllData();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: (filter == 'Custom' && _customStartDate == null)
                        ? Icon(
                            Icons.calendar_today_outlined,
                            size: 18.sp,
                            color: isSelected
                                ? AppColors.whiteColor
                                : (AppColors.isDarkMode
                                    ? Colors.white70
                                    : const Color(0xFF222222)),
                          )
                        : Text(
                            filter == 'Custom' && _customStartDate != null
                                ? '${DateFormat('MM/dd').format(_customStartDate!)} - ${DateFormat('MM/dd').format(_customEndDate!)}'
                                : _dateFilterLabel(filter),
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.whiteColor
                                  : (AppColors.isDarkMode
                                      ? Colors.white70
                                      : const Color(0xFF222222)),
                              fontSize: 13.sp,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                if (index < _dateFilters.length - 1)
                  Container(
                    width: 1,
                    height: 18.h,
                    color:
                        AppColors.isDarkMode
                            ? AppColors.divider
                            : const Color(0xFFE0E0E0),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ==========================================
  // FOCUSED SUB-IB 8 SUMMARY CARDS
  // ==========================================
  Widget _buildFocusedNodeSummaryCards(Map<String, dynamic> node) {
    final name =
        (node['name'] ??
                node['partner_name'] ??
                node['username'] ??
                node['client_name'] ??
                node['user_name'] ??
                node['full_name'] ??
                node['email']?.toString().split('@').first ??
                'ibm sub two')
            .toString();
    final level = node['level'] ?? 2;
    final plan = node['plan_name'] ?? node['plan'] ?? 'Sub 5';
    final partnerId =
        int.tryParse(
          (node['partner_user_id'] ??
                  node['user_id'] ??
                  node['client_user_id'] ??
                  0)
              .toString(),
        ) ??
        0;

    final clients = node['clients_count'] ?? node['clients'] ?? '1/1';
    final subIbs = node['subs_count'] ?? node['sub_ibs'] ?? 0;
    final deposits = (double.tryParse((node['deposits'] ?? 200).toString()) ??
            200.0)
        .toStringAsFixed(2);
    final netFunding = (double.tryParse(
              (node['net'] ?? node['net_funding'] ?? 200).toString(),
            ) ??
            200.0)
        .toStringAsFixed(2);
    final lots = (double.tryParse((node['lots'] ?? 0.03).toString()) ?? 0.03)
        .toStringAsFixed(2);
    final equity = (double.tryParse((node['equity'] ?? 155.01).toString()) ??
            155.01)
        .toStringAsFixed(2);
    final available =
        (double.tryParse((node['available'] ?? 0.15).toString()) ?? 0.15)
            .toStringAsFixed(2);
    final pendingPayout = (double.tryParse(
              (node['pending_payout'] ?? node['pending'] ?? 0).toString(),
            ) ??
            0.0)
        .toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniDetailCard(
                title: TranslationUtils.tr('ib_nav_clients'),
                value: '$clients',
                subtitle: TranslationUtils.tr('ibm_their_own_whole_branch'),
                icon: Icons.groups_rounded,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildMiniDetailCard(
                title: TranslationUtils.tr('ib_sub_ibs'),
                value: '$subIbs',
                subtitle: TranslationUtils.tr('ibm_working_under_them'),
                icon: Icons.account_tree_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildMiniDetailCard(
                title: TranslationUtils.tr('transaction_history_deposits'),
                value: '\$$deposits',
                subtitle: TranslationUtils.tr('ibm_branch_this_period'),
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF00C48C),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildMiniDetailCard(
                title: TranslationUtils.tr('ibm_net_funding'),
                value: '\$$netFunding',
                subtitle: TranslationUtils.tr('ibm_deposits_minus_withdrawals'),
                icon: Icons.balance_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildMiniDetailCard(
                title: TranslationUtils.tr('chart_label_lots'),
                value: lots,
                subtitle: TranslationUtils.tr('ibm_branch_this_period'),
                icon: Icons.show_chart_rounded,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildMiniDetailCard(
                title: TranslationUtils.tr('dashboard_equity'),
                value: '\$$equity',
                subtitle: TranslationUtils.tr('ibm_right_now_not_the_period'),
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildMiniDetailCard(
                title: TranslationUtils.tr('ibm_available'),
                value: '\$$available',
                subtitle: TranslationUtils.tr('ibm_their_wallet'),
                icon: Icons.payments_rounded,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildMiniDetailCard(
                title: TranslationUtils.tr('ibm_pending_payout'),
                value: '\$$pendingPayout',
                subtitle: TranslationUtils.tr('ibm_locked_in_a_request'),
                icon: Icons.hourglass_empty_rounded,
                color: const Color(0xFFF2994A),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),

        // Focus Header Action Card
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color:
                AppColors.isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6.w,
                runSpacing: 4.h,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      TranslationUtils.trArgs('ibm_sub_ib_level', {
                        'level': '$level',
                      }),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '· $plan',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedFocusNode = null),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        TranslationUtils.tr('ibm_show_whole_network'),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () {
                      if (partnerId > 0) {
                        Get.to(
                          () => IbmClientProfileScreen(
                            clientId: partnerId,
                            clientName: name,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            TranslationUtils.tr('ibm_open_full_page'),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.whiteColor,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: AppColors.whiteColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniDetailCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color? color,
  }) {
    final effectiveColor = color ?? AppColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(icon, size: 16.w, color: effectiveColor),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ROOT "YOU" NODE
  // ==========================================
  Widget _buildNetworkRootYouNode(
    Map<String, dynamic> treeData,
    Map<String, dynamic> summary,
  ) {
    final youData = treeData['you'] is Map ? treeData['you'] as Map : {};
    final name =
        (youData['name'] ??
                youData['partner_name'] ??
                youData['username'] ??
                'You · ibm master chain')
            .toString();
    final role = youData['type']?.toString() ?? 'Master IB';
    final direct = youData['direct'] ?? summary['direct'] ?? 3;
    final totalSubs =
        youData['sub_ibs'] ?? summary['total'] ?? summary['sub_ibs'] ?? 3;
    final earned = (double.tryParse(
              (youData['earned'] ??
                      summary['earned'] ??
                      summary['you_earned'] ??
                      0.09)
                  .toString(),
            ) ??
            0.09)
        .toStringAsFixed(2);
    final myId = youData['partner_user_id'] ?? youData['user_id'] ?? 38;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4.w, color: AppColors.primary),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16.r,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              'I',
                              style: TextStyle(
                                color: AppColors.whiteColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6.w,
                                  runSpacing: 2.h,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6.w,
                                        vertical: 1.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          4.r,
                                        ),
                                      ),
                                      child: Text(
                                        role,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  TranslationUtils.trArgs(
                                    'ibm_direct_subs_earned_line',
                                    {
                                      'direct': '$direct',
                                      'subs': '$totalSubs',
                                      'earned': '$earned',
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () {
                        final id = int.tryParse(myId.toString()) ?? 38;
                        Get.to(
                          () => IbmClientProfileScreen(
                            clientId: id,
                            clientName: name,
                            isYou: true,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            TranslationUtils.tr('ticket_status_open'),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward,
                            size: 13.w,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // RECURSIVE TREE NODE WIDGET
  // ==========================================
  Widget _buildTreeNodeWidget(Map<String, dynamic> node, {required int level}) {
    final name =
        (node['name'] ??
                node['partner_name'] ??
                node['username'] ??
                node['client_name'] ??
                node['user_name'] ??
                node['full_name'] ??
                node['email']?.toString().split('@').first ??
                TranslationUtils.tr('ibm_partner'))
            .toString();
    final email = (node['email'] ?? '').toString();
    final account =
        (node['account_number'] ??
                node['login'] ??
                node['first_account'] ??
                node['trading_account'] ??
                '')
            .toString();
    final nodeLevel = node['level'] ?? level;
    final plan = (node['plan_name'] ?? node['plan'] ?? 'Sub 7').toString();
    final cameVia =
        (node['via'] ??
                node['via_link'] ??
                node['referral_code'] ??
                node['came_via'] ??
                '')
            .toString();
    final partnerId =
        int.tryParse(
          (node['partner_user_id'] ??
                  node['user_id'] ??
                  node['client_user_id'] ??
                  node['id'] ??
                  0)
              .toString(),
        ) ??
        0;

    // Overlay enriched figures fetched from /portal/network/{id}/node.
    // The network-tree endpoint only returns label/ib_user_id/child counts,
    // so every money/count field is 0 on first paint; the per-node endpoint
    // (cached eagerly via _enrichVisibleTreeRows) fills them in. Merge any
    // cached enrichment so the row matches web on first render.
    // Overlay figures from _nodeFiguresById[partnerId] (parent's /node people
    // entry). The old code copied cached.first onto the parent — wrong:
    // cached.first was the parent's FIRST CHILD, so every row rendered
    // with the same figures. Real figures live keyed by user_id.
    final nodeKey = partnerId > 0 ? 'node_$partnerId' : '${name}_$level';
    final donor = partnerId > 0 ? _nodeFiguresById[partnerId] : null;
    if (donor != null) {
      final merged = Map<String, dynamic>.from(node);
      donor.forEach((key, value) {
        if (value == null) return;
        final existing = merged[key];
        final donorHasRealValue = value is num ? value != 0 : true;
        final existingIsEmpty =
            existing == null ||
            (existing is num && existing == 0) ||
            (existing is String && existing.isEmpty);
        if (existingIsEmpty && donorHasRealValue) merged[key] = value;
      });
      node = merged;
    }

    final isSubIb =
        node['is_sub_ib'] == true ||
        node['is_ib'] == true ||
        node['type'] == 'sub_ib';
    final isDirectClient =
        node['is_direct'] == true ||
        node['direct_client'] == true ||
        (nodeLevel == 1 && isSubIb);
    final isSubClient = !isDirectClient && !isSubIb;

    final branch =
        node['branch'] is Map
            ? node['branch'] as Map
            : (node['branch'] is List && (node['branch'] as List).isNotEmpty
                ? (node['branch'] as List)[0]
                : node);
    final own =
        node['own'] is Map
            ? node['own'] as Map
            : (node['own'] is List && (node['own'] as List).isNotEmpty
                ? (node['own'] as List)[0]
                : {});

    // The card represents the Sub-IB themselves, so DEPOSITS / NET / LOTS
    // must come from their OWN trading activity (node['own'][0]), not from
    // their branch aggregates. Branch aggregates flow into BRANCH EARNED only,
    // matching the web UI.
    final deposits = (double.tryParse(
              (own['deposits'] ?? node['deposits'] ?? 0).toString(),
            ) ??
            0.0)
        .toStringAsFixed(2);
    final net = (double.tryParse(
              (own['net'] ?? own['net_funding'] ?? node['net'] ?? 0).toString(),
            ) ??
            0.0)
        .toStringAsFixed(2);
    final lots =
        (double.tryParse((own['lots'] ?? node['lots'] ?? 0).toString()) ?? 0.0)
            .toStringAsFixed(2);
    final earned = (double.tryParse(
              (own['commission'] ??
                      node['you_earned'] ??
                      node['commission'] ??
                      0)
                  .toString(),
            ) ??
            0.0)
        .toStringAsFixed(2);
    final downlineSubs =
        node['downline_subs'] ?? node['sub_ibs'] ?? node['subs_count'] ?? 0;
    final downlineClients =
        node['downline_clients'] ??
        node['clients_tree'] ??
        node['clients_count'] ??
        node['clients'] ??
        0;
    final branchEarned = (double.tryParse(
              (node['branch_earned'] ??
                      branch['commission'] ??
                      branch['you_earned'] ??
                      node['commission'] ??
                      0)
                  .toString(),
            ) ??
            0.0)
        .toStringAsFixed(2);

    final List<dynamic> rawChildren =
        node['children'] is List
            ? node['children'] as List
            : (node['nodes'] is List
                ? node['nodes'] as List
                : (node['clients'] is List ? node['clients'] as List : []));
    // Children come from the parent's /node fetch ONLY — never both that
    // AND rawChildren. The previous concat duplicated every kid because
    // network-tree `children[]` and /node `people[]` list the same rows.
    final cachedChildren =
        _lazyChildrenCache.containsKey(nodeKey)
            ? _lazyChildrenCache[nodeKey]!
            : <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> children =
        cachedChildren.isNotEmpty
            ? cachedChildren
            : rawChildren.whereType<Map<String, dynamic>>().toList();
    // Wait, simpler `isCollapsed`: if it's in `_collapsedNodeKeys`, it's the OPPOSITE of `_isAllExpanded`.
    // Actually, let's just do:
    final isCollapsedLocal =
        _isAllExpanded
            ? _collapsedNodeKeys.contains(nodeKey)
            : !_collapsedNodeKeys.contains(nodeKey);

    final bool canExpand =
        children.isNotEmpty ||
        isSubIb ||
        downlineSubs.toString() != '0' ||
        downlineClients.toString() != '0';

    // Search query matching
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final match =
          name.toLowerCase().contains(q) ||
          email.toLowerCase().contains(q) ||
          account.toLowerCase().contains(q);
      final childMatch = children.any(
        (c) =>
            (c['name'] ?? '').toString().toLowerCase().contains(q) ||
            (c['email'] ?? '').toString().toLowerCase().contains(q),
      );
      if (!match && !childMatch) return const SizedBox.shrink();
    }

    final double leftIndent = (level - 1) * 14.w;

    final subtitleItems = <String>[];
    if (account.isNotEmpty)
      subtitleItems.add(account.startsWith('#') ? account : '#$account');
    if (email.isNotEmpty) subtitleItems.add(email);
    if (plan.isNotEmpty) subtitleItems.add(plan);
    if (cameVia.isNotEmpty) {
      subtitleItems.add(
        TranslationUtils.trArgs('ibm_via_source', {'source': cameVia}),
      );
    }

    return Container(
      margin: EdgeInsetsDirectional.only(bottom: 8.h, start: leftIndent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap:
                partnerId > 0
                    ? () {
                      Get.to(
                        () => IbmClientProfileScreen(
                          clientId: partnerId,
                          clientName: name,
                        ),
                      );
                    }
                    : null,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.divider),
              ),
              clipBehavior: Clip.hardEdge,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4.w,
                      color:
                          _selectedFocusNode == node
                              ? AppColors.primary
                              : (isSubIb
                                  ? AppColors.primary
                                  : const Color(0xFFF2994A)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (canExpand)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_collapsedNodeKeys.contains(
                                          nodeKey,
                                        )) {
                                          _collapsedNodeKeys.remove(nodeKey);
                                        } else {
                                          _collapsedNodeKeys.add(nodeKey);
                                        }

                                        final isCollapsedNow =
                                            _isAllExpanded
                                                ? _collapsedNodeKeys.contains(
                                                  nodeKey,
                                                )
                                                : !_collapsedNodeKeys.contains(
                                                  nodeKey,
                                                );

                                        if (!isCollapsedNow) {
                                          if (children.isEmpty &&
                                              !_lazyChildrenCache.containsKey(
                                                nodeKey,
                                              ) &&
                                              partnerId > 0) {
                                            _lazyLoadingKeys.add(nodeKey);
                                            controller
                                                .getNetworkNodeChildren(
                                                  partnerId,
                                                  period: _mapFilterToApi(
                                                    _selectedDateFilter,
                                                  ),
                                                )
                                                .then((fetched) {
                                                  if (mounted) {
                                                    setState(() {
                                                      _applyNodeResponse(
                                                        partnerId,
                                                        fetched,
                                                      );
                                                      _lazyLoadingKeys.remove(
                                                        nodeKey,
                                                      );
                                                    });
                                                  }
                                                });
                                          }
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.only(
                                        end: 6.w,
                                        top: 2.h,
                                      ),
                                      child:
                                          _lazyLoadingKeys.contains(nodeKey)
                                              ? SizedBox(
                                                width: 14.w,
                                                height: 14.w,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.primary,
                                                    ),
                                              )
                                              : Icon(
                                                isCollapsedLocal
                                                    ? Icons.chevron_right
                                                    : Icons.expand_more,
                                                size: 20.w,
                                                color: AppColors.textGrey,
                                              ),
                                    ),
                                  ),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6.w,
                                    runSpacing: 4.h,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isSubIb)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 5.w,
                                            vertical: 1.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              4.r,
                                            ),
                                          ),
                                          child: Text(
                                            TranslationUtils.trArgs(
                                              'ibm_sub_ib_level',
                                              {'level': '$nodeLevel'},
                                            ),
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (isDirectClient) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 5.w,
                                            vertical: 1.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF00C48C,
                                            ).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              4.r,
                                            ),
                                          ),
                                          child: Text(
                                            TranslationUtils.tr(
                                              'ibm_direct_client',
                                            ),
                                            style: const TextStyle(
                                              color: Color(0xFF00C48C),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isSubClient) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 5.w,
                                            vertical: 1.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFF2994A,
                                            ).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              4.r,
                                            ),
                                          ),
                                          child: Text(
                                            TranslationUtils.tr(
                                              'ibm_a_sub_ibs_client',
                                            ),
                                            style: const TextStyle(
                                              color: Color(0xFFF2994A),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                GestureDetector(
                                  onTap: () {
                                    if (partnerId > 0) {
                                      Get.to(
                                        () => IbmClientProfileScreen(
                                          clientId: partnerId,
                                          clientName: name,
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 18.w,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (subtitleItems.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Text(
                                subtitleItems.join(' · '),
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 10.sp,
                                ),
                              ),
                            ],
                            SizedBox(height: 8.h),
                            // Metrics strip — wraps to 2 lines on narrow screens so
                            // DOWNLINE / BRANCH EARNED never get clipped.
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.isDarkMode
                                        ? const Color(0xFF1E1E1E)
                                        : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Wrap(
                                spacing: 14.w,
                                runSpacing: 6.h,
                                children: [
                                  _buildMiniMetricMobile(
                                    'DEPOSITS',
                                    '\$$deposits',
                                  ),
                                  _buildMiniMetricMobile('NET', '\$$net'),
                                  _buildMiniMetricMobile('LOTS', lots),
                                  _buildMiniMetricMobile(
                                    'YOU EARNED',
                                    '\$$earned',
                                  ),
                                  if (downlineSubs > 0 || downlineClients > 0)
                                    _buildMiniMetricMobile(
                                      'DOWNLINE',
                                      TranslationUtils.trArgs(
                                        'ibm_downline_subs_cli_short',
                                        {
                                          'subs': '$downlineSubs',
                                          'clients': '$downlineClients',
                                        },
                                      ),
                                    ),
                                  if (double.tryParse(branchEarned) != null &&
                                      double.parse(branchEarned) > 0)
                                    _buildMiniMetricMobile(
                                      'BRANCH EARNED',
                                      '\$$branchEarned',
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Children nodes recursion
          if (canExpand && !isCollapsedLocal)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child:
                  _lazyLoadingKeys.contains(nodeKey)
                      ? Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: 14.w,
                          top: 8.h,
                          bottom: 8.h,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              TranslationUtils.tr('common_loading'),
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Column(
                        children:
                            children
                                .map(
                                  (child) => _buildTreeNodeWidget(
                                    child,
                                    level: level + 1,
                                  ),
                                )
                                .toList(),
                      ),
            ),
        ],
      ),
    );
  }

  // Extract / Construct tree node objects from API or fallback
  List<Map<String, dynamic>> _extractTreeNodes(Map<String, dynamic> treeData) {
    List<Map<String, dynamic>> list = [];
    if (treeData['tree'] is List && (treeData['tree'] as List).isNotEmpty) {
      list =
          (treeData['tree'] as List).whereType<Map<String, dynamic>>().toList();
    } else if (treeData['nodes'] is List &&
        (treeData['nodes'] as List).isNotEmpty) {
      list =
          (treeData['nodes'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
    } else if (treeData['people'] is List &&
        (treeData['people'] as List).isNotEmpty) {
      list =
          (treeData['people'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
    } else if (treeData['rows'] is List &&
        (treeData['rows'] as List).isNotEmpty) {
      list =
          (treeData['rows'] as List).whereType<Map<String, dynamic>>().toList();
    }

    // Normalise every node so downstream widgets see consistent keys
    // regardless of which endpoint it came from. `/clients/network-tree`
    // uses `label` + `ib_user_id`; `/network/{id}/node` uses `name` +
    // `user_id`. The row builder reads `name`, `user_id`, etc., so we
    // mirror the network-node shape here.
    list = list.map(_normaliseTreeNode).toList();

    // Always unwrap the synthetic direct/cascade root. The network-tree
    // payload wraps the user's real partners inside one direct node whose
    // `children` are the actual sub-IB rows. Earlier code only did this when
    // walletData['user_id'] matched, which silently left mobile on the bare
    // direct node (no name/email/deposits) and produced blank cards.
    if (list.length == 1) {
      final first = list.first;
      final isSyntheticRoot =
          first['type']?.toString() == 'direct' ||
          first['type']?.toString() == 'cascade' ||
          first['client_count'] != null ||
          first['sub_ib_count'] != null;
      if (isSyntheticRoot) {
        final rawChildren =
            first['children'] ?? first['nodes'] ?? first['people'] ?? [];
        if (rawChildren is List && rawChildren.isNotEmpty) {
          list =
              rawChildren
                  .whereType<Map<String, dynamic>>()
                  .map(_normaliseTreeNode)
                  .toList();
        } else {
          list = [];
        }
      }
    }

    // Recursively unwrap any deeper synthetic nodes and normalise children.
    list = list.map(_unwrapNested).toList();

    return list;
  }

  /// Mirrors the network-node shape onto a node from any source so widgets
  /// downstream can rely on `name`, `user_id`, `email`, etc.
  Map<String, dynamic> _normaliseTreeNode(Map<String, dynamic> node) {
    final out = Map<String, dynamic>.from(node);
    if (out['name'] == null && out['label'] != null) {
      out['name'] = out['label'];
    }
    if (out['user_id'] == null && out['ib_user_id'] != null) {
      out['user_id'] = out['ib_user_id'];
    }
    if (out['partner_user_id'] == null && out['user_id'] != null) {
      out['partner_user_id'] = out['user_id'];
    }
    if (out['sub_ibs'] == null && out['sub_ib_count'] != null) {
      out['sub_ibs'] = out['sub_ib_count'];
    }
    if (out['clients_tree'] == null &&
        out['client_count'] != null &&
        out['sub_ib_count'] != null) {
      out['clients_tree'] =
          ((out['client_count'] as num) + (out['sub_ib_count'] as num));
    }
    return out;
  }

  Map<String, dynamic> _unwrapNested(Map<String, dynamic> node) {
    final out = Map<String, dynamic>.from(node);
    final children = out['children'];
    if (children is List && children.isNotEmpty) {
      final normalised = children.whereType<Map<String, dynamic>>().map(
        _normaliseTreeNode,
      );
      out['children'] = normalised.map(_unwrapNested).toList();
    }
    return out;
  }

  Set<String> _getAllNodeKeys(
    List<Map<String, dynamic>> nodes, {
    int level = 1,
  }) {
    final keys = <String>{};
    for (final node in nodes) {
      final name = node['name']?.toString() ?? 'Node';
      final id = node['partner_user_id'] ?? node['user_id'] ?? 0;
      keys.add('${name}_${id}_$level');
      if (node['children'] is List) {
        final children =
            (node['children'] as List)
                .whereType<Map<String, dynamic>>()
                .toList();
        keys.addAll(_getAllNodeKeys(children, level: level + 1));
      }
    }
    return keys;
  }

  Widget _buildSubTabBadge({
    required String label,
    required dynamic count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow:
              isSelected && !AppColors.isDarkMode
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [],
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? AppColors.whiteColor : AppColors.textSecondary,
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.whiteColor.withOpacity(0.2)
                        : (AppColors.isDarkMode
                            ? AppColors.surface
                            : const Color(0xFFF1EEF8)),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color:
                      isSelected
                          ? AppColors.whiteColor
                          : (AppColors.isDarkMode
                              ? AppColors.textPrimary
                              : AppColors.primary),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMetricCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border:
            AppColors.isDarkMode ? Border.all(color: AppColors.divider) : null,
        boxShadow:
            AppColors.isDarkMode
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(icon, size: 14.w, color: color),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 9.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const Map<String, String> _miniMetricKeys = {
    'DEPOSITS': 'ibm_metric_deposits_upper',
    'NET': 'ibm_metric_net_upper',
    'LOTS': 'ibm_metric_lots_upper',
    'DOWNLINE': 'ibm_downline_caps',
    'YOU EARNED': 'ibm_you_earned_upper',
    'BRANCH EARNED': 'ibm_branch_earned_upper',
  };

  Widget _buildMiniMetricMobile(String label, String value) {
    final isPositive =
        label == 'DEPOSITS' ||
        label == 'YOU EARNED' ||
        label == 'BRANCH EARNED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TranslationUtils.tr(_miniMetricKeys[label] ?? label),
          style: TextStyle(
            fontSize: 9.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color:
                isPositive && value != '\$0.00' && value != '\$0'
                    ? const Color(0xFF00C48C)
                    : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildClientRowCard(dynamic row) {
    final r = row is Map ? row : {};
    final name = (r['name'] ?? r['username'] ?? 'Client').toString();
    final email = (r['email'] ?? '').toString();
    final isIb = r['is_ib'] ?? false;
    final lastLogin = (r['last_login'] ?? '--').toString();

    // Extract financials from currencies array if available
    Map? firstCurr;
    final currencies = r['currencies'];
    if (currencies is List && currencies.isNotEmpty) {
      firstCurr = currencies.first is Map ? currencies.first : null;
    }

    final depositsValue = double.tryParse((firstCurr?['deposits'] ?? r['deposits'] ?? 0).toString()) ?? 0.0;
    final deposits = depositsValue.toStringAsFixed(2);

    final withdrawalsValue = double.tryParse((firstCurr?['withdrawals'] ?? r['withdrawals'] ?? 0).toString()) ?? 0.0;

    final netRaw = firstCurr?['net_deposit'] ?? firstCurr?['net'] ?? r['net_deposit'] ?? r['net'];
    final netValue = netRaw != null ? (double.tryParse(netRaw.toString()) ?? 0.0) : (depositsValue - withdrawalsValue);
    final net = netValue.toStringAsFixed(2);

    final lots = (firstCurr?['lots'] ?? r['lots'])?.toString() ?? '0';

    final commStr = (firstCurr?['commission'] ?? r['commission'] ?? 0).toString();
    final comm = (double.tryParse(commStr) ?? 0.0).toStringAsFixed(2);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final id = r['client_user_id'] ?? r['id'] ?? 0;
        Get.to(() => IbmClientProfileScreen(clientId: id, clientName: name));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow:
              AppColors.isDarkMode
                  ? []
                  : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isIb) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                'IB',
                                style: TextStyle(
                                  color: AppColors.whiteColor,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        email.isNotEmpty ? email : lastLogin,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.divider, size: 20.w),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color:
                    AppColors.isDarkMode
                        ? AppColors.surface
                        : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniMetricMobile('DEPOSITS', '\$$deposits'),
                  _buildMiniMetricMobile('NET', '\$$net'),
                  _buildMiniMetricMobile('LOTS', lots),
                  _buildMiniMetricMobile('COMMISSION', '\$$comm'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mapFilterToApi(String filter) {
    switch (filter) {
      case 'Today':
        return 'today';
      case '7D':
        return '7d';
      case '30D':
        return '30d';
      case 'MTD':
        return 'mtd';
      case 'All':
        return 'all';
      case 'Custom':
        return 'custom';
      default:
        return 'mtd';
    }
  }

  // ==========================================
  // TAB 2: SUB-IB REQUESTS
  // ==========================================
  Widget _buildSubIbRequestsTab() {
    return Obx(() {
      final requests = controller.requestsData;
      final rawList = requests['requests'] ?? requests['rows'] ?? [];
      final List<dynamic> list = rawList is List ? rawList : [];

      final filtered =
          list.where((req) {
            final r = req is Map ? req : {};
            if (_selectedRequestTab == 'Waiting on you') {
              return r['status'] == 'pending' || r['status'] == 'waiting';
            }
            if (_selectedRequestTab == 'Approved') {
              return r['status'] == 'approved';
            }
            if (_selectedRequestTab == 'Declined') {
              return r['status'] == 'declined' || r['status'] == 'rejected';
            }
            if (_selectedRequestTab == 'With the broker') {
              return r['status'] == 'with_broker';
            }
            return true;
          }).toList();

      return ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        children: [
          // Sub-IB Request filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _requestTabs.map((tab) {
                    final isSelected = _selectedRequestTab == tab;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRequestTab = tab),
                      child: Container(
                        margin: EdgeInsetsDirectional.only(end: 8.w),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : (AppColors.isDarkMode
                                      ? AppColors.surface
                                      : AppColors.whiteColor),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          _requestTabLabel(tab),
                          style: TextStyle(
                            color:
                                isSelected
                                    ? AppColors.whiteColor
                                    : AppColors.textSecondary,
                            fontSize: 12.sp,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          SizedBox(height: 16.h),

          if (filtered.isEmpty)
            _buildEmptyPlaceholder(
              icon: Icons.inbox_outlined,
              title: TranslationUtils.tr('ibm_no_requests'),
              subtitle: TranslationUtils.tr('ibm_no_requests_in_category'),
            )
          else
            ...filtered.map((req) => _buildRequestCard(req)),
        ],
      );
    });
  }

  Widget _buildRequestCard(dynamic request) {
    final r = request is Map ? request : {};
    final id = r['id'] ?? 0;
    final name = (r['user_name'] ?? r['name'] ?? 'Partner').toString();
    final email = (r['user_email'] ?? r['email'] ?? '').toString();
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final requestedAt = (r['created_at'] ?? '').toString();

    Color statusColor = const Color(0xFFF2994A);
    if (status == 'approved') statusColor = const Color(0xFF00C48C);
    if (status == 'declined' || status == 'rejected') statusColor = Colors.red;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: AppTextStyles.heading.copyWith(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            TranslationUtils.trArgs('ibm_email_requested_on', {
              'email': email,
              'date': requestedAt,
            }),
            style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
          ),
          if (status == 'pending' || status == 'waiting') ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprove(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.whiteColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      TranslationUtils.tr('ibm_approve'),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReject(id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      TranslationUtils.tr('ibm_decline'),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleApprove(int requestId) {
    Get.defaultDialog(
      title: TranslationUtils.tr('ibm_approve_request'),
      titleStyle: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      content: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Text(
          TranslationUtils.tr('ibm_confirm_approve_sub_ib_request'),
          style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
        ),
      ),
      textConfirm: TranslationUtils.tr('ibm_approve'),
      textCancel: TranslationUtils.tr('account_management_cancel'),
      confirmTextColor: AppColors.whiteColor,
      buttonColor: AppColors.primary,
      onConfirm: () async {
        Get.back();
        await controller.approveSubIbRequest(requestId: requestId, planId: 1);
        controller.fetchRequests();
      },
    );
  }

  void _handleReject(int requestId) {
    final reasonController = TextEditingController();
    Get.defaultDialog(
      title: TranslationUtils.tr('ibm_decline_request'),
      titleStyle: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      content: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            Text(
              TranslationUtils.tr('ibm_please_provide_decline_reason'),
              style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: TranslationUtils.tr('ibm_reason_for_declining'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      textConfirm: TranslationUtils.tr('ibm_decline'),
      textCancel: TranslationUtils.tr('account_management_cancel'),
      confirmTextColor: AppColors.whiteColor,
      buttonColor: Colors.red,
      onConfirm: () async {
        Get.back();
        await controller.rejectSubIbRequest(
          requestId: requestId,
          reason: reasonController.text,
        );
        controller.fetchRequests();
      },
    );
  }

  Widget _buildEmptyPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40.w, color: AppColors.primary),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}
