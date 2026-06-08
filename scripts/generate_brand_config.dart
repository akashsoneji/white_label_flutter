#!/usr/bin/env dart
//
// scripts/generate_brand_config.dart
//
// Reads assets/config/brands/brands.yaml and generates:
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

void main() async {
  print('Brand Config Generator');
  print('======================\n');

  final yamlFile = File(yamlPath);
  if (!yamlFile.existsSync()) {
    print('ERROR: $yamlPath not found');
    exit(1);
  }

  final yaml = yamlFile.readAsStringSync();
  final defaultBrand = parseDefaultBrand(yaml);
  final brands = parseYaml(yaml);

  if (brands.isEmpty) {
    print('ERROR: No brands found in $yamlPath');
    exit(1);
  }

  print('Found ${brands.length} brand(s): ${brands.map((b) => b['name']).join(', ')}\n');

  await generateBrandConfigs(brands);
  await generateBrandsJson(defaultBrand, brands);
  await generateFlavorConfig(defaultBrand, brands);
  await generateAndroidFlavors(brands);
  await createAndroidFlavorDirs(brands);
  await updateLaunchJson(brands);

  print('\nBrand config generation complete!');
  print('Run: ./build.sh <brand> apk release');
}

String parseDefaultBrand(String yaml) {
  final match = RegExp(r'^\s*default:\s*(\S+)\s*$', multiLine: true).firstMatch(yaml);
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
    if (trimmed.startsWith('brands:') || trimmed.startsWith('default:')) continue;

    if (trimmed.startsWith('- name:')) {
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

    var foundSection = false;
    for (final section in ['android', 'ios', 'colors', 'urls', 'assets']) {
      if (trimmed.startsWith('$section:')) {
        currentSection = section;
        foundSection = true;
        break;
      }
    }
    if (foundSection) continue;
    if (currentSection.isEmpty) continue;

    final keyMatch = RegExp(r'^(\s*)([^:#]+):\s*(.*)$').firstMatch(line);
    if (keyMatch != null) {
      final key = keyMatch.group(2)!.trim();
      final value = keyMatch.group(3)!.trim().replaceAll('"', '').replaceAll("'", '');
      (currentEntry[currentSection] as Map<String, dynamic>)[key] = value;
    }
  }

  if (currentEntry != null) brands.add(currentEntry);
  return brands;
}

String _extractValue(String line) {
  return line.split(':').sublist(1).join(':').trim().replaceAll('"', '').replaceAll("'", '');
}

String _assetFilename(String fullPath) => fullPath.contains('/') ? fullPath.split('/').last : fullPath;

String colorToHex(String color) {
  var hex = color.replaceAll('#', '').replaceAll('0x', '').toUpperCase();
  if (hex.length == 8) return hex.substring(2);
  return hex;
}

