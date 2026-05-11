import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/otp_modal.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';

import 'legal_documents_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referrerController = TextEditingController();

  String _selectedCountryCode = '';
  String _selectedCountryFlag = '';
  bool _isFormValid = false;
  final ValueNotifier<bool> _passwordVisible = ValueNotifier<bool>(false);

  final AuthController _authController = Get.find<AuthController>();
  final LanguageService _languageService = Get.find<LanguageService>();
  bool _enableBiometricAfterRegister = false;

  @override
  void initState() {
    super.initState();
    _addListeners();
    _setDeviceCountry();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referrerController.dispose();
    _passwordVisible.dispose();
    super.dispose();
  }

  void _addListeners() {
    _firstNameController.addListener(_validateForm);
    _lastNameController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    setState(() {
      _isFormValid =
          _firstNameController.text.isNotEmpty &&
          _lastNameController.text.isNotEmpty &&
          _phoneController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
    });
  }

  Future<void> _sendOTPForVerification() async {
    try {
      _showOtpVerificationBottomSheet();
    } catch (e) {
      _hideLoadingDialog();
      _showError('Failed to send OTP: $e');
    }
  }

  void _showOtpVerificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder:
          (context) => OtpModal(
            email: _emailController.text.trim(),
            isEmailVerification: true,
            otpLength: 5,
            onOtpSubmitted: (otp) async {
              await _verifyOtpAndCompleteRegistration(otp);
            },
            onResendOtp: () async {
              await _sendOTPForVerification();
            },
          ),
    );
  }

  Future<void> _verifyOtpAndCompleteRegistration(String otp) async {
    try {
      _showLoadingDialog('Verifying OTP...');
      final registrationData = {
        "first_name": _firstNameController.text.trim(),
        "last_name": _lastNameController.text.trim(),
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
        "mobile": _phoneController.text.trim(),
        "otp_verification_type": "email",
        "register_event_type": "verifyOtp",
        "accept_terms": true,
      };

      final referrerCode = _referrerController.text.trim();
      if (referrerCode.isNotEmpty) {
        registrationData["ib_affiliate_refcode"] = referrerCode;
      }

      final otpVerified = await _authController.register(data: registrationData);

      _hideLoadingDialog();

      if (otpVerified) {
        Navigator.of(context).pop();

        CustomToastService.showSuccess(
          title: 'Success',
          message: 'Account created successfully!',
        );

        if (_enableBiometricAfterRegister) {
          final supported = await BiometricService.instance.isDeviceSupported();
          final enrolled = await BiometricService.instance.isEnrolled();
          if (supported && enrolled) {
            final ok = await BiometricService.instance.authenticate(
              reason: _languageService.tr('biometric_enable_reason'),
            );
            if (ok) {
              await SecureStorageService.setBiometricEnabled(
                true,
                userIdentifier: _emailController.text.trim(),
              );
              Get.find<AppLockService>().markJustAuthenticated();
            }
          }
        }

        _navigateToNextScreen();
      }
    } catch (e) {
      _hideLoadingDialog();
      _showError('OTP verification failed: $e');
    }
  }

  void _navigateToNextScreen() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Please enter your email address',
      );
      return;
    }

    if (!_isValidEmail(email)) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Please check email, email is not valid',
      );
      return;
    }

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final registrationData = {
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "email": email,
      "password": _passwordController.text.trim(),
      "mobile": _phoneController.text.trim(),
      "otp_verification_type": "email",
      "register_event_type": "register",
      "accept_terms": true,
      "register_country_code": _selectedCountryCode,
    };

    final referrerCode = _referrerController.text.trim();
    if (referrerCode.isNotEmpty) {
      registrationData["ib_affiliate_refcode"] = referrerCode;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegalDocumentsScreen(registrationData: registrationData),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    CommonLoadingWidget(isFullScreen: true);
  }

  void _hideLoadingDialog() {
    if (Get.isDialogOpen == true) {
      Get.back(closeOverlays: true);
    }
  }

  void _showError(String message) {
    CustomToastService.showError(title: 'Error', message: message);
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: AppColors.whiteColor,
        textStyle: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountryCode = "+${country.phoneCode}";
          _selectedCountryFlag = "${country.flagEmoji} +${country.phoneCode}";
          _validateForm();
        });
      },
    );
  }

  void _setDeviceCountry() {
    try {
      final deviceLocale = ui.window.locale;
      final countryCode = deviceLocale.countryCode;

      if (countryCode != null && countryCode.isNotEmpty) {
        final countries = CountryService().getAll();
        final deviceCountry = countries.firstWhere(
          (country) => country.countryCode == countryCode,
          orElse: () => countries.first,
        );

        setState(() {
          _selectedCountryCode = "+${deviceCountry.phoneCode}";
          _selectedCountryFlag = deviceCountry.flagEmoji;
          _validateForm();
        });
      }
    } catch (e) {
      print("Error detecting device country: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: RTLHelper.getRTLPadding(left: 24.w, right: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24.h),
                      _buildTitleSection(),
                      SizedBox(height: 24.h),
                      _buildFormFields(),
                      SizedBox(height: 24.h),
                      _buildCreateAccountButton(),
                      SizedBox(height: 12.h),
                      _buildLoginLink(),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_languageService.tr("register_title"), style: AppTextStyles.heading),
        SizedBox(height: 4.h),
        Text(
          _languageService.tr("register_personal_info"),
          style: AppTextStyles.subheading.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _firstNameController,
          label: _languageService.tr("register_first_name"),
          validator: (value) => _validateRequired(value, 'validation_name_required'),
        ),
        _buildTextField(
          controller: _lastNameController,
          label: _languageService.tr("register_last_name"),
          validator: (value) => _validateRequired(value, 'validation_name_required'),
        ),
        _buildCountryField(),
        _buildTextField(
          controller: _emailController,
          label: _languageService.tr("register_email"),
          keyboardType: TextInputType.emailAddress,
          validator: (value) => _validateEmail(value),
        ),
        _buildPasswordField(),
        _buildTextField(
          controller: _referrerController,
          label: 'Referrer Code',
          keyboardType: TextInputType.text,
          maxLength: 30,
        ),
        Row(
          children: [
            Checkbox(
              value: _enableBiometricAfterRegister,
              onChanged: (v) async {
                final value = v ?? false;
                if (!value) {
                  setState(() => _enableBiometricAfterRegister = false);
                  return;
                }

                final supported =
                    await BiometricService.instance.isDeviceSupported();
                final enrolled = await BiometricService.instance.isEnrolled();
                if (!supported || !enrolled) {
                  setState(() => _enableBiometricAfterRegister = false);
                  return;
                }

                if (!mounted) return;
                setState(() => _enableBiometricAfterRegister = true);
              },
              activeColor: AppColors.primary,
            ),
            Expanded(
              child: Text(
                _languageService.tr('biometric_enable_checkbox'),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    bool? obscureText,
    int? maxLength,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        obscureText: obscureText ?? false,
        controller: controller,
        labelText: label,
        keyboardType: keyboardType,
        validator: validator,
        suffixIcon: suffixIcon,
        inputFormatters:
            maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
      ),
    );
  }

  Widget _buildPasswordField() {
    return ValueListenableBuilder<bool>(
      valueListenable: _passwordVisible,
      builder: (context, isVisible, child) {
        return _buildTextField(
          controller: _passwordController,
          label: _languageService.tr("register_password"),
          keyboardType: TextInputType.text,
          obscureText: !isVisible,
          suffixIcon: IconButton(
            onPressed: () => _passwordVisible.value = !isVisible,
            icon: SvgPicture.asset(
              isVisible ? "assets/svg/eye_icon.svg" : "assets/svg/eye-slash.svg",
            ),
          ),
          validator: (value) => _validatePassword(value),
        );
      },
    );
  }

  Widget _buildCountryField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          InkWell(
            onTap: _showCountryPicker,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _selectedCountryFlag.isNotEmpty ? _selectedCountryFlag : "🌐 +--",
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: _languageService.tr("register_phone"),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _languageService.tr('validation_required');
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateAccountButton() {
    return SizedBox(
      width: double.infinity,
      child: RTLHelper.rtlButton(
        height: 46.h,
        text: _languageService.tr("onboarding_next"),
        onPressed: _isFormValid ? _navigateToNextScreen : null,
        backgroundColor: AppColors.primary,
        foregroundColor: _isFormValid ? AppColors.whiteColor : AppColors.textGrey,
      ),
    );
  }

  Widget _buildLoginLink() {
    return Align(
      alignment: RTLHelper.getRTLAlignment(Alignment.center),
      child: RichText(
        text: TextSpan(
          text: "${_languageService.tr("register_already_have_account")} ",
          style: TextStyle(color: AppColors.textGrey, fontSize: 14.sp),
          children: [
            TextSpan(
              text: _languageService.tr("register_log_in"),
              style: AppTextStyles.link,
              recognizer: TapGestureRecognizer()..onTap = () => Get.toNamed(AppPages.LOGIN),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: RTLHelper.getRTLPadding(
        left: 24.w,
        right: 24.w,
        top: 16.h,
        bottom: 16.h,
      ),
      child: RTLHelper.rtlRow(
        children: [
          _buildBackButton(),
          SizedBox(width: 16.w),
          Expanded(child: _buildProgressBar()),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      height: 40.h,
      width: 40.w,
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: RTLHelper.rtlIcon(Icons.arrow_back_ios, color: Colors.black),
        iconSize: 17.h,
        padding: RTLHelper.getRTLPadding(left: 5.w),
      ),
    );
  }

  Widget _buildProgressBar() {
    return RTLHelper.rtlRow(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _progressBar(active: true),
        SizedBox(width: 8.w),
        _progressBar(),
        SizedBox(width: 8.w),
        _progressBar(),
      ],
    );
  }

  Widget _progressBar({bool active = false}) {
    return Container(
      width: 60.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String? _validateRequired(String? value, String errorKey) {
    if (value == null || value.isEmpty) {
      return _languageService.tr(errorKey);
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return _languageService.tr('validation_required');
    }
    if (!_isValidEmail(value)) {
      return 'Please check email, email is not valid';
    }
    return null;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return _languageService.tr('validation_required');
    }
    if (value.length < 6) {
      return _languageService.tr('validation_password_min_length');
    }
    return null;
  }
}

