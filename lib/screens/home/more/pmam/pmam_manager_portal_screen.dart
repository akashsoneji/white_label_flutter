import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/pmam/pmam_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/language_service.dart';
import 'widgets/edit_plan_bottom_sheet.dart';
import 'package:crm_app/screens/home/more/pmam/pmam_manager_investor_detail_screen.dart';

class PmamManagerPortalScreen extends StatefulWidget {
  const PmamManagerPortalScreen({
    super.key,
    this.initialTab = 0,
    this.embedded = false,
  });

  /// 0 = Investors, 1 = Plans.
  final int initialTab;
  /// When true, hides the app bar (caller provides its own).
  final bool embedded;

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
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
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
        return AppColors.error;
      case 'pending':
        return AppColors.warningText;
      default:
        return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: widget.embedded
          ? null
          : AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
        title: Text(
            TranslationUtils.tr('pmam_manager_portal_screen_manager_portal'),
            style: AppTextStyles.heading),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 12.w),
            child: GestureDetector(
              onTap: () => Get.toNamed(AppPages.PMAM_CREATE_PLAN),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  TranslationUtils.tr('pmam_manager_portal_screen_new_plan'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.onColoredBackground,
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
            color: AppColors.onColoredBackground,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textGrey,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTextStyles.bodyText.copyWith(fontSize: 14.sp),
              tabs: [
                Tab(text: TranslationUtils.tr('pmam_main_screen_my_investors')),
                Tab(text: TranslationUtils.tr('copy_trading_nav_my_plans')),
              ],
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
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.border.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatPill(
                  label: TranslationUtils.tr('common_total'),
                  value: '${allInvestors.length}',
                  color: AppColors.primary,
                ),
                _VertDivider(),
                _StatPill(
                  label: TranslationUtils.tr('chart_active'),
                  value: '${counts['active']}',
                  color: AppColors.green,
                ),
                _VertDivider(),
                _StatPill(
                  label: TranslationUtils.tr('wallet_inactive'),
                  value: '${counts['inactive']}',
                  color: AppColors.textGrey,
                ),
                _VertDivider(),
                _StatPill(
                  label: TranslationUtils.tr('kyc_verification_rejected'),
                  value: '${counts['rejected']}',
                  color: AppColors.error,
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
                  label: TranslationUtils.tr('common_all'),
                  count: allInvestors.length,
                  selected: _investorFilter == 'all',
                  onTap: () => setState(() => _investorFilter = 'all'),
                ),
                SizedBox(width: 8.w),
                _PortalFilterChip(
                  label: TranslationUtils.tr('chart_active'),
                  count: counts['active']!,
                  selected: _investorFilter == 'active',
                  onTap: () => setState(() => _investorFilter = 'active'),
                ),
                SizedBox(width: 8.w),
                _PortalFilterChip(
                  label: TranslationUtils.tr('wallet_inactive'),
                  count: counts['inactive']!,
                  selected: _investorFilter == 'inactive',
                  onTap: () => setState(() => _investorFilter = 'inactive'),
                ),
                SizedBox(width: 8.w),
                _PortalFilterChip(
                  label: TranslationUtils.tr('kyc_verification_rejected'),
                  count: counts['rejected']!,
                  selected: _investorFilter == 'rejected',
                  onTap: () => setState(() => _investorFilter = 'rejected'),
                ),
                SizedBox(width: 8.w),
                _PortalFilterChip(
                  label: TranslationUtils.tr('kyc_verification_pending'),
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
                            TranslationUtils.tr(
                                'pmam_manager_portal_screen_no_investors_in_this_category'),
                            style: AppTextStyles.bodyText.copyWith(
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
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.border.withValues(alpha: 0.04),
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
                                        style: AppTextStyles.bodyText.copyWith(
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
                                            style: AppTextStyles.bodyText.copyWith(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            email,
                                            style: AppTextStyles.bodyText.copyWith(
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
                                        style: AppTextStyles.bodyText.copyWith(
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
                                          label: TranslationUtils.tr(
                                              'settings_account'),
                                          value: account,
                                        ),
                                      ),
                                      Expanded(
                                        child: _InvInfoCol(
                                          label:
                                              TranslationUtils.tr('pmam_invested'),
                                          value:
                                              '\$${invested.toStringAsFixed(2)}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _InvInfoCol(
                                          label: TranslationUtils.tr(
                                              'pmam_net_pnl_short'),
                                          value:
                                              '${pnlIsPos ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                                          valueColor:
                                              pnlIsPos
                                                  ? AppColors.green
                                                  : AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (activeSince.isNotEmpty &&
                                    activeSince.length >= 10) ...[
                                  SizedBox(height: 6.h),
                                  Text(
                                    '${TranslationUtils.tr('pmam_active_since')}: ${activeSince.substring(0, 10)}',
                                    style: AppTextStyles.bodyText.copyWith(
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
                                            side: BorderSide(color: AppColors.error),
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
                                                  color: AppColors.error,
                                                ),
                                              )
                                              : Text(
                                                TranslationUtils.tr('pmam_reject'),
                                                style: AppTextStyles.bodyText.copyWith(
                                                  color: AppColors.error,
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
                                            backgroundColor: AppColors.brandPrimary,
                                            foregroundColor: AppColors.onColoredBackground,
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
                                                  color: AppColors.onColoredBackground,
                                                ),
                                              )
                                              : Text(
                                                TranslationUtils.tr('ibm_approve'),
                                                style: AppTextStyles.bodyText.copyWith(
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
                                        TranslationUtils.tr('ibm_view'),
                                        style: AppTextStyles.bodyText.copyWith(
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
            TranslationUtils.tr('master_dashboard_overview_tab_no_plans_yet'),
            style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textGrey),
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
                statusColor = AppColors.warningText;
                break;
              case 'paused':
                statusColor = AppColors.warningText;
                break;
              default:
                statusColor = AppColors.textGrey;
            }
            final isPaused = status == 'paused' ||
                (p['is_paused'] == 1 || p['is_paused'] == true);
            final canPauseResume = status == 'approved' || isPaused;
            return Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border.withValues(alpha: 0.04),
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
                          style: AppTextStyles.bodyText.copyWith(
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
                              ? TranslationUtils.tr('kyc_verification_approved')
                              : status == 'pending_admin'
                              ? TranslationUtils.tr('pmam_pending_admin')
                              : status,
                          style: AppTextStyles.bodyText.copyWith(
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
                    TranslationUtils.tr('settings_account'),
                    '${p['trading_account_number'] ?? p['trading_account_id'] ?? '-'}',
                  ),
                  _PortalPlanInfoRow(
                    TranslationUtils.tr('general_commission'),
                    '${p['commission_percentage'] ?? 0}%',
                  ),
                  _PortalPlanInfoRow(
                    TranslationUtils.tr(
                        'pmam_manager_detail_screen_min_investment'),
                    '\$${p['minimum_investment'] ?? 0}',
                  ),
                  _PortalPlanInfoRow(
                    TranslationUtils.tr('pmam_nav_investors'),
                    '${p['active_investors'] ?? 0}',
                  ),
                  _PortalPlanInfoRow(
                    TranslationUtils.tr('pmam_locked_aum'),
                    '\$${p['total_locked'] ?? 0}',
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.visibility),
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
                           label:  Text(
                            TranslationUtils.tr('ibm_view'),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.primary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openEditPlan(p),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16.sp,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            TranslationUtils.tr('general_edit'),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.primary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                          ),
                        ),
                      ),
                      if (canPauseResume) ...[
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmPauseResume(
                              planId: (p['id'] is int)
                                  ? p['id'] as int
                                  : int.tryParse('${p['id']}') ?? 0,
                              planName: (p['plan_name'] ?? 'Plan').toString(),
                              isPaused: isPaused,
                            ),
                            icon: Icon(
                              isPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 16.sp,
                              color: isPaused
                                  ? AppColors.green
                                  : AppColors.warningText,
                            ),
                            label: Text(
                              isPaused
                                  ? TranslationUtils.tr('my_plans_tab_resume')
                                  : TranslationUtils.tr('my_plans_tab_pause'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: isPaused
                                    ? AppColors.green
                                    : AppColors.warningText,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (isPaused
                                      ? AppColors.green
                                      : AppColors.warningText)
                                  .withValues(alpha: 0.1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                            ),
                          ),
                        ),
                      ],
                      if (status == 'approved') ...[
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _ctrl.inactivatePlan(p['id'] ?? 0),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error.withValues(alpha: 0.1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                            ),
                            child: Text(
                              TranslationUtils.tr('pmam_inactivate'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.error,
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

  /// Opens the bottom-sheet edit modal (mirrors the web "Edit plan" dialog).
  Future<void> _openEditPlan(Map<String, dynamic> plan) async {
    await EditPlanBottomSheet.show(context, plan);
  }

  /// Shows the confirm dialog (matching the web wording) and calls the
  /// controller to pause / resume the plan, then shows a snackbar.
  Future<void> _confirmPauseResume({
    required int planId,
    required String planName,
    required bool isPaused,
  }) async {
    if (planId <= 0) return;
    final title = isPaused
        ? TranslationUtils.trArgs(
            'pmam_resume_plan_confirm', {'name': planName})
        : TranslationUtils.trArgs('pmam_pause_plan_confirm', {'name': planName});
    final body = isPaused
        ? TranslationUtils.tr('pmam_resume_plan_body')
        : TranslationUtils.tr('pmam_pause_plan_body');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          body,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.sp,
            color: AppColors.textGrey,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              TranslationUtils.tr('account_management_cancel'),
              style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isPaused ? AppColors.green : AppColors.warningText,
              foregroundColor: AppColors.onColoredBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPaused
                ? TranslationUtils.tr('my_plans_tab_resume')
                : TranslationUtils.tr('my_plans_tab_pause')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = isPaused
        ? await _ctrl.resumeManagerPlan(planId)
        : await _ctrl.pauseManagerPlan(planId);

    if (!mounted) return;
    Get.snackbar(
      result.ok
          ? TranslationUtils.tr('create_account_success')
          : TranslationUtils.tr('close_position_error'),
      result.message,
      backgroundColor: result.ok
          ? AppColors.green.withValues(alpha: 0.95)
          : AppColors.error.withValues(alpha: 0.95),
      colorText: AppColors.onColoredBackground,
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.all(12.w),
      borderRadius: 10,
      duration: const Duration(seconds: 3),
    );
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
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 28.h, width: 1, color: AppColors.border);
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
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
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
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.onColoredBackground : AppColors.textGrey,
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
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp, color: AppColors.textGrey),
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
