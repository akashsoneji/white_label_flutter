import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:yaml/yaml.dart';

import '../../brands/brand_id.dart';
import '../../brands/brand_resolver.dart';
import '../../flavor_config.dart';
import 'app_config_model.dart';

class AppConfigService extends GetxService {
  final _config = Rxn<AppConfigModel>();

  AppConfigModel? get config => _config.value;

  bool isFeatureEnabled(String key, {bool defaultValue = true}) {
    return _config.value?.isFeatureEnabled(key, defaultValue: defaultValue) ??
        defaultValue;
  }

  Future<void> ensureInitialized() async {
    if (_config.value != null) return;
    await reload();
  }

  /// Reload app config from the currently-active brand.
  ///
  /// Sources, in order:
  ///   1. `assets/clients/<activeBrand>/brand.yaml` — the bundled per-
  ///      client config (what the build script copies from
  ///      `assets/brands/<brand>/brand.yaml`).
  ///   2. The legacy `assets/config/brands/brands.json` for branding
  ///      fields that aren't in the YAML yet.
  ///   3. `FlavorConfig` as a final fallback for branding.
  Future<void> reload() async {
    final branding = AppBrandingConfig(
      appName: FlavorConfig.instance.appName,
      appTitle: FlavorConfig.instance.appTitle,
      primaryColor: FlavorConfig.instance.primaryColor,
      secondaryColor: FlavorConfig.instance.secondaryColor,
      accentColor: FlavorConfig.instance.accentColor,
      logoSvgPath: FlavorConfig.instance.svgLogoPath,
      splashLogoPath: FlavorConfig.instance.splashLogoPath,
    );

    final features = await _readFeatureFlags();

    _config.value = AppConfigModel(
      branding: branding,
      features: features,
    );

    if (kDebugMode) {
      debugPrint(
        'AppConfigService: loaded features for ${FlavorConfig.instance.flavor.name} → $features',
      );
    }
  }

  /// Read `featureFlags:` from the bundled per-client brand.yaml.
  ///
  /// Returns an empty map if the file is missing or has no `featureFlags`
  /// section — every flag then falls back to its defaultValue.
  Future<Map<String, bool>> _readFeatureFlags() async {
    try {
      // Resolve the active brand id from the resolver if it's up, else
      // fall back to FlavorConfig.
      BrandId active = BrandId.tenax;
      try {
        if (Get.isRegistered<BrandResolver>()) {
          final resolver = Get.find<BrandResolver>();
          await resolver.ensureInitialized();
          active = resolver.activeBrand.value;
        }
      } catch (_) {
        // Resolver not ready yet — default to flavor.
      }

      final assetPath = BrandResolver.appConfigAssetPathFor(active);
      final raw = await rootBundle.loadString(assetPath);
      // brand.yaml is YAML; we only need the top-level `featureFlags` map.
      final parsed = loadYaml(raw);
      if (parsed is! YamlMap) return const <String, bool>{};

      final flagBlock = parsed['featureFlags'];
      if (flagBlock is! YamlMap) return const <String, bool>{};

      final out = <String, bool>{};
      flagBlock.forEach((key, value) {
        if (key is String) {
          if (value is bool) {
            out[key] = value;
          } else if (value is num) {
            out[key] = value != 0;
          } else if (value is String) {
            final v = value.toLowerCase().trim();
            out[key] = v == 'true' || v == '1' || v == 'yes' || v == 'on';
          }
        }
      });
      return out;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppConfigService: failed to read featureFlags: $e');
      }
      return const <String, bool>{};
    }
  }

  /// Convenience: should the app use the single-stream `/ws/stream` socket?
  bool get useUnifiedStreamSocket =>
      isFeatureEnabled(FeatureFlags.unifiedStreamSocketKey, defaultValue: false);
}

/// Canonical feature-flag keys. These must match the keys you put in
/// `assets/brands/<brand>/brand.yaml` under `featureFlags:`.
class FeatureFlags {
  FeatureFlags._();

  /// Master toggle: when true, the app uses the single `/ws/stream` socket
  /// (MessagePack binary, condition-based demux). When false, the legacy
  /// 5-socket path is used.
  static const String unifiedStreamSocketKey = 'unifiedStreamSocket';
}
