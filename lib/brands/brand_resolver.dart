import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../flavor_config.dart';
import 'brand_id.dart';
import 'brand_registry.dart';

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

  late final Future<void> _initialization;

  @override
  void onInit() {
    super.onInit();
    _initialization = _initialize();
  }

  Future<void> ensureInitialized() => _initialization;

  BrandRegistry? get registry => _registry;

  /// Returns the expected path for the given brand's config.
  /// Convention: `assets/config/<brandId>/app_config.json`
  static String appConfigAssetPathFor(BrandId brandId) {
    return 'assets/config/${brandId.value}/app_config.json';
  }

  Future<void> _initialize() async {
    try {
      _registry = await BrandRegistry.loadFromAssets();
    } catch (e) {
      // Registry missing or invalid should never block app startup.
      debugPrint('[BrandResolver] Failed to load registry: $e');
      _registry = const BrandRegistry(
        defaultBrand: BrandId.tenax,
        brands: <BrandId>[BrandId.tenax],
      );
    }

    // Build-time selection only (no runtime switching).
    //
    // Use: `--dart-define=CLIENT=tenax` / `--dart-define=CLIENT=vantage`
    final selected = _client.trim().isNotEmpty ? _client : _flavor;
    final buildTime = BrandId.fromString(selected);
    final allowed = _registry!.brands.contains(buildTime)
        ? buildTime
        : _registry!.defaultBrand;

    activeBrand.value = allowed;

    // Initialize FlavorConfig from build-time client defaults early.
    // AppConfigService can still override branding later.
    switch (allowed.value) {
      case 'vantage':
        FlavorConfig.vantage;
        break;
      case 'tenax':
      default:
        FlavorConfig.tenax;
        break;
    }
  }

  Future<void> setActiveBrand(BrandId id) async {
    // Runtime switching is intentionally disabled (build-time only).
    // Keep method for compatibility; it becomes a no-op in release builds.
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

