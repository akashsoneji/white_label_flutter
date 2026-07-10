# Plan: Cregis 60-sec deposit wait via Transaction-History polling

## Goal (user request, 2026-07-10)

Change the Cregis "waiting" flow so that:

1. **Timeout: 60 seconds** (not 100 min). The current 100-min duration cap must become **60 seconds** on the waiting screen.
2. **Detect success via the Transaction-History API, not the cregis status endpoint.**
   - When the user taps **Generate Address**, capture the **tap time** (`DateTime.now()`).
   - Every **5 seconds**, call the Transaction-History API (`ApiConstants.getTransactions`).
   - Look at the **latest (newest-first) transaction**. If its `created_at` is **after the saved tap-time**, treat it as **success** → show a success toast + redirect to the Transaction-History screen (no more waiting).
   - **Match rule (confirmed): any transaction whose `created_at` > tap-time = success.** (No ref/status matching required.)
3. **Cancel handling (within 60s):** if the user **taps back OR swipes back**, treat as **cancel** → show error toast **"Transaction cancelled"** and leave/return appropriately (do NOT auto-redirect to history).
4. **Timeout with nothing happening (60s elapsed, no newer txn, no cancel):** show a toast like **"Transaction is processing"** and **redirect to the Transaction-History screen to wait there.**
5. **Fix the back-navigation bug on Transaction-History screen:** after the app auto-moves the user to Transaction History, pressing **back button** or **swipe-back** currently shows a **blank screen** instead of returning to where they came from (dashboard). Back + swipe must both return to the correct origin.

---

## Current state (verified by reading the code)

### Waiting screens (two of them)
- `lib/screens/finance/presentation/pages/cregis_success_screen.dart` — hosted-checkout flow (the screenshot: "Payment Request Submitted", "Verifying payment details… (18/20)", "Open Payment Link", "Go to Transaction History").
- `lib/screens/finance/presentation/pages/cregis_address_screen.dart` — direct-address / QR flow ("Direct Crypto Transfer").
- Both currently poll `ApiConstants.cregisDepositStatus` (`${ajax}deposit/by-reference?ref=…`) every 4s and use a **duration-based 100-min cap** (`_cregisPollMaxDurationMinutes = 100`, added in the previous session).

### Controller
- `lib/screens/finance/view_models/deposit_instruction_controller.dart`
  - `createCregisDepositAddress()` is the **Generate Address** handler. On success:
    - If `checkout_url` non-empty → `_startPolling()` + `Get.toNamed(AppPages.CREGIS_SUCCESS, arguments: {checkoutUrl, referenceNumber, amount})`.
    - Else if `cregis_address` non-empty → shows a success toast (the address screen is pushed elsewhere / by the deposit screen).
  - `_startPolling()` also polls `deposit/by-reference` (100-min cap) — this is a **third** poller, largely redundant with the screen pollers.
  - **This is where we capture the tap-time** (`DateTime.now()` at the start of `createCregisDepositAddress`, or right before navigating).

### Transaction-History API + model
- Endpoint: `ApiConstants.getTransactions` = `${ajax}transactions`.
- Controller: `lib/screens/finance/view_models/transaction_history_controller.dart`.
  - `fetchUserTransactions({int page = 1})` populates `userTransactions` (`RxList<Data>`).
  - `Data.createdAt` is parsed from `created_at_iso` (preferred) or `created_at`. **This is the field to compare against tap-time.** Parse with `DateTime.tryParse(createdAt)?.toLocal()`.
  - The screen sorts newest-first itself (`_computeFilteredTransactions`), but the **controller's raw `userTransactions` order is whatever the API returns** — so in the poller we must compute the max `created_at` ourselves rather than trusting index 0.

### Transaction-History screen back button (the blank-screen bug)
- `lib/screens/finance/presentation/pages/transaction_history_screen.dart`:
  - `PopScope(canPop: false, onPopInvoked: (didPop){ /* does nothing */ })` → **device/system back + swipe-back are completely swallowed → blank/stuck screen. This is the bug.**
  - AppBar back button logic:
    ```dart
    final fromTab = Get.arguments?['from'] ?? 'dashboard';
    if (fromTab == 'finance') {
      NavigationHelper.safeBack(context: context);   // Navigator.pop()
    } else {
      Get.offAllNamed(Routes.TRADING);
    }
    ```
  - When the Cregis flow redirects here it uses `Get.offAllNamed(AppPages.TRANSACTION_HISTORY, arguments: {'from': 'finance'})`. Because it's `offAllNamed`, the **back stack is wiped**, so `Navigator.pop()` (the `'finance'` branch) has nothing to pop → blank screen.

---

## Design decisions

