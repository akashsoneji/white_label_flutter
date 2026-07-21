"""Scan and fix remaining hardcoded strings in specific files."""
import re

files_to_fix = {
    'lib/brands/meta/meta_new_order_screen.dart': [
        ("'Fill policy'", "languageService.tr('meta_neworder_fill_policy')"),
        ("'Fill or Kill'", "languageService.tr('meta_neworder_fok')"),
        ("'Expiration:'", "languageService.tr('meta_neworder_expiration')"),
        ("'BY MARKET'", "languageService.tr('meta_neworder_by_market')"),
        ("'SELL'", "languageService.tr('meta_neworder_sell')"),
        ("'BUY'", "languageService.tr('meta_neworder_buy')"),
        ("'PLACE'", "languageService.tr('meta_neworder_place')"),
    ],
    'lib/brands/meta/meta_close_position_screen.dart': [
        ("'Close position'", "languageService.tr('meta_close_position_label')"),
        ("'Close mode'", "languageService.tr('meta_close_mode')"),
        ("'Tap a − pill to close part of the position'", "languageService.tr('meta_close_partial_hint')"),
        ("'Fill policy'", "languageService.tr('meta_close_fill_policy')"),
        ("'Fill or Kill'", "languageService.tr('meta_close_fok')"),
        ("'Immediate or Cancel'", "languageService.tr('meta_close_ioc')"),
        ("'Book or Cancel'", "languageService.tr('meta_close_boc')"),
    ],
    'lib/brands/meta/meta_modify_position_screen.dart': [
        ("'Modify position #${p.orderId}'", "languageService.tr('meta_modify_position_label', {'id': '$p.orderId'})"),
        ("'Auto SL/TP Calculator'", "languageService.tr('meta_modify_auto_sl_tp')"),
        ("'Apply'", "languageService.tr('meta_modify_apply')"),
        ("'Stop Loss'", "languageService.tr('meta_modify_stop_loss')"),
        ("'Take Profit'", "languageService.tr('meta_modify_take_profit')"),
        ("'Stop Loss or Take Profit you set must differ from market price by at least 20 points'", "languageService.tr('meta_modify_validation')"),
        ("'MODIFY'", "languageService.tr('meta_modify_button')"),
    ],
    'lib/brands/meta/meta_watchlist_screen.dart': [
        ("'No favorites yet'", "languageService.tr('meta_watchlist_no_favorites')"),
        ("'Tap  🔍  to search and add symbols'", "languageService.tr('meta_watchlist_search_hint')"),
        ("'No results'", "languageService.tr('meta_watchlist_no_results')"),
        ("'No symbols in this folder'", "languageService.tr('meta_watchlist_no_symbols_folder')"),
        ("'Cancel'", "languageService.tr('meta_watchlist_cancel')"),
        ("'Delete'", "languageService.tr('meta_watchlist_delete')"),
        ("'Selected symbols'", "languageService.tr('meta_watchlist_selected_symbols')"),
        ("'No symbols selected'", "languageService.tr('meta_watchlist_no_selection')"),
        ("'Add symbol'", "languageService.tr('meta_watchlist_add_symbol')"),
        ("'Find symbols'", "languageService.tr('meta_watchlist_find_symbols')"),
        ("'Done'", "languageService.tr('meta_watchlist_done')"),
        ("'Select all'", "languageService.tr('meta_watchlist_select_all')"),
        ("'Search'", "languageService.tr('meta_watchlist_search_btn')"),
        ("'Start typing to search'", "languageService.tr('meta_watchlist_start_typing')"),
    ],
    'lib/brands/meta/meta_history_screen.dart': [
        ("'History'", "languageService.tr('meta_history_title')"),
        ("'Empty history'", "languageService.tr('meta_history_empty')"),
        ("'Retry'", "languageService.tr('meta_history_retry')"),
        ("'Balance'", "languageService.tr('meta_history_balance')"),
        ("'Deposit'", "languageService.tr('meta_history_deposit')"),
        ("'S / L:'", "languageService.tr('meta_history_sl')"),
        ("'T / P:'", "languageService.tr('meta_history_tp')"),
        ("'Open:'", "languageService.tr('meta_history_open')"),
        ("'Swap:'", "languageService.tr('meta_history_swap')"),
        ("'Commission:'", "languageService.tr('meta_history_commission')"),
        ("'Loading more…'", "languageService.tr('meta_history_loading_more')"),
        ("'SELECT PERIOD'", "languageService.tr('meta_history_select_period')"),
        ("'SORT COLUMNS'", "languageService.tr('meta_history_sort_columns')"),
        ("'SELECT SYMBOL'", "languageService.tr('meta_history_select_symbol_filter')"),
        ("'Select symbol'", "languageService.tr('meta_history_select_symbol_hint')"),
        ("'Sort columns'", "languageService.tr('meta_history_sort_columns_hint')"),
    ],
    'lib/brands/meta/widgets/meta_native_chart.dart': [
        ("'Waiting for ticks…'", "languageService.tr('meta_chart_waiting_ticks')"),
    ],
    'lib/brands/celestial/celestial_history_screen.dart': [
        ("'History'", "languageService.tr('celestial_history_title')"),
        ("'No history for $_periodLabel'", "languageService.tr('celestial_history_no_period', {'period': '$_periodLabel'})"),
        ("'$open  →  $close'", "languageService.tr('celestial_history_open_close', {'open': '$open', 'close': '$close'})"),
    ],
    'lib/brands/celestial/celestial_watchlist_screen.dart': [
        ("'WatchList'", "languageService.tr('celestial_watchlist_title')"),
        ("'No favorites yet'", "languageService.tr('celestial_watchlist_no_favorites')"),
        ("'Tap  🔍  to search and add symbols'", "languageService.tr('celestial_watchlist_search_hint')"),
        ("'No results'", "languageService.tr('celestial_watchlist_no_results')"),
        ("'Search'", "languageService.tr('celestial_watchlist_search_btn')"),
    ],
}

total = 0
for filepath, replacements in files_to_fix.items():
    if not open(filepath, encoding='utf-8').read().strip():
        print(f"SKIP (empty): {filepath}")
        continue
    content = open(filepath, encoding='utf-8').read()
    orig = content
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
            total += 1
        # else:
        #     print(f"  NOT FOUND: {old[:50]} in {filepath}")
    if content != orig:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✓ {filepath}")
    else:
        print(f"- {filepath} (no changes)")

print(f"\nTotal replacements: {total}")
