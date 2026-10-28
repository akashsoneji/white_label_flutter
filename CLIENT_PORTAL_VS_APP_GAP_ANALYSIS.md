# Client Portal vs Mobile App — API & Feature Gap Analysis

Generated 2026-10-27. Source docs: [user-guide.md](user-guide.md) (screen flow) aur [client-portal-endpoints.md](client-portal-endpoints.md) (har API ka detail). App side: `lib/` (mainly `lib/constants/api_const.dart`, `lib/services/*`, `lib/screens/ibm/data/ibm_api_provider.dart`, `lib/routes/app_routes.dart`).

## Kaise compare kiya

- `client-portal-endpoints.md` ke har `#### METHOD /api/...` heading ko ek API maana — **306 unique APIs** (index me 347 likha hai kyunki wahan same API multiple screens par count hui hai).
- App ke saare Dart files scan kiye: `ApiConstants` ke `${ajax}` interpolation resolve kiye, inline string literals (`'user/...'`, `'ibm/...'`, `'v1/...'`, `'copytrading/...'`) bhi pakde. Commented Swift block (`api_const.dart:294+`) ignore kiya.
- Path compare kiya (`/api/` prefix hata ke, `{id}` / `:param` = wildcard, case-insensitive). HTTP method compare nahi kiya.
- Jo "missing" aaye unko non-comment Dart code me dobara grep karke verify kiya; 2 false-negatives manually "common" me shift kiye, 7 ko "Alternate" maana (app same kaam doosri API se karta hai).
- Limitation: static analysis hai. Runtime par bani dynamic URL (string concat) ho to chhoot sakti hai; method mismatch (GET vs POST) is report me detect nahi hota.

## Summary

| | Count |
|---|---|
| Docs me total APIs | 306 |
| Common (docs + app dono me) | **215** (70%) |
| Alternate (app doosri API use karta hai) | 7 |
| Docs me hai, app me nahi | **84** |
| App me hai, docs me nahi | ~40 |

### Module-wise coverage

| Module (docs) | Total | Common | Alternate | Missing |
|---|---|---|---|---|
| Auth (Login / Register / OTP / Password) | 16 | 8 | 0 | 8 |
| App shell (every logged-in page) | 17 | 8 | 0 | 9 |
| Dashboard | 11 | 8 | 0 | 3 |
| Trading Accounts | 3 | 3 | 0 | 0 |
| Trading Terminal | 20 | 10 | 1 | 9 |
| Deposit | 7 | 5 | 0 | 2 |
| Withdrawal | 5 | 5 | 0 | 0 |
| Internal Transfer | 8 | 3 | 0 | 5 |
| IB Dashboard (classic IB) | 43 | 28 | 1 | 14 |
| IB Manager Portal | 48 | 48 | 0 | 0 |
| PAMM | 33 | 27 | 1 | 5 |
| Copy Trading | 31 | 29 | 1 | 1 |
| Tickets | 6 | 6 | 0 | 0 |
| Platforms | 1 | 0 | 0 | 1 |
| Settings | 37 | 11 | 2 | 24 |
| Promotions & extras | 20 | 16 | 1 | 3 |

Fully covered: **Trading Accounts, Withdrawal, IB Manager Portal, Tickets**. Sabse bada gap: **Settings (24)**, **IB Dashboard (14)**, **App shell (9)**, **Trading Terminal (9)**, **Auth (8)**.

---

## Feature / screen mapping (user-guide.md → app)

Legend: ✅ app me hai · 🟡 partial (screen hai, kuch APIs/flows missing) · ❌ app me nahi · ➖ web-only, mobile me zaroorat nahi

### Auth
- ✅ Login `/login` → `lib/screens/auth/presentation/pages/login_screen.dart` (email login + Google 2FA OTP `google_login_otp_screen.dart`)
- ✅ Register `/register` → `create_account_screen.dart`, OTP → `verify_code_screen.dart`
- ✅ Forgot / Verify OTP / Reset password → `forgot_password_screen.dart`, `verify_code_screen.dart`, `create_new_password_screen.dart`
- ❌ Google Sign-In (OAuth redirect / callback / complete-registration)
- ❌ Referral / invite link `/user/invite/:code` (sponsor visit tracking, `ibm/r/{code}`)
- ❌ SSO verify `/user/sso/verify/:token`
- ➖ Auto-login from landing site `/auth/from-net`

### App shell
- ✅ CRM settings / maintenance / force update (`crm-settings`, `mobile-app-details`)
- ✅ Module guard → app `user/enabled-modules` use karta hai (docs: `user/modules`)
- 🟡 Notifications header → list hai, **mark-as-read (single/all) nahi**
- ❌ Active notices (`notices/active`), session check (`session/check`), MT5 credentials popup + ack, banner tracking, `current-page`, `prop-coupons`, `user/json`

### Dashboard
- ✅ Dashboard, accounts, primary account (`lib/screens/trading/presentation/pages/dashboard_screen.dart`)
- ❌ Account nickname (`mt5accounts/setnickname`), price-alert FCM token update (`price-alerts/update-fcm-token`)

### Trading Accounts — ✅ complete
Open account, change leverage, change MT5 / investor password (`open_account_screen.dart`, `change_leverage_screen.dart`, `change_password_screen.dart`).

### Trading Terminal
- ✅ Native trade screen: market watch, new order, close / modify / pending orders, TP-SL, trade history (`trade_screen.dart`, `pending_order_screen.dart`, `order_history_screen.dart`)
- ✅ Mobile WebView chart (`chart_screen.dart`)
- 🟡 Price alerts → create/list hai, **edit (PUT) / delete (DELETE) nahi**
- ❌ Chart state / chart store save-load, trade history export, `tradingaccounts/sync` (app `mt5accounts/mt5AccountSync` use karta hai), economic calendar

