import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
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
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/services/one_click_trading_service.dart';
import 'package:crm_app/screens/home/more/one_click_trading_disclaimer_screen.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/core/config/app_config_service.dart';
import 'package:crm_app/core/feature_flags/feature_keys.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';
import 'package:crm_app/screens/home/brands/vantage/vantage_more_layout.dart';
import 'package:crm_app/services/enabled_modules_service.dart';
import 'package:crm_app/screens/home/more/promotional/promotional_screen.dart';
import 'package:crm_app/widgets/theme_bottom_sheet.dart';
import 'package:crm_app/main.dart' as main_config;

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
    if (Get.isRegistered<EnabledModulesService>()) {
      Get.find<EnabledModulesService>().fetchEnabledModules(force: true);
    }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedInitialData &&
        (_lastRefreshTime == null ||
            DateTime.now().difference(_lastRefreshTime!).inMilliseconds >
                500)) {
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
      IBController ibController;
      if (Get.isRegistered<IBController>()) {
        ibController = Get.find<IBController>();
      } else {
        ibController = Get.put(IBController());
      }

      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );

      final ibStatusResponse = await ibController.getIBStatus();

      Get.back(closeOverlays: true);

      if (ibStatusResponse != null && ibStatusResponse.status == true) {
        final ibStatus = ibStatusResponse.data?.ibStatus;
        final isApproved = ibStatusResponse.data?.isApproved ?? false;
        final profileCompletion = ibStatusResponse.data?.profileCompletion ?? 0;

        if (ibStatus == 'rejected') {
          CustomToastService.showError(
            message:
                'Your IB application has been rejected. Please contact support for more information.',
          );
          return;
        }
        if (ibStatus == 'not_applied') {
          Get.toNamed(AppPages.PARTNERSHIP_PROGRAM);
        } else if (ibStatus == 'approved' && isApproved == true) {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/ib-main');
        } else if (profileCompletion == 100) {
          Get.toNamed(AppPages.PARTNERSHIP_PROGRAM);
        } else {
          CustomToastService.showError(
            duration: Duration(seconds: 2),
            message:
                ibStatusResponse.message ??
                'Profile is not complete. Please complete your profile first.',
          );
        }
      } else {
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
      if (Get.isDialogOpen ?? false) {
        Get.back(closeOverlays: true);
      }
      CustomToastService.showError(message: 'Error checking IB status: $e');
    }
  }

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
    final AuthController authController = Get.find<AuthController>();
    final languageService = Get.find<LanguageService>();
    final isVantage = FlavorConfig.isVantage();

    final appBar =
        FlavorConfig.isVantage()
            ? null
            : AppBar(
              backgroundColor: AppColors.tradeBackgroundCenterColor,
              scrolledUnderElevation: 0,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: EdgeInsets.only(left: 16.w),
                child: AppBackButton(onPressed: () => Navigator.pop(context)),
              ),
              title: Text(
                languageService.tr('setting_title'),
                style: AppTextStyles.screenTitle,
              ),
              centerTitle: true,
            );

    final body = SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
            _buildCompactProfileCard(authController),
            SizedBox(height: 12.h),
            _buildCompactVerificationCard(languageService),
            SizedBox(height: 16.h),
            _buildCompactSection(
              title: languageService.tr('general_financial'),
              child: _buildCompactFinancialGrid(),
            ),
            SizedBox(height: 16.h),
            _buildCompactSection(
              title: languageService.tr('general_tradind_settings'),
              child: Obx(
                () => _buildCompactMenuList(_buildFinanceSectionItems()),
              ),
            ),
            SizedBox(height: 16.h),
            _buildCompactSection(
              title: languageService.tr('general_account_security'),
              child: _buildCompactMenuList(_buildSecuritySectionItems()),
            ),
            SizedBox(height: 16.h),
            _buildCompactSection(
              title: 'Account',
              child: _buildCompactMenuList(
                _buildDangerSectionItems(authController),
              ),
            ),
            SizedBox(height: 20.h),
            _buildCompactVersionInfo(languageService),
            SizedBox(height: 80.h + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );

    if (isVantage) {
      return VantageMoreLayout(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: appBar,
      body: body,
    );
  }

  Widget _buildCompactProfileCard(AuthController authController) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          AppColors.isDarkMode
              ? BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
              : BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.8),
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (authController.userFullName ?? 'U').isNotEmpty
                    ? authController.userFullName![0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cardBackground,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        authController.userFullName ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  authController.userEmail ?? '',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: IconButton(
              icon: SvgPicture.asset(
                'assets/svg/edit_profile.svg',
                height: 18.h,
                width: 18.w,
                color: AppColors.primary,
              ),
              onPressed: () {
                final model = moreController.dashboardModel.value;
                final stage = model?.data?.stageCompletion;
                final isProfileVerified =
                    (stage?.emailVerified != null) &&
                    (stage?.mobileVerified != null) &&
                    (stage?.personalDetails == true);
                Get.toNamed(
                  AppPages.EDIT_PROFILE,
                  arguments: isProfileVerified,
                );
              },
              padding: EdgeInsets.all(8.w),
              constraints: BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactVerificationCard(LanguageService languageService) {
    return GetBuilder<MoreController>(
      builder: (controller) {
        final model = controller.dashboardModel.value;
        final stage = model?.data?.stageCompletion;
        final completion = _calculateCompletion(stage);
        if (completion == 100) return const SizedBox.shrink();

        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              AppColors.isDarkMode
                  ? BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                  : BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageService.tr('verify_your_account'),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          languageService.tr('complete_verification_to_unlock'),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14.sp,
                      color: AppColors.primary,
                    ),
                    onPressed: () async {
                      final mdl = controller.dashboardModel.value;
                      final stg = mdl?.data?.stageCompletion;
                      await Get.toNamed(AppPages.KYC_INTRO, arguments: stg);
                      controller.loadMoreScreenData();
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3.r),
                      child: LinearProgressIndicator(
                        value: completion / 100,
                        minHeight: 5,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    '$completion%',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 1.0,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildCompactFinancialGrid() {
    final items = [
      _CompactGridItem(
        iconData: Icons.south_west_rounded,
        label: languageService.tr('general_deposit'),
        color: AppColors.iconGreen,
        onTap: () => Get.to(() => PaymentMethodsScreen(accountNumber: '')),
      ),
      _CompactGridItem(
        iconData: Icons.north_east_rounded,
        label: languageService.tr('general_withdraw'),
        color: AppColors.iconOrange,
        onTap: () => Get.toNamed(AppPages.WITHDRAWAL),
      ),
      _CompactGridItem(
        iconData: Icons.swap_horiz_rounded,
        label: languageService.tr('general_transfer'),
        color: AppColors.notificationBlue,
        onTap: () => Get.toNamed(AppPages.INTERNAL_TRANSFER),
      ),
      _CompactGridItem(
        iconData: Icons.receipt_long_rounded,
        label: languageService.tr('general_history'),
        color: AppColors.iconPurple,
        onTap: () => Get.toNamed(AppPages.TRANSACTION_HISTORY),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8.h,
      crossAxisSpacing: 8.w,
      childAspectRatio: 2.2,
      children: items.map((item) => _buildCompactGridCard(item)).toList(),
    );
  }

  Widget _buildCompactGridCard(_CompactGridItem item) {
    final iconColor = AppColors.isDarkMode ? Colors.white : item.color;
    final iconBg =
        AppColors.isDarkMode
            ? Colors.white.withValues(alpha: 0.12)
            : item.color.withValues(alpha: 0.12);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: [
              AppColors.isDarkMode
                  ? BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                  : BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Icon(item.iconData, size: 18.sp, color: iconColor),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16.sp,
                color: AppColors.textGrey.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_CompactMenuItem> _buildFinanceSectionItems() {
    final modulesService = Get.find<EnabledModulesService>();
    final modules = modulesService.modules.value;
    final showCopyTrading = modules?.copytrading ?? false;
    final showPmam =
        modules?.pmam ?? appConfig.isFeatureEnabled(FeatureKeys.pmam);
    final showPromotional = modulesService.isPromotionalMenuVisible;

    final items = <_CompactMenuItem>[
      _CompactMenuItem(
        iconData: Icons.account_balance_rounded,
        label: languageService.tr('general_finance'),
        color: AppColors.iconTeal,
        onTap: () async {
          await Get.toNamed(AppPages.FINANCE);
          if (mounted) _refreshDataIfNeeded();
        },
      ),
    ];

    if (showPromotional) {
      items.add(
        _CompactMenuItem(
          iconData: Icons.campaign_rounded,
          label: languageService.tr('general_promotional'),
          color: AppColors.iconOrange,
          onTap: () => Get.to(
            () => const PromotionalScreen(),
            transition: Transition.rightToLeft,
          ),
        ),
      );
    }

    items.add(
      _CompactMenuItem(
        iconData: Icons.dashboard_rounded,
        label: languageService.tr('more_dashboard'),
        color: AppColors.primary,
        onTap: () async => await _handleSwitchToIB(),
      ),
    );

    if (showCopyTrading) {
      items.add(
        _CompactMenuItem(
          iconData: Icons.content_copy_rounded,
          label: languageService.tr('more_copy_trading'),
          color: AppColors.iconBlue,
          onTap: () => Get.toNamed(AppPages.COPY_TRADING_MAIN),
        ),
      );
    }
    if (showPmam) {
      items.add(
        _CompactMenuItem(
          iconData: Icons.groups_rounded,
          label: 'PAMM',
          color: AppColors.iconLightBlue,
          onTap: () => Get.toNamed(AppPages.PMAM_MAIN),
        ),
      );
    }
    return items;
  }

  List<_CompactMenuItem> _buildSecuritySectionItems() {
    return [
      if (main_config.enableDarkModeGlobal)
        _CompactMenuItem(
          iconData: Icons.color_lens_rounded,
          label: languageService.tr('settings_theme'),
          color: AppColors.iconPurple,
          onTap: () => showThemeBottomSheet(context),
        ),
      _CompactMenuItem(
        iconData: Icons.lock_outline_rounded,
        label: languageService.tr('change_password'),
        color: AppColors.iconRed,
        onTap: () => Get.toNamed(AppPages.CHANGE_PASSWORD),
      ),
      _CompactMenuItem(
        iconData: Icons.security_rounded,
        label: languageService.tr('two_factor_authentication'),
        color: AppColors.iconDeepPurple,
        onTap: () => Get.toNamed(AppPages.TWO_FACTOR_AUTH),
      ),
      _CompactMenuItem(
        iconData: Icons.touch_app_rounded,
        label: 'One Click Trading',
        color: AppColors.iconDeepTeal,
        isToggle: true,
        toggleValue: _oneClickEnabled,
        onTap: _toggleOneClickTrading,
      ),
      _CompactMenuItem(
        iconData: Icons.fingerprint_rounded,
        label: languageService.tr('biometric_login_toggle'),
        color: AppColors.iconIndigo,
        isToggle: true,
        toggleValue: _biometricEnabled,
        onTap: _toggleBiometric,
      ),
    ];
  }

  List<_CompactMenuItem> _buildDangerSectionItems(
    AuthController authController,
  ) {
    return [
      _CompactMenuItem(
        iconData: Icons.delete_forever_rounded,
        label: languageService.tr('delete_account'),
        color: AppColors.iconPink,
        onTap: () => _showDeleteAccountDialog(authController),
      ),
      _CompactMenuItem(
        iconData: Icons.logout_rounded,
        label: languageService.tr('more_logout'),
        color: AppColors.red,
        showArrow: false,
        onTap: () => _showLogoutDialog(authController),
      ),
    ];
  }

  Widget _buildCompactMenuList(List<_CompactMenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          AppColors.isDarkMode
              ? BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
              : BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
        ],
      ),
      child: Column(
        children:
            items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _buildCompactMenuRow(item),
                  if (idx < items.length - 1)
                    Padding(
                      padding: EdgeInsets.only(left: 52.w),
                      child: Divider(
                        height: 1,
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildCompactMenuRow(_CompactMenuItem item) {
    final iconColor = AppColors.isDarkMode ? Colors.white : item.color;
    final iconBg =
        AppColors.isDarkMode
            ? Colors.white.withValues(alpha: 0.12)
            : item.color.withValues(alpha: 0.12);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Icon(item.iconData, size: 18.sp, color: iconColor),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (item.isToggle)
                _buildCompactSwitch(item.toggleValue, onTap: item.onTap)
              else if (item.showArrow)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18.sp,
                  color: AppColors.textGrey.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSwitch(bool value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42.w,
        height: 24.h,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.all(2.5.w),
            width: 19.w,
            height: 19.w,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactVersionInfo(LanguageService languageService) {
    return Center(
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final version = snapshot.data!.version;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text(
              '${languageService.tr('version_label')} $version',
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.textGrey.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog(AuthController authController) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        backgroundColor: AppColors.cardBackground,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 28.sp,
                  color: AppColors.red,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                languageService.tr('logout_confirm_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _buildCompactDialogButton(
                        label: languageService.tr('navigation_yes'),
                        isPrimary: true,
                        onTap:
                            authController.isLoading
                                ? null
                                : () async => await authController.logout(),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildCompactDialogButton(
                      label: languageService.tr('navigation_no'),
                      isPrimary: false,
                      onTap: () => Get.back(closeOverlays: true),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        backgroundColor: AppColors.cardBackground,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: AppColors.iconPink.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  size: 28.sp,
                  color: AppColors.iconPink,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                languageService.tr('delete_account_confirm_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              Obx(
                () => TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: languageService.tr(
                      'delete_account_password_hint',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color:
                            _isPasswordEmpty.value
                                ? Colors.red
                                : AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color:
                            _isPasswordEmpty.value
                                ? Colors.red
                                : AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _buildCompactDialogButton(
                        label: languageService.tr('navigation_yes'),
                        isPrimary: true,
                        isDanger: true,
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
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildCompactDialogButton(
                      label: languageService.tr('navigation_no'),
                      isPrimary: false,
                      onTap: () => Get.back(closeOverlays: true),
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

  Widget _buildCompactDialogButton({
    required String label,
    required bool isPrimary,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          height: 44.h,
          decoration: BoxDecoration(
            color:
                isPrimary
                    ? (isDanger ? AppColors.iconPink : AppColors.primary)
                    : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? AppColors.whiteColor : AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactGridItem {
  final IconData iconData;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _CompactGridItem({
    required this.iconData,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _CompactMenuItem {
  final IconData iconData;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showArrow;
  final bool isToggle;
  final bool toggleValue;

  _CompactMenuItem({
    required this.iconData,
    required this.label,
    required this.color,
    required this.onTap,
    this.showArrow = true,
    this.isToggle = false,
    this.toggleValue = false,
  });
}

class VerifyAccountCard extends StatelessWidget {
  final String title;
  final String subTitle;
  final String percentage;

  const VerifyAccountCard({
    super.key,
    required this.title,
    required this.subTitle,
    required this.percentage,
  });

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
    return GetBuilder<MoreController>(
      builder: (controller) {
        final model = controller.dashboardModel.value;
        final stage = model?.data?.stageCompletion;
        final completion = _calculateCompletion(stage);

        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              AppColors.isDarkMode
                  ? BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                  : BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.verified_user_outlined,
                        size: 22.sp,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          subTitle,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                    onPressed: () async {
                      final model = controller.dashboardModel.value;
                      final stage = model?.data?.stageCompletion;
                      await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
                      controller.loadMoreScreenData();
                    },
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: completion / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    '$completion%',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
