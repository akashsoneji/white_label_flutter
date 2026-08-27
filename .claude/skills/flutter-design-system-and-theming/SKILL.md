---
name: flutter-design-system-and-theming
description: |
  Comprehensive design system, Material 3 theming, color schemes, typography, glassmorphism, gradients, and custom token guidelines for Flutter.
  Use when styling widgets, adding Dark/Light mode support, creating custom ThemeExtensions, defining color palettes, or crafting premium modern UI cards/buttons.
  Triggers on: "theme", "dark mode", "light mode", "design system", "colors", "typography", "styling", "glassmorphism", "card design", "button styling".
---

# Flutter Design System & Theming Guidelines

Follow these standards to create modern, polished, and consistent Flutter UI designs:

## 1. Avoid Hardcoded Colors and Styles
- **Never** hardcode plain hex colors (e.g. `Color(0xFF1E1E1E)`) or raw text styles directly in feature widgets.
- Always read colors and text themes from `Theme.of(context)`:
  - `final theme = Theme.of(context);`
  - `final colorScheme = theme.colorScheme;`
  - `final textTheme = theme.textTheme;`

## 2. Using ThemeExtension for Custom Design Tokens
When the app requires custom semantic colors (e.g., success, warning, crypto profit/loss, border gradients), define a `ThemeExtension`:

```dart
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color primaryGradientStart;
  final Color primaryGradientEnd;
  final Color cardBackground;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color error;

  const AppColorsExtension({
    required this.primaryGradientStart,
    required this.primaryGradientEnd,
    required this.cardBackground,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.error,
  });

  @override
  AppColorsExtension copyWith({
    Color? primaryGradientStart,
    Color? primaryGradientEnd,
    Color? cardBackground,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? error,
  }) {
    return AppColorsExtension(
      primaryGradientStart: primaryGradientStart ?? this.primaryGradientStart,
      primaryGradientEnd: primaryGradientEnd ?? this.primaryGradientEnd,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      error: error ?? this.error,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      primaryGradientStart: Color.lerp(primaryGradientStart, other.primaryGradientStart, t)!,
      primaryGradientEnd: Color.lerp(primaryGradientEnd, other.primaryGradientEnd, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}
```

## 3. Premium Card & Glassmorphism Aesthetics
For high-end financial, trading, or modern dashboard cards:
- Use subtle border outlines (`Border.all(color: theme.colorScheme.outline.withOpacity(0.12), width: 1)`).
- Use smooth corner radii (`BorderRadius.circular(16)` or `20`).
- Implement frosted glass (Glassmorphism) with `BackdropFilter`:
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(16),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: child,
    ),
  ),
)
```

## 4. Typography Scale
- Use Material 3 text styles consistently:
  - `titleLarge` / `titleMedium` for headers and card titles.
  - `bodyMedium` / `bodySmall` for content and descriptions.
  - `labelSmall` / `labelMedium` for badges, tags, and timestamps.
- Maintain readable contrast ratios (WCAG AA standard: minimum 4.5:1 for body text).
