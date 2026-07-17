import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/main.dart' as main_config;
import '../flavor_config.dart';
import '../services/theme_service.dart';

/// Central color system for the entire app.
/// All colors flow through here — change once, update everywhere.
/// Flavors (tenax/vantage) control brand colors automatically.
class AppColors {
  static ThemeService? get _themeService =>
      Get.isRegistered<ThemeService>() ? Get.find<ThemeService>() : null;

  static bool get isDarkMode {
    if (!main_config.enableDarkModeGlobal) return false;
    final service = _themeService;
    if (service != null) return service.isDarkResolved;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  // ── Brand Colors (flavor-driven) ──────────────────────────────────────────
  // Primary color - brand-specific in both modes, with darkPrimaryColor for dark mode.
  static Color get primary =>
      isDarkMode ? FlavorConfig.instance.darkPrimaryColor : FlavorConfig.instance.primaryColor;
  static Color get secondary => FlavorConfig.instance.secondaryColor;
  static Color get accent => FlavorConfig.instance.accentColor;
  static const Color _pureBlack = Color(0xFF000000);
  static Color get pureBlack => _pureBlack;
  static Color get toastBackground => _pureBlack.withValues(alpha: 0.87);

  // ── Common Black & Grey ───────────────────────────────────────────────────
  // Primary text — black in light, white in dark
  static Color get textPrimary =>
      isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  // Secondary text — lighter grey in both modes
  static Color get textSecondary =>
      isDarkMode ? const Color(0xFFC0C0C0) : const Color(0xFF757984);
  // Grey text (captions, hints, placeholders) — #757984 in light, #C8C8C8 in dark (brighter for visibility)
  static Color get textGrey =>
      isDarkMode ? const Color(0xFFC8C8C8) : const Color(0xFF757984);
  // Light variant of grey text — brighter in dark mode
  static Color get textGreyLight =>
      isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF919EAB);
  // Trade center text — lighter in dark mode for visibility
  static Color get tradeTextCenterColor =>
      isDarkMode ? const Color(0xFFC8C8C8) : const Color(0xFF4F535D);

