# Full-Project Language Support (All Screens, All 6 Languages)

## Goal
1. Add 3 new languages — French (`fr`), Indonesian (`id`), Chinese (`zh`) — to the existing 5-language setup (en, ar, tr, hi, es), for 6 total.
2. Migrate **every screen and widget** in the project from hardcoded `Text('...')` strings to `languageService.tr('key')`, so the entire UI switches language at runtime.
3. Make `assets/translations/en.json` the single source of truth for all UI text; `ar.json`, `es.json`, `hi.json`, `tr.json`, `fr.json`, `id.json`, `zh.json` mirror the same key set with their translations.

## Approach
`LanguageService.supportedLanguages` (in `lib/services/language_service.dart`) is the single source of truth: it drives the picker in `language_selector_screen.dart`, the `supportedLocales` list given to `GetMaterialApp` in `main.dart`, secure-storage save/load, and the asset loader that reads `assets/translations/<code>.json`. Add the 3 new entries there and the picker / `GetMaterialApp` automatically picks them up.

Chinese needs a region qualifier (`Locale('zh', 'CN')`) for Flutter's built-in `GlobalMaterialLocalizations` to match; French and Indonesian use bare `Locale(code)` like the existing entries.

The translation migration strategy:
- **`en.json` is expanded first** — it becomes the master key set. Every UI string in every screen/widget must have a matching key.
- **Other language files are filled to match** — same keys, translated values. The 3 new language files start empty; they're populated in the same pass.
- **Screens are migrated file-by-file** — each `Text('hardcoded')`, `title: '...'`, `snackbar`, `toast`, `dialog`, etc. becomes `languageService.tr('key')`. Screens that already use `tr()` are untouched.
- **`tr()` fallback behavior is the safety net** — when a key is missing in the active language, `tr()` returns the key string itself. So partial migration is safe (users see the key rather than a crash). The goal is 100% coverage.

## Steps

### Phase A — Expand the master dictionary (`en.json`)
- [ ] A1 — Read `assets/translations/en.json` end-to-end. The current file has ~250 keys. Treat it as the "minimum" set; many screens have additional hardcoded strings not yet captured.
- [ ] A2 — Grep every `lib/screens/**/*.dart` and `lib/widgets/**/*.dart` for hardcoded user-facing strings: `Text('`, `title: '`, `title: "`, `snackbar`, `toast`, `showDialog`, `AlertDialog`, `CupertinoAlertDialog`, `ElevatedButton(text: `, `TextButton(text: `, `hintText: `, `labelText: `, `subtitle: `, `placeholder: `, `contentText: `, `message: `, `errorText: `, `helperText: `, `tooltip: `.
- [ ] A3 — For each unique string found, add a new entry in `en.json`. Naming convention: `<screen_or_feature>_<purpose>` (e.g. `dashboard_open_real_account`, `withdrawal_amount_label`, `kyc_bank_list_title`). Use `{placeholder}` for interpolated values (e.g. `chart_timeframe_label: "Timeframe: {tf}"`).
- [ ] A4 — Run a script (or manual diff) to confirm the existing `ar.json`, `es.json`, `hi.json`, `tr.json` still parse as valid JSON with their existing keys. Do NOT reorder or rename their existing keys; only add newly-needed keys with placeholder `""` values so the Agent can populate them later.

### Phase B — Add 3 new languages
- [x] B1 — `lib/services/language_service.dart:13` `supportedLanguages` map: append `'fr': 'Français'`, `'id': 'Bahasa'`, `'zh': '中文'`. **DONE**.
- [x] B2 — `rtlLanguages` list kept as-is with explicit comment: only Arabic is RTL. **DONE**.
- [x] B3 — `changeLanguage` + saved-locale load: rewrote to use `static _localeFor(code)` helper that returns `Locale('zh', 'CN')` for Chinese, `Locale(code)` for the rest; storage now writes `zh_CN` for Chinese. **DONE**.
- [x] B4 — `getCurrentLocale` / saved-locale load: both go through `_localeFor` so Chinese is correctly reloaded. **DONE**.
- [x] B5 — `supportedLocales` getter: now `supportedLanguages.keys.map(_localeFor).toList()`. **DONE**.
- [x] B6 — `getLanguageInfo` + `getAvailableLocales` now go through `_localeFor` so the reported `locale` field is region-correct for Chinese. **DONE**.
- [x] B7 — Created empty `assets/translations/{fr,id,zh}.json` (`{}`). **DONE**.
- [x] B8 — `flutter analyze lib/services/language_service.dart` is **CLEAN** (0 issues).

