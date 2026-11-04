# PAMM module — align APIs, UI and scenarios with the new PAMM docs

## Goal
Make the whole PAMM module (investor + master) call exactly the APIs the new docs describe, at the screen/trigger they describe, and handle every status scenario. Source of truth: `~/Downloads/pmam-user-guide.md` (flows) and `~/Downloads/pmam-client-endpoints.md` (sections 1.x explore, 2.x investor, 3.x master). These replace the older `client-portal-endpoints.md` / `user-guide.md` for PAMM.

## Approach
- **Rule:** an API is wired only if a user-guide flow uses it, at the screen/trigger the guide gives. A documented API that no flow uses is not called.
- **Correction to earlier work:** I removed `managers/datatable`, `investor/plans` and `dashboard-stats` because the old doc didn't list them. The new doc does list them (1.2, 2.1, 3.10). Per the new guide:
  - `dashboard-stats` (3.10) = master dashboard cards → **restore**.
  - `managers` / `managers/datatable` (1.1/1.2) = "older manager list screens; Explore now uses the plan table" (guide line 111). The app has no such screen → stay removed, and `GET managers` (which I added) also goes.
  - `investor/plans` (2.1) is not in any guide flow → stays removed.
  - `manager/status` (3.1) is documented and stays. It decides apply screen vs dashboard.
- **Explore becomes a plan table, like web.** `plans/datatable` loads on open. The manager filter (`managers/search`) and plan filter (`plans/search`) re-query the table with `manager_code` / `plan_id`. They no longer open the profile.
- The add-on work (2.4 purchase-options, 2.5 `purchase_option_id`, 2.6 cancel, add-on fields in 3.17) goes into this plan. `Additional-Plan-Purchase-Mobile-API (1).md` is the source for the add-on UI rules.
- Keep the existing patterns: static `PmamService` methods, GetX `PmamController` / `PmamManagerPlanDetailController`, `CustomToastService`, `TranslationUtils.tr` with keys added to all 9 language JSONs. UI rules: theme colours, Loading / Error-with-retry / Empty / Data states, compact cards.

## Steps

### A. Service layer — `lib/services/pmam_service.dart`
- [x] A1. Remove `getManagers()` (`GET managers`). Change `getPlansDataTable({managerCode, planId})` to send DataTables paging (`draw`, `start`, `length`) if 1.7 lists it, then check against 1.7 request params.
- [x] A2. Add `getManagerStatus()` cache-buster `_t` (web sends it). No other change.
- [x] A3. Restore `getManagerDashboardStats()` → `GET manager/dashboard-stats` (3.10).
- [x] A4. Add investor APIs: `getPurchaseOptions()` → `GET investor/purchase-options` (2.4); `cancelRequest(int enrollmentId)` → `POST investor/cancel/{id}` (2.6). `getPnlHistory({int? enrollmentId})` gets the optional enrollment filter (2.9; check the param name in 2.9).
- [x] A5. `searchPlans(query, {String? managerCode})` gets the optional manager code (guide table line 94).
- [x] A6. Add master APIs:
  - `getPlanStats(planId)` → `plans/{id}/stats` (3.12)
  - `getPlanFundEntries(planId, …)` → `plans/{id}/fund-entries` (3.16)
  - `getWithdrawableBalance(planId)` → `plans/{id}/withdrawable-balance` (3.22)
  - `validateWithdrawal(planId, amount)` → `plans/{id}/validate-withdrawal` (3.23)
  - `exportCommissions({dateFrom, dateTo})` → `commissions/export` (3.25, CSV)
- [x] A7. `getManagerCommissions` gets the filters from 3.24: plan id, dates, search, sort, page. `rejectInvestorRequest(id, {String? reason})` sends `reason` (3.19).

