import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:crm_app/utils/app_logger.dart';

/// Service for in-app APK download and installation.
class InAppUpdateService {
  static InAppUpdateService? _instance;

  static InAppUpdateService get instance {
    _instance ??= InAppUpdateService._();
    return _instance!;
  }

  InAppUpdateService._();

  /// Check if the given URL contains an APK reference.
  /// Handles URLs with query parameters like:
  /// https://example.com/download.php?filename=app.apk&t=123
  bool isApkUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.apk')) return true;
    try {
      final uri = Uri.parse(lower);
      if (uri.path.endsWith('.apk')) return true;
      for (final value in uri.queryParameters.values) {
        if (value.endsWith('.apk')) return true;
      }
    } catch (_) {}
    return lower.contains('.apk');
  }

  /// Download APK and install it.
  ///
  /// Returns:
  /// - `DownloadResult.success` if download completed and installer opened
  /// - `DownloadResult.error` on failure
  Future<DownloadResult> downloadAndInstall(
    String updateUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      AppLogger.debug('InAppUpdateService: Starting APK download: $updateUrl');

      final file = await _downloadFile(updateUrl, onProgress: onProgress);
      if (file == null) {
        return DownloadResult.error;
      }

      await _installApk(file);
      return DownloadResult.success;
    } catch (e, stackTrace) {
      AppLogger.error(
        'InAppUpdateService: Error during download/install',
        error: e,
        stackTrace: stackTrace,
      );
      return DownloadResult.error;
    }
  }

  Future<File?> _downloadFile(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        AppLogger.error(
          'InAppUpdateService: HTTP error ${response.statusCode} for URL: $url',
        );
        client.close();
        return null;
      }

      final contentLength = response.contentLength ?? -1;
      AppLogger.debug(
        'InAppUpdateService: Content-Length: $contentLength bytes',
      );

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/update_$timestamp.apk');

      final sink = file.openWrite();

      int downloadedBytes = 0;
      int lastLoggedPercent = -1;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;

          final percent = (progress * 10).floor();
          if (percent != lastLoggedPercent) {
            lastLoggedPercent = percent;
            AppLogger.debug(
              'InAppUpdateService: Download progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }

          onProgress?.call(progress.clamp(0.0, 1.0));
        }
      }

      await sink.close();
      client.close();

      AppLogger.debug(
        'InAppUpdateService: Download complete. File: ${file.path}',
      );
      return file;
    } catch (e, stackTrace) {
      AppLogger.error(
        'InAppUpdateService: Download failed',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _installApk(File apkFile) async {
    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );

    switch (result.type) {
      case ResultType.done:
        AppLogger.debug('InAppUpdateService: Installer opened successfully');
        break;
      case ResultType.noAppToOpen:
        AppLogger.error(
          'InAppUpdateService: No app found to open APK file',
        );
        throw Exception('No installer app found');
      case ResultType.error:
        AppLogger.error(
          'InAppUpdateService: Error opening installer: ${result.message}',
        );
        throw Exception(result.message);
      case ResultType.fileNotFound:
        AppLogger.error(
          'InAppUpdateService: APK file not found at path: ${apkFile.path}',
        );
        throw Exception('APK file not found');
      default:
        AppLogger.debug(
          'InAppUpdateService: OpenFilex result: ${result.type} - ${result.message}',
        );
    }
  }
}

enum DownloadResult {
  success,
  error,
}