### Where to capture tap-time
- Capture `_cregisTapTime = DateTime.now()` inside `createCregisDepositAddress()` **before** the API call, store it on the controller, and **pass it via route arguments** to whichever waiting screen is pushed (`tapTimeIso: _cregisTapTime.toIso8601String()`). This keeps each screen self-contained and testable.

### New polling logic (both waiting screens)
Replace the `deposit/by-reference` poller with a **Transaction-History poller**:
- Interval: **5 seconds** (`_pollIntervalSeconds = 5`).
- Hard cap: **60 seconds** (`_maxWaitSeconds = 60`), duration-based via saved `_pollingStartedAt`.
- Each tick:
  1. Call the transactions API (reuse `TransactionHistoryController.fetchUserTransactions()` or a lightweight direct call — see "Open question" below).
  2. Compute the **newest** `created_at` across all returned rows.
  3. If `newest > tapTime` → **success**: cancel timer, success toast ("Deposit received / confirmed"), `markMT5AccountsAsStale()`, redirect to Transaction-History (see redirect fix below).
  4. Else keep waiting; update the status text ("Checking… (Ns)").
- On **60s elapsed with no newer txn** → **timeout**: cancel timer, toast **"Transaction is processing. Check Transaction History."**, redirect to Transaction-History (the user waits there).

### Cancel handling (back + swipe within 60s)
- On the waiting screens the current `PopScope(canPop:false, onPopInvoked: _goToHistory)` must change to a **cancel** action:
  - `PopScope(canPop: false, onPopInvoked: (didPop){ if(!didPop) _cancel(); })`
  - `_cancel()`: cancel the timer, show error toast **"Transaction cancelled"**, then `Get.back()` (return to the deposit screen the user came from — NOT to history).
  - The AppBar back arrow calls the same `_cancel()`.
  - **Important:** distinguish "user cancel" from "auto success/timeout redirect". Use an internal `bool _resolved = false;` — set it `true` when success/timeout fires so `PopScope`/dispose don't double-fire the cancel toast.

### Transaction-History back-navigation fix (UNIVERSAL — every caller)

Transaction History is opened from **multiple** places, and back + swipe must ALWAYS return to wherever the user came from:

| Caller | How it opens | Back stack? |
|---|---|---|
| `more_screen.dart:934` | `Get.toNamed(TRANSACTION_HISTORY)` — **no args** | YES (normal push) |
| `celestial_settings_screen.dart:581` | `Get.toNamed(...)` — no args | YES |
| `meta_settings_screen.dart:581` | `Get.toNamed(...)` — no args | YES |
| Cregis success/address/controller (3×) | `Get.offAllNamed(..., {'from':'finance'})` | NO (stack wiped) |

**Current bug (both symptoms):**
1. `PopScope(canPop:false, onPopInvoked: /* no-op */)` → **swipe-back is completely swallowed everywhere** → stuck screen.
2. AppBar back reads `from` arg; the 3 `toNamed` callers pass **no** `from`, so it defaults to `'dashboard'` → `Get.offAllNamed(TRADING)` even when the user came from More/Settings (wrong destination), and the Cregis `offAllNamed` case does `Navigator.pop()` on an empty stack → blank.

**Universal fix — one `_handleBack()` used by BOTH AppBar back AND `PopScope`:**
```dart
void _handleBack() {
  // Normal push (More / Celestial / Meta settings) → return to origin.
  if (Navigator.of(context).canPop()) {
    Get.back();
    return;
  }
  // Stack was wiped (Cregis offAllNamed flow) → dashboard is the origin.
  Get.offAllNamed(Routes.TRADING);
}
```
- `PopScope(canPop:false, onPopInvoked:(didPop){ if(!didPop) _handleBack(); })` — fixes swipe-back for **every** caller.
- AppBar back arrow → `_handleBack()` (drop the old `fromTab` switch entirely; `canPop()` is a more reliable signal than the missing `from` arg).
- This makes back + swipe correct for More, Celestial, Meta, AND the Cregis redirect — no per-caller args needed.

**Note:** we no longer need to thread a `from:'cregis'` arg. `Navigator.canPop()` distinguishes "pushed normally" (has origin to pop back to) from "offAllNamed" (stack empty → go dashboard). Simpler and covers all current + future callers.

---

## Files to change

