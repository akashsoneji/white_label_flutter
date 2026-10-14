# IB Manager Portal — New APIs (with dry-run responses)

Date: 2026-10-12 · Postman: `IB_Manager_Portal_New_APIs.postman_collection.json` (same Desktop)

These are the IB Manager portal APIs that are **not** in the old Postman collection or in `IB_MANAGER_PORTAL_API_UI.md`.

## How the dry run was done

- **Where:** local CRM on Prachi's Mac (`http://crm.forex.com`, local DB). **No live server was touched.**
- **As whom:** local IB Manager partner (user 57) with 4 clients; one client (58) used for client-side calls.
- **Data:** every row the dry run created (distribution, export, deposit, transfer, KYC doc, OTPs, token) was deleted afterwards and balances were put back. Plan rename was renamed back.
- **Local limits:** the local trade engine (MT5 bridge) was off, so MT5 live data / password change could not be checked end to end.
- Each API was called with valid data **and** with wrong data (validation, someone else's id). Responses below are the real ones; long lists are cut to the first item (`"... N more"`).

## Quick result

| Area | APIs | Working | Problem |
|---|---|---|---|
| Partner plan rename | 1 | 1 | — |
| Referral link stats | 1 | 1 | not used by any screen |
| Commission distribution | 5 | 5 | — |
| Reports | 3 | 3 | — |
| Exports | 4 | 4 | — |
| IB Client API — clients & KYC | 4 | 3 | create client success path not tested (IB had no referral code); KYC status mismatch |
| IB Client API — money | 12 | 10 | transfer 500 but money moved; OTP vs withdrawal account id mismatch; withdrawal success path not tested |
| IB Client API — MT5 | 6 | 3 | `/mt5-groups` always 500; business error returned as 500; password change not verified |

## Basics (for the mobile developer)

- **Base URL:** `https://<broker CRM domain>/api/ibm/portal`
- **Login:** `POST https://<broker CRM domain>/api/login` with `email`, `password` → Sanctum token. Send `Authorization: Bearer <token>` and `Accept: application/json` on every call.
- The user must be an **active IB Manager partner**, otherwise every call returns 403.
- **Response envelope:** `{ "success": true|false, "message": "...", "data": ... }` — exceptions are listed in issue 6 and 7.
- **Errors:** 422 = validation (message says which field), 404 = not found or not in your network, 403 = no access.
- **[W]** = write call. Refused when the IB is "managed by broker" (broker runs the account on their behalf).
- `period` values: `today | 7d | 30d | mtd | all | custom` (custom needs `from` + `to`). Any other value silently becomes `mtd`.
- Dates are `Y-m-d`.


# Part A — IB portal screens

## 1. Partner Plans

### Rename partner plan [W]

`PATCH /api/ibm/portal/partner-plans/{planId}/rename`

- **What it does:** Changes only the name/description of a plan the IB created for sub-IBs.
- **Where used:** Client portal → IB Manager → **Commission Plans** (`/ib-manager-portal/plans`), rename popup — `IBMgrPlans.vue:838`
- **Params:** Body: `plan_name` (required, max 150), `description` (optional, max 1000)

| Dry-run case | HTTP | Result |
|---|---|---|
| Valid rename | 200 | OK |
| Empty body | 422 | OK — validation |
| Plan of another IB | 404 | OK — blocked |

<details><summary>Response — Valid rename (200)</summary>

```json
{
  "success": true,
  "message": "Plan renamed.",
  "data": {
    "plan_id": 11,
    "name": "DRYRUN rename",
    "description": "dry run"
  }
}
```

</details>

<details><summary>Response — Empty body (422)</summary>

```json
{
  "success": false,
  "message": "The plan name field is required.",
  "data": {
    "errors": {
      "plan_name": [
        "The plan name field is required."
      ]
    }
  }
}
```

</details>

<details><summary>Response — Plan of another IB (404)</summary>

```json
{
  "success": false,
  "message": "Plan not found.",
  "data": null
}
```

</details>

## 2. Referral Links

### Link stats

`GET /api/ibm/portal/links/{linkId}/stats?period=30d`

- **What it does:** Visits / signups / conversions for one referral link.
- **Where used:** **Not used by any screen.** Wrapper exists (`ibmanagerApi.js:85`) but `IBMgrReferrals.vue` never calls it.
- **Params:** Query: `period` = today | 7d | 30d | mtd | all | custom (custom needs `from`, `to`)

| Dry-run case | HTTP | Result |
|---|---|---|
| Own link | 200 | OK |

<details><summary>Response — Own link (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "link": {
      "link_id": 8,
      "code": "INSTA",
      "label": "instagram",
      "type": "group_specific",
      "is_active": true
    },
    "period": {
      "key": "30d",
      "from": "2026-09-13 00:00:00",
      "to": "2026-10-12 23:59:59"
    },
    "counts": {
      "visits": 0,
      "unique_visits": 0,
      "signups": 0,
      "accounts": 0,
      "funded": 0
    },
    "earned": [],
    "daily": []
  }
}
```

</details>

## 3. Commission Distribution

### Form data

`GET /api/ibm/portal/commission-distributions/create`

- **What it does:** Data to open the 'give commission to client' form (IB wallet balance etc.).
- **Where used:** **My Commission** (`/ib-manager-portal/commission`) — `IBMgrCommission.vue:871`
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| Load form | 200 | OK |

<details><summary>Response — Load form (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "enabled": true,
    "currency": "USD",
    "balance": "3.65",
    "is_frozen": false,
    "min_amount": null,
    "max_amount": null
  }
}
```