### B. Investor — Explore (`lib/screens/home/more/pmam/pmam_explore_managers_screen.dart`, `pmam_controller.dart`)
- [x] B1. Controller: replace `loadManagers()` / `managersList: List<PmamManager>` with `loadExplorePlans({managerCode, planId})` → `plans/datatable`. Use a typed `PmamExplorePlan` model in `lib/models/pmam_model.dart`, built from the real 1.7 response: `id`, `plan_name`, `manager_code`, `manager_name`, `member_since`, `minimum_investment`, `commission_percentage`, `total_aum`, `active_investors`, `hide_investors`, `profit_percentage`, `max_drawdown`, `manager_balance_ok`, `is_enrolled`. Read rows from `data` directly, because the body has no `success` key.
- [x] B2. Screen: one card per plan. Show the plan name and manager, AUM, gain %, drawdown, commission, min investment and investors (hide the count when `hide_investors`). Show an "Invested" badge instead of the Invest button when `is_enrolled`. Stats header and chips (All / Enrolled / Low commission / Has AUM) are computed from plan rows.
- [x] B3. Filters: manager search box → `managers/search` → on pick, set `manager_code` and reload `plans/datatable`. Plan search box → `plans/search` (pass the chosen manager code if any). Its `code` is the plan id (guide line 46), so on pick set `plan_id` and reload. Add clear-filter chips. Fix `PmamSearchOption.plan` to read `code` as `planId`. Remove the "tap suggestion → open profile" flow I added (`_openSearchOption`, `loadPlansDataTable`).
- [x] B4. Card tap → manager profile with `{manager_code, plan_id}`. The profile preselects that plan (`_initialPlanId` already exists in `pmam_fund_manager_view_screen.dart`).
- [x] B5. Update the other `loadManagers` callers in `pmam_investor_portal_screen.dart` (lines ~106, ~114, ~1127) to the new loader. Delete `_buildFundManagersTab` if it stays unused.

### C. Investor — Manager profile + Invest drawer (`pmam_fund_manager_view_screen.dart`, invest drawer widget)
- [x] C1. Profile: `managers/{code}` on open. On plan change: `managers/{code}/trades` and `open-positions` with `plan_id`. Handle "Manager not found" and "Plan not found" with an error state and retry.
- [x] C2. Profile: `enrollments` + `eligible-accounts` always on open. Today they only load when `myInvestments` is empty.
- [x] C3. Invest drawer, on every open: `eligible-accounts` + `purchase-options`.
  - Empty accounts → the app's own "no eligible live account" message. Never the manager's "Create Plan" text.
  - Show the available balance per account.
  - Add-on dropdown (None + options) only when `enabled`. Show the wallet balance. When fee > wallet, show "add $shortage to wallet", disable Invest and offer a Deposit button.
- [x] C4. Join: `request-join` with `pmam_plan_id`, `investor_account_id`, `invested_amount`, plus `purchase_option_id` only if an add-on was picked. Client checks: amount ≥ plan minimum and ≥ 1, amount ≤ available balance.
  - On success: toast with the server message. If `data.purchase` is a map (it is `""` when none), show the add-on name, fee and wallet after.
  - On 422 `insufficient_wallet`: show the shortage UI. On any other 422: show the server message and reload the options. Other join errors: show the server message.
  - Then refresh enrollments.

### D. Investor — My Investments (`pmam_investor_portal_screen.dart`, `pmam_controller.dart` `loadInvestorPortal`)
- [ ] D1. On open: `enrollments`, `my-open-allocations`, `pnl-history`, `my-fund-entries`, `eligible-accounts`. Already wired; check each list shows in the UI. `pnlHistory` has no consumer yet, so add a P&L history section or tab.
- [ ] D2. Status chips for `pending`, `active`, `inactive`, `rejected`, `cancelled`, with actions by status:
  - `pending` → **Cancel** (new): confirm dialog → `investor/cancel/{id}` → toast "Request cancelled." plus "add-on $X refunded to wallet" when `addon_refunded > 0` → reload.
  - `active` → **Add funds** (`investor/deposit`, amount ≥ 1, show the server success text, reload enrollments) and **Unsubscribe** (`investor/unsubscribe/{id}`). Disable the button while the call is in flight, so two quick presses can't fire twice. Show the server message for the weekend / minimum-holding / "already being processed" errors.
  - `inactive` / `rejected` / `cancelled` → no actions, read-only.
