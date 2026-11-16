# How the chart works with your platform

One idea runs through everything here: **the chart draws, your platform decides.**

It never places, moves or closes an order by itself. When a trader drags a stop
loss, the chart shows the level waiting and tells you what they asked for. Your
code calls the broker. Only when you confirm does the line settle. Refuse, and
the old price stands as if nothing happened.

That is deliberate. A chart that moves a stop the instant a finger lets go is
lying about money it does not control.

- [Web / Vue guide](./web.md)
- [Flutter guide](./flutter.md)

---

## 1. The two directions

```
             set / upsert / remove / bars / bar / quote
   platform  ───────────────────────────────────────▶  chart
             ◀───────────────────────────────────────
             orderModify / orderClose / orderLevelRemove
```

Web calls methods directly. Flutter sends the same things as messages through
the WebView bridge. Same model, same rules, two transports.

## 2. The order model

Everything the chart draws comes from these two shapes:

```ts
interface Position {
  id: string;             // your ticket number
  side: 'buy' | 'sell';
  volume: number;         // lots
  entry: number;          // open price
  sl?: number | null;     // optional
  tp?: number | null;     // optional
  profit?: number | null; // from the server; omitted = the chart estimates
  editable?: boolean;     // false locks it against dragging
}

interface PendingOrder {
  id: string;
  side: 'buy' | 'sell';
  kind: 'limit' | 'stop' | 'stopLimit';
  volume: number;
  price: number;          // trigger
  sl?: number | null;
  tp?: number | null;
  editable?: boolean;
}
```

An order with no SL and no TP is fine — it draws one line. Nothing else is
required.

**Prices are plain numbers.** Times on candles are **unix seconds**, already
shifted into the display zone by `displayOffsetMinutes`. Send milliseconds and
the bars land in 1970.

## 3. What the trader can do, and what you get

| On the chart | Event | What you must do |
|---|---|---|
| Drag the SL/TP line or its ⠿ grip | `orderModify` `{ orderId, kind, from, to, order }` | call the broker, then `upsert` the updated order |
| Press **SL** / **TP** on the order's pill, then click a price | `orderModify` with `from: null` | same — it is an add |
| Press 🗑 on an SL/TP pill | `orderLevelRemove` `{ orderId, kind }` | clear that field, then `upsert` |
| Press ✕ on the order's pill | `orderClose` `{ orderId }` | close it, then `remove(orderId)` |
| Tap an order or a cluster badge | `orderFocus` `{ orderIds }` | optional — highlight the same rows in your list |
| Nobody answered in time | `orderTimeout` `{ orderId, kind }` | tell the user; the chart has already put the level back |

### The rule that catches everyone

**Every reported action needs a reply.** The chart marks the level as waiting
(dashed) and stops there. No reply means a level that sits dashed forever, and
the button looks broken.

Reply with:

- accepted → `orders.upsert(updatedOrder)` (or `orders.remove(id)` for a close)
- refused → nothing, or `orders.upsert(originalOrder)` to snap it back at once

`orders.confirmTimeoutMs` (10s by default) is the backstop: after it the chart
restores the level and fires `orderTimeout`. Set `0` to disable.

## 4. The SL/TP lifecycle, end to end

```
1. trader drags the SL from 62727 to 62796
                     │
2. chart checks the rules ──── breaks one? line turns red, drop refused
                     │          (SL above entry on a buy, inside stopLevelPoints)
                     ▼
3. level drawn dashed  +  orderModify { orderId, kind:'sl', from:62727, to:62796 }
                     │
4. your code: api.modifyOrder(...)
                     │
        ┌────────────┴────────────┐
     accepted                  refused / timeout
        │                          │
5. orders.upsert(order)      nothing (or upsert the original)
        │                          │
   line solid at 62796        line back at 62727, orderTimeout fired
```

Adding is the same flow with `from: null`. While it waits, the chart holds the
new level on screen dashed, so a placement never looks like it did nothing.

### The rules a drop must pass

Enforced by the chart before anything is reported:

