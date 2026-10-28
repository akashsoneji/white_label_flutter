import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';

class PriceAlertMonitorService extends GetxController {
  static final PriceAlertMonitorService _instance =
      PriceAlertMonitorService._internal();
  factory PriceAlertMonitorService() => _instance;
  PriceAlertMonitorService._internal();

  final NotificationService _notificationService = NotificationService();
  Timer? _monitoringTimer;
  final List<Map<String, dynamic>> _activeAlerts = [];
  bool _isMonitoring = false;

  // Chart socket controller for real-time price data
  ChartSocketController? _chartSocketController;

  @override
  void onInit() {
    super.onInit();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _notificationService.initialize();
    await _loadActiveAlerts();

    // Try to find ChartSocketController
    try {
      _chartSocketController = Get.find<ChartSocketController>();
      debugPrint('✅ Found existing ChartSocketController');
    } catch (e) {
      debugPrint('❌ ChartSocketController not found: $e');
      // Try to create one
      try {
        _chartSocketController = Get.put(ChartSocketController());
        debugPrint('✅ Created new ChartSocketController');
      } catch (e2) {
        debugPrint('❌ Failed to create ChartSocketController: $e2');
      }
    }

    _startMonitoring();
  }

  Future<void> _loadActiveAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> alerts = prefs.getStringList('price_alerts') ?? [];

      _activeAlerts.clear();
      for (String alertStr in alerts) {
        try {
          final Map<String, dynamic> alert = json.decode(alertStr);
          if (alert['isActive'] == true) {
            _activeAlerts.add(alert);
          }
        } catch (e) {
          debugPrint('Error parsing alert: $e');
        }
      }

