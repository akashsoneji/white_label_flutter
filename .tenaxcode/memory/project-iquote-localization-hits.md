---
name: project-iquote-localization-hits
description: "iQuote localization in-progress: 10 files/139 hits, full line-number map + reuse-keys + new-keys plan"
type: project
createdAt: 1787826585534
updatedAt: 1787826585534
---

iQuote localization (2026-08-27, IN PROGRESS — Vantage already DONE). 10 files, 139 hardcoded hits. Full detail saved in `.scratch/iquote_hits.json` (per-file line numbers) and `.scratch/iquote_reuse.json` (reuse map). All 9 lang files currently at 2518 keys.

**REUSABLE EXISTING KEYS (use these, don't create):**
- 'Loading...' → common_loading; 'Demo' → common_demo; 'Deposit' → common_deposit; 'Withdrawal' → general_withdrawal; 'Sort' → common_sort; 'Edit Order' → edit_order_screen_edit_order; 'One Click Trading' → more_screen_one_click_trading; 'No active account found' → chart_no_active_account; 'Take profit' → pending_order_take_profit_label; 'Stop loss' → pending_order_stop_loss_label; 'Error' → trading_error (generic).

**NEW KEYS TO CREATE (add to all 9 langs, iquote_/common_ prefix):** common_success ('Success'), iquote_positions_closed_success ('Positions closed successfully'), iquote_tab_market ('Market'), iquote_tab_pending ('Pending'), iquote_trigger_price ('Trigger Price'), iquote_limit_price ('Limit Price'), iquote_order_price ('Order Price'), common_undo ('Undo'), iquote_close_position ('Close Position'), iquote_close_losing ('Close Losing Positions'), iquote_close_losing_confirm ('Close all losing positions?'), iquote_close_profitable ('Close Profitable Positions'), iquote_close_profitable_confirm ('Close all profitable positions?'), iquote_close_all ('Close All Positions'), iquote_close_all_confirm ('Close all positions?'), iquote_no_positions ('No positions'), iquote_no_positions_filter ('No positions matched the selected filter'), iquote_scratchcard ('Scratchcard'), iquote_support_ticket ('Support Ticket'), iquote_order_placed ('Order placed'), iquote_search_symbol ('Search symbol'), iquote_search_symbols ('Search symbols…' — note ellipsis char), iquote_volume_gt_zero ('Volume must be greater than 0.'), iquote_auth_token_missing ('Authentication token missing.'), iquote_no_mt5_account ('No active MT5 account selected.'), iquote_valid_trigger ('Please enter a valid trigger price.'), iquote_valid_limit ('Please enter a valid limit price.'), iquote_failed_close_positions ('Failed to close positions'), iquote_failed_close_position ('Failed to close position'), iquote_failed_cancel_order ('Failed to cancel order'), iquote_ib_status_error ('Error checking IB status'), common_real ('Real'). For $e interpolation strings wire as `'${tr(key)}: $e'`.

**DO NOT TRANSLATE (acronyms/proper nouns):** 'IB', 'PAMM'. Leave hardcoded.

**CAUTION — verify before wiring these label: strings aren't ==compared in logic:** iquote_chart_screen.dart L1222 'Market'/L1228 'Pending' (toggle labels — check no ==comparison), L1420 'Trigger Price', L1458 'Limit Price', L1521 'Order Price', L1582 'Take profit', L1594 'Stop loss'. If compared, translate display only.

**FILES + line numbers (from .scratch/iquote_hits.json):**
1. auth/.../iquote/pages/iquote_create_account_screen.dart: L225 title 'Error'→trading_error.
2. home/brands/iquote/history_filter_sheet.dart: L526 hintText 'Search symbol'→iquote_search_symbol.
3. home/brands/iquote/iquote_chart_screen.dart: L465/484 'Error', L466 'No active account found'→chart_no_active_account, L479 'Success'→common_success, L480 'Positions closed successfully', L485 'Failed to close positions: $e', L1222 'Market', L1228 'Pending', L1420 'Trigger Price', L1458 'Limit Price', L1521 'Order Price', L1582 'Take profit', L1594 'Stop loss', L2080 'Undo', L2202 hintText 'Search symbols…', L2322 tooltip 'Sort'→common_sort.
4. home/brands/iquote/iquote_market_screen.dart: L364 'Loading...'→common_loading.
5. home/brands/iquote/iquote_order_details_screen.dart: 1 hit (rescan — was in list but no line shown).
6. home/brands/iquote/iquote_position_detail_screen.dart: L984 'Take profit', L999 'Stop loss'.
7. home/brands/iquote/iquote_position_screen.dart: L1243 'Close Position', L1250 'Edit Order'→edit_order_screen_edit_order, L1296 'Close Losing Positions', L1303 'Close all losing positions?', L1309 'Close Profitable Positions', L1316 'Close all profitable positions?', L1322 'Close All Positions', L1329 'Close all positions?', L1391 'No positions', L1392 'No positions matched the selected filter', L1500/1515/1719/1731/1871/1883 'Error', L1501/1720/1872 'No active account found', L1516 'Failed to close positions: $e', L1732 'Failed to close position: $e', L1884 'Failed to cancel order: $e'.
8. home/brands/iquote/view_models/iquote_chart_controller.dart: L343 'No active MT5 account selected.', L350 'Volume must be greater than 0.', L367 'Please enter a valid trigger price.', L377/387 'Please enter a valid limit price.', L398 'Authentication token missing.', L435 'Order placed'.
9. home/iquote_home_screen.dart: L41 'Error checking IB status: $e', L206 'Demo'→common_demo, L218 'Real'→common_real, L226 'IB'(SKIP), L235 'PAMM'(SKIP), L244 'Scratchcard', L253 'Support Ticket', L261 'Deposit'→common_deposit, L272 'Withdrawal'→general_withdrawal.
10. home/more/iquote_assets_layout.dart: L222 'Error checking IB status: $e', L1246 title 'One Click Trading'→more_screen_one_click_trading.

**ACCESS:** most iquote files likely have languageService accessor already (check). Else inline `Get.find<LanguageService>().tr('key')`, import `package:crm_app/services/language_service.dart`. flutter bin `~/development/flutter/bin/flutter`. Add keys via inline python loop ['en','es','es_MX','zh','id','ar','fr','hi','tr'] json.load→d[k]=vals[lang]→dump(ensure_ascii=False,indent=2)→append '\n'. After iQuote → Celestial → Meta.
