import 'package:flutter/material.dart';
import 'clients/tenax/config.dart';
import 'clients/vantage/config.dart';
import 'clients/celestial/config.dart';
import 'clients/pipze/config.dart';

enum Flavor {
  tenax,
  vantage,
  celestial,
  pipze,
}

class FlavorConfig {
  final Flavor flavor;
  final String appName;
  final String appTitle;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String apiBaseUrl;
  final String chartBaseUrl;
  final String websocketUrl;
  final String appIconPath;
  final String svgLogoPath;
  final String splashLogoPath; // Splash screen logo path
  final String? remoteLogoUrl;
  final Map<String, dynamic>? selectedBrokerData;

  static FlavorConfig? _instance;
  static Flavor? _selectedFlavor;

  factory FlavorConfig({
    required Flavor flavor,
    required String appName,
    required String appTitle,
    required Color primaryColor,
    required Color secondaryColor,
    required Color accentColor,
    required String apiBaseUrl,
    required String websocketUrl,
    required String chartBaseUrl,
    required String appIconPath,
    required String svgLogoPath,
    required String splashLogoPath,
    String? remoteLogoUrl,
    Map<String, dynamic>? selectedBrokerData,
  }) {
    // If no flavor is selected yet, or if the flavor matches the selected one, initialize it
    if (_selectedFlavor == null || _selectedFlavor == flavor) {
      _instance = FlavorConfig._internal(
        flavor: flavor,
        appName: appName,
        title: appTitle,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        accentColor: accentColor,
        apiBaseUrl: apiBaseUrl,
        websocketUrl: websocketUrl,
        chartBaseUrl: chartBaseUrl,
        appIconPath: appIconPath,
        svgLogoPath: svgLogoPath,
        splashLogoPath: splashLogoPath,
        remoteLogoUrl: remoteLogoUrl,
        selectedBrokerData: selectedBrokerData,
      );
      _selectedFlavor = flavor;
    }
    return _instance!;
  }

  /// Reset the flavor configuration (useful for testing or switching flavors)
  static void reset() {
    _instance = null;
    _selectedFlavor = null;
  }

  FlavorConfig._internal({
    required this.flavor,
    required String title,
    required this.appName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.apiBaseUrl,
    required this.websocketUrl,
    required this.chartBaseUrl,
    required this.appIconPath,
    required this.svgLogoPath,
    required this.splashLogoPath,
    required this.remoteLogoUrl,
    required this.selectedBrokerData,
  }) : appTitle = title;

  static FlavorConfig get instance {
    return _instance ?? FlavorConfig.tenax;
  }

  static bool isTenax() => _instance?.flavor == Flavor.tenax;
  static bool isCelestial() => _instance?.flavor == Flavor.celestial;
  static bool isPipze() => _instance?.flavor == Flavor.pipze;

  /// Vantage and Celestial share the same 4-tab trading shell and Vantage auth UI.
  static bool isVantage() =>
      _instance?.flavor == Flavor.vantage ||
      _instance?.flavor == Flavor.celestial ||
      _instance?.flavor == Flavor.pipze;

  /// Alias for UI branching (auth, trading shell, finance screens).
  static bool usesVantageUi() => isVantage();

  static String get svgLogoAsset => instance.svgLogoPath;
  static String? get remoteLogo => instance.remoteLogoUrl;
  static bool get hasRemoteLogo =>
      (instance.remoteLogoUrl ?? '').trim().isNotEmpty;
  static String get effectiveLogo => remoteLogo ?? svgLogoAsset;
  static Map<String, dynamic>? get brokerData => instance.selectedBrokerData;
  static String get appNameDisplay => instance.appName;

