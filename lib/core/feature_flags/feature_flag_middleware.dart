import 'package:get/get.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config_service.dart';
import '../routing/feature_unavailable_screen.dart';

class FeatureFlagMiddleware extends GetMiddleware {
  final String featureKey;
  final bool defaultEnabled;

  FeatureFlagMiddleware(
    this.featureKey, {
    this.defaultEnabled = true,
  });

  @override
  RouteSettings? redirect(String? route) {
    try {
      final cfg = Get.find<AppConfigService>();
      final enabled =
          cfg.isFeatureEnabled(featureKey, defaultValue: defaultEnabled);
      if (enabled) return null;
    } catch (_) {
      // If config isn't available for some reason, fall back to defaultEnabled.
      if (defaultEnabled) return null;
    }

    return RouteSettings(
      name: FeatureUnavailableScreen.routeName,
      arguments: {'featureKey': featureKey},
    );
  }
}

