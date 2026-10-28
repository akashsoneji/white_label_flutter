# Client Portal — Mobile app flow guide

Generated 2026-10-22. Har screen par kaunsi API, kis order me, kya bhejna hai aur value kahan se aati hai.
Har API ka poora detail (headers, params, response, har key ka matlab, errors): [client-portal-endpoints.md](client-portal-endpoints.md).

## Shuru karne se pehle (har app ke liye)

1. **Base URL** — broker ka CRM domain, jaise `https://crm.<broker>.com`. Saari APIs `{{baseUrl}}/api/...` par hain.
2. **App start** — sabse pehle [`GET /api/user/crm-settings`](client-portal-endpoints.md#get-api-user-crm-settings) call karo (token nahi chahiye). Isme `mobile_app_details.is_under_maintenance` (maintenance screen), `is_force_update` + `app_version` (update dikhana), company details aur feature settings aate hain.
3. **Login** — [`POST /api/user/login`](client-portal-endpoints.md#post-api-user-login) se `token` milta hai. Use secure storage me rakho.
4. **Har private API** — header bhejo: `Authorization: Bearer <token>`, `Accept: application/json`.
5. **401 aaye** (`{"message":"Unauthenticated","status":false}`) — token expire hai: token hatao, login screen par bhejo.
6. **Response padhna** — `success: true` = kaam hua, `data` me asli data. `success: false` = `message` user ko dikhao. 422 me `message` me pehla validation error hota hai.
7. **429** — bahut zyada requests; thodi der rukkar dobara try karo.
8. **IB Manager portal** ki APIs (`/api/ibm/...`) ka token alag middleware (`ibm.auth`) se check hota hai — wahi login token chalta hai jab user IB Manager ho.

## Ek API ka data dusri API me kaise jaata hai (example)

Internal Transfer screen: [`GET /api/user/internaltransfer`](client-portal-endpoints.md#get-api-user-internaltransfer) user ke accounts deta hai (`data.userMT5Accounts[]`) aur wallet (`data.wallet`).

- User "From" aur "To" me account chunta hai. Dropdown ki value = account ka `meta_account_number` (jaise `2000004`), wallet ke liye `wallet_id`.
- Wahi value [`POST /api/user/internaltransfer/request`](client-portal-endpoints.md#post-api-user-internaltransfer-request) me `from_account` / `to_account` banke jaati hai, saath me `amount`.
- `available_for_transfer` batata hai kitna bhej sakte hain; `has_credit` / `transfer_blocked_reason` se pata chalta hai transfer kyun ruk sakta hai — ye kisi API me nahi jaate, sirf screen par dikhte hain.
- Account ka `id` (database id, jaise `5`) is screen par kahin nahi bheja jaata — transfer hamesha account **number** se hota hai.

Har API ke response table me **Next API** column yahi batata hai.

## Screens

- [Auth (Login / Register / OTP / Password)](#auth-login-register-otp-password)
- [App shell (every logged-in page)](#app-shell-every-logged-in-page)
- [Dashboard](#dashboard)
- [Trading Accounts](#trading-accounts)
- [Trading Terminal](#trading-terminal)
- [Deposit](#deposit)
- [Withdrawal](#withdrawal)
- [Internal Transfer](#internal-transfer)
- [IB Dashboard (classic IB)](#ib-dashboard-classic-ib)
- [IB Manager Portal](#ib-manager-portal)
- [Transaction History](#transaction-history)
- [PAMM](#pamm)
- [Copy Trading](#copy-trading)
- [Tickets](#tickets)
- [Platforms](#platforms)
- [Settings](#settings)
- [Promotions & extras (header / dashboard links)](#promotions-extras-header-dashboard-links)

---

## Auth (Login / Register / OTP / Password)

User account banata hai, login karta hai, ya password bhool jaye to reset karta hai. Login ke baad mila `token` har private API me `Authorization: Bearer <token>` header me jaata hai.

### Login — `/login`

**User action par (button / form submit):**

1. [`GET /api/user/auth/google/redirect`](client-portal-endpoints.md#get-api-user-auth-google-redirect) — redirect — data laata hai. Kuch bhejna nahi hai.
2. [`POST /api/user/auth/google/verify-login-otp`](client-portal-endpoints.md#post-api-user-auth-google-verify-login-otp) — OTP verified successfully. Bhejo: `email` (email address); `otp_code` (otp code (mail ya google authenticator se)).
3. [`POST /api/user/login`](client-portal-endpoints.md#post-api-user-login) — login — request bhejta hai. Bhejo: `password` (password); `fcm_token` (push notification ke liye device ka fcm token); `device_type` (device ka type (android / ios / web)); `email` (email address).

### Register — `/register`

**Screen khulte hi (data load):**

1. [`GET /api/user`](client-portal-endpoints.md#get-api-user) — user — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/user/crm-settings`](client-portal-endpoints.md#get-api-user-crm-settings) — CRM settings retrieved successfully. Kuch bhejna nahi hai.
3. [`GET /api/user/json`](client-portal-endpoints.md#get-api-user-json) — json — data laata hai. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

4. [`GET /api/ibm/r/{code}`](client-portal-endpoints.md#get-api-ibm-r-code) — r — data laata hai. Bhejo: `code` ← [`GET /api/ibm/portal/links`](client-portal-endpoints.md#get-api-ibm-portal-links) ka `data.links[].code` ya [`GET /api/ibm/portal/links/{id}/clients`](client-portal-endpoints.md#get-api-ibm-portal-links-id-clients) ka `data.link.code`.

**User action par (button / form submit):**

5. [`GET /api/user/auth/google/redirect`](client-portal-endpoints.md#get-api-user-auth-google-redirect) — redirect — data laata hai. Kuch bhejna nahi hai.
6. [`POST /api/user/ib/track-sponsor-visit`](client-portal-endpoints.md#post-api-user-ib-track-sponsor-visit) — Visit tracked successfully. Bhejo: `sponsorcode` (sponsorcode (null)).
7. [`POST /api/user/register`](client-portal-endpoints.md#post-api-user-register) — register — request bhejta hai. Bhejo: `email` (email address).

### OTP Verification (signup) — `/otp-verification`

**User action par (button / form submit):**

1. [`POST /api/user/register`](client-portal-endpoints.md#post-api-user-register) — register — request bhejta hai. Bhejo: `email` (email address).

### Complete Registration (Google signup) — `/complete-registration`

**Screen khulte hi (data load):**

1. [`GET /api/user/json`](client-portal-endpoints.md#get-api-user-json) — json — data laata hai. Kuch bhejna nahi hai.

**User action par (button / form submit):**

2. [`POST /api/user/auth/google/check-mobile`](client-portal-endpoints.md#post-api-user-auth-google-check-mobile) — check mobile — request bhejta hai. Bhejo: `mobile` (mobile number (country code ke bina)); `country_code` (phone ka country code (jaise `+91`)).
3. [`POST /api/user/auth/google/complete-registration`](client-portal-endpoints.md#post-api-user-auth-google-complete-registration) — complete registration — request bhejta hai. Bhejo: `mobile` (mobile number (country code ke bina)); `country_code` (phone ka country code (jaise `+91`)); `password` (password); `otp_code` (otp code (mail ya google authenticator se)); `otp_verification_type` (otp verification type (null)).

### Forgot Password — `/forgot-password`

**User action par (button / form submit):**

1. [`POST /api/user/password/forgot`](client-portal-endpoints.md#post-api-user-password-forgot) — OTP sent to your email.. Bhejo: `email` (email address).

### Verify OTP (password reset) — `/verify-otp`

**User action par (button / form submit):**

1. [`POST /api/user/password/forgot`](client-portal-endpoints.md#post-api-user-password-forgot) — OTP sent to your email.. Bhejo: `email` (email address).
2. [`POST /api/user/password/verify-otp`](client-portal-endpoints.md#post-api-user-password-verify-otp) — OTP verified.. Bhejo: `email` (email address); `otp` (user ko mail / sms par aaya otp).

### Reset Password — `/reset-password`

**User action par (button / form submit):**

1. [`POST /api/user/password/reset`](client-portal-endpoints.md#post-api-user-password-reset) — Password reset successfully.. Bhejo: `email` (email address); `otp` (user ko mail / sms par aaya otp); `password` (password); `password_confirmation` (password dobara (match hona chahiye)).
2. [`POST /api/user/password/reset-token`](client-portal-endpoints.md#post-api-user-password-reset-token) — Password reset successfully.. Bhejo: `token` (token (null)); `email` (email address); `password` (password); `password_confirmation` (password dobara (match hona chahiye)).

### Google OAuth callback — `/auth/google/callback`

**User action par (button / form submit):**

1. [`GET /api/user/auth/google/callback`](client-portal-endpoints.md#get-api-user-auth-google-callback) — callback — data laata hai. Kuch bhejna nahi hai.

### Auto-login from landing site — `/auth/from-net`

**User action par (button / form submit):**

1. [`POST /api/user/login`](client-portal-endpoints.md#post-api-user-login) — login — request bhejta hai. Bhejo: `password` (password); `fcm_token` (push notification ke liye device ka fcm token); `device_type` (device ka type (android / ios / web)); `email` (email address).

### SSO verify — `/user/sso/verify/:token`

Is screen par koi API call nahi hoti.

### Invite / Referral link — `/user/invite/:referral_code`

**User action par (button / form submit):**

1. [`POST /api/user/ib/track-sponsor-visit`](client-portal-endpoints.md#post-api-user-ib-track-sponsor-visit) — Visit tracked successfully. Bhejo: `sponsorcode` (sponsorcode (null)).

---

## App shell (every logged-in page)

Login ke baad har screen par ye APIs background me chalti hain: user profile, notifications, settings, maintenance check. App start hote hi inhe ek baar call karo.

### App root — `(all)`

**Screen khulte hi (data load):**

1. [`GET /api/user/live-chat`](client-portal-endpoints.md#get-api-user-live-chat) — Live chat settings retrieved successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/notices/active`](client-portal-endpoints.md#get-api-user-notices-active) — active — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/user/session/check`](client-portal-endpoints.md#get-api-user-session-check) — Session is active. Kuch bhejna nahi hai.

### Left sidebar — `(all)`

**Screen khulte hi (data load):**

1. [`GET /api/user/ib/status`](client-portal-endpoints.md#get-api-user-ib-status) — IB status retrieved successfully. Kuch bhejna nahi hai.

### Top header — `(all)`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/client/system`](client-portal-endpoints.md#get-api-ibm-client-system) — System resolved.. Kuch bhejna nahi hai.
2. [`GET /api/user/dashboard`](client-portal-endpoints.md#get-api-user-dashboard) — User dashboard data retrieved successfully.. Kuch bhejna nahi hai.
3. [`GET /api/user/notifications`](client-portal-endpoints.md#get-api-user-notifications) — notifications — data laata hai. Kuch bhejna nahi hai.
4. [`GET /api/user/notifications/markasread`](client-portal-endpoints.md#get-api-user-notifications-markasread) — Notifications marked as read successfully. Kuch bhejna nahi hai.
5. [`GET /api/user/wallet`](client-portal-endpoints.md#get-api-user-wallet) — wallet Details. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

6. [`GET /api/user/notifications/markasread/{id}`](client-portal-endpoints.md#get-api-user-notifications-markasread-id) — markasread — data laata hai. Bhejo: `id` (is record ka database id).
7. [`GET /api/user/notifications/mt5-credentials/{id}`](client-portal-endpoints.md#get-api-user-notifications-mt5-credentials-id) — mt5 credentials — data laata hai. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

8. [`POST /api/user/logout`](client-portal-endpoints.md#post-api-user-logout) — User logged out successfully. Bhejo: `fcm_token` (push notification ke liye device ka fcm token).
9. [`POST /api/user/notifications/mt5-credentials/{id}/ack`](client-portal-endpoints.md#post-api-user-notifications-mt5-credentials-id-ack) — ack — request bhejta hai. Bhejo: `id` (is record ka database id).

### Router guard (module check before each page) — `(all)`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/client/system`](client-portal-endpoints.md#get-api-ibm-client-system) — System resolved.. Kuch bhejna nahi hai.
2. [`GET /api/user/enabled-modules`](client-portal-endpoints.md#get-api-user-enabled-modules) — Enabled modules retrieved. Kuch bhejna nahi hai.
3. [`GET /api/user/ib/status`](client-portal-endpoints.md#get-api-user-ib-status) — IB status retrieved successfully. Kuch bhejna nahi hai.
4. [`GET /api/user/wallet`](client-portal-endpoints.md#get-api-user-wallet) — wallet Details. Kuch bhejna nahi hai.

**User action par (button / form submit):**

5. [`POST /api/user/current-page`](client-portal-endpoints.md#post-api-user-current-page) — current page — request bhejta hai. Bhejo: `route` (route (null)).

### Mobile navigation — `(all)`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/client/system`](client-portal-endpoints.md#get-api-ibm-client-system) — System resolved.. Kuch bhejna nahi hai.
2. [`GET /api/user/ib/status`](client-portal-endpoints.md#get-api-user-ib-status) — IB status retrieved successfully. Kuch bhejna nahi hai.
3. [`GET /api/user/live-chat`](client-portal-endpoints.md#get-api-user-live-chat) — Live chat settings retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

4. [`POST /api/user/logout`](client-portal-endpoints.md#post-api-user-logout) — User logged out successfully. Bhejo: `fcm_token` (push notification ke liye device ka fcm token).

### Page banners — `(all)`

**Screen khulte hi (data load):**

1. [`GET /api/user/banners`](client-portal-endpoints.md#get-api-user-banners) — Active banners.. Kuch bhejna nahi hai.
2. [`GET /api/user/enabled-modules`](client-portal-endpoints.md#get-api-user-enabled-modules) — Enabled modules retrieved. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/user/banners/track`](client-portal-endpoints.md#post-api-user-banners-track) — Event tracked.. Bhejo: `banner_id` (banner ka id); `event_type` (event type (null)).

---

## Dashboard

Home screen: accounts ka summary, balance, recent activity, banners.

### Dashboard — `/dashboard`

**Screen khulte hi (data load):**

1. [`GET /api/user/deposit/by-reference`](client-portal-endpoints.md#get-api-user-deposit-by-reference) — by reference — data laata hai. Bhejo: `reference` ← [`GET /api/user/finance-activity`](client-portal-endpoints.md#get-api-user-finance-activity) ka `data[].reference_number`.
2. [`GET /api/user/finance-activity`](client-portal-endpoints.md#get-api-user-finance-activity) — Transactions fetched successfully. Kuch bhejna nahi hai.
3. [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) — Trading accounts retrieved successfully. Kuch bhejna nahi hai.
4. [`GET /api/user/prop-coupons`](client-portal-endpoints.md#get-api-user-prop-coupons) — prop coupons — data laata hai. Kuch bhejna nahi hai.
5. [`GET /api/user/settings/profile`](client-portal-endpoints.md#get-api-user-settings-profile) — User profile data retrieved successfully.. Kuch bhejna nahi hai.

**User action par (button / form submit):**

6. [`POST /api/user/mt5accounts/changeleverage`](client-portal-endpoints.md#post-api-user-mt5accounts-changeleverage) — Leverage change request processed successfully. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_id` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_type` (account ka type (live / demo / mt5)); `leverage` (naya leverage (jaise 100 = 1:100)).
7. [`POST /api/user/mt5accounts/changepassword`](client-portal-endpoints.md#post-api-user-mt5accounts-changepassword) — changepassword — request bhejta hai. Bhejo: `newPassword` (naya password); `newPassword.min` (new password.min (null)); `newPassword.max` (new password.max (null)); `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_id` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.
8. [`POST /api/user/mt5accounts/changePrimaryAccount`](client-portal-endpoints.md#post-api-user-mt5accounts-changeprimaryaccount) — Primary account changed successfully. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.
9. [`POST /api/user/mt5accounts/setbalance`](client-portal-endpoints.md#post-api-user-mt5accounts-setbalance) — setbalance — request bhejta hai. Bhejo: `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).
10. [`POST /api/user/mt5accounts/setnickname`](client-portal-endpoints.md#post-api-user-mt5accounts-setnickname) — Nick Name updated successfully. Bhejo: `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `mt5_nick_name` (user ka diya hua account nickname).
11. [`POST /api/user/price-alerts/update-fcm-token`](client-portal-endpoints.md#post-api-user-price-alerts-update-fcm-token) — FCM token updated successfully. Bhejo: `fcm_token` (push notification ke liye device ka fcm token); `device_type` (device ka type (android / ios / web)); `mt5_account_id` (mt5 account (number ya id).

---

## Trading Accounts

User ke MT5 accounts: list, naya account, leverage / password / nickname badalna.

### Trading Accounts — `/trading-accounts`

**Screen khulte hi (data load):**

1. [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) — Trading accounts retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

2. [`POST /api/user/mt5accounts/changeleverage`](client-portal-endpoints.md#post-api-user-mt5accounts-changeleverage) — Leverage change request processed successfully. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_id` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_type` (account ka type (live / demo / mt5)); `leverage` (naya leverage (jaise 100 = 1:100)).
3. [`POST /api/user/mt5accounts/changepassword`](client-portal-endpoints.md#post-api-user-mt5accounts-changepassword) — changepassword — request bhejta hai. Bhejo: `newPassword` (naya password); `newPassword.min` (new password.min (null)); `newPassword.max` (new password.max (null)); `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_id` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.
4. [`POST /api/user/mt5accounts/changePrimaryAccount`](client-portal-endpoints.md#post-api-user-mt5accounts-changeprimaryaccount) — Primary account changed successfully. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.
5. [`POST /api/user/mt5accounts/create`](client-portal-endpoints.md#post-api-user-mt5accounts-create) — Live account created successfully. Bhejo: `group_id` (group (account type / plan group) ka id); `leverage` (naya leverage (jaise 100 = 1:100)); `main_password` (main password (null)); `investor_password` (investor password (null)).
6. [`POST /api/user/mt5accounts/plandetails`](client-portal-endpoints.md#post-api-user-mt5accounts-plandetails) — Groups retrieved successfully. Bhejo: `is_live` (kya live hai? (`true` / `false`)); `trading_platform` (platform (mt5 / web_trader)).
7. [`POST /api/user/mt5accounts/resetinvestorpassword`](client-portal-endpoints.md#post-api-user-mt5accounts-resetinvestorpassword) — resetinvestorpassword — request bhejta hai. Bhejo: `newPassword` (naya password); `newPassword.min` (new password.min (null)); `newPassword.max` (new password.max (null)); `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_id` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.
8. [`POST /api/user/mt5accounts/setbalance`](client-portal-endpoints.md#post-api-user-mt5accounts-setbalance) — setbalance — request bhejta hai. Bhejo: `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).
9. [`POST /api/user/mt5accounts/setnickname`](client-portal-endpoints.md#post-api-user-mt5accounts-setnickname) — Nick Name updated successfully. Bhejo: `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `mt5_nick_name` (user ka diya hua account nickname).

---

## Trading Terminal

Web trader: symbols, price, chart, order lagana, position band karna, TP/SL.

### Trading Terminal (launcher) — `/trading-terminal`

**User action par (button / form submit):**

1. [`DELETE /api/user/trade/chart-state/{param}`](client-portal-endpoints.md#delete-api-user-trade-chart-state-param) — chart state — delete karta hai. Bhejo: `param` (param (null)).
2. [`POST /api/user/trade/new-order`](client-portal-endpoints.md#post-api-user-trade-new-order) — new order — request bhejta hai. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `volume` (lot size); `type` (type); `mt5_account.required` (mt5 account.required (null)); `volume.min` (volume.min (null)).

### Web Trader (terminal) — `/trading`

**Screen khulte hi (data load):**

1. [`GET /api/user`](client-portal-endpoints.md#get-api-user) — user — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/user/economic-calendar`](client-portal-endpoints.md#get-api-user-economic-calendar) — Economic calendar retrieved successfully. Bhejo: `from` (is page ki pehli row ka number); `to` (is page ki aakhri row ka number); `country` (country ka id (countries list se)); `currency` (currency (jaise `usd`, `usc` = us cent)); `importance` (importance (null)); `provider` (provider (null)); `limit` (limit (null)).
3. [`GET /api/user/modules`](client-portal-endpoints.md#get-api-user-modules) — Module list retrieved. Kuch bhejna nahi hai.
4. [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) — Trading accounts retrieved successfully. Kuch bhejna nahi hai.
5. [`GET /api/user/price-alerts`](client-portal-endpoints.md#get-api-user-price-alerts) — Price alerts retrieved successfully. Kuch bhejna nahi hai.
6. [`GET /api/user/trade/marketwatch`](client-portal-endpoints.md#get-api-user-trade-marketwatch) — Marketwatch retrieved successfully. Kuch bhejna nahi hai.
7. [`GET /api/user/trade/tradehistory`](client-portal-endpoints.md#get-api-user-trade-tradehistory) — Trade history fetched successfully. Bhejo: `login` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/bonus`](client-portal-endpoints.md#get-api-user-bonus) ka `data.mt5Accounts[].meta_account_number`; `page` (page number); `per_page` (ek page me kitni rows).
8. [`GET /api/user/tradingaccounts/sync`](client-portal-endpoints.md#get-api-user-tradingaccounts-sync) — sync — data laata hai. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

9. [`GET /api/user/trade/chart-store/{param}`](client-portal-endpoints.md#get-api-user-trade-chart-store-param) — chart store — data laata hai. Bhejo: `param` (param (null)).

**User action par (button / form submit):**

10. [`DELETE /api/user/price-alerts/{id}`](client-portal-endpoints.md#delete-api-user-price-alerts-id) — Price alert deleted successfully. Bhejo: `id` (is record ka database id).
11. [`DELETE /api/user/trade/chart-state/{param}`](client-portal-endpoints.md#delete-api-user-trade-chart-state-param) — chart state — delete karta hai. Bhejo: `param` (param (null)).
12. [`GET /api/user/trade/tradehistory/export`](client-portal-endpoints.md#get-api-user-trade-tradehistory-export) — export — data laata hai. Kuch bhejna nahi hai.
13. [`POST /api/user/mt5accounts/changeleverage`](client-portal-endpoints.md#post-api-user-mt5accounts-changeleverage) — Leverage change request processed successfully. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_id` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_type` (account ka type (live / demo / mt5)); `leverage` (naya leverage (jaise 100 = 1:100)).
14. [`POST /api/user/mt5accounts/changepassword`](client-portal-endpoints.md#post-api-user-mt5accounts-changepassword) — changepassword — request bhejta hai. Bhejo: `newPassword` (naya password); `newPassword.min` (new password.min (null)); `newPassword.max` (new password.max (null)); `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `account_id` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.
15. [`POST /api/user/mt5accounts/changePrimaryAccount`](client-portal-endpoints.md#post-api-user-mt5accounts-changeprimaryaccount) — Primary account changed successfully. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.
16. [`POST /api/user/mt5accounts/setbalance`](client-portal-endpoints.md#post-api-user-mt5accounts-setbalance) — setbalance — request bhejta hai. Bhejo: `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).
17. [`POST /api/user/price-alerts`](client-portal-endpoints.md#post-api-user-price-alerts) — Price alert created successfully. Bhejo: `mt5_account_id` (mt5 account (number ya id); `meta_account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `target_price` (price alert ka target price); `condition` (alert kab chale: `above` (upar jaye) / `below` (neeche aaye)); `fcm_token` (push notification ke liye device ka fcm token); `device_type` (device ka type (android / ios / web)); `message` (server ka message).
18. [`POST /api/user/price-alerts/update-fcm-token`](client-portal-endpoints.md#post-api-user-price-alerts-update-fcm-token) — FCM token updated successfully. Bhejo: `fcm_token` (push notification ke liye device ka fcm token); `device_type` (device ka type (android / ios / web)); `mt5_account_id` (mt5 account (number ya id).
19. [`POST /api/user/trade/chart-state`](client-portal-endpoints.md#post-api-user-trade-chart-state) — chart state — request bhejta hai. Kuch bhejna nahi hai.
20. [`POST /api/user/trade/chart-store`](client-portal-endpoints.md#post-api-user-trade-chart-store) — Chart saved.. Bhejo: `scope` (scope (null)); `state` (state ka id).
21. [`POST /api/user/trade/closePendingOrder`](client-portal-endpoints.md#post-api-user-trade-closependingorder) — close Pending Order — request bhejta hai. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `order_ids` (order ke ids ki list).
22. [`POST /api/user/trade/closePositionByPositionId`](client-portal-endpoints.md#post-api-user-trade-closepositionbypositionid) — close Position By Position Id — request bhejta hai. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `position_id` (open position ka id); `position_ids` (position ke ids ki list); `position_ids.*` (position ids.* (null)); `volume` (lot size).
23. [`POST /api/user/trade/marketwatch`](client-portal-endpoints.md#post-api-user-trade-marketwatch) — Marketwatch created/updated successfully. Bhejo: `symbols` (symbols (null)).
24. [`POST /api/user/trade/new-order`](client-portal-endpoints.md#post-api-user-trade-new-order) — new order — request bhejta hai. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `volume` (lot size); `type` (type); `mt5_account.required` (mt5 account.required (null)); `volume.min` (volume.min (null)).
25. [`POST /api/user/trade/update-pending-order-tp-sl`](client-portal-endpoints.md#post-api-user-trade-update-pending-order-tp-sl) — update pending order tp sl — request bhejta hai. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `order_id` (order ka id); `stop_loss` (stop loss (null)); `take_profit` (take profit (null)); `price` (price (null)).
26. [`POST /api/user/trade/update-tp-sl`](client-portal-endpoints.md#post-api-user-trade-update-tp-sl) — update tp sl — request bhejta hai. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `position_id` (open position ka id); `stop_loss` (stop loss (null)); `take_profit` (take profit (null)).
27. [`PUT /api/user/price-alerts/{id}`](client-portal-endpoints.md#put-api-user-price-alerts-id) — Price alert updated successfully. Bhejo: `id` (is record ka database id); `symbol` (instrument (jaise xauusd, eurusd)); `target_price` (price alert ka target price); `condition` (alert kab chale: `above` (upar jaye) / `below` (neeche aaye)); `fcm_token` (push notification ke liye device ka fcm token); `device_type` (device ka type (android / ios / web)); `message` (server ka message); `is_active` (active hai ya nahi).

### Mobile WebView chart — `/mobile-chart`

**User action par (button / form submit):**

1. [`DELETE /api/user/trade/chart-state/{param}`](client-portal-endpoints.md#delete-api-user-trade-chart-state-param) — chart state — delete karta hai. Bhejo: `param` (param (null)).
2. [`POST /api/user/mt5accounts/changePrimaryAccount`](client-portal-endpoints.md#post-api-user-mt5accounts-changeprimaryaccount) — Primary account changed successfully. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.
3. [`POST /api/user/trade/new-order`](client-portal-endpoints.md#post-api-user-trade-new-order) — new order — request bhejta hai. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `volume` (lot size); `type` (type); `mt5_account.required` (mt5 account.required (null)); `volume.min` (volume.min (null)).

---

## Deposit

Paisa daalna: method chuno → amount + account → request bhejo → history me status dekho.

### Deposit (methods) — `/deposit`

**Screen khulte hi (data load):**

1. [`GET /api/user/deposit`](client-portal-endpoints.md#get-api-user-deposit) — Deposit methods retrieved successfully. Kuch bhejna nahi hai.

### Deposit request / history — `/deposit-request`

**Screen khulte hi (data load):**

1. [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) — Trading accounts retrieved successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/regulation`](client-portal-endpoints.md#get-api-user-regulation) — Regulation details fetched successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/user/deposit/{methodSlug}`](client-portal-endpoints.md#get-api-user-deposit-methodslug) — Deposit method retrieved successfully. Bhejo: `methodSlug` ← [`GET /api/user/deposit`](client-portal-endpoints.md#get-api-user-deposit) ka `data[].deposit_slug`.

**User action par (button / form submit):**

4. [`POST /api/user/deposit/cregis`](client-portal-endpoints.md#post-api-user-deposit-cregis) — cregis — request bhejta hai. Bhejo: `gateway_method_id` (gateway method ka id); `mt5_account_id` (mt5 account (number ya id); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `chain_id` (chain ka id); `crypto_network` (crypto network (null)).
5. [`POST /api/user/deposit/depositrequest`](client-portal-endpoints.md#post-api-user-deposit-depositrequest) — Deposit request created successfully. Bhejo: `mt5_account_id` (mt5 account (number ya id); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `gateway_method_id` (gateway method ka id); `utr_referce` (utr referce (null)); `user_input_net_amount` (user input net ki raqam); `user_input_currency` (user input currency (null)); `client_note` (client note (null)).
6. [`POST /api/user/deposit/dynamic/{gatewaySlug}`](client-portal-endpoints.md#post-api-user-deposit-dynamic-gatewayslug) — dynamic — request bhejta hai. Bhejo: `gatewaySlug` (gateway slug (null)); `gateway_method_id` (gateway method ka id); `mt5_account_id` (mt5 account (number ya id); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `user_input_net_amount` (user input net ki raqam); `user_input_currency` (user input currency (null)); `card_number` (card number); `card_expiry` (card expiry (null)); `card_cvv` (card cvv (null)); `card_name` (card ka naam) … aur 1 fields.
7. [`POST /api/user/deposit/unipayment`](client-portal-endpoints.md#post-api-user-deposit-unipayment) — unipayment — request bhejta hai. Bhejo: `gateway_method_id` (gateway method ka id); `mt5_account_id` (mt5 account (number ya id); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).

### UniPayment success — `/deposit/unipayment/success`

**Screen khulte hi (data load):**

1. [`GET /api/user/deposit/by-reference`](client-portal-endpoints.md#get-api-user-deposit-by-reference) — by reference — data laata hai. Bhejo: `reference` ← [`GET /api/user/finance-activity`](client-portal-endpoints.md#get-api-user-finance-activity) ka `data[].reference_number`.

### UniPayment cancel — `/deposit/unipayment/cancel`

Is screen par koi API call nahi hoti.

### Cregis success — `/deposit/cregis/success`

**Screen khulte hi (data load):**

1. [`GET /api/user/deposit/by-reference`](client-portal-endpoints.md#get-api-user-deposit-by-reference) — by reference — data laata hai. Bhejo: `reference` ← [`GET /api/user/finance-activity`](client-portal-endpoints.md#get-api-user-finance-activity) ka `data[].reference_number`.

---

## Withdrawal

Paisa nikalna: method chuno → account + amount → OTP → request bhejo.

### Withdrawal (methods) — `/withdrawal`

**Screen khulte hi (data load):**

1. [`GET /api/user/withdrawal`](client-portal-endpoints.md#get-api-user-withdrawal) — Withdrawal methods retrieved successfully. Kuch bhejna nahi hai.

### Withdrawal request / history — `/withdrawal-request`

**Screen khulte hi (data load):**

1. [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) — Trading accounts retrieved successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

2. [`GET /api/user/withdrawal/withdrawal-method/{methodId}`](client-portal-endpoints.md#get-api-user-withdrawal-withdrawal-method-methodid) — Withdrawal method retrieved successfully. Bhejo: `methodId` ← [`GET /api/user/withdrawal`](client-portal-endpoints.md#get-api-user-withdrawal) ka `data[].method_slug` ya [`GET /api/ibm/portal/wallet`](client-portal-endpoints.md#get-api-ibm-portal-wallet) ka `data.methods[].slug`.

**User action par (button / form submit):**

3. [`GET /api/user/withdrawal/sendOTP`](client-portal-endpoints.md#get-api-user-withdrawal-sendotp) — send OTP — data laata hai. Kuch bhejna nahi hai.
4. [`POST /api/user/withdrawal/checkbalance`](client-portal-endpoints.md#post-api-user-withdrawal-checkbalance) — checkbalance — request bhejta hai. Bhejo: `context` (context (null)); `account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/internaltransfer`](client-portal-endpoints.md#get-api-user-internaltransfer) ka `data.userMT5Accounts[].meta_account_number`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `withdrawalMethod` (withdrawal method (null)).
5. [`POST /api/user/withdrawal/withdrawalrequest`](client-portal-endpoints.md#post-api-user-withdrawal-withdrawalrequest) — Withdrawal request created successfully. Bhejo: `mt5_account_id` (mt5 account (number ya id); `withdrawal_method_id` (withdrawal method ka id); `withdrawal_method_slug` (withdrawal method ka code (slug)); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `user_input_net_amount` (user input net ki raqam); `user_input_currency` (user input currency (null)); `master_withdrawal_method_slug` (master withdrawal method ka code (slug)); `otp` (user ko mail / sms par aaya otp).

---

## Internal Transfer

Apne hi accounts ke beech (MT5 ↔ MT5 / wallet) paisa bhejna, aur dusre trader ko transfer.

### Internal Transfer — `/internal-transfer`

**Screen khulte hi (data load):**

1. [`GET /api/user/crm-settings`](client-portal-endpoints.md#get-api-user-crm-settings) — CRM settings retrieved successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/internaltransfer`](client-portal-endpoints.md#get-api-user-internaltransfer) — Data retrieved successfully. Kuch bhejna nahi hai.
3. [`GET /api/user/internaltransfer/history`](client-portal-endpoints.md#get-api-user-internaltransfer-history) — Internal transfer history retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

4. [`GET /api/user/withdrawal/sendOTP`](client-portal-endpoints.md#get-api-user-withdrawal-sendotp) — send OTP — data laata hai. Kuch bhejna nahi hai.
5. [`POST /api/user/internaltransfer/request`](client-portal-endpoints.md#post-api-user-internaltransfer-request) — request — request bhejta hai. Bhejo: `from_account` ← [`GET /api/user/internaltransfer`](client-portal-endpoints.md#get-api-user-internaltransfer) ka `data.wallet.wallet_id` ya [`GET /api/user/internaltransfer`](client-portal-endpoints.md#get-api-user-internaltransfer) ka `data.userMT5Accounts[].meta_account_number`; `to_account` ← [`GET /api/user/internaltransfer`](client-portal-endpoints.md#get-api-user-internaltransfer) ka `data.wallet.wallet_id` ya [`GET /api/user/internaltransfer`](client-portal-endpoints.md#get-api-user-internaltransfer) ka `data.userMT5Accounts[].meta_account_number`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).
6. [`POST /api/user/withdrawal/checkbalance`](client-portal-endpoints.md#post-api-user-withdrawal-checkbalance) — checkbalance — request bhejta hai. Bhejo: `context` (context (null)); `account_number` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/internaltransfer`](client-portal-endpoints.md#get-api-user-internaltransfer) ka `data.userMT5Accounts[].meta_account_number`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `withdrawalMethod` (withdrawal method (null)).

### Internal Transfer History — `/internal-transfer-history`

**Screen khulte hi (data load):**

1. [`GET /api/user/internaltransfer/history`](client-portal-endpoints.md#get-api-user-internaltransfer-history) — Internal transfer history retrieved successfully. Kuch bhejna nahi hai.

### Trader to Trader Transfer — `/trader-transfer`

**Screen khulte hi (data load):**

1. [`GET /api/user/trader-transfer/config`](client-portal-endpoints.md#get-api-user-trader-transfer-config) — Trader Transfer is not available.. Kuch bhejna nahi hai.
2. [`GET /api/user/trader-transfer/history`](client-portal-endpoints.md#get-api-user-trader-transfer-history) — OK. Bhejo: `direction` (paisa aaya (`credit`) ya gaya (`debit`)); `status` (request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. kuch purani apis yahan http code (jaise `200`) bhejti hain); `date_from` (date from (null)); `date_to` (date to (null)).

**User action par (button / form submit):**

3. [`POST /api/user/trader-transfer/send-otp`](client-portal-endpoints.md#post-api-user-trader-transfer-send-otp) — OTP sent to your email. Bhejo: `recipient_token` (recipient token (null)); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).
4. [`POST /api/user/trader-transfer/submit`](client-portal-endpoints.md#post-api-user-trader-transfer-submit) — Transfer submitted. It will be completed after admin approval.. Bhejo: `recipient_token` (recipient token (null)); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `otp` (user ko mail / sms par aaya otp); `note` (note).
5. [`POST /api/user/trader-transfer/verify-recipient`](client-portal-endpoints.md#post-api-user-trader-transfer-verify-recipient) — Recipient verified. Bhejo: `email` (email address).

---

## IB Dashboard (classic IB)

IB (introducing broker) ka portal: apply, structure, clients, sub-IB, commission transfer.

### IB Dashboard / IB Application — `/ib-dashboard`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/dashboard`](client-portal-endpoints.md#get-api-ibm-portal-dashboard) — dashboard — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/user`](client-portal-endpoints.md#get-api-user) — user — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/user/crm-settings`](client-portal-endpoints.md#get-api-user-crm-settings) — CRM settings retrieved successfully. Kuch bhejna nahi hai.
4. [`GET /api/user/ib/activities`](client-portal-endpoints.md#get-api-user-ib-activities) — Recent activities retrieved successfully. Kuch bhejna nahi hai.
5. [`GET /api/user/ib/dashboard`](client-portal-endpoints.md#get-api-user-ib-dashboard) — IB details retrieved successfully. Kuch bhejna nahi hai.
6. [`GET /api/user/ib/stats`](client-portal-endpoints.md#get-api-user-ib-stats) — IB stats retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

7. [`POST /api/user/ib/application`](client-portal-endpoints.md#post-api-user-ib-application) — Your request has been submitted.. Bhejo: `terms_accepted` (user ne terms accept kiye (`true`)).
8. [`POST /api/user/ib/track-visit`](client-portal-endpoints.md#post-api-user-ib-track-visit) — track visit — request bhejta hai. Bhejo: `reference_link_id` ← [`GET /api/user/ib/dashboard`](client-portal-endpoints.md#get-api-user-ib-dashboard) ka `data.userIBDetails.reference_link_id` ya [`GET /api/user/ib/status`](client-portal-endpoints.md#get-api-user-ib-status) ka `data.reference_link_id`; `visitor_ip` (visitor ip (null)); `user_agent` (user agent (null)); `referrer` (referrer (null)).

### My Structure — `/my-structure`

**Screen khulte hi (data load):**

1. [`GET /api/user/ib/progressive-stats`](client-portal-endpoints.md#get-api-user-ib-progressive-stats) — progressive stats — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/user/ib/structure`](client-portal-endpoints.md#get-api-user-ib-structure) — IB structure retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`DELETE /api/user/ib/commission-groups/{id}`](client-portal-endpoints.md#delete-api-user-ib-commission-groups-id) — commission groups — delete karta hai. Bhejo: `id` (is record ka database id).

### Sub IB Structure — `/sub-ib-structure`

**Screen khulte hi (data load):**

1. [`GET /api/user/ib/commission-groups`](client-portal-endpoints.md#get-api-user-ib-commission-groups) — Commission groups retrieved successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/ib/structure`](client-portal-endpoints.md#get-api-user-ib-structure) — IB structure retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`DELETE /api/user/ib/commission-groups/{id}`](client-portal-endpoints.md#delete-api-user-ib-commission-groups-id) — commission groups — delete karta hai. Bhejo: `id` (is record ka database id).

### Sub IB Structure — create/edit commission group — `/sub-ib-structure/create`

**Screen khulte hi (data load):**

1. [`GET /api/user/ib/structure`](client-portal-endpoints.md#get-api-user-ib-structure) — IB structure retrieved successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

2. [`GET /api/user/ib/commission-groups/{id}`](client-portal-endpoints.md#get-api-user-ib-commission-groups-id) — Commission group retrieved successfully. Bhejo: `id` (is record ka database id).
3. [`GET /api/user/ib/get-template-rates/{templateId}`](client-portal-endpoints.md#get-api-user-ib-get-template-rates-templateid) — Data retrieved successfully. Bhejo: `templateId` (template id (null)).

**User action par (button / form submit):**

4. [`POST /api/user/ib/manage`](client-portal-endpoints.md#post-api-user-ib-manage) — IB Commission Group saved successfully. Bhejo: `structure_type` (structure type (null)); `group_name` (group ka naam); `master_ids` (master ke ids ki list).

### My Network (clients) — `/my-client`

**Screen khulte hi (data load):**

1. [`GET /api/user/ib/clients`](client-portal-endpoints.md#get-api-user-ib-clients) — Clients retrieved successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/ib/stats`](client-portal-endpoints.md#get-api-user-ib-stats) — IB stats retrieved successfully. Kuch bhejna nahi hai.
3. [`GET /api/user/ib/sub-ibs`](client-portal-endpoints.md#get-api-user-ib-sub-ibs) — Sub-IBs retrieved successfully. Kuch bhejna nahi hai.
4. [`GET /api/user/ib/trade-history`](client-portal-endpoints.md#get-api-user-ib-trade-history) — Select a client to view trade history. Kuch bhejna nahi hai.
5. [`GET /api/user/ib/tree-structure`](client-portal-endpoints.md#get-api-user-ib-tree-structure) — Tree structure retrieved successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

6. [`GET /api/user/ib/get-ib-details/{userSlug}`](client-portal-endpoints.md#get-api-user-ib-get-ib-details-userslug) — IB details retrieved successfully. Bhejo: `userSlug` ← [`GET /api/user/ib/tree-structure`](client-portal-endpoints.md#get-api-user-ib-tree-structure) ka `data.tree[].user.user_slug` ya [`GET /api/user/dashboard`](client-portal-endpoints.md#get-api-user-dashboard) ka `data.user.user_slug`.
7. [`GET /api/user/ib/sub-ib-stats/{subIBId}`](client-portal-endpoints.md#get-api-user-ib-sub-ib-stats-subibid) — Sub-IB stats retrieved successfully. Bhejo: `subIBId` (sub ibid (null)).
8. [`GET /api/user/ib/sub-ib-structure/{subIBId}`](client-portal-endpoints.md#get-api-user-ib-sub-ib-structure-subibid) — Clients retrieved successfully. Bhejo: `subIBId` (sub ibid (null)).
9. [`GET /api/user/ib/sub-ib-sub-ibs/{subIBId}`](client-portal-endpoints.md#get-api-user-ib-sub-ib-sub-ibs-subibid) — Sub-IBs retrieved successfully. Bhejo: `subIBId` (sub ibid (null)).

### Sub IB Approval — `/sub-ib-approval`

**Screen khulte hi (data load):**

1. [`GET /api/user/ib/ib-request-list`](client-portal-endpoints.md#get-api-user-ib-ib-request-list) — IB requests retrieved successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

2. [`GET /api/user/ib/get-structure-options/{id}`](client-portal-endpoints.md#get-api-user-ib-get-structure-options-id) — get structure options — data laata hai. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

3. [`POST /api/user/ib/update-status/{id}`](client-portal-endpoints.md#post-api-user-ib-update-status-id) — IB status updated successfully. Bhejo: `id` (is record ka database id); `status` (request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. kuch purani apis yahan http code (jaise `200`) bhejti hain); `structure_type` (structure type (null)); `standard_group_id` (standard group ka id).

### Transfer Commission — `/ib-transfer-create`

**Screen khulte hi (data load):**

1. [`GET /api/user/ib/transfer/clients/search`](client-portal-endpoints.md#get-api-user-ib-transfer-clients-search) — search — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/user/ib/transfer/create`](client-portal-endpoints.md#get-api-user-ib-transfer-create) — create — data laata hai. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/user/ib/transfer/store`](client-portal-endpoints.md#post-api-user-ib-transfer-store) — Commission transfer request submitted successfully. Pending admin approval.. Bhejo: `to_client_user_id` (to client user ka id); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `comment` (comment / note).

### Transfer Commission History — `/ib-transfer-history`

**Screen khulte hi (data load):**

1. [`GET /api/user/ib/transfer/history`](client-portal-endpoints.md#get-api-user-ib-transfer-history) — history — data laata hai. Kuch bhejna nahi hai.

**User action par (button / form submit):**

2. [`POST /api/user/ib/transfer/{id}/cancel`](client-portal-endpoints.md#post-api-user-ib-transfer-id-cancel) — Transfer request cancelled successfully.. Bhejo: `id` (is record ka database id).

### IB Trade & Win — `/ib/trade-win`

**Screen khulte hi (data load):**

1. [`GET /api/v1/user/trade-win/products`](client-portal-endpoints.md#get-api-v1-user-trade-win-products) — Products retrieved successfully.. Kuch bhejna nahi hai.
2. [`GET /api/v1/user/trade-win/saved-addresses`](client-portal-endpoints.md#get-api-v1-user-trade-win-saved-addresses) — Saved addresses retrieved successfully.. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/v1/user/trade-win/claim`](client-portal-endpoints.md#post-api-v1-user-trade-win-claim) — Claim successful!. Bhejo: `product_id` (product ka id); `quantity` (quantity (null)); `shipping_details` (shipping details (null)); `audience` (kiske liye (client / ib)).

### IB Demo Contest (list/create/edit/view) — `/ib-contest`

**Screen khulte hi (data load):**

1. [`GET /api/ib/demo-contest/instruments`](client-portal-endpoints.md#get-api-ib-demo-contest-instruments) — instruments — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ib/demo-contest/my-contests`](client-portal-endpoints.md#get-api-ib-demo-contest-my-contests) — my contests — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/user/kyc/countries`](client-portal-endpoints.md#get-api-user-kyc-countries) — Countries retrieved successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

4. [`GET /api/ib/demo-contest/{id}/enrollments`](client-portal-endpoints.md#get-api-ib-demo-contest-id-enrollments) — enrollments — data laata hai. Bhejo: `id` (is record ka database id).
5. [`GET /api/user/demo-contest/{contestId}/leaderboard`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-leaderboard) — leaderboard — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.

**User action par (button / form submit):**

6. [`POST /api/ib/demo-contest/{id}/add-prize-fund`](client-portal-endpoints.md#post-api-ib-demo-contest-id-add-prize-fund) — Prize fund added to contest pool.. Bhejo: `id` (is record ka database id); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).
7. [`POST /api/ib/demo-contest/{id}/cancel`](client-portal-endpoints.md#post-api-ib-demo-contest-id-cancel) — Contest cancelled. All participants refunded.. Bhejo: `id` (is record ka database id); `reason` (kaaran (reason)).
8. [`POST /api/ib/demo-contest/{id}/update`](client-portal-endpoints.md#post-api-ib-demo-contest-id-update) — Contest updated.. Bhejo: `id` (is record ka database id); `name` (naam); `tagline` (chhota tagline); `start_date` (shuru hone ki date); `end_date` (khatam hone ki date); `registration_closes` (registration kab band hoga); `starting_balance` (contest ka starting balance); `min_participants` (kam se kam participants); `max_participants` (zyada se zyada participants); `ranking_by` (rank kis basis par (jaise return_percent)) … aur 4 fields.
9. [`POST /api/ib/demo-contest/enrollment/{id}/approve`](client-portal-endpoints.md#post-api-ib-demo-contest-enrollment-id-approve) — approve — request bhejta hai. Bhejo: `id` (is record ka database id).
10. [`POST /api/ib/demo-contest/enrollment/{id}/reject`](client-portal-endpoints.md#post-api-ib-demo-contest-enrollment-id-reject) — Enrollment rejected and fee refunded.. Bhejo: `id` (is record ka database id); `reason` (kaaran (reason)).
11. [`POST /api/ib/demo-contest/store`](client-portal-endpoints.md#post-api-ib-demo-contest-store) — Contest created and sent to admin for approval.. Bhejo: `name` (naam); `tagline` (chhota tagline); `start_date` (shuru hone ki date); `end_date` (khatam hone ki date); `registration_closes` (registration kab band hoga); `starting_balance` (contest ka starting balance); `min_participants` (kam se kam participants); `max_participants` (zyada se zyada participants); `ranking_by` (rank kis basis par (jaise return_percent)); `timezone` (timezone (null)) … aur 19 fields.

---

## IB Manager Portal

Naya IB Manager portal: clients, commission plans, referral links, reports, wallet.

### Portal shell (common calls) — `/ib-manager-portal`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/dashboard`](client-portal-endpoints.md#get-api-ibm-portal-dashboard) — dashboard — data laata hai. Kuch bhejna nahi hai.

### Dashboard — `/ib-manager-portal`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/dashboard`](client-portal-endpoints.md#get-api-ibm-portal-dashboard) — dashboard — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ibm/portal/dashboard/activity`](client-portal-endpoints.md#get-api-ibm-portal-dashboard-activity) — activity — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/ibm/portal/network`](client-portal-endpoints.md#get-api-ibm-portal-network) — network — data laata hai. Kuch bhejna nahi hai.

### My Clients — `/ib-manager-portal/clients`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/clients`](client-portal-endpoints.md#get-api-ibm-portal-clients) — clients — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ibm/portal/clients/network-tree`](client-portal-endpoints.md#get-api-ibm-portal-clients-network-tree) — network tree — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/ibm/portal/network/tree-summary`](client-portal-endpoints.md#get-api-ibm-portal-network-tree-summary) — tree summary — data laata hai. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

4. [`GET /api/ibm/portal/network/{id}`](client-portal-endpoints.md#get-api-ibm-portal-network-id) — network — data laata hai. Bhejo: `id` (is record ka database id).
5. [`GET /api/ibm/portal/network/{id}/node`](client-portal-endpoints.md#get-api-ibm-portal-network-id-node) — node — data laata hai. Bhejo: `id` (is record ka database id).
6. [`GET /api/ibm/portal/network/{id}/wallet`](client-portal-endpoints.md#get-api-ibm-portal-network-id-wallet) — wallet — data laata hai. Bhejo: `id` (is record ka database id).

### Person detail (client / sub-IB) — `/ib-manager-portal/people/:personId`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/network/tree-summary`](client-portal-endpoints.md#get-api-ibm-portal-network-tree-summary) — tree summary — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ibm/portal/partner-plans`](client-portal-endpoints.md#get-api-ibm-portal-partner-plans) — partner plans — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/ibm/portal/wallet`](client-portal-endpoints.md#get-api-ibm-portal-wallet) — wallet — data laata hai. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

4. [`GET /api/ibm/portal/clients/{id}`](client-portal-endpoints.md#get-api-ibm-portal-clients-id) — clients — data laata hai. Bhejo: `id` (is record ka database id).
5. [`GET /api/ibm/portal/network/{id}`](client-portal-endpoints.md#get-api-ibm-portal-network-id) — network — data laata hai. Bhejo: `id` (is record ka database id).
6. [`GET /api/ibm/portal/network/{id}/links`](client-portal-endpoints.md#get-api-ibm-portal-network-id-links) — links — data laata hai. Bhejo: `id` (is record ka database id).
7. [`GET /api/ibm/portal/network/{id}/node`](client-portal-endpoints.md#get-api-ibm-portal-network-id-node) — node — data laata hai. Bhejo: `id` (is record ka database id).
8. [`GET /api/ibm/portal/network/{id}/plan`](client-portal-endpoints.md#get-api-ibm-portal-network-id-plan) — plan — data laata hai. Bhejo: `id` (is record ka database id).
9. [`GET /api/ibm/portal/network/{id}/symbols`](client-portal-endpoints.md#get-api-ibm-portal-network-id-symbols) — symbols — data laata hai. Bhejo: `id` (is record ka database id).
10. [`GET /api/ibm/portal/network/{id}/wallet`](client-portal-endpoints.md#get-api-ibm-portal-network-id-wallet) — wallet — data laata hai. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

11. [`POST /api/ibm/portal/partner-plans/{id}/assign`](client-portal-endpoints.md#post-api-ibm-portal-partner-plans-id-assign) — assign — request bhejta hai. Bhejo: `id` (is record ka database id); `ib_user_id` ← [`GET /api/ibm/portal/network/tree-summary`](client-portal-endpoints.md#get-api-ibm-portal-network-tree-summary) ka `data.ib_user_id` ya [`GET /api/ibm/portal/network/{id}/node`](client-portal-endpoints.md#get-api-ibm-portal-network-id-node) ka `data.ib_user_id`.

### Sub-IB Requests — `/ib-manager-portal/requests`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/partner-plans`](client-portal-endpoints.md#get-api-ibm-portal-partner-plans) — partner plans — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ibm/portal/requests`](client-portal-endpoints.md#get-api-ibm-portal-requests) — requests — data laata hai. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/ibm/portal/requests/{requestId}/approve`](client-portal-endpoints.md#post-api-ibm-portal-requests-requestid-approve) — approve — request bhejta hai. Bhejo: `requestId` (request id (null)); `plan_id` ← [`GET /api/ibm/portal/partner-plans`](client-portal-endpoints.md#get-api-ibm-portal-partner-plans) ka `data.plans[].plan_id` ya [`GET /api/ibm/portal/network/{id}/plan`](client-portal-endpoints.md#get-api-ibm-portal-network-id-plan) ka `data.plan_id`; `plan_group_ids` (plan group ke ids ki list); `plan_group_ids.*` (plan group ids.* (null)).
4. [`POST /api/ibm/portal/requests/{requestId}/reject`](client-portal-endpoints.md#post-api-ibm-portal-requests-requestid-reject) — Request declined.. Bhejo: `requestId` (request id (null)); `reason` (kaaran (reason)).

### Sub-IB Performance (from dashboard "View all") — `/ib-manager-portal/sub-ibs`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/network/performance`](client-portal-endpoints.md#get-api-ibm-portal-network-performance) — performance — data laata hai. Kuch bhejna nahi hai.

### Commission Plans — `/ib-manager-portal/plans`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/partner-plans`](client-portal-endpoints.md#get-api-ibm-portal-partner-plans) — partner plans — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ibm/portal/partner-plans/sub-ibs`](client-portal-endpoints.md#get-api-ibm-portal-partner-plans-sub-ibs) — sub ibs — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/ibm/portal/partner-plans/template`](client-portal-endpoints.md#get-api-ibm-portal-partner-plans-template) — template — data laata hai. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

4. [`GET /api/ibm/portal/partner-plans/{id}`](client-portal-endpoints.md#get-api-ibm-portal-partner-plans-id) — partner plans — data laata hai. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

5. [`DELETE /api/ibm/portal/partner-plans/{id}`](client-portal-endpoints.md#delete-api-ibm-portal-partner-plans-id) — Plan deleted.. Bhejo: `id` (is record ka database id).
6. [`PATCH /api/ibm/portal/partner-plans/{id}/rename`](client-portal-endpoints.md#patch-api-ibm-portal-partner-plans-id-rename) — Plan renamed.. Bhejo: `id` (is record ka database id); `plan_name` (plan ka naam); `description` (description).
7. [`POST /api/ibm/portal/partner-plans`](client-portal-endpoints.md#post-api-ibm-portal-partner-plans) — Plan created.. Bhejo: `plan_name` (plan ka naam); `description` (description); `groups` (groups (null)); `groups.*.group_id` (groups.*.group ka id); `groups.*.rates` (groups.*.rates (null)); `groups.*.symbol_rates` (groups.*.symbol rates (null)); `groups.*.blocked_symbol_ids` (groups.*.blocked symbol ke ids ki list); `groups.*.blocked_symbol_names` (groups.*.blocked symbol names (null)).
8. [`POST /api/ibm/portal/partner-plans/{id}/assign`](client-portal-endpoints.md#post-api-ibm-portal-partner-plans-id-assign) — assign — request bhejta hai. Bhejo: `id` (is record ka database id); `ib_user_id` ← [`GET /api/ibm/portal/network/tree-summary`](client-portal-endpoints.md#get-api-ibm-portal-network-tree-summary) ka `data.ib_user_id` ya [`GET /api/ibm/portal/network/{id}/node`](client-portal-endpoints.md#get-api-ibm-portal-network-id-node) ka `data.ib_user_id`.
9. [`PUT /api/ibm/portal/partner-plans/{id}`](client-portal-endpoints.md#put-api-ibm-portal-partner-plans-id) — Plan saved.. Bhejo: `id` (is record ka database id); `plan_name` (plan ka naam); `description` (description); `is_active` (active hai ya nahi); `groups` (groups (null)); `groups.*.group_id` (groups.*.group ka id); `groups.*.rates` (groups.*.rates (null)); `groups.*.symbol_rates` (groups.*.symbol rates (null)); `groups.*.blocked_symbol_ids` (groups.*.blocked symbol ke ids ki list); `groups.*.blocked_symbol_names` (groups.*.blocked symbol names (null)).

### My Commission — `/ib-manager-portal/commission`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/commission-distributions`](client-portal-endpoints.md#get-api-ibm-portal-commission-distributions) — commission distributions — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ibm/portal/commission-distributions/create`](client-portal-endpoints.md#get-api-ibm-portal-commission-distributions-create) — create — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/ibm/portal/plan`](client-portal-endpoints.md#get-api-ibm-portal-plan) — plan — data laata hai. Kuch bhejna nahi hai.
4. [`GET /api/ibm/portal/wallet`](client-portal-endpoints.md#get-api-ibm-portal-wallet) — wallet — data laata hai. Kuch bhejna nahi hai.
5. [`GET /api/ibm/portal/wallet/transactions`](client-portal-endpoints.md#get-api-ibm-portal-wallet-transactions) — transactions — data laata hai. Kuch bhejna nahi hai.

**User action par (button / form submit):**

6. [`DELETE /api/ibm/portal/commission-distributions/{id}`](client-portal-endpoints.md#delete-api-ibm-portal-commission-distributions-id) — Your request has been withdrawn.. Bhejo: `id` (is record ka database id).
7. [`GET /api/ibm/portal/exports/{id}`](client-portal-endpoints.md#get-api-ibm-portal-exports-id) — exports — data laata hai. Bhejo: `id` (is record ka database id).
8. [`GET /api/ibm/portal/exports/{id}/download`](client-portal-endpoints.md#get-api-ibm-portal-exports-id-download) — download — data laata hai. Bhejo: `id` (is record ka database id).
9. [`POST /api/ibm/portal/commission-distributions`](client-portal-endpoints.md#post-api-ibm-portal-commission-distributions) — Your request has been submitted for approval.. Bhejo: `client_user_id` ← [`GET /api/ibm/portal/client-funding`](client-portal-endpoints.md#get-api-ibm-portal-client-funding) ka `data.rows[].client_user_id` ya [`GET /api/ibm/portal/clients`](client-portal-endpoints.md#get-api-ibm-portal-clients) ka `data.rows[].client_user_id`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `comment` (comment / note).
10. [`POST /api/ibm/portal/exports`](client-portal-endpoints.md#post-api-ibm-portal-exports) — Your report is being prepared.. Bhejo: `kind` (kind (null)); `from` (is page ki pehli row ka number); `to` (is page ki aakhri row ka number); `type` (type); `status` (request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. kuch purani apis yahan http code (jaise `200`) bhejti hain); `view` (view (null)); `mt5_account` ← [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number` ya [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `side` (buy ya sell).
11. [`POST /api/ibm/portal/wallet/withdraw`](client-portal-endpoints.md#post-api-ibm-portal-wallet-withdraw) — Your payout request has been submitted.. Bhejo: `currency` (currency (jaise `usd`, `usc` = us cent)); `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")); `method_slug` (withdrawal method ka code); `withdrawal_method_id` (withdrawal method ka id).

### My Team Deposit / My Team Withdrawal — `/ib-manager-portal/team-deposits`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/client-funding`](client-portal-endpoints.md#get-api-ibm-portal-client-funding) — client funding — data laata hai. Bhejo: `from` (is page ki pehli row ka number); `to` (is page ki aakhri row ka number); `type` (type).

**User action par (button / form submit):**

2. [`GET /api/ibm/portal/exports/{id}`](client-portal-endpoints.md#get-api-ibm-portal-exports-id) — exports — data laata hai. Bhejo: `id` (is record ka database id).
3. [`GET /api/ibm/portal/exports/{id}/download`](client-portal-endpoints.md#get-api-ibm-portal-exports-id-download) — download — data laata hai. Bhejo: `id` (is record ka database id).
4. [`POST /api/ibm/portal/exports`](client-portal-endpoints.md#post-api-ibm-portal-exports) — Your report is being prepared.. Bhejo: `kind` (kind (null)); `from` (is page ki pehli row ka number); `to` (is page ki aakhri row ka number); `type` (type); `status` (request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. kuch purani apis yahan http code (jaise `200`) bhejti hain); `view` (view (null)); `mt5_account` ← [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number` ya [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `side` (buy ya sell).

### IB Commission report — `/ib-manager-portal/ib-commission-report`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/commission-report`](client-portal-endpoints.md#get-api-ibm-portal-commission-report) — commission report — data laata hai. Bhejo: `from` (is page ki pehli row ka number); `to` (is page ki aakhri row ka number); `view` (view (null)); `mt5_account` ← [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number` ya [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `type` (type).

**User action par (button / form submit):**

2. [`GET /api/ibm/portal/exports/{id}`](client-portal-endpoints.md#get-api-ibm-portal-exports-id) — exports — data laata hai. Bhejo: `id` (is record ka database id).
3. [`GET /api/ibm/portal/exports/{id}/download`](client-portal-endpoints.md#get-api-ibm-portal-exports-id-download) — download — data laata hai. Bhejo: `id` (is record ka database id).
4. [`POST /api/ibm/portal/exports`](client-portal-endpoints.md#post-api-ibm-portal-exports) — Your report is being prepared.. Bhejo: `kind` (kind (null)); `from` (is page ki pehli row ka number); `to` (is page ki aakhri row ka number); `type` (type); `status` (request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. kuch purani apis yahan http code (jaise `200`) bhejti hain); `view` (view (null)); `mt5_account` ← [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number` ya [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `side` (buy ya sell).

### IB Withdraw report — `/ib-manager-portal/ib-withdraw-report`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/payout-report`](client-portal-endpoints.md#get-api-ibm-portal-payout-report) — payout report — data laata hai. Bhejo: `from` (is page ki pehli row ka number); `to` (is page ki aakhri row ka number); `status` (request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. kuch purani apis yahan http code (jaise `200`) bhejti hain).

**User action par (button / form submit):**

2. [`GET /api/ibm/portal/exports/{id}`](client-portal-endpoints.md#get-api-ibm-portal-exports-id) — exports — data laata hai. Bhejo: `id` (is record ka database id).
3. [`GET /api/ibm/portal/exports/{id}/download`](client-portal-endpoints.md#get-api-ibm-portal-exports-id-download) — download — data laata hai. Bhejo: `id` (is record ka database id).
4. [`POST /api/ibm/portal/exports`](client-portal-endpoints.md#post-api-ibm-portal-exports) — Your report is being prepared.. Bhejo: `kind` (kind (null)); `from` (is page ki pehli row ka number); `to` (is page ki aakhri row ka number); `type` (type); `status` (request ka result: `true` = kaam ho gaya, `false` = kaam nahi hua. kuch purani apis yahan http code (jaise `200`) bhejti hain); `view` (view (null)); `mt5_account` ← [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number` ya [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number`; `symbol` (instrument (jaise xauusd, eurusd)); `side` (buy ya sell).

### Referral Links — `/ib-manager-portal/referrals`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/links`](client-portal-endpoints.md#get-api-ibm-portal-links) — links — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ibm/portal/plan/groups`](client-portal-endpoints.md#get-api-ibm-portal-plan-groups) — groups — data laata hai. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/ibm/portal/links/{id}/clients`](client-portal-endpoints.md#get-api-ibm-portal-links-id-clients) — clients — data laata hai. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

4. [`DELETE /api/ibm/portal/links/{id}`](client-portal-endpoints.md#delete-api-ibm-portal-links-id) — Link removed.. Bhejo: `id` (is record ka database id).
5. [`POST /api/ibm/portal/links`](client-portal-endpoints.md#post-api-ibm-portal-links) — Link created.. Bhejo: `label` (screen par dikhane wala label); `code` (code (referral / link code)); `plan_group_ids` (plan group ke ids ki list); `plan_group_ids.*` (plan group ids.* (null)); `default_plan_group_id` (default plan group ka id); `expires_at` (kab expire hoga (`null` = kabhi nahi)).
6. [`PUT /api/ibm/portal/links/{id}`](client-portal-endpoints.md#put-api-ibm-portal-links-id) — Link saved.. Bhejo: `id` (is record ka database id); `label` (screen par dikhane wala label); `is_active` (active hai ya nahi); `plan_group_ids` (plan group ke ids ki list); `plan_group_ids.*` (plan group ids.* (null)); `default_plan_group_id` (default plan group ka id); `expires_at` (kab expire hoga (`null` = kabhi nahi)).

### Marketing Material — `/ib-manager-portal/marketing`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/marketing`](client-portal-endpoints.md#get-api-ibm-portal-marketing) — marketing — data laata hai. Kuch bhejna nahi hai.

### Settings — `/ib-manager-portal/settings`

**Screen khulte hi (data load):**

1. [`GET /api/ibm/portal/client-visibility`](client-portal-endpoints.md#get-api-ibm-portal-client-visibility) — client visibility — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/ibm/portal/plan`](client-portal-endpoints.md#get-api-ibm-portal-plan) — plan — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/ibm/portal/wallet`](client-portal-endpoints.md#get-api-ibm-portal-wallet) — wallet — data laata hai. Kuch bhejna nahi hai.

**User action par (button / form submit):**

4. [`POST /api/ibm/portal/client-visibility`](client-portal-endpoints.md#post-api-ibm-portal-client-visibility) — Saved.. Bhejo: `plan_group_ids` (plan group ke ids ki list); `plan_group_ids.*` (plan group ids.* (null)); `default_plan_group_id` (default plan group ka id).

### Transfer Commission (leaves portal → Internal Transfer page) — `/internal-transfer`

Is screen par koi API call nahi hoti.

---

## Transaction History

Saare deposit / withdrawal / transfer ki history.

### Transaction History — `/transaction-history`

**Screen khulte hi (data load):**

1. [`GET /api/user/finance-activity`](client-portal-endpoints.md#get-api-user-finance-activity) — Transactions fetched successfully. Kuch bhejna nahi hai.

### Wallet History — `/wallet-history`

**Screen khulte hi (data load):**

1. [`GET /api/user/finance-activity`](client-portal-endpoints.md#get-api-user-finance-activity) — Transactions fetched successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/internaltransfer/history`](client-portal-endpoints.md#get-api-user-internaltransfer-history) — Internal transfer history retrieved successfully. Kuch bhejna nahi hai.

---

## PAMM

Fund manager me invest karna (investor) ya khud manager banke plan chalana.

### Explore Fund Managers — `/pmam/investor/explore`

**Screen khulte hi (data load):**

1. [`GET /api/user/pmam/investor/eligible-accounts`](client-portal-endpoints.md#get-api-user-pmam-investor-eligible-accounts) — Eligible accounts retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) — Enrollments retrieved. Kuch bhejna nahi hai.
3. [`GET /api/user/pmam/investor/my-fund-entries`](client-portal-endpoints.md#get-api-user-pmam-investor-my-fund-entries) — Fund entries retrieved. Kuch bhejna nahi hai.
4. [`GET /api/user/pmam/investor/my-open-allocations`](client-portal-endpoints.md#get-api-user-pmam-investor-my-open-allocations) — Open allocations retrieved. Kuch bhejna nahi hai.
5. [`GET /api/user/pmam/investor/pnl-history`](client-portal-endpoints.md#get-api-user-pmam-investor-pnl-history) — P&L history retrieved. Kuch bhejna nahi hai.
6. [`GET /api/user/pmam/managers/search`](client-portal-endpoints.md#get-api-user-pmam-managers-search) — Managers found. Kuch bhejna nahi hai.
7. [`GET /api/user/pmam/plans/search`](client-portal-endpoints.md#get-api-user-pmam-plans-search) — Plans found. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

8. [`GET /api/user/pmam/managers/{code}/trades`](client-portal-endpoints.md#get-api-user-pmam-managers-code-trades) — Trade history retrieved. Bhejo: `code` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].manager_code` ya [`GET /api/user/pmam/managers/{code}`](client-portal-endpoints.md#get-api-user-pmam-managers-code) ka `data.manager_code`; `plan_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.

**User action par (button / form submit):**

9. [`POST /api/user/pmam/investor/deposit`](client-portal-endpoints.md#post-api-user-pmam-investor-deposit) — deposit — request bhejta hai. Bhejo: `pmam_investor_id` ← [`GET /api/user/pmam/investor/my-fund-entries`](client-portal-endpoints.md#get-api-user-pmam-investor-my-fund-entries) ka `data[].pmam_investor_id` ya [`GET /api/user/pmam/manager/plans/{planId}/allocations`](client-portal-endpoints.md#get-api-user-pmam-manager-plans-planid-allocations) ka `data.data[].pmam_investor_id`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).
10. [`POST /api/user/pmam/investor/request-join`](client-portal-endpoints.md#post-api-user-pmam-investor-request-join) — Join request submitted. Awaiting manager approval.. Bhejo: `pmam_plan_id` (pmam plan ka id); `investor_account_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].investor_account_id`; `invested_amount` (kitna invest kiya).
11. [`POST /api/user/pmam/investor/unsubscribe/{id}`](client-portal-endpoints.md#post-api-user-pmam-investor-unsubscribe-id) — unsubscribe — request bhejta hai. Bhejo: `id` (is record ka database id).
12. [`POST /api/user/pmam/plans/datatable`](client-portal-endpoints.md#post-api-user-pmam-plans-datatable) — datatable — request bhejta hai. Bhejo: `manager_code` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].manager_code` ya [`GET /api/user/pmam/managers`](client-portal-endpoints.md#get-api-user-pmam-managers) ka `data[].manager_code`; `plan_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.

### My Investments — `/pmam/investor/my-investments`

**Screen khulte hi (data load):**

1. [`GET /api/user/pmam/investor/eligible-accounts`](client-portal-endpoints.md#get-api-user-pmam-investor-eligible-accounts) — Eligible accounts retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) — Enrollments retrieved. Kuch bhejna nahi hai.
3. [`GET /api/user/pmam/investor/my-fund-entries`](client-portal-endpoints.md#get-api-user-pmam-investor-my-fund-entries) — Fund entries retrieved. Kuch bhejna nahi hai.
4. [`GET /api/user/pmam/investor/my-open-allocations`](client-portal-endpoints.md#get-api-user-pmam-investor-my-open-allocations) — Open allocations retrieved. Kuch bhejna nahi hai.
5. [`GET /api/user/pmam/investor/pnl-history`](client-portal-endpoints.md#get-api-user-pmam-investor-pnl-history) — P&L history retrieved. Kuch bhejna nahi hai.
6. [`GET /api/user/pmam/managers/search`](client-portal-endpoints.md#get-api-user-pmam-managers-search) — Managers found. Kuch bhejna nahi hai.
7. [`GET /api/user/pmam/plans/search`](client-portal-endpoints.md#get-api-user-pmam-plans-search) — Plans found. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

8. [`GET /api/user/pmam/managers/{code}/trades`](client-portal-endpoints.md#get-api-user-pmam-managers-code-trades) — Trade history retrieved. Bhejo: `code` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].manager_code` ya [`GET /api/user/pmam/managers/{code}`](client-portal-endpoints.md#get-api-user-pmam-managers-code) ka `data.manager_code`; `plan_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.

**User action par (button / form submit):**

9. [`POST /api/user/pmam/investor/deposit`](client-portal-endpoints.md#post-api-user-pmam-investor-deposit) — deposit — request bhejta hai. Bhejo: `pmam_investor_id` ← [`GET /api/user/pmam/investor/my-fund-entries`](client-portal-endpoints.md#get-api-user-pmam-investor-my-fund-entries) ka `data[].pmam_investor_id` ya [`GET /api/user/pmam/manager/plans/{planId}/allocations`](client-portal-endpoints.md#get-api-user-pmam-manager-plans-planid-allocations) ka `data.data[].pmam_investor_id`; `amount` (amount (kai jagah currency sign ke saath text, jaise "$150.00")).
10. [`POST /api/user/pmam/investor/request-join`](client-portal-endpoints.md#post-api-user-pmam-investor-request-join) — Join request submitted. Awaiting manager approval.. Bhejo: `pmam_plan_id` (pmam plan ka id); `investor_account_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].investor_account_id`; `invested_amount` (kitna invest kiya).
11. [`POST /api/user/pmam/investor/unsubscribe/{id}`](client-portal-endpoints.md#post-api-user-pmam-investor-unsubscribe-id) — unsubscribe — request bhejta hai. Bhejo: `id` (is record ka database id).
12. [`POST /api/user/pmam/plans/datatable`](client-portal-endpoints.md#post-api-user-pmam-plans-datatable) — datatable — request bhejta hai. Bhejo: `manager_code` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].manager_code` ya [`GET /api/user/pmam/managers`](client-portal-endpoints.md#get-api-user-pmam-managers) ka `data[].manager_code`; `plan_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.

### Managers list — `/pmam/managers`

**Screen khulte hi (data load):**

1. [`GET /api/user/pmam/managers`](client-portal-endpoints.md#get-api-user-pmam-managers) — Managers list retrieved. Kuch bhejna nahi hai.

### Manager public profile — `/pmam/manager/:code`

**Screen khulte hi (data load):**

1. [`GET /api/user/pmam/investor/eligible-accounts`](client-portal-endpoints.md#get-api-user-pmam-investor-eligible-accounts) — Eligible accounts retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) — Enrollments retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/user/pmam/managers/{code}`](client-portal-endpoints.md#get-api-user-pmam-managers-code) — Manager profile retrieved. Bhejo: `code` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].manager_code` ya [`GET /api/user/pmam/managers`](client-portal-endpoints.md#get-api-user-pmam-managers) ka `data[].manager_code`.
4. [`GET /api/user/pmam/managers/{code}/open-positions`](client-portal-endpoints.md#get-api-user-pmam-managers-code-open-positions) — Open positions retrieved. Bhejo: `code` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].manager_code` ya [`GET /api/user/pmam/managers/{code}`](client-portal-endpoints.md#get-api-user-pmam-managers-code) ka `data.manager_code`; `plan_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.
5. [`GET /api/user/pmam/managers/{code}/trades`](client-portal-endpoints.md#get-api-user-pmam-managers-code-trades) — Trade history retrieved. Bhejo: `code` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].manager_code` ya [`GET /api/user/pmam/managers/{code}`](client-portal-endpoints.md#get-api-user-pmam-managers-code) ka `data.manager_code`; `plan_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.

**User action par (button / form submit):**

6. [`POST /api/user/pmam/investor/request-join`](client-portal-endpoints.md#post-api-user-pmam-investor-request-join) — Join request submitted. Awaiting manager approval.. Bhejo: `pmam_plan_id` (pmam plan ka id); `investor_account_id` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].investor_account_id`; `invested_amount` (kitna invest kiya).

### Become a manager (apply) — `/pmam/manager/apply`

**User action par (button / form submit):**

1. [`POST /api/user/pmam/manager/apply`](client-portal-endpoints.md#post-api-user-pmam-manager-apply) — apply — request bhejta hai. Bhejo: `terms_accepted` (user ne terms accept kiye (`true`)).

### Manager dashboard — `/pmam/manager/dashboard`

**Screen khulte hi (data load):**

1. [`GET /api/user/pmam/manager/dashboard-overview`](client-portal-endpoints.md#get-api-user-pmam-manager-dashboard-overview) — OK. Kuch bhejna nahi hai.
2. [`GET /api/user/pmam/manager/eligible-accounts`](client-portal-endpoints.md#get-api-user-pmam-manager-eligible-accounts) — Eligible accounts retrieved. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/user/pmam/manager/plans`](client-portal-endpoints.md#post-api-user-pmam-manager-plans) — Plan submitted for admin approval.. Bhejo: `trading_account_id` (trading account ka id); `plan_name` (plan ka naam); `commission_percentage` (commission %); `minimum_investment` (minimum investment); `strategy_description` (trading strategy); `risk_information` (risk ki jaankari).

### Manager — My Plans — `/pmam/manager/plans`

**Screen khulte hi (data load):**

1. [`GET /api/user/pmam/manager/eligible-accounts`](client-portal-endpoints.md#get-api-user-pmam-manager-eligible-accounts) — Eligible accounts retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/pmam/manager/plans`](client-portal-endpoints.md#get-api-user-pmam-manager-plans) — Plans retrieved. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/user/pmam/manager/plans`](client-portal-endpoints.md#post-api-user-pmam-manager-plans) — Plan submitted for admin approval.. Bhejo: `trading_account_id` (trading account ka id); `plan_name` (plan ka naam); `commission_percentage` (commission %); `minimum_investment` (minimum investment); `strategy_description` (trading strategy); `risk_information` (risk ki jaankari).
4. [`POST /api/user/pmam/manager/plans/{planId}/inactivate`](client-portal-endpoints.md#post-api-user-pmam-manager-plans-planid-inactivate) — inactivate — request bhejta hai. Bhejo: `planId` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.
5. [`POST /api/user/pmam/manager/plans/{planId}/pause`](client-portal-endpoints.md#post-api-user-pmam-manager-plans-planid-pause) — Plan paused successfully.. Bhejo: `planId` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.
6. [`POST /api/user/pmam/manager/plans/{planId}/resume`](client-portal-endpoints.md#post-api-user-pmam-manager-plans-planid-resume) — Plan resumed successfully.. Bhejo: `planId` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.
7. [`PUT /api/user/pmam/manager/plans/{planId}`](client-portal-endpoints.md#put-api-user-pmam-manager-plans-planid) — Plan updated successfully.. Bhejo: `planId` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`; `plan_name` (plan ka naam); `strategy_description` (trading strategy); `risk_information` (risk ki jaankari); `commission_percentage` (commission %); `minimum_investment` (minimum investment).

### Manager — Plan view — `/pmam/manager/plans/:planId`

**Kisi item par tap karke (detail):**

1. [`GET /api/user/pmam/manager/plans/{planId}/allocations`](client-portal-endpoints.md#get-api-user-pmam-manager-plans-planid-allocations) — Plan allocations retrieved. Bhejo: `planId` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.
2. [`GET /api/user/pmam/manager/plans/{planId}/detail`](client-portal-endpoints.md#get-api-user-pmam-manager-plans-planid-detail) — Plan detail retrieved. Bhejo: `planId` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.
3. [`GET /api/user/pmam/manager/plans/{planId}/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-plans-planid-investors) — Plan investors retrieved. Bhejo: `planId` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.

### Manager — Investor requests — `/pmam/manager/plans/:planId/requests`

**Kisi item par tap karke (detail):**

1. [`GET /api/user/pmam/manager/plans/{planId}/investor-requests`](client-portal-endpoints.md#get-api-user-pmam-manager-plans-planid-investor-requests) — Investor requests retrieved. Bhejo: `planId` ← [`GET /api/user/pmam/investor/enrollments`](client-portal-endpoints.md#get-api-user-pmam-investor-enrollments) ka `data[].plan_id` ya [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) ka `data[].plan_id`.

**User action par (button / form submit):**

2. [`POST /api/user/pmam/manager/investor-requests/{id}/approve`](client-portal-endpoints.md#post-api-user-pmam-manager-investor-requests-id-approve) — approve — request bhejta hai. Bhejo: `id` (is record ka database id).
3. [`POST /api/user/pmam/manager/investor-requests/{id}/reject`](client-portal-endpoints.md#post-api-user-pmam-manager-investor-requests-id-reject) — Investor request rejected.. Bhejo: `id` (is record ka database id); `reason` (kaaran (reason)).

### Manager — Investors — `/pmam/manager/investors`

**Screen khulte hi (data load):**

1. [`GET /api/user/pmam/manager/investors`](client-portal-endpoints.md#get-api-user-pmam-manager-investors) — Investors retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/pmam/manager/plans`](client-portal-endpoints.md#get-api-user-pmam-manager-plans) — Plans retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/user/pmam/manager/investors/{investorId}/detail`](client-portal-endpoints.md#get-api-user-pmam-manager-investors-investorid-detail) — Investor detail retrieved. Bhejo: `investorId` ← [`GET /api/user/pmam/manager/commissions`](client-portal-endpoints.md#get-api-user-pmam-manager-commissions) ka `data.data[].investor_id`.

**User action par (button / form submit):**

4. [`POST /api/user/pmam/manager/investor-requests/{id}/approve`](client-portal-endpoints.md#post-api-user-pmam-manager-investor-requests-id-approve) — approve — request bhejta hai. Bhejo: `id` (is record ka database id).
5. [`POST /api/user/pmam/manager/investor-requests/{id}/reject`](client-portal-endpoints.md#post-api-user-pmam-manager-investor-requests-id-reject) — Investor request rejected.. Bhejo: `id` (is record ka database id); `reason` (kaaran (reason)).

### Manager — Commissions — `/pmam/manager/commissions`

**Screen khulte hi (data load):**

1. [`GET /api/user/pmam/manager/commissions`](client-portal-endpoints.md#get-api-user-pmam-manager-commissions) — Commissions retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/pmam/manager/plans`](client-portal-endpoints.md#get-api-user-pmam-manager-plans) — Plans retrieved. Kuch bhejna nahi hai.

---

## Copy Trading

Kisi master trader ko copy karna (copier) ya khud master banna.

### Leaderboard — `/copy-trade`

**Screen khulte hi (data load):**

1. [`GET /api/copytrading/masters/search`](client-portal-endpoints.md#get-api-copytrading-masters-search) — Masters found. Kuch bhejna nahi hai.
2. [`GET /api/copytrading/plans`](client-portal-endpoints.md#get-api-copytrading-plans) — Plans list retrieved. Kuch bhejna nahi hai.
3. [`GET /api/copytrading/plans/search`](client-portal-endpoints.md#get-api-copytrading-plans-search) — Plans found. Kuch bhejna nahi hai.
4. [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) — Eligible accounts retrieved. Kuch bhejna nahi hai.
5. [`GET /api/user/copytrading/copier/subscriptions`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions) — Subscriptions retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

6. [`GET /api/user/copytrading/copier/masters/{code}`](client-portal-endpoints.md#get-api-user-copytrading-copier-masters-code) — Master profile retrieved. Bhejo: `code` ← [`GET /api/copytrading/plans`](client-portal-endpoints.md#get-api-copytrading-plans) ka `data[].master_code` ya [`GET /api/copytrading/masters/{code}`](client-portal-endpoints.md#get-api-copytrading-masters-code) ka `data.master_code`.

**User action par (button / form submit):**

7. [`POST /api/user/copytrading/copier/subscribe`](client-portal-endpoints.md#post-api-user-copytrading-copier-subscribe) — subscribe — request bhejta hai. Bhejo: `plan_id` ← [`GET /api/copytrading/plans`](client-portal-endpoints.md#get-api-copytrading-plans) ka `data[].plan_id` ya [`GET /api/user/copytrading/copier/subscriptions`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions) ka `data[].plan_id`; `mt5_account_id` (mt5 account (number ya id); `investment_amount` (investment ki raqam); `copying_method` (copying method (null)); `sizing_method` (lot size kaise tay hota hai); `fixed_lot_size` (fixed lot size); `lot_multiplier` (lot multiplier (null)); `mirror_ratio` (mirror ratio (null)); `is_reverse` (kya reverse hai? (`true` / `false`)); `risk_percent` (risk %) … aur 13 fields.

### Master profile — `/copy-trade/master/:code`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) — Eligible accounts retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/copytrading/copier/subscriptions`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions) — Subscriptions retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/copytrading/masters/{code}`](client-portal-endpoints.md#get-api-copytrading-masters-code) — Master profile retrieved. Bhejo: `code` ← [`GET /api/user/copytrading/master/status`](client-portal-endpoints.md#get-api-user-copytrading-master-status) ka `data.master_code` ya [`GET /api/user/copytrading/copier/masters/{code}`](client-portal-endpoints.md#get-api-user-copytrading-copier-masters-code) ka `data.master_code`.
4. [`GET /api/copytrading/masters/{code}/trade-history`](client-portal-endpoints.md#get-api-copytrading-masters-code-trade-history) — Master trade history retrieved. Bhejo: `code` ← [`GET /api/copytrading/masters/{code}`](client-portal-endpoints.md#get-api-copytrading-masters-code) ka `data.master_code` ya [`GET /api/user/copytrading/copier/masters/{code}`](client-portal-endpoints.md#get-api-user-copytrading-copier-masters-code) ka `data.master_code`.
5. [`GET /api/user/copytrading/copier/masters/{code}`](client-portal-endpoints.md#get-api-user-copytrading-copier-masters-code) — Master profile retrieved. Bhejo: `code` ← [`GET /api/copytrading/plans`](client-portal-endpoints.md#get-api-copytrading-plans) ka `data[].master_code` ya [`GET /api/copytrading/masters/{code}`](client-portal-endpoints.md#get-api-copytrading-masters-code) ka `data.master_code`.

**User action par (button / form submit):**

6. [`POST /api/user/copytrading/copier/subscribe`](client-portal-endpoints.md#post-api-user-copytrading-copier-subscribe) — subscribe — request bhejta hai. Bhejo: `plan_id` ← [`GET /api/copytrading/plans`](client-portal-endpoints.md#get-api-copytrading-plans) ka `data[].plan_id` ya [`GET /api/user/copytrading/copier/subscriptions`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions) ka `data[].plan_id`; `mt5_account_id` (mt5 account (number ya id); `investment_amount` (investment ki raqam); `copying_method` (copying method (null)); `sizing_method` (lot size kaise tay hota hai); `fixed_lot_size` (fixed lot size); `lot_multiplier` (lot multiplier (null)); `mirror_ratio` (mirror ratio (null)); `is_reverse` (kya reverse hai? (`true` / `false`)); `risk_percent` (risk %) … aur 13 fields.

### My Investments (copier dashboard) — `/copy-trading/dashboard`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/copier/subscriptions`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions) — Subscriptions retrieved. Kuch bhejna nahi hai.

**User action par (button / form submit):**

2. [`POST /api/user/copytrading/copier/subscriptions/{id}/pause`](client-portal-endpoints.md#post-api-user-copytrading-copier-subscriptions-id-pause) — Subscription paused successfully.. Bhejo: `id` (is record ka database id).
3. [`POST /api/user/copytrading/copier/subscriptions/{id}/resume`](client-portal-endpoints.md#post-api-user-copytrading-copier-subscriptions-id-resume) — Subscription resumed successfully.. Bhejo: `id` (is record ka database id).
4. [`POST /api/user/copytrading/copier/subscriptions/{id}/stop`](client-portal-endpoints.md#post-api-user-copytrading-copier-subscriptions-id-stop) — Subscription stopped successfully. Your capital has been released.. Bhejo: `id` (is record ka database id).
5. [`PUT /api/user/copytrading/copier/subscriptions/{id}/update`](client-portal-endpoints.md#put-api-user-copytrading-copier-subscriptions-id-update) — Subscription updated successfully.. Bhejo: `id` (is record ka database id); `copying_method` (copying method (null)); `sizing_method` (lot size kaise tay hota hai); `fixed_lot_size` (fixed lot size); `lot_multiplier` (lot multiplier (null)); `mirror_ratio` (mirror ratio (null)); `is_reverse` (kya reverse hai? (`true` / `false`)); `risk_percent` (risk %); `dynamic_lot_rules` (dynamic lot rules (null)); `dynamic_lot_rules.drawdown_threshold_pct` (dynamic lot rules.drawdown threshold %) … aur 10 fields.

### Subscription detail — `/copy-trading/dashboard/subscription/:id`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/copier/subscriptions`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions) — Subscriptions retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

2. [`GET /api/user/copytrading/copier/subscriptions/{id}/commission-history`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions-id-commission-history) — Commission history retrieved. Bhejo: `id` (is record ka database id).
3. [`GET /api/user/copytrading/copier/subscriptions/{id}/detail`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions-id-detail) — Subscription detail retrieved. Bhejo: `id` (is record ka database id).
4. [`GET /api/user/copytrading/copier/subscriptions/{id}/trades`](client-portal-endpoints.md#get-api-user-copytrading-copier-subscriptions-id-trades) — Trades retrieved. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

5. [`POST /api/user/copytrading/copier/subscriptions/{id}/pause`](client-portal-endpoints.md#post-api-user-copytrading-copier-subscriptions-id-pause) — Subscription paused successfully.. Bhejo: `id` (is record ka database id).
6. [`POST /api/user/copytrading/copier/subscriptions/{id}/resume`](client-portal-endpoints.md#post-api-user-copytrading-copier-subscriptions-id-resume) — Subscription resumed successfully.. Bhejo: `id` (is record ka database id).
7. [`POST /api/user/copytrading/copier/subscriptions/{id}/stop`](client-portal-endpoints.md#post-api-user-copytrading-copier-subscriptions-id-stop) — Subscription stopped successfully. Your capital has been released.. Bhejo: `id` (is record ka database id).

### Master dashboard — `/copy-trading/master/dashboard`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/master/dashboard-overview`](client-portal-endpoints.md#get-api-user-copytrading-master-dashboard-overview) — Dashboard overview retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/copytrading/master/status`](client-portal-endpoints.md#get-api-user-copytrading-master-status) — Master status retrieved. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/user/copytrading/master/apply`](client-portal-endpoints.md#post-api-user-copytrading-master-apply) — apply — request bhejta hai. Bhejo: `terms_accepted` (user ne terms accept kiye (`true`)); `nickname` (nickname (null)); `strategy` (strategy (null)); `risk_info` (risk info (null)).

### Master dashboard (legacy) — `/copy-trading/master/dashboard/legacy`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/master/dashboard-stats`](client-portal-endpoints.md#get-api-user-copytrading-master-dashboard-stats) — Dashboard stats retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/copytrading/master/plans`](client-portal-endpoints.md#get-api-user-copytrading-master-plans) — Plans retrieved. Kuch bhejna nahi hai.
3. [`GET /api/user/copytrading/master/status`](client-portal-endpoints.md#get-api-user-copytrading-master-status) — Master status retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

4. [`GET /api/copytrading/masters/{code}`](client-portal-endpoints.md#get-api-copytrading-masters-code) — Master profile retrieved. Bhejo: `code` ← [`GET /api/user/copytrading/master/status`](client-portal-endpoints.md#get-api-user-copytrading-master-status) ka `data.master_code` ya [`GET /api/user/copytrading/copier/masters/{code}`](client-portal-endpoints.md#get-api-user-copytrading-copier-masters-code) ka `data.master_code`.
5. [`GET /api/user/copytrading/master/plans/{id}/open-positions`](client-portal-endpoints.md#get-api-user-copytrading-master-plans-id-open-positions) — Open positions retrieved. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

6. [`POST /api/user/copytrading/master/apply`](client-portal-endpoints.md#post-api-user-copytrading-master-apply) — apply — request bhejta hai. Bhejo: `terms_accepted` (user ne terms accept kiye (`true`)); `nickname` (nickname (null)); `strategy` (strategy (null)); `risk_info` (risk info (null)).

### Master — Plans — `/copy-trading/master/plans`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) — Eligible accounts retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/copytrading/master/plans`](client-portal-endpoints.md#get-api-user-copytrading-master-plans) — Plans retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/user/copytrading/master/plans/{id}`](client-portal-endpoints.md#get-api-user-copytrading-master-plans-id) — Plan detail retrieved. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

4. [`POST /api/user/copytrading/master/plans`](client-portal-endpoints.md#post-api-user-copytrading-master-plans) — Plan created and submitted for admin approval.. Bhejo: `trading_account_id` (trading account ka id); `name` (naam); `plan_name` (plan ka naam); `strategy_description` (trading strategy); `risk_info` (risk info (null)); `commission_value` (commission value (null)); `settlement_cycle` (kitne din me settlement); `no_fee_days` (no fee days (null)); `min_capital` (kam se kam capital); `copy_ratio` (copy ratio) … aur 1 fields.
5. [`POST /api/user/copytrading/master/plans/{id}/pause`](client-portal-endpoints.md#post-api-user-copytrading-master-plans-id-pause) — Plan paused. Copying is suspended until you resume.. Bhejo: `id` (is record ka database id).
6. [`POST /api/user/copytrading/master/plans/{id}/resume`](client-portal-endpoints.md#post-api-user-copytrading-master-plans-id-resume) — Plan resumed. Copying is active again.. Bhejo: `id` (is record ka database id).
7. [`PUT /api/user/copytrading/master/plans/{id}`](client-portal-endpoints.md#put-api-user-copytrading-master-plans-id) — Plan updated.. Bhejo: `id` (is record ka database id); `plan_name` (plan ka naam); `name` (naam); `strategy_description` (trading strategy); `risk_info` (risk info (null)); `commission_value` (commission value (null)); `settlement_cycle` (kitne din me settlement); `no_fee_days` (no fee days (null)); `min_capital` (kam se kam capital); `copy_ratio` (copy ratio) … aur 1 fields.

### Master — Plan detail — `/copy-trading/master/plan/:id`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/master/plans`](client-portal-endpoints.md#get-api-user-copytrading-master-plans) — Plans retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

2. [`GET /api/user/copytrading/master/plans/{id}`](client-portal-endpoints.md#get-api-user-copytrading-master-plans-id) — Plan detail retrieved. Bhejo: `id` (is record ka database id).

**User action par (button / form submit):**

3. [`POST /api/user/copytrading/master/plans/{id}/inactivate`](client-portal-endpoints.md#post-api-user-copytrading-master-plans-id-inactivate) — Plan inactivated successfully.. Bhejo: `id` (is record ka database id).
4. [`POST /api/user/copytrading/master/plans/{id}/pause`](client-portal-endpoints.md#post-api-user-copytrading-master-plans-id-pause) — Plan paused. Copying is suspended until you resume.. Bhejo: `id` (is record ka database id).
5. [`POST /api/user/copytrading/master/plans/{id}/resume`](client-portal-endpoints.md#post-api-user-copytrading-master-plans-id-resume) — Plan resumed. Copying is active again.. Bhejo: `id` (is record ka database id).
6. [`PUT /api/user/copytrading/master/plans/{id}`](client-portal-endpoints.md#put-api-user-copytrading-master-plans-id) — Plan updated.. Bhejo: `id` (is record ka database id); `plan_name` (plan ka naam); `name` (naam); `strategy_description` (trading strategy); `risk_info` (risk info (null)); `commission_value` (commission value (null)); `settlement_cycle` (kitne din me settlement); `no_fee_days` (no fee days (null)); `min_capital` (kam se kam capital); `copy_ratio` (copy ratio) … aur 1 fields.

### Master — Copiers — `/copy-trading/master/copiers`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/master/copiers`](client-portal-endpoints.md#get-api-user-copytrading-master-copiers) — Copiers retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/copytrading/master/plans`](client-portal-endpoints.md#get-api-user-copytrading-master-plans) — Plans retrieved. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/user/copytrading/master/copiers/{copierId}/subscription-history`](client-portal-endpoints.md#get-api-user-copytrading-master-copiers-copierid-subscription-history) — Subscription history retrieved. Bhejo: `copierId` ← [`GET /api/user/copytrading/master/plans/{id}`](client-portal-endpoints.md#get-api-user-copytrading-master-plans-id) ka `data.activity_feed[].meta.copier_id`.

### Master — Settlements — `/copy-trading/master/settlements`

**Screen khulte hi (data load):**

1. [`GET /api/user/copytrading/master/settlements`](client-portal-endpoints.md#get-api-user-copytrading-master-settlements) — Settlements retrieved. Kuch bhejna nahi hai.

---

## Tickets

Support ticket banana, reply karna, band karna.

### Tickets list — `/tickets`

**Screen khulte hi (data load):**

1. [`GET /api/user/tickets`](client-portal-endpoints.md#get-api-user-tickets) — Tickets retrieved successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/tickets/departments`](client-portal-endpoints.md#get-api-user-tickets-departments) — Departments retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/user/tickets`](client-portal-endpoints.md#post-api-user-tickets) — Ticket created successfully. Bhejo: `title` (title); `department_id` (department ka id); `description` (description); `priority` (priority); `file` (file (null)).
4. [`POST /api/user/tickets/{ticketId}/close`](client-portal-endpoints.md#post-api-user-tickets-ticketid-close) — Ticket closed successfully. Bhejo: `ticketId` (ticket id (null)).

### New ticket — `/new-ticket`

**Screen khulte hi (data load):**

1. [`GET /api/user/tickets/departments`](client-portal-endpoints.md#get-api-user-tickets-departments) — Departments retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

2. [`POST /api/user/tickets`](client-portal-endpoints.md#post-api-user-tickets) — Ticket created successfully. Bhejo: `title` (title); `department_id` (department ka id); `description` (description); `priority` (priority); `file` (file (null)).

### Ticket detail — `/ticket/:id`

**Kisi item par tap karke (detail):**

1. [`GET /api/user/tickets/{ticketId}`](client-portal-endpoints.md#get-api-user-tickets-ticketid) — Data retrieved successfully. Bhejo: `ticketId` ← [`GET /api/user/tickets`](client-portal-endpoints.md#get-api-user-tickets) ka `data.data[].id`.

**User action par (button / form submit):**

2. [`POST /api/user/tickets/{ticketId}/close`](client-portal-endpoints.md#post-api-user-tickets-ticketid-close) — Ticket closed successfully. Bhejo: `ticketId` (ticket id (null)).
3. [`POST /api/user/tickets/{ticketId}/reply`](client-portal-endpoints.md#post-api-user-tickets-ticketid-reply) — Reply sent successfully. Bhejo: `ticketId` (ticket id (null)); `reply_text` (reply text (null)).

### Live chat — `/live-chat`

Is screen par koi API call nahi hoti.

---

## Platforms

MT5 / app download links.

### Platforms (download links) — `/platform`

**Screen khulte hi (data load):**

1. [`GET /api/user/crm-settings`](client-portal-endpoints.md#get-api-user-crm-settings) — CRM settings retrieved successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/platform-links`](client-portal-endpoints.md#get-api-user-platform-links) — Platform links retrieved successfully. Kuch bhejna nahi hai.

---

## Settings

Profile, security (password, 2FA), KYC, bank accounts, notification settings.

### Profile — `/settings-profile`

**Screen khulte hi (data load):**

1. [`GET /api/user/kyc`](client-portal-endpoints.md#get-api-user-kyc) — KYC data fetched successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/kyc/countries`](client-portal-endpoints.md#get-api-user-kyc-countries) — Countries retrieved successfully. Kuch bhejna nahi hai.
3. [`GET /api/user/settings/profile`](client-portal-endpoints.md#get-api-user-settings-profile) — User profile data retrieved successfully.. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

4. [`GET /api/user/kyc/cities/{stateId}`](client-portal-endpoints.md#get-api-user-kyc-cities-stateid) — Cities retrieved successfully. Bhejo: `stateId` ← [`GET /api/user/kyc/states/{countryId}`](client-portal-endpoints.md#get-api-user-kyc-states-countryid) ka `data[].id`.
5. [`GET /api/user/kyc/states/{countryId}`](client-portal-endpoints.md#get-api-user-kyc-states-countryid) — States retrieved successfully. Bhejo: `countryId` (country id (null)).

**User action par (button / form submit):**

6. [`POST /api/user/kyc/profile`](client-portal-endpoints.md#post-api-user-kyc-profile) — Profile updated successfully. Bhejo: `first_name` (user ka pehla naam); `last_name` (user ka surname); `mobile` (mobile number (country code ke bina)); `title` (title); `gender` (gender); `dob` (date of birth (yyyy-mm-dd)); `nationality` (nationality); `country` (country ka id (countries list se)); `state` (state ka id); `city` (city ka id) … aur 3 fields.

### Security (password, 2FA, devices) — `/settings-security`

**Screen khulte hi (data load):**

1. [`GET /api/user/robot-trading-status`](client-portal-endpoints.md#get-api-user-robot-trading-status) — Robot trading status retrieved. Kuch bhejna nahi hai.
2. [`GET /api/user/sessions`](client-portal-endpoints.md#get-api-user-sessions) — sessions — data laata hai. Kuch bhejna nahi hai.
3. [`GET /api/user/settings/google-otp/status`](client-portal-endpoints.md#get-api-user-settings-google-otp-status) — OTP status. Kuch bhejna nahi hai.

**User action par (button / form submit):**

4. [`DELETE /api/user/robot-trading-api-key`](client-portal-endpoints.md#delete-api-user-robot-trading-api-key) — API key revoked. Kuch bhejna nahi hai.
5. [`DELETE /api/user/sessions/{id}`](client-portal-endpoints.md#delete-api-user-sessions-id) — Session revoked successfully. Bhejo: `id` (is record ka database id).
6. [`POST /api/user/robot-trading-api-key`](client-portal-endpoints.md#post-api-user-robot-trading-api-key) — API key created. Store it securely; it will not be shown again.. Kuch bhejna nahi hai.
7. [`POST /api/user/robot-trading-api-key/regenerate`](client-portal-endpoints.md#post-api-user-robot-trading-api-key-regenerate) — API key regenerated. Store it securely; it will not be shown again.. Kuch bhejna nahi hai.
8. [`POST /api/user/settings/change-password`](client-portal-endpoints.md#post-api-user-settings-change-password) — Password changed successfully. Please login again.. Bhejo: `current_password` (abhi ka password); `password` (password); `current_password.required` (current password.required (null)); `password.required` (password.required (null)); `password.min` (password.min (null)); `password.max` (password.max (null)); `password.confirmed` (password.confirmed (null)); `password.regex` (password.regex (null)); `password_confirmation` (password dobara (match hona chahiye)).
9. [`POST /api/user/settings/google-otp/disable`](client-portal-endpoints.md#post-api-user-settings-google-otp-disable) — OTP disabled successfully. Bhejo: `otp_code` (otp code (mail ya google authenticator se)).
10. [`POST /api/user/settings/google-otp/generate`](client-portal-endpoints.md#post-api-user-settings-google-otp-generate) — OTP QR code generated. Kuch bhejna nahi hai.
11. [`POST /api/user/settings/google-otp/verify`](client-portal-endpoints.md#post-api-user-settings-google-otp-verify) — OTP verified and enabled successfully. Bhejo: `otp_code` (otp code (mail ya google authenticator se)).

### KYC — `/kyc`

**Screen khulte hi (data load):**

1. [`GET /api/user/kyc`](client-portal-endpoints.md#get-api-user-kyc) — KYC data fetched successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/kyc/countries`](client-portal-endpoints.md#get-api-user-kyc-countries) — Countries retrieved successfully. Kuch bhejna nahi hai.
3. [`GET /api/user/kyc/shufti/status`](client-portal-endpoints.md#get-api-user-kyc-shufti-status) — No verification found. Kuch bhejna nahi hai.
4. [`GET /api/user/regulation`](client-portal-endpoints.md#get-api-user-regulation) — Regulation details fetched successfully. Kuch bhejna nahi hai.
5. [`GET /api/user/settings/profile`](client-portal-endpoints.md#get-api-user-settings-profile) — User profile data retrieved successfully.. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

6. [`GET /api/user/kyc/cities/{stateId}`](client-portal-endpoints.md#get-api-user-kyc-cities-stateid) — Cities retrieved successfully. Bhejo: `stateId` ← [`GET /api/user/kyc/states/{countryId}`](client-portal-endpoints.md#get-api-user-kyc-states-countryid) ka `data[].id`.
7. [`GET /api/user/kyc/states/{countryId}`](client-portal-endpoints.md#get-api-user-kyc-states-countryid) — States retrieved successfully. Bhejo: `countryId` (country id (null)).

**User action par (button / form submit):**

8. [`POST /api/user/auth/google/check-mobile`](client-portal-endpoints.md#post-api-user-auth-google-check-mobile) — check mobile — request bhejta hai. Bhejo: `mobile` (mobile number (country code ke bina)); `country_code` (phone ka country code (jaise `+91`)).
9. [`POST /api/user/kyc/documents/upload`](client-portal-endpoints.md#post-api-user-kyc-documents-upload) — Documents uploaded successfully. Bhejo: `origin` (origin (null)); `field_key` (field key (null)); `document_type` (document type (null)); `subdocument_type` (subdocument type (null)); `files` (files (null)); `files.*` (files.* (null)); `file` (file (null)); `files.*.mimes` (files.*.mimes (null)); `file.mimes` (file.mimes (null)); `files[]` (files[] (null)).
10. [`POST /api/user/kyc/profile`](client-portal-endpoints.md#post-api-user-kyc-profile) — Profile updated successfully. Bhejo: `first_name` (user ka pehla naam); `last_name` (user ka surname); `mobile` (mobile number (country code ke bina)); `title` (title); `gender` (gender); `dob` (date of birth (yyyy-mm-dd)); `nationality` (nationality); `country` (country ka id (countries list se)); `state` (state ka id); `city` (city ka id) … aur 3 fields.
11. [`POST /api/user/kyc/shufti/start`](client-portal-endpoints.md#post-api-user-kyc-shufti-start) — start — request bhejta hai. Kuch bhejna nahi hai.
12. [`POST /api/user/kyc/submit-unified`](client-portal-endpoints.md#post-api-user-kyc-submit-unified) — KYC submitted successfully!. Bhejo: `is_reupload` (kya reupload hai? (`true` / `false`)); `title` (title); `gender` (gender); `date_of_birth` (date of birth (null)); `dob` (date of birth (yyyy-mm-dd)); `country` (country ka id (countries list se)); `state` (state ka id); `city` (city ka id); `address_line1` (address line1 (null)); `address_1` (address line 1) … aur 2 fields.
13. [`POST /api/user/kyc/sumsub/refresh`](client-portal-endpoints.md#post-api-user-kyc-sumsub-refresh) — Nothing to refresh.. Kuch bhejna nahi hai.
14. [`POST /api/user/kyc/sumsub/token`](client-portal-endpoints.md#post-api-user-kyc-sumsub-token) — token — request bhejta hai. Kuch bhejna nahi hai.
15. [`POST /api/user/mobile-verification/send`](client-portal-endpoints.md#post-api-user-mobile-verification-send) — Mobile number is already verified.. Kuch bhejna nahi hai.
16. [`POST /api/user/mobile-verification/verify`](client-portal-endpoints.md#post-api-user-mobile-verification-verify) — Mobile number is already verified.. Bhejo: `otp` (user ko mail / sms par aaya otp).
17. [`POST /api/user/regulation`](client-portal-endpoints.md#post-api-user-regulation) — Regulation details saved successfully. Bhejo: `profile_snapshot` (profile snapshot (null)).

### Documents — `/settings-documents`

**Screen khulte hi (data load):**

1. [`GET /api/user/kyc`](client-portal-endpoints.md#get-api-user-kyc) — KYC data fetched successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/settings/profile`](client-portal-endpoints.md#get-api-user-settings-profile) — User profile data retrieved successfully.. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/user/kyc-image-proxy/{documentId}`](client-portal-endpoints.md#get-api-user-kyc-image-proxy-documentid) — kyc image proxy — data laata hai. Bhejo: `documentId` (document id (null)).

**User action par (button / form submit):**

4. [`POST /api/user/kyc/documents/finalize-chunked`](client-portal-endpoints.md#post-api-user-kyc-documents-finalize-chunked) — File uploaded successfully. Bhejo: `sessionId` (session id (null)); `fileName` (file name (null)); `fileSize` (file size (null)); `document_type` (document type (null)); `subdocument_type` (subdocument type (null)).
5. [`POST /api/user/kyc/documents/upload`](client-portal-endpoints.md#post-api-user-kyc-documents-upload) — Documents uploaded successfully. Bhejo: `origin` (origin (null)); `field_key` (field key (null)); `document_type` (document type (null)); `subdocument_type` (subdocument type (null)); `files` (files (null)); `files.*` (files.* (null)); `file` (file (null)); `files.*.mimes` (files.*.mimes (null)); `file.mimes` (file.mimes (null)); `files[]` (files[] (null)).
6. [`POST /api/user/kyc/documents/upload-chunk`](client-portal-endpoints.md#post-api-user-kyc-documents-upload-chunk) — Chunk uploaded successfully. Bhejo: `chunk` (chunk (null)); `chunkIndex` (chunk index (null)); `totalChunks` (total chunks (null)); `fileName` (file name (null)); `fileSize` (file size (null)); `fileType` (file type (null)); `document_type` (document type (null)); `subdocument_type` (subdocument type (null)).

### Bank / withdrawal accounts — `/settings-bank-accounts`

**Screen khulte hi (data load):**

1. [`GET /api/user/regulation`](client-portal-endpoints.md#get-api-user-regulation) — Regulation details fetched successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/withdrawal`](client-portal-endpoints.md#get-api-user-withdrawal) — Withdrawal methods retrieved successfully. Kuch bhejna nahi hai.
3. [`GET /api/user/withdrawal/getUserWithdrawalMethods`](client-portal-endpoints.md#get-api-user-withdrawal-getuserwithdrawalmethods) — Withdrawal methods retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

4. [`DELETE /api/user/withdrawal/delete/{id}`](client-portal-endpoints.md#delete-api-user-withdrawal-delete-id) — Withdrawal method deleted successfully. Bhejo: `id` (is record ka database id).
5. [`GET /api/user/withdrawal/sendOTP`](client-portal-endpoints.md#get-api-user-withdrawal-sendotp) — send OTP — data laata hai. Kuch bhejna nahi hai.
6. [`POST /api/user/utility/ifsc-code`](client-portal-endpoints.md#post-api-user-utility-ifsc-code) — IFSC code retrieved successfully. Bhejo: `ifscCode` (ifsc code (null)).
7. [`POST /api/user/withdrawal`](client-portal-endpoints.md#post-api-user-withdrawal) — withdrawal — request bhejta hai. Bhejo: `withdrawal_method.required` (withdrawal method.required (null)); `withdrawal_method.in` (withdrawal method.in (null)); `currency.required` (currency.required (null)); `relationship.required` (relationship.required (null)); `relationship.in` (relationship.in (null)); `otp.required` (otp.required (null)); `otp.digits` (otp.digits (null)); `.required` (.required (null)); `.regex` (.regex (null)); `bank_name.required` (bank name.required (null)) … aur 21 fields.

### Withdrawal details — `/settings-withdrawal-details/:id`

**Screen khulte hi (data load):**

1. [`GET /api/user/regulation`](client-portal-endpoints.md#get-api-user-regulation) — Regulation details fetched successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/withdrawal/getUserWithdrawalMethods`](client-portal-endpoints.md#get-api-user-withdrawal-getuserwithdrawalmethods) — Withdrawal methods retrieved successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

3. [`GET /api/user/image-proxy/{id}`](client-portal-endpoints.md#get-api-user-image-proxy-id) — image proxy — data laata hai. Bhejo: `id` (is record ka database id).

### Login activities — `/settings-activities`

**Screen khulte hi (data load):**

1. [`GET /api/user/sessions`](client-portal-endpoints.md#get-api-user-sessions) — sessions — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/user/settings/activitylog`](client-portal-endpoints.md#get-api-user-settings-activitylog) — Activities retrieved successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`DELETE /api/user/sessions/{id}`](client-portal-endpoints.md#delete-api-user-sessions-id) — Session revoked successfully. Bhejo: `id` (is record ka database id).

### Notification preferences — `/settings-notifications`

**Screen khulte hi (data load):**

1. [`GET /api/user/email-preferences`](client-portal-endpoints.md#get-api-user-email-preferences) — Email preferences retrieved.. Kuch bhejna nahi hai.

**User action par (button / form submit):**

2. [`POST /api/user/email-preferences`](client-portal-endpoints.md#post-api-user-email-preferences) — Email preferences updated.. Bhejo: `marketing` (marketing (null)); `newsletters` (newsletters (null)); `product_updates` (product updates (null)).

### API guide — `/api-guide`

Is screen par koi API call nahi hoti.

### Email unsubscribe — `/unsubscribe`

**Screen khulte hi (data load):**

1. [`GET /api/email/unsubscribe/resolve`](client-portal-endpoints.md#get-api-email-unsubscribe-resolve) — resolve — data laata hai. Kuch bhejna nahi hai.

**User action par (button / form submit):**

2. [`POST /api/email/unsubscribe`](client-portal-endpoints.md#post-api-email-unsubscribe) — unsubscribe — request bhejta hai. Bhejo: `token` (token (null)).

---

## Promotions & extras (header / dashboard links)

Notifications, bonus, scratch card, trade & win, demo contest.

### Notifications list — `/notifications`

**Screen khulte hi (data load):**

1. [`GET /api/user/notifications/all`](client-portal-endpoints.md#get-api-user-notifications-all) — all — data laata hai. Kuch bhejna nahi hai.

### Bonus — `/bonus`

**Screen khulte hi (data load):**

1. [`GET /api/user/bonus`](client-portal-endpoints.md#get-api-user-bonus) — Bonus fetched successfully. Kuch bhejna nahi hai.
2. [`GET /api/user/bonus/bonusClaimList`](client-portal-endpoints.md#get-api-user-bonus-bonusclaimlist) — Bonus fetched successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/user/bonus/bonusClaim`](client-portal-endpoints.md#post-api-user-bonus-bonusclaim) — Bonus request submitted — pending approval. Bhejo: `deposit_id` (deposit ka id); `bonus_id` (bonus ka id).
4. [`POST /api/user/bonus/bonusClaimCancel`](client-portal-endpoints.md#post-api-user-bonus-bonusclaimcancel) — bonus Claim Cancel — request bhejta hai. Bhejo: `id` (is record ka database id); `reason` (kaaran (reason)).

### Scratch card promotion — `/promotion`

**Screen khulte hi (data load):**

1. [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) — Trading accounts retrieved successfully. Kuch bhejna nahi hai.
2. [`GET /api/v1/user/scratch-cards`](client-portal-endpoints.md#get-api-v1-user-scratch-cards) — Scratch cards fetched successfully. Kuch bhejna nahi hai.
3. [`GET /api/v1/user/scratch-cards/leaderboard`](client-portal-endpoints.md#get-api-v1-user-scratch-cards-leaderboard) — Leaderboard fetched successfully. Kuch bhejna nahi hai.

**User action par (button / form submit):**

4. [`POST /api/user/mobile-verification/send`](client-portal-endpoints.md#post-api-user-mobile-verification-send) — Mobile number is already verified.. Kuch bhejna nahi hai.
5. [`POST /api/user/mobile-verification/verify`](client-portal-endpoints.md#post-api-user-mobile-verification-verify) — Mobile number is already verified.. Bhejo: `otp` (user ko mail / sms par aaya otp).
6. [`POST /api/user/mt5accounts/create`](client-portal-endpoints.md#post-api-user-mt5accounts-create) — Live account created successfully. Bhejo: `group_id` (group (account type / plan group) ka id); `leverage` (naya leverage (jaise 100 = 1:100)); `main_password` (main password (null)); `investor_password` (investor password (null)).
7. [`POST /api/v1/user/scratch-cards/claim`](client-portal-endpoints.md#post-api-v1-user-scratch-cards-claim) — Your claim has been sent for approval.. Kuch bhejna nahi hai.
8. [`POST /api/v1/user/scratch-cards/reveal`](client-portal-endpoints.md#post-api-v1-user-scratch-cards-reveal) — reveal — request bhejta hai. Bhejo: `card_id` (card ka id).

### Trade & Win — `/promotion/trade-win`

**Screen khulte hi (data load):**

1. [`GET /api/v1/user/trade-win/products`](client-portal-endpoints.md#get-api-v1-user-trade-win-products) — Products retrieved successfully.. Kuch bhejna nahi hai.
2. [`GET /api/v1/user/trade-win/saved-addresses`](client-portal-endpoints.md#get-api-v1-user-trade-win-saved-addresses) — Saved addresses retrieved successfully.. Kuch bhejna nahi hai.

**User action par (button / form submit):**

3. [`POST /api/v1/user/trade-win/claim`](client-portal-endpoints.md#post-api-v1-user-trade-win-claim) — Claim successful!. Bhejo: `product_id` (product ka id); `quantity` (quantity (null)); `shipping_details` (shipping details (null)); `audience` (kiske liye (client / ib)).

### Demo Contest list — `/demo-contest`

**Screen khulte hi (data load):**

1. [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) — contests — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) — my stats — data laata hai. Bhejo: `contest_id` ← [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
3. [`GET /api/user/kyc`](client-portal-endpoints.md#get-api-user-kyc) — KYC data fetched successfully. Kuch bhejna nahi hai.
4. [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) — Trading accounts retrieved successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

5. [`GET /api/user/demo-contest/{contestId}/leaderboard`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-leaderboard) — leaderboard — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
6. [`GET /api/user/demo-contest/{contestId}/rule-violations`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-rule-violations) — rule violations — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
7. [`GET /api/user/demo-contest/{contestId}/steps`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-steps) — steps — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
8. [`GET /api/user/demo-contest/{contestId}/terms`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-terms) — terms — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
9. [`GET /api/user/demo-contest/{contestId}/trading-history`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-trading-history) — trading history — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.

**User action par (button / form submit):**

10. [`POST /api/user/demo-contest/{contestId}/enroll`](client-portal-endpoints.md#post-api-user-demo-contest-contestid-enroll) — Successfully enrolled! Your contest MT5 account has been created and credited.. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`; `terms_accepted` (user ne terms accept kiye (`true`)).
11. [`POST /api/user/demo-contest/{contestId}/enroll-preview`](client-portal-endpoints.md#post-api-user-demo-contest-contestid-enroll-preview) — enroll preview — request bhejta hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
12. [`POST /api/user/demo-contest/claim`](client-portal-endpoints.md#post-api-user-demo-contest-claim) — Claim submitted successfully!. Bhejo: `contest_id` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`; `real_account_number` (real account number).
13. [`POST /api/user/demo-contest/step/{stepId}/click`](client-portal-endpoints.md#post-api-user-demo-contest-step-stepid-click) — Step marked as completed.. Bhejo: `stepId` (step id (null)).

### Demo Contest detail — `/demo-contest/:id`

**Screen khulte hi (data load):**

1. [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) — contests — data laata hai. Kuch bhejna nahi hai.
2. [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) — my stats — data laata hai. Bhejo: `contest_id` ← [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
3. [`GET /api/user/kyc`](client-portal-endpoints.md#get-api-user-kyc) — KYC data fetched successfully. Kuch bhejna nahi hai.
4. [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) — Trading accounts retrieved successfully. Kuch bhejna nahi hai.

**Kisi item par tap karke (detail):**

5. [`GET /api/user/demo-contest/{contestId}/leaderboard`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-leaderboard) — leaderboard — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
6. [`GET /api/user/demo-contest/{contestId}/rule-violations`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-rule-violations) — rule violations — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
7. [`GET /api/user/demo-contest/{contestId}/steps`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-steps) — steps — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
8. [`GET /api/user/demo-contest/{contestId}/terms`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-terms) — terms — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
9. [`GET /api/user/demo-contest/{contestId}/trading-history`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-trading-history) — trading history — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.

**User action par (button / form submit):**

10. [`POST /api/user/demo-contest/{contestId}/enroll`](client-portal-endpoints.md#post-api-user-demo-contest-contestid-enroll) — Successfully enrolled! Your contest MT5 account has been created and credited.. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`; `terms_accepted` (user ne terms accept kiye (`true`)).
11. [`POST /api/user/demo-contest/{contestId}/enroll-preview`](client-portal-endpoints.md#post-api-user-demo-contest-contestid-enroll-preview) — enroll preview — request bhejta hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.
12. [`POST /api/user/demo-contest/claim`](client-portal-endpoints.md#post-api-user-demo-contest-claim) — Claim submitted successfully!. Bhejo: `contest_id` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`; `real_account_number` (real account number).
13. [`POST /api/user/demo-contest/step/{stepId}/click`](client-portal-endpoints.md#post-api-user-demo-contest-step-stepid-click) — Step marked as completed.. Bhejo: `stepId` (step id (null)).
14. [`POST /api/user/mt5accounts/changePrimaryAccount`](client-portal-endpoints.md#post-api-user-mt5accounts-changeprimaryaccount) — Primary account changed successfully. Bhejo: `mt5_account` ← [`GET /api/user/mt5accounts/get`](client-portal-endpoints.md#get-api-user-mt5accounts-get) ka `data[].meta_account_number` ya [`GET /api/user/copytrading/copier/eligible-accounts`](client-portal-endpoints.md#get-api-user-copytrading-copier-eligible-accounts) ka `data[].meta_account_number`.

### Demo Contest leaderboard — `/demo-contest/:id/leaderboard`

**Kisi item par tap karke (detail):**

1. [`GET /api/user/demo-contest/{contestId}/leaderboard`](client-portal-endpoints.md#get-api-user-demo-contest-contestid-leaderboard) — leaderboard — data laata hai. Bhejo: `contestId` ← [`GET /api/user/demo-contest/my-stats`](client-portal-endpoints.md#get-api-user-demo-contest-my-stats) ka `data.participant.contest_id` ya [`GET /api/user/demo-contest/contests`](client-portal-endpoints.md#get-api-user-demo-contest-contests) ka `data[].contest.prizes[].contest_id`.

### Trading Central — `/trading-central/:page?`

**Screen khulte hi (data load):**

1. [`GET /api/user/trading-central`](client-portal-endpoints.md#get-api-user-trading-central) — Trading Central settings retrieved successfully. Kuch bhejna nahi hai.

### Under maintenance — `/maintenance`

Is screen par koi API call nahi hoti.

---
