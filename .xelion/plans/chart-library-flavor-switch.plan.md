# Chart Library Flavor Switch (TradingView Advanced Charts + Custom Datafeed)

## Goal
Chart screen me ek **new chart library** (TradingView Advanced Charts with custom Datafeed) add karna hai jo **per-flavor `useNewChart` flag** ke through toggle ho. Flag `true` ho to naya chart load ho, `false` (default) ho to abhi wala existing WebView chart (`/mobile-chart` URL) hi load ho. Implementation reference user ne `chart_source/` me di hai (`ChartScreen.jsx`, `Datafeed.js`, `flutter/chart_screen.dart`, `flutter/datafeed.dart`, `IMPLEMENTATION_GUIDE.md`) — wo files workspace ke bahar hain isliye implementation phase me Agent ko unhe **workspace ke andar copy** karwa kar consult karna hoga (see "Risks / Open questions").

## Approach

### Why TradingView Advanced Charts (WebView) over native Flutter chart
- Reference files JSX + JS Datafeed hain → ye **TradingView Charting Library / Advanced Charts** ka standard pattern hai (JSAPI + `Datafeed` implementing `onReady`, `searchSymbols`, `resolveSymbol`, `getBars`, `subscribeBars`, `unsubscribeBars`).
- Native Flutter port karna effort-heavy aur feature-lossy hoga.
- Best fit: ek **new local HTML** (`assets/chart/advanced/index.html`) banao jo TradingView library ko inline use kare, aur **`Datafeed.js`** ko Flutter-side se bridge karo (HTTP for history bars, WebSocket subscription for realtime via `JavaScriptHandler`s in `flutter_inappwebview`).
- Existing `ChartInAppWebView` ko untouched chhodte hain. Ek **naya widget** `AdvancedChartInAppWebView` banao jo same external API (`updateSymbol`, `updateNativeTrades`) expose kare, taaki `chart_screen.dart` me sirf widget swap karna pade.

### Flag plumbing (config-driven)
1. **`assets/brands/<brand>/brand.yaml`** me har brand ke andar ek naya section:
   ```yaml
   features:
     useNewChart: true   # ya false
   ```
2. **`scripts/generate_brand_config.dart`** ko update karo: `features` section parse karke `useNewChart` bool nikalo, aur **per-brand `lib/clients/<brand>/config.dart`** + **`lib/flavor_config.dart`** me propagate karo.
3. **`lib/clients/base_config.dart`** me `final bool useNewChart` add karo (default `false`).
4. **`FlavorConfig`** me getter `useNewChart` add karo.
5. **`chart_screen.dart` → `_buildChartArea()`** me sirf widget choose karo:
   ```dart
   final useNew = FlavorConfig.instance.useNewChart;
   return useNew
       ? AdvancedChartInAppWebView(key: _webViewKey, symbol: ..., url: ...)
       : ChartInAppWebView(key: _webViewKey, symbol: ..., url: ...);
   ```
   `_webViewKey` type `GlobalKey<ChartInAppWebViewState>` se badal ke ek **shared abstract state interface** (e.g. `ChartWebViewController`) ya simply `GlobalKey<State>` + dynamic call wrapper banayenge so dono widgets ke `updateSymbol` / `updateNativeTrades` call ek hi code path se kaam karein.

### New chart widget design
- `lib/widgets/advanced_chart_inapp_webview.dart`
  - Loads `file:///android_asset/flutter_assets/assets/chart/advanced/index.html` (via `InAppWebView` `initialFile` / `loadFile`).
  - Registers `JavaScriptHandler`s:
    - `getBars(symbol, resolution, from, to, countBack, firstDataRequest)` → calls backend candles API → returns JSON array `[{time, open, high, low, close, volume}]`.
    - `resolveSymbol(symbol)` → returns symbol metadata (pricescale from `SymbolDetailsCacheService`).
    - `subscribeBars(symbol, resolution, subscribeUid)` → start price stream subscription (via `ChartSocketController`), forward ticks back to JS via `evaluateJavascript("window.__onTick(...)")`.
    - `unsubscribeBars(subscribeUid)` → stop subscription.
  - Public methods (same names as existing widget):
    - `updateSymbol(String symbol)`
    - `updateNativeTrades(String tradesJson)`
- `assets/chart/advanced/`
  - `index.html` — bootstraps TradingView widget, wires `Datafeed.js`.
  - `Datafeed.js` — ported 1:1 from reference, but `getBars/subscribeBars/unsubscribeBars` call **Flutter handlers via `window.flutter_inappwebview.callHandler(...)`** instead of direct `fetch`/WebSocket.
  - (TradingView library JS: either load from CDN if license allows, OR vendor locally — decide in implementation, see Risks.)

