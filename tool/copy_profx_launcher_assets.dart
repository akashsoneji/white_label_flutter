import 'dart:io';

import 'package:path/path.dart' as p;

void main() {
  _copyAndroidIcons();
  _copyIosIcons();
}

void _copyAndroidIcons() {
  const densities = <String>[
    'mipmap-anydpi-v26',
    'mipmap-hdpi',
    'mipmap-mdpi',
    'mipmap-xhdpi',
    'mipmap-xxhdpi',
    'mipmap-xxxhdpi',
  ];

  final srcRoot = Directory('android/app/src/main/res');
  final destRoot = Directory('android/app/src/profx/res');

  for (final density in densities) {
    final srcDir = Directory(p.join(srcRoot.path, density));
    if (!srcDir.existsSync()) continue;

    final destDir = Directory(p.join(destRoot.path, density));
    destDir.createSync(recursive: true);

    for (final entity in srcDir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('ic_launcher')) continue;
      entity.copySync(p.join(destDir.path, name));
    }
  }
}

void _copyIosIcons() {
  final src = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  if (!src.existsSync()) return;

  final dest = Directory(
    'ios/Runner/Assets.xcassets/profx_app_icon.appiconset',
  );
  if (dest.existsSync()) {
    dest.deleteSync(recursive: true);
  }
  dest.createSync(recursive: true);

  for (final entity in src.listSync(recursive: false)) {
    if (entity is! File) continue;
    entity.copySync(p.join(dest.path, p.basename(entity.path)));
  }
}
