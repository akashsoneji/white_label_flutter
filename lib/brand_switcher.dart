import 'package:flutter/material.dart';
import 'flavor_config.dart';

/// Brand Switcher Utility
/// Provides easy methods to switch between different brands and inspect
/// their runtime configuration.
///
class BrandSwitcher {
  BrandSwitcher._();

  // ── Brand-aware getters ────────────────────────────────────────────────────
  // NOTE: these compare against `flavor.name` (a String) rather than `Flavor.x`
  // enum values so they work in single-client release builds where the
  // generated `enum Flavor` only contains the active brand.

  static bool get isVantage => _active == 'vantage';

  static bool get isCelestial => _active == 'celestial' || usesCelestialUi;

  static bool get isPipze => _active == 'pipze';

  static bool get isIquote => _active == 'iquote';

  static bool get isTenax => _active == 'tenax';

  static bool get isTelifox => _active == 'telifox';

  static bool get isGtxprime => _active == 'gtxprime';

  static bool get isBaazex => _active == 'baazex';

  static bool get isSkyriss => _active == 'skyriss';

  static bool get isKantara => _active == 'kantara';

  /// Lowercased name of the active flavor. Always safe to read, even when
  /// the `Flavor` enum is narrowed to a single client.
  static String get _active => FlavorConfig.instance.flavor.name.toLowerCase();

  static bool get isMeta => _active == 'meta';

  static bool get usesVantageUi => FlavorConfig.usesVantageUi();

  static bool get usesCelestialUi => FlavorConfig.usesCelestialUi();

  /// The Flavor enum value of the active brand.
  static Flavor get currentFlavor => FlavorConfig.instance.flavor;

  /// Display name of the active brand.
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
  /// Switch to the named brand.
  /// unknown. No-op (logs only) when the brand is already active.
  ///
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
  static void switchToMeta() => switchTo('meta');
  static void switchToKantara() => switchTo('kantara');

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
  ///
  /// NOTE: in single-client release builds the `Flavor` enum only contains
  /// the active brand, so this is a no-op that just returns the current
  /// flavor.
  static Flavor quickSwitchBrand() {
    final values = Flavor.values;
    if (values.isEmpty) {
      debugPrint('🎨 quickSwitchBrand: no flavors registered');
      return FlavorConfig.instance.flavor;
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
  ///
  /// Uses a string lookup keyed on the enum's `name` so it works whether
  /// the `Flavor` enum is the full 9-brand matrix or narrowed to a single
  /// client in release builds.
  static String labelOf(Flavor flavor) {
    return _labelForName(flavor.name);
  }

  /// Pretty display name for a brand id.
  /// Always safe to call — falls back to the raw input.
  static String labelForName(String name) => _labelForName(name);

  static String _labelForName(String name) {
    switch (name.toLowerCase()) {
      case 'vantage':
        return 'Vantage';
      case 'celestial':
        return 'Celestial';
      case 'pipze':
        return 'Pipze';
      case 'tenax':
        return 'Tenax';
      case 'telifox':
        return 'Telifox';
      case 'gtxprime':
        return 'GTX Prime';
      case 'baazex':
        return 'Baazex';
      case 'skyriss':
        return 'Skyriss';
      case 'meta':
        return 'Meta';
      case 'kantara':
        return 'Kantara';
      default:
        return name;
    }
  }

  static String _label(Flavor f) => _labelForName(f.name);
}