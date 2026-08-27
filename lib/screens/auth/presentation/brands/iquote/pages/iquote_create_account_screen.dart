import 'dart:ui' as ui;
import 'package:crm_app/constants/text_styles.dart';

import 'package:country_picker/country_picker.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/otp_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';

import '../../../auth_form_validation.dart';
import '../../../brands/vantage/widgets/vantage_auth_scaffold.dart';
import '../../../brands/vantage/widgets/vantage_auth_theme.dart';
import '../../../brands/vantage/widgets/vantage_controls.dart';

class IquoteCreateAccountScreen extends StatefulWidget {
  const IquoteCreateAccountScreen({super.key});

  @override
  State<IquoteCreateAccountScreen> createState() =>
      _IquoteCreateAccountScreenState();
}

class _IquoteCreateAccountScreenState
    extends State<IquoteCreateAccountScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedCountryCode = '';
  String _selectedCountryFlag = '';
  // ISO-3166-1 alpha-2 code from country_picker (e.g. "IN", "US").
  String _selectedCountryIso = '';
  Map<String, dynamic>? _registrationData;

  bool _isFormValid = false;
  bool _passwordVisible = false;

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
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _addListeners() {
    _firstNameController.addListener(_validateForm);
    _lastNameController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _validateForm();
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

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      useSafeArea: true,
      countryListTheme: CountryListThemeData(
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountryCode = "+${country.phoneCode}";
          _selectedCountryFlag = country.flagEmoji;
          // country_picker exposes ISO-3166-1 alpha-2 via `Country.countryCode`.
          _selectedCountryIso = country.countryCode;
          _validateForm();
        });
      },
    );
  }

  void _setDeviceCountry() {
    try {
      final deviceLocale = ui.window.locale;
      final countryCode = deviceLocale.countryCode;
      if (countryCode == null || countryCode.isEmpty) return;
      final countries = CountryService().getAll();
      final deviceCountry = countries.firstWhere(
        (c) => c.countryCode == countryCode,
        orElse: () => countries.first,
      );
      setState(() {
        _selectedCountryCode = "+${deviceCountry.phoneCode}";
        _selectedCountryFlag = deviceCountry.flagEmoji;
        _selectedCountryIso = deviceCountry.countryCode;
        _validateForm();
      });
    } catch (_) {}
  }

  /// Builds the phone payload for the register API call. `Country.countryCode`
  /// from `country_picker` is already ISO-3166-1 alpha-2 (e.g. "IN", "US"),
  /// so we forward it as `country` (uppercase) and lowercase it for `country_slug`.
  Map<String, String> _buildPhonePayload() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return <String, String>{
      'mobile': digits,
      'national': digits,
      'country_code': _selectedCountryCode,
      'country': _selectedCountryIso.toUpperCase(),
      'country_slug': _selectedCountryIso.toLowerCase(),
    };
  }

  Map<String, dynamic> _buildRegistrationData({
    required String registerEventType,
    String? otp,
  }) {
    final phonePayload = _buildPhonePayload();
    final data = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'mobile': phonePayload['mobile'],
      'phone_number': phonePayload['national'],
      'country_code': phonePayload['country_code'],
      'register_country_code': phonePayload['country_code'],
      'country': phonePayload['country'],
      'country_slug': phonePayload['country_slug'],
      'otp_verification_type': 'email',
      'register_event_type': registerEventType,
      'accept_terms': true,
    };
    if (otp != null && otp.isNotEmpty) {
      data['otp'] = otp;
    }
    return data;
  }

  void _showOtpVerificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return OtpModal(
          email: _emailController.text.trim(),
          isEmailVerification: true,
          otpLength: 6,
          onOtpSubmitted: (otp) async {
            await _verifyOtpAndCompleteRegistration(otp);
          },
          onResendOtp: _resendRegistrationOtp,
        );
      },
    );
  }

  Future<void> _verifyOtpAndCompleteRegistration(String otp) async {
    try {
      final registrationData = Map<String, dynamic>.from(
        _registrationData ?? _buildRegistrationData(registerEventType: 'register'),
      );
      registrationData['register_event_type'] = 'verifyOtp';
      registrationData['otp'] = otp;

      final otpVerified = await _authController.registerWithOTPVerification(
        data: registrationData,
      );
      if (!mounted) return;
      if (otpVerified) {
        Navigator.of(context).pop();

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

        Get.offAllNamed(AppPages.ACCOUNT_CREATED);
      }
    } catch (e) {
      CustomToastService.showError(title: _languageService.tr('trading_error'), message: '$e');
    }
  }

  Future<void> _resendRegistrationOtp() async {
    final resendData = Map<String, dynamic>.from(
      _registrationData ?? _buildRegistrationData(registerEventType: 'register'),
    );
    resendData.remove('otp');
    resendData['register_event_type'] = 'register';

    await _authController.register(data: resendData);
  }

  Future<void> _startRegistration() async {
    final errors = AuthFormValidation.validateSignUp(
      languageService: _languageService,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    if (!AuthFormValidation.showErrorsIfAny(errors)) return;

    _registrationData = _buildRegistrationData(registerEventType: 'register');
    final registered = await _authController.register(data: _registrationData!);
    if (!mounted) return;
    if (registered) {
      _showOtpVerificationBottomSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VantageAuthScaffold(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _languageService.tr('create_account_screen_title'),
              style: AppTextStyles.bodyText.copyWith(
                color: VantageAuthTheme.text,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 18.h),
            VantagePillTextField(
              controller: _firstNameController,
              hintText: _languageService.tr('create_account_screen_first_name'),
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            SizedBox(height: 10.h),
            VantagePillTextField(
              controller: _lastNameController,
              hintText: _languageService.tr('create_account_screen_last_name'),
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                InkWell(
                  onTap: _showCountryPicker,
                  borderRadius: BorderRadius.circular(24.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: VantageAuthTheme.fieldFill,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: VantageAuthTheme.fieldBorder),
                    ),
                    child: Text(
                      _selectedCountryFlag.isNotEmpty
                          ? _selectedCountryFlag
                          : '🌐',
                      style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autovalidateMode: AutovalidateMode.disabled,
                    inputFormatters: [LengthLimitingTextInputFormatter(20)],
                    onChanged: (_) => _validateForm(),
                    decoration: VantageAuthTheme.pillDecoration(
                      hintText: _languageService.tr(
                        'create_account_screen_phone_number',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            VantagePillTextField(
              controller: _emailController,
              hintText: _languageService.tr('create_account_screen_email'),
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(Icons.mail_outline_rounded),
              onChanged: (_) => _validateForm(),
            ),
            SizedBox(height: 10.h),
            VantagePillTextField(
              controller: _passwordController,
              hintText: _languageService.tr('create_account_screen_password'),
              obscureText: !_passwordVisible,
              prefixIcon: Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed:
                    () => setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.isDarkMode ? Colors.white : VantageAuthTheme.muted,
                ),
              ),
              onChanged: (_) => _validateForm(),
            ),
            SizedBox(height: 16.h),
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
                    final enrolled =
                        await BiometricService.instance.isEnrolled();
                    if (!supported || !enrolled) {
                      setState(() => _enableBiometricAfterRegister = false);
                      return;
                    }

                    if (!mounted) return;
                    setState(() => _enableBiometricAfterRegister = true);
                  },
                  activeColor: VantageAuthTheme.primary,
                  checkColor: AppColors.isDarkMode ? Colors.black : Colors.white,
                  side: BorderSide(
                    color: AppColors.isDarkMode ? Colors.white : Colors.grey,
                    width: 1.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    _languageService.tr('biometric_enable_checkbox'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: VantageAuthTheme.muted,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Obx(() {
              return VantagePrimaryButton(
                text: _languageService.tr('create_account_screen_sign_up'),
                isLoading: _authController.isLoading,
                onPressed:
                    !_isFormValid || _authController.isLoading
                        ? null
                        : _startRegistration,
              );
            }),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () => Get.offAllNamed(AppPages.LOGIN),
              child: Text.rich(
                TextSpan(
                  text: _languageService.tr('create_account_screen_already_have_account'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: VantageAuthTheme.muted,
                    fontSize: 13.sp,
                  ),
                  children: [
                    TextSpan(
                      text: _languageService.tr('login_screen_sign_in'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: VantageAuthTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _languageService.tr('create_account_screen_agree_terms'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(color: VantageAuthTheme.muted, fontSize: 11.sp),
            ),
            // SizedBox(height: 6.h),
            // if (_selectedCountryCode.isNotEmpty)
            //   Text(
            //     'Selected code: $_selectedCountryCode',
            //     textAlign: TextAlign.center,
            //     style: AppTextStyles.bodyText.copyWith(color: VantageAuthTheme.muted, fontSize: 11.sp),
            //   ),
          ],
      ),
    );
  }
}
