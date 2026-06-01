import 'dart:async';
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/services/price_alert_service.dart';
import 'package:crm_app/services/loading_service.dart';
import 'package:crm_app/services/notification_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/app_lock_service.dart';
import 'constants/color.dart';

import 'flavor_config.dart';
import 'brands/brand_resolver.dart';
import 'brands/brand_id.dart';
import 'services/language_service.dart';
import 'services/theme_service.dart';
import 'core/config/app_config_service.dart';
import 'core/network/api_client.dart';
import 'core/network/network_startup_phase.dart';
import 'services/api_service_client.dart';
import 'package:crm_app/screens/copy_trading/data/datasources/copy_trading_remote_data_source.dart';
import 'package:crm_app/screens/copy_trading/data/repositories/copy_trading_repository_impl.dart';
import 'package:crm_app/screens/copy_trading/data/repositories/copy_trading_repository.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository_impl.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/screens/ib/data/datasources/ib_remote_data_source.dart';
import 'package:crm_app/screens/ib/data/repositories/ib_repository_impl.dart';
import 'package:crm_app/screens/ib/data/repositories/ib_repository.dart';
import 'package:crm_app/screens/kyc/data/repositories/kyc_repository_impl.dart';
import 'package:crm_app/screens/kyc/data/repositories/kyc_repository.dart';
import 'package:crm_app/screens/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:crm_app/screens/wallet/data/repositories/wallet_repository.dart';
import 'package:crm_app/screens/profile/data/repositories/profile_repository_impl.dart';
import 'package:crm_app/screens/profile/data/repositories/profile_repository.dart';
import 'package:crm_app/screens/trading/data/repositories/trading_repository_impl.dart';
import 'package:crm_app/screens/trading/data/repositories/trading_repository.dart';
import 'package:crm_app/screens/bonus/data/repositories/bonus_repository_impl.dart';
import 'package:crm_app/screens/bonus/domain/repositories/bonus_repository.dart';
import 'package:crm_app/screens/auth/data/repositories/auth_repository_impl.dart';
import 'package:crm_app/screens/auth/data/repositories/auth_repository.dart';
import 'package:crm_app/screens/auth/data/usecases/login_user.dart';
import 'package:crm_app/screens/auth/data/usecases/forgot_password.dart';
import 'package:crm_app/screens/auth/data/usecases/register_user.dart';
import 'package:crm_app/screens/auth/data/usecases/register_with_otp_verification.dart';
import 'package:crm_app/screens/auth/data/usecases/request_password_reset_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/reset_password.dart';
import 'package:crm_app/screens/auth/data/usecases/reset_password_with_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/send_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/verify_password_reset_otp.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'services/auth_service.dart';
import 'services/google_otp_service.dart';
import 'services/enabled_modules_service.dart';
import 'services/crm_settings_service.dart';
import 'package:crm_app/services/market_watch_v2_service.dart';
import 'services/account_service.dart';
import 'services/websocket_endpoint_helper.dart';
import 'routes/app_pages.dart';
import 'widgets/exit_confirmation_wrapper.dart';
import 'widgets/app_notification_stack.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'utils/app_logger.dart';
// App status check imports are enabled
import 'services/app_status/app_status_service.dart';
import 'services/app_status/app_status_controller.dart';
import 'services/app_status/app_status_overlay.dart';

// Connectivity overlay imports
import 'services/connectivity/connectivity_service.dart';
import 'services/connectivity/connectivity_controller.dart';
import 'services/connectivity/connectivity_overlay.dart';
import 'services/app_lock/app_lock_lifecycle.dart';
import 'services/app_lock/app_lock_overlay.dart';

// Firebase Background Message Handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  // 🎨 AUTO-DETECT FLAVOR FROM BUILD CONFIGURATION
  // The flavor is automatically detected from the build command
  // Example: flutter build apk --flavor vantage -t lib/main.dart

  // Reset any previous flavor configuration
  FlavorConfig.reset();

  WidgetsFlutterBinding.ensureInitialized();
  // Auto-detect and initialize the correct flavor
  await _initializeFlavor();

  // Initialize Firebase and get FCM Token
  try {
    await Firebase.initializeApp();

    // Set the background messaging handler early on, as a native callback
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // IMPORTANT: Do not block app startup on token fetching.
    // Native splash will stay visible until the first Flutter frame renders.
    // Token retrieval can be slow/flaky, so we fetch it in the background.
    FirebaseMessaging.instance
        .getToken()
        .then((token) async {
          try {
            print("====================================");
            print("FCM TOKEN: $token");
            print("====================================");

            if (token != null) {
              await SecureStorageService.saveFcmToken(token);
            }
          } catch (e) {
            print("FCM token handling error: $e");
          }
        })
        .catchError((e) {
          print("FCM token fetch error: $e");
        });
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  // Initialize logging system
  _initializeLogging();

  // Add global error handling for debugging crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter Error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Add global error handling for async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Platform Error: $error', error: error, stackTrace: stack);
    return true;
  };

  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Register AppLock service early so global overlays can safely read it
  // even if some startup path renders widgets before initServices finishes.
  if (!Get.isRegistered<AppLockService>()) {
    Get.put<AppLockService>(AppLockService(), permanent: true);
  }

  // Initialize GetX services
  await initServices();

  runApp(const MyGetXApp());
}

