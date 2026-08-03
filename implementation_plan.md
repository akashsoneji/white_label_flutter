# Apply Fast Loading Preloaded Chart to Celestial and Meta

The goal is to apply the fast-loading, background-preloaded, cache-enabled WebView chart (currently used in Pipze/iQuote) to the Celestial and Meta brands, without breaking their existing UI elements (trade buttons, position lines, timeframe picker).

## User Review Required

Because Celestial and Meta have complex features built directly into their chart screens (like `__renderPositionLines`, `__pushLiveTick`, timeframe switching, etc.), migrating them from `webview_flutter` to `flutter_inappwebview` requires ensuring all JS communication bridges are preserved.

## Proposed Changes

### 1. `lib/widgets/chart_inapp_webview.dart`
- Expose an `evaluateJavascript(String source)` method on `ChartInAppWebViewState` so parent screens can call custom JS functions like `__renderPositionLines`.

### 2. `lib/services/chart_preload_service.dart`
- Adapt `ChartPreloadService` to preload `assets/chart/index.html` for Celestial and Meta (since they use the local HTML file for drawing position lines and custom timeframes), OR adjust the service so that if it's Meta/Celestial it preloads the local asset using `InAppLocalhostServer` or `initialFile`. 

### 3. `lib/brands/celestial/celestial_chart_screen.dart`
- Replace `WebViewWidget(controller: _wvc)` with `ChartInAppWebView`.
- Use a `GlobalKey<ChartInAppWebViewState>` to interact with the chart.
- Replace `_wvc.runJavaScript(js)` with `chartKey.currentState?.evaluateJavascript(js)`.
- Use `url: "asset://assets/chart/index.html"` or an appropriate asset URI.

### 4. `lib/brands/meta/meta_chart_screen.dart`
- Apply the same changes as `celestial_chart_screen.dart`.

## Open Questions
- Do you want Celestial and Meta to use the remote URL (`mobile-chart`) like IQuote, OR do you want them to continue using the local `assets/chart/index.html` but powered by the fast `flutter_inappwebview` with preloading? (Local asset is recommended as it contains the custom JS for drawing position lines and timeframes).
