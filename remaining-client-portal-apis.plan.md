# Baaki client-portal APIs — app me lagane ka plan

## Goal
Docs (`user-guide.md`, `client-portal-endpoints.md`) ki 58 zaroori APIs me se jo **44 baaki** hain, unhe app me lagana — pehle Phase 1 ki 3, phir Phase 2 ki 26 (module-wise), phir broker-feature wali 15 (sirf module on ho tab dikhe). Har API ka data real response se model banakar aayega, koi static data nahi.

## Steps
- [ ] Step 0 — Trader Transfer tile ko `enabled-modules.trader_transfer` se gate karo (Finance screen)
- [ ] Step 1 — Notifications list ko `GET notifications/all` par shift karo (fake pagination hatao)
- [ ] Step 2 — Dynamic gateway deposit: `POST deposit/dynamic/{gatewaySlug}`
- [ ] Step 3 — Google signup complete-registration screen: `POST auth/google/complete-registration`
- [ ] Step 4 — Account nickname: `POST mt5accounts/setnickname` (Accounts screen se rename)
- [ ] Step 5 — Session check on app start/resume: `GET session/check`
- [ ] Step 6 — Price alert edit/delete server par: `PUT` / `DELETE price-alerts/{id}`
- [ ] Step 7 — Copy trading leaderboard search: `GET copytrading/plans/search`
- [ ] Step 8 — PAMM: managers list, managers/plans search, eligible-accounts, commissions (5 APIs)
- [ ] Step 9 — IB: activities, tree-structure, get-ib-details, template-rates, structure-options (5 APIs)
- [ ] Step 10 — Promotions: bonus cancel `bonusClaimCancel`, scratch card `claim`
- [ ] Step 11 — Platforms screen: `GET platform-links`
- [ ] Step 12 — Login activity screen: `GET settings/activitylog` (paginated)
- [ ] Step 13 — Bank accounts: delete `withdrawal/delete/{id}` + `image-proxy/{id}` se proof image
- [ ] Step 14 — Mobile verification OTP: `mobile-verification/send` + `verify` (KYC + scratch card)
- [ ] Step 15 — KYC documents image: `kyc-image-proxy/{documentId}`
- [ ] Step 16 — Register referral tracking: `ibm/r/{code}` + `ib/track-sponsor-visit`
- [ ] Step 17 — Broker-feature APIs (15) — module flag on ho tabhi dikhao: UniPayment, IFSC, Sumsub/Shufti KYC, IB Demo Contest (9)
- [ ] Step 18 — Har step ke baad: `flutter analyze` (poora project) + phone par tenax/pippro me test + translations 9 languages me
- [ ] Step 19 — Cleanup A: `api_const.dart` ke 29 unused constants hatao (koi call nahi karta)
- [ ] Step 20 — Cleanup B: docs me na milne wali legacy APIs ko doc wale naye endpoint par shift karo (backend confirm ke baad), purani hatao
- [ ] Step 21 — Cleanup C: 158 dead Dart files (main.dart se kabhi import nahi hoti, ~15.5k lines) batch-wise hatao
- [ ] Step 22 — Cleanup D: repo root ki scratch/temp files (~40) hatao

## Kaam karne ka tareeka (har API ke liye same pattern)
1. Endpoint `lib/constants/api_const.dart` me add (`${ajax}...` pattern).
2. Response ka model real API response se banao (`fromJson`), docs ka sample sirf reference.
3. Call existing service/controller me (GetX controller + `ApiClient`), naya service tabhi jab module ka koi service na ho.
4. UI me 4 state: Loading (shimmer), Error (retry), Empty, Data. Theme colours, `const` widgets.
5. Naye text ki keys saari language JSON files me (key parity).
6. Feature module se jude ho to `EnabledModulesService` / `crm-settings` flag se tile/button chhupao.
7. Verify: `flutter analyze` 0 errors, phone par flow chalao, API log me request/response check.

## Detail — kya, kahan, kaise

