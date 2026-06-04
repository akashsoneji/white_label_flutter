import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// Cregis direct crypto address flow (ported from crmapp — additive screen).
class CregisAddressScreen extends StatefulWidget {
  final String cregisAddress;
  final String referenceNumber;
  final String amount;
  final String networkKey;

  const CregisAddressScreen({
    super.key,
    required this.cregisAddress,
    required this.referenceNumber,
    required this.amount,
    required this.networkKey,
  });

  @override
  State<CregisAddressScreen> createState() => _CregisAddressScreenState();
}

class _CregisAddressScreenState extends State<CregisAddressScreen> {
  Timer? _pollingTimer;
  int _attempts = 0;
  final int _maxAttempts = 20;
  String _statusText = 'Waiting for payment...';
  bool _isPolling = true;

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
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _attempts++;
      if (_attempts > _maxAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isPolling = false;
            _statusText =
                'Verification timeout. Check status in Transaction History.';
          });
          CustomToastService.showWarning(
            message:
                'Verification timeout. Check status in transaction history later.',
            title: 'Status Pending',
          );
        }
        return;
      }

      setState(() {
        _statusText =
            'Checking payment status... (${_attempts}/$_maxAttempts)';
      });

      final data = await _getCregisDepositStatus(widget.referenceNumber);
      if (data != null && mounted) {
        final status = data['status']?.toString().toLowerCase();
        if (status == 'approved' || status == 'confirmed') {
          timer.cancel();
          setState(() {
            _isPolling = false;
            _statusText = 'Deposit confirmed!';
          });
          CustomToastService.showSuccess(
            message: 'Deposit confirmed! Balance updated.',
          );

          try {
            final dashboardController = Get.find<DashboardController>();
            dashboardController.markMT5AccountsAsStale();
          } catch (_) {}

          Get.offAllNamed(
            AppPages.TRANSACTION_HISTORY,
            arguments: {'from': 'finance'},
          );
        } else if (status == 'rejected' || status == 'failed') {
          timer.cancel();
          setState(() {
            _isPolling = false;
            _statusText = 'Payment rejected.';
          });
          CustomToastService.showError(message: 'Deposit payment rejected.');
          Get.offAllNamed(
            AppPages.TRANSACTION_HISTORY,
            arguments: {'from': 'finance'},
          );
        }
      }
    });
  }

  Future<Map<String, dynamic>?> _getCregisDepositStatus(String refNumber) async {
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await ApiService.get(
        endpoint: '${ApiConstants.cregisDepositStatus}?ref=$refNumber',
        token: token,
      );

      if (response.success && response.data != null) {
        final data = response.data['data'] ?? response.data;
        return data as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error checking Cregis status: $e');
      return null;
    }
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

  void _goToHistory() {
    _pollingTimer?.cancel();
    Get.offAllNamed(
      AppPages.TRANSACTION_HISTORY,
      arguments: {'from': 'finance'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent(widget.cregisAddress)}';
    final networkLabel = _getNetworkLabel(widget.networkKey);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _goToHistory();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: AppBackButton(onPressed: _goToHistory),
          title: Text(
            'Direct Crypto Transfer',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Send',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.amount} USD',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'using $networkLabel',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 24),
              Text(
                'Deposit Wallet Address',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        padding: const EdgeInsets.all(8),
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only send ${_getSafetyCurrency(widget.networkKey)} on $networkLabel. Sending other assets may result in loss.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.red.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reference: ${widget.referenceNumber}',
                style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
              ),
              const SizedBox(height: 32),
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
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: TextStyle(
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
                    const Icon(Icons.info_outline, size: 40, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
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
                          style: TextStyle(
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
