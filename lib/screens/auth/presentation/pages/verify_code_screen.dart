import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;

  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isFormValid = false;
  String _otpCode = '';
  final LanguageService languageService = Get.find<LanguageService>();
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _addListeners();
    _validateForm();
  }

  void _addListeners() {
    for (int i = 0; i < 6; i++) {
      _controllers[i].addListener(_validateForm);
    }
  }

  void _validateForm() {
    setState(() {
      _otpCode = _controllers.map((controller) => controller.text).join();
      _isFormValid = _otpCode.length == 6;
    });
  }

  void _onCodeChanged(String value, int index) {
    if (value.length > 1 && value.length <= 6) {
      final otp = value.padRight(6, '');
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = i < otp.length ? otp[i] : '';
      }
      if (otp.length == 6) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_focusNodes[5].canRequestFocus) _focusNodes[5].requestFocus();
        });
      } else if (otp.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 50), () {
          final idx = (otp.length - 1).clamp(0, 5);
          if (_focusNodes[idx].canRequestFocus) _focusNodes[idx].requestFocus();
        });
      }
    } else if (value.length == 1) {
      if (index < 5) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_focusNodes[index + 1].canRequestFocus) {
            _focusNodes[index + 1].requestFocus();
          }
        });
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty) {
      if (index > 0) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_focusNodes[index - 1].canRequestFocus) {
            _focusNodes[index - 1].requestFocus();
          }
        });
      }
    }
  }

  void _verifyCode() {
    if (_isFormValid) {
      authController.verifyPasswordResetOTP(email: widget.email, otp: _otpCode);
    }
  }

  void _resendCode() {
    authController.requestPasswordResetOTP(email: widget.email);
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24.h),
                  _buildHeader(),
                  SizedBox(height: 40.h),
                  _buildTitle(),
                  _buildDescription(),
                  SizedBox(height: 40.h),
                  _buildCodeInput(),
                  SizedBox(height: 35.h),
                  _buildVerifyButton(),
                  SizedBox(height: 24.h),
                  _buildResendCode(),
                ],
              ),
            ),
            Obx(() {
              if (authController.isLoading) {
                return Center(child: CommonLoadingWidget(isFullScreen: true));
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppBackButton(onPressed: () => Navigator.pop(context));
  }

  Widget _buildDescription() {
    return Text(
      "${languageService.tr("verify_code_description")}\t${widget.email}",
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textGrey,
        height: 22 / 14,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      languageService.tr("verify_code_title"),
      style: AppTextStyles.heading.copyWith(
        fontSize: 31.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildCodeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50.w,
          height: 46.h,
          child: TextField(
            cursorColor: AppColors.primary,
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: index == 0 ? 6 : 1,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(index == 0 ? 6 : 1),
            ],
            onChanged: (value) => _onCodeChanged(value, index),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              height: 1.2,
            ),
            decoration: InputDecoration(
              counterText: "",
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: 13.h,
                horizontal: 14.w,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      child: Obx(
        () => ElevatedButton(
          onPressed: authController.isLoading || !_isFormValid ? null : _verifyCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.border,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            languageService.tr("verify_code_button"),
            style: AppTextStyles.button.copyWith(
              color: _isFormValid ? AppColors.whiteColor : AppColors.textGrey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendCode() {
    return Center(
      child: Column(
        children: [
          Text(
            languageService.tr("verify_code_didnt_receive"),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textGrey,
              fontSize: 14.sp,
              height: 22 / 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 7.h),
          GestureDetector(
            onTap: _resendCode,
            child: Text(
              languageService.tr("verify_code_resend"),
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.primary,
                fontSize: 14.sp,
                height: 22 / 14,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

