import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_error_retry.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_primary_button.dart';
import 'package:crm_app/services/language_service.dart';

import 'withdrawal_amount_controller.dart';

/// What the OTP sheet closed with: the step's outcome and the code that was
/// typed, which a confirmed new quote is sent again with.
class WithdrawalOtpResult {
  final WithdrawalOutcome outcome;
  final String code;

  const WithdrawalOtpResult({required this.outcome, this.code = ''});
}

/// Opens [WithdrawalOtpSheet]. Completes with null when the client closed the
/// sheet; the form behind it is kept.
Future<WithdrawalOtpResult?> showWithdrawalOtpSheet(
  BuildContext context, {
  required WithdrawalAmountController controller,
}) {
  return showModalBottomSheet<WithdrawalOtpResult>(
    context: context,
    isScrollControlled: true,
    // Closing goes through the sheet's PopScope, which blocks it while the
    // withdrawal is being sent.
    enableDrag: false,
    backgroundColor: AppColors.cardBackground,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (_) => WithdrawalOtpSheet(controller: controller),
  );
}

/// Asks for the withdrawal code: requests it when opened, takes six digits
/// and submits the withdrawal. A wrong code keeps the sheet open.
class WithdrawalOtpSheet extends StatefulWidget {
  final WithdrawalAmountController controller;

  const WithdrawalOtpSheet({super.key, required this.controller});

  @override
  State<WithdrawalOtpSheet> createState() => _WithdrawalOtpSheetState();
}