### Backwards compatibility
- All flavors default `useNewChart: false` initially → zero behavior change for existing brands.
- Only `telifox` (or whichever brand user wants to test) flips to `true`.

## Steps

- [ ] **Step 1 — Reference files ko workspace me copy karo**
  - Agent: `/Users/akash/Desktop/Soneji Infotech/chart_source/` ke 5 files ko `app/.xelion/reference/chart_source/` ke andar copy karo (user ko bolo ya manually copy karke pull karo). Implementation in tinhi files ke andar likhe API ko exactly mirror karna chahiye.
  - Files: `ChartScreen.jsx`, `Datafeed.js`, `flutter/chart_screen.dart`, `flutter/datafeed.dart`, `IMPLEMENTATION_GUIDE.md`.

- [ ] **Step 2 — `BaseClientConfig` me `useNewChart` field add karo**
  - File: `lib/clients/base_config.dart`
  - Add `final bool useNewChart;` (default `false` in constructor).

- [ ] **Step 3 — All `lib/clients/<brand>/config.dart` me `useNewChart` set karo**
  - Currently sirf `lib/clients/telifox/config.dart` exist karta hai. Set `useNewChart: true` for telifox (since user testing). Aur brand configs generator se aayenge.

- [ ] **Step 4 — `brand.yaml` schema extend karo**
  - Files: `assets/brands/<brand>/brand.yaml` (sabhi 6 brands: celestial, pipze, skyriss, telifox, tenax, vantage) + `assets/config/brands/brands.yaml`.
  - Har brand me add:
    ```yaml
    features:
      useNewChart: false   # telifox: true
    ```

- [ ] **Step 5 — Generator update karo**
  - File: `scripts/generate_brand_config.dart`
  - `parseYaml` ke section list me `'features'` add karo (saath me android/ios/colors/urls/assets ke).
  - `parseSingleBrandYaml` me default `features: { useNewChart: false }`.
  - `generateBrandConfigs()` me `useNewChart: ${features['useNewChart'] ?? false}` line emit karo.
  - `generateBrandsJson` me `features` section include karo.
  - `generateLegacyBrandsYaml` me bhi `features` write karo (so round-trip safe).

- [ ] **Step 6 — `FlavorConfig` me field + getter add karo**
  - File: `lib/flavor_config.dart` (generated)
  - Generator me add: `final bool useNewChart;` constructor param + storage + `applyBranding()` me preserve, aur extension `toFlavorConfig()` me pass `useNewChart: useNewChart`.
  - Manual regen: `dart run scripts/generate_brand_config.dart`.

- [x] **Step 7 — Naya widget `AdvancedChartInAppWebView` banao**
  - File: `lib/widgets/advanced_chart_inapp_webview.dart`
  - Same constructor shape as `ChartInAppWebView` (`url`, `symbol`, `key`).
  - `State` class `AdvancedChartInAppWebViewState` with public `Future<void> updateSymbol(String)` and `Future<void> updateNativeTrades(String)`.
  - `InAppWebView` with `initialFile: "assets/chart/advanced/index.html"`.
  - Register handlers: `getBars`, `resolveSymbol`, `subscribeBars`, `unsubscribeBars`, `onChartReady`.
  - On `subscribeBars`, hook into existing `ChartSocketController.priceStream` (Get.find) and push ticks via `controller.evaluateJavascript("window.__onTick(${jsonEncode(tick)})")`.

- [ ] **Step 8 — Datafeed bridge service**
  - File: `lib/services/chart_datafeed_bridge.dart`
  - `getBars(symbol, resolution, from, to, countBack)` → HTTP call to candles endpoint (use existing `FlavorConfig.instance.chartBaseUrl` or API base; pick after seeing reference `Datafeed.js`).
  - `resolveSymbol(symbol)` → return cached digits/pricescale via `SymbolDetailsCacheService.getSymbolDetails`.
  - Keeps logic out of the widget so it's testable.

- [ ] **Step 9 — Assets: `assets/chart/advanced/` add karo**
  - Files:
    - `assets/chart/advanced/index.html`
    - `assets/chart/advanced/Datafeed.js`
    - (TradingView library bundle if vendoring; otherwise CDN script tag).
  - `pubspec.yaml` me `assets:` list me `- assets/chart/advanced/` add karo.

- [ ] **Step 10 — `chart_screen.dart` me conditional rendering**
  - File: `lib/screens/home/chart_screen.dart`
  - `_webViewKey` ko ek shared interface ya `GlobalKey` ke pair me convert karo (do separate keys: `_legacyKey`, `_advancedKey`). Helper methods:
    ```dart
    void _wvUpdateSymbol(String s) {
      if (FlavorConfig.instance.useNewChart) {
        _advancedKey.currentState?.updateSymbol(s);
      } else {
        _legacyKey.currentState?.updateSymbol(s);
      }
    }
    void _wvUpdateTrades(String json) { /* similar */ }
    ```
  - `_buildChartArea()` ke andar return me conditional widget.
  - All existing call sites (`_handleSymbolChange`, `_updateTradesOnChart`, `didUpdateWidget` paths) ko helper methods se route karo — no other behavior change.

