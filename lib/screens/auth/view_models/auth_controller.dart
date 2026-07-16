import 'package:get/get.dart';
import 'package:crm_app/models/login_response_model.dart';
import 'package:crm_app/models/user_model.dart';
import 'package:crm_app/models/settings_profile_model.dart' as profile_model;
import 'package:get/get.dart' as g;
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/account_cache_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/kyc/view_models/compliance_controller.dart';

import 'package:crm_app/routes/app_pages.dart';
import 'dart:convert';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/websocket_endpoint_helper.dart';
import 'package:crm_app/screens/wallet/view_models/wallet_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/services/app_lock_service.dart';
import 'package:crm_app/services/one_click_trading_service.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'dart:io' show Platform;
import 'package:crm_app/services/biometric_service.dart';
import 'package:crm_app/screens/auth/data/repositories/auth_repository.dart';
import 'package:crm_app/screens/auth/data/usecases/forgot_password.dart';
import 'package:crm_app/screens/auth/data/usecases/login_user.dart';
import 'package:crm_app/screens/auth/data/usecases/register_user.dart';
import 'package:crm_app/screens/auth/data/usecases/register_with_otp_verification.dart';
import 'package:crm_app/screens/auth/data/usecases/request_password_reset_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/reset_password.dart';
import 'package:crm_app/screens/auth/data/usecases/reset_password_with_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/send_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/verify_password_reset_otp.dart';
import 'package:crm_app/services/google_otp_service.dart';
import 'package:crm_app/services/enabled_modules_service.dart';

class AuthController extends GetxController {
  GoogleOtpService get _googleOtpService => Get.find<GoogleOtpService>();
  final AuthRepository _authRepo = Get.find<AuthRepository>();
  final LoginUser _loginUser = Get.find<LoginUser>();
  final ForgotPassword _forgotPassword = Get.find<ForgotPassword>();
  final RegisterUser _registerUser = Get.find<RegisterUser>();
  final RegisterWithOtpVerification _registerWithOtpVerification =
      Get.find<RegisterWithOtpVerification>();
  final SendOtp _sendOtp = Get.find<SendOtp>();
  final ResetPassword _resetPassword = Get.find<ResetPassword>();
  final RequestPasswordResetOtp _requestPasswordResetOtp =
      Get.find<RequestPasswordResetOtp>();
  final VerifyPasswordResetOtp _verifyPasswordResetOtp =
      Get.find<VerifyPasswordResetOtp>();
  final ResetPasswordWithOtp _resetPasswordWithOtp =
      Get.find<ResetPasswordWithOtp>();

  // Observable states
  final _isLoading = false.obs;
  final _errorMessage = ''.obs;
  final _isAuthenticated = false.obs;
  final _loginResponse = Rxn<LoginResponseModel>();
  final _userData = Rxn<UserModel>();
  final _otpSentEmail = ''.obs;
  final _otpSentMessage = ''.obs;
  final _verifiedEmail = ''.obs;
  final _verifiedOtp = ''.obs;
  final _registerData = Rxn<Map<String, dynamic>>();
  final _profileData = Rxn<profile_model.SettingsProfileData>();

  // Getters
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  bool get isAuthenticated => _isAuthenticated.value;
  RxBool get isAuthenticatedRx => _isAuthenticated;
  LoginResponseModel? get loginResponse => _loginResponse.value;
  UserModel? get userData => _userData.value;
  String get otpSentEmail => _otpSentEmail.value;
  String get otpSentMessage => _otpSentMessage.value;
  String get verifiedEmail => _verifiedEmail.value;
  String get verifiedOtp => _verifiedOtp.value;
  Map<String, dynamic>? get registerData => _registerData.value;
  profile_model.SettingsProfileData? get profileData => _profileData.value;
  bool get isGoogleOtpEnabled => _userData.value?.googleOtpEnabled ?? false;

  // User data getters
  String? get userEmail => _userData.value?.email;
  String? get userFullName => _userData.value?.fullName;
  String? get userFirstName => _userData.value?.firstName;
  String? get userLastName => _userData.value?.lastName;
  String? get userMobile => _userData.value?.mobile;
  bool get isEmailVerified => _userData.value?.isEmailVerified ?? false;
  bool get isMobileVerified => _userData.value?.isMobileVerified ?? false;
  bool get isUserActive => _userData.value?.isActive ?? false;

  @override
  void onInit() {
    super.onInit();
    // checkAuthStatus(); // Redundant - called in AuthCheckScreen and initServices
    getUserData();
  }

  // Get user data from secure storage
  Future<UserModel?> getUserData() async {
    try {
      final userData = await SecureStorageService.getUserData();
      _userData.value = userData;
      return userData;
    } catch (e) {
      print('AuthController: Error getting user data: $e');
      _setError('Failed to get user data: $e');
      return null;
    }
  }

  // Get user email specifically
  Future<String?> getUserEmail() async {
    final user = await getUserData();
    print("userEmail getUserEmail : ${user?.email}");
    return user?.email;
  }

  Future<String> getUserName() async {
    final user = await getUserData();
    print("userEmail getUserEmail : ${user?.firstName} ${user?.lastName}");
    return '${user?.firstName} ${user?.lastName}';
  }

  // Refresh user data (useful for profile updates)
  Future<void> refreshUserData() async {
    await getUserData();
  }

