#!/usr/bin/env dart
//
// scripts/add_flavor.dart
//
// One-shot scaffolding for a new brand (parent or child).
//
// Given a brand name, parent (if child), label, colors, and URLs, this script
// writes `assets/brands/<name>/brand.yaml`, creates placeholder assets, then
// shells out to `scripts/generate_brand_config.dart` to regenerate every
// downstream artifact (lib/clients/<name>/config.dart, flavor_config.dart,
// android/brand_flavors.gradle, .vscode/launch.json, .vscode/tasks.json,
// brands.json, AndroidManifest.xml, etc.).
//
// The ONLY thing this script does manually that the generator doesn't is
// patch lib/app/ui_registry.dart → `_uiParentByClient` so the runtime picks
// the right UI tree (Vantage 4-tab / Celestial 5-tab) for the new brand.
//
// USAGE
//   # Interactive (asks for each value):
//   dart run scripts/add_flavor.dart
//
//   # Non-interactive (all flags):
//   dart run scripts/add_flavor.dart \
//     --name acme \
//     --type child \
//     --parent vantage \
//     --label "Acme Trading" \
//     --primary "#1B5E20" \
//     --secondary "#A5D6A7" \
//     --accent "#FFB300" \
//     --api "https://api.acme.io/api/" \
//     --websocket "wss://api.acme.io/trade-engine" \
//     --chart "https://api.acme.io" \
//     --applicationId "com.acme.app" \
//     --appName "Acme"
//
//   # Dry run (no files written, just print plan):
//   dart run scripts/add_flavor.dart --name acme --type child --parent vantage --dry-run
//
// After this script finishes, the brand is fully runnable:
//   - VSCode: pick "🟢 Acme (debug)" from the Run & Debug panel
//   - CLI:    ./build.sh acme apk release
//             flutter build apk --flavor acme -t lib/main.dart \
//               --dart-define=CLIENT=acme --dart-define=FLAVOR=acme
//
// 📘 Full guide with all flags, examples, troubleshooting, and architecture
//    diagrams: docs/ADD_FLAVOR.md
// 🔎 Inline help:     dart run scripts/add_flavor.dart --help
//

import 'dart:io';

const String brandRoot = 'assets/brands';
const String clientRoot = 'lib/clients';
const String androidSrc = 'android/app/src';
const String uiRegistryPath = 'lib/app/ui_registry.dart';
const String generatorScript = 'scripts/generate_brand_config.dart';

// ── Arg parsing ──────────────────────────────────────────────────────────────
class Args {
  String? name;
  String? type; // 'parent' or 'child'
  String? parent; // required if type=child
  String? label;
  String? primary;
  String? secondary;
  String? accent;
  String? splashColor;
  String? launcherBackground;
  String? api;
  String? websocket;
  String? chart;
  String? applicationId;
  String? appName;
  String? iconPath; // optional — defaults to parent's icon.png
  String? themeMode; // 'light' | 'dark' | 'both' (default 'both')
  bool dryRun = false;
  bool help = false;
}

