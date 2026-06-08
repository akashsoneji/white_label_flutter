import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Prepares brand-specific assets for Flutter build.
/// Usage: dart run scripts/prepare_flavor.dart {flavor}
/// Example: dart run scripts/prepare_flavor.dart pipze
void main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Error: Please specify a flavor');
    print('Usage: dart run scripts/prepare_flavor.dart {flavor}');
    print('Example: dart run scripts/prepare_flavor.dart pipze');
    exit(1);
  }

  final flavor = args[0].trim().toLowerCase();
  print('🚀 Preparing $flavor flavor...\n');

  try {
    final allFlavors = await loadBrandNames();
    if (!allFlavors.contains(flavor)) {
      throw Exception(
        'Unknown flavor "$flavor". Known flavors: ${allFlavors.join(', ')}',
      );
    }

    await cleanOtherClientAssets(flavor, allFlavors);
    await copyClientAssets(flavor);
    await updatePubspec(flavor, allFlavors);
    await generateNativeSplash(flavor);
    await generateLauncherIcons(flavor);

    print('\n✅ Successfully prepared $flavor flavor!');
    print(
      '📦 You can now build with: flutter build apk --flavor $flavor --dart-define=CLIENT=$flavor --dart-define=FLAVOR=$flavor',
    );
  } catch (e) {
    print('\n❌ Error preparing flavor: $e');
    exit(1);
  }
}

Future<List<String>> loadBrandNames() async {
  final generated = File('assets/config/brands/brands.json');
  if (await generated.exists()) {
    final decoded = jsonDecode(await generated.readAsString());
    if (decoded is Map && decoded['brands'] is List) {
      return (decoded['brands'] as List)
          .map((value) => value.toString().trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toList();
    }
  }

  final yaml = File('assets/config/brands/brands.yaml');
  if (!await yaml.exists()) {
    throw Exception('Brand registry not found: assets/config/brands/brands.json or brands.yaml');
  }

  final names = <String>[];
  for (final line in (await yaml.readAsString()).split('\n')) {
    final match = RegExp(r'^\s*-\s*name:\s*(\S+)\s*$').firstMatch(line);
    if (match != null) names.add(match.group(1)!.trim().toLowerCase());
  }
  return names;
}

Future<void> cleanOtherClientAssets(String currentFlavor, List<String> allFlavors) async {
  print('🧹 Cleaning other client assets...');

  final clientsDir = Directory('assets/clients');
  if (await clientsDir.exists()) {
    await for (final entity in clientsDir.list()) {
      if (entity is Directory) {
        final folderName = path.basename(entity.path).toLowerCase();
        if (folderName != currentFlavor && allFlavors.contains(folderName)) {
          await entity.delete(recursive: true);
          print('  ✓ Removed: assets/clients/$folderName/');
        }
      }
    }
  } else {
    await clientsDir.create(recursive: true);
  }

  print('  ✓ Cleanup complete - only $currentFlavor assets will remain after copy');
}

/// Copy editable source assets from assets/brands/{flavor}/ to prepared runtime assets/clients/{flavor}/.
Future<void> copyClientAssets(String flavor) async {
  print('📂 Copying client assets...');

  final sourceDir = Directory(path.join('assets', 'brands', flavor));
  final targetDir = Directory(path.join('assets', 'clients', flavor));

  if (!await sourceDir.exists()) {
    throw Exception('Brand source assets directory not found: ${sourceDir.path}');
  }

  if (await targetDir.exists()) await targetDir.delete(recursive: true);
  await targetDir.create(recursive: true);

  await for (final entity in sourceDir.list(recursive: true)) {
    if (entity is File && !path.basename(entity.path).startsWith('.')) {
      final relativePath = path.relative(entity.path, from: sourceDir.path);
      final targetPath = path.join(targetDir.path, relativePath);
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      await entity.copy(targetPath);
      print('  ✓ Copied: $relativePath');
    }
  }
}

Future<void> updatePubspec(String flavor, List<String> allFlavors) async {
  print('\n📝 Updating pubspec.yaml...');

  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) throw Exception('pubspec.yaml not found');

  var content = await pubspecFile.readAsString();

  final managedBlock = '''    # GENERATED ACTIVE CLIENT ASSETS - DO NOT EDIT BY HAND
    - assets/clients/$flavor/
    # END GENERATED ACTIVE CLIENT ASSETS''';

  final managedPattern = RegExp(
    r'    # GENERATED ACTIVE CLIENT ASSETS - DO NOT EDIT BY HAND\n'
    r'    - assets/clients/[^\n]+/\n'
    r'    # END GENERATED ACTIVE CLIENT ASSETS',
    multiLine: true,
  );

  if (managedPattern.hasMatch(content)) {
    content = content.replaceFirst(managedPattern, managedBlock);
  } else {
    for (final f in allFlavors) {
      content = content.replaceAll(
        RegExp(r'^\s*-\s*assets/clients/' + RegExp.escape(f) + r'/\s*$', multiLine: true),
        '',
      );
    }
    content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final assetsIndex = content.indexOf('  assets:');
    if (assetsIndex == -1) throw Exception('Could not find flutter assets section in pubspec.yaml');
    final insertIndex = content.indexOf('\n', assetsIndex) + 1;
    content = content.substring(0, insertIndex) + managedBlock + '\n' + content.substring(insertIndex);
  }

  await pubspecFile.writeAsString(content);
  print('  ✓ Active client assets set to assets/clients/$flavor/');
}

