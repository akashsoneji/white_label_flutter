# IQuote Symbol Change Flow — Analysis & Plan

## Goal
Trace exactly what happens code-wise when a user changes the trading symbol — from the chart screen directly, and from the Market / Home tab — in the iquote parent's context.

## Approach
Follow the parent (Vantage) symbol lifecycle end-to-end first, then map each step onto iquote's existing screens and controller. The Vantage parent flow in `chart_screen.dart` is the reference implementation; iquote already has `IQuoteChartScreen` + `IQuoteChartController` but needs the full symbol-change wiring.

---

## Symbol Change Flow — Step by Step

### Phase 1 — App Start / First Chart Open

1. **`initState()`** (`chart_screen.dart:~313`)
   - `selectedSymbol` = `symbolSelectionService.currentSymbol` → fallback `'XAUUSD'`
   - `ChartScreen._selectedSymbolNotifier.value = selectedSymbol` — static `ValueNotifier<String>` that instruments/market screens also listen to
   - `chartSocketController` (GetX) get-or-create; `chartController` get-or-create

2. **`_initializeWithFirstInstrument()`**
   - Registers an `ever(instrumentsController.instrumentsList, _onFirstInstrumentLoaded)` listener
   - When `instrumentsList` populates → first instrument's symbol becomes `selectedSymbol`
   - Notifier updated → `chartSocketController.initializeSocketForSymbol(selectedSymbol)` → WebSocket subscribe

3. **`didChangeDependencies()`** (`chart_screen.dart:~1470`)
   - Fires on tab-switch and app-resume
   - Reads `symbolSelectionService.currentSymbol`; if `selectedSymbol` empty, picks cached/notifier value
   - If socket disconnected: `chartSocketController.handleAppRestart()`

### Phase 2 — Symbol Change from Chart Screen (picker)

1. User taps symbol picker → `_handleSymbolChange(newSymbol)` is called

2. **`_handleSymbolChange(newSymbol)`** (`chart_screen.dart:~900`)
   - Guard: `!mounted || newSymbol == selectedSymbol` → return
   - **Critical**: reset `_datafeedSymbolForSelected` cache — without this, `_buildChartArea()` passes the old `displaySymbol` to `ChartInAppWebView.symbol` prop → prop doesn't change → `didUpdateWidget` never fires → JS `updateSymbol` never called
   - `setState(() => selectedSymbol = newSymbol)`
   - `ChartScreen._selectedSymbolNotifier.value = newSymbol` (broadcast)
   - `chartSocketController.changeSymbol(newSymbol)` (with `.c` suffix) → old unsubscribe + new subscribe
   - `chartSocketController.getSocketData()` → fresh data request

3. **Rebuild → `_buildChartArea()`**
   - `displaySymbol` is new → cache cleared → `ChartInAppWebView(symbol: newSymbol)` prop changes
   - WebView `didUpdateWidget` fires → JS `updateSymbol(newSymbol)` → TradingView reloads

### Phase 3 — Symbol Change from Instruments/Market Tab (no stack change)

1. Instruments screen sets `ChartScreen._selectedSymbolNotifier.value = selectedSymbol`

2. **`_onSymbolChangedFromInstruments`** listener fires automatically — **no navigation needed**

3. Same Phase 2 steps: socket subscribe + chart reload + WebView prop update

### Phase 4 — Tab Switch (Home ↔ Market ↔ Chart)

- `trading_main_screen.dart`: `setState(() => _index = 1)` → Chart tab
- Chart widget rebuilds → `initState` already ran → `didChangeDependencies` fires
- Cached symbol or notifier value picked up
- **No symbol change happens** unless notifier has a different value

### Phase 5 — Live Price Updates

- `_listenToPriceUpdates()` registers `ever(chartSocketController.currentSymbol, ...)`
- New WebSocket data → `realTimePrice` update → `setState` → UI refresh
- TP/SL overlay lines, MA strip text, bid/ask update live

---

## IQuote-Specific Mapping

