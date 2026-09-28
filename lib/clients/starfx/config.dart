// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import '../base_config.dart';

/// Auto-generated config for "StarFX".
/// Change values in assets/config/brands/brands.yaml and re-run the generator.
class StarfxConfig extends BaseClientConfig {
  const StarfxConfig()
      : super(
          brandName: 'StarFX',
          appTitle: 'StarFX',
          primaryColor: const Color(0xFF151515),
          darkPrimaryColor: const Color(0xFFFFFFFF),
          secondaryColor: const Color(0xFFFF9441),
          accentColor: const Color(0xFFFF9441),
          logoSvgPath: 'logo.svg',
          splashLogoPath: 'splash_logo.svg',
          appIconPath: 'icon.png',
 apiBaseUrl: 'https://trader.starfxtrading.com/api/',
 websocketUrl: 'wss://trader.starfxtrading.com/trade-engine',
 chartBaseUrl: 'https://trader.starfxtrading.com',
 useNewChart: false,
 );
}
