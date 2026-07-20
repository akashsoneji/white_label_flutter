#!/usr/bin/env dart
//
// scripts/generate_brand_config.dart
//
// Reads assets/brands/{brand}/brand.yaml (preferred) or assets/config/brands/brands.yaml and generates:
//   - lib/clients/{brand}/config.dart
//   - lib/clients/{brand}/launcher_icons.yaml
//   - lib/flavor_config.dart
//   - assets/config/brands/brands.json
//   - android/brand_flavors.gradle
//   - android/app/src/{brand}/
//   - .vscode/launch.json
//
// Usage: dart run scripts/generate_brand_config.dart

import 'dart:convert';
import 'dart:io';

const String yamlPath = 'assets/config/brands/brands.yaml';
const String brandRootPath = 'assets/brands';

void main() async {
  print('Brand Config Generator');
  print('======================\n');

  final source = loadBrandSource();
  final defaultBrand = source.defaultBrand;
  final brands = source.brands;

  if (brands.isEmpty) {
    print('ERROR: No brands found in $yamlPath');
    exit(1);
  }

  print(
    'Found ${brands.length} brand(s): ${brands.map((b) => b['name']).join(', ')}\n',
  );

  await generateBrandConfigs(brands);
  if (loadBrandsFromBrandFolders().isNotEmpty) {
    await generateLegacyBrandsYaml(defaultBrand, brands);
  }
  await generateBrandsJson(defaultBrand, brands);
  await generateFlavorConfig(defaultBrand, brands);
  await generateAndroidFlavors(brands);
  await createAndroidFlavorDirs(brands);
  await updateLaunchJson(brands);
  await updateTasksJson(brands);

  print('\nBrand config generation complete!');
  print('Run: ./build.sh <brand> apk release');
}

class BrandSource {
  final String defaultBrand;
  final List<Map<String, dynamic>> brands;

  const BrandSource({required this.defaultBrand, required this.brands});
}

BrandSource loadBrandSource() {
  final folderBrands = loadBrandsFromBrandFolders();
  if (folderBrands.isNotEmpty) {
    final defaultBrand =
        Platform.environment['DEFAULT_BRAND']?.trim().toLowerCase();
    final legacyDefault =
        File(yamlPath).existsSync()
            ? parseDefaultBrand(File(yamlPath).readAsStringSync()).toLowerCase()
            : '';
    final preferredDefault =
        defaultBrand != null && defaultBrand.isNotEmpty
            ? defaultBrand
            : legacyDefault;
    final resolvedDefault =
        preferredDefault.isNotEmpty &&
                folderBrands.any((brand) => brand['name'] == preferredDefault)
            ? preferredDefault
            : folderBrands.first['name'] as String;

    print('Using per-client brand.yaml files from $brandRootPath/*/brand.yaml');
    return BrandSource(defaultBrand: resolvedDefault, brands: folderBrands);
  }

  final yamlFile = File(yamlPath);
  if (!yamlFile.existsSync()) {
    print(
      'ERROR: No brand source found. Add $brandRootPath/{brand}/brand.yaml or $yamlPath',
    );
    exit(1);
  }

  final yaml = yamlFile.readAsStringSync();
  print('Using legacy source: $yamlPath');
  return BrandSource(
    defaultBrand: parseDefaultBrand(yaml),
    brands: parseYaml(yaml),
  );
}

List<Map<String, dynamic>> loadBrandsFromBrandFolders() {
  final root = Directory(brandRootPath);
  if (!root.existsSync()) return <Map<String, dynamic>>[];

  final brands = <Map<String, dynamic>>[];
  for (final entity in root.listSync().whereType<Directory>()) {
    final yamlFile = File('${entity.path}/brand.yaml');
    if (!yamlFile.existsSync()) continue;

    final parsed = parseSingleBrandYaml(
      yamlFile.readAsStringSync(),
      entity.path,
    );
    brands.add(parsed);
  }

  brands.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  return brands;
}

