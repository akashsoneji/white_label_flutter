import 'package:flutter/material.dart';

import 'package:crm_app/widgets/app_back_button.dart';

/// @deprecated Use [AppBackButton] — kept for existing imports.
class AppSvgBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppSvgBackButton({super.key, this.onPressed});

  static void popRoute(BuildContext context) =>
      AppBackButton.popRoute(context);

  @override
  Widget build(BuildContext context) {
    return AppBackButton(
      onPressed: onPressed ?? () => AppBackButton.popRoute(context),
    );
  }
}
