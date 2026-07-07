// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import 'clients/base_config.dart';
import 'clients/baazex/config.dart';
import 'clients/celestial/config.dart';
import 'clients/gtxprime/config.dart';
import 'clients/kantara/config.dart';
import 'clients/pipze/config.dart';
import 'clients/skyriss/config.dart';
import 'clients/telifox/config.dart';
import 'clients/tenax/config.dart';
import 'clients/vantage/config.dart';

enum Flavor {
  baazex,
  celestial,
  gtxprime,
  kantara,
  pipze,
  skyriss,
  telifox,
  tenax,
  vantage,
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

  static FlavorConfig get instance => _instance ?? activate(Flavor.vantage);

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
      orElse: () => Flavor.vantage,
    );
    return activate(flavor);
  }

  static FlavorConfig _configFor(Flavor flavor) {
    switch (flavor) {
      case Flavor.baazex:
        const config = BaazexConfig();
        return config.toFlavorConfig(Flavor.baazex, 'baazex');
      case Flavor.celestial:
        const config = CelestialConfig();
        return config.toFlavorConfig(Flavor.celestial, 'celestial');
      case Flavor.gtxprime:
        const config = GtxprimeConfig();
        return config.toFlavorConfig(Flavor.gtxprime, 'gtxprime');
      case Flavor.kantara:
        const config = KantaraConfig();
        return config.toFlavorConfig(Flavor.kantara, 'kantara');
      case Flavor.pipze:
        const config = PipzeConfig();
        return config.toFlavorConfig(Flavor.pipze, 'pipze');
      case Flavor.skyriss:
        const config = SkyrissConfig();
        return config.toFlavorConfig(Flavor.skyriss, 'skyriss');
      case Flavor.telifox:
        const config = TelifoxConfig();
        return config.toFlavorConfig(Flavor.telifox, 'telifox');
      case Flavor.tenax:
        const config = TenaxConfig();
        return config.toFlavorConfig(Flavor.tenax, 'tenax');
      case Flavor.vantage:
        const config = VantageConfig();
        return config.toFlavorConfig(Flavor.vantage, 'vantage');
    }
  }

  static bool isBaazex() => _instance?.flavor == Flavor.baazex;
  static FlavorConfig get baazex => activate(Flavor.baazex);

  static bool isCelestial() => _instance?.flavor == Flavor.celestial;
  static FlavorConfig get celestial => activate(Flavor.celestial);

  static bool isGtxprime() => _instance?.flavor == Flavor.gtxprime;
  static FlavorConfig get gtxprime => activate(Flavor.gtxprime);

  static bool isKantara() => _instance?.flavor == Flavor.kantara;
  static FlavorConfig get kantara => activate(Flavor.kantara);

  static bool isPipze() => _instance?.flavor == Flavor.pipze;
  static FlavorConfig get pipze => activate(Flavor.pipze);

  static bool isSkyriss() => _instance?.flavor == Flavor.skyriss;
  static FlavorConfig get skyriss => activate(Flavor.skyriss);

  static bool isTelifox() => _instance?.flavor == Flavor.telifox;
  static FlavorConfig get telifox => activate(Flavor.telifox);

  static bool isTenax() => _instance?.flavor == Flavor.tenax;
  static FlavorConfig get tenax => activate(Flavor.tenax);

  static FlavorConfig get vantage => activate(Flavor.vantage);

  static bool isVantage() => usesVantageUi();

  static bool usesVantageUi() {
    final name = (_instance?.flavor.name ?? Flavor.vantage.name).toLowerCase();
    return const <String>{'baazex', 'gtxprime', 'kantara', 'pipze', 'skyriss', 'telifox', 'tenax', 'vantage'}.contains(name);
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
