// import 'dart:async';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';

// class PriceAlertService {
//   static final PriceAlertService _instance = PriceAlertService._internal();
//   factory PriceAlertService() => _instance;
//   PriceAlertService._internal();

//   final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
//   bool _isInitialized = false;

//   Future<void> initialize() async {
//     if (_isInitialized) return;

//     try {
//       // Initialize notifications
//       const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//       const iosSettings = DarwinInitializationSettings();
//       const initSettings = InitializationSettings(
//         android: androidSettings,
//         iOS: iosSettings,
//       );

//       await _notifications.initialize(initSettings);
//       _isInitialized = true;
//       print('PriceAlertService: Initialized successfully');
//     } catch (e) {
//       print('PriceAlertService: Failed to initialize: $e');
//     }
//   }

//   Future<void> checkPriceAlerts(double currentPrice, String symbol) async {
//     try {
//       final alerts = await getPriceAlerts();

//       for (final alert in alerts) {
//         if (alert['symbol'] == symbol) {
//           final targetPrice = alert['price'] as double;
//           final condition = alert['condition'] as String;
//           final isTriggered = _isAlertTriggered(currentPrice, targetPrice, condition);

//           if (isTriggered && !(alert['triggered'] as bool? ?? false)) {
//             await _triggerAlert(alert, currentPrice);
//             await _markAlertAsTriggered(alert['id'] as String);
//           }
//         }
//       }
//     } catch (e) {
//       print('PriceAlertService: Error checking price alerts: $e');
//     }
//   }

//   bool _isAlertTriggered(double currentPrice, double targetPrice, String condition) {
//     switch (condition) {
//       case 'above':
//         return currentPrice >= targetPrice;
//       case 'below':
//         return currentPrice <= targetPrice;
//       default:
//         return false;
//     }
//   }

//   Future<void> _triggerAlert(Map<String, dynamic> alert, double currentPrice) async {
//     try {
//       const androidDetails = AndroidNotificationDetails(
//         'price_alerts',
//         'Price Alerts',
//         channelDescription: 'Notifications for price alerts',
//         importance: Importance.high,
//         priority: Priority.high,
//       );

//       const iosDetails = DarwinNotificationDetails();
//       const details = NotificationDetails(
//         android: androidDetails,
//         iOS: iosDetails,
//       );

//       final title = 'Price Alert: ${alert['symbol']}';
//       final body = '${alert['symbol']} is now ${currentPrice.toStringAsFixed(5)}';

//       await _notifications.show(
//         DateTime.now().millisecondsSinceEpoch ~/ 1000,
//         title,
//         body,
//         details,
//       );

//       print('PriceAlertService: Alert triggered for ${alert['symbol']}');
//     } catch (e) {
//       print('PriceAlertService: Error triggering alert: $e');
//     }
//   }

//   Future<void> _markAlertAsTriggered(String alertId) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final alertsJson = prefs.getString('price_alerts') ?? '[]';
//       final alerts = List<Map<String, dynamic>>.from(
//         jsonDecode(alertsJson).map((alert) => Map<String, dynamic>.from(alert)),
//       );

//       final index = alerts.indexWhere((alert) => alert['id'] == alertId);
//       if (index != -1) {
//         alerts[index]['triggered'] = true;
//         await prefs.setString('price_alerts', jsonEncode(alerts));
//       }
//     } catch (e) {
//       print('PriceAlertService: Error marking alert as triggered: $e');
//     }
//   }

//   Future<List<Map<String, dynamic>>> getPriceAlerts() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final alertsJson = prefs.getString('price_alerts') ?? '[]';
//       return List<Map<String, dynamic>>.from(
//         jsonDecode(alertsJson).map((alert) => Map<String, dynamic>.from(alert)),
//       );
//     } catch (e) {
//       print('PriceAlertService: Error getting price alerts: $e');
//       return [];
//     }
//   }

//   Future<void> addPriceAlert({
//     required String symbol,
//     required double price,
//     required String condition,
//     String? message,
//   }) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final alertsJson = prefs.getString('price_alerts') ?? '[]';
//       final alerts = List<Map<String, dynamic>>.from(
//         jsonDecode(alertsJson).map((alert) => Map<String, dynamic>.from(alert)),
//       );

