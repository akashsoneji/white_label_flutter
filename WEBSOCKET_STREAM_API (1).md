# Trade Engine — Single WebSocket Stream API (`/ws/stream`)

**Version:** 1.0
**Date:** 2026-06-10
**Audience:** Mobile app / Frontend developers
**Status:** Ready for integration (staging test pending)

Yeh document `/ws/stream` — single multiplexed WebSocket endpoint — ka complete integration guide hai. Ek hi connection pe **prices (marketwatch), positions, pending orders, accounts** sab milta hai. Data **MessagePack binary** mein aata hai (chhota + fast), control messages **JSON text** mein.

> **Legacy note:** Purane 5 endpoints (`/ws/op`, `/ws/po`, `/ws/account`, `/ws/marketwatch`, `/ws/marketwatchv2`, `/ws/symbol`) abhi bhi kaam karte hain, unchanged. Naya app `/ws/stream` use kare — 5 connections ki jagah 1.

---

## 1. Quick Start (TL;DR)

```
1. Connect:    wss://<engine-host>:<port>/ws/stream     (binaryType = 'arraybuffer')
2. Send:       { "type": "authenticate", "authID": "<token>", "trading_account": "301023" }
3. Wait for:   { "type": "authenticated", ... }
4. Send:       { "type": "stream_subscribe", "channels": ["prices","positions","orders","accounts"] }
5. Receive:    BINARY frames → msgpack.decode → [tag, payload] → demux on tag
```

**Dependency:** MessagePack decoder
- JS/React Native: `npm i @msgpack/msgpack`
- Flutter/Dart: `msgpack_dart`
- Kotlin: `org.msgpack:msgpack-core`
- Swift: `MessagePack.swift`

---

## 2. Connection

| | |
|---|---|
| URL | `wss://<engine-host>:<port>/ws/stream` |
| Protocol | WebSocket (RFC 6455) |
| Client → Server | **JSON text** (always) |
| Server → Client (control) | **JSON text** (auth ack, errors, subscribe ack) |
| Server → Client (data) | **BINARY** — MessagePack-encoded array `[tag, payload]` |

```js
const ws = new WebSocket('wss://engine.example.com:3001/ws/stream');
ws.binaryType = 'arraybuffer';   // REQUIRED for binary frames
```

---

## 3. Message Flow

```
Client                                  Server
  │                                       │
  │── WS connect ────────────────────────▶│
  │                                       │
  │── {type:'authenticate', ...} ────────▶│  (JSON text)
  │◀─ {type:'authenticated', ...} ────────│  (JSON text)
  │                                       │
  │── {type:'stream_subscribe', ...} ────▶│  (JSON text)
  │◀─ initial snapshots ──────────────────│  (BINARY: pos/po/ac)
  │◀─ {type:'stream_subscribed', ...} ────│  (JSON text)
  │                                       │
  │◀─ live prices ['p', ...] ─────────────│  (BINARY, continuous)
  │◀─ position updates ['pos', ...] ──────│  (BINARY, on change)
  │◀─ order updates ['po', ...] ──────────│  (BINARY, on change)
  │◀─ account updates ['ac', ...] ────────│  (BINARY, on change)
  │                                       │
  │── {type:'unsubscribe'} ──────────────▶│  (teardown; socket stays open)
```

---

## 4. Step 1 — Authenticate

**Send (first message after connect):**
```json
{ "type": "authenticate", "authID": "<websocket_token>", "trading_account": "301023" }
```

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | yes | `"authenticate"` |
| `authID` | string | yes | WebSocket token (Laravel se milta hai — login API response) |
| `trading_account` | string | yes | MT5/self-hosted account number |

**Success response (JSON text):**
```json
{
  "type": "authenticated",
  "status": "success",
  "message": "Authentication successful. You will receive self-hosted data for account 301023 only.",
  "user": { "id": 42, "user_slug": "john-doe" },
  "trading_account": "301023",
  "group_id": 5,
  "trading_server": "selfHosted"
}
```

**Failure response (socket closes with code 1008):**
```json
{ "type": "error", "message": "Authentication failed - invalid token" }
```

> ✅ Auth hote hi account ke **group price channel pe auto-subscribe** ho jaata hai — marketwatch pricing isi se aati hai.

---

## 5. Step 2 — Stream Subscribe

**Send:**
```json
{ "type": "stream_subscribe", "channels": ["prices", "positions", "orders", "accounts"] }
```

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | yes | `"stream_subscribe"` |
| `channels` | string[] | no | Subset of: `prices`, `positions`, `orders`, `accounts`. **Omit = all.** |

