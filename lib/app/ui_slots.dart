import 'package:flutter/widgets.dart';

/// Claude-style UI slots: shared logic, swappable presentation.
///
/// Each slot represents a screen/root widget whose UI can differ per client,
/// while controllers/usecases remain shared.
abstract class UiSlots {
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

