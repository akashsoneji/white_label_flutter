import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/responsive_layout.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/pmam/pmam_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_select_field.dart';
import 'package:crm_app/models/pmam_model.dart';
import 'package:crm_app/services/language_service.dart';

class PmamManagerDetailScreen extends StatefulWidget {
  const PmamManagerDetailScreen({super.key});

  @override
  State<PmamManagerDetailScreen> createState() =>
      _PmamManagerDetailScreenState();
}

class _PmamManagerDetailScreenState extends State<PmamManagerDetailScreen> {
  late final PmamController _ctrl;
  late PmamManager _manager;
  PmamPlan? _selectedPlan;

  // For Invest Now sheet
  Map<String, dynamic>? _selectedAccount;

  @override
  void initState() {
    super.initState();
    if (Get.arguments is PmamManager) {
      _manager = Get.arguments as PmamManager;
      if (_manager.plans.isNotEmpty) {
        _selectedPlan = _manager.plans.first;
      }
    } else {
      Get.back();
      return;
    }

    if (Get.isRegistered<PmamController>()) {
      _ctrl = Get.find<PmamController>();
    } else {
      _ctrl = Get.put(PmamController());
    }

    if (_selectedPlan != null) {
      _ctrl.loadEligibleAccounts(_selectedPlan!.id);
    }
  }

  String _fmt(double val) {
    return '\$${val.toStringAsFixed(2)}';
  }

