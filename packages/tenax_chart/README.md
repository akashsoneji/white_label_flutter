# tenax_chart

Flutter wrapper for the Tenax Chart 0.2.1 mobile bundle. The chart page
(`assets/chart/`) runs in an `InAppWebView` loaded from the app's own assets
and is fed in **push mode**. The package opens no socket and makes no HTTP
call — the host app supplies everything through `TenaxChartDataSource`.

App-agnostic: drop it into any white-label app with a `path:` dependency.

## Install

```yaml
dependencies:
  tenax_chart:
    path: packages/tenax_chart
```

`flutter_inappwebview ^6.0.0` is the only dependency.

## Use

```dart
TenaxChartView(
  config: TenaxChartConfig(
    symbol: 'XAUUSD',
    interval: '15m',
    themeMode: 'dark',
    persistenceKey: 'tenax.chart.mybrand', // one per brand
    orders: const TenaxOrdersOptions(allowDrag: true, allowClose: true),
  ),
  dataSource: MyDataSource(),        // implements TenaxChartDataSource
  controller: chartController,       // optional, for imperative calls
  onEvent: (event) {},               // optional, chart → app events
  onActionError: (error) {},         // a drag/close the broker refused
)
```

A rebuild with a new `config` (symbol, interval, theme, order options) is
sent to the running page by message — the WebView is not reloaded.
`displayOffsetMinutes` is the exception: the page fixes it at mount, so
when it is null the view reads `server_offset_minutes` from the first bars
page before opening the WebView.

## The data source

| Method | Feeds |
| --- | --- |
| `fetchBars(symbol, interval, limit:)` | history (`GET /api/bars`); also polled with `limit: 3` every 2 s to repair dropped frames |
| `liveBars(symbol, interval)` | server-built `k` bars; subscribe on listen, unsubscribe on cancel |
| `lastPrice(symbol)` | bid/ask for the price lines and P&L — never moves a candle |
| `orders(symbol)` / `orderChanges(symbol)` | positions and pending orders on the symbol |
| `instruments()` | symbol search list (empty list = no search) |
| `instrumentOptions(symbol)` | per-symbol tick size / stop level / contract size, merged over `config.orders` |
| `modifyLevel(orderId:, kind:, price:)` | SL / TP / pending-trigger drag; `price: null` clears; throw to refuse |
| `closeOrder(orderId)` | close from the chart; throw to refuse |

Bars are unix **seconds**, oldest first, last one forming. Engine payloads
can be parsed with `TenaxBarsPage.fromEngineJson` and
`TenaxBar.fromEngineFrame` (prices scaled by `10^digits`).

## Limits of the mobile bundle

- No scroll-back message: the chart shows what the first `fetchBars` returned
  (default 1000 bars).
- The page cannot change its clock offset after mount.

## In crmapp

- Adapter: `lib/services/chart/crm_tenax_chart_data_source.dart`
  (`/ws/stream` + `/api/bars`, order actions via `TradingController`).
- Widget: `lib/widgets/chart/app_tenax_chart.dart` (`AppTenaxChart`).
- Enabled only where `FlavorConfig.usesSingleStreamSocket` is true; other
  flavors keep the remote `/mobile-chart` WebView, marked `LEGACY_CHART`.
