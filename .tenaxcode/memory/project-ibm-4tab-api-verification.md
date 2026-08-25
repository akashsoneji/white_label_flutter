---
name: project-ibm-4tab-api-verification
description: "IBM 4-tab API verification task: required endpoints per tab + controller fetch method line numbers"
type: project
createdAt: 1787637487014
updatedAt: 1787637487014
---

TASK (2026-08-25): verify the 4 IBM portal tabs call the correct APIs and render data correctly. Reference doc: `IB_MANAGER_PORTAL_API_UI.md` (828 lines, has full API map + response shapes).

**Required API calls per tab (from doc §1 table + §2/§9/§11):**
- **My Clients** (`ibm_clients_screen.dart`) — Direct tab: `GET /portal/clients?scope=direct`. Network tab (loadNetwork, 3 parallel): `GET /portal/network/tree-summary` + `GET /portal/clients?scope=total&per_page=1` + `GET /portal/clients/network-tree?period=today`. Lazy expand: `GET /portal/network/{id}/node`.
- **Sub-IB Requests** — `GET /portal/requests` (+approve/reject POST, `GET /portal/partner-plans`).
- **Marketing Material** (`ibm_marketing_screen.dart`) — `GET /portal/marketing` (query: category slug, q search). Download streams binary.
- **Settings** (`ibm_settings_screen.dart`) — `GET /portal/wallet`, `GET /portal/plan`, `GET /portal/client-visibility` (POST body `{plan_group_ids[], default_plan_group_id?}`).

**Controller (`ibm/view_models/ibm_controller.dart`) fetch methods exist:** fetchDashboard(240), fetchNetwork(283), fetchClients(299 has scope param), fetchRequests(323), fetchWallet(413), fetchLinks(478), fetchPlanGroups(514), fetchMarketingMaterials(895 has category+q), fetchClientVisibility(937), fetchMyPlan(1280), fetchNetworkTreeSummary(1104), fetchClientsNetworkTree(1194), fetchNetworkNode(789/823 = /network/{id}/node). All delegate to `_apiProvider` (ibm_api_provider.dart).

**Nav (done earlier this session):** bottom nav = 6 tabs (Dashboard, Promotion, Network, Commission, Links, More). More tab = `ibm_more_screen.dart` with 2 sub-tabs Marketing+Settings (both take `embedded:true` to hide their own IbmTopHeader). User NOW wants to confirm data flows correctly in: Clients&Network group, Marketing, Settings.

**Next:** check initState of each screen for correct fetch calls + verify screens read the right controller Rx fields.