1. **`lib/screens/finance/view_models/deposit_instruction_controller.dart`**
   - Capture `_cregisTapTime = DateTime.now()` at the top of `createCregisDepositAddress()`.
   - Pass `tapTimeIso` in the route args for `CREGIS_SUCCESS` (and to the address screen wherever it's pushed).
   - **Remove / neuter the redundant `_startPolling()`** (the `deposit/by-reference` poller) since the waiting screen now owns polling. Keep `_stopPolling()` for safety, or delete the trio (`_pollingTimer`, `_pollingAttempts`, `_pollCregisStatus`, constants) if nothing else references them — verify with a search first.

2. **`lib/screens/finance/presentation/pages/cregis_success_screen.dart`**
   - Add `final String tapTimeIso;` to the widget + constructor + route-arg wiring in `app_pages.dart` binding (check how args are currently unpacked).
   - Replace `_startStatusPolling()` internals: 5s interval, 60s cap, Transaction-History poll, newest-`created_at` > tap-time = success.
   - Replace `PopScope`/back button with the `_cancel()` behavior ("Transaction cancelled").
   - On success/timeout set `_resolved = true` and redirect to history with `from:'cregis'`.

3. **`lib/screens/finance/presentation/pages/cregis_address_screen.dart`**
   - Same changes as the success screen (tapTimeIso arg, 5s/60s Transaction-History poll, cancel toast, resolved flag, redirect with `from:'cregis'`).

4. **`lib/screens/finance/presentation/pages/transaction_history_screen.dart`**
   - Extract the AppBar back logic into `_handleBack()`.
   - `PopScope(canPop:false, onPopInvoked:(didPop){ if(!didPop) _handleBack(); })` (was a no-op → this is the blank-screen fix).
   - Add `from == 'cregis'` → `Get.offAllNamed(Routes.TRADING)` branch so post-deposit back lands on dashboard.

5. **Route bindings** (`lib/routes/app_pages.dart`) — verify how `CREGIS_SUCCESS` / `CREGIS_ADDRESS` unpack `Get.arguments` and add `tapTimeIso`. (The screens may read `Get.arguments` directly instead of constructor params — confirm before editing.)

6. **Translations** (`assets/translations/*.json`) — add keys if the codebase localizes toasts (check whether these toasts use `languageService.tr(...)` or raw strings; current Cregis toasts are raw English strings, so raw is consistent).

---

## Polling detail — reuse vs. lightweight call

`TransactionHistoryController.fetchUserTransactions()` does a LOT of logging and replaces the whole `userTransactions` list. Calling it every 5s is heavy but functionally fine and reuses the exact same parsing/repository path (`_repo.getTransactions`). 

**Chosen:** reuse `Get.put(TransactionHistoryController())` + `fetchUserTransactions()` each tick, then read `userTransactions` and compute `max(createdAt)`. Pros: single source of truth, the destination history screen is already warm. Cons: verbose logs (acceptable; can be quietened later). If perf is a concern we can add a slim `Future<DateTime?> fetchLatestTransactionTime()` to the controller that hits `_repo.getTransactions` and returns only the max `created_at` — **preferred if we want to avoid clobbering `userTransactions` mid-scroll**, but since the user is on the waiting screen (not the list), clobbering is harmless. Go with reuse.

---

## Edge cases

- **Clock skew:** tap-time is device-local; `created_at` is server time (parsed `.toLocal()`). If server/device clocks differ, a "newer" txn check could false-positive/negative. Mitigation: compare in UTC (`DateTime.tryParse(createdAt)` is UTC if the ISO has `Z`) and subtract a small skew buffer (e.g. treat `created_at > tapTime - 3s` as new) — **but** the user explicitly said "just newer than tap-time", so keep it simple first; note the risk.
- **First tick race:** don't fire the success check on a txn that already existed before the tap. Because we compare to tap-time this is naturally handled — pre-existing txns have older `created_at`.
- **Double redirect:** guard every terminal action with `if (_resolved) return; _resolved = true;`.
- **dispose during in-flight await:** check `mounted` after every `await` before `setState`/navigation (already the pattern in these files).
- **Swipe-back vs. programmatic pop:** `PopScope.onPopInvoked(didPop)` — only act when `!didPop`.
- **`Get.offAllNamed` wipes stack:** that's why the history back must be `offAllNamed(TRADING)` for the `cregis` case, not `Navigator.pop`.

---

## Verification

1. `flutter analyze` on all 4 changed files → 0 errors.
2. Manual: tap Generate Address →
   - deposit completes fast (server posts a txn within 60s) → success toast + lands on history.
   - nothing happens for 60s → "processing" toast + lands on history.
   - press back / swipe within 60s → "Transaction cancelled" toast + returns to deposit screen.
3. On history after auto-redirect: back button AND swipe-back → dashboard (no blank screen).
4. Confirm the 5s cadence hits `${ajax}transactions` (check network logs).

---

## Open questions (resolved)

- **Success match rule:** ANY txn with `created_at > tap-time` (confirmed by user).
- **Cancel = back OR swipe** → "Transaction cancelled" (confirmed by user).
