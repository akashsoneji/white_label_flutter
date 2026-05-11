import 'package:flutter/material.dart';

import '../base_config.dart';

/// Vantage client configuration.
class VantageConfig extends BaseClientConfig {
  const VantageConfig()
    : super(
        brandName: 'Vantage',
        appTitle: 'Vantage',
        // Match the existing design tokens (blue primary + light background).
        primaryColor: const Color.fromARGB(255, 81, 13, 154),
        secondaryColor: const Color(0xFFE8F5E8),
        accentColor: const Color.fromARGB(255, 81, 13, 154),
        logoSvgPath: 'logo.svg',
        splashLogoPath: 'splash_logo.svg',
        appIconPath: 'app_icon.png',
        // Keep same APIs (per requirement) unless overridden later.
        apiBaseUrl: 'https://demo.tenaxcode.com/api/',
        websocketUrl: 'wss://demo.tenaxcode.com/trade-engine',
        chartBaseUrl: 'https://demo.tenaxcode.com',
      );
}
