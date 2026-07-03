import 'package:flutter/material.dart';
import 'flavor_config.dart';

/// Brand Switcher Utility
/// Provides easy methods to switch between different brands and inspect
/// their runtime configuration.
///
/// All 8 buildable flavors are supported:
///   - Vantage (parent, 4-tab UI tree)
///   - Celestial (parent, 5-tab standalone UI tree)
///   - Pipze / Tenax / Telifox / GTXPrime / Baazex / Skyriss
///     (Vantage children — share the 4-tab UI tree)
class BrandSwitcher {
  BrandSwitcher._();

  // ── Brand-aware getters ────────────────────────────────────────────────────
  /// `true` when the active flavor is literally `Vantage` (not a child).
  static bool get isVantage => FlavorConfig.instance.flavor == Flavor.vantage;

  /// `true` when the active flavor is literally `Celestial` (not a child).
  static bool get isCelestial => FlavorConfig.instance.flavor == Flavor.celestial;

  /// `true` when the active flavor is `Pipze`.
  static bool get isPipze => FlavorConfig.instance.flavor == Flavor.pipze;

  /// `true` when the active flavor is `Tenax`.
  static bool get isTenax => FlavorConfig.instance.flavor == Flavor.tenax;

  /// `true` when the active flavor is `Telifox`.
  static bool get isTelifox => FlavorConfig.instance.flavor == Flavor.telifox;

  /// `true` when the active flavor is `GTX Prime`.
  static bool get isGtxprime => FlavorConfig.instance.flavor == Flavor.gtxprime;

  /// `true` when the active flavor is `Baazex`.
  static bool get isBaazex => FlavorConfig.instance.flavor == Flavor.baazex;

  /// `true` when the active flavor is `Skyriss`.
  static bool get isSkyriss => FlavorConfig.instance.flavor == Flavor.skyriss;

  /// `true` when the active flavor should use Vantage's shared UI tree
  /// (4-tab Prices/Markets/Accounts/Settings). Equivalent to
  /// `FlavorConfig.usesVantageUi()`.
  static bool get usesVantageUi => FlavorConfig.usesVantageUi();

  /// The Flavor enum value of the active brand.
  static Flavor get currentFlavor => FlavorConfig.instance.flavor;

  /// Display name of the active brand (e.g. "Baazex", "Celestial").
  static String get currentBrandName => FlavorConfig.instance.appName;

  /// Primary color of the active brand.
  static Color get currentBrandColor => FlavorConfig.instance.primaryColor;

  /// All brand colors for the active brand, keyed by role.
  static Map<String, Color> get currentBrandColors => {
        'primary': FlavorConfig.instance.primaryColor,
        'darkPrimary': FlavorConfig.instance.darkPrimaryColor,
        'secondary': FlavorConfig.instance.secondaryColor,
        'accent': FlavorConfig.instance.accentColor,
      };

  /// `true` if the active brand has a registered dark-mode primary color.
  static bool get hasDarkPrimary {
    final dark = FlavorConfig.instance.darkPrimaryColor;
    return dark != FlavorConfig.instance.primaryColor;
  }

  /// API base URL of the active brand.
  static String get currentApiBaseUrl => FlavorConfig.instance.apiBaseUrl;

  /// WebSocket URL of the active brand.
  static String get currentWebsocketUrl => FlavorConfig.instance.websocketUrl;

  /// Chart base URL of the active brand.
  static String get currentChartBaseUrl => FlavorConfig.instance.chartBaseUrl;

  /// SVG logo asset path of the active brand.
  static String get currentLogoAsset => FlavorConfig.instance.svgLogoPath;

  /// Splash logo asset path of the active brand.
  static String get currentSplashAsset => FlavorConfig.instance.splashLogoPath;

