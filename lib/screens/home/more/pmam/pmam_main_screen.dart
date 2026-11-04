
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../constants/color.dart';
import '../../../../controllers/pmam/pmam_controller.dart';
import '../../../../widgets/pmam_bottom_navigation.dart';
import 'pmam_become_manager_screen.dart';
import 'pmam_explore_managers_screen.dart';
import 'pmam_investor_portal_screen.dart';
import '../../../../routes/app_pages.dart';
import 'pmam_manager_commissions_screen.dart';
import 'pmam_manager_dashboard_screen.dart';
import 'pmam_manager_portal_screen.dart';

/// Single entry-point for the PAMM module.
///
/// Hosts a bottom-navigation scaffold whose tab set depends on whether the
/// signed-in user is an *approved* PAMM manager:
///
///   • Approved manager → 5 tabs
///     Dashboard / My Plans / My Investors / Explore / My Investments
///
///   • Everyone else  → 3 tabs
///     Become a Manager / Explore Fund Managers / My Investments
class PmamMainScreen extends StatefulWidget {
  const PmamMainScreen({super.key});

  @override
  State<PmamMainScreen> createState() => _PmamMainScreenState();
}

class _PmamMainScreenState extends State<PmamMainScreen> {
  final PmamController _c = Get.put(PmamController(), permanent: true);

  /// Index of the "Explore Fund Managers" tab within [_pagesFor] for a mode.
  /// • manager  → 5 tabs → Explore is at index 3
  /// • investor → 3 tabs → Explore is at index 1
  static const int _exploreIdxForManager = 3;
  static const int _exploreIdxForInvestor = 1;

  /// Positions in the manager tab set.
  static const int _dashboardIdx = 0;
  static const int _myPlansIdx = 1;

  int? _idx; // null until first mode is known → then resolves to Explore
  PmamNavMode? _lastMode;

  /// Default tab index for a given mode — always lands on "Explore".
  int _defaultIdxFor(PmamNavMode mode) => mode == PmamNavMode.manager
      ? _exploreIdxForManager
      : _exploreIdxForInvestor;

  @override
  void initState() {
    super.initState();
    // Kick off the lightweight profile check so we know the manager status
    // before deciding which tab set to show.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _c.loadManagerStatus();
      } catch (_) {}
    });
  }

  PmamNavMode _modeFor(String? status) =>
      (status?.toLowerCase() == 'approved')
          ? PmamNavMode.manager
          : PmamNavMode.investor;

  List<Widget> _pagesFor(PmamNavMode mode) {
    if (mode == PmamNavMode.manager) {
      return [
        PmamManagerDashboardScreen(),
        // Plans tab of the manager portal.
        PmamManagerPortalScreen(initialTab: 1, embedded: true),
        // Investors tab of the manager portal.
        PmamManagerPortalScreen(initialTab: 0, embedded: true),
        PmamExploreManagersScreen(embedded: true),
        // My Investments tab of the investor portal.
        PmamInvestorPortalScreen(initialTab: 1, embedded: true),
      ];
    }
    return [
      PmamBecomeManagerScreen(),
      PmamExploreManagersScreen(embedded: true),
      PmamInvestorPortalScreen(initialTab: 1, embedded: true),
    ];
  }

  String _titleFor(PmamNavMode mode, int i) {
    if (mode == PmamNavMode.manager) {
      return [
        TranslationUtils.tr('pmam_manager_dashboard_screen_manager_dashboard'),
        TranslationUtils.tr('copy_trading_nav_my_plans'),
        TranslationUtils.tr('pmam_main_screen_my_investors'),
        TranslationUtils.tr(
            'pmam_explore_managers_screen_explore_fund_managers'),
        TranslationUtils.tr('my_investments_screen_my_investments'),
      ][i];
    }
    return [
      TranslationUtils.tr('pmam_become_manager_screen_become_manager'),
      TranslationUtils.tr('pmam_explore_managers_screen_explore_fund_managers'),
      TranslationUtils.tr('my_investments_screen_my_investments'),
    ][i];
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = _modeFor(_c.managerStatus.value);

      // Reset the active index whenever the tab set changes so we don't end
      // up pointing at a missing tab. Default lands on "Explore".
      if (_lastMode != mode) {
        _lastMode = mode;
        final defaultIdx = _defaultIdxFor(mode);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _idx = defaultIdx);
        });
      }

      final pages = _pagesFor(mode);
      final int resolvedIdx = _idx ?? _defaultIdxFor(mode);
      final safeIdx = resolvedIdx.clamp(0, pages.length - 1);

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          elevation: 0,
          centerTitle: false,
          // Home closes the whole PAMM stack (plan detail, commissions, …) and
          // returns to the main shell, which is still on the More tab.
          leading: IconButton(
            tooltip: TranslationUtils.tr('more_title'),
            icon: SvgPicture.asset(
              'assets/svg/ib_dashboard/home.svg',
              colorFilter: ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => Get.until((route) => route.isFirst),
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(
            _titleFor(mode, safeIdx),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          // Every tab refreshes by pulling down. Commission History lives on
          // the Dashboard tab only; New Plan on the My Plans tab only.
          actions: [
            if (mode == PmamNavMode.manager && safeIdx == _dashboardIdx)
              IconButton(
                tooltip: TranslationUtils.tr('pmam_commissions_title'),
                icon: Icon(Icons.payments_outlined, color: AppColors.textPrimary),
                onPressed: () =>
                    Get.to(() => const PmamManagerCommissionsScreen()),
              ),
            if (mode == PmamNavMode.manager && safeIdx == _myPlansIdx)
              Padding(
                padding: EdgeInsetsDirectional.only(end: 12.w),
                child: TextButton.icon(
                  onPressed: () => Get.toNamed(AppPages.PMAM_CREATE_PLAN),
                  icon: Icon(
                    Icons.add_rounded,
                    size: 18.sp,
                    color: AppColors.onColoredBackground,
                  ),
                  label: Text(
                    TranslationUtils.tr('pmam_manager_portal_screen_new_plan'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.onColoredBackground,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    minimumSize: Size(0, 34.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: IndexedStack(
          index: safeIdx,
          children: pages,
        ),
        bottomNavigationBar: PmamBottomNavigation(
          currentIndex: safeIdx,
          mode: mode,
          onTap: (i) => setState(() => _idx = i),
        ),
      );
    });
  }
}
