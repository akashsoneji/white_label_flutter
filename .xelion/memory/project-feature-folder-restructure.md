---
name: project-feature-folder-restructure
description: "Lib restructure 2026-07-09: flat → feature folder"
type: project
createdAt: 1783576158765
updatedAt: 1783593286982
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
- Added `FlavorConfig.isMultiBrokerEnabled` getter (true when flavor is `tenax` OR when active config has `selectedBrokerData`), `FlavorConfig.isONSA` getter (always false), `FlavorConfig.applyTenaxBrokerRuntimeConfig(Map<String, dynamic>?)` (no-op when payload is null/empty, otherwise applies via existing `applyBranding`). Added `FlavorConfigCopyWith` extension exposing `.copyWith(...)` for any field. **These are baked into the generator template at `scripts/generate_brand_config.dart` (around the `_parseColor` + `_BaseClientConfigFlavorConfigX` blocks) so they survive regeneration** — if you add a NEW helper, edit the template, NOT the generated file.
- Added `Flavor.meta` case to `FlavorConfig._configFor` (uses new `MetaConfig` from `lib/clients/meta/config.dart`) so the switch is now exhaustive — also baked into the generator template.
- Added Tenax multi-broker persistence to `SecureStorageService` (SharedPreferences-backed): `getTenaxBrokerSelection`, `saveTenaxBrokerSelection`, `getTenaxBrokerSelectionFlag`, `getTenaxUserBrokerProfiles`, `upsertTenaxUserBrokerProfile`, `getTenaxCurrentProfileKey`, `setTenaxCurrentProfileKey`.
- Fixed `lib/screens/home/more/more_screen.dart` to call `FlavorConfig.applyTenaxBrokerRuntimeConfig(mergedMap)` instead of the older 4-arg `config:/brokerName:/brokerLogoUrl:/brokerData:` signature.
- Fixed `lib/screens/home/more/more_screen.dart:1215` `FlavorConfig.isONSA()` → `FlavorConfig.isONSA` (it's a getter, not a method).
- Removed unused `_MenuItemWithButton` class and `_logoutBrokerLogoSource()` helper from `more_screen.dart` (no callers).
- Fixed `lib/screens/home/more/copytrading/master_dashboard_overview_tab.dart:394` `?pill` (Dart 3.8+ `null-aware-elements` feature, not enabled here) → `if (pill != null) pill!`.
- Fixed `lib/brand_switcher.dart` `_labelForName` switch: `case Flavor.meta` was inside a `String` switch (constant_pattern_never_matches_value_type) → replaced with `case 'meta':`.
- Fixed `lib/brand_switcher.dart:54` `static bool get isMeta => FlavorConfig.instance.flavor == Flavor.meta;` → `static bool get isMeta => _active == 'meta';` because in single-client builds the `Flavor` enum is narrowed to one value and `Flavor.meta` doesn't exist.
- **UI routing bug**: `lib/routes/app_pages.dart` `_Paths.TRADING` was hardcoded to `() => const TradingMainScreen()` so `MetaMainShell` (in `lib/brands/meta/`) and `CelestialMainShell` (in `lib/brands/celestial/`) were never reachable from routes. **Fixed** to use `() => UiRegistry.instance.tradingMain()`. **Celestial UI routing**: `lib/app/ui_registry.dart` previously mapped `'celestial' → 'vantage'` in `_uiParentByClient`, so Celestial was inheriting the Vantage shared UI even though it has its own complete 5-tab `CelestialMainShell`. **Fixed** by mapping `'celestial' → 'celestial'`, importing `CelestialMainShell`, and adding `if (_usesCelestialUi) return const CelestialMainShell();` in `tradingMain()`. Also removed now-unused `import '../screens/home/trading_main_screen.dart';` from `app_pages.dart`.

Build state: 0 errors, ~70 warnings (mostly unused imports, empty catches, harmless) as of 2026-07-09. `./build.sh celestial apk release` and `./build.sh meta apk release` both produce 3 split APKs (arm64-v8a, armeabi-v7a, x86_64) at `build/app/outputs/flutter-apk/`.
