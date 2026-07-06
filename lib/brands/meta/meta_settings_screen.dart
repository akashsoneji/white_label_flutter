import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/home/more/one_click_trading_disclaimer_screen.dart';
import 'package:crm_app/screens/home/more/promotional/promotional_screen.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/services/app_lock_service.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/enabled_modules_service.dart';
import 'package:crm_app/services/one_click_trading_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/theme_service.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/theme_bottom_sheet.dart';

import 'meta_theme.dart';
import 'meta_trading_account_screen.dart';

/// Meta Settings screen — full parity with Vantage/Pipze MoreScreen.
/// Wired to MoreController (dashboard API), EnabledModulesService (feature
/// flags), OneClickTradingService, and BiometricService.
class MetaSettingsScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const MetaSettingsScreen({super.key, this.onNavigateToTab});

  @override
  State<MetaSettingsScreen> createState() =>
      _MetaSettingsScreenState();
}

class _MetaSettingsScreenState extends State<MetaSettingsScreen>
    with WidgetsBindingObserver {
  // ── Controllers ───────────────────────────────────────────────────────────
  late final MoreController _moreController;

  // ── Toggle state ──────────────────────────────────────────────────────────
  bool _oneClickEnabled = false;
  bool _biometricEnabled = false;

  // ── Refresh guard ─────────────────────────────────────────────────────────
  bool _hasLoadedInitialData = false;
  DateTime? _lastRefreshTime;

  final OneClickTradingService _oneClickService =
      OneClickTradingService.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // Life-cycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Safe put — reuse existing instance if MoreScreen already registered it.
    _moreController = Get.isRegistered<MoreController>()
        ? Get.find<MoreController>()
        : Get.put(MoreController());

    WidgetsBinding.instance.addObserver(this);
    _moreController.loadMoreScreenData();

    if (Get.isRegistered<EnabledModulesService>()) {
      Get.find<EnabledModulesService>().fetchEnabledModules(force: true);
    }

    _hasLoadedInitialData = true;
    _lastRefreshTime = DateTime.now();
    _loadToggles();
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
            DateTime.now()
                    .difference(_lastRefreshTime!)
                    .inMilliseconds >
                500)) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _refreshIfNeeded();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _refreshIfNeeded();
  }

  void _refreshIfNeeded() {
    if (mounted) {
      _lastRefreshTime = DateTime.now();
      _moreController.loadMoreScreenData();
    }
  }

  // ── Toggle loaders ────────────────────────────────────────────────────────

  Future<void> _loadToggles() async {
    try {
      final oneClick = await _oneClickService.isOneClickTradingEnabled();
      final bio = await SecureStorageService.getBiometricEnabled();
      if (!mounted) return;
      setState(() {
        _oneClickEnabled = oneClick;
        _biometricEnabled = bio;
      });
    } catch (_) {}
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
        builder: (_) => const OneClickTradingDisclaimerScreen(),
      ),
    );
    await _loadToggles();
  }

  Future<void> _toggleBiometric() async {
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
      CustomToastService.showError(message: 'Biometric not supported on this device');
      return;
    }
    final enrolled = await BiometricService.instance.isEnrolled();
    if (!enrolled) {
      await BiometricService.instance.openDeviceSecuritySettings();
      return;
    }
    final ok = await BiometricService.instance
        .authenticate(reason: 'Enable biometric login');
    if (!ok) return;

    await SecureStorageService.setBiometricEnabled(true);
    lock.markJustAuthenticated();
    if (!mounted) return;
    setState(() => _biometricEnabled = true);
  }

  // ── IB switch ─────────────────────────────────────────────────────────────

  Future<void> _handleSwitchToIB() async {
    try {
      final IBController ibController = Get.isRegistered<IBController>()
          ? Get.find<IBController>()
          : Get.put(IBController());

      Get.dialog(
        Center(child: CommonLoadingWidget(size: 50.0, color: MetaTheme.buyBlue)),
        barrierDismissible: false,
      );

      final ibStatusResponse = await ibController.getIBStatus();
      Get.back(closeOverlays: true);

      if (ibStatusResponse != null && ibStatusResponse.status == true) {
        final ibStatus = ibStatusResponse.data?.ibStatus;
        final isApproved = ibStatusResponse.data?.isApproved ?? false;
        final profileCompletion =
            ibStatusResponse.data?.profileCompletion ?? 0;

        if (ibStatus == 'rejected') {
          CustomToastService.showError(
            message:
                'Your IB application has been rejected. Please contact support.',
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
            duration: const Duration(seconds: 2),
            message: ibStatusResponse.message ??
                'Profile is not complete. Please complete your profile first.',
          );
        }
      } else {
        final errorMsg = ibStatusResponse?.message ??
            (Get.isRegistered<IBController>()
                ? Get.find<IBController>().errorMessage.value
                : '') ;
        CustomToastService.showError(
          message: errorMsg.isNotEmpty
              ? errorMsg
              : 'Failed to check IB status. Please try again.',
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(closeOverlays: true);
      CustomToastService.showError(message: 'Error checking IB status: $e');
    }
  }

  // ── KYC completion helper ─────────────────────────────────────────────────

  int _calculateCompletion(StageCompletion? stage) {
    if (stage == null) return 0;
    int c = 0;
    if (stage.mobileVerified != null) c += 20;
    if (stage.emailVerified != null) c += 20;
    if (stage.personalDetails == true) c += 20;
    if (stage.identityVerified == true) c += 20;
    if (stage.addressProofVerified == true) c += 20;
    return c;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      backgroundColor: MetaTheme.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),

              // ── Header title ──────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
                child: Text('Settings', style: MetaTheme.title(context)),
              ),

              // ── Profile card ──────────────────────────────────────────────
              Obx(() => _buildProfileCard(context, auth)),
              SizedBox(height: 12.h),

              // ── KYC verification card ─────────────────────────────────────
              _buildKycCard(context),
              SizedBox(height: 16.h),

              // ── Financial quick-action grid ───────────────────────────────
              _sectionLabel(context, 'Financial'),
              SizedBox(height: 8.h),
              _buildFinancialGrid(context),
              SizedBox(height: 16.h),

              // ── Trading Settings ──────────────────────────────────────────
              _sectionLabel(context, 'Trading Settings'),
              SizedBox(height: 8.h),
              Obx(() => _buildMenuList(context, _tradingSettingsItems(context))),
              SizedBox(height: 16.h),

              // ── Security & Preferences ────────────────────────────────────
              _sectionLabel(context, 'Security & Preferences'),
              SizedBox(height: 8.h),
              _buildMenuList(context, _securityItems(context)),
              SizedBox(height: 16.h),

              // ── Account ───────────────────────────────────────────────────
              _sectionLabel(context, 'Account'),
              SizedBox(height: 8.h),
              _buildMenuList(context, _accountItems(context, auth)),
              SizedBox(height: 16.h),

              // ── Version footer ────────────────────────────────────────────
              _buildVersionFooter(context),
              SizedBox(height: 80.h + MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section label
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(BuildContext c, String label) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: MetaTheme.subText(c),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 2 — Profile card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProfileCard(BuildContext c, AuthController auth) {
    final name = auth.userFullName ?? 'User';
    final email = auth.userEmail ?? '';
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : 'U';

    // Determine if profile is fully verified (for edit profile argument)
    final model = _moreController.dashboardModel.value;
    final stage = model?.data?.stageCompletion;
    final isProfileVerified = (stage?.emailVerified != null) &&
        (stage?.mobileVerified != null) &&
        (stage?.personalDetails == true);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: _cardDecoration(c),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MetaTheme.buy(c).withValues(alpha: 0.7),
                  MetaTheme.buy(c),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Name / email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.sp,
                    color: MetaTheme.mainText(c),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    email,
                    style: TextStyle(
                      color: MetaTheme.subText(c),
                      fontSize: 12.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Edit button
          Container(
            decoration: BoxDecoration(
              color: MetaTheme.buy(c).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: IconButton(
              icon: SvgPicture.asset(
                'assets/svg/edit_profile.svg',
                height: 18.h,
                width: 18.w,
                colorFilter: ColorFilter.mode(
                  MetaTheme.buy(c),
                  BlendMode.srcIn,
                ),
              ),
              onPressed: () =>
                  Get.toNamed(Routes.EDIT_PROFILE, arguments: isProfileVerified),
              padding: EdgeInsets.all(8.w),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3 — KYC verification card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildKycCard(BuildContext c) {
    return GetBuilder<MoreController>(
      builder: (controller) {
        final model = controller.dashboardModel.value;
        final stage = model?.data?.stageCompletion;
        final completion = _calculateCompletion(stage);
        if (completion == 100) return const SizedBox.shrink();

        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: MetaTheme.buy(c).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
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
                      color: MetaTheme.buy(c).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 18.sp,
                      color: MetaTheme.buy(c),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify Your Account',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: MetaTheme.mainText(c),
                          ),
                        ),
                        Text(
                          'Complete verification to unlock all features',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: MetaTheme.subText(c),
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
                      color: MetaTheme.buy(c),
                    ),
                    onPressed: () async {
                      final mdl = controller.dashboardModel.value;
                      final stg = mdl?.data?.stageCompletion;
                      await Get.toNamed(Routes.KYC_INTRO, arguments: stg);
                      controller.loadMoreScreenData();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                        backgroundColor: MetaTheme.divider(c),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          MetaTheme.buy(c),
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
                      color: MetaTheme.buy(c),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Step 4 — Financial quick-action 2×2 grid
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFinancialGrid(BuildContext c) {
    final items = [
      _CelGridItem(
        icon: Icons.south_west_rounded,
        label: 'Deposit',
        color: const Color(0xFF4CAF50),
        onTap: () => Get.to(() => PaymentMethodsScreen(accountNumber: '')),
      ),
      _CelGridItem(
        icon: Icons.north_east_rounded,
        label: 'Withdraw',
        color: const Color(0xFFFF9800),
        onTap: () => Get.toNamed(Routes.WITHDRAWAL),
      ),
      _CelGridItem(
        icon: Icons.swap_horiz_rounded,
        label: 'Transfer',
        color: const Color(0xFF2196F3),
        onTap: () => Get.toNamed(Routes.INTERNAL_TRANSFER),
      ),
      _CelGridItem(
        icon: Icons.receipt_long_rounded,
        label: 'History',
        color: const Color(0xFF9C27B0),
        onTap: () => Get.toNamed(Routes.TRANSACTION_HISTORY),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8.h,
      crossAxisSpacing: 8.w,
      childAspectRatio: 2.2,
      children: items.map((item) => _buildGridCard(c, item)).toList(),
    );
  }

  Widget _buildGridCard(BuildContext c, _CelGridItem item) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : item.color;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : item.color.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: _cardDecoration(c, radius: 10),
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
                  child: Icon(item.icon, size: 18.sp, color: iconColor),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: MetaTheme.mainText(c),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16.sp,
                color: MetaTheme.subText(c).withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 5 — Trading Settings items (feature-flag gated)
  // ─────────────────────────────────────────────────────────────────────────

  List<_CelMenuItem> _tradingSettingsItems(BuildContext c) {
    final modulesService = Get.isRegistered<EnabledModulesService>()
        ? Get.find<EnabledModulesService>()
        : null;
    final modules = modulesService?.modules.value;
    final showCopyTrading = modules?.copytrading ?? false;
    final showPmam = modules?.pmam ?? false;
    final showPromotional = modulesService?.isPromotionalMenuVisible ?? false;

    final items = <_CelMenuItem>[
      // ── Trading Account (Meta-only) ─────────────────────────────────
      _CelMenuItem(
        icon: Icons.manage_accounts_rounded,
        label: 'Trading Account',
        color: const Color(0xFF1E88E5),
        onTap: () => Get.to(
          () => MetaTradingAccountScreen(
            onNavigateToTab: widget.onNavigateToTab,
          ),
          transition: Transition.rightToLeft,
        ),
      ),
      _CelMenuItem(
        icon: Icons.account_balance_rounded,
        label: 'Finance',
        color: const Color(0xFF009688),
        onTap: () async {
          await Get.toNamed(AppPages.FINANCE);
          if (mounted) _refreshIfNeeded();
        },
      ),
    ];

    if (showPromotional) {
      items.add(_CelMenuItem(
        icon: Icons.campaign_rounded,
        label: 'Promotional',
        color: const Color(0xFFFF9800),
        onTap: () => Get.to(
          () => const PromotionalScreen(),
          transition: Transition.rightToLeft,
        ),
      ));
    }

    items.add(_CelMenuItem(
      icon: Icons.dashboard_rounded,
      label: 'IB Dashboard',
      color: MetaTheme.buy(c),
      onTap: () async => await _handleSwitchToIB(),
    ));

    if (showCopyTrading) {
      items.add(_CelMenuItem(
        icon: Icons.content_copy_rounded,
        label: 'Copy Trading',
        color: const Color(0xFF2196F3),
        onTap: () => Get.toNamed(Routes.COPY_TRADING_MAIN),
      ));
    }

    if (showPmam) {
      items.add(_CelMenuItem(
        icon: Icons.groups_rounded,
        label: 'PAMM',
        color: const Color(0xFF03A9F4),
        onTap: () => Get.toNamed(Routes.PMAM_MAIN),
      ));
    }

    return items;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 6 — Security & Preferences items
  // ─────────────────────────────────────────────────────────────────────────

  List<_CelMenuItem> _securityItems(BuildContext c) {
    final themeService = Get.find<ThemeService>();
    return [
      if (themeService.canUserChangeTheme)
        _CelMenuItem(
          icon: Icons.color_lens_rounded,
          label: 'Theme',
          color: const Color(0xFF9C27B0),
          onTap: () => showThemeBottomSheet(context),
        ),
      _CelMenuItem(
        icon: Icons.lock_outline_rounded,
        label: 'Change Password',
        color: const Color(0xFFF44336),
        onTap: () => Get.toNamed(AppPages.CHANGE_PASSWORD),
      ),
      _CelMenuItem(
        icon: Icons.security_rounded,
        label: 'Two-Factor Authentication',
        color: const Color(0xFF673AB7),
        onTap: () => Get.toNamed(Routes.TWO_FACTOR_AUTH),
      ),
      _CelMenuItem(
        icon: Icons.touch_app_rounded,
        label: 'One Click Trading',
        color: const Color(0xFF00BCD4),
        isToggle: true,
        toggleValue: _oneClickEnabled,
        onTap: _toggleOneClickTrading,
      ),
      _CelMenuItem(
        icon: Icons.fingerprint_rounded,
        label: 'Biometric Login',
        color: const Color(0xFF3F51B5),
        isToggle: true,
        toggleValue: _biometricEnabled,
        onTap: _toggleBiometric,
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 7 — Account items (tickets, delete, logout)
  // ─────────────────────────────────────────────────────────────────────────

  List<_CelMenuItem> _accountItems(BuildContext c, AuthController auth) {
    return [
      _CelMenuItem(
        icon: Icons.support_agent_rounded,
        label: 'Support Tickets',
        color: const Color(0xFFE91E63),
        onTap: () => Get.toNamed(Routes.TICKET_LIST),
      ),
      _CelMenuItem(
        icon: Icons.delete_forever_rounded,
        label: 'Delete Account',
        color: const Color(0xFFE91E63),
        onTap: () => _showDeleteAccountDialog(c, auth),
      ),
      _CelMenuItem(
        icon: Icons.logout_rounded,
        label: 'Logout',
        color: MetaTheme.sell(c),
        showArrow: false,
        onTap: () => _showLogoutDialog(c, auth),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Menu list + row renderer
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMenuList(BuildContext c, List<_CelMenuItem> items) {
    return Container(
      decoration: _cardDecoration(c),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Column(
            children: [
              _buildMenuRow(c, item),
              if (idx < items.length - 1)
                Padding(
                  padding: EdgeInsets.only(left: 52.w),
                  child: Divider(
                    height: 1,
                    color: MetaTheme.divider(c),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuRow(BuildContext c, _CelMenuItem item) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : item.color;
    final iconBg = isDark
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
                  child: Icon(item.icon, size: 18.sp, color: iconColor),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: MetaTheme.mainText(c),
                  ),
                ),
              ),
              if (item.isToggle)
                _buildToggleSwitch(c, item.toggleValue, onTap: item.onTap)
              else if (item.showArrow)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18.sp,
                  color: MetaTheme.subText(c).withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Animated toggle switch
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildToggleSwitch(BuildContext c, bool value,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42.w,
        height: 24.h,
        decoration: BoxDecoration(
          color: value ? MetaTheme.buy(c) : MetaTheme.divider(c),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.all(2.5.w),
            width: 19.w,
            height: 19.w,
            decoration: BoxDecoration(
              color: MetaTheme.card(c),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Step 8 — Version footer
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildVersionFooter(BuildContext c) {
    return Center(
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text(
              'Version ${snap.data!.version}',
              style: TextStyle(
                fontSize: 11.sp,
                color: MetaTheme.subText(c).withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 10 — Dialog helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext c, AuthController auth) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        backgroundColor: MetaTheme.card(c),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: MetaTheme.buy(c).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: BrandLogo(
                  source: FlavorConfig.effectiveLogo,
                  fit: BoxFit.contain,
                  isCircle: true,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: MetaTheme.mainText(c),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _dialogButton(
                        c,
                        label: 'Yes',
                        isPrimary: true,
                        onTap: auth.isLoading
                            ? null
                            : () async => await auth.logout(),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _dialogButton(
                      c,
                      label: 'No',
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

  void _showDeleteAccountDialog(BuildContext c, AuthController auth) {
    final passwordCtrl = TextEditingController();
    final isEmpty = false.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        backgroundColor: MetaTheme.card(c),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever_rounded,
                    size: 28.sp, color: const Color(0xFFE91E63)),
              ),
              SizedBox(height: 16.h),
              Text(
                'Are you sure you want to delete your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: MetaTheme.mainText(c),
                ),
              ),
              SizedBox(height: 16.h),
              Obx(() => TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    style: TextStyle(
                        fontSize: 14.sp, color: MetaTheme.mainText(c)),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: TextStyle(color: MetaTheme.subText(c)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide:
                            BorderSide(color: MetaTheme.divider(c)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                          color: isEmpty.value
                              ? MetaTheme.sell(c)
                              : MetaTheme.divider(c),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                          color: isEmpty.value
                              ? MetaTheme.sell(c)
                              : MetaTheme.buy(c),
                          width: 1.5,
                        ),
                      ),
                      fillColor: MetaTheme.softBg(c),
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 12.h),
                    ),
                  )),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => _dialogButton(
                          c,
                          label: 'Yes',
                          isPrimary: true,
                          isDanger: true,
                          onTap: auth.isLoading
                              ? null
                              : () {
                                  if (passwordCtrl.text.isEmpty) {
                                    isEmpty.value = true;
                                  } else {
                                    isEmpty.value = false;
                                    auth.deleteAccount({
                                      'password': passwordCtrl.text,
                                      'reason':
                                          'No longer needed',
                                      'accept_terms': true,
                                      'confirm_deletion': true,
                                    });
                                  }
                                },
                        )),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _dialogButton(
                      c,
                      label: 'No',
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

  Widget _dialogButton(
    BuildContext c, {
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
            color: isPrimary
                ? (isDanger
                    ? const Color(0xFFE91E63)
                    : MetaTheme.buy(c))
                : MetaTheme.softBg(c),
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.white : MetaTheme.mainText(c),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared card decoration helper
  // ─────────────────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration(BuildContext c, {double radius = 12}) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    return BoxDecoration(
      color: MetaTheme.card(c),
      borderRadius: BorderRadius.circular(radius.r),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 11 — Private data model classes
// ─────────────────────────────────────────────────────────────────────────────

class _CelGridItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CelGridItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _CelMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showArrow;
  final bool isToggle;
  final bool toggleValue;

  const _CelMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.showArrow = true,
    this.isToggle = false,
    this.toggleValue = false,
  });
}