  /// Applies runtime branding overrides (usually from a JSON config).
  static void applyBranding({
    required Map<String, dynamic> config,
    String? brokerName,
    String? brokerLogoUrl,
    Map<String, dynamic>? brokerData,
  }) {
    final current = instance;
    _instance = FlavorConfig._internal(
      flavor: current.flavor,
      title: config['appTitle']?.toString() ?? current.appTitle,
      appName: brokerName ?? config['appName']?.toString() ?? current.appName,
      primaryColor: _parseColor(config['primaryColor']) ?? current.primaryColor,
      secondaryColor:
          _parseColor(config['secondaryColor']) ?? current.secondaryColor,
      accentColor: _parseColor(config['accentColor']) ?? current.accentColor,
      apiBaseUrl: config['apiBaseUrl']?.toString() ?? current.apiBaseUrl,
      websocketUrl: config['websocketUrl']?.toString() ?? current.websocketUrl,
      chartBaseUrl: config['chartBaseUrl']?.toString() ?? current.chartBaseUrl,
      appIconPath: config['appIconPath']?.toString() ?? current.appIconPath,
      svgLogoPath:
          brokerLogoUrl ?? config['logoSvgPath']?.toString() ?? current.svgLogoPath,
      splashLogoPath:
          config['splashLogoPath']?.toString() ?? current.splashLogoPath,
      remoteLogoUrl:
          config['remoteLogoUrl']?.toString() ?? current.remoteLogoUrl,
      selectedBrokerData:
          brokerData ??
          (config['selectedBrokerData'] as Map<String, dynamic>?) ??
          current.selectedBrokerData,
    );
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is Color) return value;
    if (value is int) {
      return Color(value);
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    var hex = raw.replaceFirst('#', '').replaceFirst('0x', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) {
      return null;
    }
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }

  static FlavorConfig get tenax {
    _selectedFlavor = Flavor.tenax;
    const config = TenaxConfig(); // Load centralized config
    return FlavorConfig(
      flavor: Flavor.tenax,
      appName: config.brandName,
      appTitle: config.appTitle,
      primaryColor: config.primaryColor,
      secondaryColor: config.secondaryColor,
      accentColor: config.accentColor,
      websocketUrl: config.websocketUrl,
      chartBaseUrl: config.chartBaseUrl,
      apiBaseUrl: config.apiBaseUrl,
      appIconPath: config.getAssetPath('tenax', config.appIconPath),
      svgLogoPath: config.getAssetPath('tenax', config.logoSvgPath),
      splashLogoPath: config.getAssetPath('tenax', config.splashLogoPath),
      remoteLogoUrl: null,
      selectedBrokerData: null,
    );
  }

  static FlavorConfig get vantage {
    _selectedFlavor = Flavor.vantage;
    const config = VantageConfig();
    return FlavorConfig(
      flavor: Flavor.vantage,
      appName: config.brandName,
      appTitle: config.appTitle,
      primaryColor: config.primaryColor,
      secondaryColor: config.secondaryColor,
      accentColor: config.accentColor,
      websocketUrl: config.websocketUrl,
      chartBaseUrl: config.chartBaseUrl,
      apiBaseUrl: config.apiBaseUrl,
      appIconPath: config.getAssetPath('vantage', config.appIconPath),
      svgLogoPath: config.getAssetPath('vantage', config.logoSvgPath),
      splashLogoPath: config.getAssetPath('vantage', config.splashLogoPath),
      remoteLogoUrl: null,
      selectedBrokerData: null,
    );
  }

  static FlavorConfig get celestial {
    _selectedFlavor = Flavor.celestial;
    const config = CelestialConfig();
    return FlavorConfig(
      flavor: Flavor.celestial,
      appName: config.brandName,
      appTitle: config.appTitle,
      primaryColor: config.primaryColor,
      secondaryColor: config.secondaryColor,
      accentColor: config.accentColor,
      websocketUrl: config.websocketUrl,
      chartBaseUrl: config.chartBaseUrl,
      apiBaseUrl: config.apiBaseUrl,
      appIconPath: config.getAssetPath('celestial', config.appIconPath),
      svgLogoPath: config.getAssetPath('celestial', config.logoSvgPath),
      splashLogoPath: config.getAssetPath('celestial', config.splashLogoPath),
      remoteLogoUrl: null,
      selectedBrokerData: null,
    );
  }

  static FlavorConfig get pipze {
    _selectedFlavor = Flavor.pipze;
    const config = PipzeConfig();
    return FlavorConfig(
      flavor: Flavor.pipze,
      appName: config.brandName,
      appTitle: config.appTitle,
      primaryColor: config.primaryColor,
      secondaryColor: config.secondaryColor,
      accentColor: config.accentColor,
      websocketUrl: config.websocketUrl,
      chartBaseUrl: config.chartBaseUrl,
      apiBaseUrl: config.apiBaseUrl,
      appIconPath: config.getAssetPath('pipze', config.appIconPath),
      svgLogoPath: config.getAssetPath('pipze', config.logoSvgPath),
      splashLogoPath: config.getAssetPath('pipze', config.splashLogoPath),
      remoteLogoUrl: null,
      selectedBrokerData: null,
    );
  }
}
