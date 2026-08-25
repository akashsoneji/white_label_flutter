# IB Dashboard — Complete Requirements
> Jo ek IB dekhna chahta hai jab woh apna portal open kare

---

## 1. Overview Cards (Top Row) — "Mera Business Kaisa Hai"

Yeh 4-5 cards sabse upar hone chahiye — ek nazar me pura business dikh jaye.

| Card | Data | Source |
|------|------|--------|
| **Total Clients** | Mere directly refer kiye clients (active + inactive) | `ibm_hierarchy` |
| **Network Size** | Direct + Sub-IB chain ke saare clients | `ibm_hierarchy` (recursive) |
| **Sub-IBs** | Kitne IBs mere under kaam kar rahe hain | `ibm_hierarchy` |
| **My IB Rank / Level** | Broker ne jo tier assign kiya (Silver / Gold / etc.) | `ibm_profiles` |
| **Member Since** | Main kab se IB hoon | `ibm_profiles.approved_at` |

---

## 2. Commission Summary — "Mera Paisa"

Sabse important section. Period filter ke saath (Today / 7D / MTD / YTD / All).

```
┌─────────────────┬──────────────────┬─────────────────┬──────────────────┐
│  Total Earned   │   Paid Out       │   Available     │   Pending        │
│  $12,450.00     │  $10,000.00      │   $2,200.00     │   $250.00        │
│  (lifetime)     │  (transferred)   │   (ready now)   │  (in approval)   │
└─────────────────┴──────────────────┴─────────────────┴──────────────────┘
```

### Per-Currency Breakdown
- USD commission: $X
- EUR commission: €X
- (har currency alag row)

### Commission by Source
| Source | Amount | % of Total |
|--------|--------|------------|
| Direct clients trade | $X | 70% |
| Sub-IB network | $X | 30% |

### Commission Trend (Mini Chart)
- Last 6 months bar chart — har mahine kitna mila
- Trend line: upar ja raha hai ya neeche

---

## 3. Trading Volume — "Meri Network Ne Kitna Trade Kiya"

Period filter ke saath.

| Metric | Value |
|--------|-------|
| **Total Lots** | 1,245.50 |
| **Total Trades** | 3,421 |
| **Active Traders** | 28 (is month trade kiya) |
| **Avg Lots / Trader** | 44.48 |
| **Top Symbol** | XAUUSD (45% volume) |

### Volume by Symbol (Top 5)
```
XAUUSD  ████████████░░░░  45%  312.5 lots
EURUSD  ██████░░░░░░░░░░  22%  145.2 lots
GBPUSD  ████░░░░░░░░░░░░  15%   98.1 lots
...
```

---

## 4. Client Funnel — "Meri Network Ki Health"

```
Applied → Approved → Funded → Active Trader
  120    →   95    →   72   →     41
```

| Status | Count |
|--------|-------|
| Total Registered | 120 |
| KYC Approved | 95 |
| First Deposit Done | 72 |
| Active This Month | 41 |
| Churned (no trade 60d) | 18 |
| New This Month | 7 |

---

## 5. Deposits & Withdrawals — "Meri Network Ka Fund Flow"

Period filter ke saath.

| | Amount | Count |
|-|--------|-------|
| **Total Deposited** | $145,000 | 234 txns |
| **Total Withdrawn** | $32,000 | 89 txns |
| **Net Funding** | $113,000 | — |
| **First Deposits** | $28,000 | 7 new clients |
| **Avg Deposit Size** | $619 | — |

---

## 6. Sub-IB Performance — "Mere Neeche Waale Kaise Kar Rahe Hain"

Table — har sub-IB ki performance ek row me.

| Sub-IB Name | Clients | Lots | Commission | Status |
|-------------|---------|------|------------|--------|
| Ahmed Khan | 12 | 234.5 | $1,200 | 🟢 Active |
| Sara Ali | 8 | 123.0 | $680 | 🟢 Active |
| Raj Verma | 3 | 12.0 | $45 | 🟡 Low |
| Mona Patel | 1 | 0 | $0 | 🔴 Inactive |

- Click karo → us sub-IB ka detail drill-down

---

## 7. Recent Activity Feed — "Aaj Kya Hua"

Timeline format, latest upar.

```
🟢 2h ago    Ahmed deposited $500
💰 3h ago    Commission earned: $45.50 from XAUUSD trade
👤 5h ago    New client registered: sara@example.com
🔴 1d ago    Client John withdrew $1,200
💰 1d ago    Sub-IB Raj earned $12.00 (your share: $3.00)
📋 2d ago    Pending commission request approved: $250.00
```

