import 'dart:io';

import 'package:image/image.dart' as img;

/// Simple helper that converts the provided ProFX JPEG artwork into PNG.
Future<void> main() async {
  final sourceFile = File('assets/profx/App logo.jpeg');
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source artwork not found at ${sourceFile.path}');
    exitCode = 1;
    return;
  }

  final bytes = await sourceFile.readAsBytes();
  final decoded = img.decodeJpg(bytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode JPEG artwork.');
    exitCode = 1;
    return;
  }

  final outputFile = File('assets/profx/profx_icon.png');
  await outputFile.writeAsBytes(img.encodePng(decoded));
  stdout.writeln('Generated ${outputFile.path}');
}