Future<void> generateNativeSplash(String flavor) async {
  print('\n🎨 Generating native splash resources...');

  final configFile = File(path.join('lib', 'clients', flavor, 'config.dart'));
  if (!await configFile.exists()) {
    print('  ⚠️  Warning: Client config not found, skipping splash generation');
    return;
  }

  final configContent = await configFile.readAsString();
  final colorMatch = RegExp(
    r'primaryColor:\s*const\s*Color\(0x([A-Fa-f0-9]{8})\)',
  ).firstMatch(configContent);
  if (colorMatch == null) {
    print('  ⚠️  Warning: Could not extract primary color from config');
    return;
  }

  final colorHex = '#${colorMatch.group(1)!.substring(2)}';

  final drawableDir = Directory(path.join('android', 'app', 'src', flavor, 'res', 'drawable'));
  final drawableV21Dir = Directory(path.join('android', 'app', 'src', flavor, 'res', 'drawable-v21'));
  await drawableDir.create(recursive: true);
  await drawableV21Dir.create(recursive: true);

  final launchBackgroundXml = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/my_splash_color" />
</layer-list>
''';

  await File(path.join(drawableDir.path, 'launch_background.xml')).writeAsString(launchBackgroundXml);
  await File(path.join(drawableV21Dir.path, 'launch_background.xml')).writeAsString(launchBackgroundXml);

  final valuesDir = Directory(path.join('android', 'app', 'src', flavor, 'res', 'values'));
  await valuesDir.create(recursive: true);

  final secondaryColorMatch = RegExp(
    r'secondaryColor:\s*const\s*Color\(0x([A-Fa-f0-9]{8})\)',
  ).firstMatch(configContent);
  final accentColorMatch = RegExp(
    r'accentColor:\s*const\s*Color\(0x([A-Fa-f0-9]{8})\)',
  ).firstMatch(configContent);

  final secondaryColorHex = secondaryColorMatch != null ? '#${secondaryColorMatch.group(1)!.substring(2)}' : '#FFFFFF';
  final accentColorHex = accentColorMatch != null ? '#${accentColorMatch.group(1)!.substring(2)}' : colorHex;

  final colorsXml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary_color">$colorHex</color>
    <color name="secondary_color">$secondaryColorHex</color>
    <color name="accent_color">$accentColorHex</color>
    <color name="my_splash_color">${flavor == 'sr' ? '#FFFFFF' : colorHex}</color>
    <color name="ic_launcher_background">$colorHex</color>
</resources>
''';

  await File(path.join(valuesDir.path, 'colors.xml')).writeAsString(colorsXml);

  print('  ✓ Created launch_background.xml');
  print('  ✓ Created colors.xml');
  print('  ✓ Splash color: $colorHex');
}