</details>

### Search my clients

`GET /api/ibm/portal/commission-distributions/clients?search=`

- **What it does:** Client picker for the form — only the IB's own clients.
- **Where used:** My Commission — `IBMgrCommission.vue:932`
- **Params:** Query: `search`

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 200 | OK |

<details><summary>Response — List (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "clients": [
      {
        "id": 58,
        "email": "client1@example.com",
        "name": "Test Client"
      },
      "... 3 more"
    ]
  }
}
```

</details>

### Distribute to a client [W]

`POST /api/ibm/portal/commission-distributions`

- **What it does:** IB sends part of its commission to a client. Goes to the broker for approval (status `pending`); the amount is held from the IB wallet.
- **Where used:** My Commission — `IBMgrCommission.vue:984`
- **Params:** Body: `client_user_id` (required), `amount` (required, > 0), `comment` (max 500)

| Dry-run case | HTTP | Result |
|---|---|---|
| 0.5 USD to own client | 200 | OK — pending approval |
| amount 0 | 422 | OK — validation |
| Client of another IB | 422 | OK — blocked |

<details><summary>Response — 0.5 USD to own client (200)</summary>

```json
{
  "success": true,
  "message": "Your request has been submitted for approval.",
  "data": {
    "distribution_id": 1,
    "client_user_id": 58,
    "currency": "USD",
    "amount": "0.50"
  }
}
```

</details>

<details><summary>Response — amount 0 (422)</summary>

```json
{
  "success": false,
  "message": "The amount field must be greater than 0.",
  "data": {
    "errors": {
      "amount": [
        "The amount field must be greater than 0."
      ]
    }
  }
}
```

</details>

<details><summary>Response — Client of another IB (422)</summary>

```json
{
  "success": false,
  "message": "You can only send commission to your own direct clients.",
  "data": null
}
```

</details>

### Distribution history

`GET /api/ibm/portal/commission-distributions?page=1&per_page=25`

- **What it does:** Past distributions with status.
- **Where used:** My Commission — `IBMgrCommission.vue:895`
- **Params:** Query: `page`, `per_page` (1-100)

| Dry-run case | HTTP | Result |
|---|---|---|
| After one distribution | 200 | OK |

<details><summary>Response — After one distribution (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "rows": [
      {
        "id": 1,
        "client_email": "client1@example.com",
        "client_name": "Test Client",
        "currency": "USD",
        "amount": "0.50",
        "status": "pending",
        "comment": "DRYRUN",
        "rejection_reason": null,
        "requested_at": "2026-10-12 12:01:09",
        "reviewed_at": null
      }
    ],
    "pagination": {
      "current_page": 1,
      "last_page": 1,
      "per_page": 25,
      "total": 1
    }
  }
}
```

</details>

### Cancel distribution [W]

`DELETE /api/ibm/portal/commission-distributions/{id}`

- **What it does:** Cancels a pending distribution; the held amount goes back to the IB wallet.
- **Where used:** My Commission — `IBMgrCommission.vue:1016`
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| Cancel pending | 200 | OK — wallet reversed |
| Cancel same one again | 422 | OK — blocked |

<details><summary>Response — Cancel pending (200)</summary>

```json
{
  "success": true,
  "message": "Your request has been withdrawn.",
  "data": {
    "distribution_id": 1
  }
}
```

</details>

<details><summary>Response — Cancel same one again (422)</summary>

```json
{
  "success": false,
  "message": "Only a pending distribution can be cancelled.",
  "data": null
}
```

</details>

## 4. Reports

### Client funding (team deposits / withdrawals)

`GET /api/ibm/portal/client-funding?from=&to=&type=deposit&page=1`

- **What it does:** Deposits / withdrawals of the IB's clients.
- **Where used:** **My Team Deposit** (`/ib-manager-portal/team-deposits`) and **My Team Withdrawal** (`/team-withdrawals`) — `IBMgrClientFunding.vue`
- **Params:** Query: `from`, `to` (Y-m-d, optional), `type` = deposit | withdrawal, `page`

| Dry-run case | HTTP | Result |
|---|---|---|
| All | 200 | OK |
| Deposits only | 200 | OK |

<details><summary>Response — All (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "rows": [
      {
        "type": "withdrawal",
        "moved_at": "2026-09-25 07:11:15",
        "client_user_id": 82,
        "client_name": "Test Client2",
        "client_email": "cl•••••@example.com",
        "amount": 1000,
        "currency": "USC",
        "status": "approved"
      },
      "... 3 more"
    ],
    "totals": {
      "USC": {
        "deposit": 10000,
        "withdrawal": 1000
      },
      "USD": {
        "deposit": 200,
        "withdrawal": 0
      }
    },
    "pagination": {
      "page": 1,
      "per_page": 25,
      "total": 4,
      "last_page": 1
    }
  }
}
```

</details>

<details><summary>Response — Deposits only (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "rows": [
      {
        "type": "deposit",
        "moved_at": "2026-09-25 07:09:27",
        "client_user_id": 82,
        "client_name": "Test Client2",
        "client_email": "cl•••••@example.com",
        "amount": 10000,
        "currency": "USC",
        "status": "approved"
      },
      "... 2 more"
    ],
    "totals": {
      "USC": {
        "deposit": 10000,
        "withdrawal": 0
      },
      "USD": {
        "deposit": 200,
        "withdrawal": 0
      }
    },
    "pagination": {
      "page": 1,
      "per_page": 25,
      "total": 3,
      "last_page": 1
    }
  }
}
```

