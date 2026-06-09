import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../flavor_config.dart';
import 'brand_id.dart';
import 'brand_registry.dart';

/// Brand details loaded from brands.json (brandDetails field).
class BrandDetails {
  final String name;
  final String type; // 'parent' or 'child'
  final String? inheritsFrom;
  final String label;

  /// Brand theme mode:
  ///   'dark'  → forced dark, theme switcher hidden
  ///   'light' → forced light, theme switcher hidden
  ///   'both'  → user can pick light/dark/system
  final String themeMode;

  const BrandDetails({
    required this.name,
    required this.type,
    this.inheritsFrom,
    required this.label,
    this.themeMode = 'both',
  });

  factory BrandDetails.fromJson(Map<String, dynamic> json) {
    return BrandDetails(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'parent',
      inheritsFrom: json['inheritsFrom'] as String?,
      label: json['label'] as String? ?? '',
      themeMode: json['themeMode'] as String? ?? 'both',
    );
  }

  /// True when the brand is locked to dark (no user choice).
  bool get isDarkOnly => themeMode.toLowerCase() == 'dark';

  /// True when the brand is locked to light (no user choice).
  bool get isLightOnly => themeMode.toLowerCase() == 'light';

  /// True when the user can pick light/dark/system.
  bool get isUserSelectable => themeMode.toLowerCase() == 'both';
}

/// Resolves the active brand at runtime and applies it to existing branding
/// plumbing via [FlavorConfig] + [AppConfigService]'s existing model.
class BrandResolver extends GetxService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _brandKey = 'selected_brand_id';
  static const String _client = String.fromEnvironment(
    'CLIENT',
    defaultValue: '',
  );
  static const String _flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'tenax',
  );

  final Rx<BrandId> activeBrand = BrandId.tenax.obs;
  BrandRegistry? _registry;
  final Map<String, BrandDetails> _brandDetails = {};

  late final Future<void> _initialization;

  @override
  void onInit() {
    super.onInit();
    _initialization = _initialize();
  }

  Future<void> ensureInitialized() => _initialization;

  BrandRegistry? get registry => _registry;

  /// Returns brand details for a given brand name.
  BrandDetails? getBrandDetails(String brandName) => _brandDetails[brandName];

  /// Returns the UI parent brand for a given brand.
  /// - Parent brands return themselves (they have their own screens).
  /// - Child brands return their `inheritsFrom` parent.
  /// The result is the brand whose screen files should be used.
  static String resolveUiBrand(String brandName, Map<String, BrandDetails> details) {
    final detail = details[brandName];
    if (detail == null) return brandName;

    if (detail.type == 'child' && detail.inheritsFrom != null && details.containsKey(detail.inheritsFrom)) {
      // Recursively resolve in case the parent is also a child.
      // If parent metadata is intentionally not bundled in a single-client build,
      // fall back to the active brand name so APK decompile does not expose parent/child registry data.
      return resolveUiBrand(detail.inheritsFrom!, details);
    }

    return brandName;
  }

  /// Returns the expected path for the given brand's config.
  /// Convention: `assets/config/<brandId>/app_config.json`
  static String appConfigAssetPathFor(BrandId brandId) {
    return 'assets/config/${brandId.value}/app_config.json';
  }

  Future<void> _initialize() async {
    try {
      _registry = await BrandRegistry.loadFromAssets();
    } catch (e) {
      debugPrint('[BrandResolver] Failed to load registry: $e');
      _registry = const BrandRegistry(
        defaultBrand: BrandId.tenax,
        brands: <BrandId>[BrandId.tenax],
      );
    }

    // Load extended brand details from brands.json
    try {
      final jsonStr = await rootBundle.loadString('assets/config/brands/brands.json');
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final detailsList = decoded['brandDetails'] as List<dynamic>?;
      if (detailsList != null) {
        for (final item in detailsList) {
          final d = BrandDetails.fromJson(item as Map<String, dynamic>);
          _brandDetails[d.name] = d;
        }
      }
    } catch (e) {
      debugPrint('[BrandResolver] Failed to load brand details: $e');
    }

    // Build-time selection only (no runtime switching).
    //
    // Use: `--dart-define=CLIENT=tenax` / `--dart-define=CLIENT=vantage` / `--dart-define=CLIENT=celestial`
    final selected = _client.trim().isNotEmpty ? _client : _flavor;
    final buildTime = BrandId.fromString(selected);
    final allowed = _registry!.brands.contains(buildTime)
        ? buildTime
        : _registry!.defaultBrand;

    activeBrand.value = allowed;

    // Initialize FlavorConfig from build-time client defaults early.
    FlavorConfig.activateByName(allowed.value);
  }

  Future<void> setActiveBrand(BrandId id) async {
    // Runtime switching is intentionally disabled (build-time only).
    if (kReleaseMode) return;

    final registry = _registry;
    final allowed = registry == null || registry.brands.contains(id);
    if (!allowed) return;

    if (activeBrand.value == id) return;

    activeBrand.value = id;
    await _storage.write(key: _brandKey, value: id.value);

    // Trigger global rebuilds (GetMaterialApp is wrapped by Obx in main.dart).
    Get.forceAppUpdate();
  }
}

