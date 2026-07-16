import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/otp_modal.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';


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
  IsoCode? _selectedIsoCode;
  // ISO-3166-1 alpha-2 country code (e.g. "IN", "US") — captured from
  // country_picker's `Country.countryCode` so we can pass it to the API
  // as both `country` (uppercase) and `country_slug` (lowercase).
  String _selectedCountryIso = '';
  // Max number of national digits allowed for the selected country.
  int _maxPhoneDigits = 15;
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
          _isPhoneValid() &&
          _isValidEmail(_emailController.text.trim()) &&
          _passwordController.text.isNotEmpty;
    });
  }

  // ---- Country-aware phone helpers --------------------------------------

  /// Maps a 2-letter ISO country code (from country_picker) to an [IsoCode].
  IsoCode? _isoFromCountryCode(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return null;
    final upper = countryCode.toUpperCase();
    for (final iso in IsoCode.values) {
      if (iso.name == upper) return iso;
    }
    return null;
  }

  /// Computes the max number of national digits for the given country so the
  /// input can be capped per-country (e.g. 10 for IN, 9 for many others).
  int _maxDigitsForIso(IsoCode? iso) {
    if (iso == null) return 15;
    final lengths = metadataLenghtsByIsoCode[iso];
    if (lengths == null) return 15;
    final all = <int>[
      ...lengths.general,
      ...lengths.mobile,
      ...lengths.fixedLine,
    ];
    if (all.isEmpty) return 15;
    return all.reduce((a, b) => a > b ? a : b);
  }

  /// Returns only the digits currently entered in the phone field.
  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

  /// Country-aware validity of the entered phone number.
  bool _isPhoneValid() {
    final digits = _phoneDigits;
    if (digits.isEmpty) return false;
    final iso = _selectedIsoCode;
    if (iso == null) return digits.length >= 6 && digits.length <= 15;
    try {
      final number = PhoneNumber.parse(digits, destinationCountry: iso);
      if (number.isValid(type: PhoneNumberType.mobile) || number.isValid()) {
        return true;
      }
    } catch (_) {}
    // Fallback: If library parsing fails or says it is invalid (e.g. mock/test numbers or unassigned area codes),
    // we accept it if the length of the digits is reasonable (e.g., between 7 and 15 digits).
    return digits.length >= 7 && digits.length <= 15;
  }

  /// Formats the entered national number for display (country specific).
  void _formatPhoneInput() {
    final iso = _selectedIsoCode;
    final digits = _phoneDigits;
    if (iso == null || digits.isEmpty) return;
    try {
      final formatted =
          PhoneNumber.parse(digits, destinationCountry: iso).formatNsn();
      if (formatted.isNotEmpty && formatted != _phoneController.text) {
        _phoneController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    } catch (_) {
      // Keep raw input if it cannot be formatted yet.
    }
  }

  void _applyCountry({
    required String phoneCode,
    required String flagEmoji,
    required String countryIso2,
  }) {
    final iso = _isoFromCountryCode(countryIso2);
    setState(() {
      _selectedCountryCode = "+$phoneCode";
      _selectedCountryFlag = "$flagEmoji +$phoneCode";
      _selectedIsoCode = iso;
      // country_picker exposes the ISO-3166-1 alpha-2 code via
      // `Country.countryCode` (already uppercase, e.g. "IN", "US").
      // Store it as-provided so callers can build both `country`
      // (uppercase) and `country_slug` (lowercase) for the API.
      _selectedCountryIso = countryIso2;
      _maxPhoneDigits = _maxDigitsForIso(iso);
    });
    // Re-trim/format any existing input to the newly selected country.
    final digits = _phoneDigits;
    if (digits.length > _maxPhoneDigits) {
      _phoneController.text = digits.substring(0, _maxPhoneDigits);
    }
    _formatPhoneInput();
    _validateForm();
  }

  /// Builds the phone payload for the register API call. The ISO country
  /// code is exposed by `country_picker` via `Country.countryCode` —
  /// already in ISO-3166-1 alpha-2 form (e.g. "IN", "US"). We pass it
  /// through as `country` (uppercase) and lowercase it for `country_slug`.
  Map<String, String> _buildPhonePayload() {
    final digits = _phoneDigits;
    final isoUpper = _selectedCountryIso.toUpperCase();
    return <String, String>{
      'mobile': digits,
      'national': digits,
      'country_code': _selectedCountryCode,
      'country': isoUpper,
      'country_slug': _selectedCountryIso.toLowerCase(),
    };
  }

  // -----------------------------------------------------------------------

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
      final phonePayload = _buildPhonePayload();
      final registrationData = {
        "first_name": _firstNameController.text.trim(),
        "last_name": _lastNameController.text.trim(),
        "email": _emailController.text.trim(),
        "mobile": phonePayload["mobile"],
        "phone_number": phonePayload["national"],
        "country_code": phonePayload["country_code"],
        "register_country_code": phonePayload["country_code"],
        "country": phonePayload["country"],
        "country_slug": phonePayload["country_slug"],
        "password": _passwordController.text.trim(),
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

    final phonePayload = _buildPhonePayload();
    final registrationData = {
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "email": email,
      "mobile": phonePayload["mobile"],
      "phone_number": phonePayload["national"],
      "country_code": phonePayload["country_code"],
      "register_country_code": phonePayload["country_code"],
      "country": phonePayload["country"],
      "country_slug": phonePayload["country_slug"],
      "password": _passwordController.text.trim(),
      "otp_verification_type": "email",
      "register_event_type": "register",
      "accept_terms": true,
    };

    final referrerCode = _referrerController.text.trim();
    if (referrerCode.isNotEmpty) {
      registrationData["ib_affiliate_refcode"] = referrerCode;
    }

    Get.toNamed(
      AppPages.LEGAL_DOCUMENTS,
      arguments: registrationData,
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
          prefixIcon: Icon(Icons.search, color: AppColors.textPrimary),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.placeholderSoft,
            ),
          ),
        ),
      ),
      onSelect: (Country country) {
        _applyCountry(
          phoneCode: country.phoneCode,
          flagEmoji: country.flagEmoji,
          countryIso2: country.countryCode,
        );
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
          (country) =>
              country.countryCode.toUpperCase() == countryCode.toUpperCase(),
          orElse: () => countries.first,
        );

        _applyCountry(
          phoneCode: deviceCountry.phoneCode,
          flagEmoji: deviceCountry.flagEmoji,
          countryIso2: deviceCountry.countryCode,
        );
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
        // _buildTextField(
        //   controller: _referrerController,
        //   label: 'Referrer Code',
        //   keyboardType: TextInputType.text,
        //   maxLength: 30,
        // ),
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
              checkColor: AppColors.pureWhite,
              side: BorderSide(color: AppColors.border),
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
              color: AppColors.primary,
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-()]')),
                _PhoneDigitsLimitFormatter(() => _maxPhoneDigits),
              ],
              onChanged: (_) => _formatPhoneInput(),
              decoration: InputDecoration(
                labelText: _languageService.tr("register_phone"),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.isEmpty) {
                  return _languageService.tr('validation_required');
                }
                if (!_isPhoneValid()) {
                  return _languageService.tr('create_account_validation_phone');
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
    return AppBackButton(onPressed: () => Navigator.pop(context));
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
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
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

/// Limits the phone field to a country-specific number of DIGITS while still
/// allowing separator characters (space, dash, parentheses) added by formatting.
class _PhoneDigitsLimitFormatter extends TextInputFormatter {
  _PhoneDigitsLimitFormatter(this.maxDigits);

  final int Function() maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= maxDigits()) {
      return newValue;
    }
    return oldValue;
  }
}
