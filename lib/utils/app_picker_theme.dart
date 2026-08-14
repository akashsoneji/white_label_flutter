import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/constants/color.dart';

/// Theme-aware helpers for dropdowns and date pickers in forms.
class AppPickerTheme {
  AppPickerTheme._();

  /// Background for open dropdown menus.
  static Color get dropdownMenuColor => AppColors.card;

  /// Selected value / menu item text.
  static TextStyle dropdownTextStyle(
    double fontSize, {
    FontWeight? fontWeight,
  }) => AppTextStyles.bodyText.copyWith(
    fontSize: fontSize,
    color: AppColors.textPrimary,
    fontWeight: fontWeight,
  );

  /// Hint / placeholder text in dropdowns.
  static TextStyle dropdownHintStyle(double fontSize) =>
      AppTextStyles.bodyText.copyWith(fontSize: fontSize, color: AppColors.textGrey);

  /// Icon color for dropdown arrows.
  static Color get dropdownIconColor => AppColors.textGrey;

  static DatePickerThemeData _calendarDayTheme({required bool isDark}) {
    final selectedBg = AppColors.primary.withValues(alpha: 0.6);
    final selectedFg = AppColors.onColoredBackground;
    final todayBg = AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.15);
    final todayFg =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final dayFg =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return DatePickerThemeData(
      backgroundColor: AppColors.card,
      headerBackgroundColor: AppColors.primary.withValues(alpha: 0.1),
      headerForegroundColor: isDark ? AppColors.textPrimary : AppColors.primary,
      weekdayStyle: AppTextStyles.bodyText.copyWith(
        color: AppColors.textGrey,
        fontWeight: FontWeight.w600,
      ),
      yearStyle: AppTextStyles.bodyText.copyWith(color: dayFg),
      dayStyle: AppTextStyles.bodyText.copyWith(color: dayFg),
      dayBackgroundColor: WidgetStateProperty<Color?>.fromMap({
        WidgetState.selected: selectedBg,
      }),
      dayForegroundColor: WidgetStateProperty<Color?>.fromMap({
        WidgetState.selected: selectedFg,
        WidgetState.disabled: AppColors.textGrey.withValues(alpha: 0.4),
      }),
      todayForegroundColor: WidgetStateProperty.all(todayFg),
      todayBackgroundColor: WidgetStateProperty.all(todayBg),
      rangeSelectionBackgroundColor: AppColors.brandPrimary.withValues(
        alpha: 0.2,
      ),
      rangeSelectionOverlayColor: WidgetStateProperty.all(
        AppColors.brandPrimary.withValues(alpha: 0.12),
      ),
    );
  }

  /// Opens a date picker dialog with light/dark colors from [AppColors].
  static Future<DateTime?> showAppDatePicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final isDark = AppColors.isDarkMode;
    final surface = AppColors.card;
    final onSurface = AppColors.textPrimary;

    final colorScheme =
        isDark
            ? ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.onColoredBackground,
              surface: surface,
              onSurface: onSurface,
              secondary: AppColors.primary,
              onSecondary: AppColors.onColoredBackground,
            )
            : ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.onColoredBackground,
              surface: surface,
              onSurface: onSurface,
              secondary: AppColors.primary,
              onSecondary: AppColors.onColoredBackground,
            );

    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme,
            dialogTheme: DialogThemeData(
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
            ),
            datePickerTheme: _calendarDayTheme(isDark: isDark),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
