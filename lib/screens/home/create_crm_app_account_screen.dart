import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/create_trading_account_controller.dart';
import 'package:crm_app/screens/trading/view_models/plan_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class CreateCrmAppAccountScreen extends StatefulWidget {
  final String accountType;
  final bool isDemo;
  final PlanModel? plan;

  const CreateCrmAppAccountScreen({
    Key? key,
    required this.accountType,
    required this.isDemo,
    this.plan,
  }) : super(key: key);

  @override
  State<CreateCrmAppAccountScreen> createState() =>
      _CreateCrmAppAccountScreenState();
}

class _CreateCrmAppAccountScreenState extends State<CreateCrmAppAccountScreen> {
  late final CreateTradingAccountController controller;
  String selectedLeverage = '';

  @override
  void initState() {
    super.initState();
    controller = Get.put(CreateTradingAccountController());
    // Set account type based on what was passed from previous screen
    controller.setAccountType(widget.accountType);
    // Initialize leverage with plan model value
    selectedLeverage = widget.plan?.leverage ?? '';
    controller.setgroupId(widget.plan?.id ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Create new ${widget.accountType} Account',
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: RTLHelper.getRTLPadding(left: 24.w, right: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 32.h),

              // Leverage Field
              if (!widget.isDemo) ...[
                _buildDropdownField(
                  label: Get.find<LanguageService>().tr(
                    'create_account_leverage',
                  ),
                  value: selectedLeverage,
                  options: [
                    '1:100',
                    '1:200',
                    '1:300',
                    '1:400',
                    '1:500',
                    '1:600',
                    '1:700',
                    '1:800',
                    '1:900',
                    '1:1000',
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedLeverage = value ?? '';
                    });
                    // Store leverage in controller for API call
                    controller.setLeverage(selectedLeverage);
                  },
                ),
              ],
              if (widget.isDemo) ...[
                // Title
                Text(
                  'Select Account',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.icongrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),

                // Radios side-by-side
                Obx(() {
                  return Row(
                    children: [
                      SizedBox(
                        height: 40.h,
                        width: 155.w,
                        child: _AccountRadio(
                          label: controller.accounts[0],
                          value: controller.accounts[0],
                          groupValue: controller.selected.value,
                          onChanged: (v) => controller.selected.value = v!,
                        ),
                      ),
                      // const SizedBox(width: 28),
                      // _AccountRadio(
                      //   label: controller.accounts[1],
                      //   value: controller.accounts[1],
                      //   groupValue: controller.selected.value,
                      //   onChanged: (v) => controller.selected.value = v!,
                      // ),
                    ],
                  );
                }),
              ],

              SizedBox(height: 10.h),

              // Currency Field
              // _buildDropdownField(
              //   label: 'Currency',
              //   value: 'USD',
              //   options: [
              //     'USD',
              //     'EUR',
              //     'GBP',
              //     'JPY',
              //     'AUD',
              //     'CAD',
              //     'CHF',
              //     'NZD',
              //   ],
              //   onChanged: (value) {
              //     // Handle currency selection
              //   },
              // ),
              SizedBox(height: 10.h),
              Obx(
                () => _buildPasswordField(
                  readOnly: true,
                  label: Get.find<LanguageService>().tr(
                    'create_account_currency',
                  ),
                  controller: controller.currencyController,
                  showPassword: true,
                  onTogglePassword: null,
                ),
              ),

              SizedBox(height: 10.h),
              // Master Password Field
              Obx(
                () => _buildPasswordField(
                  label: Get.find<LanguageService>().tr(
                    'create_account_create_mt5_password',
                  ),
                  helperText: Get.find<LanguageService>().tr(
                    'create_account_master_password_helper',
                  ),
                  controller: controller.tradingPasswordController,
                  showPassword: controller.showTradingPassword.value,
                  onTogglePassword: controller.toggleTradingPasswordVisibility,
                ),
              ),
              SizedBox(height: 10.h),

              // Investor Password Field (auto-generated, read-only)
              Obx(
                () => _buildPasswordField(
                  label: Get.find<LanguageService>().tr(
                    'create_account_investor_password_auto',
                  ),
                  helperText: Get.find<LanguageService>().tr(
                    'create_account_investor_password_helper',
                  ),
                  controller: controller.investorPasswordController,
                  showPassword: controller.showInvestorPassword.value,
                  onTogglePassword: controller.toggleInvestorPasswordVisibility,
                  readOnly: true,
                  ignoreOnChanged: true,
                ),
              ),

              Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Note :',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text:
                            'Your Investor password and trading password cannot be the same.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Create Account Button
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 10,
          left: 24.w,
          right: 24.w,
        ),
        child: _buildCreateAccountButton(),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        controller: TextEditingController(text: value),
        readOnly: true,
        onTap:
            () =>
                _showDropdownPicker(context, label, value, options, onChanged),
        suffixIcon: InkWell(
          onTap:
              () => _showDropdownPicker(
                context,
                label,
                value,
                options,
                onChanged,
              ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: RTLHelper.rtlIcon(
              Icons.keyboard_arrow_down_outlined,
              color: Colors.grey,
            ),
          ),
        ),
        decoration: InputDecoration(
          labelText: label,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool showPassword,
    VoidCallback? onTogglePassword,
    bool readOnly = false,
    String? helperText,
    bool ignoreOnChanged = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        controller: controller,
        obscureText: !showPassword,
        readOnly: readOnly,
        suffixIcon:
            onTogglePassword != null
                ? InkWell(
                  onTap: onTogglePassword,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Icon(
                      showPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                )
                : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 3,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error),
          ),
        ),
        onChanged:
            ignoreOnChanged
                ? null
                : (value) {
                  if (controller == this.controller.tradingPasswordController) {
                    this.controller.updateTradingPassword(value);
                  } else {
                    this.controller.updateInvestorPassword(value);
                  }
                },
      ),
    );
  }

  Widget _buildCreateAccountButton() {
    return Obx(
      () => ElevatedButton(
        onPressed:
            controller.isLoading.value
                ? null
                : (widget.isDemo)
                ? controller.createDemoAccount
                : controller.createAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              controller.isLoading.value ? Colors.grey : AppColors.primary,
          foregroundColor: AppColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
        ),
        child:
            controller.isLoading.value
                ? ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)
                : Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
      ),
    );
  }

  void _showDropdownPicker(
    BuildContext context,
    String label,
    String currentValue,
    List<String> options,
    Function(String?) onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Select $label',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  height: 300.h,
                  child: ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option == currentValue;

                      return InkWell(
                        onTap: () {
                          onChanged(option);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 16.h,
                            horizontal: 16.w,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _AccountRadio extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _AccountRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Color purple = AppColors.primary; // tweak to your brand color

    return RadioTheme(
      data: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          // selected circle color
          if (states.contains(MaterialState.selected)) return purple;
          // unselected border color
          return Colors.grey.shade500;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style:   TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