Future<void> initServices() async {
  // Brand selection must be ready before loading app_config so the correct
  // `assets/config/<brandId>/app_config.json` is used.
  final brandResolver = Get.put<BrandResolver>(
    BrandResolver(),
    permanent: true,
  );
  await brandResolver.ensureInitialized();

  // Load bundled app config (branding + feature flags) early.
  final appConfigService = Get.put<AppConfigService>(
    AppConfigService(),
    permanent: true,
  );
  await appConfigService.ensureInitialized();

  // Re-load app config whenever brand changes.
  ever<BrandId>(brandResolver.activeBrand, (_) async {
    try {
      await appConfigService.reload();
    } catch (_) {
      // Don't block if a brand's config isn't bundled yet.
    }
  });

  // Register services
  final languageService = Get.put<LanguageService>(
    LanguageService(),
    permanent: true,
  );
  await languageService.ensureInitialized();

  // Register ThemeService
  final themeService = Get.put<ThemeService>(ThemeService(), permanent: true);
  await themeService.ensureInitialized();

  // Shared API client abstraction (wrapping existing ApiService).
  Get.put<ApiClient>(ApiServiceClient(), permanent: true);

  // CopyTrading (incremental clean architecture)
  Get.put<CopyTradingRemoteDataSource>(
    CopyTradingRemoteDataSource(Get.find<ApiClient>()),
    permanent: true,
  );
  Get.put<CopyTradingRepository>(
    CopyTradingRepositoryImpl(Get.find<CopyTradingRemoteDataSource>()),
    permanent: true,
  );

  // Finance (incremental clean architecture)
  Get.put<FinanceRepository>(
    FinanceRepositoryImpl(Get.find<ApiClient>()),
    permanent: true,
  );

  // IB (incremental clean architecture)
  Get.put<IbRemoteDataSource>(
    IbRemoteDataSource(Get.find<ApiClient>()),
    permanent: true,
  );
  Get.put<IbRepository>(
    IbRepositoryImpl(Get.find<IbRemoteDataSource>()),
    permanent: true,
  );

  // KYC (incremental clean architecture)
  Get.put<KycRepository>(
    KycRepositoryImpl(Get.find<ApiClient>()),
    permanent: true,
  );

  // Wallet (incremental clean architecture)
  Get.put<WalletRepository>(
    WalletRepositoryImpl(Get.find<ApiClient>()),
    permanent: true,
  );

  // Profile / More (incremental clean architecture)
  Get.put<ProfileRepository>(
    ProfileRepositoryImpl(Get.find<ApiClient>()),
    permanent: true,
  );

  Get.put<TradingRepository>(
    TradingRepositoryImpl(Get.find<ApiClient>()),
    permanent: true,
  );
  Get.put<BonusRepository>(
    BonusRepositoryImpl(Get.find<ApiClient>()),
    permanent: true,
  );

  Get.put<AuthService>(AuthServiceImpl(Get.find<ApiClient>()), permanent: true);
  Get.put<GoogleOtpService>(GoogleOtpService(), permanent: true);
  Get.put<EnabledModulesService>(EnabledModulesService(), permanent: true);
  Get.put<CrmSettingsService>(CrmSettingsService(), permanent: true);
  Get.put<AuthRepository>(
    AuthRepositoryImpl(Get.find<AuthService>(), Get.find<ApiClient>()),
    permanent: true,
  );
  Get.put<LoginUser>(LoginUser(Get.find<AuthRepository>()), permanent: true);
  Get.put<ForgotPassword>(
    ForgotPassword(Get.find<AuthRepository>()),
    permanent: true,
  );
  Get.put<RegisterUser>(
    RegisterUser(Get.find<AuthRepository>()),
    permanent: true,
  );
  Get.put<RegisterWithOtpVerification>(
    RegisterWithOtpVerification(Get.find<AuthRepository>()),
    permanent: true,
  );
  Get.put<SendOtp>(SendOtp(Get.find<AuthRepository>()), permanent: true);
  Get.put<ResetPassword>(
    ResetPassword(Get.find<AuthRepository>()),
    permanent: true,
  );
  Get.put<RequestPasswordResetOtp>(
    RequestPasswordResetOtp(Get.find<AuthRepository>()),
    permanent: true,
  );
  Get.put<VerifyPasswordResetOtp>(
    VerifyPasswordResetOtp(Get.find<AuthRepository>()),
    permanent: true,
  );
  Get.put<ResetPasswordWithOtp>(
    ResetPasswordWithOtp(Get.find<AuthRepository>()),
    permanent: true,
  );
  Get.put<AccountService>(AccountServiceImpl(), permanent: true);
  Get.put<LoadingService>(LoadingService(), permanent: true);

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  Get.put<NotificationService>(notificationService, permanent: true);

  // Register controllers in proper order
  Get.put<AuthController>(AuthController(), permanent: true);
  if (!Get.isRegistered<AppLockService>()) {
    Get.put<AppLockService>(AppLockService(), permanent: true);
  }

  // Initialize DashboardController first as AccountController depends on it
  Get.put<DashboardController>(DashboardController(), permanent: true);
  Get.put<AccountController>(AccountController(), permanent: true);
  Get.put<MarketWatchV2Service>(MarketWatchV2Service(), permanent: true);
  Get.put<InstrumentsController>(InstrumentsController(), permanent: true);
  Get.put<ChartSocketController>(ChartSocketController(), permanent: true);
  Get.put<TradingController>(TradingController(), permanent: true);
  await PriceAlertService().initialize();

  // Initialize app notification controller for global notifications
  Get.put<AppNotificationController>(
    AppNotificationController(),
    permanent: true,
  );

  // Initialize app status service and controller for version check and maintenance mode
  // REQUIRED: Version check and maintenance check are enabled for testing
  Get.put<AppStatusService>(AppStatusService(), permanent: true);
  Get.put<AppStatusController>(AppStatusController(), permanent: true);

  // Start periodic app status checking
  // REQUIRED: Starting periodic check for testing
  final appStatusService = Get.find<AppStatusService>();
  appStatusService.startPeriodicCheck();

  // Initialize connectivity service and controller for no-internet overlay
  await Get.putAsync<ConnectivityService>(
    () async => await ConnectivityService().init(),
    permanent: true,
  );
  Get.put<ConnectivityController>(ConnectivityController(), permanent: true);
}

