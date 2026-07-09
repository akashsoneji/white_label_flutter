---
name: project-chart-tab-autopush-from-ontabchanged
description: "Vantage Chart tab: simplified ChartTabHost + push from _onTabChanged"
type: project
createdAt: 1783588699859
updatedAt: 1783589921757
---

Vantage 5-tab Chart tab auto-push bug + fix
The Chart tab in `lib/screens/home/trading_main_screen.dart:_onTabChanged` auto-pushes `ChartScreen` (which renders `VantageChartLayout` for Vantage UI brands) when the user navigates to index 1. This applies to all 8 Vantage UI brands (vantage + 7 children: pipze, baazex, gtxprime, kantara, skyriss, telifox, tenax).

**Why:** `ChartTabHost` originally drove the auto-push via `isSelected: _currentIndex == 1` — but `_screens` is a `late List<Widget>` built ONCE in `initState()`. So `isSelected: false` was baked into the host even after the user tapped the Chart tab. Result: blank white PageView, no chart pushed, bottom nav stays visible (because route wasn't pushed), top-right settings icon's `onNavigateToTab(2)` never fires.

**How to apply:**
- `ChartTabHost` is now a STATELESS, inert transparent placeholder (`ColoredBox(Colors.transparent)`). The push is driven entirely from `_onTabChanged` in `trading_main_screen.dart` (post-frame callback, `_isVantage && index == 1 && previousIndex != 1`).
- Guard against double-push via `Get.currentRoute.contains('ChartScreen')`.
- Resolve initial symbol safely via `Get.isRegistered<SymbolSelectionService>()` — fall back to 'XAUUSD' if not registered yet.
- `onSettingsTap` in `vantage_chart_layout.dart:364` calls `widget.onNavigateToTab!(2)` if non-null, else pops (standalone context).

**Affected files:**
- `lib/screens/home/trading_main_screen.dart` (added push logic, imports `'../../services/symbol_selection_service.dart'`)
- `lib/screens/home/chart_tab_host.dart` (simplified to StatelessWidget — no more isSelected/onNavigateToChart)
- `lib/screens/home/brands/vantage/vantage_chart_layout.dart` (onSettingsTap cleaned up to NOT pop + call separately — relies on callback to do both)

Related: [[project-vantage-5-tab-chart-plan]], [[project-baazex-ui-tree-fix]].
