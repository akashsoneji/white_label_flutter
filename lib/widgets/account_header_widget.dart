import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/flavor_config.dart';

enum AccountHeaderLayoutStyle { defaultLayout, vantageInstruments }

class AccountHeaderWidget extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onSearchTap;
  final bool showSearchIcon;
  final bool showMenuIcon;
  final Widget? rightWidget;
  final EdgeInsets? padding;
  final double? floatingProfit;

  /// When true, reads [TradingController.accountInfoRx] inside [Obx] for P/L.
  final bool useTradingFloatingProfit;
  final AccountHeaderLayoutStyle layoutStyle;

  const AccountHeaderWidget({
    super.key,
    this.onMenuTap,
    this.onSearchTap,
    this.showSearchIcon = true,
    this.showMenuIcon = false,
    this.rightWidget,
    this.padding,
    this.floatingProfit,
    this.useTradingFloatingProfit = false,
    this.layoutStyle = AccountHeaderLayoutStyle.defaultLayout,
  });

  @override
  Widget build(BuildContext context) {
    final AccountController accountController = Get.find<AccountController>();
    // Get DashboardController for primary account (like dashboard screen)
    final DashboardController? dashboardController =
        Get.isRegistered<DashboardController>()
            ? Get.find<DashboardController>()
            : null;

    return SafeArea(
      child: Container(
        padding:
            padding ?? EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            if (showMenuIcon) ...[
              SvgPicture.asset(
                "assets/svg/menu.svg",
                height: 24.h,
                width: 24.w,
                color: AppColors.textPrimary,
              ),
              SizedBox(width: 6.w),
            ],
            Expanded(
              child: Obx(() {
                final activeAccount =
                    accountController.activeMT5AccountRx.value;

                final dash = dashboardController;
                if (dash != null) {
                  dash.mt5Accounts.length;
                }

                final primaryAccount = activeAccount ?? dash?.primaryMT5Account;

                final isWebSocketConnected =
                    dash?.isWebSocketConnectedRx.value ?? false;

                AccountInfo? accountInfo;
                if (primaryAccount != null && dash != null) {
                  accountInfo =
                      dash.accountInfoMap[primaryAccount.metaAccountNumber];
                }

                final double? realTimeEquity = accountInfo?.equity;
                final double? apiEquity =
                    primaryAccount != null
                        ? double.tryParse(primaryAccount.equity)
                        : null;
                final double displayEquity =
                    realTimeEquity ?? (apiEquity ?? 0.0);

                final bool hasAccountInfo =
                    primaryAccount != null &&
                    dash != null &&
                    dash.accountInfoMap.containsKey(
                      primaryAccount.metaAccountNumber,
                    );
                final bool showLoading =
                    primaryAccount != null &&
                    realTimeEquity == null &&
                    (!isWebSocketConnected || !hasAccountInfo) &&
                    displayEquity == 0.0;

                if (primaryAccount != null && dashboardController != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    dashboardController.ensureWebSocketInitialized();
                  });
                }

                double? tradingProfit;
                if (useTradingFloatingProfit &&
                    Get.isRegistered<TradingController>()) {
                  tradingProfit =
                      Get.find<TradingController>().accountInfoRx.value?.profit;
                }

                final double? resolvedFloatingProfit =
                    floatingProfit ?? tradingProfit;
                final bool useFloatingProfit = resolvedFloatingProfit != null;
                final double displayValue =
                    useFloatingProfit ? resolvedFloatingProfit : displayEquity;
                final bool isPositive = displayValue >= 0;

                final valueText =
                    useFloatingProfit
                        ? '\$${PrecisionHelper.formatPnL(displayValue)}'
                        : '\$${displayEquity.toStringAsFixed(2)}';

                final valueColor =
                    useFloatingProfit
                        ? (isPositive ? AppColors.success : AppColors.error)
                        : AppTextStyles.heading.color;

                final accountTypeText = _getAccountTypeText(primaryAccount);
                final accountNumberText = _getAccountNumber(primaryAccount);
                final accountTypeColor = _getAccountTypeColor(primaryAccount);
                final accountTypeTextColor = _getAccountTypeTextColor(
                  primaryAccount,
                );

                final accountSelector = Builder(
                  builder: (pillContext) {
                    return GestureDetector(
                      onTap: () async {
                        accountController.resetToDefaultAccounts();

                        if (layoutStyle ==
                            AccountHeaderLayoutStyle.vantageInstruments) {
                          await _showAccountSelectionPopupMenu(
                            anchorContext: pillContext,
                            accountController: accountController,
                          );
                          return;
                        }

                        _showAccountSelectionBottomSheet(
                          context,
                          accountController,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 28.h,
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.isDarkMode
                                      ? AppColors.surfaceSecondary
                                      : AppColors.card.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.border.withOpacity(0.18),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20.w,
                                  height: 20.w,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.isDarkMode
                                            ? AppColors.surfaceSecondary
                                            : accountTypeColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 12.sp,
                                    color:
                                        AppColors.isDarkMode
                                            ? AppColors.whiteColor
                                            : accountTypeTextColor,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: Text(
                                    accountNumberText,
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.isDarkMode
                                            ? AppColors.surfaceSecondary
                                            : accountTypeColor.withOpacity(
                                              0.12,
                                            ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    accountTypeText.toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          AppColors.isDarkMode
                                              ? AppColors.whiteColor
                                              : accountTypeColor,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );

                final valueRow = Row(
                  children: [
                    if (showLoading && !useFloatingProfit) ...[
                      LoadingAnimationWidget.fourRotatingDots(
                        color: AppColors.primary,
                        size: 18.w,
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Flexible(
                      child: Text(
                        valueText,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: valueColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                );

                switch (layoutStyle) {
                  case AccountHeaderLayoutStyle.vantageInstruments:
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: AppColors.border.withOpacity(0.18),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [SizedBox(height: 2.h), valueRow],
                            ),
                          ),
                          SizedBox(width: 4.w),
                          accountSelector,
                        ],
                      ),
                    );
                  case AccountHeaderLayoutStyle.defaultLayout:
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        valueRow,
                        SizedBox(height: 2.h),
                        accountSelector,
                      ],
                    );
                }
              }),
            ),
            if (rightWidget != null) ...[
              rightWidget!,
            ] else if (showSearchIcon) ...[
              if (FlavorConfig.isVantage())
                Container(
                  margin: EdgeInsets.only(left: 8.w),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: onSearchTap,
                    icon: SvgPicture.asset(
                      "assets/svg/search-normal.svg",
                      height: 20.h,
                      width: 20.w,
                      color: AppColors.primary,
                    ),
                    padding: EdgeInsets.all(8.r),
                    constraints: const BoxConstraints(),
                  ),
                )
              else
                GestureDetector(
                  onTap: onSearchTap,
                  child: SvgPicture.asset(
                    "assets/svg/search-normal.svg",
                    height: 24.h,
                    width: 24.w,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ FIX: Updated to use primary account (MT5Account) instead of AccountController
  Color _getAccountTypeColor(MT5Account? primaryAccount) {
    if (primaryAccount != null) {
      final accountType = primaryAccount.accountType;
      if (accountType.toLowerCase() == "live") {
        return AppColors.accent;
      }
      return AppColors.primary;
    }
    // Default color when no accounts are available
    return AppColors.primary;
  }

  String _getAccountTypeText(MT5Account? primaryAccount) {
    if (primaryAccount != null) {
      final accountType = primaryAccount.accountType;
      // Map account types to display text
      switch (accountType.toLowerCase()) {
        case 'live':
          return 'Live';
        case 'demo':
          return 'DEMO';
        default:
          return accountType.toUpperCase();
      }
    }
    return 'Live'; // Default fallback
  }

  Color _getAccountTypeTextColor(MT5Account? primaryAccount) {
    // In dark mode with light gray backgrounds, use dark text for contrast
    if (AppColors.isDarkMode) {
      if (primaryAccount?.accountType.toLowerCase() == "live") {
        return AppColors.whiteColor; // White text on green/live accent
      }
      return const Color(0xFF1A1A1A); // Dark text for DEMO on light backgrounds
    }
    return AppColors
        .whiteColor; // Light mode: always white on colored backgrounds
  }

  String _getAccountNumber(MT5Account? primaryAccount) {
    // ✅ FIX: Use primary account number (like dashboard screen)
    if (primaryAccount != null) {
      return primaryAccount.metaAccountNumber;
    }
    return ''; // Keep blank while initial account data is loading.
  }

  void _showAccountSelectionBottomSheet(
    BuildContext context,
    AccountController accountController,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Obx(() {
          double dynamicHeight;
          if (accountController.accounts.length <= 2) {
            dynamicHeight = MediaQuery.of(context).size.height * 0.35;
          } else if (accountController.accounts.length <= 3) {
            dynamicHeight = MediaQuery.of(context).size.height * 0.45;
          } else if (accountController.accounts.length <= 4) {
            dynamicHeight = MediaQuery.of(context).size.height * 0.55;
          } else {
            dynamicHeight = MediaQuery.of(context).size.height * 0.65;
          }

          // Compute insets for iOS/Android
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return Padding(
            padding: EdgeInsets.only(
              bottom: bottomInset,
            ),
            child: Container(
              height: dynamicHeight,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                  // bottomLeft and bottomRight are not set, so only top corners are rounded
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 12.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.grey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Account',
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  accountController.isLoading
                      ? Expanded(
                        child: Container(
                          padding: EdgeInsets.all(20.w),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                      : Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom,
                          ),
                          itemCount: accountController.mt5Accounts.length,
                          itemBuilder: (context, index) {
                            final account =
                                accountController.mt5Accounts[index];
                            final isActive =
                                accountController
                                    .activeMT5Account
                                    ?.metaAccountNumber ==
                                account.metaAccountNumber;
                            return Container(
                              child: ListTile(
                                leading: Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.isDarkMode
                                            ? AppColors.surfaceSecondary
                                            : (account.accountType == 'live'
                                                ? AppColors.primary
                                                : AppColors.success),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet,
                                    color:
                                        AppColors.isDarkMode
                                            ? AppColors.whiteColor
                                            : AppColors.whiteColor,
                                    size: 20.h,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      account.accountType.capitalizeFirst ?? '',
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (isActive) ...[
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6.w,
                                          vertical: 2.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success,
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: AppTextStyles.label.copyWith(
                                            fontSize: 8.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.whiteColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ID: ${account.metaAccountNumber}',
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 12.sp,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                    Text(
                                      '\$${account.balance}',
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Radio<String>(
                                  value: account.metaAccountNumber,
                                  groupValue:
                                      accountController
                                          .activeMT5Account
                                          ?.metaAccountNumber,
                                  onChanged: (value) async {
                                    // Disable the radio button while loading
                                    if (accountController.isLoading) {
                                      return;
                                    }

                                    // ✅ FIX: Close bottom sheet immediately for better UX
                                    // Account switch happens in background
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }

                                    try {
                                      // Call API to switch account (runs in background)
                                      accountController.setActiveMT5Account(
                                        value!,
                                      );
                                    } catch (e) {
                                      if (kDebugMode) {
                                        print('Account switch failed: $e');
                                      }
                                    }
                                  },
                                  activeColor: AppColors.primary,
                                ),
                                tileColor:
                                    isActive
                                        ? AppColors.primary.withOpacity(0.1)
                                        : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _showAccountSelectionPopupMenu({
    required BuildContext anchorContext,
    required AccountController accountController,
  }) async {
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    if (overlay == null || renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = position & renderBox.size;

    final selected = await showMenu<String>(
      context: anchorContext,
      color: AppColors.card,
      surfaceTintColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.border.withOpacity(0.18), width: 0.5),
      ),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(rect.left, rect.bottom + 6.h, rect.width, rect.height),
        Offset.zero & overlay.size,
      ),
      items:
          accountController.mt5Accounts.map((account) {
            final isActive =
                accountController.activeMT5Account?.metaAccountNumber ==
                account.metaAccountNumber;
            final type = (account.accountType).toUpperCase();
            final id = account.metaAccountNumber;

            return PopupMenuItem<String>(
              value: id,
              height: 42.h,
              child: Row(
                children: [
                  Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          AppColors.isDarkMode
                              ? AppColors.surfaceSecondary
                              : (type == 'LIVE'
                                      ? AppColors.accent
                                      : AppColors.primary)
                                  .withOpacity(0.16),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 12.sp,
                      color:
                          AppColors.isDarkMode
                              ? AppColors.whiteColor
                              : (type == 'LIVE'
                                  ? AppColors.accent
                                  : AppColors.primary),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      id,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AppColors.isDarkMode
                              ? AppColors.surfaceSecondary
                              : (type == 'LIVE'
                                      ? AppColors.accent
                                      : AppColors.primary)
                                  .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color:
                            AppColors.isDarkMode
                                ? AppColors.whiteColor
                                : (type == 'LIVE'
                                    ? AppColors.accent
                                    : AppColors.primary),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    SizedBox(width: 8.w),
                    Icon(Icons.check, size: 16.sp, color: AppColors.success),
                  ],
                ],
              ),
            );
          }).toList(),
    );

    if (selected == null) return;
    if (accountController.isLoading) return;
    if (accountController.activeMT5Account?.metaAccountNumber == selected) {
      return;
    }

    try {
      await accountController.setActiveMT5Account(selected);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Account switch failed: $e');
      }
    }
  }
}
