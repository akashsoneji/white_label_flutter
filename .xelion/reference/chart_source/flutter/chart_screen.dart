// ============================================================
// TRADYN - ChartScreen (Flutter / Dart)
// Converted from ChartScreen.jsx
//
// Dependencies (add to pubspec.yaml):
//   webview_flutter: ^4.7.0
//   socket_io_client: ^2.0.3+1
//   vibration: ^1.9.0
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// ─── Models ────────────────────────────────────────────────────────────────

class SymbolInfo {
  final String symbol;
  final double volumeMin;
  final double volumeMax;
  final double volumeStep;
  final double point;
  final String? description;
  final List<TradeSession> tradeSessions;

  const SymbolInfo({
    required this.symbol,
    this.volumeMin = 0.01,
    this.volumeMax = 100.0,
    this.volumeStep = 0.01,
    this.point = 0.00001,
    this.description,
    this.tradeSessions = const [],
  });

  factory SymbolInfo.fromJson(Map<String, dynamic> j) => SymbolInfo(
        symbol: j['symbol'] ?? '',
        volumeMin: (j['volume_min'] ?? 0.01).toDouble(),
        volumeMax: (j['volume_max'] ?? 100.0).toDouble(),
        volumeStep: (j['volume_step'] ?? 0.01).toDouble(),
        point: (j['point'] ?? 0.00001).toDouble(),
        description: j['description'],
        tradeSessions: (j['trade_sessions'] as List<dynamic>? ?? [])
            .map((e) => TradeSession.fromJson(e))
            .toList(),
      );
}

class TradeSession {
  final String day;
  final List<SessionTime> sessions;
  const TradeSession({required this.day, required this.sessions});

  factory TradeSession.fromJson(Map<String, dynamic> j) => TradeSession(
        day: j['day'] ?? '',
        sessions: (j['sessions'] as List<dynamic>? ?? [])
            .map((e) => SessionTime.fromJson(e))
            .toList(),
      );
}

class SessionTime {
  final String open;
  final String close;
  const SessionTime({required this.open, required this.close});
  factory SessionTime.fromJson(Map<String, dynamic> j) =>
      SessionTime(open: j['open'] ?? '0000', close: j['close'] ?? '2359');
}

class UserInfo {
  final int login;
  final bool trading;
  const UserInfo({required this.login, this.trading = true});
}

class AppTheme {
  final Color colorPrimary;
  final Color colorError;
  final Color colorBackground;
  final Color colorText;
  final Color colorSuccess;
  final Color colorBackgroundPrimary;

  const AppTheme({
    this.colorPrimary = const Color(0xFF2196F3),
    this.colorError = const Color(0xFFF44336),
    this.colorBackground = const Color(0xFF121212),
    this.colorText = const Color(0xFFFFFFFF),
    this.colorSuccess = const Color(0xFF4CAF50),
    this.colorBackgroundPrimary = const Color(0xFF1E1E1E),
  });

  String toHex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
}

class NotificationData {
  final String title;
  final String content;
  final bool visible;
  final String icon; // "success" | "fail"
  const NotificationData({
    required this.title,
    this.content = '',
    this.visible = true,
    this.icon = 'success',
  });
}

// ─── Constants ──────────────────────────────────────────────────────────────

const _positionActions = {0: 'Buy', 1: 'Sell'};
const _orderTypes = {
  0: 'Buy', 1: 'Sell', 2: 'Buy Limit',
  3: 'Sell Limit', 4: 'Buy Stop', 5: 'Sell Stop'
};
const _returnCodes = {
  10009: 'Order placed',
  10002: 'Order filled',
  10003: 'Order cancelled',
  10008: 'Order modified',
};
const _langTvMap = {
  'en': 'en', 'ar': 'ar', 'ch': 'zh', 'es': 'es',
  'hi': 'en', 'fr': 'fr', 'id': 'id_ID', 'de': 'de',
  'th': 'th', 'ms': 'ms_MY', 'ja': 'ja', 'ko': 'ko',
  'tr': 'tr', 'ru': 'ru',
};

