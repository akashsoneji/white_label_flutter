---
name: project-ibm-network-tree-own-vs-branch-fix
description: "IBM network tree row shows branch totals instead of own — fix to prefer own[] for the row's Sub-IB (white_label + crmapp)"
type: project
createdAt: 1787824478174
updatedAt: 1787824478174
---

**RESOLVED (2026-08-27):** IBM network tree row figures showed WRONG values (branch totals instead of own). Web shows correct figures on the same API.

**Root cause:** `lib/screens/ibm/presentation/pages/ibm_clients_screen.dart` `Widget _buildNetworkRow(...)` (~L1519-1573) read row figures as `branch['deposits'] ?? own['deposits']`, etc. — `branch[]` was checked FIRST, so a Sub-IB's row displayed their BRANCH aggregates (downline totals) instead of the Sub-IB's OWN trading activity. `branchEarned` then double-counted by also falling back to `branch['commission']`.

**Correct semantics:** Each row represents the Sub-IB themselves — `own[]` is the Sub-IB's own trading; `branch[]` is what their downline generated (used only by the PARENT's view, not this row).

**Fix applied in BOTH apps** (files were identical — `diff` returned nothing): change precedence to `own[]` first, reserve `branch[]` for `branchEarned` only:
- `deposits = own['deposits'] ?? node['deposits'] ?? 0`
- `net = own['net'] ?? own['net_funding'] ?? node['net'] ?? 0`
- `lots = own['lots'] ?? node['lots'] ?? 0`
- `earned` (YOU EARNED) = `own['commission'] ?? node['you_earned'] ?? node['commission'] ?? 0`
- `branchEarned` = `node['branch_earned'] ?? branch['commission'] ?? branch['you_earned'] ?? node['commission'] ?? 0`

After fix, the user's example (Sub-IB "ibm sub one" /user_id 39, fetched via parent /node user_id 38):
- Was: DEPOSITS $200.00, NET $200.00, LOTS 0.03, YOU EARNED $0.09 (all from branch).
- Now: DEPOSITS $100.00, NET $100.00, LOTS 0, YOU EARNED $0.00, BRANCH EARNED $0.09 — matches web.

flutter analyze: white_label = 0 issues; crmapp = 17 pre-existing `withOpacity` deprecation infos (unrelated).
