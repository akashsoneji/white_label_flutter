import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:crm_app/utils/app_logger.dart';

/// Service for in-app APK download and installation.
/// Handles:
/// - Downloading APK from direct URL (current flow: APK hosted on your server)
/// - Future-ready: Detecting Play Store AAB URLs and redirecting to Play Store
/// - Showing download progress
/// - Installing APK with system permission prompt
class InAppUpdateService {
  static InAppUpdateService? _instance;

  /// Singleton
  static InAppUpdateService get instance {
    _instance ??= InAppUpdateService._();
    return _instance!;
  }

  InAppUpdateService._();

  /// Check if the given URL is a direct APK file URL.
  bool _isApkUrl(String url) {
    return url.toLowerCase().endsWith('.apk');
  }

  /// Check if the given URL is a Play Store URL.
  bool _isPlayStoreUrl(String url) {
    return url.contains('play.google.com') ||
        url.contains('market.android.com');
  }

  /// Check if the given URL is a direct AAB file URL.
  bool _isAabUrl(String url) {
    return url.toLowerCase().endsWith('.aab');
  }

  /// Download and install update.
  ///
  /// Returns:
  /// - `DownloadResult.downloading` if download started/completed
  /// - `DownloadResult.playStore` if URL is Play Store (caller should open Play Store)
  /// - `DownloadResult.aabPlayStore` if URL is AAB (caller should open Play Store)
  /// - `DownloadResult.error` on failure
  Future<DownloadResult> downloadAndInstall(
    String updateUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Route based on URL type
      if (_isPlayStoreUrl(updateUrl) || _isAabUrl(updateUrl)) {
        AppLogger.debug(
          'InAppUpdateService: URL is Play Store/AAB — caller should open store',
        );
        return _isAabUrl(updateUrl)
            ? DownloadResult.aabPlayStore
            : DownloadResult.playStore;
      }

      if (!_isApkUrl(updateUrl)) {
        AppLogger.error(
          'InAppUpdateService: Unknown update URL format: $updateUrl',
        );
        return DownloadResult.error;
      }

      AppLogger.debug('InAppUpdateService: Starting APK download: $updateUrl');

      // Download APK to app's cache directory
      final file = await _downloadFile(updateUrl, onProgress: onProgress);
      if (file == null) {
        return DownloadResult.error;
      }

      // Install APK (opens system installer, shows "Install unknown apps?" permission)
      await _installApk(file);
      return DownloadResult.downloading;
    } catch (e, stackTrace) {
      AppLogger.error(
        'InAppUpdateService: Error during download/install',
        error: e,
        stackTrace: stackTrace,
      );
      return DownloadResult.error;
    }
  }

  /// Internal download helper.
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

          // Log every 10%
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

  /// Trigger Android system APK installer.
  /// Android will automatically prompt the user with
  /// "Install unknown apps?" permission if needed.
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

/// Result of the download-and-install flow.
enum DownloadResult {
  /// APK is being downloaded (progress will be reported via callback).
  downloading,

  /// URL is a Play Store URL — caller should open Play Store in browser.
  playStore,

  /// URL is a direct AAB file URL — caller should open Play Store.
  /// AAB files cannot be installed directly; must go through Play Store.
  aabPlayStore,

  /// An error occurred.
  error,
}