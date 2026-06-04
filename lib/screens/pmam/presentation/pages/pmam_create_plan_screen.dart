import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/pmam/view_models/pmam_controller.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';

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
    // Only load eligible accounts (lightweight — avoids full portal reload)
    if (_ctrl.eligibleAccounts.isEmpty) {
      await _ctrl.loadEligibleAccounts();
    }
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
      CustomToastService.showError(
        title: 'Required',
        message: 'Please select a trading account',
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
        leading: const AppBackButton(),

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
        title: Text('Create New Plan', style: AppTextStyles.heading),
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
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MANAGER PROFILE',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _ProfileRow(
                      label: 'Name',
                      value: authCtrl.userFullName ?? '',
                    ),
                    _ProfileRow(
                      label: 'Manager ID',
                      value:
                          _ctrl.managerCode.value.isEmpty
                              ? 'N/A'
                              : _ctrl.managerCode.value,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
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
                            color: AppColors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'Approved Manager',
                            style: TextStyle(
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
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormLabel('Plan Name', optional: true),
                    _StyledTextField(
                      controller: _planNameCtrl,
                      hint: 'e.g. Conservative Growth Fund',
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel('Trading Account', required: true),
                    Obx(() {
                      final accounts = _ctrl.eligibleAccounts;
                      if (accounts.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.dividerMedium),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            'No eligible accounts available',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                        );
                      }
                      return DropdownButtonFormField<Map<String, dynamic>>(
                        isExpanded: true,
                        value: _selectedAccount,
                        hint: Text(
                          'Select a trading account',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 6.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: const BorderSide(
                              color: AppColors.dividerMedium,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: const BorderSide(
                              color: AppColors.dividerMedium,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                        items:
                            accounts.map((acc) {
                              final accNo = acc['meta_account_number'] ?? '-';
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
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: acc,
                                child: Text(
                                  '$accNo — Balance: \$${bal.toStringAsFixed(2)} (Available: \$${availBal.toStringAsFixed(2)})',
                                  style: TextStyle(fontSize: 13.sp),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                        onChanged: (v) => setState(() => _selectedAccount = v),
                      );
                    }),
                    SizedBox(height: 4.h),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        "Don't see your account? Add new account",
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel('Commission %', required: true),
                    _StyledTextField(
                      controller: _commissionCtrl,
                      hint: 'e.g. 20',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final n = double.tryParse(v);
                        if (n == null || n < 0 || n > 100) {
                          return 'Enter a value between 0 and 100';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Percentage of profits charged as your commission.',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel('Minimum Investment (\$)', required: true),
                    _StyledTextField(
                      controller: _minInvestmentCtrl,
                      hint: 'e.g. 500',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel('About this Plan', optional: true),
                    _StyledTextField(
                      controller: _descriptionCtrl,
                      hint:
                          'Describe your trading strategy, approach, goals...',
                      maxLines: 3,
                    ),
                    SizedBox(height: 16.h),

                    _FormLabel('Risk Information', optional: true),
                    _StyledTextField(
                      controller: _riskInfoCtrl,
                      hint: 'Describe the risk level and max drawdown...',
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
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(
                        0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                    ),
                    child:
                        _ctrl.isCreatePlanLoading.value
                            ? CommonLoadingWidget(size: 22, color: AppColors.whiteColor)
                            : Text(
                              'Submit Plan',
                              style: TextStyle(
                                color: AppColors.whiteColor,
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
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          children: [
            TextSpan(text: text),
            if (optional)
              TextSpan(
                text: ' (optional)',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            if (required)
              TextSpan(text: ' *', style: TextStyle(color: AppColors.red)),
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
      style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.dividerMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.dividerMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: AppColors.red),
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
            style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
          ),
          Text(
            value,
            style: TextStyle(
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
