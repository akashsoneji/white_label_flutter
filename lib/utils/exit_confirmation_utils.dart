import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crm_app/widgets/exit_confirmation_dialog.dart';

class ExitConfirmationUtils {
  /// Shows exit confirmation dialog and exits app if user confirms
  static Future<void> showExitConfirmation(BuildContext context) async {
    final bool? shouldExit = await ExitConfirmationDialog.show(context);

    if (shouldExit == true) {
      // User confirmed exit
      SystemNavigator.pop(); // Exit the app
    }
    // If shouldExit is false or null, do nothing (stay in app)
  }

  /// Handles back button with exit confirmation for specific screens
  static Future<bool> handleBackButton(
    BuildContext context, {
    bool showExitDialog = true,
  }) async {
    if (showExitDialog) {
      await showExitConfirmation(context);
      return false; // Prevent default back behavior
    } else {
      return true; // Allow default back behavior
    }
  }
}
