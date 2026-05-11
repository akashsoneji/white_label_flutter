import 'package:package_info_plus/package_info_plus.dart';

/// Service to manage app version information
/// Provides cached access to app version and build number
class AppVersionService {
  static AppVersionService? _instance;
  PackageInfo? _packageInfo;
  bool _isLoading = false;

  AppVersionService._();

  /// Get singleton instance
  static AppVersionService get instance {
    _instance ??= AppVersionService._();
    return _instance!;
  }

  /// Initialize and cache package info
  Future<void> initialize() async {
    if (_packageInfo != null || _isLoading) return;
    
    _isLoading = true;
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } finally {
      _isLoading = false;
    }
  }

  /// Get app version (e.g., "1.0.0")
  Future<String> getVersion() async {
    await initialize();
    return _packageInfo?.version ?? '1.0.0';
  }

  /// Get build number (e.g., "1")
  Future<String> getBuildNumber() async {
    await initialize();
    return _packageInfo?.buildNumber ?? '1';
  }

  /// Get full version string (e.g., "1.0.0 (1)")
  Future<String> getFullVersion() async {
    await initialize();
    if (_packageInfo == null) return '1.0.0';
    return '${_packageInfo!.version} (${_packageInfo!.buildNumber})';
  }

  /// Get app name
  Future<String> getAppName() async {
    await initialize();
    return _packageInfo?.appName ?? 'App';
  }

  /// Get package name
  Future<String> getPackageName() async {
    await initialize();
    return _packageInfo?.packageName ?? '';
  }
}