### Step 0 — Trader Transfer tile gating
- Abhi `finance_screen.dart:69-76` tile hamesha dikhta hai.
- `EnabledModulesService` me `isTraderTransferEnabled` getter add karo (`trader_transfer` key), tile ko `Obx` me usse wrap karo.

### Step 1 — `GET /api/user/notifications/all`
- Web: Notifications list page `loadNotifications`, params NONE.
- App abhi `notifications?page=N` use karta hai jo `page` ignore karta hai (aaj duplicate-id guard lagaya).
- Kaam: list screen ke liye `notifications/all` use karo, pagination hatao; header ka bell/unread count `notifications` se hi rahe.
- File: `lib/screens/notifications/...` (provider + controller).

### Step 2 — `POST /api/user/deposit/dynamic/{gatewaySlug}`
- Params: `gateway_method_id`, `mt5_account_id`, `amount`, `user_input_net_amount`, `user_input_currency`, `card_number`, `card_expiry` (gateway ke hisaab se fields).
- App me gateway data `deposit_instruction_controller.dart` me aata hai — wahi se `gatewaySlug` lekar is endpoint par submit.
- Response me redirect/payment URL aaye to WebView me kholo.
- **Backend sawaal:** mobile ke liye success/cancel return URL / deep link kya hai?

### Step 3 — `POST /api/user/auth/google/complete-registration`
- Params: `mobile`, `country_code`, `password`, `otp_code`, `otp_verification_type`.
- Google login ke baad agar user ka registration adhoora hai to ye screen (mobile + password + OTP) dikhao, phir normal login flow.
- Files: `google_login_otp_screen.dart`, `auth_service.dart` (`_withRegisterMeta` pattern follow).

### Step 4 — `POST /api/user/mt5accounts/setnickname`
- Params: `meta_account_number`, `mt5_nick_name`.
- Accounts list / account card par "Rename" action → dialog → API → list refresh.

### Step 5 — `GET /api/user/session/check`
- Web app root `mounted` par call karta hai. App: splash ke baad aur app resume par; session invalid ho to logout → login screen.

### Step 6 — `PUT` / `DELETE /api/user/price-alerts/{id}`
- PUT params: `symbol`, `target_price`, `condition`, `fcm_token`, `device_type`, `message`, `is_active`.
- Abhi `price_alert_monitor_service.dart:466` sirf POST karta hai; alert ka server `id` save karo, edit/delete/pause par PUT/DELETE.
- **Backend sawaal:** server-side trigger par FCM push aayega? Tab local monitoring hata sakte hain.

### Step 7 — `GET /api/copytrading/plans/search`
- Leaderboard (`explore_masters_screen.dart`) me search box → is API se suggestions/filter.

### Step 8 — PAMM (5)
- `pmam/managers` — Managers list screen.
- `pmam/managers/search`, `pmam/plans/search` — Explore + My Investments me search/filter dropdown.
- `pmam/manager/eligible-accounts` — Manager dashboard / plan create me trading account picker.
- `pmam/manager/commissions` — naya "Commissions" screen (manager side).
- Files: `lib/services/pmam_service.dart`, `lib/controllers/pmam/pmam_controller.dart`, `lib/screens/home/more/pmam/`.

### Step 9 — IB (5)
- `ib/activities` — IB Dashboard par "Recent activities" list.
- `ib/tree-structure` — My Network tree (search ke saath).
- `ib/get-ib-details/{userSlug}` — network me kisi IB par tap → detail sheet.
- `ib/get-template-rates/{templateId}` — Sub-IB structure create me template select par rates.
- `ib/get-structure-options/{id}` — Sub-IB approval me reason/options modal.
- Files: `lib/screens/ib/data/datasources/ib_remote_data_source.dart`, `ib_controller.dart`, `ib_dashboard_new_screen.dart`.