String _brandClassName(String name) {
  return name
      .split(RegExp(r'[_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();
}

String _dartString(String value) => value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

Future<void> generateBrandConfigs(List<Map<String, dynamic>> brands) async {
  print('1. Generating brand config Dart files...');

  for (final brand in brands) {
    final name = brand['name'] as String;
    final label = brand['label'] as String;
    final colors = brand['colors'] as Map<String, dynamic>;
    final urls = brand['urls'] as Map<String, dynamic>;
    final assets = brand['assets'] as Map<String, dynamic>;

    final primary = colors['primary'] ?? '#5F259E';
    final secondary = colors['secondary'] ?? '#FFFFFF';
    final accent = colors['accent'] ?? primary;
    final api = urls['api'] ?? 'https://example.com/api/';
    final websocket = urls['websocket'] ?? 'wss://example.com/ws';
    final chart = urls['chart'] ?? 'https://example.com';
    final appIcon = assets['appIcon'] ?? 'assets/brands/$name/icon.png';
    final logo = assets['logo'] ?? 'assets/brands/$name/logo.svg';
    final splashLogo = assets['splashLogo'] ?? 'assets/brands/$name/splash_logo.svg';
    final className = _brandClassName(name);

    final clientDir = Directory('lib/clients/$name');
    if (!clientDir.existsSync()) clientDir.createSync(recursive: true);

    final content = '''// GENERATED — Do not edit manually. Regenerate from brands.yaml.
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
          secondaryColor: const Color(0xFF${colorToHex(secondary)}),
          accentColor: const Color(0xFF${colorToHex(accent)}),
          logoSvgPath: '${_dartString(_assetFilename(logo))}',
          splashLogoPath: '${_dartString(_assetFilename(splashLogo))}',
          appIconPath: '${_dartString(_assetFilename(appIcon))}',
          apiBaseUrl: '${_dartString(api)}',
          websocketUrl: '${_dartString(websocket)}',
          chartBaseUrl: '${_dartString(chart)}',
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
  final appIcon = assets['appIcon'] ?? 'assets/brands/$name/icon.png';

  final content = '''# GENERATED — Do not edit manually. Regenerate from brands.yaml.
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "$appIcon"
  min_sdk_android: 21
  adaptive_icon_background: "$primary"
  adaptive_icon_foreground: "$appIcon"
''';

  File('lib/clients/$name/launcher_icons.yaml').writeAsStringSync(content);
}

Future<void> generateBrandsJson(String defaultBrand, List<Map<String, dynamic>> brands) async {
  print('\n2. Generating brands.json...');

  final simpleList = brands.map((b) => b['name'] as String).toList();
  final details = brands.map((brand) {
    final map = <String, dynamic>{
      'name': brand['name'],
      'type': brand['type'],
      'label': brand['label'],
      'android': brand['android'],
      'ios': brand['ios'],
      'colors': brand['colors'],
      'urls': brand['urls'],
      'assets': brand['assets'],
    };
    if (brand['inheritsFrom'] != null) map['inheritsFrom'] = brand['inheritsFrom'];
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

Future<void> generateFlavorConfig(String defaultBrand, List<Map<String, dynamic>> brands) async {
  print('\n3. Generating lib/flavor_config.dart...');

  final imports = brands
      .map((brand) => "import 'clients/${brand['name']}/config.dart';")
      .join('\n');
  final enumValues = brands.map((brand) => '  ${brand['name']},').join('\n');
  final cases = brands.map((brand) {
    final name = brand['name'] as String;
    final className = _brandClassName(name);
    return '''      case Flavor.$name:
        const config = ${className}Config();
        return config.toFlavorConfig(Flavor.$name, '$name');''';
  }).join('\n');
  final getters = brands.map((brand) {
    final name = brand['name'] as String;
    final configGetter = '  static FlavorConfig get $name => activate(Flavor.$name);';
    if (name == 'vantage') return configGetter;
    return '''  static bool is${_brandClassName(name)}() => _instance?.flavor == Flavor.$name;
$configGetter''';
  }).join('\n\n');

  final content = '''// GENERATED — Do not edit manually. Regenerate from brands.yaml.
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

  static FlavorConfig get instance => _instance ?? activate(Flavor.$defaultBrand);

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
      orElse: () => Flavor.$defaultBrand,
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
    final name = (_instance?.flavor.name ?? Flavor.$defaultBrand.name).toLowerCase();
    return const {'vantage', 'celestial', 'pipze'}.contains(name);
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
    if (hex.length == 6) hex = 'FF\$hex';
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
''';

  File('lib/flavor_config.dart').writeAsStringSync(content);
  print('  Updated: lib/flavor_config.dart');
}

Future<void> generateAndroidFlavors(List<Map<String, dynamic>> brands) async {
  print('\n4. Generating android/brand_flavors.gradle...');

  final buffer = StringBuffer();
  buffer.writeln('// GENERATED — Do not edit manually.');
  buffer.writeln('// Regenerate from brands.yaml: dart run scripts/generate_brand_config.dart');
  buffer.writeln();
  buffer.writeln('ext.brandFlavors = [');

  for (final brand in brands) {
    final name = brand['name'] as String;
    final label = brand['label'] as String;
    final android = brand['android'] as Map<String, dynamic>;
    final colors = brand['colors'] as Map<String, dynamic>;
    final appId = android['applicationId'] ?? 'com.$name.app';
    final appName = android['appName'] ?? label;
    final primary = (colors['primary'] as String? ?? '#5F259E').replaceAll('#', '');
    final secondary = (colors['secondary'] as String? ?? '#FFFFFF').replaceAll('#', '');
    final accent = (colors['accent'] as String? ?? '#$primary').replaceAll('#', '');

    buffer.writeln('    [');
    buffer.writeln('        name: "$name",');
    buffer.writeln('        label: "$label",');
    buffer.writeln('        appId: "$appId",');
    buffer.writeln('        appName: "$appName",');
    buffer.writeln('        primary: "#$primary",');
    buffer.writeln('        secondary: "#$secondary",');
    buffer.writeln('        accent: "#$accent",');
    buffer.writeln('        type: "${brand['type']}",');
    if (brand['inheritsFrom'] != null) buffer.writeln('        inheritsFrom: "${brand['inheritsFrom']}",');
    buffer.writeln('    ],');
  }

  buffer.writeln(']');
  buffer.writeln();
  buffer.writeln('// Helper to get flavor by name');
  buffer.writeln('ext.getBrandFlavor = { String name -> brandFlavors.find { it.name == name } }');

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
    final primary = (colors['primary'] as String? ?? '#5F259E').replaceAll('#', '');
    final secondary = (colors['secondary'] as String? ?? '#FFFFFF').replaceAll('#', '');
    final accent = (colors['accent'] as String? ?? '#$primary').replaceAll('#', '');

    final valuesDir = Directory('${resDir.path}/values');
    valuesDir.createSync(recursive: true);
    File('${valuesDir.path}/colors.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary_color">#$primary</color>
    <color name="secondary_color">#$secondary</color>
    <color name="accent_color">#$accent</color>
    <color name="my_splash_color">#$primary</color>
    <color name="ic_launcher_background">#$primary</color>
</resources>
''');

    final manifestPath = '${flavorDir.path}/AndroidManifest.xml';
    if (!File(manifestPath).existsSync()) {
      File(manifestPath).writeAsStringSync(_androidManifestTemplate());
    }

    for (final drawableDir in ['drawable', 'drawable-v21']) {
      final dDir = Directory('${resDir.path}/$drawableDir');
      dDir.createSync(recursive: true);
      File('${dDir.path}/launch_background.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/my_splash_color" />
</layer-list>
''');
    }

    final xmlDir = Directory('${flavorDir.path}/res/xml');
    xmlDir.createSync(recursive: true);
    File('${xmlDir.path}/file_paths.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-path name="external" path="." />
    <external-files-path name="external_files" path="." />
    <cache-path name="cache" path="." />
    <external-cache-path name="external_cache" path="." />
</paths>
''');

    print('  Ready: android/app/src/$name/ (manifest + resources)');
  }
}

String _androidManifestTemplate() => '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
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

Future<void> updateLaunchJson(List<Map<String, dynamic>> brands) async {
  print('\n6. Updating .vscode/launch.json...');

  final configs = <Map<String, dynamic>>[];
  for (final brand in brands) {
    final name = brand['name'] as String;
    final label = brand['label'] as String;
    for (final mode in ['debug', 'profile', 'release']) {
      final args = ['--flavor', name, '--dart-define=CLIENT=$name', '--dart-define=FLAVOR=$name'];
      if (mode == 'debug') args.add('--no-enable-impeller');
      configs.add({
        'name': '${_getIconEmoji(name, brands.indexOf(brand))} $label ($mode)',
        'request': 'launch',
        'type': 'dart',
        'program': 'lib/main.dart',
        'args': args,
        'flutterMode': mode,
        'console': 'terminal',
      });
    }
  }

  Directory('.vscode').createSync(recursive: true);
  File('.vscode/launch.json').writeAsStringSync(_generateLaunchJson(configs));
  print('  Updated: .vscode/launch.json');
  print('  Total configurations: ${configs.length}');
}

String _generateLaunchJson(List<Map<String, dynamic>> configs) {
  final buffer = StringBuffer();
  buffer.writeln('{');
  buffer.writeln('    "version": "0.2.0",');
  buffer.writeln('    "configurations": [');

  for (var i = 0; i < configs.length; i++) {
    final config = configs[i];
    buffer.writeln('        {');
    buffer.writeln('            "name": "${_escapeJson(config['name'] as String)}",');
    buffer.writeln('            "request": "${config['request']}",');
    buffer.writeln('            "type": "${config['type']}",');
    buffer.writeln('            "program": "${config['program']}",');
    buffer.write('            "args": [');
    buffer.write((config['args'] as List<String>).map((a) => '"${_escapeJson(a)}"').join(', '));
    buffer.writeln('],');
    buffer.writeln('            "flutterMode": "${config['flutterMode']}",');
    buffer.writeln('            "console": "${config['console']}"');
    buffer.write('        }');
    if (i < configs.length - 1) buffer.write(',');
    buffer.writeln();
  }

  buffer.writeln('    ]');
  buffer.writeln('}');
  return buffer.toString();
}

String _escapeJson(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

String _getIconEmoji(String name, int index) {
  final emojis = ['🔵', '🟡', '🟢', '🔴', '🟣', '🟠', '🔶', '🩵', '🩷', '🟤'];
  return emojis[index % emojis.length];
}
