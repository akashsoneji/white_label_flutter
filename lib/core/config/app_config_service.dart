import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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

  Future<void> reload() async {
    final brandResolver =
        Get.isRegistered<BrandResolver>() ? Get.find<BrandResolver>() : null;
    final brandId = brandResolver?.activeBrand.value ?? BrandId.tenax;
    final assetPath = BrandResolver.appConfigAssetPathFor(brandId);

    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw StateError('Invalid app_config.json: expected JSON object');
      }
      final model = AppConfigModel.fromJson(decoded.cast<String, dynamic>());
      _config.value = model;

      // Apply branding to FlavorConfig so existing UI uses it without refactors.
      // We now prioritize existing FlavorConfig instance values unless JSON explicitly overrides them.
      final branding = model.branding;
      FlavorConfig.applyBranding(
        config: <String, dynamic>{
          'appName': branding.appName.isNotEmpty ? branding.appName : FlavorConfig.instance.appName,
          'appTitle': branding.appTitle.isNotEmpty ? branding.appTitle : FlavorConfig.instance.appTitle,
          'primaryColor': branding.primaryColor ?? FlavorConfig.instance.primaryColor,
          'secondaryColor': branding.secondaryColor ?? FlavorConfig.instance.secondaryColor,
          'accentColor': branding.accentColor ?? FlavorConfig.instance.accentColor,
        },
        brokerName: branding.appName.isNotEmpty ? branding.appName : FlavorConfig.instance.appName,
        brokerLogoUrl: branding.logoSvgPath ?? FlavorConfig.instance.svgLogoPath,
        brokerData: null,
      );
    } on FlutterError catch (e) {
      // If the asset isn't bundled (common after flavor/build-cache issues),
      // don't block the entire app at splash. Fall back to the already-defined
      // FlavorConfig defaults so the app can continue.
      print('[AppConfig] Failed to load $assetPath: $e');
      _config.value = AppConfigModel(
        branding: AppBrandingConfig(
          appName: FlavorConfig.instance.appName,
          appTitle: FlavorConfig.instance.appTitle,
          primaryColor: FlavorConfig.instance.primaryColor,
          secondaryColor: FlavorConfig.instance.secondaryColor,
          accentColor: FlavorConfig.instance.accentColor,
          logoSvgPath: FlavorConfig.instance.svgLogoPath,
          splashLogoPath: FlavorConfig.instance.splashLogoPath,
        ),
        features: const <String, bool>{},
      );
    } on FormatException catch (e) {
      print('[AppConfig] Invalid JSON in $assetPath: $e');
      rethrow;
    }
  }
}