// ─── ChartScreen Widget ─────────────────────────────────────────────────────

class ChartScreen extends StatefulWidget {
  final bool visible;
  final SymbolInfo? symbol;
  final List<SymbolInfo> symbols;
  final IO.Socket? socket;
  final UserInfo? user;
  final Map<String, dynamic> positions; // { data: {id: pos}, posObj: {sym: [ids]} }
  final Map<String, dynamic> orders;   // { data: {id: ord}, ordersObj: {sym: [ids]} }
  final Map<String, dynamic> ticks;    // { symbol: { bid, ask, time } }
  final bool isDark;
  final String language;
  final AppTheme theme;
  final String clientId;
  final String server;
  final ValueChanged<NotificationData>? onNotification;
  final String platform; // "android" | "ios"

  const ChartScreen({
    super.key,
    this.visible = true,
    this.symbol,
    this.symbols = const [],
    this.socket,
    this.user,
    this.positions = const {},
    this.orders = const {},
    this.ticks = const {},
    this.isDark = true,
    this.language = 'en',
    this.theme = const AppTheme(),
    this.clientId = '',
    this.server = '',
    this.onNotification,
    this.platform = 'android',
  });

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  // ── WebView ───────────────────────────────────────────────────────────────
  WebViewController? _webViewController;
  bool _widgetReady = false;

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _isConnected = false;
  bool _tradeOpen = false;
  late double _volume;
  bool _isBuyingBuy = false;
  bool _isBuyingSell = false;

  // ── Market closed ─────────────────────────────────────────────────────────
  Timer? _closedTimer;
  int _closedSeconds = 0;

  // ── Socket listeners ──────────────────────────────────────────────────────
  late VoidCallback _onConnect;
  late VoidCallback _onDisconnect;

  @override
  void initState() {
    super.initState();
    _volume = widget.symbol?.volumeMin ?? 0.01;
    _initSocket();
    _startClosedTimer();
  }

  @override
  void didUpdateWidget(ChartScreen old) {
    super.didUpdateWidget(old);
    if (old.symbol?.symbol != widget.symbol?.symbol) {
      setState(() => _volume = widget.symbol?.volumeMin ?? 0.01);
    }
    if (old.socket != widget.socket) {
      _removeSocketListeners(old.socket);
      _initSocket();
    }
    if (old.isDark != widget.isDark && _widgetReady) {
      _callJS("window.__changeTheme('${widget.isDark ? 'dark' : 'light'}')");
    }
    if (old.positions != widget.positions && _widgetReady && _isConnected) {
      _renderPositionLines();
    }
    if (old.orders != widget.orders && _widgetReady && _isConnected) {
      _renderOrderLines();
    }
  }

  @override
  void dispose() {
    _closedTimer?.cancel();
    _removeSocketListeners(widget.socket);
    super.dispose();
  }

  // ── Socket ────────────────────────────────────────────────────────────────

  void _initSocket() {
    final s = widget.socket;
    if (s == null) {
      setState(() => _isConnected = false);
      return;
    }
    setState(() => _isConnected = s.connected);

    _onConnect = () => setState(() => _isConnected = true);
    _onDisconnect = () => setState(() => _isConnected = false);

    s.on('connect', (_) => _onConnect());
    s.on('disconnect', (_) => _onDisconnect());

    s.on('tick', (data) {
      if (_widgetReady) {
        _updateBidAskLines(data is Map ? data : {});
      }
    });

    s.on('api-reconnected', (_) {
      if (_widgetReady) {
        _callJS('window.__resetChart()');
      }
    });
  }

  void _removeSocketListeners(IO.Socket? s) {
    if (s == null) return;
    s.off('connect');
    s.off('disconnect');
    s.off('tick');
    s.off('api-reconnected');
  }

  // ── Market closed timer ───────────────────────────────────────────────────

