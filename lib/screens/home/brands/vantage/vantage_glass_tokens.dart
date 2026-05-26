import 'package:flutter/material.dart';
import 'package:crm_app/constants/color.dart';

/// Vantage UI tokens (premium, dark-safe).
///
/// Intentionally avoids heavy “glass blur”. Uses crisp surfaces with subtle
/// brand accent and consistent borders/radii across Vantage-only screens.
class VantageUiTokens {
  VantageUiTokens._();

  static double get radiusLg => 18.0;
  static double get radiusMd => 14.0;
  static double get radiusSm => 12.0;

  static Color get borderColor =>
      AppColors.border.withValues(alpha: AppColors.isDarkMode ? 0.28 : 0.14);

  static Color get surface =>
      (AppColors.isDarkMode ? AppColors.surfaceDark : AppColors.card);

  static Color get surfaceAlt =>
      AppColors.surface.withValues(alpha: AppColors.isDarkMode ? 0.92 : 0.96);

  static List<BoxShadow> get cardShadow {
    if (AppColors.isDarkMode) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static LinearGradient get headerAccentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primary.withValues(alpha: AppColors.isDarkMode ? 0.22 : 0.10),
      AppColors.primary.withValues(alpha: AppColors.isDarkMode ? 0.04 : 0.02),
    ],
  );

  static BoxDecoration cardDecoration({bool accented = true}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(color: borderColor),
      boxShadow: cardShadow,
      gradient: accented ? headerAccentGradient : null,
    );
  }

  static BoxDecoration groupDecoration() {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(color: borderColor),
    );
  }

  static BoxDecoration pillDecoration() {
    return BoxDecoration(
      color: surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: borderColor),
    );
  }
}

