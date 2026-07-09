---
name: project-3-parents-7-children-2026-07-09
description: "3 parents + 7 Vantage children — Chart tab applies to all Vantage UI brands"
type: project
createdAt: 1783590523898
updatedAt: 1783597879705
---

Project has 3 parents + 7 children (10 brands total) as of 2026-07-09
**Why:** user asked to cross-check that all Vantage UI changes (specifically the new Chart tab feature) apply to every Vantage child. Counting reveals:

**Parent brands (3) — each owns its own UI tree:**
1. **Vantage** (`lib/screens/home/trading_main_screen.dart`) — 5-tab nav: Prices(0)/Chart(1)/Markets(2)/Accounts(3)/Settings(4). `FlavorConfig.usesVantageUi() == true`.
2. **Celestial** (`lib/brands/celestial/celestial_main_shell.dart`) — 5-tab standalone tree. `FlavorConfig.usesVantageUi() == false`, `FlavorConfig.usesParentUi() == true`.
3. **Meta** (`lib/brands/meta/meta_main_shell.dart`) — standalone shell. `FlavorConfig.usesVantageUi() == false`, `FlavorConfig.usesParentUi() == true`.

**Vantage children (7) — inherit Vantage's UI tree:**
- baazex, gtxprime, kantara, pipze, skyriss, telifox, tenax

All 7 are registered in three places:
- `lib/flavor_config.dart` `usesVantageUi()` const set (8 entries: 7 children + vantage)
- `lib/app/ui_registry.dart` `_uiParentByClient` map (8 entries mapped to 'vantage')
- `lib/screens/finance/presentation/finance_ui_registry.dart` `_usesVantageUi` getter (8 entries)

**How to apply:**
- When adding a new Vantage child, register it in ALL THREE places plus add a `Flavor` enum + switch case in `flavor_config.dart` + create `lib/clients/<name>/config.dart` + `assets/brands/<name>/brand.yaml` + Android manifest + gradle entry.
- The `_configFor` switch in `flavor_config.dart` MUST have a case for every flavor — missing case throws at runtime when `activateByName(...)` lands on it.
- `Celestial` and `Meta` MUST NOT be added to `_usesVantageUi` getters — they are parents with their own UI tree. Adding `celestial` to `finance_ui_registry.dart:_usesVantageUi` was a pre-existing bug (cleaned up 2026-07-09).
- `usesParentUi()` const set = {'celestial', 'meta', 'vantage'} — these are the brands that own their own shell and don't inherit Vantage's tree.
- **`lib/routes/app_pages.dart` `_Paths.TRADING` routes through `UiRegistry.instance.tradingMain()`** (was hardcoded to `TradingMainScreen`, which prevented CelestialMainShell / MetaMainShell from ever showing). Celestial UI was previously mapped `'celestial' → 'vantage'` in `_uiParentByClient` — fixed to `'celestial' → 'celestial'` so CelestialMainShell renders.

**Cleanups applied 2026-07-09:**
- Removed stale `'celestial'` entry from `finance_ui_registry.dart:_usesVantageUi` (was incorrectly routing Celestial's finance screens to Vantage's tree).
- Removed stale `'acme'` entry from `ui_registry.dart:_uiParentByClient` (leftover from a previous `add_flavor.dart` test run).

**Meta Chart screen (`lib/brands/meta/meta_chart_screen.dart`) on 2026-07-09 was replaced wholesale with the Celestial TRADYN-style chart implementation, themed in `MetaTheme` (Meta blue + Meta dark palette)**. The new screen has the same 6-icon toolbar (☰, indicator, crosshair, M5 timeframe, dark-mode, battery), the "Trade" pill that toggles an inline Buy/Sell panel showing live bid/ask + lot stepper (`− 0.01 +`), and live TradingView Widget via WebView. The chart pulls from `ChartSocketController`, `InstrumentsController`, and `TradingController` (same GetX services as Celestial) — no extra wiring was needed since Celestial and Meta share the same trading stack.

Related: [[project-baazex-ui-tree-fix]], [[project-vantage-child-brands-2026-07-03]], [[project-child-flavor-pattern]], [[project-chart-tab-autopush-from-ontabchanged]].