  void _startClosedTimer() {
    _closedTimer?.cancel();
    _closedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _closedSeconds++);
    });
  }

  bool get _marketOpen {
    // Simplified: always open unless overridden. Implement isMarketOpen() as needed.
    return true;
  }

  // ── JS Bridge ─────────────────────────────────────────────────────────────

  Future<void> _callJS(String js) async {
    try {
      await _webViewController?.runJavaScript(js);
    } catch (e) {
      debugPrint('[ChartScreen] JS error: $e');
    }
  }

  // ── Bid / Ask lines ───────────────────────────────────────────────────────

  void _updateBidAskLines(Map tick) {
    if (tick.isEmpty) return;
    final bid = double.tryParse(tick['bid'].toString()) ?? 0;
    final ask = double.tryParse(tick['ask'].toString()) ?? 0;
    final t = tick['time']?.toString() ?? '';
    if (bid == 0 || ask == 0) return;

    _callJS('''
      window.__updateBidAsk({
        bid: $bid, ask: $ask, time: "$t",
        bidColor: "${widget.theme.toHex(widget.theme.colorPrimary)}",
        askColor: "${widget.theme.toHex(widget.theme.colorError)}"
      });
    ''');
  }

  // ── Position lines ────────────────────────────────────────────────────────

  void _renderPositionLines() {
    final posData = widget.positions['data'] as Map? ?? {};
    final posObj = widget.positions['posObj'] as Map? ?? {};
    final sym = widget.symbol?.symbol ?? '';
    final ids = (posObj[sym] as List? ?? []);

    final lines = ids
        .where((id) => posData.containsKey(id.toString()))
        .map((id) {
          final pos = posData[id.toString()] as Map;
          final profit = (pos['profit'] ?? 0).toDouble();
          final action = _positionActions[pos['action']] ?? 'Buy';
          final vol = pos['volume'];
          final price = (pos['open_price'] ?? 0).toDouble();
          final color = profit >= 0
              ? widget.theme.toHex(widget.theme.colorSuccess)
              : widget.theme.toHex(widget.theme.colorError);
          return {
            'price': price,
            'text': 'Profit: ${profit.toStringAsFixed(2)}',
            'quantity': '$action: $vol',
            'color': color,
          };
        })
        .toList();

    _callJS('window.__renderPositionLines(${jsonEncode(lines)})');
  }

  // ── Order lines ───────────────────────────────────────────────────────────

  void _renderOrderLines() {
    final ordData = widget.orders['data'] as Map? ?? {};
    final ordObj = widget.orders['ordersObj'] as Map? ?? {};
    final sym = widget.symbol?.symbol ?? '';
    final ids = (ordObj[sym] as List? ?? []);

    final lines = ids
        .where((id) => ordData.containsKey(id.toString()))
        .map((id) {
          final ord = ordData[id.toString()] as Map;
          final type = _orderTypes[ord['type']] ?? 'Order';
          final vol = ord['volume'];
          final price = (ord['open_price'] ?? 0).toDouble();
          return {
            'orderId': ord['order_id'],
            'price': price,
            'quantity': '$type: $vol',
          };
        })
        .toList();

    _callJS('window.__renderOrderLines(${jsonEncode(lines)})');
  }

  // ── Cancel order ──────────────────────────────────────────────────────────

  void _cancelOrder(Map order) {
    final s = widget.socket;
    if (s == null) return;
    bool resolved = false;

    void handler(dynamic res) {
      if (resolved) return;
      resolved = true;
      s.off('order-response');
      final r = res is Map ? res : {};
      if (r['result'] != null || r['success'] == true) {
        HapticFeedback.mediumImpact();
        widget.onNotification?.call(NotificationData(
          title: 'Order cancelled',
          content: '#${order['order_id']}\n'
              '${_orderTypes[order['type']]} '
              '${order['volume']} ${order['symbol']}',
          visible: true,
          icon: 'success',
        ));
      } else {
        HapticFeedback.vibrate();
        widget.onNotification?.call(NotificationData(
          title: '${r['error'] ?? 'Error'}',
          visible: true,
          icon: 'fail',
        ));
      }
      Future.delayed(const Duration(seconds: 2), () {
        widget.onNotification?.call(const NotificationData(
          title: '', visible: false,
        ));
      });
    }

    s.on('order-response', handler);
    s.emit('order-cancel', {'order_id': order['order_id']});

    Future.delayed(const Duration(seconds: 30), () {
      if (!resolved) {
        resolved = true;
        s.off('order-response');
        HapticFeedback.vibrate();
        widget.onNotification?.call(const NotificationData(
          title: 'Request timeout', visible: true, icon: 'fail',
        ));
        Future.delayed(const Duration(seconds: 2), () {
          widget.onNotification?.call(const NotificationData(
            title: '', visible: false,
          ));
        });
      }
    });
  }

  // ── Place order ───────────────────────────────────────────────────────────

  void _placeOrder(String side) {
    final s = widget.socket;
    if (s == null || _isBuyingBuy || _isBuyingSell) return;

    setState(() {
      if (side == 'buy') _isBuyingBuy = true;
      if (side == 'sell') _isBuyingSell = true;
    });

    final type = side == 'sell' ? 1 : 0;
    bool resolved = false;

    void resetBuying() =>
        setState(() => _isBuyingBuy = _isBuyingSell = false);

    void handler(dynamic res) {
      if (resolved) return;
      resolved = true;
      s.off('order-response');
      final r = res is Map ? res : {};
      if (r['result'] != null) {
        final code = int.tryParse(r['result'].toString()) ?? 0;
        final success = [10009, 10002, 10003, 10008].contains(code);
        if (success) {
          HapticFeedback.mediumImpact();
          widget.onNotification?.call(NotificationData(
            title: _returnCodes[code] ?? 'Order placed',
            content: '${_orderTypes[type]} $_volume ${widget.symbol?.symbol} at market',
            visible: true,
            icon: 'success',
          ));
        } else {
          HapticFeedback.vibrate();
          final ticket = r['ticket'] ?? 0;
          widget.onNotification?.call(NotificationData(
            title: ticket > 0
                ? '${_returnCodes[code] ?? 'Error'} #$ticket'
                : '${_returnCodes[code] ?? 'Error'}',
            visible: true,
            icon: 'fail',
          ));
        }
      } else if (r['error'] != null) {
        HapticFeedback.vibrate();
        widget.onNotification?.call(NotificationData(
          title: '${r['error']}', visible: true, icon: 'fail',
        ));
      }
      Future.delayed(const Duration(seconds: 2), () {
        widget.onNotification?.call(const NotificationData(
          title: '', visible: false,
        ));
      });
      resetBuying();
    }

    s.on('order-response', handler);
    s.emit('order-create', {
      'position_id': 0,
      'price': 0,
      'volume': _volume,
      'tp': 0,
      'sl': 0,
      'symbol': widget.symbol?.symbol ?? '',
      'type': type,
      'comment': '',
    });

    Future.delayed(const Duration(seconds: 30), () {
      if (!resolved) {
        resolved = true;
        s.off('order-response');
        resetBuying();
        HapticFeedback.vibrate();
        widget.onNotification?.call(const NotificationData(
          title: 'Request timeout', visible: true, icon: 'fail',
        ));
        Future.delayed(const Duration(seconds: 2), () {
          widget.onNotification?.call(const NotificationData(
            title: '', visible: false,
          ));
        });
      }
    });
  }

  // ── Build the HTML that hosts the TradingView widget ─────────────────────

  String _buildChartHtml() {
    final locale = _langTvMap[widget.language] ?? 'en';
    final theme = widget.isDark ? 'dark' : 'light';
    final bg = widget.theme.toHex(widget.theme.colorBackground);
    final primaryHex = widget.theme.toHex(widget.theme.colorPrimary);
    final errorHex = widget.theme.toHex(widget.theme.colorError);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    html, body { width:100%; height:100%; background:$bg; overflow:hidden; }
    #tv_chart_container { width:100%; height:100%; }
  </style>
</head>
<body>
  <div id="tv_chart_container"></div>

  <!-- TradingView charting_library must be bundled in your assets -->
  <script src="charting_library/charting_library.standalone.js"></script>

  <script>
    // ── Bridge helpers exposed to Flutter ──────────────────────────────
    let _tvWidget = null;
    let _bidLine  = null;
    let _askLine  = null;

    window.__changeTheme = function(t) {
      if (_tvWidget) _tvWidget.changeTheme(t);
    };

    window.__resetChart = function() {
      if (_tvWidget) {
        try { _tvWidget.activeChart().resetData(); } catch(e) {}
      }
    };

    window.__updateBidAsk = function(opts) {
      if (!_tvWidget) return;
      try {
        const chart = _tvWidget.activeChart();
        if (_bidLine) { chart.removeEntity(_bidLine); _bidLine = null; }
        if (_askLine) { chart.removeEntity(_askLine); _askLine = null; }
        const t = opts.time;
        _bidLine = chart.createShape(
          { price: opts.bid, time: t },
          { shape: "horizontal_line", lock: true,
            disableSelection:true, disableSave:true, disableUndo:true,
            overrides: { linecolor: opts.bidColor, linewidth:1, linestyle:1,
              showLabel:true, horzLabelsAlign:"right", textcolor: opts.bidColor } }
        );
        _askLine = chart.createShape(
          { price: opts.ask, time: t },
          { shape: "horizontal_line", lock: true,
            disableSelection:true, disableSave:true, disableUndo:true,
            overrides: { linecolor: opts.askColor, linewidth:1, linestyle:1,
              showLabel:true, horzLabelsAlign:"right", textcolor: opts.askColor } }
        );
      } catch(e) { console.error(e); }
    };

    window.__renderPositionLines = function(lines) {
      if (!_tvWidget) return;
      try {
        const chart = _tvWidget.activeChart();
        lines.forEach(function(l) {
          chart.createPositionLine()
            .setText(l.text)
            .setQuantity(l.quantity)
            .setLineColor(l.color)
            .setExtendLeft(true)
            .setLineStyle(0)
            .setLineLength(50)
            .setPrice(l.price);
        });
      } catch(e) { console.error(e); }
    };

    window.__renderOrderLines = function(lines) {
      if (!_tvWidget) return;
      try {
        const chart = _tvWidget.activeChart();
        lines.forEach(function(l) {
          chart.createOrderLine()
            .setText("Order")
            .setQuantity(l.quantity)
            .setPrice(l.price)
            .setLineStyle(0)
            .setLineLength(50);
        });
      } catch(e) { console.error(e); }
    };

    // ── TradingView widget init ────────────────────────────────────────
    const widget = new TradingView.widget({
      library_path:   "charting_library/charting_library",
      fullscreen:     true,
      autosize:       true,
      symbol:         "${widget.symbol?.symbol ?? 'EURUSD'}",
      container:      "tv_chart_container",
      interval:       "1",
      datafeed:       window.__tradynDatafeed,   // injected by Datafeed bridge
      timezone:       "exchange",
      theme:          "$theme",
      locale:         "$locale",
      loading_screen: { backgroundColor: "$bg" },
      client_id:      "${widget.clientId}",
      user_id:        "${widget.user?.login ?? ''}",
      load_last_chart:            true,
      auto_save_delay:            2,
      charts_storage_url:         "https://chart-storage.tradyn.com",
      charts_storage_api_version: "1.1",
      enabled_features: [
        "show_spread_operators","move_logo_to_main_pane",
        "header_resolutions","hide_left_toolbar_by_default",
        "show_hide_button_in_legend"
      ],
      disabled_features: [
        "use_localstorage_for_settings","edit_buttons_in_legend",
        "control_bar","border_around_the_chart","header_compare",
        "adaptive_logo","timeframes_toolbar","widget_logo",
        "header_symbol_search","header_screenshot","left_toolbar",
        "header_fullscreen_button","hide_main_series_symbol_from_indicator_legend",
        "header_saveload"
      ],
    });

    _tvWidget = widget;

    widget.onChartReady(function() {
      window.FlutterBridge && window.FlutterBridge.postMessage(
        JSON.stringify({ type: "widgetReady" })
      );
    });
  </script>
</body>
</html>
''';
  }

  // ── Volume stepper helpers ────────────────────────────────────────────────

  void _incrementVolume() {
    final sym = widget.symbol;
    if (sym == null) return;
    final next = _volume + sym.volumeStep;
    if (next <= sym.volumeMax) setState(() => _volume = _round(next, sym.volumeStep));
  }

  void _decrementVolume() {
    final sym = widget.symbol;
    if (sym == null) return;
    final next = _volume - sym.volumeStep;
    if (next >= sym.volumeMin) setState(() => _volume = _round(next, sym.volumeStep));
  }

  double _round(double value, double step) {
    final decimals = step.toString().contains('.')
        ? step.toString().split('.').last.length
        : 0;
    final factor = 10.0 * decimals;
    return factor == 0 ? value : (value * factor).round() / factor;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Stack(
      children: [
        // ── TradingView WebView ─────────────────────────────────────────
        WebViewWidget(
          controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..addJavaScriptChannel(
              'FlutterBridge',
              onMessageReceived: (msg) {
                try {
                  final data = jsonDecode(msg.message) as Map;
                  if (data['type'] == 'widgetReady') {
                    setState(() => _widgetReady = true);
                    _renderPositionLines();
                    _renderOrderLines();
                  }
                } catch (_) {}
              },
            )
            ..loadHtmlString(_buildChartHtml()),
        ),

        // ── Quick Trade Panel ───────────────────────────────────────────
        if (_widgetReady && (widget.user?.trading ?? true) && _tradeOpen)
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: Material(
              color: widget.theme.colorBackground,
              borderRadius: BorderRadius.circular(8),
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // SELL
                    Expanded(
                      child: _TradeButton(
                        label: 'Sell\nmarket',
                        color: widget.theme.colorError,
                        loading: _isBuyingSell,
                        onTap: () => _placeOrder('sell'),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Volume stepper
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _volume.toStringAsFixed(2),
                            style: TextStyle(
                              color: widget.theme.colorText,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove,
                                    color: widget.theme.colorText, size: 18),
                                onPressed: _decrementVolume,
                              ),
                              IconButton(
                                icon: Icon(Icons.add,
                                    color: widget.theme.colorText, size: 18),
                                onPressed: _incrementVolume,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // BUY
                    Expanded(
                      child: _TradeButton(
                        label: 'Buy\nmarket',
                        color: widget.theme.colorSuccess,
                        loading: _isBuyingBuy,
                        onTap: () => _placeOrder('buy'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Market closed banner ────────────────────────────────────────
        if (!_marketOpen)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.theme.colorBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.theme.colorError),
                ),
                child: Text(
                  'Market closed',
                  style: TextStyle(
                    color: widget.theme.colorText, fontSize: 12,
                  ),
                ),
              ),
            ),
          ),

        // ── Trade button (top-right) ────────────────────────────────────
        if ((widget.user?.trading ?? true))
          Positioned(
            top: 8,
            right: 12,
            child: GestureDetector(
              onTap: () => setState(() => _tradeOpen = !_tradeOpen),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.theme.colorBackgroundPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Trade',
                  style: TextStyle(
                    color: widget.theme.colorText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Small reusable trade button ────────────────────────────────────────────

class _TradeButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _TradeButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        opacity: loading ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
        ),
      ),
    );
  }
}
