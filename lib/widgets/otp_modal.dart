import 'dart:io';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/services/language_service.dart';

class OtpModal extends StatefulWidget {
  final String email;
  final String? phoneNumber;
  final VoidCallback? onVerify;
  final Function(String)? onOtpSubmitted;
  final VoidCallback? onResendOtp;
  final bool isEmailVerification;
  final int otpLength;
  final Function(void Function())?
  onModalReady; // Callback to expose clearFields method

  const OtpModal({
    Key? key,
    this.email = '',
    this.phoneNumber,
    this.onVerify,
    this.onOtpSubmitted,
    this.onResendOtp,
    this.isEmailVerification = true,
    this.otpLength = 6, // ✅ Default is 6 - this is correct
    this.onModalReady,
  }) : super(key: key);

  @override
  State<OtpModal> createState() => _OtpModalState();
}

class _OtpModalState extends State<OtpModal> {
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;
  final ScrollController _scrollController = ScrollController();
  late final List<String> _previousOtpValues;

  @override
  void initState() {
    super.initState();
    // ✅ Creates controllers based on otpLength (6 by default)
    _otpControllers = List.generate(
      widget.otpLength,
      (index) => TextEditingController(),
    );
    _otpFocusNodes = List.generate(widget.otpLength, (index) => FocusNode());
    _previousOtpValues = List.generate(widget.otpLength, (index) => '');

    // Add focus listeners to handle keyboard appearance
    for (int i = 0; i < widget.otpLength; i++) {
      _otpFocusNodes[i].addListener(() {
        if (_otpFocusNodes[i].hasFocus) {
          _scrollToVisible(i);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Expose clearFields method to parent via callback
    if (widget.onModalReady != null) {
      widget.onModalReady!(clearOtpFields);
    }
  }

  // Method to clear OTP fields (can be called from outside)
  void clearOtpFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    // Reset previous values
    for (int i = 0; i < _previousOtpValues.length; i++) {
      _previousOtpValues[i] = '';
    }
    // Focus on the first input field
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToVisible(int index) {
    // Add a small delay to ensure the keyboard is fully visible
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        final double itemHeight = 60.h;
        final double scrollOffset =
            (index * itemHeight) - (MediaQuery.of(context).size.height * 0.3);
        if (scrollOffset > 0) {
          _scrollController.animateTo(
            scrollOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24.h),

              // Title
              Text(
                widget.isEmailVerification
                    ? 'Verify Email'
                    : 'Verify Mobile Number',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),

              // Instructions - ✅ FIXED: Changed from "5-digit" to use dynamic otpLength
              Text(
                widget.isEmailVerification
                    ? 'Enter the ${widget.otpLength}-digit code we\'ve sent to your email'
                    : 'Enter the ${widget.otpLength}-digit code we\'ve sent to your number',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.textGrey.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                widget.isEmailVerification
                    ? widget.email
                    : (widget.phoneNumber ?? ''),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),

              // OTP Input Fields - ✅ Generates fields based on otpLength (will be 6)
              // Boxes are positional (box 1 = first digit typed), so the row
              // must stay LTR even in Arabic.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(widget.otpLength, (index) {
                    return Container(
                      width: 51.w,
                      height: 50.h,
                      child:
                          Platform.isAndroid
                              ? _buildOtpBoxAndroid(index)
                              : _buildOtpBox(index),
                    );
                  }),
                ),
              ),
              SizedBox(height: 32.h),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: widget.onVerify ?? _handleVerify,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.whiteColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Verify',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Resend OTP Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Didn\'t receive the code? ',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      color: AppColors.textGrey.withValues(alpha: 0.9),
                    ),
                  ),
                  TextButton(
                    onPressed: _handleResendOtp,
                    child: Text(
                      'Resend',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  // Build OTP box for iOS
  Widget _buildOtpBox(int index) {
    return TextField(
      controller: _otpControllers[index],
      focusNode: _otpFocusNodes[index],
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: index == 0 ? widget.otpLength : 1,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(index == 0 ? widget.otpLength : 1),
      ],
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.all(5),
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.icongrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.icongrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      onChanged: (value) {
        if (value.length > 1 && value.length <= widget.otpLength) {
          // Handle paste - distribute digits across fields
          final otp = value.padRight(widget.otpLength, '');
          for (int i = 0; i < widget.otpLength; i++) {
            _otpControllers[i].text = i < otp.length ? otp[i] : '';
            _previousOtpValues[i] = i < otp.length ? otp[i] : '';
          }
          if (otp.length == widget.otpLength) {
            _otpFocusNodes[widget.otpLength - 1].requestFocus();
          } else if (otp.length >
              _otpControllers.indexWhere((c) => c.text.isEmpty)) {
            _otpFocusNodes[otp.length - 1].requestFocus();
          }
        } else if (value.length == 1 && index < widget.otpLength - 1) {
          // Move to next box when a digit is entered
          _previousOtpValues[index] = value;
          _otpFocusNodes[index + 1].requestFocus();
        } else if (value.isEmpty && index > 0) {
          // Move to previous box when backspace clears the current box
          _previousOtpValues[index] = '';
          _otpFocusNodes[index - 1].requestFocus();
        } else if (value.isEmpty && index == 0) {
          // Clear all fields and reset focus to first box if first box is cleared
          for (int i = 0; i < widget.otpLength; i++) {
            _otpControllers[i].clear();
            _previousOtpValues[i] = '';
          }
          _otpFocusNodes[0].requestFocus();
        } else if (value.length == 1 && index == widget.otpLength - 1) {
          // Last field filled, hide keyboard
          _previousOtpValues[index] = value;
          _otpFocusNodes[index].unfocus();
        }
      },
      onTap: () {
        // When user taps on a box, select all text for easy replacement
        if (_otpControllers[index].text.isNotEmpty) {
          _otpControllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _otpControllers[index].text.length,
          );
        }
      },
    );
  }

