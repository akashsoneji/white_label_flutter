// Shared brand.yaml reader for the deep-link scripts
// (generate_well_known.dart, check_deeplink.dart). Not a CLI entrypoint.
//
// brand.yaml files are read with the same flat, line-based rules the other
// brand scripts use: a non-indented `section:` line opens a section and
// indented `key: value` lines belong to it.

import 'dart:io';

const String brandRootPath = 'assets/brands';

/// Path prefixes the app claims on every deep-link host. Keep in sync with
/// `deepLinkPaths` in scripts/generate_brand_config.dart and the
/// `<data android:pathPrefix>` entries in android/app/src/main/AndroidManifest.xml.
const List<String> deepLinkPaths = [
  '/ref',
  '/register',
  '/reset-password',
  '/verify-email',
  '/app',
];

class DeepLinkBrand {
  final String flavor;
  final String androidPackage;
  final String iosBundleId;
  final String host;
  final String hostAlt;
  final String iosTeamId;
  final String iosAppStoreId;
  final List<String> androidSha256;

  const DeepLinkBrand({
    required this.flavor,
    required this.androidPackage,
    required this.iosBundleId,
    required this.host,
    required this.hostAlt,
    required this.iosTeamId,
    required this.iosAppStoreId,
    required this.androidSha256,
  });

  bool get isEnabled => host.isNotEmpty;

  List<String> get hosts => [host, if (hostAlt.isNotEmpty && hostAlt != host) hostAlt];

  String get iosAppId => '$iosTeamId.$iosBundleId';
}

/// Values that still hold a `<PLACEHOLDER>` from the brand.yaml template.
bool isPlaceholder(String value) =>
    value.trim().isEmpty || value.contains('<') || value.contains('>');

Map<String, Map<String, String>> readBrandSections(File file) {
  final sections = <String, Map<String, String>>{'': <String, String>{}};
  var current = '';
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.replaceAll('\r', '');
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final match = RegExp(r'^([^:#]+):\s*(.*)$').firstMatch(trimmed);
    if (match == null) continue;
    final key = match.group(1)!.trim();
    final value = _unquote(match.group(2)!);
    final indented = line.startsWith(' ') || line.startsWith('\t');

    if (!indented) {
      if (value.isEmpty) {
        current = key;
        sections.putIfAbsent(current, () => <String, String>{});
      } else {
        current = '';
        sections['']![key] = value;
      }
      continue;
    }
    sections.putIfAbsent(current, () => <String, String>{})[key] = value;
  }
  return sections;
}

String _unquote(String value) {
  var v = value.trim();
  final comment = v.indexOf(' #');
  if (comment >= 0 && !v.startsWith('"') && !v.startsWith("'")) {
    v = v.substring(0, comment).trim();
  }
  return v.replaceAll('"', '').replaceAll("'", '').trim();
}

DeepLinkBrand? loadDeepLinkBrand(String flavor) {
  final file = File('$brandRootPath/$flavor/brand.yaml');
  if (!file.existsSync()) return null;
  final sections = readBrandSections(file);
  final name = sections['']!['name'] ?? flavor;
  final deepLink = sections['deepLink'] ?? const <String, String>{};
  final host = deepLink['host'] ?? '';
  return DeepLinkBrand(
    flavor: name,
    androidPackage: sections['android']?['applicationId'] ?? 'com.$name.app',
    iosBundleId: sections['ios']?['bundleId'] ?? 'com.$name.app',
    host: host,
    hostAlt: deepLink['hostAlt'] ?? host,
    iosTeamId: deepLink['iosTeamId'] ?? '',
    iosAppStoreId: deepLink['iosAppStoreId'] ?? '',
    androidSha256: (deepLink['androidSha256'] ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
  );
}

List<DeepLinkBrand> loadAllBrands() {
  final root = Directory(brandRootPath);
  if (!root.existsSync()) return const [];
  final brands = <DeepLinkBrand>[];
  for (final dir in root.listSync().whereType<Directory>()) {
    final flavor = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final brand = loadDeepLinkBrand(flavor);
    if (brand != null) brands.add(brand);
  }
  brands.sort((a, b) => a.flavor.compareTo(b.flavor));
  return brands;
}
