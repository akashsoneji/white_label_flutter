# iQuote New-Order Bottom Sheet — Vantage-style Pending-Order Dropdown

## Goal
Jab iQuote chart screen pe "Pending" pill tap hota hai aur bottom sheet (`_NewOrderSheet`) khulta hai, Pending tab me **Vantage ki tarah explicit 6-option order-type dropdown** ho — Buy Limit / Sell Limit / Buy Stop / Sell Stop / Buy Stop Limit / Sell Stop Limit. User jis option ko select kare, uski value + derived pricing (limit price ask/bid, TP/SL recalculation, Buy/Sell flag) waise hi flow ho jaise Vantage me hota hai.

Aaj ki screenshot me jo dikh raha hai wo Market-order design jaisa hai (volume chips 0.01/0.10/0.50/1.00/2.00/5.00, single TP/SL on-off toggle, "SELL LIMIT" / "BUY STOP" pill buttons jo auto-compute ho rahe hain price se) — ye Pending order me galat design hai. Pending tab Vantage jaisa hona chahiye.

## Context (jo code me abhi hai)
- Bottom sheet: `lib/screens/home/brands/iquote/iquote_chart_screen.dart`
  - `_NewOrderSheet` / `_NewOrderSheetState` — lines 961–1580.
  - Order-type control = **Market / Pending tabs** (L1128-1150). Pending tab me dropdown nahi hai — sirf `_tab = 1` set hota hai, baaki sab derived (limit-vs-stop auto-resolve from price vs bid/ask at L1556/1558).
  - Volume: hardcoded `_lots = [0.01, 0.10, 0.50, 1.00, 2.00, 5.00]` (L976). Volume chips Market-design jaisi hain — pending me aise chips ki zaroorat nahi (Vantage me simple −/+ stepper + free-text input use hota hai).
  - TP/SL: ek single `_tpSlEnabled` toggle (L1337). Vantage me alag-alag Take Profit + Stop Loss blocks hain, dono ke apne price inputs + PnL display.
  - Submit labels: `'SELL LIMIT' / 'BUY STOP'` (L1447-1448) — auto-compute from `_price < currentBid` / `_price < currentAsk`. Dropdown se independent.
- Controller: `lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart`
  - `submitOrder(...)` at L327: accepts `orderKind: 'market' | 'limit' | 'stop'` only. **No stop-limit.**
  - `_orderType(side, kind)` at L420-429 maps to `OrderType.{buyLimit,sellLimit,buyStop,sellStop,buyMarket,sellMarket}`. Stop-Limit order type bana hi nahi sakte iss controller se.
- Vantage fork (logic + dropdown source of truth): `lib/screens/home/brands/vantage/vantage_pending_order_content.dart`
  - Dropdown widget `_buildOrderTypeDropdown()` + `_showOrderTypeBottomSheet()` — 6 options, tap sets `widget.selectedOrderType.value` + sets `selectedPendingOrderType` (Buy=1 / Sell=0). Direct port karna hai.
- Pending order screen (sibling plan already wired iQuote to VantagePendingOrderContent): `lib/screens/home/pending_order_screen.dart` — L511 combined gate `isVantage = usesVantageUi() || usesIquoteUi()`. Ye already kaam kar raha hai.

## Approach
Bottom sheet ke **Pending tab body** ko Vantage-style layout me convert karo. Vantage me jo 6-option dropdown + price input + TP/SL separate blocks hain, unka mini-port is sheet ke Pending branch me. Market tab ka design untouched rahega (wo sahi hai). Submit mapping update karo taaki dropdown selection ka wire correct OrderType me jaye.

Approach: Vantage ke source se dropdown widget + `_updatePrices` + `_recalculateTPSL` + TP/SL PnL logic — ye sab copy karke is sheet ke Pending branch me inline karo. New ValueNotifier state add karo sheet state me (`_selectedOrderType`, `_selectedPendingOrderType`). Controller `submitOrder` me **stop-limit support add karo** (otherwise Buy/Sell Stop Limit UI se select hoke bhi backend me limit/stop me fall back karega).

## Steps
- [ ] Step 1 — Read Vantage source to extract: dropdown widget (`_buildOrderTypeDropdown` + `_showOrderTypeBottomSheet`), order-type → limitPrice bid/ask switch (`_updatePrices` L439-506), TP/SL 1.15% recalc (`_recalculateTPSL`), separate TP/SL price inputs + PnL builder. Done = have line refs.
- [ ] Step 2 — Add `OrderType.stopLimit` support to controller `submitOrder`: `_orderType()` map me `Buy Stop Limit` / `Sell Stop Limit` cases add karo, aur ek `'stop_limit'` orderKind accept karo. Validate ki `OrderType.buyStopLimit` / `sellStopLimit` enum values already exist in `lib/models/order_types.dart`.
- [ ] Step 3 — `_NewOrderSheetState` me Vantage-style state add karo:
  - `final ValueNotifier<String> _selectedOrderType = ValueNotifier('Buy Limit');`
  - `final ValueNotifier<int> _selectedPendingOrderType = ValueNotifier(1);` (1=Buy, 0=Sell)
  - `final ValueNotifier<double> _limitPrice = ValueNotifier(0.0);`
  - `final ValueNotifier<bool> _tpEnabled = ValueNotifier(false);`
  - `final ValueNotifier<bool> _slEnabled = ValueNotifier(false);`
  - `final ValueNotifier<double> _tpPrice = ValueNotifier(0.0);`
  - `final ValueNotifier<double> _slPrice = ValueNotifier(0.0);`
  - TP/SL TextEditingControllers.
  - Wire listener on `_selectedPendingOrderType` to reset manual-edit flags + recompute prices (Vantage L427-436 pattern).
