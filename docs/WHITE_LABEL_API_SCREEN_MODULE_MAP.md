# White Label App API — Screen/Module Inventory

**Scope:** Flutter app under `lib/`, including direct `ApiService`/`ApiClient` calls, raw HTTP, chart REST, and WebSocket-backed flows.

**Flavors:** Pipze is a Vantage child flavor. The screen/controller/API layer is shared; only `apiBaseUrl`, `websocketUrl`, `chartBaseUrl`, branding, and feature flags vary. Pipze source values are `https://my.pipze.com/api/`, `wss://my.pipze.com/trade-engine`, and `https://my.pipze.com` (`assets/config/brands/brands.yaml:202-222`).

## 1. Transport and cross-cutting logic

| Layer | Location | Responsibility |
|---|---|---|
| API constants | `lib/constants/api_const.dart:3-283` | Central endpoint paths; most paths use `user/`, Scratch Card and Trade & Win use `v1/user/`. |
| HTTP service | `lib/services/api_service.dart:64-93` | Bearer token, JSON requests, retry/error handling, 401 session handling, multipart/form requests. |
| Repository client | `lib/core/network/api_client.dart`, `lib/services/api_service_client.dart:8-37` | Typed repository-facing adapter over the shared API service. |
| Startup/auth | `lib/main.dart:794-876`, `lib/screens/auth/view_models/auth_controller.dart:1286-1373` | Token check, auth cleanup, controller initialization, startup network suppression, navigation. |
| WebSockets | `lib/services/unified_websocket_service.dart:1-151`, `lib/services/websocket_endpoint_helper.dart:147-173` | Market watch, symbols, open positions, pending orders, account switching and reconnect. |
| Flavor config | `lib/flavor_config.dart`, `assets/config/brands/brands.yaml:202-222` | Vantage/Pipze API, socket and chart URLs. |

## 2. Module-wise screen and API map

### 00 — Bootstrap / app status

- **Screens/flows:** Splash, `AuthCheckScreen`, maintenance/update screens.
- **API:** `GET user/mobile-app-details` — version, maintenance and force-update gate; `GET user/crm-settings` — remote CRM configuration; `GET user/enabled-modules` — per-user module flags.
- **Code:** `lib/services/app_status/app_status_service.dart`, `lib/services/crm_settings_service.dart`, `lib/services/enabled_modules_service.dart`, `lib/main.dart:794-876`.
- **Local logic:** startup timer/suppression, cached config/model parsing, maintenance/update state, feature-gate decisions, unauthenticated redirect.
- **Note:** periodic app-status polling is currently disabled in `app_status_service.dart`; `assets/mock/app_status_response.json` is a local mock.

### 01 — Authentication and session

- **Screens:** Login, register, email OTP, forgot-password, reset-password, Google login/OTP, logout.
- **API:** `POST user/register`, `POST user/send-otp`, `POST user/verify-otp`, `POST user/login`, `POST user/auth/google/check-mobile`, `POST user/auth/google/verify-login-otp`, `POST user/password/email`, `POST user/password/forgot`, `POST user/password/verify-otp`, `POST user/password/reset`, `POST user/reset-password`, `POST user/register-fcm-token`, `POST user/logout`.
- **Code:** `lib/screens/auth/view_models/auth_controller.dart`, `lib/services/auth_service.dart:78-107`, `lib/screens/auth/data/repositories/auth_repository_impl.dart:93`, `lib/services/google_otp_service.dart:26-105`.
- **Local logic:** connectivity pre-check, token/user persistence, response normalization, OTP state/countdown, controller reinitialization, pending notification routing, WebSocket cache reset.

### 02 — Password and security

- **Screens:** Change password, Google 2FA settings, delete account.
- **API:** `POST user/settings/change-password`, `POST user/mt5accounts/changepassword`, `POST user/mt5accounts/resetinvestorpassword`, `POST user/settings/google-otp/generate`, `POST user/settings/google-otp/verify`, `POST user/settings/google-otp/disable`, `POST user/settings/delete-account`.
- **Code:** `lib/screens/auth/view_models/change_password_controller.dart`, `lib/screens/more/view_models/two_factor_auth_controller.dart`, `lib/services/google_otp_service.dart`.
- **Local logic:** form validation, OTP visibility/state, secure-token cleanup, confirmation dialogs, post-success logout/navigation.

