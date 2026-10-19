
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

String colorToHex(String color) {
  var hex = color.replaceAll('#', '').replaceAll('0x', '').toUpperCase();
  if (hex.length == 8) return hex.substring(2);
  return hex;
}
String colorWithHash(String color) => '#${colorToHex(color)}';

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

    final brandColors = await loadBrandColors(flavor);
    final inheritance = await loadInheritance(flavor);

    await cleanOtherClientAssets(flavor, allFlavors, inheritance);
    await copyClientAssets(flavor, inheritance);

    await copyGoogleServicesIfPresent(flavor);
    await writeBuildBrandRegistry(flavor, inheritance);
    await updatePubspec(flavor, allFlavors, inheritance);
    await generateNativeSplash(flavor, brandColors: brandColors);
    await prepareAdaptiveForeground(flavor);
    await generateLauncherIcons(flavor);

    // iOS preparation (data-driven from brand.yaml). Keeps iOS in sync so the
    // app can be run directly from Xcode after a single terminal command.
    await prepareIos(flavor, brandColors: brandColors);

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
  // IMPORTANT: Do not read the scoped runtime registry first.
  // prepare_flavor.dart intentionally rewrites assets/config/brands/brands.json
  // to contain ONLY the active build flavor. If we read it first, switching
  // Pipze -> Skyriss/Celestial later fails with "Unknown flavor".
  // The source of truth for all available flavors is assets/brands/*/brand.yaml.
  final brandRoot = Directory(path.join('assets', 'brands'));
  if (await brandRoot.exists()) {
    final names = <String>[];
    await for (final entity in brandRoot.list()) {
      if (entity is! Directory) continue;
      final brandYaml = File(path.join(entity.path, 'brand.yaml'));
      if (!await brandYaml.exists()) continue;

      final name = await readBrandNameFromYaml(brandYaml);
      if (name.isNotEmpty) names.add(name);
    }

    names.sort();
    if (names.isNotEmpty) return names;
  }

  final yaml = File('assets/config/brands/brands.yaml');
  if (!await yaml.exists()) {
    throw Exception('Brand registry not found: assets/brands/*/brand.yaml or assets/config/brands/brands.yaml');
  }

  final names = <String>[];
  for (final line in (await yaml.readAsString()).split('\n')) {
    final match = RegExp(r'^\s*-\s*name:\s*(\S+)\s*$').firstMatch(line);
    if (match != null) names.add(match.group(1)!.trim().toLowerCase());
  }
  return names;
}

Future<String> readBrandNameFromYaml(File brandYaml) async {
  for (final line in (await brandYaml.readAsString()).split('\n')) {
    final match = RegExp(r'^\s*name:\s*(\S+)\s*$').firstMatch(line);
    if (match != null) {
      return match.group(1)!.replaceAll('"', '').replaceAll("'", '').trim().toLowerCase();
    }
  }
  return '';
}

Future<Map<String, String>> loadBrandColors(String flavor) async {
  final brandYaml = File(path.join('assets', 'brands', flavor, 'brand.yaml'));
  if (await brandYaml.exists()) {
    final colors = <String, String>{};
    var inColors = false;
    for (final line in (await brandYaml.readAsString()).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed == 'colors:') {
        inColors = true;
        continue;
      }
      if (inColors && RegExp(r'^[A-Za-z_][A-Za-z0-9_]*:\s*$').hasMatch(trimmed)) {
        break;
      }
      if (!inColors) continue;
      final match = RegExp(r'^([^:#]+):\s*(.*)$').firstMatch(trimmed);
      if (match == null) continue;
      final key = match.group(1)!.trim();
      final value = match.group(2)!.trim().replaceAll('"', '').replaceAll("'", '');
      if (key.isNotEmpty && value.isNotEmpty) colors[key] = value;
    }
    if (colors.isNotEmpty) return colors;
  }

  final generated = File('assets/config/brands/brands.json');
  if (await generated.exists()) {
    final decoded = jsonDecode(await generated.readAsString());
    final details = decoded is Map ? decoded['brandDetails'] : null;
    if (details is List) {
      for (final item in details) {
        if (item is Map && item['name']?.toString().toLowerCase() == flavor) {
          final colors = item['colors'];
          if (colors is Map) {
            return colors.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            );
          }
        }
      }
    }
  }

  return <String, String>{};
}

