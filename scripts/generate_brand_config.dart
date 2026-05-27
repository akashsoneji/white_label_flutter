#!/usr/bin/env dart
//
// scripts/generate_brand_config.dart
//
// Reads assets/config/brands/brands.yaml and generates:
//   - lib/clients/{brand}/config.dart  (brand config)
//   - assets/config/brands/brands.json  (runtime registry)
//   - android/brand_flavors.gradle     (Android product flavors)
//   - android/app/src/{brand}/         (flavor manifest + resources)
//   - .vscode/launch.json             (VSCode launch configs)
//
// Usage: dart run scripts/generate_brand_config.dart

import 'dart:io';

void main() async {
  print('Brand Config Generator');
  print('======================\n');

  final yamlPath = 'assets/config/brands/brands.yaml';
  if (!File(yamlPath).existsSync()) {
    print('ERROR: $yamlPath not found');
    exit(1);
  }

  final yaml = File(yamlPath).readAsStringSync();
  final brands = parseYaml(yaml);

  if (brands.isEmpty) {
    print('ERROR: No brands found in $yamlPath');
    exit(1);
  }

  print('Found ${brands.length} brand(s): ${brands.map((b) => b['name']).join(', ')}\n');

  // 1. Generate brand config dart files
  await generateBrandConfigs(brands);

  // 2. Generate brands.json
  await generateBrandsJson(brands);

  // 3. Generate Android brand_flavors.gradle
  await generateAndroidFlavors(brands);

  // 4. Create Android flavor directories
  await createAndroidFlavorDirs(brands);

  // 5. Update launch.json
  await updateLaunchJson(brands);

  print('\nBrand config generation complete!');
  print('Run: ./build.sh <brand> apk release');
}

// ─── YAML Parser ─────────────────────────────────────────────────────────────

