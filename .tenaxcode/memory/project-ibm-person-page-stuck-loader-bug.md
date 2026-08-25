---
name: project-ibm-person-page-stuck-loader-bug
description: "DEVICE LOGS: all IBM person APIs return 200 w/ correct data. Real bug = SingleTickerProviderStateMixin crash at L125 (rebuilding TabController) → fix to TickerProviderStateMixin. Plus Overview body 99891px overflow → wrap in SingleChildScrollView."
type: project
createdAt: 1787641145462
updatedAt: 1787642848434
---

IBM person page (`lib/screens/ibm/presentation/pages/ibm_client_profile_screen.dart`) — REAL ROOT CAUSE FOUND from device logs 2026-08-25.

**DATA IS FINE.** Device logs show all 4 calls return 200 with full correct data for sub-IB id 40 ("ibm sub two"): GET /api/ibm/portal/clients/40?period=mtd (client detail, is_direct=false, upline 38/39), GET /portal/network/40?period=mtd (partner depth=2, clients own/branch=1, own[] USD deposits 200 net 200 equity 155.01, sub_partners=0), GET /portal/network/40/wallet?period=mtd (wallets[0] available 0.15 lifetime_earned 0.15), GET /portal/network/40/links (links[0] IBMSUB2). So classification SHOULD be isClient=true + isIb=true → 5 tabs.

**THE CRASH (why it stays on loader / only Overview):**
`[Error] Platform Error: _IbmClientProfileScreenState is a SingleTickerProviderStateMixin but multiple tickers were created. A SingleTickerProviderStateMixin can only be used as a TickerProvider once.`
Stack: `_resolveTabsAndLoad.<anonymous closure>` at ibm_client_profile_screen.dart:125 → `new TabController` → SingleTickerProviderStateMixin.createTicker. The state class is declared `with SingleTickerProviderStateMixin` (~L28). In `_resolveTabsAndLoad`'s setState I do `_tabController.dispose(); _tabController = TabController(length: tabs.length, vsync: this);` — creating a SECOND ticker. SingleTickerProviderStateMixin allows only ONE ticker EVER (even after disposing the first), so the new TabController throws → setState closure throws → TabController left disposed/broken, tabs never rebuild → screen stuck.

**FIX #1 (the crash):** change `with SingleTickerProviderStateMixin` → `with TickerProviderStateMixin` at the state class declaration (~L27-28). That allows rebuilding the TabController when the tab set resolves. This is THE fix for the stuck/one-tab bug.

**FIX #2 (layout):** second screenshot after 30D tap shows `BOTTOM OVERFLOWED BY 99891 PIXELS`. The Overview body (_buildOverviewBody) is a Column placed in an unbounded-height context (TabBarView child) without scroll → giant overflow. Need the Overview tab body wrapped in SingleChildScrollView (or ListView). Check _buildOverviewTab/_buildOverviewBody (~L517+) — ensure the returned widget is scrollable. Likely the Obx returns a Column directly; wrap the body Column in SingleChildScrollView with padding.

**Also note:** logs confirm only ONE call each per load (no duplicate API calls) — user asked "how many times you call this api"; answer: once each, correct. period=mtd default is correct per doc.

flutter bin = `~/development/flutter/bin/flutter`. analyze target: that one file. Links: [[project-ibm-person-page-stuck-loader-bug]] [[project-ibm-detail-overview-zero-data-bug]].