### Current iquote status
| Aspect | Current | Notes |
|--------|---------|-------|
| `brands.yaml` | `type: child, inheritsFrom: vantage` | Shares Vantage UI tree |
| `ui_registry.dart` | `'iquote' → 'vantage'` | Renders Vantage screens |
| `IQuoteChartScreen` | Exists at `lib/screens/home/brands/iquote/iquote_chart_screen.dart` | Has layout + WebView placeholder |
| `IQuoteChartController` | Exists at `lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart` | Needs full symbol wiring |
| Imports in `trading_main_screen.dart` | Already imports iquote home/market/chart | Ready to route |

### Steps needed to make iquote a full parent (own symbol change flow)

- [ ] **Phase 1 — Init**: `IQuoteChartScreen.initState()` → own `_selectedSymbolNotifier`, pick `symbolSelectionService.currentSymbol` (fallback `'XAUUSD'`), get-or-create `IQuoteChartController`
- [ ] **Phase 1 — First instrument**: `ever(instrumentsController.instrumentsList, ...)` listener → pick first symbol → `_selectedSymbolNotifier.value = symbol` → `iquoteChartController.initializeSocketForSymbol(symbol)`
- [ ] **Phase 3 — Notifier listener**: `IQuoteChartScreen._selectedSymbolNotifier.addListener(_onSymbolChanged)` → calls `_handleSymbolChange(newSymbol)` (same guard + flow as parent)
- [ ] **Phase 2 — `_handleSymbolChange()`**: Guard → reset `_datafeedSymbolForSelected` → `setState(selectedSymbol = newSymbol)` → update notifier → `iquoteChartController.changeSymbol(newSymbol)` → `getSocketData()`
- [ ] **Phase 4 — Lifecycle**: `didChangeDependencies()` → cached symbol from `symbolSelectionService` → reconnect socket if needed
- [ ] **Phase 5 — Price updates**: `_listenToPriceUpdates()` → `ever(iquoteChartController.currentSymbol, ...)` → bid/ask live update
- [ ] **Controller** (`IQuoteChartController`): implement `changeSymbol()`, `initializeSocketForSymbol()`, `getSocketData()`, `currentSymbol` Rx — mirror `ChartSocketController` pattern
- [ ] **Brand routing** (if making iquote a parent): `brands.yaml` → `type: parent`, `ui_registry.dart` → `'iquote' → 'iquote'`, `trading_main_screen.dart` → route `IQuoteHomeScreen` / `IQuoteMarketScreen` / `IQuoteChartScreen`

## Files

| File | What it does now | What needs to change |
|------|------------------|---------------------|
| `lib/screens/home/chart_screen.dart` | Reference parent flow (Vantage) | — (reference only) |
| `lib/screens/home/brands/iquote/iquote_chart_screen.dart` | Has layout + placeholder chart | Add `_handleSymbolChange`, notifier, init logic |
| `lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart` | Needs socket management methods | Implement `changeSymbol`, `initializeSocketForSymbol`, `getSocketData` |
| `lib/screens/home/brands/iquote/iquote_market_screen.dart` | Market/instrument list | Ensure symbol tap → `IQuoteChartScreen._selectedSymbolNotifier.value = symbol` |
| `lib/screens/home/brands/iquote/iquote_home_screen.dart` | Home tab | No symbol change — just nav |
| `lib/screens/home/trading_main_screen.dart` | Already imports iquote screens | Wire iquote tabs when `FlavorConfig.isIquote` is true |
| `lib/app/ui_registry.dart` | `'iquote' → 'vantage'` | Change to `'iquote' → 'iquote'` for parent mode |
| `assets/config/brands/brands.yaml` | `type: child, inheritsFrom: vantage` | Change to `type: parent` for parent mode |

## Risks / Open Questions

- `search_in_file` returned errors for iquote_chart_screen.dart — Agent mode will read it directly to confirm current state
- `ChartSocketController` is shared — iquote can either reuse it or get its own instance; reusing is simpler but may leak Vantage-specific state
- WebView `didUpdateWidget` depends on `symbol` prop changing with a unique key — ensure IQuoteChartScreen uses `_webViewKey` pattern
- If iquote remains a child of vantage, it inherits the parent's symbol flow and only needs the notifier-to-controller bridge
