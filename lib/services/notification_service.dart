import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isInitialized = false;
  bool _hasPermission = false;

  // Notification channel IDs
  static const String _priceAlertChannelId = 'price_alerts';
  static const String _priceAlertChannelName = 'Price Alerts';
  static const String _priceAlertChannelDescription =
      'Notifications for price alerts';

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Initialize Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize iOS settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Initialize settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();

    _isInitialized = true;

    // Check permission status
    await _checkPermissionStatus();

    // Setup FCM Foreground listeners
    await setupFCMListeners();
  }

  Future<void> _createNotificationChannels() async {
    // Android channels are automatically created when showing notifications
    // with the newer version of flutter_local_notifications
  }

  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Request notification permission
    PermissionStatus status = await Permission.notification.request();

    if (status.isGranted) {
      _hasPermission = true;
      return true;
    } else if (status.isDenied) {
      // Show dialog explaining why we need permission
      return false;
    } else if (status.isPermanentlyDenied) {
      // Open app settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  Future<bool> _checkPermissionStatus() async {
    PermissionStatus status = await Permission.notification.status;
    _hasPermission = status.isGranted;
    return _hasPermission;
  }

  Future<void> setupFCMListeners() async {
    // Some flavors/builds may not include Firebase configuration (no google-services.json),
    // or Firebase initialization may fail. In that case, skip FCM setup gracefully.
    if (Firebase.apps.isEmpty) {
      debugPrint('FCM: Firebase not initialized; skipping FCM listeners');
      return;
    }

    try {
    // 1. Configure iOS/macOS foreground visibility
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // 2. Listen to foreground messages and show heads-up notification manually if needed by Android
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );

        // Show local notification for Android (iOS handles it automatically if presentation options are set)
        _showLocalNotification(message);
      }
    });
    } catch (e, st) {
      debugPrint('FCM: Failed to set up listeners: $e');
      debugPrint('$st');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel', // id
          'High Importance Notifications', // title
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      message.notification.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: json.encode(message.data),
    );
  }

  bool get hasPermission => _hasPermission;

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    // Handle notification tap
    if (response.payload != null) {
      try {
        Map<String, dynamic> payload = json.decode(response.payload!);
        // Navigate to specific screen based on payload
        // You can implement navigation logic here
        debugPrint('Notification tapped: $payload');
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  Future<void> schedulePriceAlert({
    required String symbol,
    required double targetPrice,
    required String condition, // 'above' or 'below'
    required double currentPrice,
    String? message,
  }) async {
    if (!_hasPermission) {
      throw Exception('Notification permission not granted');
    }

    // Generate unique ID for this alert
    final int alertId = DateTime.now().millisecondsSinceEpoch % 100000;

    // Create notification payload
    final Map<String, dynamic> payload = {
      'symbol': symbol,
      'targetPrice': targetPrice,
      'condition': condition,
      'currentPrice': currentPrice,
      'message': message,
      'alertId': alertId,
    };

    // Create notification details
    final NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _priceAlertChannelId,
        _priceAlertChannelName,
        channelDescription: _priceAlertChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        sound: const RawResourceAndroidNotificationSound('alert_sound'),
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF2196F3),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          _buildNotificationContent(
            symbol,
            targetPrice,
            condition,
            currentPrice,
            message,
          ),
          htmlFormatBigText: true,
          contentTitle: _buildNotificationTitle(symbol, condition),
          htmlFormatContentTitle: true,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alert_sound.mp3',
      ),
    );

    debugPrint('🔔 ===== SCHEDULING PRICE ALERT =====');
    debugPrint('📊 Symbol: $symbol');
    debugPrint('💰 Target: ${targetPrice.toStringAsFixed(5)}');
    debugPrint('📈 Current: ${currentPrice.toStringAsFixed(5)}');
    debugPrint('🎯 Condition: $condition');
    debugPrint('🆔 Alert ID: $alertId');

    try {
      debugPrint('📱 Showing notification...');
      // Show notification immediately
      await _notifications.show(
        alertId,
        _buildNotificationTitle(symbol, condition),
        _buildNotificationContent(
          symbol,
          targetPrice,
          condition,
          currentPrice,
          message,
        ),
        notificationDetails,
        payload: json.encode(payload),
      );
      debugPrint('✅ Notification displayed successfully');

      debugPrint('🔊 Playing alert sound...');
      // Play sound immediately
      await _playAlertSound();
      debugPrint('✅ Alert sound played successfully');

      debugPrint('🔔 ===== PRICE ALERT COMPLETE =====');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
      rethrow; // Re-throw to let the retry mechanism handle it
    }
  }

  String _buildNotificationTitle(String symbol, String condition) {
    return 'Price Alert: $symbol ${condition == 'above' ? '↑' : '↓'}';
  }

  String _buildNotificationContent(
    String symbol,
    double targetPrice,
    String condition,
    double currentPrice,
    String? message,
  ) {
    String content =
        '$symbol price is ${condition == 'above' ? 'above' : 'below'} \$${targetPrice.toStringAsFixed(5)}';

    if (message != null && message.isNotEmpty) {
      content += '\n\n$message';
    }

    return content;
  }

  Future<void> _playAlertSound() async {
    try {
      // Play the alert sound from assets
      await _audioPlayer.play(AssetSource('audio/alert_sound.mp3'));
    } catch (e) {
      try {
        // Fallback: try alternative path
        await _audioPlayer.play(AssetSource('alert_sound.mp3'));
      } catch (e2) {
        debugPrint('Error playing alert sound: $e2');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getActivePriceAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> alerts = prefs.getStringList('price_alerts') ?? [];

      final List<Map<String, dynamic>> activeAlerts = [];

      for (String alertStr in alerts) {
        try {
          final Map<String, dynamic> alert = json.decode(alertStr);
          if (alert['isActive'] == true) {
            activeAlerts.add(alert);
          }
        } catch (e) {
          debugPrint('Error parsing alert: $e');
        }
      }

      return activeAlerts;
    } catch (e) {
      debugPrint('Error getting active alerts: $e');
      return [];
    }
  }

  Future<void> cancelPriceAlert(int alertId) async {
    try {
      // Cancel the scheduled notification
      await _notifications.cancel(alertId);

      // Update local storage
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
      debugPrint('Error canceling alert: $e');
    }
  }

  Future<void> cancelAllPriceAlerts() async {
    try {
      await _notifications.cancelAll();

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('price_alerts');
    } catch (e) {
      debugPrint('Error canceling all alerts: $e');
    }
  }

  Future<void> showTestNotification() async {
    if (!_hasPermission) {
      bool granted = await requestPermissions();
      if (!granted) {
        throw Exception('Notification permission not granted');
      }
    }

    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _priceAlertChannelId,
        _priceAlertChannelName,
        channelDescription: _priceAlertChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('alert_sound'),
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alert_sound.mp3',
      ),
    );

    await _notifications.show(
      999,
      'Test Price Alert',
      'This is a test notification for price alerts',
      notificationDetails,
    );

    // Play sound
    await _playAlertSound();
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
