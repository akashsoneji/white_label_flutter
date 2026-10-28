import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/app_settings_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Makes sure the user's mobile number is verified.
///
/// Calls `POST mobile-verification/send`. When the server answers
/// `data.verified: true` the number is already verified and no UI is shown;
/// otherwise an OTP sheet collects the code for `mobile-verification/verify`.
/// Returns whether the number is verified at the end.
Future<bool> ensureMobileVerified() async {
  // No SMS channel configured: nothing can be verified, so don't block.
  if (isMobileOtpOff) return true;
  final sent = await _sendMobileOtp();
  if (sent == null) return false;
  if (sent) return true;
  final verified = await Get.bottomSheet<bool>(
    const _MobileOtpSheet(),
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
  );
  if (verified != true) return false;
  if (Get.isRegistered<MoreController>()) {
    unawaited(Get.find<MoreController>().loadMoreScreenData());
  }
  return true;
}

/// `app-settings`: `mobile_otp_enabled` off or `otp_policy.mobile_available`
/// false → mobile OTP UI is hidden everywhere.
bool get isMobileOtpOff =>
    Get.isRegistered<AppSettingsService>() &&
    Get.find<AppSettingsService>().isMobileOtpOff;

/// `true` = already verified, `false` = OTP sent, `null` = request failed.
Future<bool?> _sendMobileOtp() async {
  try {
    final response = await ApiService.post(
      endpoint: ApiConstants.mobileVerificationSend,
    );
    if (!response.success) {
      CustomToastService.showError(
        message: response.message?.isNotEmpty == true
            ? response.message!
            : TranslationUtils.tr('mobile_otp_send_failed'),
      );
      return null;
    }
    return _isVerified(response.data);
  } catch (_) {
    CustomToastService.showError(
      message: TranslationUtils.tr('mobile_otp_send_failed'),
    );
    return null;
  }
}

bool _isVerified(dynamic body) {
  final data = body is Map ? body['data'] : null;
  return data is Map && data['verified'] == true;
}

class _MobileOtpSheet extends StatefulWidget {
  const _MobileOtpSheet();

  @override
  State<_MobileOtpSheet> createState() => _MobileOtpSheetState();
}

class _MobileOtpSheetState extends State<_MobileOtpSheet> {
  static const _resendCooldown = 60;

  final _otpController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendCooldown;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    final result = await _sendMobileOtp();
    if (!mounted) return;
    setState(() => _resending = false);
    if (result == true) {
      Get.back(result: true);
    } else if (result == false) {
      _startCooldown();
    }
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _error = TranslationUtils.tr('mobile_otp_invalid'));
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.mobileVerificationVerify,
        data: {'otp': otp},
      );
      if (!mounted) return;
      if (response.success) {
        CustomToastService.showSuccess(
          message: response.message?.isNotEmpty == true
              ? response.message!
              : TranslationUtils.tr('mobile_otp_verified'),
        );
        Get.back(result: true);
        return;
      }
      setState(() {
        _error = response.message?.isNotEmpty == true
            ? response.message!
            : TranslationUtils.tr('mobile_otp_verify_failed');
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = TranslationUtils.tr('mobile_otp_verify_failed'));
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0 && !_resending && !_verifying;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                TranslationUtils.tr('mobile_otp_title'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                TranslationUtils.tr('mobile_otp_subtitle'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: _otpController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _verify(),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 18.sp,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: canResend ? _resend : null,
                  child: Text(
                    _secondsLeft > 0
                        ? TranslationUtils.trArgs(
                            'mobile_otp_resend_in',
                            {'seconds': '$_secondsLeft'},
                          )
                        : TranslationUtils.tr('mobile_otp_resend'),
                    style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              SizedBox(
                height: 44.h,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onColoredBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: _verifying
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onColoredBackground,
                          ),
                        )
                      : Text(TranslationUtils.tr('mobile_otp_verify')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
