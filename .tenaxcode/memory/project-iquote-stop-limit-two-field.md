---
name: project-iquote-stop-limit-two-field
description: "iQuote pending order needs 2-field trigger+limit UI for stop-limit variants (like Vantage screenshot); currently only 1 Order Price field. Full impl plan."
type: project
createdAt: 1787817154733
updatedAt: 1787817154733
---

TASK (2026-08-27): iQuote pending-order sheet must show TWO price fields when order type is Buy/Sell Stop Limit — "When Price Is Trigger Price" (Trigger Price = wire `price`) + "When Price Is Limit Price" (Limit Price = wire `stop_limit_price`), with cross-validation error text ("Trigger price should be above 159.368"). Reference = Vantage screenshot (from CRM app; exact strings NOT in whitelabel repo). Currently iQuote shows only ONE "Order Price" field.

FILE: `lib/screens/home/brands/iquote/iquote_chart_screen.dart` — `_NewOrderSheetState` (class starts ~L976).
- State fields ~L980: `_priceCtl` (TextEditingController), `_orderType='buy_limit'` (String, L999), helpers `_price` getter L1147 = double.tryParse(_priceCtl.text), `_onOrderTypeChanged` L1031, `_updateTpSlFromMarketPrice` L1098, `initState` L1053, `dispose` L1090. `_volume`, `_tpCtl`,`_slCtl`,`_tpSlEnabled`,`_isTpCustom`,`_isSlCustom`.
- Pending UI block L1321-1406: dropdown `_AnimatedOrderTypeDropdown` L1323 + single Obx `_Field('Order Price', _priceCtl, digits: ctrl.priceDigits.value)` with ±step buttons L1344-1371.
- `_submit(side)` L1608-1641: builds orderKind from `_orderType` (buy_stop_limit/sell_stop_limit → 'stop_limit'; buy_stop/sell_stop → 'stop'; else 'limit'), calls `widget.ctrl.submitOrder(side, orderKind, volume, price, takeProfit, stopLoss)`. **DOES NOT pass stopLimitPrice — must add.**

CONTROLLER `submitOrder` L327-418 (`lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart`): signature currently {side, orderKind, volume, price, takeProfit, stopLoss}. Calls `_trading.placeTradeOrder(...)` L375 — NO stopLimitPrice passed. **Must add `String? stopLimitPrice` param + forward it.** `_orderType(side,kind)` L420 already maps stop_limit→buyStopLimit/sellStopLimit (added earlier this session). priceDigits RxInt from websocket quote.digits (dynamic, reactive).

BACKEND READY: `TradingController.placeTradeOrder` L2572 (`lib/screens/trading/view_models/trading_controller.dart`) accepts `String? stopLimitPrice` L2579 → payload['stop_limit_price'] L2677-2678. Model chart_screen.dart L734-758 confirms: for buyStopLimit/sellStopLimit, `price`=Trigger (openPrice), `stopLimitPrice`=Limit (limitPrice).

OrderType enum (`lib/models/order_types.dart`): buyStopLimit(6,'Buy Stop Limit','buy_stop_limit',isBuy:true,requiresPrice:true), sellStopLimit(7,...). NO isStopLimit helper — check apiString.contains('stop_limit') or value==6/7.

IMPL STEPS:
1. Add state field `_triggerCtl` (TextEditingController) for Trigger Price. Keep `_priceCtl` as the Limit Price for stop-limit; for non-stop-limit `_priceCtl` stays the single Order Price.
2. Add getter `bool get _isStopLimit => _orderType=='buy_stop_limit'||_orderType=='sell_stop_limit';`
3. In pending UI (L1321-1406): when `_isStopLimit`, render TWO labeled Obx `_Field`s — "Trigger Price" (_triggerCtl) + "Limit Price" (_priceCtl) each with ±step, plus a validation error Text (buy: trigger should be above ask; sell: trigger should be below bid — mirror Vantage). When not stop-limit, keep single "Order Price" field.
4. `_onOrderTypeChanged` L1031: when switching TO stop_limit, seed _triggerCtl too (buy_stop_limit trigger=ask, sell_stop_limit trigger=bid); limit seed = same or leave.
5. `initState`/`dispose`: init + dispose `_triggerCtl`.
6. `_submit` L1608: when `_isStopLimit`, price = _triggerCtl.text (Trigger), stopLimitPrice = _priceCtl.text (Limit). Pass new `stopLimitPrice:` arg to submitOrder.
7. Controller submitOrder: add `String? stopLimitPrice` param, forward to placeTradeOrder.

DONE EARLIER THIS SESSION (verified analyze clean, 0 errors, 8 pre-existing warnings): (a) `_orderType` stop_limit case in controller; (b) `_AnimatedOrderTypeDropdown`+`_DropdownOptionTile` animated 6-option dropdown at file end ~L2576-2815; (c) `_DecimalDigitsFormatter` class at end (~L2821, needs `import 'package:flutter/services.dart'` L30 — ADDED); (d) `_Field` got optional `int? digits` param → inputFormatters clamp decimals; price/TP/SL fields wrapped in Obx reading ctrl.priceDigits.value; (e) Place button label wrapped in AnimatedSwitcher.

flutter bin `~/development/flutter/bin/flutter`. analyze: `flutter analyze lib/screens/home/brands/iquote/iquote_chart_screen.dart` and the controller. Overflow note: screenshot shows "BOTTOM OVERFLOWED BY 1.4 PIXELS" near Chart toggle — minor, separate.
