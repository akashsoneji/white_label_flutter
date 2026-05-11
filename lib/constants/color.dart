import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../flavor_config.dart';
import '../services/theme_service.dart';

class AppColors {
  // Get ThemeService instance if available
  static ThemeService? get _themeService =>
      Get.isRegistered<ThemeService>() ? Get.find<ThemeService>() : null;

  // Helper to check if dark mode
  static bool get isDarkMode {
    final service = _themeService;
    if (service != null) return service.isDarkResolved;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }
  // Brand Colors - Now using flavor configuration
  static Color get primary => FlavorConfig.instance.primaryColor;
  static Color get secondary => FlavorConfig.instance.secondaryColor;
  static Color get accent => FlavorConfig.instance.accentColor;

  // Legacy static colors (keeping for backward compatibility)
  static const Color secondaryStatic = Color(0xFFF6F6F6);
  static const Color accentStatic = Color(0xFFFEBC1F);
  static const Color blue = Color(0xFF3478F6);

  // Text Colors - Light Theme
  static const Color textPrimaryLight = Colors.black;
  static const Color textSecondaryLight = Colors.grey;
  static const Color textGreyLightTheme = Color.fromRGBO(117, 121, 132, 1);
  static const Color textGreyLightVariant = Color(0xff919EAB);
  static const Color whiteColorLight = Color(0xFFF6F6F6);
  static const Color tradeTextCenterColorLight = Color(0xFF4F535D);
  // static const Color tradeBackgroundCenterColor = Color(0xFFD6D6D6);
  static const Color tradeBackgroundCenterColorLight = Color(0xFFf7f7f7);

  // Text Colors - Dark Theme
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textGreyDark = Color.fromRGBO(160, 160, 160, 1);
  static const Color textGreyLightDark = Color(0xFF9E9E9E);
  static const Color whiteColorDark = Color(0xFF2C2C2C);
  static const Color tradeTextCenterColorDark = Color(0xFFB0B0B0);
  static const Color tradeBackgroundCenterColorDark = Color(0xFF1E1E1E);

  // Current Text Colors (based on theme)
  static Color get textPrimary => isDarkMode ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary => isDarkMode ? textSecondaryDark : textSecondaryLight;
  static Color get textGrey => isDarkMode ? textGreyDark : textGreyLightTheme;
  static Color get textGreyLight => isDarkMode ? textGreyLightDark : textGreyLightVariant;
  static Color get whiteColor => isDarkMode ? whiteColorDark : whiteColorLight;
  static Color get tradeTextCenterColor => isDarkMode ? tradeTextCenterColorDark : tradeTextCenterColorLight;
  static Color get tradeBackgroundCenterColor => isDarkMode ? tradeBackgroundCenterColorDark : tradeBackgroundCenterColorLight;

  // Backgrounds - Light Theme
  static const Color backgroundLightTheme = Color(0xFFFFFFFF);
  static const Color surfaceLightTheme = Color(0xFFF5F5F5);
  static const Color cardLightTheme = Color(0xFFFFFFFF);

  // Backgrounds - Dark Theme
  static const Color backgroundDarkTheme = Color(0xFF121212);
  static const Color surfaceDarkTheme = Color(0xFF1E1E1E);
  static const Color cardDarkTheme = Color(0xFF2C2C2C);

  // Current Backgrounds (based on theme) - Keep old name for backward compatibility
  static Color get backgroundLight => isDarkMode ? backgroundDarkTheme : backgroundLightTheme;
  static Color get surface => isDarkMode ? surfaceDarkTheme : surfaceLightTheme;
  static Color get cardBackground => isDarkMode ? cardDarkTheme : cardLightTheme;
  // Direct theme getters
  static Color get background => isDarkMode ? backgroundDarkTheme : backgroundLightTheme;
  static Color get card => isDarkMode ? cardDarkTheme : cardLightTheme;

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  // Quote Digit Color
  static const Color red = Color(0xFFD72E1F);
  static const Color green = Color(0xFF3C8836);
  static const Color grey = Color(0xFFEDF1F3);
  static const Color icongrey = Color(0xFF757984);
  static const Color icongreylight = Color(0x7A919EAB);
  // static const Color cardBackGround = Color(0xffFBF5FF);
  // static const Color cardBackGround =  primary.withValues(alpha: 0.1);
  /// Soft primary-tinted background used for highlight chips / badges.
  /// Slightly stronger tint in dark mode so the brand color still reads on dark surfaces.
  static Color get cardBackGround => primary.withValues(alpha: isDarkMode ? 0.10 : 0.20);

  /// Secondary primary-tinted background, used for stronger emphasis chips.
  static Color get cardBackGroundSecondary => primary.withValues(alpha: isDarkMode ? 0.45 : 0.60);
  // Others - Light Theme
  static const Color borderLight = Color(0xFFBBBBBB);
  static const Color hintLight = Colors.grey;
  static const Color dashLineColorLight = Color(0x33757984);

  // Others - Dark Theme
  static const Color borderDark = Color(0xFF404040);
  static const Color hintDark = Color(0xFF9E9E9E);
  static const Color dashLineColorDark = Color(0x40404040);

  // Current Others (based on theme)
  static Color get border => isDarkMode ? borderDark : borderLight;
  static Color get hint => isDarkMode ? hintDark : hintLight;
  static Color get dashLineColor => isDarkMode ? dashLineColorDark : dashLineColorLight;
}