**Response (JSON text):**
```json
{
  "type": "stream_subscribed",
  "channels": ["prices", "positions", "orders", "accounts"],
  "message": "Subscribed. Real-time updates will arrive as type-tagged arrays (array[0] = channel tag)."
}
```

Subscribe hote hi **initial snapshots BINARY frames** mein aate hain:
- positions → first 100 (more via `chunk_request`)
- orders → first 100
- accounts → account snapshot

**Examples:**
```json
{ "type": "stream_subscribe" }
{ "type": "stream_subscribe", "channels": ["prices"] }
{ "type": "stream_subscribe", "channels": ["prices", "positions"] }
```

---

## 6. Step 3 — Receive Data (BINARY frames)

Har binary frame ko msgpack-decode karo. Result hamesha **2-element envelope**:

```
[tag, payload]
```

| `tag` | Channel | Payload content |
|---|---|---|
| `"p"` | Prices (marketwatch) | single price array YA batch of price arrays |
| `"pos"` | Positions | single position array YA batch (inner tag: `op`/`a`/`u`/`r`) |
| `"po"` | Pending orders | single order array YA batch (inner tag: `a`/`u`/`r`/`po`) |
| `"ac"` | Accounts | batch of account arrays (inner tag: `ac`) |
| `"sy"` | Symbols | reserved (future) |

### 6.1 Price — tag `"p"` (Marketwatch)

**Single tick:**
```js
['p', ['EURUSD', 1.08562, 1.08581, 19, 5, 1718023456789]]
```

| Index | Field | Type | Example |
|---|---|---|---|
| 0 | symbol | string | `"EURUSD"` |
| 1 | bid | number | `1.08562` |
| 2 | ask | number | `1.08581` |
| 3 | spread (points) | number | `19` |
| 4 | digits | number | `5` |
| 5 | timestamp (ms) | number | `1718023456789` |

**Batch (multiple symbols, 3ms server-side batching):**
```js
['p', [
  ['EURUSD', 1.08562, 1.08581, 19, 5, 1718023456789],
  ['XAUUSD', 2310.45, 2310.95, 50, 2, 1718023456790]
]]
```

**Detect single vs batch:** `typeof payload[0] === 'string'` → single; `Array.isArray(payload[0])` → batch.

**Frequency:** max 30 updates/sec per symbol (server throttle). Spread/digits group ke हिसाब se already adjusted — display-ready.

### 6.2 Positions — tag `"pos"`

Inner payload ka **pehla element action** batata hai:

**`'op'` — open position (initial snapshot):**
```js
['pos', ['op', 12345, '301023', 'XAUUSD', 0, 0.10, 2310.45, 2311.20, 7.50, 0, 2300.00, 2320.00, 'sh', 1718023456, 2, 100]]
```

| Index | Field | Type | Notes |
|---|---|---|---|
| 0 | action | string | `"op"` |
| 1 | position_id | number | unique |
| 2 | account | string | `"301023"` |
| 3 | symbol | string | display symbol |
| 4 | side | number | `0`=BUY, `1`=SELL |
| 5 | volume (lots) | number | `0.10` |
| 6 | open price | number | |
| 7 | current price | number | BUY→bid, SELL→ask |
| 8 | profit | number | unrealized P&L |
| 9 | swap | number | |
| 10 | SL | number | `0` = not set |
| 11 | TP | number | `0` = not set |
| 12 | server type | string | `"sh"` |
| 13 | open time | number | unix seconds |
| 14 | digits | number | price formatting |
| 15 | contract size | number | |

**`'a'` — add (naya trade khula):** same shape as `op` (action = `'a'`)
```js
['pos', ['a', 12346, '301023', 'EURUSD', 1, 0.50, 1.08560, 1.08555, 2.50, ...]]
```

**`'u'` — update (price tick pe P&L update):** same shape (action = `'u'`); index 7 = new current price, index 8 = new profit
```js
['pos', ['u', 12345, '301023', 'XAUUSD', 0, 0.10, 2310.45, 2311.80, 13.50, ...]]
```

**`'r'` — remove (position closed):**
```js
['pos', ['r', '301023', 12345]]            // single id
['pos', ['r', '301023', 12345, 12346]]     // multiple ids
```
Format: `['r', account, ...position_ids]`

