import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_dashboard_controller.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'master_plan_detail_screen.dart';

class MasterDashboardScreen extends StatelessWidget {
  final String masterCode;
  const MasterDashboardScreen({super.key, required this.masterCode});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CopyTradingMasterDashboardController(masterCode: masterCode));

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Master Dashboard',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: AppSvgBackButton(
          onPressed: () => AppSvgBackButton.popRoute(context),
        ),
        actions: [
          IconButton(
            onPressed: () => controller.refreshAll(showLoading: true),
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.stats.value == null && controller.plans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => controller.refreshAll(showLoading: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
            children: [
              _MasterProfileCard(masterCode: masterCode),
              SizedBox(height: 8.h),
              _StatsGrid(stats: controller.stats.value),
              SizedBox(height: 8.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 ElevatedButton.icon(
                   onPressed: () => _showCreatePlanSheet(context, controller),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.primary,
                     foregroundColor: AppColors.whiteColor,
                     // Override global theme's minimumSize (which is infinity width).
                     minimumSize: Size(double.maxFinite, 40.h),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(12.r),
                     ),
                   ),
                   icon: Icon(Icons.add, size: 18.r),
                   label: const Text(
                     'Create Plan',
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
                ],
              ),
              SizedBox(height: 12.h),
              if (controller.plans.isEmpty)
                _EmptyPlans(onCreate: () => _showCreatePlanSheet(context, controller))
              else
                ...controller.plans.map((p) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: _PlanTile(plan: p, controller: controller),
                    )),
              SizedBox(height: 24.h),
            ],
          ),
        );
      }),
    );
  }

  void _showCreatePlanSheet(BuildContext context, CopyTradingMasterDashboardController controller) {
    controller.loadEligibleAccountsForCreatePlan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePlanSheet(controller: controller),
    );
  }
}

