import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_client_profile_screen.dart';

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

  final List<String> _requestTabs = [
    'Waiting on you',
    'With the broker',
    'Approved',
    'Declined',
    'All',
  ];
  String _selectedRequestTab = 'Waiting on you';

  @override
  void initState() {
    super.initState();
    _sectionTabController = TabController(length: 2, vsync: this);
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
                icon: Icon(
                  Icons.menu,
                  size: 22.w,
                  color:
                      AppColors.isDarkMode
                          ? Colors.white
                          : AppColors.textPrimary,
                ),
                onPressed: () {
                  Scaffold.of(ctx).openDrawer();
                },
              ),
        ),
        titleSpacing: 0,
        title: Text(
          'Clients & Network',
          style: AppTextStyles.heading.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Obx(() {
            final balance = controller.walletData['balance'] ?? '0.00';
            return Padding(
              padding: EdgeInsets.only(right: 16.w),
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
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
                tabs: [
                  const Tab(text: 'My Clients'),
                  Tab(
                    child: Obx(() {
                      final reqs =
                          controller.requestsData['waiting_count'] ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sub-IB Requests'),
                          if (reqs > 0) ...[
                            SizedBox(width: 4.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 1.h,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$reqs',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: Colors.white,
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
  // SCREENSHOT 2: MY CLIENTS / MY NETWORK
  // ==========================================
  Widget _buildMyClientsTab() {
    return Obx(() {
      if (controller.isLoading.value && controller.clientsData.isEmpty) {
        return Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        );
      }

      final data = controller.clientsData;
      final summary = data['summary'] ?? {};
      final totalClients = summary['total'] ?? 0;
      final activeClients = summary['active'] ?? 0;
      final newClients = summary['new_in_period'] ?? 0;
      final commission =
          summary['commission'] is Map
              ? summary['commission']['USD'] ?? 0.0
              : 0.0;

      final List<dynamic> rows = data['rows'] ?? [];
      final filteredRows =
          rows.where((r) {
            if (_searchQuery.isEmpty) return true;
            final name = (r['name'] ?? '').toString().toLowerCase();
            final email = (r['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase());
          }).toList();

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh:
            () => controller.fetchClients(
              period: _mapFilterToApi(_selectedDateFilter),
            ),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          children: [
            // Header text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Network',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '$totalClients client(s) in this period',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Date filter pills (Sleek text style)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _dateFilters.map((filter) {
                      final isSelected = _selectedDateFilter == filter;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDateFilter = filter);
                          controller.fetchClients(
                            period: _mapFilterToApi(filter),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.only(right: 20.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                filter,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? (AppColors.isDarkMode
                                              ? Colors.white
                                              : AppColors.textPrimary)
                                          : AppColors.textGrey,
                                  fontSize: 14.sp,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Container(
                                width: 16.w,
                                height: 3.h,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            SizedBox(height: 16.h),

            // Direct Clients vs Network sub-tabs
            Row(
              children: [
                _buildSubTabBadge(
                  label: 'Direct Clients',
                  count: totalClients,
                  isSelected: controller.clientScope.value == 'direct',
                  onTap: () => controller.fetchClients(scope: 'direct'),
                ),
                SizedBox(width: 8.w),
                _buildSubTabBadge(
                  label: 'Network',
                  count: summary['network_total'] ?? 0,
                  isSelected: controller.clientScope.value == 'network',
                  onTap: () => controller.fetchClients(scope: 'network'),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // 4 Metric Cards Mobile Style (Compact Rows)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileMetricCard(
                        title: 'Total Clients',
                        subtitle: 'assigned to you',
                        value: '$totalClients',
                        icon: Icons.people_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildMobileMetricCard(
                        title: 'Active',
                        subtitle: 'traded this period',
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
                        title: 'New',
                        subtitle: 'joined this period',
                        value: '$newClients',
                        icon: Icons.person_add_rounded,
                        color: const Color(0xFF2D9CDB),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildMobileMetricCard(
                        title: 'Earned',
                        subtitle: 'from these clients',
                        value: '\$${commission.toStringAsFixed(2)}',
                        icon: Icons.monetization_on_rounded,
                        color: const Color(0xFFF2994A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Search bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18.w, color: AppColors.textGrey),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search name or email',
                        hintStyle: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13.sp,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(
                        Icons.close,
                        size: 16.w,
                        color: AppColors.textGrey,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 14.h),

            // Client Cards List
            if (filteredRows.isEmpty)
              _buildEmptyPlaceholder(
                icon: Icons.person_off_outlined,
                title: 'No Clients Found',
                subtitle: 'No clients match your filter criteria.',
              )
            else
              ...filteredRows.map((row) => _buildClientRowCard(row)).toList(),
          ],
        ),
      );
    });
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
                        ? Colors.white.withOpacity(0.2)
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
                          ? Colors.white
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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16.w, color: color),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: AppTextStyles.heading.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textGrey, fontSize: 9.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildClientRowCard(dynamic row) {
    final r = row is Map ? row : {};
    final name = r['name'] ?? 'Client';
    final email = r['email'] ?? '';
    final isIb = r['is_ib'] ?? false;
    final lastLogin = r['last_login'] ?? '--';
    final accounts = r['accounts'] ?? 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final id = r['client_user_id'] ?? r['user_id'] ?? 0;
        Get.to(() => IbmClientProfileScreen(clientId: id, clientName: name));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16.r),
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
                  radius: 20.r,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
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
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isIb) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'IB',
                                style: TextStyle(
                                  color: Colors.white,
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
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.divider, size: 20.w),
              ],
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color:
                    AppColors.isDarkMode
                        ? AppColors.surface
                        : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniMetricMobile('Accounts', '$accounts'),
                  _buildMiniMetricMobile('Lots', '--'),
                  _buildMiniMetricMobile('Earned', '\$0.00'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetricMobile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: AppTextStyles.heading.copyWith(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SCREENSHOT 1: SUB-IB REQUESTS
  // ==========================================
  Widget _buildSubIbRequestsTab() {
    return Obx(() {
      final reqData = controller.requestsData;
      final waiting = reqData['waiting_count'] ?? 0;
      final withBroker = reqData['with_broker_count'] ?? 0;
      final approved = reqData['approved_count'] ?? 1;
      final declined = reqData['declined_count'] ?? 0;
      final List<dynamic> requests =
          reqData['rows'] ?? reqData['requests'] ?? [];

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => controller.fetchRequests(),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          children: [
            Text(
              'Sub-IB Requests',
              style: AppTextStyles.heading.copyWith(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'People asking to work as partners under you',
              style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp),
            ),
            SizedBox(height: 14.h),

            // 4 Status Summary Cards Compact
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileMetricCard(
                        title: 'Waiting on you',
                        subtitle: 'needs your decision',
                        value: '$waiting',
                        icon: Icons.hourglass_top_rounded,
                        color: const Color(0xFFF2994A),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildMobileMetricCard(
                        title: 'With the broker',
                        subtitle: 'they sign off',
                        value: '$withBroker',
                        icon: Icons.account_balance_rounded,
                        color: const Color(0xFF2D9CDB),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileMetricCard(
                        title: 'Approved',
                        subtitle: 'partners under you',
                        value: '$approved',
                        icon: Icons.handshake_rounded,
                        color: const Color(0xFF00C48C),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildMobileMetricCard(
                        title: 'Declined',
                        subtitle: 'they can ask again',
                        value: '$declined',
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFFEB5757),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Request Filter Tabs (Sleek text style)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _requestTabs.map((tab) {
                      final isSelected = _selectedRequestTab == tab;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRequestTab = tab),
                        child: Padding(
                          padding: EdgeInsets.only(right: 20.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tab,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? (AppColors.isDarkMode
                                              ? Colors.white
                                              : AppColors.textPrimary)
                                          : AppColors.textGrey,
                                  fontSize: 14.sp,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Container(
                                width: 16.w,
                                height: 3.h,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            SizedBox(height: 16.h),

            // Request Content / Empty state matching Screenshot 1
            if (requests.isEmpty)
              _buildEmptyPlaceholder(
                icon: Icons.inbox_outlined,
                title: 'Nothing waiting on you',
                subtitle:
                    'When one of your clients asks to become a partner, it lands here for your decision.',
              )
            else
              ...requests.map((r) => _buildRequestCard(r)).toList(),
          ],
        ),
      );
    });
  }

  Widget _buildRequestCard(dynamic req) {
    final r = req is Map ? req : {};
    final requestId = r['id'] ?? r['request_id'] ?? 0;
    final name = r['name'] ?? r['client_name'] ?? 'Partner Candidate';
    final email = r['email'] ?? '';
    final status = r['status'] ?? 'pending';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 20.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12.sp,
                        ),
                      ),
                  ],
                ),
              ),
              _buildStatusPill(status),
            ],
          ),
          if (status == 'pending') ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _showRejectDialog(requestId),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showApproveDialog(requestId),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 13.sp,
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

  Widget _buildStatusPill(String status) {
    Color bgColor;
    Color textColor;
    if (status == 'approved') {
      bgColor = const Color(0xFF00C48C).withOpacity(0.1);
      textColor = const Color(0xFF00C48C);
    } else if (status == 'pending') {
      bgColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange;
    } else {
      bgColor = Colors.redAccent.withOpacity(0.1);
      textColor = Colors.redAccent;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 50.w, color: AppColors.textGrey.withOpacity(0.5)),
          SizedBox(height: 12.h),
          Text(
            title,
            style: AppTextStyles.heading.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(int requestId) {
    int? selectedPlanId;
    if (controller.plansList.isNotEmpty) {
      selectedPlanId =
          controller.plansList.first['plan_id'] ??
          controller.plansList.first['id'];
    }

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: const Text('Assign Plan & Approve'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a Commission Plan for this Sub-IB:'),
                SizedBox(height: 12.h),
                if (controller.plansList.isEmpty)
                  const Text(
                    'No commission plans available. Please create one first.',
                    style: TextStyle(color: Colors.redAccent),
                  )
                else
                  DropdownButtonFormField<int>(
                    value: selectedPlanId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    items:
                        controller.plansList.map<DropdownMenuItem<int>>((p) {
                          final id = p['plan_id'] ?? p['id'] ?? 0;
                          final name = p['name'] ?? 'Plan $id';
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(name),
                          );
                        }).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedPlanId = val);
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed:
                    selectedPlanId == null
                        ? null
                        : () async {
                          Get.back();
                          await controller.approveSubIbRequest(
                            requestId: requestId,
                            planId: selectedPlanId!,
                          );
                        },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRejectDialog(int requestId) {
    final reasonController = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('Decline Request'),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            hintText: 'Reason for declining (optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back();
              await controller.rejectSubIbRequest(
                requestId: requestId,
                reason: reasonController.text.trim(),
              );
            },
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  String _mapFilterToApi(String filter) {
    switch (filter) {
      case 'Today':
        return 'today';
      case '7D':
        return 'this_week';
      case '30D':
        return 'last_month';
      case 'MTD':
        return 'this_month';
      case 'All':
        return 'all_time';
      default:
        return 'this_month';
    }
  }
}
