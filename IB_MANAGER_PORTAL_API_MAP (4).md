# IB Manager Portal — API Map (menu-wise)

Every API the **`/ib-manager-portal`** dashboard uses, grouped by menu section, with the
request and the response shape each returns.

- **Frontend API layer:** `crmfronend/src/components/ibmanager-portal/ibmanagerApi.js`
- **Menu definition:** `crmfronend/src/components/ibmanager-portal/sections.js`
- **Backend routes:** `crmwebadmin/core/Modules/IBManager/Routes/api.php` (L301–383)
- **Base URL:** `VITE_IBMGR_API` or `…/api/ibm` → all paths below are prefixed `/api/ibm/portal`
- **Auth:** `Authorization: Bearer <auth_token>`, middleware `auth:sanctum` + `ibm.auth`
- **Envelope:** every success is wrapped by `PortalController::ok()`:
  ```json
  { "success": true, "message": "…", "data": { /* the shapes below */ } }
  ```
  Failures → `{ "success": false, "message": "…", ...extra }` (HTTP 4xx). Laravel
  validation errors → `{ "message": "…", "errors": { "field": ["…"] } }` (422).

---

## Menu (sidebar / portal sections)

| # | Section (`key`) | Label | Route |
|---|---|---|---|
| 1 | `dashboard` | Dashboard | `/ib-manager-portal` |
| 1b | `ib-trade-win` | Promotion → Trade & Win (only if `tradewin` module on) | `/ib/trade-win` |
| 2 | `clients` | My Clients | `/ib-manager-portal/clients` |
| 3 | `requests` | Sub-IB Requests | `/ib-manager-portal/requests` |
| 4 | `sub-ibs` | Sub-IB Performance (hidden, via "View all") | `/ib-manager-portal/sub-ibs` |
| 5 | `plans` | Commission Plans | `/ib-manager-portal/plans` |
| 6 | `commission` | My Commission | `/ib-manager-portal/commission` |
| 7 | `referrals` | Referral Links | `/ib-manager-portal/referrals` |
| 8 | `marketing` | Marketing Material | `/ib-manager-portal/marketing` |
| 9 | `settings` | Settings | `/ib-manager-portal/settings` |
| + | `people/:id` | Person drill-down (from Clients / Sub-IBs) | `/ib-manager-portal/people/:id` |

Sidebar groups them as: **Dashboard**, **Promotion** (Trade & Win — only when the
`tradewin` module is enabled), **Clients & Network** (clients + requests),
**Commission** (commission + plans), **Referral Links**, **Marketing Material**, **Settings**.

---

## 1. Dashboard — `IBMgrDashboard.vue`

JS object: `ibmgrDashboardApi`

### `GET /portal/dashboard?period=…&scope=…`  → `stats()`
Full KPI block for the caller. `scope` ∈ `direct | network | total`.
```json
{
  "period": { "key": "str", "from": "datetime", "to": "datetime" },
  "scope": "direct|network|total",
  "currencies": [{
    "currency": "str",
    "commission": { "period": 0.0, "mtd": 0.0, "lots": 0.0, "trades": 0, "per_lot": 0.0 },
    "wallet": { "unpaid_balance": 0.0, "pending_payout": 0.0, "lifetime_earned": 0.0, "lifetime_paid": 0.0, "is_frozen": false },
    "funding": { "deposits": 0.0, "withdrawals": 0.0, "net": 0.0 },
    "equity": { "equity": 0.0, "balance": 0.0 }
  }],
  "equity_as_of": "str|null",
  "clients": { "total": 0, "active": 0, "new_in_period": 0 },
  "partners": { "direct": 0, "network": 0, "total": 0 },
  "funnel": { "visits": 0, "unique_visits": 0, "signups": 0, "accounts": 0, "funded": 0 },
  "top_earners": [{ "type": "client|partner", "user_id": 0, "currency": "str", "amount": 0.0 }]
}
```

