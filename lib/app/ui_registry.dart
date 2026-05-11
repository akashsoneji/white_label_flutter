import 'package:flutter/widgets.dart';

import '../screens/auth/presentation/pages/create_account_screen.dart';
import '../screens/auth/presentation/pages/create_new_password_screen.dart';
import '../screens/auth/presentation/pages/forgot_password_screen.dart';
import '../screens/auth/presentation/pages/get_started_screen.dart';
import '../screens/auth/presentation/pages/login_screen.dart';
import '../screens/auth/presentation/pages/splash_screen.dart';
import '../screens/auth/presentation/pages/verify_code_screen.dart';
import '../screens/finance/presentation/pages/finance_screen.dart';
import '../screens/home/more/more_screen.dart';
import '../screens/kyc/presentation/pages/kyc_intro_screen.dart';
import '../screens/trading/presentation/pages/trading_main_screen.dart';

import '../screens/auth/presentation/brands/vantage/pages/create_account_screen.dart';
import '../screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart';
import '../screens/auth/presentation/brands/vantage/pages/forgot_password_screen.dart';
import '../screens/auth/presentation/brands/vantage/pages/get_started_screen.dart';
import '../screens/auth/presentation/brands/vantage/pages/login_screen.dart';
import '../screens/auth/presentation/brands/vantage/pages/verify_code_screen.dart';

import 'ui_slots.dart';

/// Build-time selected client (no runtime switching).
///
/// Use: `--dart-define=CLIENT=tenax` or `--dart-define=CLIENT=vantage`
const String activeClient = String.fromEnvironment(
  'CLIENT',
  defaultValue: 'tenax',
);

class UiRegistry implements UiSlots {
  final String client;

  const UiRegistry({required this.client});

  bool get _isVantage => client.toLowerCase() == 'vantage';

  @override
  Widget splash() => const SplashScreen();

  @override
  Widget getStarted() {
    if (_isVantage) return VantageGetStartedScreen();
    return GetStartedScreen();
  }

  @override
  Widget login() {
    if (_isVantage) return const VantageLoginScreen();
    return const LoginScreen();
  }

  @override
  Widget createAccount() {
    if (_isVantage) return const VantageCreateAccountScreen();
    return const CreateAccountScreen();
  }

  @override
  Widget forgotPassword() {
    if (_isVantage) return const VantageForgotPasswordScreen();
    return const ForgotPasswordScreen();
  }

  @override
  Widget verifyCode({required String email}) {
    if (_isVantage) return VantageVerifyCodeScreen(email: email);
    return VerifyCodeScreen(email: email);
  }

  @override
  Widget createNewPassword() {
    if (_isVantage) return const VantageCreateNewPasswordScreen();
    return const CreateNewPasswordScreen();
  }

  @override
  Widget tradingMain() => const TradingMainScreen();

  @override
  Widget more() => const MoreScreen();

  @override
  Widget finance() => const FinanceScreen();

  @override
  Widget kycIntro() => KycIntroScreen(stageCompletion: null);
}

