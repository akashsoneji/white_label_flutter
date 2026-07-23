import 'package:cached_network_image/cached_network_image.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/more/view_models/two_factor_auth_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/otp_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  final TwoFactorAuthController _controller = Get.put(TwoFactorAuthController());
  final LanguageService _languageService = Get.find<LanguageService>();

  void _showSetupOtpModal() {
    _controller.onOtpChanged('');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpModal(
        email: _languageService.tr('two_factor_authentication'),
        onOtpSubmitted: (code) {
          Get.back();
          _controller.onOtpChanged(code);
          _controller.verifySetup();
        },
      ),
    );
  }

  void _showDisableOtpModal() {
    _controller.onOtpChanged('');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OtpModal(
        email: _languageService.tr('two_factor_authentication'),
        onOtpSubmitted: (code) {
          Get.back();
          _controller.onOtpChanged(code);
          _controller.disable();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: Text(
          _languageService.tr('two_factor_authentication'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppBackButton(onPressed: () => Get.back(closeOverlays: true),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Obx(() {
            switch (_controller.uiState) {
              case TwoFactorAuthUiState.disabled:
                return _buildDisabledState();
              case TwoFactorAuthUiState.setup:
                return _buildSetupState();
              case TwoFactorAuthUiState.enabled:
                return _buildEnabledState();
              case TwoFactorAuthUiState.disabling:
                return _buildDisablingState();
            }
          }),
          Obx(() {
            if (_controller.isLoading) {
              return Center(child: CommonLoadingWidget(isFullScreen: true));
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildDisabledState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageService.tr('two_factor_subtitle'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              color: AppColors.textGrey,
              height: 1.5,
            ),
          ),
          SizedBox(height: 24.h),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _languageService.tr('two_factor_setup_title'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _languageService.tr('two_factor_setup_description'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.textGrey,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20.h),
                _primaryButton(
                  label: _languageService.tr('two_factor_generate_qr'),
                  onPressed: _controller.generateQr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupState() {
    final data = _controller.generateData;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageService.tr('two_factor_scan_instruction'),
            style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textGrey),
          ),
          SizedBox(height: 20.h),
          if (data != null && data.qrCodeUrl.isNotEmpty) ...[
            Center(
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: CachedNetworkImage(
                  imageUrl: data.qrCodeUrl,
                  width: 200.w,
                  height: 200.w,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => SizedBox(
                    width: 200.w,
                    height: 200.w,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.qr_code_2,
                    size: 80.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              _languageService.tr('two_factor_manual_code'),
              style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey),
            ),
            SizedBox(height: 8.h),
            _buildSecretBox(data.secretKey),
            SizedBox(height: 24.h),
          ],
          _primaryButton(
            label: _languageService.tr('two_factor_verify_enable'),
            onPressed: _showSetupOtpModal,
          ),
          SizedBox(height: 12.h),
          _secondaryButton(
            label: _languageService.tr('cancel'),
            onPressed: _controller.cancelSetup,
          ),
        ],
      ),
    );
  }

  Widget _buildEnabledState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageService.tr('two_factor_subtitle'),
            style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textGrey),
          ),
          SizedBox(height: 24.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.quickActionGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.quickActionGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.quickActionGreen,
                  size: 22.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _languageService.tr('two_factor_enabled_status'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.quickActionGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          _outlineButton(
            label: _languageService.tr('two_factor_disable'),
            onPressed: _showDisableOtpModal,
          ),
        ],
      ),
    );
  }

  Widget _buildDisablingState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageService.tr('two_factor_disable_instruction'),
            style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textGrey),
          ),
          SizedBox(height: 24.h),
          _primaryButton(
            label: _languageService.tr('two_factor_confirm_disable'),
            onPressed: _showDisableOtpModal,
          ),
          SizedBox(height: 12.h),
          _secondaryButton(
            label: _languageService.tr('cancel'),
            onPressed: _controller.cancelDisable,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildSecretBox(String secret) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              secret,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                letterSpacing: 1.2,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 20.sp, color: AppColors.primary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: secret));
              CustomToastService.showSuccess(
                title: _languageService.tr('success'),
                message: _languageService.tr('two_factor_secret_copied'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 46.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.whiteColor,
          disabledBackgroundColor: AppColors.border,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.whiteColor,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 46.h,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 46.h,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}