Map<String, dynamic> parseSingleBrandYaml(String yaml, String brandDir) {
  final parsed = parseYaml(
    'brands:\n${yaml.split('\n').map((line) => '  $line').join('\n')}',
  );
  if (parsed.isEmpty) {
    throw Exception('Invalid brand config: $brandDir/brand.yaml');
  }

  final brand = parsed.first;
  final name = (brand['name'] as String).trim().toLowerCase();
  if (name.isEmpty) throw Exception('Missing name in $brandDir/brand.yaml');

  final label = (brand['label'] as String).trim();
  brand['label'] = label.isEmpty ? name : label;

  final assets = brand['assets'] as Map<String, dynamic>;
  assets['appIcon'] = _resolveBrandAssetPath(
    brandDir,
    name,
    assets['appIcon'] ?? 'icon.png',
  );
  assets['logo'] = _resolveBrandAssetPath(
    brandDir,
    name,
    assets['logo'] ?? 'logo.svg',
  );
  assets['splashLogo'] = _resolveBrandAssetPath(
    brandDir,
    name,
    assets['splashLogo'] ?? 'splash_logo.svg',
  );

  // Ensure features section exists with sensible defaults.
  final features = brand['features'] as Map<String, dynamic>;
  if (!features.containsKey('useNewChart')) {
    features['useNewChart'] = 'false';
  }
  brand['features'] = features;
  return brand;
}

String _resolveBrandAssetPath(String brandDir, String name, dynamic value) {
  final raw = value.toString().trim();
  if (raw.startsWith('assets/')) return raw;
  return '$brandDir/$raw'.replaceAll('\\', '/');
}

