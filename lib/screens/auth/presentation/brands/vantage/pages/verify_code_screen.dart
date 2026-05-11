import 'package:crm_app/routes/app_pages.dart';
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
            text: 'You remember your password? ',
            style: TextStyle(color: VantageAuthTheme.muted, fontSize: 13.sp),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verify Code',
            style: TextStyle(
              color: VantageAuthTheme.text,
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Please enter the code we just sent to email\n${widget.email}',
            style: TextStyle(
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
              text: 'Verify',
              isLoading: authController.isLoading,
              onPressed: authController.isLoading ? null : _verifyCode,
            );
          }),
          SizedBox(height: 12.h),
          Center(
            child: TextButton(
              onPressed: authController.isLoading ? null : _resendCode,
              child: const Text(
                'Resend Code',
                style: TextStyle(
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
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22.r),
                borderSide: const BorderSide(color: VantageAuthTheme.fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22.r),
                borderSide: const BorderSide(color: VantageAuthTheme.fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22.r),
                borderSide: const BorderSide(color: VantageAuthTheme.primary, width: 1.5),
              ),
            ),
          ),
        );
      }),
    );
  }
}

