import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crm_app/main.dart' as main_config;
import 'package:crm_app/brands/brand_resolver.dart';

class ThemeService extends GetxService with WidgetsBindingObserver {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  // Legacy key (Light/Dark only)
  static const String _legacyThemeKey = 'is_dark_mode';
  // New key (System/Light/Dark)
  static const String _themeModeKey = 'theme_mode';

  static const ThemeMode defaultThemeMode = ThemeMode.system;

  /// Persisted user preference (System/Light/Dark).
  final Rx<ThemeMode> themeModeRx = defaultThemeMode.obs;

  /// Observable mirror of [isDarkResolved] — used by widgets inside Obx to
  /// rebuild when the theme flips (the underlying [themeModeRx] is Rx, but
  /// `platformBrightness` changes are not observable through GetX directly,
  /// so we recompute and update this whenever either source changes).
  final RxBool isDarkModeObs = false.obs;

  void _refreshDarkMode() {
    isDarkModeObs.value = isDarkResolved;
  }

  /// Effective theme mode based on:
  ///   1. Brand lock (dark-only / light-only)
  ///   2. Global flag (enableDarkModeGlobal)
  ///   3. User preference
  ThemeMode get themeMode {
    final brandConfig = _currentBrandThemeConfig();

    // 1) Brand forced dark → always dark, no user choice
    if (brandConfig == 'dark') return ThemeMode.dark;

    // 2) Brand forced light → always light, no user choice
    if (brandConfig == 'light') return ThemeMode.light;

    // 3) Global flag off → light only
    if (!main_config.enableDarkModeGlobal) return ThemeMode.light;

    // 4) User preference (both) → user choice wins
    return themeModeRx.value;
  }

  late final Future<void> _initialization;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    ever(themeModeRx, (_) => _refreshDarkMode());
    _refreshDarkMode();
    _initialization = _initialize();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _refreshDarkMode();

    // When the selected mode is System, Flutter switches Material themes by
    // itself, but our app-wide AppColors are getter-based and many widgets use
    // them directly. Force a rebuild so those widgets also resolve dark/light
    // colors immediately after the OS theme changes.
    if (themeMode == ThemeMode.system) {
      Get.forceAppUpdate();
    }
  }

  Future<void> _initialize() async {
    await _loadSavedThemeMode();
  }

  Future<void> ensureInitialized() => _initialization;

  /// Returns the active brand's themeMode setting.
  ///   'dark'  → forced dark
  ///   'light' → forced light
  ///   'both'  → user-selectable (default)
  String _currentBrandThemeConfig() {
    try {
      if (!Get.isRegistered<BrandResolver>()) return 'both';
      final resolver = Get.find<BrandResolver>();
      final active = resolver.activeBrand.value.value;
      final details = resolver.getBrandDetails(active);
      return (details?.themeMode ?? 'both').toLowerCase();
    } catch (_) {
      return 'both';
    }
  }

  /// True if the user can change theme for the active brand.
  ///   - false when brand is forced dark or forced light
  ///   - false when global flag is off
  ///   - true otherwise
  bool get canUserChangeTheme {
    final brandConfig = _currentBrandThemeConfig();
    if (brandConfig == 'dark' || brandConfig == 'light') return false;
    if (!main_config.enableDarkModeGlobal) return false;
    return true;
  }

  /// True if theme switcher UI should be hidden for the current brand.
  bool get isThemeSwitcherHidden {
    final brandConfig = _currentBrandThemeConfig();
    return brandConfig == 'dark' || brandConfig == 'light';
  }

  /// Returns forced theme mode (or null if user-selectable).
  ThemeMode? get forcedThemeMode {
    final brandConfig = _currentBrandThemeConfig();
    if (brandConfig == 'dark') return ThemeMode.dark;
    if (brandConfig == 'light') return ThemeMode.light;
    return null;
  }

  bool get isSystemMode {
    if (isThemeSwitcherHidden) return false;
    if (!main_config.enableDarkModeGlobal) return false;
    return themeModeRx.value == ThemeMode.system;
  }

  bool get isDarkResolved {
    // Brand forced dark → always dark
    if (forcedThemeMode == ThemeMode.dark) return true;
    // Brand forced light → never dark
    if (forcedThemeMode == ThemeMode.light) return false;
    // Global flag off → never dark
    if (!main_config.enableDarkModeGlobal) return false;
    // User preference
    if (themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return themeMode == ThemeMode.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    // Block theme changes when brand is locked or global flag is off
    if (isThemeSwitcherHidden) {
      // Force the locked value instead
      final locked = forcedThemeMode ?? ThemeMode.light;
      if (themeModeRx.value == locked) return;
      themeModeRx.value = locked;
      await _saveThemeMode(locked);
      Get.forceAppUpdate();
      return;
    }

    if (!main_config.enableDarkModeGlobal) {
      if (themeModeRx.value == ThemeMode.light) return;
      themeModeRx.value = ThemeMode.light;
      await _saveThemeMode(ThemeMode.light);
      Get.forceAppUpdate();
      return;
    }

    if (themeModeRx.value == mode) return;
    themeModeRx.value = mode;
    await _saveThemeMode(mode);
    Get.forceAppUpdate();
  }

  Future<void> toggleTheme() async {
    if (isThemeSwitcherHidden) return;
    if (!main_config.enableDarkModeGlobal) {
      await setThemeMode(ThemeMode.light);
      return;
    }
    final next = isDarkResolved ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }

  /// Back-compat API: interpret as forcing light/dark (not system).
  Future<void> setDarkMode(bool value) async {
    if (isThemeSwitcherHidden) {
      // Stay locked; no-op
      return;
    }
    if (!main_config.enableDarkModeGlobal) {
      await setThemeMode(ThemeMode.light);
      return;
    }
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

      // Migration: legacy boolean value → preserve dark if it was explicitly on,
      // otherwise fall back to System so a device set to dark opens the app dark.
      // This prevents old installs with `is_dark_mode=false` from being stuck in
      // Light while the OS is Dark.
      final legacy = await _storage.read(key: _legacyThemeKey);
      if (legacy != null) {
        final migrated = legacy == 'true' ? ThemeMode.dark : ThemeMode.system;
        themeModeRx.value = migrated;
        await _saveThemeMode(migrated);
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
