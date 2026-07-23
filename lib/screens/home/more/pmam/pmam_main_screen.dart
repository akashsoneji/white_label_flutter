import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../constants/color.dart';
import '../../../../controllers/pmam/pmam_controller.dart';
import '../../../../widgets/pmam_bottom_navigation.dart';
import 'pmam_become_manager_screen.dart';
import 'pmam_explore_managers_screen.dart';
import 'pmam_investor_portal_screen.dart';
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
        'Manager Dashboard',
        'My Plans',
        'My Investors',
        'Explore Fund Managers',
        'My Investments',
      ][i];
    }
    return [
      'Become a Manager',
      'Explore Fund Managers',
      'My Investments',
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
          leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
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
          actions: [
            if (mode == PmamNavMode.manager)
              IconButton(
                tooltip: 'Refresh',
                icon: Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
                onPressed: () => _c.loadManagerDashboard(),
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
