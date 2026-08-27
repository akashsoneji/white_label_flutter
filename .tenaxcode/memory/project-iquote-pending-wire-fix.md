---
name: project-iquote-pending-wire-fix
description: "DONE: iQuote pending _submit now matches Vantage — volume preserves user precision (max(2, actualDecimals)); TP/SL formatted via PrecisionHelper.formatPrice at live priceDigits; new formattedVolume param in controller. analyze clean."
type: project
createdAt: 1787822360700
updatedAt: 1787822516672
---

DONE 2026-08-27: iQuote pending-order wire values fixed to match Vantage (lib/screens/home/pending_order_screen.dart _placePendingOrder reference). 0 analyze errors, 9 pre-existing warnings (same baseline).

WHAT SHIPPED:
1. **view_models/iquote_chart_controller.dart** submitOrder gained `String? formattedVolume` param. The forwarded call to `_trading.placeTradeOrder(...)` now uses `formattedVolume ?? volume.toStringAsFixed(2)`. So the sheet can pre-format the volume string at user-input precision.
2. **iquote_chart_screen.dart** `_NewOrderSheetState._submit()`:
   - `final digits = widget.ctrl.priceDigits.value;`
   - **Volume**: counts actual decimal places in `_volume.toString()`, takes `max(2, actualDecimals)`, formats via `_volume.toStringAsFixed(volDecimals)`. So `0.001` → "0.001" (not "0.00"), `0.10` → "0.10" (not "0.10").
   - **TP**: `PrecisionHelper.formatPrice(PrecisionHelper.parseDouble(_tpCtl.text.trim(), decimals: digits), decimals: digits)` — formatted to live priceDigits like Vantage.
   - **SL**: same.
   - `submitOrder(...)` call now passes `formattedVolume:`, `takeProfit: formattedTp`, `stopLoss: formattedSl`.

Stop-limit two-field wiring retained from prior sessions: trigger → `price`, limit → `stopLimitPrice`. Backend (TradingController.placeTradeOrder L2677-2678) still places `stop_limit_price` in payload when present.

PrecisionHelper: `lib/utils/precision_helper.dart` already imported (L51).