List<Map<String, dynamic>> parseYaml(String yaml) {
  final brands = <Map<String, dynamic>>[];
  final lines = yaml.split('\n');
  Map<String, dynamic>? currentEntry;
  String currentSection = '';

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    // Strip trailing \r for Windows compatibility
    line = line.replaceAll('\r', '');

    // Skip empty lines and comments
    if (line.trim().isEmpty || line.trim().startsWith('#')) continue;

    if (line.trim().startsWith('brands:')) {
      continue;
    }

    if (line.trim().startsWith('- name:')) {
      if (currentEntry != null) {
        brands.add(currentEntry);
      }
      currentEntry = {
        'name': _extractValue(line),
        'type': 'child', // default
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

    if (line.trim().startsWith('default:')) {
      continue; // handled separately
    }

    if (line.trim().startsWith('type:')) {
      currentEntry['type'] = _extractValue(line);
      currentSection = '';
      continue;
    }

    if (line.trim().startsWith('inheritsFrom:')) {
      final val = _extractValue(line);
      if (val.isNotEmpty) {
        currentEntry['inheritsFrom'] = val;
      }
      currentSection = '';
      continue;
    }

    if (line.trim().startsWith('label:')) {
      currentEntry['label'] = _extractValue(line);
      currentSection = '';
      continue;
    }

    // Top-level sections (android, ios, colors, urls, assets)
    for (final section in ['android', 'ios', 'colors', 'urls', 'assets']) {
      if (line.trim().startsWith('$section:')) {
        currentSection = section;
        break;
      }
    }

    if (currentSection.isEmpty) continue;

    // Parse key-value pairs under sections
    final keyMatch = RegExp(r'^(\s*)([^:#]+):\s*(.*)$').firstMatch(line);
    if (keyMatch != null) {
      final key = keyMatch.group(2)!.trim();
      final value = keyMatch.group(3)!.trim().replaceAll('"', '').replaceAll("'", '');

      if (currentSection == 'android' || currentSection == 'ios') {
        (currentEntry[currentSection] as Map<String, dynamic>)[key] = value;
      } else if (currentSection == 'colors' || currentSection == 'urls' || currentSection == 'assets') {
        (currentEntry[currentSection] as Map<String, dynamic>)[key] = value;
      }
    }
  }

  if (currentEntry != null) {
    brands.add(currentEntry);
  }

  return brands;
}

String _extractValue(String line) {
  return line.split(':').sublist(1).join(':').trim().replaceAll('"', '').replaceAll("'", '');
}

// Extract just the filename from the asset path (BaseClientConfig uses getAssetPath to make full path)
String _assetFilename(String fullPath) {
  if (fullPath.contains('/')) {
    return fullPath.split('/').last;
  }
  return fullPath;
}

String colorToHex(String color) {
  // Input: "#1A4E8A" or "1A4E8A"
  // Output: just the 6-digit hex (RGB). Color(0xFF...) adds alpha.
  var hex = color.replaceAll('#', '').replaceAll('0x', '').toUpperCase();
  if (hex.length == 8 && hex.startsWith('FF')) {
    return hex.substring(2); // Already full-alpha — strip it, let Color() add it
  }
  if (hex.length == 8) {
    return hex.substring(2); // Has non-FF alpha — strip, use RGB only
  }
  return hex; // Already 6-digit RGB
}

// ─── Generate Brand Config Dart Files ─────────────────────────────────────────

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
    final appIcon = assets['appIcon'] ?? 'app_icon.png';
    final logo = assets['logo'] ?? 'logo.svg';
    final splashLogo = assets['splashLogo'] ?? 'splash_logo.svg';

    final content = '''// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import '../base_config.dart';

/// Auto-generated config for "$label".
/// Change values in assets/config/brands/brands.yaml and re-run the generator.
class ${_capitalize(name)}Config extends BaseClientConfig {
  const ${_capitalize(name)}Config()
      : super(
          brandName: '$label',
          appTitle: '$label',
          primaryColor: const Color(0xFF${colorToHex(primary)}),
          secondaryColor: const Color(0xFF${colorToHex(secondary)}),
          accentColor: const Color(0xFF${colorToHex(accent)}),
          logoSvgPath: '${_assetFilename(logo)}',
          splashLogoPath: '${_assetFilename(splashLogo)}',
          appIconPath: '${_assetFilename(appIcon)}',
          apiBaseUrl: '$api',
          websocketUrl: '$websocket',
          chartBaseUrl: '$chart',
        );
}
''';

    // Create lib/clients/{brand}/ directory
    final clientDir = Directory('lib/clients/$name');
    if (!clientDir.existsSync()) {
      clientDir.createSync(recursive: true);
    }

    // Create assets subdirectory
    final assetsDir = Directory('${clientDir.path}/assets');
    if (!assetsDir.existsSync()) {
      assetsDir.createSync(recursive: true);
    }

    // Copy brand assets from assets/brands/{name}/ to lib/clients/{name}/assets/
    final brandAssetsDir = Directory('assets/brands/$name');
    if (brandAssetsDir.existsSync()) {
      await for (final entity in brandAssetsDir.list()) {
        if (entity is File) {
          final targetPath = '${assetsDir.path}/${entity.path.split('/').last}';
          await entity.copy(targetPath);
        }
      }
      print('  Copied assets: assets/brands/$name/ → lib/clients/$name/assets/');
    }

    File('${clientDir.path}/config.dart').writeAsStringSync(content);
    print('  Created: lib/clients/$name/config.dart');
  }
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ─── Generate brands.json ─────────────────────────────────────────────────────

