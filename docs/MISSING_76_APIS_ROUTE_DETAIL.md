# Baaki 76 APIs — route detail + mobile app me call hogi ya nahi

Generated 2026-10-27. Source: `~/Downloads/client-portal-endpoints.md` (har endpoint ka full request/response wahan hai).
Ye wo endpoints hain jo web client portal use karta hai lekin white-label app (Android / iOS) abhi call nahi karti.

**Mobile developers ko 58 APIs use karni hain, 13 optional hain, aur 5 ki zaroorat nahi hai.**

## Decision ka matlab

- **Haan — Phase 1** — abhi lagao, pehle karna hai.
- **Haan — Phase 2** — Phase 1 ke baad lagao.
- **Haan, agar broker ke paas feature on hai** — sirf tab lagao jab broker ke paas ye feature on ho.
- **Optional — Phase 3** — abhi zaroori nahi; demand aaye tab lagao.
- **Nahi — mat lagao** — app ke paas iska kaam pehle se hai, ya ye web-only hai.

## Summary

- Haan — Phase 1: **17**
- Haan — Phase 2: **26**
- Haan, agar broker ke paas feature on hai: **15**
- Optional — Phase 3: **13**
- Nahi — mat lagao: **5**
- Total: **76**

## Quick list (module-wise)

| # | Module | Method | Endpoint | Web route | App me call? |
|---|---|---|---|---|---|
| 1 | Trader-to-Trader Transfer | GET | `/api/user/trader-transfer/config` | `/trader-transfer` | Haan — Phase 1 |
| 2 | Trader-to-Trader Transfer | POST | `/api/user/trader-transfer/verify-recipient` | `/trader-transfer` | Haan — Phase 1 |
| 3 | Trader-to-Trader Transfer | POST | `/api/user/trader-transfer/send-otp` | `/trader-transfer` | Haan — Phase 1 |
| 4 | Trader-to-Trader Transfer | POST | `/api/user/trader-transfer/submit` | `/trader-transfer` | Haan — Phase 1 |
| 5 | Trader-to-Trader Transfer | GET | `/api/user/trader-transfer/history` | `/trader-transfer` | Haan — Phase 1 |
| 6 | Deposit | POST | `/api/user/deposit/dynamic/{gatewaySlug}` | `/deposit-request` | Haan — Phase 1 |
| 7 | Deposit | POST | `/api/user/deposit/unipayment` | `/deposit-request` | Haan, agar broker ke paas feature on hai |
| 8 | App shell | GET | `/api/user/live-chat` | `(all)` | Haan — Phase 1 |
| 9 | App shell | GET | `/api/user/notices/active` | `(all)` | Haan — Phase 1 |
| 10 | App shell | GET | `/api/user/session/check` | `(all)` | Haan — Phase 2 |
| 11 | App shell | GET | `/api/user/notifications/markasread` | `(all)` | Haan — Phase 1 |
| 12 | App shell | GET | `/api/user/notifications/markasread/{id}` | `(all)` | Haan — Phase 1 |
| 13 | App shell | GET | `/api/user/notifications/mt5-credentials/{id}` | `(all)` | Haan — Phase 1 |
| 14 | App shell | POST | `/api/user/notifications/mt5-credentials/{id}/ack` | `(all)` | Haan — Phase 1 |
| 15 | App shell | POST | `/api/user/banners/track` | `(all)` | Optional — Phase 3 |
| 16 | Notifications | GET | `/api/user/notifications/all` | `/notifications` | Haan — Phase 1 |
| 17 | Auth | POST | `/api/user/auth/google/complete-registration` | `/complete-registration` | Haan — Phase 1 |
| 18 | Auth | GET | `/api/ibm/r/{code}` | `/register` | Haan — Phase 2 |
| 19 | Auth | POST | `/api/user/ib/track-sponsor-visit` | `/register` | Haan — Phase 2 |
| 20 | Auth | GET | `/api/user` | `/register` | Nahi — mat lagao |
| 21 | Auth | GET | `/api/user/json` | `/register` | Nahi — mat lagao |
| 22 | Auth | POST | `/api/user/password/reset-token` | `/reset-password` | Nahi — mat lagao |
| 23 | Dashboard / Accounts | POST | `/api/user/mt5accounts/setnickname` | `/dashboard` | Haan — Phase 2 |
| 24 | Dashboard / Accounts | GET | `/api/user/prop-coupons` | `/dashboard` | Optional — Phase 3 |
| 25 | Trading | PUT | `/api/user/price-alerts/{id}` | `/trading` | Haan — Phase 2 |
| 26 | Trading | DELETE | `/api/user/price-alerts/{id}` | `/trading` | Haan — Phase 2 |
| 27 | Trading | GET | `/api/user/economic-calendar` | `/trading` | Optional — Phase 3 |
| 28 | Trading | GET | `/api/user/trade/tradehistory/export` | `/trading` | Optional — Phase 3 |
| 29 | Trading | GET | `/api/user/modules` | `/trading` | Nahi — mat lagao |
| 30 | Copy Trading | GET | `/api/copytrading/plans/search` | `/copy-trade` | Haan — Phase 2 |
| 31 | PAMM | GET | `/api/user/pmam/managers` | `/pmam/managers` | Haan — Phase 2 |
| 32 | PAMM | GET | `/api/user/pmam/managers/search` | `/pmam/investor/explore` | Haan — Phase 2 |
| 33 | PAMM | GET | `/api/user/pmam/plans/search` | `/pmam/investor/explore` | Haan — Phase 2 |
| 34 | PAMM | POST | `/api/user/pmam/plans/datatable` | `/pmam/investor/explore` | Nahi — mat lagao |
| 35 | PAMM | GET | `/api/user/pmam/manager/eligible-accounts` | `/pmam/manager/dashboard` | Haan — Phase 2 |
| 36 | PAMM | GET | `/api/user/pmam/manager/commissions` | `/pmam/manager/commissions` | Haan — Phase 2 |
| 37 | IB (classic) | GET | `/api/user/ib/activities` | `/ib-dashboard` | Haan — Phase 2 |
| 38 | IB (classic) | GET | `/api/user/ib/tree-structure` | `/my-client` | Haan — Phase 2 |
| 39 | IB (classic) | GET | `/api/user/ib/get-ib-details/{userSlug}` | `/my-client` | Haan — Phase 2 |
| 40 | IB (classic) | GET | `/api/user/ib/get-template-rates/{templateId}` | `/sub-ib-structure/create` | Haan — Phase 2 |
| 41 | IB (classic) | GET | `/api/user/ib/get-structure-options/{id}` | `/sub-ib-approval` | Haan — Phase 2 |
| 42 | IB Demo Contest (host) | GET | `/api/ib/demo-contest/my-contests` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 43 | IB Demo Contest (host) | GET | `/api/ib/demo-contest/instruments` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 44 | IB Demo Contest (host) | POST | `/api/ib/demo-contest/store` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 45 | IB Demo Contest (host) | POST | `/api/ib/demo-contest/{id}/update` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 46 | IB Demo Contest (host) | POST | `/api/ib/demo-contest/{id}/cancel` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 47 | IB Demo Contest (host) | POST | `/api/ib/demo-contest/{id}/add-prize-fund` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 48 | IB Demo Contest (host) | GET | `/api/ib/demo-contest/{id}/enrollments` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 49 | IB Demo Contest (host) | POST | `/api/ib/demo-contest/enrollment/{id}/approve` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 50 | IB Demo Contest (host) | POST | `/api/ib/demo-contest/enrollment/{id}/reject` | `/ib-contest` | Haan, agar broker ke paas feature on hai |
| 51 | Promotions | POST | `/api/user/bonus/bonusClaimCancel` | `/bonus` | Haan — Phase 2 |
| 52 | Promotions | POST | `/api/v1/user/scratch-cards/claim` | `/promotion` | Haan — Phase 2 |
| 53 | Promotions | GET | `/api/user/trading-central` | `/trading-central/:page?` | Optional — Phase 3 |
| 54 | Platforms | GET | `/api/user/platform-links` | `/platform` | Haan — Phase 2 |
| 55 | Settings — Security | GET | `/api/user/sessions` | `/settings-security` | Haan — Phase 1 |
| 56 | Settings — Security | DELETE | `/api/user/sessions/{id}` | `/settings-security` | Haan — Phase 1 |
| 57 | Settings — Security | GET | `/api/user/settings/google-otp/status` | `/settings-security` | Haan — Phase 1 |
| 58 | Settings — Security | GET | `/api/user/robot-trading-status` | `/settings-security` | Optional — Phase 3 |
| 59 | Settings — Security | POST | `/api/user/robot-trading-api-key` | `/settings-security` | Optional — Phase 3 |
| 60 | Settings — Security | POST | `/api/user/robot-trading-api-key/regenerate` | `/settings-security` | Optional — Phase 3 |
| 61 | Settings — Security | DELETE | `/api/user/robot-trading-api-key` | `/settings-security` | Optional — Phase 3 |
| 62 | Settings | GET | `/api/user/settings/activitylog` | `/settings-activities` | Haan — Phase 2 |
| 63 | Settings | GET | `/api/user/email-preferences` | `/settings-notifications` | Optional — Phase 3 |
| 64 | Settings | POST | `/api/user/email-preferences` | `/settings-notifications` | Optional — Phase 3 |
| 65 | Settings — Bank | DELETE | `/api/user/withdrawal/delete/{id}` | `/settings-bank-accounts` | Haan — Phase 2 |
| 66 | Settings — Bank | POST | `/api/user/utility/ifsc-code` | `/settings-bank-accounts` | Haan, agar broker ke paas feature on hai |
| 67 | Settings — Bank | GET | `/api/user/image-proxy/{id}` | `/settings-withdrawal-details/:id` | Haan — Phase 2 |
| 68 | KYC | POST | `/api/user/kyc/sumsub/token` | `/kyc` | Haan, agar broker ke paas feature on hai |
| 69 | KYC | POST | `/api/user/kyc/sumsub/refresh` | `/kyc` | Haan, agar broker ke paas feature on hai |
| 70 | KYC | POST | `/api/user/kyc/shufti/start` | `/kyc` | Haan, agar broker ke paas feature on hai |
| 71 | KYC | GET | `/api/user/kyc/shufti/status` | `/kyc` | Haan, agar broker ke paas feature on hai |
| 72 | KYC | POST | `/api/user/mobile-verification/send` | `/kyc` | Haan — Phase 2 |
| 73 | KYC | POST | `/api/user/mobile-verification/verify` | `/kyc` | Haan — Phase 2 |
| 74 | KYC — Documents | GET | `/api/user/kyc-image-proxy/{documentId}` | `/settings-documents` | Haan — Phase 2 |
| 75 | KYC — Documents | POST | `/api/user/kyc/documents/upload-chunk` | `/settings-documents` | Optional — Phase 3 |
| 76 | KYC — Documents | POST | `/api/user/kyc/documents/finalize-chunked` | `/settings-documents` | Optional — Phase 3 |

