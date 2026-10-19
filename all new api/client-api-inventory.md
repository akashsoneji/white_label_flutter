# Client frontend — API inventory (menu → page → API)

- Frontend: `crmfronend` **main-merger** @ `22890f77`
- Backend: `crmwebadmin` **development-new** @ `8a38a4707`
- Generated: 2026-10-16. Responses are read from the controller source (no live calls).

## How to read this

- **Base URLs:** client `{{baseUrl}}/api/user` (`src/services/api.js`), IB Manager portal `{{baseUrl}}/api/ibm` (`ibmanager-portal/ibmanagerApi.js`), copy trading `/api/user/copytrading` + public `/api/copytrading`, scratch card / trade & win `/api/v1/user`, IB demo contest `/api/ib`.
- **Auth:** `Authorization: Bearer <auth_token>` (localStorage `auth_token`). Every GET also sends `_t=<timestamp>` cache-buster and `Accept-Language`.
- **Standard envelope** (`core/app/Http/Controllers/Controller.php:207` `apiResponse`): `{ "status": <http code>, "success": true|false, "message": "...", "data": {...} }` — `null` values become `""`.
- **IB Manager portal envelope** (`Modules/IBManager/Http/Controllers/Portal/PortalController.php:62-70`): `{ "success": true|false, "message": "...", "data": ... }` (no `status` key; errors use HTTP 400/403/404/422).
- `"..."` in a sample = the value comes from the DB; the key names are exact. File:line points at the exact `return`.
- APIs loaded by the app shell (sidebar, header, App root) are listed once under **App shell** and not repeated on every page.

> The Affiliate portal is **not on main-merger** (it lives only on branch `afiliate_TNX-277`), so it is not covered here.

## Summary

- **Auth (Login / Register / OTP / Password)** — 11 pages, 16 APIs
  - Login (`/login`) — 3 APIs
  - Register (`/register`) — 7 APIs
  - OTP Verification (signup) (`/otp-verification`) — 1 APIs
  - Complete Registration (Google signup) (`/complete-registration`) — 3 APIs
  - Forgot Password (`/forgot-password`) — 1 APIs
  - Verify OTP (password reset) (`/verify-otp`) — 2 APIs
  - Reset Password (`/reset-password`) — 2 APIs
  - Google OAuth callback (`/auth/google/callback`) — 1 APIs
  - Auto-login from landing site (`/auth/from-net`) — 1 APIs
  - SSO verify (`/user/sso/verify/:token`) — 0 APIs
  - Invite / Referral link (`/user/invite/:referral_code`) — 1 APIs
- **App shell (every logged-in page)** — 6 pages, 17 APIs
  - App root (`(all)`) — 3 APIs
  - Left sidebar (`(all)`) — 1 APIs
  - Top header (`(all)`) — 9 APIs
  - Router guard (module check before each page) (`(all)`) — 5 APIs
  - Mobile navigation (`(all)`) — 4 APIs
  - Page banners (`(all)`) — 3 APIs
- **Dashboard** — 1 pages, 11 APIs
  - Dashboard (`/dashboard`) — 11 APIs
- **Trading Accounts** — 1 pages, 9 APIs
  - Trading Accounts (`/trading-accounts`) — 9 APIs
- **Trading Terminal** — 3 pages, 27 APIs
  - Trading Terminal (launcher) (`/trading-terminal`) — 2 APIs
  - Web Trader (terminal) (`/trading`) — 27 APIs
  - Mobile WebView chart (`/mobile-chart`) — 3 APIs
- **Deposit** — 5 pages, 9 APIs
  - Deposit (methods) (`/deposit`) — 1 APIs
  - Deposit request / history (`/deposit-request`) — 7 APIs
  - UniPayment success (`/deposit/unipayment/success`) — 1 APIs
  - UniPayment cancel (`/deposit/unipayment/cancel`) — 0 APIs
  - Cregis success (`/deposit/cregis/success`) — 1 APIs
- **Withdrawal** — 2 pages, 6 APIs
  - Withdrawal (methods) (`/withdrawal`) — 1 APIs
  - Withdrawal request / history (`/withdrawal-request`) — 5 APIs
- **Internal Transfer** — 3 pages, 11 APIs
  - Internal Transfer (`/internal-transfer`) — 6 APIs
  - Internal Transfer History (`/internal-transfer-history`) — 1 APIs
  - Trader to Trader Transfer (`/trader-transfer`) — 5 APIs
- **IB Dashboard (classic IB)** — 10 pages, 45 APIs
  - IB Dashboard / IB Application (`/ib-dashboard`) — 8 APIs
  - My Structure (`/my-structure`) — 3 APIs
  - Sub IB Structure (`/sub-ib-structure`) — 3 APIs
  - Sub IB Structure — create/edit commission group (`/sub-ib-structure/create`) — 4 APIs
  - My Network (clients) (`/my-client`) — 9 APIs
  - Sub IB Approval (`/sub-ib-approval`) — 3 APIs
  - Transfer Commission (`/ib-transfer-create`) — 3 APIs
  - Transfer Commission History (`/ib-transfer-history`) — 2 APIs
  - IB Trade & Win (`/ib/trade-win`) — 3 APIs
  - IB Demo Contest (list/create/edit/view) (`/ib-contest`) — 11 APIs
- **IB Manager Portal** — 15 pages, 49 APIs
  - Portal shell (common calls) (`/ib-manager-portal`) — 1 APIs
  - Dashboard (`/ib-manager-portal`) — 3 APIs
  - My Clients (`/ib-manager-portal/clients`) — 6 APIs
  - Person detail (client / sub-IB) (`/ib-manager-portal/people/:personId`) — 11 APIs
  - Sub-IB Requests (`/ib-manager-portal/requests`) — 4 APIs
  - Sub-IB Performance (from dashboard "View all") (`/ib-manager-portal/sub-ibs`) — 1 APIs
  - Commission Plans (`/ib-manager-portal/plans`) — 9 APIs
  - My Commission (`/ib-manager-portal/commission`) — 11 APIs
  - My Team Deposit / My Team Withdrawal (`/ib-manager-portal/team-deposits`) — 4 APIs
  - IB Commission report (`/ib-manager-portal/ib-commission-report`) — 4 APIs
  - IB Withdraw report (`/ib-manager-portal/ib-withdraw-report`) — 4 APIs
  - Referral Links (`/ib-manager-portal/referrals`) — 6 APIs
  - Marketing Material (`/ib-manager-portal/marketing`) — 1 APIs
  - Settings (`/ib-manager-portal/settings`) — 4 APIs
  - Transfer Commission (leaves portal → Internal Transfer page) (`/internal-transfer`) — see Internal Transfer
- **Transaction History** — 2 pages, 2 APIs
  - Transaction History (`/transaction-history`) — 1 APIs
  - Wallet History (`/wallet-history`) — 2 APIs
- **PAMM** — 11 pages, 33 APIs
  - Explore Fund Managers (`/pmam/investor/explore`) — 12 APIs
  - My Investments (`/pmam/investor/my-investments`) — 12 APIs
  - Managers list (`/pmam/managers`) — 1 APIs
  - Manager public profile (`/pmam/manager/:code`) — 6 APIs
  - Become a manager (apply) (`/pmam/manager/apply`) — 1 APIs
  - Manager dashboard (`/pmam/manager/dashboard`) — 3 APIs
  - Manager — My Plans (`/pmam/manager/plans`) — 7 APIs
  - Manager — Plan view (`/pmam/manager/plans/:planId`) — 3 APIs
  - Manager — Investor requests (`/pmam/manager/plans/:planId/requests`) — 3 APIs
  - Manager — Investors (`/pmam/manager/investors`) — 5 APIs
  - Manager — Commissions (`/pmam/manager/commissions`) — 2 APIs
- **Copy Trading** — 10 pages, 31 APIs
  - Leaderboard (`/copy-trade`) — 7 APIs
  - Master profile (`/copy-trade/master/:code`) — 6 APIs
  - My Investments (copier dashboard) (`/copy-trading/dashboard`) — 5 APIs
  - Subscription detail (`/copy-trading/dashboard/subscription/:id`) — 7 APIs
  - Master dashboard (`/copy-trading/master/dashboard`) — 3 APIs
  - Master dashboard (legacy) (`/copy-trading/master/dashboard/legacy`) — 6 APIs
  - Master — Plans (`/copy-trading/master/plans`) — 7 APIs
  - Master — Plan detail (`/copy-trading/master/plan/:id`) — 6 APIs
  - Master — Copiers (`/copy-trading/master/copiers`) — 3 APIs
  - Master — Settlements (`/copy-trading/master/settlements`) — 1 APIs
- **Tickets** — 4 pages, 6 APIs
  - Tickets list (`/tickets`) — 4 APIs
  - New ticket (`/new-ticket`) — 2 APIs
  - Ticket detail (`/ticket/:id`) — 3 APIs
  - Live chat (`/live-chat`) — 0 APIs
- **Platforms** — 1 pages, 2 APIs
  - Platforms (download links) (`/platform`) — 2 APIs
- **Settings** — 10 pages, 43 APIs
  - Profile (`/settings-profile`) — 6 APIs
  - Security (password, 2FA, devices) (`/settings-security`) — 11 APIs
  - KYC (`/kyc`) — 17 APIs
  - Documents (`/settings-documents`) — 6 APIs
  - Bank / withdrawal accounts (`/settings-bank-accounts`) — 7 APIs
  - Withdrawal details (`/settings-withdrawal-details/:id`) — 3 APIs
  - Login activities (`/settings-activities`) — 3 APIs
  - Notification preferences (`/settings-notifications`) — 2 APIs
  - API guide (`/api-guide`) — 0 APIs
  - Email unsubscribe (`/unsubscribe`) — 2 APIs
- **Promotions & extras (header / dashboard links)** — 9 pages, 30 APIs
  - Notifications list (`/notifications`) — 1 APIs
  - Bonus (`/bonus`) — 4 APIs
  - Scratch card promotion (`/promotion`) — 8 APIs
  - Trade & Win (`/promotion/trade-win`) — 3 APIs
  - Demo Contest list (`/demo-contest`) — 13 APIs
  - Demo Contest detail (`/demo-contest/:id`) — 14 APIs
  - Demo Contest leaderboard (`/demo-contest/:id/leaderboard`) — 1 APIs
  - Trading Central (`/trading-central/:page?`) — 1 APIs
  - Under maintenance (`/maintenance`) — 0 APIs

**Total unique APIs:** 306

---

## Auth (Login / Register / OTP / Password)

> Public screens before login. Default auth layout (config/authLayouts.js:30-70). Branded layouts (pipze, gtxprime, skyriss, pipze-net) call the same endpoints.

### Login — `/login`

Component: `src/components/LoginScreen.vue` — **3 APIs**

1. `GET /api/user/auth/google/redirect` → `GoogleAuthController@redirectToGoogle`
2. `POST /api/user/auth/google/verify-login-otp` → `GoogleAuthController@verifyLoginOTP`
3. `POST /api/user/login` → `AuthController@login`

<details><summary>Request / response details</summary>

##### `GET /api/user/auth/google/redirect`

- **Frontend:** `googleAuthService.getGoogleAuthUrl` (`src/services/googleAuth.service.js:40`)
- **Triggered from:** `handleGoogleLogin`
- **Backend:** `GoogleAuthController@redirectToGoogle` — `core/app/Http/Controllers/User/GoogleAuthController.php:52-141`
- **Middleware:** `logNavigation`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:119`
```json
{
  "status": 200,
  "success": true,
  "message": "Redirect URL generated",
  "data": {
    "auth_url": "..."
  }
}
```

**Errors** (`success: false`)
- `:58` `403` — Google SSO is not enabled
- `:68` `500` — Google OAuth is not properly configured. Please contact administrator.
- `:139` `500` — ($errorMessage, false, $errorData, 500)

##### `POST /api/user/auth/google/verify-login-otp`

- **Frontend:** `googleAuthService.verifyLoginOTP` (`src/services/googleAuth.service.js:189`)
- **Triggered from:** `handleVerify`
- **Backend:** `GoogleAuthController@verifyLoginOTP` — `core/app/Http/Controllers/User/GoogleAuthController.php:617-669`
- **Middleware:** `logNavigation`
- **Request fields (validated):** `email`, `otp_code`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:658`
```json
{
  "status": 200,
  "success": true,
  "message": "OTP verified successfully",
  "data": {
    "user": "...",
    "token": "...",
    "websocket_token": "...",
    "redirect": "..."
  }
}
```

**Errors** (`success: false`)
- `:626` `422` — Validation failed
- `:632` `404` — User not found
- `:636` `400` — Google OTP is not enabled for this account
- `:641` `401` — Invalid OTP code
- `:667` `500` — Failed to verify OTP: 

##### `POST /api/user/login`

- **Frontend:** `authService.login` (`src/services/auth.service.js:53`)
- **Triggered from:** `handleLogin`
- **Backend:** `AuthController@login` — `core/app/Http/Controllers/User/AuthController.php:236-438`
- **Middleware:** `logNavigation`, `throttle:10,1`
- **Request fields (validated):** `password`, `fcm_token`, `device_type`

**Success**

`core/app/Http/Controllers/User/AuthController.php:342`
```json
{
  "status": 200,
  "success": true,
  "message": "Google Authenticator setup is required",
  "data": {
    "requires_google_otp_setup": "...",
    "email": "..."
  }
}
```
`core/app/Http/Controllers/User/AuthController.php:349`
```json
{
  "status": 200,
  "success": true,
  "message": "Two-factor authentication required",
  "data": {
    "requires_google_otp": "...",
    "email": "..."
  }
}
```
`core/app/Http/Controllers/User/AuthController.php:396`
```json
{
  "status": 200,
  "success": true,
  "message": "auth.sign_in",
  "data": {
    "user": "...",
    "token": "...",
    "websocket_token": "...",
    "redirect": "..."
  }
}
```
`core/app/Http/Controllers/User/AuthController.php:419`
```json
{
  "status": 200,
  "success": true,
  "message": "auth.sign_in",
  "data": {
    "redirect": "..."
  }
}
```

</details>

### Register — `/register`

Component: `src/components/RegisterScreen.vue` — **7 APIs**

1. `GET /api/ibm/r/{code}`
2. `GET /api/user` → external
3. `GET /api/user/auth/google/redirect` → `GoogleAuthController@redirectToGoogle`
4. `GET /api/user/crm-settings` → `SettingController@getCrmSettings`
5. `GET /api/user/json` → external
6. `POST /api/user/ib/track-sponsor-visit` → `IbaController@trackSponsorCodeVisit`
7. `POST /api/user/register` → `AuthController@register`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/r/{code}`

- **Frontend:** `trackIbmLinkVisit` (`src/components/RegisterScreen.vue:340`)
- **Triggered from:** `trackIbmLinkVisit`
- **Backend:** _no matching route on development-new_

_Response shape not detected — see controller._

##### `GET /api/user`

- **External call, not the CRM:** `GET https://api.ipify.org?format=json` — Visitor IP lookup (IB link tracking)
- Called from: `src/components/RegisterScreen.vue:357`

##### `GET /api/user/auth/google/redirect`

- **Frontend:** `googleAuthService.getGoogleAuthUrl` (`src/services/googleAuth.service.js:40`)
- **Triggered from:** `typedRef`
- **Backend:** `GoogleAuthController@redirectToGoogle` — `core/app/Http/Controllers/User/GoogleAuthController.php:52-141`
- **Middleware:** `logNavigation`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:119`
```json
{
  "status": 200,
  "success": true,
  "message": "Redirect URL generated",
  "data": {
    "auth_url": "..."
  }
}
```

**Errors** (`success: false`)
- `:58` `403` — Google SSO is not enabled
- `:68` `500` — Google OAuth is not properly configured. Please contact administrator.
- `:139` `500` — ($errorMessage, false, $errorData, 500)

##### `GET /api/user/crm-settings`

- **Frontend:** `crmSettingsService.getCrmSettings` (`src/services/crmSettings.service.js:19`)
- **Triggered from:** `mounted`, `setup`
- **Backend:** `SettingController@getCrmSettings` — `core/app/Http/Controllers/Common/SettingController.php:475-489`
- **Middleware:** `logNavigation`

**Success**

`core/app/Http/Controllers/Common/SettingController.php:478`
```json
{
  "status": 200,
  "success": true,
  "message": "CRM settings retrieved successfully",
  "data": "<$crmSettingsService->getPublicPayload()>"
}
```

**Errors** (`success: false`)
- `:487` `500` — Error: 

##### `GET /api/user/json`

- **External call, not the CRM:** `GET https://ipapi.co/json/ (and fallback https://api.country.is/)` — Country / IP lookup to pre-fill the phone country on signup
- Called from: `src/components/RegisterScreen.vue:350`

##### `POST /api/user/ib/track-sponsor-visit`

- **Frontend:** `subIbService.trackSponsorCodeVisit` (`src/services/sub-ib.service.js:127`)
- **Triggered from:** `ibmFromUrl`
- **Backend:** `IbaController@trackSponsorCodeVisit` — `core/app/Http/Controllers/User/IbaController.php:5669-5709`
- **Request fields (validated):** `sponsorcode`

**Success**

`core/app/Http/Controllers/User/IbaController.php:5683`
```json
{
  "status": 200,
  "success": true,
  "message": "Visit processed",
  "data": {
    "reference_link_id": "...",
    "visit_count": "..."
  }
}
```
`core/app/Http/Controllers/User/IbaController.php:5692`
```json
{
  "status": 200,
  "success": true,
  "message": "Visit tracked successfully",
  "data": {
    "reference_link_id": "...",
    "visit_count": "..."
  }
}
```

##### `POST /api/user/register`

- **Frontend:** `authService.register` (`src/services/auth.service.js:160`)
- **Triggered from:** `isoCountry`
- **Backend:** `AuthController@register` — `core/app/Http/Controllers/User/AuthController.php:496-695`
- **Middleware:** `logNavigation`, `feature.maintenance:registration`

> One endpoint, four steps chosen by `register_event_type` (AuthController.php:496). Handlers: handleInitialRegistration :603, handleResendOtp :685, handleOtpVerification :739, handleCompleteRegistration :881.

**Success**
```json
// register_event_type = register (send OTP)
{ "status": 200, "success": true, "message": "...", "data": { "lead": { ... } } }

// register_event_type = resendOtp
{ "status": 200, "success": true, "message": "...", "data": "" }

// register_event_type = verifyOtp / completeRegister (account created + logged in)
{ "status": 200, "success": true, "message": "...",
  "data": { "user": { ... }, "token": "<sanctum token>", "websocket_token": "...", "redirect": "<auto-login url>" } }
```
**Error**
```json
{ "status": 422|400, "success": false, "message": "Domain not allowed | Registration is not available in your country. | already registered ...", "data": "" }
```

</details>

### OTP Verification (signup) — `/otp-verification`

Component: `src/components/OTPVerification.vue` — **1 APIs**

1. `POST /api/user/register` → `AuthController@register`

<details><summary>Request / response details</summary>

##### `POST /api/user/register`

- **Frontend:** `authService.register` (`src/services/auth.service.js:160`), `authService.verifyOTP` (`src/services/auth.service.js:192`)
- **Triggered from:** `resendOTP`, `handleOTPVerification`
- **Backend:** `AuthController@register` — `core/app/Http/Controllers/User/AuthController.php:496-695`
- **Middleware:** `logNavigation`, `feature.maintenance:registration`

> One endpoint, four steps chosen by `register_event_type` (AuthController.php:496). Handlers: handleInitialRegistration :603, handleResendOtp :685, handleOtpVerification :739, handleCompleteRegistration :881.

**Success**
```json
// register_event_type = register (send OTP)
{ "status": 200, "success": true, "message": "...", "data": { "lead": { ... } } }

// register_event_type = resendOtp
{ "status": 200, "success": true, "message": "...", "data": "" }

// register_event_type = verifyOtp / completeRegister (account created + logged in)
{ "status": 200, "success": true, "message": "...",
  "data": { "user": { ... }, "token": "<sanctum token>", "websocket_token": "...", "redirect": "<auto-login url>" } }
```
**Error**
```json
{ "status": 422|400, "success": false, "message": "Domain not allowed | Registration is not available in your country. | already registered ...", "data": "" }
```

</details>

### Complete Registration (Google signup) — `/complete-registration`

Component: `src/components/CompleteRegistration.vue` — **3 APIs**

1. `GET /api/user/json` → external
2. `POST /api/user/auth/google/check-mobile` → `GoogleAuthController@checkMobileAvailability`
3. `POST /api/user/auth/google/complete-registration` → `GoogleAuthController@completeGoogleRegistration`

<details><summary>Request / response details</summary>

##### `GET /api/user/json`

- **External call, not the CRM:** `GET https://ipapi.co/json/ (and fallback https://api.country.is/)` — Country / IP lookup to pre-fill the phone country on signup
- Called from: `src/components/CompleteRegistration.vue:327`

##### `POST /api/user/auth/google/check-mobile`

- **Frontend:** `googleAuthService.checkMobileAvailability` (`src/services/googleAuth.service.js:336`)
- **Triggered from:** `checkMobileAvailability`
- **Backend:** `GoogleAuthController@checkMobileAvailability` — `core/app/Http/Controllers/User/GoogleAuthController.php:999-1038`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mobile`, `country_code`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:1030`
```json
{
  "status": 200,
  "success": true,
  "message": "Mobile number is available",
  "data": {
    "available": "..."
  }
}
```

**Errors** (`success: false`)
- `:1005` `401` — User not authenticated
- `:1014` `422` — Validation failed
- `:1019` `422` — Please select a country code and enter a valid mobile number.
- `:1025` — This mobile number is already registered. Please use a different number.
- `:1036` `500` — Failed to check mobile availability

##### `POST /api/user/auth/google/complete-registration`

- **Frontend:** `googleAuthService.completeGoogleRegistration` (`src/services/googleAuth.service.js:283`)
- **Triggered from:** `handleMobileSubmit`, `autoSubmitMobileAndRedirect`
- **Backend:** `GoogleAuthController@completeGoogleRegistration` — `core/app/Http/Controllers/User/GoogleAuthController.php:819-936`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mobile`, `country_code`, `password`, `otp_code`, `otp_verification_type`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:926`
```json
{
  "status": 200,
  "success": true,
  "message": "Registration completed successfully",
  "data": {
    "user": "...",
    "needs_kyc": "...",
    "registration_complete": "..."
  }
}
```

**Errors** (`success: false`)
- `:825` `401` — User not authenticated
- `:850` `422` — Validation failed
- `:855` `422` — Please select a country code and enter a valid mobile number.
- `:859` `422` — This mobile number is already registered. Please use a different number.
- `:868` `401` — Invalid OTP code. Please try again.
- `:934` `500` — Failed to complete registration: 

</details>

### Forgot Password — `/forgot-password`

Component: `src/components/ForgotPassword.vue` — **1 APIs**

1. `POST /api/user/password/forgot` → `AuthController@requestPasswordReset`

<details><summary>Request / response details</summary>

##### `POST /api/user/password/forgot`

- **Frontend:** `authService.requestPasswordReset` (`src/services/auth.service.js:224`)
- **Triggered from:** `submit`
- **Backend:** `AuthController@requestPasswordReset` — `core/app/Http/Controllers/User/AuthController.php:2078-2121`
- **Middleware:** `logNavigation`
- **Request fields (validated):** `email`

**Success**

`core/app/Http/Controllers/User/AuthController.php:2116`
```json
{
  "status": 200,
  "success": true,
  "message": "OTP sent to your email.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2085` — User not found or registration incomplete.
- `:2091` — Please wait before requesting another OTP.
- `:2119` — Failed to send OTP.

</details>

### Verify OTP (password reset) — `/verify-otp`

Component: `src/components/VerifyOTP.vue` — **2 APIs**

1. `POST /api/user/password/forgot` → `AuthController@requestPasswordReset`
2. `POST /api/user/password/verify-otp` → `AuthController@verifyPasswordResetOtp`

<details><summary>Request / response details</summary>

##### `POST /api/user/password/forgot`

- **Frontend:** `authService.requestPasswordReset` (`src/services/auth.service.js:224`)
- **Triggered from:** `resendOtp`
- **Backend:** `AuthController@requestPasswordReset` — `core/app/Http/Controllers/User/AuthController.php:2078-2121`
- **Middleware:** `logNavigation`
- **Request fields (validated):** `email`

**Success**

`core/app/Http/Controllers/User/AuthController.php:2116`
```json
{
  "status": 200,
  "success": true,
  "message": "OTP sent to your email.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2085` — User not found or registration incomplete.
- `:2091` — Please wait before requesting another OTP.
- `:2119` — Failed to send OTP.

##### `POST /api/user/password/verify-otp`

- **Frontend:** `authService.verifyPasswordOtp` (`src/services/auth.service.js:241`)
- **Triggered from:** `submit`
- **Backend:** `AuthController@verifyPasswordResetOtp` — `core/app/Http/Controllers/User/AuthController.php:2126-2159`
- **Middleware:** `logNavigation`
- **Request fields (validated):** `email`, `otp`

**Success**

`core/app/Http/Controllers/User/AuthController.php:2154`
```json
{
  "status": 200,
  "success": true,
  "message": "OTP verified.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2136` — Invalid email.
- `:2145` — OTP not found. Please request a new one.
- `:2148` — OTP expired. Please request a new one.
- `:2151` — Invalid OTP.
- `:2157` — OTP verification failed.

</details>

### Reset Password — `/reset-password`

Component: `src/components/ResetPassword.vue` — **2 APIs**

1. `POST /api/user/password/reset` → `AuthController@resetPasswordWithOtp`
2. `POST /api/user/password/reset-token` → `AuthController@reset`

<details><summary>Request / response details</summary>

##### `POST /api/user/password/reset`

- **Frontend:** `authService.resetPasswordWithOtp` (`src/services/auth.service.js:254`)
- **Triggered from:** `submit`
- **Backend:** `AuthController@resetPasswordWithOtp` — `core/app/Http/Controllers/User/AuthController.php:2164-2210`
- **Middleware:** `logNavigation`
- **Request fields (validated):** `email`, `otp`, `password`

**Success**

`core/app/Http/Controllers/User/AuthController.php:2205`
```json
{
  "status": 200,
  "success": true,
  "message": "Password reset successfully.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2175` — Invalid email.
- `:2184` — OTP not found. Please request a new one.
- `:2187` — OTP expired. Please request a new one.
- `:2190` — Invalid OTP.
- `:2208` — Password reset failed.

##### `POST /api/user/password/reset-token`

- **Frontend:** `authService.resetPasswordWithToken` (`src/services/auth.service.js:274`)
- **Triggered from:** `submit`
- **Backend:** `AuthController@reset` — `core/app/Http/Controllers/User/AuthController.php:1733-1777`
- **Middleware:** `logNavigation`
- **Request fields (validated):** `token`, `email`, `password`

**Success**

`core/app/Http/Controllers/User/AuthController.php:1761`
```json
{
  "status": 200,
  "success": true,
  "message": "Password reset successfully.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:1766` — (__($status), false)
- `:1773` — ($e->getMessage(), false)

</details>

### Google OAuth callback — `/auth/google/callback`

Component: `src/components/GoogleCallback.vue` — **1 APIs**

1. `GET /api/user/auth/google/callback` → `GoogleAuthController@handleGoogleCallback`

<details><summary>Request / response details</summary>

##### `GET /api/user/auth/google/callback`

- **Frontend:** `googleAuthService.handleGoogleCallback` (`src/services/googleAuth.service.js:64`)
- **Triggered from:** `mounted`
- **Backend:** `GoogleAuthController@handleGoogleCallback` — `core/app/Http/Controllers/User/GoogleAuthController.php:146-504`
- **Middleware:** `logNavigation`

> OAuth browser redirect, not JSON.

**Success**
```json
302 redirect to the frontend with token / error in the query string
```

</details>

### Auto-login from landing site — `/auth/from-net`

Component: `src/components/AuthFromNet.vue` — **1 APIs**

1. `POST /api/user/login` → `AuthController@login`

<details><summary>Request / response details</summary>

##### `POST /api/user/login`

- **Frontend:** `authService.login` (`src/services/auth.service.js:53`)
- **Triggered from:** `mounted`
- **Backend:** `AuthController@login` — `core/app/Http/Controllers/User/AuthController.php:236-438`
- **Middleware:** `logNavigation`, `throttle:10,1`
- **Request fields (validated):** `password`, `fcm_token`, `device_type`

**Success**

`core/app/Http/Controllers/User/AuthController.php:342`
```json
{
  "status": 200,
  "success": true,
  "message": "Google Authenticator setup is required",
  "data": {
    "requires_google_otp_setup": "...",
    "email": "..."
  }
}
```
`core/app/Http/Controllers/User/AuthController.php:349`
```json
{
  "status": 200,
  "success": true,
  "message": "Two-factor authentication required",
  "data": {
    "requires_google_otp": "...",
    "email": "..."
  }
}
```
`core/app/Http/Controllers/User/AuthController.php:396`
```json
{
  "status": 200,
  "success": true,
  "message": "auth.sign_in",
  "data": {
    "user": "...",
    "token": "...",
    "websocket_token": "...",
    "redirect": "..."
  }
}
```
`core/app/Http/Controllers/User/AuthController.php:419`
```json
{
  "status": 200,
  "success": true,
  "message": "auth.sign_in",
  "data": {
    "redirect": "..."
  }
}
```

</details>

### SSO verify — `/user/sso/verify/:token`

Component: `src/components/SSOVerify.vue` — **0 APIs**

_No API calls (static page or uses only the app-shell calls)._

### Invite / Referral link — `/user/invite/:referral_code`

Component: `src/components/Invite.vue` — **1 APIs**

1. `POST /api/user/ib/track-sponsor-visit` → `IbaController@trackSponsorCodeVisit`

<details><summary>Request / response details</summary>

##### `POST /api/user/ib/track-sponsor-visit`

- **Frontend:** `subIbService.trackSponsorCodeVisit` (`src/services/sub-ib.service.js:127`)
- **Triggered from:** `validateIBReferralCode`
- **Backend:** `IbaController@trackSponsorCodeVisit` — `core/app/Http/Controllers/User/IbaController.php:5669-5709`
- **Request fields (validated):** `sponsorcode`

**Success**

`core/app/Http/Controllers/User/IbaController.php:5683`
```json
{
  "status": 200,
  "success": true,
  "message": "Visit processed",
  "data": {
    "reference_link_id": "...",
    "visit_count": "..."
  }
}
```
`core/app/Http/Controllers/User/IbaController.php:5692`
```json
{
  "status": 200,
  "success": true,
  "message": "Visit tracked successfully",
  "data": {
    "reference_link_id": "...",
    "visit_count": "..."
  }
}
```

</details>

---

## App shell (every logged-in page)

> Loaded on every page: App.vue root, the router guard (blocks pages of disabled modules), LeftMenu (sidebar), TopMenu (header: notifications, profile, wallet, language), PWANavigation (mobile bottom/side nav) and PageBannerStack (page banners).

### App root — `(all)`

Component: `src/App.vue` — **3 APIs**

1. `GET /api/user/live-chat` → `SettingController@getLiveChat`
2. `GET /api/user/notices/active` → `Closure`
3. `GET /api/user/session/check` → `UserController@sessionCheck`

<details><summary>Request / response details</summary>

##### `GET /api/user/live-chat`

- **Frontend:** `getLiveChatState` (`src/services/modules.service.js:267`)
- **Triggered from:** `setup`
- **Backend:** `SettingController@getLiveChat` — `core/app/Http/Controllers/Common/SettingController.php:1419-1427`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/SettingController.php:1421`
```json
{
  "status": 200,
  "success": true,
  "message": "Live chat settings retrieved successfully",
  "data": "<\\App\\Services\\LiveChatService::clientState()>"
}
```

##### `GET /api/user/notices/active`

- **Frontend:** `load` (`src/components/MaintenanceNoticeBanner.vue:41`)
- **Triggered from:** `load`
- **Backend:** `Closure` — `—`
- **Middleware:** `logNavigation`

> Inline closure in routes/api.php:186-193 — always returns an empty list today.

**Success**
```json
{
  "status": true,
  "data": { "notices": [] }
}
```

##### `GET /api/user/session/check`

- **Frontend:** `verifySession` (`src/services/sessionGuard.js:72`)
- **Triggered from:** `mounted`
- **Backend:** `UserController@sessionCheck` — `core/app/Http/Controllers/User/UserController.php:710-715`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:712`
```json
{
  "status": 200,
  "success": true,
  "message": "Session is active",
  "data": {
    "user_id": "..."
  }
}
```

</details>

### Left sidebar — `(all)`

Component: `src/components/LeftMenu.vue` — **1 APIs**

1. `GET /api/user/ib/status` → `IbaController@getIBStatus`

<details><summary>Request / response details</summary>

##### `GET /api/user/ib/status`

- **Frontend:** `ibService.getIBStatus` (`src/services/ib.service.js:17`)
- **Triggered from:** `setup`
- **Backend:** `IbaController@getIBStatus` — `core/app/Http/Controllers/User/IbaController.php:3786-3835`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:3831`
```json
{
  "status": 200,
  "success": true,
  "message": "IB status retrieved successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:3833` `500` — Failed to get IB status: 

</details>

### Top header — `(all)`

Component: `src/components/TopMenu.vue` — **9 APIs**

1. `GET /api/ibm/client/system` → `SystemController@show`
2. `GET /api/user/dashboard` → `UserController@index`
3. `GET /api/user/notifications` → `NotificationController@showNotification`
4. `GET /api/user/notifications/markasread` → `NotificationController@markAsRead`
5. `GET /api/user/notifications/markasread/{id}` → `NotificationController@markSingleAsRead`
6. `GET /api/user/notifications/mt5-credentials/{id}` → `NotificationController@showMt5Credentials`
7. `GET /api/user/wallet` → `WalletController@getWalletBal`
8. `POST /api/user/logout` → `UserController@logout`
9. `POST /api/user/notifications/mt5-credentials/{id}/ack` → `NotificationController@ackMt5Credentials`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/client/system`

- **Frontend:** `loadSystem` (`src/composables/useIbSystem.js:35`)
- **Triggered from:** `setup`, `setPortalMode`
- **Backend:** `SystemController@show` — `core/Modules/IBManager/Http/Controllers/Client/SystemController.php:30-84`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/IBManager/Http/Controllers/Client/SystemController.php:70`
```json
{
  "success": "...",
  "message": "...",
  "data": "...",
  "system": "...",
  "is_partner": "...",
  "can_apply": "...",
  "partner_request": "...",
  "in_both_systems": "..."
}
```

**Errors** (`success: false`)
- `:35` `401` — (['success' => false, 'message' => 'Unauthorized.'], 401)

##### `GET /api/user/dashboard`

- **Frontend:** `userService.getDashboard` (`src/services/user.service.js:19`)
- **Triggered from:** `mounted`, `forceRefreshAll`
- **Backend:** `UserController@index` — `core/app/Http/Controllers/User/UserController.php:164-409`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:387`
```json
{
  "status": 200,
  "success": true,
  "message": "User dashboard data retrieved successfully.",
  "data": {
    "user": "...",
    "profile_completion_percentage": "...",
    "stage_completion": "...",
    "today_trades": "...",
    "monthly_deposits": "..."
  }
}
```

**Errors** (`success: false`)
- `:405` — Something went wrong while retrieving user dashboard data.

##### `GET /api/user/notifications`

- **Frontend:** `fetchNotifications` (`src/services/notification.service.js:5`)
- **Triggered from:** `mounted`, `setInterval`, `toggleNotificationOpen`
- **Backend:** `NotificationController@showNotification` — `core/app/Http/Controllers/Common/NotificationController.php:689-1105`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/NotificationController.php:1097`
```json
{
  "notifications": "...",
  "unread_total": "..."
}
```

**Errors** (`success: false`)
- `:1103` `500` — ($e->getMessage(), false, [], 500)

##### `GET /api/user/notifications/markasread`

- **Frontend:** `markAllNotificationsRead` (`src/services/notification.service.js:25`)
- **Triggered from:** `markAllNotificationsRead`
- **Backend:** `NotificationController@markAsRead` — `core/app/Http/Controllers/Common/NotificationController.php:1107-1128`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/NotificationController.php:1123`
```json
{
  "status": 200,
  "success": true,
  "message": "Notifications marked as read successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:1126` `500` — ($e->getMessage(), false, [], 500)

##### `GET /api/user/notifications/markasread/{id}`

- **Frontend:** `markNotificationAsRead` (`src/services/notification.service.js:33`)
- **Triggered from:** `handleNotificationClick`
- **Backend:** `NotificationController@markSingleAsRead` — `core/app/Http/Controllers/Common/NotificationController.php:1131-1149`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/NotificationController.php:1145`
```json
{
  "success": "..."
}
```

**Errors** (`success: false`)
- `:1147` `500` — (['success' => false, 'message' => $e->getMessage()], 500)

##### `GET /api/user/notifications/mt5-credentials/{id}`

- **Frontend:** `showMt5Credentials` (`src/services/notification.service.js:47`)
- **Triggered from:** `handleNotificationClick`
- **Backend:** `NotificationController@showMt5Credentials` — `core/app/Http/Controllers/Common/NotificationController.php:1157-1206`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/NotificationController.php:1193`
```json
{
  "ok": "...",
  "data": "...",
  "id": "...",
  "login": "...",
  "server": "...",
  "plan_title": "...",
  "leverage": "...",
  "currency": "...",
  "main_password": "...",
  "investor_password": "..."
}
```

**Errors** (`success: false`)
- `:1161` `401` — (['ok' => false, 'message' => 'Unauthenticated'], 401)
- `:1171` `404` — (['ok' => false, 'message' => 'Not found'], 404)
- `:1179` `410` — ([ 'ok' => false, 'code' => 'already_shown', 'data' => [ 'id' => (int) $notification->id, 'login' => $data['login'] ?? null, 'server' => $da

##### `GET /api/user/wallet`

- **Frontend:** `walletService.getWalletBalance` (`src/services/wallet.service.js:7`)
- **Triggered from:** `mounted`, `setInterval`, `watch`, `forceRefreshAll`
- **Backend:** `WalletController@getWalletBal` — `core/Modules/Wallet/Http/Controllers/WalletController.php:13-43`
- **Middleware:** `logNavigation`, `auth:sanctum`

**Success**

`core/Modules/Wallet/Http/Controllers/WalletController.php:40`
```json
{
  "status": 200,
  "success": true,
  "message": "wallet Details",
  "data": "<$data>"
}
```
`core/Modules/Wallet/Http/Controllers/WalletController.php:42`
```json
{
  "balance": "..."
}
```

##### `POST /api/user/logout`

- **Frontend:** `authService.logout` (`src/services/auth.service.js:288`)
- **Triggered from:** `handleLogout`
- **Backend:** `UserController@logout` — `core/app/Http/Controllers/User/UserController.php:718-781`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:743`
```json
{
  "status": 200,
  "success": true,
  "message": "User logged out successfully",
  "data": "..."
}
```

##### `POST /api/user/notifications/mt5-credentials/{id}/ack`

- **Frontend:** `ackMt5Credentials` (`src/services/notification.service.js:67`)
- **Triggered from:** `ackAndClose`
- **Backend:** `NotificationController@ackMt5Credentials` — `core/app/Http/Controllers/Common/NotificationController.php:1214-1249`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/NotificationController.php:1248`
```json
{
  "ok": "..."
}
```

**Errors** (`success: false`)
- `:1218` `401` — (['ok' => false, 'message' => 'Unauthenticated'], 401)
- `:1227` `404` — (['ok' => false, 'message' => 'Not found'], 404)

</details>

### Router guard (module check before each page) — `(all)`

Component: `src/router/index.js` — **5 APIs**

1. `GET /api/ibm/client/system` → `SystemController@show`
2. `GET /api/user/enabled-modules` → `ModuleController@enabled`
3. `GET /api/user/ib/status` → `IbaController@getIBStatus`
4. `GET /api/user/wallet` → `WalletController@getWalletBal`
5. `POST /api/user/current-page` → `OnlineUserController@reportCurrentPage`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/client/system`

- **Frontend:** `loadSystem` (`src/composables/useIbSystem.js:35`)
- **Triggered from:** `component`
- **Backend:** `SystemController@show` — `core/Modules/IBManager/Http/Controllers/Client/SystemController.php:30-84`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/IBManager/Http/Controllers/Client/SystemController.php:70`
```json
{
  "success": "...",
  "message": "...",
  "data": "...",
  "system": "...",
  "is_partner": "...",
  "can_apply": "...",
  "partner_request": "...",
  "in_both_systems": "..."
}
```

**Errors** (`success: false`)
- `:35` `401` — (['success' => false, 'message' => 'Unauthorized.'], 401)

##### `GET /api/user/enabled-modules`

- **Frontend:** `getEnabledModules` (`src/services/modules.service.js:121`)
- **Triggered from:** `bounce`
- **Backend:** `ModuleController@enabled` — `core/app/Http/Controllers/Common/ModuleController.php:268-271`
- **Middleware:** `logNavigation`

> Built by ModuleController::enabledResponse (ModuleController.php:222-237). Plain response()->json — no `success` key, `status` is a boolean. Only client-facing modules (`client => true` in resolveModules :36-188) are returned; each value comes from that broker's module status + admin setting, so true/false differs per broker. Frontend caches it (modules.service.js:113) and uses it in the router guard (router/index.js:1386) to block pages of disabled modules, and to show/hide menus (Dashboard.vue:580, IBManagerPortal.vue:172, PWANavigation.vue:1215).

**Success**
```json
{
  "status": true,
  "message": "Enabled modules retrieved",
  "data": {
    "pmam": true,
    "copytrading": true,
    "scratchcard": true,
    "tradewin": true,
    "price_alert": true,
    "democontest": true,
    "page_banner": true,
    "propfirm": false,
    "platform": true,
    "ibm_reports": true,
    "trading_central": true,
    "trader_transfer": true,
    "ib": true,
    "helpdesk": true
  }
}
```

##### `GET /api/user/ib/status`

- **Frontend:** `ibService.getIBStatus` (`src/services/ib.service.js:17`)
- **Triggered from:** `component`
- **Backend:** `IbaController@getIBStatus` — `core/app/Http/Controllers/User/IbaController.php:3786-3835`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:3831`
```json
{
  "status": 200,
  "success": true,
  "message": "IB status retrieved successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:3833` `500` — Failed to get IB status: 

##### `GET /api/user/wallet`

- **Frontend:** `walletService.getWalletBalance` (`src/services/wallet.service.js:7`)
- **Triggered from:** `marketingService`
- **Backend:** `WalletController@getWalletBal` — `core/Modules/Wallet/Http/Controllers/WalletController.php:13-43`
- **Middleware:** `logNavigation`, `auth:sanctum`

**Success**

`core/Modules/Wallet/Http/Controllers/WalletController.php:40`
```json
{
  "status": 200,
  "success": true,
  "message": "wallet Details",
  "data": "<$data>"
}
```
`core/Modules/Wallet/Http/Controllers/WalletController.php:42`
```json
{
  "balance": "..."
}
```

##### `POST /api/user/current-page`

- **Frontend:** `reportCurrentPage` (`src/router/index.js:1486`)
- **Triggered from:** `proceed`
- **Backend:** `OnlineUserController@reportCurrentPage` — `core/app/Http/Controllers/Common/OnlineUserController.php:334-351`
- **Middleware:** `logNavigation`, `auth:sanctum`
- **Request fields (validated):** `route`

**Success**

`core/app/Http/Controllers/Common/OnlineUserController.php:341`
```json
{
  "status": "..."
}
```

</details>

### Mobile navigation — `(all)`

Component: `src/components/PWANavigation.vue` — **4 APIs**

1. `GET /api/ibm/client/system` → `SystemController@show`
2. `GET /api/user/ib/status` → `IbaController@getIBStatus`
3. `GET /api/user/live-chat` → `SettingController@getLiveChat`
4. `POST /api/user/logout` → `UserController@logout`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/client/system`

- **Frontend:** `loadSystem` (`src/composables/useIbSystem.js:35`)
- **Triggered from:** `setup`
- **Backend:** `SystemController@show` — `core/Modules/IBManager/Http/Controllers/Client/SystemController.php:30-84`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/IBManager/Http/Controllers/Client/SystemController.php:70`
```json
{
  "success": "...",
  "message": "...",
  "data": "...",
  "system": "...",
  "is_partner": "...",
  "can_apply": "...",
  "partner_request": "...",
  "in_both_systems": "..."
}
```

**Errors** (`success: false`)
- `:35` `401` — (['success' => false, 'message' => 'Unauthorized.'], 401)

##### `GET /api/user/ib/status`

- **Frontend:** `ibService.getIBStatus` (`src/services/ib.service.js:17`)
- **Triggered from:** `setup`
- **Backend:** `IbaController@getIBStatus` — `core/app/Http/Controllers/User/IbaController.php:3786-3835`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:3831`
```json
{
  "status": 200,
  "success": true,
  "message": "IB status retrieved successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:3833` `500` — Failed to get IB status: 

##### `GET /api/user/live-chat`

- **Frontend:** `getLiveChatState` (`src/services/modules.service.js:267`)
- **Triggered from:** `setup`
- **Backend:** `SettingController@getLiveChat` — `core/app/Http/Controllers/Common/SettingController.php:1419-1427`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/SettingController.php:1421`
```json
{
  "status": 200,
  "success": true,
  "message": "Live chat settings retrieved successfully",
  "data": "<\\App\\Services\\LiveChatService::clientState()>"
}
```

##### `POST /api/user/logout`

- **Frontend:** `authService.logout` (`src/services/auth.service.js:288`)
- **Triggered from:** `handleLogout`
- **Backend:** `UserController@logout` — `core/app/Http/Controllers/User/UserController.php:718-781`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:743`
```json
{
  "status": 200,
  "success": true,
  "message": "User logged out successfully",
  "data": "..."
}
```

</details>

### Page banners — `(all)`

Component: `src/components/PageBannerStack.vue` — **3 APIs**

1. `GET /api/user/banners` → `BannerApiController@active`
2. `GET /api/user/enabled-modules` → `ModuleController@enabled`
3. `POST /api/user/banners/track` → `BannerApiController@trackEvent`

<details><summary>Request / response details</summary>

##### `GET /api/user/banners`

- **Frontend:** `bannerService.getActiveBanners` (`src/services/banner.service.js:36`)
- **Triggered from:** `fetchBanners`
- **Backend:** `BannerApiController@active` — `core/Modules/PageBanner/app/Http/Controllers/Api/BannerApiController.php:22-64`

**Success**

`core/Modules/PageBanner/app/Http/Controllers/Api/BannerApiController.php:63`
```json
{
  "status": 200,
  "success": true,
  "message": "Active banners.",
  "data": {
    "banners": "..."
  }
}
```

##### `GET /api/user/enabled-modules`

- **Frontend:** `getEnabledModules` (`src/services/modules.service.js:121`)
- **Triggered from:** `fetchBanners`
- **Backend:** `ModuleController@enabled` — `core/app/Http/Controllers/Common/ModuleController.php:268-271`
- **Middleware:** `logNavigation`

> Built by ModuleController::enabledResponse (ModuleController.php:222-237). Plain response()->json — no `success` key, `status` is a boolean. Only client-facing modules (`client => true` in resolveModules :36-188) are returned; each value comes from that broker's module status + admin setting, so true/false differs per broker. Frontend caches it (modules.service.js:113) and uses it in the router guard (router/index.js:1386) to block pages of disabled modules, and to show/hide menus (Dashboard.vue:580, IBManagerPortal.vue:172, PWANavigation.vue:1215).

**Success**
```json
{
  "status": true,
  "message": "Enabled modules retrieved",
  "data": {
    "pmam": true,
    "copytrading": true,
    "scratchcard": true,
    "tradewin": true,
    "price_alert": true,
    "democontest": true,
    "page_banner": true,
    "propfirm": false,
    "platform": true,
    "ibm_reports": true,
    "trading_central": true,
    "trader_transfer": true,
    "ib": true,
    "helpdesk": true
  }
}
```

##### `POST /api/user/banners/track`

- **Frontend:** `bannerService.trackEvent` (`src/services/banner.service.js:66`)
- **Triggered from:** `trackImpressions`, `onBannerClick`, `onDismiss`, `onDismissForever`
- **Backend:** `BannerApiController@trackEvent` — `core/Modules/PageBanner/app/Http/Controllers/Api/BannerApiController.php:71-107`
- **Request fields (validated):** `banner_id`, `event_type`

**Success**

`core/Modules/PageBanner/app/Http/Controllers/Api/BannerApiController.php:106`
```json
{
  "status": 200,
  "success": true,
  "message": "Event tracked.",
  "data": "..."
}
```

</details>

---

## Dashboard

### Dashboard — `/dashboard`

Component: `src/components/Dashboard.vue` — **11 APIs**

1. `GET /api/user/deposit/by-reference` → `FinanceController@getDepositByReference`
2. `GET /api/user/finance-activity` → `FinanceController@transactions1`
3. `GET /api/user/mt5accounts/get` → `Mt5Controller@getMT5Accounts`
4. `GET /api/user/prop-coupons`
5. `GET /api/user/settings/profile` → `UserController@getUserProfile`
6. `POST /api/user/mt5accounts/changeleverage` → `Mt5Controller@changeLeverageRequest`
7. `POST /api/user/mt5accounts/changepassword` → `Mt5Controller@changePassword`
8. `POST /api/user/mt5accounts/changePrimaryAccount` → `Mt5Controller@changePrimaryAccount`
9. `POST /api/user/mt5accounts/setbalance` → `Mt5Controller@setBalance`
10. `POST /api/user/mt5accounts/setnickname` → `Mt5Controller@setNickName`
11. `POST /api/user/price-alerts/update-fcm-token` → `PriceAlertController@updateFcmToken`

<details><summary>Request / response details</summary>

##### `GET /api/user/deposit/by-reference`

- **Frontend:** `financeService.getDepositByReference` (`src/services/finance.service.js:378`)
- **Triggered from:** `pollDepositStatus`
- **Backend:** `FinanceController@getDepositByReference` — `core/app/Http/Controllers/User/FinanceController.php:10001-10024`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:10016`
```json
{
  "status": 200,
  "success": true,
  "message": "Deposit found.",
  "data": {
    "reference_number": "...",
    "amount": "...",
    "status": "...",
    "mt5_account_id": "...",
    "gateway_method_id": "...",
    "created_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:10005` `400` — Reference number is required.
- `:10013` `404` — Deposit not found.

##### `GET /api/user/finance-activity`

- **Frontend:** `financeService.getTransactionHistory` (`src/services/finance.service.js:203`)
- **Triggered from:** `fetchMonthlyDepositsSum`, `loadRecentTransactions`
- **Backend:** `FinanceController@transactions1` — `core/app/Http/Controllers/User/FinanceController.php:8001-8625`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:8600`
```json
{
  "status": 200,
  "success": true,
  "message": "Transactions fetched successfully",
  "data": "<$paginatedTransactions->items() // Direct array>"
}
```
`core/app/Http/Controllers/User/FinanceController.php:8620`
```json
($responseData, 200)
```

**Errors** (`success: false`)
- `:8623` `500` — An error occurred while fetching transactions.

##### `GET /api/user/mt5accounts/get`

- **Frontend:** `mt5Service.getAccounts` (`src/services/mt5.service.js:15`)
- **Triggered from:** `mounted`, `loadDashboardData`, `setInterval`
- **Backend:** `Mt5Controller@getMT5Accounts` — `core/app/Http/Controllers/Common/Mt5Controller.php:146-341`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:337`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading accounts retrieved successfully",
  "data": "<$selectedAccounts>"
}
```

**Errors** (`success: false`)
- `:151` `401` — User not authenticated
- `:165` — No active trading accounts found
- `:339` `500` — Failed to retrieve trading accounts: 

##### `GET /api/user/prop-coupons`

> **Not live:** Called by the dashboard only when the Prop Firm module is on. PropFirm is disabled in modules_statuses.json, so the route is not registered and the call returns 404 (the dashboard ignores the error).

- **Frontend:** `propCouponService.getCoupons` (`src/services/propCoupon.service.js:9`)
- **Triggered from:** `loadPropCoupons`

_Response shape not detected — see controller._

##### `GET /api/user/settings/profile`

- **Frontend:** `userService.getProfile` (`src/services/user.service.js:47`)
- **Triggered from:** `loadDashboardData`
- **Backend:** `UserController@getUserProfile` — `core/app/Http/Controllers/User/UserController.php:416-591`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:582`
```json
{
  "status": 200,
  "success": true,
  "message": "User profile data retrieved successfully.",
  "data": {
    "user": "..."
  }
}
```

##### `POST /api/user/mt5accounts/changeleverage`

- **Frontend:** `mt5Service.changeLeverage` (`src/services/mt5.service.js:157`), `mt5Service.requestUnlimitedLeverage` (`src/services/mt5.service.js:181`)
- **Triggered from:** `submitLeverage`, `submitUnlimitedLeverage`
- **Backend:** `Mt5Controller@changeLeverageRequest` — `core/app/Http/Controllers/Common/Mt5Controller.php:2923-3194`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:3185`
```json
{
  "status": 200,
  "success": true,
  "message": "Leverage change request processed successfully",
  "data": {
    "request_status": "..."
  }
}
```

**Errors** (`success: false`)
- `:2959` `404` — Account not found
- `:2991` `422` — Enter a valid leverage (a whole number of at least 1)
- `:3005` `422` — Leverage changes are not allowed for this account group
- `:3009` `422` — Requested leverage 1:
- `:3020` `422` — Current leverage and new leverage are same
- `:3035` `422` — Leverage change request is already pending

##### `POST /api/user/mt5accounts/changepassword`

- **Frontend:** `mt5Service.changePassword` (`src/services/mt5.service.js:117`)
- **Triggered from:** `submitPassword`
- **Backend:** `Mt5Controller@changePassword` — `core/app/Http/Controllers/Common/Mt5Controller.php:2756-2807`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `newPassword`, `newPassword.min`, `newPassword.max`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2801`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:2802`
```json
{
  "status": 200,
  "success": true,
  "message": "Password changed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2762` `400` — MT5 account number is required
- `:2781` `404` — MT5 account not found
- `:2792` `500` — Failed to update the password in MT5: 
- `:2804` `500` — ($e->getMessage(), false, [], 500)
- `:2805` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/changePrimaryAccount`

- **Frontend:** `mt5Service.setPrimaryAccount` (`src/services/mt5.service.js:191`)
- **Triggered from:** `handleTradeAction`
- **Backend:** `Mt5Controller@changePrimaryAccount` — `core/app/Http/Controllers/Common/Mt5Controller.php:455-474`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:468`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:469`
```json
{
  "status": 200,
  "success": true,
  "message": "Primary account changed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:461` `404` — Trading account not found.
- `:462` `404` — Trading account not found
- `:471` `500` — ($e->getMessage(), false, [], 500)
- `:472` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/setbalance`

- **Frontend:** `mt5Service.setBalance` (`src/services/mt5.service.js:78`)
- **Triggered from:** `submitBalance`
- **Backend:** `Mt5Controller@setBalance` — `core/app/Http/Controllers/Common/Mt5Controller.php:2583-2726`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2712`
```json
{
  "status": 200,
  "success": true,
  "message": "Balance updated successfully",
  "data": {
    "amount": "...",
    "account_number": "...",
    "balance": "...",
    "reference_number": "..."
  }
}
```

**Errors** (`success: false`)
- `:2589` `404` — MT5 account not found
- `:2593` `400` — Only demo account can be updated
- `:2598` `400` — Demo contest accounts cannot be manually funded.
- `:2662` `500` — Failed to deposit funds: 
- `:2724` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/setnickname`

- **Frontend:** `mt5Service.setNickname` (`src/services/mt5.service.js:104`)
- **Triggered from:** `submitNickname`
- **Backend:** `Mt5Controller@setNickName` — `core/app/Http/Controllers/Common/Mt5Controller.php:2728-2754`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2750`
```json
{
  "status": 200,
  "success": true,
  "message": "Nick Name updated successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2734` `404` — MT5 account not found
- `:2740` `404` — MT5 account not found
- `:2752` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/price-alerts/update-fcm-token`

- **Frontend:** `registerPriceAlertWebToken` (`src/services/priceAlertNotification.js:29`)
- **Triggered from:** `mounted`
- **Backend:** `PriceAlertController@updateFcmToken` — `core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:262-327`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `fcm_token`, `device_type`, `mt5_account_id`

**Success**

`core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:324`
```json
{
  "status": 200,
  "success": true,
  "message": "FCM token updated successfully",
  "data": {
    "alerts_updated": "..."
  }
}
```

**Errors** (`success: false`)
- `:266` `404` — Price Alerts module is disabled
- `:278` `422` — Validation failed
- `:294` `404` — MT5 Account not found or does not belong to you

</details>

---

## Trading Accounts

### Trading Accounts — `/trading-accounts`

Component: `src/components/TradingAccounts.vue` — **9 APIs**

1. `GET /api/user/mt5accounts/get` → `Mt5Controller@getMT5Accounts`
2. `POST /api/user/mt5accounts/changeleverage` → `Mt5Controller@changeLeverageRequest`
3. `POST /api/user/mt5accounts/changepassword` → `Mt5Controller@changePassword`
4. `POST /api/user/mt5accounts/changePrimaryAccount` → `Mt5Controller@changePrimaryAccount`
5. `POST /api/user/mt5accounts/create` → `Mt5Controller@createMT5Account`
6. `POST /api/user/mt5accounts/plandetails` → `Mt5Controller@getMT5GroupMaster`
7. `POST /api/user/mt5accounts/resetinvestorpassword` → `Mt5Controller@resetInvestorPassword`
8. `POST /api/user/mt5accounts/setbalance` → `Mt5Controller@setBalance`
9. `POST /api/user/mt5accounts/setnickname` → `Mt5Controller@setNickName`

<details><summary>Request / response details</summary>

##### `GET /api/user/mt5accounts/get`

- **Frontend:** `mt5Service.getAccounts` (`src/services/mt5.service.js:15`)
- **Triggered from:** `loadTradingAccounts`, `updateValuesOnly`, `handleAccountCreated`
- **Backend:** `Mt5Controller@getMT5Accounts` — `core/app/Http/Controllers/Common/Mt5Controller.php:146-341`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:337`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading accounts retrieved successfully",
  "data": "<$selectedAccounts>"
}
```

**Errors** (`success: false`)
- `:151` `401` — User not authenticated
- `:165` — No active trading accounts found
- `:339` `500` — Failed to retrieve trading accounts: 

##### `POST /api/user/mt5accounts/changeleverage`

- **Frontend:** `mt5Service.changeLeverage` (`src/services/mt5.service.js:157`), `mt5Service.requestUnlimitedLeverage` (`src/services/mt5.service.js:181`)
- **Triggered from:** `submitLeverage`, `submitUnlimitedLeverage`
- **Backend:** `Mt5Controller@changeLeverageRequest` — `core/app/Http/Controllers/Common/Mt5Controller.php:2923-3194`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:3185`
```json
{
  "status": 200,
  "success": true,
  "message": "Leverage change request processed successfully",
  "data": {
    "request_status": "..."
  }
}
```

**Errors** (`success: false`)
- `:2959` `404` — Account not found
- `:2991` `422` — Enter a valid leverage (a whole number of at least 1)
- `:3005` `422` — Leverage changes are not allowed for this account group
- `:3009` `422` — Requested leverage 1:
- `:3020` `422` — Current leverage and new leverage are same
- `:3035` `422` — Leverage change request is already pending

##### `POST /api/user/mt5accounts/changepassword`

- **Frontend:** `mt5Service.changePassword` (`src/services/mt5.service.js:117`)
- **Triggered from:** `submitPassword`
- **Backend:** `Mt5Controller@changePassword` — `core/app/Http/Controllers/Common/Mt5Controller.php:2756-2807`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `newPassword`, `newPassword.min`, `newPassword.max`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2801`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:2802`
```json
{
  "status": 200,
  "success": true,
  "message": "Password changed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2762` `400` — MT5 account number is required
- `:2781` `404` — MT5 account not found
- `:2792` `500` — Failed to update the password in MT5: 
- `:2804` `500` — ($e->getMessage(), false, [], 500)
- `:2805` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/changePrimaryAccount`

- **Frontend:** `mt5Service.setPrimaryAccount` (`src/services/mt5.service.js:191`)
- **Triggered from:** `platform`, `handleTradeAction`
- **Backend:** `Mt5Controller@changePrimaryAccount` — `core/app/Http/Controllers/Common/Mt5Controller.php:455-474`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:468`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:469`
```json
{
  "status": 200,
  "success": true,
  "message": "Primary account changed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:461` `404` — Trading account not found.
- `:462` `404` — Trading account not found
- `:471` `500` — ($e->getMessage(), false, [], 500)
- `:472` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/create`

- **Frontend:** `mt5Service.createAccount` (`src/services/mt5.service.js:53`)
- **Triggered from:** `submitAccountCreation`
- **Backend:** `Mt5Controller@createMT5Account` — `core/app/Http/Controllers/Common/Mt5Controller.php:495-521`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`


**Errors** (`success: false`)
- `:513` `429` — Your previous account request is still being processed. Please wait a moment and check your accounts list.

##### `POST /api/user/mt5accounts/plandetails`

- **Frontend:** `mt5Service.getPlanDetails` (`src/services/mt5.service.js:68`)
- **Triggered from:** `fetchAccountTypes`, `ftdBonus`
- **Backend:** `Mt5Controller@getMT5GroupMaster` — `core/app/Http/Controllers/Common/Mt5Controller.php:2223-2487`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2265`
```json
{
  "status": 200,
  "success": true,
  "message": "Record retrieved successfully",
  "data": "<$filteredData>"
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:2485`
```json
{
  "status": 200,
  "success": true,
  "message": "Groups retrieved successfully",
  "data": "<$filteredGroups>"
}
```

**Errors** (`success: false`)
- `:2268` `404` — No record found

##### `POST /api/user/mt5accounts/resetinvestorpassword`

- **Frontend:** `mt5Service.resetInvestorPassword` (`src/services/mt5.service.js:135`)
- **Triggered from:** `submitPassword`
- **Backend:** `Mt5Controller@resetInvestorPassword` — `core/app/Http/Controllers/Common/Mt5Controller.php:2823-2888`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `newPassword`, `newPassword.min`, `newPassword.max`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2879`
```json
{
  "status": 200,
  "success": true,
  "message": "Investor password reset successfully. Save it now — it will not be shown again.",
  "data": {
    "investor_password": "..."
  }
}
```

**Errors** (`success: false`)
- `:2828` `400` — MT5 account number is required
- `:2848` `404` — User not found
- `:2855` `404` — MT5 account not found
- `:2871` `500` — Failed to reset investor password: 
- `:2886` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/setbalance`

- **Frontend:** `mt5Service.setBalance` (`src/services/mt5.service.js:78`)
- **Triggered from:** `submitBalance`
- **Backend:** `Mt5Controller@setBalance` — `core/app/Http/Controllers/Common/Mt5Controller.php:2583-2726`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2712`
```json
{
  "status": 200,
  "success": true,
  "message": "Balance updated successfully",
  "data": {
    "amount": "...",
    "account_number": "...",
    "balance": "...",
    "reference_number": "..."
  }
}
```

**Errors** (`success: false`)
- `:2589` `404` — MT5 account not found
- `:2593` `400` — Only demo account can be updated
- `:2598` `400` — Demo contest accounts cannot be manually funded.
- `:2662` `500` — Failed to deposit funds: 
- `:2724` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/setnickname`

- **Frontend:** `mt5Service.setNickname` (`src/services/mt5.service.js:104`)
- **Triggered from:** `submitNickname`
- **Backend:** `Mt5Controller@setNickName` — `core/app/Http/Controllers/Common/Mt5Controller.php:2728-2754`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2750`
```json
{
  "status": 200,
  "success": true,
  "message": "Nick Name updated successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2734` `404` — MT5 account not found
- `:2740` `404` — MT5 account not found
- `:2752` `500` — ($e->getMessage(), false, [], 500)

</details>

---

## Trading Terminal

### Trading Terminal (launcher) — `/trading-terminal`

Component: `src/components/TradingTerminal.vue` — **2 APIs**

1. `DELETE /api/user/trade/chart-state/{param}`
2. `POST /api/user/trade/new-order` → `TradeController@placeOrder`

<details><summary>Request / response details</summary>

##### `DELETE /api/user/trade/chart-state/{param}`

> **Not live:** Chart layouts are saved in the browser only (CHART_STATE_BACKEND_DISABLED = true in chartSaveLoadAdapter.js:7). Backend routes are commented out in routes/api.php:532-534, so this call is never made.

- **Frontend:** `removeChart` (`src/services/chartSaveLoadAdapter.js:579`)
- **Triggered from:** `watch`

_Response shape not detected — see controller._

##### `POST /api/user/trade/new-order`

- **Frontend:** `tradeService.placeOrder` (`src/services/trade.service.js:47`)
- **Triggered from:** `handleQuickTrade`
- **Backend:** `TradeController@placeOrder` — `core/app/Http/Controllers/User/TradeController.php:165-858`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mt5_account`, `symbol`, `volume`, `type`, `mt5_account.required`, `volume.min`

**Success**

`core/app/Http/Controllers/User/TradeController.php:553`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$mappedResponse>"
}
```
`core/app/Http/Controllers/User/TradeController.php:719`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$parsedData>"
}
```
`core/app/Http/Controllers/User/TradeController.php:852`
```json
{
  "status": 200,
  "success": true,
  "message": "Trade has been successfully placed",
  "data": "<$parsedData>"
}
```

**Errors** (`success: false`)
- `:171` `400` — Trading Account is required
- `:223` `500` — MT5 Account not found
- `:228` `403` — Trading is disabled for this account
- `:233` `503` — Market is closed today (holiday)
- `:238` `503` — Market is closed
- `:250` `403` — Trading is not allowed for this instrument on ScratchCard accounts.

</details>

### Web Trader (terminal) — `/trading`

Component: `src/components/trading/TradingLayout.vue` — **27 APIs**

1. `DELETE /api/user/price-alerts/{id}` → `PriceAlertController@destroy`
2. `DELETE /api/user/trade/chart-state/{param}`
3. `GET /api/user` → external
4. `GET /api/user/economic-calendar` → `EconomicCalendarController@index`
5. `GET /api/user/modules` → `ModuleController@index`
6. `GET /api/user/mt5accounts/get` → `Mt5Controller@getMT5Accounts`
7. `GET /api/user/price-alerts` → `PriceAlertController@index`
8. `GET /api/user/trade/chart-store/{param}` → `ChartStoreController@show`
9. `GET /api/user/trade/marketwatch` → `UserMarketwatchController@getMarketwatch`
10. `GET /api/user/trade/tradehistory` → `TradeController@fetchTradeHistory`
11. `GET /api/user/trade/tradehistory/export` → `TradeController@exportTradeHistory`
12. `GET /api/user/tradingaccounts/sync` → `Mt5Controller@mt5AccountSync`
13. `POST /api/user/mt5accounts/changeleverage` → `Mt5Controller@changeLeverageRequest`
14. `POST /api/user/mt5accounts/changepassword` → `Mt5Controller@changePassword`
15. `POST /api/user/mt5accounts/changePrimaryAccount` → `Mt5Controller@changePrimaryAccount`
16. `POST /api/user/mt5accounts/setbalance` → `Mt5Controller@setBalance`
17. `POST /api/user/price-alerts` → `PriceAlertController@store`
18. `POST /api/user/price-alerts/update-fcm-token` → `PriceAlertController@updateFcmToken`
19. `POST /api/user/trade/chart-state`
20. `POST /api/user/trade/chart-store` → `ChartStoreController@store`
21. `POST /api/user/trade/closePendingOrder` → `TradeController@closePendingOrder`
22. `POST /api/user/trade/closePositionByPositionId` → `TradeController@closePositionByPositionId`
23. `POST /api/user/trade/marketwatch` → `UserMarketwatchController@createOrUpdate`
24. `POST /api/user/trade/new-order` → `TradeController@placeOrder`
25. `POST /api/user/trade/update-pending-order-tp-sl` → `TradeController@updatePendingOrderTPSL`
26. `POST /api/user/trade/update-tp-sl` → `TradeController@updateTPSL`
27. `PUT /api/user/price-alerts/{id}` → `PriceAlertController@update`

<details><summary>Request / response details</summary>

##### `DELETE /api/user/price-alerts/{id}`

- **Frontend:** `priceAlertService.deleteAlert` (`src/services/priceAlert.service.js:32`)
- **Triggered from:** `closeModal`, `accountNumberForCreate`
- **Backend:** `PriceAlertController@destroy` — `core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:225-253`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:252`
```json
{
  "status": 200,
  "success": true,
  "message": "Price alert deleted successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:229` `404` — Price Alerts module is disabled
- `:239` `404` — Price alert not found

##### `DELETE /api/user/trade/chart-state/{param}`

> **Not live:** Chart layouts are saved in the browser only (CHART_STATE_BACKEND_DISABLED = true in chartSaveLoadAdapter.js:7). Backend routes are commented out in routes/api.php:532-534, so this call is never made.

- **Frontend:** `removeChart` (`src/services/chartSaveLoadAdapter.js:579`)
- **Triggered from:** `watch`

_Response shape not detected — see controller._

##### `GET /api/user`

- **External call, not the CRM:** `GET https://api.ipify.org?format=json` — Visitor IP lookup (IB link tracking)
- Called from: `src/components/trading/desktop/DesktopTradingView.vue:539`

##### `GET /api/user/economic-calendar`

- **Frontend:** `economicCalendarService.getEvents` (`src/services/economicCalendar.service.js:18`)
- **Triggered from:** `formatDateTime`
- **Backend:** `EconomicCalendarController@index` — `core/app/Http/Controllers/User/EconomicCalendarController.php:12-109`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `from`, `to`, `country`, `currency`, `importance`, `provider`, `limit`

**Success**

`core/app/Http/Controllers/User/EconomicCalendarController.php:108`
```json
{
  "status": 200,
  "success": true,
  "message": "Economic calendar retrieved successfully",
  "data": "<$events>"
}
```

##### `GET /api/user/modules`

- **Frontend:** `getModuleList` (`src/services/modules.service.js:144`)
- **Triggered from:** `onMounted`
- **Backend:** `ModuleController@index` — `core/app/Http/Controllers/Common/ModuleController.php:273-276`
- **Middleware:** `logNavigation`

> Built by ModuleController::listResponse (ModuleController.php:242-262). Same client-facing modules as /enabled-modules, as a list with name + description. No `success` key.

**Success**
```json
{
  "status": true,
  "message": "Module list retrieved",
  "data": [
    { "key": "pmam", "name": "PMAM", "description": "Portfolio Management Account Manager", "enabled": true },
    { "key": "copytrading", "name": "Copy Trading", "description": "Follow and copy master traders", "enabled": true },
    { "key": "price_alert", "name": "Price Alerts", "description": "Real-time price alert notifications", "enabled": true },
    ...
  ]
}
```

##### `GET /api/user/mt5accounts/get`

- **Frontend:** `mt5Service.getAccounts` (`src/services/mt5.service.js:15`)
- **Triggered from:** `handleLeverageChanged`, `setTimeout`, `closeAddBalanceModal`, `createRealAccount`, `onMounted`
- **Backend:** `Mt5Controller@getMT5Accounts` — `core/app/Http/Controllers/Common/Mt5Controller.php:146-341`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:337`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading accounts retrieved successfully",
  "data": "<$selectedAccounts>"
}
```

**Errors** (`success: false`)
- `:151` `401` — User not authenticated
- `:165` — No active trading accounts found
- `:339` `500` — Failed to retrieve trading accounts: 

##### `GET /api/user/price-alerts`

- **Frontend:** `priceAlertService.getAlerts` (`src/services/priceAlert.service.js:10`)
- **Triggered from:** `formatPrice`
- **Backend:** `PriceAlertController@index` — `core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:31-76`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:75`
```json
{
  "status": 200,
  "success": true,
  "message": "Price alerts retrieved successfully",
  "data": {
    "alerts": "..."
  }
}
```

**Errors** (`success: false`)
- `:35` `404` — Price Alerts module is disabled
- `:51` `404` — MT5 Account not found or does not belong to you

##### `GET /api/user/trade/chart-store/{param}`

- **Frontend:** `chartRemote.load` (`src/components/trading/shared/TenaxChartPanel.vue:93`)
- **Triggered from:** `load`
- **Backend:** `ChartStoreController@show` — `core/app/Http/Controllers/User/ChartStoreController.php:31-47`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:120,1`

**Success**

`core/app/Http/Controllers/User/ChartStoreController.php:41`
```json
{
  "status": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:34` `422` — (['status' => false, 'message' => 'Unknown chart scope.'], 422)

##### `GET /api/user/trade/marketwatch`

- **Frontend:** `tradeService.getMarketWatch` (`src/services/trade.service.js:345`)
- **Triggered from:** `setTimeout`, `formatSpread`, `onMounted`
- **Backend:** `UserMarketwatchController@getMarketwatch` — `core/app/Http/Controllers/User/UserMarketwatchController.php:15-38`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserMarketwatchController.php:21`
```json
{
  "status": 200,
  "success": true,
  "message": "Marketwatch retrieved successfully",
  "data": "<$marketwatch->symbols>"
}
```
`core/app/Http/Controllers/User/UserMarketwatchController.php:37`
```json
{
  "status": 200,
  "success": true,
  "message": "Marketwatch retrieved successfully",
  "data": "<$defaultSymbols>"
}
```

##### `GET /api/user/trade/tradehistory`

- **Frontend:** `tradeService.getTradeHistory` (`src/services/trade.service.js:253`)
- **Triggered from:** `setTimeout`, `buildExportDateFilterLabel`, `formatSymbol`, `onMounted`, `buildHistoryParams`, `watch`, `handleOrderCancelled`
- **Backend:** `TradeController@fetchTradeHistory` — `core/app/Http/Controllers/User/TradeController.php:4117-5663`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/TradeController.php:5637`
```json
{
  "status": "...",
  "success": "...",
  "message": "...",
  "data": "...",
  "pagination": "...",
  "current_page": "...",
  "last_page": "...",
  "per_page": "...",
  "total": "...",
  "next_page_url": "...",
  "prev_page_url": "...",
  "totals": "...",
  "summary": "..."
}
```

**Errors** (`success: false`)
- `:4135` `400` — Account number is required. Please provide login, trading_account, or mt5_account parameter
- `:4147` `404` — No trading accounts found
- `:4180` `400` — Invalid account
- `:4571` `500` — ([ 'status' => $mt5Response['status'] ?? true, 'success' => $mt5Response['status'] ?? true, 'message' => $mt5Response['message'] ?? 'Trade h
- `:4589` `500` — Error processing trade history: 
- `:5656` `500` — An error occurred while fetching trade history: 

##### `GET /api/user/trade/tradehistory/export`

- **Frontend:** `tradeService.downloadTradeHistoryExport` (`src/services/trade.service.js:265`)
- **Triggered from:** `formatSymbol`
- **Backend:** `TradeController@exportTradeHistory` — `core/app/Http/Controllers/User/TradeController.php:5668-5738`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`


**Errors** (`success: false`)
- `:5674` `404` — No trades found for the selected filters.
- `:5678` `422` — Too many trades to export (
- `:5731` `500` — Failed to export trade history: 

##### `GET /api/user/tradingaccounts/sync`

- **Frontend:** `mt5Service.syncAccounts` (`src/services/mt5.service.js:203`)
- **Triggered from:** `handleLeverageChanged`, `createRealAccount`
- **Backend:** `Mt5Controller@mt5AccountSync` — `core/app/Http/Controllers/Common/Mt5Controller.php:3765-3914`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:3773`
```json
{
  "status": 200,
  "success": true,
  "message": "No trading accounts",
  "data": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:3909`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "synced": "...",
    "failed": "...",
    "total": "..."
  }
}
```

##### `POST /api/user/mt5accounts/changeleverage`

- **Frontend:** `mt5Service.changeLeverage` (`src/services/mt5.service.js:157`), `mt5Service.requestUnlimitedLeverage` (`src/services/mt5.service.js:181`)
- **Triggered from:** `submitLeverage`, `submitUnlimitedLeverage`
- **Backend:** `Mt5Controller@changeLeverageRequest` — `core/app/Http/Controllers/Common/Mt5Controller.php:2923-3194`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:3185`
```json
{
  "status": 200,
  "success": true,
  "message": "Leverage change request processed successfully",
  "data": {
    "request_status": "..."
  }
}
```

**Errors** (`success: false`)
- `:2959` `404` — Account not found
- `:2991` `422` — Enter a valid leverage (a whole number of at least 1)
- `:3005` `422` — Leverage changes are not allowed for this account group
- `:3009` `422` — Requested leverage 1:
- `:3020` `422` — Current leverage and new leverage are same
- `:3035` `422` — Leverage change request is already pending

##### `POST /api/user/mt5accounts/changepassword`

- **Frontend:** `mt5Service.changePassword` (`src/services/mt5.service.js:117`)
- **Triggered from:** `submitPassword`
- **Backend:** `Mt5Controller@changePassword` — `core/app/Http/Controllers/Common/Mt5Controller.php:2756-2807`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `newPassword`, `newPassword.min`, `newPassword.max`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2801`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:2802`
```json
{
  "status": 200,
  "success": true,
  "message": "Password changed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2762` `400` — MT5 account number is required
- `:2781` `404` — MT5 account not found
- `:2792` `500` — Failed to update the password in MT5: 
- `:2804` `500` — ($e->getMessage(), false, [], 500)
- `:2805` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/changePrimaryAccount`

- **Frontend:** `mt5Service.setPrimaryAccount` (`src/services/mt5.service.js:191`)
- **Triggered from:** `handleAccountSelected`, `setTimeout`, `selectAccount`, `handleSwitch`, `navigateToTrade`
- **Backend:** `Mt5Controller@changePrimaryAccount` — `core/app/Http/Controllers/Common/Mt5Controller.php:455-474`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:468`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:469`
```json
{
  "status": 200,
  "success": true,
  "message": "Primary account changed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:461` `404` — Trading account not found.
- `:462` `404` — Trading account not found
- `:471` `500` — ($e->getMessage(), false, [], 500)
- `:472` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/mt5accounts/setbalance`

- **Frontend:** `mt5Service.setBalance` (`src/services/mt5.service.js:78`)
- **Triggered from:** `submitBalance`
- **Backend:** `Mt5Controller@setBalance` — `core/app/Http/Controllers/Common/Mt5Controller.php:2583-2726`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:2712`
```json
{
  "status": 200,
  "success": true,
  "message": "Balance updated successfully",
  "data": {
    "amount": "...",
    "account_number": "...",
    "balance": "...",
    "reference_number": "..."
  }
}
```

**Errors** (`success: false`)
- `:2589` `404` — MT5 account not found
- `:2593` `400` — Only demo account can be updated
- `:2598` `400` — Demo contest accounts cannot be manually funded.
- `:2662` `500` — Failed to deposit funds: 
- `:2724` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/price-alerts`

- **Frontend:** `priceAlertService.createAlert` (`src/services/priceAlert.service.js:22`)
- **Triggered from:** `accountNumberForCreate`
- **Backend:** `PriceAlertController@store` — `core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:82-162`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `mt5_account_id`, `meta_account_number`, `symbol`, `target_price`, `condition`, `fcm_token`, `device_type`, `message`

**Success**

`core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:161`
```json
{
  "status": 200,
  "success": true,
  "message": "Price alert created successfully",
  "data": {
    "alert": "..."
  }
}
```

**Errors** (`success: false`)
- `:86` `404` — Price Alerts module is disabled
- `:103` `422` — Validation failed
- `:107` `422` — Provide either mt5_account_id or meta_account_number
- `:122` `404` — MT5 Account not found or does not belong to you
- `:129` `400` — Account does not have a group assigned
- `:140` `400` — Maximum {$maxAlerts} active alerts allowed per user

##### `POST /api/user/price-alerts/update-fcm-token`

- **Frontend:** `registerPriceAlertWebToken` (`src/services/priceAlertNotification.js:29`)
- **Triggered from:** `onMounted`
- **Backend:** `PriceAlertController@updateFcmToken` — `core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:262-327`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `fcm_token`, `device_type`, `mt5_account_id`

**Success**

`core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:324`
```json
{
  "status": 200,
  "success": true,
  "message": "FCM token updated successfully",
  "data": {
    "alerts_updated": "..."
  }
}
```

**Errors** (`success: false`)
- `:266` `404` — Price Alerts module is disabled
- `:278` `422` — Validation failed
- `:294` `404` — MT5 Account not found or does not belong to you

##### `POST /api/user/trade/chart-state`

> **Not live:** Chart layouts are saved in the browser only (CHART_STATE_BACKEND_DISABLED = true in chartSaveLoadAdapter.js:7). Backend routes are commented out in routes/api.php:532-534, so this call is never made.

- **Frontend:** `persist` (`src/services/chartSaveLoadAdapter.js:357`)
- **Triggered from:** `toUTCYYYYMMDD`, `setup`

_Response shape not detected — see controller._

##### `POST /api/user/trade/chart-store`

- **Frontend:** `chartRemote.save` (`src/components/trading/shared/TenaxChartPanel.vue:97`)
- **Triggered from:** `save`
- **Backend:** `ChartStoreController@store` — `core/app/Http/Controllers/User/ChartStoreController.php:49-69`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:120,1`
- **Request fields (validated):** `scope`, `state`

**Success**

`core/app/Http/Controllers/User/ChartStoreController.php:68`
```json
{
  "status": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:57` `422` — (['status' => false, 'message' => 'Unknown chart scope.'], 422)

##### `POST /api/user/trade/closePendingOrder`

- **Frontend:** `tradeService.closePendingOrder` (`src/services/trade.service.js:67`)
- **Triggered from:** `getOrderTypeClass`, `sanitizeStopLoss`, `current`, `handleOrderModify`, `closeConfirmModal`
- **Backend:** `TradeController@closePendingOrder` — `core/app/Http/Controllers/User/TradeController.php:2005-2143`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mt5_account`


**Errors** (`success: false`)
- `:2054` `400` — The order ids field is required.
- `:2060` `400` — All order IDs must be numeric.
- `:2069` `404` — Invalid Account
- `:2128` `500` — ( $message, $cancelledCount > 0, [ 'cancelled' => $cancelledOrders, 'failed' => $failedOrders, ], $cancelledCount > 0 ? 200 : 500 )
- `:2141` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/trade/closePositionByPositionId`

- **Frontend:** `tradeService.closePositionsByIds` (`src/services/trade.service.js:118`), `tradeService.closePositionById` (`src/services/trade.service.js:101`)
- **Triggered from:** `handleOverlayClick`, `updateContainerHeight`, `getPLClass`, `validateCloseVolume`, `current`, `volumeToSend`, `closeConfirmModal`
- **Backend:** `TradeController@closePositionByPositionId` — `core/app/Http/Controllers/User/TradeController.php:1424-1947`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mt5_account`, `position_id`, `position_ids`, `position_ids.*`, `volume`

**Success**

`core/app/Http/Controllers/User/TradeController.php:1670`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "closed": "...",
    "failed": "...",
    "failed_positions": "...",
    "closed_position_ids": "..."
  }
}
```
`core/app/Http/Controllers/User/TradeController.php:1739`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$data>"
}
```
`core/app/Http/Controllers/User/TradeController.php:1929`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "already_closed": "...",
    "position_id": "..."
  }
}
```

**Errors** (`success: false`)
- `:1453` `422` — Either position_id or position_ids (non-empty array) is required
- `:1460` `500` — Invalid MT5 Account
- `:1467` `503` — Market is closed
- `:1470` `503` — Market is closed
- `:1536` `500` — ( $bulkResp['message'] ?? 'Batch close failed', false, ['errors' => [$bulkResp['message'] ?? 'Batch close failed']], 500 )
- `:1934` `500` — ($errorMessage, false, [], 500)

##### `POST /api/user/trade/marketwatch`

- **Frontend:** `tradeService.updateMarketWatch` (`src/services/trade.service.js:332`)
- **Triggered from:** `handleAdd`, `handleRemove`, `toggleFavorite`, `onDrop`, `handleDelete`, `onDragHandleEnd`
- **Backend:** `UserMarketwatchController@createOrUpdate` — `core/app/Http/Controllers/User/UserMarketwatchController.php:42-59`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `symbols`

**Success**

`core/app/Http/Controllers/User/UserMarketwatchController.php:58`
```json
{
  "status": 200,
  "success": true,
  "message": "Marketwatch created/updated successfully",
  "data": "<$userMarketwatch>"
}
```

##### `POST /api/user/trade/new-order`

- **Frontend:** `tradeService.placeOrder` (`src/services/trade.service.js:47`)
- **Triggered from:** `side`, `adjustQtVolume`, `handleQuickTrade`, `symbolForApi`
- **Backend:** `TradeController@placeOrder` — `core/app/Http/Controllers/User/TradeController.php:165-858`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mt5_account`, `symbol`, `volume`, `type`, `mt5_account.required`, `volume.min`

**Success**

`core/app/Http/Controllers/User/TradeController.php:553`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$mappedResponse>"
}
```
`core/app/Http/Controllers/User/TradeController.php:719`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$parsedData>"
}
```
`core/app/Http/Controllers/User/TradeController.php:852`
```json
{
  "status": 200,
  "success": true,
  "message": "Trade has been successfully placed",
  "data": "<$parsedData>"
}
```

**Errors** (`success: false`)
- `:171` `400` — Trading Account is required
- `:223` `500` — MT5 Account not found
- `:228` `403` — Trading is disabled for this account
- `:233` `503` — Market is closed today (holiday)
- `:238` `503` — Market is closed
- `:250` `403` — Trading is not allowed for this instrument on ScratchCard accounts.

##### `POST /api/user/trade/update-pending-order-tp-sl`

- **Frontend:** `tradeService.modifyPendingOrder` (`src/services/trade.service.js:198`)
- **Triggered from:** `sanitizeStopLoss`, `keep`, `decreaseStopLoss`
- **Backend:** `TradeController@updatePendingOrderTPSL` — `core/app/Http/Controllers/User/TradeController.php:6460-6601`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mt5_account`, `order_id`, `stop_loss`, `take_profit`, `price`

**Success**

`core/app/Http/Controllers/User/TradeController.php:6595`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$result['data'] ?? $result>"
}
```

**Errors** (`success: false`)
- `:6521` `404` — Trading account not found or inactive
- `:6532` `404` — Pending order not found
- `:6536` `400` — Cannot update TP/SL for a cancelled or executed order
- `:6550` `400` — ($errorMessage, false, $result['data'] ?? [], 400)
- `:6599` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/trade/update-tp-sl`

- **Frontend:** `roundIfNeeded` (`src/services/trade.service.js:173`)
- **Triggered from:** `sanitizeStopLoss`, `keep`, `handleQuickClose`
- **Backend:** `TradeController@updateTPSL` — `core/app/Http/Controllers/User/TradeController.php:6237-6370`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mt5_account`, `position_id`, `stop_loss`, `take_profit`

**Success**

`core/app/Http/Controllers/User/TradeController.php:6364`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$result['data'] ?? $result>"
}
```

**Errors** (`success: false`)
- `:6289` `404` — Trading account not found or inactive
- `:6301` `400` — Cannot update TP/SL for a closed position
- `:6360` `400` — ($errorMessage, false, $result['data'] ?? [], 400)
- `:6368` `500` — ($e->getMessage(), false, [], 500)

##### `PUT /api/user/price-alerts/{id}`

- **Frontend:** `priceAlertService.updateAlert` (`src/services/priceAlert.service.js:27`)
- **Triggered from:** `isPaused`, `accountNumberForCreate`
- **Backend:** `PriceAlertController@update` — `core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:168-219`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `symbol`, `target_price`, `condition`, `fcm_token`, `device_type`, `message`, `is_active`

**Success**

`core/Modules/PriceAlerts/Http/Controllers/User/PriceAlertController.php:218`
```json
{
  "status": 200,
  "success": true,
  "message": "Price alert updated successfully",
  "data": {
    "alert": "..."
  }
}
```

**Errors** (`success: false`)
- `:172` `404` — Price Alerts module is disabled
- `:182` `404` — Price alert not found
- `:187` `400` — Cannot update a triggered alert
- `:201` `422` — Validation failed

</details>

### Mobile WebView chart — `/mobile-chart`

Component: `src/components/trading/mobile/MobileWebViewChart.vue` — **3 APIs**

1. `DELETE /api/user/trade/chart-state/{param}`
2. `POST /api/user/mt5accounts/changePrimaryAccount` → `Mt5Controller@changePrimaryAccount`
3. `POST /api/user/trade/new-order` → `TradeController@placeOrder`

<details><summary>Request / response details</summary>

##### `DELETE /api/user/trade/chart-state/{param}`

> **Not live:** Chart layouts are saved in the browser only (CHART_STATE_BACKEND_DISABLED = true in chartSaveLoadAdapter.js:7). Backend routes are commented out in routes/api.php:532-534, so this call is never made.

- **Frontend:** `removeChart` (`src/services/chartSaveLoadAdapter.js:579`)
- **Triggered from:** `watch`

_Response shape not detected — see controller._

##### `POST /api/user/mt5accounts/changePrimaryAccount`

- **Frontend:** `mt5Service.setPrimaryAccount` (`src/services/mt5.service.js:191`)
- **Triggered from:** `onMounted`
- **Backend:** `Mt5Controller@changePrimaryAccount` — `core/app/Http/Controllers/Common/Mt5Controller.php:455-474`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:468`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:469`
```json
{
  "status": 200,
  "success": true,
  "message": "Primary account changed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:461` `404` — Trading account not found.
- `:462` `404` — Trading account not found
- `:471` `500` — ($e->getMessage(), false, [], 500)
- `:472` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/trade/new-order`

- **Frontend:** `tradeService.placeOrder` (`src/services/trade.service.js:47`)
- **Triggered from:** `handleQuickTrade`
- **Backend:** `TradeController@placeOrder` — `core/app/Http/Controllers/User/TradeController.php:165-858`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mt5_account`, `symbol`, `volume`, `type`, `mt5_account.required`, `volume.min`

**Success**

`core/app/Http/Controllers/User/TradeController.php:553`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$mappedResponse>"
}
```
`core/app/Http/Controllers/User/TradeController.php:719`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$parsedData>"
}
```
`core/app/Http/Controllers/User/TradeController.php:852`
```json
{
  "status": 200,
  "success": true,
  "message": "Trade has been successfully placed",
  "data": "<$parsedData>"
}
```

**Errors** (`success: false`)
- `:171` `400` — Trading Account is required
- `:223` `500` — MT5 Account not found
- `:228` `403` — Trading is disabled for this account
- `:233` `503` — Market is closed today (holiday)
- `:238` `503` — Market is closed
- `:250` `403` — Trading is not allowed for this instrument on ScratchCard accounts.

</details>

---

## Deposit

### Deposit (methods) — `/deposit`

Component: `src/components/Deposit.vue` — **1 APIs**

1. `GET /api/user/deposit` → `FinanceController@deposit`

<details><summary>Request / response details</summary>

##### `GET /api/user/deposit`

- **Frontend:** `financeService.getDepositMethods` (`src/services/finance.service.js:7`)
- **Triggered from:** `loadDepositMethods`
- **Backend:** `FinanceController@deposit` — `core/app/Http/Controllers/User/FinanceController.php:735-912`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:900`
```json
{
  "status": 200,
  "success": true,
  "message": "Deposit methods retrieved successfully",
  "data": "<$filteredMethods>"
}
```

**Errors** (`success: false`)
- `:743` `403` — Deposit is currently disabled. Please contact our support team for assistance.
- `:907` `500` — Error retrieving deposit methods

</details>

### Deposit request / history — `/deposit-request`

Component: `src/components/DepositRequest.vue` — **7 APIs**

1. `GET /api/user/deposit/{methodSlug}` → `FinanceController@depositMethod`
2. `GET /api/user/mt5accounts/get` → `Mt5Controller@getMT5Accounts`
3. `GET /api/user/regulation` → `UserController@getRegulationDetails`
4. `POST /api/user/deposit/cregis` → `FinanceController@cregisDeposit`
5. `POST /api/user/deposit/depositrequest` → `FinanceController@createDepositRequest`
6. `POST /api/user/deposit/dynamic/{gatewaySlug}` → `DynamicGatewayController@deposit`
7. `POST /api/user/deposit/unipayment` → `FinanceController@unipaymentDeposit`

<details><summary>Request / response details</summary>

##### `GET /api/user/deposit/{methodSlug}`

- **Frontend:** `financeService.getDepositMethodDetails` (`src/services/finance.service.js:16`)
- **Triggered from:** `loadAccountDetails`
- **Backend:** `FinanceController@depositMethod` — `core/app/Http/Controllers/User/FinanceController.php:1074-1326`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:1312`
```json
{
  "status": 200,
  "success": true,
  "message": "Deposit method retrieved successfully",
  "data": "<$data>"
}
```
`core/app/Http/Controllers/User/FinanceController.php:1313`
```json
{
  "depositMethod": "...",
  "userMT5Accounts": "...",
  "wallet": "..."
}
```

**Errors** (`success: false`)
- `:1084` `404` — This payment method is no longer available. Please choose another method.
- `:1099` `403` — ($message, false, [], 403)
- `:1110` `403` — This payment method is currently unavailable. Please try another method.
- `:1143` `403` — KYC verification required for this deposit method.
- `:1321` `500` — ($e->getMessage(), false, [], 500)

##### `GET /api/user/mt5accounts/get`

- **Frontend:** `mt5Service.getAccounts` (`src/services/mt5.service.js:15`)
- **Triggered from:** `loadTradingAccounts`
- **Backend:** `Mt5Controller@getMT5Accounts` — `core/app/Http/Controllers/Common/Mt5Controller.php:146-341`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:337`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading accounts retrieved successfully",
  "data": "<$selectedAccounts>"
}
```

**Errors** (`success: false`)
- `:151` `401` — User not authenticated
- `:165` — No active trading accounts found
- `:339` `500` — Failed to retrieve trading accounts: 

##### `GET /api/user/regulation`

- **Frontend:** `regulationService.getRegulationDetails` (`src/services/regulation.service.js:6`)
- **Triggered from:** `loadRegulatedBrokerSetting`
- **Backend:** `UserController@getRegulationDetails` — `core/app/Http/Controllers/User/UserController.php:826-960`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:912`
```json
{
  "status": 200,
  "success": true,
  "message": "Regulation details fetched successfully",
  "data": {
    "regulated_broker_enabled": "...",
    "regulation_valid": "...",
    "regulation_required": "...",
    "review_status": "...",
    "review_notes": "...",
    "reviewed_at": "...",
    "hide_country_for_regulated": "...",
    "hide_country_for_regulated_countries": "...",
    "disable_upi_deposit_for_regulated": "...",
    "disable_upi_withdrawal_for_regulated": "...",
    "force_regulated_form": "...",
    "force_skip_regulated_form": "...",
    "require_fatca": "...",
    "require_pep": "...",
    "require_us_tax_form": "...",
    "dynamic_compliance_enabled": "...",
    "schema": "...",
    "template": "...",
    "regulation": "...",
    "id": "...",
    "template_id": "...",
    "template_version": "...",
    "form_payload": "...",
    "ip_address": "...",
    "ip_location": "...",
    "user_agent": "...",
    "submitted_at": "...",
    "created_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:949` `500` — Failed to fetch regulation details: 

##### `POST /api/user/deposit/cregis`

- **Frontend:** `financeService.createCregisDeposit` (`src/services/finance.service.js:358`)
- **Triggered from:** `cur`
- **Backend:** `FinanceController@cregisDeposit` — `core/app/Http/Controllers/User/FinanceController.php:8803-9068`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `feature.maintenance:deposit`
- **Request fields (validated):** `gateway_method_id`, `mt5_account_id`, `amount`, `chain_id`, `crypto_network`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:8994`
```json
{
  "status": 200,
  "success": true,
  "message": "Payment order created",
  "data": {
    "reference_number": "...",
    "amount": "...",
    "chain_id": "...",
    "crypto_network": "...",
    "checkout_url": "...",
    "cregis_id": "...",
    "account_number": "..."
  }
}
```

**Errors** (`success: false`)
- `:8815` `422` — ($validator->errors()->first(), false, [], 422)
- `:8825` `403` — Cregis is currently unavailable for this deposit method.
- `:8835` `503` — Cregis gateway credentials are incomplete in Master Gateway settings.
- `:8841` — Invalid MT5 Account
- `:8849` `422` — ($msg, false, [], 422)
- `:8956` `502` — Cregis did not return a checkout URL.

##### `POST /api/user/deposit/depositrequest`

- **Frontend:** `financeService.createDepositRequest` (`src/services/finance.service.js:27`)
- **Triggered from:** `cur`
- **Backend:** `FinanceController@createDepositRequest` — `core/app/Http/Controllers/User/FinanceController.php:1687-2071`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `feature.maintenance:deposit`, `throttle:10,1`
- **Request fields (validated):** `mt5_account_id`, `amount`, `gateway_method_id`, `utr_referce`, `user_input_net_amount`, `user_input_currency`, `client_note`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:2045`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "link": "..."
  }
}
```
`core/app/Http/Controllers/User/FinanceController.php:2054`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/User/FinanceController.php:2055`
```json
{
  "status": 200,
  "success": true,
  "message": "Deposit request created successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:1697` `404` — User not found
- `:1709` `403` — Deposits are not available in your country.
- `:1717` `403` — KYC verification is required before you can request a deposit. Please complete KYC and try again.
- `:1738` `429` — Another deposit request is already being processed for your account. Please wait a moment.
- `:1747` — Invalid gateway method
- `:1751` `422` — This deposit method currency is not configured. Please contact support.

##### `POST /api/user/deposit/dynamic/{gatewaySlug}`

- **Frontend:** `financeService.createDynamicDeposit` (`src/services/finance.service.js:368`)
- **Triggered from:** `cur`
- **Backend:** `DynamicGatewayController@deposit` — `core/app/Http/Controllers/User/DynamicGatewayController.php:36-340`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `feature.maintenance:deposit`
- **Request fields (validated):** `gateway_method_id`, `mt5_account_id`, `amount`, `user_input_net_amount`, `user_input_currency`, `card_number`, `card_expiry`, `card_cvv`, `card_name`, `payer_mobile`

**Success**

`core/app/Http/Controllers/User/DynamicGatewayController.php:327`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "mt5_account_id": "...",
    "reference_number": "...",
    "open_in_new_tab": "..."
  }
}
```

**Errors** (`success: false`)
- `:62` `404` — Unsupported payment gateway.
- `:69` `404` — User not found
- `:74` `429` — Another deposit request is already being processed. Please wait a moment.
- `:93` `422` — ($validator->errors()->first(), false, [], 422)
- `:109` `422` — Mobile number is required for 
- `:121` — Invalid gateway method

##### `POST /api/user/deposit/unipayment`

- **Frontend:** `financeService.createUniPaymentDeposit` (`src/services/finance.service.js:348`)
- **Triggered from:** `cur`
- **Backend:** `FinanceController@unipaymentDeposit` — `core/app/Http/Controllers/User/FinanceController.php:9575-9717`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `feature.maintenance:deposit`
- **Request fields (validated):** `gateway_method_id`, `mt5_account_id`, `amount`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:9697`
```json
{
  "status": 200,
  "success": true,
  "message": "Invoice created",
  "data": {
    "invoice_url": "...",
    "invoice_id": "...",
    "reference_number": "...",
    "amount": "...",
    "currency": "...",
    "account_number": "..."
  }
}
```

**Errors** (`success: false`)
- `:9585` `422` — ($validator->errors()->first(), false, [], 422)
- `:9594` `403` — UniPayment is currently unavailable.
- `:9603` `503` — UniPayment gateway credentials are incomplete in Master Gateway settings.
- `:9610` — Invalid MT5 Account
- `:9619` `422` — ($msg, false, [], 422)
- `:9647` `422` — UniPayment requires HTTPS callback URLs. Your 

</details>

### UniPayment success — `/deposit/unipayment/success`

Component: `src/components/UniPaymentSuccess.vue` — **1 APIs**

1. `GET /api/user/deposit/by-reference` → `FinanceController@getDepositByReference`

<details><summary>Request / response details</summary>

##### `GET /api/user/deposit/by-reference`

- **Frontend:** `financeService.getDepositByReference` (`src/services/finance.service.js:378`)
- **Triggered from:** `check`
- **Backend:** `FinanceController@getDepositByReference` — `core/app/Http/Controllers/User/FinanceController.php:10001-10024`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:10016`
```json
{
  "status": 200,
  "success": true,
  "message": "Deposit found.",
  "data": {
    "reference_number": "...",
    "amount": "...",
    "status": "...",
    "mt5_account_id": "...",
    "gateway_method_id": "...",
    "created_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:10005` `400` — Reference number is required.
- `:10013` `404` — Deposit not found.

</details>

### UniPayment cancel — `/deposit/unipayment/cancel`

Component: `src/components/UniPaymentCancel.vue` — **0 APIs**

_No API calls (static page or uses only the app-shell calls)._

### Cregis success — `/deposit/cregis/success`

Component: `src/components/CregisSuccess.vue` — **1 APIs**

1. `GET /api/user/deposit/by-reference` → `FinanceController@getDepositByReference`

<details><summary>Request / response details</summary>

##### `GET /api/user/deposit/by-reference`

- **Frontend:** `financeService.getDepositByReference` (`src/services/finance.service.js:378`)
- **Triggered from:** `check`
- **Backend:** `FinanceController@getDepositByReference` — `core/app/Http/Controllers/User/FinanceController.php:10001-10024`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:10016`
```json
{
  "status": 200,
  "success": true,
  "message": "Deposit found.",
  "data": {
    "reference_number": "...",
    "amount": "...",
    "status": "...",
    "mt5_account_id": "...",
    "gateway_method_id": "...",
    "created_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:10005` `400` — Reference number is required.
- `:10013` `404` — Deposit not found.

</details>

---

## Withdrawal

### Withdrawal (methods) — `/withdrawal`

Component: `src/components/Withdrawal.vue` — **1 APIs**

1. `GET /api/user/withdrawal` → `FinanceController@withdrawal`

<details><summary>Request / response details</summary>

##### `GET /api/user/withdrawal`

- **Frontend:** `financeService.getWithdrawalMethods` (`src/services/finance.service.js:77`)
- **Triggered from:** `loadWithdrawalMethods`
- **Backend:** `FinanceController@withdrawal` — `core/app/Http/Controllers/User/FinanceController.php:2078-2254`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:2242`
```json
{
  "status": 200,
  "success": true,
  "message": "Withdrawal methods retrieved successfully",
  "data": "<$filteredMethods>"
}
```

**Errors** (`success: false`)
- `:2089` `403` — ($message, false, [], 403)
- `:2252` `500` — ($e->getMessage(), false, [], 500)

</details>

### Withdrawal request / history — `/withdrawal-request`

Component: `src/components/WithdrawalRequest.vue` — **5 APIs**

1. `GET /api/user/mt5accounts/get` → `Mt5Controller@getMT5Accounts`
2. `GET /api/user/withdrawal/sendOTP` → `FinanceController@withdrawalOtpSend`
3. `GET /api/user/withdrawal/withdrawal-method/{methodId}` → `FinanceController@withdrawalMethod`
4. `POST /api/user/withdrawal/checkbalance` → `FinanceController@checkBalance`
5. `POST /api/user/withdrawal/withdrawalrequest` → `FinanceController@createWithdrawalRequest`

<details><summary>Request / response details</summary>

##### `GET /api/user/mt5accounts/get`

- **Frontend:** `mt5Service.getAccounts` (`src/services/mt5.service.js:15`)
- **Triggered from:** `updateValuesOnly`
- **Backend:** `Mt5Controller@getMT5Accounts` — `core/app/Http/Controllers/Common/Mt5Controller.php:146-341`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:337`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading accounts retrieved successfully",
  "data": "<$selectedAccounts>"
}
```

**Errors** (`success: false`)
- `:151` `401` — User not authenticated
- `:165` — No active trading accounts found
- `:339` `500` — Failed to retrieve trading accounts: 

##### `GET /api/user/withdrawal/sendOTP`

- **Frontend:** `financeService.sendWithdrawalOTP` (`src/services/finance.service.js:127`)
- **Triggered from:** `setInterval`, `submitWithdrawalRequest`
- **Backend:** `FinanceController@withdrawalOtpSend` — `core/app/Http/Controllers/User/FinanceController.php:3422-3607`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:3582`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "channel": "...",
    "alternate_channel": "..."
  }
}
```

**Errors** (`success: false`)
- `:3431` `422` — ($balanceCheck['message'], false, [], 422)
- `:3462` `422` — Account ID and amount are required for withdrawal.
- `:3477` `403` — Account locked for PMAM. Unsubscribe first.
- `:3480` `403` — This account is a PMAM pool with investor funds. Withdrawals are not allowed.
- `:3493` `422` — ($balanceCheck['message'], false, [], 422)
- `:3510` `403` — Source account is locked for PMAM. Unsubscribe first.

##### `GET /api/user/withdrawal/withdrawal-method/{methodId}`

- **Frontend:** `financeService.getWithdrawalMethodDetails` (`src/services/finance.service.js:91`)
- **Triggered from:** `loadWithdrawalMethodDetails`
- **Backend:** `FinanceController@withdrawalMethod` — `core/app/Http/Controllers/User/FinanceController.php:2262-2585`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:2572`
```json
{
  "status": 200,
  "success": true,
  "message": "Withdrawal method retrieved successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:2295` `403` — KYC verification required for this withdrawal method.
- `:2310` `403` — ($message, false, [], 403)
- `:2318` `403` — Withdrawal is currently disabled. Please contact our support team for assistance.
- `:2319` `403` — Withdrawal is currently disabled. Please contact our support team for assistance.
- `:2580` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/withdrawal/checkbalance`

- **Frontend:** `financeService.checkBalance` (`src/services/finance.service.js:104`)
- **Triggered from:** `setTimeout`
- **Backend:** `FinanceController@checkBalance` — `core/app/Http/Controllers/User/FinanceController.php:4135-4382`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:4193`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "valid": "..."
  }
}
```
`core/app/Http/Controllers/User/FinanceController.php:4194`
```json
{
  "valid": "..."
}
```

**Errors** (`success: false`)
- `:4144` `404` — Invalid withdrawal method
- `:4161` `422` — ($minMsg, false, [], 422)
- `:4167` `422` — ($maxMsg, false, [], 422)
- `:4199` `500` — Insufficient wallet balance.
- `:4223` `500` — Insufficient rebate balance.
- `:4249` `500` — Insufficient IB wallet balance.

##### `POST /api/user/withdrawal/withdrawalrequest`

- **Frontend:** `financeService.createWithdrawalRequest` (`src/services/finance.service.js:118`)
- **Triggered from:** `verifyOTP`
- **Backend:** `FinanceController@createWithdrawalRequest` — `core/app/Http/Controllers/User/FinanceController.php:2705-3372`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `feature.maintenance:withdrawal`, `throttle:10,1`
- **Request fields (validated):** `mt5_account_id`, `withdrawal_method_id`, `withdrawal_method_slug`, `amount`, `user_input_net_amount`, `user_input_currency`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:3355`
```json
{
  "status": 200,
  "success": true,
  "message": "Withdrawal request created successfully",
  "data": "<$data>"
}
```
`core/app/Http/Controllers/User/FinanceController.php:3359`
```json
{
  "message": "..."
}
```

**Errors** (`success: false`)
- `:2716` `422` — User not found.
- `:2727` `403` — Withdrawals are not available in your country.
- `:2735` `403` — KYC verification is required before you can request a withdrawal. Please complete KYC and try again.
- `:2775` `403` — Commission withdrawals are currently unavailable. Please contact support.
- `:2785` `422` — The wallet service is not available right now. Please try again later or contact support.
- `:2794` `422` — You do not have a wallet yet. Please make a first deposit to create one, then try the withdrawal again.

</details>

---

## Internal Transfer

### Internal Transfer — `/internal-transfer`

Component: `src/components/InternalTransaction.vue` — **6 APIs**

1. `GET /api/user/crm-settings` → `SettingController@getCrmSettings`
2. `GET /api/user/internaltransfer` → `FinanceController@internalTransfer`
3. `GET /api/user/internaltransfer/history` → `FinanceController@getInternalTransferHistory`
4. `GET /api/user/withdrawal/sendOTP` → `FinanceController@withdrawalOtpSend`
5. `POST /api/user/internaltransfer/request` → `FinanceController@createInternalTransferRequest`
6. `POST /api/user/withdrawal/checkbalance` → `FinanceController@checkBalance`

<details><summary>Request / response details</summary>

##### `GET /api/user/crm-settings`

- **Frontend:** `crmSettingsService.getCrmSettings` (`src/services/crmSettings.service.js:19`)
- **Triggered from:** `loadFinancialSettings`
- **Backend:** `SettingController@getCrmSettings` — `core/app/Http/Controllers/Common/SettingController.php:475-489`
- **Middleware:** `logNavigation`

**Success**

`core/app/Http/Controllers/Common/SettingController.php:478`
```json
{
  "status": 200,
  "success": true,
  "message": "CRM settings retrieved successfully",
  "data": "<$crmSettingsService->getPublicPayload()>"
}
```

**Errors** (`success: false`)
- `:487` `500` — Error: 

##### `GET /api/user/internaltransfer`

- **Frontend:** `financeService.getInternalTransferAccounts` (`src/services/finance.service.js:164`)
- **Triggered from:** `loadAccounts`
- **Backend:** `FinanceController@internalTransfer` — `core/app/Http/Controllers/User/FinanceController.php:4472-4632`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:4623`
```json
{
  "status": 200,
  "success": true,
  "message": "Data retrieved successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:4479` `403` — Internal transfer is disabled for your account. Please contact admin to enable it.

##### `GET /api/user/internaltransfer/history`

- **Frontend:** `financeService.getInternalTransferHistory` (`src/services/finance.service.js:183`)
- **Triggered from:** `loadTransferHistory`
- **Backend:** `FinanceController@getInternalTransferHistory` — `core/app/Http/Controllers/User/FinanceController.php:5182-5269`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:5252`
```json
{
  "status": 200,
  "success": true,
  "message": "Internal transfer history retrieved successfully",
  "data": {
    "data": "...",
    "pagination": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "...",
    "from": "...",
    "to": "..."
  }
}
```

**Errors** (`success: false`)
- `:5267` `500` — Failed to fetch internal transfer history

##### `GET /api/user/withdrawal/sendOTP`

- **Frontend:** `financeService.sendWithdrawalOTP` (`src/services/finance.service.js:127`)
- **Triggered from:** `sendOTP`
- **Backend:** `FinanceController@withdrawalOtpSend` — `core/app/Http/Controllers/User/FinanceController.php:3422-3607`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:3582`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "channel": "...",
    "alternate_channel": "..."
  }
}
```

**Errors** (`success: false`)
- `:3431` `422` — ($balanceCheck['message'], false, [], 422)
- `:3462` `422` — Account ID and amount are required for withdrawal.
- `:3477` `403` — Account locked for PMAM. Unsubscribe first.
- `:3480` `403` — This account is a PMAM pool with investor funds. Withdrawals are not allowed.
- `:3493` `422` — ($balanceCheck['message'], false, [], 422)
- `:3510` `403` — Source account is locked for PMAM. Unsubscribe first.

##### `POST /api/user/internaltransfer/request`

- **Frontend:** `financeService.createInternalTransfer` (`src/services/finance.service.js:174`)
- **Triggered from:** `submitInternalTransfer`
- **Backend:** `FinanceController@createInternalTransferRequest` — `core/app/Http/Controllers/User/FinanceController.php:4736-4948`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:10,1`
- **Request fields (validated):** `from_account`, `to_account`, `amount`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:4886`
```json
{
  "status": 200,
  "success": true,
  "message": "Transfer request submitted for admin approval.",
  "data": {
    "status": "..."
  }
}
```
`core/app/Http/Controllers/User/FinanceController.php:4898`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "..."
}
```
`core/app/Http/Controllers/User/FinanceController.php:4930`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/User/FinanceController.php:4935`
```json
{
  "status": 200,
  "success": true,
  "message": "Funds transferred successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:4747` `404` — User not found
- `:4760` `429` — Another transfer is already being processed for your account. Please wait a moment.
- `:4777` `422` — ($otpVerificationResult['error'], false, [], 422)
- `:4786` `403` — Internal transfer is disabled for your account. Please contact admin to enable it.
- `:4811` — ($validator->errors(), false, [], 200)
- `:4813` `422` — Validation failed

##### `POST /api/user/withdrawal/checkbalance`

- **Frontend:** `financeService.checkBalance` (`src/services/finance.service.js:104`)
- **Triggered from:** `setTimeout`
- **Backend:** `FinanceController@checkBalance` — `core/app/Http/Controllers/User/FinanceController.php:4135-4382`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:4193`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "valid": "..."
  }
}
```
`core/app/Http/Controllers/User/FinanceController.php:4194`
```json
{
  "valid": "..."
}
```

**Errors** (`success: false`)
- `:4144` `404` — Invalid withdrawal method
- `:4161` `422` — ($minMsg, false, [], 422)
- `:4167` `422` — ($maxMsg, false, [], 422)
- `:4199` `500` — Insufficient wallet balance.
- `:4223` `500` — Insufficient rebate balance.
- `:4249` `500` — Insufficient IB wallet balance.

</details>

### Internal Transfer History — `/internal-transfer-history`

Component: `src/components/InternalTransferHistory.vue` — **1 APIs**

1. `GET /api/user/internaltransfer/history` → `FinanceController@getInternalTransferHistory`

<details><summary>Request / response details</summary>

##### `GET /api/user/internaltransfer/history`

- **Frontend:** `financeService.getInternalTransferHistory` (`src/services/finance.service.js:183`)
- **Triggered from:** `loadInternalTransfers`
- **Backend:** `FinanceController@getInternalTransferHistory` — `core/app/Http/Controllers/User/FinanceController.php:5182-5269`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:5252`
```json
{
  "status": 200,
  "success": true,
  "message": "Internal transfer history retrieved successfully",
  "data": {
    "data": "...",
    "pagination": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "...",
    "from": "...",
    "to": "..."
  }
}
```

**Errors** (`success: false`)
- `:5267` `500` — Failed to fetch internal transfer history

</details>

### Trader to Trader Transfer — `/trader-transfer`

Component: `src/components/TraderTransfer.vue` — **5 APIs**

1. `GET /api/user/trader-transfer/config` → `TraderTransferController@config`
2. `GET /api/user/trader-transfer/history` → `TraderTransferController@history`
3. `POST /api/user/trader-transfer/send-otp` → `TraderTransferController@sendOtp`
4. `POST /api/user/trader-transfer/submit` → `TraderTransferController@submit`
5. `POST /api/user/trader-transfer/verify-recipient` → `TraderTransferController@verifyRecipient`

<details><summary>Request / response details</summary>

##### `GET /api/user/trader-transfer/config`

- **Frontend:** `traderTransferService.getConfig` (`src/services/traderTransfer.service.js:8`)
- **Triggered from:** `loadConfig`
- **Backend:** `TraderTransferController@config` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:37-60`
- **Middleware:** `auth:sanctum`, `throttle:api`

**Success**

`core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:43`
```json
{
  "status": 200,
  "success": true,
  "message": "Trader Transfer is not available.",
  "data": {
    "enabled": "..."
  }
}
```
`core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:49`
```json
{
  "status": 200,
  "success": true,
  "message": "OK",
  "data": {
    "enabled": "...",
    "min_amount": "...",
    "max_amount": "...",
    "sender_kyc_required": "...",
    "can_send": "...",
    "blocked_reason": "...",
    "wallet_id": "...",
    "available_balance": "...",
    "pending_transfer": "..."
  }
}
```

##### `GET /api/user/trader-transfer/history`

- **Frontend:** `traderTransferService.getHistory` (`src/services/traderTransfer.service.js:58`)
- **Triggered from:** `loadHistory`
- **Backend:** `TraderTransferController@history` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:195-244`
- **Middleware:** `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `direction`, `status`, `date_from`, `date_to`

**Success**

`core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:237`
```json
{
  "status": 200,
  "success": true,
  "message": "OK",
  "data": {
    "data": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "..."
  }
}
```

##### `POST /api/user/trader-transfer/send-otp`

- **Frontend:** `traderTransferService.sendOtp` (`src/services/traderTransfer.service.js:26`)
- **Triggered from:** `sendOtp`
- **Backend:** `TraderTransferController@sendOtp` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:79-146`
- **Middleware:** `auth:sanctum`, `throttle:api`, `feature.maintenance:withdrawal`, `throttle:5,1`
- **Request fields (validated):** `recipient_token`, `amount`

**Success**

`core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:141`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "channel": "...",
    "alternate_channel": "..."
  }
}
```

**Errors** (`success: false`)
- `:90` `422` — ($blockReason, false, [], 422)
- `:96` `422` — Insufficient wallet balance.
- `:103` `429` — Please wait for 1 minute before resending OTP.
- `:134` `422` — ($e->getMessage(), false, [], 422)
- `:138` `500` — Could not send the OTP. Please try again.

##### `POST /api/user/trader-transfer/submit`

- **Frontend:** `traderTransferService.submit` (`src/services/traderTransfer.service.js:39`)
- **Triggered from:** `submitTransfer`
- **Backend:** `TraderTransferController@submit` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:148-189`
- **Middleware:** `auth:sanctum`, `throttle:api`, `feature.maintenance:withdrawal`, `throttle:10,1`
- **Request fields (validated):** `recipient_token`, `amount`, `otp`, `note`

**Success**

`core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:184`
```json
{
  "status": 200,
  "success": true,
  "message": "Transfer submitted. It will be completed after admin approval.",
  "data": "<$this->present($transfer, $user->id)>"
}
```

**Errors** (`success: false`)
- `:162` `429` — Your transfer is already being processed. Please wait.
- `:168` `422` — ($otpError, false, [], 422)
- `:179` `422` — ($e->getMessage(), false, [], 422)

##### `POST /api/user/trader-transfer/verify-recipient`

- **Frontend:** `traderTransferService.verifyRecipient` (`src/services/traderTransfer.service.js:17`)
- **Triggered from:** `verifyRecipient`
- **Backend:** `TraderTransferController@verifyRecipient` — `core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:62-73`
- **Middleware:** `auth:sanctum`, `throttle:api`, `throttle:10,1`
- **Request fields (validated):** `email`

**Success**

`core/Modules/TraderTransfer/Http/Controllers/User/TraderTransferController.php:72`
```json
{
  "status": 200,
  "success": true,
  "message": "Recipient verified",
  "data": "<$result>"
}
```

**Errors** (`success: false`)
- `:69` `422` — ($e->getMessage(), false, [], 422)

</details>

---

## IB Dashboard (classic IB)

> Sidebar submenu depends on IB status (useIBStatus): not-IB → IB application; approved IB → Dashboard, My Structure, Sub IB Structure, My Network, Sub IB Approval, Transfer Commission.

### IB Dashboard / IB Application — `/ib-dashboard`

Component: `src/components/IBDashboard.vue` — **8 APIs**

1. `GET /api/ibm/portal/dashboard` → `DashboardController@index`
2. `GET /api/user` → external
3. `GET /api/user/crm-settings` → `SettingController@getCrmSettings`
4. `GET /api/user/ib/activities` → `IbaController@getRecentActivities`
5. `GET /api/user/ib/dashboard` → `IbaController@getDashboardData`
6. `GET /api/user/ib/stats` → `IbaController@getIBStats`
7. `POST /api/user/ib/application` → `IbaController@submitIBApplication`
8. `POST /api/user/ib/track-visit` → `IbaController@trackReferralVisit`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/dashboard`

- **Frontend:** `ibmgrDashboardApi.stats` (`src/components/ibmanager-portal/ibmanagerApi.js:259`)
- **Triggered from:** `loadIbmReferralLink`
- **Backend:** `DashboardController@index` — `core/Modules/IBManager/Http/Controllers/Portal/DashboardController.php:32-51`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/DashboardController.php:50`
```json
{
  "success": true,
  "message": "...",
  "data": "<Cache::remember($key, self::CACHE_TTL, fn (): array => $this->overview($ibUserId>"
}
```

##### `GET /api/user`

- **External call, not the CRM:** `GET https://api.ipify.org?format=json` — Visitor IP lookup (IB link tracking)
- Called from: `src/components/IBDashboard.vue:1325`

##### `GET /api/user/crm-settings`

- **Frontend:** `crmSettingsService.getCrmSettings` (`src/services/crmSettings.service.js:19`)
- **Triggered from:** `loadIbTermsAgreement`
- **Backend:** `SettingController@getCrmSettings` — `core/app/Http/Controllers/Common/SettingController.php:475-489`
- **Middleware:** `logNavigation`

**Success**

`core/app/Http/Controllers/Common/SettingController.php:478`
```json
{
  "status": 200,
  "success": true,
  "message": "CRM settings retrieved successfully",
  "data": "<$crmSettingsService->getPublicPayload()>"
}
```

**Errors** (`success: false`)
- `:487` `500` — Error: 

##### `GET /api/user/ib/activities`

- **Frontend:** `ibService.getRecentActivities` (`src/services/ib.service.js:97`)
- **Triggered from:** `loadRecentActivities`
- **Backend:** `IbaController@getRecentActivities` — `core/app/Http/Controllers/User/IbaController.php:5282-5436`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:5432`
```json
{
  "status": 200,
  "success": true,
  "message": "Recent activities retrieved successfully",
  "data": "<$activities>"
}
```

**Errors** (`success: false`)
- `:5434` `500` — Failed to get recent activities: 

##### `GET /api/user/ib/dashboard`

- **Frontend:** `ibService.getDashboardData` (`src/services/ib.service.js:7`)
- **Triggered from:** `loadDashboardData`
- **Backend:** `IbaController@getDashboardData` — `core/app/Http/Controllers/User/IbaController.php:231-261`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:256`
```json
{
  "status": 200,
  "success": true,
  "message": "IB details retrieved successfully",
  "data": {
    "userIBDetails": "..."
  }
}
```

**Errors** (`success: false`)
- `:259` `500` — ($e->getMessage(), false, [], 500)

##### `GET /api/user/ib/stats`

- **Frontend:** `ibService.getIBStats` (`src/services/ib.service.js:37`)
- **Triggered from:** `loadIBStats`, `updateValuesOnly`
- **Backend:** `IbaController@getIBStats` — `core/app/Http/Controllers/User/IbaController.php:4213-4263`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:4227`
```json
{
  "status": 200,
  "success": true,
  "message": "IB stats retrieved successfully",
  "data": {
    "available_rebate": "...",
    "total_clients": "...",
    "total_withdrawal": "...",
    "ib_withdrawal_rebate": "...",
    "total_deposited": "...",
    "total_equity": "...",
    "total_rebate_generated": "...",
    "ib_pending_requests": "...",
    "total_lots": "...",
    "margin_level_below_100": "...",
    "reference_links": "...",
    "direct_commission": "...",
    "sub_ib_commission": "...",
    "my_commission": "...",
    "total_commission": "...",
    "commission_this_month": "...",
    "commission_this_quarter": "...",
    "commission_this_year": "...",
    "direct_commission_this_month": "...",
    "sub_ib_commission_this_month": "...",
    "direct_commission_this_quarter": "...",
    "sub_ib_commission_this_quarter": "...",
    "direct_commission_this_year": "...",
    "sub_ib_commission_this_year": "...",
    "my_commission_this_month": "...",
    "my_commission_this_quarter": "...",
    "my_commission_this_year": "..."
  }
}
```

**Errors** (`success: false`)
- `:4261` `500` — Failed to get IB stats: 

##### `POST /api/user/ib/application`

- **Frontend:** `ibService.submitIBApplication` (`src/services/ib.service.js:27`)
- **Triggered from:** `submitApplication`
- **Backend:** `IbaController@submitIBApplication` — `core/app/Http/Controllers/User/IbaController.php:4064-4162`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `terms_accepted`

**Success**

`core/app/Http/Controllers/User/IbaController.php:4155`
```json
{
  "status": 200,
  "success": true,
  "message": "IB application submitted successfully",
  "data": {
    "application_id": "...",
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:4085` `400` — IB application already submitted
- `:4099` `422` — ($steps['message'], false, [], 422)
- `:4104` `422` — ($kyc['message'], false, ['kyc_status' => $kyc['kyc_status'], 'kyc_required' => true], 422)
- `:4160` `500` — Failed to submit IB application: 

##### `POST /api/user/ib/track-visit`

- **Frontend:** `ibService.trackReferralVisit` (`src/services/ib.service.js:157`)
- **Triggered from:** `trackReferralVisit`
- **Backend:** `IbaController@trackReferralVisit` — `core/app/Http/Controllers/User/IbaController.php:5616-5663`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `reference_link_id`, `visitor_ip`, `user_agent`, `referrer`

**Success**

`core/app/Http/Controllers/User/IbaController.php:5655`
```json
{
  "status": 200,
  "success": true,
  "message": "Visit tracked successfully",
  "data": {
    "reference_link_id": "...",
    "visit_count": "..."
  }
}
```

**Errors** (`success: false`)
- `:5635` `404` — Referral link not found
- `:5661` `500` — Failed to track visit: 

</details>

### My Structure — `/my-structure`

Component: `src/components/MyStructure.vue` — **3 APIs**

1. `DELETE /api/user/ib/commission-groups/{id}` → `IBCommisionGroupController@deleteCommissionGroup`
2. `GET /api/user/ib/progressive-stats` → `IbaController@getProgressiveStats`
3. `GET /api/user/ib/structure` → `IbaController@getMyStructure`

<details><summary>Request / response details</summary>

##### `DELETE /api/user/ib/commission-groups/{id}`

- **Frontend:** `subIbService.deleteCommissionGroup` (`src/services/sub-ib.service.js:47`)
- **Triggered from:** `subIbService`
- **Backend:** `IBCommisionGroupController@deleteCommissionGroup` — `core/app/Http/Controllers/User/IBCommisionGroupController.php:1554-1573`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IBCommisionGroupController.php:1569`
```json
{
  "status": 200,
  "success": true,
  "message": "Commission group deleted successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:1564` `404` — Commission group not found
- `:1571` `500` — Failed to delete commission group: 

##### `GET /api/user/ib/progressive-stats`

- **Frontend:** `ibService.getProgressiveStats` (`src/services/ib.service.js:77`)
- **Triggered from:** `loadProgressiveStats`
- **Backend:** `IbaController@getProgressiveStats` — `core/app/Http/Controllers/User/IbaController.php:7024-7259`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:7227`
```json
{
  "status": 200,
  "success": true,
  "message": "Success",
  "data": {
    "active_clients": "...",
    "total_deposit": "...",
    "total_withdrawal": "...",
    "net_deposit": "...",
    "team_active_clients": "...",
    "team_net_deposit": "...",
    "total_earned": "...",
    "total_lots": "...",
    "current_tier_earnings": "...",
    "current_balance": "...",
    "current_tier": "...",
    "name": "...",
    "min_clients": "...",
    "min_deposit": "...",
    "condition": "...",
    "next_tier": "...",
    "clients_needed": "...",
    "deposit_needed": "...",
    "current_rebates": "..."
  }
}
```

**Errors** (`success: false`)
- `:7029` `401` — Unauthenticated
- `:7081` — ([ 'status' => false, 'message' => 'No Progressive IB Plan assigned.' ])
- `:7257` `500` — ($e->getMessage(), false, [], 500)

##### `GET /api/user/ib/structure`

- **Frontend:** `ibService.getMyStructure` (`src/services/ib.service.js:57`)
- **Triggered from:** `loadStructureData`
- **Backend:** `IbaController@getMyStructure` — `core/app/Http/Controllers/User/IbaController.php:4791-4993`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:4982`
```json
{
  "status": 200,
  "success": true,
  "message": "IB structure retrieved successfully",
  "data": {
    "master_groups": "...",
    "symbol_categories": "...",
    "commission_data": "...",
    "has_admin_assigned_templates": "...",
    "admin_assigned_templates": "...",
    "private_groups": "..."
  }
}
```

**Errors** (`success: false`)
- `:4797` `403` — You do not have access to this page
- `:4991` `500` — Failed to get IB structure: 

</details>

### Sub IB Structure — `/sub-ib-structure`

Component: `src/components/SubIBStructure.vue` — **3 APIs**

1. `DELETE /api/user/ib/commission-groups/{id}` → `IBCommisionGroupController@deleteCommissionGroup`
2. `GET /api/user/ib/commission-groups` → `IBCommisionGroupController@getCommissionGroups`
3. `GET /api/user/ib/structure` → `IbaController@getMyStructure`

<details><summary>Request / response details</summary>

##### `DELETE /api/user/ib/commission-groups/{id}`

- **Frontend:** `subIbService.deleteCommissionGroup` (`src/services/sub-ib.service.js:47`)
- **Triggered from:** `deleteGroup`
- **Backend:** `IBCommisionGroupController@deleteCommissionGroup` — `core/app/Http/Controllers/User/IBCommisionGroupController.php:1554-1573`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IBCommisionGroupController.php:1569`
```json
{
  "status": 200,
  "success": true,
  "message": "Commission group deleted successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:1564` `404` — Commission group not found
- `:1571` `500` — Failed to delete commission group: 

##### `GET /api/user/ib/commission-groups`

- **Frontend:** `subIbService.getCommissionGroups` (`src/services/sub-ib.service.js:7`)
- **Triggered from:** `loadStandardGroups`
- **Backend:** `IBCommisionGroupController@getCommissionGroups` — `core/app/Http/Controllers/User/IBCommisionGroupController.php:1249-1268`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IBCommisionGroupController.php:1264`
```json
{
  "status": 200,
  "success": true,
  "message": "Commission groups retrieved successfully",
  "data": "<$commissionGroups>"
}
```

**Errors** (`success: false`)
- `:1266` `500` — Failed to get commission groups: 

##### `GET /api/user/ib/structure`

- **Frontend:** `ibService.getMyStructure` (`src/services/ib.service.js:57`)
- **Triggered from:** `loadData`
- **Backend:** `IbaController@getMyStructure` — `core/app/Http/Controllers/User/IbaController.php:4791-4993`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:4982`
```json
{
  "status": 200,
  "success": true,
  "message": "IB structure retrieved successfully",
  "data": {
    "master_groups": "...",
    "symbol_categories": "...",
    "commission_data": "...",
    "has_admin_assigned_templates": "...",
    "admin_assigned_templates": "...",
    "private_groups": "..."
  }
}
```

**Errors** (`success: false`)
- `:4797` `403` — You do not have access to this page
- `:4991` `500` — Failed to get IB structure: 

</details>

### Sub IB Structure — create/edit commission group — `/sub-ib-structure/create`

Component: `src/components/ManageCommissionGroup.vue` — **4 APIs**

1. `GET /api/user/ib/commission-groups/{id}` → `IBCommisionGroupController@getCommissionGroup`
2. `GET /api/user/ib/get-template-rates/{templateId}` → `IBCommisionGroupController@getTemplateCommissionRates`
3. `GET /api/user/ib/structure` → `IbaController@getMyStructure`
4. `POST /api/user/ib/manage` → `IBCommisionGroupController@manage`

<details><summary>Request / response details</summary>

##### `GET /api/user/ib/commission-groups/{id}`

- **Frontend:** `subIbService.getCommissionGroup` (`src/services/sub-ib.service.js:27`)
- **Triggered from:** `loadEditData`
- **Backend:** `IBCommisionGroupController@getCommissionGroup` — `core/app/Http/Controllers/User/IBCommisionGroupController.php:1314-1502`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IBCommisionGroupController.php:1486`
```json
{
  "status": 200,
  "success": true,
  "message": "Commission group retrieved successfully",
  "data": {
    "id": "...",
    "group_name": "...",
    "template_id": "...",
    "is_sub_ib_private_group": "...",
    "user_id": "...",
    "symbol_categories": "...",
    "master_group_names": "...",
    "master_groups": "...",
    "commission_data": "...",
    "current_commission_data": "...",
    "max_allowed_commission_data": "..."
  }
}
```

**Errors** (`success: false`)
- `:1328` `404` — Commission group not found
- `:1333` `403` — You are not authorized to access this private group
- `:1338` `403` — You are not authorized to access this group
- `:1500` `500` — Failed to get commission group: 

##### `GET /api/user/ib/get-template-rates/{templateId}`

- **Frontend:** `subIbService.getTemplateCommissionRates` (`src/services/sub-ib.service.js:117`)
- **Triggered from:** `loadTemplateRates`
- **Backend:** `IBCommisionGroupController@getTemplateCommissionRates` — `core/app/Http/Controllers/User/IBCommisionGroupController.php:1925-1963`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IBCommisionGroupController.php:1957`
```json
{
  "status": 200,
  "success": true,
  "message": "Data retrieved successfully",
  "data": "<$rates>"
}
```

**Errors** (`success: false`)
- `:1937` `403` — Template is not assigned to you
- `:1961` `500` — Error fetching template commission rates: 

##### `GET /api/user/ib/structure`

- **Frontend:** `ibService.getMyStructure` (`src/services/ib.service.js:57`)
- **Triggered from:** `loadStructureData`
- **Backend:** `IbaController@getMyStructure` — `core/app/Http/Controllers/User/IbaController.php:4791-4993`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:4982`
```json
{
  "status": 200,
  "success": true,
  "message": "IB structure retrieved successfully",
  "data": {
    "master_groups": "...",
    "symbol_categories": "...",
    "commission_data": "...",
    "has_admin_assigned_templates": "...",
    "admin_assigned_templates": "...",
    "private_groups": "..."
  }
}
```

**Errors** (`success: false`)
- `:4797` `403` — You do not have access to this page
- `:4991` `500` — Failed to get IB structure: 

##### `POST /api/user/ib/manage`

- **Frontend:** `subIbService.manageCommissionGroup` (`src/services/sub-ib.service.js:57`)
- **Triggered from:** `saveGroup`
- **Backend:** `IBCommisionGroupController@manage` — `core/app/Http/Controllers/User/IBCommisionGroupController.php:431-844`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IBCommisionGroupController.php:843`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:469` `422` — Validation failed
- `:487` `403` — You are not authorized to use the following groups for this user: 
- `:507` `422` — Rate for {$groupName} - {$categoryName} cannot exceed maximum of \$
- `:568` `422` — Validation failed
- `:577` `422` — Validation failed
- `:647` `422` — Validation failed

</details>

### My Network (clients) — `/my-client`

Component: `src/components/MyClient.vue` — **9 APIs**

1. `GET /api/user/ib/clients` → `IbaController@getMyClients`
2. `GET /api/user/ib/get-ib-details/{userSlug}` → `IbaController@getIBDetailsApi`
3. `GET /api/user/ib/stats` → `IbaController@getIBStats`
4. `GET /api/user/ib/sub-ib-stats/{subIBId}` → `IbaController@getSubIBStats`
5. `GET /api/user/ib/sub-ib-structure/{subIBId}` → `IbaController@getSubIBStructure`
6. `GET /api/user/ib/sub-ib-sub-ibs/{subIBId}` → `IbaController@getSubIBSubIBs`
7. `GET /api/user/ib/sub-ibs` → `IbaController@getMySubIBs`
8. `GET /api/user/ib/trade-history` → `IbaController@getTradeHistory`
9. `GET /api/user/ib/tree-structure` → `IbaController@getIBTreeStructure`

<details><summary>Request / response details</summary>

##### `GET /api/user/ib/clients`

- **Frontend:** `myClientService.getMyClients` (`src/services/my-client.service.js:19`)
- **Triggered from:** `loadMyClients`
- **Backend:** `IbaController@getMyClients` — `core/app/Http/Controllers/User/IbaController.php:4385-4393`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`


**Errors** (`success: false`)
- `:4391` `500` — Failed to get clients: 

##### `GET /api/user/ib/get-ib-details/{userSlug}`

- **Frontend:** `myClientService.getIBDetails` (`src/services/my-client.service.js:132`)
- **Triggered from:** `loadIBDetails`
- **Backend:** `IbaController@getIBDetailsApi` — `core/app/Http/Controllers/User/IbaController.php:1841-1902`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:1898`
```json
{
  "status": 200,
  "success": true,
  "message": "IB details retrieved successfully",
  "data": "<$responseData>"
}
```

**Errors** (`success: false`)
- `:1847` `404` — IB not found
- `:1900` `500` — Failed to get IB details: 

##### `GET /api/user/ib/stats`

- **Frontend:** `ibService.getIBStats` (`src/services/ib.service.js:37`)
- **Triggered from:** `loadIBStats`
- **Backend:** `IbaController@getIBStats` — `core/app/Http/Controllers/User/IbaController.php:4213-4263`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:4227`
```json
{
  "status": 200,
  "success": true,
  "message": "IB stats retrieved successfully",
  "data": {
    "available_rebate": "...",
    "total_clients": "...",
    "total_withdrawal": "...",
    "ib_withdrawal_rebate": "...",
    "total_deposited": "...",
    "total_equity": "...",
    "total_rebate_generated": "...",
    "ib_pending_requests": "...",
    "total_lots": "...",
    "margin_level_below_100": "...",
    "reference_links": "...",
    "direct_commission": "...",
    "sub_ib_commission": "...",
    "my_commission": "...",
    "total_commission": "...",
    "commission_this_month": "...",
    "commission_this_quarter": "...",
    "commission_this_year": "...",
    "direct_commission_this_month": "...",
    "sub_ib_commission_this_month": "...",
    "direct_commission_this_quarter": "...",
    "sub_ib_commission_this_quarter": "...",
    "direct_commission_this_year": "...",
    "sub_ib_commission_this_year": "...",
    "my_commission_this_month": "...",
    "my_commission_this_quarter": "...",
    "my_commission_this_year": "..."
  }
}
```

**Errors** (`success: false`)
- `:4261` `500` — Failed to get IB stats: 

##### `GET /api/user/ib/sub-ib-stats/{subIBId}`

- **Frontend:** `myClientService.getSubIBStats` (`src/services/my-client.service.js:149`)
- **Triggered from:** `loadSubIBStats`, `loadSubSubIBStats`
- **Backend:** `IbaController@getSubIBStats` — `core/app/Http/Controllers/User/IbaController.php:4268-4338`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:4303`
```json
{
  "status": 200,
  "success": true,
  "message": "Sub-IB stats retrieved successfully",
  "data": {
    "available_rebate": "...",
    "total_clients": "...",
    "total_withdrawal": "...",
    "ib_withdrawal_rebate": "...",
    "total_deposited": "...",
    "total_equity": "...",
    "total_rebate_generated": "...",
    "ib_pending_requests": "...",
    "total_lots": "...",
    "margin_level_below_100": "...",
    "sub_ib_count": "...",
    "reference_links": "...",
    "direct_commission": "...",
    "sub_ib_commission": "...",
    "my_commission": "...",
    "total_commission": "...",
    "commission_this_month": "...",
    "commission_this_quarter": "...",
    "commission_this_year": "...",
    "direct_commission_this_month": "...",
    "sub_ib_commission_this_month": "...",
    "direct_commission_this_quarter": "...",
    "sub_ib_commission_this_quarter": "...",
    "direct_commission_this_year": "...",
    "sub_ib_commission_this_year": "...",
    "my_commission_this_month": "...",
    "my_commission_this_quarter": "...",
    "my_commission_this_year": "..."
  }
}
```

**Errors** (`success: false`)
- `:4284` `404` — Sub-IB not found or access denied
- `:4336` `500` — Failed to get Sub-IB stats: 

##### `GET /api/user/ib/sub-ib-structure/{subIBId}`

- **Frontend:** `myClientService.getSubIBStructure` (`src/services/my-client.service.js:47`)
- **Triggered from:** `loadSubIBClients`, `loadSubSubIBClients`
- **Backend:** `IbaController@getSubIBStructure` — `core/app/Http/Controllers/User/IbaController.php:4644-4668`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`


**Errors** (`success: false`)
- `:4660` `404` — Sub-IB not found or access denied
- `:4666` `500` — Failed to get Sub IB structure: 

##### `GET /api/user/ib/sub-ib-sub-ibs/{subIBId}`

- **Frontend:** `myClientService.getSubIBSubIBs` (`src/services/my-client.service.js:61`)
- **Triggered from:** `loadSubIBSubIBs`, `loadSubSubIBSubIBs`
- **Backend:** `IbaController@getSubIBSubIBs` — `core/app/Http/Controllers/User/IbaController.php:4721-4745`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`


**Errors** (`success: false`)
- `:4737` `404` — Sub-IB not found or access denied
- `:4743` `500` — Failed to get Sub IB Sub IBs: 

##### `GET /api/user/ib/sub-ibs`

- **Frontend:** `myClientService.getMySubIBs` (`src/services/my-client.service.js:33`)
- **Triggered from:** `loadAllSubIBsForDrawer`, `loadMySubIBs`
- **Backend:** `IbaController@getMySubIBs` — `core/app/Http/Controllers/User/IbaController.php:4578-4586`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`


**Errors** (`success: false`)
- `:4584` `500` — Failed to get Sub IBs: 

##### `GET /api/user/ib/trade-history`

- **Frontend:** `myClientService.getTradeHistory` (`src/services/my-client.service.js:75`), `myClientService.getSubIBTradeHistory` (`src/services/my-client.service.js:166`)
- **Triggered from:** `loadTradeHistory`, `loadSubIBTradeHistory`, `loadSubSubIBTradeHistory`
- **Backend:** `IbaController@getTradeHistory` — `core/app/Http/Controllers/User/IbaController.php:5168-5237`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`


**Errors** (`success: false`)
- `:5189` `404` — Sub-IB not found or access denied
- `:5198` `404` — Client not found or access denied
- `:5235` `500` — Failed to get trade history: 

##### `GET /api/user/ib/tree-structure`

- **Frontend:** `ibService.getTreeStructure` (`src/services/ib.service.js:67`), `myClientService.getIBTreeStructure` (`src/services/my-client.service.js:115`)
- **Triggered from:** `fetchNetworkTree`, `searchNetworkTree`, `loadIBTreeStructure`
- **Backend:** `IbaController@getIBTreeStructure` — `core/app/Http/Controllers/User/IbaController.php:4399-4434`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:4427`
```json
{
  "status": 200,
  "success": true,
  "message": "Tree structure retrieved successfully",
  "data": {
    "tree": "..."
  }
}
```

**Errors** (`success: false`)
- `:4432` `500` — Failed to get tree structure: 

</details>

### Sub IB Approval — `/sub-ib-approval`

Component: `src/components/SubIBApproval.vue` — **3 APIs**

1. `GET /api/user/ib/get-structure-options/{id}` → `IbaController@getIBStructureOptions`
2. `GET /api/user/ib/ib-request-list` → `IbaController@ibRequestListApi`
3. `POST /api/user/ib/update-status/{id}` → `IbaController@updateIBstatus`

<details><summary>Request / response details</summary>

##### `GET /api/user/ib/get-structure-options/{id}`

- **Frontend:** `subIbService.getStructureOptions` (`src/services/sub-ib.service.js:97`)
- **Triggered from:** `openReasonModal`
- **Backend:** `IbaController@getIBStructureOptions` — `core/app/Http/Controllers/User/IbaController.php:2844-2857`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:2852`
```json
{
  "status": 200,
  "success": true,
  "message": "Content rendered successfully",
  "data": {
    "html": "..."
  }
}
```

**Errors** (`success: false`)
- `:2849` — ($result['message'], false, [], $result['code'])
- `:2855` `500` — Failed to get structure options: 

##### `GET /api/user/ib/ib-request-list`

- **Frontend:** `subIbService.getIBRequestList` (`src/services/sub-ib.service.js:87`)
- **Triggered from:** `loadIBRequestList`
- **Backend:** `IbaController@ibRequestListApi` — `core/app/Http/Controllers/User/IbaController.php:3113-3210`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:3206`
```json
{
  "status": 200,
  "success": true,
  "message": "IB requests retrieved successfully",
  "data": "<$formattedData>"
}
```

**Errors** (`success: false`)
- `:3119` `403` — You do not have access to this page
- `:3208` `500` — Failed to get IB requests: 

##### `POST /api/user/ib/update-status/{id}`

- **Frontend:** `subIbService.updateIBStatus` (`src/services/sub-ib.service.js:107`)
- **Triggered from:** `updateStatusWithReason`
- **Backend:** `IbaController@updateIBstatus` — `core/app/Http/Controllers/User/IbaController.php:3263-3459`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/IbaController.php:3454`
```json
{
  "status": 200,
  "success": true,
  "message": "IB status updated successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:3322` `422` — Please select a private group.
- `:3327` `422` — Please select a standard group.
- `:3457` `500` — Failed to update IB status

</details>

### Transfer Commission — `/ib-transfer-create`

Component: `src/components/IBTransferCommission.vue` — **3 APIs**

1. `GET /api/user/ib/transfer/clients/search` → `IbCommissionTransferController@clientsSearchAjax`
2. `GET /api/user/ib/transfer/create` → `IbCommissionTransferController@create`
3. `POST /api/user/ib/transfer/store` → `IbCommissionTransferController@store`

<details><summary>Request / response details</summary>

##### `GET /api/user/ib/transfer/clients/search`

- **Frontend:** `ibTransferService.searchClients` (`src/services/ibTransfer.service.js:12`)
- **Triggered from:** `fetchClients`
- **Backend:** `IbCommissionTransferController@clientsSearchAjax` — `core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:112-122`

**Success**

`core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:116`
```json
{
  "results": "..."
}
```

##### `GET /api/user/ib/transfer/create`

- **Frontend:** `ibTransferService.getTransferCreateInfo` (`src/services/ibTransfer.service.js:6`)
- **Triggered from:** `fetchInfo`
- **Backend:** `IbCommissionTransferController@create` — `core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:47-70`

**Success**

`core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:62`
```json
{
  "success": "...",
  "enabled": "...",
  "available_balance": "...",
  "min_amount": "...",
  "daily_cap": "...",
  "daily_remaining": "..."
}
```

**Errors** (`success: false`)
- `:51` `401` — (['success' => false, 'message' => 'Unauthenticated'], 401)

##### `POST /api/user/ib/transfer/store`

- **Frontend:** `ibTransferService.createTransfer` (`src/services/ibTransfer.service.js:18`)
- **Triggered from:** `handleTransferSubmit`
- **Backend:** `IbCommissionTransferController@store` — `core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:75-107`
- **Request fields (validated):** `to_client_user_id`, `amount`, `comment`

**Success**

`core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:96`
```json
{
  "success": "...",
  "message": "...",
  "transfer": "..."
}
```

**Errors** (`success: false`)
- `:79` `401` — (['success' => false, 'message' => 'Unauthenticated'], 401)
- `:102` `422` — ([ 'success' => false, 'message' => $e->getMessage(), ], 422)

</details>

### Transfer Commission History — `/ib-transfer-history`

Component: `src/components/IBTransferHistory.vue` — **2 APIs**

1. `GET /api/user/ib/transfer/history` → `IbCommissionTransferController@history`
2. `POST /api/user/ib/transfer/{id}/cancel` → `IbCommissionTransferController@cancelOwn`

<details><summary>Request / response details</summary>

##### `GET /api/user/ib/transfer/history`

- **Frontend:** `ibTransferService.getHistory` (`src/services/ibTransfer.service.js:24`)
- **Triggered from:** `fetchHistory`
- **Backend:** `IbCommissionTransferController@history` — `core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:127-153`

**Success**

`core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:149`
```json
{
  "success": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:131` `401` — (['success' => false, 'message' => 'Unauthenticated'], 401)

##### `POST /api/user/ib/transfer/{id}/cancel`

- **Frontend:** `ibTransferService.cancelTransfer` (`src/services/ibTransfer.service.js:30`)
- **Triggered from:** `handleCancel`
- **Backend:** `IbCommissionTransferController@cancelOwn` — `core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:158-177`

**Success**

`core/Modules/IbCommissionTransfer/Http/Controllers/User/IbCommissionTransferController.php:167`
```json
{
  "success": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:162` `401` — (['success' => false, 'message' => 'Unauthenticated'], 401)
- `:172` `422` — ([ 'success' => false, 'message' => $e->getMessage(), ], 422)

</details>

### IB Trade & Win — `/ib/trade-win`

Component: `src/components/TradeWin.vue` — **3 APIs**

1. `GET /api/v1/user/trade-win/products` → `TradeWinApiController@getProducts`
2. `GET /api/v1/user/trade-win/saved-addresses` → `TradeWinApiController@getSavedAddresses`
3. `POST /api/v1/user/trade-win/claim` → `TradeWinApiController@claimProduct`

<details><summary>Request / response details</summary>

##### `GET /api/v1/user/trade-win/products`

- **Frontend:** `tradeWinService.getProducts` (`src/services/tradeWin.service.js:14`)
- **Triggered from:** `refreshLeaderboard`, `fetchProducts`
- **Backend:** `TradeWinApiController@getProducts` — `core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:272-466`
- **Middleware:** `auth:sanctum`, `throttle:api`

**Success**

`core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:449`
```json
{
  "message": "...",
  "status": "...",
  "module_enabled": "...",
  "data": "...",
  "products": "...",
  "stats": "...",
  "leaderboard": "...",
  "symbol_categories": "...",
  "reward_categories": "...",
  "past_wins": "...",
  "audience": "...",
  "availability": "...",
  "availability_counts": "..."
}
```

##### `GET /api/v1/user/trade-win/saved-addresses`

- **Frontend:** `tradeWinService.getSavedAddresses` (`src/services/tradeWin.service.js:49`)
- **Triggered from:** `openRedeemModal`
- **Backend:** `TradeWinApiController@getSavedAddresses` — `core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:805-817`
- **Middleware:** `auth:sanctum`, `throttle:api`

**Success**

`core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:812`
```json
{
  "status": "...",
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:809` `401` — (['status' => false, 'message' => 'User not authenticated.'], 401)

##### `POST /api/v1/user/trade-win/claim`

- **Frontend:** `tradeWinService.claimProduct` (`src/services/tradeWin.service.js:26`)
- **Triggered from:** `handleFinalClaim`
- **Backend:** `TradeWinApiController@claimProduct` — `core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:622-803`
- **Middleware:** `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `product_id`, `quantity`, `shipping_details`, `audience`

**Success**

`core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:795`
```json
{
  "message": "...",
  "status": "...",
  "claim_id": "...",
  "reference_no": "...",
  "shipping_details": "...",
  "saved_addresses": "..."
}
```

**Errors** (`success: false`)
- `:643` `400` — (['message' => 'Insufficient stock', 'status' => false], 400)
- `:648` `400` — ([ 'message' => 'This reward is outside its campaign window', 'status' => false, ], 400)
- `:660` `400` — ([ 'message' => sprintf( 'Deposit requirement not met — $%s more needed', number_format($requiredDeposit - $availableDeposit, 2) ), 'status'
- `:729` `400` — ([ 'message' => "Insufficient {$poolLabel} lot volume balance", 'status' => false, ], 400)

</details>

### IB Demo Contest (list/create/edit/view) — `/ib-contest`

Component: `src/components/IBDemoContest.vue` — **11 APIs**

1. `GET /api/ib/demo-contest/{id}/enrollments` → `DemoContestIbApiController@enrollmentList`
2. `GET /api/ib/demo-contest/instruments` → `DemoContestIbApiController@getInstruments`
3. `GET /api/ib/demo-contest/my-contests` → `DemoContestIbApiController@index`
4. `GET /api/user/demo-contest/{contestId}/leaderboard` → `DemoContestApiController@contestLeaderboard`
5. `GET /api/user/kyc/countries` → `KYCController@getCountries`
6. `POST /api/ib/demo-contest/{id}/add-prize-fund` → `DemoContestIbApiController@addPrizeFund`
7. `POST /api/ib/demo-contest/{id}/cancel` → `DemoContestIbApiController@cancelContest`
8. `POST /api/ib/demo-contest/{id}/update` → `DemoContestIbApiController@update`
9. `POST /api/ib/demo-contest/enrollment/{id}/approve` → `DemoContestIbApiController@approveEnrollment`
10. `POST /api/ib/demo-contest/enrollment/{id}/reject` → `DemoContestIbApiController@rejectEnrollment`
11. `POST /api/ib/demo-contest/store` → `DemoContestIbApiController@store`

<details><summary>Request / response details</summary>

##### `GET /api/ib/demo-contest/{id}/enrollments`

- **Frontend:** `demoContestService.ibGetEnrollments` (`src/services/demoContest.service.js:249`)
- **Triggered from:** `loadEnrollments`
- **Backend:** `DemoContestIbApiController@enrollmentList` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:253-276`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:275`
```json
{
  "status": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:260` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `GET /api/ib/demo-contest/instruments`

- **Frontend:** `demoContestService.ibGetInstruments` (`src/services/demoContest.service.js:220`)
- **Triggered from:** `loadInstruments`
- **Backend:** `DemoContestIbApiController@getInstruments` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:463-475`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:468`
```json
{
  "status": "...",
  "data": "...",
  "categories": "...",
  "symbols": "..."
}
```

##### `GET /api/ib/demo-contest/my-contests`

- **Frontend:** `demoContestService.ibGetMyContests` (`src/services/demoContest.service.js:209`)
- **Triggered from:** `fetchContests`
- **Backend:** `DemoContestIbApiController@index` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:23-46`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:45`
```json
{
  "status": "...",
  "data": "..."
}
```

##### `GET /api/user/demo-contest/{contestId}/leaderboard`

- **Frontend:** `demoContestService.getContestLeaderboard` (`src/services/demoContest.service.js:167`)
- **Triggered from:** `fetchLeaderboard`
- **Backend:** `DemoContestApiController@contestLeaderboard` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:502-527`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:522`
```json
{
  "status": "...",
  "type": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:506` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `GET /api/user/kyc/countries`

- **Frontend:** `kycService.getCountries` (`src/services/kyc.service.js:307`)
- **Triggered from:** `loadCountries`
- **Backend:** `KYCController@getCountries` — `core/app/Http/Controllers/User/KYCController.php:272-288`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:278`
```json
{
  "status": 200,
  "success": true,
  "message": "Countries retrieved successfully",
  "data": "<$countries>"
}
```

**Errors** (`success: false`)
- `:284` `500` — An error occurred while fetching countries.
- `:286` `500` — Failed to fetch countries

##### `POST /api/ib/demo-contest/{id}/add-prize-fund`

- **Frontend:** `demoContestService.ibAddPrizeFund` (`src/services/demoContest.service.js:285`)
- **Triggered from:** `submitAddFund`
- **Backend:** `DemoContestIbApiController@addPrizeFund` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:380-403`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `amount`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:395`
```json
{
  "status": "...",
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:389` `404` — (['status' => false, 'message' => 'Contest not found'], 404)
- `:401` `500` — (['status' => false, 'message' => $e->getMessage()], 500)

##### `POST /api/ib/demo-contest/{id}/cancel`

- **Frontend:** `demoContestService.ibCancelContest` (`src/services/demoContest.service.js:276`)
- **Triggered from:** `submitCancelContest`
- **Backend:** `DemoContestIbApiController@cancelContest` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:346-375`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:371`
```json
{
  "status": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:353` `404` — (['status' => false, 'message' => 'Contest not found'], 404)
- `:357` `422` — ([ 'status' => false, 'message' => 'Contest cannot be cancelled within 24 hours of its start date.', ], 422)
- `:373` `500` — (['status' => false, 'message' => $e->getMessage()], 500)

##### `POST /api/ib/demo-contest/{id}/update`

- **Frontend:** `demoContestService.ibUpdateContest` (`src/services/demoContest.service.js:240`)
- **Triggered from:** `submitCreate`
- **Backend:** `DemoContestIbApiController@update` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:178-248`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:247`
```json
{
  "status": "...",
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:185` `404` — (['status' => false, 'message' => 'Contest not found'], 404)
- `:188` `422` — (['status' => false, 'message' => 'Cannot edit a contest that has already been approved or rejected.'], 422)

##### `POST /api/ib/demo-contest/enrollment/{id}/approve`

- **Frontend:** `demoContestService.ibApproveEnrollment` (`src/services/demoContest.service.js:258`)
- **Triggered from:** `approveEnroll`
- **Backend:** `DemoContestIbApiController@approveEnrollment` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:281-312`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:308`
```json
{
  "status": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:285` `404` — (['status' => false, 'message' => 'Participant not found'], 404)
- `:290` `403` — (['status' => false, 'message' => 'Unauthorized'], 403)
- `:294` `400` — (['status' => false, 'message' => 'Enrollment is not in pending state'], 400)
- `:300` `400` — (['status' => false, 'message' => $result['message']], 400)
- `:310` `500` — (['status' => false, 'message' => $e->getMessage()], 500)

##### `POST /api/ib/demo-contest/enrollment/{id}/reject`

- **Frontend:** `demoContestService.ibRejectEnrollment` (`src/services/demoContest.service.js:267`)
- **Triggered from:** `rejectEnroll`
- **Backend:** `DemoContestIbApiController@rejectEnrollment` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:317-341`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:337`
```json
{
  "status": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:321` `404` — (['status' => false, 'message' => 'Participant not found'], 404)
- `:325` `403` — (['status' => false, 'message' => 'Unauthorized'], 403)
- `:339` `500` — (['status' => false, 'message' => $e->getMessage()], 500)

##### `POST /api/ib/demo-contest/store`

- **Frontend:** `demoContestService.ibCreateContest` (`src/services/demoContest.service.js:231`)
- **Triggered from:** `submitCreate`
- **Backend:** `DemoContestIbApiController@store` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:51-173`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `name`, `tagline`, `start_date`, `end_date`, `registration_closes`, `starting_balance`, `min_participants`, `max_participants`, `ranking_by`, `timezone`, `enrollment_type`, `enrollment_fee`, `enrollment_start_date`, `enrollment_end_date`, `contest_start_date`, `contest_end_date`, `allow_multiple_contests`, `max_participations_per_user`, `prize_pool_type`, `ib_admin_share_percent`, `enrollment_steps_enabled`, `auto_disqualify_on_violation`, `terms_enabled`, `terms_content`, `prizes`, `enrollment_steps`, `instruments`, `trading_platform`, `mt5_group_id`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestIbApiController.php:164`
```json
{
  "status": "...",
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:171` `500` — (['status' => false, 'message' => $e->getMessage()], 500)

</details>

---

## IB Manager Portal

> Shown instead of the classic IB menu when the IB Manager module is on. Single route /ib-manager-portal/:section rendered by IBManagerPortal.vue (v-if chain :36-115). Section list: ibmanager-portal/sections.js IBM_SECTIONS.

### Portal shell (common calls) — `/ib-manager-portal`

Component: `src/components/ibmanager-portal/IBManagerPortal.vue` — **1 APIs**

1. `GET /api/ibm/portal/dashboard` → `DashboardController@index`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/dashboard`

- **Frontend:** `ibmgrDashboardApi.stats` (`src/components/ibmanager-portal/ibmanagerApi.js:259`)
- **Triggered from:** `changeSection`, `loadStats`
- **Backend:** `DashboardController@index` — `core/Modules/IBManager/Http/Controllers/Portal/DashboardController.php:32-51`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/DashboardController.php:50`
```json
{
  "success": true,
  "message": "...",
  "data": "<Cache::remember($key, self::CACHE_TTL, fn (): array => $this->overview($ibUserId>"
}
```

</details>

### Dashboard — `/ib-manager-portal`

Component: `src/components/ibmanager-portal/sections/IBMgrDashboard.vue` — **3 APIs**

1. `GET /api/ibm/portal/dashboard` → `DashboardController@index`
2. `GET /api/ibm/portal/dashboard/activity` → `DashboardController@activity`
3. `GET /api/ibm/portal/network` → `NetworkController@index`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/dashboard`

- **Frontend:** `ibmgrDashboardApi.stats` (`src/components/ibmanager-portal/ibmanagerApi.js:259`)
- **Triggered from:** `loadStats`
- **Backend:** `DashboardController@index` — `core/Modules/IBManager/Http/Controllers/Portal/DashboardController.php:32-51`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/DashboardController.php:50`
```json
{
  "success": true,
  "message": "...",
  "data": "<Cache::remember($key, self::CACHE_TTL, fn (): array => $this->overview($ibUserId>"
}
```

##### `GET /api/ibm/portal/dashboard/activity`

- **Frontend:** `ibmgrDashboardApi.activity` (`src/components/ibmanager-portal/ibmanagerApi.js:262`)
- **Triggered from:** `loadStats`
- **Backend:** `DashboardController@activity` — `core/Modules/IBManager/Http/Controllers/Portal/DashboardController.php:436-473`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/DashboardController.php:472`
```json
{
  "success": true,
  "message": "...",
  "data": "<$groups>"
}
```

##### `GET /api/ibm/portal/network`

- **Frontend:** `ibmgrStructureApi.network` (`src/components/ibmanager-portal/ibmanagerApi.js:154`)
- **Triggered from:** `loadStats`
- **Backend:** `NetworkController@index` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:22-136`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:120`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "parent_id": "...",
    "equity_as_of": "...",
    "rows": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

</details>

### My Clients — `/ib-manager-portal/clients`

Component: `src/components/ibmanager-portal/sections/IBMgrClients.vue` — **6 APIs**

1. `GET /api/ibm/portal/clients` → `ClientController@index`
2. `GET /api/ibm/portal/clients/network-tree` → `ClientController@networkTree`
3. `GET /api/ibm/portal/network/{id}` → `NetworkController@show`
4. `GET /api/ibm/portal/network/{id}/node` → `NetworkController@node`
5. `GET /api/ibm/portal/network/{id}/wallet` → `NetworkController@wallet`
6. `GET /api/ibm/portal/network/tree-summary` → `NetworkController@treeSummary`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/clients`

- **Frontend:** `ibmgrClientsApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:59`)
- **Triggered from:** `loadDirect`, `loadNetwork`, `runSearch`, `exportCsv`
- **Backend:** `ClientController@index` — `core/Modules/IBManager/Http/Controllers/Portal/ClientController.php:25-256`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ClientController.php:235`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "scope": "...",
    "summary": "...",
    "partners": "...",
    "links": "...",
    "rows": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

##### `GET /api/ibm/portal/clients/network-tree`

- **Frontend:** `ibmgrClientsApi.networkTree` (`src/components/ibmanager-portal/ibmanagerApi.js:62`)
- **Triggered from:** `loadNetwork`
- **Backend:** `ClientController@networkTree` — `core/Modules/IBManager/Http/Controllers/Portal/ClientController.php:483-566`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ClientController.php:558`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "nodes": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}`

- **Frontend:** `ibmgrStructureApi.partner` (`src/components/ibmanager-portal/ibmanagerApi.js:158`)
- **Triggered from:** `loadPicked`
- **Backend:** `NetworkController@show` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:743-830`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:793`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "upline": "...",
    "partner": "...",
    "partner_user_id": "...",
    "name": "...",
    "email": "...",
    "arrived_via": "...",
    "status": "...",
    "depth": "...",
    "partner_since": "...",
    "sub_partners": "...",
    "equity_as_of": "...",
    "clients": "...",
    "own": "...",
    "branch": "...",
    "active": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}/node`

- **Frontend:** `ibmgrStructureApi.node` (`src/components/ibmanager-portal/ibmanagerApi.js:161`)
- **Triggered from:** `load`
- **Backend:** `NetworkController@node` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:238-360`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:298`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "ib_user_id": "...",
    "client_total": "...",
    "client_shown": "...",
    "people": "...",
    "deposits": "...",
    "withdrawals": "...",
    "equity": "...",
    "commission": "...",
    "accounts": "...",
    "names": "...",
    "emails": "...",
    "profiles": "...",
    "plans": "...",
    "grandChildren": "...",
    "viaLinks": "...",
    "depth": "...",
    "subtreeIdsByChild": "...",
    "branchAssignments": "...",
    "clients": "...",
    "client_user_id": "...",
    "name": "...",
    "email": "...",
    "first_account": "...",
    "balance": "...",
    "is_direct": "...",
    "currencies": "...",
    "sub_ibs": "...",
    "referral_code": "...",
    "plan_name": "...",
    "status": "...",
    "level": "...",
    "clients_tree": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}/wallet`

- **Frontend:** `ibmgrStructureApi.partnerWallet` (`src/components/ibmanager-portal/ibmanagerApi.js:164`)
- **Triggered from:** `loadPicked`
- **Backend:** `NetworkController@wallet` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:149-190`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:171`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "partner_user_id": "...",
    "wallets": "...",
    "currency": "...",
    "available": "...",
    "pending_payout": "...",
    "lifetime_earned": "...",
    "lifetime_paid": "...",
    "is_frozen": "...",
    "payouts": "...",
    "id": "...",
    "amount": "...",
    "status": "...",
    "requested_at": "...",
    "paid_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:157` `422` — Use your own wallet for this.

##### `GET /api/ibm/portal/network/tree-summary`

- **Frontend:** `ibmgrStructureApi.treeSummary` (`src/components/ibmanager-portal/ibmanagerApi.js:160`)
- **Triggered from:** `loadNetwork`
- **Backend:** `NetworkController@treeSummary` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:475-494`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:482`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "ib_user_id": "...",
    "name": "...",
    "direct": "...",
    "total": "...",
    "clients": "..."
  }
}
```

</details>

### Person detail (client / sub-IB) — `/ib-manager-portal/people/:personId`

Component: `src/components/ibmanager-portal/sections/IBMgrPerson.vue` — **11 APIs**

1. `GET /api/ibm/portal/clients/{id}` → `ClientController@show`
2. `GET /api/ibm/portal/network/{id}` → `NetworkController@show`
3. `GET /api/ibm/portal/network/{id}/links` → `NetworkController@links`
4. `GET /api/ibm/portal/network/{id}/node` → `NetworkController@node`
5. `GET /api/ibm/portal/network/{id}/plan` → `PlanController@partnerPlan`
6. `GET /api/ibm/portal/network/{id}/symbols` → `NetworkController@symbols`
7. `GET /api/ibm/portal/network/{id}/wallet` → `NetworkController@wallet`
8. `GET /api/ibm/portal/network/tree-summary` → `NetworkController@treeSummary`
9. `GET /api/ibm/portal/partner-plans` → `PartnerPlanController@index`
10. `GET /api/ibm/portal/wallet` → `WalletController@index`
11. `POST /api/ibm/portal/partner-plans/{id}/assign` → `PartnerPlanController@assignToPlan`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/clients/{id}`

- **Frontend:** `ibmgrClientsApi.show` (`src/components/ibmanager-portal/ibmanagerApi.js:60`)
- **Triggered from:** `load`
- **Backend:** `ClientController@show` — `core/Modules/IBManager/Http/Controllers/Portal/ClientController.php:846-925`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ClientController.php:875`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "client": "...",
    "client_user_id": "...",
    "name": "...",
    "email": "...",
    "email_masked": "...",
    "registered_at": "...",
    "joined_at": "...",
    "last_login_at": "...",
    "last_deposit_at": "...",
    "last_withdrawal_at": "...",
    "is_direct": "...",
    "via_link": "...",
    "via_link_code": "...",
    "via_link_is_mine": "...",
    "via_link_owner": "...",
    "joined_via_at": "...",
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "equity_as_of": "...",
    "upline": "...",
    "history": "...",
    "events": "...",
    "last_trade_at": "...",
    "last_rebate_at": "...",
    "symbols": "...",
    "idle_days": "...",
    "totals": "...",
    "accounts": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}`

- **Frontend:** `ibmgrStructureApi.partner` (`src/components/ibmanager-portal/ibmanagerApi.js:158`)
- **Triggered from:** `load`
- **Backend:** `NetworkController@show` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:743-830`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:793`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "upline": "...",
    "partner": "...",
    "partner_user_id": "...",
    "name": "...",
    "email": "...",
    "arrived_via": "...",
    "status": "...",
    "depth": "...",
    "partner_since": "...",
    "sub_partners": "...",
    "equity_as_of": "...",
    "clients": "...",
    "own": "...",
    "branch": "...",
    "active": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}/links`

- **Frontend:** `ibmgrStructureApi.partnerLinks` (`src/components/ibmanager-portal/ibmanagerApi.js:168`)
- **Triggered from:** `load`
- **Backend:** `NetworkController@links` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:1216-1261`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:1229`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "links": "..."
  }
}
```
`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:1249`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "links": "...",
    "link_id": "...",
    "code": "...",
    "label": "...",
    "is_default_link": "...",
    "is_active": "...",
    "created_at": "...",
    "signups": "...",
    "funded": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}/node`

- **Frontend:** `ibmgrStructureApi.node` (`src/components/ibmanager-portal/ibmanagerApi.js:161`)
- **Triggered from:** `load`
- **Backend:** `NetworkController@node` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:238-360`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:298`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "ib_user_id": "...",
    "client_total": "...",
    "client_shown": "...",
    "people": "...",
    "deposits": "...",
    "withdrawals": "...",
    "equity": "...",
    "commission": "...",
    "accounts": "...",
    "names": "...",
    "emails": "...",
    "profiles": "...",
    "plans": "...",
    "grandChildren": "...",
    "viaLinks": "...",
    "depth": "...",
    "subtreeIdsByChild": "...",
    "branchAssignments": "...",
    "clients": "...",
    "client_user_id": "...",
    "name": "...",
    "email": "...",
    "first_account": "...",
    "balance": "...",
    "is_direct": "...",
    "currencies": "...",
    "sub_ibs": "...",
    "referral_code": "...",
    "plan_name": "...",
    "status": "...",
    "level": "...",
    "clients_tree": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}/plan`

- **Frontend:** `ibmgrStructureApi.partnerPlan` (`src/components/ibmanager-portal/ibmanagerApi.js:166`)
- **Triggered from:** `loadPlan`
- **Backend:** `PlanController@partnerPlan` — `core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:38-77`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:55`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan": "...",
    "groups": "...",
    "assigned_at": "...",
    "assigned_by_you": "...",
    "is_yours": "..."
  }
}
```
`core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:69`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan_id": "...",
    "assigned_at": "...",
    "assigned_by_you": "...",
    "is_yours": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}/symbols`

- **Frontend:** `ibmgrStructureApi.partnerSymbols` (`src/components/ibmanager-portal/ibmanagerApi.js:170`)
- **Triggered from:** `loadSymbols`
- **Backend:** `NetworkController@symbols` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:1271-1342`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:1302`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "rows": "...",
    "totals": "..."
  }
}
```

##### `GET /api/ibm/portal/network/{id}/wallet`

- **Frontend:** `ibmgrStructureApi.partnerWallet` (`src/components/ibmanager-portal/ibmanagerApi.js:164`)
- **Triggered from:** `load`
- **Backend:** `NetworkController@wallet` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:149-190`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:171`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "partner_user_id": "...",
    "wallets": "...",
    "currency": "...",
    "available": "...",
    "pending_payout": "...",
    "lifetime_earned": "...",
    "lifetime_paid": "...",
    "is_frozen": "...",
    "payouts": "...",
    "id": "...",
    "amount": "...",
    "status": "...",
    "requested_at": "...",
    "paid_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:157` `422` — Use your own wallet for this.

##### `GET /api/ibm/portal/network/tree-summary`

- **Frontend:** `ibmgrStructureApi.treeSummary` (`src/components/ibmanager-portal/ibmanagerApi.js:160`)
- **Triggered from:** `load`
- **Backend:** `NetworkController@treeSummary` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:475-494`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:482`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "ib_user_id": "...",
    "name": "...",
    "direct": "...",
    "total": "...",
    "clients": "..."
  }
}
```

##### `GET /api/ibm/portal/partner-plans`

- **Frontend:** `ibmgrPartnerPlansApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:190`)
- **Triggered from:** `openPlanPicker`
- **Backend:** `PartnerPlanController@index` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:42-69`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:59`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plans": "...",
    "plan_id": "...",
    "name": "...",
    "description": "...",
    "is_active": "...",
    "partners_using": "...",
    "created_at": "..."
  }
}
```

##### `GET /api/ibm/portal/wallet`

- **Frontend:** `ibmgrWalletApi.asPartner` (`src/components/ibmanager-portal/ibmanagerApi.js:223`)
- **Triggered from:** `load`
- **Backend:** `WalletController@index` — `core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:47-100`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:61`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "minimum_payout_by_currency": "...",
    "methods": "...",
    "payouts": "...",
    "id": "...",
    "currency": "...",
    "amount": "...",
    "status": "...",
    "method_name": "...",
    "beneficiary_label": "...",
    "requested_at": "...",
    "paid_at": "...",
    "payment_reference": "...",
    "rejection_reason": "...",
    "raised_by_broker": "...",
    "wallets": "...",
    "balance": "...",
    "pending_payout": "...",
    "lifetime_earned": "...",
    "lifetime_paid": "...",
    "is_frozen": "...",
    "can_withdraw": "...",
    "open_payout_status": "...",
    "minimum_payout": "..."
  }
}
```

##### `POST /api/ibm/portal/partner-plans/{id}/assign`

- **Frontend:** `ibmgrPartnerPlansApi.assign` (`src/components/ibmanager-portal/ibmanagerApi.js:203`)
- **Triggered from:** `savePlanChange`
- **Backend:** `PartnerPlanController@assignToPlan` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:407-483`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `ib_user_id`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:479`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan_id": "...",
    "plan_name": "..."
  }
}
```

**Errors** (`success: false`)
- `:425` `403` — That user is not your direct sub-IB.
- `:434` `422` — This plan is no longer within the limits of your own plan.
- `:445` `422` — They are already on that plan.

</details>

### Sub-IB Requests — `/ib-manager-portal/requests`

Component: `src/components/ibmanager-portal/sections/IBMgrRequests.vue` — **4 APIs**

1. `GET /api/ibm/portal/partner-plans` → `PartnerPlanController@index`
2. `GET /api/ibm/portal/requests` → `PartnerRequestController@index`
3. `POST /api/ibm/portal/requests/{requestId}/approve` → `PartnerRequestController@approve`
4. `POST /api/ibm/portal/requests/{requestId}/reject` → `PartnerRequestController@reject`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/partner-plans`

- **Frontend:** `ibmgrPartnerPlansApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:190`)
- **Triggered from:** `loadPlans`
- **Backend:** `PartnerPlanController@index` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:42-69`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:59`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plans": "...",
    "plan_id": "...",
    "name": "...",
    "description": "...",
    "is_active": "...",
    "partners_using": "...",
    "created_at": "..."
  }
}
```

##### `GET /api/ibm/portal/requests`

- **Frontend:** `ibmgrRequestsApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:176`)
- **Triggered from:** `load`
- **Backend:** `PartnerRequestController@index` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerRequestController.php:41-85`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerRequestController.php:60`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "status": "...",
    "requests": "...",
    "request_id": "...",
    "user_id": "...",
    "name": "...",
    "email": "...",
    "message": "...",
    "plan_id": "...",
    "rejection_reason": "...",
    "origin": "...",
    "requested_at": "...",
    "ib_approved_at": "...",
    "reviewed_at": "..."
  }
}
```

##### `POST /api/ibm/portal/requests/{requestId}/approve`

- **Frontend:** `ibmgrRequestsApi.approve` (`src/components/ibmanager-portal/ibmanagerApi.js:178`)
- **Triggered from:** `doApprove`
- **Backend:** `PartnerRequestController@approve` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerRequestController.php:87-207`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `plan_id`, `plan_group_ids`, `plan_group_ids.*`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerRequestController.php:149`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "request_id": "...",
    "user_id": "...",
    "awaiting_admin": "..."
  }
}
```
`core/Modules/IBManager/Http/Controllers/Portal/PartnerRequestController.php:201`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "request_id": "...",
    "user_id": "...",
    "plan_id": "...",
    "plan_group_ids": "..."
  }
}
```

**Errors** (`success: false`)
- `:93` `422` — This request has already been decided.
- `:115` `422` — This plan is no longer within the limits of your own plan.

##### `POST /api/ibm/portal/requests/{requestId}/reject`

- **Frontend:** `ibmgrRequestsApi.reject` (`src/components/ibmanager-portal/ibmanagerApi.js:183`)
- **Triggered from:** `doReject`
- **Backend:** `PartnerRequestController@reject` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerRequestController.php:209-241`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `reason`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerRequestController.php:237`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "request_id": "...",
    "user_id": "..."
  }
}
```

**Errors** (`success: false`)
- `:215` `422` — This request has already been decided.

</details>

### Sub-IB Performance (from dashboard "View all") — `/ib-manager-portal/sub-ibs`

Component: `src/components/ibmanager-portal/sections/IBMgrSubIbs.vue` — **1 APIs**

1. `GET /api/ibm/portal/network/performance` → `NetworkController@performance`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/network/performance`

- **Frontend:** `ibmgrStructureApi.performance` (`src/components/ibmanager-portal/ibmanagerApi.js:156`)
- **Triggered from:** `load`
- **Backend:** `NetworkController@performance` — `core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:1039-1207`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:1076`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "rows": "...",
    "totals": "...",
    "currency": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```
`core/Modules/IBManager/Http/Controllers/Portal/NetworkController.php:1191`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "period": "...",
    "key": "...",
    "from": "...",
    "to": "...",
    "currency": "...",
    "equity_as_of": "...",
    "sort": "...",
    "dir": "...",
    "totals": "...",
    "rows": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

</details>

### Commission Plans — `/ib-manager-portal/plans`

Component: `src/components/ibmanager-portal/sections/IBMgrPlans.vue` — **9 APIs**

1. `DELETE /api/ibm/portal/partner-plans/{id}` → `PartnerPlanController@destroy`
2. `GET /api/ibm/portal/partner-plans` → `PartnerPlanController@index`
3. `GET /api/ibm/portal/partner-plans/{id}` → `PartnerPlanController@show`
4. `GET /api/ibm/portal/partner-plans/sub-ibs` → `PartnerPlanController@subIbs`
5. `GET /api/ibm/portal/partner-plans/template` → `PartnerPlanController@template`
6. `PATCH /api/ibm/portal/partner-plans/{id}/rename` → `PartnerPlanController@rename`
7. `POST /api/ibm/portal/partner-plans` → `PartnerPlanController@store`
8. `POST /api/ibm/portal/partner-plans/{id}/assign` → `PartnerPlanController@assignToPlan`
9. `PUT /api/ibm/portal/partner-plans/{id}` → `PartnerPlanController@update`

<details><summary>Request / response details</summary>

##### `DELETE /api/ibm/portal/partner-plans/{id}`

- **Frontend:** `ibmgrPartnerPlansApi.destroy` (`src/components/ibmanager-portal/ibmanagerApi.js:198`)
- **Triggered from:** `doDelete`
- **Backend:** `PartnerPlanController@destroy` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:335-355`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:354`
```json
{
  "success": true,
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:346` `422` — Cannot delete: {$activeAssignments} sub-IB(s) are currently assigned to this plan. Reassign them first.

##### `GET /api/ibm/portal/partner-plans`

- **Frontend:** `ibmgrPartnerPlansApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:190`)
- **Triggered from:** `load`
- **Backend:** `PartnerPlanController@index` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:42-69`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:59`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plans": "...",
    "plan_id": "...",
    "name": "...",
    "description": "...",
    "is_active": "...",
    "partners_using": "...",
    "created_at": "..."
  }
}
```

##### `GET /api/ibm/portal/partner-plans/{id}`

- **Frontend:** `ibmgrPartnerPlansApi.show` (`src/components/ibmanager-portal/ibmanagerApi.js:191`)
- **Triggered from:** `loadTemplate`
- **Backend:** `PartnerPlanController@show` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:99-124`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:111`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan": "...",
    "plan_id": "...",
    "name": "...",
    "description": "...",
    "is_active": "...",
    "partners_using": "...",
    "is_locked": "...",
    "draft": "...",
    "caps": "...",
    "symbol_catalogue": "..."
  }
}
```

##### `GET /api/ibm/portal/partner-plans/sub-ibs`

- **Frontend:** `ibmgrPartnerPlansApi.subIbs` (`src/components/ibmanager-portal/ibmanagerApi.js:205`)
- **Triggered from:** `loadSubIbs`
- **Backend:** `PartnerPlanController@subIbs` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:364-405`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:394`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "sub_ibs": "...",
    "id": "...",
    "name": "...",
    "email": "...",
    "total": "...",
    "shown": "..."
  }
}
```

##### `GET /api/ibm/portal/partner-plans/template`

- **Frontend:** `ibmgrPartnerPlansApi.template` (`src/components/ibmanager-portal/ibmanagerApi.js:192`)
- **Triggered from:** `loadTemplate`
- **Backend:** `PartnerPlanController@template` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:75-97`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:92`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "draft": "...",
    "caps": "...",
    "symbol_catalogue": "..."
  }
}
```

##### `PATCH /api/ibm/portal/partner-plans/{id}/rename`

- **Frontend:** `ibmgrPartnerPlansApi.rename` (`src/components/ibmanager-portal/ibmanagerApi.js:197`)
- **Triggered from:** `doRename`
- **Backend:** `PartnerPlanController@rename` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:310-333`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `plan_name`, `description`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:328`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan_id": "...",
    "name": "...",
    "description": "..."
  }
}
```

##### `POST /api/ibm/portal/partner-plans`

- **Frontend:** `ibmgrPartnerPlansApi.store` (`src/components/ibmanager-portal/ibmanagerApi.js:193`)
- **Triggered from:** `savePlan`
- **Backend:** `PartnerPlanController@store` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:126-166`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `plan_name`, `description`, `groups`, `groups.*.group_id`, `groups.*.rates`, `groups.*.symbol_rates`, `groups.*.blocked_symbol_ids`, `groups.*.blocked_symbol_names`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:162`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan_id": "...",
    "caps": "..."
  }
}
```

##### `POST /api/ibm/portal/partner-plans/{id}/assign`

- **Frontend:** `ibmgrPartnerPlansApi.assign` (`src/components/ibmanager-portal/ibmanagerApi.js:203`)
- **Triggered from:** `doAssign`
- **Backend:** `PartnerPlanController@assignToPlan` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:407-483`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `ib_user_id`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:479`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan_id": "...",
    "plan_name": "..."
  }
}
```

**Errors** (`success: false`)
- `:425` `403` — That user is not your direct sub-IB.
- `:434` `422` — This plan is no longer within the limits of your own plan.
- `:445` `422` — They are already on that plan.

##### `PUT /api/ibm/portal/partner-plans/{id}`

- **Frontend:** `ibmgrPartnerPlansApi.update` (`src/components/ibmanager-portal/ibmanagerApi.js:194`)
- **Triggered from:** `savePlan`
- **Backend:** `PartnerPlanController@update` — `core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:168-300`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `plan_name`, `description`, `is_active`, `groups`, `groups.*.group_id`, `groups.*.rates`, `groups.*.symbol_rates`, `groups.*.blocked_symbol_ids`, `groups.*.blocked_symbol_names`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PartnerPlanController.php:296`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan_id": "...",
    "caps": "..."
  }
}
```

**Errors** (`success: false`)
- `:184` `422` — ( "Cannot edit: {$activeAssignments} sub-IB(s) are assigned to this plan. Create a new plan and reassign them, or ask the broker to make the

</details>

### My Commission — `/ib-manager-portal/commission`

Component: `src/components/ibmanager-portal/sections/IBMgrCommission.vue` — **11 APIs**

1. `DELETE /api/ibm/portal/commission-distributions/{id}` → `CommissionDistributionController@cancel`
2. `GET /api/ibm/portal/commission-distributions` → `CommissionDistributionController@history`
3. `GET /api/ibm/portal/commission-distributions/create` → `CommissionDistributionController@create`
4. `GET /api/ibm/portal/exports/{id}` → `ExportController@show`
5. `GET /api/ibm/portal/exports/{id}/download` → `ExportController@download`
6. `GET /api/ibm/portal/plan` → `PlanController@show`
7. `GET /api/ibm/portal/wallet` → `WalletController@index`
8. `GET /api/ibm/portal/wallet/transactions` → `WalletController@transactions`
9. `POST /api/ibm/portal/commission-distributions` → `CommissionDistributionController@store`
10. `POST /api/ibm/portal/exports` → `ExportController@store`
11. `POST /api/ibm/portal/wallet/withdraw` → `WalletController@withdraw`

<details><summary>Request / response details</summary>

##### `DELETE /api/ibm/portal/commission-distributions/{id}`

- **Frontend:** `ibmgrDistributionApi.cancel` (`src/components/ibmanager-portal/ibmanagerApi.js:250`)
- **Triggered from:** `cancelDistribution`
- **Backend:** `CommissionDistributionController@cancel` — `core/Modules/IBManager/Http/Controllers/Portal/CommissionDistributionController.php:160-180`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/CommissionDistributionController.php:179`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "distribution_id": "..."
  }
}
```

**Errors** (`success: false`)
- `:170` `404` — Request not found.
- `:176` `422` — ($e->getMessage(), 422)

##### `GET /api/ibm/portal/commission-distributions`

- **Frontend:** `ibmgrDistributionApi.history` (`src/components/ibmanager-portal/ibmanagerApi.js:249`)
- **Triggered from:** `loadDistHistory`
- **Backend:** `CommissionDistributionController@history` — `core/Modules/IBManager/Http/Controllers/Portal/CommissionDistributionController.php:117-152`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/CommissionDistributionController.php:132`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "rows": "...",
    "id": "...",
    "client_email": "...",
    "client_name": "...",
    "currency": "...",
    "amount": "...",
    "status": "...",
    "comment": "...",
    "rejection_reason": "...",
    "requested_at": "...",
    "reviewed_at": "...",
    "pagination": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "..."
  }
}
```

##### `GET /api/ibm/portal/commission-distributions/create`

- **Frontend:** `ibmgrDistributionApi.create` (`src/components/ibmanager-portal/ibmanagerApi.js:244`)
- **Triggered from:** `loadDistribution`
- **Backend:** `CommissionDistributionController@create` — `core/Modules/IBManager/Http/Controllers/Portal/CommissionDistributionController.php:35-52`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/CommissionDistributionController.php:44`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "enabled": "...",
    "currency": "...",
    "balance": "...",
    "is_frozen": "...",
    "min_amount": "...",
    "max_amount": "..."
  }
}
```

##### `GET /api/ibm/portal/exports/{id}`

- **Frontend:** `ibmgrExportsApi.show` (`src/components/ibmanager-portal/ibmanagerApi.js:134`)
- **Triggered from:** `setTimeout`
- **Backend:** `ExportController@show` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:107-116`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:115`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "export": "..."
  }
}
```

**Errors** (`success: false`)
- `:112` `404` — Report not found.

##### `GET /api/ibm/portal/exports/{id}/download`

- **Frontend:** `ibmgrExportsApi.download` (`src/components/ibmanager-portal/ibmanagerApi.js:138`)
- **Triggered from:** `setTimeout`
- **Backend:** `ExportController@download` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:121-189`
- **Middleware:** `auth:sanctum`, `ibm.auth`


**Errors** (`success: false`)
- `:126` `404` — Report not found.
- `:132` `410` — This report is no longer available for download.
- `:145` `410` — This report is no longer available for download.
- `:154` `410` — This report is no longer available for download.

##### `GET /api/ibm/portal/plan`

- **Frontend:** `ibmgrCommissionApi.myPlan` (`src/components/ibmanager-portal/ibmanagerApi.js:104`)
- **Triggered from:** `loadRates`
- **Backend:** `PlanController@show` — `core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:24-29`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:28`
```json
{
  "success": true,
  "message": "...",
  "data": "<$this->present($this->guard->requireAssignedPlanId($ibUserId))>"
}
```

##### `GET /api/ibm/portal/wallet`

- **Frontend:** `ibmgrWalletApi.get` (`src/components/ibmanager-portal/ibmanagerApi.js:218`)
- **Triggered from:** `loadWallet`
- **Backend:** `WalletController@index` — `core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:47-100`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:61`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "minimum_payout_by_currency": "...",
    "methods": "...",
    "payouts": "...",
    "id": "...",
    "currency": "...",
    "amount": "...",
    "status": "...",
    "method_name": "...",
    "beneficiary_label": "...",
    "requested_at": "...",
    "paid_at": "...",
    "payment_reference": "...",
    "rejection_reason": "...",
    "raised_by_broker": "...",
    "wallets": "...",
    "balance": "...",
    "pending_payout": "...",
    "lifetime_earned": "...",
    "lifetime_paid": "...",
    "is_frozen": "...",
    "can_withdraw": "...",
    "open_payout_status": "...",
    "minimum_payout": "..."
  }
}
```

##### `GET /api/ibm/portal/wallet/transactions`

- **Frontend:** `ibmgrCommissionApi.ledger` (`src/components/ibmanager-portal/ibmanagerApi.js:103`)
- **Triggered from:** `loadLedger`
- **Backend:** `WalletController@transactions` — `core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:158-244`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:215`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "filters": "...",
    "currency": "...",
    "type": "...",
    "from": "...",
    "to": "...",
    "transactions": "...",
    "id": "...",
    "direction": "...",
    "amount": "...",
    "balance_before": "...",
    "balance_after": "...",
    "description": "...",
    "created_at": "...",
    "trade": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

##### `POST /api/ibm/portal/commission-distributions`

- **Frontend:** `ibmgrDistributionApi.store` (`src/components/ibmanager-portal/ibmanagerApi.js:248`)
- **Triggered from:** `submitDistribution`
- **Backend:** `CommissionDistributionController@store` — `core/Modules/IBManager/Http/Controllers/Portal/CommissionDistributionController.php:73-115`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `client_user_id`, `amount`, `comment`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/CommissionDistributionController.php:109`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "distribution_id": "...",
    "client_user_id": "...",
    "currency": "...",
    "amount": "..."
  }
}
```

**Errors** (`success: false`)
- `:97` `422` — ($e->getMessage(), 422)

##### `POST /api/ibm/portal/exports`

- **Frontend:** `ibmgrExportsApi.create` (`src/components/ibmanager-portal/ibmanagerApi.js:130`)
- **Triggered from:** `fail`
- **Backend:** `ExportController@store` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:42-104`
- **Middleware:** `auth:sanctum`, `ibm.auth`
- **Request fields (validated):** `kind`, `from`, `to`, `type`, `status`, `view`, `mt5_account`, `symbol`, `side`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:102`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "export": "..."
  }
}
```

**Errors** (`success: false`)
- `:77` `409` — A report is already being prepared. You will be notified when it is ready.

##### `POST /api/ibm/portal/wallet/withdraw`

- **Frontend:** `ibmgrWalletApi.withdraw` (`src/components/ibmanager-portal/ibmanagerApi.js:219`)
- **Triggered from:** `submit`
- **Backend:** `WalletController@withdraw` — `core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:386-449`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `currency`, `amount`, `method_slug`, `withdrawal_method_id`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:442`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "payout_request_id": "...",
    "currency": "...",
    "amount": "...",
    "balance": "...",
    "pending_payout": "..."
  }
}
```

**Errors** (`success: false`)
- `:417` `422` — ($e->getMessage(), 422)
- `:428` `422` — ($e->getMessage(), 422)

</details>

### My Team Deposit / My Team Withdrawal — `/ib-manager-portal/team-deposits`

Component: `src/components/ibmanager-portal/sections/IBMgrClientFunding.vue` — **4 APIs**

1. `GET /api/ibm/portal/client-funding` → `ClientFundingController@index`
2. `GET /api/ibm/portal/exports/{id}` → `ExportController@show`
3. `GET /api/ibm/portal/exports/{id}/download` → `ExportController@download`
4. `POST /api/ibm/portal/exports` → `ExportController@store`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/client-funding`

- **Frontend:** `ibmgrClientFundingApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:111`)
- **Triggered from:** `load`
- **Backend:** `ClientFundingController@index` — `core/Modules/IBManager/Http/Controllers/Portal/ClientFundingController.php:24-71`
- **Middleware:** `auth:sanctum`, `ibm.auth`
- **Request fields (validated):** `from`, `to`, `type`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ClientFundingController.php:50`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "rows": "...",
    "type": "...",
    "moved_at": "...",
    "client_user_id": "...",
    "client_name": "...",
    "client_email": "...",
    "amount": "...",
    "currency": "...",
    "status": "...",
    "totals": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

##### `GET /api/ibm/portal/exports/{id}`

- **Frontend:** `ibmgrExportsApi.show` (`src/components/ibmanager-portal/ibmanagerApi.js:134`)
- **Triggered from:** `setTimeout`
- **Backend:** `ExportController@show` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:107-116`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:115`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "export": "..."
  }
}
```

**Errors** (`success: false`)
- `:112` `404` — Report not found.

##### `GET /api/ibm/portal/exports/{id}/download`

- **Frontend:** `ibmgrExportsApi.download` (`src/components/ibmanager-portal/ibmanagerApi.js:138`)
- **Triggered from:** `setTimeout`
- **Backend:** `ExportController@download` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:121-189`
- **Middleware:** `auth:sanctum`, `ibm.auth`


**Errors** (`success: false`)
- `:126` `404` — Report not found.
- `:132` `410` — This report is no longer available for download.
- `:145` `410` — This report is no longer available for download.
- `:154` `410` — This report is no longer available for download.

##### `POST /api/ibm/portal/exports`

- **Frontend:** `ibmgrExportsApi.create` (`src/components/ibmanager-portal/ibmanagerApi.js:130`)
- **Triggered from:** `fail`
- **Backend:** `ExportController@store` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:42-104`
- **Middleware:** `auth:sanctum`, `ibm.auth`
- **Request fields (validated):** `kind`, `from`, `to`, `type`, `status`, `view`, `mt5_account`, `symbol`, `side`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:102`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "export": "..."
  }
}
```

**Errors** (`success: false`)
- `:77` `409` — A report is already being prepared. You will be notified when it is ready.

</details>

### IB Commission report — `/ib-manager-portal/ib-commission-report`

Component: `src/components/ibmanager-portal/sections/IBMgrCommissionReport.vue` — **4 APIs**

1. `GET /api/ibm/portal/commission-report` → `CommissionReportController@index`
2. `GET /api/ibm/portal/exports/{id}` → `ExportController@show`
3. `GET /api/ibm/portal/exports/{id}/download` → `ExportController@download`
4. `POST /api/ibm/portal/exports` → `ExportController@store`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/commission-report`

- **Frontend:** `ibmgrCommissionReportApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:116`)
- **Triggered from:** `load`
- **Backend:** `CommissionReportController@index` — `core/Modules/IBManager/Http/Controllers/Portal/CommissionReportController.php:33-85`
- **Middleware:** `auth:sanctum`, `ibm.auth`
- **Request fields (validated):** `from`, `to`, `view`, `mt5_account`, `symbol`, `type`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/CommissionReportController.php:63`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "view": "...",
    "rows": "...",
    "summary": "...",
    "totals": "...",
    "currency": "...",
    "lots": "...",
    "commission": "...",
    "options": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

##### `GET /api/ibm/portal/exports/{id}`

- **Frontend:** `ibmgrExportsApi.show` (`src/components/ibmanager-portal/ibmanagerApi.js:134`)
- **Triggered from:** `setTimeout`
- **Backend:** `ExportController@show` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:107-116`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:115`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "export": "..."
  }
}
```

**Errors** (`success: false`)
- `:112` `404` — Report not found.

##### `GET /api/ibm/portal/exports/{id}/download`

- **Frontend:** `ibmgrExportsApi.download` (`src/components/ibmanager-portal/ibmanagerApi.js:138`)
- **Triggered from:** `setTimeout`
- **Backend:** `ExportController@download` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:121-189`
- **Middleware:** `auth:sanctum`, `ibm.auth`


**Errors** (`success: false`)
- `:126` `404` — Report not found.
- `:132` `410` — This report is no longer available for download.
- `:145` `410` — This report is no longer available for download.
- `:154` `410` — This report is no longer available for download.

##### `POST /api/ibm/portal/exports`

- **Frontend:** `ibmgrExportsApi.create` (`src/components/ibmanager-portal/ibmanagerApi.js:130`)
- **Triggered from:** `fail`
- **Backend:** `ExportController@store` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:42-104`
- **Middleware:** `auth:sanctum`, `ibm.auth`
- **Request fields (validated):** `kind`, `from`, `to`, `type`, `status`, `view`, `mt5_account`, `symbol`, `side`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:102`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "export": "..."
  }
}
```

**Errors** (`success: false`)
- `:77` `409` — A report is already being prepared. You will be notified when it is ready.

</details>

### IB Withdraw report — `/ib-manager-portal/ib-withdraw-report`

Component: `src/components/ibmanager-portal/sections/IBMgrPayoutReport.vue` — **4 APIs**

1. `GET /api/ibm/portal/exports/{id}` → `ExportController@show`
2. `GET /api/ibm/portal/exports/{id}/download` → `ExportController@download`
3. `GET /api/ibm/portal/payout-report` → `PayoutReportController@index`
4. `POST /api/ibm/portal/exports` → `ExportController@store`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/exports/{id}`

- **Frontend:** `ibmgrExportsApi.show` (`src/components/ibmanager-portal/ibmanagerApi.js:134`)
- **Triggered from:** `setTimeout`
- **Backend:** `ExportController@show` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:107-116`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:115`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "export": "..."
  }
}
```

**Errors** (`success: false`)
- `:112` `404` — Report not found.

##### `GET /api/ibm/portal/exports/{id}/download`

- **Frontend:** `ibmgrExportsApi.download` (`src/components/ibmanager-portal/ibmanagerApi.js:138`)
- **Triggered from:** `setTimeout`
- **Backend:** `ExportController@download` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:121-189`
- **Middleware:** `auth:sanctum`, `ibm.auth`


**Errors** (`success: false`)
- `:126` `404` — Report not found.
- `:132` `410` — This report is no longer available for download.
- `:145` `410` — This report is no longer available for download.
- `:154` `410` — This report is no longer available for download.

##### `GET /api/ibm/portal/payout-report`

- **Frontend:** `ibmgrPayoutReportApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:121`)
- **Triggered from:** `load`
- **Backend:** `PayoutReportController@index` — `core/Modules/IBManager/Http/Controllers/Portal/PayoutReportController.php:28-105`
- **Middleware:** `auth:sanctum`, `ibm.auth`
- **Request fields (validated):** `from`, `to`, `status`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PayoutReportController.php:73`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "rows": "...",
    "id": "...",
    "kind": "...",
    "currency": "...",
    "amount": "...",
    "status": "...",
    "method_name": "...",
    "beneficiary_label": "...",
    "requested_at": "...",
    "reviewed_at": "...",
    "paid_at": "...",
    "payment_reference": "...",
    "rejection_reason": "...",
    "refunded_at": "...",
    "totals": "...",
    "requested": "...",
    "paid": "...",
    "in_process": "...",
    "rejected": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

##### `POST /api/ibm/portal/exports`

- **Frontend:** `ibmgrExportsApi.create` (`src/components/ibmanager-portal/ibmanagerApi.js:130`)
- **Triggered from:** `fail`
- **Backend:** `ExportController@store` — `core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:42-104`
- **Middleware:** `auth:sanctum`, `ibm.auth`
- **Request fields (validated):** `kind`, `from`, `to`, `type`, `status`, `view`, `mt5_account`, `symbol`, `side`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ExportController.php:102`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "export": "..."
  }
}
```

**Errors** (`success: false`)
- `:77` `409` — A report is already being prepared. You will be notified when it is ready.

</details>

### Referral Links — `/ib-manager-portal/referrals`

Component: `src/components/ibmanager-portal/sections/IBMgrReferrals.vue` — **6 APIs**

1. `DELETE /api/ibm/portal/links/{id}` → `ReferralLinkController@destroy`
2. `GET /api/ibm/portal/links` → `ReferralLinkController@index`
3. `GET /api/ibm/portal/links/{id}/clients` → `ReferralLinkController@clients`
4. `GET /api/ibm/portal/plan/groups` → `PlanController@groups`
5. `POST /api/ibm/portal/links` → `ReferralLinkController@store`
6. `PUT /api/ibm/portal/links/{id}` → `ReferralLinkController@update`

<details><summary>Request / response details</summary>

##### `DELETE /api/ibm/portal/links/{id}`

- **Frontend:** `ibmgrReferralsApi.destroy` (`src/components/ibmanager-portal/ibmanagerApi.js:84`)
- **Triggered from:** `remove`
- **Backend:** `ReferralLinkController@destroy` — `core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:194-214`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:213`
```json
{
  "success": true,
  "message": "...",
  "data": "<null>"
}
```

**Errors** (`success: false`)
- `:202` `422` — Your default link cannot be deleted.

##### `GET /api/ibm/portal/links`

- **Frontend:** `ibmgrReferralsApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:81`)
- **Triggered from:** `load`
- **Backend:** `ReferralLinkController@index` — `core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:34-74`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:48`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "links": "...",
    "link_id": "...",
    "code": "...",
    "label": "...",
    "type": "...",
    "is_default_link": "...",
    "is_active": "...",
    "expires_at": "...",
    "groups": "...",
    "plan_group_id": "...",
    "name": "...",
    "is_default": "...",
    "counts": "..."
  }
}
```

##### `GET /api/ibm/portal/links/{id}/clients`

- **Frontend:** `ibmgrReferralsApi.clients` (`src/components/ibmanager-portal/ibmanagerApi.js:87`)
- **Triggered from:** `openPeople`
- **Backend:** `ReferralLinkController@clients` — `core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:275-327`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:305`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "link": "...",
    "link_id": "...",
    "code": "...",
    "label": "...",
    "period": "...",
    "key": "...",
    "clients": "...",
    "client_user_id": "...",
    "name": "...",
    "email": "...",
    "registered_at": "...",
    "first_account_at": "...",
    "first_deposit_at": "...",
    "first_trade_at": "...",
    "held_by_you": "...",
    "held_by": "..."
  }
}
```

##### `GET /api/ibm/portal/plan/groups`

- **Frontend:** `ibmgrPlanGroupsApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:29`)
- **Triggered from:** `load`
- **Backend:** `PlanController@groups` — `core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:161-188`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:187`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "groups": "..."
  }
}
```

##### `POST /api/ibm/portal/links`

- **Frontend:** `ibmgrReferralsApi.create` (`src/components/ibmanager-portal/ibmanagerApi.js:82`)
- **Triggered from:** `save`
- **Backend:** `ReferralLinkController@store` — `core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:76-125`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `label`, `code`, `plan_group_ids`, `plan_group_ids.*`, `default_plan_group_id`, `expires_at`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:124`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "link_id": "...",
    "code": "..."
  }
}
```

**Errors** (`success: false`)
- `:95` `422` — The pre-selected group must be one of the groups on this link.
- `:101` `422` — That link code is already taken.

##### `PUT /api/ibm/portal/links/{id}`

- **Frontend:** `ibmgrReferralsApi.update` (`src/components/ibmanager-portal/ibmanagerApi.js:83`)
- **Triggered from:** `save`, `toggle`
- **Backend:** `ReferralLinkController@update` — `core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:127-192`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `label`, `is_active`, `plan_group_ids`, `plan_group_ids.*`, `default_plan_group_id`, `expires_at`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/ReferralLinkController.php:191`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "link_id": "..."
  }
}
```

**Errors** (`success: false`)
- `:142` `422` — Your default link cannot be switched off.
- `:150` `422` — Your default link follows your client group settings and has no group list of its own.
- `:156` `422` — Choose at least one group for this link.
- `:160` `422` — The pre-selected group must be one of the groups on this link.

</details>

### Marketing Material — `/ib-manager-portal/marketing`

Component: `src/components/ibmanager-portal/sections/IBMgrMarketing.vue` — **1 APIs**

1. `GET /api/ibm/portal/marketing` → `MarketingController@index`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/marketing`

- **Frontend:** `ibmgrMarketingApi.list` (`src/components/ibmanager-portal/ibmanagerApi.js:93`)
- **Triggered from:** `load`
- **Backend:** `MarketingController@index` — `core/Modules/IBManager/Http/Controllers/Portal/MarketingController.php:25-63`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/MarketingController.php:59`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "materials": "...",
    "categories": "..."
  }
}
```

</details>

### Settings — `/ib-manager-portal/settings`

Component: `src/components/ibmanager-portal/sections/IBMgrSettings.vue` — **4 APIs**

1. `GET /api/ibm/portal/client-visibility` → `VisibilityController@index`
2. `GET /api/ibm/portal/plan` → `PlanController@show`
3. `GET /api/ibm/portal/wallet` → `WalletController@index`
4. `POST /api/ibm/portal/client-visibility` → `VisibilityController@update`

<details><summary>Request / response details</summary>

##### `GET /api/ibm/portal/client-visibility`

- **Frontend:** `ibmgrVisibilityApi.get` (`src/components/ibmanager-portal/ibmanagerApi.js:35`)
- **Triggered from:** `load`
- **Backend:** `VisibilityController@index` — `core/Modules/IBManager/Http/Controllers/Portal/VisibilityController.php:29-68`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/VisibilityController.php:59`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "groups": "...",
    "plan_name": "...",
    "default_plan_group_id": "...",
    "visible_count": "..."
  }
}
```

##### `GET /api/ibm/portal/plan`

- **Frontend:** `ibmgrCommissionApi.myPlan` (`src/components/ibmanager-portal/ibmanagerApi.js:104`)
- **Triggered from:** `load`
- **Backend:** `PlanController@show` — `core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:24-29`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/PlanController.php:28`
```json
{
  "success": true,
  "message": "...",
  "data": "<$this->present($this->guard->requireAssignedPlanId($ibUserId))>"
}
```

##### `GET /api/ibm/portal/wallet`

- **Frontend:** `ibmgrWalletApi.get` (`src/components/ibmanager-portal/ibmanagerApi.js:218`)
- **Triggered from:** `load`
- **Backend:** `WalletController@index` — `core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:47-100`
- **Middleware:** `auth:sanctum`, `ibm.auth`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/WalletController.php:61`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "minimum_payout_by_currency": "...",
    "methods": "...",
    "payouts": "...",
    "id": "...",
    "currency": "...",
    "amount": "...",
    "status": "...",
    "method_name": "...",
    "beneficiary_label": "...",
    "requested_at": "...",
    "paid_at": "...",
    "payment_reference": "...",
    "rejection_reason": "...",
    "raised_by_broker": "...",
    "wallets": "...",
    "balance": "...",
    "pending_payout": "...",
    "lifetime_earned": "...",
    "lifetime_paid": "...",
    "is_frozen": "...",
    "can_withdraw": "...",
    "open_payout_status": "...",
    "minimum_payout": "..."
  }
}
```

##### `POST /api/ibm/portal/client-visibility`

- **Frontend:** `ibmgrVisibilityApi.save` (`src/components/ibmanager-portal/ibmanagerApi.js:36`)
- **Triggered from:** `save`
- **Backend:** `VisibilityController@update` — `core/Modules/IBManager/Http/Controllers/Portal/VisibilityController.php:70-121`
- **Middleware:** `auth:sanctum`, `ibm.auth`, `ibm.not-managed-by-broker`
- **Request fields (validated):** `plan_group_ids`, `plan_group_ids.*`, `default_plan_group_id`

**Success**

`core/Modules/IBManager/Http/Controllers/Portal/VisibilityController.php:117`
```json
{
  "success": true,
  "message": "...",
  "data": {
    "plan_group_ids": "...",
    "default_plan_group_id": "..."
  }
}
```

**Errors** (`success: false`)
- `:85` `422` — Leave at least one group on, or your clients cannot open an account.
- `:95` `422` — One or more of the selected groups is not on your plan.
- `:105` `422` — The default group must be one of the groups you are showing.

</details>

### Transfer Commission (leaves portal → Internal Transfer page) — `/internal-transfer`

Uses the same page as **Internal Transfer**.

---

## Transaction History

### Transaction History — `/transaction-history`

Component: `src/components/TransactionHistory.vue` — **1 APIs**

1. `GET /api/user/finance-activity` → `FinanceController@transactions1`

<details><summary>Request / response details</summary>

##### `GET /api/user/finance-activity`

- **Frontend:** `financeService.getTransactionHistory` (`src/services/finance.service.js:203`)
- **Triggered from:** `loadTransactionHistory`
- **Backend:** `FinanceController@transactions1` — `core/app/Http/Controllers/User/FinanceController.php:8001-8625`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:8600`
```json
{
  "status": 200,
  "success": true,
  "message": "Transactions fetched successfully",
  "data": "<$paginatedTransactions->items() // Direct array>"
}
```
`core/app/Http/Controllers/User/FinanceController.php:8620`
```json
($responseData, 200)
```

**Errors** (`success: false`)
- `:8623` `500` — An error occurred while fetching transactions.

</details>

### Wallet History — `/wallet-history`

Component: `src/components/WalletHistory.vue` — **2 APIs**

1. `GET /api/user/finance-activity` → `FinanceController@transactions1`
2. `GET /api/user/internaltransfer/history` → `FinanceController@getInternalTransferHistory`

<details><summary>Request / response details</summary>

##### `GET /api/user/finance-activity`

- **Frontend:** `financeService.getTransactionHistory` (`src/services/finance.service.js:203`)
- **Triggered from:** `runFetch`
- **Backend:** `FinanceController@transactions1` — `core/app/Http/Controllers/User/FinanceController.php:8001-8625`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:8600`
```json
{
  "status": 200,
  "success": true,
  "message": "Transactions fetched successfully",
  "data": "<$paginatedTransactions->items() // Direct array>"
}
```
`core/app/Http/Controllers/User/FinanceController.php:8620`
```json
($responseData, 200)
```

**Errors** (`success: false`)
- `:8623` `500` — An error occurred while fetching transactions.

##### `GET /api/user/internaltransfer/history`

- **Frontend:** `financeService.getInternalTransferHistory` (`src/services/finance.service.js:183`)
- **Triggered from:** `runFetch`
- **Backend:** `FinanceController@getInternalTransferHistory` — `core/app/Http/Controllers/User/FinanceController.php:5182-5269`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:5252`
```json
{
  "status": 200,
  "success": true,
  "message": "Internal transfer history retrieved successfully",
  "data": {
    "data": "...",
    "pagination": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "...",
    "from": "...",
    "to": "..."
  }
}
```

**Errors** (`success: false`)
- `:5267` `500` — Failed to fetch internal transfer history

</details>

---

## PAMM

### Explore Fund Managers — `/pmam/investor/explore`

Component: `src/components/pmam/PmamExploreFundManagers.vue` — **12 APIs**

1. `GET /api/user/pmam/investor/eligible-accounts` → `PmamApiController@getEligibleAccounts`
2. `GET /api/user/pmam/investor/enrollments` → `PmamApiController@getMyEnrollments`
3. `GET /api/user/pmam/investor/my-fund-entries` → `PmamApiController@getMyFundEntries`
4. `GET /api/user/pmam/investor/my-open-allocations` → `PmamApiController@getMyOpenAllocations`
5. `GET /api/user/pmam/investor/pnl-history` → `PmamApiController@getMyPnlHistory`
6. `GET /api/user/pmam/managers/{code}/trades` → `PmamApiController@getManagerPlanTrades`
7. `GET /api/user/pmam/managers/search` → `PmamApiController@searchManagers`
8. `GET /api/user/pmam/plans/search` → `PmamApiController@searchPlans`
9. `POST /api/user/pmam/investor/deposit` → `PmamApiController@addDeposit`
10. `POST /api/user/pmam/investor/request-join` → `PmamApiController@requestJoin`
11. `POST /api/user/pmam/investor/unsubscribe/{id}` → `PmamApiController@unsubscribe`
12. `POST /api/user/pmam/plans/datatable` → `PmamApiController@getPlansListDataTable`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/investor/eligible-accounts`

- **Frontend:** `pmamService.getEligibleAccounts` (`src/services/pmam.service.js:149`)
- **Triggered from:** `loadTradingAccounts`
- **Backend:** `PmamApiController@getEligibleAccounts` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1589-1645`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1644`
```json
{
  "status": 200,
  "success": true,
  "message": "Eligible accounts retrieved",
  "data": "<$accounts>"
}
```

##### `GET /api/user/pmam/investor/enrollments`

- **Frontend:** `pmamService.getMyEnrollments` (`src/services/pmam.service.js:419`)
- **Triggered from:** `loadInvestments`, `setTimeout`, `loadUserInvestments`
- **Backend:** `PmamApiController@getMyEnrollments` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1542-1581`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1580`
```json
{
  "status": 200,
  "success": true,
  "message": "Enrollments retrieved",
  "data": "<$enrollments>"
}
```

##### `GET /api/user/pmam/investor/my-fund-entries`

- **Frontend:** `pmamService.getMyFundEntries` (`src/services/pmam.service.js:213`)
- **Triggered from:** `loadInvestments`
- **Backend:** `PmamApiController@getMyFundEntries` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2119-2142`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2141`
```json
{
  "status": 200,
  "success": true,
  "message": "Fund entries retrieved",
  "data": "<$entries>"
}
```

##### `GET /api/user/pmam/investor/my-open-allocations`

- **Frontend:** `pmamService.getMyOpenAllocations` (`src/services/pmam.service.js:222`)
- **Triggered from:** `loadInvestments`
- **Backend:** `PmamApiController@getMyOpenAllocations` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2147-2174`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2173`
```json
{
  "status": 200,
  "success": true,
  "message": "Open allocations retrieved",
  "data": "<$allocations>"
}
```

##### `GET /api/user/pmam/investor/pnl-history`

- **Frontend:** `pmamService.getMyPnlHistory` (`src/services/pmam.service.js:204`)
- **Triggered from:** `openTradeDrawer`
- **Backend:** `PmamApiController@getMyPnlHistory` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2083-2114`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2113`
```json
{
  "status": 200,
  "success": true,
  "message": "P&L history retrieved",
  "data": "<$distributions>"
}
```

**Errors** (`success: false`)
- `:2097` `404` — Enrollment not found

##### `GET /api/user/pmam/managers/{code}/trades`

- **Frontend:** `pmamService.getManagerTrades` (`src/services/pmam.service.js:401`)
- **Triggered from:** `loadDrawerTrades`
- **Backend:** `PmamApiController@getManagerPlanTrades` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3206-3376`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3241`
```json
{
  "status": 200,
  "success": true,
  "message": "Trade history retrieved",
  "data": {
    "trades": "...",
    "total": "...",
    "page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3310`
```json
{
  "status": 200,
  "success": true,
  "message": "Not enrolled in this plan",
  "data": {
    "trades": "...",
    "total": "...",
    "page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```

**Errors** (`success: false`)
- `:3216` `422` — plan_id is required
- `:3221` `404` — Manager not found
- `:3230` `404` — Plan not found
- `:3293` `404` — Enrollment not found

##### `GET /api/user/pmam/managers/search`

- **Frontend:** `pmamService.searchManagers` (`src/services/pmam.service.js:368`)
- **Triggered from:** `searchManagerOptions`
- **Backend:** `PmamApiController@searchManagers` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3410-3450`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3414`
```json
{
  "status": 200,
  "success": true,
  "message": "Managers found",
  "data": "..."
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3449`
```json
{
  "status": 200,
  "success": true,
  "message": "Managers found",
  "data": "<$managers>"
}
```

##### `GET /api/user/pmam/plans/search`

- **Frontend:** `pmamService.searchPlans` (`src/services/pmam.service.js:383`)
- **Triggered from:** `searchPlanOptions`
- **Backend:** `PmamApiController@searchPlans` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3464-3503`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3468`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans found",
  "data": "..."
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3502`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans found",
  "data": "<$plans>"
}
```

##### `POST /api/user/pmam/investor/deposit`

- **Frontend:** `pmamService.addDeposit` (`src/services/pmam.service.js:185`)
- **Triggered from:** `handleAddFundsSubmit`
- **Backend:** `PmamApiController@addDeposit` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1901-1993`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `pmam_investor_id`, `amount`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1992`
```json
{
  "status": 200,
  "success": true,
  "message": "Additional deposit locked and added to manager pool. You will participate in trades opened after this deposit.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:1919` `422` — Trading account not found.
- `:1925` `422` — Insufficient available (unlocked) balance.
- `:1958` `422` — Failed to deposit funds into manager account: 

##### `POST /api/user/pmam/investor/request-join`

- **Frontend:** `pmamService.requestJoin` (`src/services/pmam.service.js:167`)
- **Triggered from:** `handleSubmit`
- **Backend:** `PmamApiController@requestJoin` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1704-1873`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `pmam_plan_id`, `investor_account_id`, `invested_amount`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1872`
```json
{
  "status": 200,
  "success": true,
  "message": "Join request submitted. Awaiting manager approval.",
  "data": {
    "id": "...",
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:1719` `422` — This plan is not available for investment at this time.
- `:1724` `422` — This manager is currently suspended and is not accepting new investments.
- `:1730` `422` — ($limitChk['message'] ?? 'Investment amount is outside the allowed range.', false, [], 422)
- `:1734` `422` — ($coolChk['message'] ?? 'You must wait before re-subscribing to this plan.', false, [], 422)
- `:1740` `422` — Cannot enroll: fund manager account has negative balance. Please try again later.
- `:1745` `422` — Minimum investment is {$plan->minimum_investment}.

##### `POST /api/user/pmam/investor/unsubscribe/{id}`

- **Frontend:** `pmamService.unsubscribe` (`src/services/pmam.service.js:194`)
- **Triggered from:** `handleUnsubscribe`
- **Backend:** `PmamApiController@unsubscribe` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2000-2075`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2074`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2009` `422` — Unsubscribe is not allowed on weekends. Please try again on a weekday.
- `:2015` `422` — ($lockChk['message'] ?? 'You cannot unsubscribe yet due to the lock-in period.', false, [], 422)
- `:2025` `429` — An unsubscribe request is already being processed for this investment. Please wait.
- `:2034` `422` — ($result['message'], false, $data, 422)

##### `POST /api/user/pmam/plans/datatable`

- **Frontend:** `pmamService.getPlansDataTable` (`src/services/pmam.service.js:392`)
- **Triggered from:** `start`
- **Backend:** `PmamApiController@getPlansListDataTable` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3520-3624`
- **Middleware:** `auth:sanctum`

> Yajra DataTables server-side JSON (PmamApiController.php:3520), not the standard envelope.

**Success**
```json
{
  "draw": 1,
  "recordsTotal": 12,
  "recordsFiltered": 12,
  "data": [ { "id": 1, "name": "...", "manager_name": "...", "total_aum": 0, "profit": 0, "max_drawdown": 0, ... } ]
}
```

</details>

### My Investments — `/pmam/investor/my-investments`

Component: `src/components/pmam/PmamMyInvestments.vue` — **12 APIs**

1. `GET /api/user/pmam/investor/eligible-accounts` → `PmamApiController@getEligibleAccounts`
2. `GET /api/user/pmam/investor/enrollments` → `PmamApiController@getMyEnrollments`
3. `GET /api/user/pmam/investor/my-fund-entries` → `PmamApiController@getMyFundEntries`
4. `GET /api/user/pmam/investor/my-open-allocations` → `PmamApiController@getMyOpenAllocations`
5. `GET /api/user/pmam/investor/pnl-history` → `PmamApiController@getMyPnlHistory`
6. `GET /api/user/pmam/managers/{code}/trades` → `PmamApiController@getManagerPlanTrades`
7. `GET /api/user/pmam/managers/search` → `PmamApiController@searchManagers`
8. `GET /api/user/pmam/plans/search` → `PmamApiController@searchPlans`
9. `POST /api/user/pmam/investor/deposit` → `PmamApiController@addDeposit`
10. `POST /api/user/pmam/investor/request-join` → `PmamApiController@requestJoin`
11. `POST /api/user/pmam/investor/unsubscribe/{id}` → `PmamApiController@unsubscribe`
12. `POST /api/user/pmam/plans/datatable` → `PmamApiController@getPlansListDataTable`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/investor/eligible-accounts`

- **Frontend:** `pmamService.getEligibleAccounts` (`src/services/pmam.service.js:149`)
- **Triggered from:** `loadTradingAccounts`
- **Backend:** `PmamApiController@getEligibleAccounts` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1589-1645`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1644`
```json
{
  "status": 200,
  "success": true,
  "message": "Eligible accounts retrieved",
  "data": "<$accounts>"
}
```

##### `GET /api/user/pmam/investor/enrollments`

- **Frontend:** `pmamService.getMyEnrollments` (`src/services/pmam.service.js:419`)
- **Triggered from:** `loadInvestments`, `setTimeout`, `loadUserInvestments`
- **Backend:** `PmamApiController@getMyEnrollments` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1542-1581`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1580`
```json
{
  "status": 200,
  "success": true,
  "message": "Enrollments retrieved",
  "data": "<$enrollments>"
}
```

##### `GET /api/user/pmam/investor/my-fund-entries`

- **Frontend:** `pmamService.getMyFundEntries` (`src/services/pmam.service.js:213`)
- **Triggered from:** `loadInvestments`
- **Backend:** `PmamApiController@getMyFundEntries` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2119-2142`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2141`
```json
{
  "status": 200,
  "success": true,
  "message": "Fund entries retrieved",
  "data": "<$entries>"
}
```

##### `GET /api/user/pmam/investor/my-open-allocations`

- **Frontend:** `pmamService.getMyOpenAllocations` (`src/services/pmam.service.js:222`)
- **Triggered from:** `loadInvestments`
- **Backend:** `PmamApiController@getMyOpenAllocations` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2147-2174`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2173`
```json
{
  "status": 200,
  "success": true,
  "message": "Open allocations retrieved",
  "data": "<$allocations>"
}
```

##### `GET /api/user/pmam/investor/pnl-history`

- **Frontend:** `pmamService.getMyPnlHistory` (`src/services/pmam.service.js:204`)
- **Triggered from:** `openTradeDrawer`
- **Backend:** `PmamApiController@getMyPnlHistory` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2083-2114`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2113`
```json
{
  "status": 200,
  "success": true,
  "message": "P&L history retrieved",
  "data": "<$distributions>"
}
```

**Errors** (`success: false`)
- `:2097` `404` — Enrollment not found

##### `GET /api/user/pmam/managers/{code}/trades`

- **Frontend:** `pmamService.getManagerTrades` (`src/services/pmam.service.js:401`)
- **Triggered from:** `loadDrawerTrades`
- **Backend:** `PmamApiController@getManagerPlanTrades` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3206-3376`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3241`
```json
{
  "status": 200,
  "success": true,
  "message": "Trade history retrieved",
  "data": {
    "trades": "...",
    "total": "...",
    "page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3310`
```json
{
  "status": 200,
  "success": true,
  "message": "Not enrolled in this plan",
  "data": {
    "trades": "...",
    "total": "...",
    "page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```

**Errors** (`success: false`)
- `:3216` `422` — plan_id is required
- `:3221` `404` — Manager not found
- `:3230` `404` — Plan not found
- `:3293` `404` — Enrollment not found

##### `GET /api/user/pmam/managers/search`

- **Frontend:** `pmamService.searchManagers` (`src/services/pmam.service.js:368`)
- **Triggered from:** `searchManagerOptions`
- **Backend:** `PmamApiController@searchManagers` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3410-3450`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3414`
```json
{
  "status": 200,
  "success": true,
  "message": "Managers found",
  "data": "..."
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3449`
```json
{
  "status": 200,
  "success": true,
  "message": "Managers found",
  "data": "<$managers>"
}
```

##### `GET /api/user/pmam/plans/search`

- **Frontend:** `pmamService.searchPlans` (`src/services/pmam.service.js:383`)
- **Triggered from:** `searchPlanOptions`
- **Backend:** `PmamApiController@searchPlans` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3464-3503`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3468`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans found",
  "data": "..."
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3502`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans found",
  "data": "<$plans>"
}
```

##### `POST /api/user/pmam/investor/deposit`

- **Frontend:** `pmamService.addDeposit` (`src/services/pmam.service.js:185`)
- **Triggered from:** `handleAddFundsSubmit`
- **Backend:** `PmamApiController@addDeposit` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1901-1993`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `pmam_investor_id`, `amount`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1992`
```json
{
  "status": 200,
  "success": true,
  "message": "Additional deposit locked and added to manager pool. You will participate in trades opened after this deposit.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:1919` `422` — Trading account not found.
- `:1925` `422` — Insufficient available (unlocked) balance.
- `:1958` `422` — Failed to deposit funds into manager account: 

##### `POST /api/user/pmam/investor/request-join`

- **Frontend:** `pmamService.requestJoin` (`src/services/pmam.service.js:167`)
- **Triggered from:** `handleSubmit`
- **Backend:** `PmamApiController@requestJoin` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1704-1873`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `pmam_plan_id`, `investor_account_id`, `invested_amount`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1872`
```json
{
  "status": 200,
  "success": true,
  "message": "Join request submitted. Awaiting manager approval.",
  "data": {
    "id": "...",
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:1719` `422` — This plan is not available for investment at this time.
- `:1724` `422` — This manager is currently suspended and is not accepting new investments.
- `:1730` `422` — ($limitChk['message'] ?? 'Investment amount is outside the allowed range.', false, [], 422)
- `:1734` `422` — ($coolChk['message'] ?? 'You must wait before re-subscribing to this plan.', false, [], 422)
- `:1740` `422` — Cannot enroll: fund manager account has negative balance. Please try again later.
- `:1745` `422` — Minimum investment is {$plan->minimum_investment}.

##### `POST /api/user/pmam/investor/unsubscribe/{id}`

- **Frontend:** `pmamService.unsubscribe` (`src/services/pmam.service.js:194`)
- **Triggered from:** `handleUnsubscribe`
- **Backend:** `PmamApiController@unsubscribe` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2000-2075`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2074`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:2009` `422` — Unsubscribe is not allowed on weekends. Please try again on a weekday.
- `:2015` `422` — ($lockChk['message'] ?? 'You cannot unsubscribe yet due to the lock-in period.', false, [], 422)
- `:2025` `429` — An unsubscribe request is already being processed for this investment. Please wait.
- `:2034` `422` — ($result['message'], false, $data, 422)

##### `POST /api/user/pmam/plans/datatable`

- **Frontend:** `pmamService.getPlansDataTable` (`src/services/pmam.service.js:392`)
- **Triggered from:** `start`
- **Backend:** `PmamApiController@getPlansListDataTable` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3520-3624`
- **Middleware:** `auth:sanctum`

> Yajra DataTables server-side JSON (PmamApiController.php:3520), not the standard envelope.

**Success**
```json
{
  "draw": 1,
  "recordsTotal": 12,
  "recordsFiltered": 12,
  "data": [ { "id": 1, "name": "...", "manager_name": "...", "total_aum": 0, "profit": 0, "max_drawdown": 0, ... } ]
}
```

</details>

### Managers list — `/pmam/managers`

Component: `src/components/pmam/PmamManagersList.vue` — **1 APIs**

1. `GET /api/user/pmam/managers` → `PmamApiController@getManagersList`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/managers`

- **Frontend:** `pmamService.getManagersList` (`src/services/pmam.service.js:287`)
- **Triggered from:** `loadData`
- **Backend:** `PmamApiController@getManagersList` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3629-3668`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3667`
```json
{
  "status": 200,
  "success": true,
  "message": "Managers list retrieved",
  "data": "<$managers>"
}
```

</details>

### Manager public profile — `/pmam/manager/:code`

Component: `src/components/pmam/PmamManagerProfile.vue` — **6 APIs**

1. `GET /api/user/pmam/investor/eligible-accounts` → `PmamApiController@getEligibleAccounts`
2. `GET /api/user/pmam/investor/enrollments` → `PmamApiController@getMyEnrollments`
3. `GET /api/user/pmam/managers/{code}` → `PmamApiController@getManagerProfile`
4. `GET /api/user/pmam/managers/{code}/open-positions` → `PmamApiController@getManagerPlanOpenPositions`
5. `GET /api/user/pmam/managers/{code}/trades` → `PmamApiController@getManagerPlanTrades`
6. `POST /api/user/pmam/investor/request-join` → `PmamApiController@requestJoin`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/investor/eligible-accounts`

- **Frontend:** `pmamService.getEligibleAccounts` (`src/services/pmam.service.js:149`)
- **Triggered from:** `loadTradingAccounts`
- **Backend:** `PmamApiController@getEligibleAccounts` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1589-1645`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1644`
```json
{
  "status": 200,
  "success": true,
  "message": "Eligible accounts retrieved",
  "data": "<$accounts>"
}
```

##### `GET /api/user/pmam/investor/enrollments`

- **Frontend:** `pmamService.getMyEnrollments` (`src/services/pmam.service.js:419`)
- **Triggered from:** `loadUserInvestments`
- **Backend:** `PmamApiController@getMyEnrollments` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1542-1581`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1580`
```json
{
  "status": 200,
  "success": true,
  "message": "Enrollments retrieved",
  "data": "<$enrollments>"
}
```

##### `GET /api/user/pmam/managers/{code}`

- **Frontend:** `pmamService.getManagerProfile` (`src/services/pmam.service.js:341`)
- **Triggered from:** `loadData`
- **Backend:** `PmamApiController@getManagerProfile` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3673-3760`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3747`
```json
{
  "status": 200,
  "success": true,
  "message": "Manager profile retrieved",
  "data": {
    "manager_code": "...",
    "manager_name": "...",
    "manager_email": "...",
    "member_since": "...",
    "total_plans": "...",
    "total_aum": "...",
    "total_investors": "...",
    "plans": "...",
    "performance_summary": "...",
    "reviews": "..."
  }
}
```

**Errors** (`success: false`)
- `:3681` `404` — Manager not found

##### `GET /api/user/pmam/managers/{code}/open-positions`

- **Frontend:** `pmamService.getManagerOpenPositions` (`src/services/pmam.service.js:410`)
- **Triggered from:** `loadTrades`
- **Backend:** `PmamApiController@getManagerPlanOpenPositions` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3154-3194`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3193`
```json
{
  "status": 200,
  "success": true,
  "message": "Open positions retrieved",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:3158` `422` — plan_id is required
- `:3163` `404` — Manager not found
- `:3172` `404` — Plan not found

##### `GET /api/user/pmam/managers/{code}/trades`

- **Frontend:** `pmamService.getManagerTrades` (`src/services/pmam.service.js:401`)
- **Triggered from:** `loadTrades`
- **Backend:** `PmamApiController@getManagerPlanTrades` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3206-3376`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3241`
```json
{
  "status": 200,
  "success": true,
  "message": "Trade history retrieved",
  "data": {
    "trades": "...",
    "total": "...",
    "page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:3310`
```json
{
  "status": 200,
  "success": true,
  "message": "Not enrolled in this plan",
  "data": {
    "trades": "...",
    "total": "...",
    "page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```

**Errors** (`success: false`)
- `:3216` `422` — plan_id is required
- `:3221` `404` — Manager not found
- `:3230` `404` — Plan not found
- `:3293` `404` — Enrollment not found

##### `POST /api/user/pmam/investor/request-join`

- **Frontend:** `pmamService.requestJoin` (`src/services/pmam.service.js:167`)
- **Triggered from:** `handleSubmit`
- **Backend:** `PmamApiController@requestJoin` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1704-1873`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `pmam_plan_id`, `investor_account_id`, `invested_amount`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1872`
```json
{
  "status": 200,
  "success": true,
  "message": "Join request submitted. Awaiting manager approval.",
  "data": {
    "id": "...",
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:1719` `422` — This plan is not available for investment at this time.
- `:1724` `422` — This manager is currently suspended and is not accepting new investments.
- `:1730` `422` — ($limitChk['message'] ?? 'Investment amount is outside the allowed range.', false, [], 422)
- `:1734` `422` — ($coolChk['message'] ?? 'You must wait before re-subscribing to this plan.', false, [], 422)
- `:1740` `422` — Cannot enroll: fund manager account has negative balance. Please try again later.
- `:1745` `422` — Minimum investment is {$plan->minimum_investment}.

</details>

### Become a manager (apply) — `/pmam/manager/apply`

Component: `src/components/pmam/PmamManagerApply.vue` — **1 APIs**

1. `POST /api/user/pmam/manager/apply` → `PmamApiController@applyAsManager`

<details><summary>Request / response details</summary>

##### `POST /api/user/pmam/manager/apply`

- **Frontend:** `pmamService.applyAsManager` (`src/services/pmam.service.js:13`)
- **Triggered from:** `handleSubmit`
- **Backend:** `PmamApiController@applyAsManager` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:191-247`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `terms_accepted`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:246`
```json
{
  "status": 200,
  "success": true,
  "message": "Manager application submitted successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:202` `422` — ($masterEnrollmentChk['message'] ?? 'New PAMM master enrollments are currently disabled.', false, [], 422)
- `:208` `422` — IB partners cannot become PMAM managers. Roles are mutually exclusive.
- `:217` `422` — You already have an active manager application.
- `:225` `422` — ($steps['message'], false, [], 422)

</details>

### Manager dashboard — `/pmam/manager/dashboard`

Component: `src/components/pmam/PmamManagerDashboard.vue` — **3 APIs**

1. `GET /api/user/pmam/manager/dashboard-overview` → `PmamApiController@getManagerDashboardOverview`
2. `GET /api/user/pmam/manager/eligible-accounts` → `PmamApiController@getManagerEligibleAccounts`
3. `POST /api/user/pmam/manager/plans` → `PmamApiController@createPlan`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/manager/dashboard-overview`

- **Frontend:** `pmamService.getManagerDashboardOverview` (`src/services/pmam.service.js:323`)
- **Triggered from:** `loadOverview`
- **Backend:** `PmamApiController@getManagerDashboardOverview` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2352-2375`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2358`
```json
{
  "status": 200,
  "success": true,
  "message": "OK",
  "data": "<$this->pmamEmptyDashboardOverview($request, 'no_manager')>"
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2374`
```json
{
  "status": 200,
  "success": true,
  "message": "OK",
  "data": "<$payload>"
}
```

##### `GET /api/user/pmam/manager/eligible-accounts`

- **Frontend:** `pmamService.getManagerEligibleAccounts` (`src/services/pmam.service.js:267`)
- **Triggered from:** `loadTradingAccounts`
- **Backend:** `PmamApiController@getManagerEligibleAccounts` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1654-1698`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1697`
```json
{
  "status": 200,
  "success": true,
  "message": "Eligible accounts retrieved",
  "data": "<$accounts>"
}
```

##### `POST /api/user/pmam/manager/plans`

- **Frontend:** `pmamService.createPlan` (`src/services/pmam.service.js:22`)
- **Triggered from:** `handleSubmit`
- **Backend:** `PmamApiController@createPlan` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:253-373`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `trading_account_id`, `plan_name`, `commission_percentage`, `minimum_investment`, `strategy_description`, `risk_information`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:372`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "id": "...",
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:260` `422` — Trading account number is required.
- `:263` `422` — Trading account number is required.
- `:279` `422` — You do not have an approved manager account.
- `:285` `422` — ($capChk['message'] ?? 'Commission exceeds the platform maximum.', false, [], 422)
- `:294` `422` — Trading account not found or does not belong to you.
- `:302` `422` — Trading account number is required.

</details>

### Manager — My Plans — `/pmam/manager/plans`

Component: `src/components/pmam/PmamMyPlans.vue` — **7 APIs**

1. `GET /api/user/pmam/manager/eligible-accounts` → `PmamApiController@getManagerEligibleAccounts`
2. `GET /api/user/pmam/manager/plans` → `PmamApiController@getManagerPlans`
3. `POST /api/user/pmam/manager/plans` → `PmamApiController@createPlan`
4. `POST /api/user/pmam/manager/plans/{planId}/inactivate` → `PmamApiController@inactivatePlan`
5. `POST /api/user/pmam/manager/plans/{planId}/pause` → `PmamApiController@pausePlan`
6. `POST /api/user/pmam/manager/plans/{planId}/resume` → `PmamApiController@resumePlan`
7. `PUT /api/user/pmam/manager/plans/{planId}` → `PmamApiController@updatePlan`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/manager/eligible-accounts`

- **Frontend:** `pmamService.getManagerEligibleAccounts` (`src/services/pmam.service.js:267`)
- **Triggered from:** `loadTradingAccounts`
- **Backend:** `PmamApiController@getManagerEligibleAccounts` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1654-1698`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1697`
```json
{
  "status": 200,
  "success": true,
  "message": "Eligible accounts retrieved",
  "data": "<$accounts>"
}
```

##### `GET /api/user/pmam/manager/plans`

- **Frontend:** `pmamService.getManagerPlans` (`src/services/pmam.service.js:231`)
- **Triggered from:** `loadPlans`
- **Backend:** `PmamApiController@getManagerPlans` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:378-420`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:384`
```json
{
  "success": "...",
  "data": "..."
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:419`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "<$plans>"
}
```

##### `POST /api/user/pmam/manager/plans`

- **Frontend:** `pmamService.createPlan` (`src/services/pmam.service.js:22`)
- **Triggered from:** `handleSubmit`
- **Backend:** `PmamApiController@createPlan` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:253-373`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `trading_account_id`, `plan_name`, `commission_percentage`, `minimum_investment`, `strategy_description`, `risk_information`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:372`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "id": "...",
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:260` `422` — Trading account number is required.
- `:263` `422` — Trading account number is required.
- `:279` `422` — You do not have an approved manager account.
- `:285` `422` — ($capChk['message'] ?? 'Commission exceeds the platform maximum.', false, [], 422)
- `:294` `422` — Trading account not found or does not belong to you.
- `:302` `422` — Trading account number is required.

##### `POST /api/user/pmam/manager/plans/{planId}/inactivate`

- **Frontend:** `pmamService.inactivatePlan` (`src/services/pmam.service.js:240`)
- **Triggered from:** `confirmInactivate`
- **Backend:** `PmamApiController@inactivatePlan` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:425-489`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:488`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan inactivated successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:433` `422` — Plan is already inactive.
- `:439` `422` — Only approved or paused plans can be inactivated.
- `:447` `422` — ( sprintf('Cannot inactivate: plan has %d active investor(s) with $%s AUM.', $activeInvestorCount, number_format($totalAum, 2)), false, ['ac

##### `POST /api/user/pmam/manager/plans/{planId}/pause`

- **Frontend:** `pmamService.pausePlan` (`src/services/pmam.service.js:305`)
- **Triggered from:** `confirmPause`
- **Backend:** `PmamApiController@pausePlan` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:550-608`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:607`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan paused successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:558` `422` — Plan is already paused.
- `:561` `422` — Only approved plans can be paused.

##### `POST /api/user/pmam/manager/plans/{planId}/resume`

- **Frontend:** `pmamService.resumePlan` (`src/services/pmam.service.js:314`)
- **Triggered from:** `confirmResume`
- **Backend:** `PmamApiController@resumePlan` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:614-670`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:669`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan resumed successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:622` `422` — Plan is already active.
- `:625` `422` — Only paused plans can be resumed.

##### `PUT /api/user/pmam/manager/plans/{planId}`

- **Frontend:** `pmamService.updatePlan` (`src/services/pmam.service.js:296`)
- **Triggered from:** `handleSubmit`
- **Backend:** `PmamApiController@updatePlan` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:496-544`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `plan_name`, `strategy_description`, `risk_information`, `commission_percentage`, `minimum_investment`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:540`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan updated successfully.",
  "data": {
    "plan_id": "...",
    "updated_fields": "..."
  }
}
```

**Errors** (`success: false`)
- `:504` `422` — Cannot edit an 
- `:524` `422` — Commission and minimum investment can only be changed when the plan has no active investors.
- `:534` `422` — No editable fields provided.

</details>

### Manager — Plan view — `/pmam/manager/plans/:planId`

Component: `src/components/pmam/PmamManagerPlanView.vue` — **3 APIs**

1. `GET /api/user/pmam/manager/plans/{planId}/allocations` → `PmamApiController@getPlanAllocations`
2. `GET /api/user/pmam/manager/plans/{planId}/detail` → `PmamApiController@getPlanDetail`
3. `GET /api/user/pmam/manager/plans/{planId}/investors` → `PmamApiController@getPlanInvestors`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/manager/plans/{planId}/allocations`

- **Frontend:** `pmamService.getPlanAllocations` (`src/services/pmam.service.js:85`)
- **Triggered from:** `loadAllocations`
- **Backend:** `PmamApiController@getPlanAllocations` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1324-1394`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1387`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan allocations retrieved",
  "data": {
    "data": "...",
    "total": "...",
    "current_page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```

##### `GET /api/user/pmam/manager/plans/{planId}/detail`

- **Frontend:** `pmamService.getPlanDetail` (`src/services/pmam.service.js:67`)
- **Triggered from:** `loadDetail`
- **Backend:** `PmamApiController@getPlanDetail` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1062-1251`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1227`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan detail retrieved",
  "data": {
    "plan": "...",
    "id": "...",
    "plan_name": "...",
    "status": "...",
    "strategy_description": "...",
    "risk_information": "...",
    "total_aum": "...",
    "total_pnl": "...",
    "total_commission": "...",
    "active_investors": "...",
    "commission_pct": "...",
    "minimum_investment": "...",
    "created_at": "...",
    "withdrawable": "...",
    "can_withdraw": "...",
    "withdraw_message": "...",
    "investors": "...",
    "unique_investors": "...",
    "equity_curve": "...",
    "commission_summary": "...",
    "recent_activity": "..."
  }
}
```

##### `GET /api/user/pmam/manager/plans/{planId}/investors`

- **Frontend:** `pmamService.getPlanInvestors` (`src/services/pmam.service.js:76`)
- **Triggered from:** `search`
- **Backend:** `PmamApiController@getPlanInvestors` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1258-1317`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1310`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan investors retrieved",
  "data": {
    "data": "...",
    "total": "...",
    "current_page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```

</details>

### Manager — Investor requests — `/pmam/manager/plans/:planId/requests`

Component: `src/components/pmam/PmamManagerInvestorRequests.vue` — **3 APIs**

1. `GET /api/user/pmam/manager/plans/{planId}/investor-requests` → `PmamApiController@getInvestorRequests`
2. `POST /api/user/pmam/manager/investor-requests/{id}/approve` → `PmamApiController@approveInvestorRequest`
3. `POST /api/user/pmam/manager/investor-requests/{id}/reject` → `PmamApiController@rejectInvestorRequest`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/manager/plans/{planId}/investor-requests`

- **Frontend:** `pmamService.getInvestorRequests` (`src/services/pmam.service.js:31`)
- **Triggered from:** `loadRequests`
- **Backend:** `PmamApiController@getInvestorRequests` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:796-808`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:807`
```json
{
  "status": 200,
  "success": true,
  "message": "Investor requests retrieved",
  "data": "<$requests>"
}
```

##### `POST /api/user/pmam/manager/investor-requests/{id}/approve`

- **Frontend:** `pmamService.approveInvestorRequest` (`src/services/pmam.service.js:40`)
- **Triggered from:** `approveRequest`
- **Backend:** `PmamApiController@approveInvestorRequest` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:821-1000`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:999`
```json
{
  "status": 200,
  "success": true,
  "message": "Investor request approved. Account locked and funds deposited into pool.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:828` `403` — Not authorized.
- `:832` `422` — Request is not pending.
- `:839` `422` — Trading account not found.
- `:850` `422` — This account is a fund manager pool account. Pool accounts cannot be used for investing.
- `:856` `422` — Cannot approve: fund manager account has negative balance. Please try again later.
- `:865` `422` — Investor account has no available balance to lock.

##### `POST /api/user/pmam/manager/investor-requests/{id}/reject`

- **Frontend:** `pmamService.rejectInvestorRequest` (`src/services/pmam.service.js:49`)
- **Triggered from:** `confirmReject`
- **Backend:** `PmamApiController@rejectInvestorRequest` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1006-1022`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1021`
```json
{
  "status": 200,
  "success": true,
  "message": "Investor request rejected.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:1012` `403` — Not authorized.
- `:1016` `422` — Request is not pending.

</details>

### Manager — Investors — `/pmam/manager/investors`

Component: `src/components/pmam/PmamManagerInvestors.vue` — **5 APIs**

1. `GET /api/user/pmam/manager/investors` → `PmamApiController@getManagerInvestors`
2. `GET /api/user/pmam/manager/investors/{investorId}/detail` → `PmamApiController@getInvestorDetail`
3. `GET /api/user/pmam/manager/plans` → `PmamApiController@getManagerPlans`
4. `POST /api/user/pmam/manager/investor-requests/{id}/approve` → `PmamApiController@approveInvestorRequest`
5. `POST /api/user/pmam/manager/investor-requests/{id}/reject` → `PmamApiController@rejectInvestorRequest`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/manager/investors`

- **Frontend:** `pmamService.getManagerInvestors` (`src/services/pmam.service.js:258`)
- **Triggered from:** `loadData`, `approveInvestor`, `rejectInvestor`
- **Backend:** `PmamApiController@getManagerInvestors` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:675-710`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:681`
```json
{
  "success": "...",
  "data": "..."
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:709`
```json
{
  "status": 200,
  "success": true,
  "message": "Investors retrieved",
  "data": "<$investors>"
}
```

##### `GET /api/user/pmam/manager/investors/{investorId}/detail`

- **Frontend:** `pmamService.getInvestorDetail` (`src/services/pmam.service.js:121`)
- **Triggered from:** `openInvestorDetail`
- **Backend:** `PmamApiController@getInvestorDetail` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1428-1499`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1481`
```json
{
  "status": 200,
  "success": true,
  "message": "Investor detail retrieved",
  "data": {
    "investor": "...",
    "id": "...",
    "investor_name": "...",
    "investor_email": "...",
    "account_number": "...",
    "plan_id": "...",
    "plan_name": "...",
    "invested_amount": "...",
    "total_pnl": "...",
    "current_value": "...",
    "allocation_pct": "...",
    "status": "...",
    "open_allocations": "...",
    "distributions": "...",
    "fund_entries": "..."
  }
}
```

##### `GET /api/user/pmam/manager/plans`

- **Frontend:** `pmamService.getManagerPlans` (`src/services/pmam.service.js:231`)
- **Triggered from:** `loadData`
- **Backend:** `PmamApiController@getManagerPlans` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:378-420`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:384`
```json
{
  "success": "...",
  "data": "..."
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:419`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "<$plans>"
}
```

##### `POST /api/user/pmam/manager/investor-requests/{id}/approve`

- **Frontend:** `pmamService.approveInvestorRequest` (`src/services/pmam.service.js:40`)
- **Triggered from:** `approveInvestor`
- **Backend:** `PmamApiController@approveInvestorRequest` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:821-1000`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:999`
```json
{
  "status": 200,
  "success": true,
  "message": "Investor request approved. Account locked and funds deposited into pool.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:828` `403` — Not authorized.
- `:832` `422` — Request is not pending.
- `:839` `422` — Trading account not found.
- `:850` `422` — This account is a fund manager pool account. Pool accounts cannot be used for investing.
- `:856` `422` — Cannot approve: fund manager account has negative balance. Please try again later.
- `:865` `422` — Investor account has no available balance to lock.

##### `POST /api/user/pmam/manager/investor-requests/{id}/reject`

- **Frontend:** `pmamService.rejectInvestorRequest` (`src/services/pmam.service.js:49`)
- **Triggered from:** `rejectInvestor`
- **Backend:** `PmamApiController@rejectInvestorRequest` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1006-1022`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:1021`
```json
{
  "status": 200,
  "success": true,
  "message": "Investor request rejected.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:1012` `403` — Not authorized.
- `:1016` `422` — Request is not pending.

</details>

### Manager — Commissions — `/pmam/manager/commissions`

Component: `src/components/pmam/PmamManagerCommissions.vue` — **2 APIs**

1. `GET /api/user/pmam/manager/commissions` → `PmamApiController@getCommissionsList`
2. `GET /api/user/pmam/manager/plans` → `PmamApiController@getManagerPlans`

<details><summary>Request / response details</summary>

##### `GET /api/user/pmam/manager/commissions`

- **Frontend:** `pmamService.getManagerCommissionsList` (`src/services/pmam.service.js:332`)
- **Triggered from:** `reload`
- **Backend:** `PmamApiController@getCommissionsList` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2882-2971`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2898`
```json
{
  "status": 200,
  "success": true,
  "message": "No commissions yet",
  "data": {
    "data": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "..."
  }
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:2964`
```json
{
  "status": 200,
  "success": true,
  "message": "Commissions retrieved",
  "data": {
    "data": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "..."
  }
}
```

**Errors** (`success: false`)
- `:2888` `404` — Manager not found.

##### `GET /api/user/pmam/manager/plans`

- **Frontend:** `pmamService.getManagerPlans` (`src/services/pmam.service.js:231`)
- **Triggered from:** `loadPlans`
- **Backend:** `PmamApiController@getManagerPlans` — `core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:378-420`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:384`
```json
{
  "success": "...",
  "data": "..."
}
```
`core/Modules/PMAM/app/Http/Controllers/Api/PmamApiController.php:419`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "<$plans>"
}
```

</details>

---

## Copy Trading

> Menu shown only when VITE_COPY_TRADING_ENABLED is true.

### Leaderboard — `/copy-trade`

Component: `src/components/copytrading/CopyTradingLeaderboard.vue` — **7 APIs**

1. `GET /api/copytrading/masters/search` → `CopyTradingApiController@searchPublicMasters`
2. `GET /api/copytrading/plans` → `CopyTradingApiController@getPublicPlans`
3. `GET /api/copytrading/plans/search` → `CopyTradingApiController@searchPublicPlans`
4. `GET /api/user/copytrading/copier/eligible-accounts` → `CopyTradingApiController@getCopierEligibleAccounts`
5. `GET /api/user/copytrading/copier/masters/{code}` → `CopyTradingApiController@getCopierMasterProfile`
6. `GET /api/user/copytrading/copier/subscriptions` → `CopyTradingApiController@getMySubscriptions`
7. `POST /api/user/copytrading/copier/subscribe` → `CopyTradingApiController@subscribeAsCopier`

<details><summary>Request / response details</summary>

##### `GET /api/copytrading/masters/search`

- **Frontend:** `copytradingService.public.searchMasters` (`src/services/copytrading.service.js:581`)
- **Triggered from:** `searchMasterOptions`
- **Backend:** `CopyTradingApiController@searchPublicMasters` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4413-4450`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4417`
```json
{
  "status": 200,
  "success": true,
  "message": "Masters found",
  "data": "..."
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4449`
```json
{
  "status": 200,
  "success": true,
  "message": "Masters found",
  "data": "<$masters>"
}
```

##### `GET /api/copytrading/plans`

- **Frontend:** `copytradingService.public.getPlans` (`src/services/copytrading.service.js:567`)
- **Triggered from:** `loadMasters`
- **Backend:** `CopyTradingApiController@getPublicPlans` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4524-4640`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4639`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans list retrieved",
  "data": "<$plans>"
}
```

##### `GET /api/copytrading/plans/search`

- **Frontend:** `copytradingService.public.searchPlans` (`src/services/copytrading.service.js:596`)
- **Triggered from:** `searchPlanOptions`
- **Backend:** `CopyTradingApiController@searchPublicPlans` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4464-4503`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4468`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans found",
  "data": "..."
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4502`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans found",
  "data": "<$plans>"
}
```

##### `GET /api/user/copytrading/copier/eligible-accounts`

- **Frontend:** `copytradingService.copier.getEligibleAccounts` (`src/services/copytrading.service.js:351`)
- **Triggered from:** `loadEligibleAccounts`
- **Backend:** `CopyTradingApiController@getCopierEligibleAccounts` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3037-3170`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3169`
```json
{
  "status": 200,
  "success": true,
  "message": "Eligible accounts retrieved",
  "data": "<$accounts->values()>"
}
```

##### `GET /api/user/copytrading/copier/masters/{code}`

- **Frontend:** `copytradingService.copier.getMasterProfile` (`src/services/copytrading.service.js:323`)
- **Triggered from:** `loadMasterPlans`
- **Backend:** `CopyTradingApiController@getCopierMasterProfile` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2933-3029`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3016`
```json
{
  "status": 200,
  "success": true,
  "message": "Master profile retrieved",
  "data": {
    "master_code": "...",
    "master_nickname": "...",
    "master_name": "...",
    "server_type": "...",
    "lp_provider_name": "...",
    "strategy_description": "...",
    "risk_information": "...",
    "risk_score": "...",
    "total_plans": "...",
    "approved_plans": "...",
    "pending_plans": "..."
  }
}
```

**Errors** (`success: false`)
- `:2941` `404` — Master not found

##### `GET /api/user/copytrading/copier/subscriptions`

- **Frontend:** `copytradingService.copier.getSubscriptions` (`src/services/copytrading.service.js:377`)
- **Triggered from:** `submitSubscribe`
- **Backend:** `CopyTradingApiController@getMySubscriptions` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3546-3637`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3636`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscriptions retrieved",
  "data": "<$subscriptions>"
}
```

##### `POST /api/user/copytrading/copier/subscribe`

- **Frontend:** `copytradingService.copier.subscribe` (`src/services/copytrading.service.js:364`)
- **Triggered from:** `submitSubscribe`
- **Backend:** `CopyTradingApiController@subscribeAsCopier` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3175-3541`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `plan_id`, `mt5_account_id`, `investment_amount`, `copying_method`, `sizing_method`, `fixed_lot_size`, `lot_multiplier`, `mirror_ratio`, `is_reverse`, `risk_percent`, `dynamic_lot_rules`, `dynamic_lot_rules.drawdown_threshold_pct`, `dynamic_lot_rules.multiplier`, `fixed_ratio_rules`, `fixed_ratio_rules.profit_step`, `fixed_ratio_rules.lot_step`, `copy_open_trades`, `overrides_sl_tp`, `sl_tp_mode`, `take_profit_pips`, `stop_loss_pips`, `take_profit_dollar`, `stop_loss_dollar`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3533`
```json
{
  "status": 200,
  "success": true,
  "message": "Successfully subscribed to copy trading plan.",
  "data": {
    "id": "...",
    "status": "...",
    "plan_id": "...",
    "plan_name": "...",
    "master_code": "...",
    "master_nickname": "..."
  }
}
```

**Errors** (`success: false`)
- `:3216` `422` — At least one of TP or SL is required when overriding master TP/SL.
- `:3227` `422` — Trading account not found or does not belong to you.
- `:3235` `422` — ($copierGate['message'], false, [], 422)
- `:3252` `404` — Plan not found or not approved.
- `:3256` `422` — This plan is paused and is not accepting new copiers.
- `:3267` `422` — This plan\

</details>

### Master profile — `/copy-trade/master/:code`

Component: `src/components/copytrading/CopyTradingMasterProfile.vue` — **6 APIs**

1. `GET /api/copytrading/masters/{code}` → `CopyTradingApiController@getPublicMasterProfile`
2. `GET /api/copytrading/masters/{code}/trade-history` → `CopyTradingApiController@getPublicMasterTradeHistory`
3. `GET /api/user/copytrading/copier/eligible-accounts` → `CopyTradingApiController@getCopierEligibleAccounts`
4. `GET /api/user/copytrading/copier/masters/{code}` → `CopyTradingApiController@getCopierMasterProfile`
5. `GET /api/user/copytrading/copier/subscriptions` → `CopyTradingApiController@getMySubscriptions`
6. `POST /api/user/copytrading/copier/subscribe` → `CopyTradingApiController@subscribeAsCopier`

<details><summary>Request / response details</summary>

##### `GET /api/copytrading/masters/{code}`

- **Frontend:** `copytradingService.public.getMasterProfile` (`src/services/copytrading.service.js:610`)
- **Triggered from:** `loadMaster`
- **Backend:** `CopyTradingApiController@getPublicMasterProfile` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4858-5058`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:5025`
```json
{
  "status": 200,
  "success": true,
  "message": "Master profile retrieved",
  "data": {
    "master_code": "...",
    "master_nickname": "...",
    "master_name": "...",
    "server_type": "...",
    "account_currency": "...",
    "lp_provider_name": "...",
    "strategy_description": "...",
    "risk_information": "...",
    "risk_score": "...",
    "member_since": "...",
    "with_us_days": "...",
    "total_plans": "...",
    "total_copiers": "...",
    "hide_copiers": "...",
    "total_pnl": "...",
    "total_gain": "...",
    "total_gain_percent": "...",
    "win_rate": "...",
    "max_drawdown": "...",
    "master_equity": "...",
    "plans": "...",
    "open_positions": "...",
    "performance_series": "...",
    "performance_window": "...",
    "timeframe": "...",
    "profile_scope": "...",
    "selected_plan_id": "..."
  }
}
```

**Errors** (`success: false`)
- `:4871` `404` — Master not found
- `:4880` `422` — Invalid plan_id.
- `:4888` `422` — Plan not found or not approved for this master.

##### `GET /api/copytrading/masters/{code}/trade-history`

- **Frontend:** `copytradingService.public.getMasterTradeHistory` (`src/services/copytrading.service.js:624`)
- **Triggered from:** `loadTradeHistory`
- **Backend:** `CopyTradingApiController@getPublicMasterTradeHistory` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4646-4744`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4686`
```json
{
  "status": 200,
  "success": true,
  "message": "Master trade history retrieved",
  "data": {
    "data": "...",
    "pagination": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "...",
    "timeframe": "...",
    "selected_plan_id": "..."
  }
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4707`
```json
{
  "status": 200,
  "success": true,
  "message": "Master trade history retrieved",
  "data": {
    "data": "...",
    "pagination": "...",
    "timeframe": "...",
    "selected_plan_id": "..."
  }
}
```

**Errors** (`success: false`)
- `:4656` `404` — Master not found
- `:4664` `422` — Invalid plan_id.
- `:4671` `422` — Plan not found or not approved for this master.

##### `GET /api/user/copytrading/copier/eligible-accounts`

- **Frontend:** `copytradingService.copier.getEligibleAccounts` (`src/services/copytrading.service.js:351`)
- **Triggered from:** `loadEligibleAccounts`
- **Backend:** `CopyTradingApiController@getCopierEligibleAccounts` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3037-3170`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3169`
```json
{
  "status": 200,
  "success": true,
  "message": "Eligible accounts retrieved",
  "data": "<$accounts->values()>"
}
```

##### `GET /api/user/copytrading/copier/masters/{code}`

- **Frontend:** `copytradingService.copier.getMasterProfile` (`src/services/copytrading.service.js:323`)
- **Triggered from:** `loadMasterPlans`
- **Backend:** `CopyTradingApiController@getCopierMasterProfile` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2933-3029`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3016`
```json
{
  "status": 200,
  "success": true,
  "message": "Master profile retrieved",
  "data": {
    "master_code": "...",
    "master_nickname": "...",
    "master_name": "...",
    "server_type": "...",
    "lp_provider_name": "...",
    "strategy_description": "...",
    "risk_information": "...",
    "risk_score": "...",
    "total_plans": "...",
    "approved_plans": "...",
    "pending_plans": "..."
  }
}
```

**Errors** (`success: false`)
- `:2941` `404` — Master not found

##### `GET /api/user/copytrading/copier/subscriptions`

- **Frontend:** `copytradingService.copier.getSubscriptions` (`src/services/copytrading.service.js:377`)
- **Triggered from:** `submitSubscribe`
- **Backend:** `CopyTradingApiController@getMySubscriptions` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3546-3637`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3636`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscriptions retrieved",
  "data": "<$subscriptions>"
}
```

##### `POST /api/user/copytrading/copier/subscribe`

- **Frontend:** `copytradingService.copier.subscribe` (`src/services/copytrading.service.js:364`)
- **Triggered from:** `submitSubscribe`
- **Backend:** `CopyTradingApiController@subscribeAsCopier` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3175-3541`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `plan_id`, `mt5_account_id`, `investment_amount`, `copying_method`, `sizing_method`, `fixed_lot_size`, `lot_multiplier`, `mirror_ratio`, `is_reverse`, `risk_percent`, `dynamic_lot_rules`, `dynamic_lot_rules.drawdown_threshold_pct`, `dynamic_lot_rules.multiplier`, `fixed_ratio_rules`, `fixed_ratio_rules.profit_step`, `fixed_ratio_rules.lot_step`, `copy_open_trades`, `overrides_sl_tp`, `sl_tp_mode`, `take_profit_pips`, `stop_loss_pips`, `take_profit_dollar`, `stop_loss_dollar`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3533`
```json
{
  "status": 200,
  "success": true,
  "message": "Successfully subscribed to copy trading plan.",
  "data": {
    "id": "...",
    "status": "...",
    "plan_id": "...",
    "plan_name": "...",
    "master_code": "...",
    "master_nickname": "..."
  }
}
```

**Errors** (`success: false`)
- `:3216` `422` — At least one of TP or SL is required when overriding master TP/SL.
- `:3227` `422` — Trading account not found or does not belong to you.
- `:3235` `422` — ($copierGate['message'], false, [], 422)
- `:3252` `404` — Plan not found or not approved.
- `:3256` `422` — This plan is paused and is not accepting new copiers.
- `:3267` `422` — This plan\

</details>

### My Investments (copier dashboard) — `/copy-trading/dashboard`

Component: `src/components/copytrading/CopyTradingCopierDashboard.vue` — **5 APIs**

1. `GET /api/user/copytrading/copier/subscriptions` → `CopyTradingApiController@getMySubscriptions`
2. `POST /api/user/copytrading/copier/subscriptions/{id}/pause` → `CopyTradingApiController@pauseMySubscription`
3. `POST /api/user/copytrading/copier/subscriptions/{id}/resume` → `CopyTradingApiController@resumeMySubscription`
4. `POST /api/user/copytrading/copier/subscriptions/{id}/stop` → `CopyTradingApiController@stopMySubscription`
5. `PUT /api/user/copytrading/copier/subscriptions/{id}/update` → `CopyTradingApiController@updateMySubscription`

<details><summary>Request / response details</summary>

##### `GET /api/user/copytrading/copier/subscriptions`

- **Frontend:** `copytradingService.copier.getSubscriptions` (`src/services/copytrading.service.js:377`)
- **Triggered from:** `loadSubscriptions`, `pauseSubscription`, `resumeSubscription`, `stopSubscription`, `stop_loss_dollar`
- **Backend:** `CopyTradingApiController@getMySubscriptions` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3546-3637`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3636`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscriptions retrieved",
  "data": "<$subscriptions>"
}
```

##### `POST /api/user/copytrading/copier/subscriptions/{id}/pause`

- **Frontend:** `copytradingService.copier.pause` (`src/services/copytrading.service.js:403`)
- **Triggered from:** `pauseSubscription`
- **Backend:** `CopyTradingApiController@pauseMySubscription` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3760-3785`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3784`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription paused successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:3770` `404` — Active subscription not found.
- `:3776` `422` — ($result['message'] ?? 'Failed to pause subscription.', false, [], 422)

##### `POST /api/user/copytrading/copier/subscriptions/{id}/resume`

- **Frontend:** `copytradingService.copier.resume` (`src/services/copytrading.service.js:416`)
- **Triggered from:** `resumeSubscription`
- **Backend:** `CopyTradingApiController@resumeMySubscription` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3790-3828`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3827`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription resumed successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:3801` `404` — Paused subscription not found.
- `:3809` `403` — This master has been deactivated by the administrator. Your subscription will resume automatically once the master is reactivated.
- `:3813` `403` — This plan is currently paused by the master. You can resume once copying is active again.
- `:3819` `422` — ($result['message'] ?? 'Failed to resume subscription.', false, [], 422)

##### `POST /api/user/copytrading/copier/subscriptions/{id}/stop`

- **Frontend:** `copytradingService.copier.stop` (`src/services/copytrading.service.js:429`)
- **Triggered from:** `stopSubscription`
- **Backend:** `CopyTradingApiController@stopMySubscription` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3833-3858`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3857`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription stopped successfully. Your capital has been released.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:3843` `404` — Subscription not found.
- `:3849` `422` — ($result['message'] ?? 'Failed to stop subscription.', false, [], 422)

##### `PUT /api/user/copytrading/copier/subscriptions/{id}/update`

- **Frontend:** `copytradingService.copier.updateSubscription` (`src/services/copytrading.service.js:534`)
- **Triggered from:** `stop_loss_dollar`
- **Backend:** `CopyTradingApiController@updateMySubscription` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4158-4257`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `copying_method`, `sizing_method`, `fixed_lot_size`, `lot_multiplier`, `mirror_ratio`, `is_reverse`, `risk_percent`, `dynamic_lot_rules`, `dynamic_lot_rules.drawdown_threshold_pct`, `dynamic_lot_rules.multiplier`, `fixed_ratio_rules`, `fixed_ratio_rules.profit_step`, `fixed_ratio_rules.lot_step`, `overrides_sl_tp`, `sl_tp_mode`, `take_profit_pips`, `stop_loss_pips`, `take_profit_dollar`, `stop_loss_dollar`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4252`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription updated successfully.",
  "data": {
    "copier_id": "...",
    "copy_method": "...",
    "lot_multiplier": "..."
  }
}
```

**Errors** (`success: false`)
- `:4192` `404` — Active or paused subscription not found.
- `:4196` `422` — fixed_lot_size is required when copying_method is fixed.
- `:4199` `422` — fixed_lot_size is required when sizing_method is fixed.
- `:4202` `422` — mirror_ratio is required when sizing_method is mirror_ratio.
- `:4205` `422` — risk_percent is required when sizing_method is percentage_risk.
- `:4208` `422` — dynamic_lot_rules is required when sizing_method is dynamic_lot.

</details>

### Subscription detail — `/copy-trading/dashboard/subscription/:id`

Component: `src/components/copytrading/CopyTradingCopierSubscriptionDetail.vue` — **7 APIs**

1. `GET /api/user/copytrading/copier/subscriptions` → `CopyTradingApiController@getMySubscriptions`
2. `GET /api/user/copytrading/copier/subscriptions/{id}/commission-history` → `CopyTradingApiController@getMyCommissionHistory`
3. `GET /api/user/copytrading/copier/subscriptions/{id}/detail` → `CopyTradingApiController@getMySubscriptionDetail`
4. `GET /api/user/copytrading/copier/subscriptions/{id}/trades` → `CopyTradingApiController@getMyTrades`
5. `POST /api/user/copytrading/copier/subscriptions/{id}/pause` → `CopyTradingApiController@pauseMySubscription`
6. `POST /api/user/copytrading/copier/subscriptions/{id}/resume` → `CopyTradingApiController@resumeMySubscription`
7. `POST /api/user/copytrading/copier/subscriptions/{id}/stop` → `CopyTradingApiController@stopMySubscription`

<details><summary>Request / response details</summary>

##### `GET /api/user/copytrading/copier/subscriptions`

- **Frontend:** `copytradingService.copier.getSubscriptions` (`src/services/copytrading.service.js:377`)
- **Triggered from:** `pauseSubscription`, `resumeSubscription`, `stopSubscription`
- **Backend:** `CopyTradingApiController@getMySubscriptions` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3546-3637`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3636`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscriptions retrieved",
  "data": "<$subscriptions>"
}
```

##### `GET /api/user/copytrading/copier/subscriptions/{id}/commission-history`

- **Frontend:** `copytradingService.copier.getMyCommissionHistory` (`src/services/copytrading.service.js:488`)
- **Triggered from:** `loadCommissionHistory`
- **Backend:** `CopyTradingApiController@getMyCommissionHistory` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4008-4090`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4076`
```json
{
  "status": 200,
  "success": true,
  "message": "Commission history retrieved",
  "data": {
    "data": "...",
    "summary": "...",
    "trades": "...",
    "billable_trades": "...",
    "total_commission": "...",
    "avg_per_trade": "...",
    "avg_per_billable_trade": "...",
    "total": "...",
    "current_page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```

**Errors** (`success: false`)
- `:4016` `404` — Subscription not found.

##### `GET /api/user/copytrading/copier/subscriptions/{id}/detail`

- **Frontend:** `copytradingService.copier.getSubscriptionDetail` (`src/services/copytrading.service.js:390`)
- **Triggered from:** `loadSubscriptionDetail`
- **Backend:** `CopyTradingApiController@getMySubscriptionDetail` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3642-3755`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3699`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription detail retrieved",
  "data": {
    "subscription": "...",
    "id": "...",
    "plan_id": "...",
    "plan_name": "...",
    "master_name": "...",
    "master_code": "...",
    "commission_type": "...",
    "commission_percentage": "...",
    "account_number": "...",
    "account_currency": "...",
    "capital_amount": "...",
    "copy_ratio": "...",
    "copy_method": "...",
    "sizing_method": "...",
    "fixed_lot_size": "...",
    "mirror_ratio": "...",
    "is_reverse": "...",
    "risk_percent": "...",
    "dynamic_lot_rules": "...",
    "fixed_ratio_rules": "...",
    "no_fee_until": "...",
    "in_grace_period": "...",
    "total_pnl": "...",
    "total_commission_paid": "...",
    "pending_commission": "...",
    "net_pnl": "...",
    "open_trades_count": "...",
    "closed_trades_count": "...",
    "status": "...",
    "paused_by_master_inactive": "...",
    "master_status": "...",
    "plan_copying_paused": "...",
    "active_since": "...",
    "paused_at": "...",
    "stopped_at": "...",
    "take_profit_pips": "...",
    "stop_loss_pips": "...",
    "lot_multiplier": "...",
    "overrides_sl_tp": "...",
    "sl_tp_mode": "..."
  }
}
```

**Errors** (`success: false`)
- `:3652` `404` — Subscription not found.

##### `GET /api/user/copytrading/copier/subscriptions/{id}/trades`

- **Frontend:** `copytradingService.copier.getMyTrades` (`src/services/copytrading.service.js:443`)
- **Triggered from:** `loadTrades`
- **Backend:** `CopyTradingApiController@getMyTrades` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3863-3936`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3929`
```json
{
  "status": 200,
  "success": true,
  "message": "Trades retrieved",
  "data": {
    "data": "...",
    "total": "...",
    "current_page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```

**Errors** (`success: false`)
- `:3872` `404` — Subscription not found.

##### `POST /api/user/copytrading/copier/subscriptions/{id}/pause`

- **Frontend:** `copytradingService.copier.pause` (`src/services/copytrading.service.js:403`)
- **Triggered from:** `pauseSubscription`
- **Backend:** `CopyTradingApiController@pauseMySubscription` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3760-3785`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3784`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription paused successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:3770` `404` — Active subscription not found.
- `:3776` `422` — ($result['message'] ?? 'Failed to pause subscription.', false, [], 422)

##### `POST /api/user/copytrading/copier/subscriptions/{id}/resume`

- **Frontend:** `copytradingService.copier.resume` (`src/services/copytrading.service.js:416`)
- **Triggered from:** `resumeSubscription`
- **Backend:** `CopyTradingApiController@resumeMySubscription` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3790-3828`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3827`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription resumed successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:3801` `404` — Paused subscription not found.
- `:3809` `403` — This master has been deactivated by the administrator. Your subscription will resume automatically once the master is reactivated.
- `:3813` `403` — This plan is currently paused by the master. You can resume once copying is active again.
- `:3819` `422` — ($result['message'] ?? 'Failed to resume subscription.', false, [], 422)

##### `POST /api/user/copytrading/copier/subscriptions/{id}/stop`

- **Frontend:** `copytradingService.copier.stop` (`src/services/copytrading.service.js:429`)
- **Triggered from:** `stopSubscription`
- **Backend:** `CopyTradingApiController@stopMySubscription` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3833-3858`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3857`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription stopped successfully. Your capital has been released.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:3843` `404` — Subscription not found.
- `:3849` `422` — ($result['message'] ?? 'Failed to stop subscription.', false, [], 422)

</details>

### Master dashboard — `/copy-trading/master/dashboard`

Component: `src/components/copytrading/CopyTradingMasterDashboardPro.vue` — **3 APIs**

1. `GET /api/user/copytrading/master/dashboard-overview` → `CopyTradingApiController@getMasterDashboardOverview`
2. `GET /api/user/copytrading/master/status` → `CopyTradingApiController@getMasterStatus`
3. `POST /api/user/copytrading/master/apply` → `CopyTradingApiController@applyAsMaster`

<details><summary>Request / response details</summary>

##### `GET /api/user/copytrading/master/dashboard-overview`

- **Frontend:** `copytradingService.master.getDashboardOverview` (`src/services/copytrading.service.js:85`)
- **Triggered from:** `loadOverview`
- **Backend:** `CopyTradingApiController@getMasterDashboardOverview` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:512-536`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:521`
```json
{
  "status": 200,
  "success": true,
  "message": "Dashboard overview retrieved",
  "data": "<$this->emptyDashboardOverview($request)>"
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:535`
```json
{
  "status": 200,
  "success": true,
  "message": "Dashboard overview retrieved",
  "data": "<$payload>"
}
```

##### `GET /api/user/copytrading/master/status`

- **Frontend:** `copytradingService.master.getStatus` (`src/services/copytrading.service.js:47`)
- **Triggered from:** `decideMode`, `loadStatus`, `submitApply`
- **Backend:** `CopyTradingApiController@getMasterStatus` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:343-371`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:361`
```json
{
  "status": 200,
  "success": true,
  "message": "No master application found",
  "data": "<null>"
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:364`
```json
{
  "status": 200,
  "success": true,
  "message": "Master status retrieved",
  "data": {
    "status": "...",
    "master_code": "...",
    "master_nickname": "...",
    "inactivated_at": "...",
    "inactivation_reason": "..."
  }
}
```

##### `POST /api/user/copytrading/master/apply`

- **Frontend:** `copytradingService.master.apply` (`src/services/copytrading.service.js:60`)
- **Triggered from:** `submitApply`
- **Backend:** `CopyTradingApiController@applyAsMaster` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:376-446`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `terms_accepted`, `nickname`, `strategy`, `risk_info`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:442`
```json
{
  "status": 200,
  "success": true,
  "message": "Master application submitted successfully.",
  "data": {
    "status": "...",
    "master_code": "..."
  }
}
```

**Errors** (`success: false`)
- `:391` `422` — ($gate['message'], false, [], 422)
- `:401` `422` — Your master account has been deactivated by the administrator. Please contact support to have it reactivated.
- `:404` `422` — You already have an active master application.
- `:413` `422` — ($steps['message'], false, [], 422)

</details>

### Master dashboard (legacy) — `/copy-trading/master/dashboard/legacy`

Component: `src/components/copytrading/CopyTradingMasterDashboard.vue` — **6 APIs**

1. `GET /api/copytrading/masters/{code}` → `CopyTradingApiController@getPublicMasterProfile`
2. `GET /api/user/copytrading/master/dashboard-stats` → `CopyTradingApiController@getMasterDashboardStats`
3. `GET /api/user/copytrading/master/plans` → `CopyTradingApiController@getMasterPlans`
4. `GET /api/user/copytrading/master/plans/{id}/open-positions` → `CopyTradingApiController@getMasterPlanOpenPositions`
5. `GET /api/user/copytrading/master/status` → `CopyTradingApiController@getMasterStatus`
6. `POST /api/user/copytrading/master/apply` → `CopyTradingApiController@applyAsMaster`

<details><summary>Request / response details</summary>

##### `GET /api/copytrading/masters/{code}`

- **Frontend:** `copytradingService.public.getMasterProfile` (`src/services/copytrading.service.js:610`)
- **Triggered from:** `loadPublicProfile`, `refreshPublicProfileSilently`
- **Backend:** `CopyTradingApiController@getPublicMasterProfile` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:4858-5058`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:5025`
```json
{
  "status": 200,
  "success": true,
  "message": "Master profile retrieved",
  "data": {
    "master_code": "...",
    "master_nickname": "...",
    "master_name": "...",
    "server_type": "...",
    "account_currency": "...",
    "lp_provider_name": "...",
    "strategy_description": "...",
    "risk_information": "...",
    "risk_score": "...",
    "member_since": "...",
    "with_us_days": "...",
    "total_plans": "...",
    "total_copiers": "...",
    "hide_copiers": "...",
    "total_pnl": "...",
    "total_gain": "...",
    "total_gain_percent": "...",
    "win_rate": "...",
    "max_drawdown": "...",
    "master_equity": "...",
    "plans": "...",
    "open_positions": "...",
    "performance_series": "...",
    "performance_window": "...",
    "timeframe": "...",
    "profile_scope": "...",
    "selected_plan_id": "..."
  }
}
```

**Errors** (`success: false`)
- `:4871` `404` — Master not found
- `:4880` `422` — Invalid plan_id.
- `:4888` `422` — Plan not found or not approved for this master.

##### `GET /api/user/copytrading/master/dashboard-stats`

- **Frontend:** `copytradingService.master.getDashboardStats` (`src/services/copytrading.service.js:72`)
- **Triggered from:** `loadDashboardStats`
- **Backend:** `CopyTradingApiController@getMasterDashboardStats` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:451-499`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:458`
```json
{
  "status": 200,
  "success": true,
  "message": "Dashboard stats retrieved",
  "data": {
    "plans_count": "...",
    "active_copiers_count": "...",
    "total_aum": "...",
    "commission_earned": "..."
  }
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:492`
```json
{
  "status": 200,
  "success": true,
  "message": "Dashboard stats retrieved",
  "data": {
    "plans_count": "...",
    "active_copiers_count": "...",
    "total_aum": "...",
    "commission_earned": "...",
    "master_account_currency": "..."
  }
}
```

##### `GET /api/user/copytrading/master/plans`

- **Frontend:** `copytradingService.master.getPlans` (`src/services/copytrading.service.js:97`)
- **Triggered from:** `loadPlans`
- **Backend:** `CopyTradingApiController@getMasterPlans` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1184-1201`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1191`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "..."
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1200`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "<$plans>"
}
```

##### `GET /api/user/copytrading/master/plans/{id}/open-positions`

- **Frontend:** `copytradingService.master.getPlanOpenPositions` (`src/services/copytrading.service.js:227`)
- **Triggered from:** `loadAllOpenPositions`
- **Backend:** `CopyTradingApiController@getMasterPlanOpenPositions` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2548-2587`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2586`
```json
{
  "status": 200,
  "success": true,
  "message": "Open positions retrieved",
  "data": "<$mappings>"
}
```

**Errors** (`success: false`)
- `:2554` `422` — Master not found.
- `:2563` `404` — Plan not found.

##### `GET /api/user/copytrading/master/status`

- **Frontend:** `copytradingService.master.getStatus` (`src/services/copytrading.service.js:47`)
- **Triggered from:** `loadData`, `submitApply`
- **Backend:** `CopyTradingApiController@getMasterStatus` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:343-371`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:361`
```json
{
  "status": 200,
  "success": true,
  "message": "No master application found",
  "data": "<null>"
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:364`
```json
{
  "status": 200,
  "success": true,
  "message": "Master status retrieved",
  "data": {
    "status": "...",
    "master_code": "...",
    "master_nickname": "...",
    "inactivated_at": "...",
    "inactivation_reason": "..."
  }
}
```

##### `POST /api/user/copytrading/master/apply`

- **Frontend:** `copytradingService.master.apply` (`src/services/copytrading.service.js:60`)
- **Triggered from:** `submitApply`
- **Backend:** `CopyTradingApiController@applyAsMaster` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:376-446`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `terms_accepted`, `nickname`, `strategy`, `risk_info`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:442`
```json
{
  "status": 200,
  "success": true,
  "message": "Master application submitted successfully.",
  "data": {
    "status": "...",
    "master_code": "..."
  }
}
```

**Errors** (`success: false`)
- `:391` `422` — ($gate['message'], false, [], 422)
- `:401` `422` — Your master account has been deactivated by the administrator. Please contact support to have it reactivated.
- `:404` `422` — You already have an active master application.
- `:413` `422` — ($steps['message'], false, [], 422)

</details>

### Master — Plans — `/copy-trading/master/plans`

Component: `src/components/copytrading/CopyTradingMasterPlans.vue` — **7 APIs**

1. `GET /api/user/copytrading/copier/eligible-accounts` → `CopyTradingApiController@getCopierEligibleAccounts`
2. `GET /api/user/copytrading/master/plans` → `CopyTradingApiController@getMasterPlans`
3. `GET /api/user/copytrading/master/plans/{id}` → `CopyTradingApiController@getMasterPlanDetail`
4. `POST /api/user/copytrading/master/plans` → `CopyTradingApiController@createMasterPlan`
5. `POST /api/user/copytrading/master/plans/{id}/pause` → `CopyTradingApiController@pauseMasterPlan`
6. `POST /api/user/copytrading/master/plans/{id}/resume` → `CopyTradingApiController@resumeMasterPlan`
7. `PUT /api/user/copytrading/master/plans/{id}` → `CopyTradingApiController@updateMasterPlan`

<details><summary>Request / response details</summary>

##### `GET /api/user/copytrading/copier/eligible-accounts`

- **Frontend:** `copytradingService.copier.getEligibleAccounts` (`src/services/copytrading.service.js:351`)
- **Triggered from:** `loadEligibleAccounts`
- **Backend:** `CopyTradingApiController@getCopierEligibleAccounts` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3037-3170`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:3169`
```json
{
  "status": 200,
  "success": true,
  "message": "Eligible accounts retrieved",
  "data": "<$accounts->values()>"
}
```

##### `GET /api/user/copytrading/master/plans`

- **Frontend:** `copytradingService.master.getPlans` (`src/services/copytrading.service.js:97`)
- **Triggered from:** `loadPlans`, `doPause`, `doResume`
- **Backend:** `CopyTradingApiController@getMasterPlans` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1184-1201`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1191`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "..."
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1200`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "<$plans>"
}
```

##### `GET /api/user/copytrading/master/plans/{id}`

- **Frontend:** `copytradingService.master.getPlanDetail` (`src/services/copytrading.service.js:200`)
- **Triggered from:** `loadPlan`
- **Backend:** `CopyTradingApiController@getMasterPlanDetail` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1625-2136`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2043`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan detail retrieved",
  "data": {
    "id": "...",
    "plan_name": "...",
    "server_type": "...",
    "trading_server": "...",
    "lp_provider_name": "...",
    "trading_account_number": "...",
    "initial_equity_snapshot": "...",
    "initial_equity_captured_at": "...",
    "strategy_description": "...",
    "risk_information": "...",
    "commission_type": "...",
    "commission_label": "...",
    "commission_percentage": "...",
    "subscription_fee": "...",
    "subscription_period_days": "...",
    "no_fee_days": "...",
    "minimum_capital": "...",
    "copy_ratio": "...",
    "max_copiers": "...",
    "is_full": "...",
    "total_capital": "...",
    "active_copiers": "...",
    "total_commission_earned": "...",
    "open_positions": "...",
    "currency": "...",
    "status": "...",
    "rejection_reason": "...",
    "approved_at": "...",
    "approved_by": "...",
    "copying_paused": "...",
    "copying_paused_at": "...",
    "paused_by_master_inactive": "...",
    "master_status": "...",
    "created_at": "...",
    "updated_at": "...",
    "trade_history": "...",
    "commission_history": "...",
    "copiers": "...",
    "copiers_total": "...",
    "open_positions_detail": "..."
  }
}
```

**Errors** (`success: false`)
- `:1631` `422` — Master not found.
- `:1640` `404` — Plan not found.

##### `POST /api/user/copytrading/master/plans`

- **Frontend:** `copytradingService.master.createPlan` (`src/services/copytrading.service.js:136`)
- **Triggered from:** `handleSubmit`
- **Backend:** `CopyTradingApiController@createMasterPlan` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1206-1357`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `trading_account_id`, `name`, `plan_name`, `strategy_description`, `risk_info`, `commission_value`, `settlement_cycle`, `no_fee_days`, `min_capital`, `copy_ratio`, `max_copiers`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1356`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": "<$this->formatPlanForApi($plan)>"
}
```

**Errors** (`success: false`)
- `:1232` `422` — CopyTrading is currently read-only. New plans cannot be created.
- `:1238` `422` — ($commissionCapCheck['message'], false, [], 422)
- `:1244` `422` — ($minCapitalFloorCheck['message'], false, [], 422)
- `:1253` `422` — You do not have an approved master account.
- `:1261` `422` — Trading account not found or does not belong to you.
- `:1266` `422` — Your trading account has an unknown server type. Please contact support.

##### `POST /api/user/copytrading/master/plans/{id}/pause`

- **Frontend:** `copytradingService.master.pausePlan` (`src/services/copytrading.service.js:162`)
- **Triggered from:** `doPause`
- **Backend:** `CopyTradingApiController@pauseMasterPlan` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1527-1568`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1564`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan paused. Copying is suspended until you resume.",
  "data": {
    "copying_paused": "...",
    "copying_paused_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:1533` `422` — Master not found.
- `:1537` `403` — Your master account has been deactivated by the administrator. Contact support to have it reactivated.
- `:1545` `404` — Plan not found.
- `:1549` `422` — Only approved plans can be paused.
- `:1553` `422` — Plan is already paused.

##### `POST /api/user/copytrading/master/plans/{id}/resume`

- **Frontend:** `copytradingService.master.resumePlan` (`src/services/copytrading.service.js:174`)
- **Triggered from:** `doResume`
- **Backend:** `CopyTradingApiController@resumeMasterPlan` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1573-1620`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1616`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan resumed. Copying is active again.",
  "data": {
    "copying_paused": "...",
    "copying_paused_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:1579` `422` — Master not found.
- `:1583` `403` — Your master account has been deactivated by the administrator. Contact support to have it reactivated.
- `:1591` `404` — Plan not found.
- `:1595` `422` — Only approved plans can be resumed.
- `:1599` `422` — Plan is not paused.
- `:1606` `403` — This plan was paused by the administrator and can only be resumed by them.

##### `PUT /api/user/copytrading/master/plans/{id}`

- **Frontend:** `copytradingService.master.updatePlan` (`src/services/copytrading.service.js:150`)
- **Triggered from:** `handleSubmit`
- **Backend:** `CopyTradingApiController@updateMasterPlan` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1402-1522`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `plan_name`, `name`, `strategy_description`, `risk_info`, `commission_value`, `settlement_cycle`, `no_fee_days`, `min_capital`, `copy_ratio`, `max_copiers`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1521`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan updated.",
  "data": "<$this->formatPlanForApi($plan)>"
}
```

**Errors** (`success: false`)
- `:1408` `422` — Master not found.
- `:1416` `404` — Plan not found.
- `:1420` `403` — Your master account has been deactivated by the administrator. Contact support to have it reactivated.
- `:1424` `422` — Only pending or approved plans can be updated.
- `:1455` `422` — You already have a plan with this name.
- `:1475` `422` — ($capCheck['message'], false, [], 422)

</details>

### Master — Plan detail — `/copy-trading/master/plan/:id`

Component: `src/components/copytrading/CopyTradingMasterPlanDetail.vue` — **6 APIs**

1. `GET /api/user/copytrading/master/plans` → `CopyTradingApiController@getMasterPlans`
2. `GET /api/user/copytrading/master/plans/{id}` → `CopyTradingApiController@getMasterPlanDetail`
3. `POST /api/user/copytrading/master/plans/{id}/inactivate` → `CopyTradingApiController@inactivateMasterPlan`
4. `POST /api/user/copytrading/master/plans/{id}/pause` → `CopyTradingApiController@pauseMasterPlan`
5. `POST /api/user/copytrading/master/plans/{id}/resume` → `CopyTradingApiController@resumeMasterPlan`
6. `PUT /api/user/copytrading/master/plans/{id}` → `CopyTradingApiController@updateMasterPlan`

<details><summary>Request / response details</summary>

##### `GET /api/user/copytrading/master/plans`

- **Frontend:** `copytradingService.master.getPlans` (`src/services/copytrading.service.js:97`)
- **Triggered from:** `doPause`, `doResume`
- **Backend:** `CopyTradingApiController@getMasterPlans` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1184-1201`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1191`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "..."
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1200`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "<$plans>"
}
```

##### `GET /api/user/copytrading/master/plans/{id}`

- **Frontend:** `copytradingService.master.getPlanDetail` (`src/services/copytrading.service.js:200`)
- **Triggered from:** `loadPlan`
- **Backend:** `CopyTradingApiController@getMasterPlanDetail` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1625-2136`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2043`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan detail retrieved",
  "data": {
    "id": "...",
    "plan_name": "...",
    "server_type": "...",
    "trading_server": "...",
    "lp_provider_name": "...",
    "trading_account_number": "...",
    "initial_equity_snapshot": "...",
    "initial_equity_captured_at": "...",
    "strategy_description": "...",
    "risk_information": "...",
    "commission_type": "...",
    "commission_label": "...",
    "commission_percentage": "...",
    "subscription_fee": "...",
    "subscription_period_days": "...",
    "no_fee_days": "...",
    "minimum_capital": "...",
    "copy_ratio": "...",
    "max_copiers": "...",
    "is_full": "...",
    "total_capital": "...",
    "active_copiers": "...",
    "total_commission_earned": "...",
    "open_positions": "...",
    "currency": "...",
    "status": "...",
    "rejection_reason": "...",
    "approved_at": "...",
    "approved_by": "...",
    "copying_paused": "...",
    "copying_paused_at": "...",
    "paused_by_master_inactive": "...",
    "master_status": "...",
    "created_at": "...",
    "updated_at": "...",
    "trade_history": "...",
    "commission_history": "...",
    "copiers": "...",
    "copiers_total": "...",
    "open_positions_detail": "..."
  }
}
```

**Errors** (`success: false`)
- `:1631` `422` — Master not found.
- `:1640` `404` — Plan not found.

##### `POST /api/user/copytrading/master/plans/{id}/inactivate`

- **Frontend:** `copytradingService.master.inactivatePlan` (`src/services/copytrading.service.js:187`)
- **Triggered from:** `doInactivate`
- **Backend:** `CopyTradingApiController@inactivateMasterPlan` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1363-1397`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1396`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan inactivated successfully.",
  "data": {
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:1369` `422` — Master not found.
- `:1378` `404` — Plan not found.
- `:1382` `403` — Your master account has been deactivated by the administrator. Contact support to have it reactivated.
- `:1386` `422` — Only approved plans can be inactivated.
- `:1390` `422` — Cannot inactivate plan with active copiers.

##### `POST /api/user/copytrading/master/plans/{id}/pause`

- **Frontend:** `copytradingService.master.pausePlan` (`src/services/copytrading.service.js:162`)
- **Triggered from:** `doPause`
- **Backend:** `CopyTradingApiController@pauseMasterPlan` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1527-1568`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1564`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan paused. Copying is suspended until you resume.",
  "data": {
    "copying_paused": "...",
    "copying_paused_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:1533` `422` — Master not found.
- `:1537` `403` — Your master account has been deactivated by the administrator. Contact support to have it reactivated.
- `:1545` `404` — Plan not found.
- `:1549` `422` — Only approved plans can be paused.
- `:1553` `422` — Plan is already paused.

##### `POST /api/user/copytrading/master/plans/{id}/resume`

- **Frontend:** `copytradingService.master.resumePlan` (`src/services/copytrading.service.js:174`)
- **Triggered from:** `doResume`
- **Backend:** `CopyTradingApiController@resumeMasterPlan` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1573-1620`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1616`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan resumed. Copying is active again.",
  "data": {
    "copying_paused": "...",
    "copying_paused_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:1579` `422` — Master not found.
- `:1583` `403` — Your master account has been deactivated by the administrator. Contact support to have it reactivated.
- `:1591` `404` — Plan not found.
- `:1595` `422` — Only approved plans can be resumed.
- `:1599` `422` — Plan is not paused.
- `:1606` `403` — This plan was paused by the administrator and can only be resumed by them.

##### `PUT /api/user/copytrading/master/plans/{id}`

- **Frontend:** `copytradingService.master.updatePlan` (`src/services/copytrading.service.js:150`)
- **Triggered from:** `handleSubmit`
- **Backend:** `CopyTradingApiController@updateMasterPlan` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1402-1522`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `plan_name`, `name`, `strategy_description`, `risk_info`, `commission_value`, `settlement_cycle`, `no_fee_days`, `min_capital`, `copy_ratio`, `max_copiers`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1521`
```json
{
  "status": 200,
  "success": true,
  "message": "Plan updated.",
  "data": "<$this->formatPlanForApi($plan)>"
}
```

**Errors** (`success: false`)
- `:1408` `422` — Master not found.
- `:1416` `404` — Plan not found.
- `:1420` `403` — Your master account has been deactivated by the administrator. Contact support to have it reactivated.
- `:1424` `422` — Only pending or approved plans can be updated.
- `:1455` `422` — You already have a plan with this name.
- `:1475` `422` — ($capCheck['message'], false, [], 422)

</details>

### Master — Copiers — `/copy-trading/master/copiers`

Component: `src/components/copytrading/CopyTradingMasterCopiers.vue` — **3 APIs**

1. `GET /api/user/copytrading/master/copiers` → `CopyTradingApiController@getMasterAllCopiers`
2. `GET /api/user/copytrading/master/copiers/{copierId}/subscription-history` → `CopyTradingApiController@getMasterCopierSubscriptionHistory`
3. `GET /api/user/copytrading/master/plans` → `CopyTradingApiController@getMasterPlans`

<details><summary>Request / response details</summary>

##### `GET /api/user/copytrading/master/copiers`

- **Frontend:** `copytradingService.master.getAllCopiers` (`src/services/copytrading.service.js:109`)
- **Triggered from:** `q`
- **Backend:** `CopyTradingApiController@getMasterAllCopiers` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2358-2543`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2535`
```json
{
  "status": 200,
  "success": true,
  "message": "Copiers retrieved",
  "data": {
    "summary": "...",
    "data": "...",
    "total": "...",
    "current_page": "...",
    "per_page": "...",
    "total_pages": "..."
  }
}
```

**Errors** (`success: false`)
- `:2364` `422` — Master not found.

##### `GET /api/user/copytrading/master/copiers/{copierId}/subscription-history`

- **Frontend:** `copytradingService.master.getCopierSubscriptionHistory` (`src/services/copytrading.service.js:123`)
- **Triggered from:** `openHistoryDrawer`
- **Backend:** `CopyTradingApiController@getMasterCopierSubscriptionHistory` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2182-2276`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2264`
```json
{
  "status": 200,
  "success": true,
  "message": "Subscription history retrieved",
  "data": {
    "copier": "...",
    "id": "...",
    "user_name": "...",
    "account_number": "...",
    "plan_id": "...",
    "plan_name": "...",
    "status": "...",
    "periods": "...",
    "periods_count": "..."
  }
}
```

**Errors** (`success: false`)
- `:2188` `422` — Master not found.
- `:2199` `404` — Copier not found or not yours.

##### `GET /api/user/copytrading/master/plans`

- **Frontend:** `copytradingService.master.getPlans` (`src/services/copytrading.service.js:97`)
- **Triggered from:** `mounted`
- **Backend:** `CopyTradingApiController@getMasterPlans` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1184-1201`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1191`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "..."
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:1200`
```json
{
  "status": 200,
  "success": true,
  "message": "Plans retrieved",
  "data": "<$plans>"
}
```

</details>

### Master — Settlements — `/copy-trading/master/settlements`

Component: `src/components/copytrading/CopyTradingMasterSettlements.vue` — **1 APIs**

1. `GET /api/user/copytrading/master/settlements` → `CopyTradingApiController@getMasterSettlements`

<details><summary>Request / response details</summary>

##### `GET /api/user/copytrading/master/settlements`

- **Frontend:** `copytradingService.master.getSettlements` (`src/services/copytrading.service.js:292`)
- **Triggered from:** `loadSettlements`
- **Backend:** `CopyTradingApiController@getMasterSettlements` — `core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2728-2793`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2734`
```json
{
  "status": 200,
  "success": true,
  "message": "Settlements retrieved",
  "data": {
    "data": "...",
    "pagination": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "...",
    "summary": "...",
    "total_credited": "...",
    "entry_count": "..."
  }
}
```
`core/Modules/CopyTrading/app/Http/Controllers/Api/CopyTradingApiController.php:2783`
```json
{
  "status": 200,
  "success": true,
  "message": "Settlements retrieved",
  "data": {
    "data": "...",
    "pagination": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "...",
    "summary": "..."
  }
}
```

</details>

---

## Tickets

### Tickets list — `/tickets`

Component: `src/components/Tickets.vue` — **4 APIs**

1. `GET /api/user/tickets` → `UserTicketController@getTickets`
2. `GET /api/user/tickets/departments` → `UserTicketController@getDepartments`
3. `POST /api/user/tickets` → `UserTicketController@createTicket`
4. `POST /api/user/tickets/{ticketId}/close` → `UserTicketController@closeTicket`

<details><summary>Request / response details</summary>

##### `GET /api/user/tickets`

- **Frontend:** `ticketService.getTickets` (`src/services/ticket.service.js:9`)
- **Triggered from:** `loadTickets`, `total`
- **Backend:** `UserTicketController@getTickets` — `core/app/Http/Controllers/User/UserTicketController.php:330-420`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:406`
```json
{
  "status": 200,
  "success": true,
  "message": "Tickets retrieved successfully",
  "data": {
    "data": "...",
    "pagination": "...",
    "current_page": "...",
    "last_page": "...",
    "per_page": "...",
    "total": "..."
  }
}
```

**Errors** (`success: false`)
- `:418` `500` — Failed to fetch tickets

##### `GET /api/user/tickets/departments`

- **Frontend:** `ticketService.getDepartments` (`src/services/ticket.service.js:87`)
- **Triggered from:** `loadDepartments`
- **Backend:** `UserTicketController@getDepartments` — `core/app/Http/Controllers/User/UserTicketController.php:425-445`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:439`
```json
{
  "status": 200,
  "success": true,
  "message": "Departments retrieved successfully",
  "data": "<$transformedDepartments>"
}
```

**Errors** (`success: false`)
- `:443` `500` — Failed to fetch departments

##### `POST /api/user/tickets`

- **Frontend:** `ticketService.createTicket` (`src/services/ticket.service.js:116`)
- **Triggered from:** `createTicket`
- **Backend:** `UserTicketController@createTicket` — `core/app/Http/Controllers/User/UserTicketController.php:450-566`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `title`, `department_id`, `description`, `priority`, `file`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:550`
```json
{
  "status": 200,
  "success": true,
  "message": "Ticket created successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:464` `400` — Selected department does not have support staff available.
- `:498` `400` — Invalid file type. Only images, PDFs, and documents are allowed.
- `:556` `422` — ( $e->validator->errors()->first(), false, ['errors' => $e->errors()], 422 )
- `:564` `500` — Failed to create ticket

##### `POST /api/user/tickets/{ticketId}/close`

- **Frontend:** `ticketService.closeTicket` (`src/services/ticket.service.js:178`)
- **Triggered from:** `toggleTicketStatus`
- **Backend:** `UserTicketController@closeTicket` — `core/app/Http/Controllers/User/UserTicketController.php:903-933`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:927`
```json
{
  "status": 200,
  "success": true,
  "message": "Ticket closed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:913` `404` — Ticket not found or access denied
- `:931` `500` — Failed to close ticket

</details>

### New ticket — `/new-ticket`

Component: `src/components/NewTicket.vue` — **2 APIs**

1. `GET /api/user/tickets/departments` → `UserTicketController@getDepartments`
2. `POST /api/user/tickets` → `UserTicketController@createTicket`

<details><summary>Request / response details</summary>

##### `GET /api/user/tickets/departments`

- **Frontend:** `ticketService.getDepartments` (`src/services/ticket.service.js:87`)
- **Triggered from:** `loadDepartments`
- **Backend:** `UserTicketController@getDepartments` — `core/app/Http/Controllers/User/UserTicketController.php:425-445`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:439`
```json
{
  "status": 200,
  "success": true,
  "message": "Departments retrieved successfully",
  "data": "<$transformedDepartments>"
}
```

**Errors** (`success: false`)
- `:443` `500` — Failed to fetch departments

##### `POST /api/user/tickets`

- **Frontend:** `ticketService.createTicket` (`src/services/ticket.service.js:116`)
- **Triggered from:** `createTicket`
- **Backend:** `UserTicketController@createTicket` — `core/app/Http/Controllers/User/UserTicketController.php:450-566`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `title`, `department_id`, `description`, `priority`, `file`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:550`
```json
{
  "status": 200,
  "success": true,
  "message": "Ticket created successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:464` `400` — Selected department does not have support staff available.
- `:498` `400` — Invalid file type. Only images, PDFs, and documents are allowed.
- `:556` `422` — ( $e->validator->errors()->first(), false, ['errors' => $e->errors()], 422 )
- `:564` `500` — Failed to create ticket

</details>

### Ticket detail — `/ticket/:id`

Component: `src/components/TicketDetail.vue` — **3 APIs**

1. `GET /api/user/tickets/{ticketId}` → `UserTicketController@getTicketDetails`
2. `POST /api/user/tickets/{ticketId}/close` → `UserTicketController@closeTicket`
3. `POST /api/user/tickets/{ticketId}/reply` → `UserTicketController@replyToTicket`

<details><summary>Request / response details</summary>

##### `GET /api/user/tickets/{ticketId}`

- **Frontend:** `ticketService.getTicketDetails` (`src/services/ticket.service.js:140`)
- **Triggered from:** `loadTicket`
- **Backend:** `UserTicketController@getTicketDetails` — `core/app/Http/Controllers/User/UserTicketController.php:571-716`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:710`
```json
{
  "status": 200,
  "success": true,
  "message": "Data retrieved successfully",
  "data": "<$ticketData>"
}
```

**Errors** (`success: false`)
- `:589` `404` — Ticket not found or access denied
- `:714` `500` — Failed to fetch ticket details

##### `POST /api/user/tickets/{ticketId}/close`

- **Frontend:** `ticketService.closeTicket` (`src/services/ticket.service.js:178`)
- **Triggered from:** `closeTicket`
- **Backend:** `UserTicketController@closeTicket` — `core/app/Http/Controllers/User/UserTicketController.php:903-933`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:927`
```json
{
  "status": 200,
  "success": true,
  "message": "Ticket closed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:913` `404` — Ticket not found or access denied
- `:931` `500` — Failed to close ticket

##### `POST /api/user/tickets/{ticketId}/reply`

- **Frontend:** `ticketService.replyToTicket` (`src/services/ticket.service.js:158`)
- **Triggered from:** `sendReply`
- **Backend:** `UserTicketController@replyToTicket` — `core/app/Http/Controllers/User/UserTicketController.php:721-803`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `reply_text`

**Success**

`core/app/Http/Controllers/User/UserTicketController.php:790`
```json
{
  "status": 200,
  "success": true,
  "message": "Reply sent successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:739` `404` — Ticket not found or access denied
- `:748` `403` — This ticket is closed. Please create a new ticket for further queries.
- `:793` `422` — ( $e->validator->errors()->first(), false, ['errors' => $e->errors()], 422 )
- `:801` `500` — Failed to send reply

</details>

### Live chat — `/live-chat`

Component: `src/components/LiveChatPage.vue` — **0 APIs**

_No API calls (static page or uses only the app-shell calls)._

---

## Platforms

### Platforms (download links) — `/platform`

Component: `src/components/Platform.vue` — **2 APIs**

1. `GET /api/user/crm-settings` → `SettingController@getCrmSettings`
2. `GET /api/user/platform-links` → `SettingController@getPlatformLinks`

<details><summary>Request / response details</summary>

##### `GET /api/user/crm-settings`

- **Frontend:** `crmSettingsService.getCrmSettings` (`src/services/crmSettings.service.js:19`)
- **Triggered from:** `fetchLegacyPlatforms`
- **Backend:** `SettingController@getCrmSettings` — `core/app/Http/Controllers/Common/SettingController.php:475-489`
- **Middleware:** `logNavigation`

**Success**

`core/app/Http/Controllers/Common/SettingController.php:478`
```json
{
  "status": 200,
  "success": true,
  "message": "CRM settings retrieved successfully",
  "data": "<$crmSettingsService->getPublicPayload()>"
}
```

**Errors** (`success: false`)
- `:487` `500` — Error: 

##### `GET /api/user/platform-links`

- **Frontend:** `fetchPlatforms` (`src/components/Platform.vue:147`)
- **Triggered from:** `fetchPlatforms`
- **Backend:** `SettingController@getPlatformLinks` — `core/app/Http/Controllers/Common/SettingController.php:2395-2414`
- **Middleware:** `logNavigation`

**Success**

`core/app/Http/Controllers/Common/SettingController.php:2408`
```json
{
  "status": 200,
  "success": true,
  "message": "Platform links retrieved successfully",
  "data": {
    "platform_links": "..."
  }
}
```

**Errors** (`success: false`)
- `:2412` `500` — Error: 

</details>

---

## Settings

### Profile — `/settings-profile`

Component: `src/components/SettingsProfile.vue` — **6 APIs**

1. `GET /api/user/kyc` → `KYCController@getUserDocuments`
2. `GET /api/user/kyc/cities/{stateId}` → `KYCController@getCities`
3. `GET /api/user/kyc/countries` → `KYCController@getCountries`
4. `GET /api/user/kyc/states/{countryId}` → `KYCController@getStates`
5. `GET /api/user/settings/profile` → `UserController@getUserProfile`
6. `POST /api/user/kyc/profile` → `UserController@updateKycProfile`

<details><summary>Request / response details</summary>

##### `GET /api/user/kyc`

- **Frontend:** `kycService.getUserDocuments` (`src/services/kyc.service.js:78`)
- **Triggered from:** `loadProfileData`
- **Backend:** `KYCController@getUserDocuments` — `core/app/Http/Controllers/User/KYCController.php:102-264`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:248`
```json
{
  "status": 200,
  "success": true,
  "message": "KYC data fetched successfully",
  "data": "<$responseData>"
}
```

**Errors** (`success: false`)
- `:259` `500` — An error occurred while fetching KYC data.

##### `GET /api/user/kyc/cities/{stateId}`

- **Frontend:** `kycService.getCities` (`src/services/kyc.service.js:355`)
- **Triggered from:** `loadCities`
- **Backend:** `KYCController@getCities` — `core/app/Http/Controllers/User/KYCController.php:320-336`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:326`
```json
{
  "status": 200,
  "success": true,
  "message": "Cities retrieved successfully",
  "data": "<$cities>"
}
```

**Errors** (`success: false`)
- `:332` `500` — An error occurred while fetching cities.
- `:334` `500` — Failed to fetch cities

##### `GET /api/user/kyc/countries`

- **Frontend:** `kycService.getCountries` (`src/services/kyc.service.js:307`)
- **Triggered from:** `loadProfileData`
- **Backend:** `KYCController@getCountries` — `core/app/Http/Controllers/User/KYCController.php:272-288`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:278`
```json
{
  "status": 200,
  "success": true,
  "message": "Countries retrieved successfully",
  "data": "<$countries>"
}
```

**Errors** (`success: false`)
- `:284` `500` — An error occurred while fetching countries.
- `:286` `500` — Failed to fetch countries

##### `GET /api/user/kyc/states/{countryId}`

- **Frontend:** `kycService.getStates` (`src/services/kyc.service.js:331`)
- **Triggered from:** `loadStates`
- **Backend:** `KYCController@getStates` — `core/app/Http/Controllers/User/KYCController.php:296-312`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:302`
```json
{
  "status": 200,
  "success": true,
  "message": "States retrieved successfully",
  "data": "<$states>"
}
```

**Errors** (`success: false`)
- `:308` `500` — An error occurred while fetching states.
- `:310` `500` — Failed to fetch states

##### `GET /api/user/settings/profile`

- **Frontend:** `userService.getProfile` (`src/services/user.service.js:47`)
- **Triggered from:** `loadProfileData`
- **Backend:** `UserController@getUserProfile` — `core/app/Http/Controllers/User/UserController.php:416-591`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:582`
```json
{
  "status": 200,
  "success": true,
  "message": "User profile data retrieved successfully.",
  "data": {
    "user": "..."
  }
}
```

##### `POST /api/user/kyc/profile`

- **Frontend:** `userService.updateKycProfile` (`src/services/user.service.js:74`)
- **Triggered from:** `saveProfile`
- **Backend:** `UserController@updateKycProfile` — `core/app/Http/Controllers/User/UserController.php:1993-2127`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `first_name`, `last_name`, `mobile`, `title`, `gender`, `dob`, `nationality`, `country`, `state`, `city`, `address_1`, `address_2`, `postcode`

**Success**

`core/app/Http/Controllers/User/UserController.php:2117`
```json
{
  "status": 200,
  "success": true,
  "message": "Profile updated successfully",
  "data": {
    "user": "...",
    "user_details": "...",
    "profile_complete": "..."
  }
}
```

**Errors** (`success: false`)
- `:2079` — Validation failed
- `:2125` — ($e->getMessage(), false)

</details>

### Security (password, 2FA, devices) — `/settings-security`

Component: `src/components/SettingsSecurity.vue` — **11 APIs**

1. `DELETE /api/user/robot-trading-api-key` → `RobotTradingController@revokeKey`
2. `DELETE /api/user/sessions/{id}` → `SessionController@destroy`
3. `GET /api/user/robot-trading-status` → `RobotTradingController@getStatus`
4. `GET /api/user/sessions` → `SessionController@index`
5. `GET /api/user/settings/google-otp/status` → `GoogleAuthController@getOTPStatus`
6. `POST /api/user/robot-trading-api-key` → `RobotTradingController@createKey`
7. `POST /api/user/robot-trading-api-key/regenerate` → `RobotTradingController@regenerateKey`
8. `POST /api/user/settings/change-password` → `UserController@changePassword`
9. `POST /api/user/settings/google-otp/disable` → `GoogleAuthController@disableGoogleOTP`
10. `POST /api/user/settings/google-otp/generate` → `GoogleAuthController@generateGoogleOTP`
11. `POST /api/user/settings/google-otp/verify` → `GoogleAuthController@verifyGoogleOTP`

<details><summary>Request / response details</summary>

##### `DELETE /api/user/robot-trading-api-key`

- **Frontend:** `userService.revokeRobotTradingKey` (`src/services/user.service.js:211`)
- **Triggered from:** `revokeRobotTradingKey`
- **Backend:** `RobotTradingController@revokeKey` — `core/app/Http/Controllers/User/RobotTradingController.php:136-144`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/RobotTradingController.php:143`
```json
{
  "status": 200,
  "success": true,
  "message": "API key revoked",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:141` `404` — No API key found to revoke

##### `DELETE /api/user/sessions/{id}`

- **Frontend:** `userService.revokeSession` (`src/services/user.service.js:177`)
- **Triggered from:** `revokeSession`
- **Backend:** `SessionController@destroy` — `core/app/Http/Controllers/User/SessionController.php:73-94`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/SessionController.php:90`
```json
{
  "status": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:78` `401` — (['status' => false, 'message' => 'Unauthenticated'], 401)
- `:85` `404` — (['status' => false, 'message' => 'Session not found'], 404)

##### `GET /api/user/robot-trading-status`

- **Frontend:** `userService.getRobotTradingStatus` (`src/services/user.service.js:187`)
- **Triggered from:** `fetchRobotTradingStatus`
- **Backend:** `RobotTradingController@getStatus` — `core/app/Http/Controllers/User/RobotTradingController.php:24-66`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/RobotTradingController.php:38`
```json
{
  "status": 200,
  "success": true,
  "message": "Robot trading status retrieved",
  "data": "<$data>"
}
```

##### `GET /api/user/sessions`

- **Frontend:** `userService.getSessions` (`src/services/user.service.js:167`)
- **Triggered from:** `loadSessions`
- **Backend:** `SessionController@index` — `core/app/Http/Controllers/User/SessionController.php:17-64`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/SessionController.php:60`
```json
{
  "status": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:22` `401` — (['status' => false, 'message' => 'Unauthenticated'], 401)

##### `GET /api/user/settings/google-otp/status`

- **Frontend:** `googleAuthService.getOTPStatus` (`src/services/googleAuth.service.js:363`)
- **Triggered from:** `checkOTPStatus`
- **Backend:** `GoogleAuthController@getOTPStatus` — `core/app/Http/Controllers/User/GoogleAuthController.php:509-526`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:518`
```json
{
  "status": 200,
  "success": true,
  "message": "OTP status",
  "data": {
    "google_otp_enabled": "...",
    "google_otp_required": "..."
  }
}
```

**Errors** (`success: false`)
- `:515` `401` — User not authenticated
- `:524` `500` — Failed to get OTP status

##### `POST /api/user/robot-trading-api-key`

- **Frontend:** `userService.createRobotTradingKey` (`src/services/user.service.js:195`)
- **Triggered from:** `createRobotTradingKey`
- **Backend:** `RobotTradingController@createKey` — `core/app/Http/Controllers/User/RobotTradingController.php:73-100`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/RobotTradingController.php:96`
```json
{
  "status": 200,
  "success": true,
  "message": "API key created. Store it securely; it will not be shown again.",
  "data": {
    "api_key": "...",
    "key_prefix": "..."
  }
}
```

**Errors** (`success: false`)
- `:78` `403` — Robot trading is not allowed for your account. Contact support.
- `:83` `422` — API key already exists. Revoke it first to generate a new one.

##### `POST /api/user/robot-trading-api-key/regenerate`

- **Frontend:** `userService.regenerateRobotTradingKey` (`src/services/user.service.js:203`)
- **Triggered from:** `regenerateRobotTradingKey`
- **Backend:** `RobotTradingController@regenerateKey` — `core/app/Http/Controllers/User/RobotTradingController.php:106-130`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/RobotTradingController.php:126`
```json
{
  "status": 200,
  "success": true,
  "message": "API key regenerated. Store it securely; it will not be shown again.",
  "data": {
    "api_key": "...",
    "key_prefix": "..."
  }
}
```

**Errors** (`success: false`)
- `:111` `403` — Robot trading is not allowed for your account.

##### `POST /api/user/settings/change-password`

- **Frontend:** `userService.changePassword` (`src/services/user.service.js:131`)
- **Triggered from:** `changePassword`
- **Backend:** `UserController@changePassword` — `core/app/Http/Controllers/User/UserController.php:1188-1267`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `current_password`, `password`, `current_password.required`, `password.required`, `password.min`, `password.max`, `password.confirmed`, `password.regex`

**Success**

`core/app/Http/Controllers/User/UserController.php:1247`
```json
{
  "status": 200,
  "success": true,
  "message": "Password changed successfully. Please login again.",
  "data": {
    "requires_relogin": "..."
  }
}
```

**Errors** (`success: false`)
- `:1195` `401` — User not authenticated
- `:1220` `422` — Validation failed
- `:1227` `400` — Current password is incorrect
- `:1253` `422` — Validation failed
- `:1265` `500` — An error occurred while changing password

##### `POST /api/user/settings/google-otp/disable`

- **Frontend:** `googleAuthService.disableGoogleOTP` (`src/services/googleAuth.service.js:163`)
- **Triggered from:** `confirmDisable`
- **Backend:** `GoogleAuthController@disableGoogleOTP` — `core/app/Http/Controllers/User/GoogleAuthController.php:674-717`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `otp_code`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:709`
```json
{
  "status": 200,
  "success": true,
  "message": "OTP disabled successfully",
  "data": {
    "otp_enabled": "..."
  }
}
```

**Errors** (`success: false`)
- `:682` `422` — Validation failed
- `:688` `401` — User not authenticated
- `:692` `400` — Google OTP is not enabled
- `:696` `403` — Google Authenticator is required for your account and cannot be disabled
- `:701` `401` — Invalid OTP code
- `:715` `500` — Failed to disable OTP: 

##### `POST /api/user/settings/google-otp/generate`

- **Frontend:** `googleAuthService.generateGoogleOTP` (`src/services/googleAuth.service.js:111`)
- **Triggered from:** `generateQRCode`
- **Backend:** `GoogleAuthController@generateGoogleOTP` — `core/app/Http/Controllers/User/GoogleAuthController.php:531-563`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:555`
```json
{
  "status": 200,
  "success": true,
  "message": "OTP QR code generated",
  "data": {
    "verification_required": "..."
  }
}
```

**Errors** (`success: false`)
- `:537` `401` — User not authenticated
- `:543` `403` — Google OTP is not enabled
- `:561` `500` — Failed to generate OTP: 

##### `POST /api/user/settings/google-otp/verify`

- **Frontend:** `googleAuthService.verifyGoogleOTP` (`src/services/googleAuth.service.js:136`)
- **Triggered from:** `verifyOTP`
- **Backend:** `GoogleAuthController@verifyGoogleOTP` — `core/app/Http/Controllers/User/GoogleAuthController.php:568-612`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `otp_code`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:604`
```json
{
  "status": 200,
  "success": true,
  "message": "OTP verified and enabled successfully",
  "data": {
    "otp_enabled": "..."
  }
}
```

**Errors** (`success: false`)
- `:576` `422` — Validation failed
- `:582` `401` — User not authenticated
- `:586` `400` — OTP not set up. Please generate QR code first
- `:592` `403` — Google OTP is not enabled
- `:597` `401` — Invalid OTP code
- `:610` `500` — Failed to verify OTP: 

</details>

### KYC — `/kyc`

Component: `src/components/KYC.vue` — **17 APIs**

1. `GET /api/user/kyc` → `KYCController@getUserDocuments`
2. `GET /api/user/kyc/cities/{stateId}` → `KYCController@getCities`
3. `GET /api/user/kyc/countries` → `KYCController@getCountries`
4. `GET /api/user/kyc/shufti/status` → `ShuftiKycController@status`
5. `GET /api/user/kyc/states/{countryId}` → `KYCController@getStates`
6. `GET /api/user/regulation` → `UserController@getRegulationDetails`
7. `GET /api/user/settings/profile` → `UserController@getUserProfile`
8. `POST /api/user/auth/google/check-mobile` → `GoogleAuthController@checkMobileAvailability`
9. `POST /api/user/kyc/documents/upload` → `KYCController@uploadDocument`
10. `POST /api/user/kyc/profile` → `UserController@updateKycProfile`
11. `POST /api/user/kyc/shufti/start` → `ShuftiKycController@start`
12. `POST /api/user/kyc/submit-unified` → `KYCController@submitUnifiedKyc`
13. `POST /api/user/kyc/sumsub/refresh` → `SumsubKycController@refresh`
14. `POST /api/user/kyc/sumsub/token` → `SumsubKycController@token`
15. `POST /api/user/mobile-verification/send` → `MobileVerificationController@send`
16. `POST /api/user/mobile-verification/verify` → `MobileVerificationController@verify`
17. `POST /api/user/regulation` → `UserController@saveRegulationDetails`

<details><summary>Request / response details</summary>

##### `GET /api/user/kyc`

- **Frontend:** `kycService.getUserDocuments` (`src/services/kyc.service.js:78`)
- **Triggered from:** `loadInitialData`, `refreshKycStatus`, `refreshProviderState`
- **Backend:** `KYCController@getUserDocuments` — `core/app/Http/Controllers/User/KYCController.php:102-264`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:248`
```json
{
  "status": 200,
  "success": true,
  "message": "KYC data fetched successfully",
  "data": "<$responseData>"
}
```

**Errors** (`success: false`)
- `:259` `500` — An error occurred while fetching KYC data.

##### `GET /api/user/kyc/cities/{stateId}`

- **Frontend:** `kycService.getCities` (`src/services/kyc.service.js:355`)
- **Triggered from:** `loadCities`
- **Backend:** `KYCController@getCities` — `core/app/Http/Controllers/User/KYCController.php:320-336`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:326`
```json
{
  "status": 200,
  "success": true,
  "message": "Cities retrieved successfully",
  "data": "<$cities>"
}
```

**Errors** (`success: false`)
- `:332` `500` — An error occurred while fetching cities.
- `:334` `500` — Failed to fetch cities

##### `GET /api/user/kyc/countries`

- **Frontend:** `kycService.getCountries` (`src/services/kyc.service.js:307`)
- **Triggered from:** `loadInitialData`
- **Backend:** `KYCController@getCountries` — `core/app/Http/Controllers/User/KYCController.php:272-288`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:278`
```json
{
  "status": 200,
  "success": true,
  "message": "Countries retrieved successfully",
  "data": "<$countries>"
}
```

**Errors** (`success: false`)
- `:284` `500` — An error occurred while fetching countries.
- `:286` `500` — Failed to fetch countries

##### `GET /api/user/kyc/shufti/status`

- **Frontend:** `kycService.getShuftiStatus` (`src/services/kyc.service.js:103`)
- **Triggered from:** `refresh`
- **Backend:** `ShuftiKycController@status` — `core/app/Http/Controllers/User/ShuftiKycController.php:158-179`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/ShuftiKycController.php:164`
```json
{
  "status": 200,
  "success": true,
  "message": "No verification found",
  "data": {
    "verification": "..."
  }
}
```
`core/app/Http/Controllers/User/ShuftiKycController.php:176`
```json
{
  "status": 200,
  "success": true,
  "message": "Verification status",
  "data": {
    "verification": "..."
  }
}
```

##### `GET /api/user/kyc/states/{countryId}`

- **Frontend:** `kycService.getStates` (`src/services/kyc.service.js:331`)
- **Triggered from:** `loadStates`
- **Backend:** `KYCController@getStates` — `core/app/Http/Controllers/User/KYCController.php:296-312`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:302`
```json
{
  "status": 200,
  "success": true,
  "message": "States retrieved successfully",
  "data": "<$states>"
}
```

**Errors** (`success: false`)
- `:308` `500` — An error occurred while fetching states.
- `:310` `500` — Failed to fetch states

##### `GET /api/user/regulation`

- **Frontend:** `regulationService.getRegulationDetails` (`src/services/regulation.service.js:6`), `complianceService.getSchema` (`src/services/compliance.service.js:26`)
- **Triggered from:** `loadComplianceSchema`, `loadSchema`
- **Backend:** `UserController@getRegulationDetails` — `core/app/Http/Controllers/User/UserController.php:826-960`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:912`
```json
{
  "status": 200,
  "success": true,
  "message": "Regulation details fetched successfully",
  "data": {
    "regulated_broker_enabled": "...",
    "regulation_valid": "...",
    "regulation_required": "...",
    "review_status": "...",
    "review_notes": "...",
    "reviewed_at": "...",
    "hide_country_for_regulated": "...",
    "hide_country_for_regulated_countries": "...",
    "disable_upi_deposit_for_regulated": "...",
    "disable_upi_withdrawal_for_regulated": "...",
    "force_regulated_form": "...",
    "force_skip_regulated_form": "...",
    "require_fatca": "...",
    "require_pep": "...",
    "require_us_tax_form": "...",
    "dynamic_compliance_enabled": "...",
    "schema": "...",
    "template": "...",
    "regulation": "...",
    "id": "...",
    "template_id": "...",
    "template_version": "...",
    "form_payload": "...",
    "ip_address": "...",
    "ip_location": "...",
    "user_agent": "...",
    "submitted_at": "...",
    "created_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:949` `500` — Failed to fetch regulation details: 

##### `GET /api/user/settings/profile`

- **Frontend:** `userService.getProfile` (`src/services/user.service.js:47`)
- **Triggered from:** `refreshProfileData`, `loadInitialData`
- **Backend:** `UserController@getUserProfile` — `core/app/Http/Controllers/User/UserController.php:416-591`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:582`
```json
{
  "status": 200,
  "success": true,
  "message": "User profile data retrieved successfully.",
  "data": {
    "user": "..."
  }
}
```

##### `POST /api/user/auth/google/check-mobile`

- **Frontend:** `googleAuthService.checkMobileAvailability` (`src/services/googleAuth.service.js:336`)
- **Triggered from:** `checkMobileDuplicate`
- **Backend:** `GoogleAuthController@checkMobileAvailability` — `core/app/Http/Controllers/User/GoogleAuthController.php:999-1038`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `mobile`, `country_code`

**Success**

`core/app/Http/Controllers/User/GoogleAuthController.php:1030`
```json
{
  "status": 200,
  "success": true,
  "message": "Mobile number is available",
  "data": {
    "available": "..."
  }
}
```

**Errors** (`success: false`)
- `:1005` `401` — User not authenticated
- `:1014` `422` — Validation failed
- `:1019` `422` — Please select a country code and enter a valid mobile number.
- `:1025` — This mobile number is already registered. Please use a different number.
- `:1036` `500` — Failed to check mobile availability

##### `POST /api/user/kyc/documents/upload`

- **Frontend:** `complianceService.uploadDocument` (`src/services/compliance.service.js:51`)
- **Triggered from:** `onFileSelected`
- **Backend:** `KYCController@uploadDocument` — `core/app/Http/Controllers/User/KYCController.php:343-670`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `origin`, `field_key`, `document_type`, `subdocument_type`, `files`, `files.*`, `file`, `files.*.mimes`, `file.mimes`

**Success**

`core/app/Http/Controllers/User/KYCController.php:616`
```json
{
  "status": 200,
  "success": true,
  "message": "Documents uploaded successfully",
  "data": {
    "path": "...",
    "url": "...",
    "document_url": "...",
    "origin": "..."
  }
}
```

**Errors** (`success: false`)
- `:453` `403` — ($msg, false, [ 'reason' => $latestRegulation && $latestRegulation->review_status === 'rejected' ? 'rejected' : 'no_submission', 'review_sta
- `:478` `422` — No file provided. Send either files[] or file field.
- `:653` `413` — ($errorMessage, false, [], 413)
- `:665` `408` — ($errorMessage, false, [], 408)
- `:668` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/kyc/profile`

- **Frontend:** `userService.updateKycProfile` (`src/services/user.service.js:74`)
- **Triggered from:** `submitProfile`, `submitRegulation`
- **Backend:** `UserController@updateKycProfile` — `core/app/Http/Controllers/User/UserController.php:1993-2127`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `first_name`, `last_name`, `mobile`, `title`, `gender`, `dob`, `nationality`, `country`, `state`, `city`, `address_1`, `address_2`, `postcode`

**Success**

`core/app/Http/Controllers/User/UserController.php:2117`
```json
{
  "status": 200,
  "success": true,
  "message": "Profile updated successfully",
  "data": {
    "user": "...",
    "user_details": "...",
    "profile_complete": "..."
  }
}
```

**Errors** (`success: false`)
- `:2079` — Validation failed
- `:2125` — ($e->getMessage(), false)

##### `POST /api/user/kyc/shufti/start`

- **Frontend:** `kycService.startShufti` (`src/services/kyc.service.js:93`)
- **Triggered from:** `start`
- **Backend:** `ShuftiKycController@start` — `core/app/Http/Controllers/User/ShuftiKycController.php:56-150`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/ShuftiKycController.php:73`
```json
{
  "status": 200,
  "success": true,
  "message": "Verification already in progress",
  "data": {
    "verification": "...",
    "reused": "..."
  }
}
```
`core/app/Http/Controllers/User/ShuftiKycController.php:146`
```json
{
  "status": 200,
  "success": true,
  "message": "Verification created",
  "data": {
    "verification": "...",
    "reused": "..."
  }
}
```

**Errors** (`success: false`)
- `:62` `422` — Manual document upload applies to this account
- `:87` `422` — Please complete your address in your profile before starting verification.
- `:129` `503` — Verification is temporarily unavailable. Please try again later.

##### `POST /api/user/kyc/submit-unified`

- **Frontend:** `kycService.submitUnifiedKyc` (`src/services/kyc.service.js:288`)
- **Triggered from:** `submitKYC`
- **Backend:** `KYCController@submitUnifiedKyc` — `core/app/Http/Controllers/User/KYCController.php:1082-1445`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:1435`
```json
{
  "status": 200,
  "success": true,
  "message": "KYC submitted successfully!",
  "data": {
    "documents_uploaded": "...",
    "profile_completion": "...",
    "kyc_status": "..."
  }
}
```

**Errors** (`success: false`)
- `:1092` `422` — Verify your mobile number before submitting KYC.
- `:1106` `500` — Server configuration error: upload_max_filesize is too small. Current: 
- `:1110` `500` — Server configuration error: post_max_size is too small. Current: 
- `:1173` `403` — ($msg, false, [ 'reason' => $latestRegulation && $latestRegulation->review_status === 'rejected' ? 'rejected' : 'no_submission', 'review_sta
- `:1287` `422` — ( implode(' and ', $missing) . ' ' . (count($missing) > 1 ? 'are' : 'is') . ' required. Back documents are optional.', false, [], 422 )
- `:1302` `422` — Please upload at least one new document to replace the rejected document(s).

##### `POST /api/user/kyc/sumsub/refresh`

- **Frontend:** `kycService.refreshSumsub` (`src/services/kyc.service.js:124`)
- **Triggered from:** `refreshProviderState`
- **Backend:** `SumsubKycController@refresh` — `core/app/Http/Controllers/User/SumsubKycController.php:48-68`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:20,1`

**Success**

`core/app/Http/Controllers/User/SumsubKycController.php:53`
```json
{
  "status": 200,
  "success": true,
  "message": "Nothing to refresh.",
  "data": {
    "outcome": "..."
  }
}
```
`core/app/Http/Controllers/User/SumsubKycController.php:64`
```json
{
  "status": 200,
  "success": true,
  "message": "Status refreshed.",
  "data": {
    "outcome": "...",
    "kyc_status": "..."
  }
}
```

**Errors** (`success: false`)
- `:61` `422` — Could not refresh right now. Please try again shortly.

##### `POST /api/user/kyc/sumsub/token`

- **Frontend:** `kycService.getSumsubToken` (`src/services/kyc.service.js:113`)
- **Triggered from:** `fetchToken`
- **Backend:** `SumsubKycController@token` — `core/app/Http/Controllers/User/SumsubKycController.php:22-41`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:10,1`

**Success**

`core/app/Http/Controllers/User/SumsubKycController.php:40`
```json
{
  "status": 200,
  "success": true,
  "message": "Access token issued.",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:37` `422` — ($message, false, [], 422)

##### `POST /api/user/mobile-verification/send`

- **Frontend:** `mobileVerificationService.send` (`src/services/mobileVerification.service.js:20`)
- **Triggered from:** `send`
- **Backend:** `MobileVerificationController@send` — `core/app/Http/Controllers/User/MobileVerificationController.php:45-73`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:5,1`

**Success**

`core/app/Http/Controllers/User/MobileVerificationController.php:51`
```json
{
  "status": 200,
  "success": true,
  "message": "Mobile number is already verified.",
  "data": {
    "verified": "..."
  }
}
```
`core/app/Http/Controllers/User/MobileVerificationController.php:72`
```json
{
  "status": 200,
  "success": true,
  "message": "Code sent to ",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:54` `422` — Add a mobile number to your profile first.
- `:62` `429` — Please wait a minute before requesting another code.
- `:69` `422` — ($e->getMessage(), false, [], 422)

##### `POST /api/user/mobile-verification/verify`

- **Frontend:** `mobileVerificationService.verify` (`src/services/mobileVerification.service.js:29`)
- **Triggered from:** `verify`
- **Backend:** `MobileVerificationController@verify` — `core/app/Http/Controllers/User/MobileVerificationController.php:75-117`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:10,1`
- **Request fields (validated):** `otp`

**Success**

`core/app/Http/Controllers/User/MobileVerificationController.php:82`
```json
{
  "status": 200,
  "success": true,
  "message": "Mobile number is already verified.",
  "data": {
    "verified": "..."
  }
}
```
`core/app/Http/Controllers/User/MobileVerificationController.php:116`
```json
{
  "status": 200,
  "success": true,
  "message": "Mobile number verified.",
  "data": {
    "verified": "..."
  }
}
```

**Errors** (`success: false`)
- `:87` `429` — Too many wrong codes. Please try again in 
- `:95` `400` — The code has expired. Request a new one.
- `:102` `400` — Wrong code. 

##### `POST /api/user/regulation`

- **Frontend:** `regulationService.saveRegulationDetails` (`src/services/regulation.service.js:15`), `complianceService.submit` (`src/services/compliance.service.js:36`)
- **Triggered from:** `submitRegulation`, `handleSubmit`
- **Backend:** `UserController@saveRegulationDetails` — `core/app/Http/Controllers/User/UserController.php:962-1061`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `profile_snapshot`

**Success**

`core/app/Http/Controllers/User/UserController.php:1053`
```json
{
  "status": 200,
  "success": true,
  "message": "Regulation details saved successfully",
  "data": {
    "id": "...",
    "submitted_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:969` `403` — Regulated broker profile form is disabled
- `:976` `422` — Validation failed
- `:1026` `422` — Validation failed
- `:1059` `500` — Failed to save regulation details

</details>

### Documents — `/settings-documents`

Component: `src/components/SettingsDocuments.vue` — **6 APIs**

1. `GET /api/user/kyc` → `KYCController@getUserDocuments`
2. `GET /api/user/kyc-image-proxy/{documentId}` → `KYCController@serveKycImageProxy`
3. `GET /api/user/settings/profile` → `UserController@getUserProfile`
4. `POST /api/user/kyc/documents/finalize-chunked` → `KYCController@finalizeChunkedUpload`
5. `POST /api/user/kyc/documents/upload` → `KYCController@uploadDocument`
6. `POST /api/user/kyc/documents/upload-chunk` → `KYCController@uploadChunk`

<details><summary>Request / response details</summary>

##### `GET /api/user/kyc`

- **Frontend:** `kycService.getUserDocuments` (`src/services/kyc.service.js:78`)
- **Triggered from:** `loadDocuments`
- **Backend:** `KYCController@getUserDocuments` — `core/app/Http/Controllers/User/KYCController.php:102-264`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:248`
```json
{
  "status": 200,
  "success": true,
  "message": "KYC data fetched successfully",
  "data": "<$responseData>"
}
```

**Errors** (`success: false`)
- `:259` `500` — An error occurred while fetching KYC data.

##### `GET /api/user/kyc-image-proxy/{documentId}`

- **Frontend:** `loadDocumentImage` (`src/components/SettingsDocuments.vue:967`)
- **Triggered from:** `loadDocumentImage`
- **Backend:** `KYCController@serveKycImageProxy` — `core/app/Http/Controllers/User/KYCController.php:1573-1612`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

> Used as <img src>; 404 when the file is missing.

**Success**
```json
<binary image stream> (Content-Type: image/*)
```

##### `GET /api/user/settings/profile`

- **Frontend:** `userService.getProfile` (`src/services/user.service.js:47`)
- **Triggered from:** `loadDocuments`
- **Backend:** `UserController@getUserProfile` — `core/app/Http/Controllers/User/UserController.php:416-591`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:582`
```json
{
  "status": 200,
  "success": true,
  "message": "User profile data retrieved successfully.",
  "data": {
    "user": "..."
  }
}
```

##### `POST /api/user/kyc/documents/finalize-chunked`

- **Frontend:** `kycService.uploadDocumentChunked` (`src/services/kyc.service.js:216`)
- **Triggered from:** `processFile`, `handlePaste`
- **Backend:** `KYCController@finalizeChunkedUpload` — `core/app/Http/Controllers/User/KYCController.php:786-861`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `sessionId`, `fileName`, `fileSize`, `document_type`, `subdocument_type`

**Success**

`core/app/Http/Controllers/User/KYCController.php:850`
```json
{
  "status": 200,
  "success": true,
  "message": "File uploaded successfully",
  "data": {
    "document_id": "...",
    "documents_slug": "..."
  }
}
```

**Errors** (`success: false`)
- `:810` `404` — Upload session not found
- `:818` `404` — No chunks found
- `:826` `500` — Failed to create output file
- `:840` `422` — File size mismatch after combining chunks
- `:856` `500` — Failed to save document
- `:859` `500` — Failed to finalize upload: 

##### `POST /api/user/kyc/documents/upload`

- **Frontend:** `kycService.uploadDocument` (`src/services/kyc.service.js:160`)
- **Triggered from:** `processFile`, `handlePaste`
- **Backend:** `KYCController@uploadDocument` — `core/app/Http/Controllers/User/KYCController.php:343-670`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `origin`, `field_key`, `document_type`, `subdocument_type`, `files`, `files.*`, `file`, `files.*.mimes`, `file.mimes`

**Success**

`core/app/Http/Controllers/User/KYCController.php:616`
```json
{
  "status": 200,
  "success": true,
  "message": "Documents uploaded successfully",
  "data": {
    "path": "...",
    "url": "...",
    "document_url": "...",
    "origin": "..."
  }
}
```

**Errors** (`success: false`)
- `:453` `403` — ($msg, false, [ 'reason' => $latestRegulation && $latestRegulation->review_status === 'rejected' ? 'rejected' : 'no_submission', 'review_sta
- `:478` `422` — No file provided. Send either files[] or file field.
- `:653` `413` — ($errorMessage, false, [], 413)
- `:665` `408` — ($errorMessage, false, [], 408)
- `:668` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/kyc/documents/upload-chunk`

- **Frontend:** `uploadChunk` (`src/services/kyc.service.js:66`)
- **Triggered from:** `processFile`, `handlePaste`
- **Backend:** `KYCController@uploadChunk` — `core/app/Http/Controllers/User/KYCController.php:724-778`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `chunk`, `chunkIndex`, `totalChunks`, `fileName`, `fileSize`, `fileType`, `document_type`, `subdocument_type`

**Success**

`core/app/Http/Controllers/User/KYCController.php:767`
```json
{
  "status": 200,
  "success": true,
  "message": "Chunk uploaded successfully",
  "data": {
    "chunkIndex": "...",
    "totalChunks": "...",
    "uploadedChunks": "...",
    "isComplete": "...",
    "sessionId": "..."
  }
}
```

**Errors** (`success: false`)
- `:776` `500` — Failed to upload chunk: 

</details>

### Bank / withdrawal accounts — `/settings-bank-accounts`

Component: `src/components/SettingsBankAccounts.vue` — **7 APIs**

1. `DELETE /api/user/withdrawal/delete/{id}` → `FinanceController@destroy`
2. `GET /api/user/regulation` → `UserController@getRegulationDetails`
3. `GET /api/user/withdrawal` → `FinanceController@withdrawal`
4. `GET /api/user/withdrawal/getUserWithdrawalMethods` → `FinanceController@getUserWithdrawalMethods`
5. `GET /api/user/withdrawal/sendOTP` → `FinanceController@withdrawalOtpSend`
6. `POST /api/user/utility/ifsc-code` → `FinanceController@verifyIfscCode`
7. `POST /api/user/withdrawal` → `FinanceController@store`

<details><summary>Request / response details</summary>

##### `DELETE /api/user/withdrawal/delete/{id}`

- **Frontend:** `financeService.deleteWithdrawalMethod` (`src/services/finance.service.js:280`)
- **Triggered from:** `removeMethod`
- **Backend:** `FinanceController@destroy` — `core/app/Http/Controllers/User/FinanceController.php:544-562`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:558`
```json
{
  "status": 200,
  "success": true,
  "message": "Withdrawal method deleted successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:551` `404` — No withdrawal found with the provided ID.
- `:554` `403` — Unauthorized access
- `:560` `500` — ($e->getMessage(), false, [], 500)

##### `GET /api/user/regulation`

- **Frontend:** `regulationService.getRegulationDetails` (`src/services/regulation.service.js:6`)
- **Triggered from:** `loadRegulatedRules`
- **Backend:** `UserController@getRegulationDetails` — `core/app/Http/Controllers/User/UserController.php:826-960`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:912`
```json
{
  "status": 200,
  "success": true,
  "message": "Regulation details fetched successfully",
  "data": {
    "regulated_broker_enabled": "...",
    "regulation_valid": "...",
    "regulation_required": "...",
    "review_status": "...",
    "review_notes": "...",
    "reviewed_at": "...",
    "hide_country_for_regulated": "...",
    "hide_country_for_regulated_countries": "...",
    "disable_upi_deposit_for_regulated": "...",
    "disable_upi_withdrawal_for_regulated": "...",
    "force_regulated_form": "...",
    "force_skip_regulated_form": "...",
    "require_fatca": "...",
    "require_pep": "...",
    "require_us_tax_form": "...",
    "dynamic_compliance_enabled": "...",
    "schema": "...",
    "template": "...",
    "regulation": "...",
    "id": "...",
    "template_id": "...",
    "template_version": "...",
    "form_payload": "...",
    "ip_address": "...",
    "ip_location": "...",
    "user_agent": "...",
    "submitted_at": "...",
    "created_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:949` `500` — Failed to fetch regulation details: 

##### `GET /api/user/withdrawal`

- **Frontend:** `financeService.getWithdrawalMethods` (`src/services/finance.service.js:77`)
- **Triggered from:** `loadWithdrawalMethods`
- **Backend:** `FinanceController@withdrawal` — `core/app/Http/Controllers/User/FinanceController.php:2078-2254`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:2242`
```json
{
  "status": 200,
  "success": true,
  "message": "Withdrawal methods retrieved successfully",
  "data": "<$filteredMethods>"
}
```

**Errors** (`success: false`)
- `:2089` `403` — ($message, false, [], 403)
- `:2252` `500` — ($e->getMessage(), false, [], 500)

##### `GET /api/user/withdrawal/getUserWithdrawalMethods`

- **Frontend:** `financeService.getUserWithdrawalMethods` (`src/services/finance.service.js:252`)
- **Triggered from:** `loadWithdrawalMethods`
- **Backend:** `FinanceController@getUserWithdrawalMethods` — `core/app/Http/Controllers/User/FinanceController.php:590-693`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:674`
```json
{
  "withdrawalMethods": "..."
}
```
`core/app/Http/Controllers/User/FinanceController.php:682`
```json
{
  "status": 200,
  "success": true,
  "message": "Withdrawal methods retrieved successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:691` `500` — ($e->getMessage(), false, [], 500)

##### `GET /api/user/withdrawal/sendOTP`

- **Frontend:** `financeService.sendWithdrawalOTP` (`src/services/finance.service.js:127`)
- **Triggered from:** `sendOTP`, `resendOtp`
- **Backend:** `FinanceController@withdrawalOtpSend` — `core/app/Http/Controllers/User/FinanceController.php:3422-3607`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:3582`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "channel": "...",
    "alternate_channel": "..."
  }
}
```

**Errors** (`success: false`)
- `:3431` `422` — ($balanceCheck['message'], false, [], 422)
- `:3462` `422` — Account ID and amount are required for withdrawal.
- `:3477` `403` — Account locked for PMAM. Unsubscribe first.
- `:3480` `403` — This account is a PMAM pool with investor funds. Withdrawals are not allowed.
- `:3493` `422` — ($balanceCheck['message'], false, [], 422)
- `:3510` `403` — Source account is locked for PMAM. Unsubscribe first.

##### `POST /api/user/utility/ifsc-code`

- **Frontend:** `financeService.verifyIfscCode` (`src/services/finance.service.js:289`)
- **Triggered from:** `verifyIfscCode`
- **Backend:** `FinanceController@verifyIfscCode` — `core/app/Http/Controllers/User/FinanceController.php:4113-4133`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:4124`
```json
{
  "status": 200,
  "success": true,
  "message": "IFSC code retrieved successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:4128` `404` — IFSC code not found.
- `:4131` `500` — ($e->getMessage(), false, [], 500)

##### `POST /api/user/withdrawal`

- **Frontend:** `financeService.addWithdrawalMethod` (`src/services/finance.service.js:261`)
- **Triggered from:** `submitWithdrawalMethod`
- **Backend:** `FinanceController@store` — `core/app/Http/Controllers/User/FinanceController.php:242-536`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `withdrawal_method.required`, `withdrawal_method.in`, `currency.required`, `relationship.required`, `relationship.in`, `otp.required`, `otp.digits`, `.required`, `.regex`, `bank_name.required`, `bank_account_no.required`, `bank_account_no.same`, `confirm_bank_account_no.required`, `confirm_bank_account_no.same`, `ifsc_iban.required`, `upi_address.required`, `crypto_address.required`, `crypto_network.required`, `crypto_network.in`, `.image`, `.mimes`, `.max`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:524`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/User/FinanceController.php:525`
```json
{
  "status": 200,
  "success": true,
  "message": "Withdrawal method add successfully.",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:259` `422` — Cryptocurrency payout networks are not enabled for your account. Please contact support.
- `:424` `400` — No OTP found. Please send OTP first.
- `:453` `400` — ($message, false, [], 400)
- `:534` `500` — ($e->getMessage(), false, [], 500)

</details>

### Withdrawal details — `/settings-withdrawal-details/:id`

Component: `src/components/SettingsWithdrawalDetails.vue` — **3 APIs**

1. `GET /api/user/image-proxy/{id}` → `FinanceController@serveImageProxy`
2. `GET /api/user/regulation` → `UserController@getRegulationDetails`
3. `GET /api/user/withdrawal/getUserWithdrawalMethods` → `FinanceController@getUserWithdrawalMethods`

<details><summary>Request / response details</summary>

##### `GET /api/user/image-proxy/{id}`

- **Frontend:** `loadImage` (`src/components/SettingsWithdrawalDetails.vue:309`)
- **Triggered from:** `loadImage`
- **Backend:** `FinanceController@serveImageProxy` — `core/app/Http/Controllers/User/FinanceController.php:1554-1593`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

_Response shape not detected — see controller._

##### `GET /api/user/regulation`

- **Frontend:** `regulationService.getRegulationDetails` (`src/services/regulation.service.js:6`)
- **Triggered from:** `loadRegulatedBrokerSetting`
- **Backend:** `UserController@getRegulationDetails` — `core/app/Http/Controllers/User/UserController.php:826-960`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:912`
```json
{
  "status": 200,
  "success": true,
  "message": "Regulation details fetched successfully",
  "data": {
    "regulated_broker_enabled": "...",
    "regulation_valid": "...",
    "regulation_required": "...",
    "review_status": "...",
    "review_notes": "...",
    "reviewed_at": "...",
    "hide_country_for_regulated": "...",
    "hide_country_for_regulated_countries": "...",
    "disable_upi_deposit_for_regulated": "...",
    "disable_upi_withdrawal_for_regulated": "...",
    "force_regulated_form": "...",
    "force_skip_regulated_form": "...",
    "require_fatca": "...",
    "require_pep": "...",
    "require_us_tax_form": "...",
    "dynamic_compliance_enabled": "...",
    "schema": "...",
    "template": "...",
    "regulation": "...",
    "id": "...",
    "template_id": "...",
    "template_version": "...",
    "form_payload": "...",
    "ip_address": "...",
    "ip_location": "...",
    "user_agent": "...",
    "submitted_at": "...",
    "created_at": "..."
  }
}
```

**Errors** (`success: false`)
- `:949` `500` — Failed to fetch regulation details: 

##### `GET /api/user/withdrawal/getUserWithdrawalMethods`

- **Frontend:** `financeService.getUserWithdrawalMethods` (`src/services/finance.service.js:252`)
- **Triggered from:** `loadWithdrawalMethodDetails`
- **Backend:** `FinanceController@getUserWithdrawalMethods` — `core/app/Http/Controllers/User/FinanceController.php:590-693`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/FinanceController.php:674`
```json
{
  "withdrawalMethods": "..."
}
```
`core/app/Http/Controllers/User/FinanceController.php:682`
```json
{
  "status": 200,
  "success": true,
  "message": "Withdrawal methods retrieved successfully",
  "data": "<$data>"
}
```

**Errors** (`success: false`)
- `:691` `500` — ($e->getMessage(), false, [], 500)

</details>

### Login activities — `/settings-activities`

Component: `src/components/SettingsActivities.vue` — **3 APIs**

1. `DELETE /api/user/sessions/{id}` → `SessionController@destroy`
2. `GET /api/user/sessions` → `SessionController@index`
3. `GET /api/user/settings/activitylog` → `UserController@getActivitiesLog`

<details><summary>Request / response details</summary>

##### `DELETE /api/user/sessions/{id}`

- **Frontend:** `userService.revokeSession` (`src/services/user.service.js:177`)
- **Triggered from:** `revokeSession`
- **Backend:** `SessionController@destroy` — `core/app/Http/Controllers/User/SessionController.php:73-94`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/SessionController.php:90`
```json
{
  "status": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:78` `401` — (['status' => false, 'message' => 'Unauthenticated'], 401)
- `:85` `404` — (['status' => false, 'message' => 'Session not found'], 404)

##### `GET /api/user/sessions`

- **Frontend:** `userService.getSessions` (`src/services/user.service.js:167`)
- **Triggered from:** `loadSessions`
- **Backend:** `SessionController@index` — `core/app/Http/Controllers/User/SessionController.php:17-64`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/SessionController.php:60`
```json
{
  "status": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:22` `401` — (['status' => false, 'message' => 'Unauthenticated'], 401)

##### `GET /api/user/settings/activitylog`

- **Frontend:** `userService.getActivityLog` (`src/services/user.service.js:141`)
- **Triggered from:** `loadActivities`, `loadMoreActivities`
- **Backend:** `UserController@getActivitiesLog` — `core/app/Http/Controllers/User/UserController.php:1275-1490`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/UserController.php:1472`
```json
{
  "status": 200,
  "success": true,
  "message": "Activities retrieved successfully",
  "data": {
    "activities": "...",
    "pagination": "...",
    "current_page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

</details>

### Notification preferences — `/settings-notifications`

Component: `src/components/SettingsNotifications.vue` — **2 APIs**

1. `GET /api/user/email-preferences` → `EmailPreferenceController@show`
2. `POST /api/user/email-preferences` → `EmailPreferenceController@update`

<details><summary>Request / response details</summary>

##### `GET /api/user/email-preferences`

- **Frontend:** `loadPreferences` (`src/components/SettingsNotifications.vue:169`)
- **Triggered from:** `loadPreferences`
- **Backend:** `EmailPreferenceController@show` — `core/Modules/EmailCenter/Http/Controllers/Api/EmailPreferenceController.php:33-55`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/EmailCenter/Http/Controllers/Api/EmailPreferenceController.php:48`
```json
{
  "status": 200,
  "success": true,
  "message": "Email preferences retrieved.",
  "data": {
    "marketing": "...",
    "newsletters": "...",
    "product_updates": "...",
    "globally_unsubscribed": "...",
    "email": "..."
  }
}
```

##### `POST /api/user/email-preferences`

- **Frontend:** `savePreferences` (`src/components/SettingsNotifications.vue:187`)
- **Triggered from:** `savePreferences`
- **Backend:** `EmailPreferenceController@update` — `core/Modules/EmailCenter/Http/Controllers/Api/EmailPreferenceController.php:61-102`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `marketing`, `newsletters`, `product_updates`

**Success**

`core/Modules/EmailCenter/Http/Controllers/Api/EmailPreferenceController.php:95`
```json
{
  "status": 200,
  "success": true,
  "message": "Email preferences updated.",
  "data": {
    "marketing": "...",
    "newsletters": "...",
    "product_updates": "...",
    "globally_unsubscribed": "...",
    "email": "..."
  }
}
```

</details>

### API guide — `/api-guide`

Component: `src/components/ApiGuide.vue` — **0 APIs**

_No API calls (static page or uses only the app-shell calls)._

### Email unsubscribe — `/unsubscribe`

Component: `src/components/Unsubscribe.vue` — **2 APIs**

1. `GET /api/email/unsubscribe/resolve` → `PublicUnsubscribeController@resolve`
2. `POST /api/email/unsubscribe` → `PublicUnsubscribeController@confirm`

<details><summary>Request / response details</summary>

##### `GET /api/email/unsubscribe/resolve`

- **Frontend:** `resolve` (`src/components/Unsubscribe.vue:57`)
- **Triggered from:** `resolve`
- **Backend:** `PublicUnsubscribeController@resolve` — `core/Modules/EmailCenter/Http/Controllers/Api/PublicUnsubscribeController.php:22-35`

**Success**

`core/Modules/EmailCenter/Http/Controllers/Api/PublicUnsubscribeController.php:30`
```json
{
  "status": 200,
  "success": true,
  "message": "ok",
  "data": {
    "valid": "...",
    "email": "...",
    "already_unsubscribed": "..."
  }
}
```

**Errors** (`success: false`)
- `:27` `422` — This unsubscribe link is invalid or has expired.

##### `POST /api/email/unsubscribe`

- **Frontend:** `confirm` (`src/components/Unsubscribe.vue:77`)
- **Triggered from:** `confirm`
- **Backend:** `PublicUnsubscribeController@confirm` — `core/Modules/EmailCenter/Http/Controllers/Api/PublicUnsubscribeController.php:37-52`

**Success**

`core/Modules/EmailCenter/Http/Controllers/Api/PublicUnsubscribeController.php:49`
```json
{
  "status": 200,
  "success": true,
  "message": "You have been unsubscribed from marketing emails.",
  "data": {
    "email": "..."
  }
}
```

**Errors** (`success: false`)
- `:43` `422` — This unsubscribe link is invalid or has expired.

</details>

---

## Promotions & extras (header / dashboard links)

> Not in the left sidebar; reached from the header, dashboard banners or direct links.

### Notifications list — `/notifications`

Component: `src/components/NotificationsList.vue` — **1 APIs**

1. `GET /api/user/notifications/all` → `NotificationController@showAllNotification`

<details><summary>Request / response details</summary>

##### `GET /api/user/notifications/all`

- **Frontend:** `fetchAllNotifications` (`src/services/notification.service.js:15`)
- **Triggered from:** `loadNotifications`
- **Backend:** `NotificationController@showAllNotification` — `core/app/Http/Controllers/Common/NotificationController.php:81-115`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/NotificationController.php:103`
```json
{
  "notifications": "..."
}
```

**Errors** (`success: false`)
- `:113` `500` — ($e->getMessage(), false, [], 500)

</details>

### Bonus — `/bonus`

Component: `src/components/Bonus.vue` — **4 APIs**

1. `GET /api/user/bonus` → `BonusController@index`
2. `GET /api/user/bonus/bonusClaimList` → `BonusController@bonusClaimList`
3. `POST /api/user/bonus/bonusClaim` → `BonusController@bonusClaim`
4. `POST /api/user/bonus/bonusClaimCancel` → `BonusController@cancelBonus`

<details><summary>Request / response details</summary>

##### `GET /api/user/bonus`

- **Frontend:** `bonusService.getBonuses` (`src/services/bonus.service.js:7`)
- **Triggered from:** `fetchBonuses`
- **Backend:** `BonusController@index` — `core/app/Http/Controllers/User/BonusController.php:18-133`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/BonusController.php:129`
```json
{
  "status": 200,
  "success": true,
  "message": "Bonus fetched successfully",
  "data": "<$data>"
}
```

##### `GET /api/user/bonus/bonusClaimList`

- **Frontend:** `bonusService.getBonusClaimHistory` (`src/services/bonus.service.js:44`)
- **Triggered from:** `fetchHistory`
- **Backend:** `BonusController@bonusClaimList` — `core/app/Http/Controllers/User/BonusController.php:630-720`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/BonusController.php:708`
```json
{
  "status": 200,
  "success": true,
  "message": "Bonus fetched successfully",
  "data": {
    "data": "...",
    "pagination": "...",
    "total": "...",
    "perPage": "...",
    "currentPage": "...",
    "lastPage": "...",
    "nextPageUrl": "...",
    "prevPageUrl": "..."
  }
}
```

##### `POST /api/user/bonus/bonusClaim`

- **Frontend:** `bonusService.claimBonus` (`src/services/bonus.service.js:24`)
- **Triggered from:** `confirmClaim`
- **Backend:** `BonusController@bonusClaim` — `core/app/Http/Controllers/User/BonusController.php:135-466`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `deposit_id`, `bonus_id`

**Success**

`core/app/Http/Controllers/User/BonusController.php:446`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "user_bonus_id": "...",
    "status": "..."
  }
}
```

**Errors** (`success: false`)
- `:153` `429` — Another bonus claim is already being processed for your account. Please wait a moment.
- `:165` `400` — Bonus request already exists
- `:169` `403` — Auto-bonus is disabled for your account. Please contact support.
- `:176` `403` — Invalid deposit
- `:180` `400` — Bonus is not available
- `:184` `400` — This bonus is outside its active period

##### `POST /api/user/bonus/bonusClaimCancel`

- **Frontend:** `bonusService.cancelBonus` (`src/services/bonus.service.js:34`)
- **Triggered from:** `confirmCancelBonus`
- **Backend:** `BonusController@cancelBonus` — `core/app/Http/Controllers/User/BonusController.php:528-628`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `id`, `reason`

**Success**

`core/app/Http/Controllers/User/BonusController.php:624`
```json
{
  "status": 200,
  "success": true,
  "message": "Bonus cancelled successfully.",
  "data": "<null>"
}
```

**Errors** (`success: false`)
- `:541` `404` — Bonus record not found or access denied.
- `:545` `400` — Only pending or claimed bonuses can be cancelled.
- `:549` `400` — Cannot cancel a bonus that has already been converted to balance.
- `:556` `404` — MT5 account not found.
- `:569` `400` — Failed to remove bonus from MT5: 
- `:626` `500` — Failed to submit cancel request: 

</details>

### Scratch card promotion — `/promotion`

Component: `src/components/scratchcard/promotion.vue` — **8 APIs**

1. `GET /api/user/mt5accounts/get` → `Mt5Controller@getMT5Accounts`
2. `GET /api/v1/user/scratch-cards` → `ScratchCardApiController@index`
3. `GET /api/v1/user/scratch-cards/leaderboard` → `ScratchCardApiController@leaderboard`
4. `POST /api/user/mobile-verification/send` → `MobileVerificationController@send`
5. `POST /api/user/mobile-verification/verify` → `MobileVerificationController@verify`
6. `POST /api/user/mt5accounts/create` → `Mt5Controller@createMT5Account`
7. `POST /api/v1/user/scratch-cards/claim` → `ScratchCardApiController@claim`
8. `POST /api/v1/user/scratch-cards/reveal` → `ScratchCardApiController@reveal`

<details><summary>Request / response details</summary>

##### `GET /api/user/mt5accounts/get`

- **Frontend:** `mt5Service.getAccounts` (`src/services/mt5.service.js:15`)
- **Triggered from:** `loadMt5AccountNumberMap`
- **Backend:** `Mt5Controller@getMT5Accounts` — `core/app/Http/Controllers/Common/Mt5Controller.php:146-341`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:337`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading accounts retrieved successfully",
  "data": "<$selectedAccounts>"
}
```

**Errors** (`success: false`)
- `:151` `401` — User not authenticated
- `:165` — No active trading accounts found
- `:339` `500` — Failed to retrieve trading accounts: 

##### `GET /api/v1/user/scratch-cards`

- **Frontend:** `scratchService.getScratchCards` (`src/services/scratch.service.js:38`)
- **Triggered from:** `fetchScratchCards`
- **Backend:** `ScratchCardApiController@index` — `core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:269-464`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:422`
```json
{
  "status": 200,
  "success": true,
  "message": "Scratch cards fetched successfully",
  "data": {
    "summary": "...",
    "earned_all_time": "...",
    "earned_in_30_days": "...",
    "max_limit_30_days": "...",
    "next_card_available_at": "...",
    "scratch_pending_reward_total": "...",
    "required_lots": "...",
    "lots_accumulated": "...",
    "lots_remaining": "...",
    "lots_progress_percent": "...",
    "active_step": "...",
    "active_step_status": "...",
    "steps": "...",
    "has_scratch_account": "...",
    "scratch_account_number": "...",
    "scratch_completed_once": "...",
    "scratch_offer_completed": "...",
    "can_claim": "...",
    "claim_status": "...",
    "claim_amount": "...",
    "claim_hint": "...",
    "mobile_verification_required": "...",
    "disabled": "...",
    "claim_request_id": "...",
    "cards_issued_in_30_day_period": "...",
    "card_issue_cap_30_day_period": "...",
    "card_issue_cap_reached": "...",
    "cards": "...",
    "pagination": "...",
    "page": "...",
    "per_page": "...",
    "total": "...",
    "last_page": "..."
  }
}
```

**Errors** (`success: false`)
- `:272` `403` — The luck is taking a break. Module disabled.

##### `GET /api/v1/user/scratch-cards/leaderboard`

- **Frontend:** `scratchService.getLeaderboard` (`src/services/scratch.service.js:50`)
- **Triggered from:** `fetchLeaderboard`
- **Backend:** `ScratchCardApiController@leaderboard` — `core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:162-220`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:213`
```json
{
  "status": 200,
  "success": true,
  "message": "Leaderboard fetched successfully",
  "data": {
    "window": "...",
    "window_key": "...",
    "range_label": "...",
    "leaderboard": "..."
  }
}
```

##### `POST /api/user/mobile-verification/send`

- **Frontend:** `mobileVerificationService.send` (`src/services/mobileVerification.service.js:20`)
- **Triggered from:** `send`
- **Backend:** `MobileVerificationController@send` — `core/app/Http/Controllers/User/MobileVerificationController.php:45-73`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:5,1`

**Success**

`core/app/Http/Controllers/User/MobileVerificationController.php:51`
```json
{
  "status": 200,
  "success": true,
  "message": "Mobile number is already verified.",
  "data": {
    "verified": "..."
  }
}
```
`core/app/Http/Controllers/User/MobileVerificationController.php:72`
```json
{
  "status": 200,
  "success": true,
  "message": "Code sent to ",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:54` `422` — Add a mobile number to your profile first.
- `:62` `429` — Please wait a minute before requesting another code.
- `:69` `422` — ($e->getMessage(), false, [], 422)

##### `POST /api/user/mobile-verification/verify`

- **Frontend:** `mobileVerificationService.verify` (`src/services/mobileVerification.service.js:29`)
- **Triggered from:** `verify`
- **Backend:** `MobileVerificationController@verify` — `core/app/Http/Controllers/User/MobileVerificationController.php:75-117`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`, `throttle:10,1`
- **Request fields (validated):** `otp`

**Success**

`core/app/Http/Controllers/User/MobileVerificationController.php:82`
```json
{
  "status": 200,
  "success": true,
  "message": "Mobile number is already verified.",
  "data": {
    "verified": "..."
  }
}
```
`core/app/Http/Controllers/User/MobileVerificationController.php:116`
```json
{
  "status": 200,
  "success": true,
  "message": "Mobile number verified.",
  "data": {
    "verified": "..."
  }
}
```

**Errors** (`success: false`)
- `:87` `429` — Too many wrong codes. Please try again in 
- `:95` `400` — The code has expired. Request a new one.
- `:102` `400` — Wrong code. 

##### `POST /api/user/mt5accounts/create`

- **Frontend:** `scratchService.createScratchAccount` (`src/services/scratch.service.js:89`)
- **Triggered from:** `ensureScratchTradingAccount`, `submitScratchAccount`, `persistScratchComplete`
- **Backend:** `Mt5Controller@createMT5Account` — `core/app/Http/Controllers/Common/Mt5Controller.php:495-521`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`


**Errors** (`success: false`)
- `:513` `429` — Your previous account request is still being processed. Please wait a moment and check your accounts list.

##### `POST /api/v1/user/scratch-cards/claim`

- **Frontend:** `scratchService.claimReward` (`src/services/scratch.service.js:61`)
- **Triggered from:** `onClaimReward`
- **Backend:** `ScratchCardApiController@claim` — `core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:466-489`
- **Middleware:** `auth:sanctum`, `throttle:10,1`

**Success**

`core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:484`
```json
{
  "status": 200,
  "success": true,
  "message": "Your claim has been sent for approval.",
  "data": {
    "claim_request_id": "...",
    "claim_status": "...",
    "claim_amount": "..."
  }
}
```

**Errors** (`success: false`)
- `:469` `403` — Module is currently disabled.
- `:475` `422` — ($e->getMessage(), false, [], 422)
- `:481` `422` — You already have a claim for this reward.

##### `POST /api/v1/user/scratch-cards/reveal`

- **Frontend:** `scratchService.revealCard` (`src/services/scratch.service.js:74`)
- **Triggered from:** `submitScratchAccount`, `persistScratchComplete`
- **Backend:** `ScratchCardApiController@reveal` — `core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:491-964`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `card_id`

**Success**

`core/Modules/ScratchCard/app/Http/Controllers/Api/ScratchCardApiController.php:946`
```json
{
  "status": 200,
  "success": true,
  "message": "...",
  "data": {
    "card_id": "...",
    "status": "...",
    "reward_amount": "...",
    "scratched_at": "...",
    "credit_status": "...",
    "credit_error": "...",
    "bonus_period": "...",
    "summary_update": "...",
    "earned_in_30_days": "...",
    "remaining_limit": "..."
  }
}
```

**Errors** (`success: false`)
- `:505` `403` — Module is currently disabled.
- `:510` `403` — Scratch card is not available on your account.
- `:517` `422` — Your scratch card offer is complete. The reward has already been paid.
- `:528` — Scratch trading account is required to reveal rewards.
- `:551` `422` — Card not found or already scratched.
- `:557` `422` — This card has expired.

</details>

### Trade & Win — `/promotion/trade-win`

Component: `src/components/TradeWin.vue` — **3 APIs**

1. `GET /api/v1/user/trade-win/products` → `TradeWinApiController@getProducts`
2. `GET /api/v1/user/trade-win/saved-addresses` → `TradeWinApiController@getSavedAddresses`
3. `POST /api/v1/user/trade-win/claim` → `TradeWinApiController@claimProduct`

<details><summary>Request / response details</summary>

##### `GET /api/v1/user/trade-win/products`

- **Frontend:** `tradeWinService.getProducts` (`src/services/tradeWin.service.js:14`)
- **Triggered from:** `refreshLeaderboard`, `fetchProducts`
- **Backend:** `TradeWinApiController@getProducts` — `core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:272-466`
- **Middleware:** `auth:sanctum`, `throttle:api`

**Success**

`core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:449`
```json
{
  "message": "...",
  "status": "...",
  "module_enabled": "...",
  "data": "...",
  "products": "...",
  "stats": "...",
  "leaderboard": "...",
  "symbol_categories": "...",
  "reward_categories": "...",
  "past_wins": "...",
  "audience": "...",
  "availability": "...",
  "availability_counts": "..."
}
```

##### `GET /api/v1/user/trade-win/saved-addresses`

- **Frontend:** `tradeWinService.getSavedAddresses` (`src/services/tradeWin.service.js:49`)
- **Triggered from:** `openRedeemModal`
- **Backend:** `TradeWinApiController@getSavedAddresses` — `core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:805-817`
- **Middleware:** `auth:sanctum`, `throttle:api`

**Success**

`core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:812`
```json
{
  "status": "...",
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:809` `401` — (['status' => false, 'message' => 'User not authenticated.'], 401)

##### `POST /api/v1/user/trade-win/claim`

- **Frontend:** `tradeWinService.claimProduct` (`src/services/tradeWin.service.js:26`)
- **Triggered from:** `handleFinalClaim`
- **Backend:** `TradeWinApiController@claimProduct` — `core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:622-803`
- **Middleware:** `auth:sanctum`, `throttle:api`
- **Request fields (validated):** `product_id`, `quantity`, `shipping_details`, `audience`

**Success**

`core/Modules/TradeWin/app/Http/Controllers/Api/TradeWinApiController.php:795`
```json
{
  "message": "...",
  "status": "...",
  "claim_id": "...",
  "reference_no": "...",
  "shipping_details": "...",
  "saved_addresses": "..."
}
```

**Errors** (`success: false`)
- `:643` `400` — (['message' => 'Insufficient stock', 'status' => false], 400)
- `:648` `400` — ([ 'message' => 'This reward is outside its campaign window', 'status' => false, ], 400)
- `:660` `400` — ([ 'message' => sprintf( 'Deposit requirement not met — $%s more needed', number_format($requiredDeposit - $availableDeposit, 2) ), 'status'
- `:729` `400` — ([ 'message' => "Insufficient {$poolLabel} lot volume balance", 'status' => false, ], 400)

</details>

### Demo Contest list — `/demo-contest`

Component: `src/components/DemoContest.vue` — **13 APIs**

1. `GET /api/user/demo-contest/{contestId}/leaderboard` → `DemoContestApiController@contestLeaderboard`
2. `GET /api/user/demo-contest/{contestId}/rule-violations` → `DemoContestApiController@getRuleViolations`
3. `GET /api/user/demo-contest/{contestId}/steps` → `DemoContestApiController@getEnrollmentSteps`
4. `GET /api/user/demo-contest/{contestId}/terms` → `DemoContestApiController@getTerms`
5. `GET /api/user/demo-contest/{contestId}/trading-history` → `DemoContestApiController@getTradingHistory`
6. `GET /api/user/demo-contest/contests` → `DemoContestApiController@getAllContests`
7. `GET /api/user/demo-contest/my-stats` → `DemoContestApiController@getMyStats`
8. `GET /api/user/kyc` → `KYCController@getUserDocuments`
9. `GET /api/user/mt5accounts/get` → `Mt5Controller@getMT5Accounts`
10. `POST /api/user/demo-contest/{contestId}/enroll` → `DemoContestApiController@enroll`
11. `POST /api/user/demo-contest/{contestId}/enroll-preview` → `DemoContestApiController@enrollPreview`
12. `POST /api/user/demo-contest/claim` → `DemoContestApiController@claimPrize`
13. `POST /api/user/demo-contest/step/{stepId}/click` → `DemoContestApiController@markStepClicked`

<details><summary>Request / response details</summary>

##### `GET /api/user/demo-contest/{contestId}/leaderboard`

- **Frontend:** `demoContestService.getContestLeaderboard` (`src/services/demoContest.service.js:167`)
- **Triggered from:** `selectContest`
- **Backend:** `DemoContestApiController@contestLeaderboard` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:502-527`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:522`
```json
{
  "status": "...",
  "type": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:506` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `GET /api/user/demo-contest/{contestId}/rule-violations`

- **Frontend:** `demoContestService.getRuleViolations` (`src/services/demoContest.service.js:197`)
- **Triggered from:** `loadTradingData`
- **Backend:** `DemoContestApiController@getRuleViolations` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:762-790`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:786`
```json
{
  "status": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:766` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)
- `:771` `404` — (['status' => false, 'message' => 'Contest not found.'], 404)
- `:780` `404` — (['status' => false, 'message' => 'You are not enrolled in this contest.'], 404)

##### `GET /api/user/demo-contest/{contestId}/steps`

- **Frontend:** `demoContestService.getEnrollmentSteps` (`src/services/demoContest.service.js:140`)
- **Triggered from:** `startEnrollmentFlow`
- **Backend:** `DemoContestApiController@getEnrollmentSteps` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:231-266`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:239`
```json
{
  "status": "...",
  "data": "...",
  "enabled": "..."
}
```
`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:260`
```json
{
  "status": "...",
  "enabled": "...",
  "data": "...",
  "all_done": "..."
}
```

**Errors** (`success: false`)
- `:235` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `GET /api/user/demo-contest/{contestId}/terms`

- **Frontend:** `demoContestService.getTerms` (`src/services/demoContest.service.js:176`)
- **Triggered from:** `proceedAfterTasks`
- **Backend:** `DemoContestApiController@getTerms` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:532-544`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:539`
```json
{
  "status": "...",
  "enabled": "...",
  "content": "..."
}
```

**Errors** (`success: false`)
- `:536` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `GET /api/user/demo-contest/{contestId}/trading-history`

- **Frontend:** `demoContestService.getTradingHistory` (`src/services/demoContest.service.js:185`)
- **Triggered from:** `loadTradingData`
- **Backend:** `DemoContestApiController@getTradingHistory` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:724-756`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:750`
```json
{
  "status": "...",
  "data": "...",
  "total": "...",
  "account": "..."
}
```

**Errors** (`success: false`)
- `:728` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)
- `:733` `404` — (['status' => false, 'message' => 'Contest not found.'], 404)
- `:742` `404` — (['status' => false, 'message' => 'You are not enrolled in this contest.'], 404)

##### `GET /api/user/demo-contest/contests`

- **Frontend:** `demoContestService.getContests` (`src/services/demoContest.service.js:113`)
- **Triggered from:** `fetchContestData`
- **Backend:** `DemoContestApiController@getAllContests` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:36-188`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:184`
```json
{
  "status": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:40` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)

##### `GET /api/user/demo-contest/my-stats`

- **Frontend:** `demoContestService.getMyStats` (`src/services/demoContest.service.js:77`)
- **Triggered from:** `loadEnrollmentStats`, `selectContest`
- **Backend:** `DemoContestApiController@getMyStats` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:549-618`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:573`
```json
{
  "status": "...",
  "data": "...",
  "rank": "...",
  "participant": "...",
  "days_left": "..."
}
```

**Errors** (`success: false`)
- `:553` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)
- `:558` `400` — (['status' => false, 'message' => 'Contest ID is required.'], 400)
- `:563` `404` — (['status' => false, 'message' => 'Contest not found.'], 404)

##### `GET /api/user/kyc`

- **Frontend:** `kycService.getUserDocuments` (`src/services/kyc.service.js:78`)
- **Triggered from:** `checkEligibility`
- **Backend:** `KYCController@getUserDocuments` — `core/app/Http/Controllers/User/KYCController.php:102-264`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:248`
```json
{
  "status": 200,
  "success": true,
  "message": "KYC data fetched successfully",
  "data": "<$responseData>"
}
```

**Errors** (`success: false`)
- `:259` `500` — An error occurred while fetching KYC data.

##### `GET /api/user/mt5accounts/get`

- **Frontend:** `mt5Service.getAccounts` (`src/services/mt5.service.js:15`)
- **Triggered from:** `checkEligibility`
- **Backend:** `Mt5Controller@getMT5Accounts` — `core/app/Http/Controllers/Common/Mt5Controller.php:146-341`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:337`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading accounts retrieved successfully",
  "data": "<$selectedAccounts>"
}
```

**Errors** (`success: false`)
- `:151` `401` — User not authenticated
- `:165` — No active trading accounts found
- `:339` `500` — Failed to retrieve trading accounts: 

##### `POST /api/user/demo-contest/{contestId}/enroll`

- **Frontend:** `demoContestService.enrollContest` (`src/services/demoContest.service.js:158`)
- **Triggered from:** `enroll`
- **Backend:** `DemoContestApiController@enroll` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:290-481`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:466`
```json
{
  "status": "...",
  "message": "...",
  "data": "...",
  "participant_id": "...",
  "mt5_account": "...",
  "enrollment_fee_paid": "...",
  "wallet_balance_before": "...",
  "wallet_balance_after": "..."
}
```

**Errors** (`success: false`)
- `:295` `404` — (['status' => false, 'message' => 'Contest not found'], 404)
- `:300` `422` — (['status' => false, 'message' => 'This contest has been cancelled.'], 422)
- `:305` `422` — (['status' => false, 'message' => 'Enrollment window is closed.'], 422)
- `:318` `422` — (['status' => false, 'message' => $msg], 422)
- `:329` `422` — ([ 'status' => false, 'message' => 'You are already enrolled in another active contest. This contest does not allow concurrent contest parti
- `:340` `422` — ([ 'status' => false, 'message' => 'You must complete KYC verification to enroll in this contest.', ], 422)

##### `POST /api/user/demo-contest/{contestId}/enroll-preview`

- **Frontend:** `demoContestService.enrollPreview` (`src/services/demoContest.service.js:131`)
- **Triggered from:** `proceedAfterTasks`
- **Backend:** `DemoContestApiController@enrollPreview` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:193-226`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:211`
```json
{
  "status": "...",
  "data": "...",
  "enrollment_fee": "...",
  "wallet_balance": "...",
  "wallet_after": "...",
  "can_enroll": "...",
  "enrollment_required": "...",
  "tasks_required": "...",
  "terms_required": "...",
  "multiple_allowed": "...",
  "current_participations": "...",
  "max_participations": "..."
}
```

**Errors** (`success: false`)
- `:198` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `POST /api/user/demo-contest/claim`

- **Frontend:** `demoContestService.claimPrize` (`src/services/demoContest.service.js:101`)
- **Triggered from:** `confirmSubmitClaim`
- **Backend:** `DemoContestApiController@claimPrize` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:623-718`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `contest_id`, `real_account_number`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:713`
```json
{
  "status": "...",
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:627` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)
- `:638` `404` — (['status' => false, 'message' => 'Contest not found.'], 404)
- `:642` `422` — (['status' => false, 'message' => 'This contest is not completed yet.'], 422)
- `:651` `422` — (['status' => false, 'message' => 'You are not registered in this contest.'], 422)
- `:659` `422` — (['status' => false, 'message' => 'You have already submitted a claim for this contest.'], 422)
- `:671` `422` — (['status' => false, 'message' => 'Your rank could not be verified.'], 422)

##### `POST /api/user/demo-contest/step/{stepId}/click`

- **Frontend:** `demoContestService.markStepClicked` (`src/services/demoContest.service.js:149`)
- **Triggered from:** `openTaskLink`
- **Backend:** `DemoContestApiController@markStepClicked` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:271-285`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:284`
```json
{
  "status": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:276` `404` — (['status' => false, 'message' => 'Step not found'], 404)

</details>

### Demo Contest detail — `/demo-contest/:id`

Component: `src/components/DemoContestDetail.vue` — **14 APIs**

1. `GET /api/user/demo-contest/{contestId}/leaderboard` → `DemoContestApiController@contestLeaderboard`
2. `GET /api/user/demo-contest/{contestId}/rule-violations` → `DemoContestApiController@getRuleViolations`
3. `GET /api/user/demo-contest/{contestId}/steps` → `DemoContestApiController@getEnrollmentSteps`
4. `GET /api/user/demo-contest/{contestId}/terms` → `DemoContestApiController@getTerms`
5. `GET /api/user/demo-contest/{contestId}/trading-history` → `DemoContestApiController@getTradingHistory`
6. `GET /api/user/demo-contest/contests` → `DemoContestApiController@getAllContests`
7. `GET /api/user/demo-contest/my-stats` → `DemoContestApiController@getMyStats`
8. `GET /api/user/kyc` → `KYCController@getUserDocuments`
9. `GET /api/user/mt5accounts/get` → `Mt5Controller@getMT5Accounts`
10. `POST /api/user/demo-contest/{contestId}/enroll` → `DemoContestApiController@enroll`
11. `POST /api/user/demo-contest/{contestId}/enroll-preview` → `DemoContestApiController@enrollPreview`
12. `POST /api/user/demo-contest/claim` → `DemoContestApiController@claimPrize`
13. `POST /api/user/demo-contest/step/{stepId}/click` → `DemoContestApiController@markStepClicked`
14. `POST /api/user/mt5accounts/changePrimaryAccount` → `Mt5Controller@changePrimaryAccount`

<details><summary>Request / response details</summary>

##### `GET /api/user/demo-contest/{contestId}/leaderboard`

- **Frontend:** `demoContestService.getContestLeaderboard` (`src/services/demoContest.service.js:167`)
- **Triggered from:** `selectContest`
- **Backend:** `DemoContestApiController@contestLeaderboard` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:502-527`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:522`
```json
{
  "status": "...",
  "type": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:506` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `GET /api/user/demo-contest/{contestId}/rule-violations`

- **Frontend:** `demoContestService.getRuleViolations` (`src/services/demoContest.service.js:197`)
- **Triggered from:** `loadTradingData`
- **Backend:** `DemoContestApiController@getRuleViolations` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:762-790`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:786`
```json
{
  "status": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:766` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)
- `:771` `404` — (['status' => false, 'message' => 'Contest not found.'], 404)
- `:780` `404` — (['status' => false, 'message' => 'You are not enrolled in this contest.'], 404)

##### `GET /api/user/demo-contest/{contestId}/steps`

- **Frontend:** `demoContestService.getEnrollmentSteps` (`src/services/demoContest.service.js:140`)
- **Triggered from:** `startEnrollmentFlow`
- **Backend:** `DemoContestApiController@getEnrollmentSteps` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:231-266`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:239`
```json
{
  "status": "...",
  "data": "...",
  "enabled": "..."
}
```
`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:260`
```json
{
  "status": "...",
  "enabled": "...",
  "data": "...",
  "all_done": "..."
}
```

**Errors** (`success: false`)
- `:235` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `GET /api/user/demo-contest/{contestId}/terms`

- **Frontend:** `demoContestService.getTerms` (`src/services/demoContest.service.js:176`)
- **Triggered from:** `openEnrollModal`
- **Backend:** `DemoContestApiController@getTerms` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:532-544`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:539`
```json
{
  "status": "...",
  "enabled": "...",
  "content": "..."
}
```

**Errors** (`success: false`)
- `:536` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `GET /api/user/demo-contest/{contestId}/trading-history`

- **Frontend:** `demoContestService.getTradingHistory` (`src/services/demoContest.service.js:185`)
- **Triggered from:** `loadTradingData`
- **Backend:** `DemoContestApiController@getTradingHistory` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:724-756`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:750`
```json
{
  "status": "...",
  "data": "...",
  "total": "...",
  "account": "..."
}
```

**Errors** (`success: false`)
- `:728` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)
- `:733` `404` — (['status' => false, 'message' => 'Contest not found.'], 404)
- `:742` `404` — (['status' => false, 'message' => 'You are not enrolled in this contest.'], 404)

##### `GET /api/user/demo-contest/contests`

- **Frontend:** `demoContestService.getContests` (`src/services/demoContest.service.js:113`)
- **Triggered from:** `fetchContestData`
- **Backend:** `DemoContestApiController@getAllContests` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:36-188`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:184`
```json
{
  "status": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:40` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)

##### `GET /api/user/demo-contest/my-stats`

- **Frontend:** `demoContestService.getMyStats` (`src/services/demoContest.service.js:77`)
- **Triggered from:** `loadEnrollmentStats`, `selectContest`
- **Backend:** `DemoContestApiController@getMyStats` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:549-618`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:573`
```json
{
  "status": "...",
  "data": "...",
  "rank": "...",
  "participant": "...",
  "days_left": "..."
}
```

**Errors** (`success: false`)
- `:553` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)
- `:558` `400` — (['status' => false, 'message' => 'Contest ID is required.'], 400)
- `:563` `404` — (['status' => false, 'message' => 'Contest not found.'], 404)

##### `GET /api/user/kyc`

- **Frontend:** `kycService.getUserDocuments` (`src/services/kyc.service.js:78`)
- **Triggered from:** `checkEligibility`
- **Backend:** `KYCController@getUserDocuments` — `core/app/Http/Controllers/User/KYCController.php:102-264`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/User/KYCController.php:248`
```json
{
  "status": 200,
  "success": true,
  "message": "KYC data fetched successfully",
  "data": "<$responseData>"
}
```

**Errors** (`success: false`)
- `:259` `500` — An error occurred while fetching KYC data.

##### `GET /api/user/mt5accounts/get`

- **Frontend:** `mt5Service.getAccounts` (`src/services/mt5.service.js:15`)
- **Triggered from:** `checkEligibility`
- **Backend:** `Mt5Controller@getMT5Accounts` — `core/app/Http/Controllers/Common/Mt5Controller.php:146-341`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:337`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading accounts retrieved successfully",
  "data": "<$selectedAccounts>"
}
```

**Errors** (`success: false`)
- `:151` `401` — User not authenticated
- `:165` — No active trading accounts found
- `:339` `500` — Failed to retrieve trading accounts: 

##### `POST /api/user/demo-contest/{contestId}/enroll`

- **Frontend:** `demoContestService.enrollContest` (`src/services/demoContest.service.js:158`)
- **Triggered from:** `enroll`
- **Backend:** `DemoContestApiController@enroll` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:290-481`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:466`
```json
{
  "status": "...",
  "message": "...",
  "data": "...",
  "participant_id": "...",
  "mt5_account": "...",
  "enrollment_fee_paid": "...",
  "wallet_balance_before": "...",
  "wallet_balance_after": "..."
}
```

**Errors** (`success: false`)
- `:295` `404` — (['status' => false, 'message' => 'Contest not found'], 404)
- `:300` `422` — (['status' => false, 'message' => 'This contest has been cancelled.'], 422)
- `:305` `422` — (['status' => false, 'message' => 'Enrollment window is closed.'], 422)
- `:318` `422` — (['status' => false, 'message' => $msg], 422)
- `:329` `422` — ([ 'status' => false, 'message' => 'You are already enrolled in another active contest. This contest does not allow concurrent contest parti
- `:340` `422` — ([ 'status' => false, 'message' => 'You must complete KYC verification to enroll in this contest.', ], 422)

##### `POST /api/user/demo-contest/{contestId}/enroll-preview`

- **Frontend:** `demoContestService.enrollPreview` (`src/services/demoContest.service.js:131`)
- **Triggered from:** `openEnrollModal`
- **Backend:** `DemoContestApiController@enrollPreview` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:193-226`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:211`
```json
{
  "status": "...",
  "data": "...",
  "enrollment_fee": "...",
  "wallet_balance": "...",
  "wallet_after": "...",
  "can_enroll": "...",
  "enrollment_required": "...",
  "tasks_required": "...",
  "terms_required": "...",
  "multiple_allowed": "...",
  "current_participations": "...",
  "max_participations": "..."
}
```

**Errors** (`success: false`)
- `:198` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

##### `POST /api/user/demo-contest/claim`

- **Frontend:** `demoContestService.claimPrize` (`src/services/demoContest.service.js:101`)
- **Triggered from:** `confirmSubmitClaim`
- **Backend:** `DemoContestApiController@claimPrize` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:623-718`
- **Middleware:** `auth:sanctum`
- **Request fields (validated):** `contest_id`, `real_account_number`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:713`
```json
{
  "status": "...",
  "message": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:627` `401` — (['status' => false, 'message' => 'Unauthenticated.'], 401)
- `:638` `404` — (['status' => false, 'message' => 'Contest not found.'], 404)
- `:642` `422` — (['status' => false, 'message' => 'This contest is not completed yet.'], 422)
- `:651` `422` — (['status' => false, 'message' => 'You are not registered in this contest.'], 422)
- `:659` `422` — (['status' => false, 'message' => 'You have already submitted a claim for this contest.'], 422)
- `:671` `422` — (['status' => false, 'message' => 'Your rank could not be verified.'], 422)

##### `POST /api/user/demo-contest/step/{stepId}/click`

- **Frontend:** `demoContestService.markStepClicked` (`src/services/demoContest.service.js:149`)
- **Triggered from:** `openTaskLink`
- **Backend:** `DemoContestApiController@markStepClicked` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:271-285`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:284`
```json
{
  "status": "...",
  "message": "..."
}
```

**Errors** (`success: false`)
- `:276` `404` — (['status' => false, 'message' => 'Step not found'], 404)

##### `POST /api/user/mt5accounts/changePrimaryAccount`

- **Frontend:** `mt5Service.setPrimaryAccount` (`src/services/mt5.service.js:191`)
- **Triggered from:** `handleTradeNow`
- **Backend:** `Mt5Controller@changePrimaryAccount` — `core/app/Http/Controllers/Common/Mt5Controller.php:455-474`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/Mt5Controller.php:468`
```json
{
  "message": "..."
}
```
`core/app/Http/Controllers/Common/Mt5Controller.php:469`
```json
{
  "status": 200,
  "success": true,
  "message": "Primary account changed successfully",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:461` `404` — Trading account not found.
- `:462` `404` — Trading account not found
- `:471` `500` — ($e->getMessage(), false, [], 500)
- `:472` `500` — ($e->getMessage(), false, [], 500)

</details>

### Demo Contest leaderboard — `/demo-contest/:id/leaderboard`

Component: `src/components/DemoContestLeaderboardPage.vue` — **1 APIs**

1. `GET /api/user/demo-contest/{contestId}/leaderboard` → `DemoContestApiController@contestLeaderboard`

<details><summary>Request / response details</summary>

##### `GET /api/user/demo-contest/{contestId}/leaderboard`

- **Frontend:** `demoContestService.getContestLeaderboard` (`src/services/demoContest.service.js:167`)
- **Triggered from:** `fetchLeaderboard`
- **Backend:** `DemoContestApiController@contestLeaderboard` — `core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:502-527`
- **Middleware:** `auth:sanctum`

**Success**

`core/Modules/DemoContest/app/Http/Controllers/Api/DemoContestApiController.php:522`
```json
{
  "status": "...",
  "type": "...",
  "data": "..."
}
```

**Errors** (`success: false`)
- `:506` `404` — (['status' => false, 'message' => 'Contest not found'], 404)

</details>

### Trading Central — `/trading-central/:page?`

Component: `src/components/TradingCentralPage.vue` — **1 APIs**

1. `GET /api/user/trading-central` → `SettingController@getTradingCentral`

<details><summary>Request / response details</summary>

##### `GET /api/user/trading-central`

- **Frontend:** `loadTradingCentral` (`src/components/TradingCentralPage.vue:131`)
- **Triggered from:** `loadTradingCentral`
- **Backend:** `SettingController@getTradingCentral` — `core/app/Http/Controllers/Common/SettingController.php:1396-1410`
- **Middleware:** `logNavigation`, `auth:sanctum`, `throttle:api`

**Success**

`core/app/Http/Controllers/Common/SettingController.php:1399`
```json
{
  "status": 200,
  "success": true,
  "message": "Trading Central settings retrieved successfully",
  "data": "<TradingCentralService::stateForUser(optional(auth()->user())->id)>"
}
```

**Errors** (`success: false`)
- `:1408` `500` — Error: 

</details>

### Under maintenance — `/maintenance`

Component: `src/views/UnderMaintenance.vue` — **0 APIs**

_No API calls (static page or uses only the app-shell calls)._

---

