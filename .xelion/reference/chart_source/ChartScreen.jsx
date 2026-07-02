/**
 * TRADYN - Chart Screen Component
 * Recovered from APK decompilation
 *
 * Full TradingView chart screen with:
 * - TradingView widget initialization
 * - Bid/ask horizontal lines
 * - Position lines (open trades)
 * - Order lines (pending orders)
 * - Buy/Sell quick-trade panel
 * - Dark/light theme support
 * - Multi-language support
 * - Socket.IO live tick streaming
 */

import React, {
  useState, useEffect, useRef, useCallback, useMemo
} from "react";
import TradynDatafeed, { clearChartCaches } from "./Datafeed";
import { Haptics } from "@capacitor/haptics";
import { NotificationType } from "@capacitor/haptics";
import {
  fetchParticularSymbolRecord,
  isMarketOpen,
  getTimeUntilMarketOpens,
} from "./utils";

// ─── Constants ──────────────────────────────────────────────────────────────

const POSITION_ACTIONS = { 0: "Buy", 1: "Sell" };
const ORDER_TYPES      = { 0: "Buy", 1: "Sell", 2: "Buy Limit", 3: "Sell Limit", 4: "Buy Stop", 5: "Sell Stop" };
const RETURN_CODES     = {
  10009: "Order placed",
  10002: "Order filled",
  10003: "Order cancelled",
  10008: "Order modified",
};

const LANG_TV_MAP = {
  en: "en", ar: "ar", ch: "zh", es: "es",
  hi: "en", fr: "fr", id: "id_ID", de: "de",
  th: "th", ms: "ms_MY", ja: "ja", ko: "ko",
  tr: "tr", ru: "ru",
};

// ─── ChartScreen ────────────────────────────────────────────────────────────