  // ── Switching ──────────────────────────────────────────────────────────────
  /// Switch to the named brand. Falls back to Celestial if the name is
  /// unknown. No-op (logs only) when the brand is already active.
  ///
  /// Brand names are case-insensitive. Supported: `vantage`, `celestial`,
  /// `pipze`, `tenax`, `telifox`, `gtxprime`, `baazex`, `skyriss`.
  static void switchTo(String brandName) {
    final normalized = brandName.trim().toLowerCase();
    final previous = FlavorConfig.instance.flavor;
    final config = FlavorConfig.activateByName(normalized);
    if (previous == config.flavor) {
      debugPrint('🎨 Already on ${config.appName} — no switch needed.');
      return;
    }
    debugPrint('🎨 Switched: ${_label(previous)} → ${config.appName}');
    debugPrint('   Primary:    ${config.primaryColor}');
    debugPrint('   Secondary:  ${config.secondaryColor}');
    debugPrint('   Accent:     ${config.accentColor}');
    debugPrint('   API:        ${config.apiBaseUrl}');
  }

  /// Convenience switchers — call from app code or test setup.
  static void switchToVantage() => switchTo('vantage');
  static void switchToCelestial() => switchTo('celestial');
  static void switchToPipze() => switchTo('pipze');
  static void switchToTenax() => switchTo('tenax');
  static void switchToTelifox() => switchTo('telifox');
  static void switchToGtxprime() => switchTo('gtxprime');
  static void switchToBaazex() => switchTo('baazex');
  static void switchToSkyriss() => switchTo('skyriss');

  /// Print the active brand summary to the console.
  static void printCurrentBrand() {
    final cfg = FlavorConfig.instance;
    debugPrint('🎯 Current Brand: ${cfg.appName} (${cfg.flavor.name})');
    debugPrint('   Primary Color:   ${cfg.primaryColor}');
    debugPrint('   Secondary Color: ${cfg.secondaryColor}');
    debugPrint('   Accent Color:    ${cfg.accentColor}');
    debugPrint('   App Title:       ${cfg.appTitle}');
    debugPrint('   API Base URL:    ${cfg.apiBaseUrl}');
    debugPrint('   WebSocket URL:   ${cfg.websocketUrl}');
    debugPrint('   Logo Asset:      ${cfg.svgLogoPath}');
    debugPrint('   Uses Vantage UI: ${FlavorConfig.usesVantageUi()}');
  }

  /// Rotate to the next flavor in `Flavor.values` order. The active flavor
  /// only changes at the Dart level — to actually rebuild with the new
  /// flavor in a debug APK, restart with `--dart-define=CLIENT=<new>`.
  ///
  /// Useful in `brand_test_screen.dart` to preview what a brand would look
  /// like without re-running `flutter run`. Returns the brand that would
  /// be active after the cycle.
  static Flavor quickSwitchBrand() {
    final values = Flavor.values;
    if (values.isEmpty) {
      debugPrint('🎨 quickSwitchBrand: no flavors registered');
      return Flavor.celestial;
    }
    final current = FlavorConfig.instance.flavor;
    final idx = values.indexOf(current);
    final next = idx < 0 || idx == values.length - 1
        ? values.first
        : values[idx + 1];
    debugPrint('🎨 quickSwitchBrand: ${labelOf(current)} → ${labelOf(next)}');
    FlavorConfig.activate(next);
    return next;
  }

  /// Iterate every supported flavor — useful for sanity-check scripts or
  /// automated screenshot tests that need to walk the whole brand matrix.
  static Iterable<Flavor> get allFlavors => Flavor.values;

  /// Return the human label (appName) for any flavor without activating it.
  static String labelOf(Flavor flavor) {
    switch (flavor) {
      case Flavor.vantage:
        return 'Vantage';
      case Flavor.celestial:
        return 'Celestial';
      case Flavor.pipze:
        return 'Pipze';
      case Flavor.tenax:
        return 'Tenax';
      case Flavor.telifox:
        return 'Telifox';
      case Flavor.gtxprime:
        return 'GTX Prime';
      case Flavor.baazex:
        return 'Baazex';
      case Flavor.skyriss:
        return 'Skyriss';
    }
  }

  static String _label(Flavor f) {
    try {
      return labelOf(f);
    } catch (_) {
      return f.name;
    }
  }
}