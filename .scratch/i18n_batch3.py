"""Targeted i18n batch 3 — user-facing strings only, skip dynamic formats."""
import re, os

# Skip patterns — dynamic/format strings
DYNAMIC_PATTERNS = re.compile(r'\$[a-zA-Z_]|\$\{|\{.*\}')

def is_dynamic(s):
    return bool(DYNAMIC_PATTERNS.search(s))

repls = {
    # ── META TRADE SCREEN ──
    'lib/brands/meta/meta_trade_screen.dart': [
        ("'Trade'", "'meta_trade_trades'", "languageService.tr('meta_trade_trades')"),
        ("'Spread $spread'", "'meta_trade_spread'", "languageService.tr('meta_trade_spread', {'spread': '$spread'})"),
        ("'PRICE'", "'meta_trade_column_price'", "languageService.tr('meta_trade_column_price')"),
        ("'VOLUME'", "'meta_trade_column_volume'", "languageService.tr('meta_trade_column_volume')"),
    ],
    # ── META CLOSE POSITION SCREEN ──
    'lib/brands/meta/meta_close_position_screen.dart': [
        ("'Close position #${p.orderId}'", "'meta_close_position_label'", "languageService.tr('meta_close_position_label', {'id': '$p.orderId'})"),
        ("'Close mode'", "'meta_close_mode'", "languageService.tr('meta_close_mode')"),
        ("'Tap a − pill to close part of the position'", "'meta_close_partial_hint'", "languageService.tr('meta_close_partial_hint')"),
        ("'Fill policy'", "'meta_close_fill_policy'", "languageService.tr('meta_close_fill_policy')"),
    ],
    # ── META NEW ORDER SCREEN ──
    'lib/brands/meta/meta_new_order_screen.dart': [
        ("'Price: '", "'meta_neworder_price_label'", "languageService.tr('meta_neworder_price_label')"),
        ("'Stop Limit price: '", "'meta_neworder_stop_limit_price'", "languageService.tr('meta_neworder_stop_limit_price')"),
        ("'SELL'", "'meta_neworder_sell'", "languageService.tr('meta_neworder_sell')"),
        ("'BUY'", "'meta_neworder_buy'", "languageService.tr('meta_neworder_buy')"),
        ("'PLACE'", "'meta_neworder_place'", "languageService.tr('meta_neworder_place')"),
    ],
    # ── META MODIFY POSITION SCREEN ──
    'lib/brands/meta/meta_modify_position_screen.dart': [
        ("'Modify position #${p.orderId}'", "'meta_modify_position_label'", "languageService.tr('meta_modify_position_label', {'id': '$p.orderId'})"),
        ("'Stop Loss or Take Profit you set must differ from market price by at least 1 point'",
         "'meta_modify_validation'", "languageService.tr('meta_modify_validation')"),
        ("'MODIFY'", "'meta_modify_button'", "languageService.tr('meta_modify_button')"),
    ],
    # ── META WATCHLIST SCREEN ──
    'lib/brands/meta/meta_watchlist_screen.dart': [
        ("'Tap  🔍  to search and add symbols'", "'meta_watchlist_search_hint'", "languageService.tr('meta_watchlist_search_hint')"),
        ("'Add symbol'", "'meta_watchlist_add_symbol'", "languageService.tr('meta_watchlist_add_symbol')"),
        ("'No symbols in this folder'", "'meta_watchlist_no_symbols_folder'", "languageService.tr('meta_watchlist_no_symbols_folder')"),
        ("'$selectedCount/$totalCount'", "'meta_watchlist_selected_count'", "languageService.tr('meta_watchlist_selected_count', {'sel': '$selectedCount', 'total': '$totalCount'})"),
        ("'Selected symbols'", "'meta_watchlist_selected_symbols'", "languageService.tr('meta_watchlist_selected_symbols')"),
        ("'No symbols selected'", "'meta_watchlist_no_selection'", "languageService.tr('meta_watchlist_no_selection')"),
    ],
    # ── CELESTIAL TRADE SCREEN ──
    'lib/brands/celestial/celestial_trade_screen.dart': [
        ("'Risk Management'", "'celestial_trade_risk_management'", "languageService.tr('celestial_trade_risk_management')"),
        ("'Modify'", "'celestial_trade_modify'", "languageService.tr('celestial_trade_modify')"),
        ("'Volume'", "'celestial_trade_volume'", "languageService.tr('celestial_trade_volume')"),
        ("'CURRENT'", "'celestial_trade_current'", "languageService.tr('celestial_trade_current')"),
        ("'PRICE'", "'celestial_trade_column_price'", "languageService.tr('celestial_trade_column_price')"),
        ("'VOLUME'", "'celestial_trade_column_volume'", "languageService.tr('celestial_trade_column_volume')"),
    ],
    # ── CELESTIAL WATCHLIST SCREEN ──
    'lib/brands/celestial/celestial_watchlist_screen.dart': [
        ("'WatchList'", "'celestial_watchlist_title'", "languageService.tr('celestial_watchlist_title')"),
        ("'Tap  🔍  to search and add symbols'", "'celestial_watchlist_search_hint'", "languageService.tr('celestial_watchlist_search_hint')"),
    ],
    # ── CELESTIAL HISTORY SCREEN ──
    'lib/brands/celestial/celestial_history_screen.dart': [
        ("'No history for $_periodLabel'", "'celestial_history_no_period'", "languageService.tr('celestial_history_no_period', {'period': '$_periodLabel'})"),
        ("'$open  →  $close'", "'celestial_history_open_close'", "languageService.tr('celestial_history_open_close', {'open': '$open', 'close': '$close'})"),
    ],
}

total = 0
for filepath, entries in repls.items():
    if not os.path.exists(filepath):
        print(f"SKIP: {filepath}")
        continue
    content = open(filepath, encoding='utf-8').read()
    orig = content
    for old, key, new in entries:
        if old in content:
            content = content.replace(old, new)
            total += 1
            print(f"  ✓ {filepath}: {key}")
        else:
            print(f"  NOT FOUND {filepath}: {old[:50]}")
    if content != orig:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

print(f"\nTotal replacements: {total}")
