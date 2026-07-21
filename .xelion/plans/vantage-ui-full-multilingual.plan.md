# Vantage UI — Full Multilingual Coverage Plan

## Goal
Make every user-facing string in the **Vantage UI tree** (Vantage parent + 7 children: pipze, telifox, kantara, gtxprime, baazex, skyriss, riyadex) localizable via the existing `LanguageService.tr(...)` mechanism, with `en.json` as the single source of truth, then translate the new keys into the other 7 supported languages (ar, es, fr, hi, id, tr, zh).

## Approach
1. **Treat `en.json` as source of truth** — all 8 language files are already at 2174-key parity, so the foundation is in place. We only ADD new keys (never edit existing ones in place during this work).
2. **Enumerate every hardcoded user-facing string** in the Vantage UI tree using the existing `_scan_hardcoded_strings.py` scanner, deduplicated against current `en.json` keys + values.
3. **Manually promote string → key** with stable snake_case naming (`<screen>_<purpose>` pattern, mirroring existing keys like `login_button`, `register_subtitle`).
4. **Replace literal with `tr('key')` (or `TranslationUtils.tr('key')`)** at every call site — keep null-safety, preserve `const Text(...)` by moving to a non-const child or wrapping with `'key'.translate` extension where it builds cleanly.
5. **Add the new keys to `en.json`** (sorted, with 2-space indent, trailing newline).
6. **Translate the new keys to ar, es, fr, hi, id, tr, zh** using `deep_translator` GoogleTranslator with the existing parallel-worker + placeholder-preservation pattern from `.scratch/translate_missing.py`. Extend the script to also cover `ar`, `es`, `hi`, `tr` (currently it only does fr/id/zh).
7. **Verify** — run `flutter analyze` on touched files, run a quick `grep` to confirm no orphan hardcoded UI strings remain in the Vantage tree, regenerate parity report (all 8 files still have identical key sets).

## Steps

- [ ] **Step 1 — Scope the Vantage UI tree**: build a list of every Dart file under `lib/` that any of the 7 Vantage children render at runtime. Source from `lib/app/ui_registry.dart` (`_usesVantageUi` paths) + `lib/screens/home/brands/vantage/` + `lib/widgets/vantage/` + `lib/screens/auth/presentation/brands/vantage/` + the vantage entry-points referenced by `lib/screens/finance/presentation/finance_ui_registry.dart`. Output: a canonical file list to scan.
- [ ] **Step 2 — Run the hardcoded-string scanner** (`python3 _scan_hardcoded_strings.py --dry-run`) restricted to the Vantage tree only (modify the `SCAN_DIRS` to the 4 vantage paths from Step 1). Output: `/tmp/vantage_new_keys.json` (proposed key → value).
- [ ] **Step 3 — Curate the key list**: review `/tmp/vantage_new_keys.json`, dedupe against existing en.json values, and produce a final `vantage_keys_final.json`. Renaming pass to align with the existing naming convention (`<feature>_<purpose>` lowercase snake). Drop false positives (CamelCase class names caught by scanner, etc.).
- [ ] **Step 4 — Add new keys to `assets/translations/en.json`**: merge `vantage_keys_final.json` into en.json (preserving key order, sorting alphabetically on output). Confirm 2174 → 2174+N keys.
- [ ] **Step 5 — Replace hardcoded strings with `tr(...)` calls in source files**: go file-by-file through the Vantage tree. For each match: (a) `Text('Hello')` → `Text('hello'.translate)` (uses the existing `CrmAppTranslationExtension` on `String`); (b) `title: 'Settings'` → `title: 'settings'.translate`; (c) `hintText: 'Enter email'` → `hintText: 'enter_email'.translate`. For `const Text(...)` sites, drop `const` (the extension is a runtime call) OR introduce a `final` local. For `const TextStyle(...)` with no string payload, leave alone.
- [ ] **Step 6 — Extend the translator script** (`.scratch/translate_missing.py`) to also handle `ar, es, hi, tr` in addition to the existing `fr, id, zh`. Adjust the `TARGETS` map to include the right `GoogleTranslator` target codes (`ar` → `ar`, `es` → `es`, `hi` → `hi`, `tr` → `tr`). Re-run with the new en.json key set, writing translations back into the 7 non-English files (preserving existing key order in each).
- [ ] **Step 7 — Verify parity**: confirm all 8 files have identical key sets (the existing `assert` in the script will fail loudly if not). Run `flutter analyze` on touched files; expect 0 new errors. Run a `grep` pass for any remaining hardcoded `Text('...')` in the Vantage tree — should be empty for user-facing strings (allowed: brand names, asset paths, debug strings).
- [ ] **Step 8 — Commit & report**: list the files modified, the number of new keys added, and the per-language completion rate.

## Files