### 03 — Home, dashboard, accounts and market watch

- **Screens:** Trading home, dashboard/accounts, instrument list, search/filter, account management, create account, leverage/password management.
- **API:** `GET user/dashboard`, `GET user/mt5accounts/get`, `POST user/mt5accounts/plandetails`, `POST user/mt5accounts/create`, `GET/POST user/mt5accounts/mt5AccountSync` (caller-dependent), `POST user/mt5accounts/setbalance`, `POST user/mt5accounts/changePrimaryAccount`, `GET user/instruments`, `GET user/instruments/{accountNumber}`.
- **Code:** `lib/screens/trading/view_models/dashboard_controller.dart:246`, `lib/screens/trading/view_models/account_controller.dart:214`, `lib/screens/trading/view_models/instruments_controller.dart:538`, `lib/services/symbol_details_cache_service.dart:181-239`.
- **Local logic:** primary-account selection, account-type detection, cache fallback, 24-hour symbol cache, response normalization, sorting/filtering, stale-account invalidation, reconnect after account switch.

### 04 — Trading, positions, pending orders and history

- **Screens:** Trade screen, order ticket, close-position screen, edit-order screen, pending-order content, trade history.
- **API:** `POST user/trade/new-order`, `POST user/trade/closePositionByPositionId`, `POST user/trade/closePositions`, `POST user/trade/closePendingOrder`, `POST user/trade/cancel-pending-order`, `POST user/trade/modify-pending-order`, `POST user/trade/update-tp-sl`, `POST user/trade/update-pending-order-tp-sl`, `GET user/trade/tradehistory`.
- **Code:** `lib/screens/trading/view_models/trading_controller.dart`, `lib/screens/trading/data/repositories/trading_repository_impl.dart:12-80`, `lib/screens/home/chart_screen.dart`.
- **Local logic:** Buy/Sell and pending-order validation, volume/price normalization, TP/SL checks, insufficient-balance handling, optimistic loading/toasts, bulk-close selection, pagination/filter state.

### 05 — Chart and real-time market data

- **Screens/widgets:** Chart screen, chart WebView, Tenax chart, advanced chart.
- **REST:** `POST {chartBaseUrl}/charthistory` from `lib/services/chart_datafeed_bridge.dart:113-173`.
- **WebSockets:** market watch, symbols, open positions, pending orders; endpoint construction in `lib/services/websocket_endpoint_helper.dart:147-173`.
- **Local logic:** display-symbol/datafeed-symbol resolution, `.C`/`.R` suffix normalization, digit-based `point`/`pricescale`, bid/ask midpoint, tick-to-bar aggregation, bar subscription cleanup, history-to-socket seed, persistent symbol mapping.

### 06 — Finance: deposit

- **Screens:** Finance, deposit, payment methods, deposit instruction, deposit camera, Cregis address/success.
- **API:** `GET user/deposit`, `GET user/deposit/{slug}`, multipart `POST user/deposit/depositrequest`, `POST user/deposit/cregis`, `GET user/deposit/by-reference`, `GET user/mt5accounts/get`, `POST user/mt5accounts/setbalance`.
- **Code:** `lib/screens/finance/data/repositories/finance_repository_impl.dart:14-181`, `lib/screens/finance/view_models/deposit_instruction_controller.dart:279-508`, `lib/screens/finance/presentation/pages/cregis_address_screen.dart:44-148`.
- **Local logic:** amount/file validation, gateway/network selection, multipart assembly, Cregis response parsing, timer polling by reference, timeout/success navigation, account cache invalidation.

### 07 — Finance: withdrawal, wallet and transfers