### Step 10 — Promotions (2)
- `bonus/bonusClaimCancel` — params `id`, `reason`; Bonus screen par "Cancel bonus" + reason dialog.
- `v1/user/scratch-cards/claim` — scratch card reveal ke baad "Claim" button.
- Files: `lib/screens/bonus/...` (repository + scratch_card_screen).

### Step 11 — `GET /api/user/platform-links`
- Naya "Platforms" screen: platform list + download links (store/URL launch).

### Step 12 — `GET /api/user/settings/activitylog`
- Naya "Login activity" screen (App Settings me Active Sessions ke paas), load-more pagination.

### Step 13 — Bank accounts (2)
- `withdrawal/delete/{id}` — bank/withdrawal account delete (confirm dialog).
- `image-proxy/{id}` — withdrawal detail me proof image (auth header ke saath image load).
- Files: `lib/screens/kyc/view_models/kyc_bank_controller.dart`, `bank_list_screen.dart`.

### Step 14 — Mobile verification (2)
- `mobile-verification/send` (no params) → OTP; `mobile-verification/verify` (`otp`).
- KYC flow aur scratch card promotion dono jagah reusable OTP sheet.

### Step 15 — `GET /api/user/kyc-image-proxy/{documentId}`
- KYC documents list me uploaded document ka preview (auth header ke saath).

### Step 16 — Register referral tracking (2)
- `ibm/r/{code}` — IBM referral link se app khule to visit track.
- `ib/track-sponsor-visit` — param `sponsorcode`; invite/referral link se register screen khule tab.
- Deep link se code aana chahiye — **backend/product sawaal:** app ka referral deep link format kya hai?

### Step 17 — Broker-feature APIs (15)
- **UniPayment:** `deposit/unipayment` (`gateway_method_id`, `mt5_account_id`, `amount`) → WebView.
- **IFSC:** `utility/ifsc-code` (`ifscCode`) — bank add form me IFSC verify (India brokers).
- **KYC providers:** `kyc/sumsub/token` + `refresh`, `kyc/shufti/start` + `status`. Sumsub ko native SDK chahiye (nayi dependency — approval lena hoga); Shufti URL WebView me.
- **IB Demo Contest (9):** my-contests, instruments, store, update, cancel, add-prize-fund, enrollments, approve, reject — IB ke andar naya "My Contests" module (list → create/edit → enrollments approve/reject).
- Sab ko module flag / crm-settings se gate karo.

## Abhi nahi
- **Optional, Phase 3 (13):** banners/track, prop-coupons, economic-calendar, tradehistory/export, trading-central, robot trading (4), email-preferences (2), chunked KYC upload (2) — demand aaye tab.
- **Mat lagao (5):** password/reset-token, user/modules, GET /api/user, GET /api/user/json, pmam/plans/datatable.

## Cleanup — extra APIs aur dead files

Sab kuch hatane se pehle har batch par `find_references` + poora `flutter analyze` + `flutter test` + tenax aur pippro dono par build/run. Ek module ek commit, taaki galti ho to revert aasaan ho.

### A. Unused API constants (29) — seedha hatao
`lib/constants/api_const.dart` me hain, lekin app me koi `ApiConstants.X` use nahi karta:
- Trading (purane naam): `cancelPendingOrder`, `modifyPendingOrder`, `closePositions`, `getInstruments`, `getTransactions`
- Deposit / IB: `cregisDepositStatus`, `ibTrackVisit` (Step 16 me naye endpoint se dobara lagega)
- Demo contest (user side, 10): `demoContestEnrollPreview`, `demoContestSteps`, `demoContestStepClick`, `demoContestTerms`, `demoContestEnroll`, `demoContestMyEnrollments`, `demoContestLeaderboard`, `demoContestTradingHistory`, `demoContestRuleViolations`, `demoContestClaim`
- Copy trading (10): `copyTradingMasterDashboardOverview`, `copyTradingMasterPlanOpenPositions`, `copyTradingMasterPlanPause`, `copyTradingMasterPlanResume`, `copyTradingMasterPlanUpdate`, `copyTradingCopierSubscriptions`, `copyTradingMasterCopiers`, `copyTradingCopierSubscriptionPnlHistory`, `copyTradingMasters`, `copyTradingCopierMasterProfile`
- Profile: `profileUpdate`, `getProfile`
- Note: demo contest / copy trading ke kuch screens shayad endpoint ko string se seedha call karte hain — hatane se pehle `search_for_files` se string bhi check karo.

