import 'package:flutter/widgets.dart';

import 'package:crm_app/flavor_config.dart';

import '../brands/meta/meta_main_shell.dart';
import '../brands/celestial/celestial_main_shell.dart';
import 'package:crm_app/screens/auth/presentation/pages/create_account_screen.dart';
import 'package:crm_app/screens/auth/presentation/pages/create_new_password_screen.dart';
import 'package:crm_app/screens/auth/presentation/pages/forgot_password_screen.dart';
import 'package:crm_app/screens/auth/presentation/pages/get_started_screen.dart';
import 'package:crm_app/screens/auth/presentation/pages/login_screen.dart';
import 'package:crm_app/screens/auth/presentation/pages/splash_screen.dart';
import 'package:crm_app/screens/auth/presentation/pages/verify_code_screen.dart';

import 'package:crm_app/screens/finance/presentation/pages/finance_screen.dart';
import 'package:crm_app/screens/home/more/more_screen.dart';
import 'package:crm_app/screens/kyc/presentation/pages/kyc_intro_screen.dart';
import 'package:crm_app/screens/trading/presentation/pages/trading_main_screen.dart';

import 'package:crm_app/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart'
    as vantage;
import 'package:crm_app/screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart'
    as vantage;
import 'package:crm_app/screens/auth/presentation/brands/vantage/pages/forgot_password_screen.dart'
    as vantage;
import 'package:crm_app/screens/auth/presentation/brands/vantage/pages/get_started_screen.dart'
    as vantage;
import 'package:crm_app/screens/auth/presentation/brands/vantage/pages/login_screen.dart'
    as vantage;
import 'package:crm_app/screens/auth/presentation/brands/vantage/pages/verify_code_screen.dart'
    as vantage;

import 'ui_slots.dart';

/// Build-time selected client (no runtime switching).
///
/// Use: `--dart-define=CLIENT=tenax|vantage|celestial|meta|pipze|telifox`
///
/// Falls back to the build-time `FLAVOR` define when `CLIENT` is empty.
/// Defaults to `tenax` only if neither define is set (matches the
/// previous default so existing dev workflows keep working).
String get activeClient {
  final clientFromDefine = String.fromEnvironment('CLIENT', defaultValue: '');
  if (clientFromDefine.isNotEmpty) return clientFromDefine.toLowerCase();

  // Read the active flavor that `main.dart` already resolved via
  // `_initializeFlavor()`. This makes UI routing honour the same brand
  // the rest of the app is configured for (colors, theme, API endpoints,
  // etc.) — previously the UI registry used its own env-define and
  // silently defaulted to 'tenax' for builds that only set FLAVOR,
  // causing Tenax's UI to render for every other brand.
  try {
    final name = FlavorConfig.instance.flavor.name.toLowerCase();
    if (name.isNotEmpty) return name;
  } catch (_) {
    // FlavorConfig may not be initialised yet (very early startup).
    // Fall through to the FLAVOR env-define below.
  }

  final flavorFromDefine =
      String.fromEnvironment('FLAVOR', defaultValue: '').toLowerCase();
  if (flavorFromDefine.isNotEmpty) return flavorFromDefine;

  return 'tenax';
}

/// Routes a CLIENT to its design parent. Child brands inherit their
/// parent's screens. Tenax is its own parent (it has its own design).
const Map<String, String> _uiParentByClient = {
  'vantage': 'vantage',
  'celestial': 'celestial',
  'pipze': 'vantage',
  'telifox': 'vantage',
  'kantara': 'vantage',
  'gtxprime': 'vantage',
  'baazex': 'vantage',
  'skyriss': 'vantage',
  'meta': 'meta',
  'tenax': 'tenax',
};

/// Picks the right `screens.dart`-style widget set for the active client.
class UiRegistry implements UiSlots {
  UiRegistry._();

  static final UiRegistry instance = UiRegistry._();

  /// Lower-cased client key (e.g. `pipze`, `tenax`, `vantage`).
  String get _uiBrand => activeClient;

  /// True for brands whose auth/UI design was authored for Vantage and
  /// is shared by all Vantage-inherited children.
  bool get _usesVantageUi => _uiParentByClient[_uiBrand] == 'vantage';

  bool get _usesCelestialUi => _uiParentByClient[_uiBrand] == 'celestial';

  bool get _usesMetaUi => _uiBrand == 'meta';

  // ─── Auth flow ───────────────────────────────────────────────────────────

  // Vantage has no dedicated splash screen — fall back to the generic one.
  @override
  Widget splash() => const SplashScreen();

  @override
  Widget getStarted() {
    if (_usesVantageUi) return vantage.VantageGetStartedScreen();
    return GetStartedScreen();
  }

  @override
  Widget login() {
    if (_usesVantageUi) return vantage.VantageLoginScreen();
    return LoginScreen();
  }

  @override
  Widget createAccount() {
    if (_usesVantageUi) return vantage.VantageCreateAccountScreen();
    return CreateAccountScreen();
  }

  @override
  Widget forgotPassword() {
    if (_usesVantageUi) return vantage.VantageForgotPasswordScreen();
    return ForgotPasswordScreen();
  }

  @override
  Widget verifyCode({required String email}) {
    if (_usesVantageUi) return vantage.VantageVerifyCodeScreen(email: email);
    return VerifyCodeScreen(email: email);
  }

  @override
  Widget createNewPassword() {
    if (_usesVantageUi) return vantage.VantageCreateNewPasswordScreen();
    return CreateNewPasswordScreen();
  }

  // ─── Main shell + tabs ───────────────────────────────────────────────────

  @override
  Widget tradingMain() {
    if (_usesMetaUi) return const MetaMainShell();
    if (_usesCelestialUi) return const CelestialMainShell();
    return const TradingMainScreen();
  }

  @override
  Widget more() => const MoreScreen();

  @override
  Widget finance() => const FinanceScreen();

  @override
  Widget kycIntro() => KycIntroScreen(stageCompletion: null);
}