Future<void> generateBrandsJson(List<Map<String, dynamic>> brands) async {
  print('\n2. Generating brands.json...');

  // Read existing brands.json to get the 'default' field
  String defaultBrand = 'tenax';
  final existingFile = File('assets/config/brands/brands.json');
  if (existingFile.existsSync()) {
    try {
      final content = existingFile.readAsStringSync();
      if (content.contains('"default"')) {
        final match = RegExp(r'"default":\s*"([^"]+)"').firstMatch(content);
        if (match != null) defaultBrand = match.group(1)!;
      }
    } catch (_) {}
  }

  // Read brands.yaml for default
  final yamlFile = File('assets/config/brands/brands.yaml');
  if (yamlFile.existsSync()) {
    final yaml = yamlFile.readAsStringSync();
    final match = RegExp(r'default:\s*(\S+)').firstMatch(yaml);
    if (match != null) defaultBrand = match.group(1)!;
  }

  // Generate the simple brands.json for BrandRegistry compatibility
  final simpleList = brands.map((b) => b['name'] as String).toList();

  final json = '''{
  "default": "$defaultBrand",
  "brands": ${_jsonEncodeList(simpleList)}
}
''';

  File('assets/config/brands/brands.json').writeAsStringSync(json);
  print('  Updated: assets/config/brands/brands.json');
  print('  Default brand: $defaultBrand');
}

String _jsonEncodeList(List<String> list) {
  return '[${list.map((s) => '"$s"').join(', ')}]';
}

// ─── Generate Android brand_flavors.gradle ────────────────────────────────────

Future<void> generateAndroidFlavors(List<Map<String, dynamic>> brands) async {
  print('\n3. Generating android/brand_flavors.gradle...');

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
    final appName = android['appName'] ?? name;
    final primary = (colors['primary'] as String? ?? '#5F259E').replaceAll('#', '');
    final secondary = (colors['secondary'] as String? ?? '#FFFFFF').replaceAll('#', '');
    final accent = (colors['accent'] as String? ?? primary).replaceAll('#', '');

    buffer.writeln('    [');
    buffer.writeln('        name: "$name",');
    buffer.writeln('        label: "$label",');
    buffer.writeln('        appId: "$appId",');
    buffer.writeln('        appName: "$appName",');
    buffer.writeln('        primary: "#$primary",');
    buffer.writeln('        secondary: "#$secondary",');
    buffer.writeln('        accent: "#$accent",');
    buffer.writeln('        type: "${brand['type']}",');
    if (brand['inheritsFrom'] != null) {
      buffer.writeln('        inheritsFrom: "${brand['inheritsFrom']}",');
    }
    buffer.writeln('    ],');
  }

  buffer.writeln(']');
  buffer.writeln();
  buffer.writeln('// Helper to get flavor by name');
  buffer.writeln('ext.getBrandFlavor = { String name -> brandFlavors.find { it.name == name } }');

  // Ensure scripts directory exists
  final scriptsDir = Directory('android/scripts');
  if (!scriptsDir.existsSync()) {
    scriptsDir.createSync(recursive: true);
  }

  File('android/brand_flavors.gradle').writeAsStringSync(buffer.toString());
  print('  Created: android/brand_flavors.gradle');
  print('  ${brands.length} flavor(s) defined');
}

// ─── Create Android Flavor Directories ────────────────────────────────────────