- **Screens:** Withdrawal, wallet, internal transfer, internal-transfer history, saved withdrawal methods.
- **API:** `GET user/wallet`, `GET user/internaltransfer`, `GET user/withdrawal`, `GET user/withdrawal/withdrawal-method/{slug}`, `GET user/withdrawal/getUserWithdrawalMethods`, `GET user/withdrawal/checkbalance`, `GET user/withdrawal/sendOTP`, `POST user/withdrawal/withdrawalrequest`, multipart `POST user/withdrawal`, `POST user/internaltransfer/request`, `GET user/internaltransfer/history`, `GET user/transactions`, `GET user/utility/currency-list`.
- **Code:** `lib/screens/finance/view_models/withdrawal_controller.dart:908`, `lib/screens/wallet/view_models/wallet_controller.dart:160-180`, `lib/screens/finance/view_models/internal_transfer_history_controller.dart:311`, `lib/screens/finance/view_models/transaction_history_controller.dart:804-833`.
- **Local logic:** bank/crypto/UPI payload branching, amount/account/OTP checks, balance checks, source-target validation, same-account rejection, decimal precision, pagination/filtering, receipt download progress.

### 08 — Profile, dropdowns and notifications

- **Screens:** View/edit profile, country/state/city selectors, notifications.
- **API:** `GET/POST user/settings/profile`, `GET user/settings/getCountryDropdown`, `POST user/settings/getStateDropdown`, `POST user/settings/getCityDropdown`, `GET user/notifications`, `POST user/price-alerts`.
- **Code:** `lib/screens/profile/data/repositories/profile_repository_impl.dart:7-25`, `lib/services/dropdown_service.dart:35`, `lib/screens/notifications/data/providers/notification_api_provider.dart:8`.
- **Local logic:** five-page profile payload assembly, dropdown dependency chain, notification parsing, FCM foreground/background handling, deferred notification navigation.

### 09 — KYC and compliance

- **Screens:** KYC intro/details/docs/success, bank KYC, unified compliance wizard.
- **API:** `GET user/kyc`, `POST user/kyc/profile`, `GET/POST user/regulation`, multipart `POST user/kyc/documents/upload`, multipart `POST user/kyc/submit-unified`, `GET user/utility/currency-list`.
- **Code:** `lib/screens/kyc/data/repositories/kyc_repository_impl.dart`, `lib/screens/kyc/view_models/compliance_controller.dart:206`.
- **Local logic:** stage-completion gating, document/file mapping, required-document validation, questionnaire state, upload progress and retry, response-to-stage mapping.

### 10 — IB / Introducing Broker

- **Screens:** IB main/dashboard, clients, network/structure, requests, commission groups, transfers, more.
- **API:** legacy IB constants in `lib/constants/api_const.dart:96-123`: status/application/dashboard/clients/sub-IBs/trade-history/stats/structure/approval requests, transfer create/client search/store/history/cancel, request list/track visit/commission groups/manage/update status. IBM client/portal APIs are under `/api/ibm/`: `GET ibm/client/system`, `GET/POST ibm/client/partner-request`, `GET ibm/client/account-groups`, plus portal dashboard/activity/network/summary/tree-summary/performance/detail/node/wallet/plan/links/symbols, clients and links routes.
- **Code:** `lib/screens/ib/data/datasources/ib_remote_data_source.dart:5-170`, `lib/screens/ib/view_models/ib_controller.dart:670`, `lib/screens/ibm/data/providers/ibm_api_provider.dart`, `POSTMAN_CLIENT_API.postman_collection.json:26-240`.
- **Local logic:** `GET /api/ibm/client/system` selects `ibm|legacy|none` before rendering IB UI; tab-specific loading/error state, network-tree parsing/dedup/enrichment, own-vs-branch totals, pagination, date filters, referral-link form validation, transfer balance/OTP validation.

### 11 — Copy trading

- **Screens:** Hub, explore masters, trader details, investment detail, subscribe/edit subscription, master dashboard, plans, copiers, master detail.
- **API:** public `GET copytrading/masters`, public master profile/history; authenticated master apply/status/dashboard stats/overview/plans/open-positions/pause/resume/update; copier eligible accounts/subscribe/subscriptions/detail/trades/PnL/add-capital/pause/resume/stop/update.
- **Code:** `lib/controllers/copy_trading/*.dart`, `lib/screens/copy_trading/investment_detail_screen.dart:81`, `lib/screens/copy_trading/components/edit_subscription_sheet.dart:88`.
- **Local logic:** plan/subscription state machines, pagination, PnL/stat aggregation, form validation, loading/error transitions, mock-only `trader_details_screen.dart` data.

