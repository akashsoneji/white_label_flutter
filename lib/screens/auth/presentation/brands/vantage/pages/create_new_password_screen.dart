import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../widgets/vantage_auth_scaffold.dart';
import '../widgets/vantage_auth_theme.dart';
import '../widgets/vantage_controls.dart';

class VantageCreateNewPasswordScreen extends StatefulWidget {
  const VantageCreateNewPasswordScreen({super.key});

  @override
  State<VantageCreateNewPasswordScreen> createState() =>
      _VantageCreateNewPasswordScreenState();
}

class _VantageCreateNewPasswordScreenState
    extends State<VantageCreateNewPasswordScreen> {
  final AuthController authController = Get.find<AuthController>();
  final LanguageService languageService = Get.find<LanguageService>();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String otp = '';
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    email = (args['email'] ?? '').toString();
    otp = (args['otp'] ?? '').toString();
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleResetPassword() {
    if (_formKey.currentState?.validate() != true) return;
    authController.resetPasswordWithOTP(
      email: email,
      otp: otp,
      password: passwordController.text.trim(),
      passwordConfirmation: confirmPasswordController.text.trim(),
    );
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
              'Create new Password',
              style: TextStyle(
                color: VantageAuthTheme.text,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Your new password must be different from\nprevious password.',
              style: TextStyle(
                color: VantageAuthTheme.muted,
                fontSize: 13.sp,
                height: 1.3,
              ),
            ),
            SizedBox(height: 18.h),
            VantagePillTextField(
              controller: passwordController,
              hintText: 'Password',
              obscureText: obscurePassword,
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.isDarkMode ? Colors.white : VantageAuthTheme.muted,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return languageService.tr('validation_required');
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            SizedBox(height: 12.h),
            VantagePillTextField(
              controller: confirmPasswordController,
              hintText: 'Confirm Password',
              obscureText: obscureConfirmPassword,
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => obscureConfirmPassword = !obscureConfirmPassword,
                ),
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.isDarkMode ? Colors.white : VantageAuthTheme.muted,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            SizedBox(height: 18.h),
            Obx(() {
              return VantagePrimaryButton(
                text: languageService.tr('create_password_reset_password'),
                isLoading: authController.isLoading,
                onPressed: authController.isLoading ? null : _handleResetPassword,
              );
            }),
          ],
        ),
      ),
    );
  }
}

