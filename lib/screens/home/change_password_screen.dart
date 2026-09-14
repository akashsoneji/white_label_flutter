import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../../constants/color.dart';
import '../../constants/text_styles.dart';
import 'package:crm_app/screens/auth/view_models/change_password_controller.dart';
import '../../services/language_service.dart';
import '../../utils/trl_helper.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final ChangePasswordController _changePasswordController = Get.put(
    ChangePasswordController(),
  );
  final LanguageService languageService = Get.find<LanguageService>();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Password validation regex: at least one uppercase, lowercase, digit, and special character
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]',
  );

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      await _changePasswordController.changePassword();
      // Navigation to login is handled in controller after success
    }
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return languageService.tr('change_password_current_required');
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return languageService.tr('change_password_new_required');
    }
    if (value.length < 8) {
      return languageService.tr('change_password_min_length');
    }
    if (!_passwordRegex.hasMatch(value)) {
      return languageService.tr('change_password_complexity');
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return languageService.tr('create_new_password_validation_confirm');
    }
    if (value != _changePasswordController.newPasswordController.text) {
      return languageService.tr('change_password_confirmation_mismatch');
    }
    return null;
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: SizedBox(
        height: 46.h,
        child: RTLHelper.rtlTextField(
          obscureText: obscureText,
          controller: controller,
          validator: validator,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: label,
            fillColor: AppColors.pureWhite,
            filled: true,
            hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.hint),
            labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.hint),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility : Icons.visibility_off,
                color: AppColors.hint,
              ),
              onPressed: onToggleVisibility,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: Text(
          languageService.tr('change_password'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        centerTitle: true,
      ),
      backgroundColor: AppColors.backgroundLight,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPasswordField(
                label: languageService.tr('change_password_current_password'),
                controller: _changePasswordController.currentPasswordController,
                validator: _validateCurrentPassword,
                obscureText: _obscureCurrentPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureCurrentPassword = !_obscureCurrentPassword;
                  });
                },
              ),
              _buildPasswordField(
                label: languageService.tr('create_password_new'),
                controller: _changePasswordController.newPasswordController,
                validator: _validateNewPassword,
                obscureText: _obscureNewPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
              _buildPasswordField(
                label: languageService.tr('create_new_password_confirm_password'),
                controller: _changePasswordController.confirmPasswordController,
                validator: _validateConfirmPassword,
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              SizedBox(height: 20.h),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Obx(() {
      final isLoading = _changePasswordController.isLoading;
      return SizedBox(
        width: double.infinity,
        height: 46.h,
        child: ElevatedButton(
          onPressed: isLoading ? null : _changePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            // foregroundColor: AppColors.textPrimaryLight,
            disabledBackgroundColor: AppColors.border,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child:
              isLoading
                  ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                  : Text(
                    languageService.tr('change_password'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      height: 1.71,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
        ),
      );
    });
  }
}
