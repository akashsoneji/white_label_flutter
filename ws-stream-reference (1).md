# /ws/stream — single socket reference for crmapp (Flutter)

Source of truth:
- Web client: `crmfronend/src/services/tradingWebSocket.service.js`
  - mode flag `_isStreamMode()` ~:975 (env `VITE_WS_STREAM_ENABLED` > config `webSocketStreamEnabled`)
  - `connectToStream()` :1168, `onmessage` :1227, `handleStreamTaggedMessage()` :1323
  - `requestStreamData()` (auth) :1437, `_flushStreamSymbolsSubscribe()` :1497
  - `refreshPositions()` / `refreshPendingOrders()` :1976 / :2000 (chunk_request)
  - `switchAccount()` stream branch ~:1541 (close + reopen socket)
- Engine: `crmtradeenginev3-04-may/src/services/websocket/selfHostedMessageRouter.ts`
  - protocol comment :116-127, inline auth :132-151, `handleStreamMessage` ~:1209, price snapshot ~:1406

## Why
Today the app opens separate sockets (`/ws/op`, `/ws/po`, `/ws/account`, `/ws/marketwatch`).
`/ws/stream` carries all of them on ONE socket: 1 TLS + 1 auth handshake instead of 4,
1 reconnect loop, 1 heartbeat. It does NOT make ticks faster — it cuts connect/reconnect cost and server load.

Do not confuse it with `lib/services/engine_socket_v2.dart`. That is the TenaxCore v2 protocol
(`{t:'auth', token, v:2}`, frames `[tag, payload, seq]`, tags `hello/snap/pu/pa/...`). `/ws/stream` is the
existing crmtradeenginev3 protocol: the auth message is the same as legacy, frames are `[tag, payload]` (2 elements).

## 1. Connect
```
wss://<engine-host>/ws/stream
```
- Same base URL as `/ws/op`.
- The server sends binary (msgpack) for data and JSON text for control messages. The app already has
  `MessagePackDecoder.decodeBinary` — handle both `String` and `List<int>` frames (as in `engine_socket_v2.dart:_onFrame`).

## 2. Auth — one round trip (send on `open`)
```json
{
  "type": "authenticate",
  "authID": "<same websocket token used for /ws/op>",
  "trading_account": "<login as string>",
  "channels": ["positions", "orders", "accounts", "prices"],
  "symbols": ["EURUSD", "XAUUSD", "..."]
}
```
- `channels` + `symbols` inline = the engine runs auth, then `stream_subscribe`, then symbol subscribe itself
  (`selfHostedMessageRouter.ts:137-150`). No need to wait for `authenticated` before subscribing.
- Web also re-sends the same auth after 150 ms as a safety retry (`:1213`). Optional.

Old-style multi-step (still supported, fallback only):
1. `{type:'authenticate', authID, trading_account}`
2. `{type:'stream_subscribe', channels:[...]}`
3. `{action:'subscribe', symbols:[...]}`

## 3. Inbound — control (JSON text)
- `{type:'authenticated'}` → flush any symbols queued while auth was in flight.
- `{type:'stream_subscribed', channels}` → info only.
- `{type:'pong'}` → heartbeat reply; mark socket alive.
- `{type:'error'}` → log only.
- `{type:'symbols.changed'}` → clear the symbol-details cache and refetch.
- `{type:'group_changed'}` → close the socket and reconnect fresh after ~500 ms (web does disconnect → connect).

## 4. Inbound — data (msgpack `[tag, payload]`)
- `'p'` → market-watch prices. Payload is one row `[symbol, bid, ask, ...]` OR a list of rows. Normalize: if
  `payload[0] is String` wrap it as `[payload]`. Same row shape as `/ws/marketwatch` → feed the existing
  market-watch parser.
- `'pos'` → positions. Same arrays as `/ws/op`:
  - `payload[0] == 'r'` → single removal
  - `payload[0] is List` → batch (if `payload[0][0] == 'r'` it is a removal batch, else a snapshot/delta chunk)
  - otherwise → single position array update
- `'po'` → pending orders. Same rules as `'pos'` (`'r'` = removal, list = batch, else single).
- `'ac'` → account tuple, same shape as `/ws/account` / account-in-`/ws/op`.

Reuse the existing `/ws/op`, `/ws/po`, `/ws/account` and `/ws/marketwatch` parsers. Only the demux
by tag is new. Controllers (`TradingController`, `InstrumentsController`) do not need to change.

## 5. Outbound after connect
- Add symbols: `{action:'subscribe', symbols:[...]}`
- Remove symbols: `{action:'unsubscribe', symbols:[...]}`
- Re-pull positions: `{type:'chunk_request', data_type:'positions', offset:0, limit:100}`
- Re-pull orders: `{type:'chunk_request', data_type:'orders', offset:0, limit:100}`
- Re-pull accounts: `{type:'chunk_request', data_type:'accounts', offset:0, limit:100}`
- Tear down but keep the socket: `{type:'unsubscribe'}`
- Trade requests stay on the REST API as now.

