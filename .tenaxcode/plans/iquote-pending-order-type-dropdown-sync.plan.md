# iQuote Pending Order — Order-Type Dropdown Sync (Vantage-style)

## Status: COMPLETE (2026-08-27)

The original "Step 0 — Confirm A vs B" turned out to resolve in favour of **interpretation B** (in-place wire of the existing iQuote pending-order UI), not interpretation A (new `IquotePendingOrderContent` fork). Repo audit showed:

- No `iquote_pending_order_*.dart` file exists in `lib/screens/home/brands/iquote/`.
- The iQuote pending-order UI IS already present, but it lives inside `_NewOrderSheetState` in `lib/screens/home/brands/iquote/iquote_chart_screen.dart` (L975+), opened by the bottom-bar Buy/Sell buttons → `_openNewOrderSheet()` → `showModalBottomSheet` → `_NewOrderSheet`.
- The existing sheet only supported **two** order kinds (`'limit'` / `'stop'`), auto-derived from price vs bid/ask — exactly the "value wiring missing" scenario the plan's interpretation B described.

So Steps 1–4 below target `_NewOrderSheet` (in-place wire) rather than creating a new presentation fork. Result: iQuote pending-order flow now mirrors Vantage's 6-option dropdown behaviour (Buy Limit / Sell Limit / Buy Stop / Sell Stop / Buy Stop Limit / Sell Stop Limit) with explicit user choice and proper bid/ask seeding on dropdown change.

## Goal
Vantage app ki tarah, jab user pending order add karta hai aur dropdown se order type (Buy Limit / Sell Limit / Buy Stop / Sell Stop / Buy Stop Limit / Sell Stop Limit) select karta hai, uski value + derived pricing (limit price bid/ask, TP/SL recalculation, Buy=1 / Sell=0 flag) exactly waise hi iQuote-design wali pending order screen me bhi flow ho. Matlab dropdown selection ka behaviour dono UI me identical rahe — sirf presentation iQuote ka ho.

## Context (jo code me abhi hai)
- iQuote chart screen: `lib/screens/home/brands/iquote/iquote_chart_screen.dart` — Buy/Sell pills (`_BottomBar` L781/L812) → `_openNewOrderSheet(context, side:)` (L825) → `showModalBottomSheet` (L832) → `_NewOrderSheet` (L961) / `_NewOrderSheetState` (L975+).
- Old sheet logic: 2-tab (Market / Pending). Pending tab auto-derived `'limit'` or `'stop'` from `_price` vs current `bid/ask` (L1556/L1558). Single shared `_priceCtl` field, no explicit order-type picker.
- Order model: `lib/models/order_types.dart` (`OrderType` enum with `buyStopLimit`/`sellStopLimit` already present; `apiString: 'buy_stop_limit'`/`'sell_stop_limit'`).
- Controller: `lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart` — `submitOrder(side, orderKind, volume, price, takeProfit, stopLoss)` (L327+); private `_orderType(side, kind)` helper (L420) — **did NOT support `'stop_limit'`**, falling back to market.
- OrderType.fromString covers all 8 kinds; controller's `_orderType` did not.

## Approach (executed)
1. Extended `iquote_chart_controller._orderType(side, kind)` to handle `'stop_limit'` (returns `buyStopLimit` / `sellStopLimit`).
2. Added 6-option order-type dropdown widget inside `_NewOrderSheetState`, shown only when `_tab == 1` (Pending). Selection updates `_orderType` state, auto-fills from ask (buy-limit) / bid (sell-limit) / bid (buy-stop) / ask (sell-stop), leaves empty for stop-limit, and triggers `_updateTpSlFromMarketPrice()` to recalc TP/SL.
3. Replaced the old dual-button Pending UI (auto-derived SELL LIMIT / BUY STOP labels) with a single "Place <Type> order" button. Side is inferred from the dropdown selection (`buy_*` → buy, `sell_*` → sell).
4. Updated `_submit()` to map dropdown value → controller orderKind (`'stop_limit'` / `'stop'` / `'limit'`), instead of the old auto-detect from price vs bid/ask.

## Steps
- [x] Step 0 — Repo audit (LS of iquote brand folder + grep). Resolved interpretation: A (new fork) vs B (wire existing) — went with B because the in-sheet `_NewOrderSheet` was the actual target.
- [x] Step 1 — Add `'stop_limit'` case to `iquote_chart_controller._orderType()` so the controller can return `buyStopLimit`/`sellStopLimit`.
- [x] Step 2 — Add state fields + helpers in `_NewOrderSheetState`: `_orderType` (default `'buy_limit'`), `_pendingOrderTypes` list, `_labelForOrderType()`, `_onOrderTypeChanged()` (seeds price from bid/ask + recalcs TP/SL).
- [x] Step 3 — Add explicit 6-option `DropdownButton<String>` widget inside `_NewOrderSheetState.build()`, gated to `_tab == 1`. Wires `_onOrderTypeChanged()` on change.
- [x] Step 4 — Replace the old Pending-tab dual-button (`sellLabel` / `buyLabel` + auto-derived kind) with a single "Place <Type> order" button whose side is derived from the dropdown selection.
- [x] Step 5 — Update `_submit()` to map `_orderType` → `'stop_limit'` / `'stop'` / `'limit'` instead of the old price-vs-bid/ask auto-detect.
- [x] Step 6 — `flutter analyze` on both touched files — **0 errors, 9 pre-existing warnings** (all unused-import / unused-declaration warnings unrelated to this change; present in HEAD before the edits).
- [x] Step 7 — Mark steps [x] in plan file as completed.

## Files
- `lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart` — MODIFY. Added `'stop_limit'` branch to `_orderType()` (one branch, ~3 lines).
- `lib/screens/home/brands/iquote/iquote_chart_screen.dart` — MODIFY. Added dropdown state + widget + button + `_submit()` remap (~140 lines net, surgical).
- `lib/screens/home/pending_order_screen.dart` — NOT MODIFIED (interpretation B → no new fork needed).
- `lib/screens/home/pending_order_content.dart` — NOT MODIFIED (base screen left untouched).

## Verification
- `flutter analyze lib/screens/home/brands/iquote/iquote_chart_screen.dart lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart` → **9 issues found, all pre-existing warnings (unused_import / unused_element / unused_local_variable) unrelated to this change. 0 errors.**
- Manual UI test should be done on-device: open iQuote chart → tap Buy or Sell → switch to Pending tab → dropdown should show 6 options; switching each should update the displayed label, seed the price from bid/ask (stop-limit variants leave blank), recalc TP/SL, and "Place <Type> order" button should reflect the chosen kind.