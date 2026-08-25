---
name: project-ibm-network-tree-empty-bug
description: "IBM Network tab renders empty white cards on mobile; tree row builder / _extractTreeNodes parsing suspect in ibm_clients_screen.dart"
type: project
createdAt: 1787573180804
updatedAt: 1787573180804
---

IBM Manager Portal "Clients & Network" → Network tab shows EMPTY WHITE CARDS on mobile where the network tree rows (You / ibm sub one / ibm sub two / robert d) should render. Web renders fine.

**Why:** User reported (2026-08-24) with screenshots — web shows full nested tree with rows; Flutter mobile shows blank white containers below the "Show whole network / Open full page" banner and the search/expand/collapse row.

**How to apply:** Bug is in `lib/screens/ibm/presentation/pages/ibm_clients_screen.dart`. Tree data comes from `IbmController.clientsNetworkTreeData` (RxMap, populated by `fetchClientsNetworkTree` → GET ibm/portal/clients/network-tree). Rendering path: `_buildMyClientsTab()` (L223) → `_extractTreeNodes(treeData)` (L284) → tree row builder. The empty cards mean `_extractTreeNodes` returns nodes but the row builder renders empty, OR the API envelope nesting (data.data / tree / nodes / children) isn't matched by `_extractTreeNodes`. Check the exact JSON shape the API returns vs what `_extractTreeNodes` looks for. Node shape per API map (GET /portal/network/{id}/node): {people, own clients, sub-IBs one level; children/tree keys}. Also note many fake fallback defaults in this file (L241 total ?? 1, L253 direct ?? 2, L254 total ?? 3, L261 earned ?? 0.09) that must be removed — they show fake "3"/"0.09" when data missing.

**Currency util already created:** `lib/screens/ibm/utils/ibm_currency.dart` → `IbmCurrency.format(num, currencyCode:)`. Use it to replace hardcoded `\$` across IBM screens.
