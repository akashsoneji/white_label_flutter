"""Batch i18n for all remaining Meta + Celestial files."""
import re, os

def process_file(filepath, replacements, import_line=None, getter_line=None):
    """Replace hardcoded strings with tr() calls in a Dart file."""
    if not os.path.exists(filepath):
        print(f"SKIP (not found): {filepath}")
        return 0
    
    content = open(filepath, encoding='utf-8').read()
    original = content
    count = 0
    
    # Add import if needed
    if import_line and import_line not in content:
        # Find last import line
        imports = re.findall(r'^import .+;$', content, re.MULTILINE)
        if imports:
            last_import = imports[-1]
            content = content.replace(last_import, last_import + '\n' + import_line)
            count += 1
    
    # Add getter if needed
    if getter_line and getter_line not in content:
        # Find a good insertion point - after last getter or in class body
        # Look for existing getters
        getters = re.findall(r'^\s+\w+ get \w+', content, re.MULTILINE)
        if getters:
            last_getter = getters[-1]
            # Find the line
            for m in re.finditer(last_getter, content):
                line_start = content.rfind('\n', 0, m.start()) + 1
                line_end = content.find('\n', m.end())
                insert_pos = line_end + 1
                content = content[:insert_pos] + '\n' + getter_line + content[insert_pos:]
                count += 1
                break
        else:
            # Insert after class declaration
            for m in re.finditer(r'class \w+.*?\{', content):
                insert_pos = m.end()
                content = content[:insert_pos] + '\n' + getter_line + content[insert_pos:]
                count += 1
                break
    
    # Apply replacements
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
            count += 1
        else:
            print(f"  NOT FOUND in {filepath}: {old[:60]}")
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✓ {filepath}: {count} changes")
    else:
        print(f"  - {filepath}: no changes")
    
    return count