</details>

### Commission report

`GET /api/ibm/portal/commission-report?from=&to=&view=trade&page=1`

- **What it does:** Commission earned per trade or per account.
- **Where used:** Reports → **IB Commission** (`/ib-manager-portal/ib-commission-report`) — `IBMgrCommissionReport.vue`
- **Params:** Query: `from`, `to` **required** (Y-m-d), `view` = trade | account, `symbol`, `type` = buy | sell, `page`

| Dry-run case | HTTP | Result |
|---|---|---|
| Per trade | 200 | OK |
| Per account | 200 | OK |
| No dates | 422 | OK — validation |

<details><summary>Response — Per trade (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "view": "trade",
    "rows": [
      {
        "id": 122,
        "mt5_account": "2000040",
        "date": "2026-09-29",
        "order": 1007890,
        "symbol": "XAUUSD",
        "price": "4153.23",
        "profit": "0.19000000000050932",
        "volume": 0.01,
        "commission": 0.05,
        "currency": "USD",
        "type": "Buy"
      },
      "... 24 more"
    ],
    "summary": [
      {
        "currency": "USD",
        "trades": 69,
        "accounts": 1,
        "lots": 0.69,
        "commission": 3.45
      }
    ],
    "totals": [
      {
        "currency": "USD",
        "lots": 0.69,
        "commission": 3.45
      }
    ],
    "options": {
      "accounts": [
        "2000040"
      ],
      "symbols": [
        "XAUUSD"
      ]
    },
    "pagination": {
      "page": 1,
      "per_page": 25,
      "total": 69,
      "last_page": 3
    }
  }
}
```

</details>

<details><summary>Response — Per account (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "view": "account",
    "rows": [
      {
        "mt5_account": "2000040",
        "currency": "USD",
        "trades": 69,
        "lots": 0.69,
        "profit": -225.43,
        "commission": 3.45,
        "last_trade": "2026-09-29"
      }
    ],
    "summary": [
      {
        "currency": "USD",
        "trades": 69,
        "accounts": 1,
        "lots": 0.69,
        "commission": 3.45
      }
    ],
    "totals": [
      {
        "currency": "USD",
        "lots": 0.69,
        "commission": 3.45
      }
    ],
    "options": {
      "accounts": [
        "2000040"
      ],
      "symbols": [
        "XAUUSD"
      ]
    },
    "pagination": {
      "page": 1,
      "per_page": 25,
      "total": 1,
      "last_page": 1
    }
  }
}
```

</details>

<details><summary>Response — No dates (422)</summary>

```json
{
  "success": false,
  "message": "The from field is required. (and 1 more error)",
  "data": {
    "errors": {
      "from": [
        "The from field is required."
      ],
      "to": [
        "The to field is required."
      ]
    }
  }
}
```

</details>

### Payout report

`GET /api/ibm/portal/payout-report?from=&to=&status=&page=1`

- **What it does:** The IB's own payout (withdraw) requests from its IB wallet.
- **Where used:** Reports → **IB Withdraw** (`/ib-manager-portal/ib-withdraw-report`) — `IBMgrPayoutReport.vue`
- **Params:** Query: `from`, `to` **required** (Y-m-d), `status` = pending | approved | paid | rejected | cancelled, `page`

| Dry-run case | HTTP | Result |
|---|---|---|
| Date range | 200 | OK |
| No dates | 422 | OK — validation |

<details><summary>Response — Date range (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "rows": [],
    "totals": [],
    "pagination": {
      "page": 1,
      "per_page": 25,
      "total": 0,
      "last_page": 1
    }
  }
}
```

</details>

<details><summary>Response — No dates (422)</summary>

```json
{
  "success": false,
  "message": "The from field is required. (and 1 more error)",
  "data": {
    "errors": {
      "from": [
        "The from field is required."
      ],
      "to": [
        "The to field is required."
      ]
    }
  }
}
```

</details>

## 5. Exports (file download)

### List my exports

`GET /api/ibm/portal/exports`

- **What it does:** Exports the IB started, newest first.
- **Where used:** Export button (`IbmExportButton.vue`) on My Commission, IB Commission, IB Withdraw, Team Deposit / Withdrawal
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 200 | OK |

<details><summary>Response — List (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "exports": []
  }
}
```

</details>

### Start export

`POST /api/ibm/portal/exports`

- **What it does:** Queues a CSV build of a report.
- **Where used:** Same Export button — kind `commission_history` (My Commission, IB Commission), `ib_payouts` (IB Withdraw), `client_funding` (Team Deposit / Withdrawal)
- **Params:** Body: `kind` (required) = commission_history | client_funding | ib_payouts; optional `from`, `to`, `type`, `status`, `view`, `symbol`, `side`

| Dry-run case | HTTP | Result |
|---|---|---|
| commission_history | 200 | OK — queued |
| Wrong kind | 422 | OK — validation |

<details><summary>Response — commission_history (200)</summary>

