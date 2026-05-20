import 'package:flutter/material.dart';

import '../../../constants/color.dart';
import '../../../flavor_config.dart';

/// Shared auth-flow colors derived from the active flavor.
class AuthScreenTheme {
  AuthScreenTheme._();

  static Color get scaffoldBackground =>
      FlavorConfig.isVantage()
          ? FlavorConfig.instance.secondaryColor
          : AppColors.backgroundLight;

  static Color get primary => AppColors.primary;
}