### Phase C — Migrate every screen and widget
Order matters — migrate shared/widgets first, then screens that depend on them.

- [ ] C1 — **Shared widgets** (migrate these first, other screens depend on them):
  - `lib/widgets/global_drawer.dart` — already has `languageService` injected (line 16). Migrate any remaining hardcoded strings.
  - `lib/widgets/trading_bottom_navigation.dart` — already has `languageService` injected (line 23). Migrate bottom-nav labels.
  - `lib/widgets/trade_win_bottom_navigation.dart` — already has `languageService` injected (line 40).
  - `lib/widgets/theme_bottom_sheet.dart` — already has `languageService` injected (line 58).
  - `lib/widgets/common_loading_widget.dart` — scan for hardcoded strings.
  - `lib/widgets/app_back_button.dart` — scan.
  - `lib/widgets/currency_text_field.dart` — scan.
  - `lib/widgets/rtl_wrapper.dart` — scan.
  - `lib/utils/trl_helper.dart` — scan.
  - `lib/utils/agreement_launcher.dart` — already has `languageService` injected (line 36).
- [ ] C2 — **Settings screens** (language picker itself already uses tr — use it as a template):
  - `lib/screens/settings/presentation/pages/language_selector_screen.dart` — already uses `tr()` extensively. Confirm 100% coverage.
  - `lib/screens/settings/presentation/pages/setting_screen.dart` — already has `languageService` (line 17).
- [ ] C3 — **Auth flow** (all already have `languageService` injected):
  - `lib/screens/auth/presentation/pages/get_started_screen.dart` (line 15)
  - `lib/screens/auth/presentation/pages/login_screen.dart` (line 36)
  - `lib/screens/auth/presentation/pages/login_screen_updated.dart` (line 27)
  - `lib/screens/auth/presentation/pages/create_account_screen.dart` (line 58)
  - `lib/screens/auth/presentation/pages/register_screen.dart` — scan for injection.
  - `lib/screens/auth/presentation/pages/forgot_password_screen.dart` (line 27)
  - `lib/screens/auth/presentation/pages/verify_code_screen.dart` (line 30)
  - `lib/screens/auth/presentation/pages/create_new_password_screen.dart` (line 130)
  - `lib/screens/auth/presentation/pages/legal_documents_screen.dart` (line 34)
  - `lib/screens/auth/presentation/pages/privacy_policy_screen.dart` (line 18)
  - `lib/screens/auth/presentation/pages/account_created_screen.dart` (line 17)
  - `lib/screens/auth/presentation/pages/google_login_otp_screen.dart` (line 21)
  - `lib/screens/auth/presentation/auth_form_validation.dart` (line 27)
  - **Vantage variants**: `lib/screens/auth/presentation/brands/vantage/pages/login_screen.dart`, `forgot_password_screen.dart`, `get_started_screen.dart`, `create_new_password_screen.dart`, `create_account_screen.dart`, `verify_code_screen.dart`
- [ ] C4 — **KYC screens** (all have `languageService`):
  - `lib/screens/kyc/presentation/pages/kyc_intro_screen.dart` (line 19)
  - `lib/screens/kyc/presentation/pages/kyc_docs_screen.dart` (line 20)
  - `lib/screens/kyc/presentation/pages/kyc_bank_screen.dart` (line 30)
  - `lib/screens/kyc/presentation/pages/kyc_details_screen.dart` (line 62)
  - `lib/screens/kyc/presentation/pages/unified_compliance_wizard.dart` (line 25)
  - `lib/screens/kyc/presentation/pages/bank_list_screen.dart` (line 24)
- [ ] C5 — **Finance screens**:
  - `lib/screens/finance/presentation/pages/deposit_screen.dart` (line 44)
  - `lib/screens/finance/presentation/pages/deposit_real_screen.dart` (line 79)
  - `lib/screens/finance/presentation/pages/deposit_instruction_screen.dart` (line 48)
  - `lib/screens/finance/presentation/pages/payment_methods_screen.dart` (line 28)
  - `lib/screens/finance/presentation/pages/withdrawal_screen.dart` (line 31)
  - `lib/screens/finance/presentation/pages/wallet_screen.dart` (line 27)
  - `lib/screens/finance/presentation/pages/transaction_history_screen.dart` (line 32)
  - `lib/screens/finance/presentation/pages/internal_transfer_screen.dart` (line 27)
  - `lib/screens/finance/presentation/pages/finance_screen.dart` (line 18)
  - `lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart` (line 33)