### 12 — Bonus, Scratch Card, Trade & Win

- **Screens:** Bonus, scratch-card list/reveal/leaderboard, Trade & Win catalogue/redeem.
- **API:** `GET user/bonus`, `GET user/bonus/bonusClaimList`, `POST user/bonus/bonusClaim`; `GET/POST v1/user/scratch-cards`, leaderboard, reveal and credit conversion; `GET v1/user/trade-win/products`, past wins, saved addresses; `POST v1/user/trade-win/claim`.
- **Code:** `lib/screens/bonus/presentation/pages/bonus_screen.dart:210-347`, `lib/screens/bonus/data/repositories/bonus_repository_impl.dart:13`, `lib/trade_win/view_models/trade_win_controller.dart:125`.
- **Local logic:** reward parsing, claim payload construction, scratch/reveal state, credit conversion, prize selection and redemption validation.

### 13 — Support tickets

- **Screens:** Ticket list, create ticket, ticket detail, reply, close, attachments.
- **API:** `GET user/tickets/departments`, `GET user/tickets`, `POST user/tickets`, `GET user/tickets/{ticketId}`, `POST user/tickets/{ticketId}/reply`, `POST user/tickets/{ticketId}/close`, multipart `POST user/tickets/attachment`.
- **Code:** `lib/screens/home/more/ticket/ticket_controller.dart:201-325`, `docs/SUPPORT_TICKET_MODULE.md:25-54`.
- **Local logic:** pagination, refresh-after-mutation, attachment handling, optimistic loading, close confirmation, success/error toasts.

### 14 — Demo contest

- **Screens:** Contest list, details, enroll, steps, leaderboard, stats, trading history, violations, winners.
- **API:** `GET user/demo-contest/contests`, `GET user/demo-contest/my-stats`, `GET user/demo-contest/{id}/enroll-preview`, steps/terms/leaderboard/trading-history/rule-violations, `POST user/demo-contest/{id}/enroll`, step click, claim.
- **Code:** `lib/services/demo_contest_service.dart`, `lib/screens/demo_contest/presentation/pages/demo_contest_my_stats_screen.dart:26-54`.
- **Local logic:** contest-id route arguments, loading/error/empty states, enrollment eligibility, leaderboard/stat parsing, step completion state.

## 3. Vantage/Pipze flavor matrix

| Flavor | API base | WebSocket | Chart | API/screens |
|---|---|---|---|---|
| Vantage family base | `FlavorConfig.instance.apiBaseUrl` | `FlavorConfig.instance.websocketUrl` | `FlavorConfig.instance.chartBaseUrl` | Shared implementation |
| Pipze | `https://my.pipze.com/api/` | `wss://my.pipze.com/trade-engine` | `https://my.pipze.com` | Same screens/controllers/endpoints; inherits Vantage |

No endpoint should be hardcoded to a brand domain in screens/controllers. Use `FlavorConfig` plus `ApiConstants.baseUrl`.

## 4. Local-only or non-REST integrations

- WebSocket channels are live transport, not Postman REST requests.
- `chart_datafeed_bridge.dart` uses direct chart REST and normalizes empty/error responses to no-data bars.
- `symbol_details_cache_service.dart` persists account-scoped symbol data in `SharedPreferences` for 24 hours.
- FCM notification setup/display/routing is local Firebase/platform logic; notification list itself is REST.
- App-status periodic polling is disabled; mock JSON remains local.
- `trader_details_screen.dart` contains mock/local trader data.
- `one_click_trading_queue_service.dart` is local queue/orchestration logic.
- `lib/screens/auth/view_models/riyadex_registration_controller.dart:34` calls external `https://register.riyadex.com/countries.php`; this is outside the shared API base and must be documented separately.

## 5. Collection files

- Existing endpoint-flow collection: `WhiteLabel_App_API.postman_collection.json` — 18 flow folders.
- Flavor environment: `WhiteLabel_App_API_Vantage_Pipze.postman_environment.json`.
- Screen-to-API mapping collection: `WhiteLabel_App_API_Screen_Module_Map.postman_collection.json`.

The screen-map collection intentionally uses the same `{{base_url}}` and `{{token}}` variables as the full endpoint collection, so it can be imported and run with the Pipze environment.