- [ ] **Step 11 — Regenerate + smoke test**
  - Run `dart run scripts/generate_brand_config.dart`.
  - Run `./build.sh telifox apk debug` (or VSCode `prepare-telifox` task) and verify:
    - With `useNewChart: false` → existing chart loads (no regression).
    - With `useNewChart: true` → new advanced chart loads, symbol change works, trades overlay works.

- [ ] **Step 12 — Docs**
  - Update `docs/ADD_NEW_CLIENT.md` (or add new `docs/CHART_LIBRARY_SWITCH.md`) describing the `features.useNewChart` flag and how to author the advanced chart assets.

## Files

### New
- `lib/widgets/advanced_chart_inapp_webview.dart` — new chart WebView widget mirroring existing widget's public API.
- `lib/services/chart_datafeed_bridge.dart` — Flutter-side handlers for TradingView Datafeed (`getBars`, `resolveSymbol`, subscribe/unsubscribe).
- `assets/chart/advanced/index.html` — TradingView Advanced Charts host page.
- `assets/chart/advanced/Datafeed.js` — Datafeed implementation that talks to Flutter handlers.
- `docs/CHART_LIBRARY_SWITCH.md` — how-to for the new flag (optional).
- `app/.xelion/reference/chart_source/*` — copies of user-provided reference files (read-only).

### Modified
- `lib/clients/base_config.dart` — add `useNewChart` field (default `false`).
- `lib/clients/telifox/config.dart` — generated, will get `useNewChart: true`.
- `lib/flavor_config.dart` — generated, add `useNewChart` field + getter + `applyBranding` preserve.
- `scripts/generate_brand_config.dart` — parse `features` section, emit `useNewChart` everywhere.
- `assets/brands/<brand>/brand.yaml` (all 6 brands) — add `features.useNewChart`.
- `assets/config/brands/brands.yaml` — regenerated copy with `features`.
- `assets/config/brands/brands.json` — regenerated.
- `lib/screens/home/chart_screen.dart` — branch in `_buildChartArea()`, two GlobalKeys, helper wrappers for `updateSymbol` / `updateNativeTrades`.
- `pubspec.yaml` — add `- assets/chart/advanced/` to assets list.

## Risks / Open questions

1. **Reference files workspace ke bahar hain** (`/Users/akash/Desktop/Soneji Infotech/chart_source/`). Plan ka Step 1 unhe `app/.xelion/reference/chart_source/` me copy karna hai. Tab tak Datafeed ka exact HTTP/WebSocket protocol unknown hai. Implementer ko Datafeed bridge code likhne se pehle un files ko padhna mandatory hai.
2. **TradingView Advanced Charts license** — agar reference me proprietary `charting_library/` folder use ho raha hai, to use vendor karna hoga (CDN se nahi milta). User confirm kare ki licensed bundle available hai.
3. **Bars endpoint** — `chartBaseUrl/<?>` me history candles endpoint kya hai? Reference `Datafeed.js` se nikalna hoga; agar same backend nahi hai to extra config field (`candlesUrl`) bhi `brand.yaml` me add karna pad sakta hai.
4. **WebSocket reuse vs separate** — naya chart `ChartSocketController` ke same `priceStream` ka use karega ya alag tick channel? Reference padhne ke baad decide. Default plan: reuse existing controller (no duplicate sockets).
5. **`_webViewKey` typing** — current code `GlobalKey<ChartInAppWebViewState>` use karta hai with explicit `currentState?.updateSymbol(...)` calls. Hum do alag keys + helper wrappers approach le rahe hain (simple, no shared base class). Acceptable trade-off.
6. **Hot-reload across runtime brand switch** — `applyBranding()` se runtime me brand badalti hai; `useNewChart` change hoga to chart screen rebuild zaroori hai. Plan: `FlavorConfig.applyBranding()` se aane wali value chart_screen me already `build()` me read hoti hai, so next rebuild auto pick karega.
7. **iOS WebView `initialFile`** — `flutter_inappwebview` me local asset HTML JS handlers ke saath dono platforms par kaam karta hai; iOS pe `WKWebView` ko allow file access dena pad sakta hai (`InAppWebViewSettings(allowFileAccess: true, allowFileAccessFromFileURLs: true, allowUniversalAccessFromFileURLs: true)`). Implementer ko add karna hoga.
8. **Default flag value per flavor** — current plan: sab `false`, sirf `telifox` `true`. User confirm kare agar koi aur brand bhi by-default `true` chahiye.