### `GET /portal/dashboard/activity?limit=5`  → `activity()`
Recent events across the whole downline, grouped by kind (no top-level `period`).
```json
{
  "deposits":    [ Event ],
  "withdrawals": [ Event ],
  "payouts":     [ Event ],
  "accounts":    [ Event ],
  "requests":    [ Event ]
}
// Event:
{
  "id": "deposit-123",            // "{type}-{id}"
  "type": "deposit|withdrawal|payout|request|account",
  "status": "pending|approved|opened|…",
  "user_id": 0,                    // null on some payouts
  "account": "str|null",
  "amount": 0.0,                   // null for request/account
  "currency": "str|null",
  "at": "datetime",
  "name": "str|null",
  "request_id": 0                  // ONLY on request events
}
```

---

## 1b. Promotion → Trade & Win — `TradeWin.vue`

Spliced into the IB sidebar **only when the `tradewin` module is enabled**
(`PWANavigation.vue` L501–516, route `/ib/trade-win`). This is **not** an IBManager
portal endpoint — it belongs to the separate **TradeWin** module.

- **Base URL / prefix:** `/api/v1/user/trade-win` (middleware `auth:sanctum`, `throttle:api`)
- **Controller:** `core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php`
- Envelope is the module's own `{ status, message, data }` (NOT the portal `ok()` wrapper).

### `GET /api/v1/user/trade-win/products?category=…&symbol_categories=…&availability=…&page=…`  → `getProducts()`
`availability` ∈ `redeemable | locked | all`. Sends `audience=ib` for the IB tab.
```json
{
  "message": "str", "status": true, "module_enabled": true,
  "data": {
    "products": { "current_page": 1, "data": [ Product ], "per_page": 10, "last_page": 1, "total": 0 },
    "stats": { "total_lots": 0.0, "lifetime_lots": 0.0, "spent_lots": 0.0,
               "total_prize_value_won": 0.0, "past_wins_count": 0 },
    "leaderboard": [ … ],
    "symbol_categories": [{ "id": 0, "name": "str" }],
    "past_wins": [ … ],
    "audience": "client|ib",
    "availability": "all",
    "availability_counts": { "all": 0, "redeemable": 0, "locked": 0 }
  }
}
// Product (each item in products.data) is decorated with:
{
  "eligible_lots": 0.0, "available_lots": 0.0,
  "required_deposit": 0.0, "available_deposit": 0.0,
  "deposit_met": true, "deposit_shortfall": 0.0,
  "lot_start_date": "str|null", "lot_end_date": "str|null",
  "lots_met": true, "is_redeemable": true,
  "allowed_group_names": ["str"], "allowed_symbol_names": ["str"],
  "image_path": "str|null", "symbol_category_ids": [0]
}
```

### `GET /api/v1/user/trade-win/past-wins`  → `getPastWins()`
```json
{
  "status": true, "message": "str",
  "data": { "current_page": 1, "data": [ … ], "per_page": 10, "last_page": 1, "total": 0 },
  "saved_addresses": [{ "address": "str", "city": "str", "country": "str",
                        "name": "str", "phone": "str", "email": "str" }]
}
```

### `POST /api/v1/user/trade-win/claim`  → `claimProduct()`
Body: `product_id` (int, req), `quantity` (int, req ≥1), `shipping_details` (object|null),
`audience` (`client|ib`, null).
```json
{
  "message": "str", "status": true,
  "claim_id": 0, "reference_no": "str|null",
  "shipping_details": {…}|null,
  "saved_addresses": [{ "address": "str", "city": "str", "country": "str",
                        "name": "str", "phone": "str", "email": "str" }]
}
// Errors (HTTP 400): insufficient stock / outside campaign window /
// deposit requirement not met / insufficient lot volume balance
```

### `GET /api/v1/user/trade-win/saved-addresses`  → `getSavedAddresses()`
```json
{ "status": true, "message": "str",
  "data": [{ "address": "str", "city": "str", "country": "str",
             "name": "str", "phone": "str", "email": "str" }] }
```

---

## 2. My Clients — `IBMgrClients.vue`

JS object: `ibmgrClientsApi`