String parseDefaultBrand(String yaml) {
  final match = RegExp(
    r'^\s*default:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(yaml);
  return match?.group(1)?.trim() ?? 'tenax';
}

List<Map<String, dynamic>> parseYaml(String yaml) {
  final brands = <Map<String, dynamic>>[];
  final lines = yaml.split('\n');
  Map<String, dynamic>? currentEntry;
  String currentSection = '';

  for (var line in lines) {
    line = line.replaceAll('\r', '');
    final trimmed = line.trim();

    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (trimmed.startsWith('brands:') || trimmed.startsWith('default:'))
      continue;

    if (trimmed.startsWith('- name:') || trimmed.startsWith('name:')) {
      if (currentEntry != null) brands.add(currentEntry);
      currentEntry = {
        'name': _extractValue(line),
        'type': 'child',
        'inheritsFrom': null,
        'label': '',
        'android': <String, dynamic>{},
        'ios': <String, dynamic>{},
        'colors': <String, dynamic>{},
        'urls': <String, dynamic>{},
        'assets': <String, dynamic>{},
        'features': <String, dynamic>{},
      };
      currentSection = '';
      continue;
    }

    if (currentEntry == null) continue;

    if (trimmed.startsWith('type:')) {
      currentEntry['type'] = _extractValue(line);
      currentSection = '';
      continue;
    }

    if (trimmed.startsWith('inheritsFrom:')) {
      final val = _extractValue(line);
      currentEntry['inheritsFrom'] = val.isEmpty ? null : val;
      currentSection = '';
      continue;
    }

    if (trimmed.startsWith('label:')) {
      currentEntry['label'] = _extractValue(line);
      currentSection = '';
      continue;
    }

    if (trimmed.startsWith('themeMode:')) {
      currentEntry['themeMode'] = _extractValue(line).toLowerCase();
      currentSection = '';
      continue;
    }

    // Supports YAML lists like:
    //   parents:
    //     - iquote
    //     - vantage
    if (trimmed.startsWith('parents:')) {
      currentEntry['parents'] = <String>[];
      currentSection = 'parents';
      continue;
    }

    var foundSection = false;
    for (final section in [
      'android',
      'ios',
      'colors',
      'urls',
      'assets',
      'features',
    ]) {
      if (trimmed.startsWith('$section:')) {
        currentSection = section;
        foundSection = true;
        break;
      }
    }
    if (foundSection) continue;
    if (currentSection.isEmpty) continue;

    // List items inside the `parents:` block.
    if (currentSection == 'parents') {
      final listMatch = RegExp(r'^-\s*(.+)$').firstMatch(trimmed);
      if (listMatch != null) {
        (currentEntry['parents'] as List<String>)
            .add(listMatch.group(1)!.trim().toLowerCase());
      }
      continue;
    }

    final keyMatch = RegExp(r'^(\s*)([^:#]+):\s*(.*)$').firstMatch(line);
    if (keyMatch != null) {
      final key = keyMatch.group(2)!.trim();
      final value = keyMatch
          .group(3)!
          .trim()
          .replaceAll('"', '')
          .replaceAll("'", '');
      (currentEntry[currentSection] as Map<String, dynamic>)[key] = value;
    }
  }

  if (currentEntry != null) brands.add(currentEntry);
  return brands;
}

String _extractValue(String line) {
  return line
      .split(':')
      .sublist(1)
      .join(':')
      .trim()
      .replaceAll('"', '')
      .replaceAll("'", '');
}

String _assetFilename(String fullPath) =>
    fullPath.contains('/') ? fullPath.split('/').last : fullPath;

String colorToHex(String color) {
  var hex = color.replaceAll('#', '').replaceAll('0x', '').toUpperCase();
  if (hex.length == 8) return hex.substring(2);
  return hex;
}

String _colorValue(
  Map<String, dynamic> colors,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = colors[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return fallback;
}

String _brandClassName(String name) {
  return name
      .split(RegExp(r'[_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();
}

String _dartString(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

String _envClientName() {
  final direct =
      Platform.environment['CLIENT'] ?? Platform.environment['FLAVOR'];
  if (direct != null && direct.trim().isNotEmpty)
    return direct.trim().toLowerCase();

  final define = Platform.environment['DART_DEFINES'];
  if (define == null || define.trim().isEmpty) return '';

  for (final encoded in define.split(',')) {
    try {
      final decoded = utf8.decode(base64.decode(encoded));
      final separator = decoded.indexOf('=');
      if (separator <= 0) continue;
      final key = decoded.substring(0, separator);
      final value = decoded.substring(separator + 1).trim().toLowerCase();
      if ((key == 'CLIENT' || key == 'FLAVOR') && value.isNotEmpty)
        return value;
    } catch (_) {
      // Ignore non-base64 values.
    }
  }

  return '';
}

List<Map<String, dynamic>> _brandsForCurrentBuild(
  String defaultBrand,
  List<Map<String, dynamic>> brands,
) {
  final selected = _envClientName();
  if (selected.isEmpty || selected == 'all') return brands;

  final buildBrand =
      brands
          .where((brand) => (brand['name'] as String).toLowerCase() == selected)
          .toList();
  if (buildBrand.isEmpty) {
    print(
      '  ⚠️  CLIENT/FLAVOR=$selected does not match brands.yaml; generating all flavors.',
    );
    return brands;
  }

  print('  🔒 Single-client Dart config enabled: $selected');
  return buildBrand;
}

Future<void> generateBrandConfigs(List<Map<String, dynamic>> brands) async {
  print('1. Generating brand config Dart files...');

  for (final brand in brands) {
    final name = brand['name'] as String;
    final label = brand['label'] as String;
    final colors = brand['colors'] as Map<String, dynamic>;
    final urls = brand['urls'] as Map<String, dynamic>;
    final assets = brand['assets'] as Map<String, dynamic>;

    final primary = colors['primary'] ?? '#5F259E';
    final darkPrimary = colors['darkPrimary'] ?? '#FFFFFF';
    final secondary = colors['secondary'] ?? '#FFFFFF';
    final accent = colors['accent'] ?? primary;
    final api = urls['api'] ?? 'https://example.com/api/';
    final websocket = urls['websocket'] ?? 'wss://example.com/ws';
    final chart = urls['chart'] ?? 'https://example.com';
    final appIcon = assets['appIcon'] ?? 'assets/brands/$name/icon.png';
    final logo = assets['logo'] ?? 'assets/brands/$name/logo.svg';
    final splashLogo =
        assets['splashLogo'] ?? 'assets/brands/$name/splash_logo.svg';
    final className = _brandClassName(name);

    // Features
    final features =
        brand['features'] is Map<String, dynamic>
            ? brand['features'] as Map<String, dynamic>
            : <String, dynamic>{};
    final useNewChart =
        (features['useNewChart']?.toString().toLowerCase() == 'true');

    final clientDir = Directory('lib/clients/$name');
    if (!clientDir.existsSync()) clientDir.createSync(recursive: true);

    final content =
        '''// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import '../base_config.dart';

/// Auto-generated config for "$label".
/// Change values in assets/config/brands/brands.yaml and re-run the generator.
class ${className}Config extends BaseClientConfig {
  const ${className}Config()
      : super(
          brandName: '${_dartString(label)}',
          appTitle: '${_dartString(label)}',
          primaryColor: const Color(0xFF${colorToHex(primary)}),
          darkPrimaryColor: const Color(0xFF${colorToHex(darkPrimary)}),
          secondaryColor: const Color(0xFF${colorToHex(secondary)}),
          accentColor: const Color(0xFF${colorToHex(accent)}),
          logoSvgPath: '${_dartString(_assetFilename(logo))}',
          splashLogoPath: '${_dartString(_assetFilename(splashLogo))}',
          appIconPath: '${_dartString(_assetFilename(appIcon))}',
 apiBaseUrl: '${_dartString(api)}',
 websocketUrl: '${_dartString(websocket)}',
 chartBaseUrl: '${_dartString(chart)}',
 useNewChart: $useNewChart,
 );
}
''';

    File('${clientDir.path}/config.dart').writeAsStringSync(content);
    await generateLauncherIconYaml(brand);
    print('  Created: lib/clients/$name/config.dart');
    print('  Created: lib/clients/$name/launcher_icons.yaml');
  }
}

Future<void> generateLauncherIconYaml(Map<String, dynamic> brand) async {
  final name = brand['name'] as String;
  final colors = brand['colors'] as Map<String, dynamic>;
  final assets = brand['assets'] as Map<String, dynamic>;
  final primary = colors['primary'] ?? '#5F259E';
  final launcherBackground = _colorValue(colors, [
    'launcherBackground',
    'icLauncherBackground',
    'adaptiveIconBackground',
  ], primary);
  final appIcon = assets['appIcon'] ?? 'assets/brands/$name/icon.png';

  final content =
      '''# GENERATED — Do not edit manually. Regenerate from brands.yaml.
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "$appIcon"
  min_sdk_android: 21
  adaptive_icon_background: "$launcherBackground"
  adaptive_icon_foreground: "$appIcon"
''';

  File('lib/clients/$name/launcher_icons.yaml').writeAsStringSync(content);
}

Future<void> generateLegacyBrandsYaml(
  String defaultBrand,
  List<Map<String, dynamic>> brands,
) async {
  final buffer = StringBuffer();
  buffer.writeln(
    '# GENERATED — Do not edit manually when using assets/brands/{brand}/brand.yaml.',
  );
  buffer.writeln('# Source of truth: assets/brands/*/brand.yaml');
  buffer.writeln();
  buffer.writeln('default: $defaultBrand');
  buffer.writeln();
  buffer.writeln('brands:');

  for (final brand in brands) {
    buffer.writeln('  - name: ${brand['name']}');
    buffer.writeln('    type: ${brand['type']}');
    if (brand['inheritsFrom'] != null)
      buffer.writeln('    inheritsFrom: ${brand['inheritsFrom']}');
    buffer.writeln('    label: ${brand['label']}');
    buffer.writeln('    themeMode: ${brand['themeMode'] ?? 'both'}');
    for (final section in [
      'android',
      'ios',
      'colors',
      'urls',
      'assets',
      'features',
    ]) {
      final values = brand[section] as Map<String, dynamic>;
      buffer.writeln(' $section:');
      values.forEach((key, value) {
        buffer.writeln(' $key: "$value"');
      });
    }
    buffer.writeln();
  }

  File(yamlPath).writeAsStringSync(buffer.toString());
  print('  Updated: $yamlPath');
}

Future<void> generateBrandsJson(
  String defaultBrand,
  List<Map<String, dynamic>> brands,
) async {
  print('\n2. Generating brands.json...');

  final simpleList = brands.map((b) => b['name'] as String).toList();
  final details =
      brands.map((brand) {
        final map = <String, dynamic>{
          'name': brand['name'],
          'type': brand['type'],
          'label': brand['label'],
          'themeMode': brand['themeMode'] ?? 'both',
          'android': brand['android'],
          'ios': brand['ios'],
          'colors': brand['colors'],
          'urls': brand['urls'],
          'assets': brand['assets'],
          'features':
              brand['features'] ?? <String, dynamic>{'useNewChart': 'false'},
        };
        if (brand['inheritsFrom'] != null)
          map['inheritsFrom'] = brand['inheritsFrom'];
        return map;
      }).toList();

  final json = const JsonEncoder.withIndent('  ').convert({
    'default': defaultBrand,
    'brands': simpleList,
    'brandDetails': details,
  });

  File('assets/config/brands/brands.json').writeAsStringSync('$json\n');
  print('  Updated: assets/config/brands/brands.json');
  print('  Default brand: $defaultBrand');
}

Future<void> generateFlavorConfig(
  String defaultBrand,
  List<Map<String, dynamic>> brands,
) async {
  print('\n3. Generating lib/flavor_config.dart...');

  final buildBrands = _brandsForCurrentBuild(defaultBrand, brands);
  final fallbackBrand =
      buildBrands.any((brand) => brand['name'] == defaultBrand)
          ? defaultBrand
          : buildBrands.first['name'] as String;
  final imports = buildBrands
      .map((brand) => "import 'clients/${brand['name']}/config.dart';")
      .join('\n');
  final enumValues = buildBrands
      .map((brand) => '  ${brand['name']},')
      .join('\n');
  final vantageUiBrands = const <String>{'vantage', 'gtxprime', 'kantara', 'riyadex', 'telifox', 'tenax'}.map((n) => "'$n'").join(', ');
  final iquoteUiBrands = const <String>{'iquote', 'pipze', 'skyriss', 'baazex'}.map((n) => "'$n'").join(', ');
  final cases = buildBrands
      .map((brand) {
        final name = brand['name'] as String;
        final className = _brandClassName(name);
        return '''      case Flavor.$name:
        const config = ${className}Config();
        return config.toFlavorConfig(Flavor.$name, '$name');''';
      })
      .join('\n');
  final getters = buildBrands
      .map((brand) {
        final name = brand['name'] as String;
        final configGetter =
            '  static FlavorConfig get $name => activate(Flavor.$name);';
        if (name == 'vantage') return configGetter;
        return '''  static bool is${_brandClassName(name)}() => _instance?.flavor == Flavor.$name;
$configGetter''';
      })
      .join('\n\n');

  final content =
      '''// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import 'clients/base_config.dart';
$imports

enum Flavor {
$enumValues
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

  static FlavorConfig get instance => _instance ?? activate(Flavor.$fallbackBrand);

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
      orElse: () => Flavor.$fallbackBrand,
    );
    return activate(flavor);
  }

  static FlavorConfig _configFor(Flavor flavor) {
    switch (flavor) {
$cases
    }
  }

$getters

  static bool isVantage() => usesVantageUi();

  static bool usesVantageUi() {
    final name = (_instance?.flavor.name ?? Flavor.$fallbackBrand.name).toLowerCase();
    return const <String>{$vantageUiBrands}.contains(name);
  }

  static bool usesIquoteUi() {
    final name = (_instance?.flavor.name ?? Flavor.$fallbackBrand.name).toLowerCase();
    return const <String>{$iquoteUiBrands}.contains(name);
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
    if (hex.length == 6) hex = 'FF\$hex';
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
''';

  File('lib/flavor_config.dart').writeAsStringSync(content);
  print('  Updated: lib/flavor_config.dart');
}

Future<void> generateAndroidFlavors(List<Map<String, dynamic>> brands) async {
  print('\n4. Generating android/brand_flavors.gradle...');

  final buffer = StringBuffer();
  buffer.writeln('// GENERATED — Do not edit manually.');
  buffer.writeln(
    '// Regenerate from brands.yaml: dart run scripts/generate_brand_config.dart',
  );
  buffer.writeln();
  buffer.writeln('ext.brandFlavors = [');

  for (final brand in brands) {
    final name = brand['name'] as String;
    final label = brand['label'] as String;
    final android = brand['android'] as Map<String, dynamic>;
    final colors = brand['colors'] as Map<String, dynamic>;
    final appId = android['applicationId'] ?? 'com.$name.app';
    final appName = android['appName'] ?? label;
    final primaryColor = colors['primary'] as String? ?? '#5F259E';
    final primary = colorToHex(primaryColor);
    final secondary = colorToHex(colors['secondary'] as String? ?? '#FFFFFF');
    final accent = colorToHex(colors['accent'] as String? ?? primaryColor);
    final splashColor = colorToHex(
      _colorValue(colors, ['splashColor', 'splash'], primaryColor),
    );
    final launcherBackground = colorToHex(
      _colorValue(colors, [
        'launcherBackground',
        'icLauncherBackground',
        'adaptiveIconBackground',
      ], primaryColor),
    );

    buffer.writeln('    [');
    buffer.writeln('        name: "$name",');
    buffer.writeln('        label: "$label",');
    buffer.writeln('        appId: "$appId",');
    buffer.writeln('        appName: "$appName",');
    buffer.writeln('        primary: "#$primary",');
    buffer.writeln('        secondary: "#$secondary",');
    buffer.writeln('        accent: "#$accent",');
    buffer.writeln('        splashColor: "#$splashColor",');
    buffer.writeln('        launcherBackground: "#$launcherBackground",');
    buffer.writeln('        type: "${brand['type']}",');
    if (brand['inheritsFrom'] != null)
      buffer.writeln('        inheritsFrom: "${brand['inheritsFrom']}",');
    buffer.writeln('    ],');
  }

  buffer.writeln(']');
  buffer.writeln();
  buffer.writeln('// Helper to get flavor by name');
  buffer.writeln(
    'ext.getBrandFlavor = { String name -> brandFlavors.find { it.name == name } }',
  );

  File('android/brand_flavors.gradle').writeAsStringSync(buffer.toString());
  print('  Created: android/brand_flavors.gradle');
  print('  ${brands.length} flavor(s) defined');
}

Future<void> createAndroidFlavorDirs(List<Map<String, dynamic>> brands) async {
  print('\n5. Creating Android flavor directories...');

  for (final brand in brands) {
    final name = brand['name'] as String;
    final flavorDir = Directory('android/app/src/$name');
    flavorDir.createSync(recursive: true);
    final resDir = Directory('${flavorDir.path}/res');
    resDir.createSync(recursive: true);

    final colors = brand['colors'] as Map<String, dynamic>;
    final primaryColor = colors['primary'] as String? ?? '#5F259E';
    final primary = colorToHex(primaryColor);
    final secondary = colorToHex(colors['secondary'] as String? ?? '#FFFFFF');
    final accent = colorToHex(colors['accent'] as String? ?? primaryColor);
    final splashColor = colorToHex(
      _colorValue(colors, ['splashColor', 'splash'], primaryColor),
    );
    final launcherBackground = colorToHex(
      _colorValue(colors, [
        'launcherBackground',
        'icLauncherBackground',
        'adaptiveIconBackground',
      ], primaryColor),
    );

    final valuesDir = Directory('${resDir.path}/values');
    valuesDir.createSync(recursive: true);
    File('${valuesDir.path}/colors.xml').writeAsStringSync(
      '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary_color">#$primary</color>
    <color name="secondary_color">#$secondary</color>
    <color name="accent_color">#$accent</color>
    <color name="my_splash_color">#$splashColor</color>
    <color name="ic_launcher_background">#$launcherBackground</color>
</resources>
''',
    );

    final manifestPath = '${flavorDir.path}/AndroidManifest.xml';
    if (!File(manifestPath).existsSync()) {
      File(manifestPath).writeAsStringSync(_androidManifestTemplate());
    }

    for (final drawableDir in ['drawable', 'drawable-v21']) {
      final dDir = Directory('${resDir.path}/$drawableDir');
      dDir.createSync(recursive: true);
      File('${dDir.path}/launch_background.xml').writeAsStringSync(
        '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/my_splash_color" />
</layer-list>
''',
      );
    }

    final xmlDir = Directory('${flavorDir.path}/res/xml');
    xmlDir.createSync(recursive: true);
    File('${xmlDir.path}/file_paths.xml').writeAsStringSync(
      '''<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-path name="external" path="." />
    <external-files-path name="external_files" path="." />
    <cache-path name="cache" path="." />
    <external-cache-path name="external_cache" path="." />
</paths>
''',
    );

    print('  Ready: android/app/src/$name/ (manifest + resources)');
  }
}

String _androidManifestTemplate() =>
    '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <uses-permission android:name="android.permission.USE_FINGERPRINT" />
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

    <application
        android:label="@string/app_name"
        android:enableOnBackInvokedCallback="true"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true"
        tools:replace="android:label,android:icon">

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="\${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:screenOrientation="portrait"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
''';

/// Returns a map of child-name → parent-label for every brand whose
/// `inheritsFrom` points at another known brand. Used by
/// `updateLaunchJson` to make the parent visible in the VS Code
/// run-configuration dropdown.
Map<String, String> _buildParentLabelMap(List<Map<String, dynamic>> brands) {
  final byName = <String, String>{};
  for (final brand in brands) {
    final label = brand['label'] as String;
    final name = brand['name'] as String;
    byName[name] = label.isEmpty ? name : label;
  }
  final parents = <String, String>{};
  for (final brand in brands) {
    final name = brand['name'] as String;
    final inheritsFrom = brand['inheritsFrom'] as String?;
    if (inheritsFrom != null && inheritsFrom.isNotEmpty) {
      parents[name] = byName[inheritsFrom] ?? inheritsFrom;
    }
  }
  return parents;
}

/// Returns every parent this child can run as, in preference order.
///
/// If the child's `brand.yaml` declares `parents:` (a list of parent names),
/// that list is used verbatim (preserves the author's ordering).
/// Otherwise falls back to `[inheritsFrom]` so existing single-parent brands
/// keep their single entry.
List<String> _parentBrandsFor(Map<String, dynamic> brand) {
  final raw = brand['parents'];
  if (raw is List && raw.isNotEmpty) {
    return raw.map((e) => e.toString().trim().toLowerCase()).toList();
  }
  final inherits = brand['inheritsFrom']?.toString().trim().toLowerCase();
  if (inherits != null && inherits.isNotEmpty) return [inherits];
  return [brand['name'].toString().toLowerCase()];
}

Future<void> updateLaunchJson(List<Map<String, dynamic>> brands) async {
  print('\n6. Updating .vscode/launch.json...');

  final configs = <Map<String, dynamic>>[];
  final parentLabelFor = _buildParentLabelMap(brands);
  final byName = <String, Map<String, dynamic>>{};
  for (final brand in brands) {
    byName[brand['name'].toString().toLowerCase()] = brand;
  }

  for (final brand in brands) {
    final name = brand['name']as String;
    final label = brand['label'] as String;
    final isParent = (brand['inheritsFrom'] == null || (brand['inheritsFrom'] as String).isEmpty) &&
        (brand['parents'] == null || !(brand['parents'] as List).any((e) => e.toString().isNotEmpty));
    final parentBrands = _parentBrandsFor(brand);

    for (final parent in parentBrands) {
      final parentBrand = byName[parent];
      final parentLabel = parentBrand != null
          ? (parentBrand['label']?.toString() ?? parent)
          : parent;
      for (final mode in ['debug', 'profile', 'release']) {
        final args = [
          '--flavor',
          name,
          '--dart-define=CLIENT=$name',
          '--dart-define=FLAVOR=$name',
          '--dart-define=PARENT=$parent',
        ];
        if (mode == 'debug') args.add('--no-enable-impeller');
        final displayName = isParent
            ? '$label (parent) ($mode)'
            : '$label (parent: $parentLabel) ($mode)';
        configs.add({
          'name': displayName,
          'request': 'launch',
          'type': 'dart',
          'program': 'lib/main.dart',
          'args': args,
          'flutterMode': mode,
          'console': 'terminal',
          'preLaunchTask': 'prepare-$name',
        });
      }
    }
  }

  Directory('.vscode').createSync(recursive: true);
  File('.vscode/launch.json').writeAsStringSync(_generateLaunchJson(configs));
  print('  Updated: .vscode/launch.json');
  print('  Total configurations: ${configs.length}');
}

Future<void> updateTasksJson(List<Map<String, dynamic>> brands) async {
  print('\n7. Updating .vscode/tasks.json...');

  final tasks = <Map<String, dynamic>>[];

  // Legacy scripts
  tasks.add({
    'label': 'Set Android icon (vantage)',
    'type': 'shell',
    'command': 'bash',
    'args': ['scripts/set_vantage_android_launcher_icon.sh'],
    'options': {'cwd': '\${workspaceFolder}'},
    'problemMatcher': [],
  });
  tasks.add({
    'label': 'Set Android icon (tenax)',
    'type': 'shell',
    'command': 'bash',
    'args': ['scripts/set_tenax_android_launcher_icon.sh'],
    'options': {'cwd': '\${workspaceFolder}'},
    'problemMatcher': [],
  });

  // Dynamic prepare tasks for all brands
  for (final brand in brands) {
    final name = brand['name'] as String;
    tasks.add({
      'label': 'prepare-$name',
      'type': 'shell',
      'command': 'bash',
      'args': [
        '-lc',
        'dart run scripts/prepare_flavor.dart $name && rm -rf .dart_tool/flutter_build',
      ],
      'options': {'cwd': '\${workspaceFolder}'},
      'problemMatcher': [],
      'presentation': {
        'reveal': 'always',
        'panel': 'dedicated',
        'focus': false,
        'clear': true,
      },
    });
  }

  final jsonStr = const JsonEncoder.withIndent(
    '  ',
  ).convert({'version': '2.0.0', 'tasks': tasks});

  Directory('.vscode').createSync(recursive: true);
  File('.vscode/tasks.json').writeAsStringSync('$jsonStr\n');
  print('  Updated: .vscode/tasks.json');
}

String _generateLaunchJson(List<Map<String, dynamic>> configs) {
  final buffer = StringBuffer();
  buffer.writeln('{');
  buffer.writeln('    "version": "0.2.0",');
  buffer.writeln('    "configurations": [');

  for (var i = 0; i < configs.length; i++) {
    final config = configs[i];
    buffer.writeln('        {');
    buffer.writeln(
      '            "name": "${_escapeJson(config['name'] as String)}",',
    );
    buffer.writeln('            "request": "${config['request']}",');
    buffer.writeln('            "type": "${config['type']}",');
    buffer.writeln('            "program": "${config['program']}",');
    buffer.write('            "args": [');
    buffer.write(
      (config['args'] as List<String>)
          .map((a) => '"${_escapeJson(a)}"')
          .join(', '),
    );
    buffer.writeln('],');
    buffer.writeln('            "flutterMode": "${config['flutterMode']}",');
    buffer.writeln('            "console": "${config['console']}",');
    buffer.writeln('            "preLaunchTask": "${config['preLaunchTask']}"');
    buffer.write('        }');
    if (i < configs.length - 1) buffer.write(',');
    buffer.writeln();
  }

  buffer.writeln('    ]');
  buffer.writeln('}');
  return buffer.toString();
}

String _escapeJson(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

String _getIconEmoji(String name, int index) {
  final emojis = ['🔵', '🟡', '🟢', '🔴', '🟣', '🟠', '🔶', '🩵', '🩷', '🟤'];
  return emojis[index % emojis.length];
}