class _MasterProfileCard extends StatelessWidget {
  final String masterCode;
  const _MasterProfileCard({required this.masterCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal:14.w,vertical: 8.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Master Profile', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(height: 10.h),
          Text('Your Master Code', style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.tradeBackgroundCenterColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  ),
                  child: Text(masterCode, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w400, color: AppColors.textPrimary)),
                ),
              ),
              SizedBox(width: 10.w),
              ElevatedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: masterCode));
                  Get.snackbar('Copied', 'Master code copied', snackPosition: SnackPosition.BOTTOM);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  elevation: 0,
                  // Override global theme's minimumSize (which is infinity width).
                  minimumSize: Size(60.w, 32.h),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final CopyTradingMasterDashboardStats? stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(title: 'TOTAL PLANS', value: s?.plansCount.toString() ?? '—')),
            SizedBox(width: 12.w),
            Expanded(child: _StatCard(title: 'ACTIVE COPIERS', value: s?.activeCopiersCount.toString() ?? '—')),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(child: _StatCard(title: 'AUM', value: s == null ? '—' : '\$${s.totalAum.toStringAsFixed(2)}')),
            SizedBox(width: 12.w),
            Expanded(
              child: _StatCard(
                title: 'COMMISSION EARNED',
                value: s == null ? '—' : '\$${s.commissionEarned.toStringAsFixed(2)}',
                highlight: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool highlight;
  const _StatCard({required this.title, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF22C55E).withOpacity(0.08) : AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: highlight ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 34.r,
            height: 34.r,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.insights, size: 18.r, color: AppColors.primary),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey, fontWeight: FontWeight.w400),maxLines: 1, overflow: TextOverflow.ellipsis,),
                SizedBox(height: 4.h),
                Text(value, style: TextStyle(fontSize: 14.sp, color: highlight ? const Color(0xFF16A34A) : AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyPlans({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          SizedBox(height: 12.h),
          Text('No plans yet', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(height: 6.h),
          Text(
            'Create your first plan to start accepting copiers.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 14.h),
          ElevatedButton(
            onPressed: onCreate,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.whiteColor),
            child: const Text('Create Plan'),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final CopyTradingMasterPlanItem plan;
  final CopyTradingMasterDashboardController controller;

  const _PlanTile({required this.plan, required this.controller});

  @override
  Widget build(BuildContext context) {
    final status = plan.status;
    final statusLower = status.toLowerCase();

    final statusColor = statusLower == 'approved'
        ? const Color(0xFF22C55E)
        : statusLower.contains('pending')
            ? const Color(0xFFF59E0B)
            : statusLower.contains('inactive')
                ? const Color(0xFF94A3B8)
                : const Color(0xFFEF4444);

    final canInactivate = statusLower == 'approved' && plan.activeCopiersCount == 0;
    final planSubtitle = (plan.commissionLabel.isNotEmpty ? plan.commissionLabel : plan.commissionType);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14.w),
          childrenPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 12.h),
          initiallyExpanded: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planName,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                         if (planSubtitle.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  planSubtitle,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w400, color: AppColors.textGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10.r)),
                    child: Text(status, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                ],
              ),
             
            ],
          ),
          trailing: Icon(Icons.expand_more, color: AppColors.textGrey, size: 20.r),
          children: [
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                              _metric(label: 'Copiers', value: plan.activeCopiersCount.toString()),
                      SizedBox(height: 8.h),
                      _metric(label: 'AUM', value: '\$${plan.totalCapital.toStringAsFixed(2)}'),
                      SizedBox(height: 8.h),
                      _metric(label: 'Min. capital', value: '\$${plan.minimumCapital.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
                SizedBox(
                  width: 112.w,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 34.h,
                        child: OutlinedButton(
                        onPressed: () {
                          Get.to(() => MasterPlanDetailScreen(planId: plan.id));
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          // Override global theme minimumSize (may be infinity width)
                          minimumSize: Size(0, 34.h),
                          side: BorderSide(color: AppColors.primary.withOpacity(0.6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        child: Text('Details', style: TextStyle(color: AppColors.primary, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        width: double.infinity,
                        height: 34.h,
                        child: ElevatedButton(
                        onPressed: canInactivate
                            ? () async {
                                final ok = await Get.dialog<bool>(
                                  AlertDialog(
                                    title: Text('Inactivate Plan'),
                                    content: Text('This will inactivate the plan. You can only inactivate when status is approved and active copiers = 0.'),
                                    actions: [
                                      TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Get.back(result: true), child: const Text('Inactivate')),
                                    ],
                                  ),
                                );
                                if (ok != true) return;

                                final res = await controller.inactivatePlan(planId: plan.id);
                                if (res.success) {
                                  CustomToastService.showSuccess(message: res.message ?? 'Plan inactivated', title: 'Success');
                                } else {
                                  CustomToastService.showError(message: res.message ?? controller.errorMessage.value, title: 'Error');
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          // Override global theme minimumSize (may be infinity width)
                          minimumSize: Size(0, 34.h),
                          backgroundColor: canInactivate ? AppColors.error : AppColors.textGrey.withOpacity(0.15),
                          foregroundColor: canInactivate ? AppColors.whiteColor : AppColors.textGrey,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Inactivate',
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                        ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}

Widget _metric({required String label, required String value}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
      SizedBox(height: 4.h),
      Text(value, style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
    ],
  );
}

class _CreatePlanSheet extends StatefulWidget {
  final CopyTradingMasterDashboardController controller;
  const _CreatePlanSheet({required this.controller});

  @override
  State<_CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends State<_CreatePlanSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedEligibleAccountIndex;
  final _nameCtrl = TextEditingController();
  String _commissionType = 'per_trade';
  final _commissionCtrl = TextEditingController();
  String? _subscriptionPeriod;
  final _noFeeDaysCtrl = TextEditingController(text: '0');
  final _minCapitalCtrl = TextEditingController();
  final _strategyCtrl = TextEditingController();
  final _riskCtrl = TextEditingController();
  final _tpPipsCtrl = TextEditingController();
  final _slPipsCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commissionCtrl.dispose();
    _noFeeDaysCtrl.dispose();
    _minCapitalCtrl.dispose();
    _strategyCtrl.dispose();
    _riskCtrl.dispose();
    _tpPipsCtrl.dispose();
    _slPipsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg =
        isDark ? AppColors.backgroundDarkTheme : AppColors.tradeBackgroundCenterColor;
    final cardBg = isDark ? AppColors.surfaceDarkTheme : AppColors.whiteColor;
    final borderColor =
        isDark ? AppColors.borderDark : Colors.grey.withOpacity(0.15);
    final mutedText = isDark ? AppColors.textGreyDark : AppColors.textGrey;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Create New Plan', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close)),
                ],
              ),
              Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: borderColor),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trading Account *', style: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6.h),
                      Obx(() {
                        if (widget.controller.eligibleAccountsLoading.value) {
                          return const LinearProgressIndicator(minHeight: 2);
                        }
                        final err = widget.controller.eligibleAccountsError.value;
                        if (err.isNotEmpty) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 6.h),
                            child: Text(
                              err,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return _EligibleAccountDropdown(
                          accounts: widget.controller.eligibleAccounts,
                          selectedIndex: _selectedEligibleAccountIndex,
                          onChanged: (i) =>
                              setState(() => _selectedEligibleAccountIndex = i),
                        );
                      }),
                      SizedBox(height: 14.h),
                      Text('Plan Name *', style: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6.h),
                      TextFormField(
                        controller: _nameCtrl,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter plan name' : null,
                        decoration:   InputDecoration(hintText: 'e.g. Conservative Growth Plan',hintStyle: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w400)),
                      ),
                      SizedBox(height: 14.h),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stack = constraints.maxWidth < 360;

                          final left = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Commission Type *',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _commissionType,
                                items:   [
                                  DropdownMenuItem(
                                    value: 'per_trade',
                                    child: Text(
                                      'Per Trade (% commission)',
                                      style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w400),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'subscription',
                                    child: Text(
                                      'Subscription (flat fee)',
                                      style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w400),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  _commissionType = v ?? 'per_trade';
                                  if (_commissionType != 'subscription') {
                                    _subscriptionPeriod = null;
                                    _commissionCtrl.clear();
                                  } else {
                                    _subscriptionPeriod ??= 'monthly';
                                  }
                                }),
                                decoration: const InputDecoration(),
                              ),
                            ],
                          );

                          final right = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _commissionType == 'per_trade'
                                    ? 'Commission (%) *'
                                    : 'Subscription Fee (USD) *',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              TextFormField(
                                controller: _commissionCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                decoration: InputDecoration(
                                  hintText:
                                      _commissionType == 'per_trade'
                                          ? 'e.g. 30'
                                          : 'e.g. 50',
                                  hintStyle: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w400),
                                ),
                              ),
                            ],
                          );

                          if (stack) {
                            return Column(
                              children: [
                                left,
                                SizedBox(height: 12.h),
                                right,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: left),
                              SizedBox(width: 12.w),
                              Expanded(child: right),
                            ],
                          );
                        },
                      ),
                      if (_commissionType == 'subscription') ...[
                        SizedBox(height: 14.h),
                        Text(
                          'Billing Period *',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _subscriptionPeriod ?? 'monthly',
                          items:   [
                            DropdownMenuItem(value: 'weekly', child: Text('Weekly',style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w400))),
                            DropdownMenuItem(value: 'monthly', child: Text('Monthly',style: TextStyle(fontSize: 12.sp, color:  AppColors.textPrimary, fontWeight: FontWeight.w400))),
                            DropdownMenuItem(value: 'quarterly', child: Text('Quarterly',style: TextStyle(fontSize: 12.sp, color:  AppColors.textPrimary, fontWeight: FontWeight.w400))),
                          ],
                          onChanged: (v) => setState(() => _subscriptionPeriod = v),
                          decoration: const InputDecoration(),
                        ),
                      ],
                      SizedBox(height: 14.h),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stack = constraints.maxWidth < 360;

                          final left = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No-Fee Grace Period (days)',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              TextFormField(
                                controller: _noFeeDaysCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(),
                              ),
                            ],
                          );

                          final right = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Minimum Capital (USD) *',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              TextFormField(
                                controller: _minCapitalCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                decoration:
                                      InputDecoration(hintText: 'e.g. 100',hintStyle: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w400)),
                              ),
                            ],
                          );

                          if (stack) {
                            return Column(
                              children: [
                                left,
                                SizedBox(height: 12.h),
                                right,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: left),
                              SizedBox(width: 12.w),
                              Expanded(child: right),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 14.h),
                      Text('Strategy Description', style: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6.h),
                      TextFormField(
                        controller: _strategyCtrl,
                        maxLines: 3,
                        decoration:   InputDecoration(
                          hintText: 'Describe your trading strategy, risk management approach, and what makes your trading unique.',
                          hintStyle: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w400),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text('Risk Information', style: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6.h),
                      TextFormField(
                        controller: _riskCtrl,
                        maxLines: 3,
                        decoration:   InputDecoration(
                          hintText: 'Describe the risk level and potential drawdowns of your strategy.',
                          hintStyle: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w400),
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.backgroundDarkTheme : AppColors.tradeBackgroundCenterColor).withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: isDark ? AppColors.borderDark : Colors.grey.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PER-TRADE TP / SL (PIPS)', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            SizedBox(height: 6.h),
                            Text(
                              'Set fixed take profit and stop loss for every copied trade. Leave empty or 0 to disable.',
                              style: TextStyle(fontSize: 11.sp, color: mutedText, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Take Profit (Pips)', style: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 6.h),
                                      TextFormField(
                                        controller: _tpPipsCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(hintText: 'e.g. 50'),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Stop Loss (Pips)', style: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 6.h),
                                      TextFormField(
                                        controller: _slPipsCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(hintText: 'e.g. 30'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Obx(() {
                        final loading = widget.controller.isLoading.value;
                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: loading ? null : () => Get.back(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: loading
                                    ? null
                                    : () async {
                                        if (_selectedEligibleAccountIndex == null) {
                                          Get.snackbar('Required', 'Select trading account', snackPosition: SnackPosition.BOTTOM);
                                          return;
                                        }
                                        final formState = _formKey.currentState;
                                        if (formState == null || !formState.validate()) {
                                          return;
                                        }

                                        final idx = _selectedEligibleAccountIndex!;
                                        if (idx < 0 || idx >= widget.controller.eligibleAccounts.length) {
                                          Get.snackbar('Invalid', 'Select a valid trading account', snackPosition: SnackPosition.BOTTOM);
                                          return;
                                        }
                                        final acc = widget.controller.eligibleAccounts[idx];
                                        final commissionValue = num.tryParse(_commissionCtrl.text.trim());
                                        final minCap = num.tryParse(_minCapitalCtrl.text.trim());
                                        if (commissionValue == null || minCap == null) {
                                          Get.snackbar('Invalid', 'Enter valid numeric values', snackPosition: SnackPosition.BOTTOM);
                                          return;
                                        }

                                        final body = <String, dynamic>{
                                          'trading_account_id': acc.id,
                                          'name': _nameCtrl.text.trim(),
                                          'commission_type': _commissionType,
                                          'commission_value': commissionValue,
                                          'min_capital': minCap,
                                          'no_fee_days': int.tryParse(_noFeeDaysCtrl.text.trim()) ?? 0,
                                          'strategy_description': _strategyCtrl.text.trim(),
                                          'risk_info': _riskCtrl.text.trim(),
                                        };
                                        if (_commissionType == 'subscription') {
                                          body['subscription_fee'] = commissionValue;
                                          body['subscription_period'] =
                                              (_subscriptionPeriod ?? 'monthly');
                                        }
                                        final tp = num.tryParse(_tpPipsCtrl.text.trim());
                                        final sl = num.tryParse(_slPipsCtrl.text.trim());
                                        if (tp != null && tp > 0) body['take_profit_pips'] = tp;
                                        if (sl != null && sl > 0) body['stop_loss_pips'] = sl;

                                        AppLogger.debug('Create plan payload: $body');
                                        final res = await widget.controller.createPlan(body);
                                        if (res.success) {
                                          Get.back();
                                          Get.snackbar('Created', res.message ?? 'Plan created', snackPosition: SnackPosition.BOTTOM);
                                        } else {
                                          Get.snackbar('Failed', res.message ?? widget.controller.errorMessage.value, snackPosition: SnackPosition.BOTTOM);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                child: loading
                                    ? SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Create Plan'),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EligibleAccountDropdown extends StatelessWidget {
  final List<CopyTradingEligibleAccount> accounts;
  final int? selectedIndex;
  final ValueChanged<int?> onChanged;

  const _EligibleAccountDropdown({
    required this.accounts,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText = isDark ? AppColors.textGreyDark : AppColors.textGrey;
    return DropdownButtonFormField<int>(
      value: selectedIndex ?? -1,
      items: [
          DropdownMenuItem(value: -1, child: Text('-- Select Account --',style: TextStyle(fontSize: 12.sp, color: mutedText, fontWeight: FontWeight.w400),)),
        ...List.generate(accounts.length, (i) {
          final a = accounts[i];
          final label = '${a.metaAccountNumber} (\$${a.balance}) - ${a.lpProviderName}';

          return DropdownMenuItem(value: i, child: Text(label,style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w400),));
        }),
      ],
      onChanged: (v) {
        if (v == -1) {
          onChanged(null);
        } else {
          onChanged(v);
        }
      },
      decoration: const InputDecoration(),
    );
  }
}