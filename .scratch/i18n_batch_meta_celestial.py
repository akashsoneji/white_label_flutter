"""Batch i18n: add keys to en.json, then replace literals with tr() in source."""
import json, re, os, copy

# ─── Load en.json ────────────────────────────────────────────────
en_path = 'assets/translations/en.json'
en = json.load(open(en_path))

# ─── 1. Define new keys (grouped by file) ────────────────────────
# Each entry: (key, english_value)
new_keys = [
    # ── meta_settings_screen.dart (29 strings) ──
    ('meta_settings_title', 'Settings'),
    ('meta_settings_verify_account', 'Verify Your Account'),
    ('meta_settings_complete_verification', 'Complete verification to unlock all features'),
    ('meta_settings_completion_pct', '$completion%'),
    ('meta_settings_version', 'Version ${snap.data!.version}'),
    ('meta_settings_logout_confirm', 'Are you sure you want to logout?'),
    ('meta_settings_delete_account_confirm', 'Are you sure you want to delete your account?'),
    ('meta_settings_enter_password', 'Enter your password'),
    ('meta_settings_deposit', 'Deposit'),
    ('meta_settings_withdraw', 'Withdraw'),
    ('meta_settings_transfer', 'Transfer'),
    ('meta_settings_history', 'History'),
    ('meta_settings_trading_account', 'Trading Account'),
    ('meta_settings_finance', 'Finance'),
    ('meta_settings_promotional', 'Promotional'),
    ('meta_settings_ib_dashboard', 'IB Dashboard'),
    ('meta_settings_copy_trading', 'Copy Trading'),
    ('meta_settings_theme', 'Theme'),
    ('meta_settings_change_password', 'Change Password'),
    ('meta_settings_two_factor_auth', 'Two-Factor Authentication'),
    ('meta_settings_one_click_trading', 'One Click Trading'),
    ('meta_settings_biometric_login', 'Biometric Login'),
    ('meta_settings_support_tickets', 'Support Tickets'),
    ('meta_settings_delete_account', 'Delete Account'),
    ('meta_settings_logout', 'Logout'),
    ('meta_settings_dialog_yes', 'Yes'),
    ('meta_settings_dialog_no', 'No'),

    # ── meta_main_shell.dart + meta_theme.dart (5 each, shared nav) ──
    ('nav_tab_quotes', 'Quotes'),
    ('nav_tab_charts', 'Charts'),
    ('nav_tab_trade', 'Trade'),
    ('nav_tab_history', 'History'),
    ('nav_tab_settings', 'Settings'),

    # ── meta_chart_screen.dart (9 strings) ──
    ('meta_chart_trade', 'Trade'),
    ('meta_chart_enter_lot_size', 'Enter Lot Size'),
    ('meta_chart_cancel', 'Cancel'),
    ('meta_chart_select_symbol', 'Select Symbol'),
    ('meta_chart_search_hint', 'Search...'),
    ('meta_chart_sell', 'Sell'),
    ('meta_chart_buy', 'Buy'),
    ('meta_chart_day_high', 'H: ${price.dayHigh.toStringAsFixed(digits)}'),
    ('meta_chart_day_low', 'L: ${price.dayLow.toStringAsFixed(digits)}'),

    # ── meta_close_position_screen.dart (8 strings) ──
    ('meta_close_failed', 'Close failed: $e'),
    ('meta_close_position_id', 'Close position #${p.orderId}'),
    ('meta_close_mode', 'Close mode'),
    ('meta_close_partial_hint', 'Tap a − pill to close part of the position'),
    ('meta_close_fill_policy', 'Fill policy'),
    ('meta_close_fok', 'Fill or Kill'),
    ('meta_close_ioc', 'Immediate or Cancel'),
    ('meta_close_boc', 'Book or Cancel'),

    # ── meta_new_order_screen.dart (11 strings) ──
    ('meta_neworder_price_label', 'Price: '),
    ('meta_neworder_stop_limit_price', 'Stop Limit price: '),
    ('meta_neworder_fill_policy', 'Fill policy'),
    ('meta_neworder_fok', 'Fill or Kill'),
    ('meta_neworder_expiration', 'Expiration:'),
    ('meta_neworder_by_market', 'BY MARKET'),
    ('meta_neworder_no_active_account', 'No active account'),
    ('meta_neworder_order_failed', 'Order failed'),
    ('meta_neworder_error', 'Error'),
    ('meta_neworder_refreshed', 'Refreshed'),

    # ── meta_trade_screen.dart (24 strings) ──
    ('meta_trade_trades', 'Trades'),
    ('meta_trade_net_pl', 'Net P/L'),
    ('meta_trade_count', '$count'),
    ('meta_trade_price_change', '${_fmt(entry, p.digits)}  →  ${_fmt(cur, p.digits)}'),
    ('meta_trade_label_value', '$label $value'),
    ('meta_trade_lots', '${p.volume.toStringAsFixed(2)} lot'),
    ('meta_trade_entry_price', 'Price: ${_fmt(_d(p.entryPrice), p.digits)}'),
    ('meta_trade_price_arrow', '  →  ${_fmt(_d(p.currentPrice), p.digits)}'),
    ('meta_trade_cancel_order', 'Cancel Order'),
    ('meta_trade_dismiss', 'Dismiss'),
    ('meta_trade_spread', 'Spread $spread'),
    ('meta_trade_error', 'Error'),
    ('meta_trade_success', 'Success'),
    ('meta_trade_positions', 'Positions'),
    ('meta_trade_orders', 'Orders'),
    ('meta_trade_close_position', 'Close position'),
    ('meta_trade_modify_position', 'Modify position'),
    ('meta_trade_new_order', 'New order'),
    ('meta_trade_chart', 'Chart'),
    ('meta_trade_bulk_ops', 'Bulk Operations…'),
    ('meta_trade_order_id', '#${p.orderId}'),
    ('meta_trade_add_ticket', 'Add ticket'),
    ('meta_trade_volume', 'Volume'),
    ('meta_trade_risk_management', 'Risk Management'),
    ('meta_trade_modify', 'Modify'),

    # ── meta_watchlist_screen.dart (26 strings) ──
    ('meta_watchlist_symbol_action', '${item.symbol}: ${action.name}'),
    ('meta_watchlist_quotes', 'Quotes'),
    ('meta_watchlist_symbol', 'Symbol'),
    ('meta_watchlist_bid', 'Bid'),
    ('meta_watchlist_ask', 'Ask'),
    ('meta_watchlist_no_favorites', 'No favorites yet'),
    ('meta_watchlist_search_hint', 'Tap  🔍  to search and add symbols'),
    ('meta_watchlist_day_low', 'L: ${price.dayLow.toStringAsFixed(digits)}'),
    ('meta_watchlist_day_high', 'H: ${price.dayHigh.toStringAsFixed(digits)}'),
    ('meta_watchlist_add_symbol', 'Add symbol'),
    ('meta_watchlist_no_results', 'No results'),
    ('meta_watchlist_no_symbols_folder', 'No symbols in this folder'),
    ('meta_watchlist_selected_count', '$selectedCount/$totalCount'),
    ('meta_watchlist_remove_symbols', 'Remove symbols'),
    ('meta_watchlist_remove_confirm', 'Remove ${_checked.length} symbol(s) from your watchlist?'),
    ('meta_watchlist_cancel', 'Cancel'),
    ('meta_watchlist_delete', 'Delete'),
    ('meta_watchlist_selected_symbols', 'Selected symbols'),
    ('meta_watchlist_no_selection', 'No symbols selected'),
    ('meta_watchlist_symbol_category', '${symbol.symbol}: ${symbol.category}'),
    ('meta_watchlist_find_symbols', 'Find symbols'),
    ('meta_watchlist_done', 'Done'),
    ('meta_watchlist_select_all', 'Select all'),
    ('meta_watchlist_search', 'Search'),
    ('meta_watchlist_start_typing', 'Start typing to search'),

    # ── meta_history_screen.dart (17 strings) ──
    ('meta_history_title', 'History'),
    ('meta_history_empty', 'Empty history'),
    ('meta_history_retry', 'Retry'),
    ('meta_history_balance', 'Balance'),
    ('meta_history_deposit', 'Deposit'),
    ('meta_history_sl', 'S / L:'),
    ('meta_history_tp', 'T / P:'),
    ('meta_history_open', 'Open:'),
    ('meta_history_swap', 'Swap:'),
    ('meta_history_commission', 'Commission:'),
    ('meta_history_loading_more', 'Loading more…'),
    ('meta_history_select_period', 'SELECT PERIOD'),
    ('meta_history_sort_columns', 'SORT COLUMNS'),
    ('meta_history_select_symbol', 'SELECT SYMBOL'),
    ('meta_history_row_symbol', '${row.tradeSymbol}, '),
    ('meta_history_select_symbol_filter', 'Select symbol'),
    ('meta_history_sort_columns_filter', 'Sort columns'),

    # ── meta_modify_position_screen.dart (6 strings) ──
    ('meta_modify_failed', 'Modify failed: $e'),
    ('meta_modify_position_id', 'Modify position #${p.orderId}'),
    ('meta_modify_auto_sl_tp', 'Auto SL/TP Calculator'),
    ('meta_modify_apply', 'Apply'),
    ('meta_modify_stop_loss', 'Stop Loss'),
    ('meta_modify_take_profit', 'Take Profit'),

    # ── widgets/meta_native_chart.dart ──
    ('meta_chart_waiting_ticks', 'Waiting for ticks…'),

    # ── celestial_settings_screen.dart (29 strings) ──
    ('celestial_settings_title', 'Settings'),
    ('celestial_settings_verify_account', 'Verify Your Account'),
    ('celestial_settings_complete_verification', 'Complete verification to unlock all features'),
    ('celestial_settings_completion_pct', '$completion%'),
    ('celestial_settings_version', 'Version ${snap.data!.version}'),
    ('celestial_settings_logout_confirm', 'Are you sure you want to logout?'),
    ('celestial_settings_delete_account_confirm', 'Are you sure you want to delete your account?'),
    ('celestial_settings_enter_password', 'Enter your password'),
    ('celestial_settings_deposit', 'Deposit'),
    ('celestial_settings_withdraw', 'Withdraw'),
    ('celestial_settings_transfer', 'Transfer'),
    ('celestial_settings_history', 'History'),
    ('celestial_settings_trading_account', 'Trading Account'),
    ('celestial_settings_finance', 'Finance'),
    ('celestial_settings_promotional', 'Promotional'),
    ('celestial_settings_ib_dashboard', 'IB Dashboard'),
    ('celestial_settings_copy_trading', 'Copy Trading'),
    ('celestial_settings_theme', 'Theme'),
    ('celestial_settings_change_password', 'Change Password'),
    ('celestial_settings_two_factor_auth', 'Two-Factor Authentication'),
    ('celestial_settings_one_click_trading', 'One Click Trading'),
    ('celestial_settings_biometric_login', 'Biometric Login'),
    ('celestial_settings_support_tickets', 'Support Tickets'),
    ('celestial_settings_delete_account', 'Delete Account'),
    ('celestial_settings_logout', 'Logout'),
    ('celestial_settings_dialog_yes', 'Yes'),
    ('celestial_settings_dialog_no', 'No'),

    # ── celestial_main_shell.dart + celestial_theme.dart (shared nav) ──
    # (nav_tab_* keys already defined above — reuse them)

    # ── celestial_chart_screen.dart (7 strings) ──
    ('celestial_chart_trade', 'Trade'),
    ('celestial_chart_enter_lot_size', 'Enter Lot Size'),
    ('celestial_chart_cancel', 'Cancel'),
    ('celestial_chart_select_symbol', 'Select Symbol'),
    ('celestial_chart_search_hint', 'Search...'),
    ('celestial_chart_sell', 'Sell'),
    ('celestial_chart_buy', 'Buy'),

    # ── celestial_history_screen.dart (3 strings) ──
    ('celestial_history_title', 'History'),
    ('celestial_history_no_period', 'No history for $_periodLabel'),
    ('celestial_history_open_close', '$open  →  $close'),

    # ── celestial_trade_screen.dart (23 strings) ──
    ('celestial_trade_trades', 'Trades'),
    ('celestial_trade_net_pl', 'Net P/L'),
    ('celestial_trade_count', '$count'),
    ('celestial_trade_price_change', '${_fmt(entry, p.digits)}  →  ${_fmt(cur, p.digits)}'),
    ('celestial_trade_label_value', '$label $value'),
    ('celestial_trade_lots', '${p.volume.toStringAsFixed(2)} lot'),
    ('celestial_trade_entry_price', 'Price: ${_fmt(_d(p.entryPrice), p.digits)}'),
    ('celestial_trade_price_arrow', '  →  ${_fmt(_d(p.currentPrice), p.digits)}'),
    ('celestial_trade_cancel_order', 'Cancel Order'),
    ('celestial_trade_dismiss', 'Dismiss'),
    ('celestial_trade_spread', 'Spread $spread'),
    ('celestial_trade_error', 'Error'),
    ('celestial_trade_success', 'Success'),
    ('celestial_trade_volume', 'Volume'),
    ('celestial_trade_risk_management', 'Risk Management'),
    ('celestial_trade_modify', 'Modify'),
    ('celestial_trade_order_id', '#${p.orderId}'),
    ('celestial_trade_label_colon', '$label:'),

    # ── celestial_watchlist_screen.dart (7 strings) ──
    ('celestial_watchlist_title', 'WatchList'),
    ('celestial_watchlist_no_favorites', 'No favorites yet'),
    ('celestial_watchlist_search_hint', 'Tap  🔍  to search and add symbols'),
    ('celestial_watchlist_day_low', 'L: ${price.dayLow.toStringAsFixed(digits)}'),
    ('celestial_watchlist_day_high', 'H: ${price.dayHigh.toStringAsFixed(digits)}'),
    ('celestial_watchlist_no_results', 'No results'),
    ('celestial_watchlist_search_btn', 'Search'),

    # ── shared: settings_screen.dart ──
    ('settings_title', 'Settings'),
    ('settings_logout_confirm', 'Are you sure you want to logout?'),
    ('settings_delete_account_confirm', 'Are you sure you want to delete your account?'),
    ('settings_enter_password', 'Enter your password'),
    ('settings_deposit', 'Deposit'),
    ('settings_withdraw', 'Withdraw'),
    ('settings_transfer', 'Transfer'),
    ('settings_history', 'History'),
    ('settings_trading_account', 'Trading Account'),
    ('settings_finance', 'Finance'),
    ('settings_promotional', 'Promotional'),
    ('settings_ib_dashboard', 'IB Dashboard'),
    ('settings_copy_trading', 'Copy Trading'),
    ('settings_theme', 'Theme'),
    ('settings_change_password', 'Change Password'),
    ('settings_two_factor_auth', 'Two-Factor Authentication'),
    ('settings_one_click_trading', 'One Click Trading'),
    ('settings_biometric_login', 'Biometric Login'),
    ('settings_support_tickets', 'Support Tickets'),
    ('settings_delete_account', 'Delete Account'),
    ('settings_logout', 'Logout'),
    ('settings_yes', 'Yes'),
    ('settings_no', 'No'),
    ('settings_verify_account', 'Verify Your Account'),
    ('settings_complete_verification', 'Complete verification to unlock all features'),
    ('settings_completion_pct', '$completion%'),
    ('settings_version', 'Version ${snap.data!.version}'),
    ('settings_error', 'Error'),
    ('settings_success', 'Success'),
    ('settings_privacy_policy', 'Privacy Policy'),
    ('settings_create_trading_account', 'Create Trading Account'),

    # ── shared: auth screens ──
    ('auth_error', 'Error'),
    ('auth_success', 'Success'),
    ('auth_search_hint', 'Start typing to search'),
    ('auth_search_btn', 'Search'),
    ('auth_referrer_code', 'Referrer Code'),
    ('auth_create_password_title', 'Create New Password'),
    ('auth_create_password_instruction', 'Your new password must be different from previously used passwords.'),
    ('auth_enter_new_password', 'Enter new password'),
    ('auth_confirm_new_password', 'Confirm new password'),
    ('auth_new_password_label', 'New Password'),
    ('auth_confirm_password_label', 'Confirm Password'),

    # ── shared: trading controller ──
    ('trading_error', 'Error'),
    ('trading_success', 'Success'),
    ('trading_cancel_order', 'Cancel Order'),
    ('trading_dismiss', 'Dismiss'),

    # ── nav_tab keys (already added, ensuring no dupes) ──
    ('nav_tab_watchlist', 'WatchList'),
    ('nav_tab_trade_alt', 'Trade'),
]