String brandColorValue(
  Map<String, String> colors,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = colors[key]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return fallback;
}

/// Reads the parent brand chain for [flavor] from its `brand.yaml`.
/// Returns an ordered list including the active flavor and all ancestors
/// (active first, root parent last). Empty list if the flavor is a parent.
Future<List<String>> loadInheritance(String flavor) async {
  final chain = <String>[flavor];
  final brandYaml = File(path.join('assets', 'brands', flavor, 'brand.yaml'));
  if (!await brandYaml.exists()) return chain;

  String? inheritsFrom;
  bool isChild = false;
  for (final line in (await brandYaml.readAsString()).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (trimmed.startsWith('type:')) {
      isChild = _yamlValue(trimmed).toLowerCase() == 'child';
    } else if (trimmed.startsWith('inheritsFrom:')) {
      inheritsFrom = _yamlValue(trimmed).toLowerCase();
      if (inheritsFrom.isEmpty) inheritsFrom = null;
    }
  }

  if (!isChild || inheritsFrom == null) return chain;

  // Resolve recursively — but cap depth to avoid cycles.
  const maxDepth = 5;
  var depth = 0;
  String? current = inheritsFrom;
  while (current != null && depth < maxDepth) {
    final name = current; // capture for non-null use
    chain.add(name);
    final parentYaml = File(path.join('assets', 'brands', name, 'brand.yaml'));
    if (!await parentYaml.exists()) break;
    current = null;
    for (final line in (await parentYaml.readAsString()).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('inheritsFrom:')) {
        final next = _yamlValue(trimmed).toLowerCase();
        if (next.isNotEmpty) current = next;
        break;
      }
    }
    depth++;
  }
  return chain;
}

Future<void> cleanOtherClientAssets(
  String currentFlavor,
  List<String> allFlavors,
  List<String> inheritance,
) async {
  print('🧹 Cleaning other client assets...');

  // Preserve the active flavor AND every ancestor (parent) it inherits from —
  // child flavors resolve UI/screens through their parent chain at runtime.
  final keep = inheritance.toSet();

  final clientsDir = Directory('assets/clients');
  if (await clientsDir.exists()) {
    await for (final entity in clientsDir.list()) {
      if (entity is Directory) {
        final folderName = path.basename(entity.path).toLowerCase();
        if (folderName != currentFlavor &&
            !keep.contains(folderName) &&
            allFlavors.contains(folderName)) {
          await entity.delete(recursive: true);
          print('  ✓ Removed: assets/clients/$folderName/');
        }
      }
    }
  } else {
    await clientsDir.create(recursive: true);
  }

  print('  ✓ Cleanup complete - keeping: ${keep.join(', ')}');
}

/// Copy editable source assets from assets/brands/{flavor}/ to prepared runtime assets/clients/{flavor}/.
///
/// For child flavors, also copies the ancestor chain (parent → grandparent → ...)
/// so the BrandResolver can load app_config.json + icons at runtime.
Future<void> copyClientAssets(
  String flavor,
  List<String> inheritance,
) async {
  print('📂 Copying client assets...');

  for (final name in inheritance) {
    final sourceDir = Directory(path.join('assets', 'brands', name));
    final targetDir = Directory(path.join('assets', 'clients', name));

    if (!await sourceDir.exists()) {
      if (name == flavor) {
        throw Exception(
          'Brand source assets directory not found: ${sourceDir.path}',
        );
      }
      // Ancestor chain is optional in single-tenant builds — log and skip.
      print('  ⚠️  Ancestor assets missing for $name (skipping)');
      continue;
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
        print('  ✓ [$name] Copied: $relativePath');
      }
    }
  }
}

// No longer copying app_config.json as it is removed.