## 6. Account switch — watchlist refresh + socket reconnect

Web flow (order matters):

Store side — `tradingStore.js` setActiveAccount (~:220-291)
1. Bump `_accountSwitchSeq`. Every async step below checks it and aborts if a newer switch has started
   (user taps A → B → C fast, so only C may apply).
2. `await mt5Service.setPrimaryAccount(account)` FIRST. The backend `/trade/marketwatch` is keyed on the primary
   account; fire-and-forget gave an empty watchlist until hard refresh (:235-244).
3. Set `activeAccount`, clear positions / orders / history / account info.
4. Market watch: show the cached snapshot `_marketWatchByAccount[newAccount]` right away (no blank list).
   Do NOT empty the `symbols` / `marketWatch` arrays — WS prices and the REST reload would race to refill them
   and rows show blank names / "--" (:256-266). Only reset the loaded flags.
5. Reload for the new account, with short retries guarded by the switch seq (:277-291):
   - `forceRefreshSymbols()` → instrument list of the new account's group (2 tries, 200 ms)
   - `forceRefreshMarketWatch()` → `/trade/marketwatch` (3 tries, 300 ms)

Socket side — `useTradingData.js:190-212` watcher on `activeAccount` → `tradingWebSocketService.switchAccount()` (:1514)
6. Send `{type:'unsubscribe', trading_account: old}` on the stream socket.
7. Reset per-account WS state: chunk offsets, initial-load flags, pending + active symbol sets,
   market-watch join flags. Symbols from the old account must NOT carry over.
8. Stream mode: `disconnect()` + `connect({accountNumber: new})` — a fresh socket (see the engine bug below).
9. The new auth carries `symbols` = favorites filtered for the NEW account (below), so prices start in one round trip.

Which symbols to subscribe — `favoritesForActiveAccount()` (`tradingStore.js:1062`)
- Favorites are per USER (backend + localStorage `favoriteSymbols`). The instrument list is per ACCOUNT (MT5 group).
- Subscribe only `favorites ∩ new account's symbols`. Keep the master favorites list unchanged, so a symbol hidden
  on a group without it comes back on an account whose group has it.
- If the symbol list is not loaded yet, send all favorites (nothing to filter against).
- Always add the chart's selected symbol even if it is not a favorite, otherwise the order panel shows "--"
  (`syncMarketWatchV2Subscriptions()` :1091).
- Normalize symbol keys (`normalizeSymbolKey`: upper-case, no datafeed suffix) before compare / subscribe.
- If the engine replies `{type:'error', code:'SYMBOL_NOT_AVAILABLE', symbol}`, remove that row for the
  active account only and update the per-account cache (`_onSymbolUnavailable()` :1077).

Favorite add/remove while connected (`toggleFavorite()` :1114)
- Remove → `{action:'unsubscribe', symbols:[key]}`; add → `{action:'subscribe', symbols:[key]}`.
- Save to localStorage + `tradeService.updateMarketWatch(symbols)` (the backend is the source of truth).

App mapping (Dart)
- Keep `Map<String accountNo, List<MarketWatchRow>>` as a snapshot cache; show it first on switch.
- `int _switchSeq` in the controller; check it after every `await`.
- Order: setPrimaryAccount → load symbols → load market watch → reconnect the stream with the filtered symbols.
  The socket can reconnect in parallel with the REST loads, but the auth `symbols` must use the NEW account's filter.

### Engine bug: reconnect, do not re-auth
The engine bug is still open: re-authing on the same `/ws/stream` socket keeps the old account's price
binding and symbol group, so market watch shows the old account's prices. Web fix (crmfronend 08ed1812 / main dd03e263):
- On switch: close the socket, open a new one, auth with the new `trading_account`.
- In `onDone`/`onclose`, ignore a close event from the old socket (web: `event.target !== this.streamWs`).
  In Dart, capture the channel in the listener closure and return early if `channel != _channel`.
  Otherwise the old socket's close marks the new one as disconnected and starts a duplicate reconnect.

## 7. Reconnect + heartbeat
- One backoff loop only (the existing 500 ms → 30 s pattern in `engine_socket_v2.dart` is fine).
- On every reconnect, send the full auth again with `channels` + current `symbols` (the server keeps no state).
- Keep the existing heartbeat. Treat ~60 s with no frames as dead during market hours (web `staleThresholdMs`).
- Mark alive on EVERY frame (prices flow constantly), not only on `pong`.

## 8. Rollout
- Gate behind a client config flag (mirror the web `webSocketStreamEnabled`), default off.
- Rollback = flag off; the legacy 4 endpoints stay live on the engine.
- Test MT5 and self-hosted accounts: positions, pending orders, account, market watch, account switch
  across groups, app background → foreground reconnect.