### Deposit
- ✅ Methods, deposit request/history, Cregis flow (`deposit_screen.dart`, `deposit_instruction_screen.dart`, `cregis_address_screen.dart`, `cregis_success_screen.dart`)
- ❌ UniPayment (`deposit/unipayment` + success/cancel), dynamic gateway (`deposit/dynamic/{gatewaySlug}`)

### Withdrawal — ✅ complete
`withdrawal_screen.dart` (methods, OTP, request, check balance).

### Internal Transfer
- ✅ Internal transfer + history (`internal_transfer_screen.dart`, `internal_transfer_history_screen.dart`)
- ❌ **Trader-to-Trader transfer** poora feature (config, verify recipient, send OTP, submit, history — 5 APIs)

### IB Dashboard (classic IB)
- ✅ IB application / dashboard / stats, my structure, sub-IB structure + commission groups, clients, sub-IB approval, transfer commission + history, IB Trade & Win (`lib/screens/ib/presentation/pages/*`)
- 🟡 My Network → **tree-structure aur `get-ib-details/{userSlug}` nahi**; Sub-IB approval → `get-structure-options/{id}` nahi; Sub-IB structure → `get-template-rates/{templateId}` nahi; `ib/activities` nahi
- ❌ **IB Demo Contest** (IB khud contest banata hai): my-contests, store, update, cancel, add-prize-fund, instruments, enrollments, approve/reject — 9 APIs

### IB Manager Portal — ✅ complete (48/48)
`lib/screens/ibm/*`. App isse aage bhi hai — extra endpoints niche "App-only" me.

### Transaction History
- ✅ `transaction_history_screen.dart` (`user/transactions`, `finance-activity`). Docs me is section ki APIs dusre sections me link hain, alag count nahi.

### PAMM
- ✅ Explore managers, my investments, manager profile, apply, manager dashboard, plans, plan view, investor requests, investors (`lib/screens/home/more/pmam/*`)
- 🟡 Explore → plans search / datatable nahi, managers search nahi; managers list ke liye app `managers/datatable` use karta hai
- ❌ Manager commissions (`pmam/manager/commissions`), manager eligible accounts

### Copy Trading — ✅ almost complete (29/31)
`lib/screens/home/more/copytrading/*`, `lib/screens/copy_trading/*`.
- ❌ Plans search (`copytrading/plans/search`)
- Alternate: master trade history — app authenticated `user/copytrading/copier/masters/{code}/trade-history` use karta hai, docs public `copytrading/masters/{code}/trade-history`

### Tickets — ✅ complete
`lib/screens/home/more/ticket/*`. Live chat: app me `/chat-with-us` route hai, par `user/live-chat` API call nahi hoti.

### Platforms — ❌
`user/platform-links` (MT5 download links) app me nahi.

### Settings
- ✅ Profile view/edit, change password, Google 2FA generate/verify/disable, delete account, KYC (unified compliance wizard + docs upload), bank / withdrawal methods list
- 🟡 Country/state/city → app `settings/get*Dropdown` use karta hai (docs `kyc/countries|states|cities`)
- ❌ Security: 2FA status, active sessions/devices (list + logout), robot-trading API key (status / create / regenerate / delete)
- ❌ KYC providers: Shufti (start/status), Sumsub (token/refresh), mobile number verification (send/verify)
- ❌ Documents: chunked upload (upload-chunk / finalize-chunked), `kyc-image-proxy`
- ❌ Bank accounts: delete withdrawal method, IFSC lookup; withdrawal details `image-proxy`
- ❌ Login activities (`settings/activitylog`)
- ❌ Notification / email preferences (`email-preferences` GET/POST)
- ❌ API guide page
- ➖ Email unsubscribe (web link flow)

### Promotions & extras
- ✅ Notifications list, Bonus, Scratch card, Trade & Win, Demo Contest list/detail/leaderboard
- 🟡 Bonus → claim-cancel (`bonus/bonusClaimCancel`) nahi; Scratch card → `scratch-cards/claim` nahi (reveal / convert-credit hai)
- ❌ Trading Central (`user/trading-central`)

---

## App me hai, docs me nahi (app-only APIs)

Ye endpoints app call karta hai par `client-portal-endpoints.md` me document nahi hain. Backend team se confirm karna chahiye ki ye abhi bhi supported hain.

**Auth / account (legacy ya mobile-specific)**
- `user/send-otp`, `user/verify-otp`, `user/reset-password`, `user/password/email` — purana OTP/reset flow (`api_const.dart:10-13`)
- `user/register-fcm-token` (`api_const.dart:30`)
- `user/settings/delete-account` (`api_const.dart:19`)
- `user/mobile-app-details` (`api_const.dart:135`)
- `user/enabled-modules` (`api_const.dart:139`) — docs ka `user/modules` iska alternate

**Trading**
- `user/mt5accounts/mt5AccountSync` (`api_const.dart:39`)
- `user/trade/cancel-pending-order`, `user/trade/modify-pending-order`, `user/trade/closePositions` (`api_const.dart:43-46`)
- `user/instruments`, `user/instruments/{account}` (`api_const.dart:50,66`)

**Finance**
- `user/transactions` (`api_const.dart:57`), `user/deposit-proof-proxy/{id}` (`api_const.dart:59`)
- `user/utility/currency-list` (`api_const.dart:84`)
- `v1/create-qr-code` (`lib/screens/finance/presentation/pages/cregis_address_screen.dart`)

