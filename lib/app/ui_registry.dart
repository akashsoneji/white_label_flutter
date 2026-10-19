import 'package:flutter/widgets.dart';

import 'package:crm_app/flavor_config.dart';
import 'package:get/get.dart';
import 'package:crm_app/brands/brand_resolver.dart';

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

import 'package:crm_app/screens/auth/presentation/brands/riyadex/pages/riyadex_create_account_screen.dart'
    as riyadex;
import 'package:crm_app/screens/auth/presentation/brands/riyadex/pages/riyadex_get_started_screen.dart'
    as riyadex;
import 'package:crm_app/screens/auth/presentation/brands/iquote/pages/iquote_create_account_screen.dart'
    as iquote;
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
///
/// Falls back to the build-time `FLAVOR` define when `CLIENT` is empty.
String get activeClient {
  final clientFromDefine = String.fromEnvironment('CLIENT', defaultValue: '');
  if (clientFromDefine.isNotEmpty) return clientFromDefine.toLowerCase();

  // Read the active flavor that `main.dart` already resolved via
  // `_initializeFlavor()`. This makes UI routing honour the same brand
  // the rest of the app is configured for (colors, theme, API endpoints,
  // etc.)
  try {
    final name = FlavorConfig.instance.flavor.name.toLowerCase();
    if (name.isNotEmpty) return name;
  } catch (_) {
    // FlavorConfig may not be initialised yet (very early startup).
    // Fall through to the FLAVOR env-define below.
  }

  final flavorFromDefine =
      const String.fromEnvironment('FLAVOR', defaultValue: '').toLowerCase();
  if (flavorFromDefine.isNotEmpty) return flavorFromDefine;

  if (Get.isRegistered<BrandResolver>()) {
    return Get.find<BrandResolver>().activeBrand.value.value;
  }

  return 'tenax';
}

/// Active UI parent selected at build time.
///
///
///
/// Resolution order:
///   1. `--dart-define=PARENT=...`           (the explicit override)
///   2. `FlavorConfig.usesVantageUi` / etc.  (brand's `inheritsFrom`)
///   3. The brand itself                     (parent brands)
String get activeParent {
  final explicit =
      String.fromEnvironment('PARENT', defaultValue: '').trim().toLowerCase();
  if (explicit.isNotEmpty) return explicit;

  // Fall back to whatever the brand config thinks its parent is.
  try {
    if (FlavorConfig.usesVantageUi()) return 'vantage';
  } catch (_) {}
  try {
    if (FlavorConfig.usesIquoteUi()) return 'iquote';
  } catch (_) {}
  // Parent brands render as themselves.
  return activeClient;
}

/// Routes a CLIENT to its design parent. Child brands inherit their
/// parent's screens.
///
/// The map MUST contain every brand that can be activated at runtime.
/// Each entry points at the brand whose screen files should be used.
///
const Map<String, String> _uiParentByClient = {
  // Parents
  'vantage': 'vantage',
  'iquote': 'vantage',
  'celestial': 'celestial',
  'afx': 'celestial',
  'meta': 'meta',
  'tenax': 'tenax',
  'pipze': 'iquote',
  'skyriss': 'iquote',
  'baazex': 'vantage',
  'telifox': 'vantage',
  'kantara': 'celestial',
  'starfx': 'celestial',
  'gtxprime': 'vantage',
  'riyadex': 'vantage',
  'pippro': 'vantage',
  'moneygenius': 'celestial',
};

/// Picks the right `screens.dart`-style widget set for the active client
/// **and** the active parent (overridable via `--dart-define=PARENT=`).
class UiRegistry implements UiSlots {
  UiRegistry._();

  static final UiRegistry instance = UiRegistry._();

  String get _uiBrand => activeClient;

  /// Build-time-selected parent for the active brand (PARENT env-define
  /// wins, otherwise the brand's default parent from `BrandResolver`).
  String get _uiParent {
    if (Get.isRegistered<BrandResolver>()) {
      return Get.find<BrandResolver>().activeUiParent;
    }
    final explicit =
        const String.fromEnvironment('PARENT', defaultValue: '').trim().toLowerCase();
    if (explicit.isNotEmpty) return explicit;
    return _uiParentByClient[_uiBrand] ?? _uiBrand;
  }

  bool get _usesVantageUi => _uiParent == 'vantage';

  bool get _usesIquoteUi => _uiParent == 'iquote';

  bool get _usesCelestialUi => _uiParent == 'celestial';

  bool get _usesMetaUi => _uiParent == 'meta';

  // ─── Auth flow ───────────────────────────────────────────────────────────

  @override
  Widget splash() => const SplashScreen();

  @override
  Widget getStarted() {
    final flavorName = FlavorConfig.instance.flavor.name.toLowerCase();
    if (flavorName == 'riyadex') return const riyadex.RiyadexGetStartedScreen();
    if (_usesVantageUi || _usesIquoteUi) return vantage.VantageGetStartedScreen();
    return GetStartedScreen();
  }

  @override
  Widget login() {
    if (_usesVantageUi || _usesIquoteUi) return vantage.VantageLoginScreen();
    return LoginScreen();
  }

  @override
  Widget createAccount() {
    final flavorName = FlavorConfig.instance.flavor.name.toLowerCase();
    if (flavorName == 'riyadex') {
      return const riyadex.RiyadexCreateAccountScreen();
    }
    if (flavorName == 'iquote') {
      return const iquote.IquoteCreateAccountScreen();
    }
    if (_usesVantageUi || _usesIquoteUi) return vantage.VantageCreateAccountScreen();
    return CreateAccountScreen();
  }

  @override
  Widget forgotPassword() {
    if (_usesVantageUi || _usesIquoteUi) return vantage.VantageForgotPasswordScreen();
    return ForgotPasswordScreen();
  }

  @override
  Widget verifyCode({required String email}) {
    if (_usesVantageUi || _usesIquoteUi) return vantage.VantageVerifyCodeScreen(email: email);
    return VerifyCodeScreen(email: email);
  }

  @override
  Widget createNewPassword() {
    if (_usesVantageUi || _usesIquoteUi) return vantage.VantageCreateNewPasswordScreen();
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
