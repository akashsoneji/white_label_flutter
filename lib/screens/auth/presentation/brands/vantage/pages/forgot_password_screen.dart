import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../auth_form_validation.dart';
import '../widgets/vantage_auth_theme.dart';
import '../widgets/vantage_auth_scaffold.dart';
import '../widgets/vantage_controls.dart';

class VantageForgotPasswordScreen extends StatefulWidget {
  const VantageForgotPasswordScreen({super.key});

  @override
  State<VantageForgotPasswordScreen> createState() =>
      _VantageForgotPasswordScreenState();
}

class _VantageForgotPasswordScreenState extends State<VantageForgotPasswordScreen> {
  final _emailController = TextEditingController();

  final AuthController authController = Get.find<AuthController>();
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    final email = _emailController.text.trim();
    final errors = AuthFormValidation.validateForgotPassword(
      languageService: languageService,
      email: email,
    );
    if (!AuthFormValidation.showErrorsIfAny(errors)) return;
    authController.requestPasswordResetOTP(email: email);
  }

  @override
  Widget build(BuildContext context) {
    return VantageAuthScaffold(
      bottom: TextButton(
        onPressed: () => Get.offAllNamed(AppPages.LOGIN),
        child: Text.rich(
          TextSpan(
            text: languageService.tr('forgot_password_screen_remember_password'),
            style: TextStyle(color: VantageAuthTheme.muted, fontSize: 13.sp),
            children: [
              TextSpan(
                text: languageService.tr('login_screen_sign_in'),
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
              languageService.tr('forgot_password_screen_title'),
              style: TextStyle(
                color: VantageAuthTheme.text,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 18.h),
            VantagePillTextField(
              controller: _emailController,
              hintText: languageService.tr('forgot_password_screen_email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 14.h),
            Obx(() {
              return VantagePrimaryButton(
                text: languageService.tr('forgot_password_screen_send_otp'),
                isLoading: authController.isLoading,
                onPressed: authController.isLoading ? null : _sendOtp,
              );
            }),
          ],
      ),
    );
  }
}

