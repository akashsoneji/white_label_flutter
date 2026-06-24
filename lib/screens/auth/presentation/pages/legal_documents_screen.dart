import 'dart:convert';

import 'package:crm_app/utils/trl_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/routes/app_pages.dart';
import '../auth_screen_theme.dart';
import '../brands/vantage/widgets/vantage_auth_scaffold.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';

import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/otp_modal.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/utils/agreement_launcher.dart';

class LegalDocumentsScreen extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const LegalDocumentsScreen({super.key, required this.registrationData});

  @override
  State<LegalDocumentsScreen> createState() => _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends State<LegalDocumentsScreen> {
  bool _isAgreementChecked = false;
  bool _isFormValid = false;
  final LanguageService languageService = Get.find<LanguageService>();
  AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    print("object json is ${jsonEncode(widget.registrationData)}");
    _validateForm();
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _isAgreementChecked;
    });
  }

  void _submitDocuments() {
    if (_isFormValid) {
      _createAccount();
    }
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageService.tr("legal_documents_title"),
          style: AppTextStyles.heading,
        ),
        SizedBox(height: 24.h),
        _buildAgreementCheckbox(),
        SizedBox(height: 35.h),
        _buildDocumentsList(),
        SizedBox(height: 32.h),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FlavorConfig.isVantage()) {
      return VantageAuthScaffold(
        bottom: _buildSubmitButton(),
        child: _buildFormContent(),
      );
    }

    return Scaffold(
      backgroundColor: AuthScreenTheme.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: _buildFormContent(),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildSubmitButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        children: [
          AppBackButton(onPressed: () => Navigator.pop(context)),
          SizedBox(width: 16.w),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _progressBar(active: true),
                SizedBox(width: 8.w),
                _progressBar(active: true),
                SizedBox(width: 8.w),
                _progressBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar({bool active = false}) {
    return Container(
      width: 60.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.border,
      ),
    );
  }

  Widget _buildAgreementCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 25.w,
          height: 25.h,
          child: Checkbox(
            value: _isAgreementChecked,
            onChanged: (value) {
              setState(() {
                _isAgreementChecked = value ?? false;
                _validateForm();
              });
            },
            activeColor: AppColors.whiteColor,
            checkColor: AppColors.primary,
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 3.h, left: 5.h),
            child: Text(
              languageService.tr("legal_documents_subtitle"),
              style: TextStyle(
                fontSize: 16,
                height: 22 / 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16.h),
        _buildDocumentItem(
          languageService.tr("legal_documents_customer_agreement"),
          onTap: AgreementLauncher.openTerms,
        ),
        SizedBox(height: 5.h),
        _buildDocumentItem(
          languageService.tr("legal_documents_privacy_policy"),
          onTap: AgreementLauncher.openPrivacy,
        ),
      ],
    );
  }

  Widget _buildDocumentItem(String title, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
        child: Row(
          children: [
            Container(
              width: 4.w,
              height: 4.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.link.copyWith(
                  decoration: TextDecoration.none,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: RTLHelper.rtlButton(
        height: 46.h,
        text: languageService.tr("common_submit"),
        onPressed: _isFormValid ? _submitDocuments : null,
        backgroundColor: AppColors.primary,
        foregroundColor: _isFormValid ? AppColors.whiteColor : AppColors.textGrey,
      ),
    );
  }

  Future<void> _createAccount() async {
    try {
      final registrationSuccess = await authController.register(
        data: widget.registrationData,
      );

      if (registrationSuccess) {
        await _sendOTPForVerification();
      } else {
        final errorMessage =
            authController.errorMessage.isNotEmpty
                ? authController.errorMessage
                : 'Registration failed. Please check your information and try again.';
        _showError(errorMessage);
      }
    } catch (e) {
      _hideLoadingDialog();
      _showError('Registration failed: $e');
    }
  }

  Future<void> _sendOTPForVerification() async {
    try {
      _showOtpVerificationBottomSheet();
    } catch (e) {
      _hideLoadingDialog();
      _showError('Failed to send OTP: $e');
    }
  }

  Future<void> _resendOTP(BuildContext modalContext) async {
    try {
      final resendData = Map<String, dynamic>.from(widget.registrationData);
      resendData.remove('otp');
      resendData['register_event_type'] = 'register';

      _showLoadingDialog('Resending OTP...');

      final registrationSuccess = await authController.register(data: resendData);

      _hideLoadingDialog();

      if (registrationSuccess) {
        _clearOtpFields?.call();
        CustomToastService.showSuccess(
          title: 'Success',
          message: 'OTP resent successfully. Please check your email.',
        );
      } else {
        final errorMessage =
            authController.errorMessage.isNotEmpty
                ? authController.errorMessage
                : 'Failed to resend OTP. Please try again.';
        _showError(errorMessage);
      }
    } catch (e) {
      _hideLoadingDialog();
      _showError('Failed to resend OTP: $e');
    }
  }

  void Function()? _clearOtpFields;

  void _showOtpVerificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder:
          (context) => OtpModal(
            email: widget.registrationData['email'],
            isEmailVerification: true,
            otpLength: 6,
            onModalReady: (clearFields) {
              _clearOtpFields = clearFields;
            },
            onOtpSubmitted: (otp) async {
              await _verifyOtpAndCompleteRegistration(otp, context);
            },
            onResendOtp: () async {
              await _resendOTP(context);
            },
          ),
    );
  }

  Future<void> _verifyOtpAndCompleteRegistration(
    String otp,
    BuildContext modalContext,
  ) async {
    try {
      _showLoadingDialog('Verifying OTP...');
      widget.registrationData["register_event_type"] = "verifyOtp";
      widget.registrationData["otp"] = otp;

      final otpVerified = await authController.registerWithOTPVerification(
        data: widget.registrationData,
      );

      _hideLoadingDialog();

      if (otpVerified) {
        Navigator.of(modalContext).pop();
        Get.toNamed(AppPages.ACCOUNT_CREATED);
      } else {
        _clearOtpFields?.call();
        final errorMessage =
            authController.errorMessage.isNotEmpty
                ? authController.errorMessage
                : 'OTP verification failed. Please try again.';
        _showError(errorMessage);
      }
    } catch (e) {
      _hideLoadingDialog();
      _showError('OTP verification failed: $e');
    }
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
}

