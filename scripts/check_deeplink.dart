#!/usr/bin/env dart
//
// scripts/check_deeplink.dart
//
// Deep-link doctor. Checks that a flavor's brand.yaml `deepLink` block has
// reached every layer (Android gradle, FlavorConfig, iOS xcconfig and
// entitlements) and, with --remote, that the backend serves matching
// .well-known files.
//
// Usage:
//   dart run scripts/check_deeplink.dart <flavor> [--remote]

import 'dart:convert';
import 'dart:io';

import 'deep_link_brands.dart';

int _failures = 0;
int _warnings = 0;

void _pass(String msg) => print('  ✓ $msg');

void _fail(String msg) {
  _failures++;
  print('  ✗ $msg');
}

void _warn(String msg) {
  _warnings++;
  print('  ⚠ $msg');
}

Future<void> main(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  if (positional.isEmpty) {
    stderr.writeln('Usage: dart run scripts/check_deeplink.dart <flavor> [--remote]');
    exit(64);
  }
  final flavor = positional.first.trim().toLowerCase();
  final remote = args.contains('--remote');

  final brand = loadDeepLinkBrand(flavor);
  if (brand == null) {
    stderr.writeln('assets/brands/$flavor/brand.yaml not found');
    exit(1);
  }

  print('Deep link doctor: $flavor\n');

  print('brand.yaml');
  if (!brand.isEnabled) {
    print('  – no deepLink.host: deep linking is disabled for $flavor');
    _checkDisabledFlavor(flavor);
    _summary();
    return;
  }
  _pass('host: ${brand.hosts.join(', ')}');
  isPlaceholder(brand.iosTeamId)
      ? _fail('deepLink.iosTeamId is missing')
      : _pass('iosTeamId: ${brand.iosTeamId}');
  isPlaceholder(brand.iosAppStoreId)
      ? _warn('deepLink.iosAppStoreId is still a placeholder (needed for the web fallback page)')
      : _pass('iosAppStoreId: ${brand.iosAppStoreId}');
  brand.androidSha256.isEmpty || brand.androidSha256.any(isPlaceholder)
      ? _warn('deepLink.androidSha256 has placeholders (upload + Play App Signing keys needed)')
      : _pass('androidSha256: ${brand.androidSha256.length} fingerprint(s)');

  final sharing = loadAllBrands()
      .where((b) => b.flavor != flavor && b.androidPackage == brand.androidPackage)
      .map((b) => b.flavor)
      .toList();
  sharing.isEmpty
      ? _pass('android applicationId ${brand.androidPackage} is unique')
      : _fail('android applicationId ${brand.androidPackage} is shared with: ${sharing.join(', ')}');

  print('\nAndroid');
  _checkGradle(flavor, brand);
  _checkManifest();

  print('\nDart');
  _checkFlavorConfig(flavor, brand);

  print('\niOS');
  _checkXcconfig(flavor, brand);
  _checkEntitlements();

  if (remote) {
    print('\nRemote (.well-known)');
    for (final host in brand.hosts) {
      await _checkAssetLinks(host, brand);
      await _checkAasa(host, brand);
    }
  } else {
    print('\n(Remote checks skipped; pass --remote once backend hosts the files.)');
  }

  _summary();
}

void _summary() {
  print('\n${_failures == 0 ? 'OK' : 'FAILED'}: $_failures failure(s), $_warnings warning(s)');
  if (_failures > 0) exit(1);
}

String? _read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// Returns the `[ name: "<flavor>", ... ]` block for [flavor] in brand_flavors.gradle.
String? _gradleBlock(String flavor) {
  final gradle = _read('android/brand_flavors.gradle');
  if (gradle == null) return null;
  final start = gradle.indexOf('name: "$flavor"');
  if (start < 0) return null;
  final end = gradle.indexOf('],', start);
  return gradle.substring(start, end < 0 ? gradle.length : end);
}

void _checkGradle(String flavor, DeepLinkBrand brand) {
  final block = _gradleBlock(flavor);
  if (block == null) {
    _fail('$flavor not found in android/brand_flavors.gradle (run generate_brand_config.dart)');
    return;
  }
  block.contains('deepLinkHost: "${brand.host}"')
      ? _pass('brand_flavors.gradle deepLinkHost = ${brand.host}')
      : _fail('brand_flavors.gradle has no deepLinkHost "${brand.host}" (run generate_brand_config.dart)');
}

void _checkManifest() {
  final manifest = _read('android/app/src/main/AndroidManifest.xml') ?? '';
  manifest.contains(r'android:host="${deepLinkHost}"')
      ? _pass('AndroidManifest intent-filter uses \${deepLinkHost}')
      : _fail('AndroidManifest.xml has no autoVerify intent-filter for \${deepLinkHost}');
  manifest.contains('flutter_deeplinking_enabled')
      ? _pass('Flutter built-in deep linking disabled')
      : _fail('AndroidManifest.xml is missing flutter_deeplinking_enabled=false');
}

void _checkFlavorConfig(String flavor, DeepLinkBrand brand) {
  final config = _read('lib/flavor_config.dart') ?? '';
  config.contains("'$flavor': <String>['${brand.host}'")
      ? _pass('FlavorConfig.deepLinkHosts contains ${brand.host}')
      : _fail('lib/flavor_config.dart has no deep-link host for $flavor (run generate_brand_config.dart)');
}

