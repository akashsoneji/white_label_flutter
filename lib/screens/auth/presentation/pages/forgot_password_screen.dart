import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/screens/auth/presentation/auth_form_validation.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: '');
  final AuthController authController = Get.find<AuthController>();
  final LanguageService languageService = Get.find<LanguageService>();

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
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 24.h, left: 24.0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _buildHeader(),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: BrandLogo(
                                      source: FlavorConfig.effectiveLogo,
                                      color: null,
                                      height: 100.h,
                                      width: 120.w,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(top: 70.h),
                                    child: Text(
                                      languageService.tr("forgot_password_title"),
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  RTLHelper.rtlTextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return languageService.tr(
                                          'forgot_password_enter_your_email',
                                        );
                                      }
                                      if (!value.contains('@')) {
                                        return languageService.tr(
                                          "forgot_password_Please_enter_a_valid_email",
                                        );
                                      }
                                      return null;
                                    },
                                    labelText: languageService.tr(
                                      "forgot_password_email",
                                    ),
                                  ),
                                  SizedBox(height: 35.h),
                                  Obx(() {
                                    return ElevatedButton(
                                      onPressed:
                                          authController.isLoading ? null : _sendOtp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        minimumSize: Size(double.infinity, 40.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        languageService.tr(
                                          "forgot_password_send_otp",
                                        ),
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }),
                                  SizedBox(height: 150.h),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Center(
                    child: RichText(
                      text: TextSpan(
                        text: languageService.tr(
                          "forgot_password_remember_password",
                        ),
                        style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 14.sp),
                        children: [
                          TextSpan(
                            text: languageService.tr("forgot_password_login"),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Obx(
              () => authController.isLoading
                  ? Center(child: CommonLoadingWidget(isFullScreen: true))
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppBackButton(onPressed: () => Navigator.pop(context));
  }
}

