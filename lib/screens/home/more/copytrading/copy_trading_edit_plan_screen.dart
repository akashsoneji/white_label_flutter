import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_dashboard_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:crm_app/widgets/app_select_field.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class CopyTradingEditPlanScreen extends StatefulWidget {
  final CopyTradingMasterPlanItem plan;
  final CopyTradingMasterDashboardController controller;

  const CopyTradingEditPlanScreen({
    super.key,
    required this.plan,
    required this.controller,
  });

  @override
  State<CopyTradingEditPlanScreen> createState() =>
      _CopyTradingEditPlanScreenState();
}

class _CopyTradingEditPlanScreenState extends State<CopyTradingEditPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _nameCtrl;
  late String _commissionType;
  late final TextEditingController _commissionCtrl;
  String? _subscriptionPeriod;
  late final TextEditingController _noFeeDaysCtrl;
  late final TextEditingController _minCapitalCtrl;
  late final TextEditingController _strategyCtrl;
  late final TextEditingController _riskCtrl;
  late final TextEditingController _copyRatioCtrl;
  late final TextEditingController _maxCopiersCtrl;

  CopyTradingMasterDashboardController get _controller => widget.controller;
  Color get _mutedText => AppColors.textGrey;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _nameCtrl = TextEditingController(text: p.planName);
    _commissionType = p.commissionType;
    
    final commissionVal = p.commissionType == 'subscription' ? p.subscriptionFee : p.commissionPercentage;
    _commissionCtrl = TextEditingController(
      text: commissionVal == commissionVal.toInt() ? commissionVal.toInt().toString() : commissionVal.toString(),
    );
    
    _noFeeDaysCtrl = TextEditingController(text: p.noFeeDays.toString());
    
    _minCapitalCtrl = TextEditingController(
      text: p.minimumCapital == p.minimumCapital.toInt()
          ? p.minimumCapital.toInt().toString()
          : p.minimumCapital.toString(),
    );
    
    _copyRatioCtrl = TextEditingController(
      text: p.copyRatio == p.copyRatio.toInt() ? p.copyRatio.toInt().toString() : p.copyRatio.toString(),
    );
    
    _maxCopiersCtrl = TextEditingController(text: p.maxCopiers?.toString() ?? '');
    _strategyCtrl = TextEditingController(text: p.strategyDescription);
    _riskCtrl = TextEditingController(text: p.riskInformation);
    
    _subscriptionPeriod = 'monthly';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commissionCtrl.dispose();
    _noFeeDaysCtrl.dispose();
    _minCapitalCtrl.dispose();
    _strategyCtrl.dispose();
    _riskCtrl.dispose();
    _copyRatioCtrl.dispose();
    _maxCopiersCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('my_plans_tab_edit_plan'),
          style: AppTextStyles.heading,
        ),
        leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.15),
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trading Account (Read-only)
                    Text(
                      TranslationUtils.tr('copy_trading_edit_plan_trading_account'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: _mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.tradeBackgroundCenterColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 16.r, color: _mutedText),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              '${widget.plan.tradingAccountNumber} (${widget.plan.lpProviderName})',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      TranslationUtils.tr('copy_trading_edit_plan_trading_account_cannot_be_changed_after'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 10.sp,
                        color: _mutedText,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Plan Name
                    Text(
                      TranslationUtils.tr('copy_trading_create_plan_plan_name'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: _mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _nameCtrl,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? TranslationUtils.tr('copy_trading_create_plan_enter_plan_name')
                          : null,
                      decoration: InputDecoration(
                        hintText: TranslationUtils.tr('copy_trading_create_plan_conservative_growth_plan'),
                        hintStyle: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: _mutedText,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Commission Type & Value Section
                    _buildCommissionSection(),
                    if (_commissionType == 'subscription') ...[
                      SizedBox(height: 14.h),
                      Text(
                        TranslationUtils.tr('copy_trading_create_plan_billing_period'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: _mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      AppSelectField<String>(
                        value: _subscriptionPeriod ?? 'monthly',
                        hint: TranslationUtils.tr('copy_trading_plan_select_billing_period'),
                        sheetTitle: TranslationUtils.tr('copy_trading_plan_billing_period_title'),
                        options: [
                          AppSelectOption(
                            value: 'weekly',
                            title: TranslationUtils.tr('dc_range_weekly'),
                          ),
                          AppSelectOption(
                            value: 'monthly',
                            title: TranslationUtils.tr('dc_range_monthly'),
                          ),
                          AppSelectOption(
                            value: 'quarterly',
                            title: TranslationUtils.tr('copy_trading_plan_quarterly'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _subscriptionPeriod = v ?? 'monthly'),
                      ),
                    ],
                    SizedBox(height: 14.h),

                    // Grace period & Min Capital Row
                    _buildGraceAndCapitalRow(),
                    SizedBox(height: 14.h),

                    // Strategy description
                    Text(
                      TranslationUtils.tr('master_plan_detail_screen_strategy_description'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: _mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _strategyCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: TranslationUtils.tr('copy_trading_create_plan_describe_your_trading_strategy_and_risk'),
                        hintStyle: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: _mutedText,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Risk information
                    Text(
                      TranslationUtils.tr('copy_trading_create_plan_risk_information'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: _mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _riskCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: TranslationUtils.tr('copy_trading_create_plan_describe_potential_drawdowns_and_risk_level'),
                        hintStyle: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: _mutedText,
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Copy ratio & Max copiers row
                    _buildRatioAndCopiersRow(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360;

        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr('copy_trading_create_plan_commission_type'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            AppSelectField<String>(
              value: _commissionType,
              hint: TranslationUtils.tr('copy_trading_plan_select_commission_type'),
              sheetTitle: TranslationUtils.tr('copy_trading_plan_commission_type_title'),
              options: [
                AppSelectOption(
                  value: 'per_trade',
                  title: TranslationUtils.tr('copy_trading_create_plan_per_trade_commission'),
                ),
                AppSelectOption(
                  value: 'subscription',
                  title: TranslationUtils.tr('copy_trading_create_plan_subscription_flat_fee'),
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
            ),
          ],
        );

        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _commissionType == 'per_trade'
                  ? TranslationUtils.tr('copy_trading_plan_commission_percent_required')
                  : TranslationUtils.tr('copy_trading_plan_subscription_fee_usd_required'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _commissionCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? TranslationUtils.tr('ibm_required')
                  : null,
              decoration: InputDecoration(
                hintText: _commissionType == 'per_trade'
                    ? TranslationUtils.tr('copy_trading_plan_eg_30')
                    : TranslationUtils.tr('copy_trading_plan_eg_50'),
                hintStyle: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: _mutedText),
              ),
            ),
          ],
        );

        if (stack) {
          return Column(children: [left, SizedBox(height: 12.h), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            SizedBox(width: 12.w),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildGraceAndCapitalRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360;

        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr('copy_trading_create_plan_no_fee_grace_period_days'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _noFeeDaysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(),
            ),
            SizedBox(height: 4.h),
            Text(
              TranslationUtils.tr('copy_trading_create_plan_copiers_won_pay_commission_on_trades'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.sp,
                color: _mutedText,
                height: 1.3,
              ),
            ),
          ],
        );

        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr('copy_trading_create_plan_min_capital_usd'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _minCapitalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? TranslationUtils.tr('ibm_required')
                  : null,
              decoration: InputDecoration(
                hintText: TranslationUtils.tr('copy_trading_create_plan_100'),
                hintStyle: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: _mutedText),
              ),
            ),
          ],
        );

        if (stack) {
          return Column(children: [left, SizedBox(height: 12.h), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            SizedBox(width: 12.w),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildRatioAndCopiersRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360;

        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr('copy_trading_create_plan_copy_ratio'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _copyRatioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '1',
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              TranslationUtils.tr('copy_trading_create_plan_default_copier_volume_scales_from_this'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.sp,
                color: _mutedText,
              ),
            ),
          ],
        );

        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr('copy_trading_create_plan_max_copiers'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _maxCopiersCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: TranslationUtils.tr('copy_trading_create_plan_unlimited_if_empty'),
                hintStyle: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: _mutedText),
              ),
            ),
          ],
        );

        if (stack) {
          return Column(children: [left, SizedBox(height: 12.h), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: 12.w),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Obx(() {
      final loading = _controller.isLoading.value;
      return Row(
        children: [
          Expanded(child: _buildCancelButton(loading: loading)),
          SizedBox(width: 12.w),
          Expanded(child: _buildSaveButton(loading: loading)),
        ],
      );
    });
  }

  Widget _buildCancelButton({required bool loading}) {
    return SizedBox(
      height: 46.h,
      child: OutlinedButton(
        onPressed: loading ? null : () => Get.back(),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          TranslationUtils.tr('general_cancel'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton({required bool loading}) {
    return SizedBox(
      height: 46.h,
      child: ElevatedButton(
        onPressed: loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.onColoredBackground,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: loading
            ? CommonLoadingWidget(size: 22, color: AppColors.onColoredBackground)
            : Text(
                TranslationUtils.tr('edit_plan_bottom_sheet_save_changes'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onColoredBackground,
                ),
              ),
      ),
    );
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final commissionValue = num.tryParse(_commissionCtrl.text.trim());
    final minCap = num.tryParse(_minCapitalCtrl.text.trim());
    if (commissionValue == null || minCap == null) {
      Get.snackbar(
        TranslationUtils.tr('copy_trading_plan_invalid'),
        TranslationUtils.tr('copy_trading_plan_enter_valid_numeric_values'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final body = <String, dynamic>{
      'plan_name': _nameCtrl.text.trim(),
      'commission_type': _commissionType,
      'min_capital': minCap,
      'no_fee_days': int.tryParse(_noFeeDaysCtrl.text.trim()) ?? 0,
      'commission_value': commissionValue,
      'copy_ratio': num.tryParse(_copyRatioCtrl.text.trim()) ?? 1,
      'strategy_description': _strategyCtrl.text.trim(),
      'risk_information': _riskCtrl.text.trim(),
    };

    final maxCopiersText = _maxCopiersCtrl.text.trim();
    if (maxCopiersText.isNotEmpty) {
      body['max_copiers'] = int.tryParse(maxCopiersText);
    } else {
      body['max_copiers'] = null;
    }

    if (_commissionType == 'subscription') {
      body['subscription_fee'] = commissionValue;
    }

    AppLogger.debug('Update plan payload: $body');
    final res = await _controller.updatePlan(
      planId: widget.plan.id,
      body: body,
    );
    if (res.success) {
      Get.back();
      CustomToastService.showSuccess(
        title: TranslationUtils.tr('general_success'),
        message: res.message ?? TranslationUtils.tr('ibm_plan_updated_successfully'),
      );
    } else {
      Get.snackbar(
        TranslationUtils.tr('transaction_history_failed'),
        res.message ?? _controller.errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
