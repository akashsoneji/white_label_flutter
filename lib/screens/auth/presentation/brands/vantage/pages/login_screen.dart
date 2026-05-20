import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';

import '../../../auth_form_validation.dart';
import '../widgets/vantage_auth_scaffold.dart';
import '../widgets/vantage_auth_theme.dart';
import '../widgets/vantage_controls.dart';

class VantageLoginScreen extends StatefulWidget {
  const VantageLoginScreen({super.key});

  @override
  State<VantageLoginScreen> createState() => _VantageLoginScreenState();
}

class _VantageLoginScreenState extends State<VantageLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscureText = true;
  bool _enableBiometricAfterLogin = false;
  bool _biometricAttempted = false;

  final AuthController authController = Get.find<AuthController>();
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricLogin();
    });
  }

  Future<void> _tryBiometricLogin() async {
    if (_biometricAttempted) return;
    _biometricAttempted = true;

    final enabled = await SecureStorageService.getBiometricEnabled();
    if (!enabled) return;

    final sessionValid = await SecureStorageService.isUserLoggedIn();
    if (!sessionValid) return;

    final supported = await BiometricService.instance.isDeviceSupported();
    if (!supported) return;

    final ok = await BiometricService.instance.authenticate(
      reason: languageService.tr('biometric_login_reason'),
    );
    if (!ok) return;

    Get.find<AppLockService>().markJustAuthenticated();
    await authController.checkAuthStatus();
    if (!mounted) return;
    Get.offAllNamed(AppPages.TRADING);
  }

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final errors = AuthFormValidation.validateLogin(
      languageService: languageService,
      email: email,
      password: password,
    );
    if (!AuthFormValidation.showErrorsIfAny(errors)) return;

    await authController.login(
      email: email,
      password: password,
    );

    if (_enableBiometricAfterLogin) {
      final supported = await BiometricService.instance.isDeviceSupported();
      final enrolled = await BiometricService.instance.isEnrolled();
      if (supported && enrolled) {
        final ok = await BiometricService.instance.authenticate(
          reason: languageService.tr('biometric_enable_reason'),
        );
        if (ok) {
          await SecureStorageService.setBiometricEnabled(
            true,
            userIdentifier: email,
          );
          Get.find<AppLockService>().markJustAuthenticated();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VantageAuthScaffold(
      showBack: true,
      bottom: TextButton(
        onPressed: () => Get.toNamed(AppPages.CREATE_ACCOUNT),
        child: Text.rich(
          TextSpan(
            text: "Don’t have an account? ",
            style: TextStyle(color: VantageAuthTheme.muted, fontSize: 13.sp),
            children: [
              TextSpan(
                text: 'Sign Up',
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
              'Sign In',
              style: TextStyle(
                color: VantageAuthTheme.text,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              languageService.tr('welcome_title'),
              style: TextStyle(
                color: VantageAuthTheme.muted,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 18.h),
            VantagePillTextField(
              controller: emailController,
              hintText: 'Email / Username',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
            SizedBox(height: 12.h),
            VantagePillTextField(
              controller: passwordController,
              hintText: 'Password',
              obscureText: obscureText,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscureText = !obscureText),
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: VantageAuthTheme.muted,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Align(
              alignment:
                  languageService.isRTL()
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.toNamed(AppPages.FORGOT_PASSWORD),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: VantageAuthTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _enableBiometricAfterLogin,
                  onChanged: (v) async {
                    final value = v ?? false;
                    if (!value) {
                      setState(() => _enableBiometricAfterLogin = false);
                      return;
                    }

                    final supported =
                        await BiometricService.instance.isDeviceSupported();
                    final enrolled = await BiometricService.instance.isEnrolled();
                    if (!supported || !enrolled) {
                      setState(() => _enableBiometricAfterLogin = false);
                      return;
                    }

                    if (!mounted) return;
                    setState(() => _enableBiometricAfterLogin = true);
                  },
                  activeColor: VantageAuthTheme.primary,
                ),
                Expanded(
                  child: Text(
                    languageService.tr('biometric_enable_checkbox'),
                    style: TextStyle(
                      color: VantageAuthTheme.muted,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Obx(() {
              return VantagePrimaryButton(
                text: 'Sign In',
                isLoading: authController.isLoading,
                onPressed: authController.isLoading ? null : _handleLogin,
              );
            }),
          ],
      ),
    );
  }
}

