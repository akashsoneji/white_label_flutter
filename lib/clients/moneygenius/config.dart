// GENERATED — Do not edit manually. Regenerate from brands.yaml.
// Run: dart run scripts/generate_brand_config.dart

import 'package:flutter/material.dart';
import '../base_config.dart';

/// Auto-generated config for "MoneyGenius".
/// Change values in assets/config/brands/brands.yaml and re-run the generator.
class MoneygeniusConfig extends BaseClientConfig {
  const MoneygeniusConfig()
      : super(
          brandName: 'MoneyGenius',
          appTitle: 'MoneyGenius',
          primaryColor: const Color(0xFF006838),
          darkPrimaryColor: const Color(0xFFFFFFFF),
          secondaryColor: const Color(0xFF006838),
          accentColor: const Color(0xFF24324D),
          logoSvgPath: 'logo.svg',
          splashLogoPath: 'splash_logo.svg',
          appIconPath: 'icon.png',
 apiBaseUrl: 'https://portal.moneygeniuss.com/api/',
 websocketUrl: 'wss://portal.moneygeniuss.com/trade-engine',
 chartBaseUrl: 'https://portal.moneygeniuss.com',
 useNewChart: false,
 );
}