### `GET /portal/clients?…`  → `list()`
Query: `scope` (direct/network), `search`, `status`, `under_ib`, `via_link`, `depth`, `page`.
```json
{
  "period": { "key": "str", "from": "datetime", "to": "datetime" },
  "scope": "direct|network",
  "summary": { /* totals block */ },
  "partners": [ /* Under-IB picker options */ ],
  "links":    [ /* Came-via link options */ ],
  "rows": [{
    "client_user_id": 0, "name": "str", "email": "str", "email_masked": false,
    "last_login_at": "str|null", "last_deposit_at": "str|null", "last_withdrawal_at": "str|null",
    "joined_at": "str", "is_direct": true, "direct_ib_user_id": null, "direct_ib_name": null,
    "depth": 0, "via_link": "str|null", "via_link_is_mine": null, "via_link_owner": null,
    "is_active": true, "last_trade_at": "str|null", "idle_days": 0,
    "accounts": 0, "account_logins": [], "is_ib": false,
    "currencies": [ /* per-currency commission/deposit/withdrawal/equity */ ]
  }],
  "pagination": { "page": 1, "per_page": 20, "total": 0, "last_page": 1 }
}
```

### `GET /portal/clients/network-tree?…`  → `networkTree()`
Network mode grouped by the partner who owns each client (tree rows).

### `GET /portal/clients/{id}?period=…`  → `show()`
One client's full page.
```json
{
  "client": {
    "client_user_id": 0, "name": "str", "email": "str", "email_masked": false,
    "registered_at": "str", "joined_at": "str",
    "last_login_at": "str|null", "last_deposit_at": "str|null", "last_withdrawal_at": "str|null",
    "is_direct": true, "via_link": "str|null", "via_link_code": "str|null",
    "via_link_is_mine": null, "via_link_owner": null, "joined_via_at": "str"
  },
  "period": { "key": "str", "from": "datetime", "to": "datetime" },
  "equity_as_of": "str|null",
  "upline": [ /* chain of owners */ ],
  "history": [ /* assignment history */ ],
  "events": [ /* assignments + money timeline, newest first */ ],
  "last_trade_at": "str|null", "last_rebate_at": "str|null",
  "symbols": [ /* per-symbol lots + what each pays */ ],
  "idle_days": 0,
  "totals": { /* deposits/withdrawals/equity/commission */ },
  "accounts": [ /* per-account breakdown */ ]
}
```

### `GET /portal/clients/{id}/accounts`  → `accounts()`
```json
{ "client_user_id": 0, "accounts": [ /* per-account breakdown */ ] }
```

### `GET /portal/clients/{id}/accounts/{accountId}/trades` — one account · `GET /portal/clients/{id}/trades` — all accounts  → `trades()`
Trade feed (paginated). Non-earning ledger rows are filtered out.

### `POST /portal/clients/{id}/move`  → `move()`
Body: move payload. Reassigns a client under a different sub-IB.

---

## 3. Sub-IB Requests — `IBMgrRequests.vue`

JS object: `ibmgrRequestsApi`

### `GET /portal/requests?status=…`  → `list()`
`status` ∈ `pending | approved | rejected | cancelled | all`.
```json
{
  "status": "pending",
  "requests": [{
    "request_id": 0, "user_id": 0, "name": "str", "email": "str",
    "message": "str", "status": "str", "plan_id": null, "rejection_reason": null,
    "origin": "applied|broker",
    "requested_at": "str", "ib_approved_at": "str|null", "reviewed_at": "str|null"
  }]
}
```

### `POST /portal/requests/{id}/approve`  → `approve(planId, planGroupIds)`
Body: `plan_id` (int, required), `plan_group_ids` (int[]).
```json
// auto-approval OFF:
{ "request_id": 0, "user_id": 0, "awaiting_admin": true }
// auto-approval ON:
{ "request_id": 0, "user_id": 0, "plan_id": 0, "plan_group_ids": [0] }
```

### `POST /portal/requests/{id}/reject`  → `reject(reason)`
Body: `reason` (str, max 500). Returns `{ "request_id": 0, "user_id": 0 }`.

---

## 4. Sub-IB Performance & Network — `IBMgrSubIbs.vue`, `IBMgrPerson.vue`

JS object: `ibmgrStructureApi` (+ `ibmgrSubIbsApi` for approve/reject shortcuts)

### `GET /portal/network?…`  → `network()`
Paginated direct children of a node.
```json
{
  "period": { "key": "str", "from": "str", "to": "str" },
  "parent_id": null, "equity_as_of": "str|null",
  "rows": [{ "partner_user_id": 0, "name": "str", "status": "str", "has_partners": false,
             "clients": 0, "active_clients": 0, "currencies": [ … ] }],
  "pagination": { "page": 1, "per_page": 20, "total": 0, "last_page": 1 }
}
```

