#!/usr/bin/env python3
"""
Generate the final curation of new Vantage-tree translation keys
from the scanner output, then produce:
  - vantage_keys_final.json  (key -> value, with source location)
  - vantage_edits.py (a Python script that applies the source-code replacements)
"""
import json, os, re, sys
from collections import OrderedDict

PROJECT_ROOT = os.path.abspath("/Users/admin/Desktop/Project/white_label/app/white_label")

with open("/tmp/vantage_new_keys.json", encoding="utf-8") as f:
    proposed = json.load(f)

# Manual curation: drop false positives.
# Drop: instrument "L: " / "H: " (one-char-style labels), their meaningful display
# is handled by the sort-options list and dayLow/dayHigh - rename them.
DROPS = {
    "instruments_screen",   # L:
    "instruments_screen_2", # H:
}

# Re-key L:/H: to something sensible
REDEFS = {
    "instruments_screen": "instruments_day_low_label",
    "instruments_screen_2": "instruments_day_high_label",
}

# Curate
final = OrderedDict()
for key, payload in proposed.items():
    if key in DROPS:
        continue
    if key in REDEFS:
        key = REDEFS[key]
        payload["value"] = {
            "instruments_day_low_label": "L:",
            "instruments_day_high_label": "H:",
        }[key]
    final[key] = payload

