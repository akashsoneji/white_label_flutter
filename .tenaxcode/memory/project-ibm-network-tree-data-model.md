---
name: project-ibm-network-tree-data-model
description: "RESOLVED: IBM network tree mobile fix — figures-by-user_id overlay, children dedup, master /node enrichment, Open nav"
type: project
createdAt: 1787634846028
updatedAt: 1787635569811
---

RESOLVED (2026-08-25): IBM Network tab mobile tree in `lib/screens/ibm/presentation/pages/ibm_clients_screen.dart`.

**Correct data model:** `/clients/network-tree` gives STRUCTURE (data.nodes[0] = synthetic direct root, ib_user_id=master; children[] = real sub-IB rows; nodes carry ONLY label/ib_user_id/counts, NO figures). `/portal/network/{id}/node` gives FIGURES: data.people[] = id's DIRECT downline, each WITH own[]+branch[] + user_id. So a node's own figures come from its PARENT's /node people[] entry, keyed by user_id.

**Final implementation:**
- `_nodeFiguresById` (Map<int,Map>) at ~L55: figures keyed by user_id.
- `_applyNodeResponse(int id, List<Map> people)`: normalises each person, stores `_nodeFiguresById[uid]=person` AND `_lazyChildrenCache['node_$id']=people`.
- `_enrichVisibleTreeRows()`: derives masterId = nodes[0].ib_user_id, fetches master /node, applies response → root rows get figures on first paint.
- Row builder: `nodeKey = 'node_$partnerId'`; overlays `_nodeFiguresById[partnerId]` onto node (fixed the "every row identical $200/$0.09" bug — old code copied cached.first = first CHILD); children = `_lazyChildrenCache[nodeKey]` if non-empty ELSE rawChildren (fixed duplicate rows — old code concatenated both).
- On-expand handlers route through `_applyNodeResponse(partnerId, fetched)`.
- `getNetworkNodeChildren(id, period:)` returns List<Map> of people.

**Open→ nav:** `Get.to(IbmClientProfileScreen(clientId: partnerId, clientName: name))` — partnerId IS ib_user_id (from normalised user_id/ib_user_id). Detail screen uses clientId for all /portal/network/{id}/* endpoints. Works for both master and sub-IBs. Analyzer clean.

`_normaliseTreeNode` maps label→name, ib_user_id→user_id, sub_ib_count→sub_ibs, derives clients_tree. `_extractTreeNodes` unwraps synthetic direct/cascade root unconditionally (dropped the walletData['user_id'] dependency).