## Backend team se sawaal

1. `GET /api/user`, `GET /api/user/json`, `POST /api/user/pmam/plans/datatable` — inke routes check nahi kiye. App inhe nahi lagayegi kyunki iski jagah APIs pehle se hain; agar inme koi aisa data hai jo baaki APIs me nahi milta to batao.
2. `deposit/dynamic/{gatewaySlug}` aur `deposit/unipayment` ka success/cancel — mobile ke liye return URL / deep link kya hoga (web `/deposit/unipayment/success` page par jaata hai)?
3. Sumsub ke liye native SDK lagega — kya Shufti/Sumsub ka web URL flow (WebView) bhi supported hai?
4. Price alerts: server-side alert trigger hone par push FCM se aayega? Tab app local alerts hata kar server alerts use karega.
5. `notifications/mt5-credentials/{id}` — push notification payload me ye `id` aayega taaki app tap par popup khol sake?

## Har API ka detail

### Trader-to-Trader Transfer

#### 1. GET `/api/user/trader-transfer/config`

- **App me call hogi?** Haan — Phase 1 — Screen khulte hi: feature enabled hai ya nahi, limits, fees.
- **Web route:** Trader to Trader Transfer — `/trader-transfer`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `TraderTransferController@config` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:37-60`
- **Kaam:** Ye API data laati hai. Client portal me **Trader to Trader Transfer** screen par use hoti hai (`/trader-transfer`); frontend me `loadConfig` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.enabled` — Chalu hai ya nahi — e.g. `false`

#### 2. POST `/api/user/trader-transfer/verify-recipient`

- **App me call hogi?** Haan — Phase 1 — Receiver ka account/email check karke naam dikhane ke liye.
- **Web route:** Trader to Trader Transfer — `/trader-transfer`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `TraderTransferController@verifyRecipient` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:62-73`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Trader to Trader Transfer** screen par use hoti hai (`/trader-transfer`); frontend me `verifyRecipient` se call hoti hai.
- **Request params:**
  - `email` (string, required: Yes) — Email address — rule: `required|string|max:255`
- **Response keys (main):**
  - `data.recipient_token` — Recipient token (text) — e.g. `"aJiVaK9QGgldTyWjtvezpVQfPZ…"`
  - `data.recipient_name` — recipient ka naam — e.g. `"sh***** ya***"`
  - `data.recipient_email` — Recipient email (text) — e.g. `"user+1@gmail.com"`
  - `data.expires_in` — Expires in (number) — e.g. `600`

#### 3. POST `/api/user/trader-transfer/send-otp`

- **App me call hogi?** Haan — Phase 1 — Submit se pehle OTP.
- **Web route:** Trader to Trader Transfer — `/trader-transfer`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `TraderTransferController@sendOtp` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:79-146`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Trader to Trader Transfer** screen par use hoti hai (`/trader-transfer`); frontend me `sendOtp` se call hoti hai.
- **Request params:**
  - `recipient_token` (string, required: Yes) — Recipient token (text) — rule: `required|string`
  - `amount` (number, required: Yes) — Amount (kai jagah currency sign ke saath text, jaise "$150.00") — rule: `required|numeric|gt:0`
- **Response keys (main):**
  - `data.channel` — Channel (text) — e.g. `"email"`
  - `data.alternate_channel` — Alternate channel (text) — e.g. `""`

#### 4. POST `/api/user/trader-transfer/submit`

- **App me call hogi?** Haan — Phase 1 — Transfer final submit.
- **Web route:** Trader to Trader Transfer — `/trader-transfer`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `TraderTransferController@submit` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:148-189`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Trader to Trader Transfer** screen par use hoti hai (`/trader-transfer`); frontend me `submitTransfer` se call hoti hai.
- **Request params:**
  - `recipient_token` (string, required: Yes) — Recipient token (text) — rule: `required|string`
  - `amount` (number, required: Yes) — Amount (kai jagah currency sign ke saath text, jaise "$150.00") — rule: `required|numeric|gt:0`
  - `otp` (string, required: Yes) — User ko mail / SMS par aaya OTP — rule: `required|string|max:10`
  - `note` (string, required: No) — Note — rule: `nullable|string|max:255`
- **Response keys (main):**
  - `data.id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.reference` — Transaction ka reference number (jaise `INT-000021`) — e.g. `"TT261022QEFLOO"`
  - `data.direction` — Paisa aaya (`credit`) ya gaya (`debit`) — e.g. `"sent"`
  - `data.amount` — Amount (kai jagah currency sign ke saath text, jaise "$150.00") — e.g. `1`
  - `data.status` — Request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. Kuch purani …
  - `data.counterparty_email` — Counterparty email (text) — e.g. `"user+1@gmail.com"`
  - `data.counterparty_name` — counterparty ka naam — e.g. `"sh***** ya***"`
  - `data.note` — Note — e.g. `"api doc probe"`
  - `data.admin_remarks` — Admin remarks (text) — e.g. `""`
  - `data.created_at` — Kab bana (date/time ya "2 weeks ago" jaisa text) — e.g. `"2026-10-22 06:26:18"`

#### 5. GET `/api/user/trader-transfer/history`

- **App me call hogi?** Haan — Phase 1 — Sent / received history list.
- **Web route:** Trader to Trader Transfer — `/trader-transfer`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `TraderTransferController@history` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:195-244`
- **Kaam:** Ye API data laati hai. Client portal me **Trader to Trader Transfer** screen par use hoti hai (`/trader-transfer`); frontend me `loadHistory` se call hoti hai.
- **Request params:**
  - `direction` (string, required: No) — (query) Paisa aaya (`credit`) ya gaya (`debit`) — rule: `nullable|in:sent,received`
  - `status` (string, required: No) — (query) Request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. Kuch purani APIs yahan HTTP code (jaise `200`) bhejti hain — rul…
  - `date_from` (string, required: No) — (query) Date from (text)
  - `date_to` (string, required: No) — (query) Date to (text)
- **Response keys (main):**
  - `data.data` — Asli data (object, list ya khaali)
  - `data.current_page` — Abhi kaunsa page aaya hai — e.g. `1`
  - `data.last_page` — Kul pages — isse aage "load more" band karo — e.g. `1`
  - `data.per_page` — Ek page me kitni rows — e.g. `15`
  - `data.total` — Kul rows / kul total (context ke hisaab se) — e.g. `0`

### Deposit

#### 6. POST `/api/user/deposit/dynamic/{gatewaySlug}`

- **App me call hogi?** Haan — Phase 1 — Naye payment gateways bina app update ke chalenge. Response me redirect/payment URL app WebView me kholega.
- **Web route:** Deposit request / history — `/deposit-request`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DynamicGatewayController@deposit` — `core/app/Http/Controllers/User/DynamicGatewayController.php:36-340`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Deposit request / history** screen par use hoti hai (`/deposit-request`); frontend me `cur` se call hoti hai.
- **Request params:**
  - `gatewaySlug` (string, required: Yes) — (path) Gateway Slug (text) — rule: `URL path parameter`
  - `gateway_method_id` (integer, required: Yes) — gateway method ka id — rule: `required|exists:master_deposit_method,deposit_slug`
  - `mt5_account_id` (integer, required: Yes) — MT5 account (number ya id — API ke hisaab se) — rule: `required`
  - `amount` (number, required: Yes) — Amount (kai jagah currency sign ke saath text, jaise "$150.00") — rule: `required|numeric`
  - `user_input_net_amount` (number, required: No) — user input net ki raqam — rule: `nullable|numeric|min:0.01`
  - `user_input_currency` (string, required: No) — User input currency (text) — rule: `nullable|string|max:50`
  - `card_number` (string, required: No) — card number — rule: `nullable|string`
  - `card_expiry` (string, required: No) — Card expiry (text) — rule: `nullable|string`
  - `card_cvv` (string, required: No) — Card cvv (text) — rule: `nullable|string`
  - `card_name` (string, required: No) — card ka naam — rule: `nullable|string`
  - `payer_mobile` (string, required: No) — Payer mobile (text) — rule: `nullable|regex:/^\+?[0-9]{7,15}$/`
  - `payer_id_number` (string, required: No) — payer id number — rule: `nullable|regex:/^[0-9]{13}$/`
- **Response keys (main):**
  - `data.mt5_account_id` — MT5 account (number ya id — API ke hisaab se) — e.g. `"..."`
  - `data.reference_number` — Transaction ka reference number — `deposit/by-reference` jaisi APIs me yahi bhe…
  - `data.open_in_new_tab` — Open in new tab (text) — e.g. `"..."`

#### 7. POST `/api/user/deposit/unipayment`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — UniPayment gateway wale brokers ke liye; checkout URL WebView me.
- **Web route:** Deposit request / history — `/deposit-request`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `FinanceController@unipaymentDeposit` — `core/app/Http/Controllers/User/FinanceController.php:9575-9717`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Deposit request / history** screen par use hoti hai (`/deposit-request`); frontend me `cur` se call hoti hai.
- **Request params:**
  - `gateway_method_id` (integer, required: Yes) — gateway method ka id — rule: `required|exists:master_deposit_method,deposit_slug`
  - `mt5_account_id` (integer, required: Yes) — MT5 account (number ya id — API ke hisaab se) — rule: `required`
  - `amount` (number, required: Yes) — Amount (kai jagah currency sign ke saath text, jaise "$150.00") — rule: `required|numeric`
- **Response keys (main):**
  - `data.invoice_url` — invoice ka link — e.g. `"..."`
  - `data.invoice_id` — invoice ka id — e.g. `"..."`
  - `data.reference_number` — Transaction ka reference number — `deposit/by-reference` jaisi APIs me yahi bhe…
  - `data.amount` — Amount (kai jagah currency sign ke saath text, jaise "$150.00") — e.g. `"..."`
  - `data.currency` — Currency (jaise `USD`, `USC` = US cent) — e.g. `"..."`
  - `data.account_number` — MT5 account number — e.g. `"..."`

### App shell

#### 8. GET `/api/user/live-chat`

- **App me call hogi?** Haan — Phase 1 — Live chat (Tawk / widget) ki settings API se lene ke liye; abhi app me fixed hai.
- **Web route:** App root — `(all)`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `SettingController@getLiveChat` — `core/app/Http/Controllers/Common/SettingController.php:1419-1427`
- **Kaam:** Ye API data laati hai. Client portal me **App root, Mobile navigation** screen par use hoti hai (`(all)`); frontend me `setup` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.enabled` — Chalu hai ya nahi — e.g. `false`
  - `data.provider` — Provider (text) — e.g. `""`
  - `data.url` — Link (khaali = link nahi) — e.g. `""`
  - `data.label` — Screen par dikhane wala label — e.g. `"Live Chat"`

