import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/pmam/view_models/pmam_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/pmam/presentation/pages/pmam_manager_investor_detail_screen.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class PmamManagerPortalScreen extends StatefulWidget {
  const PmamManagerPortalScreen({super.key});

  @override
  State<PmamManagerPortalScreen> createState() =>
      _PmamManagerPortalScreenState();
}

class _PmamManagerPortalScreenState extends State<PmamManagerPortalScreen>
    with SingleTickerProviderStateMixin {
  late final PmamController _ctrl;
  late final TabController _tabCtrl;
  String _investorFilter = 'all';
  int? _actionInvestorId;
  String? _actionType; // approve | reject

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    if (Get.isRegistered<PmamController>()) {
      _ctrl = Get.find<PmamController>();
    } else {
      _ctrl = Get.put(PmamController());
    }
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _ctrl.loadManagerDashboard(),
      _ctrl.loadManagerInvestors(),
    ]);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      case 'pending':
        return AppColors.statusYellow;
      default:
        return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text('Manager Portal', style: AppTextStyles.heading),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: GestureDetector(
              onTap: () => Get.toNamed(AppPages.PMAM_CREATE_PLAN),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '+ New Plan',
                  style: TextStyle(
                    color: AppColors.whiteColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(46.h),
          child: Container(
            color: AppColors.whiteColor,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textGrey,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(fontSize: 14.sp),
              tabs: const [Tab(text: 'My Investors'), Tab(text: 'My Plans')],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildInvestorsTab(), _buildPlansTab()],
      ),
    );
  }

  // ─── INVESTORS TAB ───────────────────────────────────────────────────────
  Widget _buildInvestorsTab() {
    return Obx(() {
      if (_ctrl.isInvestorsLoading.value) {
        return Center(
          child: CommonLoadingWidget(size: 36, color: AppColors.primary),
        );
      }

      final allInvestors = _ctrl.managerInvestors;

      final counts = {
        'active': allInvestors.where((i) => i['status'] == 'active').length,
        'inactive': allInvestors.where((i) => i['status'] == 'inactive').length,
        'rejected': allInvestors.where((i) => i['status'] == 'rejected').length,
        'pending': allInvestors.where((i) => i['status'] == 'pending').length,
      };

      final filtered =
          _investorFilter == 'all'
              ? allInvestors
              : allInvestors
                  .where((i) => i['status'] == _investorFilter)
                  .toList();

      return Column(
        children: [
          SizedBox(height: 12.h),

          // Summary stats bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatPill(
                  label: 'Total',
                  value: '${allInvestors.length}',
                  color: AppColors.primary,
                ),
                _VertDivider(),
                _StatPill(
                  label: 'Active',
                  value: '${counts['active']}',
                  color: AppColors.green,
                ),
                _VertDivider(),
                _StatPill(
                  label: 'Inactive',
                  value: '${counts['inactive']}',
                  color: AppColors.textGrey,
                ),
                _VertDivider(),
                _StatPill(
                  label: 'Rejected',
                  value: '${counts['rejected']}',
                  color: AppColors.red,
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _PortalFilterChip(
                  label: 'All',
                  count: allInvestors.length,
                  selected: _investorFilter == 'all',
                  onTap: () => setState(() => _investorFilter = 'all'),
                ),
                SizedBox(width: 8.w),
                _PortalFilterChip(
                  label: 'Active',
                  count: counts['active']!,
                  selected: _investorFilter == 'active',
                  onTap: () => setState(() => _investorFilter = 'active'),
                ),
                SizedBox(width: 8.w),
                _PortalFilterChip(
                  label: 'Inactive',
                  count: counts['inactive']!,
                  selected: _investorFilter == 'inactive',
                  onTap: () => setState(() => _investorFilter = 'inactive'),
                ),
                SizedBox(width: 8.w),
                _PortalFilterChip(
                  label: 'Rejected',
                  count: counts['rejected']!,
                  selected: _investorFilter == 'rejected',
                  onTap: () => setState(() => _investorFilter = 'rejected'),
                ),
                SizedBox(width: 8.w),
                _PortalFilterChip(
                  label: 'Pending',
                  count: counts['pending']!,
                  selected: _investorFilter == 'pending',
                  onTap: () => setState(() => _investorFilter = 'pending'),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // Investor list
          Expanded(
            child:
                filtered.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 48.sp,
                            color: AppColors.textGrey.withOpacity(0.4),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'No investors in this category',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _ctrl.loadManagerInvestors,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8.h),
                        itemBuilder: (_, i) {
                          final inv = filtered[i];
                          final invId =
                              int.tryParse(inv['id']?.toString() ?? '') ?? 0;
                          final name =
                              (inv['investor_name'] ?? 'Unknown').toString();
                          final email =
                              (inv['investor_email'] ?? '').toString();
                          final account =
                              (inv['account_number'] ?? '-').toString();
                          final invested =
                              double.tryParse(
                                inv['invested_amount']?.toString() ?? '0',
                              ) ??
                              0.0;
                          final pnl =
                              double.tryParse(
                                inv['net_pnl']?.toString() ?? '0',
                              ) ??
                              0.0;
                          final status = (inv['status'] ?? '').toString();
                          final activeSince =
                              (inv['active_since'] ?? '').toString();
                          final pnlIsPos = pnl >= 0;
                          final bool isPending = status == 'pending';
                          final bool isActionLoading =
                              _actionInvestorId == invId &&
                              (_actionType == 'approve' ||
                                  _actionType == 'reject');

                          final initials =
                              name
                                  .split(' ')
                                  .take(2)
                                  .map(
                                    (e) =>
                                        e.isNotEmpty ? e[0].toUpperCase() : '',
                                  )
                                  .join();

                          return Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: AppColors.whiteColor,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name + status row
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20.r,
                                      backgroundColor: AppColors.primary
                                          .withOpacity(0.12),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              color: AppColors.textGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 9.w,
                                        vertical: 3.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          status,
                                        ).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),

                                // Info grid
                                Container(
                                  padding: EdgeInsets.all(10.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.tradeBackgroundCenterColor,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _InvInfoCol(
                                          label: 'Account',
                                          value: account,
                                        ),
                                      ),
                                      Expanded(
                                        child: _InvInfoCol(
                                          label: 'Invested',
                                          value:
                                              '\$${invested.toStringAsFixed(2)}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _InvInfoCol(
                                          label: 'Net PnL',
                                          value:
                                              '${pnlIsPos ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                                          valueColor:
                                              pnlIsPos
                                                  ? AppColors.green
                                                  : AppColors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (activeSince.isNotEmpty &&
                                    activeSince.length >= 10) ...[
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Active since: ${activeSince.substring(0, 10)}',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],

                                SizedBox(height: 12.h),
                                if (isPending)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed:
                                              isActionLoading
                                                  ? null
                                                  : () async {
                                                    setState(() {
                                                      _actionInvestorId = invId;
                                                      _actionType = 'reject';
                                                    });
                                                    final ok =
                                                        await _ctrl
                                                            .rejectInvestorRequest(
                                                              invId,
                                                            );
                                                    if (ok) {
                                                      await _ctrl
                                                          .loadManagerInvestors();
                                                    }
                                                    if (mounted) {
                                                      setState(() {
                                                        _actionInvestorId = null;
                                                        _actionType = null;
                                                      });
                                                    }
                                                  },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: AppColors.red),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                10.r,
                                              ),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              vertical: 10.h,
                                            ),
                                          ),
                                          child: isActionLoading &&
                                                  _actionType == 'reject'
                                              ? SizedBox(
                                                height: 16.h,
                                                width: 16.h,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.red,
                                                ),
                                              )
                                              : Text(
                                                'Reject',
                                                style: TextStyle(
                                                  color: AppColors.red,
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              isActionLoading
                                                  ? null
                                                  : () async {
                                                    setState(() {
                                                      _actionInvestorId = invId;
                                                      _actionType = 'approve';
                                                    });
                                                    final ok =
                                                        await _ctrl
                                                            .approveInvestorRequest(
                                                              invId,
                                                            );
                                                    if (ok) {
                                                      await _ctrl
                                                          .loadManagerInvestors();
                                                    }
                                                    if (mounted) {
                                                      setState(() {
                                                        _actionInvestorId = null;
                                                        _actionType = null;
                                                      });
                                                    }
                                                  },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: AppColors.whiteColor,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                10.r,
                                              ),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              vertical: 10.h,
                                            ),
                                          ),
                                          child: isActionLoading &&
                                                  _actionType == 'approve'
                                              ? SizedBox(
                                                height: 16.h,
                                                width: 16.h,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.whiteColor,
                                                ),
                                              )
                                              : Text(
                                                'Approve',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Get.to(
                                          () => PmamManagerInvestorDetailScreen(
                                            investorId: invId,
                                            investorName: name,
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 10.h,
                                        ),
                                      ),
                                      child: Text(
                                        'View',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      );
    });
  }

  // ─── PLANS TAB ───────────────────────────────────────────────────────────
  Widget _buildPlansTab() {
    return Obx(() {
      if (_ctrl.isLoading.value && _ctrl.managerPlans.isEmpty) {
        return Center(
          child: CommonLoadingWidget(size: 36, color: AppColors.primary),
        );
      }
      final plans = _ctrl.managerPlans;
      if (plans.isEmpty) {
        return Center(
          child: Text(
            'No plans yet',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
          ),
        );
      }
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _ctrl.loadManagerDashboard,
        child: ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: plans.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (_, i) {
            final p = plans[i];
            final status = (p['status'] ?? '').toString();
            Color statusColor;
            switch (status) {
              case 'approved':
                statusColor = AppColors.green;
                break;
              case 'pending_admin':
                statusColor = AppColors.statusYellow;
                break;
              default:
                statusColor = AppColors.textGrey;
            }
            return Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
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
                      Expanded(
                        child: Text(
                          p['plan_name'] ?? 'Unnamed Plan',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          status == 'approved'
                              ? 'Approved'
                              : status == 'pending_admin'
                              ? 'Pending Admin'
                              : status,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _PortalPlanInfoRow(
                    'Account',
                    '${p['trading_account_number'] ?? p['trading_account_id'] ?? '-'}',
                  ),
                  _PortalPlanInfoRow(
                    'Commission',
                    '${p['commission_percentage'] ?? 0}%',
                  ),
                  _PortalPlanInfoRow(
                    'Min. Investment',
                    '\$${p['minimum_investment'] ?? 0}',
                  ),
                  _PortalPlanInfoRow(
                    'Investors',
                    '${p['active_investors'] ?? 0}',
                  ),
                  _PortalPlanInfoRow(
                    'Locked AUM',
                    '\$${p['total_locked'] ?? 0}',
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              () => Get.toNamed(
                                AppPages.PMAM_MANAGER_PLAN_DETAIL,
                                arguments: p['id'],
                              ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                          ),
                          child: Text(
                            'View Details',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (status == 'approved') ...[
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _ctrl.inactivatePlan(p['id'] ?? 0),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.red.withOpacity(0.1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                            ),
                            child: Text(
                              'Inactivate',
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 28.h, width: 1, color: AppColors.dividerDark);
  }
}

class _PortalFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _PortalFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.dividerMedium,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Text(
          count > 0 ? '$label ($count)' : label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.whiteColor : AppColors.textGrey,
          ),
        ),
      ),
    );
  }
}

class _InvInfoCol extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InvInfoCol({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PortalPlanInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _PortalPlanInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          Text(
            '$label: ',
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
}