# Manually add all strings that the scanner missed (read directly from source)
MANUAL_ADD = OrderedDict([
    # --- login_screen.dart ---
    ("login_screen_sign_in", {
        "value": "Sign In",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/login_screen.dart",
        "first_line": 120,
        "note": "Header Text in VantageLoginScreen",
    }),
    ("login_screen_dont_have_account", {
        "value": "Don't have an account?",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/login_screen.dart",
        "first_line": 105,
        "note": "Bottom TextSpan",
    }),
    ("login_screen_forgot_password", {
        "value": "Forgot Password?",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/login_screen.dart",
        "first_line": 153,
        "note": "Forgot password TextButton",
    }),
    # --- get_started_screen.dart ---
    ("get_started_tagline", {
        "value": "Every trader managed. One secure window.",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/get_started_screen.dart",
        "first_line": 40,
        "note": "Tagline Text",
    }),
    # --- create_account_screen.dart ---
    ("create_account_screen_title", {
        "value": "Create Account",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 230,
        "note": "Header",
    }),
    ("create_account_screen_first_name", {
        "value": "First Name",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 244,
        "note": "VantagePillTextField hint",
    }),
    ("create_account_screen_last_name", {
        "value": "Last Name",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 255,
        "note": "VantagePillTextField hint",
    }),
    ("create_account_screen_phone_number", {
        "value": "Phone number",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 271,
        "note": "VantagePillTextField hint / TextFormField decoration",
    }),
    ("create_account_screen_email", {
        "value": "Email",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 287,
        "note": "VantagePillTextField hint",
    }),
    ("create_account_screen_password", {
        "value": "Password",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 299,
        "note": "VantagePillTextField hint",
    }),
    ("create_account_screen_sign_up", {
        "value": "Sign Up",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 382,
        "note": "VantagePrimaryButton text",
    }),
    ("create_account_screen_already_have_account", {
        "value": "Already have an account?",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 397,
        "note": "Text.rich leading text",
    }),
    ("create_account_screen_agree_terms", {
        "value": "By signing up you agree to Terms & Conditions and Privacy Policy.",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart",
        "first_line": 406,
        "note": "Terms footer text",
    }),
    # --- forgot_password_screen.dart ---
    ("forgot_password_screen_title", {
        "value": "Forgot password",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/forgot_password_screen.dart",
        "first_line": 65,
        "note": "Header",
    }),
    ("forgot_password_screen_remember_password", {
        "value": "You remember your password?",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/forgot_password_screen.dart",
        "first_line": 50,
        "note": "Bottom link TextSpan",
    }),
    ("forgot_password_screen_email", {
        "value": "Email",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/forgot_password_screen.dart",
        "first_line": 85,
        "note": "VantagePillTextField hint",
    }),
    ("forgot_password_screen_send_otp", {
        "value": "Send OTP",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/forgot_password_screen.dart",
        "first_line": 94,
        "note": "VantagePrimaryButton text",
    }),
    # --- verify_code_screen.dart ---
    ("verify_code_screen_title", {
        "value": "Verify Code",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/verify_code_screen.dart",
        "first_line": 143,
        "note": "Header",
    }),
    ("verify_code_screen_subtitle", {
        "value": "Please enter the code we just sent to email\n${widget.email}",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/verify_code_screen.dart",
        "first_line": 151,
        "note": "Subtitle — interpolation with email; kept as hardcoded string (user supplies email)",
    }),
    ("verify_code_screen_verify", {
        "value": "Verify",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/verify_code_screen.dart",
        "first_line": 165,
        "note": "VantagePrimaryButton text",
    }),
    ("verify_code_screen_resend", {
        "value": "Resend Code",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/verify_code_screen.dart",
        "first_line": 175,
        "note": "Resend TextButton",
    }),
    # --- create_new_password_screen.dart ---
    ("create_new_password_title", {
        "value": "Create new Password",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart",
        "first_line": 87,
        "note": "Header",
    }),
    ("create_new_password_instruction", {
        "value": "Your new password must be different from\nprevious password.",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart",
        "first_line": 96,
        "note": "Instruction text",
    }),
    ("create_new_password_confirm_password", {
        "value": "Confirm Password",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart",
        "first_line": 116,
        "note": "VantagePillTextField hint",
    }),
    ("create_new_password_validation_length", {
        "value": "Password must be at least 8 characters",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart",
        "first_line": 131,
        "note": "Validator message",
    }),
    ("create_new_password_validation_confirm", {
        "value": "Please confirm your password",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart",
        "first_line": 143,
        "note": "Validator message",
    }),
    ("create_new_password_validation_mismatch", {
        "value": "Passwords do not match",
        "first_file": "lib/screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart",
        "first_line": 147,
        "note": "Validator message",
    }),
    # --- vantage_pending_order_content.dart ---
    ("pending_order_quantity_label", {
        "value": "Quantity",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 662,
        "note": "Row header",
    }),
    ("pending_order_trigger_price_label", {
        "value": "Trigger price",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 668,
        "note": "Row header",
    }),
    ("pending_order_risk_management_label", {
        "value": "Risk management",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 685,
        "note": "Row header",
    }),
    ("pending_order_market_execution_label", {
        "value": "Market execution",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 547,
        "note": "SummaryPill label",
    }),
    ("pending_order_buy_limit", {
        "value": "Buy limit",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 752,
        "note": "Segmented button",
    }),
    ("pending_order_sell_limit", {
        "value": "Sell limit",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 800,
        "note": "Segmented button",
    }),
    ("pending_order_enter_lots", {
        "value": "Enter lots",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 835,
        "note": "Stepper hintText",
    }),
    ("pending_order_lots_label", {
        "value": "Lots",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 835,
        "note": "Stepper labelText",
    }),
    ("pending_order_place_order", {
        "value": "Place pending order",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 515,
        "note": "CTA button (enabled state)",
    }),
    ("pending_order_fix_validation", {
        "value": "Fix validation errors",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 516,
        "note": "CTA button (disabled state)",
    }),
    ("pending_order_processing", {
        "value": "Processing...",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 473,
        "note": "Loading text",
    }),
    ("pending_order_take_profit_label", {
        "value": "Take Profit",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 974,
        "note": "SwitchTile title",
    }),
    ("pending_order_stop_loss_label", {
        "value": "Stop Loss",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 1014,
        "note": "SwitchTile title",
    }),
    ("pending_order_potential_profit_at_tp", {
        "value": "Potential Profit at TP",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 990,
        "note": "PnL label",
    }),
    ("pending_order_potential_loss_at_sl", {
        "value": "Potential Loss at SL",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 1032,
        "note": "PnL label",
    }),
    ("pending_order_price_label", {
        "value": "pending_order_price",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_content.dart",
        "first_line": 860,
        "note": "_stepperTextField labelText — already a tr('pending_order_price') key, keep the literal as-is because it's already translated by name",
        "SKIP": True,
    }),
    # --- vantage_transaction_history_screen.dart ---
    ("transaction_history_filter", {
        "value": "Filter",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 174,
        "note": "Filter button",
    }),
    ("transaction_history_account_label", {
        "value": "Account",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 186,
        "note": "Filter section header",
    }),
    ("transaction_history_type_label", {
        "value": "Type",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 198,
        "note": "Filter section header",
    }),
    ("transaction_history_date_label", {
        "value": "Date",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 207,
        "note": "Filter section header",
    }),
    ("transaction_history_period_label", {
        "value": "Period",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 220,
        "note": "Filter section header",
    }),
    ("transaction_history_transaction_type_deposit", {
        "value": "Deposit",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 31,
        "note": "Filter list entry",
    }),
    ("transaction_history_transaction_type_withdrawal", {
        "value": "Withdrawal",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 32,
        "note": "Filter list entry",
    }),
    ("transaction_history_transaction_type_transfer", {
        "value": "Fund Transfer",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 33,
        "note": "Filter list entry",
    }),
    ("transaction_history_period_today", {
        "value": "Today",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 41,
        "note": "Filter list entry",
    }),
    ("transaction_history_period_last_week", {
        "value": "Last week",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 42,
        "note": "Filter list entry",
    }),
    ("transaction_history_period_this_month", {
        "value": "This month",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 43,
        "note": "Filter list entry",
    }),
    ("transaction_history_period_custom", {
        "value": "Custom",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 44,
        "note": "Filter list entry",
    }),
    ("transaction_history_no_transactions", {
        "value": "No transactions",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 294,
        "note": "Empty state",
    }),
    ("transaction_history_amount_label", {
        "value": "Amount",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 273,
        "note": "Column header",
    }),
    ("transaction_history_status_label", {
        "value": "Status",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 273,
        "note": "Column header",
    }),
    ("transaction_history_date_column", {
        "value": "Date",
        "first_file": "lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart",
        "first_line": 273,
        "note": "Column header",
    }),
    # --- vantage_pending_order_quote_pill.dart (quick check) ---
    ("pending_order_quote_pill_on", {
        "value": "ON",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_quote_pill.dart",
        "first_line": 1,
        "note": "Skip — static value, no translation needed",
        "SKIP": True,
    }),
    ("pending_order_quote_pill_off", {
        "value": "OFF",
        "first_file": "lib/screens/home/brands/vantage/vantage_pending_order_quote_pill.dart",
        "first_line": 1,
        "note": "Skip — static value, no translation needed",
        "SKIP": True,
    }),
])

for k, v in MANUAL_ADD.items():
    if not v.get("SKIP"):
        final[k] = v

# Write final
FINAL = "/tmp/vantage_keys_final.json"
with open(FINAL, "w", encoding="utf-8") as f:
    json.dump(final, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"Wrote {FINAL}: {len(final)} keys")
# Print summary
for key, payload in final.items():
    print(f"  {key}: {payload['value']!r}")