**Batch:** payload can be an array of the above arrays:
```js
['pos', [ ['u', 12345, ...], ['u', 12346, ...] ]]
```

### 6.3 Pending Orders — tag `"po"`

**Order array shape (inner action `'a'`/`'u'`/`'po'`):**
```js
['po', ['a', 555, '301023', 'XAUUSD', 2, 0.10, 2300.00, 2310.45, 2290.00, 2320.00, 'sh', 1718023456, 0, 2]]
```

| Index | Field | Notes |
|---|---|---|
| 0 | action | `a`/`u`/`r`/`po` |
| 1 | order_id | |
| 2 | account | |
| 3 | symbol | |
| 4 | order type | `2`=BUY LIMIT, `3`=SELL LIMIT, `4`=BUY STOP, `5`=SELL STOP |
| 5 | volume (lots) | |
| 6 | order price | trigger price |
| 7 | current price | |
| 8 | SL | |
| 9 | TP | |
| 10 | server type | `"sh"` |
| 11 | created time | unix seconds |
| 12 | swap | |
| 13 | digits | |

**Remove:** `['po', ['r', account, order_id]]`
**Batch:** `['po', [ ['a', ...], ['u', ...] ]]`

**Initial orders bhi JSON text envelope mein aa sakte hain** (legacy compat):
```json
{ "type": "pending_orders_init", "chunk": [["a", ...], ...], "is_complete": true, "total": 3 }
```

### 6.4 Accounts — tag `"ac"`

```js
['ac', [['ac', '301023', 10000.00, 500.00, 10013.50, 231.04, 9782.46, 4334.5, 13.50, 'sh']]]
```

Inner array:

| Index | Field | Notes |
|---|---|---|
| 0 | tag | `"ac"` |
| 1 | account number | |
| 2 | balance | |
| 3 | credit | |
| 4 | equity | balance + credit + floating P&L |
| 5 | margin | |
| 6 | free margin | |
| 7 | margin level (%) | `0` = no positions |
| 8 | profit | floating P&L |
| 9 | server type | `"sh"` |

Update frequency: har price tick pe jab positions khuli hon; flat account pe on-change.

---

## 7. Marketwatch — kaise kaam karta hai

1. **Auth ke baad automatic:** aapke account ke **group ke saare active symbols** ki pricing `'p'` frames mein aati hai. Kuch extra nahi karna.
2. **Specific symbols only (optional filter):**
```json
{ "action": "subscribe", "symbols": ["EURUSD", "XAUUSD", "BTCUSD"] }
```
3. **Symbols remove:**
```json
{ "action": "unsubscribe", "symbols": ["BTCUSD"] }
```
4. **Chart / single symbol:** `'p'` frames mein se client-side filter karo (推荐) — extra subscription ki zaroorat nahi.

Pricing mein group ka **spread adjustment, digits, symbol suffix mapping** server-side already applied hai.

---

## 8. Pagination — `chunk_request`

100+ positions/orders ke liye:

```json
{ "type": "chunk_request", "data_type": "positions", "offset": 100, "limit": 100 }
{ "type": "chunk_request", "data_type": "orders",    "offset": 0,   "limit": 50 }
{ "type": "chunk_request", "data_type": "accounts",  "offset": 0,   "limit": 100 }
```

- `data_type`: `positions` | `orders` | `accounts`
- `limit` max: 500
- Response: BINARY frames (same format as snapshots)

---

## 9. Unsubscribe / Account switch

**Full teardown (socket open रहता है):**
```json
{ "type": "unsubscribe" }
```
Response:
```json
{ "type": "unsubscribed", "data_type": "all", "message": "Unsubscribed successfully. Connection remains open. You can re-authenticate with a new account." }
```

**Account switch (same socket):**
```json
{ "type": "authenticate", "authID": "<token>", "trading_account": "301024" }
```
→ purana group auto-unsubscribe, naya subscribe. **Phir se `stream_subscribe` bhejo.**

---

## 10. Errors

Sab errors JSON text mein:
```json
{ "type": "error", "message": "<description>" }
```

| Error message (substring) | Meaning | Action |
|---|---|---|
| `Authentication required` | Auth se pehle data manga | Pehle `authenticate` bhejo |
| `Authentication failed - invalid token` | Token galat/expired | Naya token lo (socket close hota hai 1008) |
| `Rate limit exceeded: N msgs/sec` | Bahut tez messages | Backoff; messages drop hue, socket open hai |
| `Authenticate first` | `stream_subscribe`/`chunk_request` bina auth | Auth karo pehle |
| `chunk_request requires data_type...` | Galat `data_type` | `positions`/`orders`/`accounts` use karo |