### `GET /portal/network/performance?sort=…&dir=…&currency=…`  → `performance()`
Ranked, single-currency leaderboard of direct partners.
```json
{
  "period": { "key": "str", "from": "str", "to": "str" },
  "currency": "str|null", "equity_as_of": "str|null",
  "sort": { "key": "commission|net|clients|lots|equity|name", "dir": "asc|desc" },
  "totals": { "partners": 0, "clients": 0, "active_clients": 0, "net": 0.0, "commission": 0.0 },
  "rows": [ /* per-partner ranked rows */ ],
  "pagination": { … }
}
```

### `GET /portal/network/tree-summary`  → `treeSummary()`
```json
{ "ib_user_id": 0, "name": "str", "direct": 0, "total": 0, "clients": 0 }
```

### `GET /portal/network/{id}/node?…`  → `node()`
One tree node: its people, own clients, sub-IBs (one level at a time).
```json
{
  "period": { "key": "str", "from": "str", "to": "str" },
  "ib_user_id": 0, "client_total": 0, "client_shown": 0,
  "people":  [ /* merged clients+partners */ ],
  "clients": [{ "client_user_id": 0, "name": "str", "email": "str|null",
                "first_account": "str|null", "balance": 0.0, "is_direct": true, "currencies": [ … ] }],
  "sub_ibs": [{ "ib_user_id": 0, "name": "str", "email": "str|null", "referral_code": "str|null",
                "plan_name": "str|null", "status": "str", "level": null, "sub_ibs": 0,
                "clients_tree": 0, "currencies": [ … ] }]
}
```

### `GET /portal/network/{id}`  → `partner()`  (person page header)
```json
{
  "period": { "key": "str", "from": "str", "to": "str" },
  "upline": [ … ],
  "partner": { "partner_user_id": 0, "name": "str", "email": "str|null", "arrived_via": null,
               "status": "str", "depth": null, "partner_since": "str|null", "sub_partners": 0 },
  "equity_as_of": "str|null",
  "clients": { "own": 0, "branch": 0, "active": 0 },
  "own":    [ /* per-currency, partner's own */ ],
  "branch": [ /* per-currency, whole branch */ ],
  "sub_partners": { "12": "name" }
}
```

### `GET /portal/network/{id}/wallet`  → `partnerWallet()`
```json
{
  "partner_user_id": 0,
  "wallets": [{ "currency": "str", "available": 0.0, "pending_payout": 0.0,
                "lifetime_earned": 0.0, "lifetime_paid": 0.0, "is_frozen": false }],
  "payouts": [{ "id": 0, "currency": "str", "amount": 0.0, "status": "str",
                "requested_at": "str", "paid_at": "str|null" }]
}
```

### `GET /portal/network/{id}/plan`  → `partnerPlan()`  (also `ibmgrCommissionApi` path via `PlanController::partnerPlan`)
Rates only when the caller wrote the plan.
```json
{
  "plan": { "name": "str", "plan_name": "str", "description": "str|null", "is_active": true } | null,
  "groups": [ /* only if is_yours */ ],
  "plan_id": 0, "assigned_at": "str|null", "assigned_by_you": false, "is_yours": false
}
```

### `GET /portal/network/{id}/links`  → `partnerLinks()`  ·  `GET /portal/network/{id}/symbols`  → `partnerSymbols()`
Downline partner's read-only links, and the pairs their branch paid on.

### Sub-IB approve/reject — `ibmgrSubIbsApi`
`GET /portal/sub-ibs` → `list()` · `POST /portal/sub-ibs/{id}/approve` · `POST /portal/sub-ibs/{id}/reject`.

---

## 5. Commission Plans — `IBMgrPlans.vue`

Two API objects here: read-only view of the caller's own plan (`ibmgrPlansApi` /
`ibmgrPlanGroupsApi` / `ibmgrVisibilityApi`) **and** the partner-authored plans the
caller can hand out (`ibmgrPartnerPlansApi`).

