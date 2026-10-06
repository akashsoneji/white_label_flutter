import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/stream_websocket_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/utils/message_pack_decoder.dart';

/// WebSocket **`{socketUrl}/ws/marketwatchv2`** (see [WebSocketEndpointHelper.getMarketWatchV2Url]).
///
/// **Contract (client → server, JSON text on same socket):**
/// 1. `{"authID":"<token>","trading_account":"<meta_account>"}` — first frame after connect.
/// 2. `{"action":"subscribe","symbols":["EURUSD",...]}` — per-symbol ticks (normalized, no `.c`).
/// 3. `{"action":"unsubscribe","symbols":["EURUSD"]}` — stop ticks for those symbols.
///
/// **Server → client:** binary MessagePack (see [MessagePackDecoder]); optional text/JSON fallback.
///
/// Decoded payloads are broadcast on [decodedFrames] for [InstrumentsController] (and debug [decodedLog]).
class MarketWatchV2Service extends GetxService {
  @override
  void onInit() {
    super.onInit();
    _bindStreamSocketBridge();
  }

  @override
  void onClose() {
    _streamPricesSub?.cancel();
    _streamPricesSub = null;
    disconnect();
    if (!_decodedBroadcast.isClosed) {
      _decodedBroadcast.close();
    }
    super.onClose();
  }

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  String? _tradingAccountBound;

  // Pippro / pipze: forward decoded price frames from the single `/ws/stream`
  // socket onto [_decodedBroadcast] so InstrumentsController can consume them
  // without caring which socket produced them.
  StreamSubscription<dynamic>? _streamPricesSub;

  final StreamController<dynamic> _decodedBroadcast =
      StreamController<dynamic>.broadcast();

  void _bindStreamSocketBridge() {
    if (!FlavorConfig.usesSingleStreamSocket) return;
    void attach() {
      if (!Get.isRegistered<StreamWebSocketService>()) {
        Future.delayed(const Duration(seconds: 1), attach);
        return;
      }
      final svc = Get.find<StreamWebSocketService>();
      _streamPricesSub?.cancel();
      _streamPricesSub = svc.prices.listen((payload) {
        if (_decodedBroadcast.isClosed) return;
        // InstrumentsController's existing decoder understands the raw
        // decoded shape (list / map). Pass the payload straight through.
        _decodedBroadcast.add(payload);
      });
    }
    attach();
  }

  /// Decoded server payloads (MessagePack or JSON), for instruments price updates.
  Stream<dynamic> get decodedFrames => _decodedBroadcast.stream;

  /// Request + response log for instruments screen (WS `marketwatchv2` only).
  final RxString decodedLog = ''.obs;

  static String normalizeSymbol(String raw) {
    var s = raw.trim();
    if (s.contains('.')) {
      s = s.substring(0, s.lastIndexOf('.'));
    }
    return s.toUpperCase();
  }

  void _appendLog(String line) {
    final ts = DateTime.now().toIso8601String();
    final next = '[$ts] $line';
    final cur = decodedLog.value;
    final combined = cur.isEmpty ? next : '$cur\n$next';
    decodedLog.value = combined.length > 12000
        ? combined.substring(combined.length - 12000)
        : combined;
  }

  void _logRequest(String actionLabel, Map<String, dynamic> body) {
    final forDisplay = Map<String, dynamic>.from(body);
    final auth = forDisplay['authID'];
    if (auth is String && auth.isNotEmpty) {
      forDisplay['authID'] = '<redacted len=${auth.length}>';
    }
    try {
      final json = const JsonEncoder.withIndent('  ').convert(forDisplay);
      _appendLog('→ REQUEST ($actionLabel)\n$json');
    } catch (_) {
      _appendLog('→ REQUEST ($actionLabel)\n$forDisplay');
    }
  }

  void _logResponse(dynamic decoded, {String? note}) {
    final head = note != null ? '← RESPONSE ($note)\n' : '← RESPONSE\n';
    try {
      _appendLog('$head${_stringifyDecoded(decoded)}');
    } catch (_) {
      _appendLog('$head$decoded');
    }
  }

  Future<String> _tradingAccount() async {
    try {
      final raw =
          Get.find<AccountController>().activeMT5Account?.metaAccountNumber;
      final acct = raw?.trim();
      if (acct != null && acct.isNotEmpty) return acct;
    } catch (_) {}
    return '0';
  }

