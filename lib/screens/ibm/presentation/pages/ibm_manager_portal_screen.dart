import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';

class IbmManagerPortalScreen extends StatefulWidget {
  const IbmManagerPortalScreen({super.key});

  @override
  State<IbmManagerPortalScreen> createState() => _IbmManagerPortalScreenState();
}

class _IbmManagerPortalScreenState extends State<IbmManagerPortalScreen> {
  final IbmController controller = Get.find<IbmController>();

  String selectedScope = 'total'; // total, network, direct
  String selectedPeriod = 'all'; // today, 7d, 30d, all, custom
  String? customFrom;
  String? customTo;
  String selectedCurrencyCode = 'USD'; // USD, USC (cent)

  String get _currencyPrefix =>
      selectedCurrencyCode == 'USD' ? r'$' : '$selectedCurrencyCode ';

  static final NumberFormat _amountFormat = NumberFormat('#,##0.00', 'en_US');

  String _fmt(double v) => '$_currencyPrefix${_amountFormat.format(v)}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchDashboard(
        period: selectedPeriod,
        scope: selectedScope,
        from: customFrom,
        to: customTo,
      );
    });
  }

  void _onScopeChanged(String scope) {
    setState(() {
      selectedScope = scope;
    });
    controller.fetchDashboard(
      period: selectedPeriod,
      scope: selectedScope,
      from: customFrom,
      to: customTo,
    );
  }

  void _onPeriodChanged(String period) async {
    if (period == 'custom') {
      final now = DateTime.now();
      final DateTime? start = await showDatePicker(
        context: context,
        helpText: TranslationUtils.tr('ibm_select_start_date'),
        initialDate: (customFrom != null ? DateTime.tryParse(customFrom!) : null) ??
            now.subtract(const Duration(days: 30)),
        firstDate: DateTime(2000),
        lastDate: now,
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.whiteColor,
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
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.whiteColor,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        ),
      );
      if (end == null) return;
      final picked = DateTimeRange(start: start, end: end);
      {
        String fromStr =
            "${picked.start.year}-${picked.start.month.toString().padLeft(2, '0')}-${picked.start.day.toString().padLeft(2, '0')}";
        String toStr =
            "${picked.end.year}-${picked.end.month.toString().padLeft(2, '0')}-${picked.end.day.toString().padLeft(2, '0')}";
        setState(() {
          selectedPeriod = period;
          customFrom = fromStr;
          customTo = toStr;
        });
        controller.fetchDashboard(
          period: selectedPeriod,
          scope: selectedScope,
          from: customFrom,
          to: customTo,
        );
      }
    } else {
      setState(() {
        selectedPeriod = period;
        customFrom = null;
        customTo = null;
      });
      controller.fetchDashboard(
        period: selectedPeriod,
        scope: selectedScope,
        from: customFrom,
        to: customTo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: IbmTopHeader(
        title: TranslationUtils.tr('ibm_ib_manager_portal'),
        showBackButton: false,
        hideWallet: true,
        extraActions: [_buildHeaderCurrencySwitch()],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.dashboardData.isEmpty) {
          return Center(
            child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
          );
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.dashboardData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48.w, color: Colors.redAccent),
                SizedBox(height: 16.h),
                Text(
                  controller.errorMessage.value,
                  style: AppTextStyles.bodyText,
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed:
                      () => controller.fetchDashboard(
                        period: selectedPeriod,
                        scope: selectedScope,
                        from: customFrom,
                        to: customTo,
                      ),
                  child: Text(TranslationUtils.tr('edit_profile_retry')),
                ),
              ],
            ),
          );
        }

        final data = controller.dashboardData;
        final actData = controller.dashboardActivityData;

        final Map clients = data['clients'] is Map ? data['clients'] : const {};
        final Map partners =
            data['partners'] is Map ? data['partners'] : const {};
        final Map funnel = data['funnel'] is Map ? data['funnel'] : const {};
        final List currencyList =
            data['currencies'] is List ? data['currencies'] : const [];
        final List<String> availableCodes = currencyList
            .whereType<Map>()
            .map((c) => (c['currency'] ?? '').toString())
            .where((c) => c.isNotEmpty)
            .toList();
        // Keep selectedCurrencyCode valid vs API response.
        if (availableCodes.isNotEmpty &&
            !availableCodes.contains(selectedCurrencyCode)) {
          selectedCurrencyCode = availableCodes.first;
        }
        final Map currency = _currencyBlock(currencyList);

        final Map funding = currency['funding'] is Map ? currency['funding'] : const {};
        final deposits = _parseDouble(funding['deposits']);
        final withdrawals = _parseDouble(funding['withdrawals']);
        final netFunding = funding['net'] != null
            ? _parseDouble(funding['net'])
            : deposits - withdrawals;

        final Map equityData = currency['equity'] is Map ? currency['equity'] : const {};
        final equity = _parseDouble(
          equityData['equity'] ?? equityData['balance'],
        );

        final Map commData =
            currency['commission'] is Map ? currency['commission'] : const {};
        final commission = _parseDouble(commData['period'] ?? commData['mtd']);
        final lots = _parseDouble(commData['lots']);
        final trades = _parseDouble(commData['trades']).toInt();

        // Wallet lives inside the per-currency block; older payloads put it at root.
        final Map wallet = currency['wallet'] is Map
            ? currency['wallet']
            : (data['wallet'] is Map ? data['wallet'] : const {});
        final subIbRows = controller.networkData['rows'];

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh:
              () => controller.fetchDashboard(
                period: selectedPeriod,
                scope: selectedScope,
                from: customFrom,
                to: customTo,
              ),
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            children: [
              _buildHeaderRow(),
              SizedBox(height: 16.h),
              _buildStatsGrid(
                clients: clients,
                partners: partners,
                deposits: deposits,
                withdrawals: withdrawals,
                netFunding: netFunding,
                equity: equity,
                lots: lots,
                trades: trades,
                commission: commission,
              ),
              SizedBox(height: 16.h),
              _buildCommissionSummary(
                wallet,
                data['by_source'] is Map ? data['by_source'] : const {},
              ),
              SizedBox(height: 16.h),
              _buildClientFunnel(funnel),
              SizedBox(height: 16.h),
              _buildSubIbPerformance(subIbRows),
              SizedBox(height: 16.h),
              _buildActivitySection(actData),
              SizedBox(height: 40.h),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildToggleGroup(
          options: {
            'total': TranslationUtils.tr('common_total'),
            'network': TranslationUtils.tr('ibm_nav_network'),
            'direct': TranslationUtils.tr('ibm_direct'),
          },
          selectedValue: selectedScope,
          onChanged: _onScopeChanged,
          compact: true,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildToggleGroup(
            options: {
              'today': TranslationUtils.tr('dc_range_today'),
              '7d': '7D',
              '30d': '30D',
              'all': TranslationUtils.tr('common_all'),
            },
            selectedValue: selectedPeriod,
            onChanged: _onPeriodChanged,
            fillWidth: true,
            compact: true,
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () => _onPeriodChanged('custom'),
          child: Container(
            padding: EdgeInsets.all(9.w),
            decoration: BoxDecoration(
              color: selectedPeriod == 'custom'
                  ? AppColors.primary
                  : AppColors.card,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 18.w,
              color: selectedPeriod == 'custom'
                  ? AppColors.whiteColor
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCurrencySwitch() {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: 12.w),
      child: Obx(() {
        final currencies = controller.dashboardData['currencies'];
        final List list = currencies is List ? currencies : const [];
        final codes = list
            .whereType<Map>()
            .map((c) => (c['currency'] ?? '').toString())
            .where((c) => c.isNotEmpty)
            .toList();
        if (codes.length < 2) return const SizedBox.shrink();

        return Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: AppColors.isDarkMode
                ? Colors.grey[900]
                : AppColors.card,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppColors.isDarkMode
                  ? Colors.grey[800]!
                  : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: codes.map((c) {
              final isSelected = c == selectedCurrencyCode;
              return GestureDetector(
                onTap: () => setState(() => selectedCurrencyCode = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.whiteColor
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }),
    );
  }

  Widget _buildToggleGroup({
    required Map<String, String> options,
    required String selectedValue,
    required Function(String) onChanged,
    bool fillWidth = false,
    bool compact = false,
  }) {
    Widget buildItem(MapEntry<String, String> e) {
      final isSelected = e.key == selectedValue;
      return GestureDetector(
        onTap: () => onChanged(e.key),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4.w : 6.w,
            vertical: 8.h,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            e.value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
              fontSize: compact ? 10.sp : 11.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Container(
      width: fillWidth ? double.infinity : null,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
        children: fillWidth
            ? options.entries
                .map((e) => Expanded(child: buildItem(e)))
                .toList()
            : options.entries.map(buildItem).toList(),
      ),
    );
  }


  static const Color _positiveColor = Color(0xFF00C48C);
  static const Color _negativeColor = Color(0xFFFF647C);
  static const Color _pendingColor = Color(0xFFFFB547);

  /// Lays [children] out in equal-height rows; column count adapts to width.
  Widget _buildResponsiveGrid({
    required List<Widget> children,
    int compactColumns = 2,
    int wideColumns = 4,
    double? gap,
  }) {
    final spacing = gap ?? 10.w;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 600 ? wideColumns : compactColumns;
        final rows = <Widget>[];
        for (int start = 0; start < children.length; start += columns) {
          if (start > 0) rows.add(SizedBox(height: spacing));
          if (columns == 1) {
            rows.add(children[start]);
            continue;
          }
          final rowChildren = <Widget>[];
          for (int col = 0; col < columns; col++) {
            if (col > 0) rowChildren.add(SizedBox(width: spacing));
            final index = start + col;
            rowChildren.add(
              Expanded(
                child: index < children.length
                    ? children[index]
                    : const SizedBox.shrink(),
              ),
            );
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowChildren,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }

  Widget _buildStatsGrid({
    required Map clients,
    required Map partners,
    required double deposits,
    required double withdrawals,
    required double netFunding,
    required double equity,
    required double lots,
    required int trades,
    required double commission,
  }) {
    final totalClients = clients['total'] ?? 0;
    final newInPeriod = clients['new_in_period'] ?? 0;
    final activeTraders = clients['active'] ?? 0;
    final directPartners = _parseDouble(partners['direct']).toInt();
    final networkPartners = _parseDouble(partners['network']).toInt();
    final totalSubIbs = partners['total'] != null
        ? _parseDouble(partners['total']).toInt()
        : directPartners + networkPartners;

    return _buildResponsiveGrid(
      children: [
        _buildStatCard(
          icon: Icons.groups_rounded,
          color: AppColors.primary,
          label: TranslationUtils.tr('ib_dashboard_new_screen_total_clients'),
          value: '$totalClients',
          hint: TranslationUtils.trArgs('ibm_new_this_period', {
            'count': '$newInPeriod',
          }),
        ),
        _buildStatCard(
          icon: Icons.how_to_reg_rounded,
          color: AppColors.primary,
          label: TranslationUtils.tr('ibm_active_traders'),
          value: '$activeTraders',
          hint: TranslationUtils.tr('ibm_traded_this_period'),
        ),
        _buildStatCard(
          icon: Icons.account_tree_rounded,
          color: AppColors.primary,
          label: TranslationUtils.tr('ibm_sub_ibs'),
          value: '$totalSubIbs',
          hint: TranslationUtils.trArgs('ibm_n_direct', {
            'count': '$directPartners',
          }),
        ),
        _buildStatCard(
          icon: Icons.south_west_rounded,
          color: _positiveColor,
          label: TranslationUtils.tr('ibm_total_deposits'),
          value: _fmt(deposits),
          hint: '${_fmt(netFunding)} ${TranslationUtils.tr('ibm_net_flow')}',
        ),
        _buildStatCard(
          icon: Icons.north_east_rounded,
          color: _negativeColor,
          label: TranslationUtils.tr('ibm_total_withdrawals'),
          value: _fmt(withdrawals),
        ),
        _buildStatCard(
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.primary,
          label: TranslationUtils.tr('ibm_client_equity'),
          value: _fmt(equity),
        ),
        _buildStatCard(
          icon: Icons.show_chart_rounded,
          color: AppColors.primary,
          label: TranslationUtils.tr('tw_total_lots'),
          value: lots.toStringAsFixed(2),
          hint: '$trades ${TranslationUtils.tr('tw_trades')}',
        ),
        _buildStatCard(
          icon: Icons.payments_rounded,
          color: AppColors.primary,
          label: TranslationUtils.tr('ibm_earned_this_period'),
          value: _fmt(commission),
          hint: _periodLabel(),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String hint = '',
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9.r),
            ),
            child: Icon(icon, color: AppColors.whiteColor, size: 18.w),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
                ),
                SizedBox(height: 2.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// GET /portal/wallet returns `wallets[]`; take the USD-first block.
  Map _wallet0([Map? root]) {
    final r = root ?? controller.walletData;
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

  double _minPayout() {
    final block = _wallet0();
    double n = _parseDouble(block['minimum_payout']);
    if (n <= 0) {
      final byCur = controller.walletData['minimum_payout_by_currency'];
      if (byCur is Map) {
        n = _parseDouble(byCur[selectedCurrencyCode]);
      }
    }
    if (n <= 0) n = _parseDouble(controller.walletData['minimum_payout']);
    return n;
  }

  String _periodLabel() {
    switch (selectedPeriod) {
      case 'today':
        return TranslationUtils.tr('dc_range_today');
      case '7d':
        return TranslationUtils.tr('ibm_last_7_days');
      case '30d':
        return TranslationUtils.tr('ibm_last_30_days');
      case 'this_month':
        return TranslationUtils.tr('ibm_month_to_date');
      case 'all':
        return TranslationUtils.tr('ibm_range_all_time');
      case 'custom':
        if (customFrom != null && customTo != null) return '$customFrom → $customTo';
        return TranslationUtils.tr('ibm_custom_range');
      default:
        return TranslationUtils.tr('ibm_selected_period');
    }
  }

  /// Picks the block for the selected currency from a `currencies[]` list.
  Map _currencyBlock(dynamic currencies) {
    if (currencies is! List) return const {};
    final blocks = currencies.whereType<Map>().toList();
    if (blocks.isEmpty) return const {};
    return blocks.firstWhere(
      (c) => c['currency'] == selectedCurrencyCode,
      orElse: () => blocks.first,
    );
  }

  Widget _buildCommissionSummary(Map wallet, Map bySource) {
    final sum = wallet.containsKey('summary') ? wallet['summary'] : wallet;
    final earned = _parseDouble(sum['lifetime_earned'] ?? sum['total_earned']);
    final paid = _parseDouble(sum['lifetime_paid'] ?? sum['total_paid']);
    final pending = _parseDouble(sum['pending_payout'] ?? sum['total_pending']);
    final available = _parseDouble(
      sum['unpaid_balance'] ?? sum['total_available'],
    );
    final isFrozen = sum['is_frozen'] == true;
    final Map source = bySource[selectedCurrencyCode] is Map
        ? bySource[selectedCurrencyCode]
        : const {};
    final directCommission = _parseDouble(source['direct']);
    final networkCommission = _parseDouble(source['network']);
    final splitTotal = directCommission + networkCommission;

    return _buildSectionCard(
      TranslationUtils.tr('ib_dashboard_new_screen_commission_summary'),
      '$selectedCurrencyCode · ${TranslationUtils.tr('ibm_range_all_time')}',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildResponsiveGrid(
            children: [
              _buildSummaryTile(
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                label: TranslationUtils.tr('ibm_total_earned'),
                value: _fmt(earned),
              ),
              _buildSummaryTile(
                icon: Icons.send_rounded,
                color: _positiveColor,
                label: TranslationUtils.tr('ibm_paid_out'),
                value: _fmt(paid),
              ),
              _buildSummaryTile(
                icon: Icons.hourglass_bottom_rounded,
                color: _pendingColor,
                label: TranslationUtils.tr('kyc_verification_pending'),
                value: _fmt(pending),
                valueColor: _pendingColor,
              ),
              _buildSummaryTile(
                icon: Icons.savings_rounded,
                color: _positiveColor,
                label: TranslationUtils.tr('ibm_available'),
                value: _fmt(available),
                valueColor: _positiveColor,
                footer: _buildRequestPayoutButton(available, isFrozen),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildSplitRow(
            TranslationUtils.tr('ibm_direct_clients'),
            directCommission,
            splitTotal,
          ),
          SizedBox(height: 10.h),
          _buildSplitRow(
            TranslationUtils.tr('ibm_sub_ib_network'),
            networkCommission,
            splitTotal,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    Color? valueColor,
    Widget? footer,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.iconBgSurface,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(icon, size: 14.w, color: color),
          ),
          SizedBox(height: 10.h),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 4.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          if (footer != null) ...[SizedBox(height: 10.h), footer],
        ],
      ),
    );
  }

  Widget _buildRequestPayoutButton(double available, bool dashboardFrozen) {
    return Obx(() {
      final w = controller.walletData;
      final block = _wallet0(w);
      final isFrozen =
          dashboardFrozen || (block['is_frozen'] ?? w['is_frozen']) == true;
      final canWithdrawFlag =
          (block['can_withdraw'] ?? w['can_withdraw']) != false;
      final openPayoutStatus =
          block['open_payout_status'] ?? w['open_payout_status'];
      final hasOpenPayout =
          openPayoutStatus != null && openPayoutStatus.toString().isNotEmpty;
      final canRequest = canWithdrawFlag &&
          !isFrozen &&
          !hasOpenPayout &&
          available >= _minPayout();
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canRequest ? () => Get.toNamed(AppPages.WITHDRAWAL) : null,
          style: ElevatedButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.whiteColor,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
            disabledForegroundColor: AppColors.whiteColor,
            elevation: 0,
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Text(
            TranslationUtils.tr('commission_history_screen_request_payout'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
          ),
        ),
      );
    });
  }

  Widget _buildSplitRow(String label, double value, double total) {
    final double ratio =
        total > 0 ? (value / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 84.w,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6.h,
              color: AppColors.primary,
              backgroundColor: AppColors.divider.withValues(alpha: 0.5),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '${_fmt(value)} · ${(ratio * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildClientFunnel(Map funnel) {
    final steps = [
      (Icons.ads_click_rounded, 'ibm_link_clicks', funnel['visits']),
      (Icons.people_alt_rounded, 'ibm_different_people', funnel['unique_visits']),
      (Icons.person_add_alt_1_rounded, 'ibm_signed_up', funnel['signups']),
      (Icons.credit_card_rounded, 'ibm_opened_account', funnel['accounts']),
      (Icons.account_balance_wallet_rounded, 'ibm_funded_it', funnel['funded']),
    ];

    return _buildSectionCard(
      TranslationUtils.tr('ibm_client_funnel'),
      TranslationUtils.tr('ibm_from_your_referral_links'),
      _buildResponsiveGrid(
        wideColumns: 5,
        children: [
          for (final (icon, labelKey, value) in steps)
            _buildSummaryTile(
              icon: icon,
              color: AppColors.primary,
              label: TranslationUtils.tr(labelKey),
              value: '${_parseDouble(value).toInt()}',
            ),
        ],
      ),
    );
  }

  Widget _buildSubIbPerformance(dynamic rowsList) {
    final List rows = rowsList is List ? rowsList : const [];
    return _buildSectionCard(
      TranslationUtils.tr('ibm_sub_ib_performance'),
      TranslationUtils.tr('pmam_fund_manager_view_view_all'),
      rows.isEmpty
          ? _buildEmptyBox(TranslationUtils.tr('ibm_nobody_is_below_you_yet'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0) SizedBox(height: 12.h),
                  _buildSubIbRow(rows[i] is Map ? rows[i] as Map : const {}),
                ],
              ],
            ),
      onAction: rows.isEmpty ? null : () => controller.currentTabIndex.value = 2,
    );
  }

  Widget _buildSubIbRow(Map row) {
    final name = (row['name'] ?? 'Unknown').toString();
    final clients = row['clients'] ?? 0;
    final active = row['active_clients'] ?? row['active'] ?? 0;
    final currency = _currencyBlock(row['currencies']);
    final netDeposit = _parseDouble(
      currency['net_funding'] ?? currency['deposits'],
    );
    final earned = _parseDouble(currency['commission']);
    final lots = _parseDouble(currency['lots']);
    final isActive = _parseDouble(active) >= 1;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                radius: 12.r,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: AppColors.whiteColor, fontSize: 10.sp),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              _buildStatusChip(
                isActive
                    ? TranslationUtils.tr('wallet_active')
                    : TranslationUtils.tr('wallet_inactive'),
                isActive ? _positiveColor : _negativeColor,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildValueBox(
                  TranslationUtils.tr('ibm_net_deposit'),
                  _fmt(netDeposit),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildValueBox(
                  TranslationUtils.tr('ibm_commission_earned'),
                  _fmt(earned),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            TranslationUtils.trArgs('ibm_clients_active_lots_line', {
              'clients': '$clients',
              'active': '$active',
              'lots': lots.toStringAsFixed(2),
            }),
            style: TextStyle(color: AppColors.textGrey, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildValueBox(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.iconBgSurface,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
          ),
          SizedBox(height: 2.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: TextStyle(
          fontSize: 8.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
      ),
    );
  }

  Widget _buildActivitySection(Map actData) {
    List listOf(String key) =>
        actData[key] is List ? actData[key] as List : const [];
    final List pendingRequests = listOf('requests')
        .whereType<Map>()
        .where((r) => r['status'] == 'pending')
        .toList();

    return _buildResponsiveGrid(
      compactColumns: 1,
      wideColumns: 2,
      gap: 14.h,
      children: [
        _buildActivityCard(
          icon: Icons.south_west_rounded,
          color: _positiveColor,
          title: TranslationUtils.tr('transaction_history_deposits'),
          subtitle: TranslationUtils.tr('ibm_pending_and_approved'),
          items: listOf('deposits'),
          emptyMessage: TranslationUtils.tr('ibm_no_new_deposits'),
          amountSign: 1,
        ),
        _buildActivityCard(
          icon: Icons.north_east_rounded,
          color: _negativeColor,
          title: TranslationUtils.tr('transaction_history_withdrawals'),
          subtitle: TranslationUtils.tr('ibm_pending_and_approved'),
          items: listOf('withdrawals'),
          emptyMessage: TranslationUtils.tr('ibm_nobody_has_withdrawn'),
          amountSign: -1,
        ),
        _buildActivityCard(
          icon: Icons.payments_rounded,
          color: AppColors.primary,
          title: TranslationUtils.tr('ibm_payouts'),
          subtitle: TranslationUtils.tr('ibm_you_and_your_downline'),
          items: listOf('payouts'),
          emptyMessage: TranslationUtils.tr('ibm_no_payout_taken_yet'),
        ),
        _buildActivityCard(
          icon: Icons.person_add_alt_1_rounded,
          color: AppColors.primary,
          title: TranslationUtils.tr('ibm_new_accounts'),
          subtitle: TranslationUtils.tr('ibm_whole_downline'),
          items: listOf('accounts'),
          emptyMessage: TranslationUtils.tr('ibm_no_new_accounts'),
        ),
        _buildActivityCard(
          icon: Icons.group_rounded,
          color: AppColors.textSecondary,
          title: TranslationUtils.tr('ibm_sub_ib_requests'),
          subtitle: TranslationUtils.tr('ibm_waiting_on_you'),
          items: pendingRequests,
          emptyMessage: TranslationUtils.tr('ibm_nobody_is_waiting_for_answer'),
        ),
      ],
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List items,
    required String emptyMessage,
    int amountSign = 0,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(icon, size: 12.w, color: AppColors.whiteColor),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 9.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (items.isEmpty)
            _buildEmptyBox(emptyMessage)
          else
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 16.h,
                  thickness: 1,
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
              _buildActivityItem(
                items[i] is Map ? items[i] as Map : const {},
                amountSign,
              ),
            ],
        ],
      ),
    );
  }

  /// Formats with the item's own currency (a USC deposit must not show as $).
  String _fmtAmount(double value, dynamic currency) {
    final code = (currency ?? selectedCurrencyCode).toString().toUpperCase();
    final prefix = code == 'USD' ? r'$' : '$code ';
    return '$prefix${_amountFormat.format(value)}';
  }

  /// "19d ago" style label from an API timestamp like "2026-09-25 07:09:27".
  String _relativeTime(String at) {
    final parsed = DateTime.tryParse(at.replaceFirst(' ', 'T'));
    if (parsed == null) return at.split(' ').first;
    final diff = DateTime.now().difference(parsed);
    final String short;
    if (diff.inDays >= 1) {
      short = '${diff.inDays}d';
    } else if (diff.inHours >= 1) {
      short = '${diff.inHours}h';
    } else {
      short = '${diff.inMinutes.clamp(1, 59)}m';
    }
    return TranslationUtils.trArgs('time_ago', {'time': short});
  }

  Widget _buildActivityItem(Map item, int amountSign) {
    final name = (item['name'] ?? 'Unknown').toString();
    final status = (item['status'] ?? '').toString();
    final account = (item['account'] ?? '').toString();
    final amount = _parseDouble(item['amount']);
    final atStr = (item['at'] ?? '').toString();
    final dateDisplay = atStr.isNotEmpty ? _relativeTime(atStr) : '';
    final isSettled = status == 'approved' || status == 'opened';

    String amountText = '';
    Color amountColor = AppColors.textPrimary;
    if (amount > 0) {
      final formatted = _fmtAmount(amount, item['currency']);
      if (amountSign > 0) {
        amountText = '+ $formatted';
        amountColor = _positiveColor;
      } else if (amountSign < 0) {
        amountText = '− $formatted';
        amountColor = _negativeColor;
      } else {
        amountText = formatted;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (status.isNotEmpty) ...[
                    SizedBox(width: 6.w),
                    _buildStatusChip(
                      status,
                      isSettled ? _positiveColor : _pendingColor,
                    ),
                  ],
                ],
              ),
              if (account.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  'TA#$account',
                  style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (amountText.isNotEmpty)
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            if (dateDisplay.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text(
                dateDisplay,
                style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    String title,
    String actionText,
    Widget child, {
    VoidCallback? onAction,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading.copyWith(fontSize: 14.sp),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionText,
                  style: TextStyle(
                    color: onAction != null
                        ? AppColors.primary
                        : AppColors.textGrey,
                    fontSize: 10.sp,
                    fontWeight:
                        onAction != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is Map) {
      if (value.isNotEmpty) {
        return _parseDouble(value.values.first);
      }
    }
    return 0.0;
  }
}
