# Plan: Add "Chart" Tab to Vantage Bottom Nav (5-tab layout)

**Date:** 2026-07-09
**Scope:** Vantage parent + ALL Vantage-children (8 brands total)
**Goal:** Insert a new dedicated "Chart" tab between Prices (WatchList) and Markets (Trade). Tapping it should open the existing `VantageChartLayout` full-screen (with back button, NO bottom nav) — exactly like the watchlist → chart redirect does today.

---

## Affected Brands (8)

From `lib/flavor_config.dart:200` (`usesVantageUi()` set) — these are the EXACT brands that will see this change:

| # | Brand | Type | Inherits From |
|---|-------|------|---------------|
| 1 | **vantage** | parent | — |
| 2 | **pipze** | child | vantage |
| 3 | **baazex** | child | vantage |
| 4 | **gtxprime** | child | vantage |
| 5 | **kantara** | child | vantage |
| 6 | **skyriss** | child | vantage |
| 7 | **telifox** | child | vantage |
| 8 | **tenax** | child | vantage |

**NOT affected** (have their own UI trees):
- celestial (5-tab shell: WatchList / Chart / Trade / History / Settings — already has a Chart tab)
- meta (its own UI tree)
- afx, amirifx, askbid, goldenwolffx, profx, sr, tradoxy, vr19 (inactive/legacy)
- xelthio (the umbrella project name; not a flavor)

---

## Current State (Vantage, 4 tabs)

**File:** `lib/widgets/trading_bottom_navigation.dart:25-72`

```
0: Prices    (trend-up.svg)        ← InstrumentsScreen / watchlist
1: Markets   (candle.svg)          ← TradeScreen (open positions)
2: Accounts  (wallet.svg)          ← DashboardScreen (accounts list)
3: Settings  (setting.svg)         ← MoreScreen
```

**WatchList → Chart flow today (Vantage only):**

