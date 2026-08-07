# IQuote Symbol Change Wiring — Implementation Plan

## Goal

When the user switches the selected symbol (from the market screen, home tab, or chart's own
symbol picker), the iquote chart screen must:
1. receive the new symbol,
2. clear old candle/indicator state,
3. push the symbol into the live websocket via `ChartSocketController`,
4. keep the Buy/Sell + header + MA strip + period selector in sync.

The iquote chart already has `didUpdateWidget` (line ~511) + the controller has a stub
`forceSwitchSymbol` placeholder — but the actual symbol-change plumbing is missing: no
controller method to change the socket subscription, no first-instrument listener, no
cross-tab notifier.

## Approach

Mirror the Vantage pattern in `chart_screen.dart` (`_handleSymbolChange` at line ~885) with
three pieces:

| Piece | File | Role |
|---|---|---|
| **Cross-tab notifier** | `iquote_chart_screen.dart` | `ValueNotifier<String>` shared across all iquote tabs so market → chart is a one-liner |
| **Symbol-change handler** | `iquote_chart_screen.dart` | Guarded `_handleSymbolChange(newSymbol)` — resets candle controller, fires controller, updates notifier |
| **Controller wiring** | `iquote_chart_controller.dart` | `Rx<String> currentSymbol`, `changeSymbol(sym)`, `initializeSocketForSymbol(sym)`, `getSocketData(sym)` that delegate to `ChartSocketController` |

The Vantage `ChartSocketController` already exposes `changeSymbol(String)` (called from
`chart_screen.dart:_handleSymbolChange`). Reuse it — same contract, same flow.

## Steps

### Phase 1 — Notifier + initState
- [ ] **1a.** In `iquote_chart_screen.dart`, add a `static ValueNotifier<String> _selectedSymbolNotifier = ValueNotifier<String>('')` as a State field (static so market screen can reach it without a Get.find).
- [ ] **1b.** In `initState` (after `super.initState()`): get-or-create `IQuoteChartController`, then add a listener on it that calls `_onSymbolChanged(symbol)`.
- [ ] **1c.** Also in `initState`: listen to `instrumentsController.instrumentsList` via `ever(instrumentsList, (_) => _onFirstInstrumentReady())` (the first instrument becomes the default chart symbol).

### Phase 2 — Symbol-change handler in the screen
- [ ] **2a.** Add `_handleSymbolChange(String newSymbol)` to `iquote_chart_screen.dart` State class:
  - If `newSymbol == widget.symbol` return early (guard).
  - Set `_selectedSymbolNotifier.value = newSymbol` (triggers market tab listener).
  - Call `controller.changeSymbol(newSymbol)`.
- [ ] **2b.** Add `_onSymbolChanged(String symbol)` — the controller's ever-listener callback. Calls `_handleSymbolChange(symbol)`.
- [ ] **2c.** Wire `didUpdateWidget` (already exists at line ~511) to detect when `widget.symbol` changes from outside (e.g., market screen direct navigation).

### Phase 3 — Controller methods
- [ ] **3a.** In `iquote_chart_controller.dart`, add `Rx<String> currentSymbol = ''.obs`.
- [ ] **3b.** Add `void changeSymbol(String symbol)` — sets `currentSymbol.value = symbol`, then calls `_initializeSocketForSymbol(symbol)`.
- [ ] **3c.** Add `Future<void> _initializeSocketForSymbol(String symbol)` — gets `ChartSocketController` from Get.find and calls its `changeSymbol(symbol)`.
- [ ] **3d.** Add `void getSocketData(String symbol)` — calls `ChartSocketController.getSocketData(symbol)` for historical data reload.

### Phase 4 — Market-screen integration
- [ ] **4a.** In `iquote_market_screen.dart`, when a symbol is tapped, set `IQuoteChartScreen._selectedSymbolNotifier.value = tappedSymbol` (accessed via the static field).
- [ ] **4b.** Alternative (cleaner): expose a static `void broadcastSymbol(String)` on `IQuoteChartScreen` that sets the notifier — market screen calls this without needing a reference.

### Phase 5 — Chart widget rebuild on symbol change
- [ ] **5a.** Wrap the chart placeholder / candle area in an `Obx(() => ...)` or manual listener on `controller.currentSymbol` so the widget tree rebuilds when the symbol changes.
- [ ] **5b.** In `_handleSymbolChange`, after notifier + controller update, call `setState(() {})` to refresh header/symbol row.

## Files to modify

| File | What to add |
|---|---|
| `lib/screens/home/brands/iquote/iquote_chart_screen.dart` | `_selectedSymbolNotifier`, `_handleSymbolChange`, `_onSymbolChanged`, `_onFirstInstrumentReady`, initState wiring, didUpdateWidget wiring |
| `lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart` | `currentSymbol` Rx, `changeSymbol`, `_initializeSocketForSymbol`, `getSocketData` |
| `lib/screens/home/brands/iquote/iquote_market_screen.dart` | Symbol tap → `_selectedSymbolNotifier.value = sym` (or static broadcast) |

## Risks / Open questions

- **`ChartSocketController` is in `trading_websocket_service.dart`** — it is a single shared singleton. Calling `changeSymbol` from iquote is fine as long as the vantage chart and iquote chart don't overlap (they run in separate tab contexts, so they should be safe — but verify with QA that switching rapidly doesn't flicker the vantage chart).
- **First-instrument default** — if `instrumentsController.instrumentsList` is empty at init time, the chart will show no symbol until one arrives. Consider a fallback to the existing `widget.symbol` passed from the tab host.
- **No chart library yet** — the candle area is still a placeholder. Symbol-change resets the placeholder; full candle rendering is a follow-up phase.