- [ ] C6 — **Trading / home screens**:
  - `lib/screens/home/trade_screen.dart` (line 92)
  - `lib/screens/home/chart_screen.dart` (line 81)
  - `lib/screens/home/instruments_screen.dart` (line 50)
  - `lib/screens/home/search_instruments_screen.dart` (line 41)
  - `lib/screens/home/choose_account_screen.dart` (line 32)
  - `lib/screens/home/change_password_screen.dart` (line 24)
  - `lib/screens/home/order_history_screen.dart` (line 20)
  - `lib/screens/home/pending_order_content.dart` (line 1205)
  - `lib/screens/home/enhanced_pending_order_content.dart` (line 655)
  - `lib/screens/home/brands/vantage/vantage_pending_order_content.dart` (line 973)
  - `lib/screens/home/more/id_upload_screen.dart` (line 49)
  - `lib/screens/home/more/setting/setting_screen.dart` (line 17)
  - `lib/screens/home/more/edit_profile_screen.dart` (line 39)
  - `lib/screens/home/more/two_factor_auth_screen.dart` (line 24)
  - `lib/screens/home/more/support/support_screen.dart` (line 20)
  - `lib/screens/home/more/kyc_verification_screen.dart` (line 20)
  - `lib/screens/home/more/tools_education/tools_education_screen.dart` (line 17)
- [ ] C7 — **More-list items and remaining sub-screens** (these are typically routed from `more_screen.dart`):
  - `lib/screens/home/more/` — scan every `.dart` file for `Text('`, `title: '`, etc.
  - `lib/screens/ib/presentation/pages/ib_dashboard_screen.dart` (line 16)
  - `lib/screens/ib/presentation/pages/commission_groups_screen.dart`
  - `lib/screens/ib/presentation/pages/ib_structure_screen.dart`
  - `lib/screens/demo_contest/presentation/pages/demo_contest_screen.dart` (line 37)
  - `lib/screens/demo_contest/presentation/pages/leaderboard_screen.dart` (line 65)
  - `lib/screens/demo_contest/presentation/pages/winners_screen.dart` (line 20)
  - `lib/screens/demo_contest/presentation/pages/contest_details_screen.dart` (line 45)
  - `lib/screens/demo_contest/presentation/pages/join_contest_screen.dart` (line 38)
  - `lib/screens/demo_contest/presentation/pages/contest_rules_screen.dart` (line 16)
  - `lib/screens/demo_contest/presentation/pages/my_contest_history_screen.dart` (line 36)
  - `lib/screens/bonus/presentation/pages/bonus_screen.dart` (line 351)
  - `lib/screens/trade_win/*` (multiple files, lines 19/14/55/24/117)
  - `lib/screens/more/view_models/two_factor_auth_controller.dart` (line 13)
- [ ] C8 — **Brand-specific overrides** (Vantage, Celestial, Meta, Tenax, etc.) — these override parent screens and may have their own hardcoded strings:
  - `lib/brands/celestial/*.dart`
  - `lib/brands/meta/*.dart`
  - `lib/brands/tenax/*.dart` (if present)
  - `lib/screens/*/presentation/brands/*/pages/*.dart`
  - For each, follow the same pattern: inject `LanguageService` (or pass it through), then replace hardcoded strings with `tr()`.
- [ ] C9 — **Controllers / view models** — these emit toasts, snackbars, alerts, and validation errors that are currently hardcoded English strings:
  - `lib/screens/auth/view_models/auth_controller.dart`
  - `lib/screens/more/view_models/two_factor_auth_controller.dart` (line 13 already injected)
  - `lib/screens/finance/view_models/deposit_instruction_controller.dart`
  - `lib/screens/finance/view_models/transaction_history_controller.dart`
  - Any other `*_controller.dart` / `*_binding.dart` — scan for `print('...')`, `toast`, `snackbar`, `alert`, `showDialog`.
