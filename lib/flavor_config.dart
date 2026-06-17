// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import 'clients/base_config.dart';
import 'clients/celestial/config.dart';

enum Flavor {
  celestial,
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
  }) : appTitle = title;

  static FlavorConfig get instance => _instance ?? activate(Flavor.celestial);

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
      orElse: () => Flavor.celestial,
    );
    return activate(flavor);
  }

  static FlavorConfig _configFor(Flavor flavor) {
    switch (flavor) {
      case Flavor.celestial:
        const config = CelestialConfig();
        return config.toFlavorConfig(Flavor.celestial, 'celestial');
    }
  }

  static bool isCelestial() => _instance?.flavor == Flavor.celestial;
  static FlavorConfig get celestial => activate(Flavor.celestial);

  static bool isVantage() => usesVantageUi();

  static bool usesVantageUi() {
    final name = (_instance?.flavor.name ?? Flavor.celestial.name).toLowerCase();
    return const <String>{}.contains(name);
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
    );
  }
}
