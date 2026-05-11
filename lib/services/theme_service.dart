import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeService extends GetxService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  // Legacy key (Light/Dark only)
  static const String _legacyThemeKey = 'is_dark_mode';
  // New key (System/Light/Dark)
  static const String _themeModeKey = 'theme_mode';

  static const ThemeMode defaultThemeMode = ThemeMode.system;

  /// Persisted user preference (System/Light/Dark).
  final Rx<ThemeMode> themeModeRx = defaultThemeMode.obs;

  ThemeMode get themeMode => themeModeRx.value;

  late final Future<void> _initialization;

  @override
  void onInit() {
    super.onInit();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await _loadSavedThemeMode();
  }

  Future<void> ensureInitialized() => _initialization;

  bool get isSystemMode => themeMode == ThemeMode.system;

  /// True when the *effective* UI should be dark (System-aware).
  bool get isDarkResolved {
    switch (themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeModeRx.value == mode) return;
    themeModeRx.value = mode;
    await _saveThemeMode(mode);
    Get.forceAppUpdate();
  }

  Future<void> toggleTheme() async {
    // For convenience: toggles between Light <-> Dark (ignores System).
    final next =
        isDarkResolved ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }

  /// Back-compat API: interpret as forcing light/dark (not system).
  Future<void> setDarkMode(bool value) async {
    await setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  /// Load saved theme preference from secure storage (with migration).
  Future<void> _loadSavedThemeMode() async {
    try {
      final savedMode = await _storage.read(key: _themeModeKey);
      if (savedMode != null) {
        final parsed = _parseThemeMode(savedMode);
        if (parsed != null) {
          themeModeRx.value = parsed;
          return;
        }
      }

      // Migration: legacy boolean value → explicit light/dark.
      final legacy = await _storage.read(key: _legacyThemeKey);
      if (legacy != null) {
        final legacyBool = legacy == 'true';
        final migrated = legacyBool ? ThemeMode.dark : ThemeMode.light;
        themeModeRx.value = migrated;
        await _saveThemeMode(migrated);
        // Best-effort cleanup (don’t block app startup on failures).
        try {
          await _storage.delete(key: _legacyThemeKey);
        } catch (_) {}
        return;
      }
    } catch (e) {
      print('ThemeService: Error loading saved theme: $e');
      themeModeRx.value = defaultThemeMode;
    }
  }

  ThemeMode? _parseThemeMode(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      await _storage.write(key: _themeModeKey, value: _serializeThemeMode(mode));
    } catch (e) {
      print('ThemeService: Error saving theme mode: $e');
    }
  }

  /// Back-compat getter: effective dark state.
  bool isDark() => isDarkResolved;

  /// Back-compat getter (old API expected by some screens).
  bool get isDarkMode => isDarkResolved;
}
