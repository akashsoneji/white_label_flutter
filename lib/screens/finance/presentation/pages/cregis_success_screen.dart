import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Cregis checkout / hosted payment flow (ported from crmapp — additive screen).
class CregisSuccessScreen extends StatefulWidget {
  final String referenceNumber;
  final String amount;
  final String checkoutUrl;

  const CregisSuccessScreen({
    super.key,
    required this.referenceNumber,
    required this.amount,
    required this.checkoutUrl,
  });

  @override
  State<CregisSuccessScreen> createState() => _CregisSuccessScreenState();
}

class _CregisSuccessScreenState extends State<CregisSuccessScreen> {
  Timer? _pollingTimer;
  int _attempts = 0;
  final int _maxAttempts = 20;
  String _statusText = 'Checking payment details...';
  bool _isPolling = true;

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
                'Verification timeout. Please check Transaction History.';
          });
        }
        return;
      }

      setState(() {
        _statusText =
            'Verifying payment details... (${_attempts}/$_maxAttempts)';
      });

      final data = await _getCregisDepositStatus(widget.referenceNumber);
      if (data != null && mounted) {
        final status = data['status']?.toString().toLowerCase();
        if (status == 'approved' || status == 'confirmed') {
          timer.cancel();
          setState(() {
            _isPolling = false;
            _statusText = 'Payment confirmed!';
          });
          CustomToastService.showSuccess(message: 'Deposit successful!');

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
            _statusText = 'Payment was rejected.';
          });
          CustomToastService.showError(message: 'Payment was rejected.');
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

  void _goToHistory() {
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
        if (!didPop) _goToHistory();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: AppSvgBackButton(
            onPressed: () => Get.offAllNamed(AppPages.TRADING),
          ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
