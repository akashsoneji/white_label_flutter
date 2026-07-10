---
name: project-cregis-60s-txnhistory-poll
description: "Cregis mobile deposit wait = 120s, polled via Transaction-History ref-match, with confirm-cancel dialog and Vantage-brand transaction history screen"
type: project
createdAt: 1783677590010
updatedAt: 1783761000000
---

Cregis mobile deposit wait rewritten on 2026-07-10 across three iterations. Current state (2026-07-10, last iteration):

- **120-second** wait (was 100min → 60s → 120s)
- **Success detection** = reference_number match against the row in `GET /transactions` whose `status ∈ {approved, success, completed}` (NOT tap-time, NOT deposit/by-reference)
- **Confirm-cancel dialog** on back/swipe (Yes → TRADING / No → keep waiting)
- **Visible API debug strip** on the wait screen showing the latest poll request/response
- **Brand-aware transaction history screen**: Vantage UI brands → `brands/vantage/pages/transaction_history_screen.dart`, others → `pages/transaction_history_screen.dart`

**Why (the full arc):** user iteratively asked for: (1) cap wait at 60s + Transaction-History poll instead of cregis status endpoint, (2) bump to 120s, (3) use reference_number match so clock skew / pre-existing txns don't false-positive, (4) make the user confirm cancel via dialog and send them home on confirm, (5) make the Cregis redirect land on the Vantage transaction history screen (not the generic plain one), (6) surface the API call + response on the screen so QA can see whether the ref matched.

**How to apply — the new flow:**

1. **Tap-time capture** — still done in `DepositInstructionController.submitCregisDeposit()` and `createCregisDepositAddress()` checkout branch. `_cregisTapTime = DateTime.now()` BEFORE `Get.toNamed`, `tapTimeIso: _cregisTapTime.toIso8601String()` in route args. (Tap-time itself is no longer used for success detection, but kept as a field on the controller for parity / future use.)
2. **Polling** — each waiting screen (`cregis_success_screen.dart` and `cregis_address_screen.dart`) runs `Timer.periodic(Duration(seconds: 5), …)`. Constants: `static const int _pollIntervalSeconds = 5; static const int _maxWaitSeconds = 120;`. On each tick: elapsed >= 120s → timeout; else call `Get.find<TransactionHistoryController>().fetchLatestTransactionForRef(ref, statusFilter: true)` and if `res.row != null` → success.
3. **Three terminal states, all guarded by `bool _resolved` to prevent double-fire:**
   - **Success** → `_onSuccess()`: success toast, `markMT5AccountsAsStale()`, `Get.offAllNamed(TRANSACTION_HISTORY, arguments: {'from':'finance'})`.
   - **Timeout (120s, no match)** → `_onTimeout()`: warning toast "Transaction is processing", `offAllNamed` to history.
   - **Cancel (back arrow / device back / swipe)** → `_confirmCancel()`: AlertDialog "Cancel payment? Are you sure?" with [No, keep waiting] / [Yes, cancel]. If Yes → cancel toast + `Get.offAllNamed(TRADING)` (home). If No → stay.
4. **Visible debug strip** — three `_debug*` fields (`_debugLastCall`, `_debugLastResponse`, `_debugLastAt`) drive a small gray box at the bottom of the wait screen showing the last poll call + result. Format:
   - `GET /transactions @ <ISO ts> (attempt N, ref=<first 10 chars>…)`
   - `MATCH status=<s> amount=<a> created_at=<t>` or `NO MATCH (status=<raw>, totalRows=<n>)`
   - `at <ISO ts>`
   Useful during QA. Remove once the flow is stable.
5. **Brand-aware destination** — `lib/routes/app_pages.dart` binding for `_Paths.TRANSACTION_HISTORY` is now:
   ```dart
   page: () {
     if (FlavorConfig.usesVantageUi()) {
       return const vantage.VantageTransactionHistoryScreen();
     }
     return const TransactionHistoryScreen();
   },
   ```
   Vantage UI brands (vantage + 7 children) see the branded history; everything else sees the plain one.

**Affected files:**
- `lib/routes/app_pages.dart` — added `binding: BindingsBuilder(() { Get.put(TransactionHistoryController()); })` to CREGIS_ADDRESS and CREGIS_SUCCESS so `Get.find<TransactionHistoryController>()` works on the first poll. Switched TRANSACTION_HISTORY binding to brand-aware (Vantage screen for Vantage UI brands). Imports added: `transaction_history_controller.dart`, `flavor_config.dart`, `brands/vantage/pages/transaction_history_screen.dart as vantage`.
- `lib/screens/finance/view_models/transaction_history_controller.dart` — added `fetchLatestTransactionForRef(String ref, {bool statusFilter = true})` returning a record `({Data? row, int totalRows, String rawStatus})`. Scans the first page, returns the first row whose `referenceNumber.trim() == ref.trim()` AND whose `status` (lowercased + trimmed) is in `{approved, success, completed}` (when `statusFilter=true`). Returns null row + totalRows + diagnostic `rawStatus` on no-match / http_error / exception.
- `lib/screens/finance/view_models/deposit_instruction_controller.dart` — `_cregisTapTime` field + tapTimeIso in args, no poller machinery (still removed from prior iteration).
- `lib/screens/finance/presentation/pages/cregis_success_screen.dart` — `_maxWaitSeconds = 120` (was 60), `_pollAttempts` + 3 `_debug*` fields, polling body rewritten to ref-match + visible debug update, `_confirmCancel` (dialog) replaces `_cancel`, AppBar back + PopScope both call `_confirmCancel`, debug strip rendered in `build`.
- `lib/screens/finance/presentation/pages/cregis_address_screen.dart` — same shape as success screen, kept `_getNetworkLabel`/`_getSafetyCurrency`.
- `lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart` — fixed PopScope (was no-op): added `_handleBack()` that does `if (Navigator.of(context).canPop()) Get.back(); else Get.offAllNamed(Routes.TRADING);` and wired both PopScope onPopInvoked + AppBar `AppBackButton(onPressed:)` to it. The inline `(didPop) {}` no-op is gone.
- `lib/screens/finance/presentation/pages/transaction_history_screen.dart` — already had `_handleBack()` from the previous iteration; no changes this iteration.

**Plan file:** `.xelion/plans/cregis-60s-txnhistory-poll.plan.md` (last updated before the second iteration; the dialog + 120s + ref-match changes are in this memory, not the plan file).

Related: [[project-feature-folder-restructure]] (the three Cregis screens + controller moved into the feature-folder layout earlier).