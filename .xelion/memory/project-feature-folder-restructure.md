---
name: project-feature-folder-restructure
description: "Lib restructure 2026-07-09: flat → feature folder"
type: project
createdAt: 1783576158765
updatedAt: 1783576158765
---

Whitelabel app underwent a MAJOR RESTRUCTURE on 2026-07-09: 131 analyzer errors existed because `lib/routes/app_pages.dart` and `lib/screens/home/more/more_screen.dart` still referenced the OLD flat paths while everything else had moved to a feature-folder layout:

OLD paths → NEW paths:
- `lib/screens/auth/{splash,getstart,register,password}/X.dart` → `lib/screens/auth/presentation/pages/X.dart`
- `lib/screens/home/kyc/X.dart` → `lib/screens/kyc/presentation/pages/X.dart`
- `lib/screens/home/more/finance/X.dart` → `lib/screens/finance/presentation/pages/X.dart`
- `lib/screens/home/more/bonus/X.dart` → `lib/screens/bonus/presentation/pages/X.dart`
- `lib/screens/home/more/demo_contest/X.dart` → `lib/screens/demo_contest/presentation/pages/X.dart`
- `lib/screens/home/more/ib_dashboard/X.dart` → `lib/screens/ib/presentation/pages/X.dart`
- `lib/screens/settings/X.dart` → `lib/screens/settings/presentation/pages/X.dart`
- `lib/screens/copy_trading/{finance,settings}/X.dart` → STAYED at `lib/screens/copy_trading/{finance,settings}/X.dart`
- `lib/controllers/auth_controller.dart` → `lib/screens/auth/view_models/auth_controller.dart`
- `lib/controllers/more/more_controller.dart` → `lib/screens/more/view_models/more_controller.dart`
- `lib/controllers/ib_controller.dart` → `lib/screens/ib/view_models/ib_controller.dart`
- `lib/screens/home/more/finance/...` → STAYED (more_screen.dart itself + pmam/, ticket/, setting/, support/, tools_education/, copytrading/, promotional/, edit_profile/, partnership_program/, chat_with_us/, kyc_verification/, two_factor_auth/, one_click_trading_disclaimer/, camera/, id_upload/ all still under `lib/screens/home/more/`)

Why: project reorganized from flat layout to per-feature `data/view_models/presentation/brands/X/pages` layout to support brand-specific implementations (vantage/tenax/xelthio/baazex) sharing one parent class.

How to apply: When adding new auth screens, KYC screens, finance screens — put them under `lib/screens/<feature>/presentation/pages/`. When adding new controllers — put under `lib/screens/<feature>/view_models/`. The imports in `lib/routes/app_pages.dart` are the source of truth for which paths are valid. Auth files at `lib/screens/auth/presentation/brands/vantage/pages/` are duplicates / old copies — the canonical location is `lib/screens/auth/presentation/pages/`.

Also fixed:
- Added `Routes.TWO_FACTOR_AUTH` (was only in `_Paths`) — `celestial_settings_screen.dart` and any other code using `Routes.TWO_FACTOR_AUTH` works now.
- Added `FlavorConfig.isMultiBrokerEnabled` getter (alias for `isTenax()`), `FlavorConfig.isONSA` getter (always false), `FlavorConfig.applyTenaxBrokerRuntimeConfig(Map<String, dynamic>?)` (no-op when not Tenax, otherwise applies logo/colors/selectedBrokerData overrides via new `FlavorConfig.copyWith` helper).
- Added Tenax multi-broker persistence to `SecureStorageService` (SharedPreferences-backed): `getTenaxBrokerSelection`, `saveTenaxBrokerSelection`, `getTenaxBrokerSelectionFlag`, `getTenaxUserBrokerProfiles`, `upsertTenaxUserBrokerProfile`, `getTenaxCurrentProfileKey`, `setTenaxCurrentProfileKey`.
- Fixed `lib/screens/home/more/more_screen.dart` to call `FlavorConfig.applyTenaxBrokerRuntimeConfig(mergedMap)` instead of the older 4-arg `config:/brokerName:/brokerLogoUrl:/brokerData:` signature.
- Fixed `lib/screens/home/more/more_screen.dart:1215` `FlavorConfig.isONSA()` → `FlavorConfig.isONSA` (it's a getter, not a method).
- Fixed `lib/screens/home/more/copytrading/master_dashboard_overview_tab.dart:394` `?pill` (Dart 3.8+ `null-aware-elements` feature, not enabled here) → `if (pill != null) pill!`.

Build state: 0 errors, ~70 warnings (mostly unused imports, empty catches, harmless) as of 2026-07-09.