- [ ] D3. Per-investment drill-in: `managers/{code}/trades` with `plan_id` + `investor_id` = enrollment id (`getManagerTrades` already supports it). Filter `pnl-history` by the enrollment id.

### E. Master — status gate and apply (`pmam_main_screen.dart`, `pmam_become_manager_screen.dart`, `pmam_controller.dart`)
- [ ] E1. `loadManagerStatus()` also parses `master_enrollments_enabled`. Handle "No manager application found" (no `status` key) as "never applied".
- [ ] E2. Show the screen by state:
  - Never applied + enrollments open → Become Master (terms tick + Apply).
  - Never applied + closed → info "applications are closed", no Apply button.
  - `pending` → "application under review" card. Re-check status on pull-to-refresh and on resume.
  - `rejected` → "application rejected" card; allow re-apply only if the server allows it (check the 3.2 errors).
  - `approved` → manager mode (dashboard, plans, investors, commissions tabs).
- [ ] E3. Apply (3.2): send `terms_accepted: true`. On error show the server message: IB partner, already applied, closed, profile/KYC not done. On success set the status to `pending`.

### F. Master — dashboard, plans, requests, investors, commissions, withdrawal
- [ ] F1. Dashboard (`pmam_manager_dashboard_screen.dart`): cards from `dashboard-stats` (3.10) and charts from `dashboard-overview` (3.11) with the range picker (today/7d/30d/90d/1y/all, plus custom dates if 3.11 supports `date_from`/`date_to`). Show the pending-request count if 3.10 returns it.
- [ ] F2. Create plan (`pmam_create_plan_screen.dart`): account dropdown from `manager/eligible-accounts` (3.3); empty → "no free live account". After `POST manager/plans` (3.4), the toast depends on the returned status: `approved` → live, `pending_admin` → "waiting for admin approval".
- [ ] F3. My plans (`pmam_manager_portal_screen.dart`): `manager/plans` (3.5). Status chips: approved, pending_admin, paused, inactive, rejected. Buttons:
  - Edit (3.6): commission and minimum fields are disabled while `active_investors > 0`.
  - Pause/Resume (3.7/3.8).
  - Close (3.9): only when no investor money; else show the server message.
  - Reload after each action.
- [ ] F4. Plan page (`pmam_manager_plan_detail_screen.dart` + `pmam_manager_plan_detail_controller.dart`):
  - Header stats `plans/{id}/stats` (3.12, new).
  - Detail (3.13).
  - Investors tab: paged, search, sort (3.14).
  - Trades tab (3.15) with a per-person `user_id` filter.
  - **Money history tab** `plans/{id}/fund-entries` (3.16, new).
  - **Requests tab** (3.17): show `addon_name` / `addon_fee` (`""` means none). Approve → 3.18; Reject → reason dialog → 3.19 with `reason`. Reload the list after either.
- [ ] F5. Investors (`pmam_manager_portal_screen.dart` investors tab): `manager/investors` (3.20) → tap → `investors/{id}/detail` (3.21) in `pmam_manager_investor_detail_screen.dart`: summary, open trades, commission history, money history.
- [ ] F6. Commissions (`pmam_manager_commissions_screen.dart`): 3.24 with plan filter (from `managerPlans`), date range, search, sort and pagination. Export button → 3.25 CSV, saved/shared using the app's existing file-download pattern (find and reuse it; no new package).
- [ ] F7. Master withdrawal (new flow, placement to confirm): plan → `withdrawable-balance` (3.22) shows `withdrawable` and whether it's possible → amount field → `validate-withdrawal` (3.23) → on OK, continue to the app's existing withdrawal flow.

