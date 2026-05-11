import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
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

import '../widgets/vantage_auth_scaffold.dart';
import '../widgets/vantage_auth_theme.dart';
import '../widgets/vantage_controls.dart';

class VantageCreateAccountScreen extends StatefulWidget {
  const VantageCreateAccountScreen({super.key});

  @override
  State<VantageCreateAccountScreen> createState() =>
      _VantageCreateAccountScreenState();
}

class _VantageCreateAccountScreenState
    extends State<VantageCreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedCountryCode = '';
  String _selectedCountryFlag = '';

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
      onSelect: (Country country) {
        setState(() {
          _selectedCountryCode = "+${country.phoneCode}";
          _selectedCountryFlag = country.flagEmoji;
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
        _validateForm();
      });
    } catch (_) {}
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> _sendOtpForVerification() async {
    _showOtpVerificationBottomSheet();
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
          onResendOtp: () async {
            await _sendOtpForVerification();
          },
        );
      },
    );
  }

  Future<void> _verifyOtpAndCompleteRegistration(String otp) async {
    try {
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

      final otpVerified = await _authController.register(
        data: registrationData,
      );
      if (!mounted) return;
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

        Get.offAllNamed(AppPages.LOGIN);
      }
    } catch (e) {
      CustomToastService.showError(title: 'Error', message: '$e');
    }
  }

  void _startRegistration() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Please check email, email is not valid',
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    _sendOtpForVerification();
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
              'Create Account',
              style: TextStyle(
                color: VantageAuthTheme.text,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 18.h),
            VantagePillTextField(
              controller: _firstNameController,
              hintText: 'First Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _languageService.tr('validation_required');
                }
                return null;
              },
            ),
            SizedBox(height: 10.h),
            VantagePillTextField(
              controller: _lastNameController,
              hintText: 'Last Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _languageService.tr('validation_required');
                }
                return null;
              },
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
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [LengthLimitingTextInputFormatter(20)],
                    onChanged: (_) => _validateForm(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _languageService.tr('validation_required');
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Phone number',
                      filled: true,
                      fillColor: VantageAuthTheme.fieldFill,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        borderSide: const BorderSide(
                          color: VantageAuthTheme.fieldBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        borderSide: const BorderSide(
                          color: VantageAuthTheme.fieldBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        borderSide: const BorderSide(
                          color: VantageAuthTheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            VantagePillTextField(
              controller: _emailController,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              onChanged: (_) => _validateForm(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _languageService.tr('validation_required');
                }
                if (!_isValidEmail(value)) {
                  return 'Please check email, email is not valid';
                }
                return null;
              },
            ),
            SizedBox(height: 10.h),
            VantagePillTextField(
              controller: _passwordController,
              hintText: 'Password',
              obscureText: !_passwordVisible,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed:
                    () => setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: VantageAuthTheme.muted,
                ),
              ),
              onChanged: (_) => _validateForm(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _languageService.tr('validation_required');
                }
                if (value.length < 6) {
                  return _languageService.tr('validation_password_min_length');
                }
                return null;
              },
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
                ),
                Expanded(
                  child: Text(
                    _languageService.tr('biometric_enable_checkbox'),
                    style: TextStyle(
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
                text: 'Sign Up',
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
                  text: 'Already have an account? ',
                  style: TextStyle(
                    color: VantageAuthTheme.muted,
                    fontSize: 13.sp,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
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
              'By signing up you agree to Terms & Conditions and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VantageAuthTheme.muted, fontSize: 11.sp),
            ),
            // SizedBox(height: 6.h),
            // if (_selectedCountryCode.isNotEmpty)
            //   Text(
            //     'Selected code: $_selectedCountryCode',
            //     textAlign: TextAlign.center,
            //     style: TextStyle(color: VantageAuthTheme.muted, fontSize: 11.sp),
            //   ),
          ],
        ),
      ),
    );
  }
}
