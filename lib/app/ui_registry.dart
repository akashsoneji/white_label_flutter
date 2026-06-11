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
/// Use: `--dart-define=CLIENT=tenax|vantage|celestial|pipze`
/// Child brands inherit their parent screen files based on brands.yaml.
const String activeClient = String.fromEnvironment(
  'CLIENT',
  defaultValue: 'tenax',
);

class UiRegistry implements UiSlots {
  final String client;

  const UiRegistry({required this.client});

  // Keep this synchronous for widget factories. Regenerate/update this map from
  // assets/config/brands/brands.yaml when parent-child UI inheritance changes.
  static const Map<String, String> _uiParentByClient = {
    'vantage': 'vantage',
    'celestial': 'vantage',
    'pipze': 'vantage',
    'skyriss': 'vantage',
    'tenax': 'vantage',
  };

  String get _uiBrand => _uiParentByClient[client.toLowerCase()] ?? client.toLowerCase();

  bool get _usesVantageUi => _uiBrand == 'vantage';

  @override
  Widget splash() => const SplashScreen();

  @override
  Widget getStarted() {
    if (_usesVantageUi) return VantageGetStartedScreen();
    return GetStartedScreen();
  }

  @override
  Widget login() {
    if (_usesVantageUi) return const VantageLoginScreen();
    return const LoginScreen();
  }

  @override
  Widget createAccount() {
    if (_usesVantageUi) return const VantageCreateAccountScreen();
    return const CreateAccountScreen();
  }

  @override
  Widget forgotPassword() {
    if (_usesVantageUi) return const VantageForgotPasswordScreen();
    return const ForgotPasswordScreen();
  }

  @override
  Widget verifyCode({required String email}) {
    if (_usesVantageUi) return VantageVerifyCodeScreen(email: email);
    return VerifyCodeScreen(email: email);
  }

  @override
  Widget createNewPassword() {
    if (_usesVantageUi) return const VantageCreateNewPasswordScreen();
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