//       final newAlert = {
//         'id': DateTime.now().millisecondsSinceEpoch.toString(),
//         'symbol': symbol,
//         'price': price,
//         'condition': condition,
//         'message': message ?? '',
//         'createdAt': DateTime.now().toIso8601String(),
//         'triggered': false,
//       };

//       alerts.add(newAlert);
//       await prefs.setString('price_alerts', jsonEncode(alerts));

//       print('PriceAlertService: Added price alert for $symbol');
//     } catch (e) {
//       print('PriceAlertService: Error adding price alert: $e');
//       rethrow;
//     }
//   }

//   Future<void> removePriceAlert(String alertId) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final alertsJson = prefs.getString('price_alerts') ?? '[]';
//       final alerts = List<Map<String, dynamic>>.from(
//         jsonDecode(alertsJson).map((alert) => Map<String, dynamic>.from(alert)),
//       );

//       alerts.removeWhere((alert) => alert['id'] == alertId);
//       await prefs.setString('price_alerts', jsonEncode(alerts));

//       print('PriceAlertService: Removed price alert $alertId');
//     } catch (e) {
//       print('PriceAlertService: Error removing price alert: $e');
//       rethrow;
//     }
//   }

//   Future<void> clearAllAlerts() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove('price_alerts');
//       print('PriceAlertService: Cleared all price alerts');
//     } catch (e) {
//       print('PriceAlertService: Error clearing price alerts: $e');
//       rethrow;
//     }
//   }
// } import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crm_app/services/notification_service.dart';

class PriceAlertService {
  static final PriceAlertService _instance = PriceAlertService._internal();
  factory PriceAlertService() => _instance;
  PriceAlertService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _hasNotificationPermission = false;

  List<PriceAlert> _activeAlerts = [];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _notifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Check and request permissions
      await _checkAndRequestPermissions();

      // Load saved alerts
      await _loadAlerts();

