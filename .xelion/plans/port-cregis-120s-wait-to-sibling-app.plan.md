# Plan: Port Cregis 120s deposit-wait flow to a second app (same logic, different UI)

## Goal

Take the Cregis deposit-wait behaviour implemented in this whitelabel app (current project) and replicate the **logic** in a sibling Flutter app that has the **same backend but different design/branding/feature-folder layout**. UI markup, asset paths, brand assets, and routing style will differ — this plan keeps those as `[ADAPT]` placeholders so the implementer can wire them in their target codebase.

**What stays IDENTICAL across both apps (logic to copy 1:1):**

- 120-second duration cap on the Cregis waiting screen.
- 5-second poll interval.
- Success detection rule: **first row in `GET /transactions` whose `referenceNumber.trim() == cregisRef.trim()` AND whose `status` (lowercased) is in `{approved, success, completed}`**.
- Three terminal states — success / timeout / cancel — each guarded by a `_resolved` flag.
- Confirm-cancel dialog (Yes → TRADING/homescreen, No → keep waiting).
- Visible debug strip on the wait screen showing last poll call + response.
- Universal `_handleBack()` on the Transaction-History screen (works for normal-pushed + offAllNamed cases).
- Brand-aware destination binding for `TRANSACTION_HISTORY` (only relevant if the target app also has a Vantage UI tree; skip if it doesn't).

---

## Source files (this app) — what to copy / adapt

| Source file (current project) | Role | Target equivalent |
|---|---|---|
| `lib/screens/finance/view_models/deposit_instruction_controller.dart` | Captures tap-time, passes `tapTimeIso` to waiting screens, removes the legacy `deposit/by-reference` poller | `[ADAPT] lib/screens/.../deposit_instruction_controller.dart` (or wherever the Generate-Address handler lives) |
| `lib/screens/finance/presentation/pages/cregis_success_screen.dart` | Hosted-checkout wait screen, 5s/120s poller, success/timeout/cancel/dialog, debug strip | `[ADAPT] new or existing cregis_success_screen.dart` in target app |
| `lib/screens/finance/presentation/pages/cregis_address_screen.dart` | Direct-address / QR wait screen — same logic | `[ADAPT] cregis_address_screen.dart` in target app |
| `lib/screens/finance/view_models/transaction_history_controller.dart` | Adds `fetchLatestTransactionForRef(ref, {statusFilter})` helper returning `({Data? row, int totalRows, String rawStatus})` | Same controller class — port the helper method only |
| `lib/screens/finance/presentation/pages/transaction_history_screen.dart` | Universal `_handleBack()`, PopScope fix | `[ADAPT] transaction_history_screen.dart` in target app |
| `lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart` | Branded history variant — universal `_handleBack()` | Skip if target app has no Vantage UI tree |
| `lib/routes/app_pages.dart` | Adds `binding: BindingsBuilder(...)` to both CREGIS routes; brand-aware `TRANSACTION_HISTORY` page() | `[ADAPT] app_pages.dart` or `routes.dart` in target app |

**Models / endpoints (assumed shared because backend is the same):**

- `ApiConstants.getTransactions` — endpoint that returns the transaction list.
- `ApiConstants.cregisDepositCreate` — endpoint behind the Generate-Address button.
- `ApiConstants.cregisDepositStatus` — **NO LONGER USED** (the old `deposit/by-reference` poller is deleted). Safe to delete the constant if nothing else references it.
- `Data.referenceNumber`, `Data.status`, `Data.amount`, `Data.createdAt` (or `created_at_iso`) — fields the poller reads.

---

## Step-by-step port

### Step 1 — Add the `fetchLatestTransactionForRef` helper

Open the target app's `TransactionHistoryController` and add this method. Adjust the field names if the target's data model differs (most likely the same since the backend is shared):

```dart
/// Cregis poll helper: returns the FIRST row whose `referenceNumber` matches
/// the Cregis `ref` param AND whose status is one of approved/success/completed.
/// Returns `null` row + diagnostic `rawStatus` on no-match / http_error / exception.
Future<({Data? row, int totalRows, String rawStatus})>
    fetchLatestTransactionForRef(String ref, {bool statusFilter = true}) async {
  try {
    final token = await SecureStorageService.getAuthToken();
    final response = await _repo.getTransactions(token: token ?? '');
    if (!response.success || response.data == null) {
      return (row: null, totalRows: 0, rawStatus: 'http_error');
    }

    final parsed = Transaction.fromJson(response.data as Map<String, dynamic>);
    final rows = parsed.data ?? <Data>[];

    for (final row in rows) {
      if ((row.referenceNumber ?? '').trim() != ref.trim()) continue;
      if (statusFilter) {
        final s = (row.status ?? '').toLowerCase().trim();
        const allowed = {'approved', 'success', 'completed'};
        if (!allowed.contains(s)) continue;
      }
      return (row: row, totalRows: rows.length, rawStatus: 'match');
    }
    return (row: null, totalRows: rows.length, rawStatus: 'no_match');
  } catch (e) {
    return (row: null, totalRows: 0, rawStatus: 'exception:$e');
  }
}
```

If `Transaction.fromJson`/`Data` aren't the exact names, find the actual list-returning parser in the target controller and substitute.

### Step 2 — Capture tap-time in the Generate-Address handler

Open the target app's `DepositInstructionController` (or equivalent — wherever `createCregisDepositAddress()` lives). Add this field at the top of the class:

```dart
DateTime? _cregisTapTime;
```

Then at the start of `createCregisDepositAddress()` (and at the start of `submitCregisDeposit()` if there are TWO navigation points like in this app):

```dart
_cregisTapTime = DateTime.now();
```

And in the `Get.toNamed(...)` call(s) add the route arg:

```dart
arguments: {
  // ... existing args (checkoutUrl/cregisAddress/referenceNumber/amount/networkKey) ...
  'tapTimeIso': _cregisTapTime!.toIso8601String(),
},
```

### Step 3 — Remove the legacy `deposit/by-reference` poller from the controller

In the same controller file, delete these helpers (they belong to the OLD flow):

- `_startPolling()`
- `_stopPolling()`
- `_pollCregisStatus()`

And delete the fields/constants they used:

- `Timer? _pollingTimer;`
- `int _pollingAttempts;` (if nothing else uses it — check with grep first)
- `_pollingStartedAt` if present
- Any `_cregisPollIntervalSeconds` / `_cregisPollMaxDurationMinutes` constants
- Any `_clearCregisState()` helper that became orphan

Also clean up `onClose()` — remove the `_stopPolling()` call.

Verify with `grep -r "_pollingTimer\|_pollCregisStatus" lib/` — there should be ZERO hits after the cleanup. If you find callers outside this controller, migrate them to use the screen-side poll first.

### Step 4 — Update the Cregis waiting screens

This is the biggest change. Both `cregis_success_screen.dart` and `cregis_address_screen.dart` need the same transformation.

#### 4a. Widget constructor — add `tapTimeIso`

```dart
class CregisSuccessScreen extends StatefulWidget {
  // ... existing fields ...
  final String tapTimeIso;

  const CregisSuccessScreen({
    super.key,
    // ... existing required params ...
    required this.tapTimeIso,
  });
  // ...
}
```

Same shape for `CregisAddressScreen`.

#### 4b. State fields and constants

```dart
class _CregisSuccessScreenState extends State<CregisSuccessScreen> {
  // Wait up to 120s, polling Transaction History every 5s.
  static const int _pollIntervalSeconds = 5;
  static const int _maxWaitSeconds = 120;

  Timer? _pollingTimer;
  DateTime? _pollingStartedAt;
  bool _resolved = false; // set once success/timeout/cancel fires
  String _statusText = 'Checking payment details...';
  bool _isPolling = true;
  int _pollAttempts = 0;

  // Visible debug strip
  String _debugLastCall = '(no poll yet)';
  String _debugLastResponse = '(no response yet)';
  DateTime? _debugLastAt;
  // ...
}
```

Adjust the initial `_statusText` per screen (success = "Verifying payment details...", address = "Waiting for payment...").

#### 4c. `initState` and `dispose`

```dart
@override
void initState() {
  super.initState();
  // If this screen also launches the external browser (hosted checkout), call
  // _openExternalBrowser() here too. Don't try to parse tapTime for success —
  // we no longer use tap-time for success detection (the ref-match handles it).
  _startStatusPolling();
}

@override
void dispose() {
  _pollingTimer?.cancel();
  super.dispose();
}
```

#### 4d. Polling body

```dart
void _startStatusPolling() {
  _pollingStartedAt = DateTime.now();
  _pollAttempts = 0;
  _pollingTimer = Timer.periodic(
    const Duration(seconds: _pollIntervalSeconds),
    (timer) async {
      if (!mounted || _resolved) {
        timer.cancel();
        return;
      }

      final elapsed =
          DateTime.now().difference(_pollingStartedAt!).inSeconds;
      if (elapsed >= _maxWaitSeconds) {
        _onTimeout();
        return;
      }

      _pollAttempts++;
      setState(() {
        final remaining = _maxWaitSeconds - elapsed;
        _statusText =
            'Verifying payment details... (${remaining}s, attempt $_pollAttempts)';
      });

      final ref = widget.referenceNumber;
      if (ref.trim().isEmpty) return;

      _debugLastCall =
          'GET /transactions @ ${DateTime.now().toIso8601String()} '
          '(attempt $_pollAttempts, ref=${ref.length > 10 ? '${ref.substring(0, 10)}…' : ref})';
      final res = await Get.find<TransactionHistoryController>()
          .fetchLatestTransactionForRef(ref, statusFilter: true);

      if (!mounted || _resolved) return;
      if (res.row != null) {
        _debugLastResponse =
            'MATCH status=${res.row!.status ?? '?'} amount=${res.row!.amount ?? '?'} '
            'created_at=${res.row!.createdAt ?? '?'}';
        _debugLastAt = DateTime.now();
        _onSuccess();
        return;
      }
      _debugLastResponse =
          'NO MATCH (status=${res.rawStatus}, totalRows=${res.totalRows})';
      _debugLastAt = DateTime.now();
      setState(() {});
    },
  );
}
```

#### 4e. Three terminal states

```dart
void _onSuccess() {
  if (_resolved) return;
  _resolved = true;
  _pollingTimer?.cancel();
  if (mounted) {
    setState(() {
      _isPolling = false;
      _statusText = 'Deposit confirmed!';
    });
  }
  CustomToastService.showSuccess(message: 'Deposit successful!');
  try {
    Get.find<DashboardController>().markMT5AccountsAsStale();
  } catch (_) {}
  Get.offAllNamed(
    [ADAPT] Routes.TRANSACTION_HISTORY, // or AppPages.TRANSACTION_HISTORY
    arguments: {'from': 'finance'},
  );
}

void _onTimeout() {
  if (_resolved) return;
  _resolved = true;
  _pollingTimer?.cancel();
  if (mounted) {
    setState(() {
      _isPolling = false;
      _statusText = 'Transaction is processing. Check Transaction History.';
    });
  }
  CustomToastService.showWarning(
    message: 'Transaction is processing. Please wait in Transaction History.',
    title: 'Processing',
  );
  Get.offAllNamed(
    [ADAPT] Routes.TRANSACTION_HISTORY,
    arguments: {'from': 'finance'},
  );
}

/// Back arrow / device back / swipe within the wait window → confirm dialog.
Future<void> _confirmCancel() async {
  if (_resolved) return;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel payment?'),
      content: const Text(
        'Are you sure you want to cancel this payment? The transaction '
        'will not be processed and you will be returned to the home screen.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('No, keep waiting'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Yes, cancel'),
        ),
      ],
    ),
  );
  if (confirmed != true || _resolved) return;
  _resolved = true;
  _pollingTimer?.cancel();
  CustomToastService.showError(message: 'Transaction cancelled');
  Get.offAllNamed([ADAPT] Routes.TRADING); // home screen route
}

/// Explicit "Go to Transaction History" tap — positive action, no cancel toast.
void _goToHistory() {
  if (_resolved) return;
  _resolved = true;
  _pollingTimer?.cancel();
  Get.offAllNamed(
    [ADAPT] Routes.TRANSACTION_HISTORY,
    arguments: {'from': 'finance'},
  );
}
```

#### 4f. Wire back/swipe/cancel into PopScope and AppBar

```dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvoked: (didPop) {
      if (!didPop) _confirmCancel();
    },
    child: Scaffold(
      // ... existing scaffold ...
      appBar: AppBar(
        // ...
        leading: [ADAPT_AppBackButton](
          onPressed: _confirmCancel,
        ),
        // ...
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // ... existing children ...
            children: [
              // ... status text, "Open Payment Link" button, "Go to Transaction History" button ...

              // ── Debug strip: shows last Transaction-History poll
              //    request/response so QA can see whether the Cregis
              //    reference_number matched. Remove once flow is stable. ──
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug — last poll',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _debugLastCall,
                      style: TextStyle(fontSize: 10.sp, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _debugLastResponse,
                      style: TextStyle(fontSize: 10.sp, color: Colors.black87),
                    ),
                    if (_debugLastAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'at ${_debugLastAt!.toIso8601String()}',
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

[ADAPT] notes:

- **App back-button widget**: target app may use `AppBackButton`, `AppSvgBackButton`, `IconButton`, or a custom widget — substitute accordingly. The handler is `_confirmCancel` in every case.
- **Toast service**: `CustomToastService.showSuccess/Error/Warning` is the convention used in this codebase. If the target app uses a different helper (`Fluttertoast`, `Get.snackbar`, custom service), substitute the equivalent call.
- **Status text wording**: keep English if target app is English-only; otherwise add translation keys (`assets/translations/*.json`) — `cregis_wait_status`, `cregis_wait_success`, `cregis_wait_timeout`, `cregis_wait_cancelled`, `cregis_wait_dialog_title`, `cregis_wait_dialog_content`, `cregis_wait_dialog_yes`, `cregis_wait_dialog_no`.

### Step 5 — Update route bindings

In the target app's `app_pages.dart` (or equivalent), add `binding: BindingsBuilder(...)` to both `CREGIS_SUCCESS` and `CREGIS_ADDRESS` routes so `Get.find<TransactionHistoryController>()` works on the first poll:

```dart
GetPage(
  name: _Paths.CREGIS_ADDRESS,
  binding: BindingsBuilder(() {
    if (!Get.isRegistered<TransactionHistoryController>()) {
      Get.put(TransactionHistoryController());
    }
  }),
  page: () {
    final args = Get.arguments as Map<String, dynamic>?;
    return CregisAddressScreen(
      // ... existing args ...
      tapTimeIso: args?['tapTimeIso'] ?? '',
    );
  },
),
GetPage(
  name: _Paths.CREGIS_SUCCESS,
  binding: BindingsBuilder(() {
    if (!Get.isRegistered<TransactionHistoryController>()) {
      Get.put(TransactionHistoryController());
    }
  }),
  page: () {
    final args = Get.arguments as Map<String, dynamic>?;
    return CregisSuccessScreen(
      // ... existing args ...
      tapTimeIso: args?['tapTimeIso'] ?? '',
    );
  },
),
```

Make sure `transaction_history_controller.dart` is imported in this file.

### Step 6 — Fix Transaction-History screen back/swipe

In the target app's `transaction_history_screen.dart`, replace the current `PopScope` and AppBar back button with a universal `_handleBack()`:

```dart
void _handleBack() {
  if (Navigator.of(context).canPop()) {
    Get.back();           // normal push → return to origin (More, settings, etc.)
    return;
  }
  Get.offAllNamed([ADAPT] Routes.TRADING); // stack wiped (Cregis redirect) → home
}

@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvoked: (didPop) {
      if (!didPop) _handleBack();
    },
    child: Scaffold(
      // ...
      appBar: AppBar(
        // ...
        leading: [ADAPT_AppBackButton](
          onPressed: _handleBack,
        ),
        // ...
      ),
      // ...
    ),
  );
}
```

This fixes the **blank-screen-on-swipe-back** bug for every caller (More, settings, Cregis redirect).

[ADAPT] If the target app also has a Vantage/brand UI tree with a separate `brands/vantage/pages/transaction_history_screen.dart`, apply the same `_handleBack()` there too. Otherwise skip.

### Step 7 — Brand-aware destination (only if target app has Vantage UI)

Skip this step entirely if the target app doesn't have a Vantage UI tree. If it does:

```dart
GetPage(
  name: _Paths.TRANSACTION_HISTORY,
  page: () {
    if (FlavorConfig.usesVantageUi()) {
      return const vantage.VantageTransactionHistoryScreen();
    }
    return const TransactionHistoryScreen();
  },
),
```

Make sure to import the Vantage screen with `as vantage;` and import `flavor_config.dart`.

---

## Verification (target app)

1. `flutter analyze` on all changed files → 0 errors.
2. Manual flow test:
   - Tap Generate Address → within 120s, if the backend posts a matching txn → success toast + lands on history.
   - Tap Generate Address → wait 120s with no match → "Transaction is processing" toast + lands on history.
   - Tap Generate Address → press back / swipe within 120s → confirm dialog → Yes → home, No → keep waiting.
3. On history after auto-redirect → back button + swipe-back both return to dashboard (no blank screen).
4. On history after opening from More/Settings → back + swipe both return to where the user came from.
5. Network logs should show `GET /transactions` once every 5 seconds while the wait screen is active.

---

## Files checklist (target app)

```
[ ] lib/.../view_models/transaction_history_controller.dart        ← add fetchLatestTransactionForRef
[ ] lib/.../view_models/deposit_instruction_controller.dart        ← tap-time capture + tapTimeIso args + delete legacy poller
[ ] lib/.../presentation/pages/cregis_success_screen.dart          ← full rewrite (Step 4)
[ ] lib/.../presentation/pages/cregis_address_screen.dart          ← full rewrite (Step 4)
[ ] lib/.../presentation/pages/transaction_history_screen.dart      ← universal _handleBack (Step 6)
[ ] lib/.../routes/app_pages.dart                                  ← bind controller + add tapTimeIso to bindings (Step 5)
[ ] (only if Vantage UI tree exists) lib/.../brands/vantage/pages/transaction_history_screen.dart ← universal _handleBack (Step 6)
[ ] (only if app localises) assets/translations/*.json             ← add 7 keys (see Step 4f)
```

---

## Risks / open questions

- **Field name differences**: `Data.referenceNumber` / `Data.status` / `Data.amount` / `Data.createdAt` — if the target app's model uses different names, Step 1's helper needs renaming. Grep `referenceNumber` in the target repo to confirm.
- **`DashboardController.markMT5AccountsAsStale()`** — if the target app doesn't have this method, wrap the call in a try/catch (already done in the snippets above) or substitute the equivalent balance-refresh call.
- **`Routes.TRADING` / `AppPages.TRANSACTION_HISTORY` constant names** — target app may use a different naming scheme. Substitute the actual constant.
- **Translations**: target app might already localize error/success toasts; if so, replace raw strings with `languageService.tr('cregis_wait_success')` etc.
- **Flutter version / Dart syntax**: snippets assume Dart 3 with null-safety and modern `withValues(alpha:)` — if the target app is older, replace with `.withOpacity(...)`.
- **Debug strip**: keep it during QA. Remove (or gate behind a `kDebugMode`) once the flow is stable — it's noisy on production builds.