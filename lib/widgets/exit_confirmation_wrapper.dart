import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crm_app/widgets/exit_confirmation_dialog.dart';

/// Wrapper widget that handles back button presses with exit confirmation dialog.
///
/// Usage:
/// ```dart
/// ExitConfirmationWrapper(
///   forceExitDialog: true, // Always show exit dialog
///   child: YourScreen(),
/// )
/// ```
///
/// Features:
/// - Shows exit confirmation dialog when back button is pressed
/// - Automatically detects main screens with bottom navigation
/// - Can be forced to always show exit dialog
/// - Falls back to normal navigation for nested screens
class ExitConfirmationWrapper extends StatelessWidget {
  final Widget child;
  final bool showExitDialog;
  final bool
  forceExitDialog; // Force exit dialog even when navigation stack exists

  const ExitConfirmationWrapper({
    Key? key,
    required this.child,
    this.showExitDialog = true,
    this.forceExitDialog = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) async {
        if (!didPop && showExitDialog) {
          await _handleBackButton(context);
        }
      },
      child: child,
    );
  }

  Future<void> _handleBackButton(BuildContext context) async {
    // Check if we should show exit dialog
    bool shouldShowExitDialog = forceExitDialog;

    // If not forced, check if we're at the root of navigation stack
    if (!shouldShowExitDialog) {
      // Check if we can pop (if not, we're at root)
      shouldShowExitDialog = !Navigator.of(context).canPop();

      // Also check if we're on a main screen with bottom navigation
      if (!shouldShowExitDialog) {
        final currentRoute = ModalRoute.of(context)?.settings.name;
        shouldShowExitDialog = _isMainScreenWithBottomNav(currentRoute);
      }
    }

    if (shouldShowExitDialog) {
      // Show exit confirmation dialog
      final bool? shouldExit = await ExitConfirmationDialog.show(context);

      if (shouldExit == true) {
        // User confirmed exit
        SystemNavigator.pop(); // Exit the app
      }
      // If shouldExit is false or null, do nothing (stay in app)
    } else {
      // Normal navigation - go back
      Navigator.of(context).pop();
    }
  }

  /// Check if current route is a main screen with bottom navigation
  bool _isMainScreenWithBottomNav(String? routeName) {
    if (routeName == null) return false;

    // Main screens with bottom navigation that should show exit dialog
    const mainScreensWithBottomNav = [
      '/trading', // TradingMainScreen
      '/ib-main', // IbMainScreen
    ];

    return mainScreensWithBottomNav.contains(routeName);
  }
}
