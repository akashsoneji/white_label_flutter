---
name: project-localization-9lang-task
description: "Full-app localization: 9 langs wired; VANTAGE COMPLETE (6 files); next iQuote→Celestial→Meta; then bulk-translate 1818 values"
type: project
createdAt: 1787826251182
updatedAt: 1787826485922
---

TASK (2026-08-27, ongoing): Localize ENTIRE whitelabel app flavor-wise, screen-by-screen, into 9 languages. Order: Vantage(DONE) → iQuote(NEXT) → Celestial → Meta.

**LANGUAGES (9), picker order** in `lib/services/language_service.dart` supportedLanguages: en, es, es_MX ('Español (México)'), zh ('中文 (简体)'), id ('Bahasa Indonesia'), ar, fr, hi, tr. `_localeFor`: es_MX→Locale('es','MX'), zh→Locale('zh','CN'). analyze clean.

**TRANSLATION FILES** `assets/translations/<lang>.json`, ALL 9 now 2518 keys (2509 base + 7 transaction_history_* + 4 vantage_* toast), 0 missing/extra. Loader uses `$languageCode.json`. pubspec registers folder `assets/translations/`.

**app was NEVER fully translated.** ~1818 UNIQUE untranslated English values remain. Bulk translation still pending (themed batches). Per-file untranslated approx: ar=1066,tr=1153,es/es_MX=1720,hi=1751,zh=2103,fr=2140,id=2151.

**VANTAGE = COMPLETE (all 6 hardcoded-string files wired, each analyze-clean; only pre-existing warnings remain):**
1. transaction_history_screen.dart (finance/vantage) — 9 strings, added+wired 7 new transaction_history_* keys.
2. vantage_pending_order_quote_pill.dart — Bid/Ask → Get.find<LanguageService>().tr('meta_watchlist_bid'/'ask'); added import.
3. login_screen.dart (auth/vantage) — 'Password'→register_password.
4. create_account_screen.dart (auth/vantage) — toast 'Error'→trading_error (accessor _languageService L50).
5. vantage_chart_layout.dart — added `import .../services/language_service.dart` + accessor `LanguageService get _lang => Get.find<LanguageService>();` at ~L96. Wired: SELL→meta_neworder_sell, BUY→meta_neworder_buy (inline Get.find in inner _SideButton widget), 'Quantity (lots)'→vantage_chart_layout_quantity_lots (inline Get.find), toasts→vantage_waiting_live_price/vantage_no_active_account/vantage_trade_tab_unavailable, 'Trade error: $e'→`${_lang.tr('vantage_trade_error')}: $e`. NOTE this file has 4 PRE-EXISTING warnings (unused imports app_svg_icon+advanced_chart_inapp_webview, unused locals iconColor L603/fg L969) — NOT mine, leave them.
6. vantage_pending_order_content.dart — L633 display 'Stop Loss'→pending_order_stop_loss_label. (CAUTION was: 'Stop Loss' also == comparison at L1228+ — left untouched, only display label wired.)

**4 NEW vantage_ toast keys added to all 9 langs:** vantage_waiting_live_price, vantage_no_active_account, vantage_trade_error, vantage_trade_tab_unavailable.

**NEXT = iQuote.** Find hardcoded strings: `find lib -ipath "*iquote*" -name "*.dart"`. Then same python scan for `Text('...')` + `hintText/label/title:` literals not using .tr. Reuse existing en.json keys where possible (many meta_/trading_/pending_order_ keys exist). CAUTION pattern: some `label:` strings double as == comparison logic keys — translate DISPLAY only, never the compared value. After iQuote → Celestial → Meta.

**ACCESS:** `Get.find<LanguageService>().tr('key')` or add accessor field. Import `package:crm_app/services/language_service.dart`. Package name `crm_app`.

**TOOLS:** flutter bin `~/development/flutter/bin/flutter`. Add keys to all 9 via inline python heredoc: loop ['en','es','es_MX','zh','id','ar','fr','hi','tr'], json.load→d[k]=vals[lang]→json.dump(ensure_ascii=False,indent=2)→append '\n'. Scan script pattern in .scratch/. Value→9-lang translation dict lives in `.scratch/translate_missing.py` (T dict).

**FINAL PHASE (after all 4 flavors wired):** bulk-translate the ~1818 English-fallback values across langs, themed batches visible-first: nav/buttons→auth→trading→settings/finance→IB/copy-trading. Validate: all 9 files must stay equal key count, 0 missing.
