import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';

import 'iquote_assets_layout.dart';
import '../dashboard_screen.dart';
import 'dart:convert';

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
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:crm_app/widgets/theme_bottom_sheet.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/services/enabled_modules_service.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> with WidgetsBindingObserver {
  final languageService = Get.find<LanguageService>();
  late final MoreController moreController;
  bool _hasLoadedInitialData = false;
  bool _isTenaxBrokerFlowEnabled = false;
  DateTime? _lastRefreshTime;
  List<Map<String, dynamic>> _tenaxProfiles = <Map<String, dynamic>>[];
  String? _currentTenaxProfileKey;
  String? _currentBrokerName;

  @override
  void initState() {
    super.initState();
    moreController = Get.put(MoreController());
    WidgetsBinding.instance.addObserver(this);
    _hasLoadedInitialData = false;
    moreController.loadMoreScreenData();
    _loadTenaxProfiles();
    // Ensure the optional-module flags (PAMM, Copy Trading, Scratch Card,
    // Trade Win) are reloaded the first time the More tab is opened — they
    // are otherwise only refreshed on login / app-resume.
    if (Get.isRegistered<EnabledModulesService>()) {
      Get.find<EnabledModulesService>().fetchEnabledModules(force: true);
    }
    _hasLoadedInitialData = true;
    _lastRefreshTime = DateTime.now();
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
      _loadTenaxProfiles();
      if (Get.isRegistered<EnabledModulesService>()) {
        Get.find<EnabledModulesService>().fetchEnabledModules(force: true);
      }
    }
  }

  Future<void> _loadTenaxProfiles() async {
    final isEnabled = await _isTenaxBrokerFeatureEnabled();
    if (!mounted) return;
    if (!isEnabled) {
      setState(() {
        _isTenaxBrokerFlowEnabled = false;
        _tenaxProfiles = <Map<String, dynamic>>[];
        _currentTenaxProfileKey = null;
        _currentBrokerName = null;
      });
      return;
    }

    await _seedCurrentProfileIfMissing();
    final profiles = await SecureStorageService.getTenaxUserBrokerProfiles();
    final current = await SecureStorageService.getTenaxCurrentProfileKey();
    if (!mounted) return;

    String? brokerName;
    final brokerData = await SecureStorageService.getTenaxBrokerSelection();
    if (brokerData != null) {
      final selectedName =
          (brokerData['selected_name'] ?? '').toString().trim();
      if (selectedName.isNotEmpty) {
        brokerName = selectedName;
      } else {
        final selectedSlug =
            (brokerData['selected_slug'] ??
                    brokerData['slug'] ??
                    brokerData['broker_list_item']?['slug'] ??
                    '')
                .toString();
        brokerName = selectedSlug.isNotEmpty ? selectedSlug : null;
      }
    }
    brokerName ??= FlavorConfig.instance.appName;

    setState(() {
      _isTenaxBrokerFlowEnabled = true;
      _tenaxProfiles = profiles;
      _currentTenaxProfileKey = current;
      _currentBrokerName = brokerName;
    });
  }

  Future<bool> _isTenaxBrokerFeatureEnabled() async {
    if (!FlavorConfig.isMultiBrokerEnabled) return false;
    return await SecureStorageService.getTenaxBrokerSelectionFlag();
  }

  Future<void> _seedCurrentProfileIfMissing() async {
    final authController = Get.find<AuthController>();
    final String rawEmail =
        authController.userEmail?.isNotEmpty == true
            ? authController.userEmail!
            : (authController.profileData?.data.user.email ?? '');
    final String rawName =
        authController.userFullName?.isNotEmpty == true
            ? authController.userFullName!
            : (authController.profileData?.data.user.fullName ?? '');

    final email = rawEmail.trim().toLowerCase();
    final name = rawName.trim();
    final brokerData = await SecureStorageService.getTenaxBrokerSelection();
    if (email.isEmpty || brokerData == null) return;

    final brokerSlug =
        (brokerData['selected_slug'] ??
                brokerData['slug'] ??
                brokerData['broker_list_item']?['slug'] ??
                '')
            .toString();
    if (brokerSlug.isEmpty) return;
    final profileKey = '$email|$brokerSlug';
    final existingProfiles =
        await SecureStorageService.getTenaxUserBrokerProfiles();
    final exists = existingProfiles.any(
      (item) => (item['profile_key'] ?? '').toString() == profileKey,
    );
    if (exists) {
      await SecureStorageService.setTenaxCurrentProfileKey(profileKey);
      return;
    }

    final authToken = await SecureStorageService.getAuthToken();
    final wsToken = await SecureStorageService.getWebsocketToken();
    final loginData = await SecureStorageService.getCompleteLoginData();
    final loginUser =
        loginData != null && loginData['user'] is Map<String, dynamic>
            ? loginData['user'] as Map<String, dynamic>
            : null;
    final loginEmail =
        (loginUser?['email'] ?? loginUser?['user_email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (authToken == null || authToken.isEmpty) return;
    if (loginEmail.isNotEmpty && loginEmail != email) return;

    final profile = <String, dynamic>{
      'profile_key': profileKey,
      'user_email': email,
      'user_name':
          name.isNotEmpty
              ? name
              : (loginUser?['full_name'] ??
                      loginUser?['fullName'] ??
                      loginUser?['name'] ??
                      '')
                  .toString(),
      'broker_name':
          (brokerData['selected_name'] ?? FlavorConfig.instance.appName)
              .toString(),
      'broker_slug': brokerSlug,
      'broker_logo_local_path': brokerData['selected_logo_local_path'] ?? '',
      'broker_logo_url': brokerData['selected_logo_url'] ?? '',
      'broker_data': brokerData,
      'login_data': {
        'token': authToken,
        'websocket_token': wsToken ?? '',
        'user': loginData?['user'],
        'is_logged_in': true,
      },
      'saved_at': DateTime.now().toIso8601String(),
    };
    await SecureStorageService.upsertTenaxUserBrokerProfile(profile);
  }

  Future<void> _onTapAccountDropdown() async {
    await _loadTenaxProfiles();
    if (!mounted) return;
    _showSwitchAccountBottomSheet();
  }

  void _showSwitchAccountBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0.95, end: 1),
            builder:
                (context, value, child) =>
                    Transform.scale(scale: value, child: child),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
              padding: EdgeInsetsDirectional.fromSTEB(18.w, 16.h, 18.w, 18.h),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          languageService.tr('switch_account_title'),
                          style: AppTextStyles.heading,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.border,
                          ),
                          child: Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20.h, color: AppColors.border),
                  if (_tenaxProfiles.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: Text(
                        languageService.tr('switch_account_no_accounts'),
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textGrey,
                          fontSize: 14.sp,
                        ),
                      ),
                    )
                  else
                    ..._tenaxProfiles.map(_buildAccountTile),
                  SizedBox(height: 12.h),
                  SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddAccountBottomSheet();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          languageService.tr('switch_account_add_new_broker'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.whiteColor,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildAccountTile(Map<String, dynamic> profile) {
    final isSelected =
        (profile['profile_key'] ?? '').toString() == _currentTenaxProfileKey;
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 120));
        await _selectTenaxProfile(profile);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Icon(Icons.person, size: 18.r, color: AppColors.primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (profile['user_name'] ?? '').toString(),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    (profile['user_email'] ?? '').toString(),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Broker: ${(profile['broker_name'] ?? '').toString()}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textGrey.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : AppColors.textGrey,
              ),
              child:
                  isSelected
                      ? Icon(
                        Icons.check,
                        color: AppColors.whiteColor,
                        size: 14.sp,
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTenaxProfile(Map<String, dynamic> profile) async {
    if (!await _isTenaxBrokerFeatureEnabled()) return;
    final brokerData =
        profile['broker_data'] is Map<String, dynamic>
            ? profile['broker_data'] as Map<String, dynamic>
            : null;
    if (brokerData == null) return;

    await SecureStorageService.saveTenaxBrokerSelection(brokerData);
    await SecureStorageService.setTenaxCurrentProfileKey(
      (profile['profile_key'] ?? '').toString(),
    );

    // ── Apply FlavorConfig (URL, colors, logo) ───────────────────────────
    final runtimeConfig =
        brokerData['broker_runtime_config'] is Map<String, dynamic>
            ? brokerData['broker_runtime_config'] as Map<String, dynamic>
            : brokerData;
    final selectedName = (brokerData['selected_name'] ?? '').toString();
    final selectedLogo =
        (brokerData['selected_logo_local_path'] ??
                brokerData['selected_logo_url'] ??
                '')
            .toString();

    // Merge runtime overrides onto the persisted broker payload so the
    // applyTenaxBrokerRuntimeConfig helper can pick colors + logo paths
    // from a single shape.
    final merged = Map<String, dynamic>.from(brokerData);
    if (runtimeConfig.isNotEmpty) {
      merged.addAll(runtimeConfig);
    }
    if (selectedName.isNotEmpty) merged['appName'] = selectedName;
    if (selectedLogo.isNotEmpty) merged['logoSvgPath'] = selectedLogo;
    if (selectedLogo.isNotEmpty) merged['remoteLogoUrl'] = selectedLogo;

    FlavorConfig.applyTenaxBrokerRuntimeConfig(merged);

    // ── Restore auth token from saved login_data ─────────────────────────
    final loginData = profile['login_data'];
    if (loginData is Map) {
      final token = (loginData['token'] ?? '').toString();
      final wsToken = (loginData['websocket_token'] ?? '').toString();
      final userData = loginData['user'];
      if (token.isNotEmpty) {
        await SecureStorageService.saveAuthToken(token);
        await SecureStorageService.saveWebsocketToken(wsToken);
        if (userData is Map<String, dynamic>) {
          await SecureStorageService.saveUserData(
            jsonEncode({
              'token': token,
              'websocket_token': wsToken,
              'user': userData,
              'is_logged_in': true,
            }),
          );
        }
        await SecureStorageService.saveLoginStatus(true);
        // Reload user data in AuthController
        try {
          await Get.find<AuthController>().getUserData();
        } catch (_) {}
      }
    }

    // ── Global Branding & Data Refresh ──────────────────────────────────
    // 1. Increment branding index to trigger Immediate UI theme/color refresh
    Get.find<LanguageService>().brandingUpdateIndex.value++;

    // 2. Reload saved profile list, then redirect like a fresh logged-in user flow.
    await _loadTenaxProfiles();
    Get.offAllNamed(AppPages.TRADING, arguments: 3);
  }

  void _showAddAccountBottomSheet() {
    final selectedBrokerName = FlavorConfig.instance.appName;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0.96, end: 1),
            builder:
                (context, value, child) => Transform.translate(
                  offset: Offset(0, (1 - value) * 20),
                  child: child,
                ),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
              padding: EdgeInsetsDirectional.fromSTEB(18.w, 16.h, 18.w, 18.h),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageService.tr('more_screen_add_account'),
                    style: AppTextStyles.heading,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    TranslationUtils.trArgs('more_current_broker', {
                      'broker': selectedBrokerName,
                    }),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGrey,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Get.toNamed(
                            AppPages.TENAX_BROKER_SELECTION,
                            arguments: {
                              'nextRoute': AppPages.LOGIN,
                              'allowBack': true,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          languageService.tr('add_account_choose_broker'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.whiteColor,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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
      CustomToastService.showError(
        message:
            '${languageService.tr('more_screen_error_checking_ib_status')}: $e',
      );
    }
  }

  int _calculateCompletion(StageCompletion? stage) {
    //print('_calculateCompletion - stage: $stage');
    if (stage == null) {
      //print('_calculateCompletion - stage is null, returning 0');
      return 0;
    }

    //print('_calculateCompletion - mobileVerified: ${stage.mobileVerified}');
    //print('_calculateCompletion - emailVerified: ${stage.emailVerified}');
    //print('_calculateCompletion - personalDetails: ${stage.personalDetails}');
    //print('_calculateCompletion - identityVerified: ${stage.identityVerified}');
    //print('_calculateCompletion - addressProofVerified: ${stage.addressProofVerified}',);

    int completion = 0;

    // Step 1: Check mobile verification - if mobileVerified is not null (has valid DateTime)
    if (stage.mobileVerified != null) {
      completion += 20;
      // //print('Step 1 - Mobile Verified: +20% = $completion%');
    } else {
      // //print('Step 1 - Mobile Not Verified: 0%');
    }

    // Step 2: Check email verification - if emailVerified is not null (has valid DateTime)
    if (stage.emailVerified != null) {
      completion += 20;
      // print('Step 2 - Email Verified: +20% = $completion%');
    } else {
      // print('Step 2 - Email Not Verified: $completion%');
    }

    // Step 3: Check personal details - if personalDetails is true
    if (stage.personalDetails == true) {
      completion += 20;
      // print('Step 3 - Personal Details: +20% = $completion%');
    } else {
      // print('Step 3 - Personal Details Not Complete: $completion%');
    }

    // Step 4: Check identity verification - if identityVerified is true
    if (stage.identityVerified == true) {
      completion += 20;
      // print('Step 4 - Identity Verified: +20% = $completion%');
    } else {
      // print('Step 4 - Identity Not Verified: $completion%');
    }

    // Step 5: Check address proof verification - if addressProofVerified is true
    if (stage.addressProofVerified == true) {
      completion += 20;
      // print('Step 5 - Address Proof Verified: +20% = $completion%');
    } else {
      // print('Step 5 - Address Proof Not Verified: $completion%');
    }

    // print('FINAL COMPLETION: $completion%');
    return completion;
  }

  @override
  Widget build(BuildContext context) {
    if (FlavorConfig.usesIquoteUi()) {
      return const IquoteAssetsLayout();
    }

    final AuthController authController = Get.find<AuthController>();
    final languageService = Get.find<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          languageService.tr('dashboard_title'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              size: 24.sp,
              color: AppColors.primary,
            ),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            onPressed: () => Get.toNamed(AppPages.NOTIFICATIONS),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            16.w,
            8.h,
            16.w,
            40.h + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section Card
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.72),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(3.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.whiteColor.withValues(alpha: 0.18),
                        border: Border.all(
                          color: AppColors.whiteColor.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24.r,
                        backgroundColor: AppColors.whiteColor.withValues(
                          alpha: 0.22,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 28.r,
                          color: AppColors.whiteColor,
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
                              Obx(() {
                                final name =
                                    authController.userFullName?.isNotEmpty ==
                                            true
                                        ? authController.userFullName!
                                        : (authController
                                                .profileData
                                                ?.data
                                                .user
                                                .fullName ??
                                            '');
                                return Text(
                                  name,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18.sp,
                                    color: AppColors.whiteColor,
                                  ),
                                );
                              }),
                              SizedBox(width: 6.w),
                              GetBuilder<MoreController>(
                                builder: (controller) {
                                  final model = controller.dashboardModel.value;
                                  final stage = model?.data?.stageCompletion;
                                  final completion = _calculateCompletion(
                                    stage,
                                  );
                                  return Icon(
                                    (completion == 100)
                                        ? Icons.verified
                                        : Icons.verified_outlined,
                                    color:
                                        (completion == 100)
                                            ? AppColors.whiteColor
                                            : AppColors.whiteColor.withValues(
                                              alpha: 0.45,
                                            ),
                                    size: 18.r,
                                  );
                                },
                              ),
                              const Spacer(),
                              Obx(() {
                                final model =
                                    moreController.dashboardModel.value;
                                final stage = model?.data?.stageCompletion;
                                final isProfileVerified =
                                    (stage?.emailVerified != null) &&
                                    (stage?.mobileVerified != null) &&
                                    (stage?.personalDetails == true);
                                return GestureDetector(
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
                                  child: Container(
                                    padding: EdgeInsets.all(7.r),
                                    decoration: BoxDecoration(
                                      color: AppColors.whiteColor.withValues(
                                        alpha: 0.18,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child:
                                        isProfileVerified
                                            ? Icon(
                                              Icons.remove_red_eye_outlined,
                                              size: 18.sp,
                                              color: AppColors.whiteColor,
                                            )
                                            : SvgPicture.asset(
                                              'assets/svg/edit_profile.svg',
                                              height: 18.h,
                                              width: 18.w,
                                              color: AppColors.whiteColor,
                                            ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Obx(() {
                            final email =
                                authController.userEmail?.isNotEmpty == true
                                    ? authController.userEmail!
                                    : (authController
                                            .profileData
                                            ?.data
                                            .user
                                            .email ??
                                        '');
                            return Text(
                              email,
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.whiteColor.withValues(
                                  alpha: 0.85,
                                ),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                          }),
                          if (_isTenaxBrokerFlowEnabled &&
                              (_currentBrokerName ?? '').isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  size: 13.sp,
                                  color: AppColors.whiteColor.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    _currentBrokerName!,
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: AppColors.whiteColor.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isTenaxBrokerFlowEnabled)
                      InkWell(
                        onTap: _onTapAccountDropdown,
                        borderRadius: BorderRadius.circular(20.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.whiteColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.whiteColor,
                                size: 20.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 8.h),
              GetBuilder<MoreController>(
                builder: (controller) {
                  final model = controller.dashboardModel.value;
                  final stage = model?.data?.stageCompletion;
                  final completion = _calculateCompletion(stage);
                  return completion == 100
                      ? const SizedBox.shrink()
                      : VerifyAccountCard(
                        title: languageService.tr('verify_your_account'),
                        subTitle: languageService.tr(
                          'complete_verification_to_unlock',
                        ),
                        percentage: '',
                      );
                },
              ),
              SizedBox(height: 8.h),
              const _CreateAccountActionCard(),
              SizedBox(height: 8.h),

              // Quick Actions Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _QuickActionButton(
                    icon: 'deposit',
                    label: languageService.tr('general_deposit'),
                    color: AppColors.primary,
                    onTap:
                        () => Get.to(
                          () => PaymentMethodsScreen(accountNumber: ''),
                        ),
                  ),
                  _QuickActionButton(
                    icon: 'withdrawal',
                    label: languageService.tr('general_withdraw'),
                    color: AppColors.primary,
                    onTap: () => Get.toNamed(AppPages.WITHDRAWAL),
                  ),
                  _QuickActionButton(
                    icon: 'internal-transfer',
                    label: languageService.tr('general_transfer'),
                    color: AppColors.primary,
                    onTap: () => Get.toNamed(AppPages.INTERNAL_TRANSFER),
                  ),
                  _QuickActionButton(
                    icon: 'clock',
                    label: languageService.tr('general_history'),
                    color: AppColors.primary,
                    onTap: () => Get.toNamed(AppPages.TRANSACTION_HISTORY),
                  ),
                ],
              ),

// Verification Card (if not completed)
              SizedBox(height: 16.h),

              // Services Section
              _SectionHeader(
                title: languageService.tr('general_financial'),
              ),
Obx(() {
                final modulesService = Get.find<EnabledModulesService>();
                final modules = modulesService.modules.value;
                final showCopyTrading = modules?.copytrading ?? false;
                final showPmam = modules?.pmam ?? false;
                final showPromotional = modulesService.isPromotionalMenuVisible;

                final items = <Widget>[];
                if (FlavorConfig.usesIquoteUi()) {
                  items.add(
                    _ServiceTile(
                      icon: 'wallet',
                      label: languageService.tr('dashboard_title'),
                      onTap: () => Get.to(() => DashboardScreen()),
                    ),
                  );
                }
                items.addAll([
                  _ServiceTile(
                    icon: 'dollar-circle',
                    label: languageService.tr('general_finance'),
                    onTap: () async {
                      await Get.toNamed(AppPages.FINANCE);
                      if (mounted) _refreshDataIfNeeded();
                    },
                  ),
                  _ServiceTile(
                    icon: 'dashboard',
                    label: languageService.tr('more_dashboard'),
                    onTap: () async => await _handleSwitchToIB(),
                  ),
                ]);

                if (showPromotional) {
                  items.insert(
                    1,
                    _ServiceTile(
                      icon: 'promotional',
                      label: languageService.tr('general_promotional'),
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
                    _ServiceTile(
                      icon: 'copy-trading',
                      label: languageService.tr('more_copy_trading'),
                      onTap: () => Get.toNamed(AppPages.COPY_TRADING_MAIN),
                    ),
                  );
                }
                if (showPmam) {
                  items.add(
                    _ServiceTile(
                      icon: 'dashboard',
                      label: 'PAMM',
                      onTap: () => Get.toNamed(AppPages.PMAM_MAIN),
                    ),
                  );
                }
                // items.add(
                //   _ServiceTile(
                //     icon: 'notification',
                //     iconData: Icons.notifications_none_outlined,
                //     label: languageService.trf(
                //       'general_notifications',
                //       'Notifications',
                //     ),
                //     onTap: () => Get.toNamed(AppPages.NOTIFICATIONS),
                //   ),
                // );

                items.add(
                  _ServiceTile(
                    icon: 'democontest-icon',
                    label: languageService.tr('more_demo_contest'),
                    onTap: () => Get.toNamed(AppPages.DEMO_CONTEST),
                  ),
                );

                return Wrap(
                  spacing: 10.w,
                  runSpacing: 10.w,
                  children: items,
                );
              }),

              SizedBox(height: 14.h),

              // Account & Security Section
              _SectionHeader(
                title: languageService.tr('general_tradind_settings'),
              ),
              _CardGroup(children: [const _OneClickTradingMenuItem()]),

              SizedBox(height: 14.h),

              // App Settings Section
              _SectionHeader(
                title: 'App Settings',
              ),
              _CardGroup(
                children: [
                  _MenuItem(
                    icon: 'settings',
                    label: 'App Settings',
                    onTap: () => Get.toNamed(AppPages.SETTING),
                    iconData: Icons.settings_outlined,
                  ),
                ],
              ),

              SizedBox(height: 14.h),

              // Others Section
              _SectionHeader(
                title: languageService.tr('general_account_security'),
              ),
              _CardGroup(
                children: [
                  _MenuItem(
                    icon: 'support',
                    label: languageService.tr('ticket_title'),
                    onTap: () => Get.toNamed(AppPages.TICKET_LIST),
                  ),
                  const _BiometricLoginMenuItem(),
                  _MenuItem(
                    icon: 'two_factor_auth',
                    label: languageService.tr('two_factor_authentication'),
                    onTap: () => Get.toNamed(AppPages.TWO_FACTOR_AUTH),
                  ),
                  _MenuItem(
                    icon: 'personal_info',
                    label: languageService.tr('delete_account'),
                    onTap: () => _showDeleteAccountDialog(authController),
                  ),
                  _MenuItem(
                    icon: 'logout',
                    label: languageService.tr('more_logout'),
                    onTap: () => _showLogoutDialog(authController),
                    color: AppColors.error,
                    showArrow: false,
                  ),
                ],
              ),

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
                      style: AppTextStyles.bodyText.copyWith(
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
      ),
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
              // BrandLogo(
              //   source: logoSource,
              //   height: 60.h,
              //   width: 60.w,
              //   color:
              //       FlavorConfig.isONSA() && !FlavorConfig.hasRemoteLogo
              //           ? AppColors.primary
              //           : null,
              // ),
              SizedBox(height: 24.h),
              Text(
                languageService.tr('logout_confirm_message'),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
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
                            style: AppTextStyles.bodyText.copyWith(
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
                          style: AppTextStyles.bodyText.copyWith(
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
              // BrandLogo(
              //   source: FlavorConfig.effectiveLogo,
              //   height: 80.h,
              //   width: 80.w,
              //   color:
              //       FlavorConfig.isONSA && !FlavorConfig.hasRemoteLogo
              //           ? AppColors.primary
              //           : null,
              // ),
              // SizedBox(height: 24.h),
              Text(
                languageService.tr('delete_account_confirm_message'),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
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
                                  ? AppColors.error
                                  : AppColors.textGrey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _isPasswordEmpty.value
                                  ? AppColors.error
                                  : AppColors.textGrey,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              _isPasswordEmpty.value
                                  ? AppColors.error
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
                            style: AppTextStyles.bodyText.copyWith(
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
                          style: AppTextStyles.bodyText.copyWith(
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

class _CreateAccountActionCard extends StatelessWidget {
  const _CreateAccountActionCard();

  void _openRealAccount() {
    Get.back(closeOverlays: true);
    Get.toNamed(Routes.CHOOSE_ACCOUNT);
  }

  void _openDemoAccount() {
    Get.back(closeOverlays: true);
    Get.toNamed(Routes.CHOOSE_ACCOUNT, arguments: {'isDemo': true});
  }

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageService>();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _AccountActionButton(
              icon: 'wallet',
              iconData: Icons.trending_up_rounded,
              label: lang.tr('create_account_open_real_account'),
              color: AppColors.primary,
              filled: true,
              onTap: _openRealAccount,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _AccountActionButton(
              icon: 'demo-account',
              iconData: Icons.school_outlined,
              label: lang.tr('create_account_open_demo_account'),
              color: AppColors.primary,
              onTap: _openDemoAccount,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountActionButton extends StatelessWidget {
  final String icon;
  final IconData? iconData;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _AccountActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconData,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: filled ? color : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: filled ? color : color.withValues(alpha: 0.30),
            width: filled ? 0 : 1.4,
          ),
          boxShadow:
              filled
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color:
                    filled
                        ? AppColors.whiteColor.withValues(alpha: 0.20)
                        : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child:
                    iconData != null
                        ? Icon(
                          iconData,
                          size: 18.sp,
                          color: filled ? AppColors.whiteColor : color,
                        )
                        : SvgPicture.asset(
                          'assets/svg/more/$icon.svg',
                          width: 17.w,
                          height: 17.w,
                          color: filled ? AppColors.whiteColor : color,
                        ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: filled ? AppColors.whiteColor : AppColors.textPrimary,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String icon;
  final IconData? iconData;
  final String label;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    final double tileWidth = (1.sw - 32.w - 10.w) / 2;
    return SizedBox(
      width: tileWidth,
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Center(
                    child:
                        iconData != null
                            ? Icon(
                              iconData,
                              size: 18.sp,
                              color: AppColors.primary,
                            )
                            : SvgPicture.asset(
                              'assets/svg/more/$icon.svg',
                              height: 16.h,
                              width: 16.w,
                              color: AppColors.primary,
                            ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.21,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(15.r),
                border: Border.all(color: color.withValues(alpha: 0.16)),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/svg/more/$icon.svg',
                  width: 20.w,
                  height: 20.w,
                  color: color,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
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
      padding: EdgeInsetsDirectional.only(start: 4.w, bottom: 7.h, top: 2.h),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 12.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title.toUpperCase(),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  final List<Widget> children;
  const _CardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
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
                      color: AppColors.icongrey.withValues(alpha: 0.14),
                    ),
                  ),
                ],
              );
            }).toList(),
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
  final IconData? iconData;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showArrow = true,
    this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (color ?? AppColors.primary).withValues(alpha: 0.14),
                      (color ?? AppColors.primary).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Center(
                  child:
                      iconData != null
                          ? Icon(
                            iconData,
                            size: 18.sp,
                            color: color ?? AppColors.primary,
                          )
                          : SvgPicture.asset(
                            'assets/svg/more/$icon.svg',
                            height: 16.h,
                            width: 16.w,
                            color: color ?? AppColors.primary,
                          ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w500,
                    color: color ?? AppColors.textPrimary,
                  ),
                ),
              ),
              if (showArrow)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14.sp,
                  color: AppColors.icongrey.withValues(alpha: 0.55),
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
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.touch_app_rounded,
                size: 17.sp,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              TranslationUtils.tr('more_screen_one_click_trading'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w500,
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
                    _isEnabled
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
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
                        color: AppColors.border.withValues(alpha: 0.1),
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
  bool _isEnabled = false;
  bool _isBusy = false;
  final _languageService = Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await SecureStorageService.getBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _isEnabled = enabled;
    });
  }

  Future<void> _showNotEnrolledDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
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
                  _languageService.tr('biometric_not_enrolled_title'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _languageService.tr('biometric_not_enrolled_message'),
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
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _languageService.tr('common_close'),
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
                          Navigator.of(ctx).pop();
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
                            _languageService.tr('biometric_open_settings'),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.isDarkMode ? AppColors.textPrimaryLight : AppColors.pureWhite,
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
        );
      },
    );
  }

  Future<void> _toggle() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      if (_isEnabled) {
        await SecureStorageService.setBiometricEnabled(false);
        try {
          if (Get.isRegistered<AppLockService>()) {
            await Get.find<AppLockService>().clearLock();
          }
        } catch (_) {}
        if (!mounted) return;
        setState(() => _isEnabled = false);
        return;
      }

      final bio = BiometricService.instance;
      final supported = await bio.isDeviceSupported();
      final enrolled = await bio.isEnrolled();
      if (!supported || !enrolled) {
        await SecureStorageService.setBiometricEnabled(false);
        if (mounted) {
          await _showNotEnrolledDialog();
          setState(() => _isEnabled = false);
        }
        return;
      }

      final ok = await bio.authenticate(
        reason: _languageService.tr('biometric_enable_reason'),
      );
      if (!ok) {
        await SecureStorageService.setBiometricEnabled(false);
        if (!mounted) return;
        setState(() => _isEnabled = false);
        return;
      }

      try {
        if (Get.isRegistered<AppLockService>()) {
          Get.find<AppLockService>().markJustAuthenticated();
        }
      } catch (_) {}

      await SecureStorageService.setBiometricEnabled(true);
      if (!mounted) return;
      setState(() => _isEnabled = true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.fingerprint_rounded,
                size: 17.sp,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _languageService.tr('biometric_login_toggle'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          AbsorbPointer(
            absorbing: _isBusy,
            child: GestureDetector(
              onTap: _toggle,
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
                      _isEnabled
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
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
                          color: AppColors.border.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
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

class _ThemeMenuItem extends StatelessWidget {
  const _ThemeMenuItem();

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showThemeBottomSheet(context),
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.palette_outlined,
                    size: 17.sp,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  languageService.tr('settings_theme'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: AppColors.icongrey.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
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
    // print('_calculateCompletion - stage: $stage');
    if (stage == null) {
      // print('_calculateCompletion - stage is null, returning 0');
      return 0;
    }

    // print('_calculateCompletion - mobileVerified: ${stage.mobileVerified}');
    // print('_calculateCompletion - emailVerified: ${stage.emailVerified}');
    // print('_calculateCompletion - personalDetails: ${stage.personalDetails}');
    // print('_calculateCompletion - identityVerified: ${stage.identityVerified}');
    // print('_calculateCompletion - addressProofVerified: ${stage.addressProofVerified}',);

    int completion = 0;

    // Step 1: Check mobile verification - if mobileVerified is not null (has valid DateTime)
    if (stage.mobileVerified != null) {
      completion += 20;
      // print('Step 1 - Mobile Verified: +20% = $completion%');
    } else {
      // print('Step 1 - Mobile Not Verified: 0%');
    }

    // Step 2: Check email verification - if emailVerified is not null (has valid DateTime)
    if (stage.emailVerified != null) {
      completion += 20;
      //print('Step 2 - Email Verified: +20% = $completion%');
    } else {
      //print('Step 2 - Email Not Verified: $completion%');
    }

    // Step 3: Check personal details - if personalDetails is true
    if (stage.personalDetails == true) {
      completion += 20;
      //print('Step 3 - Personal Details: +20% = $completion%');
    } else {
      //print('Step 3 - Personal Details Not Complete: $completion%');
    }

    // Step 4: Check identity verification - if identityVerified is true
    if (stage.identityVerified == true) {
      completion += 20;
      //print('Step 4 - Identity Verified: +20% = $completion%');
    } else {
      //print('Step 4 - Identity Not Verified: $completion%');
    }

    // Step 5: Check address proof verification - if addressProofVerified is true
    if (stage.addressProofVerified == true) {
      completion += 20;
      //print('Step 5 - Address Proof Verified: +20% = $completion%');
    } else {
      //print('Step 5 - Address Proof Not Verified: $completion%');
    }

    //print('FINAL COMPLETION: $completion%');
    return completion;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MoreController>(
      builder: (controller) {
        final model = controller.dashboardModel.value;
        final stage = model?.data?.stageCompletion;
        final completion = _calculateCompletion(stage);

        //print('COMPLETION----- $completion');
        //print('Model data: ${model?.data}');
        //print('Stage completion: $stage');
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
              padding: EdgeInsets.all(16.0),
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

                  // SizedBox(height: 6),

                  // Subtitle
                  Text(subTitle, style: AppTextStyles.labelOnChartPendingOrder),

                  SizedBox(height: 8),

                  // Progress row with percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$completion% ${languageService.tr('completed')}",
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: completion / 100,
                          minHeight: 3,
                          backgroundColor: AppColors.border,
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
