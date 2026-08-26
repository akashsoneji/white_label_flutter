---
name: project-ibm-subib-performance-card
description: "IBM dashboard Sub-IB Performance card: make it list ALL rows dynamically + wire View all to Network tab (currentTabIndex=2)"
type: project
createdAt: 1787662699018
updatedAt: 1787662764651
---

IBM dashboard "Sub-IB Performance" card — `lib/screens/ibm/presentation/pages/ibm_manager_portal_screen.dart`. Method `_buildSubIbPerformance(dynamic rowsList)` at L602.

**FACTS CONFIRMED (2026-08-25):**
- Controller: `final IbmController controller = Get.find<IbmController>();` (L19). Network tab index = 2. Switch via `controller.currentTabIndex.value = 2` (RxInt currentTabIndex L62; also `controller.changeTab(index)` sets it L206).
- `_parseDouble(v)` helper exists in this file. `_buildSimpleStat`, `AppColors.border/card/primary/textPrimary/textSecondary/textGrey/whiteColor` used.
- `_buildSectionCard` NOW UPDATED (this session) to: `_buildSectionCard(String title, String actionText, Widget child, {VoidCallback? onAction})` — action text is a GestureDetector(onTap:onAction); turns primary + w600 when onAction != null.

**DONE THIS SESSION:**
1. Badge conditional at L665: `Builder` → `_parseDouble(active) >= 1` ? 'Low' orange : 'Inactive' red.
2. `_buildSectionCard` got optional `onAction`.

**STILL TODO (current task):**
1. Refactor `_buildSubIbPerformance` (L602-742): currently uses `rows.first` only. Change to render ALL rows dynamically. Extract the single-row Container (L633-740, the avatar+name+badge+netDeposit/earned+footer stats) into a helper `Widget _buildSubIbRow(Map row)` that computes name/clients/active/currencies/firstCurrency/netDeposit/earned/lots per-row, and in `_buildSubIbPerformance` build `Column(children: rows.map((r)=>_buildSubIbRow(r as Map)).toList())` with SizedBox(height:12.h) separators between rows.
2. Wire View all: the return `_buildSectionCard('Sub-IB Performance','View all', <child>)` → add `onAction: () => controller.currentTabIndex.value = 2,`.
Per-row derivation (from currencies.first): netDeposit=_parseDouble(firstCurrency['net_funding'] ?? firstCurrency['deposits']); earned=_parseDouble(firstCurrency['commission']); lots=_parseDouble(firstCurrency['lots']); clients=row['clients']??0; active=row['active_clients']??row['active']??0.
API GET /api/ibm/portal/network → data.rows[] (each: partner_user_id,name,status,has_partners,clients,active_clients,currencies[]). Test data has 2 rows (ibm sub one active_clients=1, robert d active_clients=0).
flutter bin=~/development/flutter/bin/flutter; analyze that one file.
