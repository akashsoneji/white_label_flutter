import 'dart:async';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/presentation/pages/create_edit_plan_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_commission_distribution_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_exports_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_reports_screen.dart';

import 'package:crm_app/screens/ibm/presentation/widgets/assign_plan_bottom_sheet.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/screens/ibm/utils/ibm_currency.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class IbmWalletScreen extends StatefulWidget {
  const IbmWalletScreen({super.key});

  @override
  State<IbmWalletScreen> createState() => _IbmWalletScreenState();
}

class _IbmWalletScreenState extends State<IbmWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IbmController controller = Get.find<IbmController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchWallet();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          TranslationUtils.tr('general_commission'),
          style: AppTextStyles.heading.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: TranslationUtils.tr('ibm_reports'),
            icon: Icon(Icons.assessment_outlined, color: AppColors.textPrimary),
            onPressed: () => Get.to(() => const IbmReportsScreen()),
          ),
          Obx(() {
            final balanceStr = '\$${controller.walletBalance}';
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
                      textDirection: TextDirection.ltr,
                      child: Text(
                        balanceStr,
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
                controller: _tabController,
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
                  Tab(text: TranslationUtils.tr('ibm_my_commission')),
                  Tab(text: TranslationUtils.tr('ibm_commission_plans')),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [MyCommissionTab(), CommissionPlansTab()],
      ),
    );
  }
}

class MyCommissionTab extends StatefulWidget {
  const MyCommissionTab({super.key});

  @override
  State<MyCommissionTab> createState() => _MyCommissionTabState();
}

class _MyCommissionTabState extends State<MyCommissionTab> {
  final IbmApiProvider _apiProvider = IbmApiProvider();
  final IbmController _ibmController = Get.find<IbmController>();
  bool _isLoading = false;
  List<dynamic> _transactions = [];
  String? _error;

  Map<String, dynamic>? _myPlan;
  bool _planLoading = false;
  String? _planError;

  static double _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// GET /portal/wallet returns `wallets[]`; take the first (USD-first) block.
  /// Falls back to the flat root map if the server returns figures top-level.
  Map _wallet0([Map? root]) {
    final r = root ?? _ibmController.walletData;
    final w = r['wallets'];
    if (w is List && w.isNotEmpty) {
      final usd = w.firstWhere(
        (e) => e is Map && e['currency']?.toString().toUpperCase() == 'USD',
        orElse: () => w.first,
      );
      if (usd is Map) return usd;
    }
    return r;
  }

  String _currency() {
    final w = _wallet0();
    return (w['currency'] ??
            _ibmController.walletData['currency'] ??
            'USD')
        .toString();
  }

  /// Smallest allowed payout — dynamic from wallet, default 50.
  double _minPayout() {
    final block = _wallet0();
    // Prefer wallets[0].minimum_payout, then minimum_payout_by_currency[cur],
    // then flat root, defaulting to 50.
    double n = _asNum(block['minimum_payout']);
    if (n <= 0) {
      final byCur = _ibmController.walletData['minimum_payout_by_currency'];
      if (byCur is Map) n = _asNum(byCur[_currency()]);
    }
    if (n <= 0) n = _asNum(_ibmController.walletData['minimum_payout']);
    return n > 0 ? n : 50;
  }

  String _fmt(dynamic v) =>
      IbmCurrency.format(_asNum(v), currencyCode: _currency());

  String _selectedSubTab = 'Earnings';
  final List<String> _subTabs = [
    'Earnings',
    'Payouts',
    'Distribute to Client',
    'My Commission Plan',
  ];

  static const Map<String, String> _subTabKeys = {
    'Earnings': 'ibm_earnings',
    'Payouts': 'ibm_payouts',
    'Distribute to Client': 'ibm_distribute_to_client',
    'My Commission Plan': 'ibm_my_commission_plan',
  };

