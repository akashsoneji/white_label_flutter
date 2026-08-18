/// One place to point the chart at your backend. **Only [baseDomain] changes
/// per broker / environment** — every API path below is fixed and identical for
/// all brokers, exactly like the web build. Do not edit the paths unless the
/// server contract itself changes.
///
/// ```dart
/// const cfg = TenaxApiConfig(
///   baseDomain: 'https://api.mybroker.com', // the ONLY thing you change
///   token: sessionToken,
/// );
/// ```
class TenaxApiConfig {
  const TenaxApiConfig({
    required this.baseDomain,
    this.token,
    this.wsDomain,
  });

  /// Scheme + host (+ optional base path), no trailing slash.
  /// e.g. `https://api.mybroker.com` or `https://crm.broker.com/tradeengine`.
  final String baseDomain;

  /// Bearer/session token sent as `Authorization: Bearer <token>`. Optional.
  final String? token;

  /// Socket origin for live ticks. Defaults to [baseDomain] with http→ws /
  /// https→wss when omitted.
  final String? wsDomain;

  // ---- fixed API paths (same for every broker) -----------------------------

  /// Historical candles. Query: symbol, resolution, from, to.
  static const String historyPath = '/api/market/history';

  /// Instrument list for the search modal.
  static const String symbolsPath = '/api/chart/symbols';

  /// Live-tick websocket path (joined onto [resolvedWsBase]).
  static const String ticksPath = '/ws/chart/ticks';

  /// Modify an order's SL / TP / pending price. POST /{orderId}/modify.
  static const String orderModifyPath = '/api/chart/orders/{orderId}/modify';

  /// Close a position / cancel a pending. POST /{orderId}/close.
  static const String orderClosePath = '/api/chart/orders/{orderId}/close';

  /// Place a new order (optional feature). POST.
  static const String orderPlacePath = '/api/chart/orders';

  // ---- resolution helpers --------------------------------------------------

  String get _root {
    var d = baseDomain.trim();
    while (d.endsWith('/')) {
      d = d.substring(0, d.length - 1);
    }
    return d;
  }

  /// Build a full REST URL for a fixed path, filling `{orderId}` when present.
  Uri url(String path, {String? orderId, Map<String, dynamic>? query}) {
    var p = path;
    if (orderId != null) p = p.replaceAll('{orderId}', Uri.encodeComponent(orderId));
    final uri = Uri.parse('$_root$p');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    });
  }

  /// ws/wss origin for ticks, derived from [wsDomain] or [baseDomain].
  String get resolvedWsBase {
    if (wsDomain != null && wsDomain!.isNotEmpty) {
      var d = wsDomain!.trim();
      while (d.endsWith('/')) {
        d = d.substring(0, d.length - 1);
      }
      return d;
    }
    final root = _root;
    if (root.startsWith('https://')) return 'wss://${root.substring(8)}';
    if (root.startsWith('http://')) return 'ws://${root.substring(7)}';
    return root;
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };
}