  // ── Common White & Surface ─────────────────────────────────────────────────
  // Off-white for light surfaces — used for light theme backgrounds
  static Color get whiteColor =>
      isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF6F6F6);
  // Pure white for buttons and text — always white regardless of theme
  static Color get pureWhite => const Color(0xFFFFFFFF);
  // Scaffold background — #FFFFFF in light, #121212 in dark
  static Color get scaffold =>
      isDarkMode ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
  // Card background — #FFFFFF in light, #2C2C2C in dark
  static Color get card =>
      isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);
  // Surface / divider — #F5F5F5 in light, #1E1E1E in dark
  static Color get surface =>
      isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
  // Background alias for scaffold
  static Color get background => scaffold;
  // Card background alias
  static Color get cardBackground => card;

  // ── Trade Background ──────────────────────────────────────────────────────
  // Main scaffold bg for feature screens — #F7F7F7 in light, #1E1E1E in dark
  static Color get tradeBackground =>
      isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7);

  // Text field/input background — slightly lighter than card in dark mode for visibility
  static Color get textFieldBg =>
      isDarkMode ? const Color(0xFF333333) : const Color(0xFFFFFFFF);

  // ── Border & Divider ──────────────────────────────────────────────────────
  // Main border color — lighter in dark mode for visibility
  static Color get border =>
      isDarkMode ? const Color(0xFF5A5A5A) : const Color(0xFFBBBBBB);
  // Hint / placeholder color — bright white in dark mode for visibility
  static Color get hint =>
      isDarkMode ? const Color(0xFFAAAAAA) : const Color(0xFF757984);
  // Neutral divider / track — lighter in dark mode
  static Color get divider =>
      isDarkMode ? const Color(0xFF5A5A5A) : const Color(0xFFE0E0E0);

  // ── Icon Colors ────────────────────────────────────────────────────────────
  static Color get iconPrimary => primary;
  static Color get iconGrey => textGrey;
  static Color get iconLight => textGreyLight;

  // ── Icon Background ────────────────────────────────────────────────────────
  static Color get iconBgSurface => surface;
  static Color get iconBgTertiary =>
      isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0);
  static Color get iconBgPrimary => primary.withValues(alpha: 0.12);
  static Color get iconBgGreen => statusGreen.withValues(alpha: 0.08);

  // ── Brand-Tinted Surfaces ────────────────────────────────────────────────
  static Color get surfacePrimary =>
      primary.withValues(alpha: isDarkMode ? 0.10 : 0.20);
  static Color get surfaceSecondary =>
      primary.withValues(alpha: isDarkMode ? 0.45 : 0.60);
  static Color get surfaceTertiary => whiteColor.withValues(alpha: 0.85);

  // ── Chip & Badge ───────────────────────────────────────────────────────────
  static Color get chipDefault => iconBgTertiary;
  static Color get chipSelected =>
      isDarkMode ? const Color(0xFF4F535D) : primary;
  static Color get chipText => onColoredBackground;

  // ── Common Aliases ─────────────────────────────────────────────────────────
  static Color get onPrimary =>
      primary.computeLuminance() > 0.5 ? pureBlack : pureWhite;
  static Color get onColoredBackground => onPrimary;

  /// @deprecated Use `onColoredBackground` instead
  static Color get onPrimaryTint => onColoredBackground;
  static Color get shadow =>
      textPrimary.withValues(alpha: isDarkMode ? 0.2 : 0.05);
  static Color get brandPrimary => primary;

  // ── Status Colors ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFBBF7D0);
  static const Color successText = Color(0xFF15803D);

  static const Color warning = Color(0xFFFF9800);
  static const Color warningBg = Color(0xFFFFF8E1);
  static const Color warningBorder = Color(0xFFFFCC02);
  static const Color warningText = Color(0xFFB7791F);
  static const Color warningTextDark = Color(0xFF92400E);
  static const Color warningTextMedium = Color(0xFFA37E3B);

  static const Color error = Color(0xFFF44336);
  static const Color errorBg = Color(0xFFFEF2F2);

  static const Color pendingStatusDark = Color(0xFFB7791F);

  // ── Quote / Trading Colors ────────────────────────────────────────────────
  static const Color quotePositive = Color(0xFF3C8836);
  static const Color quoteNegative = Color(0xFFD72E1F);
  static const Color chartRed1 = Color(0xFFFF5A5F);
  static const Color chartRed2 = Color(0xFFE84855);

  // ── Copy Trading & PMAM Status Colors ────────────────────────────────────
  static const Color statusGreen = Color(0xFF22C55E);
  static const Color statusGreenDark = Color(0xFF16A34A);
  static const Color statusYellow = Color(0xFFF59E0B);
  static const Color statusRed = Color(0xFFEF4444);
  static const Color statusGrey = Color(0xFF94A3B8);

  // ── Feature Icon Colors ─────────────────────────────────────────────────────
  static const Color iconGreen = Color(0xFF4CAF50);
  static const Color iconOrange = Color(0xFFFF9800);
  static const Color iconPurple = Color(0xFF9C27B0);
  static const Color iconTeal = Color(0xFF00BFA5);
  static const Color iconBlue = Color(0xFF1E88E5);
  static const Color iconLightBlue = Color(0xFF29B6F6);
  static const Color iconRed = Color(0xFFEF5350);
  static const Color iconDeepPurple = Color(0xFF7E57C2);
  static const Color iconDeepTeal = Color(0xFF26A69A);
  static const Color iconIndigo = Color(0xFF5C6BC0);
  static const Color iconPink = Color(0xFFEC407A);
  static const Color iconBgPurple = Color(0xFF673AB7);

  // ── Notification & Accent ──────────────────────────────────────────────────
  static const Color notificationBlue = Color(0xFF2196F3);
  static const Color accentGold = Color(0xFFFFB800);
  static const Color blue = Color(0xFF3478F6);

  // ── Divider & Border ───────────────────────────────────────────────────────
  static const Color dividerLight = Color(0xFFEAEAEA);
  static const Color dividerMedium = Color(0xFFDDDDDD);
  static const Color dividerDark = Color(0xFFEEEEEE);
  static const Color dividerLightAlt = Color(0xFFEFEFEF);
  static const Color stepperInactive = Color(0xFFE0E0E0);
  static const Color stepperActive = Color(0xFFD0D0D0);
  static const Color stepperComplete = Color(0xFFBDBDBD);

  // ── KYC & Feature Background Colors ────────────────────────────────────────
  static Color get kycComplete =>
      isDarkMode ? const Color(0xFF1E3324) : const Color(0xFFE8F5E8);
  static Color get kycActive =>
      isDarkMode ? primary.withValues(alpha: 0.15) : const Color(0xFFF8F3FF);
  static Color get kycBorder =>
      isDarkMode ? const Color(0xFF333333) : const Color(0xFFE3E7EF);
  static const Color featureBgGreen = Color(0xFFE8F5E8);
  static const Color featureBgPurple = Color(0xFFF8F3FF);
  static const Color featureBorder = Color(0xFFE3E7EF);

  // ── Warning & Alert Colors ──────────────────────────────────────────────────
  static const Color warningBgLight = Color(0xFFFFF8E1);
  static const Color errorBgLight = Color(0xFFFEF2F2);

  // ── Scratch Card & Prize Colors ─────────────────────────────────────────────
  static const Color prizeGreen = Color(0xFF2A9D5C);
  static const Color prizeYellow = Color(0xFFFDCC29);
  static const Color prizeBgGreen = Color(0xFFEDF7EE);
  static const Color prizeDarkGreen = Color(0xFF2A7D3F);
  static const Color prizeBrown = Color(0xFF7A5500);
  static const Color prizeBackground = Color(0xFFFFFBEA);
  static const Color prizeDarkBg = Color(0xFF0F1E2D);

  // ── Leaderboard Podium Colors ───────────────────────────────────────────────
  static const Color gold = Color(0xFFF2B92C);
  static const Color silver = Color(0xFFB87333);

  // ── Special Surface Colors ─────────────────────────────────────────────────
  static const Color surfacePurple = Color(0xffEFEAF6);
  static const Color surfaceNeutralLight = Color(0xFFF9FAFB);
  static const Color surfaceDark = Color(0xFF1E1E2E);
  static const Color surfaceDarkAlt = Color(0xFF252535);
  static const Color surfaceLight = Color(0xFFE5E7EB);
  static const Color surfaceGold = Color(0xFFFFF4E0);
  static const Color surfacePurpleLight = Color(0xFFF0E0F8);
  static const Color surfaceDarkDeep = Color(0xFF151A22);
  static const Color progressTrackDark = Color(0xFF3A3A4A);

  // ── Other Utility Colors ────────────────────────────────────────────────────
  static const Color inactivePlanBg = Color(0xFFF3F4F6);
  static const Color transparentDivider = Color(0x1A000000);
  static const Color backgroundDarkAlt = Color(0xFF0D1117);
  static const Color backgroundLightAlt = Color(0xFFF8F9FC);
  static Color get placeholderSoft =>
      const Color(0xFF8C98A8).withValues(alpha: 0.2);

  // ── Accent Highlight ────────────────────────────────────────────────────────
  static Color get accentHighlightBg =>
      accent.withValues(alpha: isDarkMode ? 0.22 : 0.38);
  static Color get accentHighlightText =>
      isDarkMode ? accent : const Color(0xFF6B4E00);

  static const Color quickActionGreen = Color(0xFF4CAF50);
  static const Color quickActionOrange = Color(0xFFFF9800);
  static const Color quickActionBlue = Color(0xFF2196F3);

  // ── Legacy Aliases (backward compatibility) ────────────────────────────────
  /// @deprecated Use `tradeBackground` instead
  static Color get tradeBackgroundCenterColor => tradeBackground;

  /// @deprecated Use `tradeBackground` instead
  static Color get tradeWinScaffoldBackground => tradeBackground;

  /// @deprecated Use `scaffold` / `surface` instead
  /// Light scaffold/background color — white in light, dark surface in dark
  static Color get backgroundLight => scaffold;

  /// @deprecated Use `scaffold` / `background` instead
  static Color get backgroundLightTheme => const Color(0xFFFFFFFF);

  /// @deprecated Use `scaffold` / `background` instead
  static Color get backgroundDarkTheme => const Color(0xFF121212);

  /// @deprecated Use `surface` instead
  static Color get surfaceDarkTheme => const Color(0xFF1E1E1E);

  /// @deprecated Use `surface` instead
  static Color get surfaceLightTheme => const Color(0xFFF5F5F5);

  /// @deprecated Use `card` instead
  static Color get cardDarkTheme => const Color(0xFF2C2C2C);

  /// @deprecated Use `card` instead
  static Color get cardLightTheme => const Color(0xFFFFFFFF);

  /// @deprecated Use `card` instead
  static Color get cardBackGround => surfacePrimary;

  /// @deprecated Use `card` instead
  static Color get cardBackGroundSecondary => surfaceSecondary;

  /// @deprecated Use `border` instead
  static Color get borderLight => border;

  /// @deprecated Use `border` instead
  static Color get borderDark => border;

  /// @deprecated Use `hint` instead
  static Color get hintLight => hint;

  /// @deprecated Use `hint` instead
  static Color get hintDark => hint;

  /// @deprecated Use `divider` instead
  static Color get neutralTrack => divider;

  /// @deprecated Use `divider` instead
  static Color get dashLineColor => divider.withValues(alpha: 0.2);

  /// @deprecated Use `textGrey` instead
  static Color get textGreyLightTheme => textGrey;

  /// @deprecated Use `textGreyLight` instead
  static Color get textGreyLightVariant => textGreyLight;

  /// @deprecated Use `textGreyDark` instead
  static Color get textGreyDark => textGrey;

  /// @deprecated Use `textPrimary` instead
  static Color get textPrimaryLight => Colors.black;

  /// @deprecated Use `textPrimary` instead
  static Color get textPrimaryDark => Colors.white;

  /// @deprecated Use `textSecondary` instead
  static Color get textSecondaryLight => const Color(0xFF757984);

  /// @deprecated Use `textSecondary` instead
  static Color get textSecondaryDark => const Color(0xFFB0B0B0);

  /// @deprecated Use `whiteColor` instead
  static Color get whiteColorLight => const Color(0xFFF6F6F6);

  /// @deprecated Use `whiteColor` instead
  static Color get whiteColorDark => const Color(0xFF2C2C2C);

  /// @deprecated Use `chipDefault` instead
  static Color get chipSurface => iconBgTertiary;

  /// @deprecated Use `icongrey` instead
  static Color get icongrey => textGrey;

  /// @deprecated Use `icongreylight` instead
  static Color get icongreylight => textGreyLight.withValues(alpha: 0.5);

  /// @deprecated Use `grey` instead
  static const Color grey = Color(0xFFEDF1F3);

  /// @deprecated Use `red` instead
  static const Color red = Color(0xFFD72E1F);

  /// @deprecated Use `green` instead
  static const Color green = Color(0xFF3C8836);

  /// @deprecated Use `secondary` instead
  static const Color secondaryStatic = Color(0xFFF6F6F6);

  /// @deprecated Use `accent` instead
  static const Color accentStatic = Color(0xFFFEBC1F);

  /// @deprecated Use `successBg` instead
  static Color get successBgLight => successBg;

  /// @deprecated Use `successText` instead
  static Color successTextResolved([bool isDark = false]) =>
      isDark ? success.withValues(alpha: 0.9) : successText;

  /// @deprecated Use `kycComplete` instead
  static Color get kycStageComplete => kycComplete;

  /// @deprecated Use `kycActive` instead
  static Color get kycStageActive => kycActive;

  /// @deprecated Use `kycBorder` instead
  static Color get kycFeatureBorder => kycBorder;

  /// @deprecated Use `successBorder` instead
  static const Color successBorderLight = Color(0xFFBBF7D0);

  /// @deprecated Use `successText` instead
  static const Color successTextLight = Color(0xFF15803D);

  // Copy Trading compatibility properties
  static const Color quickActionPurple = Color(0xFF9C27B0);
  static Color get errorText => isDarkMode ? const Color(0xFFEF9999) : const Color(0xFFD32F2F);
  static Color shadowAlpha(double alpha) => textPrimary.withValues(alpha: alpha);
  static Color get switchTrackOff => isDarkMode ? const Color(0xFF505050) : const Color(0xFFDCDCDC);

  // CRM compatibility aliases (for migrated screens)
  static Color get selectedChipBackground => chipSelected;
  static Color get selectedChipForeground => onColoredBackground;
  static String get chartTheme => isDarkMode ? 'dark' : 'light';

  // PMAM compatibility aliases (from crmapp merge)
  static Color get neutralTrackMuted => isDarkMode ? const Color(0xFF3A3A4A) : const Color(0xFFE0E0E0);
  static Color get neutralTrackSoft => isDarkMode ? const Color(0xFF4A4A5A) : const Color(0xFFEEEEEE);
}