**Settings / KYC**
- `user/settings/getCountryDropdown`, `getStateDropdown`, `getCityDropdown` (`api_const.dart:70-72`)

**IB**
- `user/ib/approval/requests` (`api_const.dart:111`), `user/ib/transfer/{id}/cancel` (`api_const.dart:118`)

**IB Manager Portal (extra)** — `lib/screens/ibm/data/ibm_api_provider.dart`
- `ibm/client/partner-request`
- `ibm/portal/clients/{id}/accounts`, `clients/{id}/accounts/{acc}/trades`, `clients/{id}/trades`, `clients/{id}/move`
- `ibm/portal/commission-distributions/clients`
- `ibm/portal/links/{id}/stats`, `ibm/portal/marketing/{id}/download`
- `ibm/portal/network/summary`, `ibm/portal/wallet/payout/{id}`

**PAMM** — `lib/services/pmam_service.dart`
- `user/pmam/investor/plans`, `user/pmam/manager/dashboard-stats`, `user/pmam/manager/status`, `user/pmam/managers/datatable`

**Copy Trading** — `api_const.dart:232-235, 246, 273`
- `copytrading/masters` (public list), `user/copytrading/copier/masters/{code}/trade-history`
- `user/copytrading/copier/subscriptions/{id}/pnl-history`, `.../add-capital`

**Promotions**
- `user/demo-contest/my-enrollments` (`api_const.dart:157`)
- `v1/user/scratch-cards/convert-credit-to-balance`, `v1/user/trade-win/past-wins` (`api_const.dart:131,165`)

**Tickets**
- `user/tickets/attachment` (`api_const.dart:147`)

### App-only features (portal guide me nahi)
- Broker selection (Tenax multi-broker): `/tenax-broker-selection`, `/tenax-broker-info`
- Language selector, legal documents / privacy policy screens
- Price alert monitor (local + FCM) — `lib/services/price_alert_monitor_service.dart`
- Tools & Education, Support hub, Partnership program screens
- Copy-trading wallet / deposit / invite-friend sub-flows (`/copy-trading-wallet`, `/copy-trading-invite-friend`)
- IBM extra screens: exports, promotion, payout report, team funding report, wallet

---

## Recommended priority (missing items)

1. **Settings security** — active sessions/devices, 2FA status, login activities, email/notification preferences. Security aur compliance ke liye zaroori, APIs ready hain.
2. **KYC providers** — Sumsub / Shufti / mobile verification. Jis broker par ye enable hain, unke liye app KYC adhoora hai.
3. **Trader-to-Trader transfer** — poora feature missing (5 APIs + OTP flow).
4. **App shell** — notification mark-as-read, active notices, MT5 credentials popup + ack, session check.
5. **Deposit gateways** — UniPayment, dynamic gateway (broker-specific; jahan enable ho).
6. **IB** — network tree + IB details, IB demo contest management, structure options / template rates.
7. **Trading extras** — price alert edit/delete, trade history export, economic calendar, Trading Central, platform download links.
8. **Small gaps** — account nickname, bank method delete + IFSC lookup, bonus claim cancel, scratch-card claim, PAMM/copy-trading plan search, PAMM manager commissions.
9. **Cleanup** — app-only legacy auth endpoints (`send-otp`, `verify-otp`, `reset-password`, `password/email`) aur `getCountryDropdown` family ko docs wali APIs par migrate karne ka decision backend ke saath lo.

Neeche Appendix A me saari common APIs aur Appendix B me saari missing APIs (doc line number ke saath) hain.

---

## Appendix A — Common APIs (docs me hai aur app me use ho rahi hai)

Format: `METHOD path` — doc screen — app file (jahan endpoint define/call hai).


### Auth (Login / Register / OTP / Password) (8)

- `POST /api/user/auth/google/verify-login-otp` — Login — `lib/constants/api_const.dart`
- `POST /api/user/login` — Login — `lib/constants/api_const.dart (+1)`
- `GET /api/user/crm-settings` — Register — `lib/constants/api_const.dart`
- `POST /api/user/register` — Register — `lib/constants/api_const.dart (+1)`
- `POST /api/user/auth/google/check-mobile` — Complete Registration (Google signup) — `lib/constants/api_const.dart`
- `POST /api/user/password/forgot` — Forgot Password — `lib/constants/api_const.dart`
- `POST /api/user/password/verify-otp` — Verify OTP (password reset) — `lib/constants/api_const.dart`
- `POST /api/user/password/reset` — Reset Password — `lib/constants/api_const.dart`

### App shell (every logged-in page) (8)