### B. App jo APIs call karta hai lekin docs me nahi hain (49 paths)

**Rakho — alag server / alag doc (12):**
- Tenax chart engine: `chart/orders`, `chart/orders/{id}/modify`, `chart/orders/{id}/close`, `chart/symbols`, `market/history` (trade-engine server, client-portal doc me nahi aate).
- IB Manager Portal (`ibm/IB_Manager_Portal_New_APIs.md`): `ibm/client/partner-request`, `ibm/portal/clients/{id}/accounts`, `.../accounts/{id}/trades`, `.../move`, `.../trades`, `ibm/portal/links/{id}/stats`, `ibm/portal/marketing/{id}/download`, `ibm/portal/wallet/payout/{id}`.

**Purane naam → doc ka naya endpoint (shift karo, phir purana hatao):**
- `user/password/email` + `user/send-otp` + `user/verify-otp` + `user/reset-password` → `user/password/reset`, `user/password/verify-otp` (forgot-password flow)
- `user/withdrawal/withdrawal-method` → `user/withdrawal/withdrawal-method/{methodId}`
- `user/ib/transfer` → `user/ib/transfer/create` + `user/ib/transfer/store`
- `user/ib/update-status` → `user/ib/update-status/{id}`
- `user/ib/sub-ib-structure` → `user/ib/sub-ib-structure/{subIBId}`
- `user/ib/approval/requests`, `user/ib/sub-ib-stats`, `user/ib/sub-ib-sub-ibs` → doc me `user/ib/structure` / `progressive-stats` family — backend se mapping confirm
- `copytrading/masters` → `copytrading/plans` (Explore pehle se plans use karta hai — constant unused hai, hatao)
- `user/copytrading/copier/masters/{id}/trade-history`, `.../subscriptions/{id}/add-capital`, `.../subscriptions/{id}/pnl-history` → copy trading doc se naya naam confirm
- `user/pmam/manager/status`, `user/pmam/manager/dashboard-stats`, `user/pmam/investor/plans` → doc ke `pmam/manager/plans` / `pmam/managers` family — confirm
- `user/mt5accounts/mt5AccountSync` → doc me nahi; `mt5accounts/get` se kaam chalta ho to hatao
- `user/deposit-proof-proxy` → doc ka `image-proxy/{id}` (Step 13) — confirm
- `user/instruments/{id}` → doc me nahi; trading screens `trade/marketwatch` / chart symbols use karte hain — confirm
- `user/settings/getCountryDropdown`, `getStateDropdown`, `getCityDropdown`, `user/utility/currency-list` → doc me dropdown API ka naam confirm
- `v1/user/trade-win/past-wins`, `v1/user/scratch-cards/convert-credit-to-balance` → doc me nahi — confirm feature abhi bhi chalu hai

**Mobile-only — rakho, backend se confirm (docs web ke hain):**
- `user/register-fcm-token` (push), `user/mobile-app-details` (app version/force update), `user/settings/delete-account` (Play/App Store ki requirement)

