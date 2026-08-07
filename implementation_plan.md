# TradingView Charting Library — Local-Asset Chart Loading (2026-08-07)

## Goal
Replace the remote `chartBaseUrl/mobile-chart` URL loader with the licensed `charting_library` bundles from `/chart_lib/`, served as local Flutter assets. Chart loads instantly from `file:///android_asset/...` and live ticks stream via WebSocket through Dart-side `ChartDatafeedBridge`.

## ✅ What was done (this iteration)

| # | Task | Status |
|---|---|---|
| 1 | Copied `/chart_lib/charting_library/` (24MB, 178+ bundle files) → `app/assets/charting_library/` | ✅ Done |
| 2 | Added `assets/charting_library/` to `pubspec.yaml` under `flutter.assets` | ✅ Done |
| 3 | Copied `tradyn_chart.html` → `assets/charting_library/tradyn_chart.html` so `library_path: "charting_library/charting_library"` resolves from the same directory as the HTML | ✅ Done |
| 4 | Updated `tradyn_chart.html`: `FlutterBridge.postMessage` → `flutter_inappwebview.callHandler('FlutterBridge', payload)` (correct v6 API) + dual-fallback for either API | ✅ Done |
| 5 | Added `_extractSymbolFromUrl()` to read `?symbol=XAUUSD` from URL params (so ChartPreloadService.getLocalChartUrl() injects symbol without needing __chartConfig) | ✅ Done |
| 6 | `lib/services/chart_preload_service.dart` `_buildUrl()` now returns `file:///android_asset/flutter_assets/assets/charting_library/tradyn_chart.html?symbol=$sym` | ✅ Done |
| 7 | Removed `ValueKey(_svc.currentSymbol)` from `_PersistentChartWebView` so WebView is NOT rebuilt on symbol change — JS-based symbol swap preserves chart state | ✅ Done |
| 8 | Added `ChartPreloadService.setSymbol()` that calls `window.__changeSymbol(sym)` via JS instead of triggering URL reload | ✅ Done |
| 9 | `lib/widgets/chart_inapp_webview.dart`: imported `ChartDatafeedBridge` + `AccountController`, added `_initDatafeedBridge()` that registers `controller.addJavaScriptHandler(handlerName: 'FlutterBridge', ...)` to bridge JS → Dart for `onReady/resolveSymbol/getBars/subscribeBars/unsubscribeBars` | ✅ Done |
| 10 | `_initDatafeedBridge.subscribeBars` wires live ticks: `ChartSocketController.priceStream` → `evaluateJavascript('window.__rtCb_$uid(bar)')` to push to WebView in realtime | ✅ Done |
| 11 | Added `__changeSymbol` to `updateSymbol()` JS source as a fast-path symbol-change entry | ✅ Done |
| 12 | `ChartDatafeedBridge.resolveSymbol` now receives `accountNumber` from `Get.find<AccountController>().activeMT5Account?.metaAccountNumber` so symbol metadata (digits, category) is accurate | ✅ Done |
| 13 | Removed unused `color.dart` + `flavor_config.dart` imports from `chart_preload_service.dart` (lint clean) | ✅ Done |

## 📁 Files modified
- `pubspec.yaml` — added charting_library asset entry
- `assets/charting_library/tradyn_chart.html` — new (copied + patched)
- `lib/services/chart_preload_service.dart` — local-asset URL + JS-based symbol swap
- `lib/widgets/chart_inapp_webview.dart` — Datafeed bridge handler + AccountController integration

## 🔧 Pending follow-ups (Phase 6+)
- [ ] **Apply local URL across all chart screens**: Currently `celestial_chart_screen.dart`, `meta_chart_screen.dart`, `iquote_chart_screen.dart`, `vantage_chart_layout.dart`, `chart_screen.dart`, `edit_order_screen.dart`, `close_position_screen.dart`, `pending_order_screen.dart` still build URLs like `${chartBaseUrl}/mobile-chart?symbol=$sym`. Replace each with `ChartPreloadService.getLocalChartUrl(sym)` so all screens load the local bundle instead of remote. **Pattern**:
  ```dart
  // Before
  final url = '${FlavorConfig.instance.chartBaseUrl}/mobile-chart?symbol=$sym&theme=${AppColors.chartTheme}';
  // After
  final url = ChartPreloadService.getLocalChartUrl(sym);
  ```
- [ ] **Test on iQuote** (`useNewChart: false` for now — should keep using local via `ChartInAppWebView` after URL swap)
- [ ] **Test on Pipze** (currently uses `useNewChart: false`)
- [ ] **Verify** chart tab switch (Vantage 5-tab) is instant — preloaded WebView already warm
- [ ] **Verify** symbol change in watchlist does not reload WebView (just JS update)
- [ ] **Verify** position/order lines render via `__renderPositionLines`
- [ ] **Verify** tick stream pushes bars in realtime (no chart lag)
- [ ] **Remove** old `lib/services/chart_preload_service.dart` `_buildUrl` remote-URL code path (kept as fallback for offline mode?)

## Open Questions
- Should we still keep `${chartBaseUrl}/mobile-chart` as an offline fallback for brands that haven't migrated, OR replace everywhere and use only the local bundle?
- Should `useNewChart: true/false` now toggle between AdvancedChartInAppWebView (free widget) vs local ChartInAppWebView (licensed), or both should use the local bundle?

## Verification evidence
- `flutter analyze lib/widgets/chart_inapp_webview.dart lib/services/chart_preload_service.dart lib/services/chart_datafeed_bridge.dart` → No issues found
- `flutter analyze lib/` → 121 pre-existing warnings (none in our modified files)
- Bundle files verified at `assets/charting_library/` (24MB total)
- `library_path: "charting_library/charting_library"` resolves relative to the HTML's location