**Rate limit:** 30 msgs/sec per connection (client→server). Server data unlimited.

---

## 11. Reconnect strategy (recommended)

```
1. on close/error → exponential backoff: 1s, 2s, 4s, 8s... max 30s
2. on reconnect   → authenticate → stream_subscribe (poora handshake dobara)
3. snapshots dobara aayenge — local state REPLACE karo (merge nahi)
4. heartbeat: server WS-level ping bhejta hai; browser/OS pong auto karta hai.
   App-level kuch nahi bhejna. Agar 60s tak koi frame na aaye → reconnect.
```

---

## 12. Complete client example (JavaScript / React Native)

```js
import { decode } from '@msgpack/msgpack';

class TradeStream {
  constructor(url, token, account) {
    this.url = url; this.token = token; this.account = account;
    this.backoff = 1000;
    this.handlers = { prices: null, positions: null, orders: null, accounts: null };
  }

  connect() {
    this.ws = new WebSocket(this.url);
    this.ws.binaryType = 'arraybuffer';

    this.ws.onopen = () => {
      this.backoff = 1000;
      this.send({ type: 'authenticate', authID: this.token, trading_account: this.account });
    };

    this.ws.onmessage = (e) => {
      // Control (JSON text)
      if (typeof e.data === 'string') {
        const msg = JSON.parse(e.data);
        if (msg.type === 'authenticated') {
          this.send({ type: 'stream_subscribe', channels: ['prices','positions','orders','accounts'] });
        } else if (msg.type === 'error') {
          console.warn('[stream]', msg.message);
        }
        return;
      }
      // Data (BINARY msgpack)
      const [tag, payload] = decode(new Uint8Array(e.data));
      switch (tag) {
        case 'p':   this.emitPrices(payload); break;
        case 'pos': this.emitPositions(payload); break;
        case 'po':  this.emitOrders(payload); break;
        case 'ac':  this.handlers.accounts?.(payload); break;
      }
    };

    this.ws.onclose = () => this.scheduleReconnect();
    this.ws.onerror = () => { try { this.ws.close(); } catch {} };
  }

  emitPrices(p) {
    const ticks = Array.isArray(p[0]) ? p : [p];
    for (const [symbol, bid, ask, spread, digits, ts] of ticks)
      this.handlers.prices?.({ symbol, bid, ask, spread, digits, ts });
  }

  emitPositions(p) {
    const items = Array.isArray(p[0]) ? p : [p];
    for (const it of items) {
      const action = it[0];
      if (action === 'r') {
        this.handlers.positions?.({ action: 'remove', account: it[1], ids: it.slice(2) });
      } else {  // 'op' | 'a' | 'u'
        this.handlers.positions?.({
          action: action === 'u' ? 'update' : 'add',
          id: it[1], account: it[2], symbol: it[3],
          side: it[4] === 0 ? 'buy' : 'sell',
          lots: it[5], openPrice: it[6], currentPrice: it[7],
          profit: it[8], swap: it[9], sl: it[10], tp: it[11],
          openTime: it[13], digits: it[14],
        });
      }
    }
  }

  emitOrders(p) {
    const items = Array.isArray(p[0]) ? p : [p];
    for (const it of items) {
      const action = it[0];
      if (action === 'r') {
        this.handlers.orders?.({ action: 'remove', account: it[1], ids: it.slice(2) });
      } else {
        this.handlers.orders?.({
          action: action === 'u' ? 'update' : 'add',
          id: it[1], account: it[2], symbol: it[3],
          orderType: it[4], lots: it[5], orderPrice: it[6],
          currentPrice: it[7], sl: it[8], tp: it[9],
          createdAt: it[11], digits: it[13],
        });
      }
    }
  }

  send(obj) { if (this.ws?.readyState === 1) this.ws.send(JSON.stringify(obj)); }

  subscribeSymbols(symbols)   { this.send({ action: 'subscribe',   symbols }); }
  unsubscribeSymbols(symbols) { this.send({ action: 'unsubscribe', symbols }); }
  loadMorePositions(offset)   { this.send({ type: 'chunk_request', data_type: 'positions', offset, limit: 100 }); }
  teardown()                  { this.send({ type: 'unsubscribe' }); }

  switchAccount(account) {
    this.account = account;
    this.send({ type: 'unsubscribe' });
    this.send({ type: 'authenticate', authID: this.token, trading_account: account });
    // 'authenticated' ack ke baad onmessage handler dobara stream_subscribe bhejega
  }

  scheduleReconnect() {
    setTimeout(() => this.connect(), this.backoff);
    this.backoff = Math.min(this.backoff * 2, 30000);
  }
}

// ─── Usage ───
const stream = new TradeStream('wss://engine.example.com:3001/ws/stream', TOKEN, '301023');
stream.handlers.prices    = (t)  => updateMarketWatch(t);
stream.handlers.positions = (p)  => updatePositionsList(p);
stream.handlers.orders    = (o)  => updateOrdersList(o);
stream.handlers.accounts  = (a)  => updateAccountBar(a);
stream.connect();
```