Future<void> copyGoogleServicesIfPresent(String flavor) async {
  print('\n🔥 Preparing Firebase config...');

  final targetFile = File(path.join('android', 'app', 'src', flavor, 'google-services.json'));
  File? sourceFile;
  
  final brandDir = Directory(path.join('assets', 'brands', flavor));
  if (await brandDir.exists()) {
    await for (final entity in brandDir.list()) {
      if (entity is File && path.basename(entity.path).startsWith('google-services') && path.basename(entity.path).endsWith('.json')) {
        sourceFile = entity;
        break;
      }
    }
  }

  if (sourceFile == null || !await sourceFile.exists()) {
    if (await targetFile.exists()) {
      await targetFile.delete();
      print('  ✓ Removed stale android/app/src/$flavor/google-services.json');
    } else {
      print('  ℹ️  No google-services configuration found for $flavor');
    }
    return;
  }

  await targetFile.parent.create(recursive: true);
  await sourceFile.copy(targetFile.path);
  print('  ✓ Copied ${path.basename(sourceFile.path)} to android/app/src/$flavor/google-services.json');
}

Future<void> writeBuildBrandRegistry(
  String flavor,
  List<String> inheritance,
) async {
  print('\n🔒 Writing build-scoped brand registry...');

  // Bundle metadata for the active flavor AND every ancestor — the
  // BrandResolver's parent/child resolution requires the parent's
  // brandDetails to be present at runtime, even though we only ship a
  // single flavor in the APK.
  final brandDetails = <Map<String, dynamic>>[];
  for (final name in inheritance) {
    final d = await loadBrandDetailsFromSource(name);
    final isActive = name == flavor;
    final inheritsFrom = isActive && inheritance.length > 1
        ? inheritance[1]
        : null;
    brandDetails.add(<String, dynamic>{
      'name': name,
      'type': isActive
          ? (inheritsFrom != null ? 'child' : 'parent')
          : 'parent',
      if (inheritsFrom != null) 'inheritsFrom': inheritsFrom,
      'label': d['label'] ?? name,
      'themeMode': d['themeMode'] ?? 'both',
    });
  }

  final safeRegistry = <String, dynamic>{
    'default': flavor,
    // BrandRegistry.loadFromAssets() will also merge BrandId.tenax as a
    // safety net, but explicitly listing every kept brand keeps logs clear.
    'brands': inheritance,
    'brandDetails': brandDetails,
  };

  final registryFile = File('assets/config/brands/brands.json');
  await registryFile.parent.create(recursive: true);
  await registryFile.writeAsString('${const JsonEncoder.withIndent('  ').convert(safeRegistry)}\n');
  print('  ✓ brands.json keeps: ${inheritance.join(', ')}');
}

Future<Map<String, String>> loadBrandDetailsFromSource(String flavor) async {
  final brandYaml = File(path.join('assets', 'brands', flavor, 'brand.yaml'));
  final details = <String, String>{};

  if (await brandYaml.exists()) {
    for (final line in (await brandYaml.readAsString()).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('label:')) {
        details['label'] = _yamlValue(trimmed);
      } else if (trimmed.startsWith('themeMode:')) {
        details['themeMode'] = _yamlValue(trimmed).toLowerCase();
      }
    }
  }

  details['label'] ??= flavor;
  details['themeMode'] ??= 'both';
  return details;
}

String _yamlValue(String line) {
  return line
      .split(':')
      .sublist(1)
      .join(':')
      .trim()
      .replaceAll('"', '')
      .replaceAll("'", '');
}

