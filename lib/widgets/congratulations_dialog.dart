import 'package:flutter/material.dart';
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
    Get.offAllNamed('/trading', arguments: 2); // Dashboard is at index 3

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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.r),
          color: AppColors.card,
        ),
        child: Column(
          children: [
            // Main Content - Centered
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Congratulations Header
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Congratulations!',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.2,
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: GestureDetector(
                                onTap: () {
                                  // Close dialog and navigate to Dashboard with account refresh
                                  _refreshAccountsAndNavigateBack();
                                },
                                child: Container(
                                  width: 23,
                                  height: 23,
                                  decoration: BoxDecoration(
                                    color: AppColors.icongrey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: AppColors.whiteColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'You have successfully Created trading account',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.icongrey,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Account Information
                    Padding(
                      padding: EdgeInsets.only(left: 10.w),
                      child: Row(
                        children: [
                          // Account Number
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Number',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        accountNumber,
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 4),
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
                                      child: Icon(
                                        Icons.copy,
                                        color: AppColors.icongrey,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Server Name',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    Text(
                                      serverName,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Additional Account Details
                    SizedBox(height: 10.h),

                    // Make Deposit Button
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        onPressed: () {
                          // ✅ FIX: Navigate directly to Trading screen first, then to deposit
                          // Using Get.until was going back to login screen during registration flow
                          // because the first route was GetStartedLoginOptionScreen, not dashboard

                          // Close dialog first
                          Get.back(closeOverlays: true);

                          // Navigate to Trading screen, clearing all previous routes
                          // This ensures we're on the main app, not login flow
                          Get.offAllNamed('/trading');

                          // Refresh accounts after navigation
                          Future.delayed(Duration(milliseconds: 200), () {
                            try {
                              if (Get.isRegistered<DashboardController>()) {
                                final dashboardController =
                                    Get.find<DashboardController>();
                                print(
                                  'CongratulationsDialog: Refreshing accounts before deposit navigation',
                                );
                                dashboardController.refreshMT5Accounts(
                                  force: true,
                                );
                                dashboardController
                                    .ensureWebSocketInitialized();

                                if (Get.isRegistered<
                                  AccountWebSocketService
                                >()) {
                                  final accountWS =
                                      Get.find<AccountWebSocketService>();
                                  accountWS.requestAccountData();
                                }
                              }
                            } catch (e) {
                              print(
                                'CongratulationsDialog: Error refreshing accounts: $e',
                              );
                            }
                          });

                          // Navigate to PaymentMethodsScreen after accounts refresh
                          Future.delayed(Duration(milliseconds: 500), () {
                            print(
                              'accountNumber when we make deposit: $accountNumber',
                            );
                            // Check if account is demo, navigate to DepositScreen
                            // Otherwise navigate to PaymentMethodsScreen
                            if (accountType?.toLowerCase() == 'demo') {
                              Get.to(
                                () =>
                                    DepositScreen(accountNumber: accountNumber),
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
                          style: TextStyle(color: AppColors.whiteColor),
                        ),
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // Information Text
                    Text(
                      'Please remember your password. And also note that your real Account ID & Password has been sent to your email ID, you can always change your password in Account setting reset',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.icongrey,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 16),

                    // See Account List Link
                    GestureDetector(
                      onTap: () {
                        // Navigate to Dashboard (account list) with account refresh
                        _refreshAccountsAndNavigateBack();
                      },
                      child: Text(
                        'See account list',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