void printUsage() {
  print('''
add_flavor.dart — Scaffold a new brand (parent or child) in one shot.

USAGE
  dart run scripts/add_flavor.dart [flags]

FLAGS
  --name <id>           Brand id (lowercase, no spaces). e.g. "acme"
  --type <parent|child> Whether this brand has its own UI tree
  --parent <id>         Required when --type=child. Must be an existing parent
                        (currently: vantage, celestial)
  --label <string>      Display label (e.g. "Acme Trading"). Defaults to <name>
  --primary <#hex>      Primary color. Required.
  --secondary <#hex>    Secondary color. Defaults to #FFFFFF.
  --accent <#hex>       Accent color. Defaults to <primary>.
  --splashColor <#hex>  Splash background. Defaults to <primary>.
  --launcherBackground <#hex>  Android adaptive icon bg. Defaults to <primary>.
  --api <url>           API base URL. Required.
  --websocket <url>     WebSocket URL. Required.
  --chart <url>         Chart base URL. Required.
  --applicationId <id>  Android applicationId / iOS bundleId. Defaults to com.<name>.app
  --appName <string>    Display app name. Defaults to <label>.
  --iconPath <path>     PNG icon to copy into assets/brands/<name>/icon.png.
                        Defaults to the parent's icon.png.
  --themeMode <mode>    'light' | 'dark' | 'both' (default 'both').
  --dry-run             Print the plan, write nothing.
  --help                Show this help.

EXAMPLES
  # Add a Vantage child (4-tab UI, purple theme):
  dart run scripts/add_flavor.dart \\
    --name acme --type child --parent vantage \\
    --label "Acme Trading" \\
    --primary "#1B5E20" --secondary "#A5D6A7" --accent "#FFB300" \\
    --api "https://api.acme.io/api/" \\
    --websocket "wss://api.acme.io/trade-engine" \\
    --chart "https://api.acme.io"

  # Add a standalone parent (its own 5-tab UI):
  dart run scripts/add_flavor.dart \\
    --name stellar --type parent \\
    --label "Stellar Markets" \\
    --primary "#0D47A1" \\
    --api "https://api.stellar.io/api/" \\
    --websocket "wss://api.stellar.io/trade-engine" \\
    --chart "https://api.stellar.io"

After the script finishes, the new brand is buildable from VSCode
(launch.json has fresh entries) and from the CLI (build.sh / flutter build).
''');
}

Args parseArgs(List<String> raw) {
  final args = Args();
  for (var i = 0; i < raw.length; i++) {
    final arg = raw[i];
    String? next() => i + 1 < raw.length ? raw[++i] : null;
    switch (arg) {
      case '--name':
        args.name = next();
        break;
      case '--type':
        args.type = next();
        break;
      case '--parent':
        args.parent = next();
        break;
      case '--label':
        args.label = next();
        break;
      case '--primary':
        args.primary = next();
        break;
      case '--secondary':
        args.secondary = next();
        break;
      case '--accent':
        args.accent = next();
        break;
      case '--splashColor':
        args.splashColor = next();
        break;
      case '--launcherBackground':
        args.launcherBackground = next();
        break;
      case '--api':
        args.api = next();
        break;
      case '--websocket':
        args.websocket = next();
        break;
      case '--chart':
        args.chart = next();
        break;
      case '--applicationId':
        args.applicationId = next();
        break;
      case '--appName':
        args.appName = next();
        break;
      case '--iconPath':
        args.iconPath = next();
        break;
      case '--themeMode':
        args.themeMode = next();
        break;
      case '--dry-run':
        args.dryRun = true;
        break;
      case '--help':
      case '-h':
        args.help = true;
        break;
      default:
        print('Unknown argument: $arg');
        args.help = true;
    }
  }
  return args;
}

// ── Validation helpers ───────────────────────────────────────────────────────
String normalizeHex(String? input, {required String fallback, String field = ''}) {
  if (input == null || input.trim().isEmpty) return fallback;
  var h = input.trim().toUpperCase().replaceAll('#', '').replaceAll('0X', '');
  if (h.length == 8) h = h.substring(2); // strip alpha
  if (h.length != 6 || !RegExp(r'^[0-9A-F]{6}$').hasMatch(h)) {
    throw FormatException('Invalid hex color "$input" for $field. Use #RRGGBB.');
  }
  return '#$h';
}

String require(String? input, String field) {
  if (input == null || input.trim().isEmpty) {
    throw FormatException('Missing required field: $field');
  }
  return input.trim();
}

bool isValidBrandId(String id) =>
    RegExp(r'^[a-z][a-z0-9_]{0,30}$').hasMatch(id) &&
    !['android', 'ios', 'main', 'debug', 'profile', 'test'].contains(id);

String ensureTrailingSlash(String url) =>
    url.endsWith('/') ? url : '$url/';

// ── Pre-flight checks ───────────────────────────────────────────────────────
Future<List<String>> existingBrandIds() async {
  final dir = Directory(brandRoot);
  if (!await dir.exists()) return <String>[];
  final ids = <String>[];
  for (final entity in dir.listSync().whereType<Directory>()) {
    final yaml = File('${entity.path}/brand.yaml');
    if (!await yaml.exists()) continue;
    final id = entity.path.split(Platform.pathSeparator).last.toLowerCase();
    if (isValidBrandId(id)) ids.add(id);
  }
  return ids;
}