### C. Dead Dart files (158 files, ~15,500 lines)
`lib/main.dart` (aur `lib/generated/`) se import chain follow karne par ye files kabhi load nahi hoti. Kisi test me bhi use nahi hoti. List: `/tmp/dead_files.txt` (implementation ke time dobara generate karna).
- `lib/screens/trading` — 36
- `lib/screens/ib` — 26
- `lib/screens/copy_trading` — 11 (isme `tabs/settings_tab.dart` hai jo git me modified hai — pehle confirm ki ye kahin route se khulti hai ya nahi)
- `lib/screens/home` — 10, `lib/screens/kyc` — 10, `lib/screens/auth` — 9
- `lib/screens/finance` — 5, `lib/screens/bonus` — 4, `lib/screens/settings` — 4 (xelthio brand screens), `lib/models/demo_contest` — 4
- `lib/screens/notifications` — 2 (`notification_api_service.dart`, `widgets/notification_tile.dart`)
- Chhote: `lib/screens/example_rtl_components_screen.dart`, `example_updated_screen.dart`, `lib/services/audio_service_v2.dart`, `toast_service.dart`, `lib/utils/debug_utils.dart`, `encryption_helper.dart`, `exit_confirmation_utils.dart`, `lib/widgets/` (advanced_chart_inapp_webview, app_confirm_dialog, back_button_handler, chart_trading_notification, currency_text_field, global_drawer, login_loading_overlay, responsive_layout, social_button, toggle_pill, vantage/*), `lib/brands/brand_scope.dart`, `brand_widgets.dart`, `lib/brands/demo/*`, `lib/core/feature_flags/*`, `lib/core/routing/*` …
- Asset: `lib/img1.jpg` (lib folder me image — use nahi hoti to hatao)
- Dhyan: koi brand file `brand_switcher` / generated config se dynamic load hoti ho to wo yahan galat "dead" aa sakti hai — har brand (tenax, pippro, pipze, baazex, moneygenius…) ka build chala kar confirm.
- Hatane ke baad jo assets/translation keys sirf in files me use hoti thi, unhe bhi alag step me check karo (abhi nahi).

### D. Repo root ki scratch / temp files (~40)
Product ka hissa nahi, ek-baar ke scripts/output:
- Python scripts: `_brace_check.py`, `_find_pct.py`, `_find_pct2.py`, `_find_percent.py`, `_plan.py`, `_rewrite_full.py`, `_rewrite_state.py`, `_scan_hardcoded_strings.py`, `_scan_vantage_strings.py`, `_strip_percent.py`, `_structure.py`, `_unbalanced.py`, `_unbalanced2.py`, `fix_parser.py`, `fix_parser_acc.py`, `fix_routes.py`, `update_parsers.py`
- Dart scratch: `scratch.dart`, `scratch2.dart`, `scratch3.dart`, `test_msgpack.dart`, `test_parse.dart`, `test_parse2.dart`, `scratch/` folder
- Output / dumps: `_grep_kyc.txt`, `_lint_kyc_passport.txt`, `analysis_output.txt`, `analysis_screen.txt`, `err.txt`, `err_flutter.txt`, `temp_js_bundle.js`, `window_dump.xml`, `emulator_screen.png`, `_order_screenshots/`
- Build artifacts: `app-baazex-release-1.0.1.aab`, `app-baazex-release-1.0.2+3.aab` (repo me nahi hone chahiye — kahin aur backup rakho)
- **Tumse confirm:** `scripts/`, `tool/`, `docs/`, Postman collections aur `*.md` docs nahi hataunga.

## Backend team se confirm karna
1. Deposit dynamic/UniPayment ke liye mobile return URL / deep link.
2. Sumsub native SDK vs WebView flow.
3. Price alert server trigger par FCM push.
4. MT5 credentials notification kab banti hai, aur push payload me notification `id` aayega?
5. Trader Transfer module kaise on hota hai (admin setting?).
6. Referral deep link format (`ibm/r/{code}`, sponsor code).
7. Section B ke "purane naam" wale APIs: kaunse abhi bhi chalu hain, kaunse doc ke naye endpoint se replace karne hain.
8. Mobile-only APIs (`register-fcm-token`, `mobile-app-details`, `settings/delete-account`) rahenge na?

## Testing
- Dev (`dev.tenaxcodecrm.com`, tenax) par user `ippo+2@yopmail.com`; production brands (pippro/pipze) par sirf read-only check.
- Har step: phone par flow, API log me request/response, `flutter analyze` poora project.
