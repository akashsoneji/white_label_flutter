import 'dart:developer' as developer;

/// Custom logger for the app trading app
/// Filters out WebView spam and provides organized logging
class AppLogger {
  // Log tags for different modules
  static const String _tradingTag = 'Trading';
  static const String _chartTag = 'Chart';
  static const String _websocketTag = 'WebSocket';
  static const String _apiTag = 'API';
  static const String _orderTag = 'Order';
  static const String _priceTag = 'Price';
  static const String _errorTag = 'Error';
  static const String _debugTag = 'Debug';

  // Log levels
  static const int _debugLevel = 500;
  static const int _infoLevel = 800;
  static const int _warningLevel = 900;
  static const int _errorLevel = 1000;

  // Enable/disable logging for different modules
  static bool _enableTradingLogs = true;
  static bool _enableChartLogs = true;
  static bool _enableWebSocketLogs = true;
  static bool _enableApiLogs = true;
  static bool _enableOrderLogs = true;
  static bool _enablePriceLogs = true;
  static bool _enableErrorLogs = true;
  static bool _enableDebugLogs = false; // Disabled by default

  /// Trading related logs
  static void trading(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enableTradingLogs) return;
    // Filter out spam messages
    if (_isWebViewSpam(message)) return;
    developer.log(
      message,
      name: _tradingTag,
      error: error,
      stackTrace: stackTrace,
      level: _infoLevel,
    );
  }

  /// Chart related logs (filtered to avoid WebView spam)
  static void chart(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enableChartLogs) return;

    // Filter out WebView spam
    if (_isWebViewSpam(message)) return;

    developer.log(
      message,
      name: _chartTag,
      error: error,
      stackTrace: stackTrace,
      level: _infoLevel,
    );
  }

  /// WebSocket related logs
  static void websocket(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enableWebSocketLogs) return;
    // Filter out spam messages
    if (_isWebViewSpam(message)) return;
    developer.log(
      message,
      name: _websocketTag,
      error: error,
      stackTrace: stackTrace,
      level: _infoLevel,
    );
  }

  /// API related logs
  static void api(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enableApiLogs) return;
    // Filter out spam messages
    if (_isWebViewSpam(message)) return;
    developer.log(
      message,
      name: _apiTag,
      error: error,
      stackTrace: stackTrace,
      level: _infoLevel,
    );
  }

  /// Order related logs
  static void order(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enableOrderLogs) return;
    // Filter out spam messages
    if (_isWebViewSpam(message)) return;
    developer.log(
      message,
      name: _orderTag,
      error: error,
      stackTrace: stackTrace,
      level: _infoLevel,
    );
  }

  /// Price related logs
  static void price(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enablePriceLogs) return;
    // Filter out spam messages
    if (_isWebViewSpam(message)) return;
    developer.log(
      message,
      name: _priceTag,
      error: error,
      stackTrace: stackTrace,
      level: _infoLevel,
    );
  }

  /// Error logs (always enabled)
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _errorTag,
      error: error,
      stackTrace: stackTrace,
      level: _errorLevel,
    );
  }

  /// Debug logs (disabled by default)
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enableDebugLogs) return;
    // Filter out spam messages
    if (_isWebViewSpam(message)) return;
    developer.log(
      message,
      name: _debugTag,
      error: error,
      stackTrace: stackTrace,
      level: _debugLevel,
    );
  }

  /// Warning logs
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    // Filter out spam messages
    if (_isWebViewSpam(message)) return;
    developer.log(
      message,
      name: 'Warning',
      error: error,
      stackTrace: stackTrace,
      level: _warningLevel,
    );
  }

  /// Check if message is WebView spam
  static bool _isWebViewSpam(String message) {
    final spamPatterns = [
      'setRequestedFrameRate',
      'GPUAUX',
      'Null anb',
      'WebViewProxyApi',
      'WebViewChromium',
      'WebView.onDraw',
      'WV.df.b',
      'WV.eg.h',
      'WV.eg.onDraw',
      'com.android.webview.chromium',
      'android.webkit.WebView',
      'Unable to acquire a buffer item',
      'maxImages buffers',
      'ImageReader_JNI',
    ];

    return spamPatterns.any((pattern) => message.contains(pattern));
  }

  /// Enable/disable specific log modules
  static void setLoggingEnabled({
    bool? trading,
    bool? chart,
    bool? websocket,
    bool? api,
    bool? order,
    bool? price,
    bool? error,
    bool? debug,
  }) {
    if (trading != null) _enableTradingLogs = trading;
    if (chart != null) _enableChartLogs = chart;
    if (websocket != null) _enableWebSocketLogs = websocket;
    if (api != null) _enableApiLogs = api;
    if (order != null) _enableOrderLogs = order;
    if (price != null) _enablePriceLogs = price;
    if (error != null) _enableErrorLogs = error;
    if (debug != null) _enableDebugLogs = debug;
  }

  /// Enable all logs
  static void enableAllLogs() {
    _enableTradingLogs = true;
    _enableChartLogs = true;
    _enableWebSocketLogs = true;
    _enableApiLogs = true;
    _enableOrderLogs = true;
    _enablePriceLogs = true;
    _enableErrorLogs = true;
    _enableDebugLogs = true;
  }

  /// Disable all logs except errors
  static void enableErrorLogsOnly() {
    _enableTradingLogs = false;
    _enableChartLogs = false;
    _enableWebSocketLogs = false;
    _enableApiLogs = false;
    _enableOrderLogs = false;
    _enablePriceLogs = false;
    _enableErrorLogs = true;
    _enableDebugLogs = false;
  }

  /// Enable production logging (only errors and warnings)
  static void enableProductionLogging() {
    _enableTradingLogs = false;
    _enableChartLogs = false;
    _enableWebSocketLogs = false;
    _enableApiLogs = false;
    _enableOrderLogs = false;
    _enablePriceLogs = false;
    _enableErrorLogs = true;
    _enableDebugLogs = false;
  }

  /// Get current logging status
  static Map<String, bool> getLoggingStatus() {
    return {
      'trading': _enableTradingLogs,
      'chart': _enableChartLogs,
      'websocket': _enableWebSocketLogs,
      'api': _enableApiLogs,
      'order': _enableOrderLogs,
      'price': _enablePriceLogs,
      'error': _enableErrorLogs,
      'debug': _enableDebugLogs,
    };
  }
}

