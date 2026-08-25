# IB Manager Portal — API + UI Reference (for Flutter)

> Scope: the **new** IB dashboard only — route `/ib-manager-portal` (`IBManagerPortal.vue`).
> The old/legacy dashboard (`/ib-dashboard`, `IBDashboard.vue`) is **not** covered here.
> Nothing in the code was changed to produce this doc.

---

## 0. Base URL, Auth, Envelope

| Thing | Value |
|---|---|
| Base URL | `VITE_IBMGR_API`, else `VITE_API_URL` with `/api/user` → `/api/ibm`, else `/api/ibm` |
| Effective prefix | **`/api/ibm/portal`** for every portal call below |
| Auth header | `Authorization: Bearer <token>` (token from `localStorage.auth_token` \|\| `token`) |
| Extra headers | `Accept: application/json`, `Content-Type: application/json`, `credentials: same-origin` |
| Middleware (server) | `auth:sanctum` + `ibm.auth` (needs an active, unsuspended profile **and** a hierarchy row) |
| Error | non-2xx → JSON `{ message }` thrown; `204` → `null` |

**Which dashboard a user sees** is decided *before* any of this, by one call:
`GET /api/ibm/client/system` → `data.system` = `ibm` | `legacy` | `none`.
Only `system === "ibm"` lands the user in this portal. (Full logic in the separate system-switch notes.)

**Response envelope:** portal endpoints return `{ success, message, data: {...} }`.
Frontend always unwraps with `res.data || res`. All shapes below are the **`data`** object.

**Common period param** (used by almost every list/stat call):
`period` = `today` | `7d` | `30d` | `mtd` | `all` | `custom`
For `custom`: also send `from` and `to` (date strings). This is the `Today / 7D / 30D / MTD / All / Custom` segmented control at the top-right of every screen.

---

## 1. Menu → Section → API map

The portal's menu comes from `sections.js` (`IBM_SECTIONS`). The sidebar groups them (`ibmNavGroups`) into 3 groups + 3 flat items:

```
Dashboard                         → dashboard
Clients & Network (group)
   ├─ My Clients                  → clients      (this is the screen in the screenshot)
   └─ Sub-IB Requests             → requests
Commission (group)
   ├─ My Commission               → commission
   └─ Commission Plans            → plans
Referral Links                    → referrals
Marketing Material                → marketing
Settings                          → settings
(hidden, reached from Dashboard "View all") Sub-IB Performance → sub-ibs
(hidden, reached by row click)              Person detail      → people/:personId
```

Route pattern: `/ib-manager-portal/:section` and `/ib-manager-portal/people/:personId`.
`IBManagerPortal.vue` renders one section component by the `:section` param; `personId` (if present) always renders `IBMgrPerson.vue`.

| Menu / Screen | Component | APIs it calls |
|---|---|---|
| Dashboard | `IBMgrDashboard.vue` | `GET /portal/dashboard`, `GET /portal/dashboard/activity`, `GET /portal/network` |
| My Clients | `IBMgrClients.vue` | `GET /portal/clients`, `GET /portal/clients/network-tree`, `GET /portal/network/tree-summary`, `GET /portal/network/{id}` (+wallet) |
| Sub-IB Requests | `IBMgrRequests.vue` | `GET /portal/requests`, `POST /portal/requests/{id}/approve`, `POST /portal/requests/{id}/reject`, `GET /portal/partner-plans` |
| Sub-IB Performance | `IBMgrSubIbs.vue` | `GET /portal/network/performance` |
| My Commission | `IBMgrCommission.vue` | `GET /portal/wallet`, `GET /portal/wallet/transactions`, `POST /portal/wallet/withdraw`, `DELETE /portal/wallet/payout/{id}`, `GET /portal/plan` |
| Commission Plans | `IBMgrPlans.vue` | `GET/POST/PUT/DELETE /portal/partner-plans*`, `GET /portal/partner-plans/template`, `GET /portal/partner-plans/sub-ibs`, `POST /portal/partner-plans/{id}/assign` |
| Referral Links | `IBMgrReferrals.vue` | `GET/POST/PUT/DELETE /portal/links`, `GET /portal/links/{id}/clients`, `GET /portal/plan/groups` |
| Marketing Material | `IBMgrMarketing.vue` | `GET /portal/marketing`, download `GET /portal/marketing/{id}/download` |
| Settings | `IBMgrSettings.vue` | `GET /portal/wallet`, `GET /portal/plan`, `GET/POST /portal/client-visibility` |
| Person detail | `IBMgrPerson.vue` | `GET /portal/clients/{id}`, `GET /portal/network/{id}`, `GET /portal/network/tree-summary`, `GET /portal/clients/{id}/trades` (+per account), `GET /portal/network/{id}/node`, `GET /portal/network/{id}/wallet`, `GET /portal/network/{id}/links`, `GET /portal/network/{id}/plan`, `GET /portal/network/{id}/symbols` |

---

## 2. My Clients screen (the screenshot) — 2 tabs

`IBMgrClients.vue`. Title **"My Network"**. Two tabs:

| Tab | key | count badge | Primary API |
|---|---|---|---|
| **Direct Clients** | `direct` | `direct.summary.total` | `GET /portal/clients?scope=direct` |
| **Network** | `network` | `treeSummary().total` | `GET /portal/network/tree-summary` + `GET /portal/clients?scope=total` + `GET /portal/clients/network-tree` |

### 2a. Direct Clients tab

**Stat cards** (top row) — from `data.summary` of `GET /portal/clients`:

| Card | Field |
|---|---|
| Total Clients | `summary.total` |
| Active (traded this period) | `summary.active` |
| New (joined this period) | `summary.new_in_period` |
| Commission Earned | biggest currency in `summary.commission` (map `{ "USD": 0.0 }`) |

**Toolbar / filters** → query params of `GET /portal/clients`:
- Search box → `search` (name + email)
- `Status: All` → `status` = `active` | `idle` | `never` | `inactive`
- `Referral Source: All` → `link_id` = `<int>` or literal `none`
- Export CSV → walks all pages of the same endpoint
- Period control → `period` (+`from`/`to`)
- Paging → `page`, `per_page`

