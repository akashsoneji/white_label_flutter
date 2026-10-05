import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';
import 'package:crm_app/services/chart_webview_prewarmer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool obscureText = true;
  bool _enableBiometricAfterLogin = false;
  bool _biometricAttempted = false;

  // Get the AuthController
  final AuthController authController = Get.find<AuthController>();

  // Get the LanguageService
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricLogin();

      // Pre-warm the chart WebView in background while user logs in
      if (!FlavorConfig.instance.useNewChart) {
        final symService =
            Get.isRegistered<SymbolSelectionService>()
                ? Get.find<SymbolSelectionService>()
                : Get.put(SymbolSelectionService());

        symService.ensureDefault().then((_) {
          final sym =
              symService.currentSymbol.isNotEmpty
                  ? symService.currentSymbol
                  : 'XAUUSD';
          ChartWebViewPrewarmer.instance.prewarm(symbol: sym);
        });
      }
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

  // Validation states
  bool isEmailValid = false;
  bool isPasswordValid = false;

  // Validation methods
  bool _validateEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      // Commit the autofill context BEFORE calling login — authController.login
      // navigates away on success (Get.offAllNamed), which disposes this
      // screen and kills the chance for Google / iCloud to show the save
      // prompt. Doing it here, while the AutofillGroup is still alive and the
      // fields hold the user-entered credentials, is what makes the OS offer
      // "Save password?". If login then fails and user retries with a correct
      // password, the OS offers "Update password?" — standard behaviour.
      TextInput.finishAutofillContext();

      await authController.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
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
              userIdentifier: emailController.text.trim(),
            );
            Get.find<AppLockService>().markJustAuthenticated();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Form(
                              key: _formKey,
                              child: AutofillGroup(
                                child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: 16.h),
                                  Center(
                                    child: Container(
                                      height: 80.w,
                                      width: 80.w,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(30),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: EdgeInsets.all(14.w),
                                      child: BrandLogo(
                                        source:
                                            FlavorConfig.instance.appIconPath,
                                        isCircle: true,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(top: 70.h),
                                    child: Text(
                                      languageService.tr("welcome_title"),
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  RTLHelper.rtlTextField(
                                    controller: emailController,
                                    labelText: languageService.tr(
                                      "register_email",
                                    ),
                                    hintText: languageService.tr(
                                      "register_email",
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                      AutofillHints.email,
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return languageService.tr(
                                          "validation_email_required",
                                        );
                                      }
                                      if (!_validateEmail(value)) {
                                        return languageService.tr(
                                          "validation_email_invalid",
                                        );
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        isEmailValid = _validateEmail(value);
                                      });
                                    },
                                  ),
                                  SizedBox(height: 16.h),
                                  RTLHelper.rtlTextField(
                                    controller: passwordController,
                                    hintText: languageService.tr(
                                      "register_password",
                                    ),
                                    obscureText: obscureText,
                                    labelText: languageService.tr(
                                      "register_password",
                                    ),
                                    keyboardType: TextInputType.visiblePassword,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onFieldSubmitted: (_) => _handleLogin(),
                                    suffixIcon: IconButton(
                                      icon: SvgPicture.asset(
                                        obscureText
                                            ? "assets/svg/eye-slash.svg"
                                            : "assets/svg/eye_icon.svg",
                                        color: AppColors.textPrimary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          obscureText = !obscureText;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return languageService.tr(
                                          "validation_password_required",
                                        );
                                      }
                                      if (!_validatePassword(value)) {
                                        return languageService.tr(
                                          "validation_password_min_length",
                                        );
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        isPasswordValid = _validatePassword(
                                          value,
                                        );
                                      });
                                    },
                                  ),
                                  SizedBox(height: 5.h),
                                  Align(
                                    alignment:
                                        languageService.isRTL()
                                            ? Alignment.centerLeft
                                            : Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Get.toNamed(AppPages.FORGOT_PASSWORD);
                                      },
                                      child: Text(
                                        languageService.tr(
                                          "login_forgot_password",
                                        ),
                                        style: AppTextStyles.bodyText.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 35.h),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _enableBiometricAfterLogin,
                                        onChanged: (v) async {
                                          final value = v ?? false;
                                          if (!value) {
                                            setState(
                                              () =>
                                                  _enableBiometricAfterLogin =
                                                      false,
                                            );
                                            return;
                                          }

                                          final supported =
                                              await BiometricService.instance
                                                  .isDeviceSupported();
                                          final enrolled =
                                              await BiometricService.instance
                                                  .isEnrolled();
                                          if (!supported || !enrolled) {
                                            setState(
                                              () =>
                                                  _enableBiometricAfterLogin =
                                                      false,
                                            );
                                            return;
                                          }

                                          if (!mounted) return;
                                          setState(
                                            () =>
                                                _enableBiometricAfterLogin =
                                                    true,
                                          );
                                        },
                                        activeColor: AppColors.primary,
                                      ),
                                      Expanded(
                                        child: Text(
                                          languageService.tr(
                                            'biometric_enable_checkbox',
                                          ),
                                          style: AppTextStyles.bodyText
                                              .copyWith(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textGrey,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  Obx(() {
                                    final isLoading = authController.isLoading;
                                    return ElevatedButton(
                                      onPressed:
                                          isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        minimumSize: Size(
                                          double.infinity,
                                          40.h,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        languageService.tr("login_button"),
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              AppColors.isDarkMode
                                                  ? AppColors.textPrimaryLight
                                                  : AppColors.textPrimaryDark,
                                        ),
                                      ),
                                    );
                                  }),
                                  SizedBox(height: 16.h),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        Get.toNamed(AppPages.CREATE_ACCOUNT);
                      },
                      child: Text.rich(
                        TextSpan(
                          text:
                              "${languageService.tr("login_no_account_login")} ",
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textGrey,
                          ),
                          children: [
                            TextSpan(
                              text: languageService.tr("login_register"),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Obx(
              () =>
                  authController.isLoading
                      ? Center(child: CommonLoadingWidget(isFullScreen: true))
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
