Meta `_DetailSheet` close-position sheet fixed 2026-07-14 (3 issues).

**Issue 1 — Bid/Ask stuck on stale position price.**
Old code initialized `_liveBid`/`_liveAsk` from `widget.position.currentPrice + 0.00002` then manually re-subscribed to `_socket.priceStream` and called `setState` on each tick. The seed spread (0.00002) was below display precision for JPY pairs (digits=3 → step = 0.001), so the bid and ask columns rendered identically. The `setState` plumbing was fragile and could miss ticks if the sheet mounted mid-resubscribe.

**Fix:** Replaced manual setState subscription with a reactive `_resolveBidAsk()` method that reads `_socket.realTimePrice` (RxMap) inside `Obx`. The bid/ask `Row` widget now lives inside an `Obx(() { final live = _resolveBidAsk(); return Row(...); })` so it rebuilds on every socket tick. The seed fallback now uses a realistic spread based on the symbol's tick size (`tickSize = 1 / pow10(digits)`, then `seed + tickSize * 5`), so for digits=3 (JPY) the seed displays as "162.282 / 162.287" instead of "162.282 / 162.282".

**Issue 2 — Profit calc shows stale value (e.g. $2.33) not live tick.**
Old `_expectedProfit` used `widget.position.profitLoss` (static value captured at sheet open) plus a buggy `liveSpread/storedSpread * baseProfit` ratio that broke when `storedSpread == 0`.

**Fix:** Read the live profit from `tradingController.marketPositions` (RxList, websocket-driven), falling back to `widget.position.profitLoss`. The bottom button (`CLOSE WITH PROFIT $X.XX`) is wrapped in `Obx(() { final profit = _expectedProfit; ... })` so it rebuilds whenever `marketPositions` updates.

**Issue 3 — Partial close not discoverable.**
The pill row was the only partial-close UI: tap a `-` pill to set `_closeVolume` to a fraction. Users didn't realize the pills were interactive. No label, no mode chip, no hint.

**Fix:** Added a "Close mode" row above the pills with a FULL/PARTIAL chip that swaps based on `isPartial = widget.initialPartial || _deltaPreset < 0`, plus a 11sp hint "Tap a − pill to close part of the position" that hides once the user is in PARTIAL mode. The bottom button text already changed from "CLOSE WITH PROFIT" to "PARTIAL CLOSE" when partial.

**Why all three together:** they share the same `_DetailSheet` widget and the same data dependency on the websocket. Fixing them together was cheaper than fixing them separately.

**How to apply:**
- `_DetailSheet` in `lib/brands/meta/meta_trade_screen.dart` (around lines 1323–1930).
- Bid/ask: read via `_resolveBidAsk()` inside `Obx`. Do NOT manually `setState` from a `Stream.listen` callback — the RxMap is already reactive.
- Profit: use `_trading.marketPositions.firstWhereOrNull((p) => p.orderId == widget.position.orderId)?.profitLoss` instead of `widget.position.profitLoss`. Wrap in `Obx`.
- Partial close discovery: the mode chip + hint are NOT just decorative — without them users tap the center pill and assume the screen is broken.

**Removed dead code:** `_liveBid`, `_liveAsk`, `_liveProfit`, `_tickSub`, `StreamSubscription<dynamic>` import usage in `_DetailSheet`.

**Verification:** `flutter analyze lib/brands/meta/meta_trade_screen.dart` → No issues found.

Related: [[project-3-parents-7-children-2026-07-09]].