---

## 8. Commission Payout History — "Mujhe Kab Kab Paise Mile"

| Date | Amount | Method | Status | Ref |
|------|--------|--------|--------|-----|
| 01 Aug 2026 | $2,000 | Wallet Transfer | ✅ Paid | TXN-001 |
| 15 Jul 2026 | $1,500 | Wallet Transfer | ✅ Paid | TXN-002 |
| 01 Jul 2026 | $800 | Wallet Transfer | ⏳ Pending | TXN-003 |

---

## 9. Referral Links — "Mere Links Ki Performance"

| Link Name | Clicks | Signups | Conversion | Commission |
|-----------|--------|---------|------------|------------|
| Main Link | 1,240 | 95 | 7.7% | $8,200 |
| WhatsApp Link | 340 | 22 | 6.5% | $1,800 |
| Instagram | 120 | 8 | 6.7% | $650 |

---

## 10. My Setup / Profile Status — "Mera Account Set Hai Ya Nahi"

Status checklist — ek nazar me IB apna setup check kare.

```
✅ IB Application Approved
✅ KYC Verified
✅ Trading Account Linked
✅ Commission Plan Assigned:  Gold Plan — $5/lot XAUUSD
✅ Referral Link Active
⚠️  Bank Details Not Added (payout ke liye zaruri)
❌  Sub-IB Invitation Pending (2 invites sent, awaiting)
```

### My Commission Plan Details
| Symbol Group | Rate | Type |
|--------------|------|------|
| Metals (XAUUSD, XAGUSD) | $5.00 / lot | Per Lot |
| Forex Majors | $3.00 / lot | Per Lot |
| Crypto | 0.5% of volume | % |
| Indices | $2.00 / lot | Per Lot |

---

## 11. Alerts & Actions — "Mujhe Kya Karna Hai"

Red/yellow banners jo action demand kare.

```
🔴  2 clients ke KYC expire hone wale hain — Remind them
🟡  $250 commission pending approval (3 days old)
🟡  Sub-IB Raj ne 60 days se trade nahi kiya
🟢  $2,200 available for withdrawal — Request Now
```

---

## 12. Period Filter (Global)

Har section pe apply ho:

```
[ Today ]  [ 7D ]  [ 30D ]  [ MTD ]  [ YTD ]  [ Custom ]
```

Scope:
```
[ My Direct Clients ]  [ Full Network ]
```

---

## Data API Endpoints Needed (Backend)

| Endpoint | Data |
|----------|------|
| `GET /api/ibm/portal/dashboard` | Overview cards + summary |
| `GET /api/ibm/portal/clients` | Client list + funnel stats |
| `GET /api/ibm/portal/commission` | Commission breakdown + history |
| `GET /api/ibm/portal/trading` | Volume, lots, symbols |
| `GET /api/ibm/portal/sub-ibs` | Sub-IB performance table |
| `GET /api/ibm/portal/referrals` | Link click/signup stats |
| `GET /api/ibm/portal/payouts` | Payout history |
| `GET /api/ibm/portal/alerts` | Pending actions |
| `GET /api/ibm/portal/profile` | Setup status + plan details |

---

## Priority Order (Kaun Pehle Banana Hai)

```
Phase 1 — Abhi (data already available)
  ✅ Overview cards (clients, sub-ibs, commission totals)
  ✅ Commission summary (earned / paid / available)
  ✅ Period filter

Phase 2 — Next
  📋 Trading volume + symbol breakdown
  📋 Client funnel
  📋 Sub-IB performance table

Phase 3 — After
  📋 Referral link analytics
  📋 Activity feed
  📋 Alerts & actions

Phase 4 — Later
  📋 Payout history
  📋 Mini charts (trend)
  📋 Profile setup checklist
```

---

## UX Rules

1. **Numbers pehle** — Value bada, label chota. IB number dekhna chahta hai, description nahi.
2. **Currency hamesha saath** — `$1,200` nahi, `USD 1,200.00` — kyunki multi-currency hogi.
3. **Period filter sticky** — Ek jagah change karo, poora page update ho.
4. **Zero state** — Agar data nahi hai, card `—` dikhaye, error nahi.
5. **Mobile first** — IBs phone pe dekhte hain — cards stack hone chahiye.
6. **Export** — Commission + client table CSV export hona chahiye.
