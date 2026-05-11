import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Compresses large image files before upload (shared by API uploads and KYC UI).
class FileCompressionHelper {
  static const int maxFileSize = 1500 * 1024; // 1.5 MB

  static Future<File> compressIfNeeded(File file) async {
    final int fileSize = await file.length();
    if (fileSize <= maxFileSize) return file;

    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 85,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (result == null) return file;
    return File(result.path);
  }
}
