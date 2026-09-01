# Login → Home API Optimization

Status of the 4 approved fixes from the login→home audit (Vantage + iQuote).

## ✅ Fix 1 — Account re-put storm removed (DONE)
`lib/screens/auth/view_models/auth_controller.dart`
- The pre-login `DashboardController` registration is now reused as the permanent
  instance (no fresh `Get.put` that shadows `main.dart`'s permanent one).
- Deleted the `Get.delete` + `Get.put` re-init blocks for `DashboardController`
  and `AccountController`. Both are already registered `permanent: true` in
  `main.dart:340-341` and are populated by the awaited
  `forceCheckMT5Accounts()` + `forceRefreshAccountData()` earlier in `login()`.
- Effect: `GET user/mt5accounts/get` drops from ~4× to ~1× per login.
- WebSocket-service re-init blocks (Instruments/ChartSocket/Trading/TradingWS/
  AccountWS) were kept — they need fresh post-login socket state.

## ✅ Fix 2 — iQuote duplicate banners + IB wrapper (DONE)
- `lib/screens/home/iquote_home_screen.dart`: removed the explicit
  `bannerController.fetchBanners()` in `initState`. `BannerController.onInit`
  already fetches, so registration alone is enough → no duplicate
  `GET user/banners` on first launch.
- `lib/screens/home/more/iquote_assets_layout.dart`: `_handleSwitchToIB()` now
  delegates to the single shared `IquoteHomeScreen.handleSwitchToIB()` instead of
  duplicating the `IbmController` + `checkSystemAndNavigate` body.

## ✅ Fix 3 — Chart WebView pre-warm (DONE)
- New `lib/widgets/tenax_chart/chart_prewarmer.dart`: `TenaxChartPrewarmer.warm()`
  loads the chart bundle once in a hidden `HeadlessInAppWebView` (idempotent,
  best-effort, self-disposes after 5s).
- Wired into both home screens after first frame: `iquote_home_screen.dart`
  `initState` and `trading_main_screen.dart` (Vantage host) postFrame callback.
- Combined with the earlier `cacheEnabled: true` (`view.dart`) and the 500-bar
  initial history cap (`rest_api.dart`), first chart open is materially faster.

---

## 🔜 Fix 4 — Bootstrap-endpoint merge (PLAN ONLY — needs backend)

The remaining win is on the **foreground** critical path (login → home). Today,
before home is usable, the app makes ~6-8 blocking calls, several redundant.

### Current foreground sequence (per login)
1. `POST user/login`
2. `GET user/mt5accounts/get`      (now 1× after Fix 1)
3. `POST user/mt5accounts/mt5AccountSync`
4. `GET user/settings/profile`     (compliance gate — blocks navigation)
5. `GET user/instruments/{account}` (Vantage favorites hydrate)
6. `GET user/enabled-modules`      (background, but gates module UI)

### Proposal A — single bootstrap endpoint
Add one authenticated endpoint, e.g. `GET user/bootstrap`, returning everything
the home shell needs in one round trip:

```jsonc
{
  "profile":        { /* same shape as user/settings/profile */ },
  "enabled_modules":{ /* same as user/enabled-modules */ },
  "crm_settings":   { /* same as crm settings service payload */ },
  "accounts":       [ /* same as user/mt5accounts/get */ ],
  "kyc_status":     { /* compliance flags used by _checkCompliance */ },
  "regulation":     { /* flags currently derived from settings/profile */ }
}
```

Client change (once the endpoint exists):
- Call `user/bootstrap` immediately after `login` (or have `login` embed this
  payload directly — even better, saves a round trip).
- Feed the sub-objects into the already-registered permanent controllers/services
  (`DashboardController`, `AccountController`, `EnabledModulesService`,
  `CrmSettingsService`, compliance) instead of each firing its own GET.
- Net: collapses calls #2, #4, #6 (and the crm-settings call) into **one**.

### Proposal B — merge accounts sync + fetch
`mt5AccountSync` (#3) and `mt5accounts/get` (#2) run back-to-back. A single
"sync-and-return" endpoint (`POST user/mt5accounts/sync?return=1`) that performs
the sync and returns the fresh account list removes one more round trip.

### Expected result
Foreground login→home REST calls drop from ~6-8 to ~2-3
(`login` [+ embedded bootstrap] → optionally `sync` → `instruments`).

### Why this is backend-gated
Both proposals need new/extended server endpoints. No client code should change
until the API contract is available; otherwise we'd add a call that 404s. When
the backend is ready, the client wiring is small because all the target
controllers/services are already permanent singletons.