1. User on `Prices` tab (index 0) taps a symbol row in `InstrumentsScreen`
2. `_navigateToChartWithSymbol(symbol)` is called (instruments_screen.dart:701)
3. `_symbolSelectionService.setSymbol(symbol)` + `ChartScreen.setSelectedSymbol(symbol)`
4. Calls `widget.onNavigateToChart(symbol)` → resolves to `_openChartScreenVantage(symbol)` in `lib/screens/home/trading_main_screen.dart:54`
5. `_openChartScreenVantage` does `Get.to(() => ChartScreen(...))` — PUSHES `ChartScreen` as a full-screen route on top of the bottom nav
6. Inside `ChartScreen.build()`, the Vantage branch (chart_screen.dart:1579) returns `VantageChartLayout(...)` which has its OWN back button (`Icons.arrow_back` → `Navigator.maybePop()`) and NO bottom nav (because it's a pushed route, not a tab)

This is the exact behavior the new "Chart" tab must replicate.

**Why no bottom nav on the chart screen:** `ChartScreen` is pushed via `Get.to(...)` outside the `PageView` in `TradingMainScreen.build()`. So `Scaffold.bottomNavigationBar` from the parent is not in the route stack. The screen owns its own header with back button.

---

## Target State (Vantage, 5 tabs)

```
0: Prices    (trend-up.svg)        ← InstrumentsScreen / watchlist  [EXISTING]
1: Chart     (chart.svg)           ← VantageChartLayout (pushed)    [NEW]
2: Markets   (candle.svg)          ← TradeScreen                    [shifted from idx 1 → 2]
3: Accounts  (wallet.svg)          ← DashboardScreen                [shifted from idx 2 → 3]
4: Settings  (setting.svg)         ← MoreScreen                     [shifted from idx 3 → 4]
```

### Tap behavior on Chart tab:
- Pushes `ChartScreen` (which for Vantage returns `VantageChartLayout`) via `Get.to(...)` — same code path as `_openChartScreenVantage`
- Back button → `Navigator.maybePop()` → returns to whichever tab user was on before (Prices by default)
- Bottom nav is HIDDEN while on the chart route (because it's a pushed full-screen route, NOT a tab inside the PageView)

---

## Files to Change (6)

### 1. `lib/widgets/trading_bottom_navigation.dart`

**The Vantage branch (lines 25-72)** currently builds 4 nav items. Add a 5th item at index 1 ("Chart") and bump Markets/Accounts/Settings indices by 1.

**New SVG asset needed:** `chart.svg` already exists at `assets/svg/bottom_navigation/chart.svg` and the bold variant at `assets/svg/bottom_navigation/chart_bold.svg`. They are ALREADY used in the non-Vantage 5-tab nav (line 174 in same file) — reuse them.

**New container width:** Need to confirm 5 items fit in the existing pill. Current width: 56.h tall, padded 20.w horizontal margin + 10.w internal. With 5 items each at min width ~70-80.w, total = ~350-400.w. Standard phone width is 360-414.w, so we should:
- Test on a 360w device
- Either reduce horizontal padding from `10.w` to `6.w` or drop the capsule padding when selected, OR
- Use `FittedBox(fit: BoxFit.scaleDown)` like `_buildNavItem` already does (line 217) to scale the row down if it overflows

The Vantage variant (`_buildVantageNavItem`, line 235) currently uses `Row` not `FittedBox`. Need to wrap with `FittedBox(fit: BoxFit.scaleDown)` OR reduce selected-state horizontal padding from 12.w to 8.w.

### 2. `lib/screens/home/trading_main_screen.dart`

Three changes:

**(a) Tab index constants in `_onTabChanged` (lines 184-186):** shift by 1.

| Constant | Old | New |
|----------|-----|-----|
| `tradeIndex` | 1 | 2 |
| `dashboardIndex` | 2 | 3 |
| `moreIndex` | 3 | 4 |
| (new) `chartIndex` | — | 1 |

Initial-tab arg max-index check (line 76): `_isVantage ? 3 : 4` → `_isVantage ? 4 : 4`.

**(b) `_screens` list (lines 84-105):** insert a new entry at index 1 — a "blank" tab that triggers the chart push on first build. Two viable approaches:

**Option A (recommended — pure tab with auto-push):** Add a `ChartTabHost` widget at index 1 whose `initState` schedules a `WidgetsBinding.instance.addPostFrameCallback((_) => _openChartScreenVantage(...))` that pushes `ChartScreen`. After the user pops back, they land on Prices (index 0). Tapping the Chart tab again while still on Prices triggers another push.

**Option B (cleaner UX — empty placeholder + manual push):** Add a placeholder screen at index 1 with a "Tap to open chart" CTA that calls `_openChartScreenVantage(...)` when tapped. But this contradicts the requirement "tab tap should open chart".

**Going with Option A**, with one tweak: the push should NOT happen automatically if the user has just popped from the chart screen in the last few hundred ms (to avoid an infinite push-pop loop). Use a flag `_chartPushedForCurrentSession` that resets on `didPop` of the chart route, OR simpler — just push once per tab visit and accept that rapid re-taps may push twice (the second push just replaces the visible chart with a fresh instance).

**Cleanest implementation:** use a `StatefulWidget` wrapper `ChartTabHost` that:
1. Holds `final Function(String) onOpenChart` callback
2. In `initState`, schedules `WidgetsBinding.instance.addPostFrameCallback((_) => onOpenChart(currentSymbol))` — but ONLY if `currentSymbol.isNotEmpty`. Otherwise show a brief loading state then retry.
3. Tracks `_hasPushed` to prevent double-push when the widget re-builds on tab change.
4. Shows an empty `Container()` body so the bottom nav still renders.

This is the same pattern `_openChartScreenVantage` already uses, just triggered by tab tap instead of row tap.

**(c) `_openChartScreenVantage` (line 54):** the function itself stays the same. It already correctly does `Get.to(...) → ChartScreen → VantageChartLayout`. We just need to call it from the new tab host.

### 3. `lib/screens/home/instruments_screen.dart`

The watchlist row tap (`_navigateToChartWithSymbol` at line 701) ALREADY calls `widget.onNavigateToChart(symbol)` which goes to `_openChartScreenVantage(symbol)`. **No code change needed here.** This is the exact behavior we want the new Chart tab to replicate.

**However:** the comment block at lines 480-490 should be updated to mention the new Chart tab in the doc comment (if any). Minor.

### 4. `lib/screens/home/chart_screen.dart`

**No change to behavior** — the Vantage branch (line 1579) already returns `VantageChartLayout`. We may want to add a small comment noting that this screen is now also reachable via the Chart tab (not just watchlist tap), so future devs know both entry paths exist.

### 5. `lib/screens/home/brands/vantage/vantage_chart_layout.dart`

**No change needed** — it already has the back button (`onBack: () => Navigator.of(context).maybePop()` at line 320) and no bottom nav. It works as a pushed full-screen route.

The only minor cleanup: the top-right "settings" button calls `widget.onNavigateToTab?.call(1)` (line 333) assuming "1" is the Trade tab. **This needs to become 2** because Trade is now at index 2 in the 5-tab layout. This is a hidden bug waiting to happen — fixing it preemptively.

### 6. `lib/screens/home/dashboard_screen.dart`

Multiple hardcoded `FlavorConfig.isVantage() ? 1 : 2` calls (lines 504, 840, 949, 998) all assume Trade is at index 1 in Vantage. These are the "Trade" icon button onTap handlers in account cards. **These all need to become `2`** (the new Trade tab index).

Same for the celestial account card (line 462) — but Celestial keeps its own 5-tab layout (already has Chart at idx 1), so celestial doesn't change. The `?:` ternary handles that branch.

---

## Files NOT Changed (just verified)

- `lib/app/ui_registry.dart` — `_uiParentByClient` already maps all 8 Vantage children to `'vantage'`. No change.
- `lib/screens/finance/presentation/finance_ui_registry.dart` — `_usesVantageUi` already lists all 8. No change.
- `lib/screens/home/brands/vantage/vantage_dashboard_layout.dart` — no tab-index references.
- `lib/screens/home/brands/vantage/vantage_more_layout.dart` — let me verify this quickly.

---

## Step-by-Step Implementation Order

1. **Add the 5th tab item** in `trading_bottom_navigation.dart`. Use existing `chart.svg` / `chart_bold.svg`. Wrap Row in `FittedBox(fit: BoxFit.scaleDown)` if needed.
2. **Shift tab indices** in `trading_main_screen.dart` constants (`tradeIndex=2`, `dashboardIndex=3`, `moreIndex=4`, new `chartIndex=1`).
3. **Insert `ChartTabHost` widget** at index 1 in `_screens` list. It calls `_openChartScreenVantage(symbol)` on first build. Need to read the current symbol from `SymbolSelectionService` to pass through.
4. **Fix hardcoded index `1 → 2`** for Trade in `vantage_chart_layout.dart` line 333 (the top-right icon's `onNavigateToTab` call).
5. **Fix hardcoded `? 1 : 2` to `? 2 : 2`** for the Trade buttons in `dashboard_screen.dart` (4 occurrences).
6. **Build and test** on each child brand: vantage, pipze, baazex, gtxprime, kantara, skyriss, telifox, tenax.

### Testing checklist per brand
- [ ] Bottom nav shows 5 tabs: Prices / Chart / Markets / Accounts / Settings
- [ ] Prices tab still shows watchlist
- [ ] **NEW:** Tap Chart tab → opens `VantageChartLayout` full-screen with back button
- [ ] Back button returns to Prices tab
- [ ] Markets tab still shows Trade screen (now at index 2)
- [ ] Accounts tab still shows Dashboard (now at index 3)
- [ ] Settings tab still shows More (now at index 4)
- [ ] Watchlist row tap still works (opens chart, same flow)
- [ ] Dashboard account card "Trade" icon still navigates to Trade tab
- [ ] Bottom nav is HIDDEN while on chart full-screen route
- [ ] No overflow on 360w device (smallest target)

---

## Edge Cases to Handle

1. **Initial tab = Chart via deep link:** if user logs in and `Get.arguments` is `1` (the new chart tab index), `ChartTabHost` should still push the chart screen. Need to make sure `currentSymbol` is available before the push.
2. **Symbol not loaded yet on first visit to Chart tab:** `SymbolSelectionService.currentSymbol` may be empty if no instrument has been selected. `ChartTabHost` should wait for `InstrumentsController.allInstruments` to populate, then push with the default symbol (XAUUSD).
3. **Rapid double-tap on Chart tab:** the `KeepAliveWrapper` keeps the tab host alive. A second tap on the same tab while the chart is open will trigger `_onTabChanged(1)` again but the guard `if (_currentIndex == index) return;` (line 178) prevents re-pushing. Good.
4. **Pop back from chart then tap Chart tab again:** `_chartPushedForCurrentSession` flag must reset. Use a static ValueNotifier `chartTabHasPushed` that flips true on push and false when the pushed route is popped (listen via `RouteObserver` or `Get.back()` result).
5. **Tenax multi-broker + Chart tab:** if the user is on Tenax and hasn't picked a broker yet, tapping Chart tab should still work (it doesn't depend on broker state). Chart tab opens with the last-used symbol. No issue.
6. **Logout / app kill while on chart:** chart screen disposal already cleans up streams (chart_screen.dart dispose() at line ~1280). Pushed route gets popped with the app. No issue.

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Bottom nav overflow on small screens | Medium | Wrap Row in FittedBox(scaleDown) or reduce selected-state padding |
| Existing flows that called `onNavigateToTab(1)` (Trade) break | High | Grep for ALL hardcoded `1` in Vantage UI files and fix; will catch via #5 and #6 in impl order |
| ChartTabHost infinite push loop | Low | `_hasPushed` flag in widget state |
| Account card "Trade" button broken | Medium | Fixed in step #6 (dashboard_screen.dart) |
| Watchlist tap accidentally routes to Chart tab instead of pushing | None | `_navigateToChartWithSymbol` calls `widget.onNavigateToChart(symbol)` which is `_openChartScreenVantage` (push), NOT `onNavigateToTab`. Unchanged. |

---

## Estimated Effort

- 4 files to edit, ~80 lines of total diff
- 1 widget to create (`ChartTabHost`, ~30 lines)
- 1 build verification per brand × 8 brands = 8 builds (or 1 build with `--dart-define=CLIENT=<each>`)
- ~1 hour implementation + 30 min testing