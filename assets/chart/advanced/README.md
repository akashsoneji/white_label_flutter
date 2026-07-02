# Advanced Chart (free TradingView widget)

The new chart (enabled per-brand via `useNewChart: true` in
`lib/clients/<brand>/config.dart`) loads `index.html` from this folder.

The HTML embeds the **free public TradingView widget**
(`https://s3.tradingview.com/tv.js`) — **no license, no bundle, no extra
asset** needed. As long as the device has internet, the chart will work.

## How it gets data

- TradingView's **own market data** is used (FX, indices, commodities, crypto,
  US stocks). The HTML maps a raw symbol like `EURUSD`, `XAUUSD`, `BTCUSD` or
  a broker-suffixed `EURUSD.r` to a TradingView exchange-qualified symbol
  (e.g. `FX:EURUSD`, `OANDA:XAUUSD`, `BINANCE:BTCUSDT`).
- The user can also search any symbol from the widget's built-in toolbar.

## Trade-off vs. the licensed Advanced Charting Library

| Feature                       | Free widget (used here) | Licensed lib |
|-------------------------------|-------------------------|--------------|
| Candlestick + all timeframes  | ✅                      | ✅           |
| Indicators (RSI, MACD, …)     | ✅                      | ✅           |
| Drawing tools                 | ✅                      | ✅           |
| Light / dark theme            | ✅                      | ✅           |
| **Custom data feed**          | ❌                      | ✅           |
| **Trade markers / overlays**  | ❌                      | ✅           |
| Symbol search                 | ✅ (TV's catalog)       | ✅ (custom)  |
| License fee                   | $0                      | $$$          |

If/when you license TradingView's Advanced Charting Library and want to
plug in your own data feed + trade markers, replace `index.html` with the
licensed bundle's `index.html` + drop `charting_library/` next to it.
