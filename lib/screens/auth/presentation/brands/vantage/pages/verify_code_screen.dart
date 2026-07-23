import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../widgets/vantage_auth_scaffold.dart';
import '../widgets/vantage_auth_theme.dart';
import '../widgets/vantage_controls.dart';

class VantageVerifyCodeScreen extends StatefulWidget {
  final String email;

  const VantageVerifyCodeScreen({super.key, required this.email});

  @override
  State<VantageVerifyCodeScreen> createState() => _VantageVerifyCodeScreenState();
}

class _VantageVerifyCodeScreenState extends State<VantageVerifyCodeScreen> {
  static const int otpLength = 6; // change to 4 later if needed

  final LanguageService languageService = Get.find<LanguageService>();
  final AuthController authController = Get.find<AuthController>();

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  bool _isFormValid = false;
  String _otpCode = '';

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(otpLength, (_) => FocusNode());
    for (final c in _controllers) {
      c.addListener(_validateForm);
    }
    _validateForm();
  }

  void _validateForm() {
    setState(() {
      _otpCode = _controllers.map((c) => c.text).join();
      _isFormValid = _otpCode.length == otpLength;
    });
  }

  void _onCodeChanged(String value, int index) {
    if (value.length > 1 && value.length <= otpLength) {
      final otp = value.padRight(otpLength, '');
      for (int i = 0; i < otpLength; i++) {
        _controllers[i].text = i < otp.length ? otp[i] : '';
      }
      final next = (otpLength - 1).clamp(0, otpLength - 1);
      Future.delayed(const Duration(milliseconds: 30), () {
        if (_focusNodes[next].canRequestFocus) _focusNodes[next].requestFocus();
      });
      return;
    }

    if (value.length == 1) {
      if (index < otpLength - 1) {
        Future.delayed(const Duration(milliseconds: 30), () {
          if (_focusNodes[index + 1].canRequestFocus) {
            _focusNodes[index + 1].requestFocus();
          }
        });
      } else {
        _focusNodes[index].unfocus();
      }
      return;
    }

    if (value.isEmpty && index > 0) {
      Future.delayed(const Duration(milliseconds: 30), () {
        if (_focusNodes[index - 1].canRequestFocus) {
          _focusNodes[index - 1].requestFocus();
        }
      });
    }
  }

  void _verifyCode() {
    if (!_isFormValid) return;
    authController.verifyPasswordResetOTP(email: widget.email, otp: _otpCode);
  }

  void _resendCode() {
    authController.requestPasswordResetOTP(email: widget.email);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VantageAuthScaffold(
      bottom: TextButton(
        onPressed: () => Get.offAllNamed(AppPages.LOGIN),
        child: Text.rich(
          TextSpan(
            text: languageService.tr('verify_code_bottom_remember_password'),
            style: AppTextStyles.bodyText.copyWith(color: VantageAuthTheme.muted, fontSize: 13.sp),
            children: [
              TextSpan(
                text: languageService.tr('login_screen_sign_in'),
                style: AppTextStyles.bodyText.copyWith(
                  color: VantageAuthTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            languageService.tr('verify_code_screen_title'),
            style: AppTextStyles.bodyText.copyWith(
              color: VantageAuthTheme.text,
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            // Email is appended by interpolation; the base string is translated
            // via the en.json key and the runtime email is concatenated.
            languageService.tr('verify_code_screen_subtitle')
                .replaceFirst('{email}', widget.email),
            style: AppTextStyles.bodyText.copyWith(
              color: VantageAuthTheme.muted,
              fontSize: 13.sp,
              height: 1.3,
            ),
          ),
          SizedBox(height: 18.h),
          _OtpRow(
            controllers: _controllers,
            focusNodes: _focusNodes,
            onChanged: _onCodeChanged,
          ),
          SizedBox(height: 16.h),
          Obx(() {
            return VantagePrimaryButton(
              text: languageService.tr('verify_code_screen_verify'),
              isLoading: authController.isLoading,
              onPressed: authController.isLoading ? null : _verifyCode,
            );
          }),
          SizedBox(height: 12.h),
          Center(
            child: TextButton(
              onPressed: authController.isLoading ? null : _resendCode,
              child: Text(
                languageService.tr('verify_code_screen_resend'),
                style: AppTextStyles.bodyText.copyWith(
                  color: VantageAuthTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(String value, int index) onChanged;

  const _OtpRow({
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(controllers.length, (index) {
        return SizedBox(
          width: 44.w,
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: index == 0 ? controllers.length : 1,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(index == 0 ? controllers.length : 1),
            ],
            onChanged: (v) => onChanged(v, index),
            decoration: VantageAuthTheme.pillDecoration(
              counterText: '',
              contentPadding: EdgeInsets.symmetric(vertical: 12.h),
            ),
          ),
        );
      }),
    );
  }
}

