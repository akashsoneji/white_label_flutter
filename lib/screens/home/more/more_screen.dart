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
          child: CommonLoadingWidget(
            size: 50.0,
            color: AppColors.primary,
          ),
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
              backgroundColor: AppColors.backgroundLight,
              scrolledUnderElevation: 0,
              elevation: 0,
              automaticallyImplyLeading: false,
              shape: Border(
                bottom: BorderSide(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
              leading: Padding(
                padding: EdgeInsets.only(left: 16.w),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20.sp, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context)),
              ),
              title: Text(
                languageService.tr('setting_title'),
                style: AppTextStyles.screenTitle,
              ),
              centerTitle: true,
            );

    final body = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12.h),

          // Profile Card Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: _buildProfileCard(authController),
          ),

          SizedBox(height: 12.h),

          // Verification Card (if not completed)
          GetBuilder<MoreController>(
            builder: (controller) {
              final model = controller.dashboardModel.value;
              final stage = model?.data?.stageCompletion;
              final completion = _calculateCompletion(stage);
              return completion == 100
                  ? const SizedBox.shrink()
                  : Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: VerifyAccountCard(
                      title: languageService.tr('verify_your_account'),
                      subTitle: languageService.tr(
                        'complete_verification_to_unlock',
                      ),
                      percentage: '',
                    ),
                  );
            },
          ),

          SizedBox(height: 20.h),

          // Financial Quick Actions
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: languageService.tr('general_financial')),
                SizedBox(height: 12.h),
                _buildFinancialActions(),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Finance & Trading Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: languageService.tr('general_tradind_settings')),
                SizedBox(height: 12.h),
                _buildFinanceSection(),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Security Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: languageService.tr('general_account_security')),
                SizedBox(height: 12.h),
                _buildSecuritySection(),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Danger Zone
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Account'),
                SizedBox(height: 12.h),
                _buildDangerSection(authController),
              ],
            ),
          ),

          SizedBox(height: 32.h),

          // App Version
          Center(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final version = snapshot.data!.version;
                return Text(
                  '${languageService.tr('version_label')} $version',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textGrey.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 100.h + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );

    if (isVantage) {
      return VantageMoreLayout(
        backgroundColor: AppColors.backgroundLight,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: appBar,
      body: body,
    );
  }

  Widget _buildProfileCard(AuthController authController) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
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
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.whiteColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 14.w),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 17.sp,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GetBuilder<MoreController>(
                      builder: (controller) {
                        final model = controller.dashboardModel.value;
                        final stage = model?.data?.stageCompletion;
                        final completion = _calculateCompletion(stage);
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: completion == 100
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '$completion%',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: completion == 100
                                  ? AppColors.primary
                                  : Colors.orange,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  authController.userEmail ?? '',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 13.sp,
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
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: IconButton(
              icon: SvgPicture.asset(
                'assets/svg/edit_profile.svg',
                height: 20.h,
                width: 20.w,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: 'assets/svg/more/deposit.svg',
                label: languageService.tr('general_deposit'),
                color: const Color(0xFF4CAF50),
                onTap: () => Get.to(
                  () => PaymentMethodsScreen(accountNumber: ''),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                icon: 'assets/svg/more/withdrawal.svg',
                label: languageService.tr('general_withdraw'),
                color: const Color(0xFFFF9800),
                onTap: () => Get.toNamed(AppPages.WITHDRAWAL),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: 'assets/svg/more/internal-transfer.svg',
                label: languageService.tr('general_transfer'),
                color: const Color(0xFF2196F3),
                onTap: () => Get.toNamed(AppPages.INTERNAL_TRANSFER),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                icon: 'assets/svg/more/transaction_history.svg',
                label: languageService.tr('general_history'),
                color: const Color(0xFF9C27B0),
                onTap: () => Get.toNamed(AppPages.TRANSACTION_HISTORY),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    height: 20.h,
                    width: 20.w,
                    color: color,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: AppColors.textGrey.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceSection() {
    return Obx(() {
      final modules = Get.find<EnabledModulesService>().modules.value;
      final showCopyTrading = modules?.copytrading ?? false;
      final showPmam = modules?.pmam ?? appConfig.isFeatureEnabled(FeatureKeys.pmam);

      final items = <Widget>[
        _buildMenuItem(
          icon: 'assets/svg/more/wallet.svg',
          label: languageService.tr('general_finance'),
          color: const Color(0xFF00BFA5),
          onTap: () async {
            await Get.toNamed(AppPages.FINANCE);
            if (mounted) _refreshDataIfNeeded();
          },
        ),
        _buildMenuItem(
          icon: 'assets/svg/more/ib_dashboard/overview.svg',
          label: languageService.tr('more_dashboard'),
          color: AppColors.primary,
          onTap: () async => await _handleSwitchToIB(),
        ),
      ];

      if (showCopyTrading) {
        items.add(
          _buildMenuItem(
            icon: 'assets/svg/more/copy.svg',
            label: languageService.tr('more_copy_trading'),
            color: const Color(0xFF1E88E5),
            onTap: () => Get.toNamed(AppPages.COPY_TRADING_HUB),
          ),
        );
      }
      if (showPmam) {
        items.add(
          _buildMenuItem(
            icon: 'assets/svg/more/demo-account.svg',
            label: 'PAMM',
            color: const Color(0xFF29B6F6),
            onTap: () => Get.toNamed(AppPages.PMAM_MAIN),
          ),
        );
      }

      return _buildCardGroup(items);
    });
  }

  Widget _buildSecuritySection() {
    return _buildCardGroup([
      _buildMenuItem(
        icon: 'assets/svg/more/change_password.svg',
        label: languageService.tr('change_password'),
        color: const Color(0xFFEF5350),
        onTap: () => Get.toNamed(AppPages.CHANGE_PASSWORD),
      ),
      _buildMenuItem(
        icon: 'assets/svg/more/two_factor_auth.svg',
        label: languageService.tr('two_factor_authentication'),
        color: const Color(0xFF7E57C2),
        onTap: () => Get.toNamed(AppPages.TWO_FACTOR_AUTH),
      ),
      _buildToggleItem(
        icon: 'assets/svg/more/one-click.svg',
        label: 'One Click Trading',
        color: const Color(0xFF26A69A),
        value: _oneClickEnabled,
        onTap: _toggleOneClickTrading,
      ),
      _buildToggleItem(
        icon: 'assets/svg/more/biometric.svg',
        label: languageService.tr('biometric_login_toggle'),
        color: const Color(0xFF5C6BC0),
        value: _biometricEnabled,
        onTap: _toggleBiometric,
      ),
    ]);
  }

  Widget _buildDangerSection(AuthController authController) {
    return _buildCardGroup([
      _buildMenuItem(
        icon: 'assets/svg/more/setting/profile-kyc.svg',
        label: languageService.tr('delete_account'),
        color: const Color(0xFFEC407A),
        onTap: () => _showDeleteAccountDialog(authController),
      ),
      _buildMenuItem(
        icon: 'assets/svg/more/logout.svg',
        label: languageService.tr('more_logout'),
        color: AppColors.red,
        showArrow: false,
        onTap: () => _showLogoutDialog(authController),
      ),
    ]);
  }

  Widget _buildMenuItem({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    height: 18.h,
                    width: 18.w,
                    color: color,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (showArrow)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22.sp,
                  color: AppColors.textGrey.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String icon,
    required String label,
    required Color color,
    required bool value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    height: 18.h,
                    width: 18.w,
                    color: color,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildModernSwitch(value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSwitch(bool value) {
    return GestureDetector(
      onTap: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48.w,
        height: 28.h,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.all(3.w),
            width: 22.w,
            height: 22.w,
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
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
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  void _showLogoutDialog(AuthController authController) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.whiteColor,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 32.sp,
                  color: AppColors.red,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                languageService.tr('logout_confirm_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _buildDialogButton(
                        label: languageService.tr('navigation_yes'),
                        isPrimary: true,
                        onTap: authController.isLoading
                            ? null
                            : () async => await authController.logout(),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildDialogButton(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.whiteColor,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFEC407A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  size: 32.sp,
                  color: const Color(0xFFEC407A),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                languageService.tr('delete_account_confirm_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 20.h),
              Obx(
                () => TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: languageService.tr('delete_account_password_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: _isPasswordEmpty.value ? Colors.red : AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: _isPasswordEmpty.value ? Colors.red : AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _buildDialogButton(
                        label: languageService.tr('navigation_yes'),
                        isPrimary: true,
                        isDanger: true,
                        onTap: authController.isLoading
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
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildDialogButton(
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

  Widget _buildDialogButton({
    required String label,
    required bool isPrimary,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          height: 48.h,
          decoration: BoxDecoration(
            color: isPrimary
                ? (isDanger ? const Color(0xFFEC407A) : AppColors.primary)
                : AppColors.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12.r),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? AppColors.whiteColor : AppColors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textGrey,
        letterSpacing: 1.2,
      ),
    );
  }
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
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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