  static const Map<String, String> _filterKeys = {
    'Everything': 'ibm_everything',
    'Commission earned': 'pmam_manager_dashboard_screen_commission_earned',
    'Paid out': 'ibm_paid_out',
    'Payouts returned': 'ibm_payouts_returned',
    'Adjustments': 'ibm_adjustments',
    'Clawbacks': 'ibm_clawbacks',
  };

  String _subTabLabel(String name) =>
      TranslationUtils.tr(_subTabKeys[name] ?? name);

  String _filterLabel(String name) =>
      TranslationUtils.tr(_filterKeys[name] ?? name);

  String _selectedFilter = 'Everything';
  String _selectedFilterValue = '';

  final Map<String, String> _filterOptions = {
    'Everything': '',
    'Commission earned': 'commission',
    'Paid out': 'payout',
    'Payouts returned': 'payout_reversal',
    'Adjustments': 'adjustment',
    'Clawbacks': 'clawback',
  };

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isExporting = false;

  static const Color _exportColor = AppColors.successText;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounced so typing "NZDUSD" fires one request, not six. Clearing the
  /// box reloads the unfiltered list.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final query = value.trim();
      if (query == _searchQuery) return;
      _searchQuery = query;
      _fetchTransactions();
    });
  }

  Future<void> _exportCommissionHistory() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await runIbmExport(
        kind: 'commission_history',
        filters: {
          'type': _selectedFilterValue.isEmpty ? null : _selectedFilterValue,
          'symbol': _searchQuery.isEmpty ? null : _searchQuery,
        },
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiProvider.getPortalWalletTransactions(
        currency: _currency(),
        type: _selectedFilterValue.isEmpty ? null : _selectedFilterValue,
        search: _searchQuery,
      );
      if (response.success) {
        final rawJson = response.data;
        if (rawJson != null && rawJson is Map<String, dynamic>) {
          final innerData = rawJson['data'];
          if (innerData is Map<String, dynamic>) {
            if (innerData['transactions'] is List) {
              _transactions = innerData['transactions'];
            } else if (innerData['data'] is List) {
              _transactions = innerData['data'];
            } else {
              _transactions = [];
            }
          } else if (innerData is List) {
            _transactions = innerData;
          } else {
            _transactions = [];
          }
        } else {
          _transactions = [];
        }
      } else {
        _error =
            response.message ??
            TranslationUtils.tr('ibm_failed_to_load_transactions');
      }
    } catch (e) {
      _error = TranslationUtils.tr('ibm_error_loading_transactions');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMyPlan() async {
    if (_myPlan != null || _planLoading) return;
    setState(() {
      _planLoading = true;
      _planError = null;
    });
    try {
      final response = await _apiProvider.getMyPlan();
      if (response.success) {
        final raw = response.data;
        Map<String, dynamic> data = {};
        if (raw is Map<String, dynamic>) {
          data = raw['data'] is Map<String, dynamic> ? raw['data'] : raw;
        }
        _myPlan = data;
      } else {
        _planError =
            response.message ?? TranslationUtils.tr('ibm_failed_to_load_plan');
      }
    } catch (e) {
      _planError = TranslationUtils.tr('ibm_error_loading_the_plan');
    } finally {
      if (mounted) setState(() => _planLoading = false);
    }
  }

  void _onFilterSelected(String filterLabel) {
    setState(() {
      _selectedFilter = filterLabel;
      _selectedFilterValue = _filterOptions[filterLabel] ?? '';
    });
    _fetchTransactions();
  }

  Future<void> _cancelPayout(int payoutId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(TranslationUtils.tr('ibm_cancel_payout')),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            labelText: TranslationUtils.tr('ibm_reason_optional'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(TranslationUtils.tr('ibm_keep')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: AppColors.whiteColor,
              elevation: 0,
            ),
            child: Text(TranslationUtils.tr('ibm_cancel_payout')),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true) return;

    try {
      final res = await _apiProvider.cancelPayout(
        payoutId,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      if (res.success) {
        CustomToastService.showSuccess(
          message: TranslationUtils.tr('ibm_payout_cancelled'),
        );
        await _ibmController.fetchWallet();
      } else {
        CustomToastService.showError(
          message:
              res.message ?? TranslationUtils.tr('ibm_could_not_cancel_payout'),
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomToastService.showError(message: 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final wallet = _ibmController.walletData;
      final w0 = _wallet0(wallet);
      final availableBalance = w0['balance'] ??
          w0['available'] ??
          wallet['unpaid_balance'] ??
          wallet['balance'] ??
          0;
      final pendingPayout =
          w0['pending_payout'] ?? wallet['pending_payout'] ?? wallet['locked'] ?? 0;
      final earnedAllTime =
          w0['lifetime_earned'] ?? wallet['lifetime_earned'] ?? 0;
      final paidOut = w0['lifetime_paid'] ?? wallet['lifetime_paid'] ?? 0;
      final availableStr = _fmt(availableBalance);
      final pendingStr = _fmt(pendingPayout);
      final earnedStr = _fmt(earnedAllTime);
      final paidStr = _fmt(paidOut);

      return SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr('ibm_my_commission'),
              style: AppTextStyles.heading.copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              TranslationUtils.tr('ibm_what_you_have_earned'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            ),
            SizedBox(height: 16.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _buildStatCard(
                  TranslationUtils.tr('ibm_available_now'),
                  availableStr,
                  TranslationUtils.tr('ibm_ready_to_request'),
                  Icons.account_balance_wallet,
                  AppColors.primary,
                ),
                _buildStatCard(
                  TranslationUtils.tr('ibm_pending_payout'),
                  pendingStr,
                  TranslationUtils.tr('ibm_locked_in_open_request'),
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
                _buildStatCard(
                  TranslationUtils.tr('ibm_earned_all_time'),
                  earnedStr,
                  TranslationUtils.tr('ibm_your_share_since_day_one'),
                  Icons.stacked_line_chart,
                  AppColors.primary,
                ),
                _buildStatCard(
                  TranslationUtils.tr('ibm_paid_out'),
                  paidStr,
                  TranslationUtils.tr('ibm_settled_to_you'),
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TranslationUtils.trArgs('ibm_amount_ready', {
                            'amount': availableStr,
                          }),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          TranslationUtils.trArgs('ibm_smallest_payout_is', {
                            'amount': IbmCurrency.format(
                              _minPayout(),
                              currencyCode: _currency(),
                            ),
                          }),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Obx(() {
                    final w = _ibmController.walletData;
                    final block = _wallet0(w);
                    final isFrozen = (block['is_frozen'] ?? w['is_frozen']) == true;
                    // Doc §7: can_withdraw && !is_frozen && !open_payout_status
                    // && balance >= minimum_payout. can_withdraw defaults true
                    // when the server omits it.
                    // Read the flags from the wallets[0] block first, falling
                    // back to the flat root when the server returns figures
                    // top-level. can_withdraw defaults true when omitted.
                    final canWithdrawFlag =
                        (block['can_withdraw'] ?? w['can_withdraw']) != false;
                    final openPayoutStatus =
                        block['open_payout_status'] ?? w['open_payout_status'];
                    final hasOpenPayout = openPayoutStatus != null &&
                        openPayoutStatus.toString().isNotEmpty;
                    final canRequest = canWithdrawFlag &&
                        !isFrozen &&
                        !hasOpenPayout &&
                        _asNum(availableBalance) >= _minPayout();
                    return ElevatedButton(
                      onPressed: 
                      canRequest
                          ?
                           () => Get.toNamed(AppPages.WITHDRAWAL)
                          : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.zero,
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.whiteColor,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.4,
                        ),
                        disabledForegroundColor: AppColors.whiteColor
                            .withValues(alpha: 0.85),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        TranslationUtils.tr(
                          'commission_history_screen_request_payout',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Rounded Sub-Tabs matching Network tab design
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _subTabs.map((tabName) {
                      final isSelected = _selectedSubTab == tabName;
                      return Padding(
                        padding: EdgeInsetsDirectional.only(end: 8.w),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedSubTab = tabName;
                            });
                            if (tabName == 'My Commission Plan') {
                              _fetchMyPlan();
                            }
                          },
                          borderRadius: BorderRadius.circular(20.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : (AppColors.isDarkMode
                                          ? const Color(0xFF1E1E1E)
                                          : const Color(0xFFF1EEF8)),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              _subTabLabel(tabName),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                color:
                                    isSelected
                                        ? AppColors.whiteColor
                                        : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            SizedBox(height: 14.h),
            if (_selectedSubTab == 'Earnings') ...[
            Divider(color: AppColors.divider),
            SizedBox(height: 10.h),
            Row(
              children: [
                PopupMenuButton<String>(
                  onSelected: _onFilterSelected,
                  offset: const Offset(0, 30),
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  itemBuilder: (BuildContext context) {
                    return _filterOptions.keys.map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Row(
                          children: [
                            if (_selectedFilter == choice)
                              Icon(
                                Icons.check,
                                size: 16.w,
                                color: AppColors.textPrimary,
                              )
                            else
                              SizedBox(width: 16.w),
                            SizedBox(width: 8.w),
                            Text(
                              _filterLabel(choice),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    height: 36.h,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      _filterLabel(_selectedFilter),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: SizedBox(
                    height: 36.h,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {});
                        _onSearchChanged(value);
                      },
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: TranslationUtils.tr(
                          'ibm_search_symbol_or_account',
                        ),
                        hintStyle: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textGrey,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 16.w,
                          color: AppColors.textGrey,
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 32.w),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {});
                                  _onSearchChanged('');
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16.w,
                                  color: AppColors.textGrey,
                                ),
                              ),
                        suffixIconConstraints: BoxConstraints(minWidth: 32.w),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 8.h,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.r),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.r),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : _exportCommissionHistory,
                  icon: _isExporting
                      ? SizedBox(
                          width: 14.w,
                          height: 14.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _exportColor,
                          ),
                        )
                      : Icon(
                          Icons.description_rounded,
                          size: 16.w,
                          color: _exportColor,
                        ),
                  label: Text(
                    TranslationUtils.tr('ibm_commission_history'),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _exportColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, 36.h),
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    backgroundColor: _exportColor.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: _exportColor.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    TranslationUtils.tr('ibm_every_line_is_one_movement'),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary, // Theme primary color
                  ),
                ),
              )
            else if (_error != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red, fontSize: 14.sp),
                  ),
                ),
              )
            else if (_transactions.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Center(
                  child: Text(
                    TranslationUtils.tr('transaction_history_no_transactions'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              )
            else
              ..._transactions.map((tx) {
                final trade = tx['trade'];
                final symbol = trade?['symbol'] ?? tx['symbol'] ?? 'WALLET';
                final type =
                    trade?['side']?.toString().toUpperCase() ??
                    tx['type']?.toString().toUpperCase() ??
                    'UNKNOWN';

                String details =
                    tx['description'] ??
                    TranslationUtils.tr('ibm_transaction_details_fallback');
                if (trade != null) {
                  final account = trade['account'] ?? '';
                  final lots = trade['lots']?.toString() ?? '';
                  final entryPrice = trade['entry_price']?.toString() ?? '';
                  final exitPrice = trade['exit_price']?.toString() ?? '';
                  details = TranslationUtils.trArgs('ibm_trade_detail_row', {
                    'account': '$account',
                    'lots': lots,
                    'entry': entryPrice,
                    'exit': exitPrice,
                  });
                }

                // Handle positive/negative amounts
                final direction = tx['direction'] == 'credit' ? '+' : '-';
                final txCurrency = tx['currency']?.toString() ?? _currency();
                final amountStr =
                    '$direction ${IbmCurrency.format(_asNum(tx['amount']), currencyCode: txCurrency)}';

                final balanceStr = IbmCurrency.format(
                  _asNum(tx['balance_after']),
                  currencyCode: txCurrency,
                );

                final date = tx['created_at'] ?? 'N/A';

                return _buildTransactionItem(
                  symbol,
                  type,
                  details,
                  amountStr,
                  balanceStr,
                  date,
                );
              }).toList(),
            ] else if (_selectedSubTab == 'Payouts')
              _buildPayoutsBody()
            else if (_selectedSubTab == 'Distribute to Client')
              IbmDistributeToClientSection(
                onChanged: _ibmController.fetchWallet,
              )
            else
              _buildMyPlanBody(),
          ],
        ),
      );
    });
  }

  Widget _buildPayoutsBody() {
    final raw = _ibmController.walletData['payouts'];
    final List payouts = raw is List ? raw : const [];
    if (payouts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Text(
            TranslationUtils.tr('ibm_no_payouts_yet'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          ),
        ),
      );
    }
    return Column(
      children: payouts.whereType<Map>().map((p) {
        final currency = p['currency']?.toString() ?? _currency();
        final status = p['status']?.toString() ?? '';
        final isCancellable = const ['pending', 'open', 'requested']
            .contains(status.toLowerCase());
        final payoutId = p['id'] is int
            ? p['id'] as int
            : int.tryParse(p['id']?.toString() ?? '') ?? 0;
        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      IbmCurrency.format(
                        _asNum(p['amount']),
                        currencyCode: currency,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Requested ${p['requested_at'] ?? '—'}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      'Paid ${p['paid_at'] ?? '—'}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    status.isEmpty ? '—' : status,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isCancellable)
                    TextButton(
                      onPressed: () => _cancelPayout(payoutId),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        TranslationUtils.tr('account_management_cancel'),
                        style: TextStyle(color: Colors.red, fontSize: 12.sp),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMyPlanBody() {
    if (_planLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_planError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Text(
            _planError!,
            style: TextStyle(color: Colors.red, fontSize: 14.sp),
          ),
        ),
      );
    }
    final plan = _myPlan;
    if (plan == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Text(
            TranslationUtils.tr('ibm_no_plan_assigned'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          ),
        ),
      );
    }
    final planInner = plan['plan'] is Map ? plan['plan'] as Map : null;
    final name = (planInner?['name'] ?? plan['name'] ?? 'Commission plan')
        .toString();
    final rawGroups = plan['groups'] ?? planInner?['groups'] ?? const [];
    final List groups = rawGroups is List ? rawGroups : const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15.sp,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        if (groups.isEmpty)
          Text(
            TranslationUtils.tr('ibm_no_commission_groups_on_plan'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
          )
        else
          ...groups.whereType<Map>().map((g) {
            final gName =
                (g['name'] ?? g['symbol_group'] ?? 'Group').toString();
            final rawRates = g['rates'];
            final List rates = rawRates is List ? rawRates : const [];
            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.symmetric(horizontal: 14.w),
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    gName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          TranslationUtils.trArgs('ibm_rates_count', {
                            'count': '${rates.length}',
                          }),
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.expand_more, color: AppColors.textSecondary),
                    ],
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14.w),
                      color: AppColors.isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF9F9F9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TranslationUtils.tr('ibm_rebate_by_instrument_type'),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          if (rates.isEmpty)
                            Text(
                              TranslationUtils.tr('ibm_no_rates_set_for_group'),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                              ),
                            )
                          else
                            ...rates.whereType<Map>().map((r) {
                              final currency =
                                  r['currency']?.toString() ?? _currency();
                              return Padding(
                                padding: EdgeInsets.only(bottom: 8.h),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (r['category'] ?? 'Unknown').toString(),
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      IbmCurrency.format(
                                        _asNum(r['rate_per_lot'] ?? r['rate']),
                                        currencyCode: currency,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          Builder(builder: (_) {
                            final rawOverrides = g['symbol_overrides'];
                            final List overrides =
                                rawOverrides is List ? rawOverrides : const [];
                            final rawBlocked = g['blocked_symbols'];
                            final List blocked =
                                rawBlocked is List ? rawBlocked : const [];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (overrides.isNotEmpty) ...[
                                  SizedBox(height: 12.h),
                                  Text(
                                    TranslationUtils.tr(
                                      'ibm_symbol_specific_rates',
                                    ),
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 10.h),
                                  ...overrides.whereType<Map>().map((o) {
                                    final currency =
                                        o['currency']?.toString() ??
                                            _currency();
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 8.h),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (o['symbol'] ?? 'Unknown')
                                                  .toString(),
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            IbmCurrency.format(
                                              _asNum(o['rate_per_lot']),
                                              currencyCode: currency,
                                            ),
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                SizedBox(height: 10.h),
                                Text(
                                  blocked.isEmpty
                                      ? TranslationUtils.tr(
                                        'ibm_all_symbols_allowed_on_group',
                                      )
                                      : TranslationUtils.trArgs(
                                        'ibm_symbols_blocked_on_group',
                                        {'count': '${blocked.length}'},
                                      ),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String amount,
    String subtitle,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      // Width is governed by parent Wrap; LayoutBuilder keeps two-up on phone.
      constraints: BoxConstraints(
        minWidth: 140.w,
        maxWidth: (MediaQuery.of(context).size.width - 56.w) / 2,
      ),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(icon, color: AppColors.whiteColor, size: 16.w),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    String symbol,
    String type,
    String details,
    String amount,
    String balance,
    String date,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  details,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  date,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  balance,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommissionPlansTab extends StatefulWidget {
  const CommissionPlansTab({super.key});

  @override
  State<CommissionPlansTab> createState() => _CommissionPlansTabState();
}

class _CommissionPlansTabState extends State<CommissionPlansTab> {
  bool _isLoading = true;
  List<dynamic> _plans = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await IbmApiProvider().getPartnerPlans();
      if (response.success) {
        final rawJson = response.data;
        if (rawJson != null && rawJson is Map<String, dynamic>) {
          final innerData = rawJson['data'];
          if (innerData is Map<String, dynamic> && innerData['plans'] is List) {
            _plans = innerData['plans'];
          } else {
            _plans = [];
          }
        } else {
          _plans = [];
        }
      } else {
        _error =
            response.message ?? TranslationUtils.tr('ibm_failed_to_load_plans');
      }
    } catch (e) {
      _error = 'Error loading plans: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePlan(int planId, String planName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(TranslationUtils.tr('ibm_delete_plan')),
            content: Text(
              TranslationUtils.trArgs('ibm_confirm_delete_plan', {
                'name': planName,
              }),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  TranslationUtils.tr('account_management_cancel'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  TranslationUtils.tr('account_management_delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final res = await IbmApiProvider().deletePartnerPlan(planId);
    if (res.success) {
      CustomToastService.show(
        message: TranslationUtils.tr('ibm_plan_deleted_successfully'),
      );
      _fetchPlans();
    } else {
      if (mounted) setState(() => _isLoading = false);
      CustomToastService.show(
        message:
            res.message ?? TranslationUtils.tr('ibm_failed_to_delete_plan'),
      );
    }
  }

  Future<void> _renamePlan(
    int planId,
    String currentName,
    String currentDescription,
  ) async {
    final result = await showDialog<_RenamePlanResult>(
      context: context,
      builder: (_) => _RenamePlanDialog(
        initialName: currentName,
        initialDescription: currentDescription,
      ),
    );
    if (result == null) return;

    setState(() => _isLoading = true);
    final res = await IbmApiProvider().renamePartnerPlan(
      planId,
      planName: result.name,
      description: result.description,
    );
    if (res.success) {
      CustomToastService.showSuccess(
        message: res.message ?? TranslationUtils.tr('ibm_plan_renamed'),
      );
      _fetchPlans();
    } else {
      if (mounted) setState(() => _isLoading = false);
      CustomToastService.showError(
        message: res.message ?? TranslationUtils.tr('ibm_failed_to_rename_plan'),
      );
    }
  }

  void _showAssignBottomSheet(int planId, String planName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: AssignPlanBottomSheet(
              planId: planId,
              planName: planName,
              onAssigned: () => _fetchPlans(),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TranslationUtils.tr('ibm_my_commission_plans'),
                style: AppTextStyles.heading.copyWith(fontSize: 18.sp),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Get.to(
                    () => const CreateEditPlanScreen(),
                  );
                  if (result == true) {
                    _fetchPlans();
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text(TranslationUtils.tr('ibm_new_plan')),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_error != null)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red, fontSize: 14.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_plans.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40.w),
                child: Text(
                  TranslationUtils.tr('ibm_no_commission_plans_found'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            )
          else
            ..._plans.map((plan) {
              final String name = plan['name']?.toString() ?? 'Unknown Plan';
              final String description = plan['description']?.toString() ?? '';
              final bool isActive =
                  plan['is_active'] == true || plan['is_active'] == 1;
              final int partnersUsing =
                  plan['partners_using'] is int
                      ? plan['partners_using']
                      : int.tryParse(
                            plan['partners_using']?.toString() ?? '0',
                          ) ??
                          0;
              // A plan is locked (read-only) once it is assigned to a sub-IB.
              // The list endpoint may omit is_locked, so fall back to
              // partners_using as the "locked once assigned" signal.
              final bool isLocked =
                  plan['is_locked'] == true ||
                  plan['is_locked'] == 1 ||
                  partnersUsing > 0;

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                TranslationUtils.tr('chart_active'),
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 16.w,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            TranslationUtils.trArgs('ibm_sub_ib_using', {
                              'count': '$partnersUsing',
                            }),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (isLocked) ...[
                            SizedBox(width: 12.w),
                            Icon(
                              Icons.lock_outline,
                              size: 14.w,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              TranslationUtils.tr('ibm_locked_once_assigned'),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      SizedBox(height: 12.h),
                      Divider(height: 1, color: AppColors.divider),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final result = await Get.to(
                                  () => CreateEditPlanScreen(
                                    planId: plan['plan_id'],
                                    readOnly: isLocked,
                                  ),
                                );
                                if (result == true) {
                                  _fetchPlans();
                                }
                              },
                              child: _buildActionIcon(
                                isLocked ? Icons.visibility : Icons.edit,
                                isLocked
                                    ? TranslationUtils.tr('ibm_view')
                                    : TranslationUtils.tr('general_edit'),
                                AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 18.h,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _renamePlan(
                                plan['plan_id'] ?? 0,
                                name,
                                description,
                              ),
                              child: _buildActionIcon(
                                Icons.drive_file_rename_outline,
                                TranslationUtils.tr('ibm_rename'),
                                AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 18.h,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showAssignBottomSheet(
                                plan['plan_id'] ?? 0,
                                name,
                              ),
                              child: _buildActionIcon(
                                Icons.person_add,
                                TranslationUtils.tr('ibm_assign'),
                                AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 18.h,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  _deletePlan(plan['plan_id'] ?? 0, name),
                              child: _buildActionIcon(
                                Icons.delete_outline,
                                TranslationUtils.tr('account_management_delete'),
                                Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16.w, color: color),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RenamePlanResult {
  final String name;
  final String description;
  const _RenamePlanResult(this.name, this.description);
}

class _RenamePlanDialog extends StatefulWidget {
  final String initialName;
  final String initialDescription;

  const _RenamePlanDialog({
    required this.initialName,
    required this.initialDescription,
  });

  @override
  State<_RenamePlanDialog> createState() => _RenamePlanDialogState();
}

class _RenamePlanDialogState extends State<_RenamePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initialDescription);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _RenamePlanResult(
        _nameController.text.trim(),
        _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(TranslationUtils.tr('ibm_rename_plan')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                maxLength: 150,
                decoration: InputDecoration(
                  labelText: TranslationUtils.tr('ibm_plan_name'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? TranslationUtils.tr('ibm_plan_name_required')
                    : null,
              ),
              TextFormField(
                controller: _descriptionController,
                maxLength: 1000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: TranslationUtils.tr('ibm_description'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(TranslationUtils.tr('account_management_cancel')),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(TranslationUtils.tr('ibm_save')),
        ),
      ],
    );
  }
}