- [ ] Step 4 — Pending tab body me **Vantage layout port** karo:
  - (a) `_buildOrderTypeDropdown()` widget + `_showOrderTypeBottomSheet()` with 6 options. Tap sets both notifiers + closes sheet. Yahi current Pending body ki jagah lega (Market/Pending tabs ke neeche).
  - (b) Limit price input − / + stepper (Vantage `_buildOpenPriceInput` ~L1165).
  - (c) TP/SL separate blocks — Vantage `_buildStopLossTakeProfitWithSwitches` pattern: Take Profit switch + price input + PnL; Stop Loss switch + price input + PnL. Replace the current single `_tpSlEnabled` toggle.
  - (d) Place-order button — single full-width "Place pending order" button (Vantage style). Delete the two big SELL LIMIT / BUY STOP pill buttons from the Pending branch.
  - (e) Volume chip row remove karo Pending tab se — simple −/+ stepper use karo (Vantage has only this).
- [ ] Step 5 — `_updatePrices` (port Vantage L439-506): dropdown `_selectedOrderType` se Sell → bid, Buy → ask; TP/SL 1.15% offset. Wire bid/ask listener using `ever` worker on `widget.ctrl.lastBid`/`lastAsk` (already done in sheet at L1019-1020).
- [ ] Step 6 — Submit map update (L1547-1568): dropdown selection se direct `orderKind` derive karo (auto-resolve logic hata do):
  - 'Buy Limit' / 'Sell Limit' → `'limit'`
  - 'Buy Stop' / 'Sell Stop' → `'stop'`
  - 'Buy Stop Limit' / 'Sell Stop Limit' → `'stop_limit'`
  - Remove L1556-1558 (price-based auto-resolve). TP/SL pass karo only jab respective `_tpEnabled` / `_slEnabled` true ho.
- [ ] Step 7 — Pending tab ke labels simplify karo: button ab "Place pending order" hai, drop "SELL LIMIT"/"BUY STOP" labels.
- [ ] Step 8 — `flutter analyze` touched files par — 0 errors expected.
- [ ] Step 9 — Mark `[x]` in plan file as completed.

## Files
- `lib/screens/home/brands/iquote/iquote_chart_screen.dart` — MODIFY. Pending tab body rewrite (Steps 3-7). Most changes inside `_NewOrderSheetState` (L961-1580).
- `lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart` — MODIFY. `submitOrder` me stop-limit orderKind + `_orderType()` map update (Step 2).
- `lib/models/order_types.dart` — VERIFY ONLY. Confirm `OrderType.buyStopLimit` / `sellStopLimit` enum values already exist.
- `lib/screens/home/brands/vantage/vantage_pending_order_content.dart` — REFERENCE. Source of dropdown widget, `_updatePrices`, TP/SL block layout. Do NOT modify.

## Risks / Open questions
- Controller change (stop-limit support) crosses `_orderType` mapping — verify backend actually accepts `orderKind: 'stop_limit'`; agar nahi to fallback at Pending UI me Stop-Limit options hide karne padenge.
- Pending tab me Vantage-style port karne se sheet ka current behavior (auto-resolve) hat jayega — user explicitly dropdown select karega, jo requirement hai. Verify kar lo.
- Volume chip row remove karna hai pending se — agar user ko chips chahiye the to design intent clash hoga. Screenshot me wo Market jaisi lag rahi thi, isliye remove kar raha hoon.
- TP/SL single toggle → separate TP+SL blocks me conversion — current sheet me `_tpCtl`/`_slCtl` auto-populate from `_updateTpSlFromMarketPrice` (L1036-1081). Ye function logic reuse karenge Vantage ke `_recalculateTPSL` se.
- Symbols dropdown (Currency pair) ke saath size change hoga — Vantage layout compact hai but naye sections add honge, sheet height badh sakti hai. `isScrollControlled: true` already set hai (L823), scroll bhi hai.
- 6-option dropdown bottom sheet me flow: tap dropdown → another modal sheet opens. Nested modal — verify iQuote me ye already kahin use hua hai (Vantage me kaam karta hai).
