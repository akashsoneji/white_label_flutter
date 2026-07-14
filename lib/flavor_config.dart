// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import 'clients/base_config.dart';
import 'clients/pipze/config.dart';

enum Flavor {
  pipze,
}

class FlavorConfig {
  final Flavor flavor;
  final String appName;
  final String appTitle;
  final Color primaryColor;
  final Color darkPrimaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String apiBaseUrl;
  final String chartBaseUrl;
  final String websocketUrl;
 final String appIconPath;
 final String svgLogoPath;
 final String splashLogoPath;
 final String? remoteLogoUrl;
 final Map<String, dynamic>? selectedBrokerData;
 final bool useNewChart;

 static FlavorConfig? _instance;
 static Flavor? _selectedFlavor;

 factory FlavorConfig({
 required Flavor flavor,
 required String appName,
 required String appTitle,
 required Color primaryColor,
 required Color darkPrimaryColor,
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
 bool useNewChart = false,
 }) {
 if (_selectedFlavor == null || _selectedFlavor == flavor) {
 _instance = FlavorConfig._internal(
 flavor: flavor,
 appName: appName,
 title: appTitle,
 primaryColor: primaryColor,
 darkPrimaryColor: darkPrimaryColor,
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
 useNewChart: useNewChart,
 );
 _selectedFlavor = flavor;
 }
 return _instance!;
 }

 FlavorConfig._internal({
 required this.flavor,
 required String title,
 required this.appName,
 required this.primaryColor,
 required this.darkPrimaryColor,
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
 this.useNewChart = false,
 }) : appTitle = title;

  static FlavorConfig get instance => _instance ?? activate(Flavor.pipze);

  static void reset() {
    _instance = null;
    _selectedFlavor = null;
  }

  static FlavorConfig activate(Flavor flavor) {
    _selectedFlavor = flavor;
    return _configFor(flavor);
  }

  static FlavorConfig activateByName(String name) {
    final normalized = name.trim().toLowerCase();
    final flavor = Flavor.values.firstWhere(
      (value) => value.name == normalized,
      orElse: () => Flavor.pipze,
    );
    return activate(flavor);
  }

  static FlavorConfig _configFor(Flavor flavor) {
    switch (flavor) {
      case Flavor.pipze:
        const config = PipzeConfig();
        return config.toFlavorConfig(Flavor.pipze, 'pipze');
    }
  }

  static bool isPipze() => _instance?.flavor == Flavor.pipze;
  static FlavorConfig get pipze => activate(Flavor.pipze);

  static bool isVantage() => usesVantageUi();

  static bool usesVantageUi() {
    final name = (_instance?.flavor.name ?? Flavor.pipze.name).toLowerCase();
    return const <String>{'pipze'}.contains(name);
  }

