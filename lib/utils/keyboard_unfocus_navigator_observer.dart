import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global NavigatorObserver that hides the on-screen keyboard whenever the
/// user navigates between screens (push / pop / replace / remove).
///
/// Why: several screens use `autofocus: true` on a `TextField` (e.g. the
/// instrument search sheet) or leave a field focused when the user taps a
/// button that navigates away. On Android in particular, if the focused
/// field is not unfocused BEFORE the route change, the system keyboard
/// stays open (or re-opens) on the destination screen, which is jarring
/// and never what we want.
///
/// This observer is wired into `GetMaterialApp.navigatorObservers` in
/// `main.dart` so the behaviour applies app-wide — no per-screen changes
/// needed.
class KeyboardUnfocusNavigatorObserver extends NavigatorObserver {
  void _hideKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.hasFocus) {
      focus.unfocus();
    }
    // Safety net: explicitly hide the platform keyboard in case a
    // widget re-grabs focus during the transition.
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _hideKeyboard();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _hideKeyboard();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _hideKeyboard();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _hideKeyboard();
    super.didRemove(route, previousRoute);
  }
}