```json
{
  "success": true,
  "message": "Your report is being prepared.",
  "data": {
    "export": {
      "id": 1,
      "kind": "commission_history",
      "status": "queued",
      "params": {
        "from": "2026-09-01",
        "to": "2026-10-12",
        "type": null,
        "status": null,
        "view": "trade",
        "mt5_account": null,
        "symbol": null,
        "side": null
      },
      "row_count": null,
      "file_size": null,
      "download_name": null,
      "error": null,
      "created_at": "2026-10-12T12:01:09+00:00",
      "finished_at": null,
      "expires_at": null,
      "is_downloadable": false
    }
  }
}
```

</details>

<details><summary>Response — Wrong kind (422)</summary>

```json
{
  "success": false,
  "message": "The selected kind is invalid.",
  "data": {
    "errors": {
      "kind": [
        "The selected kind is invalid."
      ]
    }
  }
}
```

</details>

### Export status

`GET /api/ibm/portal/exports/{id}`

- **What it does:** Poll until `status` = ready.
- **Where used:** Export button (polling)
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| Own export | 200 | OK — ready, 69 rows |
| Unknown / other IB's id | 404 | OK — blocked |

<details><summary>Response — Own export (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "export": {
      "id": 1,
      "kind": "commission_history",
      "status": "ready",
      "params": {
        "from": "2026-09-01",
        "to": "2026-10-12",
        "type": null,
        "status": null,
        "view": "trade",
        "mt5_account": null,
        "symbol": null,
        "side": null
      },
      "row_count": 69,
      "file_size": 6795,
      "download_name": "commission_history_20261012_120109.csv",
      "error": null,
      "created_at": "2026-10-12T12:01:09+00:00",
      "finished_at": "2026-10-12T12:01:09+00:00",
      "expires_at": "2026-10-13T12:01:09+00:00",
      "is_downloadable": true
    }
  }
}
```

</details>

<details><summary>Response — Unknown / other IB's id (404)</summary>

```json
{
  "success": false,
  "message": "Report not found.",
  "data": null
}
```

</details>

### Download export

`GET /api/ibm/portal/exports/{id}/download`

- **What it does:** Returns the CSV file (not JSON).
- **Where used:** Export button (download)
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| Ready export | 200 | OK — text/csv |

<details><summary>Response — Ready export (200)</summary>

```text
﻿ID,"MT5 ID",Date,Order,Symbol,Price,Profit,Volume,"My Commission",Currency,Type
50,2000040,"2026-09-01 11:41:54",1001038,XAUUSD,4491.41,-108.09000000000015,0.0100,0.0500,USD,Buy
51,2000040,"2026-09-01 11:41:56",1001034,XAUUSD,4491.16,-107.80999999999949,0.0100,0.0500,USD,Buy
52,2000040,"2026-09-01 11:41:57",1001036,XAUUSD,4491.15,-107.76999999999953,0.0100,0.0500,USD,Buy
53,2000040,"2026-09-01 11
```

</details>

# Part B — IB Client API (IB works for its own clients)

**Where used:** no screen in the client portal (crmfronend) calls these. They are for a partner's own system or a mobile app.

**Must be switched on per IB by the broker:** Admin → IB Manager → IB profile → *Client API enabled* (plus optional IP allow-list). When it is off every call here returns:

```json
{ "success": false, "message": "Client API access is not enabled for this partner. Ask the broker to switch it on.", "data": null }
```

`{userId}` must be the IB's own client, otherwise 404. `{accountNumber}` is the MT5 login number.


## 6a. Clients & KYC

### Create client

`POST /api/ibm/portal/clients`

- **What it does:** IB registers a new client under itself (multipart form).
- **Where used:** Partner system / mobile app only
- **Params:** Form: `first_name`, `last_name`, `email` (unique), `mobile` (unique, max 25), `password` (min 6), `id_proof`, `address_proof` (jpeg/png/pdf, max 10 MB, optional)

| Dry-run case | HTTP | Result |
|---|---|---|
| Missing fields | 409 | Referral-code check runs before validation (issue 8) |
| Valid data, IB has no referral code | 409 | Blocked — IB needs a referral code first; success path not tested |

<details><summary>Response — Missing fields (409)</summary>

```json
{
  "success": false,
  "message": "Your partner account has no referral code yet. Ask the broker to issue one.",
  "data": null
}
```

</details>

<details><summary>Response — Valid data, IB has no referral code (409)</summary>

```json
{
  "success": false,
  "message": "Your partner account has no referral code yet. Ask the broker to issue one.",
  "data": null
}
```

</details>

### List my clients

`GET /api/ibm/portal/clients/list?page=1&per_page=25`

- **What it does:** IB's clients with their accounts.
- **Where used:** Partner system / mobile app only
- **Params:** Query: `search`, `page`, `per_page` (1-100), `direct_only` (0/1)

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 200 | OK |

<details><summary>Response — List (200)</summary>

```json
{
  "success": true,
  "message": "Clients",
  "data": {
    "clients": [
      {
        "user_id": 82,
        "first_name": "Test",
        "last_name": "Client2",
        "email": "client2@example.com",
        "mobile": "9000000000",
        "registered_at": "2026-09-25T07:05:44+00:00",
        "profile": {
          "kyc_status": "completed",
          "kyc_bypassed": false,
          "country": 101,
          "city": 57837,
          "register_source": "1"
        },
        "wallet": {
          "wallet_id": "307303600",
          "balance": 0,
          "status": "active"
        },
        "mt5_accounts": [
          {
            "account_id": 76,
            "account_number": "2000065",
            "name": "Test Client2",
            "account_type": "live",
            "currency": "USC",
            "is_cent": false,
            "status": "active",
            "balance": 8500,
            "equity": 8500,
            "credit": 0,
            "free_margin": 0,
            "margin_level": 9999,
            "profit": 0
          },
          "... 1 more"
        ]
      },
      "... 3 more"
    ],
    "pagination": {
      "total": 4,
      "per_page": 25,
      "current_page": 1,
      "last_page": 1,
      "has_more": false
    }
  }
}
```

</details>

### Client KYC status

`GET /api/ibm/portal/clients/{userId}/kyc`

- **What it does:** KYC status, required/missing documents, uploaded documents.
- **Where used:** Partner system / mobile app only
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| After one upload | 200 | Works — see issue 5 |

<details><summary>Response — After one upload (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "kyc_status": "completed",
    "required": [
      "id_proof_front",
      "... 1 more"
    ],
    "missing": [
      "address_proof_front"
    ],
    "is_complete": false,
    "documents": [
      {
        "id": 76,
        "doc_type": "id_proof_front",
        "origin": "kyc",
        "status": "pending",
        "remark": null,
        "approved_at": null,
        "uploaded_at": "2026-10-12 12:05:03"
      }
    ],
    "counts": {
      "total": 1,
      "approved": 0,
      "pending": 1,
      "rejected": 0
    }
  }
}
```