### `GET /portal/plan`  → `ibmgrCommissionApi.myPlan()` / `PlanController::show()`
The caller's own assigned plan, with categories, symbol overrides, blocked symbols.
```json
{
  "plan": { "name": "str", "plan_name": "str", "description": "str|null", "is_active": true },
  "groups": [{
    "plan_group_id": 0, "group_id": 0, "name": "str", "is_active": true,
    "rates": [{ "symbol_category_id": 0, "category": "str", "rate_per_lot": 0.0 }],
    "symbol_overrides": [{ "symbol_id": 0, "symbol": "str", "rate_per_lot": 0.0 }],
    "blocked_symbols": [{ "symbol_id": 0, "symbol": "str" }]
  }]
}
```

### `GET /portal/plan/groups`  → `ibmgrPlanGroupsApi.list()`
Flat group list for pickers.
```json
{ "groups": [{ "plan_group_id": 0, "group_id": 0, "name": "str", "is_active": true }] }
```

### `GET /portal/client-visibility`  → `ibmgrVisibilityApi.get()`
Which of the caller's plan groups their clients may choose.
```json
{
  "groups": [{ "plan_group_id": 0, "group_id": 0, "name": "str", "is_active": true,
               "is_visible": true, "is_default": false }],
  "plan_name": "str", "default_plan_group_id": null, "visible_count": 0
}
```

### `POST /portal/client-visibility`  → `ibmgrVisibilityApi.save()`
Body: `plan_group_ids` (int[], required, ≥1), `default_plan_group_id` (int|null).
Returns `{ "plan_group_ids": [0], "default_plan_group_id": 0 }`.

### Partner plans — `ibmgrPartnerPlansApi`
Plans the partner builds themselves to hand to sub-IBs.

- `GET /portal/partner-plans` → `list()`
  ```json
  { "plans": [{ "plan_id": 0, "name": "str", "description": "str|null",
                "is_active": true, "partners_using": 0, "created_at": "str|null" }] }
  ```
- `GET /portal/partner-plans/template?rate_factor=…` → `template()` → `{ "draft": [Draft], "caps": [Caps], "symbol_catalogue": SymbolCatalogue }`
- `GET /portal/partner-plans/{id}` → `show()` → `{ "plan": {…}, "draft": [Draft], "caps": [Caps], "symbol_catalogue": SymbolCatalogue }`
- `POST /portal/partner-plans` → `store()` → `{ "plan_id": 0, "caps": [Caps] }` (422 → `{ "violations": [], "caps": [Caps] }`)
  Body: `plan_name`(req ≤150), `description`(≤1000), `groups`(req ≥1) each `.group_id`(req), `.rates`, `.symbol_rates`, `.blocked_symbol_ids`, `.blocked_symbol_names`.
- `PUT /portal/partner-plans/{id}` → `update()` → `{ "plan_id": 0, "caps": [Caps] }` (adds `is_active`)
- `DELETE /portal/partner-plans/{id}` → `destroy()` → `{}` (422 if active assignments)
- `GET /portal/partner-plans/sub-ibs?q=…` → `subIbs()` → `{ "sub_ibs": [{ "id": 0, "name": "str", "email": "str|null" }], "total": 0, "shown": 0 }`
- `POST /portal/partner-plans/{id}/assign` → `assign()` — body `ib_user_id` (int, required)

> Note: `ibmanagerApi.js` also declares `addGroup / removeGroup / setRates / setSymbolRules / unassign`
> and `ibmgrPlansApi.create/update/addGroup/group-visibility`. These are client-side helpers;
> the live server routes are the ones listed in `api.php` above.

**Sub-shapes:**
- `Draft` = `{ group_id, plan_group_id, name, is_active, rates{catId:float}, symbol_rates{symId:float}, blocked_symbol_ids[] }`
- `Caps`  = `{ group_id, name, categories[{ symbol_category_id, category, max_allowed, given, you_keep }], symbol_rates[{ symbol_id, name, max_allowed, given }], blocked_symbol_ids[] }`
- `SymbolCatalogue` = `{ names{id:str}, by_category{id:[{id,name}]} }`

---

## 6. My Commission — `IBMgrCommission.vue`

JS object: `ibmgrCommissionApi` + `ibmgrWalletApi` (there is no `/portal/commission`;
the ledger IS the wallet transaction list).