Future<void> updatePubspec(
  String flavor,
  List<String> allFlavors,
  List<String> inheritance,
) async {
  print('\n📝 Updating pubspec.yaml...');

  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) throw Exception('pubspec.yaml not found');

  var content = await pubspecFile.readAsString();

  // Bundle assets/clients/<flavor>/ for every kept brand (active + ancestors)
  // so the parent/child UI resolver can load app_config.json and assets for
  // any brand in the inheritance chain at runtime.
  final clientAssetLines = inheritance
      .map((f) => '    - assets/clients/$f/')
      .join('\n');

  final managedBlock = '''    # GENERATED ACTIVE CLIENT ASSETS - DO NOT EDIT BY HAND
$clientAssetLines
    - assets/config/brands/brands.json
    # END GENERATED ACTIVE CLIENT ASSETS''';

  final managedPattern = RegExp(
    r'    # GENERATED ACTIVE CLIENT ASSETS - DO NOT EDIT BY HAND[\s\S]*?'
    r'    # END GENERATED ACTIVE CLIENT ASSETS\n?',
    multiLine: true,
  );

  if (managedPattern.hasMatch(content)) {
    content = content.replaceAll(managedPattern, '');
  }

  for (final f in allFlavors) {
    content = content.replaceAll(
      RegExp(r'^\s*-\s*assets/clients/' + RegExp.escape(f) + r'/\s*$', multiLine: true),
      '',
    );
  }
  content = content.replaceAll(RegExp(r'^\s*-\s*assets/config/\s*$', multiLine: true), '');
  content = content.replaceAll(RegExp(r'^\s*-\s*assets/config/brands/brands\.json\s*$', multiLine: true), '');
  content = content.replaceAll(RegExp(r'^\s*-\s*assets/config/[^/]+/app_config\.json\s*$', multiLine: true), '');
  content = content.replaceAll(RegExp(r'^\s*-\s*assets/clients/[^/]+/app_config\.json\s*$', multiLine: true), '');
  content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  final assetsIndex = content.indexOf('  assets:');
  if (assetsIndex == -1) throw Exception('Could not find flutter assets section in pubspec.yaml');
  final insertIndex = content.indexOf('\n', assetsIndex) + 1;
  content = content.substring(0, insertIndex) + managedBlock + '\n' + content.substring(insertIndex);
  content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  await pubspecFile.writeAsString(content);
  print('  ✓ Active client assets set to: ${inheritance.join(', ')}');
}

