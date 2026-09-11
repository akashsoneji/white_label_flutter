import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/services/enabled_modules_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/theme_bottom_sheet.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/home/more/promotional/promotional_screen.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/app_lock_service.dart';
import 'package:crm_app/services/one_click_trading_service.dart';
import 'package:crm_app/screens/home/more/one_click_trading_disclaimer_screen.dart';
import 'package:crm_app/screens/home/iquote_home_screen.dart';
import 'package:crm_app/widgets/dashboard_bottom_sheet.dart';

/// Modernized Assets & Hub Layout (Fintech Elite Style).
///
/// Features:
///   • High-status Trader Profile Header with verified status badge and profile action
///   • Vibrant Action Hub (Deposit, Withdrawal, Demo, Real) with modern gradients and micro-icons
///   • KYC Account Verification Card with live percentage gauge
///   • Curated Financial Services with themed soft-background icon badges
///   • Account & Security Hub with tactile switches and seamless navigation
class IquoteAssetsLayout extends StatefulWidget {
  const IquoteAssetsLayout({super.key});

  @override
  State<IquoteAssetsLayout> createState() => _IquoteAssetsLayoutState();
}

class _IquoteAssetsLayoutState extends State<IquoteAssetsLayout> {
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    OneClickTradingService.instance.isOneClickTradingEnabled();
  }

  Future<void> _loadBiometricState() async {
    final enabled = await SecureStorageService.getBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _isBiometricEnabled = enabled;
    });
  }

  Future<void> _toggleOneClickTrading() async {
    final currentlyOn =
        OneClickTradingService.instance.enabledNotifier.value;
    if (currentlyOn) {
      await OneClickTradingService.instance.setOneClickTradingEnabled(false);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OneClickTradingDisclaimerScreen(),
        ),
      );
    }
  }

  Future<void> _toggleBiometric() async {
    try {
      if (_isBiometricEnabled) {
        await SecureStorageService.setBiometricEnabled(false);
        try {
          if (Get.isRegistered<AppLockService>()) {
            await Get.find<AppLockService>().clearLock();
          }
        } catch (_) {}
        if (!mounted) return;
        setState(() => _isBiometricEnabled = false);
      } else {
        final available = await BiometricService.instance.isEnrolled();
        if (!available) {
          _showBiometricNotEnrolledDialog();
          return;
        }
        final authenticated = await BiometricService.instance.authenticate(
          reason: 'Authenticate to enable biometric login',
        );
        if (authenticated) {
          await SecureStorageService.setBiometricEnabled(true);
          if (!mounted) return;
          setState(() => _isBiometricEnabled = true);
        }
      }
    } catch (e) {
      CustomToastService.showError(message: e.toString());
    }
  }

  void _showBiometricNotEnrolledDialog() {
    final languageService =
        Get.isRegistered<LanguageService>()
            ? Get.find<LanguageService>()
            : null;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
        ),
        backgroundColor: AppColors.cardBackground,
        child: Container(
          padding: EdgeInsets.all(22.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            color: AppColors.cardBackground,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 30.sp,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                languageService?.tr('biometric_not_enrolled_title') ??
                    'Biometric Security',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                languageService?.tr('biometric_not_enrolled_message') ??
                    'Biometric authentication is not set up on this device.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 22.h),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () => Get.back(closeOverlays: true),
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('common_close') ?? 'Close',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () async {
                        Get.back(closeOverlays: true);
                        await BiometricService.instance
                            .openDeviceSecuritySettings();
                      },
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('biometric_open_settings') ??
                              'Open Settings',
                          style: AppTextStyles.bodyText.copyWith(
                            color: Colors.white,
                            fontSize: 14.sp,
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

  // Delegates to the single shared implementation on IquoteHomeScreen so the
  // IB-status check + error handling live in exactly one place.
  Future<void> _handleSwitchToIB() => IquoteHomeScreen.handleSwitchToIB();

  void _showLogoutDialog(BuildContext context, AuthController authController) {
    final languageService =
        Get.isRegistered<LanguageService>()
            ? Get.find<LanguageService>()
            : null;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
        ),
        backgroundColor: AppColors.cardBackground,
        child: Container(
          padding: EdgeInsets.all(22.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            color: AppColors.cardBackground,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.logout_rounded,
                    size: 26.sp,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Log Out',
                style: AppTextStyles.heading.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                languageService?.tr('logout_confirm_message') ??
                    'Are you sure you want to log out from this device?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 22.h),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () => Get.back(closeOverlays: true),
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('navigation_no') ?? 'Cancel',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () async {
                        Get.back(closeOverlays: true);
                        await authController.logout();
                      },
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('navigation_yes') ?? 'Logout',
                          style: AppTextStyles.bodyText.copyWith(
                            color: Colors.white,
                            fontSize: 14.sp,
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

  void _showDeleteAccountDialog(
    BuildContext context,
    AuthController authController,
  ) {
    final languageService =
        Get.isRegistered<LanguageService>()
            ? Get.find<LanguageService>()
            : null;
    final TextEditingController passwordController = TextEditingController();
    final RxBool isPasswordEmpty = false.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
        ),
        backgroundColor: AppColors.cardBackground,
        child: Container(
          padding: EdgeInsets.all(22.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            color: AppColors.cardBackground,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageService?.tr('delete_account_confirm_message') ??
                    'Are you sure you want to delete your account?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 14.h),
              Obx(
                () => TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        languageService?.tr('delete_account_password_hint') ??
                        'Enter your password',
                    hintStyle: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color:
                            isPasswordEmpty.value
                                ? AppColors.error
                                : AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () => Get.back(closeOverlays: true),
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('navigation_no') ?? 'Cancel',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Obx(
                      () => InkWell(
                        borderRadius: BorderRadius.circular(12.r),
                        onTap:
                            authController.isLoading
                                ? null
                                : () {
                                  if (passwordController.text.isEmpty) {
                                    isPasswordEmpty.value = true;
                                  } else {
                                    isPasswordEmpty.value = false;
                                    authController.deleteAccount({
                                      "password": passwordController.text,
                                      "reason": "No longer needed",
                                      "accept_terms": true,
                                      "confirm_deletion": true,
                                    });
                                  }
                                },
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            languageService?.tr('navigation_yes') ?? 'Delete',
                            style: AppTextStyles.bodyText.copyWith(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
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

  @override
  Widget build(BuildContext context) {
    final bgDark = AppColors.background;
    final cardBg = AppColors.card;
    final textPrimary = AppColors.textPrimary;
    final textSecondary = AppColors.textSecondary;
    final primaryColor = AppColors.primary;
    final languageService =
        Get.isRegistered<LanguageService>()
            ? Get.find<LanguageService>()
            : null;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Header Card
              _buildTopHeader(cardBg, textPrimary, textSecondary),
              SizedBox(height: 14.h),

              // 2. Action Hub (Deposit, Withdrawal, Demo, Real)
              _buildQuickActionHub(cardBg, textPrimary, textSecondary, primaryColor),
              SizedBox(height: 12.h),

              // 3. KYC Verification Card (Only when unverified)
              Obx(() {
                final model = Get.find<MoreController>().dashboardModel.value;
                final stage = model?.data?.stageCompletion;
                final isVerified =
                    (stage?.emailVerified != null) &&
                    (stage?.mobileVerified != null) &&
                    (stage?.personalDetails == true);
                if (isVerified) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: const _VerifyAccountCard(),
                );
              }),

              // 4. Financial Services Group
              _buildSectionHeader(
                title: languageService?.tr('general_financial') ?? 'Financial Services',
                textPrimary: textPrimary,
              ),
              SizedBox(height: 8.h),
              _buildDynamicServicesGroup(cardBg, textPrimary),
              SizedBox(height: 16.h),

              // 5. Account & Security Settings Group
              _buildSectionHeader(
                title: languageService?.tr('general_account_security') ?? 'Account & Security',
                textPrimary: textPrimary,
              ),
              SizedBox(height: 8.h),
              _buildSecuritySettingsGroup(cardBg, textPrimary),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required Color textPrimary}) {
    return Row(
      children: [
        Container(
          width: 3.5.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: AppTextStyles.bodyText.copyWith(
            color: textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ── 1. Top Profile Header ───────────────────────────────────────────────
  Widget _buildTopHeader(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    final AuthController? authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final MoreController? moreController =
        Get.isRegistered<MoreController>()
            ? Get.find<MoreController>()
            : Get.put(MoreController());

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: AppColors.isDarkMode ? 0.18 : 0.10),
            cardBg,
            cardBg,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                final name = authController?.userFullName ?? '';
                if (name.isEmpty) {
                  Get.toNamed(AppPages.LOGIN);
                } else {
                  Get.toNamed(AppPages.VIEW_PROFILE);
                }
              },
              borderRadius: BorderRadius.circular(14.r),
              child: Row(
                children: [
                  // Profile Avatar with Status Ring
                  Stack(
                    children: [
                      Container(
                        width: 48.w,
                        height: 48.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6366F1),
                              AppColors.primary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getUserInitials(authController?.userFullName ?? ''),
                          style: AppTextStyles.bodyText.copyWith(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12.r,
                          height: 12.r,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: cardBg, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final name = authController?.userFullName ?? '';
                            final displayName =
                                name.trim().isNotEmpty
                                    ? name.trim()
                                    : 'Sign in / Sign up';
                            return Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 2.h),
                        Builder(
                          builder: (context) {
                            final email = authController?.userEmail ?? '';
                            final subText =
                                email.isNotEmpty
                                    ? email
                                    : 'Manage your portfolio & accounts';
                            return Text(
                              subText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.5.sp,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),

          // Profile View/Edit Action Icon
          if (moreController != null)
            Obx(() {
              final model = moreController.dashboardModel.value;
              final stage = model?.data?.stageCompletion;
              final isProfileVerified =
                  (stage?.emailVerified != null) &&
                  (stage?.mobileVerified != null) &&
                  (stage?.personalDetails == true);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (isProfileVerified) {
                      Get.toNamed(AppPages.VIEW_PROFILE);
                    } else {
                      Get.toNamed(
                        AppPages.EDIT_PROFILE,
                        arguments: isProfileVerified,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.all(9.w),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      isProfileVerified
                          ? Icons.visibility_outlined
                          : Icons.edit_note_rounded,
                      size: 20.sp,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── 2. Modern Quick Action Hub (Deposit, Withdrawal, Demo, Real) ─────────
  Widget _buildQuickActionHub(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
  ) {
    final AuthController? authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final languageService = Get.isRegistered<LanguageService>()
        ? Get.find<LanguageService>()
        : null;

    return Obx(() {
      final isLoggedIn =
          (authController?.userFullName?.isNotEmpty == true) ||
          (authController?.userEmail?.isNotEmpty == true);

      if (!isLoggedIn) {
        return Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Get.toNamed(AppPages.LOGIN),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  height: 46.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Sign In',
                    style: AppTextStyles.bodyText.copyWith(
                      color: textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: InkWell(
                onTap: () => Get.toNamed(AppPages.CREATE_ACCOUNT),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  height: 46.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(
                    'Get Started',
                    style: AppTextStyles.bodyText.copyWith(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return Column(
        children: [
          // Row 1: Primary Money Actions (Deposit & Withdrawal)
          Row(
            children: [
              Expanded(
                child: _primaryActionCard(
                  title: languageService?.tr('iquote_assets_deposit') ?? 'Deposit',
                  subtitle: languageService?.tr('iquote_assets_deposit_subtitle') ?? 'Instant Add Funds',
                  icon: Icons.add_circle_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  onTap: () => Get.to(() => PaymentMethodsScreen(accountNumber: '')),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _primaryActionCard(
                  title: languageService?.tr('iquote_assets_withdrawal') ?? 'Withdrawal',
                  subtitle: languageService?.tr('iquote_assets_withdrawal_subtitle') ?? 'Fast Payouts',
                  icon: Icons.arrow_circle_up_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                  ),
                  onTap: () => Get.toNamed(AppPages.WITHDRAWAL),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Row 2: Secondary Account Setup Actions (Demo & Real)
          Row(
            children: [
              Expanded(
                child: _secondaryActionCard(
                  title: languageService?.tr('iquote_assets_demo_trading') ?? 'Demo Trading',
                  subtitle: languageService?.tr('iquote_assets_demo_trading_subtitle') ?? 'Practice with \$10k',
                  icon: Icons.play_arrow_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  cardBg: cardBg,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => Get.toNamed(
                    AppPages.CHOOSE_ACCOUNT,
                    arguments: {'isDemo': true},
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _secondaryActionCard(
                  title: languageService?.tr('iquote_assets_live_account') ?? 'Live Account',
                  subtitle: languageService?.tr('iquote_assets_live_account_subtitle') ?? 'Trade Real Markets',
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF10B981),
                  cardBg: cardBg,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => Get.toNamed(
                    AppPages.CHOOSE_ACCOUNT,
                    arguments: {'isDemo': false},
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _primaryActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(7.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyText.copyWith(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodyText.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  Widget _secondaryActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(7.w),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, color: iconColor, size: 18.sp),
                ),
                SizedBox(width: 9.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: textPrimary,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: textSecondary,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  // ── 3. Dynamic Financial Services Group ───────────────────────────────────
  Widget _buildDynamicServicesGroup(
    Color cardBg,
    Color textPrimary,
  ) {
    return Obx(() {
      final modulesService =
          Get.isRegistered<EnabledModulesService>()
              ? Get.find<EnabledModulesService>()
              : null;
      final modules = modulesService?.modules.value;
      final showCopyTrading = modules?.copytrading ?? false;
      final showPromotional = modulesService?.isPromotionalMenuVisible ?? false;
      final languageService =
          Get.isRegistered<LanguageService>()
              ? Get.find<LanguageService>()
              : null;

      final items = <Widget>[];

      // Dashboard
      items.add(
        _buildModernOptionTile(
          icon: Icons.dashboard_rounded,
          iconColor: const Color(0xFF3B82F6),
          title: languageService?.tr('dashboard_title') ?? 'Trading Dashboard',
          subtitle: languageService?.tr('iquote_assets_dashboard_subtitle') ?? 'Overview of balances & metrics',
          textPrimary: textPrimary,
          onTap: () => showDashboardBottomSheet(context),
        ),
      );

      // General Finance
      items.add(
        _buildModernOptionTile(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFF10B981),
          title: languageService?.tr('general_finance') ?? 'Finance & Wallet',
          subtitle: languageService?.tr('iquote_assets_finance_subtitle') ?? 'Transfer, history & methods',
          textPrimary: textPrimary,
          onTap: () => Get.toNamed(AppPages.FINANCE),
        ),
      );

      // IB Dashboard
      items.add(
        _buildModernOptionTile(
          icon: Icons.handshake_rounded,
          iconColor: const Color(0xFFF97316),
          title: languageService?.tr('more_dashboard') ?? 'IB Partner Portal',
          subtitle: languageService?.tr('iquote_assets_ib_subtitle') ?? 'Commissions & client tree',
          badgeText: 'Earn',
          badgeColor: const Color(0xFFF97316),
          textPrimary: textPrimary,
          onTap: () async => await _handleSwitchToIB(),
        ),
      );

      if (showPromotional) {
        items.add(
          _buildModernOptionTile(
            icon: Icons.card_giftcard_rounded,
            iconColor: const Color(0xFFEC4899),
            title: languageService?.tr('general_promotional') ?? 'Promotions & Rewards',
            subtitle: languageService?.tr('iquote_assets_promotions_subtitle') ?? 'Bonuses, scratch cards & offers',
            badgeText: 'Bonus',
            badgeColor: const Color(0xFFEC4899),
            textPrimary: textPrimary,
            onTap: () => Get.to(
              () => const PromotionalScreen(),
              transition: Transition.rightToLeft,
            ),
          ),
        );
      }

      if (showCopyTrading) {
        items.add(
          _buildModernOptionTile(
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFF6366F1),
            title: languageService?.tr('more_copy_trading') ?? 'Copy Trading',
            subtitle: languageService?.tr('iquote_assets_copy_trading_subtitle') ?? 'Follow top verified master traders',
            badgeText: 'Pro',
            badgeColor: const Color(0xFF6366F1),
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.COPY_TRADING_MAIN),
          ),
        );
      }

      // Notifications
      items.add(
        _buildModernOptionTile(
          icon: Icons.notifications_active_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: languageService?.trf('general_notifications', 'Notifications') ?? 'Notifications',
          subtitle: languageService?.tr('iquote_assets_notifications_subtitle') ?? 'Price alerts & account updates',
          textPrimary: textPrimary,
          onTap: () => Get.toNamed(AppPages.NOTIFICATIONS),
        ),
      );

      // Demo Contest
      items.add(
        _buildModernOptionTile(
          icon: Icons.emoji_events_rounded,
          iconColor: const Color(0xFFEAB308),
          title: languageService?.tr('more_demo_contest') ?? 'Trading Contests',
          subtitle: languageService?.tr('iquote_assets_contests_subtitle') ?? 'Compete risk-free for real cash prizes',
          badgeText: 'Win',
          badgeColor: const Color(0xFFEAB308),
          textPrimary: textPrimary,
          onTap: () => Get.toNamed(AppPages.DEMO_CONTEST),
        ),
      );

      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              items[i],
              if (i < items.length - 1) _buildDivider(),
            ],
          ],
        ),
      );
    });
  }

  // ── 4. Account & Security Settings Group ───────────────────────────────────
  Widget _buildSecuritySettingsGroup(
    Color cardBg,
    Color textPrimary,
  ) {
    final AuthController? authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final languageService =
        Get.isRegistered<LanguageService>()
            ? Get.find<LanguageService>()
            : null;

    final isLoggedIn =
        (authController?.userFullName?.isNotEmpty == true) ||
        (authController?.userEmail?.isNotEmpty == true);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Support / Customer Service
          _buildModernOptionTile(
            icon: Icons.support_agent_rounded,
            iconColor: const Color(0xFF10B981),
            title: languageService?.tr('ticket_title') ??
                languageService?.tr('support') ??
                '24/7 Support & Helpdesk',
            subtitle: languageService?.tr('iquote_assets_support_subtitle') ?? 'Submit tickets & live assistance',
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.TICKET_LIST),
          ),
          _buildDivider(),

          // 2. Theme Switcher
          _buildModernOptionTile(
            icon: AppColors.isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: languageService?.tr('theme') ?? 'Theme Appearance',
            subtitle: AppColors.isDarkMode ? 'Dark Mode Active' : 'Light Mode Active',
            textPrimary: textPrimary,
            onTap: () => showThemeBottomSheet(context),
          ),
          _buildDivider(),

          // 3. One Click Trading with Switch
          ValueListenableBuilder<bool>(
            valueListenable:
                OneClickTradingService.instance.enabledNotifier,
            builder: (context, enabled, _) {
              return _buildModernOptionTile(
                icon: Icons.touch_app_rounded,
                iconColor: AppColors.primary,
                title: Get.find<LanguageService>().tr('more_screen_one_click_trading'),
                subtitle: languageService?.tr('iquote_assets_one_click_subtitle') ?? 'Instant order execution without confirmation',
                textPrimary: textPrimary,
                trailing: Switch.adaptive(
                  value: enabled,
                  activeColor: AppColors.primary,
                  onChanged: (_) => _toggleOneClickTrading(),
                ),
                onTap: _toggleOneClickTrading,
              );
            },
          ),
          _buildDivider(),

          // 4. Biometric Login with Switch
          _buildModernOptionTile(
            icon: Icons.fingerprint_rounded,
            iconColor: const Color(0xFF06B6D4),
            title: languageService?.tr('biometric_login') ?? 'Biometric & Face ID',
            subtitle: languageService?.tr('iquote_assets_biometric_subtitle') ?? 'Secure fingerprint or face unlock',
            textPrimary: textPrimary,
            trailing: Switch.adaptive(
              value: _isBiometricEnabled,
              activeColor: AppColors.primary,
              onChanged: (val) => _toggleBiometric(),
            ),
            onTap: _toggleBiometric,
          ),
          _buildDivider(),

          // 5. Change Password
          _buildModernOptionTile(
            icon: Icons.lock_reset_rounded,
            iconColor: const Color(0xFFF97316),
            title: languageService?.tr('change_password') ?? 'Change Password',
            subtitle: languageService?.tr('iquote_assets_change_password_subtitle') ?? 'Update your security credentials',
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.CHANGE_PASSWORD),
          ),
          _buildDivider(),

          // 6. Two Factor Authentication
          _buildModernOptionTile(
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: languageService?.tr('two_factor_authentication') ?? 'Two-Factor Auth (2FA)',
            subtitle: languageService?.tr('iquote_assets_two_factor_subtitle') ?? 'Additional security layer for withdrawals',
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.TWO_FACTOR_AUTH),
          ),
          _buildDivider(),

          // 7. Language
          _buildModernOptionTile(
            icon: Icons.language_rounded,
            iconColor: AppColors.primary,
            title: languageService?.tr('settings_language_title') ?? 'Language',
            subtitle:
                languageService?.getCurrentLanguageName() ??
                LanguageService.supportedLanguages[LanguageService
                    .defaultLanguage]!,
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.LANGUAGE_SELECTOR),
          ),

          if (isLoggedIn && authController != null) ...[
            _buildDivider(),

            // 7. Delete Account
            _buildModernOptionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: const Color(0xFFEF4444),
              title: languageService?.tr('delete_account') ?? 'Delete Account',
              subtitle: languageService?.tr('iquote_assets_delete_account_subtitle') ?? 'Permanently close account and data',
              textPrimary: const Color(0xFFEF4444),
              onTap: () => _showDeleteAccountDialog(context, authController),
            ),
            _buildDivider(),

            // 8. Logout
            _buildModernOptionTile(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFEF4444),
              title: languageService?.tr('more_logout') ?? 'Log Out',
              subtitle: languageService?.tr('iquote_assets_logout_subtitle') ?? 'Sign out from this session',
              textPrimary: const Color(0xFFEF4444),
              onTap: () => _showLogoutDialog(context, authController),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? badgeText,
    Color? badgeColor,
    Widget? trailing,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              // Icon Badge Container
              Container(
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 20.sp),
                ),
              ),
              SizedBox(width: 12.w),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              color: textPrimary,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                color: badgeColor ?? AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textGrey,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing action or Chevron
              if (trailing != null)
                trailing
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textGrey.withValues(alpha: 0.6),
                  size: 13.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.only(left: 64.w, right: 14.w),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.border.withValues(alpha: 0.4),
      ),
    );
  }

  String _getUserInitials(String fullName) {
    if (fullName.trim().isEmpty) return '?';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _VerifyAccountCard extends StatelessWidget {
  const _VerifyAccountCard();

  static final _languageService =
      Get.isRegistered<LanguageService>() ? Get.find<LanguageService>() : null;
  static final _moreController =
      Get.isRegistered<MoreController>() ? Get.find<MoreController>() : null;

  int _calculateCompletion(StageCompletion? stage) {
    if (stage == null) return 0;
    int completion = 0;
    if (stage.mobileVerified != null) completion += 20;
    if (stage.emailVerified != null) completion += 20;
    if (stage.personalDetails == true) completion += 20;
    if (stage.identityVerified == true) completion += 20;
    if (stage.addressProofVerified == true) completion += 20;
    return completion;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = _languageService;
    final moreController = _moreController;
    if (moreController == null) return const SizedBox.shrink();

    return GetBuilder<MoreController>(
      builder: (controller) {
        final model = controller.dashboardModel.value;
        final stage = model?.data?.stageCompletion;
        final completion = _calculateCompletion(stage);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.primary.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final model = controller.dashboardModel.value;
                final stage = model?.data?.stageCompletion;
                await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
                controller.loadMoreScreenData();
              },
              borderRadius: BorderRadius.circular(16.r),
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.verified_user_rounded,
                            size: 16.sp,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Verify Your Profile',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '$completion% ${languageService?.tr('completed') ?? 'Done'}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Complete verification to unlock unlimited deposits and higher leverage.',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: completion / 100,
                        minHeight: 4.h,
                        backgroundColor: AppColors.border.withValues(alpha: 0.4),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
