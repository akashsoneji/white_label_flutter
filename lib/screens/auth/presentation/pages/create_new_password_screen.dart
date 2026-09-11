import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key});

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final AuthController authController = Get.find<AuthController>();
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
    email = args['email'] ?? '';
    otp = args['otp'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButton(onPressed: () => Navigator.pop(context)),
                SizedBox(height: 24.h),
                Text(
                  Get.find<LanguageService>().tr(
                    'create_new_password_screen_create_new_password',
                  ),
                  style: AppTextStyles.bodyText.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  Get.find<LanguageService>().tr(
                    'create_new_password_screen_your_new_password_must_be_different',
                  ),
                  style: AppTextStyles.bodyText.copyWith(fontSize: 16),
                  textAlign: TextAlign.start,
                ),
                SizedBox(height: 40),
                RTLHelper.rtlTextField(
                  controller: passwordController,
                  labelText: Get.find<LanguageService>().tr(
                    'create_new_password_new_password_label',
                  ),
                  hintText: Get.find<LanguageService>().tr(
                    'create_new_password_screen_enter_new_password',
                  ),
                  obscureText: obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return Get.find<LanguageService>().tr(
                        'validation_password_required',
                      );
                    }
                    if (value.length < 8) {
                      return Get.find<LanguageService>().tr(
                        'create_new_password_validation_length',
                      );
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                RTLHelper.rtlTextField(
                  controller: confirmPasswordController,
                  labelText: Get.find<LanguageService>().tr(
                    'create_new_password_confirm_password',
                  ),
                  hintText: Get.find<LanguageService>().tr(
                    'create_new_password_screen_confirm_new_password',
                  ),
                  obscureText: obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return Get.find<LanguageService>().tr(
                        'create_new_password_validation_confirm',
                      );
                    }
                    if (value != passwordController.text) {
                      return Get.find<LanguageService>().tr(
                        'create_account_validation_password_match',
                      );
                    }
                    return null;
                  },
                ),
                SizedBox(height: 40),
                Obx(() {
                  final isLoading = authController.isLoading;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleResetPassword,
                      child:
                          isLoading
                              ? ButtonLoadingWidget(
                                size: 20.0,
                                color: AppColors.whiteColor,
                              )
                              : Text(
                                Get.find<LanguageService>().tr(
                                  'create_password_reset_password',
                                ),
                              ),
                    ),
                  );
                }),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleResetPassword() {
    if (_formKey.currentState!.validate()) {
      authController.resetPasswordWithOTP(
        email: email,
        otp: otp,
        password: passwordController.text.trim(),
        passwordConfirmation: confirmPasswordController.text.trim(),
      );
    }
  }
}