### G. Shared rules
- [ ] G1. Treat `""` and `null` the same everywhere: `purchase`, `addon_*`, close times, and every empty value 3.x mentions.
- [ ] G2. Every new string goes into all 9 translation JSONs with key parity.
- [ ] G3. 404 "No query results for model…" → a friendly "not found" message, not the raw text.

### H. Verify
- [ ] H1. Run `/Users/admin/development/flutter/bin/flutter analyze` on the whole project: 0 errors. Run `flutter test`.
- [ ] H2. On device RMX3946 (or an emulator), using the flavor that points at `app.tenaxcode.com` (confirm which):
  - **Investor** (`harrysubib@gmail.com`): Explore table plus both filters → profile → invest drawer (no add-on, with add-on, insufficient wallet) → My Investments pending → Cancel (refund toast) → join again.
  - **Master** (`harry@tenaxcode.com`, approved): see the request with the add-on → reject with a reason → investor sees `rejected`. Join again → approve → investor sees `active` → Add funds → Unsubscribe (weekday). Create plan, Edit, Pause/Resume, plan page tabs, investors detail, commissions + export, withdrawable check.
  - **IB / pending** (`harryib@gmail.com`): PAMM opens on the pending / IB-refusal state, and Apply shows the server reason.
- [ ] H3. Write the results to `.tenaxcode/notes/pamm-test-cases.md`.

## Files
- `lib/services/pmam_service.dart`: add/restore/remove endpoints (A).
- `lib/models/pmam_model.dart`: `PmamExplorePlan`, plus typed purchase-option / enrollment models where they are touched.
- `lib/controllers/pmam/pmam_controller.dart`: explore table, filters, status gate, invest/cancel/deposit/unsubscribe, commissions filters, withdrawal.
- `lib/controllers/pmam/pmam_manager_plan_detail_controller.dart`: stats, fund-entries, requests with add-on, reject reason.
- `lib/screens/home/more/pmam/pmam_explore_managers_screen.dart`: plan-table UI and filters.
- `lib/screens/home/more/pmam/pmam_investor_portal_screen.dart`: My Investments actions by status, P&L history.
- `lib/screens/home/more/pmam/pmam_fund_manager_view_screen.dart`: profile loads, invest drawer, add-ons.
- `lib/screens/home/more/pmam/pmam_main_screen.dart`, `pmam_become_manager_screen.dart`: status gate and apply.
- `lib/screens/home/more/pmam/pmam_manager_dashboard_screen.dart`: stats cards + overview.
- `lib/screens/home/more/pmam/pmam_create_plan_screen.dart`: accounts and the status toast.
- `lib/screens/home/more/pmam/pmam_manager_portal_screen.dart`: plans actions, investors.
- `lib/screens/home/more/pmam/pmam_manager_plan_detail_screen.dart`: stats header, money history tab, requests tab.
- `lib/screens/home/more/pmam/pmam_manager_investor_detail_screen.dart`: 3.21 sections.
- `lib/screens/home/more/pmam/pmam_manager_commissions_screen.dart`: filters and export.
- `assets/translations/*.json`: new keys.

## Risks / Open questions
- **Explore UI change:** manager cards become plan cards (web parity). This is a visible redesign of the Explore tab.
- **Master withdrawal placement:** no master-withdrawal screen exists today. Is it a button on the plan page that hands over to the existing wallet withdrawal? To confirm.
- **CSV export:** needs a file save/share path. Reuse an existing download helper if the app has one; otherwise ask before adding a package.
- **Rejected master re-apply:** whether the server allows it isn't confirmed yet (read the 3.2 error list during implementation).
- **Flavor for app.tenaxcode.com:** assumed `tenax`. Confirm before the device run.
- **Scale:** ~15 files. I suggest building in order A → B/C/D (investor) → E/F (master) → H, and checking on the device after the investor part.
