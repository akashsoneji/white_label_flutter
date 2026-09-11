import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

class IBClientsScreen extends StatefulWidget {
  const IBClientsScreen({super.key});

  @override
  State<IBClientsScreen> createState() => _IBClientsScreenState();
}

class _IBClientsScreenState extends State<IBClientsScreen> {
  late IBController ibController;
  late AuthController authController;

  @override
  void initState() {
    super.initState();
    // Get or create controllers
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    authController = Get.find<AuthController>();

    // Initialize hierarchy and local UI state in controller
    ibController.resetClientsHierarchy();
    ibController.clientsTabIndex.value = 0;
    ibController.clientsSearchQuery.value = '';
    ibController.clientsExpandedItems.clear();
    ibController.clientsDataKey.value = 0;

    // Load initial data (Master IB - 4 APIs) via controller (GetX)
    ibController.loadMyClientsData();
  }

  /// Handle Sub-IB click - navigate into sub-IB
  void _onSubIBClicked(IBClient subIB) {
    print('🔄 Navigating to Sub-IB: ${subIB.name} (ID: ${subIB.id})');
    ibController.navigateToSubIB(subIB);
  }

  /// Navigate back to parent IB
  void _backToParent() {
    ibController.backToParentIB();
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'NA';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  List<IBClient> _getFilteredClients() {
    final allClients = ibController.ibClients;
    if (allClients.isEmpty) return [];

    // Separate regular clients and sub-IBs
    final regularClients = <IBClient>[];
    final subIBs = <IBClient>[];

    for (var client in allClients) {
      if (client.ibType == 'sub-ib' && client.isSubIbApproved == true) {
        subIBs.add(client);
      } else {
        regularClients.add(client);
      }
    }

    // Sort alphabetically
    regularClients.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    // In Client List we want to show only regular clients (not Sub-IBs)
    final sortedClients = [...regularClients];

    final search = ibController.clientsSearchQuery.value;
    if (search.isEmpty) return sortedClients;
    return sortedClients
        .where(
          (client) =>
              (client.name?.toLowerCase().contains(
                    search.toLowerCase(),
                  ) ??
                  false) ||
              (client.email?.toLowerCase().contains(
                    search.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  List<IBClient> _getFilteredSubIBs() {
    final allSubIBs = ibController.ibSubIBs;
    if (allSubIBs.isEmpty) return [];

    final search = ibController.clientsSearchQuery.value;
    if (search.isEmpty) return allSubIBs;
    return allSubIBs
        .where(
          (subIB) =>
              (subIB.name?.toLowerCase().contains(search.toLowerCase()) ??
                  false) ||
              (subIB.email?.toLowerCase().contains(
                    search.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  List<IBTradeHistory> _getFilteredTradeHistory() {
    final allTrades = ibController.ibTradeHistory;
    if (allTrades.isEmpty) return [];

    final search = ibController.clientsSearchQuery.value;
    if (search.isEmpty) return allTrades;
    return allTrades
        .where(
          (trade) =>
              (trade.clientName?.toLowerCase().contains(
                    search.toLowerCase(),
                  ) ??
                  false) ||
              (trade.clientEmail?.toLowerCase().contains(
                    search.toLowerCase(),
                  ) ??
                  false) ||
              (trade.symbol?.toLowerCase().contains(
                    search.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  void _toggleExpand(int index) {
    ibController.toggleClientExpand(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        title: Text(
          TranslationUtils.tr('my_clients'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ibController.loadIBData(
              subIbId: ibController.clientsSelectedSubIB.value?.id,
            ),
        backgroundColor: AppColors.whiteColor,
        child: Obx(() {
          if (ibController.isLoading.value) {
            return Center(
              child: CommonLoadingWidget(
                message: TranslationUtils.tr('ib_clients_screen_loading_data'),
                size: 50.0,
                color: AppColors.primary,
              ),
            );
          }

          final stats = ibController.ibStats.value;
          final userFullName =
              authController.userFullName ?? TranslationUtils.tr('ib_user');

          return SafeArea(
            child: Column(
              children: [
                // Hierarchy Breadcrumb
                _buildHierarchyBreadcrumb(userFullName),

                // Statistics Cards
                if (stats != null) _buildStatisticsGrid(stats, userFullName),

                // Search Bar
                _buildSearchBar(),

                // Tabs
                _buildTabs(),

                SizedBox(height: 12.h),

                // Tab Content
                Expanded(child: _getTabContent(ibController)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHierarchyBreadcrumb(String userFullName) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Breadcrumb chips
          Row(
            children: [
              // Master IB chip
              _buildBreadcrumbChip(
                label: '$userFullName (You)',
                icon: Icons.star,
                isActive: ibController.clientsSelectedSubIB.value == null,
              ),

              // Sub-IB chips
              if (ibController.clientsHierarchy.isNotEmpty)
                for (var i = 0;
                    i < ibController.clientsHierarchy.length;
                    i++) ...[
                  Icon(
                    Icons.chevron_right,
                    size: 16.sp,
                    color: AppColors.textGrey,
                  ),
                  _buildBreadcrumbChip(
                    label:
                        ibController.clientsHierarchy[i].name ??
                        TranslationUtils.tr('ib_clients_screen_sub_ib'),
                    icon: Icons.people,
                    isActive:
                        i == ibController.clientsHierarchy.length - 1,
                  ),
                ],
            ],
          ),

          // Back button
          if (ibController.clientsSelectedSubIB.value != null) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                InkWell(
                  onTap: _backToParent,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: AppColors.primary,
                          size: 16.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          ibController.clientsHierarchy.length > 1
                              ? TranslationUtils.tr('ib_back_to_sub_ib')
                              : TranslationUtils.tr('ib_back_to_master_ib'),
                          style: AppTextStyles.bodyText.copyWith(
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
                  '${ibController.ibClients.length} clients',
                  style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreadcrumbChip({
    required String label,
    required IconData icon,
    required bool isActive,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color:
            isActive ? AppColors.primary : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.whiteColor : AppColors.primary,
            size: 14.sp,
          ),
          SizedBox(width: 4.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 100.w),
            child: Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.whiteColor : AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(dynamic stats, String userFullName) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.6,
        children: [
          _buildStatCard(
            icon: Icons.people_outline,
            label: TranslationUtils.tr('ib_dashboard_new_screen_total_clients'),
            value: (stats.totalClients ?? 0).toString(),
            color: AppColors.blue,
          ),
          _buildStatCard(
            icon: Icons.arrow_downward,
            label: TranslationUtils.tr('ib_dashboard_new_screen_total_deposit'),
            value: '\$${(stats.totalDeposited ?? 0).toStringAsFixed(2)}',
            color: AppColors.green,
          ),
          _buildStatCard(
            icon: Icons.arrow_upward,
            label: TranslationUtils.tr('ib_total_withdraw'),
            value: '\$${(stats.totalWithdrawal ?? 0).toStringAsFixed(2)}',
            color: AppColors.warning,
          ),
          _buildStatCard(
            icon: Icons.account_balance_wallet,
            label: TranslationUtils.tr(
              'ib_dashboard_new_screen_available_rebate',
            ),
            value: '\$${stats.availableRebate ?? '0.00'}',
            color: AppColors.quickActionPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, size: 20.sp, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          ibController.setClientsSearchQuery(value);
        },
        decoration: InputDecoration(
          hintText: TranslationUtils.tr(
            'ib_clients_screen_search_clients_sub_ibs_trades',
          ),
          hintStyle: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textGrey),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search,
            size: 20.sp,
            color: AppColors.textGrey,
          ),
          suffixIcon:
              ibController.clientsSearchQuery.value.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 20.sp,
                      color: AppColors.textGrey,
                    ),
                    onPressed: () {
                      ibController.setClientsSearchQuery('');
                    },
                  )
                  : null,
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              TranslationUtils.tr('ib_nav_clients'),
              0,
              Icons.person_outline,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildTabButton(
              TranslationUtils.tr('ib_sub_ibs'),
              1,
              Icons.people_outline,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildTabButton(
              TranslationUtils.tr('tw_trades'),
              2,
              Icons.show_chart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index, IconData icon) {
    final isSelected = ibController.clientsTabIndex.value == index;
    return GestureDetector(
      onTap: () {
        ibController.setClientsTabIndex(index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: AppColors.border.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isSelected ? AppColors.whiteColor : AppColors.textGrey,
            ),
            SizedBox(width: 4.w),
            Text(
              text,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.whiteColor : AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getTabContent(IBController controller) {
    switch (controller.clientsTabIndex.value) {
      case 0:
        return _buildClientList(controller);
      case 1:
        return _buildSubIBList(controller);
      case 2:
        return _buildTradeHistory(controller);
      default:
        return _buildClientList(controller);
    }
  }

  Widget _buildClientList(IBController controller) {
    final filteredClients = _getFilteredClients();

    print(
      '🔍 Building client list with ${filteredClients.length} clients (key: ${controller.clientsDataKey.value})',
    );

    if (filteredClients.isEmpty) {
      return _buildEmptyState(
        TranslationUtils.tr('my_clients_screen_no_clients_found'),
        Icons.person_off_outlined,
      );
    }

    return ListView.builder(
      key: ValueKey('clients_${controller.clientsDataKey.value}'),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: filteredClients.length,
      itemBuilder: (context, index) {
        final client = filteredClients[index];
        final isExpanded =
            controller.clientsExpandedItems[index] ?? false;
        final isSubIB =
            client.ibType == 'sub-ib' && client.isSubIbApproved == true;

        return _buildClientCard(client, index, isExpanded, isSubIB);
      },
    );
  }

  Widget _buildSubIBList(IBController controller) {
    final filteredSubIBs = _getFilteredSubIBs();

    print(
      '🔍 Building sub-IB list with ${filteredSubIBs.length} sub-IBs (key: ${controller.clientsDataKey.value})',
    );

    if (filteredSubIBs.isEmpty) {
      return _buildEmptyState(
        TranslationUtils.tr('my_clients_screen_no_sub_ibs_found'),
        Icons.people_outline_outlined,
      );
    }

    return ListView.builder(
      key: ValueKey('subibs_${controller.clientsDataKey.value}'),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: filteredSubIBs.length,
      itemBuilder: (context, index) {
        final subIB = filteredSubIBs[index];
        final isExpanded =
            controller.clientsExpandedItems[index] ?? false;

        return _buildSubIBCard(subIB, index, isExpanded);
      },
    );
  }

  Widget _buildTradeHistory(IBController controller) {
    final filteredTrades = _getFilteredTradeHistory();

    print(
      '🔍 Building trade history with ${filteredTrades.length} trades (key: ${controller.clientsDataKey.value})',
    );

    if (filteredTrades.isEmpty) {
      return _buildEmptyState(
        TranslationUtils.tr('ib_no_trade_history_found'),
        Icons.history,
      );
    }

    return ListView.builder(
      key: ValueKey('trades_${controller.clientsDataKey.value}'),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: filteredTrades.length,
      itemBuilder: (context, index) {
        final trade = filteredTrades[index];
        final isExpanded =
            controller.clientsExpandedItems[index] ?? false;

        return _buildTradeCard(trade, index, isExpanded);
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48.sp,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(
    IBClient client,
    int index,
    bool isExpanded,
    bool isSubIB,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpand(index),
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.8),
                          AppColors.primary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(client.name),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.whiteColor,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                client.name ?? 'N/A',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSubIB) ...[
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  TranslationUtils.tr('ib_clients_screen_sub_ib'),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          client.email ?? '',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  if (isSubIB)
                    IconButton(
                      icon: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 16.sp,
                          color: AppColors.whiteColor,
                        ),
                      ),
                      onPressed: () => _onSubIBClicked(client),
                    )
                  else
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textGrey,
                      size: 24.sp,
                    ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (isExpanded)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12.r),
                  bottomRight: Radius.circular(12.r),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    TranslationUtils.tr('wallet_account_number'),
                    client.accountNumber ?? 'N/A',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('common_deposit'),
                    '\$${(client.deposit ?? 0.0).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('dashboard_withdraw'),
                    '\$${(client.withdraw ?? 0.0).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('ib_rebate'),
                    '\$${(client.rebate ?? 0.0).toStringAsFixed(2)}',
                  ),
                  if (client.lots != null)
                    _buildDetailRow(
                      TranslationUtils.tr('chart_label_lots'),
                      client.lots!.toStringAsFixed(2),
                    ),
                  if (client.equity != null)
                    _buildDetailRow(
                      TranslationUtils.tr('dashboard_equity'),
                      '\$${client.equity!.toStringAsFixed(2)}',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubIBCard(IBClient subIB, int index, bool isExpanded) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpand(index),
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  // Avatar with star badge
                  Stack(
                    children: [
                      Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.8),
                              AppColors.primary,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(subIB.name),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.whiteColor,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: AppColors.accentStatic,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.whiteColor, width: 2),
                          ),
                          child: Icon(
                            Icons.star,
                            size: 10.sp,
                            color: AppColors.whiteColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12.w),

                  // Name and stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subIB.name ?? 'N/A',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          subIB.email ?? '',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 12.sp,
                              color: AppColors.textGrey,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '${subIB.totalClients ?? 0} clients',
                              style: AppTextStyles.bodyText.copyWith(
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
                              '${subIB.totalSubIBs ?? 0} sub-IBs',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Navigate button
                  IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16.sp,
                        color: AppColors.whiteColor,
                      ),
                    ),
                    onPressed: () => _onSubIBClicked(subIB),
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (isExpanded)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12.r),
                  bottomRight: Radius.circular(12.r),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    TranslationUtils.tr('ib_dashboard_new_screen_total_clients'),
                    '${subIB.totalClients ?? 0}',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('ib_dashboard_new_screen_total_deposit'),
                    '\$${(subIB.totalDeposit ?? 0.0).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('ib_dashboard_new_screen_total_rebate'),
                    '\$${(subIB.totalRebate ?? 0.0).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('ib_total_sub_ibs'),
                    '${subIB.totalSubIBs ?? 0}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTradeCard(IBTradeHistory trade, int index, bool isExpanded) {
    final isProfit = (trade.profit ?? 0) >= 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpand(index),
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color:
                          isProfit
                              ? AppColors.green.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(trade.clientName),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: isProfit ? AppColors.green : AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Trade info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trade.clientName ?? 'N/A',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${trade.symbol ?? ''} • ${trade.type ?? ''}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Profit/Loss
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${trade.profit?.toStringAsFixed(2) ?? '0.00'}',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: isProfit ? AppColors.green : AppColors.error,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.textGrey,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (isExpanded)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12.r),
                  bottomRight: Radius.circular(12.r),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    TranslationUtils.tr('ib_client_email'),
                    trade.clientEmail ?? 'N/A',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('ib_mt5_account'),
                    trade.mt5Account ?? 'N/A',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('meta_watchlist_symbol'),
                    trade.symbol ?? 'N/A',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('common_type'),
                    trade.type ?? 'N/A',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('general_volume'),
                    trade.volume?.toString() ?? 'N/A',
                  ),
                  _buildDetailRow(
                    TranslationUtils.tr('dashboard_profit'),
                    '\$${trade.profit?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
          ),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