- `GET /api/user/ib/status` — Left sidebar — `lib/constants/api_const.dart`
- `GET /api/ibm/client/system` — Top header — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/user/dashboard` — Top header — `lib/constants/api_const.dart`
- `GET /api/user/notifications` — Top header — `lib/constants/api_const.dart`
- `GET /api/user/wallet` — Top header — `lib/constants/api_const.dart`
- `POST /api/user/logout` — Top header — `lib/constants/api_const.dart`
- `GET /api/user/enabled-modules` — Router guard (module check before each page) — `lib/constants/api_const.dart`
- `GET /api/user/banners` — Page banners — `lib/screens/ib/view_models/ib_controller.dart (+1)`

### Dashboard (8)

- `GET /api/user/deposit/by-reference` — Dashboard — `lib/constants/api_const.dart`
- `GET /api/user/finance-activity` — Dashboard — `lib/constants/api_const.dart`
- `GET /api/user/mt5accounts/get` — Dashboard — `lib/constants/api_const.dart`
- `GET /api/user/settings/profile` — Dashboard — `lib/constants/api_const.dart`
- `POST /api/user/mt5accounts/changeleverage` — Dashboard — `lib/constants/api_const.dart`
- `POST /api/user/mt5accounts/changepassword` — Dashboard — `lib/constants/api_const.dart`
- `POST /api/user/mt5accounts/changePrimaryAccount` — Dashboard — `lib/constants/api_const.dart`
- `POST /api/user/mt5accounts/setbalance` — Dashboard — `lib/constants/api_const.dart`

### Trading Accounts (3)

- `POST /api/user/mt5accounts/create` — Trading Accounts — `lib/constants/api_const.dart`
- `POST /api/user/mt5accounts/plandetails` — Trading Accounts — `lib/constants/api_const.dart`
- `POST /api/user/mt5accounts/resetinvestorpassword` — Trading Accounts — `lib/constants/api_const.dart`

### Trading Terminal (10)

- `POST /api/user/trade/new-order` — Trading Terminal (launcher) — `lib/constants/api_const.dart`
- `GET /api/user/price-alerts` — Web Trader (terminal) — `lib/constants/api_const.dart`
- `GET /api/user/trade/marketwatch` — Web Trader (terminal) — `lib/constants/api_const.dart`
- `GET /api/user/trade/tradehistory` — Web Trader (terminal) — `lib/constants/api_const.dart`
- `POST /api/user/price-alerts` — Web Trader (terminal) — `lib/constants/api_const.dart`
- `POST /api/user/trade/closePendingOrder` — Web Trader (terminal) — `lib/constants/api_const.dart`
- `POST /api/user/trade/closePositionByPositionId` — Web Trader (terminal) — `lib/constants/api_const.dart`
- `POST /api/user/trade/marketwatch` — Web Trader (terminal) — `lib/constants/api_const.dart`
- `POST /api/user/trade/update-pending-order-tp-sl` — Web Trader (terminal) — `lib/constants/api_const.dart`
- `POST /api/user/trade/update-tp-sl` — Web Trader (terminal) — `lib/constants/api_const.dart`

### Deposit (5)

- `GET /api/user/deposit` — Deposit (methods) — `lib/constants/api_const.dart`
- `GET /api/user/deposit/{methodSlug}` — Deposit request / history — `lib/screens/finance/data/repositories/finance_repository_impl.dart`
- `GET /api/user/regulation` — Deposit request / history — `lib/constants/api_const.dart`
- `POST /api/user/deposit/cregis` — Deposit request / history — `lib/constants/api_const.dart`
- `POST /api/user/deposit/depositrequest` — Deposit request / history — `lib/constants/api_const.dart`

### Withdrawal (5)

- `GET /api/user/withdrawal` — Withdrawal (methods) — `lib/constants/api_const.dart (+1)`
- `GET /api/user/withdrawal/sendOTP` — Withdrawal request / history — `lib/constants/api_const.dart`
- `GET /api/user/withdrawal/withdrawal-method/{methodId}` — Withdrawal request / history — `lib/constants/api_const.dart (+1)`
- `POST /api/user/withdrawal/checkbalance` — Withdrawal request / history — `lib/constants/api_const.dart`
- `POST /api/user/withdrawal/withdrawalrequest` — Withdrawal request / history — `lib/constants/api_const.dart`

### Internal Transfer (3)

- `GET /api/user/internaltransfer` — Internal Transfer — `lib/constants/api_const.dart`
- `GET /api/user/internaltransfer/history` — Internal Transfer — `lib/constants/api_const.dart`
- `POST /api/user/internaltransfer/request` — Internal Transfer — `lib/constants/api_const.dart`

### IB Dashboard (classic IB) (28)

- `GET /api/ibm/portal/dashboard` — IB Dashboard / IB Application — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/user/ib/dashboard` — IB Dashboard / IB Application — `lib/constants/api_const.dart`
- `GET /api/user/ib/stats` — IB Dashboard / IB Application — `lib/constants/api_const.dart`
- `POST /api/user/ib/application` — IB Dashboard / IB Application — `lib/constants/api_const.dart`
- `POST /api/user/ib/track-visit` — IB Dashboard / IB Application — `lib/constants/api_const.dart`
- `DELETE /api/user/ib/commission-groups/{id}` — My Structure — `lib/screens/ib/data/datasources/ib_remote_data_source.dart`
- `GET /api/user/ib/progressive-stats` — My Structure — `lib/screens/ib/view_models/ib_controller.dart`
- `GET /api/user/ib/structure` — My Structure — `lib/constants/api_const.dart`
- `GET /api/user/ib/commission-groups` — Sub IB Structure — `lib/constants/api_const.dart`
- `GET /api/user/ib/commission-groups/{id}` — Sub IB Structure — `lib/screens/ib/data/datasources/ib_remote_data_source.dart`
- `POST /api/user/ib/manage` — Sub IB Structure — `lib/constants/api_const.dart`
- `GET /api/user/ib/clients` — My Network (clients) — `lib/constants/api_const.dart`
- `GET /api/user/ib/sub-ib-stats/{subIBId}` — My Network (clients) — `lib/constants/api_const.dart (+1)`
- `GET /api/user/ib/sub-ib-structure/{subIBId}` — My Network (clients) — `lib/constants/api_const.dart (+1)`
- `GET /api/user/ib/sub-ib-sub-ibs/{subIBId}` — My Network (clients) — `lib/constants/api_const.dart (+1)`
- `GET /api/user/ib/sub-ibs` — My Network (clients) — `lib/constants/api_const.dart`
- `GET /api/user/ib/trade-history` — My Network (clients) — `lib/constants/api_const.dart`
- `GET /api/user/ib/ib-request-list` — Sub IB Approval — `lib/constants/api_const.dart`
- `POST /api/user/ib/update-status/{id}` — Sub IB Approval — `lib/constants/api_const.dart (+1)`
- `GET /api/user/ib/transfer/clients/search` — Transfer Commission — `lib/constants/api_const.dart`
- `GET /api/user/ib/transfer/create` — Transfer Commission — `lib/constants/api_const.dart`
- `POST /api/user/ib/transfer/store` — Transfer Commission — `lib/constants/api_const.dart`
- `GET /api/user/ib/transfer/history` — Transfer Commission History — `lib/constants/api_const.dart`
- `POST /api/user/ib/transfer/{id}/cancel` — Transfer Commission History — `lib/screens/ib/data/datasources/ib_remote_data_source.dart`
- `GET /api/v1/user/trade-win/products` — IB Trade & Win — `lib/constants/api_const.dart`
- `GET /api/v1/user/trade-win/saved-addresses` — IB Trade & Win — `lib/constants/api_const.dart`
- `POST /api/v1/user/trade-win/claim` — IB Trade & Win — `lib/constants/api_const.dart`
- `GET /api/user/demo-contest/{contestId}/leaderboard` — IB Demo Contest (list/create/edit/view) — `lib/constants/api_const.dart`