      _isInitialized = true;
      print('PriceAlertService initialized successfully');
    } catch (e) {
      print('Error initializing PriceAlertService: $e');
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Check Android permissions
        final androidPlugin =
            _notifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          _hasNotificationPermission = granted ?? false;
          print('Android notification permission: $_hasNotificationPermission');
        }
      } else if (Platform.isIOS) {
        // Check iOS permissions
        final iOSPlugin =
            _notifications
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        if (iOSPlugin != null) {
          final granted = await iOSPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          _hasNotificationPermission = granted ?? false;
          print('iOS notification permission: $_hasNotificationPermission');
        }
      }
    } catch (e) {
      print('Error checking permissions: $e');
      _hasNotificationPermission = false;
    }
  }

  Future<bool> hasNotificationPermission() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _hasNotificationPermission;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
    try {
      NotificationService().handleNotificationResponse(response);
    } catch (e) {
      print('PriceAlertService: Error forwarding notification tap: $e');
    }
  }

  Future<void> createPriceAlert({
    required String symbol,
    required double targetPrice,
    required bool isAbove,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final alert = PriceAlert(
      id: DateTime.now().millisecondsSinceEpoch,
      symbol: symbol,
      targetPrice: targetPrice,
      isAbove: isAbove,
      isActive: true,
      createdAt: DateTime.now(),
    );

    _activeAlerts.add(alert);
    await _saveAlerts();

    // Play alert sound for confirmation
    await _playAlertSound();

    print('Price alert created: ${alert.symbol} at ${alert.targetPrice}');
  }

  Future<void> _playAlertSound() async {
    try {
      // Try to play the custom sound file from assets
      await _audioPlayer.play(AssetSource('sounds/alert_sound.mp3'));
      print('Custom alert sound played successfully');
    } catch (e) {
      print('Error playing custom alert sound: $e');
      // Fallback to wav file if mp3 fails
      try {
        await _audioPlayer.play(AssetSource('sounds/alert_sound1.wav'));
        print('Fallback alert sound played successfully');
      } catch (e2) {
        print('Error playing fallback alert sound: $e2');
        // Final fallback - just show notification without sound
        print('Continuing without sound playback');
      }
    }
  }

  Future<void> _saveAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = _activeAlerts.map((alert) => alert.toJson()).toList();
      await prefs.setString('price_alerts', jsonEncode(alertsJson));
      print('Alerts saved successfully: ${alertsJson.length} alerts');
    } catch (e) {
      print('Error saving alerts: $e');
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsString = prefs.getString('price_alerts');
      if (alertsString != null) {
        final alertsList = jsonDecode(alertsString) as List;
        _activeAlerts =
            alertsList
                .map((alertJson) => PriceAlert.fromJson(alertJson))
                .toList();
        print('Loaded ${_activeAlerts.length} saved alerts');
      }
    } catch (e) {
      print('Error loading alerts: $e');
      _activeAlerts = [];
    }
  }

  List<PriceAlert> getActiveAlerts() => _activeAlerts;

  Future<void> deleteAlert(int alertId) async {
    _activeAlerts.removeWhere((alert) => alert.id == alertId);
    await _saveAlerts();
    await _notifications.cancel(id: alertId);
  }

  Future<void> checkPriceAlerts(double currentPrice, String symbol) async {
    if (!_isInitialized) {
      await initialize();
    }

    for (final alert in _activeAlerts) {
      if (alert.symbol == symbol && alert.isActive) {
        bool shouldTrigger = false;

        if (alert.isAbove && currentPrice >= alert.targetPrice) {
          shouldTrigger = true;
        } else if (!alert.isAbove && currentPrice <= alert.targetPrice) {
          shouldTrigger = true;
        }

        if (shouldTrigger) {
          await _triggerAlert(alert, currentPrice);
        }
      }
    }
  }

  Future<void> _triggerAlert(PriceAlert alert, double currentPrice) async {
    try {
      // Check if we have permission before showing notification
      if (!_hasNotificationPermission) {
        print('No notification permission - skipping notification');
        return;
      }

      // Show notification with custom sound
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'price_alerts',
            'Price Alerts',
            channelDescription: 'Notifications for price alerts',
            importance: Importance.high,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('alert_sound'),
            enableVibration: true,
            enableLights: true,
            playSound: true,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            sound: 'alert_sound.mp3',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notifications.show(
        id: alert.id,
        title: 'Price Alert: ${alert.symbol}',
        body: '${alert.symbol} has reached ${currentPrice.toStringAsFixed(5)}',
        notificationDetails: platformChannelSpecifics,
        payload: jsonEncode({
          'symbol': alert.symbol,
          'targetPrice': alert.targetPrice,
          'currentPrice': currentPrice,
        }),
      );

      // Play custom sound
      await _playAlertSound();

      // Deactivate alert
      alert.isActive = false;
      await _saveAlerts();

      print('Price alert triggered: ${alert.symbol}');
    } catch (e) {
      print('Error triggering alert: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }

  // Test method to verify notifications are working
  Future<void> testNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Check permission first
      if (!_hasNotificationPermission) {
        print('No notification permission - requesting permission');
        await _checkAndRequestPermissions();
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'price_alerts',
            'Price Alerts',
            channelDescription: 'Notifications for price alerts',
            importance: Importance.high,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('alert_sound'),
            enableVibration: true,
            enableLights: true,
            playSound: true,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            sound: 'alert_sound.mp3',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notifications.show(
        id: 999,
        title: 'Test Notification',
        body: 'This is a test notification for price alerts',
        notificationDetails: platformChannelSpecifics,
      );

      await _playAlertSound();
      print('Test notification sent successfully');
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  // Method to manually request permissions
  Future<bool> requestPermissions() async {
    await _checkAndRequestPermissions();
    return _hasNotificationPermission;
  }
}

class PriceAlert {
  final int id;
  final String symbol;
  final double targetPrice;
  final bool isAbove;
  bool isActive;
  final DateTime createdAt;

  PriceAlert({
    required this.id,
    required this.symbol,
    required this.targetPrice,
    required this.isAbove,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'targetPrice': targetPrice,
      'isAbove': isAbove,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      id: json['id'],
      symbol: json['symbol'],
      targetPrice: json['targetPrice'].toDouble(),
      isAbove: json['isAbove'],
      isActive: json['isActive'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
