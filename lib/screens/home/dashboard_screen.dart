import 'dart:ui';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/brand_switcher.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import '../../widgets/common_loading_widget.dart';
import '../../services/auth_service.dart';
import '../../services/account_websocket_service.dart';
import '../../widgets/custom_toast.dart';
import '../../utils/trl_helper.dart';
import 'package:crm_app/utils/svg_color_helper.dart';
import 'change_leverage_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/internal_transfer_screen.dart';
import 'package:crm_app/screens/finance/presentation/finance_ui_scope.dart';
import 'package:crm_app/screens/home/brands/vantage/vantage_dashboard_layout.dart';
import 'package:crm_app/screens/home/brands/vantage/vantage_glass_tokens.dart';
import 'package:crm_app/brands/celestial/celestial_theme.dart';
import 'package:crm_app/widgets/app_svg_icon.dart';
import 'package:crm_app/widgets/vantage/vantage_app_bar.dart';
import 'package:crm_app/screens/wallet/view_models/wallet_controller.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  DashboardScreen({this.onNavigateToTab});

  late final DashboardController controller = Get.put(DashboardController());

  Future<void> _onRefresh() async {
    // Call account get API when refresh is triggered
    await controller.refreshMT5Accounts(force: true);
    // Refresh wallet balance
    try {
      final walletCtrl =
          Get.isRegistered<WalletController>()
              ? Get.find<WalletController>()
              : Get.put(WalletController());
      walletCtrl.fetchWalletData();
    } catch (_) {}
    // Also request account data from WebSocket
    try {
      if (Get.isRegistered<AccountWebSocketService>()) {
        final accountWS = Get.find<AccountWebSocketService>();
        // Request account data refresh
        accountWS.requestAccountData();
      }
    } catch (e) {
      // ignore
    }
  }

  BoxDecoration _vantageGlassCardDecoration() =>
      VantageUiTokens.cardDecoration();

  BoxDecoration _vantageSegmentedBarDecoration() =>
      VantageUiTokens.groupDecoration();

  // ── Default (non-vantage, non-celestial) header wallet pill ────────────────
  Widget _buildWalletHeaderButton() {
    final walletCtrl =
        Get.isRegistered<WalletController>()
            ? Get.find<WalletController>()
            : Get.put(WalletController());

    return Container(
      constraints: BoxConstraints(maxWidth: 150.w),
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed(AppPages.WALLET),
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(
                  assetPath: 'assets/svg/deshboard/empty-wallet-add.svg',
                  height: 20.h,
                  width: 20.w,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6.w),
                Flexible(
                  child: Obx(() {
                    final bal = walletCtrl.balance.value;
                    final displayBal = bal.isEmpty ? '0.00' : bal;
                    final formattedBal =
                        displayBal.startsWith('\$')
                            ? displayBal
                            : '\$$displayBal';
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formattedBal,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Celestial wallet pill (lighter, MT5-inspired) ─────────────────────────
  Widget _buildCelestialWalletHeaderButton(BuildContext context) {
    final walletCtrl =
        Get.isRegistered<WalletController>()
            ? Get.find<WalletController>()
            : Get.put(WalletController());

    return Container(
      constraints: BoxConstraints(maxWidth: 150.w),
      height: 36.h,
      decoration: BoxDecoration(
        color: CelTheme.buyTint(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: CelTheme.divider(context), width: 0.6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed(AppPages.WALLET),
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(
                  assetPath: 'assets/svg/deshboard/empty-wallet-add.svg',
                  height: 16.h,
                  width: 16.w,
                  color: CelTheme.buyBlue,
                ),
                SizedBox(width: 6.w),
                Flexible(
                  child: Obx(() {
                    final bal = walletCtrl.balance.value;
                    final displayBal = bal.isEmpty ? '0.00' : bal;
                    final formattedBal =
                        displayBal.startsWith('\$')
                            ? displayBal
                            : '\$$displayBal';
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formattedBal,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: CelTheme.mainText(context),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelestialHeaderIconButton(
    BuildContext context, {
    required String assetPath,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 36.h,
      width: 36.w,
      decoration: BoxDecoration(
        color: CelTheme.buyBlue,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: IconButton(
        icon: AppSvgIcon(
          assetPath: assetPath,
          height: 18.h,
          width: 18.w,
          color: Colors.white,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildCelestialBackButton(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        color: CelTheme.mainText(context),
        size: 18.sp,
      ),
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Get.back();
        }
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildHeaderIconButton({
    required String assetPath,
    required VoidCallback onPressed,
    EdgeInsets? margin,
    String? label,
  }) {
    // Label variant renders a wider pill so the full label fits without
    // ellipsis (e.g. "Create Account"). Icon-only variant stays compact.
    final double buttonW = label != null ? 96.w : 36.w;
    final double buttonH = label != null ? 36.h : 36.h;
    return Container(
      margin: margin,
      height: buttonH,
      width: buttonW,
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.whiteColor,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          minimumSize: Size(buttonW, buttonH),
          maximumSize: Size(buttonW, buttonH),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          elevation: 0,
        ),
        child:
            label != null
                ? Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -0.3,
                  ),
                )
                : Center(
                  child: AppSvgIcon(
                    assetPath: assetPath,
                    height: 18.h,
                    width: 18.w,
                    color: AppColors.whiteColor,
                  ),
                ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // CELESTIAL — REIMAGINED DASHBOARD CONTENT (MT5-inspired)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildCelestialDashboardContent(BuildContext context) {
    return Container(
      color: CelTheme.bg(context),
      child: Obx(() {
        final isEmpty = controller.mt5Accounts.isEmpty;
        return Stack(
          children: [
            AnimatedOpacity(
              opacity: controller.isBottomSheetOpen.value ? 0.3 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: CustomScrollView(
                cacheExtent: 500,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildCelestialEmptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: 16.w,
                        right: 16.w,
                        top: 8.h,
                        bottom:
                            16 + 77.h + MediaQuery.of(context).padding.bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final account = controller.mt5Accounts[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 14.h),
                            child: _buildCelestialAccountCard(context, account),
                          );
                        }, childCount: controller.mt5Accounts.length),
                      ),
                    ),
                ],
              ),
            ),
            if (controller.isLoadingMT5Accounts.value)
              Center(
                child: CommonLoadingWidget(
                  isFullScreen: true,
                  color: CelTheme.buyBlue,
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildCelestialEmptyState(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
          decoration: BoxDecoration(
            color: CelTheme.card(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: CelTheme.divider(context), width: 0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact icon — small square chip, not a giant circle
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.whiteColor,
                  size: 22.sp,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                languageService.tr('dashboard_new_account_title'),
                style: AppTextStyles.bodyText.copyWith(
                  color: CelTheme.headerText(context),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                languageService.tr('dashboard_new_account_description'),
                style: AppTextStyles.bodyText.copyWith(
                  color: CelTheme.subText(context),
                  fontSize: 11.sp,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 14.h),
              // Two CTAs side by side (compact, equal width)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38.h,
                      child: OutlinedButton(
                        onPressed: controller.openRealAccount,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary, width: 1),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          languageService.tr('dashboard_open_real_account'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: SizedBox(
                      height: 38.h,
                      child: ElevatedButton(
                        onPressed: controller.openDemoAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          languageService.tr('dashboard_open_demo_account'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
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

  // ════════════════════════════════════════════════════════════════════════
  // IQUOTE — INNOVATIVE THEME DASHBOARD CONTENT
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildIquoteDashboardContent(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F1421) : const Color(0xFFF4F6F9);

    return Container(
      color: bgColor,
      child: Obx(() {
        final accounts = controller.mt5Accounts;
        final isEmpty = accounts.isEmpty;

        return Stack(
          children: [
            AnimatedOpacity(
              opacity: controller.isBottomSheetOpen.value ? 0.3 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildCelestialEmptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final account = accounts[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 8.h),
                            child: _buildIquoteAccountCard(context, account),
                          );
                        }, childCount: accounts.length),
                      ),
                    ),
                ],
              ),
            ),
            if (controller.isLoadingMT5Accounts.value)
              Center(
                child: CommonLoadingWidget(
                  isFullScreen: true,
                  color: AppColors.primary,
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildIquoteAccountCard(BuildContext context, MT5Account account) {
    final accountController = Get.find<AccountController>();
    final dashboardController = Get.find<DashboardController>();
    final languageService = Get.find<LanguageService>();
    final isDark = AppColors.isDarkMode;

    final cardBg = isDark ? const Color(0xFF161B29) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white54 : AppColors.textSecondary;

    return Obx(() {
      final activeAcc = accountController.activeMT5Account;
      final isActive =
          (activeAcc?.metaAccountNumber == account.metaAccountNumber) ||
          account.isPrimaryAccount;
      final isDemo = account.accountType.toLowerCase() == 'demo';

      final accountInfo = dashboardController.getAccountInfo(
        account.metaAccountNumber,
      );
      final balance =
          accountInfo?.balance ?? double.tryParse(account.balance) ?? 0.0;
      final equity =
          accountInfo?.equity ?? double.tryParse(account.equity) ?? balance;
      final pnl = accountInfo?.profit ?? double.tryParse(account.profit) ?? 0.0;
      final leverage =
          account.leverageMax > 0 ? '1:${account.leverageMax}' : '1:500';

      final borderColor =
          isActive
              ? AppColors.primary
              : (isDark
                  ? const Color(0xFF232A3B)
                  : AppColors.border.withValues(alpha: 0.12));

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: borderColor, width: isActive ? 1.3 : 0.8),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Column(
          children: [
            // Row 1: Account # | DEMO/LIVE | ACTIVE -- Balance & 3-Dot Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '#${account.metaAccountNumber}',
                      style: AppTextStyles.bodyText.copyWith(
                        color: textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.w,
                        vertical: 1.5.h,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDemo
                                ? Colors.orange.withValues(alpha: 0.12)
                                : Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                      child: Text(
                        isDemo ? 'DEMO' : 'LIVE',
                        style: AppTextStyles.bodyText.copyWith(
                          color: isDemo ? Colors.orange : Colors.green,
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      SizedBox(width: 5.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 5.w,
                          vertical: 1.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                  
                ),
                Row(
                  children: [
                    Text(
                      '${account.isCentAccount ? '¢' : '\$'}${balance.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyText.copyWith(
                        color: textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    InkWell(
                      onTap: () => _showAccountMenuBottomSheet(account),
                      borderRadius: BorderRadius.circular(4.r),
                      child: Padding(
                        padding: EdgeInsets.all(2.r),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: textSecondary,
                          size: 16.r,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 4.h),

            // Row 2: Equity & PnL details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Eq: ${account.isCentAccount ? '¢' : '\$'}${equity.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyText.copyWith(
                        color: textSecondary,
                        fontSize: 10.5.sp,
                      ),
                    ),
                    Text(
                      ' • ',
                      style: AppTextStyles.bodyText.copyWith(
                        color: textSecondary,
                        fontSize: 10.5.sp,
                      ),
                    ),
                    Text(
                      'P&L: ${pnl >= 0 ? '+' : '-'}\$${pnl.abs().toStringAsFixed(2)}',
                      style: AppTextStyles.bodyText.copyWith(
                        color:
                            pnl >= 0
                                ? const Color(0xFF2ED573)
                                : const Color(0xFFFF4757),
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' • $leverage',
                      style: AppTextStyles.bodyText.copyWith(
                        color: textSecondary,
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // Row 3: Action Buttons Row (Trade, Deposit, Withdrawal, Switch)
            Row(
              children: [
                // Trade Icon Button
                InkWell(
                  onTap: () async {
                    await accountController.setActiveMT5Account(
                      account.metaAccountNumber,
                    );
                    if (FlavorConfig.usesIquoteUi() &&
                        Get.context != null &&
                        Navigator.of(Get.context!).canPop()) {
                      Navigator.of(Get.context!).pop();
                    }
                    if (onNavigateToTab != null) {
                      onNavigateToTab!(2);
                    }
                  },
                  borderRadius: BorderRadius.circular(6.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.candlestick_chart_outlined,
                      color: AppColors.primary,
                      size: 15.r,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),

                // Deposit Button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (isDemo) {
                        controller.onDeposit(account.metaAccountNumber);
                      } else {
                        controller.onDepositRealAccount(
                          account.metaAccountNumber,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(6.r),
                    child: Container(
                      height: 28.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ED573).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: const Color(
                            0xFF2ED573,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        languageService.tr('dashboard_deposit'),
                        style: AppTextStyles.bodyText.copyWith(
                          color: const Color(0xFF2ED573),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),

                // Withdrawal / Settings Button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (isDemo) {
                        controller.onSettings(account.metaAccountNumber);
                      } else {
                        controller.onWithdraw(account.metaAccountNumber);
                      }
                    },
                    borderRadius: BorderRadius.circular(6.r),
                    child: Container(
                      height: 28.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            isDemo
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : const Color(
                                  0xFFFF4757,
                                ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color:
                              isDemo
                                  ? AppColors.primary.withValues(alpha: 0.25)
                                  : const Color(
                                    0xFFFF4757,
                                  ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        isDemo
                            ? languageService.tr('more_settings')
                            : languageService.tr('dashboard_withdraw'),
                        style: AppTextStyles.bodyText.copyWith(
                          color:
                              isDemo
                                  ? AppColors.primary
                                  : const Color(0xFFFF4757),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),

                // Switch Account Button (if not active)
                if (!isActive)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        accountController
                            .setActiveMT5Account(account.metaAccountNumber)
                            .then((_) {
                              if (FlavorConfig.usesIquoteUi() &&
                                  Get.context != null &&
                                  Navigator.of(Get.context!).canPop()) {
                                Navigator.of(Get.context!).pop();
                              }
                            });
                      },
                      borderRadius: BorderRadius.circular(6.r),
                      child: Container(
                        height: 28.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Switch',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCelestialAccountCard(BuildContext context, MT5Account account) {
    final dashboardController = Get.find<DashboardController>();
    final languageService = Get.find<LanguageService>();

    return Obx(() {
      final accountInfo = dashboardController.getAccountInfo(
        account.metaAccountNumber,
      );

      final balance =
          accountInfo != null
              ? accountInfo.balance
              : double.tryParse(account.balance.toString()) ?? 0;
      final equity =
          accountInfo != null
              ? accountInfo.equity
              : double.tryParse(account.equity.toString()) ?? 0;
      final margin =
          accountInfo != null
              ? accountInfo.margin
              : (double.tryParse(account.margin.toString()) ?? 0);
      final marginFree =
          accountInfo != null
              ? accountInfo.marginFree
              : (double.tryParse(account.freeMargin.toString()) ?? 0);
      final pnl = accountInfo?.profit ?? 0;

      final isLive = account.accountType.toLowerCase() == 'live';
      final accentColor = isLive ? CelTheme.sell(context) : CelTheme.buyBlue;
      final accentTint =
          isLive ? CelTheme.pillBg(context) : CelTheme.buyTint(context);

      return Container(
        decoration: BoxDecoration(
          color: CelTheme.card(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: CelTheme.divider(context), width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: account# + LIVE/DEMO pill + actions (compact) ───────────
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 6.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.metaAccountNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              color: CelTheme.headerText(context),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: accentTint,
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: Text(
                            account.accountType.capitalizeFirst ?? '',
                            style: AppTextStyles.bodyText.copyWith(
                              color: accentColor,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (account.masterGroupId.toLowerCase() ==
                            'scratchcard') ...[
                          SizedBox(width: 4.w),
                          BrandLogo(
                            source: 'assets/svg/more/scratch.svg',
                            height: 14,
                            width: 14,
                            color: accentColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _showAccountInfoBottomSheet(account),
                    borderRadius: BorderRadius.circular(6.r),
                    child: Padding(
                      padding: EdgeInsets.all(6.w),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: CelTheme.subText(context),
                        size: 16.sp,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showAccountMenuBottomSheet(account),
                    borderRadius: BorderRadius.circular(6.r),
                    child: Padding(
                      padding: EdgeInsets.all(6.w),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: CelTheme.subText(context),
                        size: 16.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Compact balance + P/L pill (single row) ───────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageService.tr('dashboard_balance'),
                        style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.subText(context),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.mainText(context),
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          pnl >= 0
                              ? CelTheme.tpGreen.withOpacity(0.10)
                              : CelTheme.slRed.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pnl >= 0
                              ? Icons.arrow_drop_up_rounded
                              : Icons.arrow_drop_down_rounded,
                          color: pnl >= 0 ? CelTheme.tpGreen : CelTheme.slRed,
                          size: 16.sp,
                        ),
                        Text(
                          '${pnl >= 0 ? '+' : '-'}\$${pnl.abs().toStringAsFixed(2)}',
                          style: AppTextStyles.bodyText.copyWith(
                            color: pnl >= 0 ? CelTheme.tpGreen : CelTheme.slRed,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3-col compact stat strip
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: CelTheme.buyTint(context).withOpacity(0.45),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCelestialMiniStat(
                        context,
                        label: languageService.tr('dashboard_equity'),
                        value: '\$${equity.toStringAsFixed(2)}',
                      ),
                    ),
                    _buildCelestialVDivider(context),
                    Expanded(
                      child: _buildCelestialMiniStat(
                        context,
                        label: languageService.tr('trade_metric_margin'),
                        value: '\$${margin.toStringAsFixed(2)}',
                      ),
                    ),
                    _buildCelestialVDivider(context),
                    Expanded(
                      child: _buildCelestialMiniStat(
                        context,
                        label: languageService.tr('trade_metric_free_margin'),
                        value: '\$${marginFree.toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Server meta
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    color: CelTheme.subText(context),
                    size: 11.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '${account.tradingServer.capitalizeFirst} • ${account.masterGroupId}',
                    style: AppTextStyles.bodyText.copyWith(
                      color: CelTheme.subText(context),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 10.h),

            // ── Action row: Trade | Deposit | Withdraw/Settings ──────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Row(
                children: [
                  // Trade — square icon button
                  _buildCelestialIconAction(
                    context,
                    icon: Icons.candlestick_chart_outlined,
                    color: CelTheme.buyBlue,
                    onTap: () async {
                      final accountController = Get.find<AccountController>();
                      await accountController.setActiveMT5Account(
                        account.metaAccountNumber,
                      );
                      if (FlavorConfig.usesIquoteUi() &&
                          Get.context != null &&
                          Navigator.of(Get.context!).canPop()) {
                        Navigator.of(Get.context!).pop();
                      }
                      if (onNavigateToTab != null) {
                        onNavigateToTab!(FlavorConfig.isVantage() ? 2 : 2);
                      }
                    },
                  ),
                  SizedBox(width: 8.w),
                  // Deposit
                  Expanded(
                    child: _buildCelestialFilledAction(
                      context,
                      label: languageService.tr('dashboard_deposit'),
                      color: CelTheme.tpGreen,
                      onTap: () {
                        if (account.accountType.toLowerCase() == 'live') {
                          controller.onDepositRealAccount(
                            account.metaAccountNumber,
                          );
                        } else {
                          controller.onDeposit(account.metaAccountNumber);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Withdraw / Settings
                  Expanded(
                    child: _buildCelestialFilledAction(
                      context,
                      label:
                          account.accountType.toLowerCase() == 'live'
                              ? languageService.tr('dashboard_withdraw')
                              : languageService.tr('more_settings'),
                      color: isLive ? CelTheme.sellRed : CelTheme.buyBlue,
                      onTap: () {
                        if (account.accountType.toLowerCase() == 'live') {
                          controller.onWithdraw(account.metaAccountNumber);
                        } else {
                          controller.onSettings(account.metaAccountNumber);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Switch to Trade (only non-primary) ──────────────────────
            if (!account.isPrimaryAccount) ...[
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: SizedBox(
                  width: double.infinity,
                  height: 38.h,
                  child: OutlinedButton(
                    onPressed: () {
                      final accountController = Get.find<AccountController>();
                      accountController
                          .setActiveMT5Account(account.metaAccountNumber)
                          .then((_) {
                            if (FlavorConfig.usesIquoteUi() &&
                                Get.context != null &&
                                Navigator.of(Get.context!).canPop()) {
                              Navigator.of(Get.context!).pop();
                            }
                          })
                          .catchError((e) {
                            if (kDebugMode) {
                              print('Account switch failed: $e');
                            }
                          });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: CelTheme.buyBlue, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 16.sp,
                          color: CelTheme.buyBlue,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          languageService.tr('dashboard_switch_to_trade'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: CelTheme.buyBlue,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            SizedBox(height: 14.h),
          ],
        ),
      );
    });
  }

  // Celestial compact helper: mini stat cell
  Widget _buildCelestialMiniStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            color: CelTheme.subText(context),
            fontSize: 8.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            color: CelTheme.mainText(context),
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // Celestial compact helper: thin vertical divider
  Widget _buildCelestialVDivider(BuildContext context) {
    return Container(
      width: 0.6,
      height: 22.h,
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      color: CelTheme.divider(context).withOpacity(0.7),
    );
  }

  // ── Celestial helper: square icon action (Trade) ────────────────────────
  Widget _buildCelestialIconAction(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        width: 44.h,
        height: 44.h,
        decoration: BoxDecoration(
          color: CelTheme.buyTint(context),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: CelTheme.divider(context), width: 0.6),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 20.sp),
      ),
    );
  }

  // ── Celestial helper: solid filled action (Deposit / Withdraw) ───────────
  Widget _buildCelestialFilledAction(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          height: 44.h,
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // DEFAULT (non-Celestial) DASHBOARD CONTENT — unchanged behavior
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardContent(
    BuildContext context, {
    required bool includeLoadingOverlay,
  }) {
    final isVantage = FlavorConfig.isVantage();
    final languageService = Get.find<LanguageService>();

    return Container(
      color: AppColors.tradeBackgroundCenterColor,
      child: Obx(() {
        final isEmpty = controller.mt5Accounts.isEmpty;
        return Stack(
          children: [
            AnimatedOpacity(
              opacity: controller.isBottomSheetOpen.value ? 0.3 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: CustomScrollView(
                cacheExtent: 500,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Vantage renders its AppBar via the parent scaffold
                  // (VantageDashboardLayout). Celestial renders a single
                  // AppBar in this build() method (see below), so no inner
                  // sliver AppBar is needed for either.
                  if (isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18.w,
                            vertical: 18.h,
                          ),
                          constraints: const BoxConstraints(maxWidth: 520),
                          decoration: null,
                          // isVantage
                          // ? _vantageGlassCardDecoration()
                          // : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FutureBuilder<Widget>(
                                future: SvgColorHelper.loadSvgWithColor(
                                  assetPath:
                                      'assets/svg/deshboard/no_account.svg',
                                  targetColor: AppColors.primary,
                                  colorToReplace: '#5F259E',
                                  height: 96.h,
                                  width: 96.w,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return snapshot.data!;
                                  }
                                  return SizedBox(height: 96.h, width: 96.w);
                                },
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                languageService.tr(
                                  'dashboard_new_account_title',
                                ),
                                style: AppTextStyles.heading,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                languageService.tr(
                                  'dashboard_new_account_description',
                                ),
                                style: AppTextStyles.grey14400h57,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 14.h),
                              SizedBox(
                                height: 44.h,
                                width: 333.w,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  onPressed: controller.openRealAccount,
                                  child: Text(
                                    languageService.tr(
                                      'dashboard_open_real_account',
                                    ),
                                    style: AppTextStyles.black14600h1_71
                                        .copyWith(color: AppColors.primary),
                                  ),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              SizedBox(
                                height: 44.h,
                                width: 333.w,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    side: BorderSide(
                                      color: AppColors.backgroundLight,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  onPressed: controller.openDemoAccount,
                                  child: Text(
                                    languageService.tr(
                                      'dashboard_open_demo_account',
                                    ),
                                    style: AppTextStyles.black14600h1_71
                                        .copyWith(color: AppColors.whiteColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: isVantage ? 8.h : 16,
                        bottom:
                            16 +
                            (isVantage ? 90.h : 77.h) +
                            MediaQuery.of(context).padding.bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final account = controller.mt5Accounts[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 16),
                            child: _buildAccountCard(account),
                          );
                        }, childCount: controller.mt5Accounts.length),
                      ),
                    ),
                ],
              ),
            ),
            if (includeLoadingOverlay && controller.isLoadingMT5Accounts.value)
              Center(child: CommonLoadingWidget(isFullScreen: true)),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final isVantage = FlavorConfig.isVantage();
    final isCelestial = BrandSwitcher.isCelestial;
    // ✅ FIX: Ensure WebSocket is initialized and always refresh accounts when Dashboard appears
    // This works for Get.back, Get.offAll, and bottom navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.ensureWebSocketInitialized();
      // Always call get account API when dashboard appears (bypass throttling)
      controller.refreshMT5Accounts(force: true);
      // Fetch wallet balance
      try {
        final walletCtrl =
            Get.isRegistered<WalletController>()
                ? Get.find<WalletController>()
                : Get.put(WalletController());
        walletCtrl.fetchWalletData();
      } catch (_) {}
      // Dashboard controller will handle account data request via _requestAccountData()
    });
    // Set the navigation callback in the controller
    if (onNavigateToTab != null) {
      controller.setNavigationCallback(onNavigateToTab!);
    }

    final appBar =
        isVantage
            ? VantageAppBar(
              backgroundColor: AppColors.tradeBackgroundCenterColor,
              showBack: false,
              centerTitle: true,
              leadingWidth: 180.w,
              leading: Padding(
                padding: EdgeInsets.only(left: 16.w),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildWalletHeaderButton(),
                ),
              ),
              title: Text('', style: AppTextStyles.screenTitle),
              actions: [
                _buildHeaderIconButton(
                  assetPath: 'assets/svg/deshboard/add-square.svg',
                  onPressed: controller.showOpenAccountSheet,
                  margin: EdgeInsets.only(right: 16.w),
                ),
              ],
            )
            : isCelestial
            ? AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: CelTheme.bg(context),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              leadingWidth: 220.w,
              leading: Padding(
                padding: EdgeInsets.only(left: 16.w),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Padding(
                        padding: EdgeInsets.only(right: 12.w),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20.r,
                          color: CelTheme.headerText(context),
                        ),
                      ),
                    ),
                    _buildCelestialWalletHeaderButton(context),
                  ],
                ),
              ),
              centerTitle: false,
              // title: Padding(
              //   padding: EdgeInsets.only(left: 4.w),
              //   child: Text(
              //     'Trading account',
              //     style: AppTextStyles.bodyText.copyWith(
              //       color: CelTheme.headerText(context),
              //       fontSize: 17.sp,
              //       fontWeight: FontWeight.w700,
              //     ),
              //   ),
              // ),
              actions: [
                _buildCelestialHeaderIconButton(
                  context,
                  assetPath: 'assets/svg/deshboard/add-square.svg',
                  onPressed: controller.showOpenAccountSheet,
                ),
                SizedBox(width: 16.w),
              ],
            )
            : AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: AppColors.background,
              elevation: 0,
              automaticallyImplyLeading: false,
              leadingWidth: 220.w,
              leading: Padding(
                padding: EdgeInsets.only(left: 16.w),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Padding(
                        padding: EdgeInsets.only(right: 12.w),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20.r,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _buildWalletHeaderButton(),
                  ],
                ),
              ),
              // title: Text('', style: AppTextStyles.screenTitle),
              // centerTitle: true,
              actions: [
                _buildHeaderIconButton(
                  label: 'Create Account',
                  assetPath: 'assets/svg/deshboard/add-square.svg',
                  onPressed: controller.showOpenAccountSheet,
                  margin: EdgeInsets.only(right: 16.w),
                ),
              ],
            );

    // ── iQuote full-screen scaffold ─────────────────────────────────────
    if (FlavorConfig.usesIquoteUi()) {
      final isDark = AppColors.isDarkMode;
      final bgColor =
          isDark ? const Color(0xFF0F1421) : const Color(0xFFF4F6F9);
      return Scaffold(
        backgroundColor: bgColor,
        appBar: appBar,
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: _buildIquoteDashboardContent(context),
        ),
      );
    }

    // ── Celestial full-screen scaffold ───────────────────────────────────
    if (isCelestial) {
      return Scaffold(
        backgroundColor: CelTheme.bg(context),
        appBar: appBar,
        // No outer Obx here — _buildCelestialDashboardContent owns its own
        // reactive scope. Wrapping RefreshIndicator in an empty Obx
        // triggers GetX "improper use" error.
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: CelTheme.buyBlue,
          backgroundColor: CelTheme.card(context),
          child: _buildCelestialDashboardContent(context),
        ),
      );
    }

    // Vantage-only wrapper: keeps entry screen logic, moves layout shell to a brand file.
    if (isVantage) {
      return Obx(
        () => VantageDashboardLayout(
          appBar: appBar,
          backgroundColor: AppColors.tradeBackgroundCenterColor,
          onRefresh: _onRefresh,
          dimmed: controller.isBottomSheetOpen.value,
          // prevent double overlay: Vantage layout owns the overlay
          loadingOverlay:
              controller.isLoadingMT5Accounts.value
                  ? Center(child: CommonLoadingWidget(isFullScreen: true))
                  : null,
          child: _buildDashboardContent(context, includeLoadingOverlay: false),
        ),
      );
    }

    // Non-vantage: keep existing scaffold behavior.
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: appBar,
      body: Obx(
        () => RefreshIndicator(
          onRefresh: _onRefresh,
          child: _buildDashboardContent(context, includeLoadingOverlay: true),
        ),
      ),
    );
  }

  void _showAccountInfoBottomSheet(MT5Account account) {
    Get.bottomSheet(
      AccountInfoBottomSheet(account: account),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showAccountMenuBottomSheet(MT5Account account) {
    Get.bottomSheet(
      AccountMenuBottomSheet(account: account),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildAccountCard(MT5Account account) {
    final dashboardController = Get.find<DashboardController>();

    return Obx(() {
      final accountInfo = dashboardController.getAccountInfo(
        account.metaAccountNumber,
      );

      return _buildAccountCardContent(account, accountInfo);
    });
  }

  Widget _buildAccountCardContent(
    MT5Account account,
    AccountInfo? accountInfo,
  ) {
    final languageService = Get.find<LanguageService>();
    final isVantage = FlavorConfig.isVantage();
    return Container(
      padding: EdgeInsets.all(isVantage ? 14 : 12),
      decoration:
          isVantage
              ? VantageUiTokens.cardDecoration()
              : BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.divider.withOpacity(0.5),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.metaAccountNumber,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      height: 22,
                      width: 42,
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      alignment: Alignment.center,
                      // padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            AppColors.isDarkMode
                                ? Colors.white.withOpacity(0.12)
                                : (account.accountType == 'live'
                                    ? AppColors.accent
                                    : AppColors.blue),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        account.accountType.capitalizeFirst ?? '',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              AppColors.isDarkMode
                                  ? Colors.white
                                  : Colors.white,
                        ),
                      ),
                    ),
                    if (account.masterGroupId.toLowerCase() ==
                        'scratchcard') ...[
                      SizedBox(width: 8),
                      BrandLogo(
                        source: "assets/svg/more/scratch.svg",
                        height: 22,
                        width: 22,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            languageService.tr('dashboard_equity'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textGrey,
                            ),
                          ),
                          Text(
                            accountInfo != null
                                ? '\$${accountInfo.equity.toStringAsFixed(2)}'
                                : '\$${account.equity}',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 4),
                      InkWell(
                        onTap: () => _showAccountInfoBottomSheet(account),
                        borderRadius: BorderRadius.circular(999),
                        child: AppSvgIcon(
                          assetPath: 'assets/svg/info-circle.svg',
                          height: 24,
                          width: 24,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Account Type
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: ' ${account.accountType.capitalizeFirst}\t\t',
                      style: AppTextStyles.bodyText.copyWith(
                        backgroundColor:
                            AppColors.isDarkMode
                                ? Colors.white.withOpacity(0.12)
                                : (isVantage
                                    ? AppColors.primary.withValues(alpha: 0.10)
                                    : AppColors.accent.withAlpha(50)),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    TextSpan(
                      text: '\t${account.masterGroupId}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color:
                            isVantage ? AppColors.textGrey : AppColors.icongrey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isVantage ? 12 : 16),

          // Vantage: keep layout dense (no extra chips)

          // Action Buttons
          isVantage
              ? Container(
                decoration: _vantageSegmentedBarDecoration(),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        final accountController = Get.find<AccountController>();
                        await accountController.setActiveMT5Account(
                          account.metaAccountNumber,
                        );
                        if (FlavorConfig.usesIquoteUi() &&
                            Get.context != null &&
                            Navigator.of(Get.context!).canPop()) {
                          Navigator.of(Get.context!).pop();
                        }
                        if (onNavigateToTab != null) {
                          onNavigateToTab!(FlavorConfig.isVantage() ? 2 : 2);
                        }
                      },
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 6.h,
                          horizontal: 8.w,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.isDarkMode
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.cardBackGround,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppColors.border.withValues(
                              alpha: AppColors.isDarkMode ? 0.28 : 0.14,
                            ),
                          ),
                        ),
                        child: AppSvgIcon(
                          assetPath:
                              'assets/svg/bottom_navigation/candle_bold.svg',
                          height: 16.h,
                          width: 16.w,
                          color:
                              AppColors.isDarkMode
                                  ? AppColors.primary
                                  : AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildActionButton(
                        compact: true,
                        color: AppColors.green,
                        isSvg: true,
                        icon: Icons.add,
                        svg: 'assets/svg/deshboard/money-recive.svg',
                        label: languageService.tr('dashboard_deposit'),
                        onTap: () {
                          if (account.accountType.toLowerCase() == 'live') {
                            controller.onDepositRealAccount(
                              account.metaAccountNumber,
                            );
                          } else {
                            controller.onDeposit(account.metaAccountNumber);
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildActionButton(
                        compact: true,
                        color:
                            account.accountType.toLowerCase() == 'live'
                                ? AppColors.red
                                : AppColors.primary,
                        isSvg: true,
                        svg:
                            account.accountType.toLowerCase() == 'live'
                                ? "assets/svg/deshboard/money-send.svg"
                                : 'assets/svg/more/settings.svg',
                        icon:
                            account.accountType.toLowerCase() == 'live'
                                ? Icons.trending_down
                                : Icons.settings,
                        label:
                            account.accountType.toLowerCase() == 'live'
                                ? languageService.tr('dashboard_withdraw')
                                : languageService.tr('more_settings'),
                        onTap: () {
                          if (account.accountType.toLowerCase() == 'live') {
                            controller.onWithdraw(account.metaAccountNumber);
                          } else {
                            controller.onSettings(account.metaAccountNumber);
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    InkWell(
                      onTap: () => _showAccountMenuBottomSheet(account),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 6.h,
                          horizontal: 8.w,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackGround,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppColors.border.withValues(
                              alpha: AppColors.isDarkMode ? 0.28 : 0.14,
                            ),
                          ),
                        ),
                        child: AppSvgIcon(
                          assetPath: 'assets/svg/deshboard/Three_dot.svg',
                          height: 14.h,
                          width: 14.w,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : Row(
                children: [
                  // Trade icon with InkWell
                  InkWell(
                    onTap: () async {
                      // Call setActiveMT5Account which handles socket reconnection
                      final accountController = Get.find<AccountController>();
                      await accountController.setActiveMT5Account(
                        account.metaAccountNumber,
                      );
                      if (FlavorConfig.usesIquoteUi() &&
                          Get.context != null &&
                          Navigator.of(Get.context!).canPop()) {
                        Navigator.of(Get.context!).pop();
                      }
                      if (onNavigateToTab != null) {
                        onNavigateToTab!(FlavorConfig.isVantage() ? 2 : 2);
                      }
                    },
                    borderRadius: BorderRadius.circular(5.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 10.h,
                        horizontal: 8.w,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackGround,
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: AppSvgIcon(
                        assetPath:
                            'assets/svg/bottom_navigation/candle_bold.svg',
                        height: 22.h,
                        width: 22.w,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),

                  // First Action (Always present)
                  Expanded(
                    flex: 1,
                    child: _buildActionButton(
                      color: AppColors.green,
                      isSvg: true,
                      icon: Icons.add,
                      svg: 'assets/svg/deshboard/money-recive.svg',
                      // label: account.actions[0],
                      label: languageService.tr('dashboard_deposit'),
                      onTap: () {
                        if (account.accountType.toLowerCase() == 'live') {
                          controller.onDepositRealAccount(
                            account.metaAccountNumber,
                          );
                        } else {
                          controller.onDeposit(account.metaAccountNumber);
                        }
                      },
                    ),
                  ),

                  SizedBox(width: 8.w),

                  // Second Action
                  Expanded(
                    flex: 1,
                    child: _buildActionButton(
                      color:
                          account.accountType.toLowerCase() == 'live'
                              ? AppColors.red
                              : AppColors.primary,
                      isSvg: true,
                      svg:
                          account.accountType.toLowerCase() == 'live'
                              ? "assets/svg/deshboard/money-send.svg"
                              : 'assets/svg/more/settings.svg',
                      icon:
                          account.accountType.toLowerCase() == 'live'
                              ? Icons.trending_down
                              : Icons.settings,
                      label:
                          account.accountType.toLowerCase() == 'live'
                              ? languageService.tr('dashboard_withdraw')
                              : languageService.tr('more_settings'),
                      onTap: () {
                        if (account.accountType.toLowerCase() == 'live') {
                          controller.onWithdraw(account.metaAccountNumber);
                        } else {
                          controller.onSettings(account.metaAccountNumber);
                        }
                      },
                    ),
                  ),

                  SizedBox(width: 6.w),

                  // Three dots button with onTap functionality
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 10.h,
                      horizontal: 5.w,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackGround,
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: GestureDetector(
                      onTap: () => _showAccountMenuBottomSheet(account),
                      child: AppSvgIcon(
                        assetPath: 'assets/svg/deshboard/Three_dot.svg',
                        height: 21.h,
                        width: 21.w,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  // More Options
                ],
              ),

          // Switch to Trade Button (only for some accounts)
          if (!account.isPrimaryAccount) ...[
            SizedBox(height: isVantage ? 10 : 14),
            Container(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  final accountController = Get.find<AccountController>();
                  accountController
                      .setActiveMT5Account(account.metaAccountNumber)
                      .then((_) {
                        if (FlavorConfig.usesIquoteUi() &&
                            Get.context != null &&
                            Navigator.of(Get.context!).canPop()) {
                          Navigator.of(Get.context!).pop();
                        }
                      })
                      .catchError((e) {
                        if (kDebugMode) {
                          print('Account switch failed: $e');
                        }
                      });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding:
                      isVantage
                          ? EdgeInsets.symmetric(
                            vertical: 8.h,
                            horizontal: 12.w,
                          )
                          : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppSvgIcon(
                      assetPath: 'assets/svg/deshboard/switch_icon.svg',
                      height: isVantage ? 16.h : 18.h,
                      width: isVantage ? 16.w : 18.w,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      languageService.tr('dashboard_switch_to_trade'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: isVantage ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    bool? isSvg,
    String? svg,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return Builder(
      builder: (context) {
        // Get screen width for responsive sizing
        final screenWidth = MediaQuery.of(context).size.width;
        // Calculate responsive font size based on screen width
        // Small devices (< 400px): 11sp, Medium (400-600px): 12sp, Large (> 600px): 13sp
        final double baseFontSize =
            screenWidth < 400
                ? 11.sp
                : screenWidth < 600
                ? 12.sp
                : 13.sp;
        final double fontSize =
            compact ? (baseFontSize - 2).clamp(9.5, 11.0) : baseFontSize;
        final double iconSize = compact ? 13.sp : 16.sp;
        final EdgeInsets padding =
            compact
                ? EdgeInsets.symmetric(vertical: 6.h, horizontal: 6.w)
                : EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w);

        final bool isDarkMode = AppColors.isDarkMode;
        final Color buttonBgColor =
            isDarkMode ? Colors.white.withOpacity(0.12) : color.withAlpha(20);
        final Color textAndIconColor = isDarkMode ? Colors.white : color;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 30.h : 40.h),
            padding: padding,
            decoration: BoxDecoration(
              color: buttonBgColor,
              borderRadius: BorderRadius.circular(compact ? 12.r : 5.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                (isSvg == true)
                    ? AppSvgIcon(
                      assetPath: svg!,
                      height: compact ? 13.h : 16.h,
                      width: compact ? 13.w : 16.w,
                      color: textAndIconColor,
                    )
                    : Icon(icon, color: textAndIconColor, size: iconSize),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: textAndIconColor,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Celestial helper: divider line between detail rows ─────────────────────
class _CelestialDivider extends StatelessWidget {
  final BuildContext context;
  const _CelestialDivider({required this.context});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: CelTheme.divider(context).withOpacity(0.6),
    );
  }
}

// ─── Celestial helper: detail row (label : value, MT5-like) ────────────────
class _CelestialDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final BuildContext context;

  const _CelestialDetailRow({
    required this.label,
    required this.value,
    required this.context,
    this.valueColor,
  });

  @override
  Widget build(BuildContext _) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              color: CelTheme.subText(context),
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              color: valueColor ?? CelTheme.mainText(context),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AccountInfoBottomSheet extends StatelessWidget {
  final MT5Account account;

  const AccountInfoBottomSheet({Key? key, required this.account})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dashboardController = Get.find<DashboardController>();

    return Obx(() {
      final accountInfo = dashboardController.getAccountInfo(
        account.metaAccountNumber,
      );

      return _buildContent(context, accountInfo);
    });
  }

  Widget _buildContent(BuildContext context, AccountInfo? accountInfo) {
    final languageService = Get.find<LanguageService>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Account Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Account Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          account.metaAccountNumber,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 16.sp,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.isDarkMode
                                    ? Colors.white.withOpacity(0.12)
                                    : (account.accountType == 'live'
                                        ? AppColors.accent
                                        : AppColors.blue),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            account.accountType.capitalizeFirst ?? '',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color:
                                  AppColors.isDarkMode
                                      ? Colors.white
                                      : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            child: Container(
                              height: 15.h,
                              // width: 29.w,
                              padding: EdgeInsets.only(left: 4.w, right: 4.w),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.isDarkMode
                                        ? AppColors.primary.withOpacity(0.12)
                                        : AppColors.accent.withAlpha(50),
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  text: account.tradingServer.capitalizeFirst,
                                  style: AppTextStyles.grey10400,
                                ),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: "  ${account.masterGroupId}",
                            style: AppTextStyles.grey10400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Equity Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      languageService.tr('dashboard_equity'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.icongrey,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          accountInfo != null
                              ? '\$${accountInfo.equity.toStringAsFixed(2)} USD'
                              : '\$${account.equity} USD',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Account Details
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildDetailRow(
                  languageService.tr('dashboard_balance'),
                  accountInfo != null
                      ? PrecisionHelper.formatMoney(accountInfo.balance)
                      : '\$${account.balance} USD',
                ),
                if (accountInfo != null && accountInfo.credit > 0)
                  _buildDetailRow(
                    languageService.tr('Credit'),
                    PrecisionHelper.formatMoney(accountInfo.credit),
                  ),
                _buildDetailRow(
                  languageService.tr('dashboard_equity'),
                  accountInfo != null
                      ? PrecisionHelper.formatMoney(accountInfo.equity)
                      : '\$${account.equity} USD',
                ),
                _buildDetailRow(
                  languageService.tr('dashboard_total_pl'),
                  accountInfo != null
                      ? '\$${accountInfo.profit.toStringAsFixed(2)} USD'
                      : '\$0.00 USD',
                ),
                _buildDetailRow(
                  languageService.tr('trade_metric_margin'),
                  accountInfo != null
                      ? '\$${accountInfo.margin.toStringAsFixed(2)} USD'
                      : '\$${account.margin} USD',
                ),
                _buildDetailRow(
                  languageService.tr('trade_metric_free_margin'),
                  accountInfo != null
                      ? '\$${accountInfo.marginFree.toStringAsFixed(2)} USD'
                      : '\$${account.freeMargin} USD',
                ),
                _buildDetailRow(
                  languageService.tr('trade_metric_margin_level'),
                  accountInfo != null && accountInfo.marginLevel > 0
                      ? '${accountInfo.marginLevel.toStringAsFixed(2)}%'
                      : account.marginLevel.isNotEmpty &&
                          account.marginLevel != '0'
                      ? '${account.marginLevel}%'
                      : '-',
                ),
                _buildDetailRow(
                  languageService.tr('dashboard_max_leverage'),
                  '1:500',
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Original Action Buttons (Deposit, Withdraw, Transfer)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: MediaQuery.of(context).padding.bottom > 0 ? 0 : 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    isSvg: true,
                    color: AppColors.green,
                    svg: 'assets/svg/deshboard/money-recive.svg',
                    icon: Icons.arrow_upward,
                    label: languageService.tr('dashboard_deposit'),
                    onTap: () {
                      Get.back(closeOverlays: true);
                      if (account.accountType.toLowerCase() == 'live') {
                        Get.find<DashboardController>().onDepositRealAccount(
                          account.metaAccountNumber,
                        );
                      } else {
                        Get.find<DashboardController>().onDeposit(
                          account.metaAccountNumber,
                        );
                      }
                    },
                  ),
                ),
                SizedBox(width: 12),
                account.accountType.toLowerCase() == 'live'
                    ? Expanded(
                      child: _buildActionButton(
                        isSvg: true,
                        color: AppColors.red,
                        svg: 'assets/svg/deshboard/money-send.svg',
                        icon: Icons.arrow_downward,
                        label: languageService.tr('dashboard_withdraw'),
                        onTap: () {
                          Get.back(closeOverlays: true);
                          Get.find<DashboardController>().onWithdraw(
                            account.metaAccountNumber,
                          );
                        },
                      ),
                    )
                    : SizedBox.shrink(),
                SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    color: AppColors.primary,
                    icon: Icons.swap_horiz,
                    label: languageService.tr('dashboard_transfer'),
                    onTap: () {
                      Get.back(closeOverlays: true);
                      Get.to(() => InternalTransferScreen());
                    },
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 32),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
              height: 1.375,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              color: AppColors.icongrey,
              fontWeight: FontWeight.w400,
              height: 1.57,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    bool? isSvg,
    String? svg,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 50,
      alignment: Alignment.center,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(20),
          foregroundColor: AppColors.whiteColor,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            (isSvg == true)
                ? AppSvgIcon(
                  assetPath: svg!,
                  height: 18,
                  width: 18,
                  color: color,
                )
                : Icon(icon, size: 18, color: color),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: color,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountMenuBottomSheet extends StatelessWidget {
  final MT5Account account;

  const AccountMenuBottomSheet({Key? key, required this.account})
    : super(key: key);

  // Regex covering MT5 password complexity: 8-16 chars, must include
  // uppercase, lowercase, digit, and a special character.
  static final _passwordComplexityRe = RegExp(
    r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$%\^&\*\(\)_\+\-=\[\]\{\};:,.<>/?\\|`~]).{8,16}$',
  );

  bool _isPasswordComplex(String pwd) => _passwordComplexityRe.hasMatch(pwd);

  bool _isChangeFormValid(String newPwd, String confirmPwd) {
    if (newPwd.isEmpty || confirmPwd.isEmpty) return false;
    if (newPwd != confirmPwd) return false;
    return _isPasswordComplex(newPwd);
  }

  void _showMT5ChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final authService = Get.find<AuthService>();
    final languageService = Get.find<LanguageService>();
    final isLoading = false.obs;
    final obscurePassword = true.obs;
    final obscureConfirmPassword = true.obs;
    final isValid = false.obs;

    // Recompute `isValid` whenever either field changes. Enables the
    // Change Password button only when both fields are filled, equal,
    // and the new password satisfies the complexity rule.
    void onPwdChanged() {
      isValid.value = _isChangeFormValid(
        passwordController.text,
        confirmPasswordController.text,
      );
    }

    passwordController.addListener(onPwdChanged);
    confirmPasswordController.addListener(onPwdChanged);

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: AppColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageService.tr('change_master_password'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Account: ${account.metaAccountNumber}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Obx(
                      () => RTLHelper.rtlTextField(
                        controller: passwordController,
                        obscureText: obscurePassword.value,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.textGrey,
                        ),
                        hintText: languageService.tr(
                          'create_account_create_mt5_password',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 8 || value.length > 16) {
                            return 'Password must be 8-16 characters';
                          }
                          if (!_isPasswordComplex(value)) {
                            return 'Must include uppercase, lowercase, number, and special character';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelStyle: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            color: AppColors.textGrey,
                          ),
                          floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textGrey,
                          ),
                          labelText: 'New Password',
                          hintText: 'Enter new password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              obscurePassword.value = !obscurePassword.value;
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Obx(
                      () => RTLHelper.rtlTextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword.value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Confirm new password',
                          floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textGrey,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              obscureConfirmPassword.value =
                                  !obscureConfirmPassword.value;
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        height: 46.h,
                        child: ElevatedButton(
                          onPressed:
                              (isLoading.value || !isValid.value)
                                  ? null
                                  : () async {
                                    if (formKey.currentState!.validate()) {
                                      isLoading.value = true;
                                      try {
                                        final response = await authService
                                            .changePassword(
                                              mt5Account:
                                                  account.metaAccountNumber,
                                              newPassword:
                                                  passwordController.text
                                                      .trim(),
                                            );

                                        if (response.success) {
                                          CustomToastService.showSuccess(
                                            message:
                                                response.data?['message'] ??
                                                'Password changed successfully',
                                          );
                                          Get.back(closeOverlays: true);
                                        } else {
                                          CustomToastService.showError(
                                            message:
                                                response.message ??
                                                'Failed to change password',
                                          );
                                        }
                                      } catch (e) {
                                        CustomToastService.showError(
                                          message: 'Error: $e',
                                        );
                                      } finally {
                                        isLoading.value = false;
                                        Get.back();
                                      }
                                    }
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.border,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              isLoading.value
                                  ? SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.whiteColor,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    'Change Password',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.whiteColor,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      height: 46.h,
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageService.tr('navigation_cancel'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Reset Investor Password — same shape as Change Master but uses
  //  `authService.resetInvestorPassword` (endpoint
  //  /api/user/mt5accounts/resetinvestorpassword).
  // ---------------------------------------------------------------------------
  void _showMT5ResetInvestorPasswordDialog() {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final authService = Get.find<AuthService>();
    final languageService = Get.find<LanguageService>();
    final isLoading = false.obs;
    final obscurePassword = true.obs;
    final obscureConfirmPassword = true.obs;
    final isValid = false.obs;

    void onPwdChanged() {
      isValid.value = _isChangeFormValid(
        passwordController.text,
        confirmPasswordController.text,
      );
    }

    passwordController.addListener(onPwdChanged);
    confirmPasswordController.addListener(onPwdChanged);

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: AppColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'Reset Investor Password',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pureBlack,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Obx(
                      () => RTLHelper.rtlTextField(
                        obscureText: obscurePassword.value,
                        decoration: InputDecoration(
                          labelText: 'New Investor Password',
                          hintText: 'Enter new investor password (8-16 chars)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textGrey,
                            ),
                            onPressed:
                                () =>
                                    obscurePassword.value =
                                        !obscurePassword.value,
                          ),
                        ),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                        controller: passwordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 8 || value.length > 16) {
                            return 'Password must be 8-16 characters';
                          }
                          if (!_isPasswordComplex(value)) {
                            return 'Must include uppercase, lowercase, number, and special character';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '8-16 characters with uppercase, lowercase, numbers, and special characters',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          color: AppColors.textGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Obx(
                      () => RTLHelper.rtlTextField(
                        obscureText: obscureConfirmPassword.value,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Confirm new investor password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textGrey,
                            ),
                            onPressed:
                                () =>
                                    obscureConfirmPassword.value =
                                        !obscureConfirmPassword.value,
                          ),
                        ),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                        controller: confirmPasswordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm password';
                          }
                          if (value != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (confirmPasswordController.text.isNotEmpty &&
                        passwordController.text !=
                            confirmPasswordController.text)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text(
                          languageService.tr('password_mismatch_error'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        height: 46.h,
                        child: ElevatedButton(
                          onPressed:
                              (isLoading.value || !isValid.value)
                                  ? null
                                  : () async {
                                    if (formKey.currentState!.validate()) {
                                      isLoading.value = true;
                                      try {
                                        final response = await authService
                                            .resetInvestorPassword(
                                              mt5Account:
                                                  account.metaAccountNumber,
                                              newPassword:
                                                  passwordController.text
                                                      .trim(),
                                            );
                                        if (response.success) {
                                          CustomToastService.showSuccess(
                                            message:
                                                response.data?['message'] ??
                                                'Investor password reset successfully',
                                          );
                                          Get.back(closeOverlays: true);
                                        } else {
                                          CustomToastService.showError(
                                            message:
                                                response.message ??
                                                'Failed to reset investor password',
                                          );
                                        }
                                      } catch (e) {
                                        CustomToastService.showError(
                                          message: 'Error: $e',
                                        );
                                      } finally {
                                        isLoading.value = false;
                                      }
                                    }
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary
                                .withOpacity(0.4),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              isLoading.value
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.0,
                                    ),
                                  )
                                  : Text(
                                    'Reset Password',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  // ---------------------------------------------------------------------------
  //  Bottom-sheet menu giving the user a choice between changing the
  //  master password or resetting the investor password. Mirrors the
  //  existing Transfer / Bonus / History / Leverage sheet pattern.
  // ---------------------------------------------------------------------------
  void _showMT5PasswordOptionsSheet() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.lock_outline, color: AppColors.primary),
                title: Text('Change Master Password'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Get.back();
                  _showMT5ChangePasswordDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                title: Text('Reset Investor Password'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Get.back();
                  _showMT5ResetInvestorPasswordDialog();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Menu Items
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.swap_horiz,
                  label: languageService.tr('dashboard_transfer'),
                  onTap: () {
                    Get.back(closeOverlays: true);
                    Get.to(() => InternalTransferScreen());
                  },
                ),
                SizedBox(height: 16),
                _buildMenuItem(
                  icon: Icons.card_giftcard,
                  label: languageService.tr('dashboard_bonus'),
                  onTap: () {
                    Get.back(closeOverlays: true);
                    Get.toNamed(AppPages.BONUS);
                  },
                ),
                SizedBox(height: 16),
                _buildMenuItem(
                  icon: Icons.history,
                  label: languageService.tr('dashboard_history'),
                  onTap: () {
                    Get.back(closeOverlays: true);
                    Get.to(
                      () => FinanceUiScope.widgets.transactionHistory(),
                      arguments: {'from': 'dashboard'},
                    );
                  },
                ),
                SizedBox(height: 16),
                _buildMenuItem(
                  icon: Icons.lock,
                  label: languageService.tr('change_password'),
                  onTap: () {
                    Get.back();
                    // Get.back(closeOverlays: true);
                    _showMT5PasswordOptionsSheet();
                  },
                ),
                if (account.leverageChangeAllowed) ...[
                  SizedBox(height: 16),
                  _buildMenuItem(
                    icon: Icons.trending_up,
                    label: 'Leverage',
                    onTap: () {
                      print('Leverage: ${account.leverageId}');
                      Get.back(closeOverlays: true);
                      Get.to(
                        () => ChangeLeverageScreen(
                          accountNumber: account.metaAccountNumber,
                          currentLeverage: account.leverageId,
                          leverageOptions: account.leverageOptions,
                        ),
                      );
                    },
                  ),
                ],
                // SizedBox(height: 16),
                // _buildMenuItem(
                //   icon: Icons.settings,
                //   label: languageService.tr('more_settings'),
                //   onTap: () {
                //     Get.back(closeOverlays: true);
                //     Get.to(() => MoreScreen());
                //   },
                // ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Cancel Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              margin: EdgeInsets.only(bottom: 10.h),

              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back(closeOverlays: true),
                child: Text(
                  languageService.tr('navigation_cancel'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.red,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            SizedBox(width: 16),
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.icongrey),
          ],
        ),
      ),
    );
  }
}

class OpenAccountBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.find<DashboardController>();
    final languageService = Get.find<LanguageService>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              SizedBox(height: 16.h),

              // Title row: title centered, close icon on the right.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48.w),
                    child: Text(
                      languageService.tr('dashboard_open_account'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.topLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.r),
                      onTap: () => Get.back(),
                      child: Container(
                        width: 36.w,
                        height: 36.h,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          size: 22.r,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Live Account — ElevatedButton (primary fill).
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: controller.openRealAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.whiteColor,
                      minimumSize: Size(double.infinity, 48.h),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 2,
                      alignment: Alignment.center,
                    ),
                    child: Text(
                      languageService.tr('dashboard_live'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // Demo Account — ElevatedButton (outlined).
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: controller.openDemoAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.whiteColor,
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: Size(double.infinity, 48.h),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(color: AppColors.border),
                      ),
                      elevation: 1,
                      alignment: Alignment.center,
                    ),
                    child: Text(
                      languageService.tr('dashboard_demo'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
