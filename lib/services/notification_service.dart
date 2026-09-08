import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:crm_app/constants/color.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_hub_controller.dart';
import 'package:crm_app/screens/home/trading_main_screen.dart';

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
    // Explicitly create the high-importance channel so Android 8+ shows
    // heads-up banners while the app is in the foreground. Without this,
    // some OEM devices suppress the pop-up because the channel importance
    // isn't registered until the first notification is shown.
    const AndroidNotificationChannel highImportanceChannel =
        AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highImportanceChannel);
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
      // Print FCM token for debugging
      String? token = await FirebaseMessaging.instance.getToken();
      debugPrint('\n=============================================');
      debugPrint('🔔 FCM TOKEN FOR TESTING:');
      debugPrint(token ?? 'Failed to get token');
      debugPrint('=============================================\n');

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM TOKEN REFRESHED: $newToken');
      });

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
        debugPrint('========== RAW FCM FOREGROUND PAYLOAD (JSON) ==========');
        debugPrint(jsonEncode(message.toMap()));
        debugPrint('=======================================================');

        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );

          // Show local notification for Android (iOS handles it automatically if presentation options are set)
          _showLocalNotification(message);
        }
      });

      // 3. Listen to messages when app is in the background and opened by user
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from background via notification! Payload: ${message.data}');
        _handleNotificationRedirection(message.data);
      });

      // 4. Check for initial message if app opened from terminated/killed state
      await setupInteractedMessage();

    } catch (e, st) {
      debugPrint('FCM: Failed to set up listeners: $e');
      debugPrint('$st');
    }
  }

  /// Handles notification message if the app was launched from a terminated/killed state
  Future<void> setupInteractedMessage() async {
    try {
      // 1. Check FCM RemoteMessage from killed state
      if (Firebase.apps.isNotEmpty) {
        RemoteMessage? initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();

        if (initialMessage != null && initialMessage.data.isNotEmpty) {
          debugPrint('🔔 [NOTIFICATION REDIRECTION] Initial FCM message received from killed state: ${initialMessage.data}');
          await _handleNotificationRedirection(initialMessage.data);
          return;
        }
      }

      // 2. Check local notifications plugin from killed state
      final launchDetails = await _notifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payloadStr = launchDetails.notificationResponse?.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          try {
            final Map<String, dynamic> data = json.decode(payloadStr);
            debugPrint('🔔 [NOTIFICATION REDIRECTION] Initial local notification received from killed state: $data');
            await _handleNotificationRedirection(data);
          } catch (e) {
            debugPrint('🔔 [NOTIFICATION REDIRECTION] Error parsing local notification launch payload: $e');
          }
        }
      }
    } catch (e, st) {
      debugPrint('🔔 [NOTIFICATION REDIRECTION] Error in setupInteractedMessage: $e\n$st');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    String? imageUrl;
    
    // Check various places for image URL in the payload
    if (Platform.isAndroid && message.notification?.android?.imageUrl != null) {
      imageUrl = message.notification!.android!.imageUrl;
    } else if (Platform.isIOS && message.notification?.apple?.imageUrl != null) {
      imageUrl = message.notification!.apple!.imageUrl;
    } else if (message.data['image'] != null) {
      imageUrl = message.data['image'];
    }

    String? bigPicturePath;
    StyleInformation? styleInformation;
    List<DarwinNotificationAttachment>? iosAttachments;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        bigPicturePath = await _downloadAndSaveFile(imageUrl, 'notification_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        if (Platform.isAndroid) {
          styleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(bigPicturePath),
            hideExpandedLargeIcon: false,
          );
        } else if (Platform.isIOS) {
          iosAttachments = [DarwinNotificationAttachment(bigPicturePath)];
        }
      } catch (e) {
        debugPrint('Error downloading notification image: $e');
      }
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel', // id
          'High Importance Notifications', // title
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: styleInformation,
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      attachments: iosAttachments,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      message.notification?.hashCode ?? DateTime.now().millisecond,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: json.encode(message.data),
    );
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  bool get hasPermission => _hasPermission;

  // Store pending redirection if the app is still starting up
  static Map<String, dynamic>? _pendingRedirectionData;

  Future<void> _handleNotificationRedirection(Map<String, dynamic> data) async {
    debugPrint('🔔 [NOTIFICATION REDIRECTION] Started. Payload data: $data');
    if (data['type'] == null || data['type'].toString().trim().isEmpty) {
      debugPrint('🔔 [NOTIFICATION REDIRECTION] type is null or empty. Aborting.');
      return;
    }

    // Check if user is logged in
    bool isLoggedIn = false;
    if (Get.isRegistered<AuthController>()) {
      isLoggedIn = Get.find<AuthController>().isAuthenticated;
    }
    if (!isLoggedIn) {
      final token = await SecureStorageService.getAuthToken();
      isLoggedIn = token != null && token.isNotEmpty;
    }
    
    debugPrint('🔔 [NOTIFICATION REDIRECTION] isLoggedIn: $isLoggedIn');
    if (!isLoggedIn) {
      debugPrint('🔔 [NOTIFICATION REDIRECTION] User is not logged in. Ignoring redirection.');
      _pendingRedirectionData = null;
      return;
    }

    String type = data['type'].toString().trim();
    debugPrint('🔔 [NOTIFICATION REDIRECTION] Type is: $type');

    // If the app is currently in splash / auth check screen, save for after home mounts
    final currentRoute = Get.currentRoute;
    debugPrint('🔔 [NOTIFICATION REDIRECTION] Current route: $currentRoute');
    if (currentRoute.isEmpty ||
        currentRoute == '/' ||
        currentRoute == AppPages.SPLASH ||
        currentRoute == AppPages.GET_STARTED ||
        currentRoute == '/AuthCheckScreen') {
      debugPrint('🔔 [NOTIFICATION REDIRECTION] App is still in startup/auth check. Storing pending redirection.');
      _pendingRedirectionData = data;
      return;
    }

    // Otherwise execute routing immediately
    _executeRouting(type, data);
  }

  void processPendingNotification() {
    if (_pendingRedirectionData != null) {
      debugPrint('🔔 [NOTIFICATION REDIRECTION] Processing pending notification now that main screen is loaded: $_pendingRedirectionData');
      final data = Map<String, dynamic>.from(_pendingRedirectionData!);
      String type = data['type']?.toString().trim() ?? '';
      _pendingRedirectionData = null;
      if (type.isNotEmpty) {
        // Wait 350ms to allow GetX stack transition (Get.offAllNamed(AppPages.TRADING)) to finish completely
        Future.delayed(const Duration(milliseconds: 350), () {
          _executeRouting(type, data);
        });
      }
    }
  }

  void _executeRouting(String type, [Map<String, dynamic>? data]) {
    debugPrint('🔔 [NOTIFICATION REDIRECTION] Executing routing for type: $type');
    try {
      switch (type) {
        // Ignored types: Just open the app without redirecting to a sub-screen
        case 'mt5_credentials':
        case 'leverage_change':
        case 'email_failed':
        case 'trading_restriction':
          debugPrint('🔔 [NOTIFICATION REDIRECTION] Type "$type" ignored - opening app only.');
          break;

        // KYC / Compliance: Navigate to 5th bottom tab (More / Assets / Dashboard at index 4)
        case 'kyc_status':
        case 'kyc_request':
        case 'kyc':
          _navigateToMainTab(4);
          break;

        // Financial & Transactions
        case 'deposit':
        case 'deposit_request':
        case 'withdraw':
        case 'withdraw_request':
        case 'withdrawal_request':
          Get.toNamed(AppPages.TRANSACTION_HISTORY);
          break;
        case 'internal_transfer':
          Get.toNamed(AppPages.INTERNAL_TRANSFER_HISTORY);
          break;
        case 'bonus_request':
        case 'bonus':
          Get.toNamed(AppPages.BONUS);
          break;

        // Profile & Support (Helpdesk)
        case 'support_ticket':
        case 'new_ticket':
        case 'ticket_reply':
        case 'ticket':
        case 'ticket_created':
        case 'ticket_updated':
        case 'ticket_closed':
        case 'helpdesk':
          Get.toNamed(AppPages.TICKET_LIST);
          break;
        
        // Partnerships (IB / PAMM / CopyTrading)
        case 'ib_request':
        case 'ib_commission_transfer':
        case 'ib':
          // Navigate to the last bottom tab (More / Assets / Dashboard tab at index 4)
          _navigateToMainTab(4);
          break;
        case 'copy_master_request':
        case 'copy_plan_request':
        case 'copy_copier_request':
        case 'copy_trading':
        case 'copy_trading_request':
        case 'copy':
        case 'copy_trade':
        case 'copy_request':
        case 'copier':
          if (Get.isRegistered<CopyTradingHubController>()) {
            Get.find<CopyTradingHubController>().currentTabIndex.value = 0;
          }
          if (Get.currentRoute == AppPages.COPY_TRADING_MAIN) {
            if (Get.isRegistered<CopyTradingHubController>()) {
              Get.find<CopyTradingHubController>().currentTabIndex.value = 0;
            }
          } else {
            Get.toNamed(AppPages.COPY_TRADING_MAIN, arguments: 0);
          }
          break;
        case 'pamm_manager_request':
        case 'pamm_plan_request':
        case 'pamm_investor_request':
        case 'pamm_request':
        case 'pamm':
          Get.toNamed(AppPages.PMAM_MAIN);
          break;

        // Custom / Promotional Alerts
        case 'demo_contest':
        case 'contest':
        case 'demo_contest_enroll':
        case 'demo_contest_winner':
        case 'demo_contest_start':
        case 'demo_contest_end':
          Get.toNamed(AppPages.DEMO_CONTEST);
          break;
        case 'tradewin_request':
        case 'tradewin':
        case 'trade_win':
        case 'trade_and_win':
        case 'trade_win_request':
        case 'tradewin_reward':
        case 'tradewin_claim':
        case 'trade_win_main':
          Get.toNamed(AppPages.TRADE_WIN_MAIN);
          break;
        case 'scratch_card_won':
        case 'scratch_card_loss':
        case 'scratch_card_ready':
        case 'scratch_card':
        case 'scratchcard':
        case 'scratch':
          Get.toNamed(AppPages.SCRATCH_CARD);
          break;
        case 'custom_alert':
          final redirectUrl = data?['redirect_url']?.toString().trim();
          if (redirectUrl != null && redirectUrl.isNotEmpty) {
            final uri = Uri.tryParse(redirectUrl);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              break;
            }
          }
          Get.toNamed(AppPages.NOTIFICATIONS);
          break;

        default:
          debugPrint('🔔 [NOTIFICATION REDIRECTION] Unhandled type "$type", navigating to Notifications list');
          Get.toNamed(AppPages.NOTIFICATIONS);
          break;
      }
    } catch (e, st) {
      debugPrint('🔔 [NOTIFICATION REDIRECTION] Error navigating for type "$type": $e\n$st');
    }
  }

  void _navigateToMainTab(int tabIndex) {
    if (Get.currentRoute == AppPages.TRADING) {
      TradingMainScreen.changeTab(tabIndex);
    } else {
      Get.until((route) => Get.currentRoute == AppPages.TRADING || route.isFirst);
      if (Get.currentRoute == AppPages.TRADING) {
        TradingMainScreen.changeTab(tabIndex);
      } else {
        Get.offAllNamed(AppPages.TRADING, arguments: tabIndex);
      }
    }
  }

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    debugPrint('🔔 [NOTIFICATION SERVICE] handleNotificationResponse: payload = ${response.payload}');
    await _onNotificationTapped(response);
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    // Handle local notification tap (when app is in foreground)
    if (response.payload != null) {
      try {
        Map<String, dynamic> payload = json.decode(response.payload!);
        await _handleNotificationRedirection(payload);
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
        color: AppColors.notificationBlue,
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
        color: AppColors.notificationBlue,
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
