/**
 * TRADYN - TradingView Datafeed
 * Recovered from APK decompilation
 *
 * Connects TradingView charting library to the Tradyn trade socket.
 * Endpoint: https://trade-socket.tradyn.com/charthistory
 */

import { fetchParticularSymbolRecord, getSessionToken } from "./utils";

export const supportedResolutions = [
  "1", "3", "5", "15", "30", "60", "1D", "1W",
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Convert a TV resolution string to milliseconds */
function resolutionToMs(resolution) {
  if (resolution === "1W" || resolution === "W") return 7 * 24 * 60 * 60 * 1000;
  if (resolution === "1D" || resolution === "D") return 24 * 60 * 60 * 1000;
  const minutes =
    resolution === "1"  ? 1  :
    resolution === "3"  ? 3  :
    resolution === "5"  ? 5  :
    resolution === "15" ? 15 :
    resolution === "30" ? 30 :
    resolution === "60" ? 60 :
    parseInt(resolution) || 1;
  return minutes * 60 * 1000;
}

// ---------------------------------------------------------------------------
// Streaming (tick → bar update)
// ---------------------------------------------------------------------------

let currentSymbol = "";
let socket = null;

/** Map of `${symbol}_${resolution}` → { subscriberUID, resolution, lastDailyBar, handlers[] } */
const subscriberMap = new Map();

function onTick(tick) {
  if (!currentSymbol || currentSymbol !== tick.symbol) return;

  const tickTimeMs = parseInt(tick.time, 10) * 1000;
  const bid = parseFloat(tick.bid);
  const ask = parseFloat(tick.ask);

  if (isNaN(bid) || isNaN(ask) || !isFinite(bid) || !isFinite(ask)) {
    console.warn("[Streaming] Invalid bid/ask data:", tick);
    return;
  }

  const mid = (bid + ask) / 2;

  for (const [key, sub] of subscriberMap.entries()) {
    if (!key.startsWith(tick.symbol + "_")) continue;

    const { resolution, lastDailyBar, handlers } = sub;
    if (!lastDailyBar?.time) continue;

    let newBar;
    let isNewBar = false;
    let barTime;

    if (resolution === "1W" || resolution === "W") {
      const getMondayUTC = (ts) => {
        const d = new Date(ts);
        const day = d.getUTCDay();
        const diff = day === 0 ? 6 : day - 1;
        d.setUTCDate(d.getUTCDate() - diff);
        d.setUTCHours(0, 0, 0, 0);
        return d.getTime();
      };
      barTime = getMondayUTC(tickTimeMs);
      isNewBar = barTime > lastDailyBar.time;
    } else if (resolution === "1D" || resolution === "D") {
      const getDayUTC = (ts) => {
        const d = new Date(ts);
        d.setUTCHours(0, 0, 0, 0);
        return d.getTime();
      };
      barTime = getDayUTC(tickTimeMs);
      isNewBar = barTime > lastDailyBar.time;
    } else {
      const ms = resolutionToMs(resolution);
      barTime = Math.floor(tickTimeMs / ms) * ms;
      isNewBar = tickTimeMs >= lastDailyBar.time + ms;
    }

    newBar = isNewBar
      ? { time: barTime, open: mid, high: mid, low: mid, close: mid }
      : {
          ...lastDailyBar,
          high: Math.max(lastDailyBar.high, mid),
          low:  Math.min(lastDailyBar.low,  mid),
          close: mid,
        };

    sub.lastDailyBar = newBar;
    handlers.forEach((h) => h.callback(newBar));
  }
}

// ---------------------------------------------------------------------------
// Caches
// ---------------------------------------------------------------------------

/** Cache of `${symbol}_${resolution}` → latest OHLC bar */
const lastBarCache = new Map();
/** Cache of barsHistory keyed by request fingerprint */
const barsCache = new Map();
/** Map of subscriberUID → unsubscribe fn */
const pendingUnsubs = new Map();

export function clearChartCaches() {
  lastBarCache.clear();
  barsCache.clear();
  pendingUnsubs.forEach((fn) => fn());
  pendingUnsubs.clear();
}

// ---------------------------------------------------------------------------
// Datafeed class
// ---------------------------------------------------------------------------

const HTTP_BASE_URL = "https://trade-socket.tradyn.com";

const configurationData = {
  supported_resolutions: supportedResolutions,
  supports_time: true,
  supports_marks: true,
  showCountdown: true,
  exchanges: [{ value: "", name: "All Exchanges", desc: "" }],
};

export default class TradynDatafeed {
  symbols = { data: [], symObj: {} };
  socket = null;
  server = "";

  constructor(symbols, socketInstance, server) {
    this.symbols = symbols;
    this.socket  = socketInstance;
    this.server  = server;
  }

  updateSymbols(symbols) {
    this.symbols = symbols;
  }

  // ---- TradingView Datafeed API ------------------------------------------

  onReady(callback) {
    setTimeout(() => callback(configurationData));
  }

  async getServerTime(callback) {
    if (this.socket?.connected) {
      let resolved = false;
      const handler = (res) => {
        if (resolved) return;
        resolved = true;
        this.socket.off("servertime-response", handler);
        callback(res?.time ? parseInt(res.time) : Math.floor(Date.now() / 1000));
      };
      this.socket.on("servertime-response", handler);
      this.socket.emit("get-servertime", {});
      setTimeout(() => {
        if (!resolved) {
          resolved = true;
          this.socket.off("servertime-response", handler);
          callback(Math.floor(Date.now() / 1000));
        }
      }, 5000);
    } else {
      callback(Math.floor(Date.now() / 1000));
    }
  }

  async searchSymbols(userInput, exchange, symbolType, onResult) {
    const q = userInput.toLowerCase();
    onResult(
      this.symbols.data.filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.description.toLowerCase().includes(q)
      )
    );
  }

  /** Convert trade_sessions array → TradingView session string */
  formatTradingViewSession(tradeSessions) {
    if (!tradeSessions || tradeSessions.length === 0) return "24x7";

    const dayIndex = {
      sunday: 1, monday: 2, tuesday: 3,
      wednesday: 4, thursday: 5, friday: 6, saturday: 7,
    };

    const sessionMap = new Map();

    for (const entry of tradeSessions) {
      const dayNum = dayIndex[entry.day.toLowerCase()];
      if (!dayNum || !entry.sessions?.length) continue;

      const sorted = [...entry.sessions].sort(
        (a, b) =>
          parseInt(a.open.replace(":", "")) - parseInt(b.open.replace(":", ""))
      );

      for (const sess of sorted) {
        const open  = sess.open.replace(":", "");
        const close = sess.close.replace(":", "");
        const key   = `${open}-${close}`;
        if (!sessionMap.has(key)) sessionMap.set(key, []);
        sessionMap.get(key).push(dayNum);
      }
    }

    if (sessionMap.size === 0) return "24x7";

    const parts = [];
    for (const [timeRange, days] of sessionMap) {
      const openTime = parseInt(timeRange.split("-")[0]);
      parts.push({ timeRange, days: days.sort((a, b) => a - b).join(""), openTime });
    }
    parts.sort((a, b) => a.openTime - b.openTime);
    return parts.map((p) => `${p.timeRange}:${p.days}`).join("|");
  }

  async resolveSymbol(symbolName, onSymbolResolvedCallback, onResolveErrorCallback) {
    const sym = fetchParticularSymbolRecord(this.symbols, symbolName);
    if (!sym) return onResolveErrorCallback("Cannot resolve symbol");

    const session = this.formatTradingViewSession(sym.trade_sessions);

    const symbolInfo = {
      ticker:                  sym.symbol,
      name:                    sym.symbol,
      description:             sym.description,
      type:                    sym.type,
      session,
      timezone:                "Etc/UTC",
      minmov:                  1,
      pointvalue:              1,
      pricescale:              Math.round(1 / sym.point),
      has_intraday:            true,
      visible_plots_set:       "ohlc",
      has_weekly_and_monthly:  true,
      supported_resolutions:   configurationData.supported_resolutions,
      volume_precision:        2,
      showCountdown:           configurationData.showCountdown,
      supports_time:           configurationData.supports_time,
      supports_marks:          configurationData.supports_marks,
      data_status:             "streaming",
    };

    this.getServerTime(() => {
      setTimeout(() => onSymbolResolvedCallback(symbolInfo), 0);
    });
  }

  async getBars(symbolInfo, resolution, periodParams, onHistoryCallback, onErrorCallback) {
    const { to, from, countBack, firstDataRequest } = periodParams;
    const cacheKey  = `${symbolInfo.name}_${resolution}_${from}_${to}`;
    const now       = Date.now();

    // Return cached data for non-first requests (cache valid 5 min)
    if (!firstDataRequest) {
      const cached = barsCache.get(cacheKey);
      if (cached && now - cached.timestamp < 300_000) {
        return onHistoryCallback(cached.bars, { noData: cached.bars.length === 0 });
      }
    }

    try {
      const token    = await getSessionToken();
      const response = await fetch(`${HTTP_BASE_URL}/charthistory`, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization:  `Bearer ${token}`,
        },
        body: JSON.stringify({
          symbol:     symbolInfo.name,
          from,
          to,
          resolution,
          count: countBack,
        }),
      });

      if (!response.ok) console.log(`HTTP error: ${response.status}`);

      const json = await response.json();
      const raw  = json?.data ?? [];

      if (raw.length === 0) {
        barsCache.set(cacheKey, { bars: [], timestamp: now });
        return onHistoryCallback([], { noData: true });
      }

      const bars = raw.map((b) => ({
        time:  b.time * 1000,
        low:   b.low,
        high:  b.high,
        open:  b.open,
        close: b.close,
      }));

      barsCache.set(cacheKey, { bars, timestamp: now });

      if (firstDataRequest && bars.length > 0) {
        const barKey = `${symbolInfo.name}_${resolution}`;
        lastBarCache.set(barKey, { ...bars[bars.length - 1] });
      }

      onHistoryCallback(bars, { noData: false });
    } catch (err) {
      console.error("[Datafeed] getBars error:", err);
      onErrorCallback(err);
    }
  }

  subscribeBars(symbolInfo, resolution, onRealtimeCallback, subscriberUID, onResetCacheNeededCallback) {
    const barKey = `${symbolInfo.name}_${resolution}`;
    const subKey = barKey;
    const lastBar = lastBarCache.get(barKey) ?? null;

    pendingUnsubs.set(subscriberUID, onResetCacheNeededCallback);

    // Attach tick listener
    socket = this.socket;
    socket?.off("tick", onTick);
    socket?.on("tick", onTick);

    currentSymbol = symbolInfo.name;

    const handler = { id: subscriberUID, callback: onRealtimeCallback };
    const existing = subscriberMap.get(subKey);
    if (existing) {
      existing.handlers.push(handler);
    } else {
      subscriberMap.set(subKey, {
        subscriberUID,
        resolution,
        lastDailyBar: lastBar,
        handlers: [handler],
      });
    }
  }

  unsubscribeBars(subscriberUID) {
    pendingUnsubs.delete(subscriberUID);

    for (const [key, sub] of subscriberMap.entries()) {
      const idx = sub.handlers.findIndex((h) => h.id === subscriberUID);
      if (idx !== -1) {
        sub.handlers.splice(idx, 1);
        if (sub.handlers.length === 0) subscriberMap.delete(key);
        break;
      }
    }
  }
}