</details>

### Upload client KYC

`POST /api/ibm/portal/clients/{userId}/kyc`

- **What it does:** Uploads a KYC document for the client (goes to the broker as pending).
- **Where used:** Partner system / mobile app only
- **Params:** Form: `files[]` (jpeg/png/pdf), `subdocument_type` (e.g. id_proof_front, address_proof_front)

| Dry-run case | HTTP | Result |
|---|---|---|
| PNG, id_proof_front | 200 | OK — document pending |

<details><summary>Response — PNG, id_proof_front (200)</summary>

```json
{
  "status": true,
  "success": true,
  "message": "Documents uploaded successfully",
  "data": {
    "path": "documents/OPprdagO/1791806703_6accccefc8333_kyc.png",
    "url": "",
    "document_url": "documents/OPprdagO/1791806703_6accccefc8333_kyc.png",
    "origin": "kyc"
  }
}
```

</details>

## 6b. Money

### Client deposits

`GET /api/ibm/portal/clients/{userId}/deposits`

- **What it does:** Deposit history.
- **Where used:** Partner system / mobile app only
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 200 | Works — see issue 6 |

<details><summary>Response — List (200)</summary>

```json
{
  "draw": 0,
  "recordsTotal": 1,
  "recordsFiltered": 1,
  "data": [
    {
      "user_id": 58,
      "mt5_account_id": "2000042",
      "reference_number": "DEP-9600",
      "amount": "$100.00",
      "transaction_id": "-",
      "status": "<span class=\"badge rounded-pill py-2 px-3 approve\">Approved</span>",
      "paymentMethod": "Local (local)",
      "proof": "-",
      "created_at": "2026-08-19 19:20:26",
      "transaction_type": "Deposit",
      "action": "",
      "reference_no": "DEP-9600",
      "mt5_wallet": "MT5 - #2000042",
      "payment_method": "-",
      "payment_details": "-",
      "updated_date": "2026-08-19",
      "date": "2026-08-19",
      "DT_RowIndex": 1
    }
  ],
  "input": {
    "transactionType": "deposit"
  }
}
```

</details>

### Client withdrawals

`GET /api/ibm/portal/clients/{userId}/withdrawals`

- **What it does:** Withdrawal history.
- **Where used:** Partner system / mobile app only
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 200 | Works — see issue 6 |

<details><summary>Response — List (200)</summary>

```json
{
  "draw": 0,
  "recordsTotal": 0,
  "recordsFiltered": 0,
  "data": [],
  "input": {
    "transactionType": "withdrawal"
  }
}
```

</details>

### Deposit methods

`GET /api/ibm/portal/deposit-methods`

- **What it does:** Methods + limits to show before a deposit.
- **Where used:** Partner system / mobile app only
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 200 | OK |

<details><summary>Response — List (200)</summary>

```json
{
  "success": true,
  "message": "No default deposit method is set for you. The broker configures this.",
  "data": {
    "credits_to": "trading_account",
    "default_method": null,
    "available_methods": [
      {
        "id": 2,
        "label": "Enet",
        "method_slug": "xs4Hf",
        "currency": null,
        "min_limit": "1.00",
        "max_limit": "100.00",
        "fees": "1.00"
      },
      "... 4 more"
    ]
  }
}
```

</details>

### Create deposit

`POST /api/ibm/portal/clients/{userId}/deposits`

- **What it does:** Creates a deposit request for the client (pending broker approval).
- **Where used:** Partner system / mobile app only
- **Params:** Body: `amount`, `mt5_account_id` (**MT5 login number**), `method_id`, `request_order_id`, `call_back_url`

| Dry-run case | HTTP | Result |
|---|---|---|
| Local method, 100 USD | 200 | OK — pending |
| Unknown method | 422 | OK — validation |
| amount 0 | 422 | OK — validation |

<details><summary>Response — Local method, 100 USD (200)</summary>

