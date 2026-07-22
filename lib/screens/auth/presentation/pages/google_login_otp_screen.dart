import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/otp_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class GoogleLoginOtpScreen extends StatefulWidget {
  const GoogleLoginOtpScreen({super.key});

  @override
  State<GoogleLoginOtpScreen> createState() => _GoogleLoginOtpScreenState();
}

class _GoogleLoginOtpScreenState extends State<GoogleLoginOtpScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final LanguageService _languageService = Get.find<LanguageService>();

  late final String _email;

  @override
  void initState() {
    super.initState();
    _email = Get.arguments as String? ?? '';
  }

  void _showOtpModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OtpModal(
        email: _email,
        onOtpSubmitted: (code) {
          Get.back();
          _authController.verifyGoogleLoginOtp(email: _email, otpCode: code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  Text(
                    _languageService.tr('two_factor_login_title'),
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    '${_languageService.tr('two_factor_login_description')} $_email',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      color: AppColors.textGrey,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 40.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: _showOtpModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _languageService.tr('two_factor_verify_login'),
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.whiteColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Obx(() {
              if (_authController.isLoading) {
                return Center(
                  child: CommonLoadingWidget(isFullScreen: true),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppBackButton(onPressed: () => Get.back());
  }
}