### Scan / translator scripts
- `.scratch/translate_missing.py` — **MODIFY**: add `ar, es, hi, tr` to the `TARGETS` map (currently only `fr, id, zh`). Keep the 6-worker parallel pool + placeholder-restoration logic unchanged.
- `_scan_hardcoded_strings.py` — **MODIFY**: temporarily narrow `SCAN_DIRS` to the Vantage tree only for Step 2, then restore for future runs. (Or, better, add a `--scope=vantage` CLI flag.)
- (new) `.scratch/curate_vantage_keys.py` — one-shot helper that reads `/tmp/vantage_new_keys.json`, drops known-false-positives, and writes the curated `vantage_keys_final.json`. Delete after use.

### Translation files
- `assets/translations/en.json` — **MODIFY**: add N new keys (alphabetical sort on output, 2-space indent, trailing newline).
- `assets/translations/ar.json` — **MODIFY**: add the same N new keys with Arabic translations.
- `assets/translations/es.json` — **MODIFY**: add the same N new keys with Spanish translations.
- `assets/translations/fr.json` — **MODIFY**: add the same N new keys with French translations.
- `assets/translations/hi.json` — **MODIFY**: add the same N new keys with Hindi translations.
- `assets/translations/id.json` — **MODIFY**: add the same N new keys with Indonesian translations.
- `assets/translations/tr.json` — **MODIFY**: add the same N new keys with Turkish translations.
- `assets/translations/zh.json` — **MODIFY**: add the same N new keys with Simplified Chinese translations.

### Source files (Vantage tree — to be edited, exact list depends on scan output)
- `lib/screens/auth/presentation/brands/vantage/pages/*.dart` (6 files: login, get_started, create_account, forgot_password, verify_code, create_new_password)
- `lib/screens/auth/presentation/brands/vantage/widgets/*.dart` (vantage_auth_scaffold, vantage_auth_theme, vantage_controls)
- `lib/screens/home/brands/vantage/*.dart` (vantage_chart_layout, vantage_dashboard_layout, vantage_more_layout, vantage_glass_tokens, vantage_pending_order_content, vantage_pending_order_quote_pill)
- `lib/widgets/vantage/*.dart` (vantage_app_bar, vantage_symbol_dropdown)
- `lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart`
- `lib/screens/finance/presentation/brands/vantage/pages/deposit_screen.dart` (via finance_ui_registry)
- Any other file that the scan flags — typical suspects: `vantage_more_options_list.dart`, `account_header_widget.dart` (vantage layout branch), `trading_main_screen.dart` (Vantage tab labels), `instruments_screen.dart` (vantage branch), `chart_screen.dart` (vantage layout), `pending_order_screen.dart` (vantage content), `trade_screen.dart` (vantage branch around line 528), `dashboard_controller.dart` (Vantage 5-tab labels around line 572).

### Out of scope (explicit)
- Celestial UI tree (`lib/brands/celestial/`) and Meta UI tree (`lib/brands/meta/`) — they are their own parents with their own UI. The plan covers only the Vantage tree + 7 children. (If the user wants Celestial/Meta coverage too, that's a separate plan.)
- Brand assets (logos, icons) — already in `assets/brands/<name>/`, language-independent.
- API responses and dynamic content from the trading backend.

## Risks / Open questions

- **Scanner false positives**: The regex-based scanner catches some non-UI strings (Dart identifiers inside quotes, import paths, etc.). Step 3 (manual curation) is the filter — expect to drop 10–25% of the raw output.
- **Performance**: `tr('key')` on every `Text` is a Map lookup per build. For lists with hundreds of cells this can be noticeable. Mitigation: keep `const` where possible by using a `final` local at the top of the `build` method: `final t = 'key'.translate;` and reuse.
- **RTL for Arabic**: Vantage UI is LTR-only today. The existing `LanguageService.rtlLanguages = ['ar']` will flip `Directionality` globally, but Vantage's layout (chart, glass tokens, asymmetric padding) is not RTL-tested. **Open question**: should Arabic be the first language to break Vantage's LTR assumption, or do we ship Vantage translations for ar with a force-LTR override at the Vantage widgets level? Default plan: ship all 8 languages, leave RTL handling to the existing global `Directionality` — if Vantage widgets need a `Directionality(textDirection: TextDirection.ltr)` wrap, that's a follow-up.
- **Translation quality**: `deep_translator` GoogleTranslator produces good but imperfect translations. Financial-domain strings (e.g. "Margin Call", "Stop Loss", "One-Click Trading") are likely fine. **Open question**: should we do a manual review pass on the translated files for the ~50 highest-stakes keys (login, deposit, withdraw, KYC, biometric)? Default plan: ship as-is, surface the full new-keys list in a follow-up report for manual review.
- **`const` removal cascade**: Replacing `const Text('Hello')` with `Text('hello'.translate)` removes `const` from the parent. This can disable const constructors in the widget tree, slightly increasing rebuild cost. Acceptable for the auth/home surface where rebuilds are rare. Lists (instruments, history) — use the `final t = '...'.translate;` local pattern to avoid repeated lookups.
- **Scope creep**: the user said "vantage UI and all". I'm reading that as "Vantage UI tree" (the shared parent + 7 children). If they actually meant "the entire app, all parent UIs (Vantage + Celestial + Meta)", the plan needs to be 3x larger. **Confirm before Step 5.**