```json
{
  "status": true,
  "success": true,
  "message": "Deposit request created successfully",
  "data": {
    "id": 135
  }
}
```

</details>

<details><summary>Response — Unknown method (422)</summary>

```json
{
  "success": false,
  "message": "That deposit method is not available.",
  "data": null
}
```

</details>

<details><summary>Response — amount 0 (422)</summary>

```json
{
  "success": false,
  "message": "The amount field must be at least 0.01. (and 2 more errors)",
  "data": {
    "errors": {
      "amount": [
        "The amount field must be at least 0.01."
      ],
      "mt5_account_id": [
        "The mt5 account id field is required."
      ],
      "method_id": [
        "The method id field is required."
      ]
    }
  }
}
```

</details>

### Deposit status

`GET /api/ibm/portal/deposits/status?request_order_id=`

- **What it does:** Status of a deposit by your own order id.
- **Where used:** Partner system / mobile app only
- **Params:** Query: `request_order_id` (required)

| Dry-run case | HTTP | Result |
|---|---|---|
| Existing order | 200 | OK |
| Unknown order | 404 | OK |

<details><summary>Response — Existing order (200)</summary>

```json
{
  "success": true,
  "message": "Deposit status.",
  "data": {
    "request_order_id": "DRYRUN-DEP-1012",
    "reference_number": "DEP-645915371",
    "status": "pending",
    "amount": 100,
    "approved_amount": null,
    "utr": null,
    "processed_at": null,
    "callback": null
  }
}
```

</details>

<details><summary>Response — Unknown order (404)</summary>

```json
{
  "success": false,
  "message": "No deposit found for that order id.",
  "data": null
}
```

</details>

### Request withdrawal OTP

`POST /api/ibm/portal/otp/request`

- **What it does:** Issues a 5-minute OTP for one withdrawal. **The OTP comes back in the response** — the IB must pass it to the client.
- **Where used:** Partner system / mobile app only
- **Params:** Body: `user_id`, `action` = withdraw, `amount`, `mt5_account_id` (**mt5_accounts row id**, not the login — see issue 2)

| Dry-run case | HTTP | Result |
|---|---|---|
| Valid | 200 | OK |
| action = deposit | 422 | OK — validation |

<details><summary>Response — Valid (200)</summary>

```json
{
  "success": true,
  "message": "Send this code to your client — the broker does not deliver it.",
  "data": {
    "otp_id": 2,
    "otp": "115936",
    "expires_at": "2026-10-12 12:09:04",
    "expires_in_minutes": 5
  }
}
```

</details>

<details><summary>Response — action = deposit (422)</summary>

```json
{
  "success": false,
  "message": "The selected action is invalid. (and 1 more error)",
  "data": {
    "errors": {
      "action": [
        "The selected action is invalid."
      ],
      "mt5_account_id": [
        "The mt5 account id field is required."
      ]
    }
  }
}
```

</details>

### Withdrawal methods

`GET /api/ibm/portal/withdrawal-methods`

- **What it does:** Methods to show before a withdrawal.
- **Where used:** Partner system / mobile app only
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 200 | OK |

<details><summary>Response — List (200)</summary>

```json
{
  "success": true,
  "message": "No default payout method is set for you. The broker configures this.",
  "data": {
    "pays_from": "trading_account",
    "default_method": null,
    "available_methods": [
      {
        "id": 2,
        "method_name": "crypto",
        "label": "crypto",
        "method_slug": "crypto-withdrawal",
        "currency": null,
        "min_limit": "10.00",
        "max_limit": "500.00",
        "networks": []
      }
    ]
  }
}
```

</details>

### Create withdrawal

`POST /api/ibm/portal/clients/{userId}/withdrawals`

- **What it does:** Withdrawal for the client, needs the OTP.
- **Where used:** Partner system / mobile app only
- **Params:** Body: `amount`, `otp`, `mt5_account_id` (**MT5 login number**; not allowed on wallet-first brokers), `crypto_address` + `crypto_network`, `request_order_id`, `call_back_url`

| Dry-run case | HTTP | Result |
|---|---|---|
| No otp | 422 | OK — validation |
| Wrong otp | 422 | OK — attempts counted |
| Correct otp, crypto address | 422 | Blocked by local setting (direct crypto address off) — success path not tested |

<details><summary>Response — No otp (422)</summary>

```json
{
  "success": false,
  "message": "The mt5 account id field is required. (and 1 more error)",
  "data": {
    "errors": {
      "mt5_account_id": [
        "The mt5 account id field is required."
      ],
      "otp": [
        "The otp field is required."
      ]
    }
  }
}
```

</details>

<details><summary>Response — Wrong otp (422)</summary>

```json
{
  "success": false,
  "message": "That code is wrong. 4 attempt(s) left.",
  "data": null
}
```

</details>

<details><summary>Response — Correct otp, crypto address (422)</summary>

```json
{
  "status": false,
  "success": false,
  "message": "Direct crypto address entry is not enabled for this account.",
  "data": []
}
```

</details>

### Withdrawal status

`GET /api/ibm/portal/withdrawals/status?request_order_id=`

- **What it does:** Status by your own order id.
- **Where used:** Partner system / mobile app only
- **Params:** Query: `request_order_id` (required)

| Dry-run case | HTTP | Result |
|---|---|---|
| Unknown order | 404 | OK |

<details><summary>Response — Unknown order (404)</summary>