  void _tearDownLocal() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _tradingAccountBound = null;
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _tradingAccountBound = null;
  }

  dynamic _jsonify(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _jsonify(val)));
    }
    if (v is List) {
      return v.map(_jsonify).toList();
    }
    return v;
  }

  String _stringifyDecoded(dynamic d) {
    try {
      return const JsonEncoder.withIndent('  ').convert(_jsonify(d));
    } catch (_) {
      return d.toString();
    }
  }

  void _onMessage(dynamic message) {
    try {
      dynamic decoded;
      if (MessagePackDecoder.isBinaryMessage(message)) {
        final u8 = message is Uint8List
            ? message
            : Uint8List.fromList(message as List<int>);
        decoded = MessagePackDecoder.decodeBinary(u8);
        if (decoded == null) {
          _appendLog(
            '← RESPONSE (binary decode failed, ${u8.length} bytes)',
          );
          return;
        }
        _logResponse(decoded, note: 'binary ${u8.length} bytes → decoded');
      } else {
        final s = message.toString();
        try {
          decoded = jsonDecode(s);
        } catch (_) {
          decoded = s;
        }
        _logResponse(decoded, note: 'text/json');
      }
      if (!_decodedBroadcast.isClosed) {
        _decodedBroadcast.add(decoded);
      }
    } catch (e) {
      _appendLog('← RESPONSE (onMessage error: $e)');
    }
  }

  Future<void> _ensureSocketForCurrentAccount() async {
    // Pippro / pipze: all symbol ticks arrive on the single multiplexed
    // `/ws/stream` socket (StreamWebSocketService.prices). Skip the
    // dedicated `/ws/marketwatchv2` socket for these flavors.
    if (FlavorConfig.usesSingleStreamSocket) return;
    final token = await SecureStorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      _appendLog('→ REQUEST skipped (no auth token)');
      return;
    }

    final trading = await _tradingAccount();
    if (_channel != null && _tradingAccountBound == trading) {
      return;
    }

    await disconnect();

    _tradingAccountBound = trading;
    final url = WebSocketEndpointHelper.getMarketWatchV2Url();
    _appendLog('— CONNECT marketwatchv2\n$url\ntrading_account=$trading');

    _channel = WebSocketChannel.connect(Uri.parse(url));
    _sub = _channel!.stream.listen(
      _onMessage,
      onError: (Object e) {
        _appendLog('← channel error: $e');
        _tearDownLocal();
      },
      onDone: () {
        _appendLog('← channel closed');
        _tearDownLocal();
      },
    );

    final authPayload = <String, dynamic>{
      'authID': token,
      'trading_account': trading,
    };
    _logRequest('auth (first frame on socket)', authPayload);
    _channel!.sink.add(jsonEncode(authPayload));
  }

  /// Opens `marketwatchv2` WebSocket and sends auth (no subscribe).
  /// Use when the watchlist has no symbols but you still need the session / server handshake.
  Future<void> ensureAuthenticatedConnection() async {
    await _ensureSocketForCurrentAccount();
  }

  /// Opens/restores the socket and subscribes symbols without forcing a
  /// disconnect when the same account socket is still reusable. Used on app
  /// resume to avoid a full UI/list refresh.
  Future<void> resumeSubscribeSymbols(List<String> symbols) async {
    final clean =
        symbols.map(normalizeSymbol).where((s) => s.isNotEmpty).toList();

    await _ensureSocketForCurrentAccount();
    if (_channel == null) return;
    if (clean.isEmpty) return;

    final payload = <String, dynamic>{'action': 'subscribe', 'symbols': clean};
    _logRequest('resume subscribe', payload);
    _channel!.sink.add(jsonEncode(payload));
  }

  Future<void> subscribeSymbols(List<String> symbols) async {
    final clean =
        symbols.map(normalizeSymbol).where((s) => s.isNotEmpty).toList();
    if (clean.isEmpty) return;

    // Pippro / pipze: route subscription to the single `/ws/stream` socket.
    if (FlavorConfig.usesSingleStreamSocket) {
      if (Get.isRegistered<StreamWebSocketService>()) {
        await Get.find<StreamWebSocketService>().addSymbols(clean);
      }
      return;
    }

    await _ensureSocketForCurrentAccount();
    if (_channel == null) return;

    final payload = <String, dynamic>{'action': 'subscribe', 'symbols': clean};
    _logRequest('subscribe', payload);
    _channel!.sink.add(jsonEncode(payload));
  }

  Future<void> unsubscribeSymbols(List<String> symbols) async {
    final clean =
        symbols.map(normalizeSymbol).where((s) => s.isNotEmpty).toList();
    if (clean.isEmpty) return;

    // Pippro / pipze: route unsubscription to the single `/ws/stream` socket.
    if (FlavorConfig.usesSingleStreamSocket) {
      if (Get.isRegistered<StreamWebSocketService>()) {
        await Get.find<StreamWebSocketService>().removeSymbols(clean);
      }
      return;
    }

    if (_channel == null) return;

    final payload = <String, dynamic>{
      'action': 'unsubscribe',
      'symbols': clean,
    };
    _logRequest('unsubscribe', payload);
    _channel!.sink.add(jsonEncode(payload));
  }

  /// After account switch: new socket + auth, then subscribe all favorites.
  Future<void> reconnectAndResyncFavorites() async {
    await disconnect();
    if (!Get.isRegistered<InstrumentsController>()) return;
    final favs = Get.find<InstrumentsController>().favoriteInstruments.toList();
    if (favs.isEmpty) {
      await ensureAuthenticatedConnection();
      return;
    }
    final syms =
        favs.map(normalizeSymbol).where((s) => s.isNotEmpty).toSet().toList();
    await subscribeSymbols(syms);
  }
}
