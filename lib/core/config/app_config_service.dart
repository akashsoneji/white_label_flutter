import 'package:get/get.dart';
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
    // app_config.json has been removed since branding/features are loaded via API / FlavorConfig.
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
  }
}

