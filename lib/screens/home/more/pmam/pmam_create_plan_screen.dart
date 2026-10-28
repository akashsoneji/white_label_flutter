import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/pmam/pmam_controller.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_select_field.dart';
import 'package:crm_app/services/language_service.dart';

class PmamCreatePlanScreen extends StatefulWidget {
  const PmamCreatePlanScreen({super.key});

  @override
  State<PmamCreatePlanScreen> createState() => _PmamCreatePlanScreenState();
}

class _PmamCreatePlanScreenState extends State<PmamCreatePlanScreen> {
  late final PmamController _ctrl;
  final _formKey = GlobalKey<FormState>();

  final _planNameCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  final _minInvestmentCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _riskInfoCtrl = TextEditingController();

  Map<String, dynamic>? _selectedAccount;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<PmamController>()) {
      _ctrl = Get.find<PmamController>();
    } else {
      _ctrl = Get.put(PmamController());
    }
    // Load eligible accounts for dropdown
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    // Always refetch: [eligibleAccounts] is shared with the investor join
    // sheet, which fills it from the investor endpoint.
    await _ctrl.loadManagerEligibleAccounts();
  }

  @override
  void dispose() {
    _planNameCtrl.dispose();
    _commissionCtrl.dispose();
    _minInvestmentCtrl.dispose();
    _descriptionCtrl.dispose();
    _riskInfoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) {
      Get.snackbar(
        TranslationUtils.tr('ibm_required'),
        TranslationUtils.tr('pmam_create_plan_please_select_trading_account'),
        backgroundColor: AppColors.error,
        colorText: AppColors.onColoredBackground,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    final body = {
      'trading_account_id': _selectedAccount!['id'],
      'plan_name': _planNameCtrl.text.trim(),
      'commission_percentage': double.tryParse(_commissionCtrl.text) ?? 0,
      'minimum_investment': double.tryParse(_minInvestmentCtrl.text) ?? 0,
      'strategy_description': _descriptionCtrl.text.trim(),
      'risk_information': _riskInfoCtrl.text.trim(),
    };
    final success = await _ctrl.createPlan(body);
    if (success && mounted) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
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

        // leading: GestureDetector(
        //   onTap: () => Get.back(),
        //   child: Container(
        //     height: 24.h,
        //     width: 24.w,
        //     padding: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        //     child: SvgPicture.asset(
        //       'assets/svg/trade/arro_back.svg',
        //       width: 20.w,
        //       height: 20.h,
        //       colorFilter: ColorFilter.mode(
        //         AppColors.textPrimary,
        //         BlendMode.srcIn,
        //       ),
        //     ),
        //   ),
        // ),
        title: Text(TranslationUtils.tr('copy_trading_create_plan_create_new_plan'),
            style: AppTextStyles.heading),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Manager Profile card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.border.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationUtils.tr(
                          'pmam_create_plan_manager_profile_caps'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _ProfileRow(
                      label: TranslationUtils.tr('unified_compliance_wizard_name'),
                      value: authCtrl.userFullName ?? '',
                    ),
                    _ProfileRow(
                      label: TranslationUtils.tr('pmam_create_plan_manager_id'),
                      value:
                          _ctrl.managerCode.value.isEmpty
                              ? 'N/A'
                              : _ctrl.managerCode.value,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TranslationUtils.tr('common_status'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            TranslationUtils.tr(
                                'pmam_create_plan_screen_approved_manager'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Form card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.border.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormLabel(TranslationUtils.tr('pmam_create_plan_plan_name'),
                        optional: true),
                    _StyledTextField(
                      controller: _planNameCtrl,
                      hint: TranslationUtils.tr(
                          'pmam_create_plan_plan_name_hint'),
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel(TranslationUtils.tr('settings_trading_account'),
                        required: true),
                    Obx(() {
                      final accounts = _ctrl.eligibleAccounts;
                      if (accounts.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            TranslationUtils.tr(
                                'pmam_create_plan_screen_no_eligible_accounts_available'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                        );
                      }
                      return AppSelectField<Map<String, dynamic>>(
                        value: _selectedAccount,
                        hint: TranslationUtils.tr(
                            'pmam_create_plan_select_a_trading_account'),
                        sheetTitle: TranslationUtils.tr(
                            'pmam_manager_detail_screen_select_trading_account'),
                        valueEquals: (a, b) => a['id'] == b['id'],
                        options:
                            accounts.map((acc) {
                              final accNo =
                                  acc['meta_account_number']?.toString() ?? '-';
                              final bal =
                                  double.tryParse(
                                    acc['balance']?.toString() ?? '0',
                                  ) ??
                                  0;
                              final availBal =
                                  double.tryParse(
                                    acc['available_balance']?.toString() ??
                                        '0',
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
                        onChanged:
                            (v) => setState(() => _selectedAccount = v),
                      );
                    }),
                    SizedBox(height: 4.h),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        TranslationUtils.tr(
                            'pmam_create_plan_screen_don_see_your_account_add_new'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel(
                        TranslationUtils.tr('pmam_edit_plan_commission_percent'),
                        required: true),
                    _StyledTextField(
                      controller: _commissionCtrl,
                      hint: TranslationUtils.tr(
                          'pmam_create_plan_commission_hint'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return TranslationUtils.tr('ibm_required');
                        }
                        final n = double.tryParse(v);
                        if (n == null || n < 0 || n > 100) {
                          return TranslationUtils.tr(
                              'pmam_create_plan_enter_value_between_0_and_100');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      TranslationUtils.tr(
                          'pmam_create_plan_screen_percentage_of_profits_charged_as_your'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel(
                        TranslationUtils.tr(
                            'pmam_create_plan_minimum_investment_dollar'),
                        required: true),
                    _StyledTextField(
                      controller: _minInvestmentCtrl,
                      hint: TranslationUtils.tr(
                          'pmam_create_plan_min_investment_hint'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return TranslationUtils.tr('ibm_required');
                        }
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) {
                          return TranslationUtils.tr(
                              'pmam_create_plan_enter_a_valid_amount');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel(
                        TranslationUtils.tr('pmam_create_plan_about_this_plan'),
                        optional: true),
                    _StyledTextField(
                      controller: _descriptionCtrl,
                      hint: TranslationUtils.tr(
                          'pmam_create_plan_describe_strategy_hint'),
                      maxLines: 3,
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel(
                        TranslationUtils.tr(
                            'copy_trading_create_plan_risk_information'),
                        optional: true),
                    _StyledTextField(
                      controller: _riskInfoCtrl,
                      hint: TranslationUtils.tr(
                          'pmam_create_plan_describe_risk_hint'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Submit button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: _ctrl.isCreatePlanLoading.value ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(
                        0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                    ),
                    child:
                        _ctrl.isCreatePlanLoading.value
                            ? CommonLoadingWidget(size: 22, color: AppColors.onColoredBackground)
                            : Text(
                              TranslationUtils.tr(
                                  'pmam_create_plan_screen_submit_plan'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.onColoredBackground,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  final bool optional;
  final bool required;
  const _FormLabel(this.text, {this.optional = false, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: RichText(
        text: TextSpan(
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          children: [
            TextSpan(text: text),
            if (optional)
              TextSpan(
                text: ' ${TranslationUtils.tr('pmam_create_plan_optional')}',
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            if (required)
              TextSpan(text: ' *', style: AppTextStyles.bodyText.copyWith(color: AppColors.error)),
          ],
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textGrey),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey),
          ),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
