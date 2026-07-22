import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/data/models/riyadex_country_config.dart';
import 'package:crm_app/screens/auth/view_models/riyadex_registration_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/auth/presentation/auth_form_validation.dart';
import 'package:crm_app/widgets/otp_modal.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'package:crm_app/screens/auth/presentation/brands/vantage/widgets/vantage_auth_scaffold.dart';
import 'package:crm_app/screens/auth/presentation/brands/vantage/widgets/vantage_auth_theme.dart';
import 'package:crm_app/screens/auth/presentation/brands/vantage/widgets/vantage_controls.dart';

class RiyadexCreateAccountScreen extends StatefulWidget {
  const RiyadexCreateAccountScreen({super.key});

  @override
  State<RiyadexCreateAccountScreen> createState() =>
      _RiyadexCreateAccountScreenState();
}

class _RiyadexCreateAccountScreenState
    extends State<RiyadexCreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referController = TextEditingController();

  final _passwordFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isUsCitizen = false;
  bool _isSubmitting = false;

  late RiyadexRegistrationController _controller;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<RiyadexRegistrationController>()) {
      Get.put(RiyadexRegistrationController());
    }
    _controller = Get.find<RiyadexRegistrationController>();

    _passwordFocusNode.addListener(() {
      setState(() {});
    });

    _phoneController.addListener(_formatPhone);
  }

  String get _phoneDigits => _phoneController.text.replaceAll(RegExp(r'\D'), '');

  bool get _isPhoneValid {
    final digits = _phoneDigits;
    if (digits.isEmpty) return false;
    final pCountry = _controller.selectedPhoneCountry.value ?? _controller.selectedCountry.value;
    final iso = pCountry?.iso2;
    IsoCode? isoCode;
    if (iso != null && iso.isNotEmpty) {
      try {
        isoCode = IsoCode.values.byName(iso.toUpperCase());
      } catch (_) {}
    }
    if (isoCode == null) return digits.length >= 6 && digits.length <= 15;

    try {
      final number = PhoneNumber.parse(digits, destinationCountry: isoCode);
      if (number.isValid(type: PhoneNumberType.mobile) || number.isValid()) {
        return true;
      }
    } catch (_) {}
    return digits.length >= 7 && digits.length <= 15;
  }

  void _formatPhone() {
    final pCountry = _controller.selectedPhoneCountry.value ?? _controller.selectedCountry.value;
    final iso = pCountry?.iso2;
    final digits = _phoneDigits;
    IsoCode? isoCode;
    if (iso != null && iso.isNotEmpty) {
      try {
        isoCode = IsoCode.values.byName(iso.toUpperCase());
      } catch (_) {}
    }
    if (isoCode == null || digits.isEmpty) return;

    try {
      final formatted = PhoneNumber.parse(digits, destinationCountry: isoCode).formatNsn();
      if (formatted.isNotEmpty && formatted != _phoneController.text) {
        _phoneController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _referController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_emailController.text.trim().isEmpty || !AuthFormValidation.isValidEmail(_emailController.text.trim())) {
      CustomToastService.showError(title: 'Error', message: 'Please enter a valid email address');
      return;
    }
    if (_passwordController.text.length < 8) {
      CustomToastService.showError(title: 'Error', message: 'Password must be at least 8 characters');
      return;
    }
    if (!_controller.isMinimal.value) {
      if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
        CustomToastService.showError(title: 'Error', message: 'Please fill in all required fields');
        return;
      }
      if (!_isPhoneValid) {
        CustomToastService.showError(title: 'Error', message: 'Please enter a valid phone number');
        return;
      }
    }

    if (_isUsCitizen) {
      CustomToastService.showError(title: 'Error', message: "Cannot register as US Citizen/Resident");
      return;
    }
    if (!_controller.allowedToRegister.value) {
      CustomToastService.showError(title: 'Error', message: _controller.restrictedMessage.value);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _controller.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        mobile: _phoneController.text.trim(),
        referCode: _referController.text.trim(),
      );

      if (success) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => OtpModal(
            email: _emailController.text.trim(),
            onResendOtp: () async {
              await _controller.register(
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                mobile: _phoneController.text.trim(),
                referCode: _referController.text.trim(),
              );
            },
            onOtpSubmitted: (otp) async {
              final otpVerified = await _controller.verifyOtp(
                _emailController.text.trim(),
                otp,
              );
              if (otpVerified) {
                Get.offAllNamed(Routes.ACCOUNT_CREATED);
              }
            },
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        countries: _controller.countries,
        selectedCountry: _controller.selectedCountry.value,
        onSelect: (country) {
          _controller.selectCountry(country);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showPhoneCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        countries: _controller.countries,
        selectedCountry: _controller.selectedPhoneCountry.value,
        onSelect: (country) {
          _controller.selectedPhoneCountry.value = country;
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VantageAuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Welcome to Riyadex",
              style: AppTextStyles.bodyText.copyWith(
                color: VantageAuthTheme.text,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 16.h),

            // Row(
            //   children: [
            //     GestureDetector(
            //       onTap: () => Get.offNamed(Routes.LOGIN),
            //       child: Text(
            //         "Sign in",
            //         style: AppTextStyles.bodyText.copyWith(
            //           fontSize: 16.sp,
            //           color: VantageAuthTheme.muted,
            //           fontWeight: FontWeight.w600,
            //         ),
            //       ),
            //     ),
            //     SizedBox(width: 24.w),
            //     Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Text(
            //           "Create an account",
            //           style: AppTextStyles.bodyText.copyWith(
            //             fontSize: 16.sp,
            //             color: VantageAuthTheme.text,
            //             fontWeight: FontWeight.w600,
            //           ),
            //         ),
            //         SizedBox(height: 4.h),
            //         Container(
            //           height: 2.h,
            //           width: 145.w,
            //           color: AppColors.brandPrimary,
            //         ),
            //       ],
            //     ),
            //   ],
            // ),
            // SizedBox(height: 8.h),
            // Divider(color: VantageAuthTheme.fieldBorder, height: 1.h),
            // SizedBox(height: 24.h),

            Obx(() {
              if (_controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final country = _controller.selectedCountry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Country / Region of Residence",
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      color: VantageAuthTheme.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  GestureDetector(
                    onTap: _showCountryPicker,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: VantageAuthTheme.fieldBorder),
                        borderRadius: BorderRadius.circular(24.r),
                        color: VantageAuthTheme.fieldFill,
                      ),
                      child: Row(
                        children: [
                          if (country != null)
                            Text(
                              _getFlagEmoji(country.iso2),
                              style: TextStyle(fontSize: 20.sp),
                            ),
                          if (country != null) SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              country?.name ?? "Select Country",
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14.sp,
                                color: VantageAuthTheme.text,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: VantageAuthTheme.muted,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!_controller.allowedToRegister.value) ...[
                    SizedBox(height: 24.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 20.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              _controller.restrictedMessage.value,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13.sp,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_controller.allowedToRegister.value) ...[
                    SizedBox(height: 12.h),

                    if (!_controller.isMinimal.value) ...[
                      Row(
                        children: [
                          Expanded(
                            child: VantagePillTextField(
                              hintText: "First Name",
                              controller: _firstNameController,
                              keyboardType: TextInputType.name,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: VantagePillTextField(
                              hintText: "Last Name",
                              controller: _lastNameController,
                              keyboardType: TextInputType.name,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                    ],

                    VantagePillTextField(
                      hintText: "Email address",
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 12.h),

                    if (!_controller.isMinimal.value) ...[
                      VantagePillTextField(
                        hintText: "Phone number",
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: GestureDetector(
                          onTap: _showPhoneCountryPicker,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Obx(() {
                                  final pCountry = _controller.selectedPhoneCountry.value ?? country;
                                  return Text(
                                    _getFlagEmoji(pCountry?.iso2 ?? 'US'),
                                    style: TextStyle(fontSize: 16.sp),
                                  );
                                }),
                                SizedBox(width: 4.w),
                                Icon(Icons.arrow_drop_down, size: 16.sp),
                                SizedBox(width: 4.w),
                                Obx(() {
                                  final pCountry = _controller.selectedPhoneCountry.value ?? country;
                                  return Text(
                                    pCountry?.dialCode ?? '',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 14.sp,
                                      color: VantageAuthTheme.text,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                    ],

                    VantagePillTextField(
                      hintText: "Create your account password",
                      controller: _passwordController,
                      
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: VantageAuthTheme.muted,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    
                    if (_passwordFocusNode.hasFocus || _passwordController.text.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _PasswordRulesWidget(password: _passwordController.text),
                    ],
                    SizedBox(height: 12.h),

                    // Theme(
                    //   data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    //   child: ExpansionTile(
                    //     tilePadding: EdgeInsets.zero,
                    //     title: Text(
                    //       "Partner code (optional)",
                    //       style: AppTextStyles.bodyText.copyWith(
                    //         fontSize: 14.sp,
                    //         color: VantageAuthTheme.text,
                    //         fontWeight: FontWeight.w600,
                    //       ),
                    //     ),
                    //     children: [
                    //       VantagePillTextField(
                    //         controller: _referController,
                    //         hintText: "Enter partner code",
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    // SizedBox(height: 24.h),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24.w,
                          width: 24.w,
                          child: Checkbox(
                            value: _isUsCitizen,
                            onChanged: (val) {
                              setState(() {
                                _isUsCitizen = val ?? false;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            side: BorderSide(color: VantageAuthTheme.muted),
                            activeColor: AppColors.brandPrimary,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            "I declare and confirm that I am not a citizen or resident of the US for tax purposes.",
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              color: VantageAuthTheme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    VantagePrimaryButton(
                      text: "Register",
                      onPressed: _handleRegister,
                      isLoading: _isSubmitting,
                    ),
                    // SizedBox(height: 24.h),

                    // Row(
                    //   children: [
                    //     Expanded(child: Divider(color: VantageAuthTheme.fieldBorder)),
                    //     Padding(
                    //       padding: EdgeInsets.symmetric(horizontal: 16.w),
                    //       child: Text(
                    //         "Or create an account with",
                    //         style: AppTextStyles.bodyText.copyWith(
                    //           fontSize: 14.sp,
                    //           color: VantageAuthTheme.muted,
                    //         ),
                    //       ),
                    //     ),
                    //     Expanded(child: Divider(color: VantageAuthTheme.fieldBorder)),
                    //   ],
                    // ),
                    // SizedBox(height: 24.h),

                    // VantageOutlinedButton(
                    //   text: "Google",
                    //   onPressed: () {
                    //     Get.toNamed(Routes.LOGIN);
                    //   },
                    // ),
                  ],
                ],
              );
            }),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  String _getFlagEmoji(String countryCode) {
    int flagOffset = 0x1F1E6;
    int asciiOffset = 0x41;
    if (countryCode.length != 2) return "🌐";
    int firstChar = countryCode.codeUnitAt(0) - asciiOffset + flagOffset;
    int secondChar = countryCode.codeUnitAt(1) - asciiOffset + flagOffset;
    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final List<RiyadexCountry> countries;
  final RiyadexCountry? selectedCountry;
  final ValueChanged<RiyadexCountry> onSelect;

  const _CountryPickerSheet({
    required this.countries,
    this.selectedCountry,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late List<RiyadexCountry> _filtered;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
  }

  void _filter(String query) {
    setState(() {
      _filtered = widget.countries
          .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  String _getFlagEmoji(String countryCode) {
    int flagOffset = 0x1F1E6;
    int asciiOffset = 0x41;
    if (countryCode.length != 2) return "🌐";
    int firstChar = countryCode.codeUnitAt(0) - asciiOffset + flagOffset;
    int secondChar = countryCode.codeUnitAt(1) - asciiOffset + flagOffset;
    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 12.h),
          Container(
            height: 4.h,
            width: 40.w,
            decoration: BoxDecoration(
              color: VantageAuthTheme.fieldBorder,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            "Select Country",
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: VantageAuthTheme.text,
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: VantagePillTextField(
              controller: _searchController,
              hintText: "Search country",
              onChanged: _filter,
              prefixIcon: Icon(Icons.search, color: VantageAuthTheme.muted),
            ),
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final c = _filtered[index];
                final isSelected = c.iso2 == widget.selectedCountry?.iso2;
                return ListTile(
                  leading: Text(
                    _getFlagEmoji(c.iso2),
                    style: TextStyle(fontSize: 24.sp),
                  ),
                  title: Text(
                    c.name,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      color: VantageAuthTheme.text,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: AppColors.brandPrimary)
                      : null,
                  onTap: () => widget.onSelect(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRulesWidget extends StatelessWidget {
  final String password;
  const _PasswordRulesWidget({required this.password});

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8 && password.length <= 15;
    final hasUpperLower = password.contains(RegExp(r'[A-Z]')) && password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'''[!@#\$%\^&\*\(\)_\+\-\=\[\]\{\};:'",<>\./?\\|`~]'''));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RuleRow(text: "Between 8-15 characters", isMet: hasLength),
        SizedBox(height: 4.h),
        _RuleRow(text: "At least one upper and one lower case letter", isMet: hasUpperLower),
        SizedBox(height: 4.h),
        _RuleRow(text: "At least one number", isMet: hasNumber),
        SizedBox(height: 4.h),
        _RuleRow(text: "At least one special character", isMet: hasSpecial),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String text;
  final bool isMet;
  const _RuleRow({required this.text, required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16.sp,
          color: isMet ? Colors.green : VantageAuthTheme.muted,
        ),
        SizedBox(width: 8.w),
        Text(
          text,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 12.sp,
            color: isMet ? Colors.green : VantageAuthTheme.muted,
          ),
        ),
      ],
    );
  }
}
