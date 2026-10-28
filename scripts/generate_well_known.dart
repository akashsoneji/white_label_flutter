#!/usr/bin/env dart
//
// scripts/generate_well_known.dart
//
// Builds the files backend must host for App Links / Universal Links, from the
// `deepLink` block in assets/brands/<flavor>/brand.yaml:
//   build/well-known/<host>/assetlinks.json
//   build/well-known/<host>/apple-app-site-association
// Brands that share a host are merged into one pair of files.
//
// Usage:
//   dart run scripts/generate_well_known.dart <flavor>
//   dart run scripts/generate_well_known.dart --all

import 'dart:convert';
import 'dart:io';

import 'deep_link_brands.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run scripts/generate_well_known.dart <flavor|--all>');
    exit(64);
  }

  final all = loadAllBrands().where((b) => b.isEnabled).toList();
  final selected = args.first == '--all'
      ? all
      : all.where((b) => b.flavor == args.first.trim().toLowerCase()).toList();

  if (selected.isEmpty) {
    stderr.writeln(
      'No deep-link-enabled brand matches "${args.first}". '
      'Add a deepLink.host to assets/brands/<flavor>/brand.yaml first.',
    );
    exit(1);
  }

  final errors = <String>[];
  for (final brand in selected) {
    if (isPlaceholder(brand.iosTeamId)) errors.add('${brand.flavor}: deepLink.iosTeamId is missing');
    if (isPlaceholder(brand.iosAppStoreId)) {
      errors.add('${brand.flavor}: deepLink.iosAppStoreId is missing or a placeholder');
    }
    if (brand.androidSha256.isEmpty || brand.androidSha256.any(isPlaceholder)) {
      errors.add('${brand.flavor}: deepLink.androidSha256 is missing or a placeholder');
    }
  }
  if (errors.isNotEmpty) {
    stderr.writeln('Cannot generate well-known files:');
    for (final e in errors) {
      stderr.writeln('  ✗ $e');
    }
    exit(1);
  }

  // Every brand on a host goes into that host's files, so a shared domain
  // never loses another brand's entry.
  final selectedHosts = {for (final b in selected) ...b.hosts};
  final encoder = const JsonEncoder.withIndent('  ');

  for (final host in selectedHosts) {
    final brandsOnHost = all.where((b) => b.hosts.contains(host)).toList();
    final unready = brandsOnHost.where((b) => !selected.contains(b)).toList();
    for (final b in unready) {
      final ready = !isPlaceholder(b.iosTeamId) &&
          b.androidSha256.isNotEmpty &&
          !b.androidSha256.any(isPlaceholder);
      if (!ready) {
        stderr.writeln(
          '  ⚠️  ${b.flavor} also uses $host but has placeholder values; '
          'it is left out of these files.',
        );
        brandsOnHost.remove(b);
      }
    }

    final assetLinks = brandsOnHost
        .map((b) => {
              'relation': ['delegate_permission/common.handle_all_urls'],
              'target': {
                'namespace': 'android_app',
                'package_name': b.androidPackage,
                'sha256_cert_fingerprints': b.androidSha256.map((s) => s.toUpperCase()).toList(),
              },
            })
        .toList();

    final components = [
      for (final p in deepLinkPaths) ...[
        {'/': p},
        {'/': '$p/*'},
      ],
    ];
    final aasa = {
      'applinks': {
        'details': brandsOnHost
            .map((b) => {
                  'appIDs': [b.iosAppId],
                  'components': components,
                })
            .toList(),
      },
    };

    final dir = Directory('build/well-known/$host')..createSync(recursive: true);
    File('${dir.path}/assetlinks.json').writeAsStringSync('${encoder.convert(assetLinks)}\n');
    File('${dir.path}/apple-app-site-association').writeAsStringSync('${encoder.convert(aasa)}\n');

    print('✓ $host  (${brandsOnHost.map((b) => b.flavor).join(', ')})');
    print('    ${dir.path}/assetlinks.json');
    print('    ${dir.path}/apple-app-site-association');
  }

  print('\nHost both at https://<host>/.well-known/ with Content-Type: application/json, '
      'HTTP 200 and no redirects.');
}
