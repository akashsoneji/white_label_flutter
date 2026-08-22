import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

class IbmClientProfileScreen extends StatefulWidget {
  final int clientId;
  final String clientName;

  const IbmClientProfileScreen({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  State<IbmClientProfileScreen> createState() => _IbmClientProfileScreenState();
}

class _IbmClientProfileScreenState extends State<IbmClientProfileScreen>
    with SingleTickerProviderStateMixin {
  final IbmController controller = Get.find<IbmController>();
  late TabController _tabController;

  final List<String> _dateFilters = [
    'Today',
    '7D',
    '30D',
    'MTD',
    'All',
    'Dates',
  ];
  String _selectedDateFilter = 'MTD';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Fetch initial data for Overview
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDataForTab(0);
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchDataForTab(_tabController.index);
      }
    });
  }

  void _fetchDataForTab(int index) {
    String period = _mapFilterToApi(_selectedDateFilter);
    switch (index) {
      case 0:
        controller.fetchClientOverview(widget.clientId, period: period);
        break;
      case 1:
        controller.fetchClientTrades(widget.clientId, period: period);
        break;
      case 2:
        controller.fetchNetworkNode(widget.clientId, period: period);
        break;
      case 3:
        controller.fetchNetworkSymbols(widget.clientId, period: period);
        break;
      case 4:
        controller.fetchNetworkPlan(widget.clientId);
        break;
    }
  }

  String _mapFilterToApi(String uiFilter) {
    switch (uiFilter) {
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
      default:
        return 'mtd';
    }
  }

  void _onDateFilterChanged(String filter) {
    setState(() => _selectedDateFilter = filter);
    _fetchDataForTab(_tabController.index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 18.w,
            color: AppColors.textPrimary,
          ),
        ),
        titleSpacing: 0,
        title: Text(
          widget.clientName,
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
          preferredSize: Size.fromHeight(100.h),
          child: Container(
            color:
                AppColors.isDarkMode
                    ? AppColors.pureBlack
                    : AppColors.whiteColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfileHeader(),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textGrey,
                  labelStyle: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Trades'),
                    Tab(text: 'Network'),
                    Tab(text: 'Symbol-wise commission'),
                    Tab(text: 'Commission plan'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isProfileLoading.value &&
            controller.currentClientOverview.isEmpty &&
            controller.currentNetworkNode.isEmpty &&
            controller.currentClientTrades.isEmpty &&
            controller.currentNetworkSymbols.isEmpty &&
            controller.currentNetworkPlan.isEmpty) {
          return Center(
            child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
          );
        }

        return TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildTradesTab(),
            _buildNetworkTab(),
            _buildSymbolCommissionTab(),
            _buildCommissionPlanTab(),
          ],
        );
      }),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: AppColors.primary,
            child: Text(
              widget.clientName.isNotEmpty
                  ? widget.clientName.substring(0, 1).toUpperCase()
                  : 'C',
              style: TextStyle(
                color: AppColors.whiteColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
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
                    Text(
                      widget.clientName,
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'Sub-IB',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Obx(() {
                  final data = controller.currentClientOverview;
                  final client = data['client'] ?? {};
                  final email = client['email'] ?? '';
                  final joined = client['joined_at'] ?? '';
                  return Text(
                    '$email • Joined $joined',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 11.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  );
                }),
              ],
            ),
          ),
          _buildDateFilters(),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            _dateFilters.map((filter) {
              final isSelected = _selectedDateFilter == filter;
              return GestureDetector(
                onTap: () {
                  if (!isSelected) _onDateFilterChanged(filter);
                },
                child: Padding(
                  padding: EdgeInsets.only(left: 12.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? (AppColors.isDarkMode
                                      ? AppColors.whiteColor
                                      : AppColors.textPrimary)
                                  : AppColors.textGrey,
                          fontSize: 12.sp,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: 12.w,
                        height: 2.h,
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
    );
  }

  // ==========================
  // TAB 1: OVERVIEW
  // ==========================
  Widget _buildOverviewTab() {
    final data = controller.currentClientOverview;
    if (data.isEmpty) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(0),
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Text(
            'THEIR DOWNLINE',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Clients',
                      value: '1 / 2',
                      subtitle: 'own / whole branch',
                      icon: Icons.group,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Sub-IBs',
                      value: '1',
                      subtitle: 'working under them',
                      icon: Icons.account_tree,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Deposits',
                      value: '\$200.00',
                      subtitle: 'branch, this period',
                      icon: Icons.arrow_downward,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Withdrawals',
                      value: '\$0.00',
                      subtitle: 'branch, this period',
                      icon: Icons.arrow_upward,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Net funding',
                      value: '\$200.00',
                      subtitle: 'deposits - withdrawals',
                      icon: Icons.account_balance,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Equity',
                      value: '\$155.01',
                      subtitle: 'right now, not the period',
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Lots',
                      value: '0.03',
                      subtitle: 'branch, this period',
                      icon: Icons.bar_chart,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'You earned',
                      value: '\$0.09',
                      subtitle: 'your share from them',
                      icon: Icons.monetization_on,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 24.h),
          Text(
            'THEIR REFERRAL LINKS',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          _buildLinkRow('sub1Chain', 'IBMSUB1', '0', '0'),

          SizedBox(height: 24.h),
          Text(
            'THEIR WALLET',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Available',
                      value: '\$0.06',
                      subtitle: 'they can request this',
                      icon: Icons.payments,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Pending payout',
                      value: '\$0.00',
                      subtitle: 'locked in an open request',
                      icon: Icons.hourglass_bottom,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Earned all time',
                      value: '\$0.06',
                      subtitle: 'their own share',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Paid out',
                      value: '\$0.00',
                      subtitle: 'settled',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color? color,
  }) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
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
                  color: c.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: c, size: 14.w),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            value,
            style: AppTextStyles.heading.copyWith(
              fontSize: 16.sp,
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

  Widget _buildLinkRow(
    String link,
    String code,
    String signedUp,
    String funded,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
              ),
              Text(
                code,
                style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Signed up: $signedUp', style: TextStyle(fontSize: 11.sp)),
              Text('Funded: $funded', style: TextStyle(fontSize: 11.sp)),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              'On',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================
  // TAB 2: TRADES
  // ==========================
  Widget _buildTradesTab() {
    final data = controller.currentClientTrades;
    final rows = data['rows'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(1),
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('All accounts'),
                selected: true,
                onSelected: (_) {},
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: AppColors.whiteColor,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(width: 8.w),
              ChoiceChip(
                label: const Text('All'),
                selected: true,
                onSelected: (_) {},
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: AppColors.whiteColor,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          if (rows.isEmpty)
            Container(
              height: 200.h,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 48.w, color: AppColors.textGrey),
                  SizedBox(height: 16.h),
                  Text(
                    'No closed trades',
                    style: AppTextStyles.heading.copyWith(fontSize: 16.sp),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Nothing closed on this selection in this period.',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            )
          else
            ...rows
                .map((trade) => ListTile(title: Text('Trade ${trade['id']}')))
                .toList(),
        ],
      ),
    );
  }

  // ==========================
  // TAB 3: NETWORK
  // ==========================
  Widget _buildNetworkTab() {
    final data = controller.currentNetworkNode;
    final people = data['people'] as List? ?? [];

    if (people.isEmpty) {
      return Center(
        child: Text(
          'No network data found',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(2),
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: people.length,
        itemBuilder: (context, index) {
          final person = people[index];
          return _buildNetworkNodeCard(person);
        },
      ),
    );
  }

  Widget _buildNetworkNodeCard(dynamic person) {
    final name = person['name'] ?? 'Unknown';
    final email = person['email'] ?? '';
    final isIb = person['is_ib'] == true;
    final level = person['level'] ?? 1;
    final clientsTree = person['clients_tree'] ?? 0;

    final branchList = person['branch'] as List? ?? [];
    final branch = branchList.isNotEmpty ? branchList[0] : {};
    final deposits = _parseDouble(branch['deposits']);
    final lots = _parseDouble(branch['lots']);
    final earned = _parseDouble(branch['commission']);
    final net = _parseDouble(branch['net']);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.isDarkMode ? AppColors.divider : AppColors.primary,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          title: Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                  color: AppColors.primary,
                ),
              ),
              if (isIb) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'Sub-IB · L$level',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            email,
            style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'DOWNLINE',
                    style: TextStyle(
                      fontSize: 8.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$clientsTree clients',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'BRANCH EARNED',
                    style: TextStyle(
                      fontSize: 8.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '\$${earned.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: 14.w,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
          children: [
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniMetric(
                    'DEPOSITS',
                    '\$${deposits.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                  _buildMiniMetric(
                    'NET',
                    '\$${net.toStringAsFixed(2)}',
                    AppColors.textPrimary,
                  ),
                  _buildMiniMetric(
                    'LOTS',
                    lots.toStringAsFixed(2),
                    AppColors.textPrimary,
                  ),
                  _buildMiniMetric(
                    'YOU EARNED',
                    '\$${earned.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ==========================
  // TAB 4: SYMBOL COMMISSION
  // ==========================
  Widget _buildSymbolCommissionTab() {
    final data = controller.currentNetworkSymbols;
    final rows = data['rows'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(3),
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          if (rows.isEmpty)
            Center(
              child: Text(
                'No symbol commission data',
                style: TextStyle(color: AppColors.textGrey),
              ),
            )
          else
            ...rows
                .map((row) => ListTile(title: Text(row['symbol'] ?? 'Unknown')))
                .toList(),
        ],
      ),
    );
  }

  // ==========================
  // TAB 5: COMMISSION PLAN
  // ==========================
  Widget _buildCommissionPlanTab() {
    final data = controller.currentNetworkPlan;
    final plan = data['plan'] ?? {};
    final groups = data['groups'] as List? ?? [];

    if (plan.isEmpty) {
      return Center(
        child: Text(
          'No commission plan assigned',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    final planName = plan['plan_name'] ?? 'Unknown Plan';

    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(4),
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.layers, color: AppColors.primary, size: 24.w),
                  SizedBox(width: 8.w),
                  Text(
                    planName,
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showChangePlanBottomSheet,
                icon: Icon(Icons.swap_horiz, size: 16.w),
                label: const Text('Change plan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: Color(0xFF5F259E)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          ...groups.map((group) {
            final groupName = group['name'] ?? 'Standard';
            final rates = group['rates'] as List? ?? [];
            return Container(
              margin: EdgeInsets.only(bottom: 16.h),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: ExpansionTile(
                title: Text(
                  groupName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${rates.length} rates',
                      style: TextStyle(color: Colors.green, fontSize: 12.sp),
                    ),
                    Icon(Icons.expand_more),
                  ],
                ),
                initiallyExpanded: true,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    color:
                        AppColors.isDarkMode
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF9F9F9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REBATE BY INSTRUMENT TYPE',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ...rates
                            .map(
                              (r) => _buildRateRow(
                                r['category'] ?? 'Unknown',
                                _parseDouble(r['rate_per_lot']),
                              ),
                            )
                            .toList(),
                        if (rates.isEmpty)
                          Text(
                            'No rates set for this group.',
                            style: TextStyle(
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
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRateRow(String category, double rate) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(category, style: TextStyle(fontSize: 13.sp)),
          Text(
            '\$${rate.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePlanBottomSheet() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color:
              AppColors.isDarkMode ? AppColors.pureBlack : AppColors.whiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          widget.clientName.isNotEmpty
                              ? widget.clientName.substring(0, 1).toUpperCase()
                              : 'C',
                          style: TextStyle(color: AppColors.whiteColor),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Move ${widget.clientName} to another plan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'It applies to commission from now on',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 11.sp,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search your plans',
                prefixIcon: const Icon(Icons.search),
                hintStyle: TextStyle(color: AppColors.textGrey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView(
                children: [
                  RadioListTile(
                    value: 1,
                    groupValue: 1,
                    onChanged: (v) {},
                    title: Row(
                      children: [
                        Text(
                          'Sub 7',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'On it now',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '1 partner(s) on it',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.whiteColor,
                  ),
                  child: const Text('Move them'),
                ),
                SizedBox(width: 12.w),
                OutlinedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
