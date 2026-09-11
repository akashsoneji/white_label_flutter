import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LanguageService extends GetxService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _languageKey = 'selected_language';
  static const String _localeKey = 'selected_locale';

  // Supported languages (order matches the in-app language picker)
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'ar': 'العربية',
    'es': 'Español',
    'id': 'Bahasa Indonesia',
    'vi': 'Tiếng Việt',
    'zh': '中文 (简体)',
  };

  /// Supported locales for MaterialApp.supportedLocales. Derived from
  /// [supportedLanguages] so it stays in sync with the language picker.
  /// Used by `GetMaterialApp` (see `lib/main.dart`) so flutter_localizations
  /// can resolve `Directionality` from the active locale automatically —
  /// TextFields render RTL in Arabic without us having to force
  /// `textDirection` on every field.
  static List<Locale> get supportedLocales =>
      supportedLanguages.keys.map(_localeFor).toList(growable: false);

  /// Build a [Locale] for a language code. Chinese needs a region qualifier
  /// so Flutter's built-in `GlobalMaterialLocalizations` resolves correctly
  /// (`zh-CN` = Simplified Chinese). All other supported languages use a
  /// bare `Locale(code)` like before.
  static Locale _localeFor(String code) {
    switch (code) {
      case 'zh':
        return const Locale('zh', 'CN');
      default:
        return Locale(code);
    }
  }

  // RTL languages (only Arabic — French, Indonesian, Chinese, etc. are LTR)
  static const List<String> rtlLanguages = ['ar'];

  // Default language
  static const String defaultLanguage = 'en';
  static const Locale defaultLocale = Locale('en', 'US');

  // Current language observable
  final RxString currentLanguage = defaultLanguage.obs;
  final Rx<Locale> currentLocale = defaultLocale.obs;

  // Translations map
  final Map<String, Map<String, dynamic>> _translations = {};
  // Track which languages are currently loading
  final Set<String> _loadingLanguages = {};
  late final Future<void> _initialization;

  /// Index to track branding changes (colors, logos, names)
  /// Incrementing this will trigger a global UI rebuild.
  final RxInt brandingUpdateIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await _loadSavedLanguage();
    // Load only current language at startup for faster initialization
    await _loadTranslationForLanguage(currentLanguage.value);
    // Load other languages in background (non-blocking)
    _loadOtherTranslationsInBackground();
  }

  Future<void> ensureInitialized() => _initialization;

  /// Load saved language from secure storage
  Future<void> _loadSavedLanguage() async {
    try {
      final savedLanguage = await _storage.read(key: _languageKey);
      final savedLocale = await _storage.read(key: _localeKey);

      if (savedLanguage != null &&
          supportedLanguages.containsKey(savedLanguage)) {
        currentLanguage.value = savedLanguage;

        if (savedLocale != null) {
          final localeParts = savedLocale.split('_');
          if (localeParts.length == 2) {
            currentLocale.value = Locale(localeParts[0], localeParts[1]);
          } else {
            currentLocale.value = _localeFor(savedLanguage);
          }
        } else {
          currentLocale.value = _localeFor(savedLanguage);
        }
      }
    } catch (e) {
      print('LanguageService: Error loading saved language: $e');
      // Fallback to default
      currentLanguage.value = defaultLanguage;
      currentLocale.value = defaultLocale;
    }
  }

  /// Load translation for a specific language
  Future<void> _loadTranslationForLanguage(String languageCode) async {
    // Skip if already loaded or currently loading
    if (_translations.containsKey(languageCode) ||
        _loadingLanguages.contains(languageCode)) {
      return;
    }

    _loadingLanguages.add(languageCode);
    try {
      final translationData = await _loadTranslationFile(languageCode);
      if (translationData != null) {
        _translations[languageCode] = translationData;
      }
    } catch (e) {
      print('LanguageService: Error loading translation for $languageCode: $e');
    } finally {
      _loadingLanguages.remove(languageCode);
    }
  }

  /// Load other languages in background (non-blocking)
  void _loadOtherTranslationsInBackground() {
    // Load other languages asynchronously without blocking
    Future.microtask(() async {
      final otherLanguages =
          supportedLanguages.keys
              .where((code) => code != currentLanguage.value)
              .toList();

      // Load in parallel for better performance
      await Future.wait(
        otherLanguages.map((code) => _loadTranslationForLanguage(code)),
        eagerError: false, // Don't stop on first error
      );
    });
  }

  /// Load translation file from assets
  Future<Map<String, dynamic>?> _loadTranslationFile(
    String languageCode,
  ) async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/translations/$languageCode.json',
      );
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print(
        'LanguageService: Error loading translation file for $languageCode: $e',
      );
      return null;
    }
  }

  /// Change language
  Future<void> changeLanguage(String languageCode) async {
    try {
      if (!supportedLanguages.containsKey(languageCode)) {
        throw Exception('Unsupported language: $languageCode');
      }

      // Ensure translation is loaded before switching
      await _loadTranslationForLanguage(languageCode);

      // Update current language
      currentLanguage.value = languageCode;

      // Update locale (use _localeFor so Chinese gets `zh_CN` region tag)
      currentLocale.value = _localeFor(languageCode);

      // Save to secure storage
      await _storage.write(key: _languageKey, value: languageCode);
      final loc = _localeFor(languageCode);
      final localeTag = loc.countryCode != null
          ? '${loc.languageCode}_${loc.countryCode}'
          : '${loc.languageCode}_${loc.languageCode.toUpperCase()}';
      await _storage.write(key: _localeKey, value: localeTag);

      // Update GetX locale
      Get.updateLocale(currentLocale.value);

      print('LanguageService: Language changed to $languageCode');
    } catch (e) {
      print('LanguageService: Error changing language: $e');
      rethrow;
    }
  }

  /// Get current language name
  String getCurrentLanguageName() {
    return supportedLanguages[currentLanguage.value] ?? 'English';
  }

  /// Get supported languages
  Map<String, String> getSupportedLanguages() {
    return Map.from(supportedLanguages);
  }

  /// Check if current language is RTL
  bool isRTL() {
    return rtlLanguages.contains(currentLanguage.value);
  }

  /// Get text direction
  TextDirection getTextDirection() {
    return isRTL() ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Get translation by key
  String tr(String key, [Map<String, String>? args]) {
    try {
      final translations = _translations[currentLanguage.value];
      if (translations == null) {
        // If translation not loaded yet, try to load it synchronously (fallback)
        // This should rarely happen as we load current language at startup
        if (!_loadingLanguages.contains(currentLanguage.value)) {
          _loadTranslationForLanguage(currentLanguage.value);
        }
        // Return key as fallback while loading
        return key;
      }

      String translation = translations[key]?.toString() ?? key;

      // Replace arguments if provided
      if (args != null) {
        args.forEach((argKey, argValue) {
          translation = translation.replaceAll('{$argKey}', argValue);
        });
      }

      return translation;
    } catch (e) {
      print('LanguageService: Error getting translation for key $key: $e');
      return key;
    }
  }

  /// Get translation with fallback
  String trf(String key, String fallback, [Map<String, String>? args]) {
    final translation = tr(key, args);
    return translation != key ? translation : fallback;
  }

  /// Get plural translation
  String trp(String key, int count, [Map<String, String>? args]) {
    try {
      final translations = _translations[currentLanguage.value];
      if (translations == null) return key;

      // Try to get plural form
      final pluralKey = '${key}_${count == 1 ? 'one' : 'other'}';
      String translation = translations[pluralKey]?.toString() ?? key;

      // Replace count placeholder
      translation = translation.replaceAll('{count}', count.toString());

      // Replace other arguments
      if (args != null) {
        args.forEach((argKey, argValue) {
          translation = translation.replaceAll('{$argKey}', argValue);
        });
      }

      return translation;
    } catch (e) {
      print(
        'LanguageService: Error getting plural translation for key $key: $e',
      );
      return key;
    }
  }

  /// Get current locale
  Locale getCurrentLocale() {
    return currentLocale.value;
  }

  /// Get all available locales
  List<Locale> getAvailableLocales() {
    return supportedLanguages.keys.map(_localeFor).toList();
  }

  /// Reset to default language
  Future<void> resetToDefault() async {
    await changeLanguage(defaultLanguage);
  }

  /// Clear saved language settings
  Future<void> clearSavedLanguage() async {
    try {
      await _storage.delete(key: _languageKey);
      await _storage.delete(key: _localeKey);
      await resetToDefault();
    } catch (e) {
      print('LanguageService: Error clearing saved language: $e');
    }
  }

  /// Get language info
  Map<String, dynamic> getLanguageInfo(String languageCode) {
    final loc = _localeFor(languageCode);
    return {
      'code': languageCode,
      'name': supportedLanguages[languageCode] ?? 'Unknown',
      'isRTL': rtlLanguages.contains(languageCode),
      'locale': loc,
    };
  }

  /// Check if language is supported
  bool isLanguageSupported(String languageCode) {
    return supportedLanguages.containsKey(languageCode);
  }

  /// Get system language
  String getSystemLanguage() {
    final systemLocale = Get.deviceLocale;
    if (systemLocale != null) {
      final languageCode = systemLocale.languageCode;
      if (isLanguageSupported(languageCode)) {
        return languageCode;
      }
    }
    return defaultLanguage;
  }

  /// Initialize with system language
  Future<void> initializeWithSystemLanguage() async {
    final systemLanguage = getSystemLanguage();
    if (systemLanguage != defaultLanguage) {
      await changeLanguage(systemLanguage);
    }
  }

  /// Get translation statistics
  Map<String, dynamic> getTranslationStats() {
    final stats = <String, dynamic>{};

    for (String languageCode in supportedLanguages.keys) {
      final translations = _translations[languageCode];
      if (translations != null) {
        stats[languageCode] = {
          'total_keys': translations.length,
          'translated_keys':
              translations.values
                  .where((v) => v != null && v.toString().isNotEmpty)
                  .length,
          'missing_keys':
              translations.values
                  .where((v) => v == null || v.toString().isEmpty)
                  .length,
        };
      }
    }

    return stats;
  }

  /// Validate translations
  List<String> validateTranslations() {
    final errors = <String>[];
    final referenceLanguage = 'en';
    final referenceTranslations = _translations[referenceLanguage];

    if (referenceTranslations == null) {
      errors.add(
        'Reference language ($referenceLanguage) translations not found',
      );
      return errors;
    }

    for (String languageCode in supportedLanguages.keys) {
      if (languageCode == referenceLanguage) continue;

      final translations = _translations[languageCode];
      if (translations == null) {
        errors.add('Translations not found for $languageCode');
        continue;
      }

      for (String key in referenceTranslations.keys) {
        if (!translations.containsKey(key)) {
          errors.add('Missing key "$key" in $languageCode');
        } else if (translations[key] == null ||
            translations[key].toString().isEmpty) {
          errors.add('Empty translation for key "$key" in $languageCode');
        }
      }
    }

    return errors;
  }

  /// Export translations for a specific language
  Map<String, dynamic> exportTranslations(String languageCode) {
    final translations = _translations[languageCode];
    if (translations == null) {
      throw Exception('Translations not found for $languageCode');
    }

    return {
      'language_code': languageCode,
      'language_name': supportedLanguages[languageCode],
      'is_rtl': rtlLanguages.contains(languageCode),
      'translations': translations,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  /// Import translations
  Future<void> importTranslations(
    String languageCode,
    Map<String, dynamic> translations,
  ) async {
    try {
      _translations[languageCode] = translations;
      print('LanguageService: Translations imported for $languageCode');
    } catch (e) {
      print(
        'LanguageService: Error importing translations for $languageCode: $e',
      );
      rethrow;
    }
  }
}

// Translation utility class to avoid conflicts with GetX extensions
class TranslationUtils {
  static LanguageService get _service => Get.find<LanguageService>();

  static String tr(String key) => _service.tr(key);
  static String trArgs(String key, Map<String, String> args) =>
      _service.tr(key, args);
  static String trf(String key, String fallback) => _service.trf(key, fallback);
  static String trp(String key, int count) => _service.trp(key, count);
}

// Extension for easy translation access (use with explicit override if needed)
// This extension conflicts with GetX's Trans extension, so we'll use a different method name
extension CrmAppTranslationExtension on String {
  // Use 'translate' instead of 'tr' to avoid conflicts
  String get translate => TranslationUtils.tr(this);
  String translateArgs(Map<String, String> args) =>
      TranslationUtils.trArgs(this, args);
  String translateWithFallback(String fallback) =>
      TranslationUtils.trf(this, fallback);
  String translatePlural(int count) => TranslationUtils.trp(this, count);
}