- a **buy**'s SL sits below its entry, its TP above — a **sell** is the mirror
- neither may come closer to the market than `stopLevelPoints`
- the price snaps to `tickSize`, so an unplaceable price cannot be produced
- a **filled entry cannot be dragged** — the price a position opened at is
  history. A pending order's trigger can move

Breaking one paints the line red and the drop is refused; nothing reaches your
API.

## 5. Where the config lives

| Layer | Set where | Examples |
|---|---|---|
| Boot | the `ChartUI` / `mountBridge` call | symbol, interval, datafeed mode |
| Per broker | same object on web; a `config` message on mobile | colours, `contractSize`, `tickSize`, `stopLevelPoints`, `maxVisibleLabels`, `allowDrag` |
| Per user | nothing to wire — the chart stores it | text size, toolbar side, favourite intervals, saved layouts, drawings |

```js
orders: {
  enabled: true,
  allowDrag: true,          // false = a read-only chart
  allowClose: true,         // show the ✕
  showPnl: true,
  labelSide: 'right',
  clusterWithinPx: 8,       // levels closer than this share one line + badge
  maxVisibleLabels: 40,     // lower it on weak devices
  contractSize: 100000,     // units per lot — 1 for BTC. Only used when the
                            // server sends no `profit`
  tickSize: 0.00001,        // drag snaps to this
  stopLevelPoints: 0,       // broker's minimum distance from the market
  confirmTimeoutMs: 10000,
  colors: { buy, sell, sl, tp, pending, cluster, labelText,
            slBoxBg, slBoxText, tpBoxBg, tpBoxText, close, closeBg, invalid },
}
```

## 6. The instrument list

The symbol search is fed one of three ways, in this order:

```js
// 1. hand it over — the app already loaded instruments at login
new ChartUI(el, { symbols: [
  { name: 'BTCUSD', displayName: 'Bitcoin',        category: 'CRYPTO',  digits: 2 },
  { name: 'EURUSD', displayName: 'Euro / Dollar',  category: 'FOREX',   digits: 5 },
]})
ui.setSymbols(list)                        // or later, e.g. after switching account
```

```js
// 2. let the chart fetch it
datafeed: { symbolsUrl: '/api/market/symbols' }
```

```
// 3. neither → a built-in set of 12 majors, so the search is never empty
```

On mobile it is the `symbols` message.

The **tabs are derived from the data** — every distinct `category` becomes a
tab, so adding "ENERGY" to the feed adds an Energy tab with nothing to change
in the chart. Favourites are per user, stored by the chart.

The fetch is deliberately tolerant about field names — `symbol`/`name`/`ticker`,
`displayName`/`description`, `category`/`type`/`assetClass`,
`digits`/`pricePrecision` — so most back-ends work unmapped. `digits` decides
price formatting on the axis and on every order pill; leave it out and it is
guessed from the ticker (JPY → 3, metals/crypto → 2, indices → 1, else 5).

## 7. Where the data comes from

Two modes, one flag:

```js
datafeed: { mode: 'fetch', historyUrl: '/api/market/history', wsUrl: 'wss://…' }
datafeed: { mode: 'push' }   // you feed it; the chart opens nothing
```

### Scrolling back for older bars

In **fetch** mode this is automatic: scroll within 20 bars of the left edge and
the chart pulls the next 500, prepends them and holds the view still — the
screen does not jump when the page lands. It stops asking once the feed returns
nothing older, and one request is in flight at a time.

In **push** mode the chart cannot fetch, so it asks:

```js
chart.on('historyRequest', async ({ symbol, interval, before }) => {
  const older = await api.history(symbol, interval, { before });
  chart.prependCandles(older);      // no reply needed if there is nothing older
});
```

Use **push** whenever your app already holds a socket — a web app with a price
store, or any mobile shell. A second connection means a second login for the
same stream and two versions of the truth.

### Server bars

