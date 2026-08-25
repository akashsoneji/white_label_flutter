---
name: project-ibm-my-commission-rebuild
description: "MID-EDIT My Commission: sub-tab branch wired at L696-842; NEXT add _buildPayoutsBody() + _buildMyPlanBody() methods before _buildStatCard (~L848), then analyze. Full field/helper/shape notes included."
type: project
createdAt: 1787644394089
updatedAt: 1787644747763
---

MID-EDIT ibm_wallet_screen.dart _MyCommissionTabState (2026-08-25). Sub-tab branch NOW WIRED in build(): L696 `SizedBox(height:14.h)`, L697 `if (_selectedSubTab == 'Earnings') ...[`, then filter Row + ledger, L837 `}).toList(),`, L838 `] else if (_selectedSubTab == 'Payouts')`, L839 `_buildPayoutsBody()`, L840 `else`, L841 `_buildMyPlanBody(),`, L842 `],` closes Column children. Sub-tab onTap (L653-660) calls _fetchMyPlan() when 'My Commission Plan'.

**STILL TODO — 2 builder methods DO NOT EXIST YET (that's the current analyze errors _buildPayoutsBody/_buildMyPlanBody undefined + _cancelPayout/_planError unused will clear once used):** Add BOTH as methods of _MyCommissionTabState (insert right before `Widget _buildStatCard(` which is at ~L848):
1. `Widget _buildPayoutsBody()` — read `final payouts = _ibmController.walletData['payouts']` (List). If empty → Padding+centered Text 'No payouts yet'. Else Column of rows; each payout Map p: Requested=p['requested_at'], Amount=IbmCurrency.format(_asNum(p['amount']), currencyCode: p['currency']?.toString() ?? _currency()), Status=p['status'], Paid=p['paid_at'] ?? '—'. Trailing: if status is 'pending'/'open'/'requested' (p['status'].toString().toLowerCase() one of those) show a TextButton 'Cancel' → _cancelPayout(_asNum(p['id']).toInt()) (id may be int; use `(p['id'] is int? p['id'] : int.tryParse(p['id'].toString()) ?? 0)`). Wrap in Obx? build() is ALREADY inside Obx so no — just read walletData directly (reactive via outer Obx).
2. `Widget _buildMyPlanBody()` — if _planLoading → centered CircularProgressIndicator(color: AppColors.primary). if _planError!=null → centered Text(_planError!, red). if _myPlan==null → Padding centered Text 'No plan assigned'. Else read plan Map: name=_myPlan!['plan']?['name'] ?? _myPlan!['name'] ?? 'Commission plan'; groups=_myPlan!['groups'] ?? _myPlan!['plan']?['groups'] ?? []. Show plan name (bold) then for each group (Map g): g['name']/g['symbol_group'] and rate g['rate']/g['rate_per_lot'] as read-only rows. Keep simple; per doc GET /portal/plan shape may vary — guard with ?. and _asNum.

Helpers available in state: _asNum(v), _currency(), _fmt(v), _wallet0([root]), _minPayout(), _fetchMyPlan(), _cancelPayout(int), IbmCurrency.format. Fields: _myPlan(Map?), _planLoading(bool), _planError(String?).

After adding: run `~/development/flutter/bin/flutter analyze lib/screens/ibm/presentation/pages/ibm_wallet_screen.dart`. Note: collection-if `if(c)...[..] else W1 else? ` — structure is `if...[] else if(..) W else W` which is VALID Dart collection-if with spread on first branch only; the transient 'Expected ]' error should resolve once builder methods exist. If analyze still complains about the else-if collection form, fallback: replace the 3 branch lines with a single helper call `_buildSubTabBody()` that does a normal if/else returning Widget, and put the Earnings ledger Column into it too — but PREFER keeping current spread form if analyze passes.

CommissionPlansTab (top-level tab 2) = partner-plan CRUD, KEEP as-is. flutter bin=~/development/flutter/bin/flutter. Links: [[project-ibm-my-commission-rebuild]].