Future<void> createAndroidFlavorDirs(List<Map<String, dynamic>> brands) async {
  print('\n4. Creating Android flavor directories...');

  for (final brand in brands) {
    final name = brand['name'] as String;
    final flavorDir = Directory('android/app/src/$name');

    if (flavorDir.existsSync()) {
      print('  Skipping: android/app/src/$name/ (already exists)');
      continue;
    }

    flavorDir.createSync(recursive: true);
    final resDir = Directory('${flavorDir.path}/res');
    resDir.createSync(recursive: true);

    // Create values/colors.xml
    final colors = brand['colors'] as Map<String, dynamic>;
    final primary = (colors['primary'] as String? ?? '#5F259E').replaceAll('#', '');
    final secondary = (colors['secondary'] as String? ?? '#FFFFFF').replaceAll('#', '');
    final accent = (colors['accent'] as String? ?? primary).replaceAll('#', '');

    final colorsXml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary_color">#$primary</color>
    <color name="secondary_color">#$secondary</color>
    <color name="accent_color">#$accent</color>
    <color name="my_splash_color">#$primary</color>
    <color name="ic_launcher_background">#$primary</color>
</resources>
''';

    final valuesDir = Directory('${resDir.path}/values');
    valuesDir.createSync();
    File('${valuesDir.path}/colors.xml').writeAsStringSync(colorsXml);

    final manifestPath = '${flavorDir.path}/AndroidManifest.xml';
    final manifestContent = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
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
        android:roundIcon="@mipmap/ic_launcher_round"
        android:usesCleartextTraffic="true"
        tools:replace="android:label,android:icon,android:roundIcon">

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
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
''';

    File(manifestPath).writeAsStringSync(manifestContent);

    // Create drawable and drawable-v21 for splash
    for (final drawableDir in ['drawable', 'drawable-v21']) {
      final dDir = Directory('${resDir.path}/$drawableDir');
      dDir.createSync();
      final launchBg = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/my_splash_color" />
</layer-list>
''';
      File('${dDir.path}/launch_background.xml').writeAsStringSync(launchBg);
    }

    // Create xml/ directory with file_paths.xml (needed for FileProvider)
    final xmlDir = Directory('${flavorDir.path}/res/xml');
    xmlDir.createSync(recursive: true);
    final filePathsContent = '''<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-path name="external" path="." />
    <external-files-path name="external_files" path="." />
    <cache-path name="cache" path="." />
    <external-cache-path name="external_cache" path="." />
</paths>
''';
    File('${xmlDir.path}/file_paths.xml').writeAsStringSync(filePathsContent);

    print('  Created: android/app/src/$name/ (manifest + resources)');
  }
}

// ─── Update launch.json ───────────────────────────────────────────────────────

Future<void> updateLaunchJson(List<Map<String, dynamic>> brands) async {
  print('\n5. Updating .vscode/launch.json...');

  final launchPath = '.vscode/launch.json';
  File launchFile;

  if (File(launchPath).existsSync()) {
    launchFile = File(launchPath);
  } else {
    // Create minimal launch.json
    launchFile = File(launchPath);
    launchFile.createSync(recursive: true);
    launchFile.writeAsStringSync('''{
    "version": "0.2.0",
    "configurations": []
}
''');
  }

  // Read existing configs
  var existingContent = launchFile.readAsStringSync();
  List<Map<String, dynamic>> existingConfigs = [];

  try {
    // Simple parsing — extract existing configs
    final configsMatch = RegExp(r'"configurations":\s*\[([\s\S]*?)\]').firstMatch(existingContent);
    if (configsMatch != null) {
      final configsStr = configsMatch.group(1)!;
      final configBlocks = _parseConfigBlocks(configsStr);
      for (final block in configBlocks) {
        final config = _parseConfigBlock(block);
        if (config.isNotEmpty) {
          existingConfigs.add(config);
        }
      }
    }
  } catch (e) {
    print('  Warning: Could not parse existing launch.json, will overwrite');
  }

  // Collect existing config names
  final existingNames = existingConfigs.map((c) => c['name'] as String).toSet();

  // Generate new configs for each brand
  int addedCount = 0;
  for (final brand in brands) {
    final name = brand['name'] as String;
    final label = brand['label'] as String;

    for (final mode in ['debug', 'profile', 'release']) {
      final configName = '${_getIconEmoji(name, brands.indexOf(brand))} $label ($mode)';

      if (existingNames.contains(configName)) {
        continue; // Don't duplicate
      }

      final args = [
        '--flavor',
        name,
        '--dart-define=CLIENT=$name',
        '--dart-define=FLAVOR=$name',
      ];

      if (mode == 'debug') {
        args.add('--no-enable-impeller');
      }

      existingConfigs.add({
        'name': configName,
        'request': 'launch',
        'type': 'dart',
        'preLaunchTask': 'Set Android icon ($name)',
        'program': 'lib/main.dart',
        'args': args,
        'flutterMode': mode,
        'console': 'terminal',
      });

      addedCount++;
    }
  }

  // Write back
  final output = _generateLaunchJson(existingConfigs);
  launchFile.writeAsStringSync(output);

  print('  Updated: .vscode/launch.json');
  print('  Total configurations: ${existingConfigs.length} ($addedCount new)');
}

List<String> _parseConfigBlocks(String content) {
  // Split by top-level config blocks (between { ... })
  final blocks = <String>[];
  var depth = 0;
  var current = StringBuffer();
  var inString = false;
  var escaped = false;

  for (var i = 0; i < content.length; i++) {
    final c = content[i];

    if (escaped) {
      current.write(c);
      escaped = false;
      continue;
    }

    if (c == '\\') {
      escaped = true;
      current.write(c);
      continue;
    }

    if (c == '"') {
      inString = !inString;
      current.write(c);
      continue;
    }

    if (inString) {
      current.write(c);
      continue;
    }

    if (c == '{') {
      depth++;
      current.write(c);
    } else if (c == '}') {
      depth--;
      current.write(c);
      if (depth == 0) {
        blocks.add(current.toString());
        current = StringBuffer();
      }
    } else {
      current.write(c);
    }
  }

  return blocks;
}

Map<String, dynamic> _parseConfigBlock(String block) {
  final config = <String, dynamic>{};

  // Extract "name"
  final nameMatch = RegExp(r'"name":\s*"([^"]*)"').firstMatch(block);
  if (nameMatch != null) config['name'] = nameMatch.group(1);

  // Extract "flutterMode"
  final modeMatch = RegExp(r'"flutterMode":\s*"([^"]*)"').firstMatch(block);
  if (modeMatch != null) config['flutterMode'] = modeMatch.group(1);

  // Extract "type"
  final typeMatch = RegExp(r'"type":\s*"([^"]*)"').firstMatch(block);
  if (typeMatch != null) config['type'] = typeMatch.group(1);

  // Extract "request"
  final requestMatch = RegExp(r'"request":\s*"([^"]*)"').firstMatch(block);
  if (requestMatch != null) config['request'] = requestMatch.group(1);

  return config;
}

String _generateLaunchJson(List<Map<String, dynamic>> configs) {
  final buffer = StringBuffer();
  buffer.writeln('{');
  buffer.writeln('    "version": "0.2.0",');
  buffer.writeln('    "configurations": [');

  for (var i = 0; i < configs.length; i++) {
    final config = configs[i];
    buffer.writeln('        {');
    buffer.writeln('            "name": "${_escapeJson(config['name'])}",');
    buffer.writeln('            "request": "${config['request'] ?? 'launch'}",');
    buffer.writeln('            "type": "${config['type'] ?? 'dart'}",');
    buffer.writeln('            "preLaunchTask": "${_escapeJson(config['preLaunchTask'] ?? '')}",');
    buffer.writeln('            "program": "${_escapeJson(config['program'] ?? 'lib/main.dart')}",');

    final args = config['args'] as List<String>?;
    if (args != null && args.isNotEmpty) {
      buffer.write('            "args": [');
      buffer.write(args.map((a) => '"${_escapeJson(a)}"').join(', '));
      buffer.writeln('],');
    } else {
      buffer.writeln('            "args": [],');
    }

    buffer.writeln('            "flutterMode": "${config['flutterMode'] ?? 'debug'}",');
    buffer.writeln('            "console": "${config['console'] ?? 'terminal'}"');
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
  // Cycle through colors for different brands
  final emojis = ['🔵', '🟡', '🟢', '🔴', '🟣', '🟠', '🔶', '🩵', '🩷', '🟤'];
  return emojis[index % emojis.length];
}