Future<Map<String, String>> readBrandSummary(String id) async {
  final yaml = File('$brandRoot/$id/brand.yaml');
  if (!await yaml.exists()) return {};
  final map = <String, String>{};
  for (final line in await yaml.readAsString().then((s) => s.split('\n'))) {
    final m = RegExp(r'^\s*([a-zA-Z_]+):\s*(.+?)\s*$').firstMatch(line);
    if (m != null) map[m.group(1)!] = m.group(2)!.replaceAll('"', '').replaceAll("'", '').trim();
  }
  return map;
}

// ── File writers ────────────────────────────────────────────────────────────
Future<void> writeBrandYaml(Args args) async {
  final dir = Directory('$brandRoot/${args.name}');
  await dir.create(recursive: true);

  final primary = normalizeHex(args.primary, fallback: '', field: 'primary');
  final secondary = normalizeHex(args.secondary, fallback: '#FFFFFF', field: 'secondary');
  final accent = normalizeHex(args.accent, fallback: primary, field: 'accent');
  final splash = normalizeHex(args.splashColor, fallback: primary, field: 'splashColor');
  final launcherBg = normalizeHex(args.launcherBackground, fallback: primary, field: 'launcherBackground');
  final applicationId = (args.applicationId ?? 'com.${args.name}.app').trim();
  final appName = (args.appName ?? args.label ?? args.name!).trim();
  final label = (args.label ?? args.name!).trim();
  final themeMode = (args.themeMode ?? 'both').trim().toLowerCase();

  final inheritsFromLine = args.type == 'child' ? 'inheritsFrom: ${args.parent}\n' : '';
  final typeLine = 'type: ${args.type}';

  final content = '''name: ${args.name}
$typeLine
${args.type == 'child' ? inheritsFromLine : ''}label: $label
themeMode: $themeMode

android:
  applicationId: "$applicationId"
  appName: "$appName"

ios:
  bundleId: "$applicationId"
  appName: "$appName"

colors:
  primary: "$primary"
  secondary: "$secondary"
  accent: "$accent"
  splashColor: "$splash"
  launcherBackground: "$launcherBg"

urls:
  api: "${ensureTrailingSlash(args.api!)}"
  websocket: "${args.websocket!}"
  chart: "${ensureTrailingSlash(args.chart!)}"

assets:
  appIcon: icon.png
  logo: logo.svg
  splashLogo: splash_logo.svg

features:
  useNewChart: false
''';

  final file = File('$brandRoot/${args.name}/brand.yaml');
  await file.writeAsString(content);
  print('  ✓ Wrote $brandRoot/${args.name}/brand.yaml');
}

Future<void> copyIconFromParent(Args args) async {
  final src = args.iconPath ?? '$brandRoot/${args.parent ?? 'vantage'}/icon.png';
  final dst = '$brandRoot/${args.name}/icon.png';
  if (!await File(src).exists()) {
    print('  ⚠️  Source icon not found: $src — skipping icon copy. Drop your own icon.png into $brandRoot/${args.name}/ before building.');
    return;
  }
  await File(src).copy(dst);
  print('  ✓ Copied icon: $src → $dst');
}

Future<void> writeLogoPlaceholders(Args args) async {
  final srcLogo = '$brandRoot/${args.parent ?? 'vantage'}/logo.svg';
  final dstLogo = '$brandRoot/${args.name}/logo.svg';
  final dstSplash = '$brandRoot/${args.name}/splash_logo.svg';
  if (await File(srcLogo).exists()) {
    await File(srcLogo).copy(dstLogo);
    await File(srcLogo).copy(dstSplash);
    print('  ✓ Copied logo + splash logo from $srcLogo');
  } else {
    // Minimal placeholder SVG (1×1 transparent)
    final placeholder = '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"/>\n';
    await File(dstLogo).writeAsString(placeholder);
    await File(dstSplash).writeAsString(placeholder);
    print('  ✓ Wrote placeholder logo.svg + splash_logo.svg');
  }
}

