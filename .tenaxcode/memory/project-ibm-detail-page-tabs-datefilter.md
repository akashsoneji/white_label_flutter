---
name: project-ibm-detail-page-tabs-datefilter
description: "IBM detail page: date filter confirmed wired; REAL bug is hardcoded tab logic (needs isClient/isIb dynamic detection); fix plan + api methods"
type: project
createdAt: 1787638053870
updatedAt: 1787638085478
---

VERIFIED (2026-08-25) controller side of IBM detail page — date filter IS fully wired:
- `fetchClientOverview(id, period, from, to)` L725 → api_provider.getClientOverview → assigns `currentClientOverview`. ✓ sends period.
- `fetchClientTrades` L756 → `currentClientTrades`. ✓
- `fetchNetworkNode(id, period, from, to)` L789 → `currentNetworkNode`. ✓
- `getNetworkNodeChildren` L816 returns people list. ✓
So tapping 30D/MTD/Custom DOES call the API with the right period and reassigns the Rx. If UI "does nothing", it's because figures are identical OR the Network tab in detail page renders from a source not updated by fetchNetworkNode. Date picker `showIbmDateRangeDialog` EXISTS and is wired at L387-405. Custom tap DOES open it. **Date filter likely already works** — confirm by testing whether Overview numbers change on 30D vs All.

**THE REAL BUG = tab logic.** `ibm_client_profile_screen.dart` L48-50:
```
_tabNames = widget.isYou
  ? ['Overview','Network','Symbol-wise commission']
  : ['Overview','Trades','Network','Symbol-wise commission','Commission plan'];
```
Hardcoded — ignores whether person is client vs IB. Per doc §3 must be dynamic:
- fetch `/portal/clients/{id}` (isClient = success/non-empty) + `/portal/network/{id}` (isIb) on load IN PARALLEL.
- tabs = ['Overview'] + (isClient?['Trades']:[]) + (isIb?['Network','Symbol-wise commission'] + (!isMe?['Commission plan']:[]) : []).
- Counts: plain client=2, isYou/isMe=3, partner-no-account=4, both=5.
- Needs TabController rebuilt after flags resolve (currently `late` in initState). Use a nullable controller + setState after both fetches return, or build tabs after a combined load future.

**api_provider methods available:** getClientOverview(id) = /portal/clients/{id}; getPartnerDetail(partnerUserId) L437 = /portal/network/{id} (controller `fetchPartnerDetail` L1146). Constructor: IbmClientProfileScreen(clientId, clientName, isYou).

NEXT ACTION: refactor initState to detect isClient/isIb and build tabs dynamically + rebuild TabController.