# ── META CHART SCREEN ──────────────────────────────────────────
process_file(
    'lib/brands/meta/meta_chart_screen.dart',
    [
        ("'Enter Lot Size'", "languageService.tr('meta_chart_enter_lot_size')"),
        ("'Cancel'", "languageService.tr('meta_chart_cancel')"),
        ("'Select Symbol'", "languageService.tr('meta_chart_select_symbol')"),
        ("'Search...'", "languageService.tr('meta_chart_search_hint')"),
        ("'Sell'", "languageService.tr('meta_chart_sell')"),
        ("'Buy'", "languageService.tr('meta_chart_buy')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── META TRADE SCREEN ──────────────────────────────────────────
process_file(
    'lib/brands/meta/meta_trade_screen.dart',
    [
        ("'Trades'", "languageService.tr('meta_trade_trades')"),
        ("'Net P/L'", "languageService.tr('meta_trade_net_pl')"),
        ("'Positions'", "languageService.tr('meta_trade_positions')"),
        ("'Orders'", "languageService.tr('meta_trade_orders')"),
        ("'Close position'", "languageService.tr('meta_trade_close_position')"),
        ("'Modify position'", "languageService.tr('meta_trade_modify_position')"),
        ("'New order'", "languageService.tr('meta_trade_new_order')"),
        ("'Chart'", "languageService.tr('meta_trade_chart')"),
        ("'Bulk Operations…'", "languageService.tr('meta_trade_bulk_ops')"),
        ("'Error'", "languageService.tr('meta_trade_error')"),
        ("'Success'", "languageService.tr('meta_trade_success')"),
        ("'Dismiss'", "languageService.tr('meta_trade_dismiss')"),
        ("'Cancel Order'", "languageService.tr('meta_trade_cancel_order')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── META WATCHLIST SCREEN ──────────────────────────────────────
process_file(
    'lib/brands/meta/meta_watchlist_screen.dart',
    [
        ("'Quotes'", "languageService.tr('meta_watchlist_quotes')"),
        ("'Symbol'", "languageService.tr('meta_watchlist_symbol')"),
        ("'Bid'", "languageService.tr('meta_watchlist_bid')"),
        ("'Ask'", "languageService.tr('meta_watchlist_ask')"),
        ("'No favorites yet'", "languageService.tr('meta_watchlist_no_favorites')"),
        ("'No results'", "languageService.tr('meta_watchlist_no_results')"),
        ("'Cancel'", "languageService.tr('meta_watchlist_cancel')"),
        ("'Delete'", "languageService.tr('meta_watchlist_delete')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── META HISTORY SCREEN ────────────────────────────────────────
process_file(
    'lib/brands/meta/meta_history_screen.dart',
    [
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
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── META NEW ORDER SCREEN ──────────────────────────────────────
process_file(
    'lib/brands/meta/meta_new_order_screen.dart',
    [
        ("'Fill policy'", "languageService.tr('meta_neworder_fill_policy')"),
        ("'Fill or Kill'", "languageService.tr('meta_neworder_fok')"),
        ("'Expiration:'", "languageService.tr('meta_neworder_expiration')"),
        ("'BY MARKET'", "languageService.tr('meta_neworder_by_market')"),
        ("'No active account'", "languageService.tr('meta_neworder_no_active_account')"),
        ("'Order failed'", "languageService.tr('meta_neworder_order_failed')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── META CLOSE POSITION SCREEN ─────────────────────────────────
process_file(
    'lib/brands/meta/meta_close_position_screen.dart',
    [
        ("'Close position'", "languageService.tr('meta_close_position_label')"),
        ("'Fill or Kill'", "languageService.tr('meta_close_fok')"),
        ("'Immediate or Cancel'", "languageService.tr('meta_close_ioc')"),
        ("'Book or Cancel'", "languageService.tr('meta_close_boc')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── META MODIFY POSITION SCREEN ────────────────────────────────
process_file(
    'lib/brands/meta/meta_modify_position_screen.dart',
    [
        ("'Auto SL/TP Calculator'", "languageService.tr('meta_modify_auto_sl_tp')"),
        ("'Apply'", "languageService.tr('meta_modify_apply')"),
        ("'Stop Loss'", "languageService.tr('meta_modify_stop_loss')"),
        ("'Take Profit'", "languageService.tr('meta_modify_take_profit')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── CELESTIAL CHART SCREEN ─────────────────────────────────────
process_file(
    'lib/brands/celestial/celestial_chart_screen.dart',
    [
        ("'Trade'", "languageService.tr('celestial_chart_trade')"),
        ("'Enter Lot Size'", "languageService.tr('celestial_chart_enter_lot_size')"),
        ("'Cancel'", "languageService.tr('celestial_chart_cancel')"),
        ("'Select Symbol'", "languageService.tr('celestial_chart_select_symbol')"),
        ("'Search...'", "languageService.tr('celestial_chart_search_hint')"),
        ("'Sell'", "languageService.tr('celestial_chart_sell')"),
        ("'Buy'", "languageService.tr('celestial_chart_buy')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── CELESTIAL TRADE SCREEN ─────────────────────────────────────
process_file(
    'lib/brands/celestial/celestial_trade_screen.dart',
    [
        ("'Trades'", "languageService.tr('celestial_trade_trades')"),
        ("'Net P/L'", "languageService.tr('celestial_trade_net_pl')"),
        ("'Cancel Order'", "languageService.tr('celestial_trade_cancel_order')"),
        ("'Dismiss'", "languageService.tr('celestial_trade_dismiss')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

# ── CELESTIAL WATCHLIST SCREEN ─────────────────────────────────
process_file(
    'lib/brands/celestial/celestial_watchlist_screen.dart',
    [
        ("'No favorites yet'", "languageService.tr('celestial_watchlist_no_favorites')"),
        ("'No results'", "languageService.tr('celestial_watchlist_no_results')"),
    ],
    import_line="import 'package:crm_app/services/language_service.dart';",
    getter_line="  LanguageService get languageService => Get.find<LanguageService>();",
)

print("\nDone!")