Future<void> ensureAndroidManifest(Args args) async {
  final dir = Directory('$androidSrc/${args.name}');
  await dir.create(recursive: true);
  final manifest = File('${dir.path}/AndroidManifest.xml');
  if (await manifest.exists()) {
    print('  ✓ AndroidManifest.xml already exists');
    return;
  }
  final content = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
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
  await manifest.writeAsString(content);
  print('  ✓ Wrote $androidSrc/${args.name}/AndroidManifest.xml');
}

Future<void> ensureFilePaths(Args args) async {
  final dir = Directory('$androidSrc/${args.name}/res/xml');
  await dir.create(recursive: true);
  final f = File('${dir.path}/file_paths.xml');
  if (await f.exists()) return;
  await f.writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="files" path="." />
    <cache-path name="cache" path="." />
    <external-files-path name="external_files" path="." />
    <external-cache-path name="external_cache" path="." />
</paths>
''');
  print('  ✓ Wrote $androidSrc/${args.name}/res/xml/file_paths.xml');
}

// ── ui_registry.dart patcher (only thing the generator doesn't do) ──────────
Future<void> patchUiRegistry(Args args) async {
  final file = File(uiRegistryPath);
  if (!await file.exists()) {
    print('  ⚠️  $uiRegistryPath not found — skipping UI registry patch');
    return;
  }
  var content = await file.readAsString();

  // Determine parent for ui_registry mapping.
  // - explicit child → use that parent
  // - parent (standalone) → self
  final registryParent = args.type == 'child' ? args.parent! : args.name!;

  // Skip if already present.
  if (content.contains("'${args.name}': '")) {
    print('  ✓ ui_registry.dart already maps ${args.name}');
    return;
  }

  // Insert into _uiParentByClient map. Find the closing brace of the map
  // and inject the new entry just before it. The map looks like:
  //   static const Map<String, String> _uiParentByClient = {
  //     'vantage': 'vantage',
  //     ...
  //   };
  final mapPattern = RegExp(
    r"static const Map<String, String> _uiParentByClient = \{\s*\n([\s\S]*?)\};",
    multiLine: true,
  );
  final match = mapPattern.firstMatch(content);
  if (match == null) {
    print('  ⚠️  Could not find _uiParentByClient map in $uiRegistryPath');
    return;
  }
  final body = match.group(1)!;
  // Append a new line. Match existing indentation style.
  final newLine = "    '${args.name}': '$registryParent',\n";
  final newBody = body.endsWith('\n') ? '$body$newLine' : '$body\n$newLine';
  content = content.replaceFirst(
    mapPattern,
    "static const Map<String, String> _uiParentByClient = {\n$newBody};",
  );
  await file.writeAsString(content);
  print("  ✓ Patched $uiRegistryPath → '${args.name}' → '$registryParent'");
}

Future<void> runGenerator() async {
  print('\n→ Running scripts/generate_brand_config.dart ...');
  final result = await Process.run(
    'dart',
    ['run', generatorScript],
    workingDirectory: Directory.current.path,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw Exception('generate_brand_config.dart exited ${result.exitCode}');
  }
}

// ── Main ────────────────────────────────────────────────────────────────────
Future<void> main(List<String> raw) async {
  final args = parseArgs(raw);
  if (args.help) {
    printUsage();
    return;
  }

  // Required flags
  try {
    args.name = require(args.name, '--name').toLowerCase();
    args.type = require(args.type, '--type').toLowerCase();
    args.label ??= args.name!;
    args.applicationId ??= 'com.${args.name}.app';
    args.appName ??= args.label!;
    args.themeMode ??= 'both';
    args.api = require(args.api, '--api');
    args.websocket = require(args.websocket, '--websocket');
    args.chart = require(args.chart, '--chart');
    args.primary = require(args.primary, '--primary');
  } on FormatException catch (e) {
    print('❌ ${e.message}');
    printUsage();
    exit(1);
  }

  if (!isValidBrandId(args.name!)) {
    print('❌ Invalid --name "${args.name}". Use lowercase letters/digits/underscore, 1-31 chars, must not collide with reserved words.');
    exit(1);
  }
  if (args.type != 'parent' && args.type != 'child') {
    print('❌ --type must be "parent" or "child"');
    exit(1);
  }
  if (args.type == 'child' && (args.parent == null || args.parent!.isEmpty)) {
    print('❌ --type=child requires --parent');
    exit(1);
  }
  if (!['light', 'dark', 'both'].contains(args.themeMode)) {
    print('❌ --themeMode must be one of: light, dark, both');
    exit(1);
  }

  // Check for duplicate
  final existing = await existingBrandIds();
  if (existing.contains(args.name)) {
    print('❌ Brand "${args.name}" already exists at $brandRoot/${args.name}');
    print('   Use scripts/add_new_brand.sh if you just want to re-scaffold assets,');
    print('   or remove the existing folder first.');
    exit(1);
  }
  if (args.type == 'child' && !existing.contains(args.parent!.toLowerCase())) {
    print('❌ Parent "${args.parent}" does not exist. Available parents:');
    for (final id in existing) {
      final summary = await readBrandSummary(id);
      final t = summary['type'] ?? '?';
      if (t == 'parent') print('   - $id ($t)');
    }
    exit(1);
  }
  if (args.type == 'parent' && existing.contains(args.parent!.toLowerCase())) {
    print('❌ Cannot use --parent for a parent brand (it has no parent).');
    exit(1);
  }

  // Validate hex colors up-front.
  try {
    final primary =
        normalizeHex(args.primary, fallback: '', field: 'primary');
    final secondary =
        normalizeHex(args.secondary, fallback: '#FFFFFF', field: 'secondary');
    final accent =
        normalizeHex(args.accent, fallback: primary, field: 'accent');
    final splash =
        normalizeHex(args.splashColor, fallback: primary, field: 'splashColor');
    final launcher = normalizeHex(args.launcherBackground,
        fallback: primary, field: 'launcherBackground');
    args.primary = primary;
    args.secondary = secondary;
    args.accent = accent;
    args.splashColor = splash;
    args.launcherBackground = launcher;
  } on FormatException catch (e) {
    print('❌ ${e.message}');
    exit(1);
  }

  // Plan
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║  add_flavor.dart — Scaffolding new brand: ${args.name!.padRight(20)}║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');
  print('  Type:           ${args.type}');
  if (args.type == 'child') print('  Parent:         ${args.parent}');
  print('  Label:          ${args.label}');
  print('  App name:       ${args.appName}');
  print('  Application ID: ${args.applicationId}');
  print('  Theme mode:     ${args.themeMode}');
  print('  Primary:        ${args.primary}');
  print('  Secondary:      ${args.secondary}');
  print('  Accent:         ${args.accent}');
  print('  Splash:         ${args.splashColor}');
  print('  Launcher bg:    ${args.launcherBackground}');
  print('  API:            ${args.api}');
  print('  WebSocket:      ${args.websocket}');
  print('  Chart:          ${args.chart}');
  print('');

  if (args.dryRun) {
    print('🛑 DRY-RUN — no files written. Re-run without --dry-run to apply.');
    return;
  }

  // 1. brand.yaml
  print('→ Writing $brandRoot/${args.name}/brand.yaml ...');
  await writeBrandYaml(args);

  // 2. Placeholder assets
  print('→ Copying icon + logo from parent ...');
  await copyIconFromParent(args);
  await writeLogoPlaceholders(args);

  // 3. Android scaffolding
  print('→ Writing AndroidManifest.xml + file_paths.xml ...');
  await ensureAndroidManifest(args);
  await ensureFilePaths(args);

  // 4. ui_registry.dart (only thing generator doesn't do)
  print('→ Patching $uiRegistryPath ...');
  await patchUiRegistry(args);

  // 5. Hand off to the generator for everything else
  await runGenerator();

  print('');
  print('✅ Brand "${args.name}" is fully configured and buildable.');
  print('');
  print('Run from VSCode:');
  print('  • Open the Run & Debug panel, pick the new "${args.name} (debug)" entry, press F5.');
  print('');
  print('Run from CLI:');
  print('  • flutter run --flavor ${args.name} -t lib/main.dart \\');
  print('      --dart-define=CLIENT=${args.name} --dart-define=FLAVOR=${args.name}');
  print('');
  print('Next: drop a real 1024x1024 icon.png at $brandRoot/${args.name}/icon.png and re-run:');
  print('  • dart run scripts/prepare_flavor.dart ${args.name}');
}
