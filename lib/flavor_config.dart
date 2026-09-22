// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import 'clients/base_config.dart';
import 'clients/afx/config.dart';
import 'clients/baazex/config.dart';
import 'clients/celestial/config.dart';
import 'clients/gtxprime/config.dart';
import 'clients/iquote/config.dart';
import 'clients/kantara/config.dart';
import 'clients/meta/config.dart';
import 'clients/pippro/config.dart';
import 'clients/pipze/config.dart';
import 'clients/riyadex/config.dart';
import 'clients/skyriss/config.dart';
import 'clients/telifox/config.dart';
import 'clients/tenax/config.dart';
import 'clients/vantage/config.dart';

enum Flavor {
  afx,
  baazex,
  celestial,
  gtxprime,
  iquote,
  kantara,
  meta,
  pippro,
  pipze,
  riyadex,
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
      case Flavor.afx:
        const config = AfxConfig();
        return config.toFlavorConfig(Flavor.afx, 'afx');
      case Flavor.baazex:
        const config = BaazexConfig();
        return config.toFlavorConfig(Flavor.baazex, 'baazex');
      case Flavor.celestial:
        const config = CelestialConfig();
        return config.toFlavorConfig(Flavor.celestial, 'celestial');
      case Flavor.gtxprime:
        const config = GtxprimeConfig();
        return config.toFlavorConfig(Flavor.gtxprime, 'gtxprime');
      case Flavor.iquote:
        const config = IquoteConfig();
        return config.toFlavorConfig(Flavor.iquote, 'iquote');
      case Flavor.kantara:
        const config = KantaraConfig();
        return config.toFlavorConfig(Flavor.kantara, 'kantara');
      case Flavor.meta:
        const config = MetaConfig();
        return config.toFlavorConfig(Flavor.meta, 'meta');
      case Flavor.pippro:
        const config = PipproConfig();
        return config.toFlavorConfig(Flavor.pippro, 'pippro');
      case Flavor.pipze:
        const config = PipzeConfig();
        return config.toFlavorConfig(Flavor.pipze, 'pipze');
      case Flavor.riyadex:
        const config = RiyadexConfig();
        return config.toFlavorConfig(Flavor.riyadex, 'riyadex');
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

  static bool isAfx() => _instance?.flavor == Flavor.afx;
  static FlavorConfig get afx => activate(Flavor.afx);

  static bool isBaazex() => _instance?.flavor == Flavor.baazex;
  static FlavorConfig get baazex => activate(Flavor.baazex);

  static bool isCelestial() => _instance?.flavor == Flavor.celestial;
  static FlavorConfig get celestial => activate(Flavor.celestial);

  static bool isGtxprime() => _instance?.flavor == Flavor.gtxprime;
  static FlavorConfig get gtxprime => activate(Flavor.gtxprime);

  static bool isIquote() => _instance?.flavor == Flavor.iquote;
  static FlavorConfig get iquote => activate(Flavor.iquote);

  static bool isKantara() => _instance?.flavor == Flavor.kantara;
  static FlavorConfig get kantara => activate(Flavor.kantara);

  static bool isMeta() => _instance?.flavor == Flavor.meta;
  static FlavorConfig get meta => activate(Flavor.meta);

  static bool isPippro() => _instance?.flavor == Flavor.pippro;
  static FlavorConfig get pippro => activate(Flavor.pippro);

  static bool isPipze() => _instance?.flavor == Flavor.pipze;
  static FlavorConfig get pipze => activate(Flavor.pipze);

  static bool isRiyadex() => _instance?.flavor == Flavor.riyadex;
  static FlavorConfig get riyadex => activate(Flavor.riyadex);

  static bool isSkyriss() => _instance?.flavor == Flavor.skyriss;
  static FlavorConfig get skyriss => activate(Flavor.skyriss);

  static bool isTelifox() => _instance?.flavor == Flavor.telifox;
  static FlavorConfig get telifox => activate(Flavor.telifox);

  static bool isTenax() => _instance?.flavor == Flavor.tenax;
  static FlavorConfig get tenax => activate(Flavor.tenax);

  static FlavorConfig get vantage => activate(Flavor.vantage);

  static bool isVantage() => usesVantageUi();

  static bool usesVantageUi() {
    final explicitParent = const String.fromEnvironment('PARENT', defaultValue: '').trim().toLowerCase();
    if (explicitParent == 'vantage') return true;
    if (explicitParent.isNotEmpty && explicitParent != 'vantage') return false;

    final name = (_instance?.flavor.name ?? Flavor.vantage.name).toLowerCase();
    return const <String>{'vantage', 'baazex', 'gtxprime', 'iquote', 'kantara', 'pippro', 'pipze', 'riyadex', 'telifox', 'tenax'}.contains(name);
  }

  static bool usesIquoteUi() {
    final explicitParent = const String.fromEnvironment('PARENT', defaultValue: '').trim().toLowerCase();
    if (explicitParent == 'iquote') return true;
    if (explicitParent.isNotEmpty && explicitParent != 'iquote') return false;

    final name = (_instance?.flavor.name ?? Flavor.vantage.name).toLowerCase();
    return const <String>{'iquote', 'skyriss'}.contains(name);
  }

  static String get svgLogoAsset => instance.svgLogoPath;
  static String? get remoteLogo => instance.remoteLogoUrl;
  static bool get hasRemoteLogo => (instance.remoteLogoUrl ?? '').trim().isNotEmpty;
  static String get effectiveLogo => hasRemoteLogo ? remoteLogo! : svgLogoAsset;
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