**Table columns** (each row = one client; click row → `openPerson(client_user_id)` → `/ib-manager-portal/people/{id}`):

`# · Client Name (+ "IB" tag if row.is_ib) · Trading Account · Deposits · Withdrawals · Net Deposit · Lots · Commission · Equity · Last login · Last deposit · Last withdrawal · Referral Source · Account Status`

Money columns come from `row.currencies[]` (per-currency); the row picks the biggest currency. `email_masked=true` shows a lock icon (a sub-IB's client — full email hidden).

### 2b. Network tab

Loads three calls in parallel (`loadNetwork()`):
1. `GET /portal/network/tree-summary` → header summary `{ ib_user_id, name, direct, total, clients }`
2. `GET /portal/clients?scope=total&per_page=1` → `network.summary` totals
3. `GET /portal/clients/network-tree?period=today` → the expandable tree

**Network stat cards** (`networkCards`): `Total Partners` (summary.total, note `summary.direct` directly under you) · `Network Clients` (network.summary.total) · `Active` (network.summary.active) · `Commission` (biggest of network.summary.commission).

**The tree** (`network-tree` nodes, recursive): each node shows partner name, sub-IB count, client count, active clients, per-currency branch totals. Expand/collapse in place; **"Open full page →"** → `openPerson(user_id)`.

**Tree interactions (extra calls):**
- Expand a partner row → `GET /portal/network/{id}/node` (lazy, per node — via `IbmPeopleNode`).
- Click a row to preview it in the highlighted card → `GET /portal/network/{id}` + `GET /portal/network/{id}/wallet` (parallel).
- **"Open full page →"** → navigates to `/ib-manager-portal/people/{id}` (the Person page in §3).
- Search box (≥2 chars) filters the same tree data.

---

## 3. Person / detail screen — the 2 / 3 / 4 / 5 tab logic

`IBMgrPerson.vue`, route `/ib-manager-portal/people/:personId`.

On load it fires **both** in parallel and lets the answers decide what this person is:
```js
client  = GET /portal/clients/{id}     // → isClient = !!client
partner = GET /portal/network/{id}     // → isIb     = !!partner
```
A person can be a client, a partner, or **both**. Tabs are built from those two flags (`tabs()` computed):

```js
tabs = ['Overview']                         // always
if (isClient)      tabs += ['Trades']
if (isIb) {
    tabs += ['Network', 'Symbol-wise commission']
    if (!isMe)     tabs += ['Commission plan']   // hidden on your own page
}
```

**So the tab count is:**

| Who the person is | Tabs shown | Count |
|---|---|---|
| Plain **client** (not a partner) | Overview, Trades | **2** |
| **You** yourself (the logged-in master, isMe) | Overview, Network, Symbol-wise | **3** |
| A downline **partner** who has no trading account of their own | Overview, Network, Symbol-wise, Commission plan | **4** |
| A person who is **both** a partner and a client | Overview, Trades, Network, Symbol-wise, Commission plan | **5** |

> `isMe` = the person is the logged-in user (drops the "Commission plan" tab because you can't put yourself on a plan).
> `Commission plan` tab is also only *editable* when `canChangePlan` = `isIb && !isMe && partner.depth === 1` (direct sub-IB only).

### Tab contents & APIs
- **Overview** — client: totals + timeline (`events`), symbol breakdown (`symbols`), accounts, upline chain. partner: 8 downline cards (`Clients own/branch, Sub-IBs, Deposits, Withdrawals, Net funding, Equity, Lots, You earned`) from `GET /portal/network/{id}`. Wallet + links prefetched (`GET /portal/network/{id}/wallet`, `/links`).
- **Trades** — `GET /portal/clients/{id}/trades` (All accounts) or `GET /portal/clients/{id}/accounts/{accountId}/trades`. Account dropdown = `detail.accounts[]`; side buttons `All/Buy/Sell` → `type`; symbol search → `symbol`; paged (`per_page` 50).
- **Network** — recursive tree via `IbmPeopleNode`, lazy: each expand calls `GET /portal/network/{id}/node`. A node is expandable only if `is_ib=true`. Row "open" → navigates to that person's page (recursion into sub-IB of a sub-IB). **This is the sub-IB → sub-IB → detail drill-down.**
- **Symbol-wise commission** — `GET /portal/network/{id}/symbols` (own independent period `all` by default).
- **Commission plan** — `GET /portal/network/{id}/plan`. If you press **Change plan**: `GET /portal/partner-plans` (choices) then `POST /portal/partner-plans/{planId}/assign` `{ ib_user_id }`.

### 3.1 Exact API call sequence per screen (verified from `IBMgrPerson.vue`)

**On every person-page load** these fire in parallel (`load()`), and their answers decide the tab set:
```
1. GET /portal/clients/{id}            → clients.show     (non-null ⇒ isClient=true)
2. GET /portal/network/{id}            → network.partner  (non-null ⇒ isIb=true)
3. GET /portal/network/tree-summary    → only on the FIRST person page of the session (learns your own id / isMe); skipped afterwards
```
Then **only if `isIb=true`** two more fire immediately (for the "Their Wallet" + "Their Referral Links" blocks):
```
4. GET /portal/network/{id}/wallet     → partnerWallet   (self ⇒ /portal/wallet instead)
5. GET /portal/network/{id}/links      → partnerLinks
```
Then **one lazy call per tab, on first click only** (Overview = none):
```
Trades          → GET /portal/clients/{id}/trades  (or /accounts/{accountId}/trades)
Network         → GET /portal/network/{id}/node    (+ again for each row you expand)
Symbol-wise     → GET /portal/network/{id}/symbols
Commission plan → GET /portal/network/{id}/plan
```

#### Screen A — a person who is Sub-IB **and** your own client → **5 tabs** (e.g. `/people/39` "ibm sub one")
`isClient=true` + `isIb=true`. **9 endpoints total:**

| When | API |
|---|---|
| load | `GET /portal/clients/39` |
| load | `GET /portal/network/39` |
| load (first person-page only) | `GET /portal/network/tree-summary` |
| load (because isIb) | `GET /portal/network/39/wallet` |
| load (because isIb) | `GET /portal/network/39/links` |
| Trades tab | `GET /portal/clients/39/trades` |
| Network tab | `GET /portal/network/39/node` |
| Symbol-wise tab | `GET /portal/network/39/symbols` |
| Commission plan tab | `GET /portal/network/39/plan` |

So: **5 calls on load** (Overview renders instantly from these) **+ 4 lazy** (one each when you first open Trades / Network / Symbol-wise / Commission plan).

#### Screen B — a plain client (not an IB) → **2 tabs** (e.g. `/people/41` "ibm downline client")
`isClient=true` + `isIb=false`. Wallet / links / the 3 IB-only tabs are **not** called. **3 endpoints (+ tree-summary once):**

| When | API |
|---|---|
| load | `GET /portal/clients/41` ✅ returns detail |
| load | `GET /portal/network/41` ⚠️ empty/404 → `isIb=false` (this is why only 2 tabs show) |
| load (first person-page only) | `GET /portal/network/tree-summary` |
| Trades tab (or per-account "See trades") | `GET /portal/clients/41/trades` (or `/accounts/{accountId}/trades`) |

Overview here (Deposits / Withdrawals / Net funding / Equity / Lots / You earned cards, **Top instruments**, **Trading accounts**) all come from the single `GET /portal/clients/41` response — no extra call.

> `GET /portal/network/{id}` is **always attempted** for both screen types (both load calls run in parallel); for a plain client it just returns nothing and the IB-only tabs are dropped.

---

## 4. API response shapes

> Legend: `<int> <float> <string> <bool> <datetime="Y-m-d H:i:s">`. `:4` = rounded to 4 dp. All shapes are the `data` object. Commission is a **map keyed by currency**, never summed across currencies.

### 4.1 `GET /portal/clients` — My Clients list
**Query:** `period, from, to, scope(direct|network|total), under_ib|as_ib(int), depth(int, >=3 collapses), search, link_id(int|"none"), status(active|idle|never|inactive), page, per_page`

```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "scope": "<string>",                       // direct|network|total
  "summary": {                               // whole filtered set, not just the page
    "total": "<int>",
    "active": "<int>",                        // traded within period
    "new_in_period": "<int>",                 // assigned_at in period
    "commission": { "<currency>": "<float:4>" }
  },
  "partners": [                              // [] when scope=direct & no under_ib
    { "ib_user_id": "<int>", "name": "<string>", "depth": "<int|null>" }
  ],
  "links": [                                 // "Came via" filter options
    { "link_id": "<int|'none'>", "label": "<string>", "is_mine": "<bool|null>",
      "owner": "<string|null>", "clients": "<int>" }
  ],
  "rows": [ {
    "client_user_id": "<int>",
    "name": "<string>",                       // "First Last" or "#id"
    "email": "<string>",                      // masked when !is_direct
    "email_masked": "<bool>",                 // = !is_direct
    "last_login_at": "<string|null>",
    "last_deposit_at": "<string|null>",
    "last_withdrawal_at": "<string|null>",
    "joined_at": "<string>",                  // assigned_at
    "is_direct": "<bool>",
    "direct_ib_user_id": "<int|null>",        // null when direct
    "direct_ib_name": "<string|null>",
    "depth": "<int|null>",                    // hops below caller (0 = direct)
    "via_link": "<string|null>",              // link label
    "via_link_is_mine": "<bool|null>",
    "via_link_owner": "<string|null>",        // 'You' | name | null
    "is_active": "<bool>",
    "last_trade_at": "<string|null>",
    "idle_days": "<int|null>",
    "accounts": "<int>",                      // live account count
    "account_logins": ["<string>"],           // meta_account_numbers
    "is_ib": "<bool>",                        // client is also a partner
    "currencies": [
      { "currency": "<string>", "commission": "<float:4>", "lots": "<float:4>",
        "deposits": "<float:4>", "withdrawals": "<float:4>", "equity": "<float:4>" }
    ]
  } ],
  "pagination": { "page": "<int>", "per_page": "<int>", "total": "<int>", "last_page": "<int>" }
}
```
`status` meaning: `active`=traded in period · `idle`=traded ever but not in period · `never`=never traded · `inactive`=`users.status != 1`.

### 4.2 `GET /portal/clients/network-tree` — Network tab tree
**Query:** period params.
```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "nodes": [ {                               // single root node = caller, recursive
    "type": "<string>",                       // 'direct' (caller) | 'sub_ib'
    "ib_user_id": "<int>",
    "label": "<string>",                      // 'My Direct Clients' for caller, else name/#id
    "email": "<string|null>",
    "depth": "<int>",                         // absolute depth from caller (0 = caller)
    "parent_label": "<string|null>",          // 'You (Direct)' at depth 1
    "sub_ib_count": "<int>",
    "client_count": "<int>",
    "active_clients": "<int>",
    "currencies": [                           // this partner's OWN clients only (no double count)
      { "currency": "<string>", "commission": "<float:4>", "lots": "<float:4>",
        "trades": "<int>", "deposits": "<float:4>" }
    ],
    "children": [ /* node */ ]
  } ]
}
```

### 4.3 `GET /portal/clients/{clientUserId}` — client detail (Overview)
**Query:** period params.
```jsonc
{
  "client": {
    "client_user_id": "<int>", "name": "<string>",
    "email": "<string|null>", "email_masked": "<bool>",
    "registered_at": "<string|null>", "joined_at": "<string|null>",
    "last_login_at": "<string|null>", "last_deposit_at": "<string|null>",
    "last_withdrawal_at": "<string|null>", "is_direct": "<bool>",
    "via_link": "<string|null>", "via_link_code": "<string|null>",
    "via_link_is_mine": "<bool|null>", "via_link_owner": "<string|null>",
    "joined_via_at": "<string|null>"
  },
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "equity_as_of": "<string|null>",
  "upline": [ { "ib_user_id": "<int>", "name": "<string>", "is_you": "<bool>" } ],
  "history": [ {                             // assignment history, oldest first
    "ib_user_id": "<int|null>", "ib_name": "<string>", "is_you": "<bool>",
    "status": "<string>", "from": "<string>", "until": "<string|null>" } ],
  "events": [ {                              // timeline, newest first
    "at": "<string>", "type": "<string>",     // assignment|deposit|withdrawal
    "title": "<string>", "amount": "<float:2|null>", "currency": "<string|null>" } ],
  "last_trade_at": "<string|null>",
  "last_rebate_at": "<string|null>",
  "symbols": [ { "symbol": "<string>", "currency": "<string>", "trades": "<int>",
                 "lots": "<float:2>", "commission": "<float:4>" } ],
  "idle_days": "<int|null>",
  "totals": [ {
    "currency": "<string>", "deposits": "<float:4>", "withdrawals": "<float:4>",
    "net_funding": "<float:4>", "equity": "<float:4>", "balance": "<float:4>",
    "commission": "<float:4>", "lots": "<float:4>", "trades": "<int>" } ],
  "accounts": [ /* account shape, see 4.4 */ ]
}
```

### 4.4 `GET /portal/clients/{clientUserId}/accounts` — per account
```jsonc
{
  "client_user_id": "<int>",
  "accounts": [ {
    "account_id": "<int>", "login": "<string>",
    "group": "<string|null>",                 // generic display name (never MT5 path)
    "currency": "<string>", "balance": "<float:4>",
    "equity": "<float:4>", "equity_as_of": "<string|null>",
    "trades": "<int>", "lots": "<float:4>",
    "commission": [ { "currency": "<string>", "amount": "<float:4>" } ]
  } ]
}
```

### 4.5 Trades — `GET /portal/clients/{id}/trades` (all) or `/accounts/{accountId}/trades`
**Query:** `symbol, type(buy|sell), page, per_page(50), period...`
```jsonc
{
  "account": null,                           // null for "all"; else { account_id, login, group, currency }
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "rows": [ {
    "trade_id": "<int>", "closed_at": "<string|null>",
    "symbol": "<string>", "category": "<string|null>",
    "lots": "<float:4>", "rate_per_lot": "<float:4>",
    "commission": "<float:4>", "currency": "<string>",
    "split": [ { "is_you": "<bool>", "name": "<string>",
                 "amount": "<float:4>", "currency": "<string>" } ],
    "account": "<string>", "side": "<string|null>",   // 'BUY'|'SELL'
    "open_price": "<float|null>", "close_price": "<float|null>",
    "opened_at": "<string|null>", "profit": "<float:2|null>"
  } ],
  "totals": [ { "currency": "<string>", "trades": "<int>", "lots": "<float:4>",
                "commission": "<float:4>", "profit": "<float:2|null>" } ],
  "pagination": { "page": "<int>", "per_page": "<int>", "total": "<int>", "last_page": "<int>" }
}
```

### 4.6 Network endpoints (Network tab + Person page)

> ⚠️ **Two per-currency shapes exist — don't mix them.**
> `branchCurrencies()` → keys `deposits, withdrawals, net_funding, equity, commission, lots` (rounded **4dp**). Used in `/network`, `/network/summary`, `/network/{id}` (`own`/`branch`).
> `rowCurrencies()` → keys `deposits, withdrawals, **net**, equity, lots, commission` (rounded **2dp**). Used in `/network/{id}/node`.

**`GET /portal/network`** — direct partners under a parent. Query: `period…, parent_id(int, default=caller), page, per_page(1–100, 25)`
```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "parent_id": "<int|null>",                 // null when parent is the caller
  "equity_as_of": "<string|null>",
  "rows": [ {
    "partner_user_id": "<int>", "name": "<string>",
    "status": "<string>",                     // active | paused | inactive
    "has_partners": "<bool>", "clients": "<int>", "active_clients": "<int>",
    "currencies": [ { "currency": "<string>", "deposits": "<float:4>", "withdrawals": "<float:4>",
                      "net_funding": "<float:4>", "equity": "<float:4>",
                      "commission": "<float:4>", "lots": "<float:4>" } ]
  } ],
  "pagination": { "page": "<int>", "per_page": "<int>", "total": "<int>", "last_page": "<int>" }
}
```

**`GET /portal/network/summary`** — 3 scope blocks. Query: `period…`
```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "scopes": {
    "direct":  { "partners": "<int>", "clients": "<int>", "currencies": [ /* branchCurrencies */ ] },
    "network": { "partners": "<int>", "clients": "<int>", "currencies": [ /* … */ ] },
    "total":   { "partners": "<int>", "clients": "<int>", "currencies": [ /* … */ ] }
  }
}
```

**`GET /portal/network/tree-summary`** — header numbers (Network tab count badge). No params.
```jsonc
{ "ib_user_id": "<int>", "name": "<string>", "direct": "<int>", "total": "<int>", "clients": "<int>" }
```

**`GET /portal/network/performance`** — Sub-IB Performance table. Query: `period…, page, per_page(25), q, sort(commission|net|clients|lots|equity|name), dir(asc|desc)`
> ⚠️ When the caller has no partners: `rows:[]`, `totals:[]` (array), `currency:null`. When populated: `totals` is an **object**. Branch on `currency == null`.
```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "currency": "<string>",                    // single ranking currency (all money uses it); 'USD' fallback
  "equity_as_of": "<string|null>",
  "sort": { "key": "<string>", "dir": "<string>" },
  "totals": { "partners": "<int>", "clients": "<int>", "active_clients": "<int>",
              "net": "<float:2>", "commission": "<float:2>" },
  "rows": [ {
    "partner_user_id": "<int>", "name": "<string>", "status": "<string>",
    "via_link": "<string|null>", "via_link_is_mine": "<bool|null>", "via_link_owner": "<string|null>",
    "sub_partners": "<int>", "clients": "<int>", "active_clients": "<int>",
    "deposits": "<float:2>", "withdrawals": "<float:2>", "net": "<float:2>",
    "equity": "<float:2>", "lots": "<float:2>", "commission": "<float:2>"
  } ],
  "pagination": { "page": "<int>", "per_page": "<int>", "total": "<int>", "last_page": "<int>" }
}
```

**`GET /portal/network/{id}`** — one partner (Person page Overview when isIb). Query: `period…`
```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "upline": [ { "ib_user_id": "<int>", "name": "<string>", "is_you": "<bool>" } ],
  "partner": {
    "partner_user_id": "<int>", "name": "<string>", "email": "<string|null>",
    "arrived_via": { "label": "<string>", "code": "<string>", "is_mine": "<bool>", "owner": "<string|null>" }, // or null
    "status": "<string>", "depth": "<int|null>",           // hops below caller
    "partner_since": "<string|null>", "sub_partners": "<int>"
  },
  "equity_as_of": "<string|null>",
  "clients": { "own": "<int>", "branch": "<int>", "active": "<int>" },
  "own":    [ /* branchCurrencies (net_funding, 4dp) */ ],
  "branch": [ /* branchCurrencies */ ],
  "sub_partners": { "<user_id>": "<name>" }                 // ⚠️ JSON object map, not an array
}
```

**`GET /portal/network/{id}/node`** — lazy tree level (Network tab drill-down). Query: `period…, client_limit(1–50, 8)`
```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "ib_user_id": "<int>", "client_total": "<int>", "client_shown": "<int>",
  "people": [ {                              // mergePeople(): one row per person, IBs first then by commission desc
    "user_id": "<int>", "name": "<string>", "email": "<string|null>",
    "email_masked": "<bool>",                 // present only when person is (also) a client
    "first_account": "<string|null>", "balance": "<float|int>",
    "is_client": "<bool>", "is_ib": "<bool>", "is_direct": "<bool>",
    "level": "<int|null>", "referral_code": "<string|null>", "plan_name": "<string|null>",
    "status": "<string|null>",
    "via_link": "<string|null>", "via_link_is_mine": "<bool|null>", "via_link_owner": "<string|null>",
    "sub_ibs": "<int>", "clients_tree": "<int>",
    "own":    [ /* rowCurrencies (net, 2dp); [] for IB-only */ ],
    "branch": [ /* rowCurrencies; [] for client-only */ ]
  } ],
  "clients": [ { "client_user_id": "<int>", "name": "<string>", "email": "<string|null>",
                 "first_account": "<string|null>", "balance": "<float|int>",
                 "is_direct": "<bool>", "currencies": [ /* rowCurrencies */ ] } ],
  "sub_ibs": [ { "ib_user_id": "<int>", "name": "<string>", "email": "<string|null>",
                 "referral_code": "<string|null>", "plan_name": "<string|null>", "status": "<string>",
                 "level": "<int|null>", "sub_ibs": "<int>", "clients_tree": "<int>",
                 "currencies": [ /* rowCurrencies */ ] } ]
}
```
> The tree UI (`IbmPeopleNode`) reads **`people[]`**. A node is expandable only if `is_ib=true`; expanding it calls `node` again for that `user_id`. Row "open" → `/ib-manager-portal/people/{user_id}` (recursion into a sub-IB's sub-IB).

**`GET /portal/network/{id}/wallet`** — downline partner's wallet (Person page). 422 if `{id}` == caller (use `/portal/wallet` for yourself).
```jsonc
{
  "partner_user_id": "<int>",
  "wallets": [ { "currency": "<string>", "available": "<float:2>", "pending_payout": "<float:2>",
                 "lifetime_earned": "<float:2>", "lifetime_paid": "<float:2>", "is_frozen": "<bool>" } ],
  "payouts": [ { "id": "<int>", "currency": "<string>", "amount": "<float:2>", "status": "<string>",
                 "requested_at": "<string|null>", "paid_at": "<string|null>" } ]  // latest 25
}
```

**`GET /portal/network/{id}/links`** — partner's links, read-only.
```jsonc
{ "links": [ { "link_id": "<int>", "code": "<string>", "label": "<string>",
               "is_default_link": "<bool>", "is_active": "<bool>", "created_at": "<string|null>",
               "signups": "<int>", "funded": "<int>" } ] }
```

**`GET /portal/network/{id}/symbols`** — which pair the branch paid you on. Query: `period…, q`
```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "rows": [ { "symbol": "<string>", "currency": "<string>", "trades": "<int>",
              "lots": "<float:2>", "commission": "<float:4>",
              "own_commission": "<float:4>", "own_lots": "<float:2>",
              "sub_commission": "<float:4>", "sub_lots": "<float:2>" } ],
  "totals": [ { "currency": "<string>", "trades": "<int>", "lots": "<float>", "commission": "<float>" } ]
}
```

**`GET /portal/network/{id}/plan`** — partner's plan (Commission plan tab). Rates only when the caller wrote the plan.
```jsonc
// no active plan:
{ "plan": null, "groups": [], "assigned_at": null, "assigned_by_you": false, "is_yours": false }
// otherwise:
{
  "plan": { "name": "<string|null>", "plan_name": "<string|null>", "description": "<string|null>", "is_active": "<bool>" },
  "groups": [ /* full plan groups ONLY when is_yours=true; else [] */ ],
  "plan_id": "<int>", "assigned_at": "<string|null>", "assigned_by_you": "<bool>", "is_yours": "<bool>"
}
```

### 4.7 Dashboard endpoints

**`GET /portal/dashboard`** — the 8 stat cards. Query: `period(default mtd)…, scope(direct|network|total, default total)`
```jsonc
{
  "period": { "key": "<string>", "from": "<datetime>", "to": "<datetime>" },
  "scope": "<string>",
  "currencies": [ {                          // one block per currency; no cross-currency total
    "currency": "<string>",
    "commission": { "period": "<float:4>", "mtd": "<float>", "lots": "<float>",
                    "trades": "<int>", "per_lot": "<float>" },
    "wallet": { "unpaid_balance": "<float>", "pending_payout": "<float>",
                "lifetime_earned": "<float>", "lifetime_paid": "<float>", "is_frozen": "<bool>" },
    "funding": { "deposits": "<float>", "withdrawals": "<float>", "net": "<float>" },
    "equity": { "equity": "<float>", "balance": "<float>" }
  } ],
  "equity_as_of": "<string|null>",
  "clients":  { "total": "<int>", "active": "<int>", "new_in_period": "<int>" },
  "partners": { "direct": "<int>", "network": "<int>", "total": "<int>" },
  "funnel":   { "visits": "<int>", "unique_visits": "<int>", "signups": "<int>", "accounts": "<int>", "funded": "<int>" },
  "top_earners": [ { "type": "<string>",     // client | partner
                     "user_id": "<int>", "currency": "<string>", "amount": "<float:4>", "name": "<string>" } ]  // up to 5/currency
}
```
**Card → field map:** Total Clients=`clients.total` (note `clients.new_in_period`) · Active Traders=`clients.active` · Sub-IBs=`partners.total` (note `partners.direct`) · Total Deposits=`currencies[].funding.deposits` (net `.net`) · Total Withdrawals=`.funding.withdrawals` · Client Equity=`.equity.equity` · Total Lots=`.commission.lots` (`.commission.trades`) · Commission=`.commission.period`.

**`GET /portal/dashboard/activity`** — the "Recent activity" boxes. Query: `limit(1–50, 5)`.
> ⚠️ Returns an **object of 5 named arrays** (one box each), not a merged feed.
```jsonc
{
  "deposits":    [ { "id": "deposit-<id>", "type": "deposit", "status": "pending|approved",
                     "user_id": "<int>", "account": "<string|null>", "amount": "<float:2>",
                     "currency": "<string>", "at": "<string>", "name": "<string>" } ],
  "withdrawals": [ /* same shape, type "withdrawal" */ ],
  "payouts":     [ { "id": "payout-<id>", "type": "payout", "status": "<string>",
                     "user_id": "<int|null>",              // null = your own ("You")
                     "account": null, "amount": "<float:2>", "currency": "<string>",
                     "at": "<string>", "name": "<string|null>" } ],
  "accounts":    [ { "id": "account-<id>", "type": "account", "status": "opened",
                     "user_id": "<int>", "account": "<string>", "amount": null,
                     "currency": "<string>", "at": "<string>", "name": "<string>" } ],
  "requests":    [ { "id": "request-<id>", "type": "request", "request_id": "<int>",
                     "status": "<string>", "user_id": "<int>", "account": null, "amount": null,
                     "currency": null, "at": "<string>", "name": "<string>" } ]  // oldest first
}
```

---

## 5. Sub-IB Performance screen (`IBMgrSubIbs.vue`)

`GET /portal/network/performance` — a flat, server-ranked table (built for thousands of partners).
**Query:** `period, from, to, q(search), sort, dir(asc|desc), per_page(25), page`. Sortable: `name, clients, net, equity, lots, commission`.

**Summary cards:** `Partners` (directly under you), plus network totals.
**Table columns:** `# · Partner · Status · Came via · Active / clients · Sub-IBs · Deposits · Withdrawals · Net deposit · Equity · Lots · You earned`.

---

## 6. Sub-IB Requests screen (`IBMgrRequests.vue`)

- List: `GET /portal/requests?status=pending|approved|rejected|cancelled|all`
- Approve: `POST /portal/requests/{requestId}/approve` body `{ plan_id, plan_group_ids: [] }`
- Reject: `POST /portal/requests/{requestId}/reject` body `{ reason }`
- Plans for the approve drawer: `GET /portal/partner-plans`

**Row fields:** `name, email, status(pending|ib_approved|approved|rejected|cancelled), origin('broker'|else → "added"/"asked"), requested_at, ib_approved_at, plan_id, rejection_reason`. Stat cards at top count by status.

**`GET /portal/requests?status=`** →
```jsonc
{
  "status": "<string>",
  "requests": [ {
    "request_id": "<int>", "user_id": "<int>", "name": "<string>", "email": "<string|null>",
    "message": "<string|null>", "status": "<string>", "plan_id": "<int|null>",
    "rejection_reason": "<string|null>",
    "origin": "<string>",                    // "broker" (no message & no IB reviewer) | "applied"
    "requested_at": "<string|null>", "ib_approved_at": "<string|null>", "reviewed_at": "<string|null>"
  } ]
}
```
**`POST /portal/requests/{id}/approve`** body `{ plan_id(req), plan_group_ids[] }` →
```jsonc
// needs broker final approval:  { "request_id": "<int>", "user_id": "<int>", "awaiting_admin": true }
// auto-approved:                { "request_id": "<int>", "user_id": "<int>", "plan_id": "<int>", "plan_group_ids": ["<int>"] }
```
**`POST /portal/requests/{id}/reject`** body `{ reason(≤500) }` → `{ "request_id": "<int>", "user_id": "<int>" }`
> 422 on already-decided or plan-cap `violations`.

---

## 7. My Commission screen (`IBMgrCommission.vue`)

- Wallet: `GET /portal/wallet`
- Ledger: `GET /portal/wallet/transactions` (columns: `When · What · Amount · Balance after`)
- Withdraw: `POST /portal/wallet/withdraw`
- Cancel payout: `DELETE /portal/wallet/payout/{payoutId}`
- Rates: `GET /portal/plan`

**Cards (per active wallet/currency):** `Available now` (balance; note if frozen) · `Pending payout` · `Earned all time` (lifetime_earned) · `Paid out` (lifetime_paid).
`canWithdraw = can_withdraw && !is_frozen && !open_payout_status && balance >= minimum_payout`.
Payouts table columns: `Requested · Amount · Where it goes · Status · Paid`.

**`GET /portal/wallet`** →
```jsonc
{
  "minimum_payout_by_currency": { "<currency>": "<float|null>" },
  "methods": [ {
    "slug": "<string>", "name": "<string>", "needs_account": "<bool>",   // false only for 'local'
    "accounts": [ { "withdrawal_method_id": "<int>", "label": "<string>", "currency": "<string|null>",
      "details": { "holder_name": "<string>", "bank_name": "<string>", "account_no": "<string>",
                   "ifsc_iban": "<string>", "crypto_address": "<string>", "crypto_network": "<string>",
                   "upi_address": "<string>", "currency": "<string>" } } ]  // keys present only when non-empty
  } ],
  "payouts": [ {                             // latest 50
    "id": "<int>", "currency": "<string>", "amount": "<float:4>", "status": "<string>",
    "method_name": "<string|null>", "beneficiary_label": "<string|null>",
    "requested_at": "<string>", "paid_at": "<string|null>", "payment_reference": "<string|null>",
    "rejection_reason": "<string|null>", "raised_by_broker": "<bool>"
  } ],
  "wallets": [ {
    "currency": "<string>", "balance": "<float:4>", "pending_payout": "<float:4>",
    "lifetime_earned": "<float:4>", "lifetime_paid": "<float:4>", "is_frozen": "<bool>",
    "can_withdraw": "<bool>", "open_payout_status": "<string|null>", "minimum_payout": "<float|null>"
  } ]
}
```
**`GET /portal/wallet/transactions`** — ledger table. Query: `currency, type(commission|correction|payout|payout_reversal|adjustment|clawback), page, per_page`
```jsonc
{
  "filters": { "currency": "<string|null>", "type": "<string|null>" },
  "transactions": [ {
    "id": "<int>", "currency": "<string>", "type": "<string>", "direction": "<string>",
    "amount": "<float:4>", "balance_before": "<float:4>", "balance_after": "<float:4>",
    "description": "<string|null>", "created_at": "<string|null>",
    "trade": {                               // object or null (only for commission rows)
      "symbol": "<string>", "account": "<string>", "side": "<string>",  // BUY|SELL
      "lots": "<float:2>", "entry_price": "<float|null>", "exit_price": "<float|null>",
      "closed_at": "<string|null>", "client_name": "<string|null>"
    }
  } ],
  "pagination": { "page": "<int>", "per_page": "<int>", "total": "<int>", "last_page": "<int>" }
}
```
**`POST /portal/wallet/withdraw`** body `{ currency(req), amount(req,>0), method_slug, withdrawal_method_id }` →
```jsonc
{ "payout_request_id": "<int>", "currency": "<string>", "amount": "<float:4>",
  "balance": "<float:4>", "pending_payout": "<float:4>" }
```
**`DELETE /portal/wallet/payout/{id}`** body `{ reason? }` → `{ "payout_request_id": "<int>", "balance": "<float:4>", "pending_payout": "<float:4>" }`
> 422 if the payout was raised by the broker (only they can withdraw it).

**`GET /portal/plan`** — your own rates (shown under "My rates").
```jsonc
{
  "plan": { "name": "<string|null>", "plan_name": "<string|null>", "description": "<string|null>", "is_active": "<bool>" },
  "groups": [ {
    "plan_group_id": "<int>", "group_id": "<int>", "name": "<string|null>", "is_active": "<bool>",
    "rates": [ { "symbol_category_id": "<int>", "category": "<string>", "rate_per_lot": "<float:4>" } ],
    "symbol_overrides": [ { "symbol_id": "<int>", "symbol": "<string>", "rate_per_lot": "<float:4>" } ],
    "blocked_symbols": [ { "symbol_id": "<int>", "symbol": "<string>" } ]
  } ]
}
```

---

## 8. Referral Links (`IBMgrReferrals.vue`)

CRUD: `GET/POST /portal/links`, `PUT/DELETE /portal/links/{id}`.
Per-link who-came: `GET /portal/links/{id}/clients` (columns `Client · Signed up · Got as far as`).
Group options for building a link: `GET /portal/plan/groups`.

**Cards:** `Links` (count, N own) · `Signed up` (signups from visits) · `Opened an account` (accounts) · `Funded`.

**`GET /portal/links`** →
```jsonc
{ "links": [ {
  "link_id": "<int>", "code": "<string>", "label": "<string>",
  "type": "<string>",                        // generic | group_specific
  "is_default_link": "<bool>", "is_active": "<bool>", "expires_at": "<string|null>",
  "groups": null,                            // null for generic; else [ { plan_group_id, name, is_default } ]
  "counts": { "visits": "<int>", "unique_visits": "<int>", "signups": "<int>", "accounts": "<int>", "funded": "<int>" }
} ] }
```
**`POST /portal/links`** body `{ label(req), code?, plan_group_ids[](req,min1), default_plan_group_id?, expires_at? }` → `{ "link_id": "<int>", "code": "<string>" }`
**`PUT /portal/links/{id}`** body `{ label?, is_active?, plan_group_ids?, default_plan_group_id?, expires_at? }` → `{ "link_id": "<int>" }`
**`DELETE /portal/links/{id}`** → `data: null` (generic link can't be deleted → 422)
**`GET /portal/links/{id}/clients`** →
```jsonc
{
  "link": { "link_id": "<int>", "code": "<string>", "label": "<string>" },
  "period": { "key": "<string>" },
  "clients": [ { "client_user_id": "<int>", "name": "<string>", "email": "<string|null>",
                 "registered_at": "<string|null>", "first_account_at": "<string|null>",
                 "first_deposit_at": "<string|null>", "first_trade_at": "<string|null>",
                 "held_by_you": "<bool>", "held_by": "<string|null>" } ]
}
```

---

## 9. Marketing Material (`IBMgrMarketing.vue`) — read only

- List: `GET /portal/marketing` — Query: `category(slug), q(search)`
- Download: `GET /portal/marketing/{id}/download` — ⚠️ on success **streams the binary file** (`Content-Disposition: attachment`), NOT JSON; only errors return the envelope (404).

```jsonc
{
  "materials": [ {
    "material_id": "<int>", "title": "<string>", "description": "<string|null>",
    "category": "<string>", "category_label": "<string>", "category_icon": "<string|null>",
    "language": "<string|null>", "dimensions": "<string|null>",
    "has_file": "<bool>", "file_name": "<string|null>", "file_size": "<int|null>",   // bytes
    "external_url": "<string|null>", "thumbnail_url": "<string|null>",
    "download_count": "<int>", "published_at": "<string|null>"
  } ],
  "categories": [ { "key": "<string>", "label": "<string>", "icon": "<string|null>", "count": "<int>" } ]
}
```

---

## 10. Commission Plans (`IBMgrPlans.vue`)

The plans the partner built themselves (only these can be handed to a joining sub-IB):
- `GET /portal/partner-plans` (list), `GET /portal/partner-plans/{id}` (show)
- `GET /portal/partner-plans/template` (blank template to build from)
- `POST /portal/partner-plans` (create), `PUT /portal/partner-plans/{id}`, `DELETE /portal/partner-plans/{id}`
- `POST /portal/partner-plans/{id}/assign` (assign to a sub-IB)
- `GET /portal/partner-plans/sub-ibs` (who can be assigned)

**`GET /portal/partner-plans`** →
```jsonc
{ "plans": [ { "plan_id": "<int>", "name": "<string>", "description": "<string|null>",
               "is_active": "<bool>", "partners_using": "<int>", "created_at": "<string|null>" } ] }
```
**`GET /portal/partner-plans/template`** (Query `rate_factor` 0–1) and **`GET /portal/partner-plans/{id}`** →
```jsonc
{
  "plan": { "plan_id": "<int>", "name": "<string>", "description": "<string|null>", "is_active": "<bool>" }, // template has no `plan`
  "draft": [ { "group_id": "<int>", "plan_group_id": "<int|null>", "name": "<string|null>", "is_active": "<bool>",
               "rates": { "<categoryId>": "<float>" },          // object keyed by id
               "symbol_rates": { "<symbolId>": "<float>" },
               "blocked_symbol_ids": ["<int>"] } ],
  "caps": [ {                                // ceilings you can give (from parent plan)
    "group_id": "<int>", "name": "<string|null>",
    "categories": [ { "symbol_category_id": "<int>", "category": "<string>",
                      "max_allowed": "<float:4>", "given": "<float|null>", "you_keep": "<float|null>" } ],
    "symbol_rates": [ { "symbol_id": "<int>", "name": "<string>", "max_allowed": "<float:4>", "given": "<float|null>" } ],
    "blocked_symbol_ids": ["<int>"]
  } ],
  "symbol_catalogue": { "names": { "<symbolId>": "<string>" },
                        "by_category": { "<categoryId>": [ { "id": "<int>", "name": "<string>" } ] } }
}
```
**`POST /portal/partner-plans`** / **`PUT /portal/partner-plans/{id}`** body `{ plan_name, description?, groups:[{group_id, rates{}, symbol_rates{}, blocked_symbol_ids[], blocked_symbol_names[]}], is_active? }` → `{ "plan_id": "<int>", "caps": [ /* cap group */ ] }`  (422 → `violations` + `caps`)
**`DELETE /portal/partner-plans/{id}`** → `data: []`  (422 if active assignments)
**`GET /portal/partner-plans/sub-ibs`** (Query `q`, ≤25) → `{ "sub_ibs": [ { "id": "<int>", "name": "<string>", "email": "<string>" } ], "total": "<int>", "shown": "<int>" }`
**`POST /portal/partner-plans/{id}/assign`** body `{ ib_user_id(req, direct sub-IB) }` → `{ "plan_id": "<int>", "plan_name": "<string>" }`  (403 if not your direct sub-IB)

---

## 11. Settings (`IBMgrSettings.vue`)

- `GET /portal/wallet`, `GET /portal/plan`
- Client visibility (which plan-groups a partner's clients may choose):
  `GET /portal/client-visibility`, `POST /portal/client-visibility` body `{ plan_group_ids, default_plan_group_id }`.

**`GET /portal/client-visibility`** →
```jsonc
{
  "groups": [ { "plan_group_id": "<int>", "group_id": "<int>", "name": "<string|null>",
                "is_active": "<bool>", "is_visible": "<bool>", "is_default": "<bool>" } ],
  "plan_name": "<string|null>", "default_plan_group_id": "<int|null>", "visible_count": "<int>"
}
```
**`POST /portal/client-visibility`** body `{ plan_group_ids[](req, non-empty), default_plan_group_id? }` → `{ "plan_group_ids": ["<int>"], "default_plan_group_id": "<int|null>" }`

---

## 12. Gotchas (read before writing models)

1. **No cross-currency totals anywhere.** Every money figure is an array/map keyed by currency. Never sum across currencies. Each row/card picks its dominant currency (the web app uses "biggest commission").
2. **Two per-currency shapes.** `branchCurrencies()` → `net_funding` @4dp (network index/summary/show). `rowCurrencies()` → `net` @2dp (network node). Model them separately.
3. **`performance.totals`** is `[]` (array) when empty, `{}` (object) when populated — branch on `currency == null`.
4. **`network/{id}.sub_partners`** is a JSON object map `{id: name}`, not a list.
5. **`dashboard/activity`** is an object of 5 arrays, not a flat feed.
6. **`marketing/{id}/download`** streams a binary file on success (not JSON).
7. **`partner-plans` DELETE → `data: []`**, but **`links` DELETE → `data: null`**.
8. **`rates`/`symbol_rates`** in partner-plans are objects keyed by numeric id (string key → float), not arrays.
9. **Ownership failures = HTTP 404** (probing can't confirm existence), except `assignToPlan` "not your direct sub-IB" = 403; validation = 422 with `data.errors` or `data.violations`.
10. **Datetime formats are inconsistent:** `period.*`, transactions `created_at`, `partner_since` are `Y-m-d H:i:s`; but wallet payouts `requested_at/paid_at`, links `created_at`, `assigned_at`, trade `closed_at` are raw DB strings. Parse defensively.
11. **Emails masked** for non-direct (a sub-IB's) clients — `email_masked=true`; phone never returned.
12. **Envelope:** always `{ success, message, data }`. Unwrap `data`. `204` → null.

---

## 13. Flutter build order (suggested)

1. **Gate**: `GET /api/ibm/client/system` → only build this portal when `system == "ibm"`.
2. **Shell**: bottom nav / drawer from the menu map (§1) + the period control (§0).
3. **My Clients** (§2 + 4.1/4.2) — the screenshot screen; start here.
4. **Person detail** (§3 + 4.3/4.4/4.5) — dynamic tab count from `isClient`/`isIb`/`isMe`.
5. Dashboard (§4.x below), then the remaining menu items.

All money is per-currency maps — never add across currencies; pick the dominant currency per row like the web app does.