  // Build OTP box for Android with RawKeyboardListener for backspace handling
  Widget _buildOtpBoxAndroid(int index) {
    final keyboardFocusNode = FocusNode();

    return index == 0
        ? TextField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: widget.otpLength, // Allow paste of full OTP in first field
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.otpLength),
          ],
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.all(5),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.icongrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.icongrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onChanged: (value) {
            if (value.length > 1 && value.length <= widget.otpLength) {
              // Handle paste - distribute digits across fields
              final otp = value.padRight(widget.otpLength, '');
              for (int i = 0; i < widget.otpLength; i++) {
                _otpControllers[i].text = i < otp.length ? otp[i] : '';
                _previousOtpValues[i] = i < otp.length ? otp[i] : '';
              }
              if (otp.length == widget.otpLength) {
                _otpFocusNodes[widget.otpLength - 1].requestFocus();
              } else if (otp.length >
                  _otpControllers.indexWhere((c) => c.text.isEmpty)) {
                _otpFocusNodes[otp.length - 1].requestFocus();
              }
            } else if (value.length == 1 && index < widget.otpLength - 1) {
              _previousOtpValues[index] = value;
              _otpFocusNodes[index + 1].requestFocus();
            }
          },
          onTap: () {
            if (_otpControllers[index].text.isNotEmpty) {
              _otpControllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _otpControllers[index].text.length,
              );
            }
          },
        )
        : RawKeyboardListener(
          focusNode: keyboardFocusNode,
          onKey: (event) {
            if (event is RawKeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace &&
                _otpControllers[index].text.isEmpty &&
                index > 0) {
              // Handle backspace on empty field - move to previous field
              _otpFocusNodes[index - 1].requestFocus();
            }
          },
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.all(5),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.icongrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.icongrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < widget.otpLength - 1) {
                _previousOtpValues[index] = value;
                _otpFocusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                // Move to previous box when backspace clears the current box
                _previousOtpValues[index] = '';
                _otpFocusNodes[index - 1].requestFocus();
              }
            },
            onTap: () {
              if (_otpControllers[index].text.isNotEmpty) {
                _otpControllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _otpControllers[index].text.length,
                );
              }
            },
          ),
        );
  }

  void _handleVerify() {
    final otp = _otpControllers.map((controller) => controller.text).join();
    if (otp.length == widget.otpLength) {
      if (widget.onOtpSubmitted != null) {
        widget.onOtpSubmitted!(otp);
      } else {
        // Default behavior
        Get.back(closeOverlays: true); // Close modal
        if (Get.isRegistered<AppNotificationController>()) {
          final lang = Get.find<LanguageService>();
          Get.find<AppNotificationController>().showSuccess(
            message: lang.tr('otp_modal_otp_verified_successfully'),
            title: lang.tr('general_success'),
          );
        }
      }
    } else {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please enter a valid ${widget.otpLength}-digit OTP',
          title: 'Error',
        );
      }
    }
  }

  void _handleResendOtp() {
    if (widget.onResendOtp != null) {
      // Use the callback provided by parent
      widget.onResendOtp!();
    } else {
      // Default behavior
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showSuccess(
          message: 'OTP resent successfully!',
          title: 'Success',
        );
      }
    }

    // Clear the OTP input fields
    for (var controller in _otpControllers) {
      controller.clear();
    }

    // Focus on the first input field
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes[0].requestFocus();
    }
  }
}