class _WithdrawalOtpSheetState extends State<WithdrawalOtpSheet> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  late final Worker _clearWorker;

  WithdrawalAmountController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _clearWorker = ever<int>(_controller.otpClearSignal, (_) {
      _codeController.clear();
      _codeFocus.requestFocus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleSendOutcome(_controller.requestOtpOnOpen());
    });
  }

  @override
  void dispose() {
    _clearWorker.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final outcome = await _controller.sendOtp();
    if (!mounted) return;
    // A refused resend keeps the code already typed for the earlier email.
    if (outcome == WithdrawalOutcome.success) _codeController.clear();
    await _handleSendOutcome(Future<WithdrawalOutcome>.value(outcome));
  }

  Future<void> _handleSendOutcome(Future<WithdrawalOutcome> request) async {
    final outcome = await request;
    if (!mounted) return;
    switch (outcome) {
      case WithdrawalOutcome.success:
        _codeFocus.requestFocus();
      case WithdrawalOutcome.invalid:
        // Another request is still running; its answer updates the sheet.
        break;
      case WithdrawalOutcome.otpSendFailed:
        // The message and Retry are shown inside the sheet.
        break;
      case WithdrawalOutcome.submitFailed:
      case WithdrawalOutcome.quoteRefreshed:
      case WithdrawalOutcome.kycRequired:
      case WithdrawalOutcome.quoteChanged:
      case WithdrawalOutcome.financeDisabled:
      case WithdrawalOutcome.amountError:
      case WithdrawalOutcome.otpInvalid:
      case WithdrawalOutcome.channelRejected:
        Navigator.of(context).pop(WithdrawalOtpResult(outcome: outcome));
    }
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    final outcome = await _controller.submit(code);
    if (!mounted) return;
    final staysOpen = outcome == WithdrawalOutcome.otpInvalid ||
        outcome == WithdrawalOutcome.invalid;
    if (staysOpen) return;
    Navigator.of(context).pop(WithdrawalOtpResult(outcome: outcome, code: code));
  }

  /// Keyboard "done": the same as the Confirm button, once all digits are in.
  void _onKeyboardDone() {
    final isComplete =
        _codeController.text.length == WithdrawalAmountController.otpLength;
    final isBusy = _controller.isSendingOtp.value ||
        _controller.isSubmitting.value ||
        _controller.otpSendError.value != null;
    if (isComplete && !isBusy) _confirm();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSubmitting = _controller.isSubmitting.value;
      final isSending = _controller.isSendingOtp.value;
      final sendError = _controller.otpSendError.value;
      final otpError = _controller.otpError.value;
      final resendNotice = _controller.otpResendNotice.value;
      final resendSeconds = _controller.resendSeconds.value;
      final isEmail = _controller.otpChannel.value.toLowerCase() == 'email';
      final canType = !isSending && !isSubmitting && sendError == null;

      return PopScope(
        canPop: !isSubmitting,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(16.w, 12.h, 16.w, 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SheetHeader(
                    onClose: isSubmitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                  ),
                  SizedBox(height: 4.h),
                  if (isSending)
                    const _ShimmerLine()
                  else if (sendError != null)
                    FinanceV2ErrorRetry(
                      compact: true,
                      message: sendError.isEmpty
                          ? TranslationUtils.tr('general_something_went_wrong')
                          : sendError,
                      onRetry: _sendCode,
                    )
                  else
                    Text(
                      TranslationUtils.tr(
                        isEmail ? 'fv2_code_sent_email' : 'fv2_code_sent_mobile',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textGrey,
                        fontSize: 13.sp,
                      ),
                    ),
                  SizedBox(height: 16.h),
                  _OtpBoxes(
                    controller: _codeController,
                    focusNode: _codeFocus,
                    enabled: canType,
                    hasError: otpError != null && otpError.isNotEmpty,
                    onDone: _onKeyboardDone,
                  ),
                  if (otpError != null && otpError.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Text(
                      otpError,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.errorText,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                  if (resendNotice != null && resendNotice.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Text(
                      resendNotice,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textGrey,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  _ResendRow(
                    secondsLeft: resendSeconds,
                    onResend: canType ? _sendCode : null,
                  ),
                  SizedBox(height: 12.h),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _codeController,
                    builder: (context, value, _) {
                      final isComplete = value.text.length ==
                          WithdrawalAmountController.otpLength;
                      return FinanceV2PrimaryButton(
                        label: TranslationUtils.tr('general_confirm'),
                        enabled: isComplete && canType,
                        isLoading: isSubmitting,
                        onPressed: _confirm,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _SheetHeader extends StatelessWidget {
  final VoidCallback? onClose;

  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            TranslationUtils.tr('fv2_enter_code'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.w),
          icon: Icon(
            Icons.close_rounded,
            color: AppColors.textGrey,
            size: 20.sp,
          ),
        ),
      ],
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutralTrackMuted,
      highlightColor: AppColors.neutralTrackSoft,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: 200.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    );
  }
}

/// Six boxes drawn over one invisible text field, so paste and SMS autofill
/// fill the whole code at once.
class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final VoidCallback onDone;

  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    const length = WithdrawalAmountController.otpLength;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final code = value.text;
              return Row(
                children: [
                  for (var index = 0; index < length; index++) ...[
                    if (index > 0) SizedBox(width: 8.w),
                    Expanded(
                      child: _OtpBox(
                        digit: index < code.length ? code[index] : '',
                        isActive: enabled && index == code.length,
                        hasError: hasError,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                showCursor: false,
                enableInteractiveSelection: false,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onDone(),
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String digit;
  final bool isActive;
  final bool hasError;

  const _OtpBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    if (hasError) {
      borderColor = AppColors.error;
    } else if (isActive) {
      borderColor = AppColors.primary;
    } else {
      borderColor = AppColors.border;
    }

    return Container(
      height: 48.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.textFieldBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
      ),
      child: Text(
        digit,
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textPrimary,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback? onResend;

  const _ResendRow({required this.secondsLeft, required this.onResend});

  @override
  Widget build(BuildContext context) {
    if (secondsLeft > 0) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text(
          TranslationUtils.tr('fv2_resend_in')
              .replaceAll('{seconds}', '$secondsLeft'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textGrey,
            fontSize: 12.sp,
          ),
        ),
      );
    }

    final color = onResend == null ? AppColors.textGrey : AppColors.primary;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onResend,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(40.w, 40.h),
        ),
        child: Text(
          TranslationUtils.tr('fv2_resend_code'),
          style: AppTextStyles.bodyText.copyWith(
            color: color,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