Future<void> generateLauncherIcons(String flavor) async {
  print('\n🎨 Generating launcher icons...');

  final configFile = File(path.join('lib', 'clients', flavor, 'launcher_icons.yaml'));
  if (!await configFile.exists()) {
    print('  ⚠️  Warning: Launcher icons config not found, skipping icon generation');
    return;
  }

  print('  ⏳ Running dart run flutter_launcher_icons...');
  final result = await Process.run('dart', [
    'run',
    'flutter_launcher_icons',
    '-f',
    configFile.path,
  ], workingDirectory: Directory.current.path);

  if (result.exitCode == 0) {
    print('  ✓ Launcher icons generated successfully');
    await copyIconsToFlavorFolder(flavor);
    await cleanMainResMipmapFolders();
  } else {
    print('  ⚠️  Warning: Launcher icon generation failed');
    print('  Error: ${result.stderr}');
  }
}

Future<void> cleanMainResMipmapFolders() async {
  print('  🧹 Cleaning temporary files from main/res...');

  final mainResDir = Directory(path.join('android', 'app', 'src', 'main', 'res'));
  if (!await mainResDir.exists()) return;

  await for (final entity in mainResDir.list()) {
    if (entity is Directory && path.basename(entity.path).contains('mipmap')) {
      await entity.delete(recursive: true);
      print('    ✓ Removed: ${path.basename(entity.path)}');
    }
  }

  await for (final entity in mainResDir.list()) {
    if (entity is Directory && path.basename(entity.path).contains('drawable-')) {
      var hasLauncherFiles = false;
      await for (final file in entity.list()) {
        if (file is File && path.basename(file.path).contains('ic_launcher')) {
          hasLauncherFiles = true;
          await file.delete();
        }
      }
      if (hasLauncherFiles) print('    ✓ Removed ic_launcher files from: ${path.basename(entity.path)}');
    }
  }

  print('  ✓ Cleanup complete');
}

Future<void> copyIconsToFlavorFolder(String flavor) async {
  print('  📋 Copying icons to $flavor flavor folder...');

  final mainResDir = Directory(path.join('android', 'app', 'src', 'main', 'res'));
  final flavorResDir = Directory(path.join('android', 'app', 'src', flavor, 'res'));

  if (!await mainResDir.exists()) {
    print('  ⚠️  Warning: main/res directory not found');
    return;
  }

  await flavorResDir.create(recursive: true);

  await for (final entity in mainResDir.list()) {
    if (entity is Directory && path.basename(entity.path).contains('mipmap')) {
      final mipmapName = path.basename(entity.path);
      final flavorMipmapDir = Directory(path.join(flavorResDir.path, mipmapName));
      await flavorMipmapDir.create(recursive: true);

      await for (final file in entity.list()) {
        if (file is File && path.basename(file.path).contains('ic_launcher')) {
          final fileName = path.basename(file.path);
          await file.copy(path.join(flavorMipmapDir.path, fileName));
          print('    ✓ Copied: $mipmapName/$fileName');
        }
      }
    }
  }

  final anydpiDir = Directory(path.join('android', 'app', 'src', 'main', 'res', 'mipmap-anydpi-v26'));
  if (await anydpiDir.exists()) {
    final flavorAnydpiDir = Directory(path.join(flavorResDir.path, 'mipmap-anydpi-v26'));
    await flavorAnydpiDir.create(recursive: true);
    final launcherXml = File(path.join(anydpiDir.path, 'ic_launcher.xml'));
    if (await launcherXml.exists()) {
      await launcherXml.copy(path.join(flavorAnydpiDir.path, 'ic_launcher.xml'));
      print('    ✓ Copied: mipmap-anydpi-v26/ic_launcher.xml');
    }
  }

  await for (final entity in mainResDir.list()) {
    if (entity is Directory && path.basename(entity.path).contains('drawable-')) {
      final drawableName = path.basename(entity.path);
      final flavorDrawableDir = Directory(path.join(flavorResDir.path, drawableName));
      await flavorDrawableDir.create(recursive: true);

      await for (final file in entity.list()) {
        if (file is File && path.basename(file.path).contains('ic_launcher')) {
          final fileName = path.basename(file.path);
          await file.copy(path.join(flavorDrawableDir.path, fileName));
          print('    ✓ Copied: $drawableName/$fileName');
        }
      }
    }
  }

  print('  ✓ Icons copied to $flavor flavor folder');
}
