import 'package:flutter/widgets.dart';

import '../app/ui_slots.dart';

/// Brand-specific UI factory. Each brand can provide its own full app UI
/// (screens/components) without scattering `if (brand==x)` checks everywhere.
abstract class BrandWidgets {
  // ── Auth ──
  Widget splash();
  Widget getStarted();
  Widget login();
  Widget createAccount();
  Widget forgotPassword();
  Widget verifyCode({required String email});
  Widget createNewPassword();

  // ── Main app ──
  Widget tradingMain();
  Widget more();
  Widget finance();
  Widget kycIntro();
}

/// Adapter so existing code can keep using `BrandWidgets`,
/// while implementations come from the Claude-style `UiSlots` registry.
class BrandWidgetsFromSlots implements BrandWidgets {
  final UiSlots slots;

  const BrandWidgetsFromSlots(this.slots);

  @override
  Widget splash() => slots.splash();

  @override
  Widget getStarted() => slots.getStarted();

  @override
  Widget login() => slots.login();

  @override
  Widget createAccount() => slots.createAccount();

  @override
  Widget forgotPassword() => slots.forgotPassword();

  @override
  Widget verifyCode({required String email}) => slots.verifyCode(email: email);

  @override
  Widget createNewPassword() => slots.createNewPassword();

  @override
  Widget tradingMain() => slots.tradingMain();

  @override
  Widget more() => slots.more();

  @override
  Widget finance() => slots.finance();

  @override
  Widget kycIntro() => slots.kycIntro();
}