void _checkXcconfig(String flavor, DeepLinkBrand brand) {
  final xcconfig = _read('ios/Flutter/Brand.xcconfig');
  if (xcconfig == null) {
    _fail('ios/Flutter/Brand.xcconfig missing (run prepare_flavor.dart $flavor)');
    return;
  }
  if (!xcconfig.contains('Active flavor: $flavor')) {
    _warn('Brand.xcconfig is for another flavor; run prepare_flavor.dart $flavor (launch.json does this)');
    return;
  }
  xcconfig.contains('DEEP_LINK_HOST=${brand.host}')
      ? _pass('Brand.xcconfig DEEP_LINK_HOST = ${brand.host}')
      : _fail('Brand.xcconfig DEEP_LINK_HOST is not ${brand.host}');
  xcconfig.contains('BRAND_ENTITLEMENTS=Runner/RunnerDeepLink.entitlements')
      ? _pass('Brand.xcconfig selects RunnerDeepLink.entitlements')
      : _fail('Brand.xcconfig does not select Runner/RunnerDeepLink.entitlements');
}

void _checkEntitlements() {
  final entitlements = _read('ios/Runner/RunnerDeepLink.entitlements') ?? '';
  entitlements.contains(r'applinks:$(DEEP_LINK_HOST)')
      ? _pass('RunnerDeepLink.entitlements has applinks:\$(DEEP_LINK_HOST)')
      : _fail('ios/Runner/RunnerDeepLink.entitlements missing or has no applinks entry');
  final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj') ?? '';
  final fixed = RegExp(r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;').allMatches(pbxproj).length;
  fixed == 0 && pbxproj.contains(r'CODE_SIGN_ENTITLEMENTS = "$(BRAND_ENTITLEMENTS)"')
      ? _pass('Runner target uses \$(BRAND_ENTITLEMENTS) for every configuration')
      : _fail('project.pbxproj still hardcodes Runner/Runner.entitlements in $fixed configuration(s)');
}

void _checkDisabledFlavor(String flavor) {
  final block = _gradleBlock(flavor);
  if (block != null && block.contains('deepLinkHost:')) {
    _fail('brand_flavors.gradle still has a deepLinkHost for $flavor (run generate_brand_config.dart)');
  }
  final xcconfig = _read('ios/Flutter/Brand.xcconfig') ?? '';
  if (xcconfig.contains('Active flavor: $flavor') &&
      xcconfig.contains('RunnerDeepLink.entitlements')) {
    _fail('Brand.xcconfig selects the deep-link entitlements for a disabled flavor');
  }
}

Future<({int status, String? contentType, String? location, String body})?> _get(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (
      status: response.statusCode,
      contentType: response.headers.contentType?.mimeType,
      location: response.headers.value(HttpHeaders.locationHeader),
      body: body,
    );
  } catch (e) {
    _fail('$uri: request failed ($e)');
    return null;
  } finally {
    client.close(force: true);
  }
}

bool _checkResponse(Uri uri, ({int status, String? contentType, String? location, String body}) res) {
  if (res.status >= 300 && res.status < 400) {
    _fail('$uri redirects to ${res.location} (must be served directly)');
    return false;
  }
  if (res.status != 200) {
    _fail('$uri returned HTTP ${res.status}');
    return false;
  }
  res.contentType == 'application/json'
      ? _pass('$uri: 200, application/json')
      : _warn('$uri: Content-Type is ${res.contentType}, expected application/json');
  return true;
}

Future<void> _checkAssetLinks(String host, DeepLinkBrand brand) async {
  final uri = Uri.https(host, '/.well-known/assetlinks.json');
  final res = await _get(uri);
  if (res == null || !_checkResponse(uri, res)) return;
  try {
    final entries = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    final target = entries
        .map((e) => e['target'] as Map<String, dynamic>?)
        .firstWhere((t) => t?['package_name'] == brand.androidPackage, orElse: () => null);
    if (target == null) {
      _fail('assetlinks.json has no entry for ${brand.androidPackage}');
      return;
    }
    _pass('assetlinks.json lists ${brand.androidPackage}');
    final served = (target['sha256_cert_fingerprints'] as List).map((s) => s.toString().toUpperCase()).toSet();
    for (final sha in brand.androidSha256.where((s) => !isPlaceholder(s))) {
      served.contains(sha.toUpperCase())
          ? _pass('fingerprint ${sha.substring(0, 8)}… present')
          : _fail('fingerprint $sha missing from assetlinks.json');
    }
  } catch (e) {
    _fail('assetlinks.json is not valid JSON in the expected shape ($e)');
  }
}

Future<void> _checkAasa(String host, DeepLinkBrand brand) async {
  final uri = Uri.https(host, '/.well-known/apple-app-site-association');
  final res = await _get(uri);
  if (res == null || !_checkResponse(uri, res)) return;
  try {
    final details = ((jsonDecode(res.body) as Map<String, dynamic>)['applinks']
        as Map<String, dynamic>)['details'] as List;
    final listed = details.any((d) {
      final map = d as Map<String, dynamic>;
      final ids = (map['appIDs'] as List?)?.map((e) => e.toString()) ??
          [if (map['appID'] != null) map['appID'].toString()];
      return ids.contains(brand.iosAppId);
    });
    listed
        ? _pass('apple-app-site-association lists ${brand.iosAppId}')
        : _fail('apple-app-site-association has no appIDs entry ${brand.iosAppId}');
  } catch (e) {
    _fail('apple-app-site-association is not valid JSON in the expected shape ($e)');
  }
}