### IB Manager Portal (48)

- `GET /api/ibm/portal/dashboard/activity` — Dashboard — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network` — Dashboard — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/clients` — My Clients — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/clients/network-tree` — My Clients — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network/{id}` — My Clients — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network/{id}/node` — My Clients — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network/{id}/wallet` — My Clients — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network/tree-summary` — My Clients — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/clients/{id}` — Person detail (client / sub-IB) — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network/{id}/links` — Person detail (client / sub-IB) — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network/{id}/plan` — Person detail (client / sub-IB) — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network/{id}/symbols` — Person detail (client / sub-IB) — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/partner-plans` — Person detail (client / sub-IB) — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/wallet` — Person detail (client / sub-IB) — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/partner-plans/{id}/assign` — Person detail (client / sub-IB) — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/requests` — Sub-IB Requests — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/requests/{requestId}/approve` — Sub-IB Requests — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/requests/{requestId}/reject` — Sub-IB Requests — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/network/performance` — Sub-IB Performance (from dashboard "View all") — `lib/screens/ibm/data/ibm_api_provider.dart`
- `DELETE /api/ibm/portal/partner-plans/{id}` — Commission Plans — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/partner-plans/{id}` — Commission Plans — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/partner-plans/sub-ibs` — Commission Plans — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/partner-plans/template` — Commission Plans — `lib/screens/ibm/data/ibm_api_provider.dart`
- `PATCH /api/ibm/portal/partner-plans/{id}/rename` — Commission Plans — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/partner-plans` — Commission Plans — `lib/screens/ibm/data/ibm_api_provider.dart`
- `PUT /api/ibm/portal/partner-plans/{id}` — Commission Plans — `lib/screens/ibm/data/ibm_api_provider.dart`
- `DELETE /api/ibm/portal/commission-distributions/{id}` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/commission-distributions` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/commission-distributions/create` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/exports/{id}` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/exports/{id}/download` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/plan` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/wallet/transactions` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/commission-distributions` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/exports` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/wallet/withdraw` — My Commission — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/client-funding` — My Team Deposit / My Team Withdrawal — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/commission-report` — IB Commission report — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/payout-report` — IB Withdraw report — `lib/screens/ibm/data/ibm_api_provider.dart`
- `DELETE /api/ibm/portal/links/{id}` — Referral Links — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/links` — Referral Links — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/links/{id}/clients` — Referral Links — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/plan/groups` — Referral Links — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/links` — Referral Links — `lib/screens/ibm/data/ibm_api_provider.dart`
- `PUT /api/ibm/portal/links/{id}` — Referral Links — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/marketing` — Marketing Material — `lib/screens/ibm/data/ibm_api_provider.dart`
- `GET /api/ibm/portal/client-visibility` — Settings — `lib/screens/ibm/data/ibm_api_provider.dart`
- `POST /api/ibm/portal/client-visibility` — Settings — `lib/screens/ibm/data/ibm_api_provider.dart`

### PAMM (27)

- `GET /api/user/pmam/investor/eligible-accounts` — Explore Fund Managers — `lib/services/pmam_service.dart:140`
- `GET /api/user/pmam/investor/enrollments` — Explore Fund Managers — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/investor/my-fund-entries` — Explore Fund Managers — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/investor/my-open-allocations` — Explore Fund Managers — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/investor/pnl-history` — Explore Fund Managers — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/managers/{code}/trades` — Explore Fund Managers — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/investor/deposit` — Explore Fund Managers — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/investor/request-join` — Explore Fund Managers — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/investor/unsubscribe/{id}` — Explore Fund Managers — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/managers/{code}` — Manager public profile — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/managers/{code}/open-positions` — Manager public profile — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/manager/apply` — Become a manager (apply) — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/manager/dashboard-overview` — Manager dashboard — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/manager/plans` — Manager dashboard — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/manager/plans` — Manager — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/manager/plans/{planId}/inactivate` — Manager — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/manager/plans/{planId}/pause` — Manager — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/manager/plans/{planId}/resume` — Manager — `lib/services/pmam_service.dart`
- `PUT /api/user/pmam/manager/plans/{planId}` — Manager — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/manager/plans/{planId}/allocations` — Manager — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/manager/plans/{planId}/detail` — Manager — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/manager/plans/{planId}/investors` — Manager — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/manager/plans/{planId}/investor-requests` — Manager — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/manager/investor-requests/{id}/approve` — Manager — `lib/services/pmam_service.dart`
- `POST /api/user/pmam/manager/investor-requests/{id}/reject` — Manager — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/manager/investors` — Manager — `lib/services/pmam_service.dart`
- `GET /api/user/pmam/manager/investors/{investorId}/detail` — Manager — `lib/services/pmam_service.dart`

### Copy Trading (29)

- `GET /api/copytrading/masters/search` — Leaderboard — `lib/constants/api_const.dart`
- `GET /api/copytrading/plans` — Leaderboard — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/copier/eligible-accounts` — Leaderboard — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/copier/masters/{code}` — Leaderboard — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/copier/subscriptions` — Leaderboard — `lib/constants/api_const.dart`
- `POST /api/user/copytrading/copier/subscribe` — Leaderboard — `lib/constants/api_const.dart`
- `GET /api/copytrading/masters/{code}` — Master profile — `lib/constants/api_const.dart`
- `POST /api/user/copytrading/copier/subscriptions/{id}/pause` — My Investments (copier dashboard) — `lib/constants/api_const.dart (+1)`
- `POST /api/user/copytrading/copier/subscriptions/{id}/resume` — My Investments (copier dashboard) — `lib/constants/api_const.dart (+1)`
- `POST /api/user/copytrading/copier/subscriptions/{id}/stop` — My Investments (copier dashboard) — `lib/constants/api_const.dart (+1)`
- `PUT /api/user/copytrading/copier/subscriptions/{id}/update` — My Investments (copier dashboard) — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/copier/subscriptions/{id}/commission-history` — Subscription detail — `lib/controllers/copy_trading/subscription_detail_controller.dart`
- `GET /api/user/copytrading/copier/subscriptions/{id}/detail` — Subscription detail — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/copier/subscriptions/{id}/trades` — Subscription detail — `lib/constants/api_const.dart:225`
- `GET /api/user/copytrading/master/dashboard-overview` — Master dashboard — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/master/status` — Master dashboard — `lib/constants/api_const.dart`
- `POST /api/user/copytrading/master/apply` — Master dashboard — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/master/dashboard-stats` — Master dashboard (legacy) — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/master/plans` — Master dashboard (legacy) — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/master/plans/{id}/open-positions` — Master dashboard (legacy) — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/master/plans/{id}` — Master — `lib/constants/api_const.dart (+2)`
- `POST /api/user/copytrading/master/plans` — Master — `lib/constants/api_const.dart`
- `POST /api/user/copytrading/master/plans/{id}/pause` — Master — `lib/constants/api_const.dart (+2)`
- `POST /api/user/copytrading/master/plans/{id}/resume` — Master — `lib/constants/api_const.dart (+2)`
- `PUT /api/user/copytrading/master/plans/{id}` — Master — `lib/constants/api_const.dart (+2)`
- `POST /api/user/copytrading/master/plans/{id}/inactivate` — Master — `lib/controllers/copy_trading/copy_trading_master_dashboard_controller.dart (+1)`
- `GET /api/user/copytrading/master/copiers` — Master — `lib/constants/api_const.dart (+1)`
- `GET /api/user/copytrading/master/copiers/{copierId}/subscription-history` — Master — `lib/constants/api_const.dart`
- `GET /api/user/copytrading/master/settlements` — Master — `lib/constants/api_const.dart`

### Tickets (6)

- `GET /api/user/tickets` — Tickets list — `lib/constants/api_const.dart`
- `GET /api/user/tickets/departments` — Tickets list — `lib/constants/api_const.dart`
- `POST /api/user/tickets` — Tickets list — `lib/constants/api_const.dart`
- `POST /api/user/tickets/{ticketId}/close` — Tickets list — `lib/constants/api_const.dart`
- `GET /api/user/tickets/{ticketId}` — Ticket detail — `lib/constants/api_const.dart`
- `POST /api/user/tickets/{ticketId}/reply` — Ticket detail — `lib/constants/api_const.dart`

### Settings (11)

- `GET /api/user/kyc` — Profile — `lib/constants/api_const.dart`
- `POST /api/user/kyc/profile` — Profile — `lib/constants/api_const.dart`
- `POST /api/user/settings/change-password` — Security (password, 2FA, devices) — `lib/constants/api_const.dart`
- `POST /api/user/settings/google-otp/disable` — Security (password, 2FA, devices) — `lib/constants/api_const.dart`
- `POST /api/user/settings/google-otp/generate` — Security (password, 2FA, devices) — `lib/constants/api_const.dart`
- `POST /api/user/settings/google-otp/verify` — Security (password, 2FA, devices) — `lib/constants/api_const.dart`
- `POST /api/user/kyc/documents/upload` — KYC — `lib/constants/api_const.dart`
- `POST /api/user/kyc/submit-unified` — KYC — `lib/constants/api_const.dart`
- `POST /api/user/regulation` — KYC — `lib/constants/api_const.dart`
- `GET /api/user/withdrawal/getUserWithdrawalMethods` — Bank / withdrawal accounts — `lib/constants/api_const.dart`
- `POST /api/user/withdrawal` — Bank / withdrawal accounts — `lib/constants/api_const.dart (+1)`

### Promotions & extras (header / dashboard links) (16)

- `GET /api/user/bonus` — Bonus — `lib/constants/api_const.dart`
- `GET /api/user/bonus/bonusClaimList` — Bonus — `lib/constants/api_const.dart`
- `POST /api/user/bonus/bonusClaim` — Bonus — `lib/constants/api_const.dart`
- `GET /api/v1/user/scratch-cards` — Scratch card promotion — `lib/constants/api_const.dart`
- `GET /api/v1/user/scratch-cards/leaderboard` — Scratch card promotion — `lib/constants/api_const.dart`
- `POST /api/v1/user/scratch-cards/reveal` — Scratch card promotion — `lib/constants/api_const.dart`
- `GET /api/user/demo-contest/{contestId}/rule-violations` — Demo Contest list — `lib/constants/api_const.dart`
- `GET /api/user/demo-contest/{contestId}/steps` — Demo Contest list — `lib/constants/api_const.dart`
- `GET /api/user/demo-contest/{contestId}/terms` — Demo Contest list — `lib/constants/api_const.dart`
- `GET /api/user/demo-contest/{contestId}/trading-history` — Demo Contest list — `lib/constants/api_const.dart`
- `GET /api/user/demo-contest/contests` — Demo Contest list — `lib/constants/api_const.dart`
- `GET /api/user/demo-contest/my-stats` — Demo Contest list — `lib/constants/api_const.dart`
- `POST /api/user/demo-contest/{contestId}/enroll` — Demo Contest list — `lib/constants/api_const.dart`
- `POST /api/user/demo-contest/{contestId}/enroll-preview` — Demo Contest list — `lib/constants/api_const.dart`
- `POST /api/user/demo-contest/claim` — Demo Contest list — `lib/constants/api_const.dart`
- `POST /api/user/demo-contest/step/{stepId}/click` — Demo Contest list — `lib/constants/api_const.dart`


## Appendix B — Docs me hai, app me nahi (raw list with doc line)

Line number = `client-portal-endpoints.md` me us API ka section (poora request/response wahan hai).


### Auth (Login / Register / OTP / Password) (8)

- `GET /api/user/auth/google/redirect` — Login — `client-portal-endpoints.md:49`
- `GET /api/ibm/r/{code}` — Register — `client-portal-endpoints.md:326`
- `GET /api/user` — Register — `client-portal-endpoints.md:372`
- `GET /api/user/json` — Register — `client-portal-endpoints.md:600`
- `POST /api/user/ib/track-sponsor-visit` — Register — `client-portal-endpoints.md:632`
- `POST /api/user/auth/google/complete-registration` — Complete Registration (Google signup) — `client-portal-endpoints.md:870`
- `POST /api/user/password/reset-token` — Reset Password — `client-portal-endpoints.md:1133`
- `GET /api/user/auth/google/callback` — Google OAuth callback — `client-portal-endpoints.md:1186`

### App shell (every logged-in page) (9)

- `GET /api/user/live-chat` — App root — `client-portal-endpoints.md:1236`
- `GET /api/user/notices/active` — App root — `client-portal-endpoints.md:1302`
- `GET /api/user/session/check` — App root — `client-portal-endpoints.md:1350`
- `GET /api/user/notifications/markasread` — Top header — `client-portal-endpoints.md:1786`
- `GET /api/user/notifications/markasread/{id}` — Top header — `client-portal-endpoints.md:1842`
- `GET /api/user/notifications/mt5-credentials/{id}` — Top header — `client-portal-endpoints.md:1897`
- `POST /api/user/notifications/mt5-credentials/{id}/ack` — Top header — `client-portal-endpoints.md:2095`
- `POST /api/user/current-page` — Router guard (module check before each page) — `client-portal-endpoints.md:2232`
- `POST /api/user/banners/track` — Page banners — `client-portal-endpoints.md:2342`

### Dashboard (3)

- `GET /api/user/prop-coupons` — Dashboard — `client-portal-endpoints.md:2817`
- `POST /api/user/mt5accounts/setnickname` — Dashboard — `client-portal-endpoints.md:3327`
- `POST /api/user/price-alerts/update-fcm-token` — Dashboard — `client-portal-endpoints.md:3388`

### Trading Terminal (9)

- `DELETE /api/user/trade/chart-state/{param}` — Trading Terminal (launcher) — `client-portal-endpoints.md:3704`
- `DELETE /api/user/price-alerts/{id}` — Web Trader (terminal) — `client-portal-endpoints.md:3852`
- `GET /api/user/economic-calendar` — Web Trader (terminal) — `client-portal-endpoints.md:3911`
- `GET /api/user/trade/chart-store/{param}` — Web Trader (terminal) — `client-portal-endpoints.md:4124`
- `GET /api/user/trade/tradehistory/export` — Web Trader (terminal) — `client-portal-endpoints.md:4321`
- `GET /api/user/tradingaccounts/sync` — Web Trader (terminal) — `client-portal-endpoints.md:4370`
- `POST /api/user/trade/chart-state` — Web Trader (terminal) — `client-portal-endpoints.md:4547`
- `POST /api/user/trade/chart-store` — Web Trader (terminal) — `client-portal-endpoints.md:4579`
- `PUT /api/user/price-alerts/{id}` — Web Trader (terminal) — `client-portal-endpoints.md:5089`

### Deposit (2)

- `POST /api/user/deposit/dynamic/{gatewaySlug}` — Deposit request / history — `client-portal-endpoints.md:5971`
- `POST /api/user/deposit/unipayment` — Deposit request / history — `client-portal-endpoints.md:6097`

### Internal Transfer (5)

- `GET /api/user/trader-transfer/config` — Trader to Trader Transfer — `client-portal-endpoints.md:7197`
- `GET /api/user/trader-transfer/history` — Trader to Trader Transfer — `client-portal-endpoints.md:7257`
- `POST /api/user/trader-transfer/send-otp` — Trader to Trader Transfer — `client-portal-endpoints.md:7330`
- `POST /api/user/trader-transfer/submit` — Trader to Trader Transfer — `client-portal-endpoints.md:7403`
- `POST /api/user/trader-transfer/verify-recipient` — Trader to Trader Transfer — `client-portal-endpoints.md:7494`

### IB Dashboard (classic IB) (14)

- `GET /api/user/ib/activities` — IB Dashboard / IB Application — `client-portal-endpoints.md:7755`
- `GET /api/user/ib/get-template-rates/{templateId}` — Sub IB Structure — `client-portal-endpoints.md:8916`
- `GET /api/user/ib/get-ib-details/{userSlug}` — My Network (clients) — `client-portal-endpoints.md:9178`
- `GET /api/user/ib/tree-structure` — My Network (clients) — `client-portal-endpoints.md:9792`
- `GET /api/user/ib/get-structure-options/{id}` — Sub IB Approval — `client-portal-endpoints.md:13358`
- `GET /api/ib/demo-contest/{id}/enrollments` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:14312`
- `GET /api/ib/demo-contest/instruments` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:14521`
- `GET /api/ib/demo-contest/my-contests` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:14604`
- `POST /api/ib/demo-contest/{id}/add-prize-fund` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:14838`
- `POST /api/ib/demo-contest/{id}/cancel` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:14923`
- `POST /api/ib/demo-contest/{id}/update` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:14980`
- `POST /api/ib/demo-contest/enrollment/{id}/approve` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:15165`
- `POST /api/ib/demo-contest/enrollment/{id}/reject` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:15233`
- `POST /api/ib/demo-contest/store` — IB Demo Contest (list/create/edit/view) — `client-portal-endpoints.md:15290`

### PAMM (5)

- `GET /api/user/pmam/managers/search` — Explore Fund Managers — `client-portal-endpoints.md:21414`
- `GET /api/user/pmam/plans/search` — Explore Fund Managers — `client-portal-endpoints.md:21464`
- `POST /api/user/pmam/plans/datatable` — Explore Fund Managers — `client-portal-endpoints.md:21738`
- `GET /api/user/pmam/manager/eligible-accounts` — Manager dashboard — `client-portal-endpoints.md:22583`
- `GET /api/user/pmam/manager/commissions` — Manager — `client-portal-endpoints.md:23969`

### Copy Trading (1)

- `GET /api/copytrading/plans/search` — Leaderboard — `client-portal-endpoints.md:24291`

### Platforms (1)

- `GET /api/user/platform-links` — Platforms (download links) — `client-portal-endpoints.md:28403`

### Settings (24)

- `DELETE /api/user/robot-trading-api-key` — Security (password, 2FA, devices) — `client-portal-endpoints.md:29222`
- `DELETE /api/user/sessions/{id}` — Security (password, 2FA, devices) — `client-portal-endpoints.md:29278`
- `GET /api/user/robot-trading-status` — Security (password, 2FA, devices) — `client-portal-endpoints.md:29335`
- `GET /api/user/sessions` — Security (password, 2FA, devices) — `client-portal-endpoints.md:29401`
- `GET /api/user/settings/google-otp/status` — Security (password, 2FA, devices) — `client-portal-endpoints.md:29489`
- `POST /api/user/robot-trading-api-key` — Security (password, 2FA, devices) — `client-portal-endpoints.md:29556`
- `POST /api/user/robot-trading-api-key/regenerate` — Security (password, 2FA, devices) — `client-portal-endpoints.md:29623`
- `GET /api/user/kyc/shufti/status` — KYC — `client-portal-endpoints.md:29987`
- `POST /api/user/kyc/shufti/start` — KYC — `client-portal-endpoints.md:30137`
- `POST /api/user/kyc/sumsub/refresh` — KYC — `client-portal-endpoints.md:30319`
- `POST /api/user/kyc/sumsub/token` — KYC — `client-portal-endpoints.md:30383`
- `POST /api/user/mobile-verification/send` — KYC — `client-portal-endpoints.md:30451`
- `POST /api/user/mobile-verification/verify` — KYC — `client-portal-endpoints.md:30517`
- `GET /api/user/kyc-image-proxy/{documentId}` — Documents — `client-portal-endpoints.md:30660`
- `POST /api/user/kyc/documents/finalize-chunked` — Documents — `client-portal-endpoints.md:30710`
- `POST /api/user/kyc/documents/upload-chunk` — Documents — `client-portal-endpoints.md:30788`
- `DELETE /api/user/withdrawal/delete/{id}` — Bank / withdrawal accounts — `client-portal-endpoints.md:30872`
- `POST /api/user/utility/ifsc-code` — Bank / withdrawal accounts — `client-portal-endpoints.md:31095`
- `GET /api/user/image-proxy/{id}` — Withdrawal details — `client-portal-endpoints.md:31326`
- `GET /api/user/settings/activitylog` — Login activities — `client-portal-endpoints.md:31378`
- `GET /api/user/email-preferences` — Notification preferences — `client-portal-endpoints.md:31484`
- `POST /api/user/email-preferences` — Notification preferences — `client-portal-endpoints.md:31550`
- `GET /api/email/unsubscribe/resolve` — Email unsubscribe — `client-portal-endpoints.md:31623`
- `POST /api/email/unsubscribe` — Email unsubscribe — `client-portal-endpoints.md:31693`

### Promotions & extras (header / dashboard links) (3)

- `POST /api/user/bonus/bonusClaimCancel` — Bonus — `client-portal-endpoints.md:32853`
- `POST /api/v1/user/scratch-cards/claim` — Scratch card promotion — `client-portal-endpoints.md:33216`
- `GET /api/user/trading-central` — Trading Central — `client-portal-endpoints.md:34910`