```json
{
  "success": false,
  "message": "No withdrawal found for that order id.",
  "data": null
}
```

</details>

### Client wallet

`GET /api/ibm/portal/clients/{userId}/wallet`

- **What it does:** Wallet balance.
- **Where used:** Partner system / mobile app only
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| Own client | 200 | OK |
| Client of another IB | 404 | OK — blocked |

<details><summary>Response — Own client (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "wallet": {
      "wallet_id": "4025873",
      "balance": "20.00",
      "pending_reserved": "0.00",
      "available": "20.00",
      "status": "active"
    }
  }
}
```

</details>

<details><summary>Response — Client of another IB (404)</summary>

```json
{
  "success": false,
  "message": "Client not found.",
  "data": null
}
```

</details>

### Client wallet history

`GET /api/ibm/portal/clients/{userId}/wallet/history?page=1`

- **What it does:** Wallet ledger.
- **Where used:** Partner system / mobile app only
- **Params:** Query: `page`

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 200 | OK |

<details><summary>Response — List (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "wallet_id": "4025873",
    "current_balance": "20.00",
    "transactions": [
      {
        "id": 73,
        "type": "transfer",
        "direction": "in",
        "amount": "10.00",
        "balance_before": "10.00",
        "balance_after": "20.00",
        "from": {
          "type": "trading_account",
          "account": "2000042"
        },
        "to": {
          "type": "wallet",
          "account": "4025873"
        },
        "reference": "from:2000042",
        "description": "Internal transfer ← TA#2000042",
        "settled": true,
        "created_at": "2026-08-20 05:02:30"
      },
      "... 3 more"
    ],
    "pagination": {
      "current_page": 1,
      "last_page": 1,
      "per_page": 25,
      "total": 4
    }
  }
}
```

</details>

### Transfer (wallet ↔ MT5)

`POST /api/ibm/portal/clients/{userId}/transfers`

- **What it does:** Moves money between the client's wallet and MT5 accounts.
- **Where used:** Partner system / mobile app only
- **Params:** Body: `from_account`, `to_account` (wallet id or MT5 login; must differ), `amount` (min 0.01)

| Dry-run case | HTTP | Result |
|---|---|---|
| Same from/to | 422 | OK — validation |
| Wallet → MT5, 1 USD | 500 | **BUG** — 500 timeout but money moved (issue 3) |

<details><summary>Response — Same from/to (422)</summary>

```json
{
  "success": false,
  "message": "The to account field and from account must be different.",
  "data": {
    "errors": {
      "to_account": [
        "The to account field and from account must be different."
      ]
    }
  }
}
```

</details>

<details><summary>Response — Wallet → MT5, 1 USD (500)</summary>

```json
{
  "message": "Maximum execution time of 30 seconds exceeded",
  "exception": "Symfony\\Component\\ErrorHandler\\Error\\FatalError"
}
```

</details>

## 6c. MT5

### MT5 groups

`GET /api/ibm/portal/mt5-groups`

- **What it does:** Groups the client can open an account in.
- **Where used:** Partner system / mobile app only
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| List | 500 | **BUG** — always 500 (issue 1) |

<details><summary>Response — List (500)</summary>

```json
{
  "message": "SQLSTATE[42S22]: Column not found: 1054 Unknown column 'account_type' in 'SELECT' (Connection: mysql, Host: 127.0.0.1, P...",
  "exception": "Illuminate\\Database\\QueryException"
}
```

</details>

### Open MT5 account

`POST /api/ibm/portal/clients/{userId}/mt5`

- **What it does:** Opens a live MT5 account for the client.
- **Where used:** Partner system / mobile app only
- **Params:** Body: `group_id`, `leverage`, `main_password`, `investor_password` (8-16, different)

| Dry-run case | HTTP | Result |
|---|---|---|
| Same passwords | 422 | OK — validation |
| Group limit already reached | 500 | Rule works, but sent as 500 (issue 4) |

<details><summary>Response — Same passwords (422)</summary>

```json
{
  "success": false,
  "message": "The investor password field and main password must be different.",
  "data": {
    "errors": {
      "investor_password": [
        "The investor password field and main password must be different."
      ]
    }
  }
}
```

</details>

<details><summary>Response — Group limit already reached (500)</summary>

```json
{
  "status": false,
  "success": false,
  "message": "Live account limit reached for this trading group. Maximum 1 account(s) allowed per group. Please contact support to inc...",
  "data": {
    "group_id": 1,
    "group_name": "Standard",
    "limit": 1
  }
}
```

</details>

### MT5 account detail

`GET /api/ibm/portal/clients/{userId}/mt5/{accountNumber}`

- **What it does:** Account info (live data from the trade engine).
- **Where used:** Partner system / mobile app only
- **Params:** —

| Dry-run case | HTTP | Result |
|---|---|---|
| Own account | 200 | OK (local engine off → live:false) |

<details><summary>Response — Own account (200)</summary>

```json
{
  "success": true,
  "message": "",
  "data": {
    "mt5_account_id": 48,
    "login": "2000042",
    "name": "Test Client",
    "group": "Standard",
    "leverage": 500,
    "currency": "USD",
    "account_type": "live",
    "status": "active",
    "balance": "80.00",
    "equity": "80.00",
    "margin": "0.00",
    "free_margin": "0.00",
    "profit": "0.00",
    "credit": "0.00",
    "live": false
  }
}
```