# ─── 2. Add keys to en.json ──────────────────────────────────────
added = 0
for key, value in new_keys:
    if key not in en:
        en[key] = value
        added += 1

with open(en_path, 'w', encoding='utf-8') as f:
    json.dump(en, f, ensure_ascii=False, indent=2)
print(f'en.json: added {added} new keys, total = {len(en)}')

# ─── 3. Source replacement config ────────────────────────────────
# (file_path, list of (key, original_literal))
# Literals must match EXACTLY including $interpolations and spaces.
replacements = {
    # ── meta_settings_screen.dart ──
    'lib/brands/meta/meta_settings_screen.dart': [
        ('meta_settings_title', 'Settings'),
        ('meta_settings_verify_account', 'Verify Your Account'),
        ('meta_settings_complete_verification', 'Complete verification to unlock all features'),
        ('meta_settings_completion_pct', '$completion%'),
        ('meta_settings_version', 'Version ${snap.data!.version}'),
        ('meta_settings_logout_confirm', 'Are you sure you want to logout?'),
        ('meta_settings_delete_account_confirm', 'Are you sure you want to delete your account?'),
        ('meta_settings_enter_password', 'Enter your password'),
        ('meta_settings_deposit', 'Deposit'),
        ('meta_settings_withdraw', 'Withdraw'),
        ('meta_settings_transfer', 'Transfer'),
        ('meta_settings_history', 'History'),
        ('meta_settings_trading_account', 'Trading Account'),
        ('meta_settings_finance', 'Finance'),
        ('meta_settings_promotional', 'Promotional'),
        ('meta_settings_ib_dashboard', 'IB Dashboard'),
        ('meta_settings_copy_trading', 'Copy Trading'),
        ('meta_settings_theme', 'Theme'),
        ('meta_settings_change_password', 'Change Password'),
        ('meta_settings_two_factor_auth', 'Two-Factor Authentication'),
        ('meta_settings_one_click_trading', 'One Click Trading'),
        ('meta_settings_biometric_login', 'Biometric Login'),
        ('meta_settings_support_tickets', 'Support Tickets'),
        ('meta_settings_delete_account', 'Delete Account'),
        ('meta_settings_logout', 'Logout'),
        ('meta_settings_yes', 'Yes'),
        ('meta_settings_no', 'No'),
    ],
    # ── meta_main_shell.dart ──
    'lib/brands/meta/meta_main_shell.dart': [
        ('nav_tab_quotes', 'Quotes'),
        ('nav_tab_charts', 'Charts'),
        ('nav_tab_trade', 'Trade'),
        ('nav_tab_history', 'History'),
        ('nav_tab_settings', 'Settings'),
    ],
    # ── meta_theme.dart ──
    'lib/brands/meta/meta_theme.dart': [
        ('nav_tab_quotes', 'Quotes'),
        ('nav_tab_charts', 'Charts'),
        ('nav_tab_trade', 'Trade'),
        ('nav_tab_history', 'History'),
        ('nav_tab_settings', 'Settings'),
    ],
    # ── meta_chart_screen.dart ──
    'lib/brands/meta/meta_chart_screen.dart': [
        ('meta_chart_trade', 'Trade'),
        ('meta_chart_enter_lot_size', 'Enter Lot Size'),
        ('meta_chart_cancel', 'Cancel'),
        ('meta_chart_select_symbol', 'Select Symbol'),
        ('meta_chart_search_hint', 'Search...'),
        ('meta_chart_sell', 'Sell'),
        ('meta_chart_buy', 'Buy'),
        ('meta_chart_day_high', 'H: ${price.dayHigh.toStringAsFixed(digits)}'),
        ('meta_chart_day_low', 'L: ${price.dayLow.toStringAsFixed(digits)}'),
    ],
    # ── meta_trade_screen.dart ──
    'lib/brands/meta/meta_trade_screen.dart': [
        ('meta_trade_trades', 'Trades'),
        ('meta_trade_net_pl', 'Net P/L'),
        ('meta_trade_positions', 'Positions'),
        ('meta_trade_orders', 'Orders'),
        ('meta_trade_close_position', 'Close position'),
        ('meta_trade_modify_position', 'Modify position'),
        ('meta_trade_new_order', 'New order'),
        ('meta_trade_chart', 'Chart'),
        ('meta_trade_bulk_ops', 'Bulk Operations…'),
        ('meta_trade_error', 'Error'),
        ('meta_trade_success', 'Success'),
        ('meta_trade_dismiss', 'Dismiss'),
        ('meta_trade_cancel_order', 'Cancel Order'),
        ('meta_trade_modify', 'Modify'),
        ('meta_trade_volume', 'Volume'),
        ('meta_trade_risk_management', 'Risk Management'),
        ('meta_trade_spread', 'Spread $spread'),
        ('meta_trade_add_ticket', 'Add ticket'),
    ],
    # ── meta_watchlist_screen.dart ──
    'lib/brands/meta/meta_watchlist_screen.dart': [
        ('meta_watchlist_quotes', 'Quotes'),
        ('meta_watchlist_symbol', 'Symbol'),
        ('meta_watchlist_bid', 'Bid'),
        ('meta_watchlist_ask', 'Ask'),
        ('meta_watchlist_no_favorites', 'No favorites yet'),
        ('meta_watchlist_search_hint', 'Tap  🔍  to search and add symbols'),
        ('meta_watchlist_day_low', 'L: ${price.dayLow.toStringAsFixed(digits)}'),
        ('meta_watchlist_day_high', 'H: ${price.dayHigh.toStringAsFixed(digits)}'),
        ('meta_watchlist_add_symbol', 'Add symbol'),
        ('meta_watchlist_no_results', 'No results'),
        ('meta_watchlist_no_symbols_folder', 'No symbols in this folder'),
        ('meta_watchlist_selected_count', '$selectedCount/$totalCount'),
        ('meta_watchlist_remove_symbols', 'Remove symbols'),
        ('meta_watchlist_remove_confirm', 'Remove ${_checked.length} symbol(s) from your watchlist?'),
        ('meta_watchlist_cancel', 'Cancel'),
        ('meta_watchlist_delete', 'Delete'),
        ('meta_watchlist_selected_symbols', 'Selected symbols'),
        ('meta_watchlist_no_selection', 'No symbols selected'),
        ('meta_watchlist_symbol_category', '${symbol.symbol}: ${symbol.category}'),
        ('meta_watchlist_find_symbols', 'Find symbols'),
        ('meta_watchlist_done', 'Done'),
        ('meta_watchlist_select_all', 'Select all'),
        ('meta_watchlist_search_btn', 'Search'),
        ('meta_watchlist_start_typing', 'Start typing to search'),
    ],
    # ── meta_history_screen.dart ──
    'lib/brands/meta/meta_history_screen.dart': [
        ('meta_history_title', 'History'),
        ('meta_history_empty', 'Empty history'),
        ('meta_history_retry', 'Retry'),
        ('meta_history_balance', 'Balance'),
        ('meta_history_deposit', 'Deposit'),
        ('meta_history_sl', 'S / L:'),
        ('meta_history_tp', 'T / P:'),
        ('meta_history_open', 'Open:'),
        ('meta_history_swap', 'Swap:'),
        ('meta_history_commission', 'Commission:'),
        ('meta_history_loading_more', 'Loading more…'),
        ('meta_history_select_period', 'SELECT PERIOD'),
        ('meta_history_sort_columns', 'SORT COLUMNS'),
        ('meta_history_select_symbol_filter', 'SELECT SYMBOL'),
        ('meta_history_select_symbol_hint', 'Select symbol'),
        ('meta_history_sort_columns_hint', 'Sort columns'),
        ('meta_history_row_symbol', '${row.tradeSymbol}, '),
    ],
    # ── meta_new_order_screen.dart ──
    'lib/brands/meta/meta_new_order_screen.dart': [
        ('meta_neworder_price_label', 'Price: '),
        ('meta_neworder_stop_limit_price', 'Stop Limit price: '),
        ('meta_neworder_fill_policy', 'Fill policy'),
        ('meta_neworder_fok', 'Fill or Kill'),
        ('meta_neworder_expiration', 'Expiration:'),
        ('meta_neworder_by_market', 'BY MARKET'),
        ('meta_neworder_no_active_account', 'No active account'),
        ('meta_neworder_order_failed', 'Order failed'),
        ('meta_neworder_error', 'Error'),
        ('meta_neworder_refreshed', 'Refreshed'),
    ],
    # ── meta_close_position_screen.dart ──
    'lib/brands/meta/meta_close_position_screen.dart': [
        ('meta_close_failed', 'Close failed: $e'),
        ('meta_close_position_id', 'Close position #${p.orderId}'),
        ('meta_close_mode', 'Close mode'),
        ('meta_close_partial_hint', 'Tap a − pill to close part of the position'),
        ('meta_close_fill_policy', 'Fill policy'),
        ('meta_close_fok', 'Fill or Kill'),
        ('meta_close_ioc', 'Immediate or Cancel'),
        ('meta_close_boc', 'Book or Cancel'),
    ],
    # ── meta_modify_position_screen.dart ──
    'lib/brands/meta/meta_modify_position_screen.dart': [
        ('meta_modify_failed', 'Modify failed: $e'),
        ('meta_modify_position_id', 'Modify position #${p.orderId}'),
        ('meta_modify_auto_sl_tp', 'Auto SL/TP Calculator'),
        ('meta_modify_apply', 'Apply'),
        ('meta_modify_stop_loss', 'Stop Loss'),
        ('meta_modify_take_profit', 'Take Profit'),
    ],
    # ── widgets/meta_native_chart.dart ──
    'lib/brands/meta/widgets/meta_native_chart.dart': [
        ('meta_chart_waiting_ticks', 'Waiting for ticks…'),
    ],

    # ── celestial_settings_screen.dart ──
    'lib/brands/celestial/celestial_settings_screen.dart': [
        ('celestial_settings_title', 'Settings'),
        ('celestial_settings_verify_account', 'Verify Your Account'),
        ('celestial_settings_complete_verification', 'Complete verification to unlock all features'),
        ('celestial_settings_completion_pct', '$completion%'),
        ('celestial_settings_version', 'Version ${snap.data!.version}'),
        ('celestial_settings_logout_confirm', 'Are you sure you want to logout?'),
        ('celestial_settings_delete_account_confirm', 'Are you sure you want to delete your account?'),
        ('celestial_settings_enter_password', 'Enter your password'),
        ('celestial_settings_deposit', 'Deposit'),
        ('celestial_settings_withdraw', 'Withdraw'),
        ('celestial_settings_transfer', 'Transfer'),
        ('celestial_settings_history', 'History'),
        ('celestial_settings_trading_account', 'Trading Account'),
        ('celestial_settings_finance', 'Finance'),
        ('celestial_settings_promotional', 'Promotional'),
        ('celestial_settings_ib_dashboard', 'IB Dashboard'),
        ('celestial_settings_copy_trading', 'Copy Trading'),
        ('celestial_settings_theme', 'Theme'),
        ('celestial_settings_change_password', 'Change Password'),
        ('celestial_settings_two_factor_auth', 'Two-Factor Authentication'),
        ('celestial_settings_one_click_trading', 'One Click Trading'),
        ('celestial_settings_biometric_login', 'Biometric Login'),
        ('celestial_settings_support_tickets', 'Support Tickets'),
        ('celestial_settings_delete_account', 'Delete Account'),
        ('celestial_settings_logout', 'Logout'),
        ('celestial_settings_yes', 'Yes'),
        ('celestial_settings_no', 'No'),
    ],
    # ── celestial_main_shell.dart ──
    'lib/brands/celestial/celestial_main_shell.dart': [
        ('nav_tab_watchlist', 'WatchList'),
        ('nav_tab_charts', 'Chart'),
        ('nav_tab_trade', 'Trade'),
        ('nav_tab_history', 'History'),
        ('nav_tab_settings', 'Settings'),
    ],
    # ── celestial_theme.dart ──
    'lib/brands/celestial/celestial_theme.dart': [
        ('nav_tab_watchlist', 'WatchList'),
        ('nav_tab_charts', 'Chart'),
        ('nav_tab_trade', 'Trade'),
        ('nav_tab_history', 'History'),
        ('nav_tab_settings', 'Settings'),
    ],
    # ── celestial_chart_screen.dart ──
    'lib/brands/celestial/celestial_chart_screen.dart': [
        ('celestial_chart_trade', 'Trade'),
        ('celestial_chart_enter_lot_size', 'Enter Lot Size'),
        ('celestial_chart_cancel', 'Cancel'),
        ('celestial_chart_select_symbol', 'Select Symbol'),
        ('celestial_chart_search_hint', 'Search...'),
        ('celestial_chart_sell', 'Sell'),
        ('celestial_chart_buy', 'Buy'),
    ],
    # ── celestial_trade_screen.dart ──
    'lib/brands/celestial/celestial_trade_screen.dart': [
        ('celestial_trade_trades', 'Trades'),
        ('celestial_trade_net_pl', 'Net P/L'),
        ('celestial_trade_cancel_order', 'Cancel Order'),
        ('celestial_trade_dismiss', 'Dismiss'),
        ('celestial_trade_error', 'Error'),
        ('celestial_trade_success', 'Success'),
    ],
    # ── celestial_watchlist_screen.dart ──
    'lib/brands/celestial/celestial_watchlist_screen.dart': [
        ('celestial_watchlist_title', 'WatchList'),
        ('celestial_watchlist_no_favorites', 'No favorites yet'),
        ('celestial_watchlist_search_hint', 'Tap  🔍  to search and add symbols'),
        ('celestial_watchlist_day_low', 'L: ${price.dayLow.toStringAsFixed(digits)}'),
        ('celestial_watchlist_day_high', 'H: ${price.dayHigh.toStringAsFixed(digits)}'),
        ('celestial_watchlist_no_results', 'No results'),
        ('celestial_watchlist_search_btn', 'Search'),
    ],
    # ── celestial_history_screen.dart ──
    'lib/brands/celestial/celestial_history_screen.dart': [
        ('celestial_history_title', 'History'),
        ('celestial_history_no_period', 'No history for $_periodLabel'),
        ('celestial_history_open_close', '$open  →  $close'),
    ],
}

# ─── 4. Apply replacements ───────────────────────────────────────
total_replaced = 0
for filepath, reps in replacements.items():
    if not os.path.exists(filepath):
        print(f'  SKIP (not found): {filepath}')
        continue
    content = open(filepath, encoding='utf-8').read()
    file_replaced = 0
    for key, literal in reps:
        # Replace literal with tr() call
        replacement = f"Get.find<LanguageService>().tr('{key}')"
        count = content.count(literal)
        if count == 0:
            print(f'  NOT FOUND in {filepath}: {literal[:50]}')
            continue
        content = content.replace(literal, replacement)
        file_replaced += count
    if file_replaced > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'  ✓ {filepath}: {file_replaced} replacements')
    else:
        print(f'  ⚠ {filepath}: 0 replacements (maybe already done or literal changed)')
    total_replaced += file_replaced

print(f'\nTotal replacements: {total_replaced}')
