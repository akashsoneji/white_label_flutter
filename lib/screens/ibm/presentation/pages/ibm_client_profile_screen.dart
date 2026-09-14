import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui' as ui show TextDirection;
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/change_plan_bottom_sheet.dart';
import 'package:crm_app/services/language_service.dart';

class IbmClientProfileScreen extends StatefulWidget {
  final int clientId;
  final String clientName;
  final bool isYou;

  const IbmClientProfileScreen({
    Key? key,
    required this.clientId,
    required this.clientName,
    this.isYou = false,
  }) : super(key: key);

  @override
  State<IbmClientProfileScreen> createState() => _IbmClientProfileScreenState();
}

class _IbmClientProfileScreenState extends State<IbmClientProfileScreen>
    with TickerProviderStateMixin {
  final IbmController controller = Get.find<IbmController>();
  late TabController _tabController;
  List<String> _tabNames = const ['Overview'];

  final List<String> _dateFilters = ['Today', '7D', '30D', 'MTD', 'All'];

  static const Map<String, String> _dateFilterKeys = {
    'Today': 'dc_range_today',
    'All': 'common_all',
    'Custom': 'transaction_history_period_custom',
  };

  static const Map<String, String> _tabNameKeys = {
    'Overview': 'common_overview',
    'Trades': 'tw_trades',
    'Network': 'ibm_nav_network',
    'Symbol-wise commission': 'ibm_symbol_wise_commission',
    'Commission plan': 'ibm_commission_plan',
  };

  String _dateFilterLabel(String name) {
    final key = _dateFilterKeys[name];
    return key == null ? name : TranslationUtils.tr(key);
  }

  String _tabLabel(String name) =>
      TranslationUtils.tr(_tabNameKeys[name] ?? name);
  String _selectedDateFilter = 'MTD';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Recursive network-tree state: each person card on the Network tab can
  // expand to show their own downline. Mirror the main tree's lazy-load
  // pattern so deep branches don't fetch until the user opens them.
  final Set<int> _expandedPersonIds = <int>{};
  final Map<int, List<Map<String, dynamic>>> _personChildrenCache =
      <int, List<Map<String, dynamic>>>{};
  final Set<int> _loadingPersonIds = <int>{};
  int _personDeepLevel = 4; // visual depth cap (avoid runaway nesting)

  // Tab set is resolved from the API, not hardcoded. On load we call
  // /portal/clients/{id} (isClient) and /portal/network/{id} (isIb) in
  // parallel and build the tabs from those two flags, exactly like the web
  // IBMgrPerson.vue: Overview always; +Trades if client; +Network,
  // +Symbol-wise if IB; +Commission plan if IB and not your own page.
  bool _isClient = false;
  bool _isIb = false;
  bool _tabsResolved = false;

  @override
  void initState() {
    super.initState();
    // Provisional single-tab controller until the flags resolve, so the
    // scaffold can build before the network round-trip completes.
    _tabController = TabController(length: 1, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveTabsAndLoad();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _fetchDataForTab(_tabController.index);
    }
  }

  /// Fire both classifier calls in parallel, decide the tab set, then rebuild
  /// the TabController to match. Overview data is already loaded by these two
  /// calls so the first tab renders immediately.
  Future<void> _resolveTabsAndLoad() async {
    final period = _mapFilterToApi(_selectedDateFilter);
    // Clear any data left over from a previously opened person so stale figures
    // can't leak into this profile's classification or cards.
    controller.currentClientOverview.clear();
    controller.currentPartnerDetail.clear();
    controller.currentPartnerWallet.clear();
    controller.currentPartnerLinks.clear();

    // Run BOTH classifier calls independently and guard each with a timeout.
    // A bare Future.wait would hang the whole screen forever if one endpoint
    // stalls (this was the mobile "stuck on Overview + spinner" bug). We never
    // let either call block tab-resolution: whatever settles decides the tabs.
    const timeout = Duration(seconds: 15);
    await Future.wait([
      controller
          .fetchClientOverview(widget.clientId, period: period)
          .timeout(timeout, onTimeout: () {})
          .catchError((_) {}),
      controller
          .fetchPartnerDetail(widget.clientId, period: period)
          .timeout(timeout, onTimeout: () {})
          .catchError((_) {}),
    ]);

    final isClient = controller.currentClientOverview.isNotEmpty;
    final isIb = controller.currentPartnerDetail.isNotEmpty;
    final isMe = widget.isYou;

    final tabs = <String>['Overview'];
    if (isClient) tabs.add('Trades');
    if (isIb) {
      tabs.add('Network');
      tabs.add('Symbol-wise commission');
      if (!isMe) tabs.add('Commission plan');
      // Overview's wallet + referral-link sections come from the partner's
      // own endpoints, not from /network/{id}. Fire them once here.
      controller.fetchPartnerWallet(widget.clientId, period: period);
      controller.fetchPartnerLinks(widget.clientId);
    }

    if (!mounted) return;
    setState(() {
      _isClient = isClient;
      _isIb = isIb;
      _tabsResolved = true;
      _tabNames = tabs;
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
      _tabController = TabController(length: tabs.length, vsync: this);
      _tabController.addListener(_onTabChanged);
    });
  }

  void _fetchDataForTab(int index) {
    String period = _mapFilterToApi(_selectedDateFilter);
    String? from =
        _customStartDate != null
            ? DateFormat('yyyy-MM-dd').format(_customStartDate!)
            : null;
    String? to =
        _customEndDate != null
            ? DateFormat('yyyy-MM-dd').format(_customEndDate!)
            : null;

    final tabName = _tabNames[index];
    if (tabName == 'Overview') {
      controller.fetchClientOverview(
        widget.clientId,
        period: period,
        from: from,
        to: to,
      );
      // Overview's downline cards + wallet come from the partner endpoints;
      // refresh them too so the date filter moves those figures for IBs.
      if (_isIb) {
        controller.fetchPartnerDetail(widget.clientId, period: period);
        controller.fetchPartnerWallet(widget.clientId, period: period);
      }
    } else if (tabName == 'Trades') {
      controller.fetchClientTrades(
        widget.clientId,
        period: period,
        from: from,
        to: to,
      );
    } else if (tabName == 'Network') {
      controller.fetchNetworkNode(
        widget.clientId,
        period: period,
        from: from,
        to: to,
      );
    } else if (tabName == 'Symbol-wise commission') {
      controller.fetchNetworkSymbols(
        widget.clientId,
        period: period,
        from: from,
        to: to,
      );
    } else if (tabName == 'Commission plan') {
      controller.fetchNetworkPlan(widget.clientId);
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
      case 'Custom':
        return 'custom';
      default:
        return 'mtd';
    }
  }

  void _onDateFilterChanged(String filter) {
    setState(() {
      _selectedDateFilter = filter;
      _customStartDate = null;
      _customEndDate = null;
    });
    _fetchDataForTab(_tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
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
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        '\$$balance',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(130.h),
          child: Container(
            color:
                AppColors.isDarkMode
                    ? AppColors.pureBlack
                    : AppColors.whiteColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfileHeader(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.zero,
                        labelPadding: EdgeInsets.symmetric(horizontal: 14.w),
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: EdgeInsets.zero,
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        labelColor: AppColors.whiteColor,
                        unselectedLabelColor: AppColors.textGrey,
                        labelStyle: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs:
                            _tabNames
                                .map(
                                  (name) =>
                                      Tab(
                                        height: 32.h,
                                        child: Text(_tabLabel(name)),
                                      ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        // Only block the whole screen until the classifier calls finish and
        // the tab set is known. After that each tab owns its own empty/loading
        // state, so a person whose endpoints return no data still gets tabs
        // instead of an infinite spinner.
        if (!_tabsResolved) {
          return Center(
            child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
          );
        }

        // Build the tab bodies in the SAME order _tabNames was assembled in
        // _resolveTabsAndLoad, so the TabController index always maps to the
        // right builder regardless of whether the person is a client, an IB,
        // or both.
        return TabBarView(
          controller: _tabController,
          children:
              _tabNames.map<Widget>((name) => _buildTabBody(name)).toList(),
        );
      }),
    );
  }

  /// Maps a resolved tab name to its body builder. Keeps the TabBarView
  /// children in lockstep with _tabNames.
  Widget _buildTabBody(String name) {
    switch (name) {
      case 'Trades':
        return _buildTradesTab();
      case 'Network':
        return _buildNetworkTab();
      case 'Symbol-wise commission':
        return _buildSymbolCommissionTab();
      case 'Commission plan':
        return _buildCommissionPlanTab();
      case 'Overview':
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: AppColors.primary,
                child: Text(
                  widget.clientName.isNotEmpty
                      ? widget.clientName.substring(0, 1).toUpperCase()
                      : 'C',
                  style: TextStyle(
                    color: AppColors.whiteColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.clientName,
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        if (_isIb || _isClient)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: (_isIb
                                      ? AppColors.primary
                                      : const Color(0xFF00C48C))
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              _isIb
                                  ? TranslationUtils.tr(
                                    'ib_clients_screen_sub_ib',
                                  )
                                  : TranslationUtils.tr('ibm_client'),
                              style: TextStyle(
                                color:
                                    _isIb
                                        ? AppColors.primary
                                        : const Color(0xFF00C48C),
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Obx(() {
                      final data = controller.currentClientOverview;
                      final client =
                          data['client'] is Map ? data['client'] as Map : {};
                      final email = client['email']?.toString() ?? '';

                      return Text(
                        '$email',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 11.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                    Obx(() {
                      final data = controller.currentClientOverview;
                      final client =
                          data['client'] is Map ? data['client'] as Map : {};

                      final joined =
                          client['joined_at']?.toString() ??
                          client['created_at']?.toString() ??
                          '';
                      final joinedStr =
                          joined.isNotEmpty
                              ? ' • ${TranslationUtils.trArgs('ibm_joined_date', {'date': joined})}'
                              : '';
                      return Text(
                        '$joinedStr',
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
            ],
          ),
          SizedBox(height: 8.h),
          _buildDateFilters(),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color:
            AppColors.isDarkMode
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF1EEF8),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: List.generate(_dateFilters.length, (index) {
          final filter = _dateFilters[index];
          final isSelected = _selectedDateFilter == filter;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
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
                  _fetchDataForTab(_tabController.index);
                } else {
                  _onDateFilterChanged(filter);
                }
              },
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  filter == 'Custom' && _customStartDate != null
                      ? '${DateFormat('MM/dd').format(_customStartDate!)}-${DateFormat('MM/dd').format(_customEndDate!)}'
                      : _dateFilterLabel(filter),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isSelected
                            ? AppColors.whiteColor
                            : (AppColors.isDarkMode
                                ? Colors.white70
                                : AppColors.textSecondary),
                    fontSize: 11.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================
  // TAB 1: OVERVIEW
  // ==========================
  Widget _buildOverviewTab() {
    return Obx(() {
      final client = controller.currentClientOverview;
      final partner = controller.currentPartnerDetail;

      if (client.isEmpty && partner.isEmpty) {
        return Center(
          child: Text(
            TranslationUtils.tr('ibm_no_overview_data_available'),
            style: TextStyle(color: AppColors.textGrey),
          ),
        );
      }

      // ---- THEIR DOWNLINE (partner) — GET /portal/network/{id} ----
      final Map clientsBlock =
          partner['clients'] is Map ? partner['clients'] as Map : {};
      final Map partnerBlock =
          partner['partner'] is Map ? partner['partner'] as Map : {};
      // branchCurrencies() row — take first currency block (USD-first).
      final Map branch = _firstCurrency(partner['branch']);

      final int clientsOwn = _parseInt(clientsBlock['own']);
      final int clientsTotal = _parseInt(clientsBlock['branch']);
      final int subIbs = _countSubPartners(partnerBlock['sub_partners']);

      // ---- CLIENT TOTALS ----
      final List<dynamic> clientTotalsList =
          client['totals'] is List ? client['totals'] as List : const [];

      final double branchDeposits = _parseDouble(branch['deposits']);
      final double branchWithdrawals = _parseDouble(branch['withdrawals']);
      final double branchNetFunding = _parseDouble(branch['net_funding']);
      final double branchEquity = _parseDouble(branch['equity']);
      final double branchLots = _parseDouble(branch['lots']);
      final double branchYouEarned = _parseDouble(branch['commission']);

      // ---- THEIR WALLET — GET /portal/network/{id}/wallet ----
      final Map wallet = _firstCurrency(
        controller.currentPartnerWallet['wallets'],
      );

      // ---- THEIR REFERRAL LINKS — GET /portal/network/{id}/links ----
      final List<dynamic> links =
          controller.currentPartnerLinks['links'] is List
              ? controller.currentPartnerLinks['links'] as List
              : const [];

      // ---- accounts + history — GET /portal/clients/{id} ----
      final List<dynamic> accounts =
          client['accounts'] is List ? client['accounts'] as List : const [];
      // client detail exposes the timeline as `events`, not `history`.
      final List<dynamic> history =
          client['events'] is List
              ? client['events'] as List
              : (client['history'] is List
                  ? client['history'] as List
                  : const []);

      return _buildOverviewBody(
        isIb: _isIb,
        clientsOwn: clientsOwn,
        clientsTotal: clientsTotal,
        subIbs: subIbs,
        branchDeposits: branchDeposits,
        branchWithdrawals: branchWithdrawals,
        branchNetFunding: branchNetFunding,
        branchEquity: branchEquity,
        branchLots: branchLots,
        branchYouEarned: branchYouEarned,
        clientTotals: clientTotalsList,
        wallet: wallet,
        links: links,
        accounts: accounts,
        history: history,
      );
    });
  }

  /// First per-currency block from a `[{currency:..}]` list (USD-first), or {}.
  Map _firstCurrency(dynamic list) {
    if (list is List && list.isNotEmpty) {
      final usd = list.firstWhere(
        (e) => e is Map && (e['currency']?.toString().toUpperCase() == 'USD'),
        orElse: () => list.first,
      );
      return usd is Map ? usd : {};
    }
    return {};
  }

  int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// `sub_partners` is a JSON object map {user_id: name}; count its entries.
  int _countSubPartners(dynamic v) {
    if (v is Map) return v.length;
    if (v is List) return v.length;
    return _parseInt(v);
  }

  Widget _buildOverviewBody({
    required bool isIb,
    required int clientsOwn,
    required int clientsTotal,
    required int subIbs,
    required double branchDeposits,
    required double branchWithdrawals,
    required double branchNetFunding,
    required double branchEquity,
    required double branchLots,
    required double branchYouEarned,
    required List<dynamic> clientTotals,
    required Map wallet,
    required List<dynamic> links,
    required List<dynamic> accounts,
    required List<dynamic> history,
  }) {
    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(0),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16, 16.w, 16.w),
        children: [
          if (isIb) ...[
            Text(
              TranslationUtils.tr('ibm_their_downline'),
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
                        title: TranslationUtils.tr('ib_nav_clients'),
                        value: '$clientsOwn / $clientsTotal',
                        subtitle: TranslationUtils.tr(
                          'ibm_own_whole_branch',
                        ),
                        icon: Icons.group,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _buildMetricCard(
                        title: TranslationUtils.tr('ibm_sub_ibs'),
                        value: '$subIbs',
                        subtitle: TranslationUtils.tr(
                          'ibm_working_under_them',
                        ),
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
                        title: TranslationUtils.tr(
                          'transaction_history_deposits',
                        ),
                        value: '\$${branchDeposits.toStringAsFixed(2)}',
                        subtitle: TranslationUtils.tr(
                          'ibm_branch_this_period',
                        ),
                        icon: Icons.arrow_downward,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _buildMetricCard(
                        title: TranslationUtils.tr(
                          'transaction_history_withdrawals',
                        ),
                        value: '\$${branchWithdrawals.toStringAsFixed(2)}',
                        subtitle: TranslationUtils.tr(
                          'ibm_branch_this_period',
                        ),
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: TranslationUtils.tr('ibm_net_funding'),
                        value: '\$${branchNetFunding.toStringAsFixed(2)}',
                        subtitle: TranslationUtils.tr(
                          'ibm_deposits_minus_withdrawals',
                        ),
                        icon: Icons.swap_vert,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _buildMetricCard(
                        title: TranslationUtils.tr('dashboard_equity'),
                        value: '\$${branchEquity.toStringAsFixed(2)}',
                        subtitle: TranslationUtils.tr(
                          'ibm_right_now_not_the_period',
                        ),
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
                        title: TranslationUtils.tr('chart_label_lots'),
                        value: branchLots.toStringAsFixed(2),
                        subtitle: TranslationUtils.tr(
                          'ibm_branch_this_period',
                        ),
                        icon: Icons.show_chart,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _buildMetricCard(
                        title: TranslationUtils.tr('ibm_you_earned'),
                        value: '\$${branchYouEarned.toStringAsFixed(2)}',
                        subtitle: TranslationUtils.tr(
                          'ibm_your_share_from_them',
                        ),
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
              TranslationUtils.tr('ibm_their_referral_links'),
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8.h),
            if (links.isEmpty)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  TranslationUtils.tr('ibm_no_links_created_by_partner'),
                  style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
                ),
              )
            else
              ...links.map((l) {
                final linkMap = l is Map ? l : {};
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _buildLinkRow(
                    linkMap['label']?.toString() ?? 'Default Link',
                    linkMap['code']?.toString() ?? '--',
                    '${linkMap['signups'] ?? linkMap['visits'] ?? 0}',
                    '${linkMap['funded'] ?? 0}',
                  ),
                );
              }).toList(),

            SizedBox(height: 24.h),
            Text(
              TranslationUtils.tr('ibm_their_wallet_upper'),
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
                        title: TranslationUtils.tr('ibm_available'),
                        value:
                            '\$${_parseDouble(wallet['available'] ?? wallet['balance']).toStringAsFixed(2)}',
                        subtitle: TranslationUtils.tr(
                          'ibm_they_can_request_this',
                        ),
                        icon: Icons.payments,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _buildMetricCard(
                        title: TranslationUtils.tr('ibm_pending_payout'),
                        value:
                            '\$${_parseDouble(wallet['pending'] ?? wallet['pending_payout']).toStringAsFixed(2)}',
                        subtitle: TranslationUtils.tr(
                          'ibm_locked_in_open_request',
                        ),
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
                        title: TranslationUtils.tr('ibm_earned_all_time'),
                        value:
                            '\$${_parseDouble(wallet['earned_all_time'] ?? wallet['lifetime_earned']).toStringAsFixed(2)}',
                        subtitle: TranslationUtils.tr('ibm_their_own_share'),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _buildMetricCard(
                        title: TranslationUtils.tr('ibm_paid_out'),
                        value:
                            '\$${_parseDouble(wallet['paid_out'] ?? wallet['lifetime_paid']).toStringAsFixed(2)}',
                        subtitle: 'settled',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 24.h),
            Text(
              TranslationUtils.tr('ibm_their_own_trading'),
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ] else ...[
            Text(
              'OVERVIEW',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
          SizedBox(height: 8.h),

          ...clientTotals.map((cTotal) {
            final Map cMap = cTotal is Map ? cTotal : {};
            final curr = cMap['currency']?.toString() ?? 'USD';
            final dep = _parseDouble(cMap['deposits']);
            final withdr = _parseDouble(cMap['withdrawals']);
            final net = _parseDouble(cMap['net_funding']);
            final eq = _parseDouble(cMap['equity']);
            final lots = _parseDouble(cMap['lots']);
            final comm = _parseDouble(cMap['commission']);

            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: TranslationUtils.tr(
                            'transaction_history_deposits',
                          ),
                          value: '$curr ${dep.toStringAsFixed(2)}',
                          subtitle: TranslationUtils.tr('ibm_this_period_lower'),
                          icon: Icons.arrow_downward,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildMetricCard(
                          title: TranslationUtils.tr(
                            'transaction_history_withdrawals',
                          ),
                          value: '$curr ${withdr.toStringAsFixed(2)}',
                          subtitle: TranslationUtils.tr('ibm_this_period_lower'),
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
                          title: TranslationUtils.tr('ibm_net_funding'),
                          value: '$curr ${net.toStringAsFixed(2)}',
                          subtitle: TranslationUtils.tr(
                            'ibm_deposits_minus_withdrawals',
                          ),
                          icon: Icons.account_balance,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildMetricCard(
                          title: TranslationUtils.tr('dashboard_equity'),
                          value: '$curr ${eq.toStringAsFixed(2)}',
                          subtitle: TranslationUtils.tr(
                            'ibm_right_now_not_the_period',
                          ),
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
                          title: TranslationUtils.tr('chart_label_lots'),
                          value: lots.toStringAsFixed(2),
                          subtitle: TranslationUtils.tr('ibm_this_period_lower'),
                          icon: Icons.bar_chart,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildMetricCard(
                          title: TranslationUtils.tr('ibm_you_earned'),
                          value: '$curr ${comm.toStringAsFixed(2)}',
                          subtitle: TranslationUtils.tr('ibm_your_share'),
                          icon: Icons.monetization_on,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),

          if (clientTotals.isEmpty)
            Container(
              padding: EdgeInsets.all(12.w),
              margin: EdgeInsets.only(bottom: 16.h),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                TranslationUtils.tr('ibm_no_trading_data_available'),
                style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
              ),
            ),

          if (accounts.isNotEmpty) ...[
            SizedBox(height: 24.h),
            Text(
              TranslationUtils.trArgs('ibm_trading_accounts_count', {
                'count': '${accounts.length}',
              }),
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8.h),
            ...accounts.map((acc) {
              final accMap = acc is Map ? acc : {};
              final accNum =
                  accMap['account_number']?.toString() ??
                  accMap['login']?.toString() ??
                  '--';
              final curr = accMap['currency']?.toString() ?? 'USD';
              final grp =
                  accMap['group']?.toString() ??
                  accMap['plan_group']?.toString() ??
                  'Standard';
              final bal = _parseDouble(accMap['balance']).toStringAsFixed(2);
              final eq = _parseDouble(accMap['equity']).toStringAsFixed(2);
              final lts = _parseDouble(accMap['lots']).toStringAsFixed(2);

              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
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
                          '#$accNum · $curr · $grp',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          TranslationUtils.trArgs('ibm_account_balance_row', {
                            'balance': bal,
                            'equity': eq,
                            'lots': lts,
                          }),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        final idx = _tabNames.indexOf('Trades');
                        if (idx >= 0) _tabController.animateTo(idx);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          TranslationUtils.tr('ibm_see_trades'),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],

          if (history.isNotEmpty) ...[
            SizedBox(height: 24.h),
            Text(
              'HISTORY',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children:
                    history.map((h) {
                      final hMap = h is Map ? h : {};
                      final title =
                          hMap['title']?.toString() ??
                          (hMap['type'] == 'deposit'
                              ? 'Deposit +\$${_parseDouble(hMap['amount']).toStringAsFixed(2)}'
                              : (hMap['type']?.toString() ?? 'Event'));
                      final date =
                          hMap['at']?.toString() ??
                          hMap['date']?.toString() ??
                          hMap['created_at']?.toString() ??
                          '--';

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6.w,
                                  height: 6.w,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
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
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(icon, color: c, size: 14.w),
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
              Text(
                TranslationUtils.trArgs('ibm_signed_up_count', {
                  'count': '$signedUp',
                }),
                style: TextStyle(fontSize: 11.sp),
              ),
              Text(
                TranslationUtils.trArgs('ibm_funded_count', {
                  'count': '$funded',
                }),
                style: TextStyle(fontSize: 11.sp),
              ),
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
  String _tradeSideFilter = 'All';
  String _tradeSymbolQuery = '';

  Widget _buildTradesTab() {
    final data = controller.currentClientTrades;
    final List<dynamic> rawRows =
        data['rows'] is List ? data['rows'] as List : [];
    final rows =
        rawRows.where((t) {
          if (t is! Map) return false;
          if (_tradeSideFilter != 'All') {
            final side =
                (t['type'] ?? t['side'] ?? '').toString().toLowerCase();
            if (side != _tradeSideFilter.toLowerCase()) return false;
          }
          if (_tradeSymbolQuery.isNotEmpty) {
            final sym = (t['symbol'] ?? '').toString().toLowerCase();
            if (!sym.contains(_tradeSymbolQuery.toLowerCase())) return false;
          }
          return true;
        }).toList();

    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(1),
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Row(
            children: [
              ['All', 'Buy', 'Sell']
                  .map((side) {
                    final isSel = _tradeSideFilter == side;
                    return Padding(
                      padding: EdgeInsetsDirectional.only(end: 8.w),
                      child: ChoiceChip(
                        label: Text(side),
                        selected: isSel,
                        onSelected:
                            (_) => setState(() => _tradeSideFilter = side),
                        selectedColor: AppColors.primary,
                        checkmarkColor: AppColors.whiteColor,
                        labelStyle: TextStyle(
                          color:
                              isSel
                                  ? AppColors.whiteColor
                                  : AppColors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    );
                  })
                  .toList()
                  .first,
              ...['Buy', 'Sell'].map((side) {
                final isSel = _tradeSideFilter == side;
                return Padding(
                  padding: EdgeInsetsDirectional.only(end: 8.w),
                  child: ChoiceChip(
                    label: Text(side),
                    selected: isSel,
                    onSelected: (_) => setState(() => _tradeSideFilter = side),
                    selectedColor: AppColors.primary,
                    checkmarkColor: AppColors.whiteColor,
                    labelStyle: TextStyle(
                      color:
                          isSel
                              ? AppColors.whiteColor
                              : AppColors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                );
              }),
            ],
          ),
          SizedBox(height: 12.h),

          // Symbol Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged:
                      (v) => setState(() => _tradeSymbolQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: TranslationUtils.tr('ibm_filter_by_symbol'),
                    hintStyle: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textGrey,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          if (rows.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 40.w, color: AppColors.textGrey),
                  SizedBox(height: 12.h),
                  Text(
                    TranslationUtils.tr('ibm_no_closed_trades'),
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    TranslationUtils.tr('ibm_nothing_closed_on_selection'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            )
          else
            ...rows.map((t) {
              final trade = t is Map ? t : {};
              final ticket =
                  trade['account']?.toString() ??
                  trade['ticket']?.toString() ??
                  trade['trade_id']?.toString() ??
                  trade['id']?.toString() ??
                  '--';
              final symbol = trade['symbol']?.toString() ?? 'EURUSD';
              final type =
                  (trade['side'] ?? trade['type'] ?? 'BUY')
                      .toString()
                      .toUpperCase();
              final lots = _parseDouble(trade['lots']).toStringAsFixed(2);
              final openPrice = _parseDouble(
                trade['open_price'],
              ).toStringAsFixed(2);
              final closePrice = _parseDouble(
                trade['close_price'],
              ).toStringAsFixed(2);
              final double profitValue = _parseDouble(trade['profit']);
              final profit = profitValue.toStringAsFixed(2);
              final commission = _parseDouble(
                trade['commission'],
              ).toStringAsFixed(2);
              final openTime =
                  trade['opened_at']?.toString() ??
                  trade['open_time']?.toString() ??
                  '--';
              final closeTime =
                  trade['closed_at']?.toString() ??
                  trade['close_time']?.toString() ??
                  trade['created_at']?.toString() ??
                  '--';
              final isBuy = type == 'BUY';

              return Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isBuy
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isBuy
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              symbol,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              '#$ticket',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          TranslationUtils.trArgs('ibm_plus_earned_amount', {
                            'amount': commission,
                          }),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TranslationUtils.trArgs('ibm_trade_lots_value', {
                            'lots': '$lots',
                          }),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          TranslationUtils.trArgs(
                            'ibm_trade_open_close_price',
                            {'open': '$openPrice', 'close': '$closePrice'},
                          ),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          TranslationUtils.trArgs('ibm_trade_pl_value', {
                            'profit': '$profit',
                          }),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: profitValue < 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TranslationUtils.trArgs('ibm_trade_open_time', {
                            'time': '$openTime',
                          }),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          TranslationUtils.trArgs('ibm_trade_close_time', {
                            'time': '$closeTime',
                          }),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // ==========================
  // TAB 3: NETWORK
  // ==========================
  // ==========================
  // TAB 3: NETWORK
  // ==========================
  Widget _buildNetworkTab() {
    final data = controller.currentNetworkNode;
    final people =
        data['people'] as List? ??
        data['sub_ibs'] as List? ??
        data['clients'] as List? ??
        [];

    if (people.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 48.w,
                color: AppColors.textGrey,
              ),
              SizedBox(height: 12.h),
              Text(
                TranslationUtils.tr('ibm_no_network_data_found'),
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(2),
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children:
            people
                .map<Widget>(
                  (person) => _buildNetworkNodeCard(person, level: 1),
                )
                .toList(),
      ),
    );
  }

  Widget _buildNetworkNodeCard(dynamic person, {required int level}) {
    final p = person is Map ? person : {};
    final name =
        (p['name'] ?? p['partner_name'] ?? p['username'] ?? 'Unknown')
            .toString();
    final email = (p['email'] ?? '').toString();
    final account =
        (p['first_account'] ?? p['account_number'] ?? '').toString();
    final isIb = p['is_ib'] == true;
    final isDirect = p['is_direct'] == true;
    final apiLevel = p['level'] ?? level;
    final plan = (p['plan_name'] ?? p['plan'] ?? 'Sub 7').toString();
    final via = (p['via_link'] ?? p['via'] ?? '').toString();
    final clientsTree = p['clients_tree'] ?? p['clients_count'] ?? 0;
    final subIbs = p['sub_ibs'] ?? 0;
    final partnerId =
        int.tryParse(
          (p['user_id'] ?? p['partner_user_id'] ?? p['id'] ?? 0).toString(),
        ) ??
        0;

    final branchList = p['branch'] as List? ?? [];
    final branch =
        branchList.isNotEmpty
            ? branchList[0] as Map
            : (p['branch'] is Map ? p['branch'] as Map : {});
    final ownList = p['own'] as List? ?? [];
    final own = ownList.isNotEmpty ? ownList[0] as Map : {};

    final deposits = _parseDouble(own['deposits'] ?? p['deposits']);
    final net = _parseDouble(own['net'] ?? own['net_funding'] ?? p['net']);
    final lots = _parseDouble(own['lots'] ?? p['lots']);
    final earned = _parseDouble(
      own['commission'] ?? p['you_earned'] ?? p['commission'],
    );
    final branchEarned = _parseDouble(
      p['branch_earned'] ?? branch['commission'] ?? branch['you_earned'],
    );
    final showBranchEarned = branchEarned > 0;

    final subtitleParts = <String>[];
    if (account.isNotEmpty) subtitleParts.add('#$account');
    if (email.isNotEmpty) subtitleParts.add(email);
    if (plan.isNotEmpty) subtitleParts.add(plan);
    if (via.isNotEmpty) {
      subtitleParts.add(TranslationUtils.trArgs('ibm_via_source', {
        'source': via,
      }));
    }

    final canOpen = partnerId > 0 && partnerId != widget.clientId;
    final canExpand =
        level < _personDeepLevel && (subIbs > 0 || clientsTree > 0);
    final isExpanded = canExpand && _expandedPersonIds.contains(partnerId);
    final isLoadingChildren = _loadingPersonIds.contains(partnerId);
    final children = _personChildrenCache[partnerId];

    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          canOpen
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
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4.w,
                color: isIb ? AppColors.primary : const Color(0xFFF2994A),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6.w,
                              runSpacing: 4.h,
                              children: [
                                if (canExpand)
                                  GestureDetector(
                                    onTap:
                                        () => _togglePersonExpansion(partnerId),
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.only(end: 2.w),
                                      child: Icon(
                                        isExpanded
                                            ? Icons.expand_more
                                            : Icons.chevron_right,
                                        size: 18.w,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (isIb)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(
                                        0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      TranslationUtils.trArgs(
                                        'ibm_sub_ib_level',
                                        {'level': '$apiLevel'},
                                      ),
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (isDirect)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF00C48C,
                                      ).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      TranslationUtils.tr('ibm_direct_client'),
                                      style: const TextStyle(
                                        color: Color(0xFF00C48C),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (canOpen) ...[
                            GestureDetector(
                              onTap: () {
                                Get.to(
                                  () => IbmClientProfileScreen(
                                    clientId: partnerId,
                                    clientName: name,
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.arrow_forward,
                                size: 18.w,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          subtitleParts.join(' · '),
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 10.sp,
                          ),
                        ),
                      ],
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.isDarkMode
                                  ? AppColors.surface
                                  : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Wrap(
                          spacing: 14.w,
                          runSpacing: 6.h,
                          children: [
                            _buildMiniMetric(
                              'DEPOSITS',
                              '\$${deposits.toStringAsFixed(2)}',
                              const Color(0xFF00C48C),
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
                              TranslationUtils.tr('ibm_you_earned_upper'),
                              '\$${earned.toStringAsFixed(2)}',
                              const Color(0xFF00C48C),
                            ),
                            if (subIbs > 0 || clientsTree > 0)
                              _buildMiniMetric(
                                TranslationUtils.tr('ibm_downline_caps'),
                                TranslationUtils.trArgs(
                                  'ibm_downline_subs_clients_short',
                                  {
                                    'subs': '$subIbs',
                                    'clients': '$clientsTree',
                                  },
                                ),
                                AppColors.textPrimary,
                              ),
                            if (showBranchEarned)
                              _buildMiniMetric(
                                TranslationUtils.tr('ibm_branch_earned_upper'),
                                '\$${branchEarned.toStringAsFixed(2)}',
                                const Color(0xFF00C48C),
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
    );

    if (!canExpand) {
      return Padding(
        padding: EdgeInsetsDirectional.only(start: (level - 1) * 12.w),
        child: card,
      );
    }

    Widget expandArea;
    if (isLoadingChildren) {
      expandArea = Padding(
        padding: EdgeInsetsDirectional.only(start: (level) * 12.w, top: 4.h, bottom: 8.h),
        child: Row(
          children: [
            SizedBox(
              width: 14.w,
              height: 14.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              TranslationUtils.tr('common_loading'),
              style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp),
            ),
          ],
        ),
      );
    } else if (children == null) {
      expandArea = const SizedBox.shrink();
    } else if (children.isEmpty) {
      expandArea = Padding(
        padding: EdgeInsetsDirectional.only(start: (level) * 12.w, top: 4.h, bottom: 8.h),
        child: Text(
          TranslationUtils.tr('ibm_no_downline'),
          style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp),
        ),
      );
    } else if (isExpanded) {
      expandArea = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            children
                .map<Widget>(
                  (child) => _buildNetworkNodeCard(child, level: level + 1),
                )
                .toList(),
      );
    } else {
      expandArea = const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsetsDirectional.only(start: (level - 1) * 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card,
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: expandArea,
          ),
        ],
      ),
    );
  }

  Future<void> _togglePersonExpansion(int personId) async {
    if (personId <= 0) return;
    final wasExpanded = _expandedPersonIds.contains(personId);
    setState(() {
      if (wasExpanded) {
        _expandedPersonIds.remove(personId);
      } else {
        _expandedPersonIds.add(personId);
      }
    });
    if (wasExpanded) return;
    if (_personChildrenCache.containsKey(personId)) return;
    setState(() => _loadingPersonIds.add(personId));
    try {
      final period = _mapFilterToApi(_selectedDateFilter);
      final fetched = await controller.getNetworkNodeChildren(
        personId,
        period: period,
      );
      if (!mounted) return;
      setState(() {
        _personChildrenCache[personId] = fetched;
        _loadingPersonIds.remove(personId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPersonIds.remove(personId));
    }
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
  String _symbolQuery = '';

  Widget _buildSymbolCommissionTab() {
    final data = controller.currentNetworkSymbols;
    final List<dynamic> rawRows =
        data['rows'] is List ? data['rows'] as List : [];
    final rows =
        rawRows.where((r) {
          if (r is! Map) return false;
          if (_symbolQuery.isEmpty) return true;
          final sym = (r['symbol'] ?? r['pair'] ?? '').toString().toLowerCase();
          return sym.contains(_symbolQuery.toLowerCase());
        }).toList();

    double totalLots = 0.0;
    int totalTrades = 0;
    double totalEarned = 0.0;

    for (final r in rows) {
      if (r is Map) {
        totalLots += _parseDouble(r['lots']);
        totalTrades += int.tryParse((r['trades'] ?? 0).toString()) ?? 0;
        totalEarned += _parseDouble(r['you_earned'] ?? r['commission']);
      }
    }

    return RefreshIndicator(
      onRefresh: () async => _fetchDataForTab(3),
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Filter by pair search
          Row(
            children: [
              Icon(Icons.search, size: 16.w, color: AppColors.textGrey),
              SizedBox(width: 8.w),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _symbolQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: TranslationUtils.tr('ibm_filter_by_pair'),
                    hintStyle: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textGrey,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          if (rows.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              alignment: Alignment.center,
              child: Text(
                TranslationUtils.tr('ibm_no_symbol_commission_data'),
                style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp),
              ),
            )
          else ...[
            ...rows.map((row) {
              final r = row is Map ? row : {};
              final pair =
                  r['symbol']?.toString() ?? r['pair']?.toString() ?? 'Pair';
              final trades = r['trades'] ?? 0;
              final lots = _parseDouble(r['lots']).toStringAsFixed(2);
              final ownClients = _parseDouble(
                r['your_own_clients'] ?? r['own_commission'],
              ).toStringAsFixed(2);
              final subIbs = _parseDouble(
                r['their_sub_ibs'] ?? r['sub_commission'],
              ).toStringAsFixed(2);
              final earned = _parseDouble(
                r['you_earned'] ?? r['commission'],
              ).toStringAsFixed(2);
              final share = r['share']?.toString() ?? '100%';

              return Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pair,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '\$$earned',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TranslationUtils.trArgs('ibm_trades_lots_line', {
                            'trades': '$trades',
                            'lots': '$lots',
                          }),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          TranslationUtils.trArgs('ibm_share_value', {
                            'share': share,
                          }),
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TranslationUtils.trArgs('ibm_your_own_clients_amount', {
                            'amount': ownClients,
                          }),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          TranslationUtils.trArgs('ibm_their_sub_ibs_amount', {
                            'amount': subIbs,
                          }),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),

            // Summary Total Card
            Container(
              margin: EdgeInsets.only(top: 8.h),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TranslationUtils.tr('ibm_all_pairs_usd'),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        TranslationUtils.trArgs('ibm_trades_lots_line', {
                          'trades': '$totalTrades',
                          'lots': totalLots.toStringAsFixed(2),
                        }),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$${totalEarned.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================
  // TAB 5: COMMISSION PLAN
  // ==========================
  Widget _buildCommissionPlanTab() {
    return Obx(() {
      final data = controller.currentNetworkPlan;

      if (controller.isProfileLoading.value && data.isEmpty) {
        return Center(
          child: CommonLoadingWidget(size: 40.0, color: AppColors.primary),
        );
      }

      final planRaw = data['plan'];
      final Map<String, dynamic> plan =
          planRaw is Map ? Map<String, dynamic>.from(planRaw) : {};
      final rawGroups = data['groups'];
      final List groups = rawGroups is List ? rawGroups : [];

      if (plan.isEmpty) {
        return Center(
          child: Text(
            TranslationUtils.tr('ibm_no_commission_plan_assigned'),
            style: TextStyle(color: AppColors.textGrey),
          ),
        );
      }

      final planName = plan['plan_name'] ?? plan['name'] ?? 'Unknown Plan';

      return RefreshIndicator(
        onRefresh: () async => _fetchDataForTab(4),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.layers, color: AppColors.primary, size: 24.w),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          planName,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                InkWell(
                  onTap: _showChangePlanBottomSheet,
                  borderRadius: BorderRadius.circular(8.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 16.w,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          TranslationUtils.tr(
                            'pmam_manager_detail_screen_change_plan',
                          ),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            ...groups.whereType<Map>().map((group) {
              final groupName = group['name'] ?? 'Standard';
              final rates =
                  group['rates'] is List ? group['rates'] as List : [];
              return Container(
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12.r),
                  border: BoxBorder.all(color: AppColors.card),
                ),
                child: ExpansionTile(
                  title: Text(
                    groupName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TranslationUtils.trArgs('ibm_rates_count', {
                          'count': '${rates.length}',
                        }),
                        style: TextStyle(color: Colors.green, fontSize: 12.sp),
                      ),
                      Icon(Icons.expand_more),
                    ],
                  ),
                  initiallyExpanded: true,
                  shape: const Border(),
                  collapsedShape: const Border(),
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
                            TranslationUtils.tr('ibm_rebate_by_instrument_type'),
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
                              TranslationUtils.tr('ibm_no_rates_set_for_group'),
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

            if (groups.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 24.h),
                child: Text(
                  TranslationUtils.tr('ibm_no_rate_groups_configured'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
                ),
              ),
          ],
        ),
      );
    });
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
    final data = controller.currentNetworkPlan;
    final int? currentPlanId =
        data['plan_id'] is int
            ? data['plan_id'] as int
            : int.tryParse(data['plan_id']?.toString() ?? '');

    Get.bottomSheet(
      ChangePlanBottomSheet(
        ibUserId: widget.clientId,
        ibName: widget.clientName,
        currentPlanId: currentPlanId,
        onAssigned: () => controller.fetchNetworkPlan(widget.clientId),
      ),
      isScrollControlled: true,
    );
  }
}
