import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
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
import 'package:crm_app/widgets/dashboard_bottom_sheet.dart';

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
    // Seed the shared notifier so the switch below reflects saved state.
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
      // Disclaimer screen persists via the service; notifier is already in sync.
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
          borderRadius: BorderRadius.circular(20.r),
        ),
        backgroundColor: AppColors.cardBackground,
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: AppColors.cardBackground,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8.h),
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 28.sp,
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
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                languageService?.tr('biometric_not_enrolled_message') ??
                    'Biometric authentication is not set up on this device.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () => Get.back(closeOverlays: true),
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('common_close') ?? 'Close',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontSize: 14.5.sp,
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
                            color: AppColors.pureWhite,
                            fontSize: 14.5.sp,
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
        ),
      ),
    );
  }

  Future<void> _handleSwitchToIB() async {
    try {
      final ibmController = Get.put(IbmController());
      await ibmController.checkSystemAndNavigate();
    } catch (e) {
      CustomToastService.showError(message: 'Error checking IB status: $e');
    }
  }

  void _showLogoutDialog(BuildContext context, AuthController authController) {
    final languageService =
        Get.isRegistered<LanguageService>()
            ? Get.find<LanguageService>()
            : null;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        backgroundColor: AppColors.cardBackground,
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: AppColors.cardBackground,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.h),
              Text(
                languageService?.tr('logout_confirm_message') ??
                    'Are you sure you want to log out?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
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
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('navigation_yes') ?? 'Yes',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.whiteColor,
                            fontSize: 15.sp,
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
                      onTap: () => Get.back(closeOverlays: true),
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('navigation_no') ?? 'No',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontSize: 15.sp,
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
          borderRadius: BorderRadius.circular(20.r),
        ),
        backgroundColor: AppColors.cardBackground,
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
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
                  fontWeight: FontWeight.w600,
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color:
                            isPasswordEmpty.value
                                ? AppColors.error
                                : AppColors.textGrey,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
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
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () => Get.back(closeOverlays: true),
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService?.tr('navigation_no') ?? 'Cancel',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontSize: 15.sp,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
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
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile & Edit/View Action Header Bar
              _buildTopHeader(cardBg, textPrimary, textSecondary, isDark),
              SizedBox(height: 16.h),

              // 2. Main Account Card (Hero Card with Real Dynamic Data)
              _buildAccountHeroCard(
                cardBg,
                textPrimary,
                textSecondary,
                primaryColor,
                isDark,
              ),
              Obx(() {
                final model = Get.find<MoreController>().dashboardModel.value;
                final stage = model?.data?.stageCompletion;
                final isVerified =
                    (stage?.emailVerified != null) &&
                    (stage?.mobileVerified != null) &&
                    (stage?.personalDetails == true);
                if (isVerified) return const SizedBox.shrink();
                return const _VerifyAccountCard();
              }),
              SizedBox(height: 16.h),

              // 3. Create Demo & Create Real Account Action Cards Grid
              _buildQuickFeatureRow(cardBg, textPrimary, textSecondary, isDark),
              SizedBox(height: 16.h),

              // 4. Dynamic Enabled Modules & Services Section
              Text(
                languageService?.tr('general_financial') ??
                    'Services & Account',
                style: AppTextStyles.bodyText.copyWith(
                  color: textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 10.h),
              _buildDynamicServicesGroup(
                cardBg,
                textPrimary,
                textSecondary,
                isDark,
              ),
              SizedBox(height: 16.h),

              // 5. Security & Settings Section
              Text(
                languageService?.tr('general_account_security') ??
                    'Account & Security',
                style: AppTextStyles.bodyText.copyWith(
                  color: textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 10.h),
              _buildSecuritySettingsGroup(
                cardBg,
                textPrimary,
                textSecondary,
                isDark,
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Top Profile Header (With View/Edit Profile Icon Logic) ────────────────
  Widget _buildTopHeader(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final AuthController? authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final MoreController? moreController =
        Get.isRegistered<MoreController>()
            ? Get.find<MoreController>()
            : Get.put(MoreController());

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Info
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
              borderRadius: BorderRadius.circular(12.r),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF9538),
                              AppColors.primary,
                            ],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18.r,
                          backgroundColor:
                              isDark
                                  ? const Color(0xFF2C324B)
                                  : const Color(0xFFE5E7EB),
                          child: Icon(
                            Icons.person,
                            color: isDark ? Colors.white : AppColors.primary,
                            size: 22.r,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 9.w,
                          height: 9.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ED573),
                            shape: BoxShape.circle,
                            border: Border.all(color: cardBg, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 10.w),
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
                                    : 'Sign in/Sign up';
                            return Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
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
                                    : 'Manage your assets & profile';
                            return Text(
                              subText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.sp,
                                color: textSecondary,
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

          // Right Header Action: Edit / View Profile Button
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
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child:
                        isProfileVerified
                            ? Icon(
                              Icons.remove_red_eye_outlined,
                              size: 20.r,
                              color: AppColors.primary,
                            )
                            : Icon(
                              Icons.edit_outlined,
                              size: 20.r,
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

  // ── 2. Deposit & Withdrawal Buttons (Only Action Buttons as requested) ─────────────
  Widget _buildAccountHeroCard(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
    bool isDark,
  ) {
    final AuthController? authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

    return Obx(() {
      final isLoggedIn =
          (authController?.userFullName?.isNotEmpty == true) ||
          (authController?.userEmail?.isNotEmpty == true);

      if (isLoggedIn) {
        return Row(
          children: [
            Expanded(
              child: InkWell(
                onTap:
                    () => Get.to(() => PaymentMethodsScreen(accountNumber: '')),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2ED573), Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ED573).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 20.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Deposit',
                        style: AppTextStyles.bodyText.copyWith(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: InkWell(
                onTap: () => Get.toNamed(AppPages.WITHDRAWAL),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9538), Color(0xFFFF6B00)],
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9538).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        color: Colors.white,
                        size: 20.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Withdrawal',
                        style: AppTextStyles.bodyText.copyWith(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Get.toNamed(AppPages.LOGIN),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  child: Text(
                    'Sign in',
                    style: AppTextStyles.bodyText.copyWith(
                      color: textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: InkWell(
                onTap: () => Get.toNamed(AppPages.CREATE_ACCOUNT),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9538), Color(0xFFFF6B00)],
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9538).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Sign up',
                    style: AppTextStyles.bodyText.copyWith(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    });
  }

  // ── 3. Account Creation Cards (Create Demo & Create Real) ─────────────────
  Widget _buildQuickFeatureRow(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Row(
      children: [
        // Create Demo Account Button Card
        Expanded(
          child: InkWell(
            onTap:
                () => Get.toNamed(
                  AppPages.CHOOSE_ACCOUNT,
                  arguments: {'isDemo': true},
                ),
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.orangeAccent,
                    size: 22.r,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Create Demo Account',
                    style: AppTextStyles.bodyText.copyWith(
                      color: textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),

        // Create Real Account Button Card
        Expanded(
          child: InkWell(
            onTap:
                () => Get.toNamed(
                  AppPages.CHOOSE_ACCOUNT,
                  arguments: {'isDemo': false},
                ),
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF2ED573),
                    size: 22.r,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Create Real Account',
                    style: AppTextStyles.bodyText.copyWith(
                      color: textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Dynamic Financial Services Group ───────────────────────────────────
  Widget _buildDynamicServicesGroup(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
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
        _buildOptionItem(
          icon: Icons.space_dashboard_outlined,
          iconColor: Colors.blueAccent,
          title: languageService?.tr('dashboard_title') ?? 'Dashboard',
          isDark: isDark,
          textPrimary: textPrimary,
          onTap: () => showDashboardBottomSheet(context),
        ),
      );

      // General Finance
      items.add(
        _buildOptionItem(
          icon: Icons.monetization_on_outlined,
          iconColor: Colors.green,
          title: languageService?.tr('general_finance') ?? 'General Finance',
          isDark: isDark,
          textPrimary: textPrimary,
          onTap: () => Get.toNamed(AppPages.FINANCE),
        ),
      );

      // IB Dashboard (Flow with _handleSwitchToIB)
      items.add(
        _buildOptionItem(
          icon: Icons.handshake_outlined,
          iconColor: const Color(0xFFFF9538),
          title: languageService?.tr('more_dashboard') ?? 'IB Dashboard',
          isDark: isDark,
          textPrimary: textPrimary,
          onTap: () async => await _handleSwitchToIB(),
        ),
      );

      if (showPromotional) {
        items.add(
          _buildOptionItem(
            icon: Icons.card_giftcard,
            iconColor: Colors.pinkAccent,
            title: languageService?.tr('general_promotional') ?? 'Promotional',
            isDark: isDark,
            textPrimary: textPrimary,
            onTap:
                () => Get.to(
                  () => const PromotionalScreen(),
                  transition: Transition.rightToLeft,
                ),
          ),
        );
      }

      if (showCopyTrading) {
        items.add(
          _buildOptionItem(
            icon: Icons.auto_awesome,
            iconColor: Colors.cyan,
            title: languageService?.tr('more_copy_trading') ?? 'Copy Trading',
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.COPY_TRADING_MAIN),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              items[i],
              if (i < items.length - 1) _buildDivider(isDark),
            ],
          ],
        ),
      );
    });
  }

  // ── 5. Account & Security Settings Group (Includes all 7 user-requested options) ────────
  Widget _buildSecuritySettingsGroup(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
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
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          // 1. Support / Customer Service
          _buildOptionItem(
            icon: Icons.headset_mic_outlined,
            iconColor: Colors.greenAccent,
            title:
                languageService?.tr('ticket_title') ??
                languageService?.tr('support') ??
                'Customer Service / Support',
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.TICKET_LIST),
          ),
          _buildDivider(isDark),

          // 2. Theme Switcher
          _buildOptionItem(
            icon: isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
            iconColor: Colors.amber,
            title: languageService?.tr('theme') ?? 'Theme',
            subtitle: isDark ? 'Dark' : 'Light',
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: () => showThemeBottomSheet(context),
          ),
          _buildDivider(isDark),

          // 3. One Click Trading with Switch
          ValueListenableBuilder<bool>(
            valueListenable:
                OneClickTradingService.instance.enabledNotifier,
            builder: (context, enabled, _) {
              return _buildOptionItem(
                icon: Icons.touch_app_rounded,
                iconColor: AppColors.primary,
                title: 'One Click Trading',
                isDark: isDark,
                textPrimary: textPrimary,
                trailing: SizedBox(
                  height: 24.h,
                  child: Switch.adaptive(
                    value: enabled,
                    activeColor: AppColors.primary,
                    onChanged: (_) => _toggleOneClickTrading(),
                  ),
                ),
                onTap: _toggleOneClickTrading,
              );
            },
          ),
          _buildDivider(isDark),

          // 4. Biometric Login with Switch
          _buildOptionItem(
            icon: Icons.fingerprint,
            iconColor: Colors.cyan,
            title: languageService?.tr('biometric_login') ?? 'Biometric Login',
            isDark: isDark,
            textPrimary: textPrimary,
            trailing: SizedBox(
              height: 24.h,
              child: Switch.adaptive(
                value: _isBiometricEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) => _toggleBiometric(),
              ),
            ),
            onTap: _toggleBiometric,
          ),
          _buildDivider(isDark),

          // 4. Change Password
          _buildOptionItem(
            icon: Icons.lock_reset_outlined,
            iconColor: Colors.orangeAccent,
            title: languageService?.tr('change_password') ?? 'Change Password',
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.CHANGE_PASSWORD),
          ),
          _buildDivider(isDark),

          // 5. Two Factor Authentication
          _buildOptionItem(
            icon: Icons.security_outlined,
            iconColor: Colors.purpleAccent,
            title:
                languageService?.tr('two_factor_authentication') ??
                'Two Factor Authentication',
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: () => Get.toNamed(AppPages.TWO_FACTOR_AUTH),
          ),

          if (isLoggedIn && authController != null) ...[
            _buildDivider(isDark),

            // 6. Delete Account
            _buildOptionItem(
              icon: Icons.delete_forever_outlined,
              iconColor: Colors.redAccent,
              title: languageService?.tr('delete_account') ?? 'Delete Account',
              isDark: isDark,
              textPrimary: Colors.redAccent,
              onTap: () => _showDeleteAccountDialog(context, authController),
            ),
            _buildDivider(isDark),

            // 7. Logout
            _buildOptionItem(
              icon: Icons.logout,
              iconColor: Colors.red,
              title: languageService?.tr('more_logout') ?? 'Logout',
              isDark: isDark,
              textPrimary: Colors.red,
              onTap: () => _showLogoutDialog(context, authController),
            ),
          ],
        ],
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.trim().isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          if (word.contains('/')) {
            return word.split('/').map((w) => _toTitleCase(w)).join(' / ');
          }
          if (word.toUpperCase() == word && word.length <= 3) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Widget _buildOptionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool isExternal = false,
    required bool isDark,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    final formattedTitle = _toTitleCase(title);
    final formattedSubtitle = subtitle != null ? _toTitleCase(subtitle) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 15.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: iconColor, size: 20.r),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        formattedTitle,
                        style: AppTextStyles.bodyText.copyWith(
                          color: textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (formattedSubtitle != null) ...[
                    Text(
                      formattedSubtitle,
                      style: AppTextStyles.bodyText.copyWith(
                        color: const Color(0xFFFF9538),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4.w),
                  ],
                  if (trailing != null)
                    trailing
                  else
                    Icon(
                      isExternal ? Icons.open_in_new : Icons.chevron_right,
                      color: isDark ? Colors.white38 : Colors.black38,
                      size: 18.r,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color:
            isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
      ),
    );
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

        return Card(
          elevation: 0,
          color: AppColors.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: InkWell(
            onTap: () async {
              final model = controller.dashboardModel.value;
              final stage = model?.data?.stageCompletion;
              await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
              controller.loadMoreScreenData();
            },
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Verify Account',
                          style: AppTextStyles.headingblack.copyWith(
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.textPrimary,
                        size: 14.r,
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Complete your profile to unlock all features',
                    style: AppTextStyles.labelOnChartPendingOrder.copyWith(
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    '$completion% ${languageService?.tr('completed') ?? 'Completed'}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2.r),
                    child: LinearProgressIndicator(
                      value: completion / 100,
                      minHeight: 3.h,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