/// Extension to replace print() statements with proper logging
extension LoggingExtension on String {
  void logTrading() => AppLogger.trading(this);
  void logChart() => AppLogger.chart(this);
  void logWebSocket() => AppLogger.websocket(this);
  void logApi() => AppLogger.api(this);
  void logOrder() => AppLogger.order(this);
  void logPrice() => AppLogger.price(this);
  void logError() => AppLogger.error(this);
  void logDebug() => AppLogger.debug(this);
  void logWarning() => AppLogger.warning(this);
}

/// Utility class for common logging patterns
class LoggingUtils {
  /// Log order placement
  static void logOrderPlacement({
    required String symbol,
    required String orderType,
    required String volume,
    String? price,
    String? takeProfit,
    String? stopLoss,
  }) {
    AppLogger.order('''
Order Placement:
- Symbol: $symbol
- Type: $orderType
- Volume: $volume
- Price: ${price ?? 'Market'}
- Take Profit: ${takeProfit ?? 'None'}
- Stop Loss: ${stopLoss ?? 'None'}
''');
  }

  /// Log price update
  static void logPriceUpdate({
    required String symbol,
    required double bidPrice,
    required double askPrice,
  }) {
    AppLogger.price('Price Update - $symbol: Bid: $bidPrice, Ask: $askPrice');
  }

  /// Log WebSocket connection status
  static void logWebSocketStatus({required String status, String? message}) {
    AppLogger.websocket(
      'WebSocket $status${message != null ? ': $message' : ''}',
    );
  }

  /// Log API call
  static void logApiCall({
    required String endpoint,
    required String method,
    Map<String, dynamic>? parameters,
    int? statusCode,
  }) {
    AppLogger.api('''
API Call:
- Endpoint: $endpoint
- Method: $method
- Parameters: ${parameters?.toString() ?? 'None'}
- Status: ${statusCode ?? 'Pending'}
''');
  }

  /// Log trading controller state
  static void logTradingState({
    required String symbol,
    required String orderType,
    required double bidPrice,
    required double askPrice,
    required double pipGapValue,
    required double pipSLTPValue,
  }) {
    AppLogger.trading('''
Trading State:
- Symbol: $symbol
- Order Type: $orderType
- Bid Price: $bidPrice
- Ask Price: $askPrice
- Pip Gap Value: $pipGapValue
- Pip SL/TP Value: $pipSLTPValue
''');
  }
}
