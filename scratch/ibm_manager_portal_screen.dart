import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchDashboard(period: selectedPeriod, scope: selectedScope);
    });
  }

  void _onScopeChanged(String scope) {
    setState(() {
      selectedScope = scope;
    });
    controller.fetchDashboard(period: selectedPeriod, scope: selectedScope);
  }

  void _onPeriodChanged(String period) {
    setState(() {
      selectedPeriod = period;
    });
    controller.fetchDashboard(period: selectedPeriod, scope: selectedScope);
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
                      ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final data = controller.dashboardData;
        final actData = controller.dashboardActivityData;
        final wallet = controller.walletData;
        final requests = controller.requestsData;

        // Fallback structures if API is empty
        final clients = data['clients'] ?? {};
        final partners = data['partners'] ?? {};
        final funnel = data['funnel'] ?? {};
        final currencies = data['currencies'] ?? [];
        final Map<String, dynamic> firstCurrency =
            (currencies is List && currencies.isNotEmpty) ? currencies[0] : {};

        final deposits = _parseDouble(firstCurrency['deposits']);
        final withdrawals = _parseDouble(firstCurrency['withdrawals']);
        final equity = _parseDouble(firstCurrency['equity']);
        final commission = _parseDouble(firstCurrency['commission']);

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh:
              () => controller.fetchDashboard(
                period: selectedPeriod,
                scope: selectedScope,
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
              ),
              SizedBox(height: 24.h),
              _buildCommissionSummary(wallet),
              SizedBox(height: 24.h),
              _buildClientFunnel(funnel),
              SizedBox(height: 24.h),
              _buildSubIbPerformance(data['top_earners']),
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
        Text(
          'Dashboard',
          style: AppTextStyles.heading.copyWith(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Your IB performance overview',
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textGrey,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 16.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildToggleGroup(
                options: {
                  'total': 'Total',
                  'network': 'Network',
                  'direct': 'Direct',
                },
                selectedValue: selectedScope,
                onChanged: _onScopeChanged,
              ),
              SizedBox(width: 12.w),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleGroup({
    required Map<String, String> options,
    required String selectedValue,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            options.entries.map((e) {
              final isSelected = e.key == selectedValue;
              return GestureDetector(
                onTap: () => onChanged(e.key),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFF5F259E)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 11.sp,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
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
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          title: 'Total Clients',
          value: '${clients['total'] ?? 0}',
          subtitle: '${clients['new_in_period'] ?? 0} new this month',
          icon: Icons.people,
          color: Color(0xFF5F259E),
        ),
        _buildStatCard(
          title: 'Active Traders',
          value: '${clients['active'] ?? 0}',
          subtitle: 'traded this month',
          icon: Icons.person,
          color: Color(0xFF5F259E),
        ),
        _buildStatCard(
          title: 'Sub-IBs',
          value: '${(partners['direct'] ?? 0) + (partners['network'] ?? 0)}',
          subtitle: '${partners['direct'] ?? 0} directly under you',
          icon: Icons.account_tree,
          color: Color(0xFF5F259E),
        ),
        _buildStatCard(
          title: 'Total Deposits',
          value: '\$${deposits.toStringAsFixed(2)}',
          subtitle: 'net',
          icon: Icons.arrow_circle_down,
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'Total Withdrawals',
          value: '\$${withdrawals.toStringAsFixed(2)}',
          subtitle: '',
          icon: Icons.arrow_circle_up,
          color: Colors.red,
        ),

        _buildStatCard(
          title: 'Client Equity',
          value: '\$${equity.toStringAsFixed(2)}',
          subtitle: 'right now',
          icon: Icons.account_balance_wallet,
          color: Color(0xFF5F259E),
        ),
        _buildStatCard(
          title: 'Total Lots',
          value: '0.00',
          subtitle: '0 trades',
          icon: Icons.bar_chart,
          color: Color(0xFF5F259E),
        ),
        _buildStatCard(
          title: 'Per Lot',
          value: '\$0.00',
          subtitle: 'across everything',
          icon: Icons.percent,
          color: Color(0xFF5F259E),
        ),
        _buildStatCard(
          title: 'Avg Lot Size',
          value: '0.00',
          subtitle: 'this month',
          icon: Icons.pie_chart,
          color: Color(0xFF5F259E),
        ),
        _buildStatCard(
          title: 'Earned today',
          value: '\$${commission.toStringAsFixed(2)}',
          subtitle: '',
          icon: Icons.monetization_on,
          color: Color(0xFF5F259E),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: color, size: 16.w),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 10.sp),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionSummary(Map wallet) {
    // Assuming wallet structure has totals, if not we show 0
    final sum = wallet['summary'] ?? {};
    final earned = _parseDouble(sum['total_earned']);
    final paid = _parseDouble(sum['total_paid']);
    final pending = _parseDouble(sum['total_pending']);
    final available = _parseDouble(sum['total_available']);

    return _buildSectionCard(
      'Commission Summary',
      'USD - lifetime unless stated',
      Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSimpleStat(
                  'TOTAL EARNED',
                  '\$${earned.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _buildSimpleStat(
                  'PAID OUT',
                  '\$${paid.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _buildSimpleStat(
                  'PENDING',
                  '\$${pending.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _buildSimpleStat(
                  'AVAILABLE',
                  '\$${available.toStringAsFixed(2)}',
                  valueColor: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildProgressBar(
            'Direct clients',
            0.5,
            Color(0xFF5F259E),
            '\$${(earned / 2).toStringAsFixed(2)} - 50%',
          ),
          SizedBox(height: 8.h),
          _buildProgressBar(
            'Sub-IB network',
            0.5,
            Colors.green,
            '\$${(earned / 2).toStringAsFixed(2)} - 50%',
          ),
        ],
      ),
    );
  }

  Widget _buildClientFunnel(Map funnel) {
    final linkClicks = funnel['link_clicks'] ?? 0;
    final signUps = funnel['sign_ups'] ?? 0;
    final accounts = funnel['accounts_opened'] ?? 0;
    final funded = funnel['funded'] ?? 0;

    return _buildSectionCard(
      'Client Funnel',
      'from your referral links',
      Row(
        children: [
          Expanded(child: _buildSimpleStat('Link clicks', '$linkClicks')),
          Expanded(
            child: _buildSimpleStat('Different people', '$linkClicks\n100%'),
          ),
          Expanded(child: _buildSimpleStat('Signed up', '$signUps\n0%')),
          Expanded(child: _buildSimpleStat('Opened account', '$accounts')),
          Expanded(child: _buildSimpleStat('Funded it', '$funded')),
        ],
      ),
    );
  }

  Widget _buildSubIbPerformance(dynamic topEarnersList) {
    List earners = topEarnersList is List ? topEarnersList : [];
    if (earners.isEmpty) {
      return _buildSectionCard(
        'Sub-IB Performance',
        'View all',
        Text('No Sub-IBs found.', style: TextStyle(color: Colors.grey)),
      );
    }

    final earner = earners.first;
    final name = earner['name'] ?? 'Unknown';
    final earned = earner['commission'] ?? 0.0;

    return _buildSectionCard(
      'Sub-IB Performance',
      'View all',
      Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFF5F259E),
                  radius: 12.r,
                  child: Text(
                    name[0],
                    style: TextStyle(color: Colors.white, fontSize: 10.sp),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    'Low',
                    style: TextStyle(color: Colors.orange, fontSize: 10.sp),
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
                      style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                    ),
                    Text(
                      '\$0.00',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You earned',
                      style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                    ),
                    Text(
                      '\$${earned.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              '0 clients   0 active   0.00 lots',
              style: TextStyle(color: Colors.grey, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(Map actData, Map requestsMap) {
    // requests map has 'rows'
    final List requestsList = requestsMap['rows'] ?? requestsMap['data'] ?? [];
    final pendingRequests =
        requestsList.where((r) => r['status'] == 'pending').length;

    return SizedBox(
      height: 140.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildActivityCard(
            Icons.arrow_downward,
            'Deposits',
            'pending & approved',
            'No new deposits',
            Colors.green,
          ),
          _buildActivityCard(
            Icons.arrow_upward,
            'Withdrawals',
            'pending & approved',
            'Nobody has withdrawn.',
            Colors.red,
          ),
          _buildActivityCard(
            Icons.account_balance,
            'Payouts',
            'you & your downline',
            'No payout has been taken yet.',
            Color(0xFF5F259E),
          ),
          _buildActivityCard(
            Icons.person_add,
            'New accounts',
            'whole downline',
            'No new accounts.',
            Colors.blue,
          ),
          _buildActivityCard(
            Icons.group,
            'Sub-IB requests',
            'waiting on you',
            pendingRequests > 0
                ? '$pendingRequests waiting'
                : 'Nobody is waiting for an answer.',
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
    String message,
    Color color,
  ) {
    return Container(
      width: 160.w,
      margin: EdgeInsets.only(right: 12.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
              ),
            ],
          ),
          Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 10.sp)),
          Spacer(),
          Center(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey, fontSize: 11.sp),
              textAlign: TextAlign.center,
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, String actionText, Widget child) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
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
              Text(
                actionText,
                style: TextStyle(color: Colors.grey, fontSize: 11.sp),
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
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey,
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
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    String label,
    double percent,
    Color color,
    String valueText,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey, fontSize: 11.sp),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          valueText,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp),
        ),
      ],
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
