---
name: project-vantage-5-tab-chart-plan
description: "Vantage 5-tab plan: Chart tab added between Prices and Markets"
type: project
createdAt: 1783583059264
updatedAt: 1783583059264
---

Vantage (parent) + 7 children use a 4-tab bottom nav (Prices/Markets/Accounts/Settings). Plans exist to add a 5th "Chart" tab between Prices and Markets that opens the existing VantageChartLayout as a pushed full-screen route (same as watchlist row tap does today via `_openChartScreenVantage` in `lib/screens/home/trading_main_screen.dart:54`).

**Why:** user wants the chart accessible via a dedicated tab in addition to the watchlist tap. The chart screen must be a pushed route (NOT a tab inside the PageView) so the back button works and the bottom nav is hidden — matching the current watchlist → chart behavior.

**How to apply:** When implementing, the chart tab is a `StatefulWidget` host that auto-pushes `ChartScreen` (which returns `VantageChartLayout` for Vantage UI brands) on first build, using `_openChartScreenVantage(symbol)` callback. After pushing, the chart is a route on top of the PageView, so the parent scaffold's bottom nav is naturally hidden. Tab indices for the existing 4 tabs must shift: Markets 1→2, Accounts 2→3, Settings 3→4. Hardcoded `? 1 : 2` ternaries for "go to Trade tab" in `lib/screens/home/dashboard_screen.dart` and the top-right icon's `onNavigateToTab(1)` in `lib/screens/home/brands/vantage/vantage_chart_layout.dart:333` must update to `2` (or `: 2` for the ternary's non-Vantage branch).

**Affected brands (8 — the `usesVantageUi()` set):** vantage, pipze, baazex, gtxprime, kantara, skyriss, telifox, tenax.

**Plan file:** `.xelion/plans/add-chart-tab-vantage-5-tab.plan.md` (full step-by-step, file list, edge cases, risk assessment).
