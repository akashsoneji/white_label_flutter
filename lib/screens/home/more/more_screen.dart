import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/home/more/promotional/promotional_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/one_click_trading_service.dart';
import 'package:crm_app/screens/home/more/one_click_trading_disclaimer_screen.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:crm_app/services/theme_service.dart';
import 'package:crm_app/core/config/app_config_service.dart';
import 'package:crm_app/core/feature_flags/feature_keys.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';
import 'package:crm_app/screens/home/brands/vantage/vantage_more_layout.dart';
import 'package:crm_app/screens/home/brands/vantage/vantage_glass_tokens.dart';
import 'package:crm_app/screens/home/brands/vantage/widgets/vantage_more_options_list.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> with WidgetsBindingObserver {
  final languageService = Get.find<LanguageService>();
  final appConfig = Get.find<AppConfigService>();
  late final MoreController moreController;
  bool _hasLoadedInitialData = false;
  DateTime? _lastRefreshTime;
  final OneClickTradingService _oneClickService =
      OneClickTradingService.instance;
  bool _oneClickEnabled = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    moreController = Get.put(MoreController());
    WidgetsBinding.instance.addObserver(this);
    _hasLoadedInitialData = false;
    moreController.loadMoreScreenData();
    _hasLoadedInitialData = true;
    _lastRefreshTime = DateTime.now();
    _loadVantageToggles();
  }

  Future<void> _loadVantageToggles() async {
    try {
      final oneClick = await _oneClickService.isOneClickTradingEnabled();
      final bio = await SecureStorageService.getBiometricEnabled();
      if (!mounted) return;
      setState(() {
        _oneClickEnabled = oneClick;
        _biometricEnabled = bio;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _toggleOneClickTrading() async {
    if (_oneClickEnabled) {
      await _oneClickService.setOneClickTradingEnabled(false);
      if (!mounted) return;
      setState(() => _oneClickEnabled = false);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OneClickTradingDisclaimerScreen(),
      ),
    );
    await _loadVantageToggles();
  }

  Future<void> _toggleBiometric() async {
    final language = Get.find<LanguageService>();
    final lock = Get.find<AppLockService>();

    if (_biometricEnabled) {
      await SecureStorageService.setBiometricEnabled(false);
      lock.clearLock();
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
      return;
    }

    final supported = await BiometricService.instance.isDeviceSupported();
    if (!supported) {
      CustomToastService.showError(
        message: language.tr('biometric_not_supported'),
      );
      return;
    }

    final enrolled = await BiometricService.instance.isEnrolled();
    if (!enrolled) {
      await BiometricService.instance.openDeviceSecuritySettings();
      return;
    }

    final ok = await BiometricService.instance.authenticate(
      reason: language.tr('biometric_enable_reason'),
    );
    if (!ok) return;

    await SecureStorageService.setBiometricEnabled(true);
    lock.markJustAuthenticated();
    if (!mounted) return;
    setState(() => _biometricEnabled = true);
  }

  Future<void> _openThemePickerSheet() async {
    final themeService = Get.find<ThemeService>();
    final languageService = Get.find<LanguageService>();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (ctx) {
        return Obx(() {
          final current = themeService.themeModeRx.value;
          Widget item(ThemeMode mode, String label, IconData icon) {
            return ListTile(
              leading: Icon(icon, color: AppColors.primary),
              title: Text(
                label,
                style: TextStyle(color: AppColors.textPrimary),
              ),
              trailing:
                  current == mode
                      ? Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
              onTap: () async {
                await themeService.setThemeMode(mode);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            );
          }

          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 6.h),
                item(
                  ThemeMode.system,
                  languageService.tr('settings_theme_system'),
                  Icons.brightness_auto,
                ),
                item(
                  ThemeMode.light,
                  languageService.tr('settings_theme_light'),
                  Icons.light_mode,
                ),
                item(
                  ThemeMode.dark,
                  languageService.tr('settings_theme_dark'),
                  Icons.dark_mode,
                ),
                SizedBox(height: 10.h),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes visible after navigation
    // Only refresh if it's been more than 500ms since last refresh to avoid excessive calls
    // Reduced from 1 second to make it more responsive
    if (_hasLoadedInitialData &&
        (_lastRefreshTime == null ||
            DateTime.now().difference(_lastRefreshTime!).inMilliseconds >
                500)) {
      // Add a small delay to ensure screen is fully visible before refreshing
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _refreshDataIfNeeded();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app resumes (user returns to app)
    if (state == AppLifecycleState.resumed) {
      _refreshDataIfNeeded();
    }
  }

  void _refreshDataIfNeeded() {
    if (mounted) {
      _lastRefreshTime = DateTime.now();
      moreController.loadMoreScreenData();
    }
  }

  Future<void> _handleSwitchToIB() async {
    try {
      // Get or create IBController
      IBController ibController;
      if (Get.isRegistered<IBController>()) {
        ibController = Get.find<IBController>();
      } else {
        ibController = Get.put(IBController());
      }

      // Show loading
      Get.dialog(
        Center(
          child: CommonLoadingWidget(
            // message: 'Checking IB status...',
            size: 50.0,
            color: AppColors.primary,
          ),
        ),
        barrierDismissible: false,
      );

      // Call IB Status API
      final ibStatusResponse = await ibController.getIBStatus();

      // Close loading dialog
      Get.back(closeOverlays: true);

      if (ibStatusResponse != null && ibStatusResponse.status == true) {
        final ibStatus = ibStatusResponse.data?.ibStatus;
        final isApproved = ibStatusResponse.data?.isApproved ?? false;
        final profileCompletion = ibStatusResponse.data?.profileCompletion ?? 0;

        // If IB status is rejected, show toast message
        if (ibStatus == 'rejected') {
          CustomToastService.showError(
            message:
                'Your IB application has been rejected. Please contact support for more information.',
          );
          return;
        }
        // If IB status is rejected, show toast message
        if (ibStatus == 'not_applied') {
          Get.toNamed(AppPages.PARTNERSHIP_PROGRAM);
        }
        // If IB is approved, navigate to IB Main
        else if (ibStatus == 'approved' && isApproved == true) {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/ib-main');
        }
        // If profile is 100% complete but IB not approved, go to Partnership Program
        else if (profileCompletion == 100) {
          Get.toNamed(AppPages.PARTNERSHIP_PROGRAM);
        }
        // If profile is not complete, show error message
        else {
          CustomToastService.showError(
            duration: Duration(seconds: 2),
            message:
                ibStatusResponse.message ??
                'Profile is not complete. Please complete your profile first.',
          );
        }
      } else {
        // Handle error response (status: false)
        String errorMsg;
        if (ibStatusResponse?.message != null) {
          errorMsg = ibStatusResponse!.message!;
        } else if (ibController.errorMessage.value.isNotEmpty) {
          errorMsg = ibController.errorMessage.value;
        } else {
          errorMsg = 'Failed to check IB status. Please try again.';
        }
        CustomToastService.showError(message: errorMsg);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back(closeOverlays: true);
      }
      CustomToastService.showError(message: 'Error checking IB status: $e');
    }
  }

  int _calculateCompletion(StageCompletion? stage) {
    print('_calculateCompletion - stage: $stage');
    if (stage == null) {
      print('_calculateCompletion - stage is null, returning 0');
      return 0;
    }

    print('_calculateCompletion - mobileVerified: ${stage.mobileVerified}');
    print('_calculateCompletion - emailVerified: ${stage.emailVerified}');
    print('_calculateCompletion - personalDetails: ${stage.personalDetails}');
    print('_calculateCompletion - identityVerified: ${stage.identityVerified}');
    print(
      '_calculateCompletion - addressProofVerified: ${stage.addressProofVerified}',
    );

    int completion = 0;

    // Step 1: Check mobile verification - if mobileVerified is not null (has valid DateTime)
    if (stage.mobileVerified != null) {
      completion += 20;
      print('Step 1 - Mobile Verified: +20% = $completion%');
    } else {
      print('Step 1 - Mobile Not Verified: 0%');
    }

    // Step 2: Check email verification - if emailVerified is not null (has valid DateTime)
    if (stage.emailVerified != null) {
      completion += 20;
      print('Step 2 - Email Verified: +20% = $completion%');
    } else {
      print('Step 2 - Email Not Verified: $completion%');
    }

    // Step 3: Check personal details - if personalDetails is true
    if (stage.personalDetails == true) {
      completion += 20;
      print('Step 3 - Personal Details: +20% = $completion%');
    } else {
      print('Step 3 - Personal Details Not Complete: $completion%');
    }

    // Step 4: Check identity verification - if identityVerified is true
    if (stage.identityVerified == true) {
      completion += 20;
      print('Step 4 - Identity Verified: +20% = $completion%');
    } else {
      print('Step 4 - Identity Not Verified: $completion%');
    }

    // Step 5: Check address proof verification - if addressProofVerified is true
    if (stage.addressProofVerified == true) {
      completion += 20;
      print('Step 5 - Address Proof Verified: +20% = $completion%');
    } else {
      print('Step 5 - Address Proof Not Verified: $completion%');
    }

    print('FINAL COMPLETION: $completion%');
    return completion;
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final languageService = Get.find<LanguageService>();
    final isVantage = FlavorConfig.isVantage();

    final appBar =
        FlavorConfig.isVantage()
            ? null
            : AppBar(
              scrolledUnderElevation: 0.0,
              backgroundColor: AppColors.tradeBackgroundCenterColor,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                languageService.tr('setting_title'),
                style: AppTextStyles.screenTitle,
              ),
              centerTitle: true,
              actions: [
                Obx(() {
                  final model = moreController.dashboardModel.value;
                  final stage = model?.data?.stageCompletion;
                  final isProfileVerified =
                      (stage?.emailVerified != null) &&
                      (stage?.mobileVerified != null) &&
                      (stage?.personalDetails == true);

                  return IconButton(
                    icon: SvgPicture.asset(
                      'assets/svg/edit_profile.svg',
                      height: 24.h,
                      width: 24.w,
                      color: AppColors.primary,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 8.h,
                    ),
                    onPressed: () {
                      Get.toNamed(
                        AppPages.EDIT_PROFILE,
                        arguments: isProfileVerified,
                      );
                    },
                  );
                }),
              ],
            );

    final body = SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16.w,
          isVantage ? 4.h : 8.h,
          16.w,
          90.h + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section Card
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration:
                  isVantage
                      ? VantageUiTokens.cardDecoration()
                      : BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24.r,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      size: 28.r,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${authController.userFullName}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18.sp,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            GetBuilder<MoreController>(
                              builder: (controller) {
                                final model = controller.dashboardModel.value;
                                final stage = model?.data?.stageCompletion;
                                final completion = _calculateCompletion(stage);
                                return Icon(
                                  Icons.verified,
                                  color:
                                      (completion == 100)
                                          ? AppColors.primary
                                          : AppColors.icongrey.withValues(
                                            alpha: 0.3,
                                          ),
                                  size: 18.r,
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${authController.userEmail}',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isVantage)
                    Obx(() {
                      final model = moreController.dashboardModel.value;
                      final stage = model?.data?.stageCompletion;
                      final isProfileVerified =
                          (stage?.emailVerified != null) &&
                          (stage?.mobileVerified != null) &&
                          (stage?.personalDetails == true);
                      return IconButton(
                        icon: SvgPicture.asset(
                          'assets/svg/edit_profile.svg',
                          height: 22.h,
                          width: 22.w,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          Get.toNamed(
                            AppPages.EDIT_PROFILE,
                            arguments: isProfileVerified,
                          );
                        },
                      );
                    }),
                ],
              ),
            ),

            SizedBox(height: isVantage ? 6.h : 8.h),
            GetBuilder<MoreController>(
              builder: (controller) {
                final model = controller.dashboardModel.value;
                final stage = model?.data?.stageCompletion;
                final completion = _calculateCompletion(stage);
                return completion == 100
                    ? const SizedBox.shrink()
                    : Column(
                      children: [
                        VerifyAccountCard(
                          title: languageService.tr('verify_your_account'),
                          subTitle: languageService.tr(
                            'complete_verification_to_unlock',
                          ),
                          percentage: '',
                        ),
                      ],
                    );
              },
            ),
            SizedBox(height: isVantage ? 6.h : 8.h),

            // Vantage: show ALL key options (list-style cards)
            if (isVantage) ...[
              _SectionHeader(title: languageService.tr('general_financial')),
              VantageMoreQuickActionsGrid(
                items: [
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/deposit.svg',
                    label: languageService.tr('general_deposit'),
                    tint: const Color(0xFF4CAF50),
                    onTap:
                        () => Get.to(
                          () => PaymentMethodsScreen(accountNumber: ''),
                        ),
                  ),
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/withdrawal.svg',
                    label: languageService.tr('general_withdraw'),
                    tint: const Color(0xFFFF9800),
                    onTap: () => Get.toNamed(AppPages.WITHDRAWAL),
                  ),
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/internal-transfer.svg',
                    label: languageService.tr('general_transfer'),
                    tint: const Color(0xFF2196F3),
                    onTap: () => Get.toNamed(AppPages.INTERNAL_TRANSFER),
                  ),
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/clock.svg',
                    label: languageService.tr('general_history'),
                    tint: const Color(0xFF9C27B0),
                    onTap: () => Get.toNamed(AppPages.TRANSACTION_HISTORY),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              VantageMoreOptionsList(
                items: [
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/dollar-circle.svg',
                    label: languageService.tr('general_finance'),
                    tint: const Color(0xFF00BFA5),
                    onTap: () async {
                      await Get.toNamed(AppPages.FINANCE);
                      if (mounted) _refreshDataIfNeeded();
                    },
                  ),
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/promotional.svg',
                    label: languageService.tr('general_promotional'),
                    tint: const Color(0xFF7C4DFF),
                    onTap:
                        () => Get.to(
                          () => const PromotionalScreen(),
                          transition: Transition.rightToLeft,
                        ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              _SectionHeader(
                title: languageService.tr('general_tradind_settings'),
              ),
              VantageMoreOptionsList(
                items: [
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/dashboard.svg',
                    label: languageService.tr('more_dashboard'),
                    tint: AppColors.primary,
                    onTap: () async => await _handleSwitchToIB(),
                  ),
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/copy-trading.svg',
                    label: languageService.tr('more_copy_trading'),
                    tint: const Color(0xFF1E88E5),
                    onTap: () => Get.toNamed(AppPages.COPY_TRADING_HUB),
                  ),
                  if (appConfig.isFeatureEnabled(FeatureKeys.pmam))
                    VantageMoreItem(
                      iconAsset: 'assets/svg/more/dashboard.svg',
                      label: 'PMAM',
                      tint: const Color(0xFF29B6F6),
                      onTap: () => Get.toNamed(AppPages.PMAM_MAIN),
                    ),
                ],
              ),
              SizedBox(height: 18.h),

              _SectionHeader(
                title: languageService.tr('general_account_security'),
              ),
              VantageMoreOptionsList(
                items: [
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/change_password.svg',
                    label: languageService.tr('change_password'),
                    tint: const Color(0xFFEF5350),
                    onTap: () => Get.toNamed(AppPages.CHANGE_PASSWORD),
                  ),
                  VantageMoreItem(
                    iconData: Icons.touch_app_rounded,
                    label: 'One Click',
                    tint: const Color(0xFF26A69A),
                    onTap: _toggleOneClickTrading,
                    showSwitch: true,
                    switchValue: _oneClickEnabled,
                    onSwitchChanged: (v) => _toggleOneClickTrading(),
                  ),
                  VantageMoreItem(
                    iconData: Icons.fingerprint_rounded,
                    label: languageService.tr('biometric_login_toggle'),
                    tint: const Color(0xFF5C6BC0),
                    onTap: _toggleBiometric,
                    showSwitch: true,
                    switchValue: _biometricEnabled,
                    onSwitchChanged: (v) => _toggleBiometric(),
                  ),
                  VantageMoreItem(
                    iconData: Icons.brightness_6_rounded,
                    label: languageService.tr('settings_theme_title'),
                    tint: const Color(0xFFFFB300),
                    onTap: _openThemePickerSheet,
                  ),
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/personal_info.svg',
                    label: languageService.tr('delete_account'),
                    tint: const Color(0xFFEC407A),
                    onTap: () => _showDeleteAccountDialog(authController),
                  ),
                  VantageMoreItem(
                    iconAsset: 'assets/svg/more/logout.svg',
                    label: languageService.tr('more_logout'),
                    tint: AppColors.red,
                    onTap: () => _showLogoutDialog(authController),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
            ] else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: AppColors.icongrey.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10.h,
                  crossAxisSpacing: 10.w,
                  childAspectRatio: 3.4,
                  children: [
                    _QuickActionButton(
                      icon: 'deposit',
                      label: languageService.tr('general_deposit'),
                      color: const Color(0xFF4CAF50), // Green
                      onTap:
                          () => Get.to(
                            () => PaymentMethodsScreen(accountNumber: ''),
                          ),
                    ),
                    _QuickActionButton(
                      icon: 'withdrawal',
                      label: languageService.tr('general_withdraw'),
                      color: const Color(0xFFFF9800), // Orange
                      onTap: () => Get.toNamed(AppPages.WITHDRAWAL),
                    ),
                    _QuickActionButton(
                      icon: 'internal-transfer',
                      label: languageService.tr('general_transfer'),
                      color: const Color(0xFF2196F3), // Blue
                      onTap: () => Get.toNamed(AppPages.INTERNAL_TRANSFER),
                    ),
                    _QuickActionButton(
                      icon: 'clock',
                      label: languageService.tr('general_history'),
                      color: const Color(0xFF9C27B0), // Purple
                      onTap: () => Get.toNamed(AppPages.TRANSACTION_HISTORY),
                    ),
                  ],
                ),
              ),

            // Verification Card (if not completed)
            if (!isVantage) ...[
              // Financial Section
              // _SectionHeader(title: languageService.tr('general_financial')),
              _CardGroup(
                children: [
                  _MenuItem(
                    icon: 'dollar-circle',
                    label: languageService.tr('general_finance'),
                    onTap: () async {
                      await Get.toNamed(AppPages.FINANCE);
                      if (mounted) _refreshDataIfNeeded();
                    },
                    dense: true,
                  ),
                  _MenuItem(
                    icon: 'promotional',
                    label: languageService.tr('general_promotional'),
                    onTap:
                        () => Get.to(
                          () => const PromotionalScreen(),
                          transition: Transition.rightToLeft,
                        ),
                    dense: true,
                  ),
                  // _MenuItemWithButton(
                  //   icon: 'dashboard',
                  //   label: languageService.tr('more_dashboard'),
                  //   buttonText: languageService.tr('switch_to_ib'),
                  //   onTap: () {},
                  //   onButtonTap: () async => await _handleSwitchToIB(),
                  // ),
                  _MenuItem(
                    icon: 'dashboard',
                    label: languageService.tr('more_dashboard'),
                    // buttonText: languageService.tr('switch_to_ib'),
                    onTap: () async => await _handleSwitchToIB(),
                    dense: true,
                  ),
                  _MenuItem(
                    icon: 'copy-trading',
                    label: languageService.tr('more_copy_trading'),
                    onTap: () => Get.toNamed(AppPages.COPY_TRADING_HUB),
                    dense: true,
                  ),
                  // _MenuItem(
                  //   icon: 'copy-trading',
                  //   label: languageService.tr('more_copy_trading'),
                  //   onTap: () => Get.toNamed(AppPages.COPY_TRADING_HUB),
                  // ),

                  // _MenuItemWithButton(
                  //   icon: 'copy-trading',
                  //   label: languageService.tr('more_copy_trading'),
                  //   buttonText: languageService.tr('switch_to_copy_trading'),
                  //   onTap: () => Get.toNamed(AppPages.COPY_TRADING_MAIN),
                  //   onButtonTap: () => Get.toNamed(AppPages.COPY_TRADING_MAIN),
                  // ),
                  if (appConfig.isFeatureEnabled(FeatureKeys.pmam))
                    _MenuItem(
                      icon: 'dashboard',
                      label: 'PMAM',
                      onTap: () => Get.toNamed(AppPages.PMAM_MAIN),
                      dense: true,
                    ),
                ],
              ),

              SizedBox(height: 20.h),

              // Account & Security Section
              _SectionHeader(
                title: languageService.tr('general_tradind_settings'),
              ),
              _CardGroup(children: [const _OneClickTradingMenuItem()]),

              SizedBox(height: 20.h),

              // Others Section
              _SectionHeader(
                title: languageService.tr('general_account_security'),
              ),
              _CardGroup(
                children: [
                  _MenuItem(
                    icon: 'change_password',
                    label: languageService.tr('change_password'),
                    onTap: () => Get.toNamed(AppPages.CHANGE_PASSWORD),
                    dense: true,
                  ),
                  const _BiometricLoginMenuItem(),
                  const _ThemeModeMenuItem(),
                  _MenuItem(
                    icon: 'personal_info',
                    label: languageService.tr('delete_account'),
                    onTap: () => _showDeleteAccountDialog(authController),
                    dense: true,
                  ),
                  _MenuItem(
                    icon: 'logout',
                    label: languageService.tr('more_logout'),
                    onTap: () => _showLogoutDialog(authController),
                    color: AppColors.red,
                    showArrow: false,
                    dense: true,
                  ),
                ],
              ),
            ],

            SizedBox(height: 22.h),

            // App Version
            // App Version
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final version = snapshot.data!.version;

                return Center(
                  child: Text(
                    '${languageService.tr('version_label')} $version',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textGrey.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 42.h),
          ],
        ),
      ),
    );

    // if (isVantage) {
    //   return VantageMoreLayout(
    //     backgroundColor: AppColors.tradeBackgroundCenterColor,
    //     child: Stack(
    //       children: [
    //         body,
    //         Positioned(
    //           top: MediaQuery.of(context).padding.top + 8.h,
    //           right: 0,
    //           child: Obx(() {
    //             final model = moreController.dashboardModel.value;
    //             final stage = model?.data?.stageCompletion;
    //             final isProfileVerified =
    //                 (stage?.emailVerified != null) &&
    //                 (stage?.mobileVerified != null) &&
    //                 (stage?.personalDetails == true);

    //             return Container(
    //               margin: EdgeInsets.only(right: 16.w),
    //               decoration: BoxDecoration(
    //                 color: AppColors.whiteColor,
    //                 borderRadius: BorderRadius.circular(24.r),
    //                 boxShadow: [
    //                   BoxShadow(
    //                     color: Colors.black.withValues(alpha: 0.12),
    //                     blurRadius: 10,
    //                     offset: const Offset(0, 3),
    //                   ),
    //                 ],
    //               ),
    //               child: IconButton(
    //                 icon: SvgPicture.asset(
    //                   'assets/svg/edit_profile.svg',
    //                   height: 20.h,
    //                   width: 20.w,
    //                   color: AppColors.primary,
    //                 ),
    //                 padding: EdgeInsets.all(8.r),
    //                 constraints: const BoxConstraints(),
    //                 onPressed: () {
    //                   Get.toNamed(
    //                     AppPages.EDIT_PROFILE,
    //                     arguments: isProfileVerified,
    //                   );
    //                 },
    //               ),
    //             );
    //           }),
    //         ),
    //       ],
    //     ),
    //   );
    // }

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: appBar,
      body: body,
    );
  }

  void _showLogoutDialog(AuthController authController) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.whiteColor,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.whiteColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App logo - replace asset path with your app logo svg or image
              BrandLogo(
                source: FlavorConfig.effectiveLogo,
                height: 60.h,
                width: 60.w,
                color: null,
              ),
              SizedBox(height: 24.h),
              Text(
                languageService.tr('logout_confirm_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Obx(
                      () => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            authController.isLoading
                                ? null
                                : () async {
                                  await authController.logout();
                                },
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            languageService.tr('navigation_yes'),
                            style: TextStyle(
                              color: AppColors.whiteColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Get.back(closeOverlays: true);
                      },
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService.tr('navigation_no'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16.sp,
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

  void _showDeleteAccountDialog(AuthController authController) {
    final TextEditingController _passwordController = TextEditingController();
    final RxBool _isPasswordEmpty = false.obs;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.whiteColor,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.whiteColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App logo - replace asset path with your app logo svg or image
              BrandLogo(
                source: FlavorConfig.effectiveLogo,
                height: 80.h,
                width: 80.w,
                color: null,
              ),
              SizedBox(height: 24.h),
              Text(
                languageService.tr('delete_account_confirm_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Obx(
                  () => TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: languageService.tr(
                        'delete_account_password_hint',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _isPasswordEmpty.value
                                  ? Colors.red
                                  : AppColors.textGrey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _isPasswordEmpty.value
                                  ? Colors.red
                                  : AppColors.textGrey,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _isPasswordEmpty.value
                                  ? Colors.red
                                  : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Obx(
                      () => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            authController.isLoading
                                ? null
                                : () {
                                  if (_passwordController.text.isEmpty) {
                                    _isPasswordEmpty.value = true;
                                  } else {
                                    _isPasswordEmpty.value = false;
                                    authController.deleteAccount({
                                      "password": _passwordController.text,
                                      "reason": languageService.tr(
                                        'delete_account_reason_no_longer_needed',
                                      ),
                                      "accept_terms": true,
                                      "confirm_deletion": true,
                                    });
                                  }
                                },
                        child: Container(
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            languageService.tr('navigation_yes'),
                            style: TextStyle(
                              color: AppColors.whiteColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Get.back(closeOverlays: true);
                      },
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          languageService.tr('navigation_no'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16.sp,
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
}

class _QuickActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVantage = FlavorConfig.isVantage();
    final dense = isVantage;
    final bool gridMode = !isVantage;
    final double box = dense ? 32.w : (gridMode ? 40.w : 48.w);
    final double iconSize = dense ? 16.w : (gridMode ? 18.w : 20.w);
    final double fontSize = dense ? 9.5.sp : (gridMode ? 12.sp : 11.sp);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: isVantage ? null : double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: dense ? 2.h : (gridMode ? 10.h : 8.h),
          horizontal: gridMode ? 12.w : 0,
        ),
        child:
            gridMode
                ? Row(
                  children: [
                    Container(
                      width: box,
                      height: box,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/svg/more/$icon.svg',
                          width: iconSize,
                          height: iconSize,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: box,
                      height: box,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/svg/more/$icon.svg',
                          width: iconSize,
                          height: iconSize,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(height: dense ? 3.h : 8.h),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 10.h, top: 2.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textGrey.withValues(alpha: 0.75),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  final List<Widget> children;
  const _CardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isVantage = FlavorConfig.isVantage();
    final borderAlpha = AppColors.isDarkMode ? 0.22 : 0.14;
    return Container(
      decoration:
          isVantage
              ? VantageUiTokens.groupDecoration()
              : BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: AppColors.icongrey.withValues(alpha: 0.14),
                ),
              ),
      child: Column(
        children:
            children.asMap().entries.map((entry) {
              int idx = entry.key;
              Widget val = entry.value;
              if (idx == children.length - 1) return val;
              return Column(
                children: [
                  val,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Divider(
                      height: 1,
                      color:
                          isVantage
                              ? AppColors.border.withValues(alpha: borderAlpha)
                              : AppColors.icongrey.withValues(alpha: 0.14),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }
}

// ignore: unused_element
class _MenuItemWithButton extends StatelessWidget {
  final String icon;
  final String label;
  final String buttonText;
  final VoidCallback onTap;
  final VoidCallback onButtonTap;

  const _MenuItemWithButton({
    required this.icon,
    required this.label,
    required this.buttonText,
    required this.onTap,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          child: Row(
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/svg/more/$icon.svg',
                    height: 16.h,
                    width: 16.w,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: onButtonTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  elevation: 0,
                  minimumSize: Size(0, 30.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  buttonText,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showArrow;
  final bool dense;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showArrow = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final double iconBox = dense ? 30.w : 34.w;
    final double iconSize = dense ? 16.h : 18.h;
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: 16.w,
      vertical: dense ? 9.h : 11.h,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/svg/more/$icon.svg',
                    height: iconSize,
                    width: iconSize,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: dense ? 12.w : 14.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: dense ? 13.5.sp : 14.sp,
                    fontWeight: FontWeight.w400,
                    color: color ?? AppColors.textPrimary,
                  ),
                ),
              ),
              if (showArrow)
                Icon(
                  Icons.chevron_right_rounded,
                  size: dense ? 20.sp : 22.sp,
                  color: AppColors.icongrey.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OneClickTradingMenuItem extends StatefulWidget {
  const _OneClickTradingMenuItem();

  @override
  State<_OneClickTradingMenuItem> createState() =>
      _OneClickTradingMenuItemState();
}

class _OneClickTradingMenuItemState extends State<_OneClickTradingMenuItem> {
  final OneClickTradingService _oneClickService =
      OneClickTradingService.instance;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await _oneClickService.isOneClickTradingEnabled();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.touch_app_rounded,
                size: 18.sp,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              'One Click Trading',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              if (!_isEnabled) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const OneClickTradingDisclaimerScreen(),
                  ),
                );
                await _loadState();
              } else {
                await _oneClickService.setOneClickTradingEnabled(false);
                setState(() => _isEnabled = false);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44.w,
              height: 24.h,
              decoration: BoxDecoration(
                color:
                    _isEnabled
                        ? AppColors.primary
                        : AppColors.icongrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    _isEnabled ? Alignment.centerRight : Alignment.centerLeft,
                curve: Curves.easeOut,
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: 16.w,
                  height: 16.w,
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricLoginMenuItem extends StatefulWidget {
  const _BiometricLoginMenuItem();

  @override
  State<_BiometricLoginMenuItem> createState() =>
      _BiometricLoginMenuItemState();
}

class _BiometricLoginMenuItemState extends State<_BiometricLoginMenuItem> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await SecureStorageService.getBiometricEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _toggle() async {
    final language = Get.find<LanguageService>();
    final lock = Get.find<AppLockService>();

    if (_enabled) {
      await SecureStorageService.setBiometricEnabled(false);
      lock.clearLock();
      if (!mounted) return;
      setState(() => _enabled = false);
      return;
    }

    final supported = await BiometricService.instance.isDeviceSupported();
    if (!supported) {
      CustomToastService.showError(
        message: language.tr('biometric_not_supported'),
      );
      return;
    }

    final enrolled = await BiometricService.instance.isEnrolled();
    if (!enrolled) {
      await _showNotEnrolledDialog(language);
      return;
    }

    final ok = await BiometricService.instance.authenticate(
      reason: language.tr('biometric_enable_reason'),
    );
    if (!ok) return;

    await SecureStorageService.setBiometricEnabled(true);
    lock.markJustAuthenticated();
    if (!mounted) return;
    setState(() => _enabled = true);
  }

  Future<void> _showNotEnrolledDialog(LanguageService language) async {
    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint, size: 40.r, color: AppColors.primary),
              SizedBox(height: 10.h),
              Text(
                language.tr('biometric_not_enrolled_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                language.tr('biometric_not_enrolled_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(closeOverlays: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: AppColors.icongrey.withValues(alpha: 0.25),
                        ),
                        minimumSize: Size(double.infinity, 44.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(language.tr('navigation_no')),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back(closeOverlays: true);
                        await BiometricService.instance
                            .openDeviceSecuritySettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.whiteColor,
                        minimumSize: Size(double.infinity, 44.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(language.tr('biometric_open_settings')),
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
    final languageService = Get.find<LanguageService>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.fingerprint_rounded,
                size: 18.sp,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              languageService.tr('biometric_login_toggle'),
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44.w,
              height: 24.h,
              decoration: BoxDecoration(
                color:
                    _enabled
                        ? AppColors.primary
                        : AppColors.icongrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    _enabled ? Alignment.centerRight : Alignment.centerLeft,
                curve: Curves.easeOut,
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: 16.w,
                  height: 16.w,
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeMenuItem extends StatelessWidget {
  const _ThemeModeMenuItem();

  String _labelFor(ThemeMode mode, LanguageService languageService) {
    switch (mode) {
      case ThemeMode.system:
        return languageService.tr('settings_theme_system');
      case ThemeMode.light:
        return languageService.tr('settings_theme_light');
      case ThemeMode.dark:
        return languageService.tr('settings_theme_dark');
    }
  }

  IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  Future<void> _openThemePickerSheet(
    BuildContext context,
    ThemeService themeService,
    LanguageService languageService,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (ctx) {
        return Obx(() {
          final current = themeService.themeModeRx.value;
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 18.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      languageService.tr('settings_theme_title'),
                      style: AppTextStyles.heading.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: current,
                    title: Text(
                      languageService.tr('settings_theme_system'),
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      if (v == null) return;
                      await themeService.setThemeMode(v);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: current,
                    title: Text(
                      languageService.tr('settings_theme_light'),
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      if (v == null) return;
                      await themeService.setThemeMode(v);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: current,
                    title: Text(
                      languageService.tr('settings_theme_dark'),
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      if (v == null) return;
                      await themeService.setThemeMode(v);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    final languageService = Get.find<LanguageService>();

    return Obx(() {
      final mode = themeService.themeModeRx.value;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              () =>
                  _openThemePickerSheet(context, themeService, languageService),
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
            child: Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _iconFor(mode),
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    languageService.tr('settings_theme_title'),
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _labelFor(mode, languageService),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey.withValues(alpha: 0.9),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.sp,
                  color: AppColors.icongrey.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class VerifyAccountCard extends StatelessWidget {
  final String title;
  final String subTitle;
  final String percentage;

  VerifyAccountCard({
    super.key,
    required this.title,
    required this.subTitle,
    required this.percentage,
  });

  final languageService = Get.find<LanguageService>();
  final MoreController moreController = Get.find<MoreController>();

  int _calculateCompletion(StageCompletion? stage) {
    print('_calculateCompletion - stage: $stage');
    if (stage == null) {
      print('_calculateCompletion - stage is null, returning 0');
      return 0;
    }

    print('_calculateCompletion - mobileVerified: ${stage.mobileVerified}');
    print('_calculateCompletion - emailVerified: ${stage.emailVerified}');
    print('_calculateCompletion - personalDetails: ${stage.personalDetails}');
    print('_calculateCompletion - identityVerified: ${stage.identityVerified}');
    print(
      '_calculateCompletion - addressProofVerified: ${stage.addressProofVerified}',
    );

    int completion = 0;

    // Step 1: Check mobile verification - if mobileVerified is not null (has valid DateTime)
    if (stage.mobileVerified != null) {
      completion += 20;
      print('Step 1 - Mobile Verified: +20% = $completion%');
    } else {
      print('Step 1 - Mobile Not Verified: 0%');
    }

    // Step 2: Check email verification - if emailVerified is not null (has valid DateTime)
    if (stage.emailVerified != null) {
      completion += 20;
      print('Step 2 - Email Verified: +20% = $completion%');
    } else {
      print('Step 2 - Email Not Verified: $completion%');
    }

    // Step 3: Check personal details - if personalDetails is true
    if (stage.personalDetails == true) {
      completion += 20;
      print('Step 3 - Personal Details: +20% = $completion%');
    } else {
      print('Step 3 - Personal Details Not Complete: $completion%');
    }

    // Step 4: Check identity verification - if identityVerified is true
    if (stage.identityVerified == true) {
      completion += 20;
      print('Step 4 - Identity Verified: +20% = $completion%');
    } else {
      print('Step 4 - Identity Not Verified: $completion%');
    }

    // Step 5: Check address proof verification - if addressProofVerified is true
    if (stage.addressProofVerified == true) {
      completion += 20;
      print('Step 5 - Address Proof Verified: +20% = $completion%');
    } else {
      print('Step 5 - Address Proof Not Verified: $completion%');
    }

    print('FINAL COMPLETION: $completion%');
    return completion;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MoreController>(
      builder: (controller) {
        final model = controller.dashboardModel.value;
        final stage = model?.data?.stageCompletion;
        final completion = _calculateCompletion(stage);

        print('COMPLETION----- $completion');
        print('Model data: ${model?.data}');
        print('Stage completion: $stage');
        return Card(
          elevation: 0,
          color: AppColors.primary.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () async {
              final model = controller.dashboardModel.value;
              final stage = model?.data?.stageCompletion;
              // Navigate to KYC intro and refresh data when returning
              await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
              // Refresh data when returning from KYC screens
              controller.loadMoreScreenData();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with title + arrow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title, style: AppTextStyles.headingblack),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.textPrimary,
                        size: 16,
                      ),
                    ],
                  ),

                  // const SizedBox(height: 6),

                  // Subtitle
                  Text(subTitle, style: AppTextStyles.labelOnChartPendingOrder),

                  const SizedBox(height: 8),

                  // Progress row with percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$completion% ${languageService.tr('completed')}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: completion / 100,
                          minHeight: 3,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
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
      },
    );
  }
}
