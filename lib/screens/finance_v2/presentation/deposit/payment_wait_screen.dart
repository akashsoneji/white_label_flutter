import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

import '../../data/finance_v2_repository.dart';
import '../widgets/copyable_info_row.dart';
import '../widgets/finance_v2_primary_button.dart';
import '../widgets/finance_v2_scaffold.dart';
import 'deposit_labels.dart';
import 'deposit_navigation.dart';
import 'payment_wait_controller.dart';
import 'payment_webview_screen.dart';

/// Last deposit screen of an online payment: opens the gateway page and
/// waits for the deposit to be paid or to fail.
///
/// Leaving the screen only stops the polling; the deposit is never cancelled
/// from here.
class PaymentWaitScreen extends StatefulWidget {
  final String reference;

  /// The gateway's page; empty when there is nothing to open.
  final String paymentUrl;

  const PaymentWaitScreen({
    super.key,
    required this.reference,
    this.paymentUrl = '',
  });

  @override
  State<PaymentWaitScreen> createState() => _PaymentWaitScreenState();
}

class _PaymentWaitScreenState extends State<PaymentWaitScreen> {
  late final String _tag = 'payment_wait_${identityHashCode(this)}';
  late final PaymentWaitController _controller;
  Worker? _statusWorker;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      PaymentWaitController(
        repository: Get.find<FinanceV2Repository>(),
        reference: widget.reference,
      ),
      tag: _tag,
    );
    _statusWorker = ever<PaymentWaitStatus>(_controller.status, _onStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPaymentPage());
  }

  @override
  void dispose() {
    _statusWorker?.dispose();
    Get.delete<PaymentWaitController>(tag: _tag);
    super.dispose();
  }

  void _onStatus(PaymentWaitStatus status) {
    if (status != PaymentWaitStatus.paid) return;
    CustomToastService.showSuccess(
      message: TranslationUtils.tr('cregis_success_screen_payment_confirmed'),
    );
    openDepositTransactionHistory();
  }

  Future<void> _openPaymentPage() async {
    if (!mounted || widget.paymentUrl.isEmpty) return;
    await Get.to<void>(
      () => PaymentWebViewScreen(
        url: widget.paymentUrl,
        title: TranslationUtils.tr('deposit'),
      ),
    );
    // The page was closed: ask now instead of waiting for the next tick.
    await _controller.pollNow();
  }

  /// Asks before leaving while the payment is still awaited. Leaving only
  /// stops the polling.
  Future<void> _onBack() async {
    if (_controller.status.value != PaymentWaitStatus.waiting) {
      Get.back<void>();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => const _CancelPaymentDialog(),
    );
    if (leave == true && mounted) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: FinanceV2Scaffold(
        title: TranslationUtils.tr('deposit'),
        onBack: _onBack,
        bottomCta: Obx(() {
          final status = _controller.status.value;
          return switch (status) {
            PaymentWaitStatus.failed => const _FailedActions(),
            PaymentWaitStatus.waiting when widget.paymentUrl.isNotEmpty =>
              FinanceV2PrimaryButton(
                label: TranslationUtils.tr(
                  'cregis_success_screen_open_payment_link',
                ),
                onPressed: _openPaymentPage,
              ),
            _ => FinanceV2PrimaryButton(
                label: TranslationUtils.tr(
                  'cregis_address_screen_go_to_transaction_history',
                ),
                onPressed: openDepositTransactionHistory,
              ),
          };
        }),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() => _StatusHeader(status: _controller.status.value)),
              if (widget.reference.isNotEmpty) ...[
                SizedBox(height: 24.h),
                CopyableInfoRow(
                  label: depositReferenceLabel(),
                  value: widget.reference,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A failed payment: start over, or look the deposit up in the history.
class _FailedActions extends StatelessWidget {
  const _FailedActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceV2PrimaryButton(
          label: TranslationUtils.tr('fv2_try_again'),
          onPressed: () => Get.back<void>(),
        ),
        SizedBox(height: 4.h),
        TextButton(
          onPressed: openDepositTransactionHistory,
          child: Text(
            TranslationUtils.tr(
              'cregis_address_screen_go_to_transaction_history',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.primary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelPaymentDialog extends StatelessWidget {
  const _CancelPaymentDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      content: Text(
        TranslationUtils.tr('cregis_address_screen_cancel_payment'),
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textPrimary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            TranslationUtils.tr('cregis_address_screen_no_keep_waiting'),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            TranslationUtils.tr('cregis_address_screen_yes_cancel'),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.error,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final PaymentWaitStatus status;

  const _StatusHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    final (String titleKey, IconData? icon, Color color) = switch (status) {
      PaymentWaitStatus.waiting => (
          'fv2_waiting_payment',
          null,
          AppColors.primary,
        ),
      PaymentWaitStatus.paid => (
          'cregis_success_screen_payment_confirmed',
          Icons.check_circle_outline_rounded,
          AppColors.success,
        ),
      PaymentWaitStatus.failed => (
          'fv2_payment_failed',
          Icons.error_outline_rounded,
          AppColors.error,
        ),
      PaymentWaitStatus.processing => (
          'fv2_payment_processing',
          Icons.schedule_rounded,
          AppColors.primary,
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48.w,
          height: 48.w,
          child: icon == null
              ? CircularProgressIndicator(strokeWidth: 3, color: color)
              : Icon(icon, color: color, size: 48.w),
        ),
        SizedBox(height: 16.h),
        Text(
          TranslationUtils.tr(titleKey),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (status == PaymentWaitStatus.processing) ...[
          SizedBox(height: 8.h),
          Text(
            TranslationUtils.tr(
              'cregis_address_screen_transaction_is_processing_please_wait_in',
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
            ),
          ),
        ],
      ],
    );
  }
}