### `GET /portal/wallet`  → `ibmgrWalletApi.get()`
```json
{
  "minimum_payout_by_currency": { "USD": 0.0 },
  "methods": [ /* IbmPayoutMethods->available() */ ],
  "payouts": [{ "id": 0, "currency": "str", "amount": 0.0, "status": "str",
                "method_name": "str|null", "beneficiary_label": "str|null",
                "requested_at": "str", "paid_at": "str|null", "payment_reference": "str|null",
                "rejection_reason": "str|null", "raised_by_broker": false }],
  "wallets": [{ "currency": "str", "balance": 0.0, "pending_payout": 0.0,
                "lifetime_earned": 0.0, "lifetime_paid": 0.0, "is_frozen": false,
                "can_withdraw": true, "open_payout_status": "str|null", "minimum_payout": 0.0 }]
}
```

### `GET /portal/wallet/transactions?currency=…&type=…&page=…`  → `ibmgrCommissionApi.ledger()` / `ibmgrWalletApi.transactions()`
```json
{
  "filters": { "currency": "str|null", "type": "str|null" },
  "transactions": [{
    "id": 0, "currency": "str", "type": "str", "direction": "str",
    "amount": 0.0, "balance_before": 0.0, "balance_after": 0.0,
    "description": "str|null", "created_at": "str|null",
    "trade": { "symbol": "str", "account": "str", "side": "str", "lots": 0.0,
               "entry_price": 0.0, "exit_price": 0.0, "closed_at": "str",
               "client_name": "str|null" } // or null
  }],
  "pagination": { "page": 1, "per_page": 20, "total": 0, "last_page": 1 }
}
```

### `POST /portal/wallet/withdraw`  → `ibmgrWalletApi.withdraw()`
Body: `currency` (req ≤10), `amount` (req >0), `method_slug` (≤100), `withdrawal_method_id` (int).
```json
{ "payout_request_id": 0, "currency": "str", "amount": 0.0, "balance": 0.0, "pending_payout": 0.0 }
```

### `DELETE /portal/wallet/payout/{payoutId}`  → `ibmgrWalletApi.cancelPayout()`
Body: `reason` (optional). Returns `{ "payout_request_id": 0, "balance": 0.0, "pending_payout": 0.0 }`.

### `GET /portal/plan`  → `ibmgrCommissionApi.myPlan()`
Same shape as **§5 `GET /portal/plan`** — the rate card shown next to the ledger.

---

## 7. Referral Links — `IBMgrReferrals.vue`

JS object: `ibmgrReferralsApi`

### `GET /portal/links`  → `list()`
```json
{
  "links": [{
    "link_id": 0, "code": "str", "label": "str", "type": "str",
    "is_default_link": false, "is_active": true, "expires_at": "str|null",
    "groups": [{ "plan_group_id": 0, "name": "str|null", "is_default": false }],
    "counts": { "visits": 0, "unique_visits": 0, "signups": 0, "accounts": 0, "funded": 0 }
  }]
}
```

### `POST /portal/links`  → `create()`  → `{ "link_id": 0, "code": "str" }`
Body: `label` (req ≤255), `code` (≤64 regex), `plan_group_ids` (req ≥1), `default_plan_group_id`, `expires_at`.

### `PUT /portal/links/{id}`  → `update()`  → `{ "link_id": 0 }`
Body: `label`, `is_active`, `plan_group_ids`, `default_plan_group_id`, `expires_at` (all nullable).

### `DELETE /portal/links/{id}`  → `destroy()`

### `GET /portal/links/{id}/stats?period=…`  → `stats()`
```json
{
  "link": { "link_id": 0, "code": "str", "label": "str", "type": "str", "is_active": true },
  "period": { "key": "str", "from": "str", "to": "str" },
  "counts": { "visits": 0, "unique_visits": 0, "signups": 0, "accounts": 0, "funded": 0 },
  "earned": [{ "currency": "str", "amount": 0.0 }],
  "daily": [ /* per-day series */ ]
}
```

### `GET /portal/links/{id}/clients`  → `clients()`
```json
{
  "link": { "link_id": 0, "code": "str", "label": "str" },
  "period": { "key": "str" },
  "clients": [{
    "client_user_id": 0, "name": "str", "email": "str", "registered_at": "str",
    "first_account_at": "str|null", "first_deposit_at": "str|null", "first_trade_at": "str|null",
    "held_by_you": true, "held_by": "str|null"
  }]
}
```

