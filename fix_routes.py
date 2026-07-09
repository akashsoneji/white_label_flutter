import re

with open("lib/routes/app_pages.dart", "r") as f:
    content = f.read()

# Replace copy trading imports
content = re.sub(
    r"import 'package:crm_app/screens/copy_trading/presentation/pages/hub/copy_trading_hub_screen\.dart';\nimport 'package:crm_app/screens/copy_trading/presentation/pages/copy_trading_main_screen\.dart';\nimport 'package:crm_app/screens/copy_trading/presentation/pages/trader_details_screen\.dart';",
    "import 'package:crm_app/screens/home/more/copytrading/copy_trading_hub_screen.dart';\nimport 'package:crm_app/screens/copy_trading/copy_trading_main_screen.dart';\nimport 'package:crm_app/screens/copy_trading/trader_details_screen.dart';",
    content
)

content = re.sub(
    r"import '\.\./screens/copy_trading/presentation/pages/settings/wallet_screen\.dart';\nimport '\.\./screens/copy_trading/presentation/pages/finance/deposit_screen\.dart';\nimport '\.\./screens/copy_trading/presentation/pages/finance/payment_methods_screen\.dart';\nimport '\.\./screens/copy_trading/presentation/pages/settings/invite_friend_screen\.dart';\nimport '\.\./screens/copy_trading/presentation/pages/finance/internal_transfer_screen\.dart';",
    "import '../screens/copy_trading/settings/wallet_screen.dart';\nimport '../screens/copy_trading/finance/deposit_screen.dart';\nimport '../screens/copy_trading/finance/payment_methods_screen.dart';\nimport '../screens/copy_trading/settings/invite_friend_screen.dart';\nimport '../screens/copy_trading/finance/internal_transfer_screen.dart';",
    content
)

# Replace PMAM imports
content = re.sub(
    r"// PMAM screens\nimport '\.\./screens/pmam/presentation/pages/pmam_main_screen\.dart';\nimport '\.\./screens/pmam/presentation/pages/pmam_become_manager_screen\.dart';\nimport '\.\./screens/pmam/presentation/pages/pmam_manager_dashboard_screen\.dart';\nimport '\.\./screens/pmam/presentation/pages/pmam_manager_portal_screen\.dart';\nimport '\.\./screens/pmam/presentation/pages/pmam_create_plan_screen\.dart';\nimport '\.\./screens/pmam/presentation/pages/pmam_investor_portal_screen\.dart';\nimport '\.\./screens/pmam/presentation/pages/pmam_manager_detail_screen\.dart';\nimport '\.\./screens/pmam/presentation/pages/pmam_manager_plan_detail_screen\.dart';\nimport '\.\./screens/pmam/presentation/pages/pmam_fund_manager_view_screen\.dart';",
    "// PMAM screens\nimport '../screens/home/more/pmam/pmam_main_screen.dart';\nimport '../screens/home/more/pmam/pmam_become_manager_screen.dart';\nimport '../screens/home/more/pmam/pmam_manager_dashboard_screen.dart';\nimport '../screens/home/more/pmam/pmam_manager_portal_screen.dart';\nimport '../screens/home/more/pmam/pmam_create_plan_screen.dart';\nimport '../screens/home/more/pmam/pmam_investor_portal_screen.dart';\nimport '../screens/home/more/pmam/pmam_manager_detail_screen.dart';\nimport '../screens/home/more/pmam/pmam_manager_plan_detail_screen.dart';\nimport '../screens/home/more/pmam/pmam_fund_manager_view_screen.dart';",
    content
)

content = re.sub(
    r"import '\.\./screens/pmam/feature_di/pmam_binding\.dart';\n",
    "",
    content
)

# Replace PMAM GetPages
old_pmam_routes = """    // ── PMAM ──
    GetPage(
      name: _Paths.PMAM_MAIN,
      page: () => const PmamMainScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_BECOME_MANAGER,
      page: () => const PmamBecomeManagerScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_DASHBOARD,
      page: () => const PmamManagerDashboardScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_PORTAL,
      page: () => const PmamManagerPortalScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_CREATE_PLAN,
      page: () => const PmamCreatePlanScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_INVESTOR_PORTAL,
      page: () => const PmamInvestorPortalScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_DETAIL,
      page: () => const PmamManagerDetailScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_PLAN_DETAIL,
      page: () => const PmamManagerPlanDetailScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_FUND_MANAGER_VIEW,
      page: () => const PmamFundManagerViewScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),"""

new_pmam_routes = """    // ── PMAM ──
    GetPage(name: _Paths.PMAM_MAIN, page: () => const PmamMainScreen()),
    GetPage(name: _Paths.PMAM_BECOME_MANAGER, page: () => const PmamBecomeManagerScreen()),
    GetPage(name: _Paths.PMAM_MANAGER_DASHBOARD, page: () => const PmamManagerDashboardScreen()),
    GetPage(name: _Paths.PMAM_MANAGER_PORTAL, page: () => const PmamManagerPortalScreen()),
    GetPage(name: _Paths.PMAM_CREATE_PLAN, page: () => const PmamCreatePlanScreen()),
    GetPage(name: _Paths.PMAM_INVESTOR_PORTAL, page: () => const PmamInvestorPortalScreen()),
    GetPage(name: _Paths.PMAM_MANAGER_DETAIL, page: () => const PmamManagerDetailScreen()),
    GetPage(name: _Paths.PMAM_MANAGER_PLAN_DETAIL, page: () => const PmamManagerPlanDetailScreen()),
    GetPage(name: _Paths.PMAM_FUND_MANAGER_VIEW, page: () => const PmamFundManagerViewScreen()),"""

content = content.replace(old_pmam_routes, new_pmam_routes)

with open("lib/routes/app_pages.dart", "w") as f:
    f.write(content)
