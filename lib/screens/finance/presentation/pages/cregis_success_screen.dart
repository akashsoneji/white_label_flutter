import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';

import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Cregis checkout / hosted payment flow (ported from crmapp — additive screen).
class CregisSuccessScreen extends StatefulWidget {
  final String referenceNumber;
  final String amount;
  final String checkoutUrl;

  /// ISO8601 timestamp captured the moment the user tapped to proceed. Any
  /// transaction that appears in history AFTER this time is treated as the
  /// successful deposit.
  final String tapTimeIso;

  /// Name of the payment method the user picked (e.g. "safepay").
  final String title;

  const CregisSuccessScreen({
    super.key,
    required this.referenceNumber,
    required this.amount,
    required this.checkoutUrl,
    required this.tapTimeIso,
    this.title = '',
  });

  @override
  State<CregisSuccessScreen> createState() => _CregisSuccessScreenState();
}

class _CregisSuccessScreenState extends State<CregisSuccessScreen> {
  // Wait up to 120s on this screen, checking Transaction History every 5s.
  static const int _pollIntervalSeconds = 5;
  static const int _maxWaitSeconds = 120;

  Timer? _pollingTimer;
  DateTime? _pollingStartedAt;
  bool _resolved = false; // set once success/timeout/cancel fires
  String _statusText = '';
  bool _isPolling = true;

  @override
  void initState() {
    super.initState();
    _statusText = TranslationUtils.tr(
      'cregis_success_screen_checking_payment_details',
    );
    _openExternalBrowser();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _openExternalBrowser() async {
    try {
      final uri = Uri.parse(widget.checkoutUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error opening external browser: $e');
    }
  }

  void _startStatusPolling() {
    _pollingStartedAt = DateTime.now();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: _pollIntervalSeconds),
      (timer) async {
        if (!mounted || _resolved) {
          timer.cancel();
          return;
        }

        final elapsed =
            DateTime.now().difference(_pollingStartedAt!).inSeconds;
        if (elapsed >= _maxWaitSeconds) {
          _onTimeout();
          return;
        }

        setState(() {
          final remaining = _maxWaitSeconds - elapsed;
          _statusText =
              '${TranslationUtils.tr('cregis_success_screen_checking_payment_details')} (${remaining}s)';
        });

        final ref = widget.referenceNumber;
        if (ref.trim().isEmpty) return; // can't look up without a ref

        final status = await _fetchDepositStatus(ref);
        if (!mounted || _resolved || status == null) return;
        if (_successStatuses.contains(status)) {
          _onSuccess();
        } else if (_failedStatuses.contains(status)) {
          _onFailed();
        }
      },
    );
  }

  static const _successStatuses = {'approved', 'success', 'completed'};
  static const _failedStatuses = {
    'rejected',
    'failed',
    'cancelled',
    'canceled',
    'declined',
    'expired',
  };

  /// `data.status` of GET deposit/by-reference, lowercased; null when the
  /// deposit is not found yet or the call failed (keep polling).
  Future<String?> _fetchDepositStatus(String reference) async {
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.depositByReference,
        queryParameters: {'reference': reference},
      );
      final body = response.data;
      if (!response.success || body is! Map) return null;
      final data = body['data'];
      if (data is! Map) return null;
      return data['status']?.toString().trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  void _onFailed() {
    if (_resolved) return;
    _resolved = true;
    _pollingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPolling = false;
        _statusText = TranslationUtils.tr('deposit_deposit_failed');
      });
    }
    CustomToastService.showError(
      message: TranslationUtils.tr('deposit_deposit_failed'),
    );
  }

  void _onSuccess() {
    if (_resolved) return;
    _resolved = true;
    _pollingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPolling = false;
        _statusText = TranslationUtils.tr(
          'cregis_success_screen_payment_confirmed',
        );
      });
    }
      CustomToastService.showSuccess(
        message: TranslationUtils.tr('deposit_deposit_successful'),
      );
    try {
      Get.find<DashboardController>().markMT5AccountsAsStale();
    } catch (_) {}
    Get.offAllNamed(
      AppPages.TRANSACTION_HISTORY,
      arguments: {'from': 'finance'},
    );
  }

  void _onTimeout() {
    if (_resolved) return;
    _resolved = true;
    _pollingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPolling = false;
        _statusText = TranslationUtils.tr(
          'cregis_address_screen_transaction_is_processing_check_transaction',
        );
      });
    }
    CustomToastService.showWarning(
      message: TranslationUtils.tr(
        'cregis_address_screen_transaction_is_processing_please_wait_in',
      ),
      title: TranslationUtils.tr('cregis_address_screen_processing'),
    );
    Get.offAllNamed(
      AppPages.TRANSACTION_HISTORY,
      arguments: {'from': 'finance'},
    );
  }

  /// Back arrow / device back / swipe within the wait window → confirm dialog.
  /// "Yes" cancels polling and sends the user home (TRADING).
  /// "No" leaves the user on the wait screen and the poll continues.
  Future<void> _confirmCancel() async {
    if (_resolved) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(TranslationUtils.tr('cregis_address_screen_cancel_payment')),
        content: Text(
          TranslationUtils.tr(
            'cregis_address_screen_are_you_sure_you_want_to_cancel_this_payment',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              TranslationUtils.tr('cregis_address_screen_no_keep_waiting'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              TranslationUtils.tr('cregis_address_screen_yes_cancel'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || _resolved) return;
    _resolved = true;
    _pollingTimer?.cancel();
    CustomToastService.showError(
      message: TranslationUtils.tr(
        'cregis_address_screen_transaction_cancelled',
      ),
    );
    Get.offAllNamed(AppPages.TRADING);
  }

  /// Explicit "Go to Transaction History" tap — leave the wait and go watch
  /// the deposit in history (no cancel toast).
  void _goToHistory() {
    if (_resolved) return;
    _resolved = true;
    _pollingTimer?.cancel();
    Get.offAllNamed(
      AppPages.TRANSACTION_HISTORY,
      arguments: {'from': 'finance'},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Brand primary can be near-black or near-white depending on flavor/theme,
    // so pick the label colour by luminance. Must not use textPrimary here —
    // in dark mode that is white, and primary is white too.
    final Color onPrimary =
        ThemeData.estimateBrightnessForColor(AppColors.primary) ==
                Brightness.dark
            ? AppColors.pureWhite
            : AppColors.pureBlack;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmCancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: AppSvgBackButton(onPressed: _confirmCancel),
          title: Text(
                    widget.title.isNotEmpty
                        ? widget.title
                        : TranslationUtils.tr('general_deposit'),
            style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary, fontSize: 16.sp),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 32.h),
                Text(
                  TranslationUtils.tr(
                    'cregis_success_screen_payment_request_submitted',
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'Amount: ${widget.amount} USD',
                  style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp, color: AppColors.textGrey),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ref: ${widget.referenceNumber}',
                    style: AppTextStyles.caption,
                  ),
                ),
                SizedBox(height: 32.h),
                if (_isPolling)
                  Column(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        _statusText,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.textGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 40,
                        color: Colors.orange,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _statusText,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: Colors.orange.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                SizedBox(height: 48.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openExternalBrowser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_browser, size: 20, color: onPrimary),
                        SizedBox(width: 8.w),
                        Text(
                          TranslationUtils.tr(
                            'cregis_success_screen_open_payment_link',
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _goToHistory,
                    child: Text(
                  TranslationUtils.tr(
                    'cregis_address_screen_go_to_transaction_history',
                  ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ),
              
              ],
            ),
          ),
        ),
      ),
    );
  }
}
