import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_dashboard_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'package:crm_app/widgets/app_select_field.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/utils/currency_format.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class CopyTradingCreatePlanScreen extends StatefulWidget {
  final CopyTradingMasterDashboardController controller;

  const CopyTradingCreatePlanScreen({super.key, required this.controller});

  @override
  State<CopyTradingCreatePlanScreen> createState() =>
      _CopyTradingCreatePlanScreenState();
}

class _CopyTradingCreatePlanScreenState
    extends State<CopyTradingCreatePlanScreen> {
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
  final _copyRatioCtrl = TextEditingController(text: '1');
  final _maxCopiersCtrl = TextEditingController();
  final _tpPipsCtrl = TextEditingController();
  final _slPipsCtrl = TextEditingController();

  CopyTradingMasterDashboardController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.loadEligibleAccountsForCreatePlan();
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
    _tpPipsCtrl.dispose();
    _slPipsCtrl.dispose();
    super.dispose();
  }

  Color get _mutedText => AppColors.textGrey;

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
          TranslationUtils.tr('copy_trading_create_plan_create_new_plan'),
          style: AppTextStyles.heading,
        ),
        leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(16.w, 12.h, 16.w, 24.h),
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
                      Text(
                        TranslationUtils.tr('copy_trading_create_plan_trading_account'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: _mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Obx(() {
                        if (_controller.eligibleAccountsLoading.value) {
                          return const LinearProgressIndicator(minHeight: 2);
                        }
                        final err = _controller.eligibleAccountsError.value;
                        if (err.isNotEmpty) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 6.h),
                            child: Text(
                              err,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 12.sp,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        final accounts = _controller.eligibleAccounts;
                        return AppSelectField<int>(
                          value: _selectedEligibleAccountIndex,
                          hint: TranslationUtils.tr('copy_trading_create_plan_select_account_hint'),
                          sheetTitle: TranslationUtils.tr('copy_trading_edit_plan_trading_account'),
                          enabled: accounts.isNotEmpty,
                          options: List.generate(accounts.length, (i) {
                            final a = accounts[i];
                            MT5Account? resolved;
                            if (Get.isRegistered<AccountController>()) {
                              final list = Get.find<AccountController>().mt5Accounts;
                              for (final acc in list) {
                                if (acc.metaAccountNumber == a.metaAccountNumber) {
                                  resolved = acc;
                                  break;
                                }
                              }
                            }
                            final balanceNum =
                                double.tryParse(a.balance.toString()) ?? 0;
                            return AppSelectOption<int>(
                              value: i,
                              title:
                                  '${a.metaAccountNumber} (${CurrencyFormat.amount(balanceNum, resolved)}) - ${a.lpProviderName}',
                              subtitle: '${a.tradingServer} · ${a.accountType}',
                            );
                          }),
                          onChanged:
                              (i) => setState(
                                () => _selectedEligibleAccountIndex = i,
                              ),
                        );
                      }),
                      SizedBox(height: 4.h),
                      Text(
                        TranslationUtils.tr('copy_trading_create_plan_this_is_the_master_trading_account'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 10.sp,
                          color: _mutedText,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 14.h),
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
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
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
                          onChanged:
                              (v) => setState(
                                () => _subscriptionPeriod = v ?? 'monthly',
                              ),
                        ),
                      ],
                      SizedBox(height: 14.h),
                      _buildGraceAndCapitalRow(),
                      SizedBox(height: 14.h),
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
              onChanged:
                  (v) => setState(() {
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator:
                  (v) => (v == null || v.trim().isEmpty)
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator:
                  (v) => (v == null || v.trim().isEmpty)
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
          Expanded(child: _buildCreatePlanButton(loading: loading)),
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

  Widget _buildCreatePlanButton({required bool loading}) {
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
        child:
            loading
                ? CommonLoadingWidget(size: 22, color: AppColors.onColoredBackground)
                : Text(
                  TranslationUtils.tr('my_plans_tab_create_plan'),
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
    if (_selectedEligibleAccountIndex == null) {
      Get.snackbar(
        TranslationUtils.tr('ibm_required'),
        TranslationUtils.tr('pmam_manager_detail_screen_select_trading_account'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final idx = _selectedEligibleAccountIndex!;
    if (idx < 0 || idx >= _controller.eligibleAccounts.length) {
      Get.snackbar(
        TranslationUtils.tr('copy_trading_plan_invalid'),
        TranslationUtils.tr('copy_trading_plan_select_a_valid_trading_account'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final acc = _controller.eligibleAccounts[idx];
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
      'trading_account_id': acc.id,
      'plan_name': _nameCtrl.text.trim(),
      'commission_type': _commissionType,
      'subscription_period': _commissionType == 'subscription' ? (_subscriptionPeriod ?? 'monthly') : null,
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

    AppLogger.debug('Create plan payload: $body');
    final res = await _controller.createPlan(body);
    if (res.success) {
      Get.back();
      Get.snackbar(
        TranslationUtils.tr('ticket_created'),
        res.message ?? TranslationUtils.tr('master_plan_detail_screen_plan_created'),
        snackPosition: SnackPosition.BOTTOM,
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