/// Build light theme
ThemeData _buildLightTheme() {
  return ThemeData(
    primaryColor: FlavorConfig.instance.primaryColor,
    colorScheme: ColorScheme.light(
      primary: FlavorConfig.instance.primaryColor,
      secondary: FlavorConfig.instance.secondaryColor,
      surface: AppColors.whiteColor,
      onPrimary: AppColors.whiteColor,
      onSecondary: Colors.black,
      onSurface: Colors.black,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.whiteColor,
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: FlavorConfig.instance.primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      alignLabelWithHint: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FlavorConfig.instance.primaryColor,
        foregroundColor: AppColors.whiteColor,
        minimumSize: Size(double.infinity, 40.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(vertical: 8.h),
      color: AppColors.whiteColor,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
      minLeadingWidth: 0,
      leadingAndTrailingTextStyle: TextStyle(
        fontSize: 14.sp,
        color: AppColors.textGreyLightTheme,
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: AppColors.whiteColor,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20.r),
          bottomRight: Radius.circular(20.r),
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.whiteColor,
      selectedItemColor: FlavorConfig.instance.primaryColor,
      unselectedItemColor: AppColors.textGreyLightTheme,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.whiteColor,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    iconTheme: IconThemeData(color: AppColors.textPrimary),
    textTheme: TextTheme(bodyLarge: TextStyle(color: AppColors.textPrimary)),
  );
}

/// Build dark theme
ThemeData _buildDarkTheme() {
  return ThemeData(
    primaryColor: FlavorConfig.instance.primaryColor,
    colorScheme: ColorScheme.dark(
      primary: FlavorConfig.instance.primaryColor,
      secondary: FlavorConfig.instance.secondaryColor,
      surface: AppColors.surfaceDarkTheme,
      onPrimary: AppColors.whiteColor,
      onSecondary: AppColors.whiteColor,
      onSurface: AppColors.whiteColor,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.backgroundDarkTheme,
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: FlavorConfig.instance.primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      alignLabelWithHint: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FlavorConfig.instance.primaryColor,
        foregroundColor: AppColors.whiteColor,
        minimumSize: Size(double.infinity, 40.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(vertical: 8.h),
      color: AppColors.cardDarkTheme,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
      minLeadingWidth: 0,
      leadingAndTrailingTextStyle: TextStyle(
        fontSize: 14.sp,
        color: AppColors.textGreyDark,
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: AppColors.surfaceDarkTheme,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20.r),
          bottomRight: Radius.circular(20.r),
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDarkTheme,
      selectedItemColor: FlavorConfig.instance.primaryColor,
      unselectedItemColor: AppColors.textGreyDark,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceDarkTheme,
      foregroundColor: AppColors.whiteColor,
      elevation: 0,
    ),
    iconTheme: IconThemeData(color: AppColors.whiteColor),
    textTheme: TextTheme(bodyLarge: TextStyle(color: AppColors.whiteColor)),
  );
}

class MyGetXApp extends StatelessWidget {
  const MyGetXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Obx(() {
          final languageService = Get.find<LanguageService>();
          final isRTL = languageService.isRTL();

          return Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: ExitConfirmationWrapper(
              forceExitDialog: true, // Always show exit dialog on back button
              child: AppLockLifecycle(
                child: GetMaterialApp(
                  builder: (context, child) {
                    final mediaQuery = MediaQuery.of(context);
                    return Stack(
                      children: [
                        MediaQuery(
                          data: mediaQuery.copyWith(textScaleFactor: 1.0),
                          child: child!,
                        ),
                        // Global notification overlay
                        const AppNotificationStack(),
                        // Global app status overlay (maintenance screen & force update)
                        const AppStatusOverlay(),
                        // Global connectivity overlay (no internet screen)
                        const ConnectivityOverlay(),
                        // Global app lock overlay
                        const AppLockOverlay(),
                      ],
                    );
                  },
                  title: FlavorConfig.instance.appTitle,
                  debugShowCheckedModeBanner: false,
                  // showPerformanceOverlay: true, // Removed in favor of custom overlay
                  locale: languageService.getCurrentLocale(),
                  themeMode: ThemeMode.light,
                  theme: _buildLightTheme(),
                  darkTheme: _buildDarkTheme(),
                  initialRoute: AppPages.SPLASH,
                  getPages: AppPages.routes,
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

/// Screen that checks authentication and navigates to the appropriate screen
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
    // testDecryption();
  }

  // void testDecryption() {
  //   try {
  //     final result = EncryptionHelper.decryptPayload(
  //       'LmpLtM1LChdA2Y/rI/nsk6dzGcO9IivZg5Au9d5n9cyNPdMrQIshEKVaBhk4lSs/uNSYVqr8lkACIwIOGAEUMNvYYFoiEPvHoFZxHsKnNhg6+N9LIVhAUOOPRmWLWeMm9eQhmbXBvEIgLk3/t+V420eUevC3A7JGkuEjvTFjv4Mcp3f8BKAJVvguFpwaGDvRV++Pxys8bn5QUWtJd5e+V3Cj2aT1P8nPb3o4GuzrD6KvzYaGia2mr170GCAbFPceMgUQ1Y3k7NNjuWWx+UjgsvaGVUlnOJK+cQAmwyAUOfFcRCCwAdOb+IW64OWnVrfFCzjTSd5gxNY6qjbVokjIlLeUc1qH4ym1yCI5Qs0/rOq9L9Ypmyb17pkmgIFnl0R7dJSwPZCmUzixSOCguQHLhltaJd2gNCTWMo8n1Y9vpuj7fZ11SJz2k/S9ztvP2b5vi6Q3jCPieC7A3sdmAAnLMV5upcy4fHpTt7uaGdNgtwBugf7cq9rI0JUvae+ctv2m', // payload
  //       'vYXxNGG/cNbEh7zBCUPhTg==', // iv
  //     );
  //     print('✅ DECRYPTED: $result');
  //   } catch (e) {
  //     print('❌ FAILED: $e');
  //   }
  // }

  Future<void> _checkAuthAndNavigate() async {
    try {
      unawaited(Get.find<AppStatusService>().checkAppStatus());

      final isLoggedIn = await SecureStorageService.isUserLoggedIn();

      print('AuthCheckScreen: User login status: $isLoggedIn');

      if (isLoggedIn) {
        // User is logged in, validate token before navigating
        print('AuthCheckScreen: Validating authentication token...');
        final authController = Get.find<AuthController>();
        await authController.checkAuthStatus();

        // Only navigate to trading if token is valid
        if (authController.isAuthenticated) {
          print(
            'AuthCheckScreen: User is authenticated, fetching accounts before navigation...',
          );

          // ✅ PRE-FETCH: Fetch primary account and store in helper before navigating
          try {
            final primaryAccount =
                await WebSocketEndpointHelper.fetchPrimaryAccount();
            if (primaryAccount != null) {
              WebSocketEndpointHelper.setPrimaryAccount(primaryAccount);
              print(
                'AuthCheckScreen: Primary account loaded: ${primaryAccount.metaAccountNumber}',
              );
            }
          } catch (e) {
            print('AuthCheckScreen: Error fetching accounts: $e');
          }

          if (Get.isRegistered<EnabledModulesService>()) {
            unawaited(
              Get.find<EnabledModulesService>().fetchEnabledModules(
                force: true,
              ),
            );
          }

          print('AuthCheckScreen: Navigating to Trading screen (Home)');
          // End startup phase so normal 401 handling (session expired) resumes
          NetworkStartupPhase.end();
          Get.offAllNamed(AppPages.TRADING);
        } else {
          // Token validation failed, navigate to get started
          // (no session-expired toast — user was not actively using the app)
          print(
            'AuthCheckScreen: Token validation failed, navigating to Get Started',
          );
          // Clear any stale auth data
          await SecureStorageService.clearAuthData();
          // End startup phase before navigating
          NetworkStartupPhase.end();
          Get.offAllNamed(AppPages.GET_STARTED);
        }
      } else {
        // User is not logged in, navigate to get started screen
        print(
          'AuthCheckScreen: User is not logged in, navigating to Get Started',
        );
        NetworkStartupPhase.end();
        Get.offAllNamed(AppPages.GET_STARTED);
      }
    } catch (e) {
      print('AuthCheckScreen: Error checking auth status: $e');
      // On startup errors (timeout, server error, etc.), don't wipe a persisted session.
      // If the token is actually invalid, subsequent API calls will return 401 and trigger logout.
      try {
        final stillLoggedIn = await SecureStorageService.isUserLoggedIn();
        if (stillLoggedIn) {
          NetworkStartupPhase.end();
          Get.offAllNamed(AppPages.TRADING);
          return;
        }
      } catch (_) {}
      NetworkStartupPhase.end();
      Get.offAllNamed(AppPages.GET_STARTED);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show neutral loading UI while async auth check runs.
    // Prevents SR flavor's red background "flash" before GetStarted.
    return Scaffold(
      backgroundColor:
          FlavorConfig.isVantage()
              ? FlavorConfig.instance.primaryColor
              : AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // SvgPicture.asset(FlavorConfig.instance.splashLogoPath),
            const SizedBox(height: 24),
            // const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Initialize logging system based on environment
void _initializeLogging() {
  // Check if running in debug mode
  bool isDebugMode = false;
  assert(isDebugMode = true);

  if (isDebugMode) {
    // Development mode - enable all logs
    AppLogger.enableAllLogs();
    AppLogger.debug('App started in DEBUG mode - All logs enabled');
  } else {
    // Production mode - only errors and warnings
    AppLogger.enableProductionLogging();
    AppLogger.error('App started in PRODUCTION mode - Error logs only');
  }

  // Disable InAppWebView debug logging
  try {
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
    AppLogger.debug('InAppWebView debug logging disabled');
  } catch (e) {
    AppLogger.error('Failed to disable InAppWebView debug logging: $e');
  }

  // Log app initialization
  AppLogger.chart('Chart system ready');
  AppLogger.websocket('WebSocket system ready');
}

/// Auto-detect and initialize the correct flavor based on build configuration
Future<void> _initializeFlavor() async {
  // Build-time selection only (no runtime switching).
  //
  // Preferred: `--dart-define=CLIENT=tenax|vantage`
  // Back-compat: `--dart-define=FLAVOR=tenax|vantage`
  const clientFromDefine = String.fromEnvironment('CLIENT', defaultValue: '');
  const flavorFromDefine = String.fromEnvironment('FLAVOR', defaultValue: '');

  final selectedRaw =
      clientFromDefine.isNotEmpty ? clientFromDefine : flavorFromDefine;
  final selected = selectedRaw.trim().toLowerCase();

  switch (selected) {
    case 'vantage':
      FlavorConfig.vantage;
      AppLogger.debug('Flavor initialized: vantage');
      return;
    case 'celestial':
      FlavorConfig.celestial;
      AppLogger.debug('Flavor initialized: celestial');
      return;
    case 'tenax':
    default:
      AppLogger.error(
        'Unsupported flavor/client "$selectedRaw". Falling back to tenax.',
      );
      FlavorConfig.tenax;
      AppLogger.debug('Flavor initialized: tenax');
      return;
  }
}

// adb --version
// flutter doctor