If the server builds the candles, the chart never has to: it draws what it is told, and a wrong candle can only last
until the next update. The contract is three calls (code in [web.md](web.md#server-bars-setbars-applybar-setlastprice)):

- `setBars(bars)` — the whole series, forming bar last. Same as `setCandles`, tolerant of server rows.
- `applyBar(bar)` — **upsert by `time`**. The newest bar's time replaces it in place; a newer time appends (the bar
  before it stays as last given); an older time replaces that bar (or fills a hole). Only the last candle, the price
  line and, if the price left the range, the price axis are redrawn.
- `setLastPrice({ bid, ask, price })` — the price lines and the order P&L only. It never changes a candle.

Rules that keep it exact:

1. **One basis.** History and live bars must come from the same builder: the same price (the bid the trader sees, not a
   mid), the same bucket clock. The join is by bar time; the chart does not shift prices to make them meet.
2. **`closed: true`** on the frame that ends a bar, sent *before* the first frame of the next bar. Indicators settle on
   it; the closed candle is then exactly what the server ended with.
3. **Re-read the tail every 2 s** (the last three bars, `applyBar` each) and when a bar closes. A dropped frame then
   costs at most two seconds, never a permanently wrong candle. Bars that already match cost nothing.
4. **Tag frames** with `symbol` / `interval` so a frame still in flight after a switch is dropped by the chart.
5. **One paint per frame**, however many calls arrive: coalesce on the server (about every 100 ms per symbol) to save
   bandwidth, not to save the chart.

`pushTick` stays for older integrations; it builds the candle from the tick itself, so it must not be mixed with
`applyBar` on the same chart. Mobile shells use the bridge messages `bars`, `bar` and `lastPrice`.

## 8. Shipping the build

```bash
npm run build             # dist/: bundle, stylesheet, types. No source maps
npm run build:protected   # the same, then obfuscated
TENAX_DEBUG_BUILD=1 npm run build   # with source maps, for your own debugging
```

Source maps used to be emitted always — and a source map carries the **entire
original source**. Shipping one to a broker ships the library. They are off
unless you ask for them.

`build:protected` renames every internal symbol, hides the strings and strips
the comments:

| | plain | protected |
|---|---|---|
| UMD | 368 KB | 688 KB |
| gzip | ~106 KB | ~190 KB |

Read it for what it is: **obfuscation, not encryption.** A browser has to
execute the code, so it can always be recovered — this turns "open the file"
into "spend days on it". Anything that must actually stay secret — keys, the
rules that decide money — belongs on your server, not in a bundle. The public
API keeps its names on purpose, or your own code could not call it.

The transforms that would slow a chart repainting every frame (control-flow
flattening, dead-code injection) are deliberately off. Verified: the obfuscated
UMD boots from a plain script tag, loads 500 candles and draws orders with SL
and TP.

### What to do about `dist/types`

The `.d.ts` files are what make a wrong config key fail at compile time instead
of at runtime, and what gives the editor its autocomplete. They carry **no
implementation** — only signatures.

They do, however, list class members, **including the private ones**
(`private zoomPending`, `private ordersInteraction`, …). Obfuscation renames
those in the bundle; the types name them again. So:

- **Your own apps** (the Vue client, the mobile shell) — ship the types. Catching
  `contractSize` misspelled before it reaches a trader is worth far more than
  hiding a member name.
- **A third party you are only handing a bundle to** — leave `types/` out. The
  library still works; they just lose autocomplete.

Declaration maps are not shipped either way: they point at `src/*.ts`, which is
never in the package, so they would only spell out the file layout.

## 9. Many orders on one symbol

A busy account is the case that breaks naive drawing: 200 positions is ~600
levels, and as price lines that floods the axis and stalls the frame.

The chart draws them in one canvas pass, and:

- levels within `clusterWithinPx` share **one line and one badge** — `20 orders`
- labels keep a full pill height between them, nearest the market first
- past `maxVisibleLabels`, the rest keep their lines — nothing is dropped
  silently
- tapping a badge isolates those orders; Escape brings the book back

Measured: 620 levels rebuild in **0.6 ms**.