  static String get svgLogoAsset => instance.svgLogoPath;
  static String? get remoteLogo => instance.remoteLogoUrl;
  static bool get hasRemoteLogo => (instance.remoteLogoUrl ?? '').trim().isNotEmpty;
  static String get effectiveLogo => remoteLogo ?? svgLogoAsset;
  static Map<String, dynamic>? get brokerData => instance.selectedBrokerData;
  static String get appNameDisplay => instance.appName;

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
 darkPrimaryColor: _parseColor(config['darkPrimaryColor']) ?? current.darkPrimaryColor,
 secondaryColor: _parseColor(config['secondaryColor']) ?? current.secondaryColor,
 accentColor: _parseColor(config['accentColor']) ?? current.accentColor,
 apiBaseUrl: config['apiBaseUrl']?.toString() ?? current.apiBaseUrl,
 websocketUrl: config['websocketUrl']?.toString() ?? current.websocketUrl,
 chartBaseUrl: config['chartBaseUrl']?.toString() ?? current.chartBaseUrl,
 appIconPath: config['appIconPath']?.toString() ?? current.appIconPath,
 svgLogoPath: brokerLogoUrl ?? config['logoSvgPath']?.toString() ?? current.svgLogoPath,
 splashLogoPath: config['splashLogoPath']?.toString() ?? current.splashLogoPath,
 remoteLogoUrl: config['remoteLogoUrl']?.toString() ?? current.remoteLogoUrl,
 selectedBrokerData: brokerData ?? (config['selectedBrokerData'] as Map<String, dynamic>?) ?? current.selectedBrokerData,
 useNewChart: config['useNewChart'] is bool
 ? config['useNewChart'] as bool
 : current.useNewChart,
 );
 }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is Color) return value;
    if (value is int) return Color(value);
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    var hex = raw.replaceFirst('#', '').replaceFirst('0x', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  /// True when the active flavor supports per-user multi-broker selection
  /// (the Tenax-style flow stored in `SecureStorageService`).
  ///
  /// Returns `true` when the flavor id is `tenax` or when the active config
  /// already carries a non-empty `selectedBrokerData` payload. For all
  /// other flavors the feature is disabled.
  static bool get isMultiBrokerEnabled {
    final inst = _instance;
    if (inst == null) return false;
    final name = inst.flavor.name.toLowerCase();
    if (name == 'tenax') return true;
    return (inst.selectedBrokerData?.isNotEmpty ?? false);
  }

  /// Legacy "ONSA" brand flag. Kept for backward compatibility with code
  /// that gates UI on this brand — always false in this build.
  static bool get isONSA => false;

  /// Applies a Tenax multi-broker runtime payload onto the active
  /// [FlavorConfig]. When [payload] is null or empty this is a no-op so
  /// non-Tenax flavors stay untouched. The shape mirrors [applyBranding] —
  /// callers build a single map merging tenant-supplied config + selected
  /// broker name / logo overrides.
  static void applyTenaxBrokerRuntimeConfig(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return;
    applyBranding(
      config: payload,
      brokerName: payload['appName']?.toString(),
      brokerLogoUrl: payload['logoSvgPath']?.toString() ??
          payload['remoteLogoUrl']?.toString(),
      brokerData: payload,
    );
  }
}

 /// Public copy-with helper so brand-specific wrappers can derive a tweaked
 /// instance without re-constructing the whole config.
 extension FlavorConfigCopyWith on FlavorConfig {
  FlavorConfig copyWith({
    Color? primaryColor,
    Color? darkPrimaryColor,
    Color? secondaryColor,
    Color? accentColor,
    String? appName,
    String? appTitle,
    String? apiBaseUrl,
    String? websocketUrl,
    String? chartBaseUrl,
    String? appIconPath,
    String? svgLogoPath,
    String? splashLogoPath,
    String? remoteLogoUrl,
    Map<String, dynamic>? selectedBrokerData,
    bool? useNewChart,
  }) {
    return FlavorConfig._internal(
      flavor: flavor,
      title: appTitle ?? this.appTitle,
      appName: appName ?? this.appName,
      primaryColor: primaryColor ?? this.primaryColor,
      darkPrimaryColor: darkPrimaryColor ?? this.darkPrimaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      websocketUrl: websocketUrl ?? this.websocketUrl,
      chartBaseUrl: chartBaseUrl ?? this.chartBaseUrl,
      appIconPath: appIconPath ?? this.appIconPath,
      svgLogoPath: svgLogoPath ?? this.svgLogoPath,
      splashLogoPath: splashLogoPath ?? this.splashLogoPath,
      remoteLogoUrl: remoteLogoUrl ?? this.remoteLogoUrl,
      selectedBrokerData: selectedBrokerData ?? this.selectedBrokerData,
      useNewChart: useNewChart ?? this.useNewChart,
    );
  }
 }

 extension _BaseClientConfigFlavorConfigX on BaseClientConfig {
 FlavorConfig toFlavorConfig(Flavor flavor, String clientName) {
 return FlavorConfig(
 flavor: flavor,
 appName: brandName,
 appTitle: appTitle,
 primaryColor: primaryColor,
 darkPrimaryColor: darkPrimaryColor,
 secondaryColor: secondaryColor,
 accentColor: accentColor,
 websocketUrl: websocketUrl,
 chartBaseUrl: chartBaseUrl,
 apiBaseUrl: apiBaseUrl,
 appIconPath: getAssetPath(clientName, appIconPath),
 svgLogoPath: getAssetPath(clientName, logoSvgPath),
 splashLogoPath: getAssetPath(clientName, splashLogoPath),
 remoteLogoUrl: null,
 selectedBrokerData: null,
 useNewChart: useNewChart,
 );
 }
 }
