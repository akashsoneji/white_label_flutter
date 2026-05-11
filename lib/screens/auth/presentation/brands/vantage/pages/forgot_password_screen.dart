import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  final AuthController authController = Get.find<AuthController>();
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  void dispose() {
    _emailController.dispose();
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Forgot password',
              style: TextStyle(
                color: VantageAuthTheme.text,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 18.h),
            VantagePillTextField(
              controller: _emailController,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return languageService.tr('forgot_password_enter_your_email');
                }
                if (!value.contains('@')) {
                  return languageService.tr(
                    'forgot_password_Please_enter_a_valid_email',
                  );
                }
                return null;
              },
            ),
            SizedBox(height: 14.h),
            Obx(() {
              return VantagePrimaryButton(
                text: 'Send OTP',
                isLoading: authController.isLoading,
                onPressed: authController.isLoading
                    ? null
                    : () {
                        if (_formKey.currentState?.validate() != true) return;
                        authController.requestPasswordResetOTP(
                          email: _emailController.text.trim(),
                        );
                      },
              );
            }),
          ],
        ),
      ),
    );
  }
}

