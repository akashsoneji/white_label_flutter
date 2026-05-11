import 'package:flutter/material.dart';
import 'package:crm_app/widgets/exit_confirmation_dialog.dart';

class BackButtonHandler extends StatelessWidget {
  final Widget child;
  final bool showExitDialog;
  final VoidCallback? onBackPressed;

  const BackButtonHandler({
    Key? key,
    required this.child,
    this.showExitDialog = true,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackButton(context);
        }
      },
      child: child,
    );
  }

  Future<void> _handleBackButton(BuildContext context) async {
    if (onBackPressed != null) {
      // Use custom back handler
      onBackPressed!();
    } else if (showExitDialog) {
      // Show exit confirmation dialog
      final bool? shouldExit = await ExitConfirmationDialog.show(context);

      if (shouldExit == true) {
        // User confirmed exit
        Navigator.of(context).pop();
      }
      // If shouldExit is false or null, do nothing (stay in app)
    } else {
      // No dialog, just go back
      Navigator.of(context).pop();
    }
  }
}
