import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import '../constants/color.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/screens/finance/presentation/pages/deposit_screen.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import '../services/account_websocket_service.dart';

class CongratulationsDialog extends StatelessWidget {
  final String accountNumber;
  final String serverName;
  final String? accountType;
  final String? leverage;

  const CongratulationsDialog({
    Key? key,
    required this.accountNumber,
    required this.serverName,
    this.accountType,
    this.leverage,
  }) : super(key: key);

  // Helper method to refresh accounts when navigating back to dashboard
  void _refreshAccountsAndNavigateBack() {
    // Close dialog first
    Get.back(closeOverlays: true);

    // ✅ FIX: Navigate to trading screen with dashboard tab index (3) as argument
    // This will open directly to the dashboard tab showing account list
    Get.offAllNamed('/trading', arguments: 3); // Dashboard is at index 3

    // Explicitly refresh accounts after navigation
    // Use a small delay to ensure navigation completes
    Future.delayed(Duration(milliseconds: 200), () {
      try {
        // Get dashboard controller and force refresh accounts
        if (Get.isRegistered<DashboardController>()) {
          final dashboardController = Get.find<DashboardController>();
          print(
            'CongratulationsDialog: Refreshing accounts after account creation',
          );
          dashboardController.refreshMT5Accounts(force: true);
          // Also ensure WebSocket is initialized
          dashboardController.ensureWebSocketInitialized();

          // Request account data from WebSocket
          if (Get.isRegistered<AccountWebSocketService>()) {
            final accountWS = Get.find<AccountWebSocketService>();
            accountWS.requestAccountData();
          }
        }
      } catch (e) {
        print('CongratulationsDialog: Error refreshing accounts: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: AppColors.card,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 36.h, 24.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Headers
                  Text(
                    'Congratulations!',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'You have successfully created a trading account.',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 28.h),

                  // Account Details Card
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface, // Will adapt to light/dark mode
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Account Number
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Number',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      accountNumber,
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: accountNumber),
                                      );
                                      if (Get.isRegistered<
                                        AppNotificationController
                                      >()) {
                                        Get.find<AppNotificationController>()
                                            .showSuccess(
                                              message:
                                                  'Account number copied to clipboard',
                                              title: 'Copied!',
                                            );
                                      }
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4.w,
                                      ),
                                      child: Icon(
                                        Icons.copy_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Divider
                        Container(
                          height: 40.h,
                          width: 1,
                          color: AppColors.border.withOpacity(0.5),
                          margin: EdgeInsets.symmetric(horizontal: 16.w),
                        ),

                        // Server Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Server Name',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                serverName,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 28.h),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: () {
                        // Close dialog first
                        Get.back(closeOverlays: true);

                        // Navigate to Trading screen
                        Get.offAllNamed('/trading');

                        // Refresh accounts after navigation
                        Future.delayed(Duration(milliseconds: 200), () {
                          try {
                            if (Get.isRegistered<DashboardController>()) {
                              final dashboardController =
                                  Get.find<DashboardController>();
                              dashboardController.refreshMT5Accounts(
                                force: true,
                              );
                              dashboardController.ensureWebSocketInitialized();

                              if (Get.isRegistered<AccountWebSocketService>()) {
                                final accountWS =
                                    Get.find<AccountWebSocketService>();
                                accountWS.requestAccountData();
                              }
                            }
                          } catch (e) {
                            print('Error refreshing accounts: $e');
                          }
                        });

                        // Navigate to appropriate deposit screen
                        Future.delayed(Duration(milliseconds: 500), () {
                          if (accountType?.toLowerCase() == 'demo') {
                            Get.to(
                              () => DepositScreen(accountNumber: accountNumber),
                            );
                          } else {
                            Get.to(
                              () => PaymentMethodsScreen(
                                accountNumber: accountNumber,
                              ),
                            );
                          }
                        });
                      },
                      child: Text(
                        'Make Deposit',
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.pureWhite,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Info Text
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      'Please remember your password. Your real Account ID & Password have been sent to your email. You can always change your password in account settings.',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textGreyLight,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // See Account List Link
                  GestureDetector(
                    onTap: _refreshAccountsAndNavigateBack,
                    child: Text(
                      'See account list',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Close Button (Top Right)
            Positioned(
              top: 16.h,
              right: 16.w,
              child: GestureDetector(
                onTap: _refreshAccountsAndNavigateBack,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface, // Adapts to theme
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textGrey,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