#### 9. GET `/api/user/notices/active`

- **App me call hogi?** Haan — Phase 1 — Home par active notice / announcement banner.
- **Web route:** App root — `(all)`
- **Auth:** Public (token nahi chahiye)
- **Backend:** `Closure` — `—`
- **Kaam:** Ye API data laati hai. Client portal me **App root** screen par use hoti hai (`(all)`); frontend me `load` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.notices` — Notices ki list

#### 10. GET `/api/user/session/check`

- **App me call hogi?** Haan — Phase 2 — App resume par session valid hai ya nahi (single-device login).
- **Web route:** App root — `(all)`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `UserController@sessionCheck` — `core/app/Http/Controllers/User/UserController.php:710-715`
- **Kaam:** Ye API data laati hai. Client portal me **App root** screen par use hoti hai (`(all)`); frontend me `mounted` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.user_id` — User ka id — e.g. `9`

#### 11. GET `/api/user/notifications/markasread`

- **App me call hogi?** Haan — Phase 1 — Sab notifications read mark karna.
- **Web route:** Top header — `(all)`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `NotificationController@markAsRead` — `core/app/Http/Controllers/Common/NotificationController.php:1107-1128`
- **Kaam:** Ye API data laati hai. Client portal me **Top header** screen par use hoti hai (`(all)`); frontend me `markAllNotificationsRead` se call hoti hai.
- **Request params:** NONE

#### 12. GET `/api/user/notifications/markasread/{id}`

- **App me call hogi?** Haan — Phase 1 — Ek notification tap par read mark karna.
- **Web route:** Top header — `(all)`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `NotificationController@markSingleAsRead` — `core/app/Http/Controllers/Common/NotificationController.php:1131-1149`
- **Kaam:** Ye API data laati hai. Client portal me **Top header** screen par use hoti hai (`(all)`); frontend me `handleNotificationClick` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`

#### 13. GET `/api/user/notifications/mt5-credentials/{id}`

- **App me call hogi?** Haan — Phase 1 — Naya MT5 account bane to login/password popup me dikhana.
- **Web route:** Top header — `(all)`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `NotificationController@showMt5Credentials` — `core/app/Http/Controllers/Common/NotificationController.php:1157-1206`
- **Kaam:** Ye API data laati hai. Client portal me **Top header** screen par use hoti hai (`(all)`); frontend me `handleNotificationClick` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`

#### 14. POST `/api/user/notifications/mt5-credentials/{id}/ack`

- **App me call hogi?** Haan — Phase 1 — Popup dekh liya — ack, taaki dobara na aaye.
- **Web route:** Top header — `(all)`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `NotificationController@ackMt5Credentials` — `core/app/Http/Controllers/Common/NotificationController.php:1214-1249`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Top header** screen par use hoti hai (`(all)`); frontend me `ackAndClose` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`

#### 15. POST `/api/user/banners/track`

- **App me call hogi?** Optional — Phase 3 — Banner view/click analytics. Marketing ko chahiye to add karenge.
- **Web route:** Page banners — `(all)`
- **Auth:** Public (token nahi chahiye)
- **Backend:** `BannerApiController@trackEvent` — `core/Modules/PageBanner/app/Http/Controllers/Api/BannerApiController.php:71-107`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Page banners** screen par use hoti hai (`(all)`); frontend me `trackImpressions`, `onBannerClick`, `onDismiss`, `onDismissForever` se call hoti hai.
- **Request params:**
  - `banner_id` (integer, required: Yes) — banner ka id — rule: `required|integer|exists:banners,id`
  - `event_type` (string, required: Yes) — Event type (text) — rule: `required|string|in:`

### Notifications

#### 16. GET `/api/user/notifications/all`

- **App me call hogi?** Haan — Phase 1 — Full notifications list (pagination).
- **Web route:** Notifications list — `/notifications`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `NotificationController@showAllNotification` — `core/app/Http/Controllers/Common/NotificationController.php:81-115`
- **Kaam:** Ye API data laati hai. Client portal me **Notifications list** screen par use hoti hai (`/notifications`); frontend me `loadNotifications` se call hoti hai.
- **Request params:** NONE

### Auth

#### 17. POST `/api/user/auth/google/complete-registration`

- **App me call hogi?** Haan — Phase 1 — Google se naya user: mobile + password + OTP ke baad account complete. check-mobile app me already hai.
- **Web route:** Complete Registration (Google signup) — `/complete-registration`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `GoogleAuthController@completeGoogleRegistration` — `core/app/Http/Controllers/User/GoogleAuthController.php:819-936`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Complete Registration (Google signup)** screen par use hoti hai (`/complete-registration`); frontend me `handleMobileSubmit`, `autoSubmitMobileAndRedirect` se ca…
- **Request params:**
  - `mobile` (string, required: Yes) — Mobile number (country code ke bina) — rule: `required, string, max:25, new ValidPhoneNumber()`
  - `country_code` (string, required: Yes) — Phone ka country code (jaise `+91`) — rule: `required|string|max:10`
  - `password` (string, required: Yes) — Password — rule: `required|string|min:6`
  - `otp_code` (string, required: Yes) — OTP code (mail ya Google Authenticator se) — rule: `required|string|size:6`
  - `otp_verification_type` (string (email), required: Yes) — Otp verification type (text) — rule: `required|in:mobile,email`
- **Response keys (main):**
  - `data.user` — User (text) — e.g. `"..."`
  - `data.needs_kyc` — Needs kyc (text) — e.g. `"..."`
  - `data.registration_complete` — Registration complete (text) — e.g. `"..."`

#### 18. GET `/api/ibm/r/{code}`

- **App me call hogi?** Haan — Phase 2 — IB Manager referral link/code se register — sponsor resolve karna.
- **Web route:** Register — `/register`
- **Auth:** Public (token nahi chahiye)
- **Backend:** _no matching route on development-new_
- **Kaam:** Ye API data laati hai. Client portal me **Register** screen par use hoti hai (`/register`); frontend me `trackIbmLinkVisit` se call hoti hai.
- **Request params:**
  - `code` (string, required: Yes) — (path) Code (referral / link code) — rule: `URL path parameter` — value [`GET /api/ibm/portal/links`](#get-api-ibm-portal-links) ke `data.l…

#### 19. POST `/api/user/ib/track-sponsor-visit`

- **App me call hogi?** Haan — Phase 2 — Referral link se app khule to visit count.
- **Web route:** Register — `/register`
- **Auth:** Public (token nahi chahiye)
- **Backend:** `IbaController@trackSponsorCodeVisit` — `core/app/Http/Controllers/User/IbaController.php:5669-5709`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Register, Invite / Referral link** screen par use hoti hai (`/register, /user/invite/:referral_code`); frontend me `ibmFromUrl` se call hoti hai.
- **Request params:**
  - `sponsorcode` (string, required: Yes) — Sponsorcode (text) — rule: `required|string`
- **Response keys (main):**
  - `data.reference_link_id` — IB ka referral code — e.g. `"IB_016730"`
  - `data.visit_count` — visit ki ginti — e.g. `3`

#### 20. GET `/api/user`

- **App me call hogi?** Nahi — mat lagao — App ke paas iski jagah settings/profile pehle se hai. Route check nahi kiya — backend confirm baaki.
- **Web route:** Register — `/register`
- **Auth:** Public (token nahi chahiye)
- **Kaam:** Ye API data laati hai. Client portal me **Register, Web Trader (terminal), IB Dashboard / IB Application** screen par use hoti hai (`/register, /trading, /ib-dashboard`).
- **Request params:** NONE

#### 21. GET `/api/user/json`

- **App me call hogi?** Nahi — mat lagao — App ke paas iski jagah country/state/city dropdown APIs pehle se hain. Route check nahi kiya — backend confirm baaki.
- **Web route:** Register — `/register`
- **Auth:** Public (token nahi chahiye)
- **Kaam:** Ye API data laati hai. Client portal me **Register, Complete Registration (Google signup)** screen par use hoti hai (`/register, /complete-registration`).
- **Request params:** NONE

#### 22. POST `/api/user/password/reset-token`

