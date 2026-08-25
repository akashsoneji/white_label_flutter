---
name: project-ibm-4tab-verification-findings
description: "IBM 4-tab verification: api_provider endpoints all correct; screen initState calls mapped; open items (scope total vs network, wallet fetch, response parsing)"
type: project
createdAt: 1787637516467
updatedAt: 1787637516467
---

VERIFICATION FINDINGS (2026-08-25) — IBM 4-tab API check. Endpoints in api_provider are CORRECT.

**api_provider (`ibm/data/ibm_api_provider.dart`) endpoints confirmed:**
- getPortalClients (L64): `ibm/portal/clients`, default scope='direct', sends period+scope query. ✓
- getPortalRequests (L124): `ibm/portal/requests`, status query. ✓
- getMarketingMaterials (L372): `ibm/portal/marketing` (+ category/q query), download L392 `.../marketing/{id}/download`. ✓
- getClientVisibility (L348): `ibm/portal/client-visibility`; update L366 POST same. ✓
- getMyPlan (L504): `ibm/portal/plan`. ✓
- getPortalWallet (L81): `ibm/portal/wallet`. ✓
- getClientsNetworkTree (L457): `ibm/portal/clients/network-tree`. ✓
- getPortalNetworkTreeSummary (L405): `ibm/portal/network/tree-summary`. ✓
- getNetworkNode (L309): `ibm/portal/network/{id}/node`. ✓

**My Clients screen (`ibm_clients_screen.dart`) initState (L67-95):** _sectionTabController length:2 (My Clients / Sub-IB Requests). On load calls: fetchRequests(72), fetchClients(87), fetchClientsNetworkTree(88), fetchNetworkTreeSummary(93), fetchNetworkPerformance(94), fetchNetwork(95). Direct/Network sub-toggle: fetchClients(scope:'direct') L424, fetchClients(scope:'network') L433. Lazy expand: getNetworkNodeChildren(partnerId) L1592/L1644. Requests refresh after approve/reject L2543/L2586.

**POTENTIAL ISSUE TO CHECK:** doc says Network tab needs `clients?scope=total&per_page=1` for network.summary totals — screen calls fetchClients(scope:'network') not 'total'. Verify controller.fetchClients scope handling + whether 'network' vs 'total' matters. Also verify Marketing initState calls fetchMarketingMaterials, and Settings initState calls fetchClientVisibility+fetchMyPlan+fetchWallet (earlier read showed settings initState calls fetchClientVisibility, fetchDashboard, fetchMyPlan, fetchLinks — NOT fetchWallet; wallet balance shown in More header via walletData — check if fetchWallet called anywhere on More entry).

**Still TODO:** (1) read controller.fetchClients (L299) + fetchMarketingMaterials (L895) + fetchClientVisibility (L937) bodies to confirm they parse response into the Rx fields the screens read. (2) confirm Marketing screen initState. (3) confirm Settings reads clientVisibilityGroups/selectedVisibleGroupIds/defaultVisibilityGroupId/myPlanData correctly. (4) decide if scope 'network' vs 'total' is a real bug.