  // ==================== LOGIN METHODS ====================
  Future<void> login({
    required String email,
    required String password,
    bool enableBiometricAfterLogin = false,
  }) async {
    try {
      // ⏱️ Performance measurement: Start timing
      final stopwatch = Stopwatch()..start();
      print('⏱️ [PERFORMANCE] Login process started at ${DateTime.now()}');

      _setLoading(true);
      _clearError();

      final loginStartTime = stopwatch.elapsedMilliseconds;
      String? fcmToken = await SecureStorageService.getFcmToken();
      String deviceType = Platform.isIOS ? 'ios' : 'android';

      final response = await _loginUser(
        email: email,
        password: password,
        fcmToken: fcmToken,
        deviceType: deviceType,
      );
      print(
        '⏱️ [PERFORMANCE] Login API completed: ${stopwatch.elapsedMilliseconds - loginStartTime}ms',
      );

      if (response.success && response.data != null) {
        final loginResult = response.data!;

        if (loginResult.requiresGoogleOtp) {
          final challengeEmail =
              loginResult.googleOtpChallenge?.email ?? email.trim();
          Get.toNamed(AppPages.GOOGLE_LOGIN_OTP, arguments: challengeEmail);
          return;
        }

        final loginResponse = loginResult.loginResponse;
        if (loginResponse == null) {
          _setError('Login failed. Please try again.');
          return;
        }

        // Save login data to secure storage
        final loginData = {
          'token': loginResponse.data.token,
          'websocket_token': loginResponse.data.websocketToken,
          'user': loginResponse.data.user.toJson(),
          'is_logged_in': true,
        };

        // Pre-initialize controllers in parallel with saving tokens
        // This reduces sequential overhead
        final controllerInitStart = stopwatch.elapsedMilliseconds;
        final dashboardController = Get.put(DashboardController());
        print(
          '⏱️ [PERFORMANCE] DashboardController initialized: ${stopwatch.elapsedMilliseconds - controllerInitStart}ms',
        );

        // Save tokens and update state in parallel
        final tokenSaveStart = stopwatch.elapsedMilliseconds;
        await Future.wait([
          SecureStorageService.saveUserData(jsonEncode(loginData)),
          SecureStorageService.saveAuthToken(loginResponse.data.token),
          SecureStorageService.saveWebsocketToken(
            loginResponse.data.websocketToken,
          ),
          SecureStorageService.saveLoginStatus(true),
        ]);
        print(
          '⏱️ [PERFORMANCE] Tokens saved: ${stopwatch.elapsedMilliseconds - tokenSaveStart}ms',
        );

        _loginResponse.value = loginResponse;
        _userData.value = loginResponse.data.user;
        _isAuthenticated.value = true;

        if (enableBiometricAfterLogin) {
          try {
            // Only enable if device supports + enrolled and user confirms.
            final supported =
                await BiometricService.instance.isDeviceSupported();
            final enrolled = await BiometricService.instance.isEnrolled();
            if (supported && enrolled) {
              final ok = await BiometricService.instance.authenticate(
                reason: 'Confirm biometric to enable login.',
              );
              if (ok) {
                try {
                  if (Get.isRegistered<AppLockService>()) {
                    Get.find<AppLockService>().markJustAuthenticated();
                  }
                } catch (_) {}
                await SecureStorageService.setBiometricEnabled(
                  true,
                  userIdentifier: email.trim().toLowerCase(),
                );
              }
            }
          } catch (e) {
            // Keep login flow safe even if biometrics fail.
            print(
              'AuthController: Failed to enable biometrics after login: $e',
            );
          }
        }

        // Enable one-click trading by default after login
        OneClickTradingService.instance.setOneClickTradingEnabled(true);

        // ✅ FIX: Wait for account check before connecting sockets
        // Initialize dashboard controller and fetch MT5 accounts
        int accountDataStart = 0;
        try {
          // Get account controller if it exists
          AccountController? accountController;
          try {
            if (Get.isRegistered<AccountController>()) {
              accountController = Get.find<AccountController>();
            }
          } catch (e) {
            print('AuthController: AccountController not registered yet: $e');
          }

          // ✅ FIX: Wait for account check to complete
          accountDataStart = stopwatch.elapsedMilliseconds;
          final futures = <Future>[dashboardController.forceCheckMT5Accounts()];

          if (accountController != null) {
            futures.add(accountController.forceRefreshAccountData());
          }

          await Future.wait(futures, eagerError: false);
          print(
            '⏱️ [PERFORMANCE] Account data loaded: ${stopwatch.elapsedMilliseconds - accountDataStart}ms',
          );

          // ✅ FIX: Check if account exists and set primary account
          final primaryAccount = dashboardController.primaryMT5Account;
          if (primaryAccount != null) {
            // Account exists - set it in WebSocketEndpointHelper
            WebSocketEndpointHelper.setPrimaryAccount(primaryAccount);
            print(
              'AuthController: Primary account set: ${primaryAccount.metaAccountNumber} (${primaryAccount.tradingServer})',
            );
          } else {
            // No account - set to null (will use self-hosted endpoints)
            WebSocketEndpointHelper.setPrimaryAccount(null);
            print(
              'AuthController: No account found, using self-hosted endpoints',
            );
          }

          print('AuthController: All account data loaded after login');
        } catch (e) {
          print('AuthController: Error initializing dashboard: $e');
          // Set to null on error to use self-hosted endpoints
          WebSocketEndpointHelper.setPrimaryAccount(null);
        }

        // ✅ FIX: Re-initialize ALL controllers and WebSocket services BEFORE navigation
        // This ensures everything is ready when the UI loads
        print(
          'AuthController: Re-initializing all controllers and services...',
        );

        // 1. Re-initialize DashboardController
        try {
          if (Get.isRegistered<DashboardController>()) {
            Get.delete<DashboardController>(force: true);
          }
          Get.put<DashboardController>(DashboardController(), permanent: true);
          print('AuthController: DashboardController re-initialized');
        } catch (e) {
          print(
            'AuthController: Error re-initializing DashboardController: $e',
          );
        }

        // 2. Re-initialize AccountController
        try {
          if (Get.isRegistered<AccountController>()) {
            Get.delete<AccountController>(force: true);
          }
          Get.put<AccountController>(AccountController(), permanent: true);
          print('AuthController: AccountController re-initialized');
        } catch (e) {
          print('AuthController: Error re-initializing AccountController: $e');
        }

        // 3. Re-initialize InstrumentsController (has WebSocket)
        try {
          if (Get.isRegistered<InstrumentsController>()) {
            Get.delete<InstrumentsController>(force: true);
          }
          Get.put<InstrumentsController>(
            InstrumentsController(),
            permanent: true,
          );
          print('AuthController: InstrumentsController re-initialized');
        } catch (e) {
          print(
            'AuthController: Error re-initializing InstrumentsController: $e',
          );
        }

        // 4. Re-initialize ChartSocketController (has WebSocket)
        try {
          if (Get.isRegistered<ChartSocketController>()) {
            Get.delete<ChartSocketController>(force: true);
          }
          Get.put<ChartSocketController>(
            ChartSocketController(),
            permanent: true,
          );
          print('AuthController: ChartSocketController re-initialized');
        } catch (e) {
          print(
            'AuthController: Error re-initializing ChartSocketController: $e',
          );
        }

        // 5. Re-initialize TradingController
        try {
          if (Get.isRegistered<TradingController>()) {
            Get.delete<TradingController>(force: true);
          }
          Get.put<TradingController>(TradingController(), permanent: true);
          print('AuthController: TradingController re-initialized');
        } catch (e) {
          print('AuthController: Error re-initializing TradingController: $e');
        }

        // 6. Re-initialize TradingWebSocketService
        try {
          if (Get.isRegistered<TradingWebSocketService>()) {
            Get.delete<TradingWebSocketService>(force: true);
          }
          Get.put<TradingWebSocketService>(
            TradingWebSocketService(),
            permanent: true,
          );
          print('AuthController: TradingWebSocketService re-initialized');
        } catch (e) {
          print(
            'AuthController: Error re-initializing TradingWebSocketService: $e',
          );
        }

        // 7. Re-initialize AccountWebSocketService
        try {
          if (Get.isRegistered<AccountWebSocketService>()) {
            Get.delete<AccountWebSocketService>(force: true);
          }
          Get.put<AccountWebSocketService>(
            AccountWebSocketService(),
            permanent: true,
          );
          print('AuthController: AccountWebSocketService re-initialized');
        } catch (e) {
          print(
            'AuthController: Error re-initializing AccountWebSocketService: $e',
          );
        }

        print(
          'AuthController: All controllers and services re-initialized with new user token',
        );

        _fetchEnabledModulesInBackground();

        // Navigate to trading screen AFTER controllers are ready
        await _navigatePostAuth();

        // Navigate to trading screen
        // final navigationStart = stopwatch.elapsedMilliseconds;
        //
        // stopwatch.stop();

        // ⏱️ Performance measurement: Final timing report
        // print('═══════════════════════════════════════════════════════');
        // print('⏱️ [PERFORMANCE] LOGIN TO DASHBOARD TIMING REPORT');
        // print('═══════════════════════════════════════════════════════');
        // final totalTime = stopwatch.elapsedMilliseconds;
        // print(
        //   '⏱️ Total time: ${totalTime}ms (${(totalTime / 1000).toStringAsFixed(2)}s)',
        // );
        // print('⏱️ Breakdown:');
        // print(
        //   '   • Login API: ${stopwatch.elapsedMilliseconds - loginStartTime}ms',
        // );
        // if (totalTime > controllerInitStart) {
        //   print('   • Controller Init: ${controllerInitStart}ms');
        // }
        // if (totalTime > tokenSaveStart) {
        //   print('   • Token Save: ${tokenSaveStart - controllerInitStart}ms');
        // }
        // if (accountDataStart > 0 && totalTime > accountDataStart) {
        //   print('   • Account Data: ${accountDataStart - tokenSaveStart}ms');
        // }
        // print('   • Navigation: ${totalTime - navigationStart}ms');
        // print('═══════════════════════════════════════════════════════');
        // print(
        //   '${stopwatch.elapsedMilliseconds < 2000
        //       ? "✅ EXCELLENT"
        //       : stopwatch.elapsedMilliseconds < 3000
        //       ? "✅ GOOD"
        //       : "⚠️ NEEDS IMPROVEMENT"} (<2s excellent, <3s good, >3s needs work)',
        // );
        // print('═══════════════════════════════════════════════════════');
      } else {
        print('❌ AuthController.login() - Login failed:');
        print('   response.success: ${response.success}');
        print('   response.message: ${response.message}');
        print('   response.data: ${response.data}');

        // Ensure we always have an error message to display
        final errorMessage =
            response.message?.isNotEmpty == true
                ? response.message!
                : 'Login failed. Please check your credentials and try again.';

        print('   Setting error message: $errorMessage');
        _setError(errorMessage);
      }
    } catch (e) {
      _setError('Login error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyGoogleLoginOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _googleOtpService.verifyLoginOtp(
        email: email,
        otpCode: otpCode,
      );

      if (response.success && response.data != null) {
        await _completeLogin(response.data!, email: email);
      } else {
        final errorMessage =
            response.message?.isNotEmpty == true
                ? response.message!
                : 'OTP verification failed. Please try again.';
        _setError(errorMessage);
      }
    } catch (e) {
      _setError('OTP verification error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateGoogleOtpEnabled(bool enabled) async {
    final user = _userData.value;
    if (user == null) return;

    final updatedUser = user.copyWith(googleOtpEnabled: enabled);
    _userData.value = updatedUser;

    try {
      final loginData = await SecureStorageService.getCompleteLoginData();
      if (loginData != null) {
        loginData['user'] = updatedUser.toJson();
        await SecureStorageService.saveUserData(jsonEncode(loginData));
      }
    } catch (e) {
      print('AuthController: Failed to persist google OTP flag: $e');
    }
  }

  Future<void> _completeLogin(
    LoginResponseModel response, {
    required String email,
    bool enableBiometricAfterLogin = false,
  }) async {
    final loginData = {
      'token': response.data.token,
      'websocket_token': response.data.websocketToken,
      'user': response.data.user.toJson(),
      'is_logged_in': true,
    };

    await Future.wait([
      SecureStorageService.saveUserData(jsonEncode(loginData)),
      SecureStorageService.saveAuthToken(response.data.token),
      SecureStorageService.saveWebsocketToken(response.data.websocketToken),
      SecureStorageService.saveLoginStatus(true),
    ]);

    _loginResponse.value = response;
    _userData.value = response.data.user;
    _isAuthenticated.value = true;

    if (enableBiometricAfterLogin) {
      try {
        final supported = await BiometricService.instance.isDeviceSupported();
        final enrolled = await BiometricService.instance.isEnrolled();
        if (supported && enrolled) {
          final ok = await BiometricService.instance.authenticate(
            reason: 'Confirm biometric to enable login.',
          );
          if (ok) {
            try {
              if (Get.isRegistered<AppLockService>()) {
                Get.find<AppLockService>().markJustAuthenticated();
              }
            } catch (_) {}
            await SecureStorageService.setBiometricEnabled(
              true,
              userIdentifier: email.trim().toLowerCase(),
            );
          }
        }
      } catch (e) {
        print('AuthController: Failed to enable biometrics after login: $e');
      }
    }

    OneClickTradingService.instance.setOneClickTradingEnabled(true);

    try {
      AccountController? accountController;
      final dashboardController = Get.put(DashboardController());
      try {
        if (Get.isRegistered<AccountController>()) {
          accountController = Get.find<AccountController>();
        }
      } catch (e) {
        print('AuthController: AccountController not registered yet: $e');
      }

      final futures = <Future>[dashboardController.forceCheckMT5Accounts()];
      if (accountController != null) {
        futures.add(accountController.forceRefreshAccountData());
      }
      await Future.wait(futures, eagerError: false);

      final primaryAccount = dashboardController.primaryMT5Account;
      WebSocketEndpointHelper.setPrimaryAccount(primaryAccount);
    } catch (e) {
      WebSocketEndpointHelper.setPrimaryAccount(null);
    }

    _reinitializeTradingControllers();
    _fetchEnabledModulesInBackground();
    await _navigatePostAuth();
  }

  void _reinitializeTradingControllers() {
    try {
      if (Get.isRegistered<DashboardController>()) {
        Get.delete<DashboardController>(force: true);
      }
      Get.put<DashboardController>(DashboardController(), permanent: true);
    } catch (_) {}

    try {
      if (Get.isRegistered<AccountController>()) {
        Get.delete<AccountController>(force: true);
      }
      Get.put<AccountController>(AccountController(), permanent: true);
    } catch (_) {}

    try {
      if (Get.isRegistered<InstrumentsController>()) {
        Get.delete<InstrumentsController>(force: true);
      }
      Get.put<InstrumentsController>(InstrumentsController(), permanent: true);
    } catch (_) {}

    try {
      if (Get.isRegistered<ChartSocketController>()) {
        Get.delete<ChartSocketController>(force: true);
      }
      Get.put<ChartSocketController>(ChartSocketController(), permanent: true);
    } catch (_) {}

    try {
      if (Get.isRegistered<TradingController>()) {
        Get.delete<TradingController>(force: true);
      }
      Get.put<TradingController>(TradingController(), permanent: true);
    } catch (_) {}

    try {
      if (Get.isRegistered<TradingWebSocketService>()) {
        Get.delete<TradingWebSocketService>(force: true);
      }
      Get.put<TradingWebSocketService>(TradingWebSocketService(), permanent: true);
    } catch (_) {}

    try {
      if (Get.isRegistered<AccountWebSocketService>()) {
        Get.delete<AccountWebSocketService>(force: true);
      }
      Get.put<AccountWebSocketService>(
        AccountWebSocketService(),
        permanent: true,
      );
    } catch (_) {}
  }

  void _fetchEnabledModulesInBackground() {
    if (!Get.isRegistered<EnabledModulesService>()) return;
    final service = Get.find<EnabledModulesService>();
    service.fetchEnabledModules(force: true);
  }

  // ==================== REGISTRATION METHODS ====================
  Future<bool> register({required Map<String, dynamic> data}) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _registerUser(data: data);

      if (response.success && response.data != null) {
        final message = _resolveApiMessage(
          data: response.data,
          responseMessage: response.message,
          fallback: 'Registration initiated successfully',
        );
        CustomToastService.showSuccess(message: message, title: 'Success');
        return true;
      } else {
        final errorMessage = _resolveApiMessage(
          data: response.data,
          responseMessage: response.message,
          fallback: 'Registration failed',
        );
        _errorMessage.value = errorMessage;
        CustomToastService.showError(message: errorMessage, title: 'Error');
        return false;
      }
    } catch (e) {
      final errorMessage = 'Registration error: $e';
      _errorMessage.value = errorMessage;
      CustomToastService.showError(message: errorMessage, title: 'Error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== REGISTRATION METHODS ====================
  Future<bool> registerWithOTPVerification({
    required Map<String, dynamic> data,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _registerWithOtpVerification(data: data);

      if (response.success && response.data != null) {
        print("NEW USER DATA");
        print(response.data);

        // Check if the response has the expected structure
        if (response.data!.data.token.isNotEmpty) {
          final loginData = {
            'token': response.data!.data.token,
            'websocket_token': response.data!.data.websocketToken,
            'user': response.data!.data.user.toJson(),
            'is_logged_in': true,
          };

          await SecureStorageService.saveUserData(jsonEncode(loginData));
          await SecureStorageService.saveAuthToken(response.data!.data.token);
          await SecureStorageService.saveWebsocketToken(
            response.data!.data.websocketToken,
          );
          await SecureStorageService.saveLoginStatus(true);

          // Trigger background API call for FCM token
          _registerFcmTokenInBackground(response.data!.data.token);

          // Set user data in controller
          _userData.value = response.data!.data.user;
          _isAuthenticated.value = true;

          // Enable one-click trading by default after registration
          OneClickTradingService.instance.setOneClickTradingEnabled(true);

          // ✅ FIX: Re-initialize ALL controllers and WebSocket services for new user
          // This ensures everything is ready with the new user's token
          print(
            'AuthController: Re-initializing all controllers after registration...',
          );

          try {
            // Fetch primary account and set in WebSocketEndpointHelper
            final dashboardController = Get.find<DashboardController>();
            await dashboardController.forceCheckMT5Accounts();
            final primaryAccount = dashboardController.primaryMT5Account;

            if (primaryAccount != null) {
              WebSocketEndpointHelper.setPrimaryAccount(primaryAccount);
              print(
                'AuthController: Primary account set for new user: ${primaryAccount.metaAccountNumber}',
              );
            } else {
              WebSocketEndpointHelper.setPrimaryAccount(null);
              print(
                'AuthController: No account found, using self-hosted endpoints',
              );
            }
          } catch (e) {
            print('AuthController: Error fetching account data: $e');
            WebSocketEndpointHelper.setPrimaryAccount(null);
          }

          // Re-initialize all controllers (same as login flow)
          // 1. DashboardController
          try {
            if (Get.isRegistered<DashboardController>()) {
              Get.delete<DashboardController>(force: true);
            }
            Get.put<DashboardController>(
              DashboardController(),
              permanent: true,
            );
            print('AuthController: DashboardController re-initialized');
          } catch (e) {
            print(
              'AuthController: Error re-initializing DashboardController: $e',
            );
          }

          // 2. AccountController
          try {
            if (Get.isRegistered<AccountController>()) {
              Get.delete<AccountController>(force: true);
            }
            Get.put<AccountController>(AccountController(), permanent: true);
            print('AuthController: AccountController re-initialized');
          } catch (e) {
            print(
              'AuthController: Error re-initializing AccountController: $e',
            );
          }

          // 3. InstrumentsController
          try {
            if (Get.isRegistered<InstrumentsController>()) {
              Get.delete<InstrumentsController>(force: true);
            }
            Get.put<InstrumentsController>(
              InstrumentsController(),
              permanent: true,
            );
            print('AuthController: InstrumentsController re-initialized');
          } catch (e) {
            print(
              'AuthController: Error re-initializing InstrumentsController: $e',
            );
          }

          // 4. ChartSocketController
          try {
            if (Get.isRegistered<ChartSocketController>()) {
              Get.delete<ChartSocketController>(force: true);
            }
            Get.put<ChartSocketController>(
              ChartSocketController(),
              permanent: true,
            );
            print('AuthController: ChartSocketController re-initialized');
          } catch (e) {
            print(
              'AuthController: Error re-initializing ChartSocketController: $e',
            );
          }

          // 5. TradingController
          try {
            if (Get.isRegistered<TradingController>()) {
              Get.delete<TradingController>(force: true);
            }
            Get.put<TradingController>(TradingController(), permanent: true);
            print('AuthController: TradingController re-initialized');
          } catch (e) {
            print(
              'AuthController: Error re-initializing TradingController: $e',
            );
          }

          // 6. TradingWebSocketService
          try {
            if (Get.isRegistered<TradingWebSocketService>()) {
              Get.delete<TradingWebSocketService>(force: true);
            }
            Get.put<TradingWebSocketService>(
              TradingWebSocketService(),
              permanent: true,
            );
            print('AuthController: TradingWebSocketService re-initialized');
          } catch (e) {
            print(
              'AuthController: Error re-initializing TradingWebSocketService: $e',
            );
          }

          // 7. AccountWebSocketService
          try {
            if (Get.isRegistered<AccountWebSocketService>()) {
              Get.delete<AccountWebSocketService>(force: true);
            }
            Get.put<AccountWebSocketService>(
              AccountWebSocketService(),
              permanent: true,
            );
            print('AuthController: AccountWebSocketService re-initialized');
          } catch (e) {
            print(
              'AuthController: Error re-initializing AccountWebSocketService: $e',
            );
          }

          print(
            'AuthController: All controllers re-initialized for new registered user',
          );

          final message = response.data!.message.trim().isNotEmpty
              ? response.data!.message
              : 'Registration completed successfully';
          CustomToastService.showSuccess(message: message, title: 'Success');
        } else {
          CustomToastService.showError(
            message: 'Invalid response structure from server',
            title: 'Error',
          );

          return false;
        }
      } else {
        final errorMessage = _resolveApiMessage(
          data: response.data,
          responseMessage: response.message,
          fallback: 'Registration failed',
        );
        _errorMessage.value = errorMessage;
        CustomToastService.showError(message: errorMessage, title: 'Error');
        return false;
      }

      return true;
    } catch (e) {
      final errorMessage = 'Registration error: $e';
      _errorMessage.value = errorMessage;
      CustomToastService.showError(message: errorMessage, title: 'Error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== OTP METHODS ====================
  Future<bool> sendOTP({required String email}) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _sendOtp(email: email);

      if (response.success && response.data != null) {
        _otpSentEmail.value = email;
        _otpSentMessage.value =
            response.data!['message'] ?? 'OTP sent successfully';

        CustomToastService.showSuccess(
          message: _otpSentMessage.value,
          title: 'Success',
        );

        return true;
      } else {
        _setError(response.message ?? 'Failed to send OTP');
        return false;
      }
    } catch (e) {
      _setError('Send OTP error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Future<bool> verifyOTP({required Map<String, dynamic> data}) async {
  //   try {
  //     _setLoading(true);
  //     _clearError();
  //
  //     final response = await _authService.register(data: data);
  //
  //     if (response.success && response.data != null) {
  //       _registerData.value = response.data;
  //
  //       CustomToastService.showSuccess(
  //         message: 'OTP verified successfully',
  //         title: 'Success',
  //       );
  //
  //       return true; // Return success for OTP flow
  //     } else {
  //       _setError(response.message ?? 'Registration failed');
  //       return false;
  //     }
  //   } catch (e) {
  //     _setError('Verify OTP error: $e');
  //     return false;
  //   } finally {
  //     _setLoading(false);
  //   }
  // }

  // Future<bool> verifyOTP({required String email, required String otp}) async {
  //   try {
  //     _setLoading(true);
  //     _clearError();
  //
  //     final response = await _authService.verifyOTP(email: email, otp: otp);
  //
  //     if (response.success && response.data != null) {
  //       _verifiedEmail.value = email;
  //       _verifiedOtp.value = otp;
  //
  //       CustomToastService.showSuccess(
  //         message: 'OTP verified successfully',
  //         title: 'Success',
  //       );
  //
  //       return true;
  //     } else {
  //       _setError(response.message ?? 'OTP verification failed');
  //       return false;
  //     }
  //   } catch (e) {
  //     _setError('Verify OTP error: $e');
  //     return false;
  //   } finally {
  //     _setLoading(false);
  //   }
  // }

  Future<void> resendOTP({required String email}) async {
    await sendOTP(email: email);
  }

  // ==================== PASSWORD RESET METHODS ====================
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );

      if (response.success && response.data != null) {
        CustomToastService.showSuccess(
          message: 'Password reset successfully',
          title: 'Success',
        );

        // Navigate to login screen
        Get.offAllNamed(AppPages.LOGIN);
      } else {
        _setError(response.message ?? 'Password reset failed');
      }
    } catch (e) {
      _setError('Reset password error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== LOGOUT & UTILITY METHODS ====================

  /// Centralized method to clear all user data, disconnect sockets, and reset controllers
  /// This ensures consistent cleanup across logout, account deletion, and offline logout
  Future<void> _clearAllUserData() async {
    print('AuthController: Starting centralized cleanup of all user data');

    // 1. Clear secure storage and cache
    await SecureStorageService.clearAuthData();
    await SecureStorageService.clearBiometricState();
    await AccountCacheService.clearCache();
    print('AuthController: Cleared secure storage and account cache');

    // 2. Clear WebSocketEndpointHelper cache
    WebSocketEndpointHelper.setPrimaryAccount(null);
    print('AuthController: Cleared WebSocket endpoint helper cache');

    // 3. Disconnect and DELETE all WebSocket services and controllers

    // Clear TradingWebSocketService
    try {
      if (Get.isRegistered<TradingWebSocketService>()) {
        final tradingWebSocketService = Get.find<TradingWebSocketService>();
        tradingWebSocketService.clearAllDataAndDisconnect();
        Get.delete<TradingWebSocketService>(force: true);
        print('AuthController: Trading WebSocket disconnected and deleted');
      }
    } catch (e) {
      print('AuthController: Error clearing trading WebSocket service: $e');
    }

    // Clear InstrumentsController (has WebSocket)
    try {
      if (Get.isRegistered<InstrumentsController>()) {
        final instrumentsController = Get.find<InstrumentsController>();
        instrumentsController.disconnectWebSocket();
        Get.delete<InstrumentsController>(force: true);
        print(
          'AuthController: Instruments controller disconnected and deleted',
        );
      }
    } catch (e) {
      print('AuthController: Error clearing Instruments controller: $e');
    }

    // Clear ChartSocketController (has WebSocket)
    try {
      if (Get.isRegistered<ChartSocketController>()) {
        final chartSocketController = Get.find<ChartSocketController>();
        chartSocketController.resetController();
        Get.delete<ChartSocketController>(force: true);
        print(
          'AuthController: Chart socket controller disconnected and deleted',
        );
      }
    } catch (e) {
      print('AuthController: Error clearing Chart socket controller: $e');
    }

    // Clear AccountWebSocketService
    try {
      if (Get.isRegistered<AccountWebSocketService>()) {
        Get.delete<AccountWebSocketService>(force: true);
        print('AuthController: Account WebSocket disconnected and deleted');
      }
    } catch (e) {
      print('AuthController: Error disconnecting Account WebSocket: $e');
    }

    // 4. Clear all controller data and DELETE them

    // Clear DashboardController
    try {
      if (Get.isRegistered<DashboardController>()) {
        final dashboardController = Get.find<DashboardController>();
        dashboardController.clearAllData();
        Get.delete<DashboardController>(force: true);
        print('AuthController: DashboardController cleared and deleted');
      }
    } catch (e) {
      print('AuthController: Error clearing DashboardController: $e');
    }

    // Clear AccountController
    try {
      if (Get.isRegistered<AccountController>()) {
        Get.delete<AccountController>(force: true);
        print('AuthController: AccountController deleted');
      }
    } catch (e) {
      print('AuthController: Error clearing AccountController: $e');
    }

    // Clear TradingController
    try {
      if (Get.isRegistered<TradingController>()) {
        final tradingController = Get.find<TradingController>();
        tradingController.clearAllTradingData();
        tradingController.clearInstruments();
        tradingController.pendingPositions.clear();
        tradingController.marketPositions.clear();
        tradingController.closedPositions.clear();
        Get.delete<TradingController>(force: true);
        print('AuthController: TradingController cleared and deleted');
      }
    } catch (e) {
      print('AuthController: Error clearing TradingController: $e');
    }

    // Clear WalletController
    try {
      if (Get.isRegistered<WalletController>()) {
        final walletController = Get.find<WalletController>();
        walletController.clearAllWalletData();
        Get.delete<WalletController>(force: true);
        print('AuthController: WalletController cleared and deleted');
      }
    } catch (e) {
      print('AuthController: Error clearing WalletController: $e');
    }

    // 5. Reset AuthController state
    _loginResponse.value = null;
    _userData.value = null;
    _isAuthenticated.value = false;
    _registerData.value = null;
    _clearError();

    // Clear runtime lock state
    try {
      if (Get.isRegistered<AppLockService>()) {
        Get.find<AppLockService>().clearLock();
      }
    } catch (_) {}

    print('AuthController: All user data cleared successfully');
  }

  Future<void> logout() async {
    try {
      _setLoading(true);
      _clearError();
      final token = await SecureStorageService.getAuthToken();

      final response = await _authRepo.logout(token: token);

      if (response.success && response.data != null) {
        await _clearAllUserData();
        Get.offAllNamed(AppPages.GET_STARTED);
      } else {
        print('AuthController: Logout failed - ${response.message}');
        await _clearAllUserData();
        Get.offAllNamed(AppPages.GET_STARTED);
      }
    } catch (e) {
      print('AuthController: Logout error: $e');
      try {
        await _clearAllUserData();
        Get.offAllNamed(AppPages.GET_STARTED);
      } catch (cleanupError) {
        print('AuthController: Cleanup error: $cleanupError');
        Get.offAllNamed(AppPages.GET_STARTED);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      _clearError();

      final token = await SecureStorageService.getAuthToken();

      // ["password":pasword,"reason": "No longer need the service","accept_terms": true,"confirm_deletion": true]
      final response = await _authRepo.deleteAccount(token: token!, data: data);

      if (response.success && response.data != null) {
        // Use centralized cleanup method
        await _clearAllUserData();

        // Navigate to get started screen
        Get.offAllNamed(AppPages.GET_STARTED);
      } else {
        // Don't show error UI - just log it
        print('AuthController: Delete account failed - ${response.message}');
        // Show error toast before navigation
        CustomToastService.showError(
          title: 'Error',
          message: response.message ?? 'Something went wrong',
        );
      }
    } catch (e) {
      // Don't show error UI after navigation - just log it
      print('AuthController: Delete account error: $e');
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to delete account',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logoutWithOutApi() async {
    try {
      await _clearAllUserData();
      Get.offAllNamed(AppPages.GET_STARTED);
    } catch (e) {
      print('AuthController: Logout without API error: $e');
      Get.offAllNamed(AppPages.GET_STARTED);
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final isLoggedIn = await SecureStorageService.isUserLoggedIn();
      // If we have a persisted session and a token, default to authenticated.
      // We'll only mark unauthenticated when the server explicitly rejects it.
      _isAuthenticated.value = isLoggedIn;

      if (isLoggedIn) {
        // Try to get stored user data
        final userData = await SecureStorageService.getUserData();
        if (userData != null) {
          _userData.value = userData;
        }

        // Validate token by making a lightweight API call
        // This ensures the token is still valid (not expired or invalidated)
        final token = await SecureStorageService.getAuthToken();
        if (token != null && token.isNotEmpty) {
          try {
            // Make a lightweight API call to validate token
            final response = await _authRepo.fetchProfile(token: token);

            if (!response.success) {
              // IMPORTANT: Do NOT force logout for transient/server-side failures.
              // Only mark unauthenticated when the backend explicitly rejects the token.
              final messageRaw = response.message ?? '';
              final message = messageRaw.toLowerCase();

              final isExplicitUnauthorized =
                  message.contains('unauthorized') ||
                  message.contains('session expired') ||
                  message.contains('session has expired') ||
                  message.contains('please login again') ||
                  message.contains('please log in again') ||
                  message.contains('login again');

              final isRetrySignal =
                  messageRaw == 'RETRY_REQUEST' ||
                  (response.data is Map &&
                      (response.data as Map).containsKey('shouldRetry') &&
                      (response.data as Map)['shouldRetry'] == true);

              if (isExplicitUnauthorized) {
                print(
                  'AuthController: Token explicitly rejected ($messageRaw), user is not authenticated',
                );
                _isAuthenticated.value = false;
              } else if (isRetrySignal) {
                // Treat as temporary connection issue; keep session.
                print(
                  'AuthController: Token check requested retry; keeping session authenticated',
                );
                _isAuthenticated.value = true;
              } else {
                // Any other error (500, parsing, maintenance, etc.) should not drop the user to login.
                print(
                  'AuthController: Token validation failed for non-auth reason ($messageRaw); assuming session is valid',
                );
                _isAuthenticated.value = true;
              }
            } else {
              // Token is valid
              _isAuthenticated.value = true;
            }
          } catch (e) {
            // If validation fails with exception, check if it's network related
            print('AuthController: Error validating token: $e');
            final errorStr = e.toString().toLowerCase();
            final isNetworkError =
                errorStr.contains('socket') ||
                errorStr.contains('network') ||
                errorStr.contains('timeout') ||
                errorStr.contains('handshake');

            if (isNetworkError) {
              print('AuthController: Network exception, assuming offline mode');
              _isAuthenticated.value = true;
            } else {
              // Be conservative: don't drop persisted sessions due to unknown errors.
              _isAuthenticated.value = true;
            }
          }
        } else {
          _isAuthenticated.value = false;
        }
      }
    } catch (e) {
      print('AuthController checkAuthStatus error: $e');
      _isAuthenticated.value = false;
    }
  }

  void resetAuthState() {
    _loginResponse.value = null;
    _userData.value = null;
    _isAuthenticated.value = false;
    _otpSentEmail.value = '';
    _otpSentMessage.value = '';
    _verifiedEmail.value = '';
    _verifiedOtp.value = '';
    _registerData.value = null;
    _clearError();
  }

  // ==================== PRIVATE HELPER METHODS ====================
  String _resolveApiMessage({
    dynamic data,
    String? responseMessage,
    required String fallback,
  }) {
    if (data is Map<String, dynamic>) {
      final bodyMessage = data['message'];
      if (bodyMessage is String && bodyMessage.trim().isNotEmpty) {
        return bodyMessage.trim();
      }
    }
    if (responseMessage != null && responseMessage.trim().isNotEmpty) {
      return responseMessage.trim();
    }
    return fallback;
  }

  void _setLoading(bool loading) {
    _isLoading.value = loading;
  }

  void _setError(String error) {
    _errorMessage.value = error;
    if (error.isNotEmpty) {
      CustomToastService.showError(message: error);
    }
  }

  void _clearError() {
    _errorMessage.value = '';
  }

  // Get Profile Method
  Future<profile_model.SettingsProfileData?> getProfile() async {
    try {
      _isLoading.value = true;
      _clearError();

      final token = await SecureStorageService.getAuthToken();

      final response = await _authRepo.fetchProfile(token: token);

      if (response.success && response.data != null) {
        final profileData = profile_model.SettingsProfileData.fromJson(
          response.data,
        );
        _profileData.value = profileData;
        await _syncUserDataFromProfile(profileData);
        return profileData;
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to load profile',
        );
        return null;
      }
    } catch (e, t) {
      print('AuthController: Error getting profile: $e');
      print('AuthController: Error getting profile: $t');
      CustomToastService.showError(message: 'Failed to load profile: $e');
      return null;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _syncUserDataFromProfile(
    profile_model.SettingsProfileData profileData,
  ) async {
    final profileUser = profileData.data.user;
    if (profileUser.id == 0) return;

    final currentUser = _userData.value ?? await SecureStorageService.getUserData();
    final updatedUser = UserModel(
      id: profileUser.id,
      email: profileUser.email,
      emailVerifiedAt:
          profileUser.emailVerifiedAt.toIso8601String(),
      createdAt: profileUser.createdAt.toIso8601String(),
      updatedAt: profileUser.updatedAt.toIso8601String(),
      userSlug: profileUser.userSlug,
      firstName: profileUser.firstName,
      lastName: profileUser.lastName,
      mobile: profileUser.mobile,
      mobileVerifiedAt:
          profileUser.mobileVerifiedAt.trim().isEmpty
              ? currentUser?.mobileVerifiedAt
              : profileUser.mobileVerifiedAt,
      status: profileUser.status,
      regComplete: profileUser.regComplete,
      deletedAt:
          profileUser.deletedAt.trim().isEmpty
              ? currentUser?.deletedAt
              : profileUser.deletedAt,
      googleOtpEnabled: currentUser?.googleOtpEnabled ?? false,
    );

    _userData.value = updatedUser;

    final loginData = await SecureStorageService.getCompleteLoginData();
    if (loginData != null) {
      loginData['user'] = updatedUser.toJson();
      await SecureStorageService.saveUserData(jsonEncode(loginData));
    }
  }

  // Profile Update Method
  Future<void> updateProfile({
    required String title,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String dob,
    required String gender,
    required int state,
    required int city,
    required String address,
    required String nationality,
    required String cityName,
    // required String otp,
    required int countryId,
    String postcode = '',
    String address2 = '',
  }) async {
    try {
      _isLoading.value = true;
      _clearError();

      final token = await SecureStorageService.getAuthToken();

      final response = await _authRepo.updateProfileData(
        token: token,
        data: {
          "page1": {"email": email, "title": title, "gender": gender},
          "page2": {
            "date_of_birth": dob,
            "alt_mobile": phone,
            "alt_email": email,
          },
          "page3": {
            "country": countryId,
            "state": state,
            "city": city,
            "nationality": nationality, // you’ll need to pass this
          },
          "page4": {
            "address_line1": address,
            "address_line2": cityName,
            "postcode": postcode,
            "language": "English",
          },
          "page5": {
            "us_citizen": "yes",
            "politically_exposed": "no",
            "industry": "finance",
            "tax_identification_number": "123456789",
          },
          // Keep common params outside if required by API
          "is_app": "1",
          "user_id": _userData.value?.id ?? '',
          "auth_key": token,
        },
      );

      if (response.success) {
        // Show success toast
        CustomToastService.showSuccess(
          message: response.message ?? 'Profile updated successfully!',
        );

        // Navigate to next page
        Get.toNamed(AppPages.KYC_DOCS);
      } else {
        // Show error toast
        CustomToastService.showError(
          message: response.message ?? 'Failed to update profile',
        );
      }
    } catch (e) {
      print('AuthController: Error updating profile: $e');
      CustomToastService.showError(message: 'Failed to update profile: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  // ==================== FORGOT PASSWORD METHODS ====================
  Future<void> forgotPassword({required Map<String, dynamic> data}) async {
    try {
      _setLoading(true); // show activity indicator
      _clearError();

      final response = await _forgotPassword(data: data);

      print('FORGOT PASSWORD DATA');
      print(response.data);
      final responseData = response.data;
      final map = responseData is Map<String, dynamic> ? responseData : null;
      final status = map?['status'];
      final message = map?['message'] ?? 'Something went wrong';
      if (status == true) {
        CustomToastService.showSuccess(message: message, title: 'Success');

        // Go back to previous screen
        Get.toNamed(AppPages.LOGIN);
      } else {
        print("ELSE FORGOT PASSOWRD STATUS ${status}");
        CustomToastService.showError(message: message);
      }
    } catch (e, t) {
      print("CATCH FORGOT PASSOWRD STATUS ${e}");
      print("CATCH TT FORGOT PASSOWRD STATUS ${t}");
      _setError('Forgot password error: $e');
    } finally {
      _setLoading(false); // hide activity indicator
    }
  }

  // ==================== PASSWORD RESET OTP FLOW METHODS ====================
  Future<void> requestPasswordResetOTP({required String email}) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _requestPasswordResetOtp(email: email);

      if (response.success && response.data != null) {
        final data = response.data!;
        final apiStatus = data['status'];
        if (apiStatus == false) {
          final errorMessage =
              data['message']?.toString() ??
              response.message ??
              'Failed to send OTP';
          CustomToastService.showError(title: 'Error', message: errorMessage);
          return;
        }

        final message =
            data['message']?.toString() ?? 'OTP sent to your email.';
        CustomToastService.showSuccess(message: message, title: 'Success');

        // Navigate to verify code screen with email
        Get.toNamed(AppPages.VERIFY_CODE, arguments: email);
      } else {
        final errorMessage = response.message ?? 'Failed to send OTP';
        CustomToastService.showError(title: 'Error', message: errorMessage);
      }
    } catch (e) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to send OTP: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _verifyPasswordResetOtp(email: email, otp: otp);

      if (response.success && response.data != null) {
        final message = response.data?['message'] ?? 'OTP verified.';
        CustomToastService.showSuccess(message: message, title: 'Success');

        // Navigate to create new password screen with email and otp
        Get.toNamed(
          AppPages.CREATE_NEW_PASSWORD,
          arguments: {'email': email, 'otp': otp},
        );
      } else {
        final errorMessage = response.message ?? 'OTP verification failed';
        CustomToastService.showError(message: errorMessage);
        _setError(errorMessage);
      }
    } catch (e) {
      _setError('Verify OTP error: $e');
      CustomToastService.showError(message: 'OTP verification failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPasswordWithOTP({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _resetPasswordWithOtp(
        email: email,
        otp: otp,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      if (response.success && response.data != null) {
        final message =
            response.data?['message'] ?? 'Password reset successfully';
        CustomToastService.showSuccess(message: message, title: 'Success');

        // Navigate to login screen
        Get.offAllNamed(AppPages.LOGIN);
      } else {
        final errorMessage = response.message ?? 'Password reset failed';
        CustomToastService.showError(message: errorMessage);
        _setError(errorMessage);
      }
    } catch (e) {
      _setError('Reset password error: $e');
      CustomToastService.showError(message: 'Password reset failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _navigatePostAuth() async {
    try {
      final profile = await getProfile();
      if (profile != null) {
        final user = profile.data.user;
        final details = user.userDetails;
        
        final forceRegulatedForm = user.forceRegulatedForm;
        final regulationSubmitted = user.regulationSubmitted;
        final documentsSubmitted = details.documentsSubmitted;

        if (forceRegulatedForm == 1) {
          if (regulationSubmitted == 0) {
            Get.offAllNamed(AppPages.COMPLIANCE_WIZARD);
            return;
          } else if (!documentsSubmitted) {
            Get.offAllNamed(AppPages.COMPLIANCE_WIZARD);
            // Set Step 2 active in controller
            Get.put(ComplianceController()).currentStep.value = 1;
            return;
          }
        }
      }
    } catch (e) {
      print('AuthController: Post auth compliance check failed: $e');
    }
    Get.offAllNamed(AppPages.TRADING);
  }

  Future<void> _registerFcmTokenInBackground(String authToken) async {
    try {
      String? fcmToken = await SecureStorageService.getFcmToken();
      if (fcmToken == null) return;

      String deviceType = Platform.isIOS ? 'ios' : 'android';

      await _authRepo.registerFcmToken(
        token: authToken,
        data: {'fcm_token': fcmToken, 'device_type': deviceType},
      );
      print('✅ AuthController: Registered FCM token in background');
    } catch (e) {
      print('⚠️ AuthController: Failed to register FCM token: $e');
    }
  }
}