  void _showInvestSheet() {
    if (_selectedPlan == null) return;
    _selectedAccount = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setSheetState) {
              final double balance =
                  double.tryParse(
                    _selectedAccount?['available_balance']?.toString() ?? '0',
                  ) ??
                  0;
              final double minInvest = _selectedPlan?.minimumInvestment ?? 0;
              final bool isBalanceEnough = balance >= minInvest;
              final bool canInvest =
                  isBalanceEnough && _selectedAccount != null;

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22.r),
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 20.w,
                  right: 20.w,
                  top: 20.h,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 30.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Text(
                      TranslationUtils.tr('pmam_manager_detail_screen_invest_now'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Plan Selection Dropdown
                    if (_manager.plans.length > 1) ...[
                      Text(
                        TranslationUtils.tr('pmam_fund_manager_view_select_plan'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      AppSelectField<PmamPlan>(
                        value: _selectedPlan,
                        hint: TranslationUtils.tr('pmam_select_a_plan'),
                        sheetTitle: TranslationUtils.tr(
                            'pmam_fund_manager_view_select_plan'),
                        valueEquals: (a, b) => a.id == b.id,
                        options:
                            _manager.plans
                                .map(
                                  (p) => AppSelectOption<PmamPlan>(
                                    value: p,
                                    title: p.planName,
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() {
                              _selectedPlan = val;
                              _selectedAccount = null;
                              _ctrl.loadEligibleAccounts(val.id);
                            });
                            setState(() {});
                          }
                        },
                      ),
                      SizedBox(height: 16.h),
                    ],

                    Text(
                      TranslationUtils.tr(
                          'pmam_manager_detail_screen_select_trading_account'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Obx(() {
                      if (_ctrl.isLoading.value) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(10.h),
                            child: CommonLoadingWidget(
                              size: 24,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }
                      return AppSelectField<Map<String, dynamic>>(
                        value: _selectedAccount,
                        hint: TranslationUtils.tr('pmam_choose_an_account'),
                        sheetTitle: TranslationUtils.tr(
                            'pmam_manager_detail_screen_select_trading_account'),
                        valueEquals: (a, b) => a['id'] == b['id'],
                        options:
                            _ctrl.eligibleAccounts.map((acc) {
                              final accNo =
                                  acc['meta_account_number']?.toString() ?? '-';
                              final bal =
                                  double.tryParse(
                                    acc['balance']?.toString() ?? '0',
                                  ) ??
                                  0;
                              final availBal =
                                  double.tryParse(
                                    acc['available_balance']?.toString() ?? '0',
                                  ) ??
                                  0;
                              return AppSelectOption<Map<String, dynamic>>(
                                value: acc,
                                title:
                                    '$accNo — Balance: \$${bal.toStringAsFixed(2)}',
                                subtitle:
                                    'Available: \$${availBal.toStringAsFixed(2)}',
                              );
                            }).toList(),
                        onChanged: (val) {
                          setSheetState(() => _selectedAccount = val);
                        },
                      );
                    }),
                    SizedBox(height: 20.h),

                    // Info Card: Min Invest vs Balance
                    if (_selectedPlan != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  TranslationUtils.tr(
                                      'pmam_min_investment_colon'),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12.sp,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                                Text(
                                  _fmt(_selectedPlan!.minimumInvestment),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedAccount != null) ...[
                              SizedBox(height: 6.h),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    TranslationUtils.tr(
                                        'pmam_your_balance_colon'),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 12.sp,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                  Text(
                                    _fmt(balance),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isBalanceEnough
                                              ? AppColors.green
                                              : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                    if (_selectedAccount != null && !isBalanceEnough)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          TranslationUtils.tr(
                              'pmam_fund_manager_view_insufficient_balance_for_this_plan'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    SizedBox(height: 24.h),

                    // Confirm Invest Button
                    SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        height: 44.h,
                        child: ElevatedButton(
                          onPressed:
                              canInvest
                                  ? () {
                                    //                                     print('''
                                    //  _selectedAccount!['id'],${ _selectedAccount!['id']},

                                    //                                       _selectedPlan!.id,${ _selectedPlan!.id},
                                    //                                       invest_amount(balance),$balance,''');
                                    Navigator.pop(ctx);
                                    _ctrl.joinPlan(
                                      _selectedAccount!['id'],
                                      _selectedPlan!.id,
                                      balance, // invest full available balance
                                    );
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            disabledBackgroundColor: AppColors.textGrey
                                .withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            TranslationUtils.tr(
                                'pmam_manager_detail_screen_confirm_invest'),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.onColoredBackground,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // SizedBox(height: kBottomNavigationBarHeight),
                  ],
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _manager.managerName ??
        TranslationUtils.tr('pmam_fund_manager_view_fund_manager');
    final initials =
        name
            .split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join();

    final hasActivePlan = _manager.plans.isNotEmpty && _selectedPlan != null;
    final gain = _manager.profitPercentage;
    final aum = _fmt(_manager.totalAum);
    final commission =
        hasActivePlan ? '${_selectedPlan!.commissionPercentage}%' : 'N/A';
    final investors = '${_manager.totalInvestors}';
    final minInvest =
        hasActivePlan ? _fmt(_selectedPlan!.minimumInvestment) : 'N/A';

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
        title: Text(
            TranslationUtils.tr('pmam_manager_detail_screen_manager_detail'),
            style: AppTextStyles.heading),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          children: [
            // Profile header card
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32.r,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      initials,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    name,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      TranslationUtils.tr('pmam_fund_manager_caps'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 10.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),

                  if (hasActivePlan) ...[
                    // Invest Now button
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed: _showInvestSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: AppColors.onColoredBackground,
                              size: 18.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              TranslationUtils.tr('pmam_invest_now_caps'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.onColoredBackground,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${TranslationUtils.tr('pmam_manager_detail_screen_min_investment')}: $minInvest',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.warning,
                            size: 20.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  TranslationUtils.tr(
                                      'pmam_manager_detail_screen_no_active_plan_yet'),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 14.h),

            // Use the selected plan for displaying detailed stats if needed,
            // but usually aum/investors are manager-level in PMAM context.
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6.h,
              crossAxisSpacing: 6.w,
              childAspectRatio: ResponsiveGrid.aspectRatio(2.5),
              children: [
                _DetailStatCard(
                  label: TranslationUtils.tr('pmam_gain_caps'),
                  value: '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%',
                  icon: Icons.trending_up_rounded,
                  color: gain >= 0 ? AppColors.green : AppColors.error,
                ),
                _DetailStatCard(
                  label: TranslationUtils.tr('pmam_total_aum_caps'),
                  value: aum,
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _DetailStatCard(
                  label: TranslationUtils.tr('pmam_investors_caps'),
                  value: investors,
                  icon: Icons.people_rounded,
                ),
                _DetailStatCard(
                  label: TranslationUtils.tr('pmam_commission_caps'),
                  value: commission,
                  icon: Icons.percent_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
            SizedBox(height: 4.h),

            // Plan Details card
            if (_selectedPlan != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.border.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TranslationUtils.tr(
                              'master_plan_detail_screen_plan_details'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_manager.plans.length > 1)
                          InkWell(
                            onTap:
                                _showInvestSheet, // Or a dedicated plan picker
                            child: Text(
                              TranslationUtils.tr(
                                  'pmam_manager_detail_screen_change_plan'),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.sp,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    _DetailRow(TranslationUtils.tr('pmam_create_plan_plan_name'),
                        _selectedPlan!.planName),
                    _DetailRow(TranslationUtils.tr('pmam_manager_code'),
                        _manager.managerCode),
                    _DetailRow(
                        TranslationUtils.tr('general_commission'), commission),
                    _DetailRow(
                        TranslationUtils.tr(
                            'pmam_manager_detail_screen_min_investment'),
                        minInvest),

                    if (_selectedPlan!.strategyDescription != null &&
                        _selectedPlan!.strategyDescription!.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      Text(
                        TranslationUtils.tr('pmam_strategy'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _selectedPlan!.strategyDescription!,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.textGrey,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                    if (_selectedPlan!.riskInformation != null &&
                        _selectedPlan!.riskInformation!.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      Text(
                        TranslationUtils.tr(
                            'copy_trading_create_plan_risk_information'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _selectedPlan!.riskInformation!,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.textGrey,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ],
                ),
              ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _DetailStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Container(
      width: 100.w,
      padding: EdgeInsets.all(12.w),
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
        border: Border.all(color: c.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c, size: 18.sp),
              SizedBox(width: 6.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 9.sp,
                        color: AppColors.textGrey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
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
