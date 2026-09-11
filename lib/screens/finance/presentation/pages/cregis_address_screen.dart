import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/finance/view_models/transaction_history_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// Cregis direct crypto address flow (ported from crmapp — additive screen).
class CregisAddressScreen extends StatefulWidget {
  final String cregisAddress;
  final String referenceNumber;
  final String amount;
  final String networkKey;

  /// ISO8601 timestamp captured the moment the user tapped to proceed. Any
  /// transaction that appears in history AFTER this time is treated as the
  /// successful deposit.
  final String tapTimeIso;

  const CregisAddressScreen({
    super.key,
    required this.cregisAddress,
    required this.referenceNumber,
    required this.amount,
    required this.networkKey,
    required this.tapTimeIso,
  });

  @override
  State<CregisAddressScreen> createState() => _CregisAddressScreenState();
}

class _CregisAddressScreenState extends State<CregisAddressScreen> {
  // Wait up to 120s on this screen, checking Transaction History every 5s.
  static const int _pollIntervalSeconds = 5;
  static const int _maxWaitSeconds = 120;

  Timer? _pollingTimer;
  DateTime? _pollingStartedAt;
  bool _resolved = false; // set once success/timeout/cancel fires
  String _statusText = 'Waiting for payment...';
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
    _startStatusPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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
              'Checking payment status... (${remaining}s, attempt $_pollAttempts)';
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
        _statusText = 'Deposit confirmed!';
      });
    }
    CustomToastService.showSuccess(
      message: TranslationUtils.tr('cregis_deposit_confirmed_balance_updated'),
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
        title: Text('Cancel payment?'),
        content: Text(
          'Are you sure you want to cancel this payment? The transaction '
          'will not be processed and you will be returned to the home screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('No, keep waiting'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Yes, cancel'),
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

  String _getNetworkLabel(String key) {
    const labels = {
      'trc20': 'TRC-20 (TRON)',
      'erc20': 'ERC-20 (Ethereum)',
      'bep20': 'BEP-20 (BSC)',
      'polygon': 'Polygon (MATIC)',
    };
    return labels[key.toLowerCase()] ?? key.toUpperCase();
  }

  String _getSafetyCurrency(String key) {
    const currencies = {
      'trc20': 'USDT-TRC20',
      'erc20': 'USDT-ERC20',
      'bep20': 'USDT-BEP20',
      'polygon': 'USDT-POLYGON',
    };
    return currencies[key.toLowerCase()] ?? 'USDT';
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent(widget.cregisAddress)}';
    final networkLabel = _getNetworkLabel(widget.networkKey);

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
          leading: AppBackButton(onPressed: _confirmCancel),
          title: Text(
            'Direct Crypto Transfer',
            style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary, fontSize: 16.sp),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Send',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${widget.amount} USD',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'using $networkLabel',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Image.network(
                  qrUrl,
                  height: 200,
                  width: 200,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 200,
                      width: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.qr_code_2,
                          size: 80,
                          color: AppColors.textGrey,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Deposit Wallet Address',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.cregisAddress,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.cregisAddress),
                        );
                        CustomToastService.showSuccess(
                          message: 'Address copied to clipboard',
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.copy,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only send ${_getSafetyCurrency(widget.networkKey)} on $networkLabel. Sending other assets may result in loss.',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: Colors.red.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Reference: ${widget.referenceNumber}',
                style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
              ),
              SizedBox(height: 12),
              // ── Debug strip: shows last Transaction-History poll
              //    request/response so QA can see whether the Cregis
              //    reference_number matched. Remove once flow is stable. ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10),
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
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _debugLastCall,
                      style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _debugLastResponse,
                      style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp),
                    ),
                    if (_debugLastAt != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'at ${_debugLastAt!.toIso8601String()}',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 9.sp,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 32),
              if (_isPolling)
                Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.sp,
                        color: AppColors.textGrey,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Icon(Icons.info_outline, size: 40, color: Colors.orange),
                    SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.sp,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _goToHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.whiteColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: Text(
                          'Go to Transaction History',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
