#!/usr/bin/env dart

import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run scripts/check_apk_assets.dart <apk-path> <flavor>');
    exit(64);
  }

  final apkPath = args[0];
  final flavor = args[1].trim().toLowerCase();
  final apk = File(apkPath);
  if (!await apk.exists()) {
    stderr.writeln('APK not found: $apkPath');
    exit(66);
  }

  final bytes = await apk.readAsBytes();
  final names = _zipEntryNames(bytes);
  final flutterAssets = names
      .where((name) => name.startsWith('assets/flutter_assets/assets/'))
      .toList()
    ..sort();

  final allowedPrefixes = <String>{
    'assets/flutter_assets/assets/clients/$flavor/',
    'assets/flutter_assets/assets/config/$flavor/',
    'assets/flutter_assets/assets/config/brands/brands.json',
    'assets/flutter_assets/assets/translations/',
    'assets/flutter_assets/assets/image/',
    'assets/flutter_assets/assets/svg/',
    'assets/flutter_assets/assets/font/',
    'assets/flutter_assets/assets/audio/',
    'assets/flutter_assets/assets/animation/',
    'assets/flutter_assets/assets/chart/',
    'assets/flutter_assets/assets/mock/',
  };

  final blockedClientPatterns = <String>[
    'assets/flutter_assets/assets/brands/',
    'assets/flutter_assets/assets/clients/',
    'assets/flutter_assets/assets/config/',
  ];

  final suspicious = <String>[];
  for (final asset in flutterAssets) {
    final lower = asset.toLowerCase();
    final isManagedClientAsset = blockedClientPatterns.any(lower.startsWith);
    if (!isManagedClientAsset) continue;

    final allowed = allowedPrefixes.any(lower.startsWith);
    if (!allowed) suspicious.add(asset);
  }

  print('APK: $apkPath');
  print('Flavor: $flavor');
  print('Flutter asset count: ${flutterAssets.length}');

  final visibleFlavorAssets = flutterAssets.where((asset) {
    final lower = asset.toLowerCase();
    return lower.contains('/assets/brands/') ||
        lower.contains('/assets/clients/') ||
        lower.contains('/assets/config/');
  }).toList();

  print('\nVisible flavor/config assets:');
  for (final asset in visibleFlavorAssets) {
    print('  $asset');
  }

  if (suspicious.isNotEmpty) {
    stderr.writeln('\n❌ Found assets outside selected flavor:');
    for (final asset in suspicious) {
      stderr.writeln('  $asset');
    }
    exit(1);
  }

  print('\n✅ OK: no other flavor asset/config folders are packaged.');
}

List<String> _zipEntryNames(Uint8List bytes) {
  final names = <String>[];
  var offset = 0;

  while (offset + 30 <= bytes.length) {
    final signature = _u32(bytes, offset);
    if (signature == 0x04034b50) {
      final compression = _u16(bytes, offset + 8);
      final compressedSize = _u32(bytes, offset + 18);
      final nameLength = _u16(bytes, offset + 26);
      final extraLength = _u16(bytes, offset + 28);
      final nameStart = offset + 30;
      final nameEnd = nameStart + nameLength;
      if (nameEnd > bytes.length) break;
      names.add(String.fromCharCodes(bytes.sublist(nameStart, nameEnd)));

      offset = nameEnd + extraLength + compressedSize;
      if (compression == 8 && compressedSize == 0) {
        // Fallback to central directory for uncommon data-descriptor ZIPs.
        return _centralDirectoryNames(bytes);
      }
      continue;
    }

    final central = _centralDirectoryNames(bytes);
    if (central.isNotEmpty) return central;
    break;
  }

  return names;
}

List<String> _centralDirectoryNames(Uint8List bytes) {
  final names = <String>[];
  for (var offset = 0; offset + 46 <= bytes.length; offset++) {
    if (_u32(bytes, offset) != 0x02014b50) continue;
    final nameLength = _u16(bytes, offset + 28);
    final extraLength = _u16(bytes, offset + 30);
    final commentLength = _u16(bytes, offset + 32);
    final nameStart = offset + 46;
    final nameEnd = nameStart + nameLength;
    if (nameEnd > bytes.length) break;
    names.add(String.fromCharCodes(bytes.sublist(nameStart, nameEnd)));
    offset = nameEnd + extraLength + commentLength - 1;
  }
  return names;
}

int _u16(Uint8List bytes, int offset) => bytes[offset] | (bytes[offset + 1] << 8);

int _u32(Uint8List bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);