- **App me call hogi?** Nahi — mat lagao — Email link wala reset (web). App OTP flow (password/forgot -> verify-otp -> reset) use karta hai.
- **Web route:** Reset Password — `/reset-password`
- **Auth:** Public (token nahi chahiye)
- **Backend:** `AuthController@reset` — `core/app/Http/Controllers/User/AuthController.php:1733-1777`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Reset Password** screen par use hoti hai (`/reset-password`); frontend me `submit` se call hoti hai.
- **Request params:**
  - `token` (string, required: Yes) — Token (text) — rule: `required`
  - `email` (string (email), required: Yes) — Email address — rule: `required|email`
  - `password` (string, required: Yes) — Password — rule: `required|string|min:8|max:16|confirmed`
  - `password_confirmation` (string, required: No) — Password dobara (match hona chahiye)

### Dashboard / Accounts

#### 23. POST `/api/user/mt5accounts/setnickname`

- **App me call hogi?** Haan — Phase 2 — MT5 account ka nickname set karna (model me nick_name already hai).
- **Web route:** Dashboard — `/dashboard`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `Mt5Controller@setNickName` — `core/app/Http/Controllers/Common/Mt5Controller.php:2728-2754`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Dashboard, Trading Accounts** screen par use hoti hai (`/dashboard, /trading-accounts`); frontend me `submitNickname` se call hoti hai.
- **Request params:**
  - `meta_account_number` (integer, required: No) — MT5 account number (login) — transfer, deposit, withdrawal, trading, leverage aur password wali APIs me yahi bheja jaata hai — value [`GET …
  - `mt5_nick_name` (string, required: No) — User ka diya hua account nickname

#### 24. GET `/api/user/prop-coupons`

- **App me call hogi?** Optional — Phase 3 — Prop trading coupons — prop module app me aaye tab.
- **Web route:** Dashboard — `/dashboard`
- **Auth:** Public (token nahi chahiye)
- **Kaam:** Ye API data laati hai. Client portal me **Dashboard** screen par use hoti hai (`/dashboard`); frontend me `loadPropCoupons` se call hoti hai.
- **Request params:** NONE

### Trading

#### 25. PUT `/api/user/price-alerts/{id}`

- **App me call hogi?** Haan — Phase 2 — Price alert edit — abhi app alerts local storage me rakhta hai; server sync ke liye.
- **Web route:** Web Trader (terminal) — `/trading`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `PriceAlertController@update` — `core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:168-219`
- **Kaam:** Ye API record update karti hai. Client portal me **Web Trader (terminal)** screen par use hoti hai (`/trading`); frontend me `isPaused`, `accountNumberForCreate` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`
  - `symbol` (string, required: Conditional) — Instrument (jaise XAUUSD, EURUSD) — rule: `sometimes|required|string|max:50`
  - `target_price` (number, required: Conditional) — Price alert ka target price — rule: `sometimes|required|numeric|min:0`
  - `condition` (string, required: Conditional) — Alert kab chale: `above` (upar jaye) / `below` (neeche aaye) — rule: `sometimes|required|in:above,below`
  - `fcm_token` (string, required: No) — Push notification ke liye device ka FCM token — rule: `nullable|string`
  - `device_type` (string, required: No) — Device ka type (android / ios / web) — rule: `nullable|in:android,ios`
  - `message` (string, required: No) — Server ka message — user ko toast / alert me dikhane ke liye — rule: `nullable|string|max:500`
  - `is_active` (boolean, required: Conditional) — Active hai ya nahi — rule: `sometimes|boolean`
- **Response keys (main):**
  - `data.alert` — Alert (group of fields)
  - `data.alert.id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.alert.user_id` — User ka id — e.g. `9`
  - `data.alert.mt5_account_id` — MT5 account (number ya id — API ke hisaab se) — e.g. `14`
  - `data.alert.symbol` — Instrument (jaise XAUUSD, EURUSD) — e.g. `"EURUSD"`
  - `data.alert.group_id` — Group (account type / plan group) ka id — account banane ya plan chunne me bhej…
  - `data.alert.target_price` — Price alert ka target price — e.g. `"1.25000000"`
  - `data.alert.condition` — Alert kab chale: `above` (upar jaye) / `below` (neeche aaye) — e.g. `"above"`
  - `data.alert.is_active` — Active hai ya nahi — e.g. `true`
  - `data.alert.is_triggered` — Alert chal chuka hai ya nahi — e.g. `false`

#### 26. DELETE `/api/user/price-alerts/{id}`

- **App me call hogi?** Haan — Phase 2 — Price alert delete (server sync).
- **Web route:** Web Trader (terminal) — `/trading`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `PriceAlertController@destroy` — `core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:225-253`
- **Kaam:** Ye API record delete karti hai. Client portal me **Web Trader (terminal)** screen par use hoti hai (`/trading`); frontend me `closeModal`, `accountNumberForCreate` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`

#### 27. GET `/api/user/economic-calendar`

- **App me call hogi?** Optional — Phase 3 — Economic calendar screen (Tools section).
- **Web route:** Web Trader (terminal) — `/trading`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `EconomicCalendarController@index` — `core/app/Http/Controllers/User/EconomicCalendarController.php:12-109`
- **Kaam:** Ye API data laati hai. Client portal me **Web Trader (terminal)** screen par use hoti hai (`/trading`); frontend me `formatDateTime` se call hoti hai.
- **Request params:**
  - `from` (string (date), required: No) — (query) Is page ki pehli row ka number — rule: `nullable, date_format:Y-m-d`
  - `to` (string (date), required: No) — (query) Is page ki aakhri row ka number — rule: `nullable, date_format:Y-m-d`
  - `country` (string, required: No) — (query) Country ka id (countries list se) — rule: `nullable, string`
  - `currency` (string, required: No) — (query) Currency (jaise `USD`, `USC` = US cent) — rule: `nullable, string`
  - `importance` (string, required: No) — (query) Importance (text) — rule: `nullable`
  - `provider` (string, required: No) — (query) Provider (text) — rule: `nullable, string`
  - `limit` (integer, required: No) — (query) Limit (text) — rule: `nullable, integer, min:1, max:5000`

#### 28. GET `/api/user/trade/tradehistory/export`

- **App me call hogi?** Optional — Phase 3 — History export file (CSV/PDF) download + share.
- **Web route:** Web Trader (terminal) — `/trading`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `TradeController@exportTradeHistory` — `core/app/Http/Controllers/User/TradeController.php:5668-5738`
- **Kaam:** Ye API data laati hai. Client portal me **Web Trader (terminal)** screen par use hoti hai (`/trading`); frontend me `formatSymbol` se call hoti hai.
- **Request params:** NONE

#### 29. GET `/api/user/modules`

- **App me call hogi?** Nahi — mat lagao — Ye wahi data deti hai jo app enabled-modules se already leti hai.
- **Web route:** Web Trader (terminal) — `/trading`
- **Auth:** Public (token nahi chahiye)
- **Backend:** `ModuleController@index` — `core/app/Http/Controllers/Common/ModuleController.php:273-276`
- **Kaam:** Ye API data laati hai. Client portal me **Web Trader (terminal)** screen par use hoti hai (`/trading`); frontend me `onMounted` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data[].key` — Setting / item ka code — e.g. `"pmam"`
  - `data[].name` — Naam — e.g. `"PMAM"`
  - `data[].description` — Description — e.g. `"Portfolio Management Accou…"`
  - `data[].enabled` — Chalu hai ya nahi — e.g. `true`

### Copy Trading

#### 30. GET `/api/copytrading/plans/search`

- **App me call hogi?** Haan — Phase 2 — Leaderboard me search box.
- **Web route:** Leaderboard — `/copy-trade`
- **Auth:** Public (token nahi chahiye)
- **Backend:** `CopyTradingApiController@searchPublicPlans` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4464-4503`
- **Kaam:** Ye API data laati hai. Client portal me **Leaderboard** screen par use hoti hai (`/copy-trade`); frontend me `searchPlanOptions` se call hoti hai.
- **Request params:** NONE

### PAMM

#### 31. GET `/api/user/pmam/managers`

- **App me call hogi?** Haan — Phase 2 — Fund managers list screen.
- **Web route:** Managers list — `/pmam/managers`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `PmamApiController@getManagersList` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3629-3668`
- **Kaam:** Ye API data laati hai. Client portal me **Managers list** screen par use hoti hai (`/pmam/managers`); frontend me `loadData` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data[].manager_code` — PAMM manager ka code — manager profile / trades APIs me bhejte hain — e.g. `"PA…
  - `data[].manager_name` — Manager ka naam — e.g. `"shubham yadav"`
  - `data[].plans_count` — plans ki ginti — e.g. `0`
  - `data[].total_aum` — Kul AUM — e.g. `0`
  - `data[].total_investors` — Kul investors — e.g. `0`
  - `data[].hide_investors` — Hide investors (true / false) — e.g. `false`
  - `data[].avg_commission` — Avg commission (number) — e.g. `0`
  - `data[].profit_percentage` — profit % — e.g. `0`
  - `data[].member_since` — Kab se member hai — e.g. `"2026-07-28"`
  - `data[].status` — Request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. Kuch purani …

#### 32. GET `/api/user/pmam/managers/search`

- **App me call hogi?** Haan — Phase 2 — Managers search.
- **Web route:** Explore Fund Managers — `/pmam/investor/explore`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `PmamApiController@searchManagers` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3410-3450`
- **Kaam:** Ye API data laati hai. Client portal me **Explore Fund Managers, My Investments** screen par use hoti hai (`/pmam/investor/explore, /pmam/investor/my-investments`); frontend me `searchManagerOptions` se call hoti hai.
- **Request params:** NONE

#### 33. GET `/api/user/pmam/plans/search`

- **App me call hogi?** Haan — Phase 2 — Plans search (Explore).
- **Web route:** Explore Fund Managers — `/pmam/investor/explore`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `PmamApiController@searchPlans` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3464-3503`
- **Kaam:** Ye API data laati hai. Client portal me **Explore Fund Managers, My Investments** screen par use hoti hai (`/pmam/investor/explore, /pmam/investor/my-investments`); frontend me `searchPlanOptions` se call hoti hai.
- **Request params:** NONE

#### 34. POST `/api/user/pmam/plans/datatable`

- **App me call hogi?** Nahi — mat lagao — Web ka datatable format. App ke paas iski jagah PAMM explore / plans search APIs hain. Route check nahi kiya — backend confirm baaki.
- **Web route:** Explore Fund Managers — `/pmam/investor/explore`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `PmamApiController@getPlansListDataTable` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3520-3624`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Explore Fund Managers, My Investments** screen par use hoti hai (`/pmam/investor/explore, /pmam/investor/my-investments`); frontend me `start` se call hoti hai.
- **Request params:**
  - `manager_code` (string, required: No) — PAMM manager ka code — manager profile / trades APIs me bhejte hain — value [`GET /api/user/pmam/investor/enrollments`](#get-api-user-pmam-…
  - `plan_id` (integer, required: No) — Plan ka id — plan detail / join / edit wali APIs me bhejte hain — value [`GET /api/user/pmam/investor/enrollments`](#get-api-user-pmam-inve…
- **Response keys (main):**
  - `data[].id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data[].plan_name` — Plan ka naam — e.g. `"FULL TRADING SETUP"`
  - `data[].status` — Request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. Kuch purani …
  - `data[].minimum_investment` — Minimum investment — e.g. `10`
  - `data[].commission_percentage` — Commission % — e.g. `10`
  - `data[].strategy_description` — Trading strategy — e.g. `"VERY RISKY"`
  - `data[].risk_information` — Risk ki jaankari — e.g. `"VERY RISKY"`
  - `data[].manager_code` — PAMM manager ka code — manager profile / trades APIs me bhejte hain — e.g. `"PA…
  - `data[].manager_name` — Manager ka naam — e.g. `"Test One"`
  - `data[].member_since` — Kab se member hai — e.g. `"2026-07-22"`

#### 35. GET `/api/user/pmam/manager/eligible-accounts`

- **App me call hogi?** Haan — Phase 2 — Manager plan banate waqt MT5 account dropdown.
- **Web route:** Manager dashboard — `/pmam/manager/dashboard`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `PmamApiController@getManagerEligibleAccounts` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1654-1698`
- **Kaam:** Ye API data laati hai. Client portal me **Manager dashboard, Manager — My Plans** screen par use hoti hai (`/pmam/manager/dashboard, /pmam/manager/plans`); frontend me `loadTradingAccounts` se call hoti hai.
- **Request params:** NONE

#### 36. GET `/api/user/pmam/manager/commissions`

- **App me call hogi?** Haan — Phase 2 — Manager — Commissions screen.
- **Web route:** Manager — Commissions — `/pmam/manager/commissions`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `PmamApiController@getCommissionsList` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2882-2971`
- **Kaam:** Ye API data laati hai. Client portal me **Manager — Commissions** screen par use hoti hai (`/pmam/manager/commissions`); frontend me `reload` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.data` — Asli data (object, list ya khaali)
  - `data.data[].id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.data[].plan_id` — Plan ka id — plan detail / join / edit wali APIs me bhejte hain — e.g. `1` — **…
  - `data.data[].plan_name` — Plan ka naam — e.g. `"FULL TRADING SETUP"`
  - `data.data[].investor_id` — investor ka id — e.g. `4` — **Next API:** [`GET /api/user/pmam/manager/investor…
  - `data.data[].investor_name` — Investor ka naam — e.g. `"TEst Five"`
  - `data.data[].investor_email` — Investor email (text) — e.g. `"test5@example.com"`
  - `data.data[].trade_id` — Trade / deal ka id — e.g. `1000077`
  - `data.data[].gross_profit_share` — Gross profit share (number) — e.g. `5.590110000000001`
  - `data.data[].commission_charged` — Commission charged (number) — e.g. `0.2424`

### IB (classic)

#### 37. GET `/api/user/ib/activities`

- **App me call hogi?** Haan — Phase 2 — IB dashboard par recent activity.
- **Web route:** IB Dashboard / IB Application — `/ib-dashboard`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `IbaController@getRecentActivities` — `core/app/Http/Controllers/User/IbaController.php:5282-5436`
- **Kaam:** Ye API data laati hai. Client portal me **IB Dashboard / IB Application** screen par use hoti hai (`/ib-dashboard`); frontend me `loadRecentActivities` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data[].id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data[].type` — Type — e.g. `"approval"`
  - `data[].title` — Title — e.g. `"IB Application Approved"`
  - `data[].description` — Description — e.g. `"test sub ib IB application…"`
  - `data[].time` — Time / kitna pehle (jaise "16 days ago") — e.g. `"16 days ago"`
  - `data[].amount` — Amount (kai jagah currency sign ke saath text, jaise "$150.00") — e.g. `""`
  - `data[].client_name` — client ka naam — e.g. `"shubham cent thirteen"`
  - `data[].symbol` — Instrument (jaise XAUUSD, EURUSD) — e.g. `"EURUSD"`
  - `data[].mt5_account` — MT5 account number — e.g. `2000017`
  - `data[].entry_price` — Entry price (number) — e.g. `1.16921`

#### 38. GET `/api/user/ib/tree-structure`

- **App me call hogi?** Haan — Phase 2 — My Network tree view.
- **Web route:** My Network (clients) — `/my-client`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `IbaController@getIBTreeStructure` — `core/app/Http/Controllers/User/IbaController.php:4399-4434`
- **Kaam:** Ye API data laati hai. Client portal me **My Network (clients)** screen par use hoti hai (`/my-client`); frontend me `fetchNetworkTree`, `searchNetworkTree`, `loadIBTreeStructure` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.tree` — Tree ki list
  - `data.tree[].user` — User (group of fields)
  - `data.tree[].user.id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.tree[].user.user_slug` — User ka public code (slug) — documents / images ke URL me use hota hai — e.g. `…
  - `data.tree[].user.fullname` — User ka poora naam — e.g. `"shubham yadav"`
  - `data.tree[].user.email` — Email address — e.g. `"user@gmail.com"`
  - `data.tree[].user.first_name` — User ka pehla naam — e.g. `"shubham"`
  - `data.tree[].user.last_name` — User ka surname — e.g. `"yadav"`
  - `data.tree[].user.role` — Role (jaise user / admin) — e.g. `"Master IB"`
  - `data.tree[].user.total_descendants` — Neeche ke kul members — e.g. `14`

#### 39. GET `/api/user/ib/get-ib-details/{userSlug}`

- **App me call hogi?** Haan — Phase 2 — Network me client / sub-IB tap par detail.
- **Web route:** My Network (clients) — `/my-client`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `IbaController@getIBDetailsApi` — `core/app/Http/Controllers/User/IbaController.php:1841-1902`
- **Kaam:** Ye API data laati hai. Client portal me **My Network (clients)** screen par use hoti hai (`/my-client`); frontend me `loadIBDetails` se call hoti hai.
- **Request params:**
  - `userSlug` (string, required: Yes) — (path) User Slug (text) — rule: `URL path parameter` — value [`GET /api/user/ib/tree-structure`](#get-api-user-ib-tree-structure) ke `data.…
- **Response keys (main):**
  - `data.ib_info` — Ib info (group of fields)
  - `data.ib_info.user_id` — User ka id — e.g. `9`
  - `data.ib_info.user_slug` — User ka public code (slug) — documents / images ke URL me use hota hai — e.g. `…
  - `data.ib_info.name` — Naam — e.g. `"shubham yadav"`
  - `data.ib_info.email` — Email address — e.g. `"user@gmail.com"`
  - `data.ib_info.first_name` — User ka pehla naam — e.g. `"shubham"`
  - `data.ib_info.last_name` — User ka surname — e.g. `"yadav"`
  - `data.statistics` — Statistics (group of fields)
  - `data.statistics.total_clients` — Kul clients — e.g. `12`
  - `data.statistics.total_deposited` — Kul deposited — e.g. `2317400`

#### 40. GET `/api/user/ib/get-template-rates/{templateId}`

- **App me call hogi?** Haan — Phase 2 — Commission group form me template select par rates.
- **Web route:** Sub IB Structure — create/edit commission group — `/sub-ib-structure/create`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `IBCommisionGroupController@getTemplateCommissionRates` — `core/app/Http/Controllers/User/IBCommisionGroupController.php:1925-1963`
- **Kaam:** Ye API data laati hai. Client portal me **Sub IB Structure — create/edit commission group** screen par use hoti hai (`/sub-ib-structure/create`); frontend me `loadTemplateRates` se call hoti hai.
- **Request params:**
  - `templateId` (string, required: Yes) — (path) Template Id (text) — rule: `URL path parameter`
- **Response keys (main):**
  - `data.{id}` — Id ke hisaab se rakha item (key = id)
  - `data.{id}.{id}` — Id ke hisaab se rakha item (key = id) — e.g. `25`

#### 41. GET `/api/user/ib/get-structure-options/{id}`

- **App me call hogi?** Haan — Phase 2 — Sub-IB approve karte waqt structure options.
- **Web route:** Sub IB Approval — `/sub-ib-approval`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `IbaController@getIBStructureOptions` — `core/app/Http/Controllers/User/IbaController.php:2844-2857`
- **Kaam:** Ye API data laati hai. Client portal me **Sub IB Approval** screen par use hoti hai (`/sub-ib-approval`); frontend me `openReasonModal` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`
- **Response keys (main):**
  - `data.html` — Html (text) — e.g. `"..."`

### IB Demo Contest (host)

#### 42. GET `/api/ib/demo-contest/my-contests`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — IB ke banaye contests list.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@index` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:23-46`
- **Kaam:** Ye API data laati hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `fetchContests` se call hoti hai.
- **Request params:** NONE

#### 43. GET `/api/ib/demo-contest/instruments`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Contest create form — instruments.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@getInstruments` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:463-475`
- **Kaam:** Ye API data laati hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `loadInstruments` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.categories` — Categories ki list
  - `data.categories[].id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.categories[].categories_name` — categories ka naam — e.g. `"Currency"`
  - `data.symbols` — Symbols ki list
  - `data.symbols[].id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.symbols[].symbol_name` — symbol ka naam — e.g. `"ADAUSD"`
  - `data.symbols[].category_id` — category ka id — e.g. `6`

#### 44. POST `/api/ib/demo-contest/store`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Naya contest create.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@store` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:51-173`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `submitCreate` se call hoti hai.
- **Request params:**
  - `name` (string, required: Yes) — Naam — rule: `required|string|max:255`
  - `tagline` (string, required: No) — Chhota tagline — rule: `nullable|string|max:255`
  - `start_date` (string (date), required: Yes) — Shuru hone ki date — rule: `required|date`
  - `end_date` (string (date), required: Yes) — Khatam hone ki date — rule: `required|date|after_or_equal:start_date`
  - `registration_closes` (string (date), required: No) — Registration kab band hoga — rule: `nullable|date`
  - `starting_balance` (number, required: Yes) — Contest ka starting balance — rule: `required|numeric|min:10`
  - `min_participants` (integer, required: Yes) — Kam se kam participants — rule: `required|integer|min:1`
  - `max_participants` (integer, required: Yes) — Zyada se zyada participants — rule: `required|integer|min:1|gte:min_participants`
  - `ranking_by` (string, required: Yes) — Rank kis basis par (jaise return_percent) — rule: `required|string`
  - `timezone` (string, required: Yes) — Timezone (text) — rule: `required|string`
  - `enrollment_type` (string, required: Yes) — Enrollment type (text) — rule: `required|in:free,paid`
  - `enrollment_fee` (number, required: No) — Enrollment fee (text) — rule: `nullable|numeric|min:0`
  - `enrollment_start_date` (string (date), required: No) — enrollment start ki date — rule: `nullable|date`
  - `enrollment_end_date` (string (date), required: No) — enrollment end ki date — rule: `nullable|date`
  - `contest_start_date` (string (date), required: No) — contest start ki date — rule: `nullable|date`
  - `contest_end_date` (string (date), required: No) — contest end ki date — rule: `nullable|date`
  - `allow_multiple_contests` (boolean, required: No) — multiple contests allowed hai ya nahi — rule: `boolean`
  - `max_participations_per_user` (integer, required: No) — Zyada se zyada participations per user — rule: `nullable|integer|min:1`
  - `prize_pool_type` (string, required: Yes) — Prize pool type (text) — rule: `required|in:fixed,percentage`
  - `ib_admin_share_percent` (number, required: Yes) — ib admin share % — rule: `required|numeric|min:20|max:100`
  - `enrollment_steps_enabled` (boolean, required: No) — enrollment steps chalu hai ya nahi — rule: `boolean`
  - `auto_disqualify_on_violation` (boolean, required: No) — Auto disqualify on violation (text) — rule: `boolean`
  - `terms_enabled` (boolean, required: No) — terms chalu hai ya nahi — rule: `boolean`
  - `terms_content` (string, required: No) — Terms content (text) — rule: `nullable|string`
  - `prizes` (array, required: No) — Prizes (text) — rule: `nullable|array`
  - `enrollment_steps` (array, required: No) — Enrollment steps (text) — rule: `nullable|array`
  - `instruments` (array, required: No) — Instruments (text) — rule: `nullable|array`
  - `trading_platform` (string, required: No) — Platform (MT5 / WEB_TRADER) — rule: `nullable|in:MT5,WEB_TRADER`
  - `mt5_group_id` (integer, required: No) — MT5 group ka id — rule: `nullable|integer|exists:mt5_group_masters,id`
- **Response keys (main):**
  - `data.name` — Naam — e.g. `"Probe contest"`
  - `data.tagline` — Chhota tagline — e.g. `"api doc probe"`
  - `data.start_date` — Shuru hone ki date — e.g. `"2026-11-01"`
  - `data.end_date` — Khatam hone ki date — e.g. `"2026-11-30"`
  - `data.registration_closes` — Registration kab band hoga — e.g. `"2026-10-31"`
  - `data.starting_balance` — Contest ka starting balance — e.g. `10000`
  - `data.max_participants` — Zyada se zyada participants — e.g. `50`
  - `data.ranking_by` — Rank kis basis par (jaise return_percent) — e.g. `"profit_percent"`
  - `data.timezone` — Timezone (text) — e.g. `"UTC"`
  - `data.enrollment_type` — Enrollment type (text) — e.g. `"free"`

#### 45. POST `/api/ib/demo-contest/{id}/update`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Contest edit.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@update` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:178-248`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `submitCreate` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`
  - `name` (string, required: No) — Naam
  - `tagline` (string, required: No) — Chhota tagline
  - `start_date` (string, required: No) — Shuru hone ki date
  - `end_date` (string, required: No) — Khatam hone ki date
  - `registration_closes` (string, required: No) — Registration kab band hoga
  - `starting_balance` (integer, required: No) — Contest ka starting balance
  - `min_participants` (integer, required: No) — Kam se kam participants
  - `max_participants` (integer, required: No) — Zyada se zyada participants
  - `ranking_by` (string, required: No) — Rank kis basis par (jaise return_percent)
  - `timezone` (string, required: No) — Timezone (text)
  - `enrollment_type` (string, required: No) — Enrollment type (text)
  - `prize_pool_type` (string, required: No) — Prize pool type (text)
  - `ib_admin_share_percent` (integer, required: No) — ib admin share %
- **Response keys (main):**
  - `data.id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.trading_platform` — Platform (MT5 / WEB_TRADER) — e.g. `null`
  - `data.mt5_group_id` — MT5 group ka id — e.g. `null`
  - `data.name` — Naam — e.g. `"Probe contest edited"`
  - `data.tagline` — Chhota tagline — e.g. `"api doc probe"`
  - `data.start_date` — Shuru hone ki date — e.g. `"2026-11-01"`
  - `data.end_date` — Khatam hone ki date — e.g. `"2026-11-30"`
  - `data.starting_balance` — Contest ka starting balance — e.g. `10000`
  - `data.max_participants` — Zyada se zyada participants — e.g. `50`
  - `data.max_participations_per_user` — Zyada se zyada participations per user — e.g. `1`

#### 46. POST `/api/ib/demo-contest/{id}/cancel`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Contest cancel.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@cancelContest` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:346-375`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `submitCancelContest` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`
  - `reason` (string, required: No) — Kaaran (reason)

#### 47. POST `/api/ib/demo-contest/{id}/add-prize-fund`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Prize fund add.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@addPrizeFund` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:380-403`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `submitAddFund` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`
  - `amount` (number, required: Yes) — Amount (kai jagah currency sign ke saath text, jaise "$150.00") — rule: `required|numeric|min:0.01`
- **Response keys (main):**
  - `data.id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.contest_id` — Contest ka id — contest detail / enroll / claim APIs me bhejte hain — e.g. `5`
  - `data.total_collected` — Kul collected — e.g. `0`
  - `data.creator_added` — Creator added (number) — e.g. `10`
  - `data.total_pool` — Kul pool — e.g. `10`
  - `data.distributed_amount` — distributed ki raqam — e.g. `0`
  - `data.remaining_amount` — remaining ki raqam — e.g. `10`
  - `data.is_distributed` — Kya distributed hai? (`true` / `false`) — e.g. `false`
  - `data.distributed_at` — distributed kab hua (date/time) — e.g. `null`
  - `data.created_at` — Kab bana (date/time ya "2 weeks ago" jaisa text) — e.g. `"2026-10-22T06:26:19+0…

#### 48. GET `/api/ib/demo-contest/{id}/enrollments`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Contest ke participants.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@enrollmentList` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:253-276`
- **Kaam:** Ye API data laati hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `loadEnrollments` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`
- **Response keys (main):**
  - `data.current_page` — Abhi kaunsa page aaya hai — e.g. `1`
  - `data.data` — Asli data (object, list ya khaali)
  - `data.data[].id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.data[].contest_id` — Contest ka id — contest detail / enroll / claim APIs me bhejte hain — e.g. `3`
  - `data.data[].user_id` — User ka id — e.g. `61`
  - `data.data[].demo_account_number` — Contest ka demo account number — e.g. `"56663456"`
  - `data.data[].starting_balance` — Contest ka starting balance — e.g. `10000`
  - `data.data[].current_equity` — Abhi ki equity — e.g. `9685.64`
  - `data.data[].return_percent` — Return % — e.g. `-0.73`
  - `data.data[].profit` — Profit / loss — e.g. `-314.3600000000006`

#### 49. POST `/api/ib/demo-contest/enrollment/{id}/approve`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Participant approve.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@approveEnrollment` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:281-312`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `approveEnroll` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`

#### 50. POST `/api/ib/demo-contest/enrollment/{id}/reject`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Participant reject.
- **Web route:** IB Demo Contest (list/create/edit/view) — `/ib-contest`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `DemoContestIbApiController@rejectEnrollment` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:317-341`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **IB Demo Contest (list/create/edit/view)** screen par use hoti hai (`/ib-contest`); frontend me `rejectEnroll` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`
  - `reason` (string, required: No) — Kaaran (reason)

### Promotions

#### 51. POST `/api/user/bonus/bonusClaimCancel`

- **App me call hogi?** Haan — Phase 2 — Claimed bonus cancel.
- **Web route:** Bonus — `/bonus`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `BonusController@cancelBonus` — `core/app/Http/Controllers/User/BonusController.php:528-628`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Bonus** screen par use hoti hai (`/bonus`); frontend me `confirmCancelBonus` se call hoti hai.
- **Request params:**
  - `id` (integer, required: Yes) — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `required|exists:user_bonus,id`
  - `reason` (string, required: No) — Kaaran (reason) — rule: `nullable|string|max:500`

#### 52. POST `/api/v1/user/scratch-cards/claim`

- **App me call hogi?** Haan — Phase 2 — Scratch card reward claim (reveal/convert app me already hai).
- **Web route:** Scratch card promotion — `/promotion`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `ScratchCardApiController@claim` — `core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:466-489`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Scratch card promotion** screen par use hoti hai (`/promotion`); frontend me `onClaimReward` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.claim_request_id` — claim request ka id — e.g. `6`
  - `data.claim_status` — claim ka status — e.g. `"pending"`
  - `data.claim_amount` — claim ki raqam — e.g. `5`

#### 53. GET `/api/user/trading-central`

- **App me call hogi?** Optional — Phase 3 — Trading Central widget/URL — WebView me.
- **Web route:** Trading Central — `/trading-central/:page?`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `SettingController@getTradingCentral` — `core/app/Http/Controllers/Common/SettingController.php:1396-1410`
- **Kaam:** Ye API data laati hai. Client portal me **Trading Central** screen par use hoti hai (`/trading-central/:page?`); frontend me `loadTradingCentral` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.enabled` — Chalu hai ya nahi — e.g. `true`
  - `data.deposit_required` — Deposit required (true / false) — e.g. `true`
  - `data.has_first_deposit` — Kya first deposit hai? (`true` / `false`) — e.g. `true`
  - `data.can_access` — Kya access kar sakte hain? (`true` / `false`) — e.g. `true`
  - `data.default_page` — Default page (text) — e.g. `"economic_calendar"`
  - `data.menu_label` — menu (dikhane wala text) — e.g. `"Trading Central"`
  - `data.deposit_total` — Deposit total (number) — e.g. `3700`
  - `data.pages` — Pages ki list
  - `data.pages[].key` — Setting / item ka code — e.g. `"economic_calendar"`
  - `data.pages[].label` — Screen par dikhane wala label — e.g. `"Economic Calendar"`

### Platforms

#### 54. GET `/api/user/platform-links`

- **App me call hogi?** Haan — Phase 2 — MT5 / platform download links screen.
- **Web route:** Platforms (download links) — `/platform`
- **Auth:** Public (token nahi chahiye)
- **Backend:** `SettingController@getPlatformLinks` — `core/app/Http/Controllers/Common/SettingController.php:2395-2414`
- **Kaam:** Ye API data laati hai. Client portal me **Platforms (download links)** screen par use hoti hai (`/platform`); frontend me `fetchPlatforms` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.platform_links` — Platform links ki list
  - `data.platform_links[].slug` — Code / slug (URL me use hota hai) — e.g. `"ios"`
  - `data.platform_links[].name` — Naam — e.g. `"App Store"`
  - `data.platform_links[].description` — Description — e.g. `"Trade on the go with our i…"`
  - `data.platform_links[].image_url` — Image ka URL — e.g. `""`
  - `data.platform_links[].url` — Link (khaali = link nahi) — e.g. `"https://apps.apple.com/app…"`

### Settings — Security

#### 55. GET `/api/user/sessions`

- **App me call hogi?** Haan — Phase 1 — Logged-in devices list.
- **Web route:** Security (password, 2FA, devices) — `/settings-security`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `SessionController@index` — `core/app/Http/Controllers/User/SessionController.php:17-64`
- **Kaam:** Ye API data laati hai. Client portal me **Security (password, 2FA, devices), Login activities** screen par use hoti hai (`/settings-security, /settings-activities`); frontend me `loadSessions` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data[].id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data[].name` — Naam — e.g. `"api-doc-probe"`
  - `data[].last_used_at` — last used kab hua (date/time) — e.g. `"2026-10-22T05:57:54+00:00"`
  - `data[].created_at` — Kab bana (date/time ya "2 weeks ago" jaisa text) — e.g. `"2026-10-22T05:43:27+0…
  - `data[].is_current` — Kya current hai? (`true` / `false`) — e.g. `true`
  - `data[].ip_address` — IP address — e.g. `"Unknown"`
  - `data[].location` — Location — e.g. `"Unknown Location"`
  - `data[].device` — Device — e.g. `"api-doc-probe"`

#### 56. DELETE `/api/user/sessions/{id}`

- **App me call hogi?** Haan — Phase 1 — Kisi device ko logout.
- **Web route:** Security (password, 2FA, devices) — `/settings-security`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `SessionController@destroy` — `core/app/Http/Controllers/User/SessionController.php:73-94`
- **Kaam:** Ye API record delete karti hai. Client portal me **Security (password, 2FA, devices), Login activities** screen par use hoti hai (`/settings-security, /settings-activities`); frontend me `revokeSession` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`

#### 57. GET `/api/user/settings/google-otp/status`

- **App me call hogi?** Haan — Phase 1 — 2FA on/off status (generate/verify/disable app me already hai).
- **Web route:** Security (password, 2FA, devices) — `/settings-security`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `GoogleAuthController@getOTPStatus` — `core/app/Http/Controllers/User/GoogleAuthController.php:509-526`
- **Kaam:** Ye API data laati hai. Client portal me **Security (password, 2FA, devices)** screen par use hoti hai (`/settings-security`); frontend me `checkOTPStatus` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.google_otp_enabled` — User ne Google Authenticator (2FA) chalu kiya hai ya nahi — e.g. `false`
  - `data.google_otp_required` — Login / transaction par Google OTP maangna zaroori hai ya nahi — e.g. `false`

#### 58. GET `/api/user/robot-trading-status`

- **App me call hogi?** Optional — Phase 3 — Robot trading API key status.
- **Web route:** Security (password, 2FA, devices) — `/settings-security`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `RobotTradingController@getStatus` — `core/app/Http/Controllers/User/RobotTradingController.php:24-66`
- **Kaam:** Ye API data laati hai. Client portal me **Security (password, 2FA, devices)** screen par use hoti hai (`/settings-security`); frontend me `fetchRobotTradingStatus` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.robot_trading_allowed` — User ko robot (API) trading ki permission hai ya nahi — e.g. `false`
  - `data.has_api_key` — Kya api key hai? (`true` / `false`) — e.g. `false`
  - `data.key_prefix` — Key prefix (text) — e.g. `""`
  - `data.account_numbers` — Account numbers ki list

#### 59. POST `/api/user/robot-trading-api-key`

- **App me call hogi?** Optional — Phase 3 — API key create.
- **Web route:** Security (password, 2FA, devices) — `/settings-security`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `RobotTradingController@createKey` — `core/app/Http/Controllers/User/RobotTradingController.php:73-100`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Security (password, 2FA, devices)** screen par use hoti hai (`/settings-security`); frontend me `createRobotTradingKey` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.api_key` — Api key (text) — e.g. `"tk_GGurjzv7tK8k4uVgWVPlW0V…"`
  - `data.key_prefix` — Key prefix (text) — e.g. `"tk_GGurjzv7t"`

#### 60. POST `/api/user/robot-trading-api-key/regenerate`

- **App me call hogi?** Optional — Phase 3 — API key regenerate.
- **Web route:** Security (password, 2FA, devices) — `/settings-security`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `RobotTradingController@regenerateKey` — `core/app/Http/Controllers/User/RobotTradingController.php:106-130`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Security (password, 2FA, devices)** screen par use hoti hai (`/settings-security`); frontend me `regenerateRobotTradingKey` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.api_key` — Api key (text) — e.g. `"tk_HNd9p4V91azJ1TynHkS4TDz…"`
  - `data.key_prefix` — Key prefix (text) — e.g. `"tk_HNd9p4V91"`

#### 61. DELETE `/api/user/robot-trading-api-key`

- **App me call hogi?** Optional — Phase 3 — API key delete.
- **Web route:** Security (password, 2FA, devices) — `/settings-security`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `RobotTradingController@revokeKey` — `core/app/Http/Controllers/User/RobotTradingController.php:136-144`
- **Kaam:** Ye API record delete karti hai. Client portal me **Security (password, 2FA, devices)** screen par use hoti hai (`/settings-security`); frontend me `revokeRobotTradingKey` se call hoti hai.
- **Request params:** NONE

### Settings

#### 62. GET `/api/user/settings/activitylog`

- **App me call hogi?** Haan — Phase 2 — Login activities screen.
- **Web route:** Login activities — `/settings-activities`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `UserController@getActivitiesLog` — `core/app/Http/Controllers/User/UserController.php:1275-1490`
- **Kaam:** Ye API data laati hai. Client portal me **Login activities** screen par use hoti hai (`/settings-activities`); frontend me `loadActivities`, `loadMoreActivities` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.activities` — Activities ki list
  - `data.activities[].id` — Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain…
  - `data.activities[].type` — Type — e.g. `"login"`
  - `data.activities[].title` — Title — e.g. `"Successful Login"`
  - `data.activities[].description` — Description — e.g. `"Logged in from Windows PC"`
  - `data.activities[].timestamp` — Timestamp (text) — e.g. `"2026-09-24T13:44:22+00:00"`
  - `data.activities[].ip_address` — IP address — e.g. `"171.61.161.118"`
  - `data.activities[].location` — Location — e.g. `"Ahmedabad, Gujarat, India"`
  - `data.activities[].device` — Device — e.g. `"Windows PC"`
  - `data.activities[].status` — Request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. Kuch purani …

#### 63. GET `/api/user/email-preferences`

- **App me call hogi?** Optional — Phase 3 — Email notification preferences.
- **Web route:** Notification preferences — `/settings-notifications`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `EmailPreferenceController@show` — `core/Modules/EmailCenter/Http/Controllers/Api/EmailPreferenceController.php:33-55`
- **Kaam:** Ye API data laati hai. Client portal me **Notification preferences** screen par use hoti hai (`/settings-notifications`); frontend me `loadPreferences` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.marketing` — Marketing (true / false) — e.g. `true`
  - `data.newsletters` — Newsletters (true / false) — e.g. `true`
  - `data.product_updates` — Product updates (true / false) — e.g. `true`
  - `data.globally_unsubscribed` — Globally unsubscribed (true / false) — e.g. `false`
  - `data.email` — Email address — e.g. `"user@gmail.com"`

#### 64. POST `/api/user/email-preferences`

- **App me call hogi?** Optional — Phase 3 — Email preferences save.
- **Web route:** Notification preferences — `/settings-notifications`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `EmailPreferenceController@update` — `core/Modules/EmailCenter/Http/Controllers/Api/EmailPreferenceController.php:61-102`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Notification preferences** screen par use hoti hai (`/settings-notifications`); frontend me `savePreferences` se call hoti hai.
- **Request params:**
  - `marketing` (boolean, required: Conditional) — Marketing (true / false) — rule: `sometimes, boolean`
  - `newsletters` (boolean, required: Conditional) — Newsletters (true / false) — rule: `sometimes, boolean`
  - `product_updates` (boolean, required: Conditional) — Product updates (true / false) — rule: `sometimes, boolean`
- **Response keys (main):**
  - `data.marketing` — Marketing (true / false) — e.g. `true`
  - `data.newsletters` — Newsletters (true / false) — e.g. `true`
  - `data.product_updates` — Product updates (true / false) — e.g. `true`
  - `data.globally_unsubscribed` — Globally unsubscribed (true / false) — e.g. `false`
  - `data.email` — Email address — e.g. `"user@gmail.com"`

### Settings — Bank

#### 65. DELETE `/api/user/withdrawal/delete/{id}`

- **App me call hogi?** Haan — Phase 2 — Saved bank / withdrawal method delete.
- **Web route:** Bank / withdrawal accounts — `/settings-bank-accounts`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `FinanceController@destroy` — `core/app/Http/Controllers/User/FinanceController.php:544-562`
- **Kaam:** Ye API record delete karti hai. Client portal me **Bank / withdrawal accounts** screen par use hoti hai (`/settings-bank-accounts`); frontend me `removeMethod` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`

#### 66. POST `/api/user/utility/ifsc-code`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — India bank IFSC verify (India brokers).
- **Web route:** Bank / withdrawal accounts — `/settings-bank-accounts`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `FinanceController@verifyIfscCode` — `core/app/Http/Controllers/User/FinanceController.php:4113-4133`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Bank / withdrawal accounts** screen par use hoti hai (`/settings-bank-accounts`); frontend me `verifyIfscCode` se call hoti hai.
- **Request params:**
  - `ifscCode` (string, required: No) — Ifsc Code (text)
- **Response keys (main):**
  - `data.data` — Asli data (object, list ya khaali)
  - `data.data.MICR` — MICR (text) — e.g. `"400002010"`
  - `data.data.BRANCH` — BRANCH (text) — e.g. `"MUMBAI MAIN"`
  - `data.data.ADDRESS` — ADDRESS (text) — e.g. `"MUMBAI"`
  - `data.data.STATE` — STATE (text) — e.g. `"MAHARASHTRA"`
  - `data.data.CONTACT` — CONTACT (text) — e.g. `""`
  - `data.data.UPI` — UPI (true / false) — e.g. `true`
  - `data.data.RTGS` — RTGS (true / false) — e.g. `true`
  - `data.data.CITY` — CITY (text) — e.g. `"GREATER BOMBAY"`
  - `data.data.CENTRE` — CENTRE (text) — e.g. `"MUMBAI"`

#### 67. GET `/api/user/image-proxy/{id}`

- **App me call hogi?** Haan — Phase 2 — Withdrawal method ka uploaded proof image dikhana.
- **Web route:** Withdrawal details — `/settings-withdrawal-details/:id`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `FinanceController@serveImageProxy` — `core/app/Http/Controllers/User/FinanceController.php:1554-1593`
- **Kaam:** Ye API data laati hai. Client portal me **Withdrawal details** screen par use hoti hai (`/settings-withdrawal-details/:id`); frontend me `loadImage` se call hoti hai.
- **Request params:**
  - `id` (string, required: Yes) — (path) Is record ka database id — detail / edit / delete wali APIs me yahi bhejte hain — rule: `URL path parameter`

### KYC

#### 68. POST `/api/user/kyc/sumsub/token`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Sumsub SDK ka access token. Native Sumsub SDK chahiye (naya package).
- **Web route:** KYC — `/kyc`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `SumsubKycController@token` — `core/app/Http/Controllers/User/SumsubKycController.php:22-41`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **KYC** screen par use hoti hai (`/kyc`); frontend me `fetchToken` se call hoti hai.
- **Request params:** NONE

#### 69. POST `/api/user/kyc/sumsub/refresh`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Sumsub token refresh.
- **Web route:** KYC — `/kyc`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `SumsubKycController@refresh` — `core/app/Http/Controllers/User/SumsubKycController.php:48-68`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **KYC** screen par use hoti hai (`/kyc`); frontend me `refreshProviderState` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.outcome` — Outcome (text) — e.g. `"not_sumsub"`

#### 70. POST `/api/user/kyc/shufti/start`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Shufti Pro verification start (URL WebView me).
- **Web route:** KYC — `/kyc`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `ShuftiKycController@start` — `core/app/Http/Controllers/User/ShuftiKycController.php:56-150`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **KYC** screen par use hoti hai (`/kyc`); frontend me `start` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.verification` — Verification (text) — e.g. `"..."`
  - `data.reused` — Reused (text) — e.g. `"..."`

#### 71. GET `/api/user/kyc/shufti/status`

- **App me call hogi?** Haan, agar broker ke paas feature on hai — Shufti status poll.
- **Web route:** KYC — `/kyc`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `ShuftiKycController@status` — `core/app/Http/Controllers/User/ShuftiKycController.php:158-179`
- **Kaam:** Ye API data laati hai. Client portal me **KYC** screen par use hoti hai (`/kyc`); frontend me `refresh` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.verification` — Verification (text) — e.g. `""`

#### 72. POST `/api/user/mobile-verification/send`

- **App me call hogi?** Haan — Phase 2 — Mobile number OTP send.
- **Web route:** KYC — `/kyc`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `MobileVerificationController@send` — `core/app/Http/Controllers/User/MobileVerificationController.php:45-73`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **KYC, Scratch card promotion** screen par use hoti hai (`/kyc, /promotion`); frontend me `send` se call hoti hai.
- **Request params:** NONE
- **Response keys (main):**
  - `data.verified` — Verified (true / false) — e.g. `true`

#### 73. POST `/api/user/mobile-verification/verify`

- **App me call hogi?** Haan — Phase 2 — Mobile OTP verify.
- **Web route:** KYC — `/kyc`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `MobileVerificationController@verify` — `core/app/Http/Controllers/User/MobileVerificationController.php:75-117`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **KYC, Scratch card promotion** screen par use hoti hai (`/kyc, /promotion`); frontend me `verify` se call hoti hai.
- **Request params:**
  - `otp` (string, required: Yes) — User ko mail / SMS par aaya OTP — rule: `required|string|min:4|max:8`
- **Response keys (main):**
  - `data.verified` — Verified (true / false) — e.g. `true`

### KYC — Documents

#### 74. GET `/api/user/kyc-image-proxy/{documentId}`

- **App me call hogi?** Haan — Phase 2 — Uploaded KYC document preview.
- **Web route:** Documents — `/settings-documents`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `KYCController@serveKycImageProxy` — `core/app/Http/Controllers/User/KYCController.php:1573-1612`
- **Kaam:** Ye API data laati hai. Client portal me **Documents** screen par use hoti hai (`/settings-documents`); frontend me `loadDocumentImage` se call hoti hai.
- **Request params:**
  - `documentId` (string, required: Yes) — (path) Document Id (text) — rule: `URL path parameter`

#### 75. POST `/api/user/kyc/documents/upload-chunk`

- **App me call hogi?** Optional — Phase 3 — Bade file (PDF/video) ka chunk upload. Images compress hokar normal upload me chal jaati hain.
- **Web route:** Documents — `/settings-documents`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `KYCController@uploadChunk` — `core/app/Http/Controllers/User/KYCController.php:724-778`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Documents** screen par use hoti hai (`/settings-documents`); frontend me `processFile`, `handlePaste` se call hoti hai.
- **Request params:**
  - `chunk` (file, required: Yes) — Chunk (text) — rule: `required|file`
  - `chunkIndex` (integer, required: Yes) — Chunk Index (text) — rule: `required|integer|min:0`
  - `totalChunks` (integer, required: Yes) — Total Chunks (text) — rule: `required|integer|min:1`
  - `fileName` (string, required: Yes) — File Name (text) — rule: `required|string`
  - `fileSize` (integer, required: Yes) — File Size (text) — rule: `required|integer`
  - `fileType` (string, required: Yes) — File Type (text) — rule: `required|string`
  - `document_type` (string, required: Yes) — Document type (text) — rule: `required|string`
  - `subdocument_type` (string, required: Yes) — Subdocument type (text) — rule: `required|string`
- **Response keys (main):**
  - `data.chunkIndex` — Chunk Index (text) — e.g. `"0"`
  - `data.totalChunks` — Total Chunks (text) — e.g. `"1"`
  - `data.uploadedChunks` — Uploaded Chunks (number) — e.g. `1`
  - `data.isComplete` — Is Complete (true / false) — e.g. `false`
  - `data.sessionId` — Session Id (text) — e.g. `"9_id_proof_back_d9819c26d6…"`

#### 76. POST `/api/user/kyc/documents/finalize-chunked`

- **App me call hogi?** Optional — Phase 3 — Chunk upload finish.
- **Web route:** Documents — `/settings-documents`
- **Auth:** Bearer token (`auth:sanctum`)
- **Backend:** `KYCController@finalizeChunkedUpload` — `core/app/Http/Controllers/User/KYCController.php:786-861`
- **Kaam:** Ye API naya kaam / request bhejti hai. Client portal me **Documents** screen par use hoti hai (`/settings-documents`); frontend me `processFile`, `handlePaste` se call hoti hai.
- **Request params:**
  - `sessionId` (string, required: Yes) — Session Id (text) — rule: `required|string`
  - `fileName` (string, required: Yes) — File Name (text) — rule: `required|string`
  - `fileSize` (integer, required: Yes) — File Size (number) — rule: `required|integer`
  - `document_type` (string, required: Yes) — Document type (text) — rule: `required|string`
  - `subdocument_type` (string, required: Yes) — Subdocument type (text) — rule: `required|string`
- **Response keys (main):**
  - `data.document_id` — document ka id — e.g. `90`
  - `data.documents_slug` — Documents folder ka code — e.g. `"UWNtb52I_571412"`

