import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/utils/message_pack_decoder.dart';
import 'package:crm_app/utils/fast_message_pack_decoder.dart';

/// WebSocket **`{socketUrl}/ws/marketwatchv2`** (see [WebSocketEndpointHelper.getMarketWatchV2Url]).
///
/// **Contract (client → server, JSON text on same socket):**
/// 1. `{"authID":"<token>","trading_account":"<meta_account>"}` — first frame after connect.
/// 2. `{"action":"subscribe","symbols":["EURUSD",...]}` — per-symbol ticks (normalized, no `.c`).
/// 3. `{"action":"unsubscribe","symbols":["EURUSD"]}` — stop ticks for those symbols.
///
/// **Server → client:** binary MessagePack (decoded with [FastMessagePackDecoder] for speed).
///
/// Decoded payloads are broadcast on [decodedFrames] for [InstrumentsController].
class MarketWatchV2Service extends GetxService {
  @override
  void onClose() {
    disconnect();
    if (!_decodedBroadcast.isClosed) {
      _decodedBroadcast.close();
    }
    _flushTimer?.cancel();
    super.onClose();
  }

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  String? _tradingAccountBound;

  /// ✅ Single-subscriber broadcast for decoded price frames.
  final StreamController<dynamic> _decodedBroadcast =
      StreamController<dynamic>.broadcast();

  /// Decoded server payloads (MessagePack or JSON), for instruments price updates.
  Stream<dynamic> get decodedFrames => _decodedBroadcast.stream;

  // ✅ Batching: queue decoded messages and flush in batches to reduce
  // UI rebuilds when the server sends many price ticks per second.
  final List<dynamic> _pendingFrames = [];
  Timer? _flushTimer;
  static const Duration _flushInterval = Duration(milliseconds: 80);
  static const int _maxBatchSize = 50;
  DateTime _lastFlushAt = DateTime.now();

  /// Lightweight ring of decoded activity for debug (counts only).
  final RxInt receivedFrames = 0.obs;
  final RxInt decodedFramesCount = 0.obs;
  final RxInt broadcastedFrames = 0.obs;

  /// Request + response log for instruments screen (WS `marketwatchv2` only).
  final RxString decodedLog = ''.obs;

  static String normalizeSymbol(String raw) {
    var s = raw.trim();
    if (s.contains('.')) {
      s = s.substring(0, s.lastIndexOf('.'));
    }
    return s;
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
    if (decodedLog.value.length > 5000) return;
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
    if (decodedLog.value.length > 8000) return;
    if (note == 'binary') return; // Skip price-tick logging
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
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingFrames.clear();
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

  /// High-performance message handler with batching.
  /// 
  /// Steps:
  /// 1. Fast-path: detect binary vs text in O(1) (check first byte)
  /// 2. Decode with optimized MessagePack decoder (no try-catch chain)
  /// 3. Enqueue decoded frame for batched broadcast
  void _onMessage(dynamic message) {
    try {
      receivedFrames.value++;
      dynamic decoded;

      // Fast path: detect binary by type
      if (message is Uint8List) {
        decoded = _decodeFast(message);
      } else if (message is List<int>) {
        decoded = _decodeFast(Uint8List.fromList(message));
      } else if (message is String) {
        // JSON text message
        try {
          decoded = jsonDecode(message);
        } catch (_) {
          decoded = message;
        }
        _logResponse(decoded, note: 'text/json');
      } else {
        return; // Unknown type, skip
      }

      if (decoded == null) {
        // Decode failed - try legacy decoder as fallback
        if (message is Uint8List || message is List<int>) {
          decoded = MessagePackDecoder.decodeBinary(
            message is Uint8List
                ? message
                : Uint8List.fromList(message as List<int>),
          );
        }
        if (decoded == null) return;
      }

      decodedFramesCount.value++;
      _enqueueDecoded(decoded);
    } catch (_) {
      // Silent fail for performance
    }
  }

  /// Fast binary MessagePack decode using ByteData-based reader.
  /// ~3-5x faster than the generic try-catch chain decoder.
  dynamic _decodeFast(Uint8List u8) {
    // First try our fast decoder
    final fast = FastMessagePackDecoder.decode(u8);
    if (fast != null) return fast;
    // Fall back to the package decoder
    return MessagePackDecoder.decodeBinary(u8);
  }

  /// Add decoded frame to batch queue and schedule flush.
  void _enqueueDecoded(dynamic decoded) {
    _pendingFrames.add(decoded);

    // Force flush if batch is full or too much time has passed
    final now = DateTime.now();
    final elapsed = now.difference(_lastFlushAt);

    if (_pendingFrames.length >= _maxBatchSize ||
        elapsed > const Duration(milliseconds: 250)) {
      _flushDecodedBatch();
    } else {
      _flushTimer ??= Timer(_flushInterval, _flushDecodedBatch);
    }
  }

  /// Flush all pending decoded frames in a single broadcast cycle.
  void _flushDecodedBatch() {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_pendingFrames.isEmpty) return;

    final batch = List<dynamic>.from(_pendingFrames);
    _pendingFrames.clear();
    _lastFlushAt = DateTime.now();

    // ✅ If a single frame in the batch, send directly (most common case)
    // If multiple, send them one at a time but synchronously to avoid
    // microtask explosion on the stream.
    if (!_decodedBroadcast.isClosed) {
      if (batch.length == 1) {
        _decodedBroadcast.add(batch.first);
        broadcastedFrames.value++;
      } else {
        for (final frame in batch) {
          _decodedBroadcast.add(frame);
          broadcastedFrames.value++;
        }
      }
    }
  }

  Future<void> _ensureSocketForCurrentAccount() async {
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

  Future<void> subscribeSymbols(List<String> symbols) async {
    final clean =
        symbols.map(normalizeSymbol).where((s) => s.isNotEmpty).toList();
    if (clean.isEmpty) return;

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
