# Bonus Module API Documentation (Mobile Integration Reference)

This document provides a comprehensive reference for integrating the **Bonus Module** into native mobile applications (iOS/Android). It maps the backend API endpoints exposed to the client-side application.

---

## 🔑 Global Authentication & Headers

All requests to the backend API require user authentication. Use the following headers:

| Header Name | Type | Value / Format | Description |
| :--- | :--- | :--- | :--- |
| `Authorization` | String | `Bearer <JWT_ACCESS_TOKEN>` | Bearer token obtained during authentication login. |
| `Content-Type` | String | `application/json` | Required for all POST requests. |
| `Accept` | String | `application/json` | Required to receive structured JSON responses. |

---

## 📌 Endpoint Summary

| Endpoint | Method | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `/api/bonus` | `GET` | Fetch active campaigns, eligible deposits, and eligible mappings. | Yes |
| `/api/bonus/bonusClaimList` | `GET` | Fetch the authenticated user's claim history. | Yes |
| `/api/bonus/bonusClaim` | `POST` | Claim a specific bonus against a successful deposit. | Yes |
| `/api/bonus/bonusClaimCancel` | `POST` | Request cancellation for a pending or active bonus. | Yes |

---

## 📂 API Details & Payload Schema

### 1. Get Available Bonuses & Eligible Deposit Mappings
This is the core endpoint for determining eligibility. The backend dynamically calculates which deposits qualify for which bonuses and returns the filtered mappings directly, eliminating complex client-side calculations.

* **URL:** `/api/bonus`
* **Method:** `GET`
* **Response (Success - `200 OK`):**
  ```json
  {
    "status": true,
    "data": {
      "bonus": [
        {
          "id": 12,
          "title": "Welcome 50% Bonus",
          "campaign_kind": "welcome",
          "bonus_type": "percentage",
          "bonus_percentage": 50,
          "bonus_amount_fixed": 0,
          "min_deposit_required": 100.00,
          "expiry_date": "2026-12-31T23:59:59Z",
          "is_active": true,
          "description": "Get a 50% bonus credit on your very first deposit of $100 or more."
        }
      ],
      "newDepositRequests": [
        {
          "id": 401,
          "amount": 250.00,
          "reference_number": "DEP-908124",
          "mt5_account_id": "4008124",
          "created_at": "2026-08-13T10:00:00Z"
        },
        {
          "id": 402,
          "amount": 25.00,
          "reference_number": "DEP-908125",
          "mt5_account_id": "",
          "created_at": "2026-08-13T10:15:00Z"
        }
      ],
      "eligibleBonusesByDepositId": {
        "401": [
          {
            "id": 12,
            "title": "Welcome 50% Bonus",
            "campaign_kind": "welcome",
            "bonus_type": "percentage",
            "bonus_percentage": 50,
            "bonus_amount_fixed": 0,
            "min_deposit_required": 100.00,
            "expiry_date": "2026-12-31T23:59:59Z",
            "is_active": true
          }
        ],
        "402": []
      },
      "mt5Accounts": [
        {
          "login": "4008124",
          "name": "Standard Account",
          "server": "Tenax-Server"
        }
      ]
    }
  }
  ```

---

## 🔍 How to Determine Deposit Eligibility on Mobile Client

Mobile developers do not need to hardcode eligibility checks (like deposit method, date range, or user tier). The backend does the heavy lifting and provides the mapping under `eligibleBonusesByDepositId` inside the `/api/bonus` response payload:

1. **Step 1: Call `GET /api/bonus`**
   Retrieve the lists of available deposits (`newDepositRequests`) and campaigns (`bonus`).
2. **Step 2: Inspect `eligibleBonusesByDepositId`**
   * This object's keys correspond to the `id` of deposits in `newDepositRequests`.
   * The value of each key is an array of bonus campaigns that **this specific deposit is eligible to claim**.
3. **Step 3: Render on Mobile UI**
   * **Deposit Selector view:** For a selected deposit ID (e.g., `401`), loop through `eligibleBonusesByDepositId["401"]` to populate the list of claimable bonuses.
   * **If a deposit has no eligible bonuses** (like deposit `402` which is $25.00 and does not meet the $100 minimum deposit threshold), the array will be empty (`[]`). Display a message: *"No active bonuses are available for this deposit amount."*

---

### 2. Get Bonus Claim History
Fetches a list of all claims made by the logged-in user, including their real-time lot progress, remaining time, and status.

* **URL:** `/api/bonus/bonusClaimList`
* **Method:** `GET`
* **Response (Success - `200 OK`):**
  ```json
  {
    "status": true,
    "data": [
      {
        "id": 245,
        "bonus_id": 12,
        "mt5_account": "4008124",
        "bonus_type": "Percentage (50%)",
        "bonus_percentage": "50%",
        "bonus_amount": "$500.00",
        "deposit_request_id": "DEP-908124",
        "current_lots": 3.42,
        "lot_size": 10.00,
        "remaining_days": 18,
        "status": "claimed",
        "created_at": "2026-08-10T12:30:00Z"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "lastPage": 1,
      "perPage": 10,
      "total": 1
    }
  }
  ```

#### Status Enumerations:
* `pending` — Waiting for initial system processing.
* `claimed` — Active bonus credit inside MT5 trading account.
* `cancel_requested` — User submitted a cancellation request; waiting for admin approval.
* `cancelled` — Bonus successfully cancelled and credit removed.
* `rejected` — Claim request rejected by admin.

---

### 3. Claim a Bonus
Submit a request to claim an available bonus against a successful deposit.

* **URL:** `/api/bonus/bonusClaim`
* **Method:** `POST`
* **Request Body Parameter Specification:**
  ```json
  {
    "bonus_id": 12,
    "deposit_id": "401",
    "selected_percentage": 50,
    "target_mt5_account": "4008124"
  }
  ```

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `bonus_id` | Integer | **Yes** | The ID of the bonus campaign to claim. |
| `deposit_id` | Integer | **Yes** | The ID of the corresponding successful deposit (e.g., `401`). |
| `selected_percentage` | Integer | No | Only required if the bonus allows custom percentage sliders. |
| `target_mt5_account` | String | No | Target MT5 account number. Required for wallet deposits or withdrawable campaigns. |

---

### 4. Cancel a Claimed/Pending Bonus
Allows users to opt-out and request cancellation of their active/pending bonuses.

* **URL:** `/api/bonus/bonusClaimCancel`
* **Method:** `POST`
* **Request Body Parameter Specification:**
  ```json
  {
    "id": 245,
    "reason": "I want to make a withdrawal which requires clearing active bonuses."
  }
  ```

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `id` | Integer | **Yes** | The ID of the bonus claim (not the campaign ID). |
| `reason` | String | No | Description explaining why the user is requesting cancellation. |

---

## 📱 Mobile Client Integration Checklists

### 1. Wallet Deposit vs. Direct Account Deposit Handling
* If the user deposited directly into an MT5 account, the backend maps the bonus credit automatically.
* **Wallet Deposits:** If the user made a wallet deposit, the mobile client **must** display an MT5 account selector dropdown so the user can choose which trading account will receive the credit (see `/api/bonus/bonusClaim` payload parameter `target_mt5_account`).

### 2. Live Lot Progress Bars
* For withdrawable campaigns, show progress indicators on mobile cards:
  $$\text{Progress \%} = \min\left(\left(\frac{\text{current\_lots}}{\text{lot\_size}}\right) \times 100,\ 100\right)$$
* Render as disabled/greyed-out progress bars for fixed non-withdrawable campaigns.
