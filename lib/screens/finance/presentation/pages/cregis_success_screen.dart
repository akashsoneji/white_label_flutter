import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/finance/view_models/transaction_history_controller.dart';
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

  const CregisSuccessScreen({
    super.key,
    required this.referenceNumber,
    required this.amount,
    required this.checkoutUrl,
    required this.tapTimeIso,
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
  String _statusText = 'Checking payment details...';
  bool _isPolling = true;
  int _pollAttempts = 0;

  // Visible debug strip showing the most recent Transaction-History poll.
  // Helps diagnose why success was/wasn't detected at the wait screen.
  String _debugLastCall = '(no poll yet)';
  String _debugLastResponse = '(no response yet)';
  DateTime? _debugLastAt;

  @override
  void initState() {
    super.initState();
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
    _pollAttempts = 0;
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

        _pollAttempts++;
        setState(() {
          final remaining = _maxWaitSeconds - elapsed;
          _statusText =
              'Verifying payment details... (${remaining}s, attempt $_pollAttempts)';
        });

        // Poll Transaction History and look for a row whose
        // `referenceNumber` matches the Cregis ref AND whose status is one
        // of {approved, success, completed} → success.
        final ref = widget.referenceNumber;
        if (ref.trim().isEmpty) return; // can't match without a ref

        _debugLastCall = 'GET /transactions @ ${DateTime.now().toIso8601String()} '
            '(attempt $_pollAttempts, ref=${ref.length > 10 ? '${ref.substring(0, 10)}…' : ref})';
        final res = await Get.find<TransactionHistoryController>()
            .fetchLatestTransactionForRef(ref, statusFilter: true);

        if (!mounted || _resolved) return;
        if (res.row != null) {
          _debugLastResponse =
              'MATCH status=${res.row!.status ?? '?'} amount=${res.row!.amount ?? '?'} '
              'created_at=${res.row!.createdAt ?? '?'}';
          _debugLastAt = DateTime.now();
          _onSuccess();
          return;
        }
        _debugLastResponse =
            'NO MATCH (status=${res.rawStatus}, totalRows=${res.totalRows})';
        _debugLastAt = DateTime.now();
        setState(() {});
      },
    );
  }

  void _onSuccess() {
    if (_resolved) return;
    _resolved = true;
    _pollingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPolling = false;
        _statusText = 'Payment confirmed!';
      });
    }
    CustomToastService.showSuccess(message: 'Deposit successful!');
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
        _statusText = 'Transaction is processing. Check Transaction History.';
      });
    }
    CustomToastService.showWarning(
      message: 'Transaction is processing. Please wait in Transaction History.',
      title: 'Processing',
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
        title: const Text('Cancel payment?'),
        content: const Text(
          'Are you sure you want to cancel this payment? The transaction '
          'will not be processed and you will be returned to the home screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, keep waiting'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || _resolved) return;
    _resolved = true;
    _pollingTimer?.cancel();
    CustomToastService.showError(message: 'Transaction cancelled');
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
            'Cregis Payment',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
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
                  'Payment Request Submitted',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'Amount: ${widget.amount} USD',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textGrey),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ref: ${widget.referenceNumber}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textGrey,
                      fontFamily: 'monospace',
                    ),
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
                        style: TextStyle(
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
                      const Icon(
                        Icons.info_outline,
                        size: 40,
                        color: Colors.orange,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _statusText,
                        style: TextStyle(
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
                      foregroundColor: AppColors.whiteColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.open_in_browser, size: 20),
                        SizedBox(width: 8.w),
                        Text(
                          'Open Payment Link',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
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
                      'Go to Transaction History',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ),
                // ── Debug strip: shows last Transaction-History poll
                //    request/response so QA can see whether the Cregis
                //    reference_number matched. Remove once flow is stable. ──
                SizedBox(height: 16.h),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug — last poll',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _debugLastCall,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _debugLastResponse,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.black87,
                        ),
                      ),
                      if (_debugLastAt != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          'at ${_debugLastAt!.toIso8601String()}',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ],
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