export default function ChartScreen({
  visible        = true,
  symbol,           // current symbol object  { symbol, volume_min, volume_max, volume_step, ... }
  symbols,          // full symbol list        { data: [], symObj: {} }
  socket,           // socket.io instance
  user,             // { login, trading }
  positions,        // { data: {}, posObj: {} }
  orders,           // { data: {}, ordersObj: {} }
  ticks,            // { data: { [symbol]: { bid, ask, time, dailyChangeP, ... } } }
  isDark,           // boolean
  language,         // "en" | "ar" | ...
  theme,            // { colorPrimary, colorError, colorBackground, colorText, colorSuccess, colorBackgroundPrimary }
  clientId,         // string
  server,           // string
  onNotification,   // fn({ title, content, visible, icon })
  platform,         // "android" | "ios"
}) {

  // ── Widget ref ────────────────────────────────────────────────────────────
  const [widget, setWidget]           = useState(null);
  const [widgetReady, setWidgetReady] = useState(false);
  const datafeedRef                   = useRef(null);
  const tickHandlerRef                = useRef(null);

  // ── UI state ──────────────────────────────────────────────────────────────
  const [isConnected, setIsConnected] = useState(false);
  const [tradeOpen, setTradeOpen]     = useState(false);
  const [volume, setVolume]           = useState(symbol?.volume_min ?? 0.01);
  const [isBuying, setIsBuying]       = useState({ buy: false, sell: false });
  const tradeButtonRef                = useRef(null);

  // ── Bid / Ask lines ───────────────────────────────────────────────────────
  const bidLineRef  = useRef(null);
  const askLineRef  = useRef(null);
  const showBidAsk  = true; // toggle as needed

  // ── Position / Order lines ────────────────────────────────────────────────
  const [positionLines, setPositionLines] = useState([]);
  const [orderLines,    setOrderLines]    = useState([]);
  const showPositions  = true;
  const showOrders     = true;
  const clearLines     = useRef(false);

  // ── Market closed countdown ───────────────────────────────────────────────
  const resolutionRef           = useRef("1");
  const closedSinceRef          = useRef(Math.floor(Date.now() / 1000));
  const [closedSeconds, setClosedSeconds] = useState(0);

  const symbolRecord = fetchParticularSymbolRecord(symbols, symbol?.symbol);
  const marketOpen   = isMarketOpen(symbolRecord?.trade_sessions, resolutionRef.current);

  useEffect(() => {
    if (marketOpen) return;
    const id = setInterval(() => {
      setClosedSeconds(Math.floor(Date.now() / 1000) - closedSinceRef.current);
    }, 1000);
    return () => clearInterval(id);
  }, [marketOpen]);

  const timeUntilOpen = useMemo(
    () => marketOpen
      ? null
      : getTimeUntilMarketOpens(symbolRecord?.trade_sessions, resolutionRef.current + closedSeconds),
    [marketOpen, symbolRecord?.trade_sessions, resolutionRef.current, closedSeconds]
  );

  // ── Haptic helpers ────────────────────────────────────────────────────────
  const vibrateError   = useCallback(async () => { await Haptics.vibrate(); }, []);
  const vibrateSuccess = useCallback(async () => {
    await Haptics.notification({ type: NotificationType.Success });
  }, []);

  // ── Connection tracking ───────────────────────────────────────────────────
  useEffect(() => {
    if (!socket) return setIsConnected(false);
    setIsConnected(socket.connected);
    const onConnect    = () => setIsConnected(true);
    const onDisconnect = () => setIsConnected(false);
    socket.on("connect",    onConnect);
    socket.on("disconnect", onDisconnect);
    return () => {
      socket.off("connect",    onConnect);
      socket.off("disconnect", onDisconnect);
    };
  }, [socket]);

  // ── Reset chart data on API reconnect ────────────────────────────────────
  useEffect(() => {
    if (!socket || !widgetReady) return;
    const handler = () => {
      console.log("[Chart] API reconnected - resetting chart data");
      clearChartCaches();
      try { widget?.activeChart()?.resetData(); }
      catch (e) { console.error("[Chart] Error resetting chart data:", e); }
    };
    socket.on("api-reconnected", handler);
    return () => socket.off("api-reconnected", handler);
  }, [socket, widget, widgetReady]);

  // ── Update datafeed when symbol list changes ──────────────────────────────
  useEffect(() => {
    if (datafeedRef.current && symbols) {
      datafeedRef.current.updateSymbols(symbols);
    }
  }, [symbols]);

  // ── Update theme ──────────────────────────────────────────────────────────
  useEffect(() => {
    if (widgetReady && widget?._iFrame?.contentWindow) {
      widget.changeTheme(isDark ? "dark" : "light");
    }
  }, [isDark, widget, widgetReady]);

  // ── Update trade button colour on theme change ────────────────────────────
  useEffect(() => {
    if (tradeButtonRef.current) {
      tradeButtonRef.current.style.color = theme?.colorText;
    }
  }, [theme?.colorText]);

  // ── Reset volume when symbol changes ─────────────────────────────────────
  useEffect(() => {
    setVolume(symbol?.volume_min ?? 0.01);
  }, [symbol]);

  // ─────────────────────────────────────────────────────────────────────────
  // Bid / Ask line renderer
  // ─────────────────────────────────────────────────────────────────────────
  const updateBidAskLines = useCallback((tick, tvWidget) => {
    if (!tvWidget?._iFrame?.contentWindow) return;
    try {
      if (tick?.symbol !== tvWidget?.symbolInterval()?.symbol?.split(":")[1]) return;
    } catch { return; }

    const chart = tvWidget.activeChart();
    const bid   = parseFloat(tick.bid);
    const ask   = parseFloat(tick.ask);
    const time  = tick.time;

    if (isNaN(bid) || isNaN(ask) || !time) return;

    try {
      if (bidLineRef.current) { chart.removeEntity(bidLineRef.current); bidLineRef.current = null; }
      if (askLineRef.current) { chart.removeEntity(askLineRef.current); askLineRef.current = null; }
      if (!showBidAsk) return;

      bidLineRef.current = chart.createShape(
        { price: bid, time },
        {
          shape: "horizontal_line", lock: true,
          disableSelection: true, disableSave: true, disableUndo: true,
          overrides: {
            linecolor: theme?.colorPrimary, linewidth: 1, linestyle: 1,
            showLabel: true, horzLabelsAlign: "right",
            textcolor: theme?.colorPrimary,
          },
        }
      );
      askLineRef.current = chart.createShape(
        { price: ask, time },
        {
          shape: "horizontal_line", lock: true,
          disableSelection: true, disableSave: true, disableUndo: true,
          overrides: {
            linecolor: theme?.colorError, linewidth: 1, linestyle: 1,
            showLabel: true, horzLabelsAlign: "right",
            textcolor: theme?.colorError,
          },
        }
      );
    } catch (e) {
      console.error("Error updating bid/ask lines:", e);
    }
  }, [theme, showBidAsk]);

  // ─────────────────────────────────────────────────────────────────────────
  // Position lines
  // ─────────────────────────────────────────────────────────────────────────
  const renderPositionLines = (tvWidget, symbolName, show) => {
    // remove old lines
    positionLines.forEach((line) => {
      try { if (line?._line) line.remove(); } catch (e) { console.error(e); }
    });
    setPositionLines([]);

    if (!tvWidget || !show || !tvWidget?._iFrame?.contentWindow) return;
    const chart = tvWidget.activeChart();
    if (!chart) return;

    const newLines = [];
    (positions?.posObj?.[symbolName] || []).forEach((id) => {
      const pos = positions?.data?.[id];
      if (pos?.symbol !== symbolName) return;
      try {
        const line = chart
          .createPositionLine()
          .onClose(() => { /* trigger position close dialog */ })
          .setText(`Profit: ${pos.profit.toFixed(2)}`)
          .setQuantity(`${POSITION_ACTIONS[pos.action]}: ${pos.volume}`)
          .setLineColor(pos.profit >= 0 ? theme?.colorSuccess : theme?.colorError)
          .setExtendLeft(true)
          .setTooltip("Additional position information")
          .setProtectTooltip("Protect position")
          .setCloseTooltip("Close position")
          .setReverseTooltip("Reverse position")
          .setQuantityBackgroundColor(isDark ? "#00000075" : "#ffffff75")
          .setBodyBackgroundColor(isDark ? "#00000075" : "#ffffff75")
          .setCloseButtonBackgroundColor(isDark ? "#00000075" : "#ffffff75")
          .setQuantityBorderColor(pos.profit >= 0 ? theme?.colorSuccess : theme?.colorError)
          .setBodyBorderColor(pos.profit >= 0 ? theme?.colorSuccess : theme?.colorError)
          .setCloseButtonBorderColor(pos.profit >= 0 ? theme?.colorSuccess : theme?.colorError)
          .setCloseButtonIconColor(theme?.colorText)
          .setQuantityTextColor(theme?.colorText)
          .setBodyTextColor(theme?.colorText)
          .setLineStyle(0)
          .setLineLength(50)
          .setPrice(pos.open_price);
        newLines.push(line);
      } catch (e) {
        console.error("Error creating position line:", e);
      }
    });
    setPositionLines(newLines);
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Order lines
  // ─────────────────────────────────────────────────────────────────────────
  const renderOrderLines = (tvWidget, symbolName, show) => {
    orderLines.forEach((line) => {
      try { line?.remove(); } catch (e) { console.error(e); }
    });
    setOrderLines([]);

    if (!tvWidget || !show || !tvWidget?._iFrame?.contentWindow) return;
    const chart = tvWidget.activeChart();
    if (!chart) return;

    const newLines = [];
    (orders?.ordersObj?.[symbolName] || []).forEach((id) => {
      const ord = orders?.data?.[id];
      if (ord?.symbol !== symbolName) return;
      try {
        const line = chart
          .createOrderLine()
          .setCancelTooltip("Cancel order")
          .onCancel("", () => cancelOrder(ord))
          .setText("Order")
          .setQuantity(`${ORDER_TYPES[ord.type]}: ${ord.volume}`)
          .setPrice(ord.open_price)
          .setBodyBackgroundColor(isDark ? "#00000075" : "#ffffff75")
          .setCancelButtonBackgroundColor(isDark ? "#00000075" : "#ffffff75")
          .setLineStyle(0)
          .setLineLength(50);
        newLines.push(line);
      } catch (e) {
        console.error("Error creating order line:", e);
      }
    });
    setOrderLines(newLines);
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Order cancel
  // ─────────────────────────────────────────────────────────────────────────
  const cancelOrder = useCallback(async (order) => {
    if (!socket) return;
    let resolved = false;
    const handler = (res) => {
      resolved = true;
      socket.off("order-response", handler);
      if (res.result != null || res?.success) {
        vibrateSuccess();
        onNotification({
          title:   "Order cancelled",
          content: `#${order.order_id}\n${ORDER_TYPES[order.type]} ${order.volume} ${order.symbol}`,
          visible: true, icon: "success",
        });
      } else if (res.error != null) {
        vibrateError();
        onNotification({ title: `${res.error}`, visible: true, icon: "fail" });
      }
      setTimeout(() => onNotification((n) => ({ ...n, visible: false })), 2000);
    };
    socket.on("order-response", handler);
    socket.emit("order-cancel", { order_id: order.order_id });
    setTimeout(() => {
      if (!resolved) {
        socket.off("order-response", handler);
        vibrateError();
        onNotification({ title: "Request timeout", visible: true, icon: "fail" });
        setTimeout(() => onNotification((n) => ({ ...n, visible: false })), 2000);
      }
    }, 30000);
  }, [socket]);

  // ─────────────────────────────────────────────────────────────────────────
  // Place order (buy / sell)
  // ─────────────────────────────────────────────────────────────────────────
  const placeOrder = async (side) => {
    if (!socket || isBuying.buy || isBuying.sell) return;
    setIsBuying((s) => ({ ...s, [side]: true }));

    const type = side === "sell" ? 1 : 0;
    let resolved = false;

    const handler = (res) => {
      resolved = true;
      socket.off("order-response", handler);

      if (res.result != null) {
        const success = [10009, 10002, 10003, 10008].includes(res.result);
        if (success) {
          vibrateSuccess();
          onNotification({
            title:   RETURN_CODES[res.result] || "Order placed",
            content: `${ORDER_TYPES[type]} ${volume} ${symbol?.symbol} at market`,
            visible: true, icon: "success",
          });
        } else {
          vibrateError();
          onNotification({
            title: res.ticket > 0
              ? `${RETURN_CODES[res.result]} #${res.ticket}`
              : `${RETURN_CODES[res.result] || "Error"}`,
            content: "", visible: true, icon: "fail",
          });
        }
      } else if (res.error != null) {
        vibrateError();
        onNotification({ title: `${res.error}`, content: "", visible: true, icon: "fail" });
      }

      setTimeout(() => onNotification((n) => ({ ...n, visible: false })), 2000);
      setIsBuying({ buy: false, sell: false });
    };

    socket.on("order-response", handler);
    socket.emit("order-create", {
      position_id: 0,
      price:       0,
      volume:      Number(volume),
      tp:          0,
      sl:          0,
      symbol:      symbol?.symbol,
      type,
      comment:     "",
    });

    setTimeout(() => {
      if (!resolved) {
        socket.off("order-response", handler);
        setIsBuying({ buy: false, sell: false });
        vibrateError();
        onNotification({ title: "Request timeout", content: "", visible: true, icon: "fail" });
        setTimeout(() => onNotification((n) => ({ ...n, visible: false })), 2000);
      }
    }, 30000);
  };

  // ─────────────────────────────────────────────────────────────────────────
  // TradingView widget init
  // ─────────────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (
      !document.getElementById("tv_chart_container") ||
      !("TradingView" in window) ||
      !isConnected ||
      !socket ||
      !symbol
    ) return;

    setTradeOpen(false);

    // Clear container
    const container = document.getElementById("tv_chart_container");
    if (container) container.innerHTML = "";

    // Map app language → TV locale
    const locale = LANG_TV_MAP[language] ?? "ru";

    // Create datafeed
    if (!datafeedRef.current) {
      datafeedRef.current = new TradynDatafeed(symbols, socket, server);
    }

    const tvWidget = new window.TradingView.widget({
      library_path:   "charting_library/charting_library",
      fullscreen:     true,
      autosize:       true,
      symbol:         symbol?.symbol,
      container:      "tv_chart_container",
      interval:       "1",
      datafeed:       datafeedRef.current,
      timezone:       "exchange",
      theme:          isDark ? "dark" : "light",
      locale,
      loading_screen: { backgroundColor: theme?.colorBackground },
      client_id:      clientId,
      user_id:        user?.login,
      load_last_chart:           true,
      auto_save_delay:           2,
      charts_storage_url:        "https://chart-storage.tradyn.com",
      charts_storage_api_version:"1.1",
      enabled_features: [
        "show_spread_operators",
        "move_logo_to_main_pane",
        "header_resolutions",
        "hide_left_toolbar_by_default",
        "show_hide_button_in_legend",
      ],
      disabled_features: [
        "use_localstorage_for_settings",
        "edit_buttons_in_legend",
        "control_bar",
        "border_around_the_chart",
        "header_compare",
        "adaptive_logo",
        "timeframes_toolbar",
        "widget_logo",
        "header_symbol_search",
        "header_screenshot",
        "left_toolbar",
        "header_fullscreen_button",
        "hide_main_series_symbol_from_indicator_legend",
        "header_saveload",
      ],
    });

    // Add Trade button in header
    tvWidget.headerReady().then(() => {
      if (user?.trading !== false) {
        const btn = tvWidget.createButton({ align: "right" });
        btn.setAttribute("title", "Trade");
        btn.addEventListener("click", () => setTradeOpen((v) => !v));
        btn.style.color   = theme?.colorText;
        btn.style.padding = "5px 20px";
        btn.style.border  = "none";
        btn.textContent   = "Trade";
        tradeButtonRef.current = btn;
      }
    });

    // On chart ready
    tvWidget.onChartReady(() => {
      setWidget(tvWidget);
      tvWidget.changeTheme(isDark ? "dark" : "light");

      // Restore last saved chart
      tvWidget.getSavedCharts((saved) => {
        if (saved.length > 0 && saved[0].short_symbol && saved[0].short_symbol !== "undefined") {
          tvWidget.activeChart().setSymbol(saved[0].short_symbol);
          tvWidget.activeChart().setResolution(saved[0].interval);
        }
      });

      // Symbol change handler
      tvWidget.activeChart().onSymbolChanged().subscribe(null, () => {
        const newSymbolName = tvWidget.symbolInterval().symbol.split(":")[1];
        const newSymRecord  = fetchParticularSymbolRecord(symbols, newSymbolName);
        if (newSymRecord?.symbol && socket && user?.login) {
          socket.emit("symbol-subscribe", { symbol: newSymRecord.symbol });
        }
        tvWidget.activeChart().onDataLoaded().subscribe(null, () => {
          setWidgetReady(true);
        }, true);
      });

      setWidgetReady(true);

      // Attach tick handler for bid/ask lines
      const tickHandler = (tick) => updateBidAskLines(tick, tvWidget);
      if (tickHandlerRef.current) socket.off("tick", tickHandlerRef.current);
      tickHandlerRef.current = tickHandler;
      socket.on("tick", tickHandler);
    });

    // Auto-save
    tvWidget.subscribe("onAutoSaveNeeded", () => {
      tvWidget.saveChartToServer(
        () => {},
        () => console.log("Chart save error"),
        { chartName: "Unnamed", defaultChartName: "Unnamed" }
      );
    });

    return () => {
      if (tickHandlerRef.current && socket) {
        socket.off("tick", tickHandlerRef.current);
        tickHandlerRef.current = null;
      }
    };
  }, [isConnected, socket, language]);

  // ─────────────────────────────────────────────────────────────────────────
  // Sync position & order lines when data or visibility changes
  // ─────────────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (widgetReady && isConnected && widget?._iFrame?.contentWindow) {
      const sym = widget?.symbolInterval()?.symbol?.split(":")[1] || "";
      renderPositionLines(widget, sym, showPositions);
    } else if (!showPositions) {
      positionLines.forEach((l) => { try { if (l?._line) l.remove(); } catch {} });
      setPositionLines([]);
    }
  }, [positions, showPositions, widget, widgetReady]);

  useEffect(() => {
    if (widgetReady && isConnected && widget?._iFrame?.contentWindow) {
      const sym = widget?.symbolInterval()?.symbol?.split(":")[1] || "";
      renderOrderLines(widget, sym, showOrders);
    } else if (!showOrders) {
      orderLines.forEach((l) => { try { l?.remove(); } catch {} });
      setOrderLines([]);
    }
  }, [orders, showOrders, widget, widgetReady]);

  useEffect(() => {
    if (clearLines.current) {
      positionLines.forEach((l) => { try { if (l?._line) l.remove(); } catch {} });
      orderLines.forEach((l)    => { try { if (l?._line) l.remove(); } catch {} });
      setPositionLines([]);
      setOrderLines([]);
      clearLines.current = false;
    }
  }, [clearLines.current]);

  // ─────────────────────────────────────────────────────────────────────────
  // Render
  // ─────────────────────────────────────────────────────────────────────────
  return (
    <div
      className={platform === "android" ? "android" : "ios"}
      style={{
        display:       visible ? "flex" : "none",
        flexDirection: "column",
        position:      "relative",
      }}
    >
      {/* TradingView chart container */}
      <div
        id="tv_chart_container"
        style={{
          display: visible ? "flex" : "none",
          width:  "100%",
          height: "100%",
        }}
      />

      {/* Quick Buy / Sell panel (shown when Trade button pressed) */}
      {widgetReady && user?.trading !== false && tradeOpen && (
        <div
          style={{
            position:        "absolute",
            top:             100,
            left:            20,
            display:         "flex",
            gap:             8,
            zIndex:          100,
            background:      theme?.colorBackground,
            width:           "250px",
            justifyContent:  "space-between",
          }}
        >
          {/* SELL button */}
          <button
            onClick={() => { if (!isBuying.sell) placeOrder("sell"); }}
            style={{
              backgroundColor: theme?.colorError,
              color:           "#fff",
              fontWeight:      600,
              padding:         "4px 12px",
              borderRadius:    4,
              border:          "none",
              fontSize:        12,
              cursor:          isBuying.sell ? "not-allowed" : "pointer",
              opacity:         isBuying.sell ? 0.6 : 1,
            }}
          >
            Sell by market
          </button>

          {/* Volume stepper */}
          <div style={{ display: "flex", justifyContent: "center", width: "50%" }}>
            <input
              type="number"
              min={symbol?.volume_min}
              max={symbol?.volume_max}
              step={symbol?.volume_step}
              value={volume}
              onChange={(e) => {
                const val = e.target.value;
                const trimmed = val.slice(0, val.indexOf(".") + 3);
                setVolume(Number(trimmed));
              }}
              style={{
                width:      "98%",
                padding:    "2% 1%",
                background: theme?.colorBackgroundPrimary,
                color:      theme?.colorText,
                border:     "1px solid #444",
                borderRadius: 4,
                textAlign:  "center",
              }}
            />
          </div>

          {/* BUY button */}
          <button
            onClick={() => { if (!isBuying.buy) placeOrder("buy"); }}
            style={{
              backgroundColor: theme?.colorSuccess ?? "#22c55e",
              color:           "#fff",
              fontWeight:      600,
              padding:         "4px 12px",
              borderRadius:    4,
              border:          "none",
              fontSize:        12,
              cursor:          isBuying.buy ? "not-allowed" : "pointer",
              opacity:         isBuying.buy ? 0.6 : 1,
            }}
          >
            Buy by market
          </button>
        </div>
      )}

      {/* Market closed banner */}
      {!marketOpen && timeUntilOpen && (
        <div
          style={{
            position:        "absolute",
            bottom:          20,
            left:            "50%",
            transform:       "translateX(-50%)",
            background:      theme?.colorBackground,
            color:           theme?.colorText,
            padding:         "6px 16px",
            borderRadius:    8,
            fontSize:        12,
            zIndex:          200,
            border:          `1px solid ${theme?.colorError}`,
          }}
        >
          Market closed · Opens in {timeUntilOpen}
        </div>
      )}
    </div>
  );
}