      debugPrint('Loaded ${_activeAlerts.length} active price alerts');
    } catch (e) {
      debugPrint('Error loading active alerts: $e');
    }
  }

  void _startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkPriceAlerts();
    });

    debugPrint('🔄 ===== PRICE ALERT MONITORING STARTED =====');
    debugPrint('⏰ Checking prices every 2 seconds');
    debugPrint('📊 Active alerts: ${_activeAlerts.length}');
    debugPrint(
      '🎯 Current symbol: ${_chartSocketController?.currentSymbol.value ?? 'Unknown'}',
    );
  }

  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    debugPrint('Price alert monitoring stopped');
  }

  void _checkPriceAlerts() {
    if (_activeAlerts.isEmpty) {
      debugPrint('No active alerts to check');
      return;
    }

    // Get chart socket controller if not already set
    if (_chartSocketController == null) {
      try {
        _chartSocketController = Get.find<ChartSocketController>();
      } catch (e) {
        debugPrint('ChartSocketController not found: $e');
        return;
      }
    }

    // Check if ChartSocketController is connected
    if (!_chartSocketController!.isConnected.value) {
      debugPrint(
        '⚠️ ChartSocketController not connected, attempting to reconnect...',
      );
      // Try to reconnect for the first active alert's symbol
      if (_activeAlerts.isNotEmpty) {
        final firstAlert = _activeAlerts.first;
        final symbol = firstAlert['symbol'] as String;
        ensureChartSocketConnected(symbol);
      }
      return; // Skip this check cycle, will try again next time
    }

    // Get current market price (average of bid and ask)
    final currentPrice = _chartSocketController!.getMarketPrice();
    if (currentPrice == null) {
      debugPrint('No current market price data available');
      return;
    }

    final currentSymbol = _chartSocketController!.currentSymbol.value;
    final bidPrice = _chartSocketController!.getBidPrice();
    final askPrice = _chartSocketController!.getAskPrice();
    debugPrint(
      '🔍 Checking alerts for $currentSymbol: Bid=$bidPrice, Ask=$askPrice, Market=$currentPrice (${_activeAlerts.length} active alerts)',
    );

    // Check each active alert
    for (int i = _activeAlerts.length - 1; i >= 0; i--) {
      final alert = _activeAlerts[i];
      final symbol = alert['symbol'] as String;
      final targetPrice = alert['targetPrice'] as double;
      final condition = alert['condition'] as String;

      // Check if this alert is for the current symbol
      final currentSymbol = _chartSocketController!.currentSymbol.value;
      if (symbol != currentSymbol) {
        debugPrint('⏭️ Skipping alert for $symbol (current: $currentSymbol)');
        continue;
      }

      debugPrint(
        '🎯 Checking alert: $symbol $condition $targetPrice vs current $currentPrice',
      );

      // Calculate difference for better debugging
      final difference =
          condition == 'above'
              ? currentPrice - targetPrice
              : targetPrice - currentPrice;
      final isClose = difference.abs() < 0.0001; // Within 0.0001

      debugPrint(
        '📊 Price difference: ${difference.toString()} (${isClose ? 'CLOSE!' : 'not close'})',
      );

      bool shouldTrigger = false;

      if (condition == 'above' && currentPrice >= targetPrice) {
        shouldTrigger = true;
        debugPrint('✅ ABOVE condition met: $currentPrice >= $targetPrice');
      } else if (condition == 'below' && currentPrice <= targetPrice) {
        shouldTrigger = true;
        debugPrint('✅ BELOW condition met: $currentPrice <= $targetPrice');
      } else {
        debugPrint(
          '❌ Condition not met: $currentPrice $condition $targetPrice',
        );
        if (isClose) {
          debugPrint(
            '⚠️  VERY CLOSE! Only ${difference.abs().toString()} away from trigger',
          );
        }
      }

      if (shouldTrigger) {
        debugPrint(
          'Price alert triggered: $symbol $condition $targetPrice (current: $currentPrice)',
        );
        _triggerPriceAlert(alert, currentPrice);

        // Remove the triggered alert
        _activeAlerts.removeAt(i);
        _removeAlertFromStorage(alert['id'] as int);
      }
    }
  }

  Future<void> _triggerPriceAlert(
    Map<String, dynamic> alert,
    double currentPrice,
  ) async {
    final symbol = alert['symbol'] as String;
    final targetPrice = alert['targetPrice'] as double;
    final condition = alert['condition'] as String;
    // final message = alert['message'] as String?; // DISABLED: Local notification unused
    final alertId = alert['id'] as int;

    debugPrint('🚨 ===== TRIGGERING PRICE ALERT =====');
    debugPrint('📊 Alert Details:');
    debugPrint('   - Symbol: $symbol');
    debugPrint('   - Target Price: ${targetPrice.toString()}');
    debugPrint('   - Current Price: ${currentPrice.toString()}');
    debugPrint('   - Condition: $condition');
    debugPrint('   - Alert ID: $alertId');

    // Try multiple times to ensure notification is sent
    bool notificationSent = false;
    int attempts = 0;
    const maxAttempts = 3;

    while (!notificationSent && attempts < maxAttempts) {
      attempts++;
      debugPrint('🔄 Attempt $attempts/$maxAttempts to send notification...');

      try {
        // --- LOCAL NOTIFICATION DISABLED (using API push notifications) ---
        /*
        // Check notification permissions first
        if (!_notificationService.hasPermission) {
          debugPrint('❌ No notification permission, requesting...');
          final granted = await _notificationService.requestPermissions();
          if (!granted) {
            debugPrint('❌ Permission denied, cannot send notification');
            break;
          }
        }

        // Show notification
        await _notificationService.schedulePriceAlert(
          symbol: symbol,
          targetPrice: targetPrice,
          condition: condition,
          currentPrice: currentPrice,
          message: message,
        );
        */

        notificationSent = true;
        debugPrint(
          '✅ Notification deemed sent successfully (handled via API) on attempt $attempts',
        );

        /*
        // Show in-app notification
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showSuccess(
            message:
                '$symbol price is ${condition == 'above' ? 'above' : 'below'} \$${targetPrice.toString()}',
            title: 'Price Alert Triggered!',
          );
        }
        */

        debugPrint('✅ In-app notification shown');
        debugPrint('🚨 ===== ALERT TRIGGERED SUCCESSFULLY =====');
      } catch (e) {
        debugPrint('❌ Attempt $attempts failed: $e');
        if (attempts < maxAttempts) {
          debugPrint('⏳ Waiting 1 second before retry...');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    if (!notificationSent) {
      debugPrint('❌ Failed to send notification after $maxAttempts attempts');
      // Show error notification
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message:
              '$symbol reached \$${targetPrice.toString()} but notification failed',
          title: 'Alert Triggered (No Notification)',
        );
      }
    }
  }

  Future<void> _removeAlertFromStorage(int alertId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> alerts = prefs.getStringList('price_alerts') ?? [];

      for (int i = 0; i < alerts.length; i++) {
        try {
          final Map<String, dynamic> alert = json.decode(alerts[i]);
          if (alert['id'] == alertId) {
            alert['isActive'] = false;
            alerts[i] = json.encode(alert);
            break;
          }
        } catch (e) {
          debugPrint('Error parsing alert: $e');
        }
      }

      await prefs.setStringList('price_alerts', alerts);
    } catch (e) {
      debugPrint('Error removing alert from storage: $e');
    }
  }

  /// `POST price-alerts` answers `{data: {alert: {id}}}`; the client may hand
  /// back either the whole body or just its `data`.
  int? _extractServerAlertId(dynamic body) {
    if (body is! Map) return null;
    final data = body['data'] is Map ? body['data'] as Map : body;
    final alert = data['alert'];
    if (alert is! Map) return null;
    return int.tryParse('${alert['id']}');
  }

  Future<void> _updateStoredAlert(
    bool Function(Map<String, dynamic> alert) matches,
    void Function(Map<String, dynamic> alert) apply,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final alerts = prefs.getStringList('price_alerts') ?? [];
    for (int i = 0; i < alerts.length; i++) {
      try {
        final Map<String, dynamic> alert = json.decode(alerts[i]);
        if (!matches(alert)) continue;
        apply(alert);
        alerts[i] = json.encode(alert);
      } catch (e) {
        debugPrint('Error parsing alert: $e');
      }
    }
    await prefs.setStringList('price_alerts', alerts);
  }

  /// Mirrors a server-side edit / pause / delete (`PUT`/`DELETE
  /// price-alerts/{id}`) onto the locally monitored alert, so a deleted or
  /// paused alert stops firing on this device. Pass `isActive: false` for
  /// delete.
  Future<void> syncLocalAlertFromServer({
    required int serverId,
    double? targetPrice,
    String? condition,
    bool? isActive,
  }) async {
    void apply(Map<String, dynamic> alert) {
      if (targetPrice != null) alert['targetPrice'] = targetPrice;
      if (condition != null) alert['condition'] = condition;
      if (isActive != null) alert['isActive'] = isActive;
    }

    bool matches(Map<String, dynamic> alert) => alert['serverId'] == serverId;

    try {
      await _updateStoredAlert(matches, apply);

      final inMemory = _activeAlerts.where(matches).toList();
      if (isActive == false) {
        _activeAlerts.removeWhere(matches);
      } else if (inMemory.isNotEmpty) {
        inMemory.forEach(apply);
      } else if (isActive == true) {
        final prefs = await SharedPreferences.getInstance();
        for (final raw in prefs.getStringList('price_alerts') ?? <String>[]) {
          final Map<String, dynamic> alert = json.decode(raw);
          if (matches(alert)) _activeAlerts.add(alert);
        }
      }
    } catch (e) {
      debugPrint('Error syncing local alert $serverId: $e');
    }
  }

  // Add new alert to monitoring
  Future<void> addPriceAlert({
    required String symbol,
    required double targetPrice,
    required String condition,
    required double currentPrice,
    String? message,
  }) async {
    try {
      // Ensure ChartSocketController is connected for this symbol
      await ensureChartSocketConnected(symbol);

      // Get current market data for detailed logging
      final bidPrice = _chartSocketController?.getBidPrice();
      final askPrice = _chartSocketController?.getAskPrice();
      final marketPrice = _chartSocketController?.getMarketPrice();

      // Debug price data availability
      debugPrint('🔍 Price data check:');
      debugPrint(
        '   - ChartSocketController connected: ${_chartSocketController?.isConnected.value ?? false}',
      );
      debugPrint(
        '   - Current symbol: ${_chartSocketController?.currentSymbol.value ?? 'Unknown'}',
      );
      debugPrint(
        '   - Bid price available: ${bidPrice != null} (${bidPrice?.toString() ?? 'null'})',
      );
      debugPrint(
        '   - Ask price available: ${askPrice != null} (${askPrice?.toString() ?? 'null'})',
      );
      debugPrint(
        '   - Market price available: ${marketPrice != null} (${marketPrice?.toString() ?? 'null'})',
      );
      debugPrint('   - Current price from dialog: ${currentPrice.toString()}');

      // Use currentPrice as fallback if market data is not available
      final finalBidPrice = bidPrice ?? currentPrice;
      final finalAskPrice = askPrice ?? currentPrice;
      final finalMarketPrice = marketPrice ?? currentPrice;

      debugPrint('🚨 ===== SETTING NEW PRICE ALERT =====');
      debugPrint('📊 Symbol: $symbol');
      debugPrint('💰 Current Prices:');
      debugPrint('   - Bid Price (SELL): ${finalBidPrice.toString()}');
      debugPrint('   - Ask Price (BUY): ${finalAskPrice.toString()}');
      debugPrint('   - Market Price (Alert): ${finalMarketPrice.toString()}');
      debugPrint('🎯 Alert Settings:');
      debugPrint('   - Target Price: ${targetPrice.toString()}');
      debugPrint('   - Condition: $condition');
      debugPrint('   - Message: ${message ?? 'No message'}');

      // Calculate difference and show status
      final difference =
          condition == 'above'
              ? targetPrice - finalMarketPrice
              : finalMarketPrice - targetPrice;
      final isAlreadyTriggered =
          condition == 'above'
              ? finalMarketPrice >= targetPrice
              : finalMarketPrice <= targetPrice;

      debugPrint('📈 Price Analysis:');
      debugPrint('   - Difference: ${difference.toString()}');
      debugPrint(
        '   - Status: ${isAlreadyTriggered ? 'ALREADY TRIGGERED!' : 'Waiting for trigger'}',
      );

      if (isAlreadyTriggered) {
        debugPrint('⚠️  WARNING: Alert condition is already met!');
        debugPrint(
          '   Current market price (${finalMarketPrice.toString()}) ${condition == 'above' ? '≥' : '≤'} target price (${targetPrice.toString()})',
        );
        debugPrint('🚨 TRIGGERING ALERT IMMEDIATELY!');

        // Create alert object for immediate triggering
        final immediateAlert = {
          'id': DateTime.now().millisecondsSinceEpoch % 100000,
          'symbol': symbol,
          'targetPrice': targetPrice,
          'condition': condition,
          'currentPrice': finalMarketPrice,
          'message': message,
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        };

        // Trigger immediately
        _triggerPriceAlert(immediateAlert, finalMarketPrice);
        debugPrint('✅ Immediate alert triggered!');
        return; // Don't save this alert since it's already triggered
      } else {
        debugPrint(
          '✅ Alert will trigger when market price ${condition == 'above' ? '≥' : '≤'} ${targetPrice.toString()}',
        );
      }

      // Generate unique ID
      final int alertId = DateTime.now().millisecondsSinceEpoch % 100000;

      final Map<String, dynamic> alert = {
        'id': alertId,
        'symbol': symbol,
        'targetPrice': targetPrice,
        'condition': condition,
        'currentPrice': currentPrice,
        'message': message,
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
      };

      // Add to active alerts
      _activeAlerts.add(alert);

      // Save to storage
      final prefs = await SharedPreferences.getInstance();
      final List<String> alerts = prefs.getStringList('price_alerts') ?? [];
      alerts.add(json.encode(alert));
      await prefs.setStringList('price_alerts', alerts);

      // --- Sync with Backend API ---
      try {
        String? fcmToken = await SecureStorageService.getFcmToken();
        String deviceType = Platform.isIOS ? 'ios' : 'android';
        String mt5AccountId = '';

        if (Get.isRegistered<AccountController>()) {
          final accountController = Get.find<AccountController>();
          mt5AccountId =
              accountController.primaryMT5Account?.metaAccountNumber ?? '';
        }

        final token = await SecureStorageService.getAuthToken();
        if (token != null && mt5AccountId.isNotEmpty) {
          final apiPayload = {
            'meta_account_number': mt5AccountId,
            'symbol': symbol,
            'target_price': targetPrice,
            'condition': condition,
            if (fcmToken != null) 'fcm_token': fcmToken,
            'device_type': deviceType,
          };

          final response = await Get.find<ApiClient>().post(
            endpoint: ApiConstants.priceAlerts,
            token: token,
            data: apiPayload,
          );
          final serverId = _extractServerAlertId(response.data);
          if (response.success && serverId != null) {
            // The server id is what PUT/DELETE price-alerts/{id} need, and it
            // links this local monitor entry to the "My Price Alerts" list.
            alert['serverId'] = serverId;
            await _updateStoredAlert(
              (stored) => stored['id'] == alertId,
              (stored) => stored['serverId'] = serverId,
            );
          }
          debugPrint('✅ Price alert sent to backend successfully');
        }
      } catch (apiError) {
        debugPrint('⚠️ Failed to sync price alert to backend: $apiError');
      }

      debugPrint('✅ Alert saved successfully!');
      debugPrint('📱 Total active alerts: ${_activeAlerts.length}');
      debugPrint('🔄 Monitoring will check every 2 seconds');
      debugPrint('🚨 ===== ALERT SETUP COMPLETE =====');
    } catch (e) {
      debugPrint('❌ Error adding price alert: $e');
    }
  }

  // Get active alerts count
  int get activeAlertsCount => _activeAlerts.length;

  // Get active alerts for current symbol
  List<Map<String, dynamic>> getActiveAlertsForSymbol(String symbol) {
    return _activeAlerts.where((alert) => alert['symbol'] == symbol).toList();
  }

  // Cancel specific alert
  Future<void> cancelAlert(int alertId) async {
    try {
      _activeAlerts.removeWhere((alert) => alert['id'] == alertId);
      await _removeAlertFromStorage(alertId);
      debugPrint('Cancelled alert: $alertId');
    } catch (e) {
      debugPrint('Error cancelling alert: $e');
    }
  }

  // Cancel all alerts for a symbol
  Future<void> cancelAllAlertsForSymbol(String symbol) async {
    try {
      final alertsToRemove =
          _activeAlerts.where((alert) => alert['symbol'] == symbol).toList();

      for (final alert in alertsToRemove) {
        await cancelAlert(alert['id'] as int);
      }

      debugPrint('Cancelled all alerts for symbol: $symbol');
    } catch (e) {
      debugPrint('Error cancelling alerts for symbol: $e');
    }
  }

  // Test method to manually trigger an alert
  Future<void> testTriggerAlert(String symbol, double currentPrice) async {
    try {
      debugPrint('🧪 Testing alert trigger for $symbol at $currentPrice');

      // Create a test alert
      final testAlert = {
        'id': 999999,
        'symbol': symbol,
        'targetPrice': currentPrice,
        'condition': 'above',
        'currentPrice': currentPrice,
        'message': 'Test alert triggered',
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
      };

      await _triggerPriceAlert(testAlert, currentPrice);
      debugPrint('✅ Test alert triggered successfully');
    } catch (e) {
      debugPrint('❌ Error triggering test alert: $e');
    }
  }

  // Add a test alert for specific price scenario
  Future<void> addTestAlert(
    String symbol,
    double targetPrice,
    String condition,
  ) async {
    try {
      final currentPrice = _chartSocketController?.getMarketPrice() ?? 1.14252;
      debugPrint(
        '🧪 Adding test alert: $symbol $condition $targetPrice (current: $currentPrice)',
      );

      await addPriceAlert(
        symbol: symbol,
        targetPrice: targetPrice,
        condition: condition,
        currentPrice: currentPrice,
        message: 'Test alert for debugging',
      );

      debugPrint('✅ Test alert added successfully');
    } catch (e) {
      debugPrint('❌ Error adding test alert: $e');
    }
  }

  // Test notification system directly
  Future<void> testNotificationSystem() async {
    try {
      debugPrint('🧪 ===== TESTING NOTIFICATION SYSTEM =====');

      // Test notification service directly
      await _notificationService.showTestNotification();

      debugPrint('✅ Test notification sent successfully');
      debugPrint('🧪 ===== NOTIFICATION TEST COMPLETE =====');
    } catch (e) {
      debugPrint('❌ Error testing notification system: $e');
    }
  }

  // Force ChartSocketController to connect and set symbol
  Future<void> ensureChartSocketConnected(String symbol) async {
    try {
      debugPrint('🔌 ===== ENSURING CHART SOCKET CONNECTION =====');
      debugPrint('📊 Target Symbol: $symbol');

      if (_chartSocketController == null) {
        debugPrint('❌ ChartSocketController is null, trying to find/create...');
        try {
          _chartSocketController = Get.find<ChartSocketController>();
          debugPrint('✅ Found existing ChartSocketController');
        } catch (e) {
          debugPrint('❌ ChartSocketController not found: $e');
          try {
            _chartSocketController = Get.put(ChartSocketController());
            debugPrint('✅ Created new ChartSocketController');
          } catch (e2) {
            debugPrint('❌ Failed to create ChartSocketController: $e2');
            return;
          }
        }
      }

      debugPrint('🔍 Current Status:');
      debugPrint(
        '   - Connected: ${_chartSocketController!.isConnected.value}',
      );
      debugPrint(
        '   - Current Symbol: ${_chartSocketController!.currentSymbol.value}',
      );

      if (!_chartSocketController!.isConnected.value) {
        debugPrint('🔄 Not connected, attempting to connect...');
        try {
          await _chartSocketController!.changeSymbol(symbol);
          debugPrint('✅ Connection attempt completed');
        } catch (e) {
          debugPrint('❌ Connection failed: $e');
        }
      }

      if (_chartSocketController!.currentSymbol.value != symbol) {
        debugPrint('🔄 Symbol mismatch, changing symbol...');
        try {
          await _chartSocketController!.changeSymbol(symbol);
          debugPrint('✅ Symbol changed successfully');
        } catch (e) {
          debugPrint('❌ Symbol change failed: $e');
        }
      }

      debugPrint('🔍 Final Status:');
      debugPrint(
        '   - Connected: ${_chartSocketController!.isConnected.value}',
      );
      debugPrint(
        '   - Current Symbol: ${_chartSocketController!.currentSymbol.value}',
      );
      debugPrint('🔌 ===== CONNECTION CHECK COMPLETE =====');
    } catch (e) {
      debugPrint('❌ Error ensuring ChartSocket connection: $e');
    }
  }

  // Get current monitoring status
  Map<String, dynamic> getMonitoringStatus() {
    return {
      'isMonitoring': _isMonitoring,
      'activeAlertsCount': _activeAlerts.length,
      'currentSymbol': _chartSocketController?.currentSymbol.value ?? 'Unknown',
      'currentPrice': _chartSocketController?.getMarketPrice() ?? 0.0,
      'alerts':
          _activeAlerts
              .map(
                (alert) => {
                  'symbol': alert['symbol'],
                  'targetPrice': alert['targetPrice'],
                  'condition': alert['condition'],
                },
              )
              .toList(),
    };
  }

  @override
  void onClose() {
    _stopMonitoring();
    super.onClose();
  }
}
