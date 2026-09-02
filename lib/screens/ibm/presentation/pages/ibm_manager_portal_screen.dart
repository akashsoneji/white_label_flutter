import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';

class IbmManagerPortalScreen extends StatefulWidget {
  const IbmManagerPortalScreen({super.key});

  @override
  State<IbmManagerPortalScreen> createState() => _IbmManagerPortalScreenState();
}

class _IbmManagerPortalScreenState extends State<IbmManagerPortalScreen> {
  final IbmController controller = Get.find<IbmController>();

  String selectedScope = 'total'; // total, network, direct
  String selectedPeriod =
      'this_month'; // today, 7d, 30d, this_month, all, custom
  String? customFrom;
  String? customTo;

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
        helpText: 'Select start date',
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
        helpText: 'Select end date',
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
      appBar: const IbmTopHeader(
        title: 'IB Manager Portal',
        showBackButton: false,
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
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final data = controller.dashboardData;
        final actData = controller.dashboardActivityData;
        final requests = controller.requestsData;

        // Fallback structures if API is empty
        final clients = data['clients'] ?? {};
        final partners = data['partners'] ?? {};
        final funnel = data['funnel'] ?? {};
        final currencies = data['currencies'] ?? [];
        final Map<String, dynamic> firstCurrency =
            (currencies is List && currencies.isNotEmpty) ? currencies[0] : {};

        final funding = firstCurrency['funding'] ?? {};
        final deposits = _parseDouble(funding['deposits'] ?? funding['net']);
        final withdrawals = _parseDouble(funding['withdrawals']);

        final equityData = firstCurrency['equity'] ?? {};
        final equity = _parseDouble(
          equityData['equity'] ?? equityData['balance'],
        );

        final commData = firstCurrency['commission'] ?? {};
        final commission = _parseDouble(commData['period'] ?? commData['mtd']);
        final lots = _parseDouble(commData['lots']);
        final trades = _parseDouble(commData['trades']).toInt();
        final perLot = _parseDouble(commData['per_lot']);

        // Use dashboard wallet data directly
        final effectiveWallet = data['wallet'] ?? firstCurrency['wallet'] ?? {};
        final network = controller.networkData;

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
              SizedBox(height: 24.h),
              _buildTopGrid(
                clients,
                partners,
                deposits,
                withdrawals,
                equity,
                commission,
                lots,
                trades,
                perLot,
              ),
              SizedBox(height: 24.h),
              _buildCommissionSummary(effectiveWallet),
              SizedBox(height: 24.h),
              _buildClientFunnel(funnel),
              SizedBox(height: 24.h),
              _buildSubIbPerformance(network['rows']),
              SizedBox(height: 24.h),
              _buildActivityRow(actData, requests),
              SizedBox(height: 40.h),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeaderRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dashboard',
              style: AppTextStyles.heading.copyWith(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildToggleGroup(
                options: {
                  'total': 'Total',
                  'network': 'Network',
                  'direct': 'Direct',
                },
                selectedValue: selectedScope,
                onChanged: _onScopeChanged,
              ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          'Your IB performance overview',
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textGrey,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 10.h),
        _buildToggleGroup(
          options: {
            'today': 'Today',
            '7d': '7D',
            '30d': '30D',
            'this_month': 'MTD',
            'all': 'All',
            'custom': 'Custom',
          },
          selectedValue: selectedPeriod,
          onChanged: _onPeriodChanged,
          fillWidth: true,
        ),
      ],
    );
  }

  Widget _buildToggleGroup({
    required Map<String, String> options,
    required String selectedValue,
    required Function(String) onChanged,
    bool fillWidth = false,
  }) {
    Widget buildItem(MapEntry<String, String> e) {
      final isSelected = e.key == selectedValue;
      return GestureDetector(
        onTap: () => onChanged(e.key),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: 6.w,
            vertical: 8.h,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            e.value,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
              fontSize: 11.sp,
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


  Widget _buildTopGrid(
    Map clients,
    Map partners,
    double deposits,
    double withdrawals,
    double equity,
    double commission,
    double lots,
    int trades,
    double perLot,
  ) {
    final totalClients = clients['total'] ?? 0;
    final newInPeriod = clients['new_in_period'] ?? 0;
    final activeTraders = clients['active'] ?? 0;
    final directPartners = partners['direct'] ?? 0;
    final networkPartners = partners['network'] ?? 0;
    final totalSubIbs = directPartners + networkPartners;
    final netFlow = deposits - withdrawals;
    // Web "Average Lots per Trader" = total lots / active traders (not / trades).
    final activeTradersNum =
        activeTraders is num ? activeTraders : num.tryParse('$activeTraders') ?? 0;
    final avgLotSize =
        activeTradersNum > 0 ? lots / activeTradersNum : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroEarnedCard(commission),
        SizedBox(height: 14.h),
        Row(
          children: [
            Expanded(
              child: _buildPillStat(
                icon: Icons.people_alt_rounded,
                iconBg: AppColors.iconBgPrimary,
                iconColor: AppColors.primary,
                label: 'Total Clients',
                value: '$totalClients',
                hint: '$newInPeriod new this period',
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _buildPillStat(
                icon: Icons.trending_up_rounded,
                iconBg: const Color(0xFF00C48C).withValues(alpha: 0.12),
                iconColor: const Color(0xFF00C48C),
                label: 'Active Traders',
                value: '$activeTraders',
                hint: 'traded this period',
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _buildPillStat(
                icon: Icons.account_tree_rounded,
                iconBg: AppColors.iconBgPrimary,
                iconColor: AppColors.primary,
                label: 'Sub-IBs',
                value: '$totalSubIbs',
                hint: '$directPartners direct',
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        _buildDefaultLinkCard(controller.linksList),
        SizedBox(height: 14.h),
        _buildMoneyFlowRow(deposits, withdrawals, equity, netFlow),
        SizedBox(height: 14.h),
        _buildPerformanceGrid(lots, trades, perLot, avgLotSize),
      ],
    );
  }

  Widget _buildDefaultLinkCard(List links) {
    Map? defaultLink;
    for (final l in links) {
      if (l is Map && (l['is_default_link'] == true || l['is_default'] == true)) {
        defaultLink = l;
        break;
      }
    }
    if (defaultLink == null && links.isNotEmpty && links.first is Map) {
      defaultLink = links.first as Map;
    }

    final code = defaultLink?['code']?.toString() ?? 'PARTNER123';
    final label = defaultLink?['label']?.toString() ?? 'Default Partner Link';

    return Container(
      padding: EdgeInsets.all(14.w),
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
                'Default Referral Link',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.isDarkMode ? Colors.grey[900] : const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 16.w, color: AppColors.primary),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    code,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 16.w, color: AppColors.primary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    CustomToastService.showSuccess(message: 'Referral code copied!');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroEarnedCard(double commission) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.payments_rounded, color: AppColors.whiteColor, size: 20.w),
              ),
              SizedBox(width: 10.w),
              Text(
                'Earned this period',
                style: TextStyle(
                  color: AppColors.whiteColor.withValues(alpha: 0.9),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            '\$${commission.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.whiteColor,
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14.w, color: AppColors.whiteColor.withValues(alpha: 0.85)),
              SizedBox(width: 4.w),
              Text(
                _periodLabel(),
                style: TextStyle(
                  color: AppColors.whiteColor.withValues(alpha: 0.85),
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _periodLabel() {
    switch (selectedPeriod) {
      case 'today':
        return 'Today';
      case '7d':
        return 'Last 7 days';
      case '30d':
        return 'Last 30 days';
      case 'this_month':
        return 'Month to date';
      case 'all':
        return 'All time';
      case 'custom':
        if (customFrom != null && customTo != null) return '$customFrom → $customTo';
        return 'Custom range';
      default:
        return 'Selected period';
    }
  }

  Widget _buildPillStat({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String hint,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: iconColor, size: 16.w),
          ),
          SizedBox(height: 10.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            hint,
            style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

Widget _buildMoneyFlowRow(double deposits, double withdrawals, double equity, double netFlow) {
    final netPositive = netFlow >= 0;
    final netColor = netPositive ? const Color(0xFF00C48C) : const Color(0xFFFF647C);
    final depositsColor = const Color(0xFF00C48C);
    final withdrawalsColor = const Color(0xFFFF647C);

    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MONEY FLOW',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.iconBgSurface,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'This period',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildColoredMiniStat(
                  label: 'Deposits',
                  value: '\$${deposits.toStringAsFixed(2)}',
                  icon: Icons.south_west_rounded,
                  color: depositsColor,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildColoredMiniStat(
                  label: 'Withdrawals',
                  value: '\$${withdrawals.toStringAsFixed(2)}',
                  icon: Icons.north_east_rounded,
                  color: withdrawalsColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildColoredMiniStat(
                  label: 'Client Equity',
                  value: '\$${equity.toStringAsFixed(2)}',
                  icon: Icons.account_balance_rounded,
                  color: AppColors.primary,
                  trailingText: 'live',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildColoredMiniStat(
                  label: 'Net flow',
                  value: '${netPositive ? '+' : ''}\$${netFlow.toStringAsFixed(2)}',
                  icon: netPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: netColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColoredMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? trailingText,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.iconBgSurface,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(icon, size: 14.w, color: color),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trailingText ?? label,
                  style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
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

  Widget _buildPerformanceGrid(double lots, int trades, double perLot, double avgLotSize) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFORMANCE',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _buildMiniStat(label: 'Total Lots', value: lots.toStringAsFixed(2), icon: Icons.bar_chart_rounded)),
              SizedBox(width: 10.w),
              Expanded(child: _buildMiniStat(label: 'Trades', value: '$trades', icon: Icons.swap_horiz_rounded)),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(child: _buildMiniStat(label: 'Per Lot', value: '\$${perLot.toStringAsFixed(2)}', icon: Icons.percent_rounded)),
              SizedBox(width: 10.w),
              Expanded(child: _buildMiniStat(label: 'Avg Lots/Trader', value: avgLotSize.toStringAsFixed(2), icon: Icons.straighten_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({required String label, required String value, required IconData icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.iconBgSurface,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Icon(icon, size: 14.w, color: AppColors.primary),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildCommissionSummary(Map wallet) {
    final sum = wallet.containsKey('summary') ? wallet['summary'] : wallet;
    final earned = _parseDouble(sum['lifetime_earned'] ?? sum['total_earned']);
    final paid = _parseDouble(sum['lifetime_paid'] ?? sum['total_paid']);
    final pending = _parseDouble(sum['pending_payout'] ?? sum['total_pending']);
    final available = _parseDouble(
      sum['unpaid_balance'] ?? sum['total_available'],
    );
    final total = earned > 0 ? earned : 1.0;
    final paidRatio = (paid / total).clamp(0.0, 1.0);
    final pendingRatio = (pending / total).clamp(0.0, 1.0);
    final availableRatio = (available / total).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Commission Summary',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'USD · lifetime',
                style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: SizedBox(
              height: 10.h,
              child: Row(
                children: [
                  if (paidRatio > 0)
                    Expanded(
                      flex: (paidRatio * 1000).round(),
                      child: Container(color: AppColors.primary),
                    ),
                  if (pendingRatio > 0)
                    Expanded(
                      flex: (pendingRatio * 1000).round(),
                      child: Container(color: const Color(0xFFFFB547)),
                    ),
                  if (availableRatio > 0)
                    Expanded(
                      flex: (availableRatio * 1000).round(),
                      child: Container(color: const Color(0xFF00C48C)),
                    ),
                  if (paidRatio + pendingRatio + availableRatio <= 0)
                    Expanded(child: Container(color: AppColors.divider)),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  label: 'Paid',
                  value: paid,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildLegendItem(
                  label: 'Pending',
                  value: pending,
                  color: const Color(0xFFFFB547),
                ),
              ),
              Expanded(
                child: _buildLegendItem(
                  label: 'Available',
                  value: available,
                  color: const Color(0xFF00C48C),
                  highlight: true,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            height: 1,
            color: AppColors.divider.withValues(alpha: 0.5),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total earned',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '\$${earned.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required double value,
    required Color color,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              label,
              style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFF00C48C) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildClientFunnel(Map funnel) {
    final visits = funnel['visits'] ?? 0;
    final uniqueVisits = funnel['unique_visits'] ?? 0;
    final signUps = funnel['signups'] ?? 0;
    final accounts = funnel['accounts'] ?? 0;
    final funded = funnel['funded'] ?? 0;

    // Calculate percentages
    final uniquePercent =
        visits > 0 ? (uniqueVisits / visits * 100).toStringAsFixed(0) : '0';
    final signupsPercent =
        uniqueVisits > 0
            ? (signUps / uniqueVisits * 100).toStringAsFixed(0)
            : '0';

    return _buildSectionCard(
      'Client Funnel',
      'from your referral links',
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120.w,
              child: _buildSimpleStat('Link clicks', '$visits'),
            ),
            SizedBox(
              width: 120.w,
              child: _buildSimpleStat(
                'Different people',
                '$uniqueVisits\n$uniquePercent%',
              ),
            ),
            SizedBox(
              width: 120.w,
              child: _buildSimpleStat(
                'Signed up',
                '$signUps\n$signupsPercent%',
              ),
            ),
            SizedBox(
              width: 120.w,
              child: _buildSimpleStat('Opened account', '$accounts'),
            ),
            SizedBox(
              width: 120.w,
              child: _buildSimpleStat('Funded it', '$funded'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubIbPerformance(dynamic rowsList) {
    List rows = rowsList is List ? rowsList : [];
    if (rows.isEmpty) {
      return _buildSectionCard(
        'Sub-IB Performance',
        'View all',
        Text(
          'Nobody is below you yet.',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    return _buildSectionCard(
      'Sub-IB Performance',
      'View all',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: 12.h),
            _buildSubIbRow(rows[i] is Map ? rows[i] as Map : {}),
          ],
        ],
      ),
      onAction: () => controller.currentTabIndex.value = 2,
    );
  }

  Widget _buildSubIbRow(Map row) {
    final name = (row['name'] ?? 'Unknown').toString();
    final clients = row['clients'] ?? 0;
    final active = row['active_clients'] ?? row['active'] ?? 0;

    final List currencies =
        row['currencies'] is List ? row['currencies'] : [];
    final firstCurrency = currencies.isNotEmpty ? currencies.first : {};

    final netDeposit = _parseDouble(
      firstCurrency['net_funding'] ?? firstCurrency['deposits'],
    );
    final earned = _parseDouble(firstCurrency['commission']);
    final lots = _parseDouble(firstCurrency['lots']);
    final isActive = _parseDouble(active) >= 1;
    final badgeColor = isActive ? Colors.orange : Colors.red;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8.r),
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
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(
                    color: AppColors.whiteColor,
                    fontSize: 10.sp,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  isActive ? 'Low' : 'Inactive',
                  style: TextStyle(color: badgeColor, fontSize: 10.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net deposit',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                    ),
                  ),
                  Text(
                    '\$${netDeposit.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You earned',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                    ),
                  ),
                  Text(
                    '\$${earned.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '$clients clients   $active active   ${lots.toStringAsFixed(2)} lots',
            style: TextStyle(color: AppColors.textGrey, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(Map actData, Map requestsMap) {
    final deposits = actData['deposits'] is List ? actData['deposits'] : [];
    final withdrawals =
        actData['withdrawals'] is List ? actData['withdrawals'] : [];
    final payouts = actData['payouts'] is List ? actData['payouts'] : [];
    final accounts = actData['accounts'] is List ? actData['accounts'] : [];

    final List requestsList = requestsMap['rows'] ?? requestsMap['data'] ?? [];
    final pendingRequests =
        requestsList.where((r) => r['status'] == 'pending').toList();

    return SizedBox(
      height: 140.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildActivityCard(
            Icons.arrow_downward,
            'Deposits',
            'pending & approved',
            _buildActivityListContent(deposits, 'No new deposits', true),
            Colors.green,
          ),
          _buildActivityCard(
            Icons.arrow_upward,
            'Withdrawals',
            'pending & approved',
            _buildActivityListContent(
              withdrawals,
              'Nobody has withdrawn.',
              false,
            ),
            Colors.red,
          ),
          _buildActivityCard(
            Icons.account_balance,
            'Payouts',
            'you & your downline',
            _buildActivityListContent(
              payouts,
              'No payout has been taken yet.',
              false,
            ),
            AppColors.primary,
          ),
          _buildActivityCard(
            Icons.person_add,
            'New accounts',
            'whole downline',
            _buildActivityListContent(accounts, 'No new accounts.', true),
            Colors.blue,
          ),
          _buildActivityCard(
            Icons.group,
            'Sub-IB requests',
            'waiting on you',
            _buildActivityListContent(
              pendingRequests,
              'Nobody is waiting for an answer.',
              true,
            ),
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    IconData icon,
    String title,
    String subtitle,
    Widget content,
    Color color,
  ) {
    return Container(
      width: 220.w,
      margin: EdgeInsets.only(right: 12.w),
      padding: EdgeInsets.all(12.w),
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
              Icon(icon, color: color, size: 16.w),
              SizedBox(width: 6.w),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp),
          ),
          Spacer(),
          content,
          Spacer(),
        ],
      ),
    );
  }

  Widget _buildActivityListContent(
    List items,
    String emptyMessage,
    bool isPositive,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          items.take(2).map((item) {
            final name = item['name'] ?? 'Unknown';
            final status = item['status'] ?? '';
            final amount = _parseDouble(item['amount']);
            final account = item['account'] ?? '';
            final atStr = (item['at'] ?? '').toString();
            final dateDisplay = atStr.isNotEmpty ? atStr.split(' ').first : '';

            final amountStr =
                amount > 0
                    ? (isPositive
                        ? '+\$${amount.toStringAsFixed(2)}'
                        : '\$${amount.toStringAsFixed(2)}')
                    : '';

            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            if (status.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      status == 'approved' || status == 'opened'
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  status.isNotEmpty
                                      ? status[0].toUpperCase() +
                                          status.substring(1)
                                      : status,
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    color:
                                        status == 'approved' ||
                                                status == 'opened'
                                            ? Colors.green
                                            : Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (account.isNotEmpty)
                          Text(
                            'TA#$account',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (amountStr.isNotEmpty)
                        Text(
                          amountStr,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color:
                                isPositive
                                    ? Colors.green
                                    : AppColors.textPrimary,
                          ),
                        ),
                      if (dateDisplay.isNotEmpty)
                        Text(
                          dateDisplay,
                          style: TextStyle(
                            fontSize: 8.sp,
                            color: AppColors.textGrey,
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

  Widget _buildSectionCard(
    String title,
    String actionText,
    Widget child, {
    VoidCallback? onAction,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.heading.copyWith(fontSize: 14.sp),
              ),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionText,
                  style: TextStyle(
                    color: onAction != null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight:
                        onAction != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, {Color? valueColor}) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
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
