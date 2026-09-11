import 'dart:io';
import '../constants/text_styles.dart';
import '../services/language_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global wrapper that:
/// 1. Dismisses the on-screen keyboard when the user taps anywhere outside a
///    text field (works on both Android and iOS).
/// 2. On iOS, shows a small "Done" toolbar floating just above the keyboard
///    whenever ANY keyboard is up. iOS numeric / decimal / phone keyboards
///    have no return key at all, and even the alphabetic keyboard's return
///    key often submits/newlines instead of dismissing — so users otherwise
///    have no reliable way to close the keyboard. The toolbar gives them a
///    consistent "Done" button on every screen.
///
/// Wrap the app's top-level child with this widget so the behaviour applies
/// to every screen without touching individual `TextField`s.
class KeyboardDismissWrapper extends StatefulWidget {
  final Widget child;

  const KeyboardDismissWrapper({super.key, required this.child});

  @override
  State<KeyboardDismissWrapper> createState() => _KeyboardDismissWrapperState();
}

class _KeyboardDismissWrapperState extends State<KeyboardDismissWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Keyboard show/hide changes viewInsets; rebuild so the Done bar tracks it.
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Whether there is currently a focused text field on iOS. We show the
  /// Done bar for ALL keyboard types (not just numeric) because the user
  /// asked for a dismiss button on every keyboard on iOS.
  bool get _shouldShowDoneBar {
    if (!Platform.isIOS) return false;
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return false;
    final ctx = focused.context;
    if (ctx == null) return false;
    final editable = ctx.findAncestorWidgetOfExactType<EditableText>();
    return editable != null;
  }

  void _dismiss() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused != null) {
      focused.unfocus();
    }
    // Safety net: explicitly hide the platform keyboard.
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  /// Called on every pointer-down. We DO NOT consume the event — the tap
  /// still reaches the underlying widget (so bottom nav / buttons keep
  /// working). We only trigger dismiss when:
  /// - a text field is currently focused (keyboard is up), AND
  /// - the tap is NOT inside the bottom nav area / keyboard area.
  void _maybeDismissOnTap(PointerDownEvent event, MediaQueryData mq) {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return;
    // Only dismiss if a real text field is focused.
    final ctx = focused.context;
    if (ctx == null) return;
    if (ctx.findAncestorWidgetOfExactType<EditableText>() == null) return;

    final screenHeight = mq.size.height;
    final bottomInset = mq.viewInsets.bottom;
    // Reserve the bottom navigation strip so taps there switch tabs
    // instead of just dismissing the keyboard. 80px covers the nav bar
    // on all our screens (safe area + icons).
    final bottomNavZone = mq.padding.bottom + 80;

    final tapY = event.position.dy;
    final inKeyboardZone = tapY > screenHeight - bottomInset;
    final inBottomNavZone = tapY > screenHeight - bottomNavZone;

    if (inKeyboardZone || inBottomNavZone) return;

    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final showDoneBar = _shouldShowDoneBar && bottomInset > 0;

    return Stack(
      children: [
        TapRegion(
          groupId: EditableText,
          onTapOutside: (event) => _maybeDismissOnTap(event as PointerDownEvent, mq),
          child: widget.child,
        ),
        if (showDoneBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: _DoneBar(onTap: _dismiss),
          ),
      ],
    );
  }
}

class _DoneBar extends StatelessWidget {
  final VoidCallback onTap;
  const _DoneBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD1D5DB),
      elevation: 0,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  foregroundColor: const Color(0xFF007AFF),
                ),
                child: Text(
                  TranslationUtils.tr('navigation_done'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