- [ ] C10 — **Android / iOS native strings** — any string in `android/app/src/main/AndroidManifest.xml` or `ios/Runner/Info.plist` that is user-facing (app name, notification channel name). For app name, use the existing `app_name` translation key from en.json. Platform-native strings need a separate mechanism (Flutter doesn't localize native manifests automatically); out of scope for this plan but flagged.

### Phase D — Populate the 3 new language files + fill missing keys in existing files
- [ ] D1 — `assets/translations/fr.json` — populate with French translations for every key in en.json. (Machine translation acceptable as seed; reviewer should validate.)
- [ ] D2 — `assets/translations/id.json` — populate with Indonesian translations for every key.
- [ ] D3 — `assets/translations/zh.json` — populate with Simplified Chinese translations for every key.
- [ ] D4 — For `ar.json`, `es.json`, `hi.json`, `tr.json` — fill in any keys that are currently `""` placeholders from Phase A step A4. Goal: every key present in en.json has a non-empty value in every other language file.
- [ ] D5 — Validation: write or run a one-shot Dart script (e.g. `scripts/validate_translations.dart`) that loads all 6 JSON files, compares key sets, and prints (a) keys missing in each non-en file, (b) keys present in non-en but absent in en. Zero missing keys at the end.

### Phase E — Final verification
- [ ] E1 — Run `flutter analyze lib/services/language_service.dart` — must be clean.
- [ ] E2 — Run the validation script from D5 — must report zero missing keys across all 6 files.
- [ ] E3 — Build + smoke test: `./build.sh <any-brand> apk debug` → launch → Settings → Language → switch between all 6. Confirm every screen re-renders with the selected language, RTL activates for Arabic, Chinese uses `zh-CN` locale.
- [ ] E4 — `flutter pub run flutter_launcher_icons:main` (or equivalent) if the app name in AndroidManifest / Info.plist is being read from translations — but confirm first; many white-label apps use per-brand static app names, so this may be brand-specific, not language-specific.

## Files
### Files to modify
- `lib/services/language_service.dart` — add 3 entries to `supportedLanguages`, region-aware branch for `zh`, `rtlLanguages` comment, `getLanguageInfo` update.
- `assets/translations/en.json` — expand with every new UI string key (master dictionary).
- `assets/translations/ar.json` — add newly-discovered keys, fill `""` placeholders.
- `assets/translations/es.json` — same.
- `assets/translations/hi.json` — same.
- `assets/translations/tr.json` — same.
- `assets/translations/fr.json` — new file, populated with French translations.
- `assets/translations/id.json` — new file, populated with Indonesian translations.
- `assets/translations/zh.json` — new file, populated with Simplified Chinese translations.
- **Every `lib/screens/**/*.dart`** — migrate hardcoded strings to `languageService.tr('key')` (30+ files, listed in Phase C steps).
- **Every `lib/widgets/**/*.dart`** — same (listed in C1).
- **Every `lib/brands/**/presentation/brands/**/*.dart`** — same (listed in C8).
- **Controllers / view models** — listed in C9.

### Files to create
- `scripts/validate_translations.dart` — one-shot validator that compares key sets across all translation JSONs and reports gaps.

## Risks / Open questions
- **Scale**: this is a large migration (30+ screens, ~250+ keys across 6 languages). Phases A–D should be executed in order — expand en.json first, then add languages, then migrate screens, then populate translations. Doing them out of order (e.g. migrating screens before the keys exist) wastes effort.
- **Chinese regional variant**: plan uses Simplified (`zh-CN`). If Traditional (Taiwan/Hong Kong) is needed, change region to `TW` and update display name.
- **RTL coverage**: only Arabic is RTL. French, Indonesian, Chinese are LTR. Confirm `isRTL()` still returns `true` for Arabic after adding new entries (it should — the list is unchanged).
- **Brand-specific app names**: some brands (pipze, vantage, etc.) have static app names in their `brand.yaml`. Those are not translated by this system — they're per-brand, not per-language. Out of scope unless the user explicitly wants per-brand-per-language names.
- **Date/number formatting**: `intl` package is used in several screens with hard-coded `Intl()` constructors (`DateFormat`, `NumberFormat`). Those will follow the *device* locale, not the app-selected locale, until each call site is migrated to use the `LanguageService.currentLocale` stream. Flag as a follow-up — it's independent of string translation.
- **Native manifests** (AndroidManifest.xml, Info.plist): app name in the OS launcher is not auto-localized by Flutter. Each brand currently uses a static string. Out of scope unless the user requests OS-level localization.
- **`.DS_Store` and helper scripts** at the repo root (`_find_pct.py`, `_analyze*.py`, `_order_screenshots/` etc.) are junk/diagnostics, not app code — skip them during the migration scan.