</details>

### MT5 trades

`GET /api/ibm/portal/clients/{userId}/mt5/{accountNumber}/trades?period=30d`

- **What it does:** Closed trades.
- **Where used:** Partner system / mobile app only
- **Params:** Query: `period`

| Dry-run case | HTTP | Result |
|---|---|---|
| 30 days | 200 | Works — see issue 7 |

<details><summary>Response — 30 days (200)</summary>

```json
{
  "status": true,
  "success": true,
  "message": "Trade history fetched successfully",
  "data": [],
  "pagination": {
    "current_page": 1,
    "last_page": 0,
    "per_page": 10,
    "total": 0,
    "next_page_url": null,
    "prev_page_url": null
  },
  "totals": {
    "balance": 0,
    "commission": 0,
    "deposit": 0,
    "profit": 0,
    "swap": 0,
    "withdrawal": 0
  },
  "summary": {
    "filtered_count": 0,
    "total_deals": 0,
    "total_closed_volume": 0
  }
}
```

</details>

### Change MT5 main / investor password

`POST /api/ibm/portal/clients/{userId}/mt5/{accountNumber}/password/main (or /investor)`

- **What it does:** Changes the MT5 password.
- **Where used:** Partner system / mobile app only
- **Params:** Body: `new_password` (upper + lower + digit + special)

| Dry-run case | HTTP | Result |
|---|---|---|
| Weak password | 422 | OK — validation |
| Valid password | 500 | Not verified — local trade engine is off |

<details><summary>Response — Weak password (422)</summary>

```json
{
  "success": false,
  "message": "The new password field must be at least 8 characters. (and 1 more error)",
  "data": {
    "errors": {
      "new_password": [
        "The new password field must be at least 8 characters.",
        "... 1 more"
      ]
    }
  }
}
```

</details>

<details><summary>Response — Valid password (500)</summary>

```json
{
  "status": false,
  "success": false,
  "message": "Something went wrong",
  "data": []
}
```

</details>

# Part C — Issues found in the dry run

None of these are fixed. Code paths are in `crmwebadmin/core/Modules/IBManager/`.

**1. `GET /mt5-groups` always returns 500 — broken on every broker.**
`Http/Controllers/PortalApi/GroupController.php:80` reads column `mt5_group_masters.account_type`, which migration `2026_07_07_000002` removed. Error: `Unknown column 'mt5_group_masters.account_type'`. The app cannot show a group list, so it cannot open MT5 accounts through this API.

**2. `mt5_account_id` means two different things.**
`POST /otp/request` looks it up as the **mt5_accounts row id** (`PortalApi/OtpController.php:61-63`), but `POST /clients/{id}/withdrawals` and `/deposits` look it up as the **MT5 login number** (`PortalApi/ClientController.php:1504`). Same field name, two meanings. Sending the login to `/otp/request` → 404 "Account not found"; sending the row id to `/withdrawals` → 404. Mobile app has to send different values for the same field until fixed.

**3. Transfer returns 500 but the money still moves.**
`POST /clients/{id}/transfers` (wallet → MT5, 1 USD) timed out after 30 s (local trade engine off) and returned 500 `Maximum execution time of 30 seconds exceeded`. In the DB the transfer was already `approved`, the wallet went 20 → 19 and the MT5 balance 80 → 81. An app that retries on 500 will transfer twice. (Each transfer writes 4 ledger rows — same as normal client-app transfers, so not new.)

**4. Business rule errors come back as 500.**
`POST /clients/{id}/mt5` when the group limit is reached returns HTTP **500** with a clear message ("Live account limit reached..."). Same for other errors passed through from core (e.g. password change "Something went wrong"). Should be 4xx so the app can show the message instead of a crash screen.

**5. KYC status is contradictory.**
`GET /clients/{id}/kyc` returned `kyc_status: "completed"` while `is_complete: false`, one document `pending`, and `missing: ["address_proof_front"]`. The app should trust `is_complete` / `missing`, not `kyc_status`.

**6. Deposit / withdrawal lists use a different format.**
`GET /clients/{id}/deposits` and `/withdrawals` return the admin DataTables shape (`draw`, `recordsTotal`, `data`), with `amount` as text (`"$100.00"`) and `status` as **HTML** (`<span class="badge ...">Approved</span>`). Not the `{success, data}` envelope; the app has to strip HTML.

**7. MT5 trades uses its own envelope.**
`GET /clients/{id}/mt5/{acct}/trades` returns `{status, success, message, data, pagination, totals, summary}` — different from the rest.

**8. Create client is blocked until the IB has a referral code.**
`POST /clients` returns 409 "Your partner account has no referral code yet" — checked **before** validation, so even an empty form gets 409, not 422.

**9. OTP is returned to the IB in the response.**
`POST /otp/request` returns the code in `data.otp` ("the broker does not deliver it"). This is by design, but it means the IB alone can request and use the OTP for a client's withdrawal — the client never sees it.

**10. Link stats API is not used.**
`GET /links/{id}/stats` works, but no screen calls it.

## Not tested / not proven

- Create client success (IB had no referral code), withdrawal success (direct crypto address is off locally), MT5 open success (group limit reached), MT5 password change (trade engine off locally), deposit/withdrawal callbacks to `call_back_url`.
- Should be re-run on a **test broker** before giving the API to an outside partner.
