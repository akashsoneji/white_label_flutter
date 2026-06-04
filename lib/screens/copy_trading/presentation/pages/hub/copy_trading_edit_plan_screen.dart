import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_dashboard_controller.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/app_select_field.dart';
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
        title: Text('Edit Plan', style: AppTextStyles.heading),
        leading: AppBackButton(
          onPressed: () => Get.back(closeOverlays: true),
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
                      'Trading Account',
                      style: TextStyle(
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
                              style: TextStyle(
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
                      'Trading account cannot be changed after plan creation.',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: _mutedText,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Plan Name
                    Text(
                      'Plan Name *',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: _mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _nameCtrl,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter plan name' : null,
                      decoration: InputDecoration(
                        hintText: 'e.g. Conservative Growth Plan',
                        hintStyle: TextStyle(
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
                        'Billing Period *',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      AppSelectField<String>(
                        value: _subscriptionPeriod ?? 'monthly',
                        hint: 'Select billing period',
                        sheetTitle: 'Billing Period',
                        options: const [
                          AppSelectOption(value: 'weekly', title: 'Weekly'),
                          AppSelectOption(value: 'monthly', title: 'Monthly'),
                          AppSelectOption(value: 'quarterly', title: 'Quarterly'),
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
                      'Strategy Description',
                      style: TextStyle(
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
                        hintText: 'Describe your trading strategy and risk approach.',
                        hintStyle: TextStyle(
                          fontSize: 12.sp,
                          color: _mutedText,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Risk information
                    Text(
                      'Risk Information',
                      style: TextStyle(
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
                        hintText: 'Describe potential drawdowns and risk level.',
                        hintStyle: TextStyle(
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
              'Commission Type *',
              style: TextStyle(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            AppSelectField<String>(
              value: _commissionType,
              hint: 'Select commission type',
              sheetTitle: 'Commission Type',
              options: const [
                AppSelectOption(
                  value: 'per_trade',
                  title: 'Per Trade (% commission)',
                ),
                AppSelectOption(
                  value: 'subscription',
                  title: 'Subscription (flat fee)',
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
                  ? 'Commission (%) *'
                  : 'Subscription Fee (USD) *',
              style: TextStyle(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _commissionCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: InputDecoration(
                hintText: _commissionType == 'per_trade' ? 'e.g. 30' : 'e.g. 50',
                hintStyle: TextStyle(fontSize: 12.sp, color: _mutedText),
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
              'No-Fee Grace Period (days)',
              style: TextStyle(
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
              'Copiers won\'t pay commission on trades within this grace period.',
              style: TextStyle(
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
              'Min. Capital (USD) *',
              style: TextStyle(
                fontSize: 12.sp,
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _minCapitalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: InputDecoration(
                hintText: 'e.g. 100',
                hintStyle: TextStyle(fontSize: 12.sp, color: _mutedText),
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
              'Copy ratio',
              style: TextStyle(
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
              'Default 1 — copier volume scales from this ratio.',
              style: TextStyle(
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
              'Max copiers',
              style: TextStyle(
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
                hintText: 'Unlimited if empty',
                hintStyle: TextStyle(fontSize: 12.sp, color: _mutedText),
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
          'Cancel',
          style: TextStyle(
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
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.whiteColor,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: loading
            ? CommonLoadingWidget(size: 22, color: AppColors.whiteColor)
            : Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.whiteColor,
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
      CustomToastService.showError(
        title: 'Invalid',
        message: 'Enter valid numeric values',
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
        title: 'Success',
        message: res.message ?? 'Plan updated successfully',
      );
    } else {
      CustomToastService.showError(
        title: 'Failed',
        message: res.message ?? _controller.errorMessage.value,
      );
    }
  }
}