---

## 13. Message cheatsheet

| Action | Client sends |
|---|---|
| Login | `{"type":"authenticate","authID":"<token>","trading_account":"301023"}` |
| Subscribe all | `{"type":"stream_subscribe"}` |
| Subscribe specific | `{"type":"stream_subscribe","channels":["prices","positions"]}` |
| Filter symbols | `{"action":"subscribe","symbols":["EURUSD","XAUUSD"]}` |
| Remove symbols | `{"action":"unsubscribe","symbols":["EURUSD"]}` |
| More positions | `{"type":"chunk_request","data_type":"positions","offset":100,"limit":100}` |
| More orders | `{"type":"chunk_request","data_type":"orders","offset":50,"limit":50}` |
| Teardown | `{"type":"unsubscribe"}` |
| Switch account | re-`authenticate` + re-`stream_subscribe` |

| Server sends (binary) | Meaning |
|---|---|
| `['p', tick \| ticks[]]` | Price / marketwatch |
| `['pos', item \| items[]]` | Position (`op`/`a`/`u`/`r` inner) |
| `['po', item \| items[]]` | Pending order (`a`/`u`/`r` inner) |
| `['ac', accounts[]]` | Account metrics |

| Server sends (JSON text) | Meaning |
|---|---|
| `{type:'authenticated'}` | Auth OK |
| `{type:'stream_subscribed'}` | Subscribe OK |
| `{type:'unsubscribed'}` | Teardown OK |
| `{type:'pending_orders_init'}` | Initial orders envelope |
| `{type:'error'}` | Error |

---

## 14. Legacy endpoints (reference only — naye app mein use mat karo)

| Path | Data | Auth message |
|---|---|---|
| `/ws/op` | positions | `{"authID":"...","trading_account":"..."}` |
| `/ws/po` | pending orders | same |
| `/ws/account` | accounts | same |
| `/ws/marketwatch` | all group prices | same (or `{"authid":"...","number":"..."}`) |
| `/ws/marketwatchv2` | chosen symbols | auth + `{"action":"subscribe","symbols":[...]}` |
| `/ws/symbol` | one symbol | `{"authID":"...","trading_account":"...","symbol":"XAUUSD"}` |

Legacy frames JSON text by default; format identical to the **inner payloads** documented above (बिना envelope). Isliye purana parser code reuse ho sakta hai — bas envelope unwrap karna add karo.

---

## 15. FAQ

**Q: JSON mode chahiye debugging ke liye?**
A: Abhi stream default binary hai. Debug ke liye msgpack decode karke `console.log` karo — ya legacy endpoint pe JSON dekh lo (same inner format).

**Q: Price kitni fast aati hai?**
A: Max 30 updates/sec per symbol (server throttle), 3ms batching. Mobile ke liye UI-side bhi throttle karo (e.g. 10fps render).

**Q: Connection drop pe kya hota hai?**
A: Reconnect → re-auth → re-subscribe → fresh snapshots. Local state REPLACE karo.

**Q: Ek socket pe multiple accounts?**
A: Nahi — ek socket ek account. Switch karna ho to re-authenticate (section 9).

**Q: Trade place karna isi socket se?**
A: Nahi — trades REST API se hote hain. Yeh socket sirf real-time data ke liye hai. Trade hone ke baad uska update isi socket pe `pos`/`po`/`ac` mein aayega.

---

*Engine repo: `crmtradeenginev3-04-may` • Implementation: `src/services/websocket/selfHostedMessageRouter.ts` (`handleStreamMessage`), `src/utils/messagePackEncoder.ts` (`sendChanneled`) • Test: `tests/integration/wsStreamSmoke.js`*