---

## 8. Marketing Material — `IBMgrMarketing.vue`

JS object: `ibmgrMarketingApi`

### `GET /portal/marketing?category=…&q=…`  → `list()`
```json
{
  "materials": [{
    "material_id": 0, "title": "str", "description": "str",
    "category": "str", "category_label": "str", "category_icon": "str|null",
    "language": "str", "dimensions": "str",
    "has_file": true, "file_name": "str", "file_size": 0,
    "external_url": "str", "thumbnail_url": "str|null",
    "download_count": 0, "published_at": "str"
  }],
  "categories": [{ "key": "str", "label": "str", "icon": "str|null", "count": 0 }]
}
```

### `GET /portal/marketing/{id}/download`  → `downloadUrl(id)`
Streams the file (not JSON); counts the download. Used as an `href`, no envelope.

---

## 9. Settings — `IBMgrSettings.vue`

Settings reuses the visibility + links + plan endpoints (no dedicated controller):

- `GET /portal/client-visibility` / `POST /portal/client-visibility` — see **§5**
- `GET /portal/plan/groups` — see **§5**
- `GET /portal/links` — the default referral link — see **§7**

---

## Public (no auth) — referral registration

JS object: `ibmgrPublicApi` (not behind `ibm.auth`; used by the referral landing page)

- `GET /api/ibm/referral-registration/check/{code}` → `checkLink(code)` — validates a link code
- `POST /api/ibm/referral-registration/register` → `register(data)` — registers a referred client

---

## Endpoint index (all portal routes)

```
GET    /api/ibm/portal/dashboard
GET    /api/ibm/portal/dashboard/activity
GET    /api/ibm/portal/network
GET    /api/ibm/portal/network/summary
GET    /api/ibm/portal/network/tree-summary
GET    /api/ibm/portal/network/performance
GET    /api/ibm/portal/network/{id}/wallet
GET    /api/ibm/portal/network/{id}/node
GET    /api/ibm/portal/network/{id}/plan
GET    /api/ibm/portal/network/{id}/links
GET    /api/ibm/portal/network/{id}/symbols
GET    /api/ibm/portal/network/{id}
GET    /api/ibm/portal/clients
GET    /api/ibm/portal/clients/network-tree
GET    /api/ibm/portal/clients/{id}
GET    /api/ibm/portal/clients/{id}/accounts
GET    /api/ibm/portal/clients/{id}/accounts/{accountId}/trades
GET    /api/ibm/portal/clients/{id}/trades
GET    /api/ibm/portal/plan
GET    /api/ibm/portal/plan/groups
GET    /api/ibm/portal/partner-plans
GET    /api/ibm/portal/partner-plans/template
POST   /api/ibm/portal/partner-plans
GET    /api/ibm/portal/partner-plans/sub-ibs
GET    /api/ibm/portal/partner-plans/{id}
PUT    /api/ibm/portal/partner-plans/{id}
DELETE /api/ibm/portal/partner-plans/{id}
POST   /api/ibm/portal/partner-plans/{id}/assign
GET    /api/ibm/portal/client-visibility
POST   /api/ibm/portal/client-visibility
GET    /api/ibm/portal/links
POST   /api/ibm/portal/links
PUT    /api/ibm/portal/links/{id}
DELETE /api/ibm/portal/links/{id}
GET    /api/ibm/portal/links/{id}/stats
GET    /api/ibm/portal/links/{id}/clients
GET    /api/ibm/portal/marketing
GET    /api/ibm/portal/marketing/{id}/download
GET    /api/ibm/portal/requests
POST   /api/ibm/portal/requests/{id}/approve
POST   /api/ibm/portal/requests/{id}/reject
GET    /api/ibm/portal/wallet
GET    /api/ibm/portal/wallet/transactions
POST   /api/ibm/portal/wallet/withdraw
DELETE /api/ibm/portal/wallet/payout/{payoutId}

# Promotion → Trade & Win (separate TradeWin module; only when enabled)
GET    /api/v1/user/trade-win/products
GET    /api/v1/user/trade-win/past-wins
POST   /api/v1/user/trade-win/claim
GET    /api/v1/user/trade-win/saved-addresses
```
