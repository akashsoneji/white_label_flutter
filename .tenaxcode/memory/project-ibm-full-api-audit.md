---
name: project-ibm-full-api-audit
description: "Full IBM API provider+controller audit vs doc: 8 mismatches (dashboard period default, network/performance missing from/to/q, clients missing search/status/link_id/from/to, symbols missing q, cancelPayout drops reason, tree-summary drops period) + all-OK list"
type: project
createdAt: 1787639841976
updatedAt: 1787639841976
---

FULL IBM API AUDIT (2026-08-25) — code vs `IB_MANAGER_PORTAL_API_UI.md`. Files: `lib/screens/ibm/data/ibm_api_provider.dart` (provider), `lib/screens/ibm/view_models/ibm_controller.dart` (controller). Base prefix OK: provider strings are `ibm/portal/...`, ApiService prepends `/api/` → `/api/ibm/portal/...` ✓.

**REAL MISMATCHES TO FIX (provider):**
1. `getPortalDashboard():25` — period default is `'this_month'`, spec wants `mtd`. (controller fetchDashboard():240 also passes `period ?? 'this_month'`.) FIX both defaults to `mtd`.
2. `getPortalNetworkPerformance():410` — MISSING `from`,`to`,`q`; sends EXTRA `currency`. Spec query = period,from,to,q,sort,dir,per_page,page. Add from/to/q.
3. `getPortalClients():64` — MISSING `search`,`status`,`link_id`,`from`,`to`. Only sends period,scope,page,per_page=25. Direct Clients tab toolbar (search/status/referral-source filters) + custom date can't work without these. Add them (optional params).
4. `getNetworkSymbols():325` — MISSING `q`; sends EXTRA `from`,`to` (spec only period,q). Add q. (from/to harmless but not in spec.)
5. `cancelPayout():509` — accepts `reason` param but NEVER sends it in DELETE body. FIX: send body {reason}.
6. `getClientsNetworkTree():457` — no default `today` for period (omits period if not passed). Minor: pass period default 'today' where called.

**CONTROLLER period-drop bugs:**
7. `fetchNetworkTreeSummary():1104` → `getPortalNetworkTreeSummary()` forwards NO period (siblings getClientsNetworkTree + getPortalNetworkSummary DO). Network tab date-filter can't affect tree-summary header. Provider getPortalNetworkTreeSummary():405 also has no period param — add one. (Doc §2b uses period=today for tree; tree-summary itself may be period-scoped — verify server, but add period support.)
8. `fetchPartnerWallet():1163` → `getPartnerWallet(id)` forwards NO period while fetchPartnerDetail DOES. If /network/{id}/wallet is period-scoped, detail-page date filter won't move wallet numbers. Lower priority (wallet is mostly lifetime/available, may be period-agnostic — doc §4 wallet shape has no period). Probably OK to leave.

**ALL OTHER ENDPOINTS OK** — dashboard/activity, network, tree-summary(path), network/{id}(+node/wallet/links/plan), clients/{id}(+trades, per-account accounts/{aid}/trades), requests(+approve{plan_id,plan_group_ids[]}/reject{reason}), partner-plans(+template/sub-ibs/{id}/assign{partner_user_id}/{id} detail), wallet(+transactions{currency,type,page,per_page}/withdraw{currency,amount,method_slug,withdrawal_method_id}), plan, plan/groups, links CRUD(+{id}/clients), marketing(+{id}/download, query category,q), client-visibility(GET+POST{plan_group_ids[],default_plan_group_id?}). All paths + params correct.

**Rx fields (controller):** currentClientOverview:717, currentClientTrades:718, currentNetworkNode:719, currentNetworkSymbols:720, currentNetworkPlan:721, currentPartnerDetail:31, currentPartnerWallet:32, currentPartnerLinks:33, clientsData:36, clientsNetworkTreeData:37, dashboardData:25, networkTreeSummaryData:29, networkPerformanceData:30, walletData:48, myPlanData:53, materialsList:889, clientVisibilityGroups:932, clientPeriod:40, clientScope:41.

**Fetch methods forward period correctly:** fetchClientOverview:725, fetchClientTrades:756, fetchNetworkNode:789, getNetworkNodeChildren:816, fetchNetworkSymbols:842, fetchClientsNetworkTree:1194, fetchPartnerDetail:1146, fetchNetworkSummary:1090, fetchLinkStats:1059, fetchLinkClients:1073, fetchClients:299(via clientPeriod/clientScope Rx). fetchNetworkPlan:869 (plan, no period — OK per spec).

NEXT ACTION when resumed: apply fixes #1-#5 (clear wins) in provider (+ controller default for #1). #3 needs optional params threaded from screens (bigger — the Direct Clients toolbar). Confirm with user whether to wire the toolbar filters or just add the params.