Future<void> generateNativeSplash(
  String flavor, {
  Map<String, String> brandColors = const <String, String>{},
}) async {
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

  final primaryColorHex = '#${colorMatch.group(1)!.substring(2)}';
  final splashColorHex = colorWithHash(
    brandColorValue(brandColors, ['splashColor', 'splash'], primaryColorHex),
  );
  final launcherBackgroundHex = colorWithHash(
    brandColorValue(
      brandColors,
      ['launcherBackground', 'icLauncherBackground', 'adaptiveIconBackground'],
      primaryColorHex,
    ),
  );

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
  final accentColorHex = accentColorMatch != null ? '#${accentColorMatch.group(1)!.substring(2)}' : primaryColorHex;

  final colorsXml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary_color">$primaryColorHex</color>
    <color name="secondary_color">$secondaryColorHex</color>
    <color name="accent_color">$accentColorHex</color>
    <color name="my_splash_color">$splashColorHex</color>
    <color name="ic_launcher_background">$launcherBackgroundHex</color>
</resources>
''';

  await File(path.join(valuesDir.path, 'colors.xml')).writeAsString(colorsXml);

  print('  ✓ Created launch_background.xml');
  print('  ✓ Created colors.xml');
  print('  ✓ Splash color: $splashColorHex');
  print('  ✓ Launcher background color: $launcherBackgroundHex');
}

/// Builds a 1024x1024 transparent PNG with the brand icon centered and
/// scaled to fit inside the Android adaptive-icon safe zone (~66%).
/// The adaptive icon foreground MUST respect this safe zone; without it,
/// launchers mask + crop full-bleed logos so the brand mark looks tiny
/// or invisible. Output: assets/clients/<flavor>/ic_adaptive_foreground.png
Future<void> prepareAdaptiveForeground(String flavor) async {
  print('\n🖼️  Preparing adaptive-icon foreground (safe-zone padded)...');

  final sourceIcon = File(path.join('assets', 'clients', flavor, 'icon.png'));
  if (!await sourceIcon.exists()) {
    print('  ⚠️  No icon.png for $flavor, skipping foreground prep');
    return;
  }

  final foregroundPath = path.join(
    'assets', 'clients', flavor, 'ic_adaptive_foreground.png',
  );

  // Output canvas is 1024x1024. Source is scaled to 66% (safe-zone diameter)
  // and centered. The remaining 17% margin on each side guarantees the logo
  // survives any launcher mask (circle, squircle, teardrop).
  const canvasSize = 1024;
  const targetSize = 676; // ~66% of canvas

  final sourceBytes = await sourceIcon.readAsBytes();
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    print('  ⚠️  Failed to decode ${sourceIcon.path}, skipping');
    return;
  }

  final keyed = removeIconBackground(decoded);

  final resized = img.copyResize(
    keyed,
    width: targetSize,
    height: targetSize,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  // Fill with fully-transparent pixels (default for Image() with alpha).
  final offsetX = (canvasSize - targetSize) ~/ 2;
  final offsetY = (canvasSize - targetSize) ~/ 2;
  img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);

  final outFile = File(foregroundPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsBytes(img.encodePng(canvas));
  print('  ✓ Wrote $foregroundPath (${targetSize}x$targetSize centered)');

  // Point the generated launcher_icons.yaml at the padded foreground so
  // flutter_launcher_icons uses it instead of the full-bleed source.
  await rewriteLauncherForeground(flavor, foregroundPath);
}

/// Full-bleed brand icons (e.g. a logo on a solid green square) carry their own
/// opaque background. Composited as the adaptive foreground, that square shows
/// up as a visible box/border on the Android 12+ splash and launcher, because
/// its colour never exactly matches ic_launcher_background / my_splash_color.
/// Flood-fills from the image edges and makes every pixel close to the corner
/// colour transparent, so only the logo mark remains. No-op for icons whose
/// corners are already transparent.
img.Image removeIconBackground(img.Image source) {
  final image = source.convert(numChannels: 4);
  final width = image.width;
  final height = image.height;
  final corner = image.getPixel(0, 0);
  if (corner.a < 255) return image;

  const tolerance = 40;
  final bgR = corner.r.toInt();
  final bgG = corner.g.toInt();
  final bgB = corner.b.toInt();

  bool isBackground(int x, int y) {
    final pixel = image.getPixel(x, y);
    if (pixel.a == 0) return false;
    return (pixel.r.toInt() - bgR).abs() <= tolerance &&
        (pixel.g.toInt() - bgG).abs() <= tolerance &&
        (pixel.b.toInt() - bgB).abs() <= tolerance;
  }

  final queue = <int>[];
  void enqueue(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    if (!isBackground(x, y)) return;
    image.setPixelRgba(x, y, 0, 0, 0, 0);
    queue.add(y * width + x);
  }

  for (var x = 0; x < width; x++) {
    enqueue(x, 0);
    enqueue(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    enqueue(0, y);
    enqueue(width - 1, y);
  }

  while (queue.isNotEmpty) {
    final index = queue.removeLast();
    final x = index % width;
    final y = index ~/ width;
    enqueue(x + 1, y);
    enqueue(x - 1, y);
    enqueue(x, y + 1);
    enqueue(x, y - 1);
  }

  print('  ✓ Removed opaque icon background (rgb $bgR,$bgG,$bgB) from foreground');
  return image;
}

/// Rewrites lib/clients/<flavor>/launcher_icons.yaml so adaptive_icon_foreground
/// points at the padded foreground PNG (relative to project root).
Future<void> rewriteLauncherForeground(String flavor, String foregroundPath) async {
  final yamlFile = File(path.join('lib', 'clients', flavor, 'launcher_icons.yaml'));
  if (!await yamlFile.exists()) return;

  var content = await yamlFile.readAsString();
  final relPath = foregroundPath; // already project-root relative
  content = content.replaceAllMapped(
    RegExp(r'^(\s*adaptive_icon_foreground:\s*).*$', multiLine: true),
    (m) => '${m.group(1)}"$relPath"',
  );
  await yamlFile.writeAsString(content);
  print('  ✓ Updated adaptive_icon_foreground in ${yamlFile.path}');
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
    await removeAdaptiveIconInset(flavor);
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

/// flutter_launcher_icons 0.14.x wraps the adaptive-icon foreground in
/// `<inset android:inset="16%"/>`. Because prepareAdaptiveForeground already
/// scales the logo to the adaptive-icon safe zone (66%), the extra inset
/// shrinks the logo a second time. Point the foreground straight at the
/// drawable instead.
///
/// It must be a plain `android:drawable` reference, not
/// `<bitmap android:gravity="center">`: a gravity bitmap is drawn at its raw
/// pixel size and never scaled to the layer bounds, so on launchers that
/// render the adaptive layer at a different size the logo overflowed the
/// safe zone and filled the circle edge to edge.
Future<void> removeAdaptiveIconInset(String flavor) async {
  final anydpiDir = Directory(
    path.join('android', 'app', 'src', flavor, 'res', 'mipmap-anydpi-v26'),
  );
  final xml = File(path.join(anydpiDir.path, 'ic_launcher.xml'));
  if (!await xml.exists()) return;

  var content = await xml.readAsString();
  final before = content;
  content = content.replaceAll(
    RegExp(
      r'<foreground>\s*(?:<inset\s+android:drawable="@drawable/ic_launcher_foreground"\s+android:inset="16%"\s*/>'
      r'|<bitmap\s+android:src="@drawable/ic_launcher_foreground"\s+android:gravity="center"\s*/>)\s*</foreground>',
    ),
    '<foreground android:drawable="@drawable/ic_launcher_foreground"/>',
  );
  if (content != before) {
    await xml.writeAsString(content);
    print('  ✓ Adaptive icon foreground now scales with the layer (no inset)');
  }
}

// ===========================================================================
// iOS preparation (data-driven from assets/brands/<flavor>/brand.yaml).
// No flavor name is ever hardcoded here — every value is read from brand.yaml
// so that any current or future flavor works with a single prepare command.
// ===========================================================================

Future<void> prepareIos(
  String flavor, {
  Map<String, String> brandColors = const <String, String>{},
}) async {
  print('\n🍎 Preparing iOS for $flavor...');

  final iosMeta = await loadIosMeta(flavor);
  await generateBrandXcconfig(flavor, iosMeta);
  await wireXcconfigIncludes();
  await generateIosLauncherIcons(flavor);
  await writeIosSplashColor(flavor, brandColors: brandColors);
  await copyIosGoogleServicesIfPresent(flavor);

  print('  ✓ iOS prepared. Open ios/Runner.xcworkspace in Xcode and Run.');
}

/// Reads `ios.bundleId` and `ios.appName` from the brand.yaml. Falls back to
/// `com.<flavor>.app` and the brand `label` (or flavor) when absent.
Future<Map<String, String>> loadIosMeta(String flavor) async {
  final meta = <String, String>{
    'bundleId': 'com.$flavor.app',
    'appName': flavor,
  };

  final brandYaml = File(path.join('assets', 'brands', flavor, 'brand.yaml'));
  if (!await brandYaml.exists()) return meta;

  var inIos = false;
  String? label;
  for (final line in (await brandYaml.readAsString()).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    if (trimmed.startsWith('label:')) {
      label = _yamlValue(trimmed);
      continue;
    }

    if (trimmed == 'ios:') {
      inIos = true;
      continue;
    }
    // A new top-level (non-indented) section ends the ios block.
    if (inIos && RegExp(r'^[A-Za-z_][A-Za-z0-9_]*:\s*$').hasMatch(trimmed)) {
      inIos = false;
    }
    if (!inIos) continue;

    if (trimmed.startsWith('bundleId:')) {
      final value = _yamlValue(trimmed);
      if (value.isNotEmpty) meta['bundleId'] = value;
    } else if (trimmed.startsWith('appName:')) {
      final value = _yamlValue(trimmed);
      if (value.isNotEmpty) meta['appName'] = value;
    }
  }

  if (meta['appName'] == flavor && label != null && label.isNotEmpty) {
    meta['appName'] = label;
  }
  return meta;
}

/// Writes ios/Flutter/Brand.xcconfig with the active flavor's bundle id,
/// display name, dart-defines (so Xcode-direct runs select the right flavor),
/// and the Flutter target. Overwritten on every prepare run.
Future<void> generateBrandXcconfig(String flavor, Map<String, String> iosMeta) async {
  final bundleId = iosMeta['bundleId'] ?? 'com.$flavor.app';
  final displayName = iosMeta['appName'] ?? flavor;

  final dartDefines = <String>[
    base64.encode(utf8.encode('CLIENT=$flavor')),
    base64.encode(utf8.encode('FLAVOR=$flavor')),
  ].join(',');

  final content = '''// GENERATED — Do not edit manually. Regenerate with:
//   dart run scripts/prepare_flavor.dart $flavor
// Active flavor: $flavor
PRODUCT_BUNDLE_IDENTIFIER=$bundleId
BRAND_DISPLAY_NAME=$displayName
FLUTTER_TARGET=lib/main.dart
DART_DEFINES=$dartDefines
''';

  final file = File(path.join('ios', 'Flutter', 'Brand.xcconfig'));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  print('  ✓ ios/Flutter/Brand.xcconfig (bundle: $bundleId, name: $displayName)');
}

/// Ensures Debug.xcconfig and Release.xcconfig include Brand.xcconfig.
/// Idempotent: only appends the include line once.
Future<void> wireXcconfigIncludes() async {
  const includeLine = '#include? "Brand.xcconfig"';
  for (final name in ['Debug.xcconfig', 'Release.xcconfig']) {
    final file = File(path.join('ios', 'Flutter', name));
    if (!await file.exists()) {
      print('  ⚠️  $name not found, skipping include wiring');
      continue;
    }
    var content = await file.readAsString();
    if (content.contains(includeLine)) continue;
    if (!content.endsWith('\n')) content += '\n';
    content += '$includeLine\n';
    await file.writeAsString(content);
    print('  ✓ Wired Brand.xcconfig into $name');
  }
}

/// Generates iOS app icons from lib/clients/<flavor>/launcher_icons.yaml
/// (which already has `ios: true`), overwriting AppIcon.appiconset.
Future<void> generateIosLauncherIcons(String flavor) async {
  final configFile = File(path.join('lib', 'clients', flavor, 'launcher_icons.yaml'));
  if (!await configFile.exists()) {
    print('  ⚠️  Launcher icons config not found, skipping iOS icon generation');
    return;
  }

  print('  ⏳ Generating iOS app icons...');
  final result = await Process.run('dart', [
    'run',
    'flutter_launcher_icons',
    '-f',
    configFile.path,
  ], workingDirectory: Directory.current.path);

  if (result.exitCode == 0) {
    print('  ✓ iOS app icons generated (AppIcon.appiconset)');
  } else {
    print('  ⚠️  iOS icon generation failed');
    print('  Error: ${result.stderr}');
  }
}

/// Writes the iOS launch-screen background color (appColor.colorset) from the
/// brand splash/primary color so the native launch screen matches the brand.
Future<void> writeIosSplashColor(
  String flavor, {
  Map<String, String> brandColors = const <String, String>{},
}) async {
  final colorSet = File(path.join(
    'ios', 'Runner', 'Assets.xcassets', 'appColor.colorset', 'Contents.json',
  ));
  if (!await colorSet.parent.exists()) {
    print('  ⚠️  appColor.colorset not found, skipping iOS splash color');
    return;
  }

  final hex = colorToHex(
    brandColorValue(
      brandColors,
      ['splashColor', 'splash', 'primary'],
      '#5F259E',
    ),
  );
  final r = (int.parse(hex.substring(0, 2), radix: 16) / 255).toStringAsFixed(3);
  final g = (int.parse(hex.substring(2, 4), radix: 16) / 255).toStringAsFixed(3);
  final b = (int.parse(hex.substring(4, 6), radix: 16) / 255).toStringAsFixed(3);

  String colorEntry({List<Map<String, String>>? appearances}) {
    final appearanceJson = appearances == null
        ? ''
        : '      "appearances" : [\n        {\n          "appearance" : "luminosity",\n          "value" : "dark"\n        }\n      ],\n';
    return '''    {
$appearanceJson      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "$b",
          "green" : "$g",
          "red" : "$r"
        }
      },
      "idiom" : "universal"
    }''';
  }

  final content = '''{
  "colors" : [
${colorEntry()},
${colorEntry(appearances: const [{}])}
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''';

  await colorSet.writeAsString(content);
  print('  ✓ iOS splash color set to #$hex');
}

/// Copies the iOS Firebase config (GoogleService-Info.plist) from the brand
/// folder into ios/Runner/ if present; removes a stale one otherwise.
Future<void> copyIosGoogleServicesIfPresent(String flavor) async {
  final sourceFile = File(path.join('assets', 'brands', flavor, 'GoogleService-Info.plist'));
  final targetFile = File(path.join('ios', 'Runner', 'GoogleService-Info.plist'));

  if (!await sourceFile.exists()) {
    print('  ℹ️  No GoogleService-Info.plist for $flavor (iOS Firebase optional)');
    return;
  }

  await targetFile.parent.create(recursive: true);
  await sourceFile.copy(targetFile.path);
  print('  ✓ Copied GoogleService-Info.plist to ios/Runner/');
}
